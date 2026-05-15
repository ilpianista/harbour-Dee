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
      [this](QJsonObject response) {
        if (response.contains(QStringLiteral("post_view"))) {
          response[QStringLiteral("post_view")] = normalizePostView(
              response.value(QStringLiteral("post_view")).toObject());
        }
        return response;
      });
}

void PieFedClient::likePost(const QString &jsonParams) {
  QJsonParseError parseError;
  QJsonDocument doc = QJsonDocument::fromJson(jsonParams.toUtf8(), &parseError);
  if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
    emit likePostFinished(errorJson(parseError.errorString()));
    return;
  }

  post(Operation::LikePost, QStringLiteral("/api/alpha/post/like"), doc.object(),
       [this](QJsonObject response) {
         if (response.contains(QStringLiteral("post_view"))) {
           response[QStringLiteral("post_view")] = normalizePostView(
               response.value(QStringLiteral("post_view")).toObject());
         }
         return response;
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

  QJsonObject creator = view.value(QStringLiteral("creator")).toObject();
  if (creator.contains(QStringLiteral("user_name")) &&
      !creator.contains(QStringLiteral("name"))) {
    creator[QStringLiteral("name")] = creator.value(QStringLiteral("user_name"));
  }
  view[QStringLiteral("creator")] = creator;

  // TODO(EVO-040): Complete PieFed-to-Lemmy response normalization.
  //                Why: listPosts, likePost, and comments expose only the fields
  //                QML uses today; post details, communities, site data, and
  //                moderation flags still need audited shape-by-shape mapping.
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
  view[QStringLiteral("comment")] = comment;
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
