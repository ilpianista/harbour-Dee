#ifndef PIEFEDCLIENT_H
#define PIEFEDCLIENT_H

#include <QJsonObject>
#include <QList>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QObject>
#include <QString>
#include <QUrl>
#include <functional>

class QNetworkReply;
class QUrlQuery;

// PieFedClient keeps the PieFed HTTP dialect behind the existing LemmyAPI
// boundary so QML continues to consume Lemmy-shaped JSON during the probe.
class PieFedClient : public QObject {
  Q_OBJECT

public:
  explicit PieFedClient(QObject *parent = nullptr);

  void setInstanceUrl(const QString &instanceUrl);
  void setJwt(const QString &jwt);
  void cancelPendingRequests();

  void login(const QString &username, const QString &password);
  void listPosts(const QString &jsonParams);
  void listComments(const QString &jsonParams);
  void getPost(int postId);
  void likePost(const QString &jsonParams);

signals:
  void loginFinished(const QString &json);
  void listPostsFinished(const QString &json);
  void listCommentsFinished(const QString &json);
  void getPostFinished(const QString &json);
  void likePostFinished(const QString &json);

private:
  enum class Operation { Login, ListPosts, ListComments, GetPost, LikePost };

  QUrl endpoint(const QString &path) const;
  QNetworkRequest request(const QString &path) const;
  void get(Operation operation, const QString &path, const QUrlQuery &query,
           std::function<QJsonObject(QJsonObject)> normalize);
  void post(Operation operation, const QString &path, const QJsonObject &body,
            std::function<QJsonObject(QJsonObject)> normalize);
  void emitFinished(Operation operation, const QString &json);
  QUrlQuery queryFromJson(const QString &jsonParams) const;
  QJsonObject normalizePosts(QJsonObject response) const;
  QJsonObject normalizeComments(QJsonObject response) const;
  QJsonObject normalizePostView(QJsonObject view) const;
  QJsonObject normalizeCommentView(QJsonObject view) const;

  QNetworkAccessManager m_network;
  QUrl m_baseUrl;
  QString m_jwt;
  QList<QNetworkReply *> m_replies;
  int m_generation;
};

#endif // PIEFEDCLIENT_H
