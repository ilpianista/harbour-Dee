#include "piefedclient.h"

#include <QByteArray>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QUrlQuery>

static QString compactJson(const QJsonObject &obj);
static QString errorJson(const QString &message);
static QString finishJson(QNetworkReply *reply,
                          std::function<QJsonObject(QJsonObject)> normalize);
static QString responseErrorText(QNetworkReply *reply, const QJsonObject &obj);

PieFedClient::PieFedClient(QObject *parent)
    : QObject(parent), m_generation(0) {}

void PieFedClient::setInstanceUrl(const QString &instanceUrl) {
  QString normalized = instanceUrl.trimmed();
  if (!normalized.startsWith(QStringLiteral("http://")) &&
      !normalized.startsWith(QStringLiteral("https://"))) {
    normalized.prepend(QStringLiteral("https://"));
  }
  while (normalized.endsWith('/'))
    normalized.chop(1);
  m_baseUrl = QUrl(normalized);
}

void PieFedClient::setJwt(const QString &jwt) { m_jwt = jwt; }

void PieFedClient::cancelPendingRequests() {
  ++m_generation;
  const QList<QNetworkReply *> replies = m_replies;
  m_replies.clear();
  for (QNetworkReply *reply : replies) {
    if (reply)
      reply->abort();
  }
}

void PieFedClient::login(const QString &username, const QString &password) {
  QJsonObject body;
  body[QStringLiteral("username")] = username;
  body[QStringLiteral("password")] = password;
  post(Operation::Login, QStringLiteral("/api/alpha/user/login"), body, nullptr);
}

void PieFedClient::getSite() {
  get(Operation::GetSite, QStringLiteral("/api/alpha/site"), QUrlQuery(),
      [this](QJsonObject response) { return normalizeSite(response); });
}

void PieFedClient::listPosts(const QString &jsonParams) {
  get(Operation::ListPosts, QStringLiteral("/api/alpha/post/list"),
      queryFromJson(jsonParams),
      [this](QJsonObject response) { return normalizePosts(response); });
}

void PieFedClient::listComments(const QString &jsonParams) {
  get(Operation::ListComments, QStringLiteral("/api/alpha/comment/list"),
      queryFromJson(jsonParams),
      [this](QJsonObject response) { return normalizeComments(response); });
}

void PieFedClient::getPost(int postId) {
  QUrlQuery query;
  query.addQueryItem(QStringLiteral("id"), QString::number(postId));
  get(Operation::GetPost, QStringLiteral("/api/alpha/post"), query,
      [this](QJsonObject response) { return normalizePostResponse(response); });
}

void PieFedClient::likePost(const QString &jsonParams) {
  QJsonParseError parseError;
  QJsonDocument doc = QJsonDocument::fromJson(jsonParams.toUtf8(), &parseError);
  if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
    emit likePostFinished(errorJson(parseError.errorString()));
    return;
  }

  post(Operation::LikePost, QStringLiteral("/api/alpha/post/like"), doc.object(),
       [this](QJsonObject response) { return normalizePostResponse(response); });
}

void PieFedClient::likeComment(int commentId, int score) {
  QJsonObject body;
  body[QStringLiteral("comment_id")] = commentId;
  body[QStringLiteral("score")] = score;
  post(Operation::LikeComment, QStringLiteral("/api/alpha/comment/like"), body,
       [this](QJsonObject response) {
         return normalizeCommentResponse(response);
       });
}

void PieFedClient::createComment(int postId, const QString &content,
                                 int parentId) {
  QJsonObject body;
  body[QStringLiteral("post_id")] = postId;
  body[QStringLiteral("body")] = content;
  if (parentId > 0)
    body[QStringLiteral("parent_id")] = parentId;
  post(Operation::CreateComment, QStringLiteral("/api/alpha/comment"), body,
       [this](QJsonObject response) {
         return normalizeCommentResponse(response);
       });
}

void PieFedClient::listCommunities(const QString &jsonParams) {
  get(Operation::ListCommunities, QStringLiteral("/api/alpha/community/list"),
      queryFromJson(jsonParams), [this](QJsonObject response) {
        return normalizeCommunities(response);
      });
}

void PieFedClient::getCommunity(const QString &jsonParams) {
  get(Operation::GetCommunity, QStringLiteral("/api/alpha/community"),
      queryFromJson(jsonParams), [this](QJsonObject response) {
        return normalizeCommunityResponse(response);
      });
}

