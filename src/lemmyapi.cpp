#include "lemmyapi.h"
#include "lemmy_bridge.h"
#include "postsmodel.h"
#include "securestorage.h"
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QEventLoop>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QList>
#include <QMap>
#include <QSettings>
#include <QStandardPaths>
#include <QUrl>
#include <QVariant>
#include <functional>

// ===================================================================
// LemmyWorker implementation
// ===================================================================

LemmyWorker::LemmyWorker(QObject *parent)
    : QObject(parent), m_handle(nullptr) {}

LemmyWorker::~LemmyWorker() { destroyClient(); }

void LemmyWorker::createClient(const QString &domain, bool secure) {
  destroyClient();
  QByteArray domainUtf8 = domain.toUtf8();
  m_handle = lemmy_client_new(domainUtf8.constData(), secure);
}

void LemmyWorker::destroyClient() {
  if (m_handle) {
    lemmy_client_free(m_handle);
    m_handle = nullptr;
  }
}

void LemmyWorker::setJwt(const QString &jwt) {
  if (!m_handle)
    return;
  QByteArray jwtUtf8 = jwt.toUtf8();
  lemmy_client_set_jwt(m_handle, jwtUtf8.constData());
}

static QString callRust(LemmyClientHandle *handle,
                        char *(*fn)(LemmyClientHandle *, const char *),
                        const QString &jsonParams) {
  QByteArray paramsUtf8 = jsonParams.toUtf8();
  char *result =
      fn(handle, paramsUtf8.isEmpty() ? nullptr : paramsUtf8.constData());
  QString json = result ? QString::fromUtf8(result)
                        : QStringLiteral("{\"error\":\"null result\"}");
  if (result)
    lemmy_free_string(result);
  return json;
}

void LemmyWorker::doLogin(const QString &username, const QString &password,
                          const QString &totp) {
  if (!m_handle) {
    emit loginFinished(QStringLiteral("{\"error\":\"no client\"}"));
    return;
  }
  QByteArray u = username.toUtf8();
  QByteArray p = password.toUtf8();
  QByteArray t = totp.toUtf8();
  char *result = lemmy_login(m_handle, u.constData(), p.constData(),
                             t.isEmpty() ? nullptr : t.constData());
  QString json = result ? QString::fromUtf8(result)
                        : QStringLiteral("{\"error\":\"null result\"}");
  if (result)
    lemmy_free_string(result);
  emit loginFinished(json);
}

void LemmyWorker::doLogout() {
  if (!m_handle) {
    emit logoutFinished(QStringLiteral("{\"error\":\"no client\"}"));
    return;
  }
  char *result = lemmy_logout(m_handle);
  QString json = result ? QString::fromUtf8(result)
                        : QStringLiteral("{\"error\":\"null result\"}");
  if (result)
    lemmy_free_string(result);
  emit logoutFinished(json);
}

void LemmyWorker::doGetSite() {
  if (!m_handle) {
    emit getSiteFinished(QStringLiteral("{\"error\":\"no client\"}"));
    return;
  }
  char *result = lemmy_get_site(m_handle);
  QString json = result ? QString::fromUtf8(result)
                        : QStringLiteral("{\"error\":\"null result\"}");
  if (result)
    lemmy_free_string(result);
  emit getSiteFinished(json);
}

void LemmyWorker::doListPosts(const QString &jsonParams) {
  emit listPostsFinished(callRust(m_handle, lemmy_list_posts, jsonParams));
}

void LemmyWorker::doGetPost(const QString &jsonParams) {
  emit getPostFinished(callRust(m_handle, lemmy_get_post, jsonParams));
}

void LemmyWorker::doLikePost(const QString &jsonParams) {
  emit likePostFinished(callRust(m_handle, lemmy_like_post, jsonParams));
}

void LemmyWorker::doCreatePost(const QString &jsonParams) {
  emit createPostFinished(callRust(m_handle, lemmy_create_post, jsonParams));
}

void LemmyWorker::doListComments(const QString &jsonParams) {
  emit listCommentsFinished(
      callRust(m_handle, lemmy_list_comments, jsonParams));
}

void LemmyWorker::doLikeComment(const QString &jsonParams) {
  emit likeCommentFinished(callRust(m_handle, lemmy_like_comment, jsonParams));
}

void LemmyWorker::doCreateComment(const QString &jsonParams) {
  emit createCommentFinished(
      callRust(m_handle, lemmy_create_comment, jsonParams));
}

void LemmyWorker::doListCommunities(const QString &jsonParams) {
  emit listCommunitiesFinished(
      callRust(m_handle, lemmy_list_communities, jsonParams));
}

