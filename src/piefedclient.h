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
  void getSite();
  void listPosts(const QString &jsonParams);
  void listComments(const QString &jsonParams);
  void getPost(int postId);
  void likePost(const QString &jsonParams);
  void likeComment(int commentId, int score);
  void createComment(int postId, const QString &content, int parentId);
  void listCommunities(const QString &jsonParams);
  void getCommunity(const QString &jsonParams);
  void getPerson(const QString &jsonParams);
  void search(const QString &jsonParams);
  void followCommunity(const QString &jsonParams);

signals:
  void loginFinished(const QString &json);
  void getSiteFinished(const QString &json);
  void listPostsFinished(const QString &json);
  void listCommentsFinished(const QString &json);
  void getPostFinished(const QString &json);
  void likePostFinished(const QString &json);
  void likeCommentFinished(const QString &json);
  void createCommentFinished(const QString &json);
  void listCommunitiesFinished(const QString &json);
  void getCommunityFinished(const QString &json);
  void getPersonFinished(const QString &json);
  void searchFinished(const QString &json);
  void followCommunityFinished(const QString &json);

private:
  enum class Operation {
    Login,
    GetSite,
    ListPosts,
    ListComments,
    GetPost,
    LikePost,
    LikeComment,
    CreateComment,
    ListCommunities,
    GetCommunity,
    GetPerson,
    Search,
    FollowCommunity
  };

  QUrl endpoint(const QString &path) const;
  QNetworkRequest request(const QString &path) const;
  void get(Operation operation, const QString &path, const QUrlQuery &query,
           std::function<QJsonObject(QJsonObject)> normalize);
  void post(Operation operation, const QString &path, const QJsonObject &body,
            std::function<QJsonObject(QJsonObject)> normalize);
  void emitFinished(Operation operation, const QString &json);
  QUrlQuery queryFromJson(const QString &jsonParams) const;
  QJsonObject normalizeSite(QJsonObject response) const;
  QJsonObject normalizePosts(QJsonObject response) const;
  QJsonObject normalizeComments(QJsonObject response) const;
  QJsonObject normalizeCommunities(QJsonObject response) const;
  QJsonObject normalizeCommunityResponse(QJsonObject response) const;
  QJsonObject normalizeUserResponse(QJsonObject response) const;
  QJsonObject normalizeSearch(QJsonObject response) const;
  QJsonObject normalizePostResponse(QJsonObject response) const;
  QJsonObject normalizeCommentResponse(QJsonObject response) const;
  QJsonObject normalizePostView(QJsonObject view) const;
  QJsonObject normalizeCommentView(QJsonObject view) const;
  QJsonObject normalizeCommunityView(QJsonObject view) const;
  QJsonObject normalizeCommunityModeratorView(QJsonObject view) const;
  QJsonObject normalizePersonView(QJsonObject view) const;

  QNetworkAccessManager m_network;
  QUrl m_baseUrl;
  QString m_jwt;
  QList<QNetworkReply *> m_replies;
  int m_generation;
};

#endif // PIEFEDCLIENT_H