void PieFedClient::getPerson(const QString &jsonParams) {
  get(Operation::GetPerson, QStringLiteral("/api/alpha/user"),
      queryFromJson(jsonParams),
      [this](QJsonObject response) { return normalizeUserResponse(response); });
}

void PieFedClient::search(const QString &jsonParams) {
  get(Operation::Search, QStringLiteral("/api/alpha/search"),
      queryFromJson(jsonParams),
      [this](QJsonObject response) { return normalizeSearch(response); });
}

void PieFedClient::followCommunity(const QString &jsonParams) {
  QJsonParseError parseError;
  QJsonDocument doc = QJsonDocument::fromJson(jsonParams.toUtf8(), &parseError);
  if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
    emit followCommunityFinished(errorJson(parseError.errorString()));
    return;
  }

  post(Operation::FollowCommunity, QStringLiteral("/api/alpha/community/follow"),
       doc.object(), [this](QJsonObject response) {
         return normalizeCommunityResponse(response);
       });
}

QUrl PieFedClient::endpoint(const QString &path) const {
  QUrl url = m_baseUrl;
  url.setPath(path);
  return url;
}

QNetworkRequest PieFedClient::request(const QString &path) const {
  QNetworkRequest req(endpoint(path));
  req.setHeader(QNetworkRequest::ContentTypeHeader,
                QStringLiteral("application/json"));
  req.setRawHeader("Accept", "application/json");
  if (!m_jwt.isEmpty())
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_jwt.toUtf8());
  return req;
}

void PieFedClient::get(Operation operation, const QString &path,
                       const QUrlQuery &query,
                       std::function<QJsonObject(QJsonObject)> normalize) {
  QNetworkRequest req = request(path);
  QUrl url = req.url();
  url.setQuery(query);
  req.setUrl(url);

  const int generation = m_generation;
  QNetworkReply *reply = m_network.get(req);
  m_replies.append(reply);
  connect(reply, &QNetworkReply::finished, this,
          [this, operation, reply, generation, normalize]() {
            m_replies.removeAll(reply);
            if (generation == m_generation)
              emitFinished(operation, finishJson(reply, normalize));
            reply->deleteLater();
          });
}

void PieFedClient::post(Operation operation, const QString &path,
                        const QJsonObject &body,
                        std::function<QJsonObject(QJsonObject)> normalize) {
  const int generation = m_generation;
  QNetworkReply *reply = m_network.post(
      request(path), QJsonDocument(body).toJson(QJsonDocument::Compact));
  m_replies.append(reply);
  connect(reply, &QNetworkReply::finished, this,
          [this, operation, reply, generation, normalize]() {
            m_replies.removeAll(reply);
            if (generation == m_generation)
              emitFinished(operation, finishJson(reply, normalize));
            reply->deleteLater();
          });
}

void PieFedClient::emitFinished(Operation operation, const QString &json) {
  switch (operation) {
  case Operation::Login:
    emit loginFinished(json);
    break;
  case Operation::GetSite:
    emit getSiteFinished(json);
    break;
  case Operation::ListPosts:
    emit listPostsFinished(json);
    break;
  case Operation::ListComments:
    emit listCommentsFinished(json);
    break;
  case Operation::GetPost:
    emit getPostFinished(json);
    break;
  case Operation::LikePost:
    emit likePostFinished(json);
    break;
  case Operation::LikeComment:
    emit likeCommentFinished(json);
    break;
  case Operation::CreateComment:
    emit createCommentFinished(json);
    break;
  case Operation::ListCommunities:
    emit listCommunitiesFinished(json);
    break;
  case Operation::GetCommunity:
    emit getCommunityFinished(json);
    break;
  case Operation::GetPerson:
    emit getPersonFinished(json);
    break;
  case Operation::Search:
    emit searchFinished(json);
    break;
  case Operation::FollowCommunity:
    emit followCommunityFinished(json);
    break;
  }
}