void LemmyWorker::doGetCommunity(const QString &jsonParams) {
  emit getCommunityFinished(
      callRust(m_handle, lemmy_get_community, jsonParams));
}

void LemmyWorker::doGetPerson(const QString &jsonParams) {
  emit getPersonFinished(callRust(m_handle, lemmy_get_person, jsonParams));
}

void LemmyWorker::doSearch(const QString &jsonParams) {
  emit searchFinished(callRust(m_handle, lemmy_search, jsonParams));
}

void LemmyWorker::doFollowCommunity(const QString &jsonParams) {
  emit followCommunityFinished(
      callRust(m_handle, lemmy_follow_community, jsonParams));
}

void LemmyWorker::doListNotifications(const QString &jsonParams) {
  emit listNotificationsFinished(
      callRust(m_handle, lemmy_list_notifications, jsonParams));
}

void LemmyWorker::doMarkNotificationsRead(const QString &jsonParams) {
  emit markNotificationsReadFinished(
      callRust(m_handle, lemmy_mark_notifications_read, jsonParams));
}

void LemmyWorker::doUnreadCount() {
  if (!m_handle) {
    emit unreadCountFinished(QStringLiteral("{\"error\":\"no client\"}"));
    return;
  }
  char *result = lemmy_unread_count(m_handle);
  QString json = result ? QString::fromUtf8(result)
                        : QStringLiteral("{\"error\":\"null result\"}");
  if (result)
    lemmy_free_string(result);
  emit unreadCountFinished(json);
}

// ===================================================================
// LemmyAPI implementation
// ===================================================================

LemmyAPI::LemmyAPI(QObject *parent)
    : QObject(parent), m_loggedIn(false), m_busy(false), m_posts(0),
      m_postsPage(1), m_loadingMore(false), m_communitiesPage(1),
      m_loadingMoreCommunities(false), m_commentsPage(1),
      m_loadingMoreComments(false), m_unreadCount(0), m_serverUnreadCount(-1),
      m_lastSeenNotificationId(-1), m_backgroundCheckEnabled(false),
      m_checkIntervalMinutes(15), m_notificationTimer(new QTimer(this)),
      m_worker(new LemmyWorker), // no parent – will be moved to thread
      m_secureStorage(new SecureStorage(this)) {
  // Initialize secure storage and wait for it to be ready
  QEventLoop initLoop;
  connect(m_secureStorage, &SecureStorage::initialized, &initLoop,
          &QEventLoop::quit);
  connect(m_secureStorage, &SecureStorage::error, &initLoop, &QEventLoop::quit);
  m_secureStorage->initialize();
  initLoop.exec();

  const QString settingsPath =
      QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) +
      QDir::separator() + QCoreApplication::applicationName() + ".conf";
  m_settings = new QSettings(settingsPath, QSettings::NativeFormat, this);

  if (!m_settings->contains("migrated")) {
    QSettings oldSettings(QCoreApplication::applicationName(),
                          QCoreApplication::applicationName(), this);

    for (const QString &key : oldSettings.childKeys())
      m_settings->setValue(key, oldSettings.value(key));

    oldSettings.clear();

    m_settings->setValue("migrated", "true");
  }

  m_username = m_settings->value(QStringLiteral("username")).toString();
  m_instanceUrl = m_settings->value(QStringLiteral("instanceUrl")).toString();
  m_currentSort =
      m_settings->value(QStringLiteral("currentSort"), QStringLiteral("Active"))
          .toString();
  m_commentSort =
      m_settings->value(QStringLiteral("commentSort"), QStringLiteral("Hot"))
          .toString();
  m_listingType = m_settings
                       ->value(QStringLiteral("listingType"),
                               QStringLiteral("Subscribed"))
                       .toString();

  // Retrieve JWT from secure storage
  m_jwt = m_secureStorage->loadAccessToken();

  if (!m_jwt.isEmpty()) {
    m_loggedIn = true;
  }

  // Load notification settings
  m_backgroundCheckEnabled =
      m_settings->value("notifications/backgroundCheck", false).toBool();
  m_checkIntervalMinutes =
      m_settings->value("notifications/intervalMinutes", 15).toInt();
  m_lastSeenNotificationId =
      m_settings->value("notifications/lastSeenId", -1).toInt();
  m_serverUnreadCount =
      m_settings->value("notifications/serverUnreadCount", -1).toInt();

  // Setup notification timer
  m_notificationTimer->setSingleShot(false);
  connect(m_notificationTimer, &QTimer::timeout, this,
          &LemmyAPI::onNotificationTimerFired);

  // Move the worker to a background thread
  m_worker->moveToThread(&m_workerThread);
  connect(&m_workerThread, &QThread::finished, m_worker, &QObject::deleteLater);

  // Connect worker signals → our handler slots (queued across threads)
  connect(m_worker, &LemmyWorker::loginFinished, this,
          &LemmyAPI::onLoginFinished);
  connect(m_worker, &LemmyWorker::logoutFinished, this,
          &LemmyAPI::onLogoutFinished);
  connect(m_worker, &LemmyWorker::getSiteFinished, this,
          &LemmyAPI::onGetSiteFinished);
  connect(m_worker, &LemmyWorker::listPostsFinished, this,
          &LemmyAPI::onListPostsFinished);
  connect(m_worker, &LemmyWorker::getPostFinished, this,
          &LemmyAPI::onGetPostFinished);
  connect(m_worker, &LemmyWorker::likePostFinished, this,
          &LemmyAPI::onLikePostFinished);
  connect(m_worker, &LemmyWorker::createPostFinished, this,
          &LemmyAPI::onCreatePostFinished);
  connect(m_worker, &LemmyWorker::listCommentsFinished, this,
          &LemmyAPI::onListCommentsFinished);
  connect(m_worker, &LemmyWorker::likeCommentFinished, this,
          &LemmyAPI::onLikeCommentFinished);
  connect(m_worker, &LemmyWorker::createCommentFinished, this,
          &LemmyAPI::onCreateCommentFinished);
  connect(m_worker, &LemmyWorker::listCommunitiesFinished, this,
          &LemmyAPI::onListCommunitiesFinished);
  connect(m_worker, &LemmyWorker::getCommunityFinished, this,
          &LemmyAPI::onGetCommunityFinished);
  connect(m_worker, &LemmyWorker::getPersonFinished, this,
          &LemmyAPI::onGetPersonFinished);
  connect(m_worker, &LemmyWorker::searchFinished, this,
          &LemmyAPI::onSearchFinished);
  connect(m_worker, &LemmyWorker::followCommunityFinished, this,
          &LemmyAPI::onFollowCommunityFinished);
  connect(m_worker, &LemmyWorker::listNotificationsFinished, this,
          &LemmyAPI::onListNotificationsFinished);
  connect(m_worker, &LemmyWorker::markNotificationsReadFinished, this,
          &LemmyAPI::onMarkNotificationsReadFinished);
  connect(m_worker, &LemmyWorker::unreadCountFinished, this,
          &LemmyAPI::onUnreadCountFinished);

  m_workerThread.start();

  // If we already have an instance URL, create the client
  if (!m_instanceUrl.isEmpty()) {
    ensureClient();
  }

  // Start background notification timer if logged in and enabled
  if (m_loggedIn && m_backgroundCheckEnabled)
    m_notificationTimer->start(m_checkIntervalMinutes * 60 * 1000);

  if (m_loggedIn)
    checkUnreadCount();
}