QUrlQuery PieFedClient::queryFromJson(const QString &jsonParams) const {
  QUrlQuery query;
  QJsonParseError parseError;
  QJsonDocument doc = QJsonDocument::fromJson(jsonParams.toUtf8(), &parseError);
  if (jsonParams.isEmpty() || parseError.error != QJsonParseError::NoError ||
      !doc.isObject())
    return query;

  const QJsonObject obj = doc.object();
  for (auto it = obj.constBegin(); it != obj.constEnd(); ++it) {
    if (it.value().isBool()) {
      query.addQueryItem(it.key(), it.value().toBool() ? QStringLiteral("true")
                                                       : QStringLiteral("false"));
    } else if (it.value().isDouble()) {
      query.addQueryItem(it.key(), QString::number(it.value().toDouble(), 'g', 15));
    } else if (it.value().isString()) {
      QString value = it.value().toString();
      if (it.key() == QStringLiteral("sort")) {
        if (value == QStringLiteral("Controversial"))
          value = QStringLiteral("Hot");
        else if (value == QStringLiteral("MostComments"))
          value = QStringLiteral("Active");
        else if (value == QStringLiteral("NewComments"))
          value = QStringLiteral("New");
      }
      query.addQueryItem(it.key(), value);
    }
  }

  // TODO(EVO-030): Align PieFed pagination and filter UI with Dee filters.
  //                Why: The probe now maps known unsupported Lemmy sort values,
  //                but it still ignores PieFed next_page metadata and the QML
  //                sort picker still offers values PieFed cannot represent
  //                exactly.
  //                Done: Pagination follows PieFed's response contract, PieFed
  //                sort choices are represented honestly in the UI, and Lemmy
  //                routing remains unchanged.
  //                Non-Goals: Do not redesign unrelated filters or add a
  //                generic filtering abstraction in this step.
  return query;
}

QJsonObject PieFedClient::normalizeSite(QJsonObject response) const {
  QJsonArray admins;
  for (const QJsonValue &value :
       response.value(QStringLiteral("admins")).toArray())
    admins.append(normalizePersonView(value.toObject()));
  response[QStringLiteral("admins")] = admins;

  if (response.contains(QStringLiteral("site")) &&
      !response.contains(QStringLiteral("site_view"))) {
    const QJsonObject site = response.value(QStringLiteral("site")).toObject();
    QJsonObject counts;
    if (site.contains(QStringLiteral("user_count")))
      counts[QStringLiteral("users")] = site.value(QStringLiteral("user_count"));
    QJsonObject siteView;
    siteView[QStringLiteral("site")] = site;
    siteView[QStringLiteral("counts")] = counts;
    response[QStringLiteral("site_view")] = siteView;
  }
  return response;
}

QJsonObject PieFedClient::normalizePosts(QJsonObject response) const {
  QJsonArray normalized;
  const QJsonArray posts = response.value(QStringLiteral("posts")).toArray();
  for (const QJsonValue &value : posts)
    normalized.append(normalizePostView(value.toObject()));
  response[QStringLiteral("posts")] = normalized;
  return response;
}

QJsonObject PieFedClient::normalizeComments(QJsonObject response) const {
  QJsonArray normalized;
  const QJsonArray comments =
      response.value(QStringLiteral("comments")).toArray();
  for (const QJsonValue &value : comments)
    normalized.append(normalizeCommentView(value.toObject()));
  response[QStringLiteral("comments")] = normalized;
  return response;
}

QJsonObject PieFedClient::normalizeCommunities(QJsonObject response) const {
  QJsonArray normalized;
  const QJsonArray communities =
      response.value(QStringLiteral("communities")).toArray();
  for (const QJsonValue &value : communities)
    normalized.append(normalizeCommunityView(value.toObject()));
  response[QStringLiteral("communities")] = normalized;
  return response;
}

QJsonObject PieFedClient::normalizeCommunityResponse(
    QJsonObject response) const {
  if (response.contains(QStringLiteral("community_view"))) {
    response[QStringLiteral("community_view")] = normalizeCommunityView(
        response.value(QStringLiteral("community_view")).toObject());
  }

  QJsonArray moderators;
  for (const QJsonValue &value :
       response.value(QStringLiteral("moderators")).toArray())
    moderators.append(normalizeCommunityModeratorView(value.toObject()));
  if (!moderators.isEmpty())
    response[QStringLiteral("moderators")] = moderators;
  return response;
}