LemmyAPI::~LemmyAPI() {
  m_notificationTimer->stop();
  m_workerThread.quit();
  m_workerThread.wait();
}

void LemmyAPI::appendCommunities(const QJsonArray &newCommunities) {
  for (const auto &community : newCommunities) {
    m_communities.append(community);
  }
  emit communitiesChanged();
}

void LemmyAPI::buildCommentTree(const QJsonArray &comments) {
  struct CommentNode {
    QJsonObject commentObj;
    QJsonObject creatorObj;
    QJsonObject counts;
    QString path;
    int depth;
    int score;
    int myVote;
    QList<int> children;
  };

  QMap<QString, int> pathToIndex;
  QList<CommentNode> allNodes;

  // First pass: create all nodes
  for (const auto &item : comments) {
    QJsonObject itemObj = item.toObject();
    QJsonObject comment =
        itemObj.contains("comment") ? itemObj["comment"].toObject() : itemObj;
    QString path = comment.contains("path") ? comment["path"].toString() : "";
    int depth = path.isEmpty() ? 1 : path.split('.').length();

    int score = 0;
    if (itemObj.contains("counts")) {
      score = itemObj["counts"].toObject().value("score").toInt(0);
    }

    int myVote = 0;
    if (itemObj.contains("my_vote")) {
      myVote = itemObj["my_vote"].toInt(0);
    }

    CommentNode node;
    node.commentObj = comment;
    node.creatorObj = itemObj.contains("creator")
                          ? itemObj["creator"].toObject()
                          : QJsonObject();
    node.counts = itemObj.contains("counts") ? itemObj["counts"].toObject()
                                             : QJsonObject();
    node.path = path;
    node.depth = depth;
    node.score = score;
    node.myVote = myVote;

    pathToIndex[path] = allNodes.size();
    allNodes.append(node);
  }

  // Second pass: link children to parents by index
  QList<int> rootIndices;
  for (int i = 0; i < allNodes.size(); ++i) {
    if (allNodes[i].depth == 1) {
      rootIndices.append(i);
    } else {
      QString parentPath =
          allNodes[i].path.left(allNodes[i].path.lastIndexOf('.'));
      if (pathToIndex.contains(parentPath)) {
        allNodes[pathToIndex[parentPath]].children.append(i);
      } else {
        rootIndices.append(i);
      }
    }
  }

  // Flatten tree into threaded comments with depth info
  std::function<void(int, int)> flatten = [&](int nodeIdx, int depth) {
    const CommentNode &node = allNodes[nodeIdx];
    QVariantMap entry;
    entry["commentData"] = QVariant(node.commentObj);
    entry["creator"] = QVariant(node.creatorObj);
    entry["counts"] = QVariant(node.counts);
    entry["depth"] = depth;
    entry["score"] = node.score;
    entry["myVote"] = node.myVote;
    m_comments.append(entry);

    for (int childIdx : node.children) {
      flatten(childIdx, depth + 1);
    }
  };

  for (int rootIdx : rootIndices) {
    flatten(rootIdx, 1);
  }
}

void LemmyAPI::ensureClient() {
  if (m_instanceUrl.isEmpty())
    return;

  QUrl url(m_instanceUrl);
  QString domain = url.host();
  if (domain.isEmpty()) {
    // User may have typed just a domain without scheme
    domain = m_instanceUrl;
    domain.remove(QStringLiteral("https://"));
    domain.remove(QStringLiteral("http://"));
    // Strip trailing slash
    while (domain.endsWith('/'))
      domain.chop(1);
  }
  bool secure = !m_instanceUrl.startsWith(QStringLiteral("http://"));

  QMetaObject::invokeMethod(m_worker, "createClient", Qt::QueuedConnection,
                            Q_ARG(QString, domain), Q_ARG(bool, secure));

  // If we have a JWT, set it on the client
  if (!m_jwt.isEmpty()) {
    QMetaObject::invokeMethod(m_worker, "setJwt", Qt::QueuedConnection,
                              Q_ARG(QString, m_jwt));
  }
}

QJsonObject LemmyAPI::parseJson(const QString &json) {
  QJsonParseError err;
  QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8(), &err);
  if (err.error != QJsonParseError::NoError || !doc.isObject()) {
    QJsonObject errObj;
    errObj[QStringLiteral("error")] = err.errorString();
    return errObj;
  }
  return doc.object();
}

void LemmyAPI::invokeWorker(const char *method, const QString &jsonParams) {
  setBusy(true);
  QMetaObject::invokeMethod(m_worker, method, Qt::QueuedConnection,
                            Q_ARG(QString, jsonParams));
}

void LemmyAPI::handleSimpleResponse(const QString &json,
                                    const QString &methodName) {
  QJsonObject obj = parseJson(json);
  if (obj.contains(QStringLiteral("error"))) {
    setError(obj[QStringLiteral("error")].toString());
    setBusy(false);
    emit requestFailed(methodName, m_error);
    return;
  }
  setBusy(false);
  emit requestFinished(methodName, obj);
}

void LemmyAPI::loadMoreHelper(int &page, bool &loadingFlag, QJsonObject &filter,
                              const char *workerMethod) {
  setBusy(true);
  page++;
  loadingFlag = true;
  QJsonObject params = filter;
  params["page"] = page;
  QString paramsStr = QJsonDocument(params).toJson(QJsonDocument::Compact);
  QMetaObject::invokeMethod(m_worker, workerMethod, Qt::QueuedConnection,
                            Q_ARG(QString, paramsStr));
}

void LemmyAPI::setBusy(bool busy) {
  if (m_busy != busy) {
    m_busy = busy;
    emit busyChanged();
  }
}

void LemmyAPI::setLoggedIn(bool loggedIn) {
  if (m_loggedIn != loggedIn) {
    m_loggedIn = loggedIn;
    emit loggedInChanged();
  }
}

void LemmyAPI::setError(const QString &error) {
  if (m_error != error) {
    m_error = error;
    emit errorChanged();
  }
}

void LemmyAPI::setPostsPage(int page) {
  if (m_postsPage != page) {
    m_postsPage = page;
    emit postsPageChanged();
  }
}

void LemmyAPI::setCurrentSort(const QString &sort) {
  if (m_currentSort == sort)
    return;
  m_currentSort = sort;
  m_settings->setValue(QStringLiteral("currentSort"), sort);
  emit currentSortChanged();
}