QJsonObject PieFedClient::normalizeUserResponse(QJsonObject response) const {
  response = normalizePosts(response);
  response = normalizeComments(response);

  QJsonArray moderates;
  for (const QJsonValue &value :
       response.value(QStringLiteral("moderates")).toArray())
    moderates.append(normalizeCommunityModeratorView(value.toObject()));
  if (!moderates.isEmpty())
    response[QStringLiteral("moderates")] = moderates;

  if (response.contains(QStringLiteral("person_view"))) {
    response[QStringLiteral("person_view")] = normalizePersonView(
        response.value(QStringLiteral("person_view")).toObject());
  }
  return response;
}

QJsonObject PieFedClient::normalizeSearch(QJsonObject response) const {
  response = normalizePosts(response);
  response = normalizeComments(response);
  response = normalizeCommunities(response);

  QJsonArray users;
  for (const QJsonValue &value :
       response.value(QStringLiteral("users")).toArray())
    users.append(normalizePersonView(value.toObject()));
  response[QStringLiteral("users")] = users;
  return response;
}

QJsonObject PieFedClient::normalizePostResponse(QJsonObject response) const {
  if (response.contains(QStringLiteral("post_view"))) {
    response[QStringLiteral("post_view")] = normalizePostView(
        response.value(QStringLiteral("post_view")).toObject());
  }
  return response;
}

QJsonObject PieFedClient::normalizeCommentResponse(QJsonObject response) const {
  if (response.contains(QStringLiteral("comment_view"))) {
    response[QStringLiteral("comment_view")] = normalizeCommentView(
        response.value(QStringLiteral("comment_view")).toObject());
  }
  return response;
}

QJsonObject PieFedClient::normalizePostView(QJsonObject view) const {
  QJsonObject post = view.value(QStringLiteral("post")).toObject();
  if (post.contains(QStringLiteral("title")) &&
      !post.contains(QStringLiteral("name"))) {
    post[QStringLiteral("name")] = post.value(QStringLiteral("title"));
  }
  if (post.contains(QStringLiteral("user_id")) &&
      !post.contains(QStringLiteral("creator_id"))) {
    post[QStringLiteral("creator_id")] = post.value(QStringLiteral("user_id"));
  }
  if (post.contains(QStringLiteral("sticky"))) {
    post[QStringLiteral("featured_community")] =
        post.value(QStringLiteral("sticky"));
  }
  if (post.contains(QStringLiteral("instance_sticky"))) {
    post[QStringLiteral("featured_local")] =
        post.value(QStringLiteral("instance_sticky"));
  }
  view[QStringLiteral("post")] = post;

  if (view.contains(QStringLiteral("creator"))) {
    QJsonObject personView;
    personView[QStringLiteral("person")] = view.value(QStringLiteral("creator"));
    view[QStringLiteral("creator")] =
        normalizePersonView(personView).value(QStringLiteral("person"));
  }
  if (view.contains(QStringLiteral("community"))) {
    QJsonObject communityView;
    communityView[QStringLiteral("community")] =
        view.value(QStringLiteral("community"));
    view[QStringLiteral("community")] =
        normalizeCommunityView(communityView).value(QStringLiteral("community"));
  }

  // TODO(EVO-040): Complete PieFed-to-Lemmy response normalization.
  //                Why: PieFed operations now consistently pass through this
  //                client, but only the fields QML uses today have audited
  //                normalization.
  //                Done: Every PieFed operation implemented in LemmyAPI returns
  //                the same top-level keys and nested field names that existing
  //                QML expects, with focused smoke coverage for representative
  //                responses.
  //                Non-Goals: Do not add a parallel PieFed model layer or change
  //                QML to branch on server software in this step.
  return view;
}

QJsonObject PieFedClient::normalizeCommentView(QJsonObject view) const {
  view = normalizePostView(view);

  QJsonObject comment = view.value(QStringLiteral("comment")).toObject();
  if (comment.contains(QStringLiteral("body")) &&
      !comment.contains(QStringLiteral("content"))) {
    comment[QStringLiteral("content")] = comment.value(QStringLiteral("body"));
  }
  if (comment.contains(QStringLiteral("user_id")) &&
      !comment.contains(QStringLiteral("creator_id"))) {
    comment[QStringLiteral("creator_id")] =
        comment.value(QStringLiteral("user_id"));
  }
  view[QStringLiteral("comment")] = comment;
  return view;
}