void LemmyAPI::setCommentSort(const QString &sort) {
  if (m_commentSort == sort)
    return;
  m_commentSort = sort;
  m_settings->setValue(QStringLiteral("commentSort"), sort);
  emit commentSortChanged();
}

void LemmyAPI::setListingType(const QString &type) {
  if (m_listingType == type)
    return;
  m_listingType = type;
  m_settings->setValue(QStringLiteral("listingType"), type);
  emit listingTypeChanged();
}

void LemmyAPI::setPostsModel(PostsModel *model) {
  if (m_posts != model) {
    m_posts = model;
    emit postsChanged();
  }
}

void LemmyAPI::setCheckIntervalMinutes(int minutes) {
  minutes = qMax(1, minutes);
  if (m_checkIntervalMinutes == minutes)
    return;
  m_checkIntervalMinutes = minutes;
  m_settings->setValue("notifications/intervalMinutes", minutes);
  emit checkIntervalMinutesChanged();
  if (m_notificationTimer->isActive())
    m_notificationTimer->setInterval(minutes * 60 * 1000);
}

void LemmyAPI::login(const QString instanceUrl, const QString username,
                     const QString password, const QString totp) {
  if (m_busy)
    return;

  if (instanceUrl.isEmpty() || username.isEmpty() || password.isEmpty()) {
    setError(tr("Please fill in all fields"));
    emit loginFailed(error());
    return;
  }

  setBusy(true);
  setError(QString());

  m_username = username;
  m_instanceUrl = instanceUrl;

  ensureClient();

  QMetaObject::invokeMethod(m_worker, "doLogin", Qt::QueuedConnection,
                            Q_ARG(QString, username), Q_ARG(QString, password),
                            Q_ARG(QString, totp));
}

void LemmyAPI::logout() {
  setBusy(true);
  QMetaObject::invokeMethod(m_worker, "doLogout", Qt::QueuedConnection);
}

void LemmyAPI::clearError() { setError(QString()); }

void LemmyAPI::getSite() {
  setBusy(true);
  QMetaObject::invokeMethod(m_worker, "doGetSite", Qt::QueuedConnection);
}

void LemmyAPI::listPosts(const QString &jsonParams) {
  setBusy(true);
  m_postsPage = 1;
  m_loadingMore = false;

  // Store base filter (without page) for pagination
  QJsonDocument doc = QJsonDocument::fromJson(jsonParams.toUtf8());
  if (doc.isObject()) {
    QJsonObject obj = doc.object();
    obj.remove("page");
    m_postsFilter = obj;
  } else {
    m_postsFilter = QJsonObject();
  }

  QMetaObject::invokeMethod(m_worker, "doListPosts", Qt::QueuedConnection,
                            Q_ARG(QString, jsonParams));
}

void LemmyAPI::loadMorePosts() {
  loadMoreHelper(m_postsPage, m_loadingMore, m_postsFilter, "doListPosts");
}

void LemmyAPI::loadMoreCommunities() {
  loadMoreHelper(m_communitiesPage, m_loadingMoreCommunities,
                 m_communitiesFilter, "doListCommunities");
}

void LemmyAPI::loadMoreComments() {
  loadMoreHelper(m_commentsPage, m_loadingMoreComments, m_commentsFilter,
                 "doListComments");
}

void LemmyAPI::listComments(const QString &jsonParams) {
  setBusy(true);
  m_commentsPage = 1;
  m_loadingMoreComments = false;
  m_allCommentItems = QJsonArray();

  // Store base filter (without page) for pagination
  QJsonDocument doc = QJsonDocument::fromJson(jsonParams.toUtf8());
  if (doc.isObject()) {
    QJsonObject obj = doc.object();
    obj.remove("page");
    m_commentsFilter = obj;
  } else {
    m_commentsFilter = QJsonObject();
  }

  m_comments.clear();
  emit commentsChanged();
  QMetaObject::invokeMethod(m_worker, "doListComments", Qt::QueuedConnection,
                            Q_ARG(QString, jsonParams));
}

void LemmyAPI::likeComment(int commentId, int score) {
  setBusy(true);
  QString params = QStringLiteral("{\"comment_id\":%1,\"score\":%2}")
                       .arg(commentId)
                       .arg(score);
  QMetaObject::invokeMethod(m_worker, "doLikeComment", Qt::QueuedConnection,
                            Q_ARG(QString, params));
}

void LemmyAPI::updateCommentVote(int commentId, int myVote, int score) {
  for (int i = 0; i < m_comments.size(); ++i) {
    QVariantMap entry = m_comments[i].toMap();
    QJsonObject cd = entry.value(QStringLiteral("commentData")).toJsonObject();
    if (cd.value(QStringLiteral("id")).toInt() == commentId) {
      QJsonObject counts = entry.value(QStringLiteral("counts")).toJsonObject();
      counts[QStringLiteral("score")] = score;
      entry[QStringLiteral("counts")] = QVariant::fromValue(counts);
      entry[QStringLiteral("myVote")] = myVote;
      m_comments[i] = entry;
      emit commentsChanged();
      return;
    }
  }
}

void LemmyAPI::createComment(int postId, const QString &content, int parentId) {
  setBusy(true);
  QJsonObject obj;
  obj["post_id"] = postId;
  obj["content"] = content;
  if (parentId > 0) {
    obj["parent_id"] = parentId;
  }
  QString params = QJsonDocument(obj).toJson(QJsonDocument::Compact);
  QMetaObject::invokeMethod(m_worker, "doCreateComment", Qt::QueuedConnection,
                            Q_ARG(QString, params));
}

void LemmyAPI::listCommunities(const QString &jsonParams) {
  setBusy(true);
  m_communitiesPage = 1;
  m_loadingMoreCommunities = false;

  // Store base filter (without page) for pagination
  QJsonDocument doc = QJsonDocument::fromJson(jsonParams.toUtf8());
  if (doc.isObject()) {
    QJsonObject obj = doc.object();
    obj.remove("page");
    m_communitiesFilter = obj;
  } else {
    m_communitiesFilter = QJsonObject();
  }

  QMetaObject::invokeMethod(m_worker, "doListCommunities", Qt::QueuedConnection,
                            Q_ARG(QString, jsonParams));
}

void LemmyAPI::getPost(int postId) {
  setBusy(true);
  QString params = QStringLiteral("{\"id\":%1}").arg(postId);
  QMetaObject::invokeMethod(m_worker, "doGetPost", Qt::QueuedConnection,
                            Q_ARG(QString, params));
}

void LemmyAPI::likePost(int postId, int score) {
  setBusy(true);
  QString params =
      QStringLiteral("{\"post_id\":%1,\"score\":%2}").arg(postId).arg(score);
  QMetaObject::invokeMethod(m_worker, "doLikePost", Qt::QueuedConnection,
                            Q_ARG(QString, params));
}

void LemmyAPI::updatePostInModel(int postId, const QJsonObject &postView) {
  if (m_posts)
    m_posts->updatePost(postId, postView);
}

void LemmyAPI::createPost(const QString &jsonParams) {
  invokeWorker("doCreatePost", jsonParams);
}

void LemmyAPI::getCommunity(const QString &jsonParams) {
  invokeWorker("doGetCommunity", jsonParams);
}

void LemmyAPI::getPerson(const QString &jsonParams) {
  invokeWorker("doGetPerson", jsonParams);
}

void LemmyAPI::search(const QString &jsonParams) {
  invokeWorker("doSearch", jsonParams);
}

void LemmyAPI::followCommunity(const QString &jsonParams) {
  invokeWorker("doFollowCommunity", jsonParams);
}

void LemmyAPI::listNotifications(bool unreadOnly, int limit, int page) {
  QJsonObject params;
  params["unread_only"] = unreadOnly;
  if (limit > 0)
    params["limit"] = limit;
  if (page > 0)
    params["page"] = page;
  setBusy(true);
  QMetaObject::invokeMethod(
      m_worker, "doListNotifications", Qt::QueuedConnection,
      Q_ARG(QString, QJsonDocument(params).toJson(QJsonDocument::Compact)));
}

void LemmyAPI::markNotificationsRead(int notificationId,
                                     const QString &notificationType) {
  QJsonObject params;
  if (notificationId < 0)
    params["all"] = true;
  else {
    params["notification_id"] = notificationId;
    if (!notificationType.isEmpty())
      params["notification_type"] = notificationType;
  }
  setBusy(true);
  QMetaObject::invokeMethod(
      m_worker, "doMarkNotificationsRead", Qt::QueuedConnection,
      Q_ARG(QString, QJsonDocument(params).toJson(QJsonDocument::Compact)));
}

void LemmyAPI::setBackgroundCheckEnabled(bool enabled) {
  if (m_backgroundCheckEnabled == enabled)
    return;
  m_backgroundCheckEnabled = enabled;
  m_settings->setValue("notifications/backgroundCheck", enabled);
  emit backgroundCheckEnabledChanged();
  if (enabled && m_loggedIn)
    m_notificationTimer->start(m_checkIntervalMinutes * 60 * 1000);
  else
    m_notificationTimer->stop();
}