QJsonObject PieFedClient::normalizeCommunityView(QJsonObject view) const {
  QJsonObject counts = view.value(QStringLiteral("counts")).toObject();
  if (counts.contains(QStringLiteral("subscriptions_count")) &&
      !counts.contains(QStringLiteral("subscribers"))) {
    counts[QStringLiteral("subscribers")] =
        counts.value(QStringLiteral("subscriptions_count"));
  }
  if (counts.contains(QStringLiteral("post_count")) &&
      !counts.contains(QStringLiteral("posts"))) {
    counts[QStringLiteral("posts")] = counts.value(QStringLiteral("post_count"));
  }
  if (counts.contains(QStringLiteral("post_reply_count")) &&
      !counts.contains(QStringLiteral("comments"))) {
    counts[QStringLiteral("comments")] =
        counts.value(QStringLiteral("post_reply_count"));
  }
  if (counts.contains(QStringLiteral("active_daily")) &&
      !counts.contains(QStringLiteral("users_active_day"))) {
    counts[QStringLiteral("users_active_day")] =
        counts.value(QStringLiteral("active_daily"));
  }
  if (counts.contains(QStringLiteral("active_weekly")) &&
      !counts.contains(QStringLiteral("users_active_week"))) {
    counts[QStringLiteral("users_active_week")] =
        counts.value(QStringLiteral("active_weekly"));
  }
  if (counts.contains(QStringLiteral("active_monthly")) &&
      !counts.contains(QStringLiteral("users_active_month"))) {
    counts[QStringLiteral("users_active_month")] =
        counts.value(QStringLiteral("active_monthly"));
  }
  if (counts.contains(QStringLiteral("active_6monthly")) &&
      !counts.contains(QStringLiteral("users_active_half_year"))) {
    counts[QStringLiteral("users_active_half_year")] =
        counts.value(QStringLiteral("active_6monthly"));
  }
  view[QStringLiteral("counts")] = counts;
  return view;
}

QJsonObject PieFedClient::normalizeCommunityModeratorView(
    QJsonObject view) const {
  if (view.contains(QStringLiteral("community"))) {
    QJsonObject communityView;
    communityView[QStringLiteral("community")] =
        view.value(QStringLiteral("community"));
    view[QStringLiteral("community")] =
        normalizeCommunityView(communityView).value(QStringLiteral("community"));
  }
  if (view.contains(QStringLiteral("moderator"))) {
    QJsonObject personView;
    personView[QStringLiteral("person")] =
        view.value(QStringLiteral("moderator"));
    view[QStringLiteral("moderator")] =
        normalizePersonView(personView).value(QStringLiteral("person"));
  }
  return view;
}

QJsonObject PieFedClient::normalizePersonView(QJsonObject view) const {
  QJsonObject person = view.value(QStringLiteral("person")).toObject();
  if (person.contains(QStringLiteral("user_name")) &&
      !person.contains(QStringLiteral("name"))) {
    person[QStringLiteral("name")] = person.value(QStringLiteral("user_name"));
  }
  view[QStringLiteral("person")] = person;
  return view;
}

static QString compactJson(const QJsonObject &obj) {
  return QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

static QString errorJson(const QString &message) {
  QJsonObject obj;
  obj[QStringLiteral("error")] = message;
  return compactJson(obj);
}

static QString finishJson(QNetworkReply *reply,
                          std::function<QJsonObject(QJsonObject)> normalize) {
  const QByteArray data = reply->readAll();
  const int status =
      reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
  QJsonParseError parseError;
  QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
  const QJsonObject obj = doc.isObject() ? doc.object() : QJsonObject();

  if (reply->error() != QNetworkReply::NoError || status >= 400)
    return errorJson(responseErrorText(reply, obj));
  if (parseError.error != QJsonParseError::NoError || !doc.isObject())
    return errorJson(parseError.errorString());
  return compactJson(normalize ? normalize(obj) : obj);
}

static QString responseErrorText(QNetworkReply *reply, const QJsonObject &obj) {
  const QString message = obj.value(QStringLiteral("message")).toString();
  if (!message.isEmpty())
    return message;
  const QString status = obj.value(QStringLiteral("status")).toString();
  if (!status.isEmpty())
    return status;
  if (reply->error() != QNetworkReply::NoError)
    return reply->errorString();
  return QStringLiteral("HTTP %1")
      .arg(reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt());
}