void LemmyAPI::onNotificationTimerFired() {
  if (m_loggedIn && !m_busy)
    checkUnreadCount();
}

void LemmyAPI::checkUnreadCount() {
  QMetaObject::invokeMethod(m_worker, "doUnreadCount", Qt::QueuedConnection);
}

void LemmyAPI::onListNotificationsFinished(const QString &json) {
  setBusy(false);
  QJsonObject obj = parseJson(json);
  if (obj.contains("error")) {
    emit requestFailed("listNotifications", obj["error"].toString());
    return;
  }
  QJsonArray arr = obj.value("notifications").toArray();
  m_notifications.clear();
  int newUnread = 0;
  int newSinceLastCheck = 0;
  int maxId = m_lastSeenNotificationId;
  for (const QJsonValue &v : arr) {
    QJsonObject n = v.toObject();
    m_notifications.append(n.toVariantMap());
    if (n.value("unread").toBool())
      newUnread++;
    int nid = n.value("id").toInt();
    if (nid > maxId)
      maxId = nid;
    if (nid > m_lastSeenNotificationId)
      newSinceLastCheck++;
  }
  bool hasNew = newSinceLastCheck > 0 && m_lastSeenNotificationId >= 0;
  int prevUnread = m_unreadCount;
  m_unreadCount = newUnread;
  if (m_unreadCount != prevUnread)
    emit unreadCountChanged();
  if (hasNew)
    emit newNotificationsReceived(newSinceLastCheck);
  if (maxId > m_lastSeenNotificationId) {
    m_lastSeenNotificationId = maxId;
    m_settings->setValue("notifications/lastSeenId", maxId);
  }
  emit notificationsChanged();
  emit requestFinished("listNotifications", obj);
}

void LemmyAPI::onMarkNotificationsReadFinished(const QString &json) {
  setBusy(false);
  emit requestFinished("markNotificationsRead", parseJson(json));
  listNotifications();
}

void LemmyAPI::onUnreadCountFinished(const QString &json) {
  QJsonObject obj = parseJson(json);
  if (obj.contains("error")) {
    return;
  }
  int total = obj.value("replies").toInt(0) + obj.value("mentions").toInt(0) +
              obj.value("private_messages").toInt(0);
  int prev = m_serverUnreadCount;
  m_serverUnreadCount = total;
  m_settings->setValue("notifications/serverUnreadCount", total);
  m_unreadCount = total;
  emit unreadCountChanged();
  if (prev >= 0 && total > prev)
    emit newNotificationsReceived(total - prev);
}

void LemmyAPI::onLoginFinished(const QString &json) {
  QJsonObject obj = parseJson(json);
  if (obj.contains(QStringLiteral("error"))) {
    QString msg = obj[QStringLiteral("error")].toString();
    setError(msg);
    setBusy(false);
    emit loginFailed(msg);
    return;
  }

  // lemmy-client-rs returns LoginResponse which has jwt field
  QString jwt = obj.value(QStringLiteral("jwt")).toString();
  if (jwt.isEmpty()) {
    // Some versions return nested structure
    jwt = obj.value(QStringLiteral("jwt")).toString();
  }

  if (!jwt.isEmpty()) {
    m_jwt = jwt;
    // Store JWT securely
    m_secureStorage->saveAccessToken(jwt);
    // Store details in QSettings
    m_settings->setValue(QStringLiteral("username"), m_username);
    m_settings->setValue(QStringLiteral("instanceUrl"), m_instanceUrl);

    // Set the JWT on the Rust client for subsequent requests
    QMetaObject::invokeMethod(m_worker, "setJwt", Qt::QueuedConnection,
                              Q_ARG(QString, m_jwt));

    setLoggedIn(true);
    setBusy(false);
    emit loginSuccess();

    // Start background notification timer if enabled
    if (m_backgroundCheckEnabled)
      m_notificationTimer->start(m_checkIntervalMinutes * 60 * 1000);

    checkUnreadCount();
  } else {
    setError(tr("Login succeeded but no token received"));
    setBusy(false);
    emit loginFailed(m_error);
  }
}

void LemmyAPI::onLogoutFinished(const QString &json) {
  Q_UNUSED(json)
  m_jwt.clear();
  // Remove JWT from secure storage
  m_secureStorage->clearAll();
  // Remove user details from QSettings
  m_settings->remove(QStringLiteral("username"));
  m_settings->remove(QStringLiteral("instanceUrl"));
  m_username.clear();
  m_instanceUrl.clear();
  setLoggedIn(false);
  setBusy(false);

  // Stop notification timer
  m_notificationTimer->stop();
  m_notifications.clear();
  m_unreadCount = 0;
  m_serverUnreadCount = -1;
  emit notificationsChanged();
  emit unreadCountChanged();

  // Clear cached data
  if (m_posts) {
    m_posts->clear();
  }
  m_communities = QJsonArray();
  emit communitiesChanged();
  m_comments.clear();
  m_allCommentItems = QJsonArray();
  emit commentsChanged();
}

void LemmyAPI::onGetSiteFinished(const QString &json) {
  QJsonObject obj = parseJson(json);
  if (obj.contains(QStringLiteral("error"))) {
    setError(obj[QStringLiteral("error")].toString());
    setBusy(false);
    emit requestFailed(QStringLiteral("getSite"), m_error);
    return;
  }
  m_siteInfo = obj;
  emit siteInfoChanged();
  setBusy(false);
  emit requestFinished(QStringLiteral("getSite"), obj);
}

void LemmyAPI::onListPostsFinished(const QString &json) {
  QJsonObject obj = parseJson(json);
  if (obj.contains(QStringLiteral("error"))) {
    setError(obj[QStringLiteral("error")].toString());
    setBusy(false);
    m_loadingMore = false;
    emit requestFailed(QStringLiteral("listPosts"), m_error);
    return;
  }
  if (!m_loadingMore && m_posts) {
    m_posts->clear();
  }
  QJsonArray newPosts = obj.value(QStringLiteral("posts")).toArray();
  if (m_posts) {
    m_posts->append(newPosts);
  }
  setBusy(false);
  m_loadingMore = false;
  emit requestFinished(QStringLiteral("listPosts"), obj);
}

void LemmyAPI::onGetPostFinished(const QString &json) {
  handleSimpleResponse(json, QStringLiteral("getPost"));
}

void LemmyAPI::onLikePostFinished(const QString &json) {
  handleSimpleResponse(json, QStringLiteral("likePost"));
}

void LemmyAPI::onCreatePostFinished(const QString &json) {
  handleSimpleResponse(json, QStringLiteral("createPost"));
}

void LemmyAPI::onListCommentsFinished(const QString &json) {
  QJsonObject obj = parseJson(json);
  if (obj.contains(QStringLiteral("error"))) {
    setError(obj[QStringLiteral("error")].toString());
    setBusy(false);
    m_loadingMoreComments = false;
    emit requestFailed(QStringLiteral("listComments"), m_error);
    return;
  }
  QJsonArray newComments = obj.value(QStringLiteral("comments")).toArray();

  if (m_loadingMoreComments) {
    // Append new items to accumulated list
    for (const QJsonValue &val : newComments) {
      m_allCommentItems.append(val);
    }
  } else {
    // Initial load: replace accumulated items
    m_allCommentItems = newComments;
  }

  // Rebuild the entire comment tree from all accumulated raw items
  m_comments.clear();
  buildCommentTree(m_allCommentItems);

  emit commentsChanged();
  setBusy(false);
  m_loadingMoreComments = false;
  emit requestFinished(QStringLiteral("listComments"), obj);
}

void LemmyAPI::onLikeCommentFinished(const QString &json) {
  handleSimpleResponse(json, QStringLiteral("likeComment"));
}

void LemmyAPI::onCreateCommentFinished(const QString &json) {
  handleSimpleResponse(json, QStringLiteral("createComment"));
}

void LemmyAPI::onListCommunitiesFinished(const QString &json) {
  QJsonObject obj = parseJson(json);
  if (obj.contains(QStringLiteral("error"))) {
    setError(obj[QStringLiteral("error")].toString());
    setBusy(false);
    m_loadingMoreCommunities = false;
    emit requestFailed(QStringLiteral("listCommunities"), m_error);
    return;
  }
  QJsonArray newCommunities =
      obj.value(QStringLiteral("communities")).toArray();
  if (m_loadingMoreCommunities) {
    appendCommunities(newCommunities);
  } else {
    m_communities = newCommunities;
    emit communitiesChanged();
  }
  setBusy(false);
  m_loadingMoreCommunities = false;
  emit requestFinished(QStringLiteral("listCommunities"), obj);
}

void LemmyAPI::onGetCommunityFinished(const QString &json) {
  handleSimpleResponse(json, QStringLiteral("getCommunity"));
}

void LemmyAPI::onGetPersonFinished(const QString &json) {
  handleSimpleResponse(json, QStringLiteral("getPerson"));
}

void LemmyAPI::onSearchFinished(const QString &json) {
  handleSimpleResponse(json, QStringLiteral("search"));
}

void LemmyAPI::onFollowCommunityFinished(const QString &json) {
  handleSimpleResponse(json, QStringLiteral("followCommunity"));
}
