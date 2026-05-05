#ifndef LEMMYAPI_H
#define LEMMYAPI_H

#include "postsmodel.h"
#include "securestorage.h"
#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QSettings>
#include <QString>
#include <QThread>

// Forward-declare the opaque Rust handle
extern "C" {
struct LemmyClientHandle;
}

// ---------------------------------------------------------------------------
// LemmyWorker – runs blocking Rust FFI calls on a dedicated thread
// ---------------------------------------------------------------------------

class LemmyWorker : public QObject {
  Q_OBJECT

public:
  explicit LemmyWorker(QObject *parent = nullptr);
  ~LemmyWorker();

public slots:
  void createClient(const QString &domain, bool secure);
  void destroyClient();
  void setJwt(const QString &jwt);

  void doLogin(const QString &username, const QString &password,
               const QString &totp);
  void doLogout();
  void doGetSite();
  void doListPosts(const QString &jsonParams);
  void doGetPost(const QString &jsonParams);
  void doLikePost(const QString &jsonParams);
  void doListComments(const QString &jsonParams);
  void doLikeComment(const QString &jsonParams);
  void doCreateComment(const QString &jsonParams);
  void doListCommunities(const QString &jsonParams);
  void doGetCommunity(const QString &jsonParams);
  void doGetPerson(const QString &jsonParams);
  void doSearch(const QString &jsonParams);
  void doFollowCommunity(const QString &jsonParams);

signals:
  void loginFinished(const QString &json);
  void logoutFinished(const QString &json);
  void getSiteFinished(const QString &json);
  void listPostsFinished(const QString &json);
  void getPostFinished(const QString &json);
  void likePostFinished(const QString &json);
  void listCommentsFinished(const QString &json);
  void likeCommentFinished(const QString &json);
  void createCommentFinished(const QString &json);
  void listCommunitiesFinished(const QString &json);
  void getCommunityFinished(const QString &json);
  void getPersonFinished(const QString &json);
  void searchFinished(const QString &json);
  void followCommunityFinished(const QString &json);

private:
  LemmyClientHandle *m_handle;
};

// ---------------------------------------------------------------------------
// LemmyAPI – QML-facing API object
// ---------------------------------------------------------------------------

class LemmyAPI : public QObject {
  Q_OBJECT

  Q_PROPERTY(QString instanceUrl READ instanceUrl NOTIFY instanceUrlChanged)
  Q_PROPERTY(QString username READ username NOTIFY usernameChanged)
  Q_PROPERTY(bool loggedIn READ loggedIn NOTIFY loggedInChanged)
  Q_PROPERTY(QString error READ error WRITE setError NOTIFY errorChanged)
  Q_PROPERTY(bool busy READ busy WRITE setBusy NOTIFY busyChanged)
  Q_PROPERTY(QString currentSort READ currentSort WRITE setCurrentSort NOTIFY
                 currentSortChanged)
  Q_PROPERTY(QString commentSort READ commentSort WRITE setCommentSort NOTIFY
                 commentSortChanged)
  Q_PROPERTY(PostsModel *posts READ posts NOTIFY postsChanged)
  Q_PROPERTY(QJsonArray communities READ communities NOTIFY communitiesChanged)
  Q_PROPERTY(QVariantList comments READ comments NOTIFY commentsChanged)
  Q_PROPERTY(QJsonObject siteInfo READ siteInfo NOTIFY siteInfoChanged)

public:
  explicit LemmyAPI(QObject *parent = nullptr);
  ~LemmyAPI();

  // Property getters
  QString instanceUrl() const { return m_instanceUrl; }
  QString username() const { return m_username; }
  bool loggedIn() const { return m_loggedIn; }
  QString error() const { return m_error; }
  bool busy() const { return m_busy; }
  PostsModel *posts() const { return m_posts; }
  QJsonArray communities() const { return m_communities; }
  QVariantList comments() const { return m_comments; }
  QJsonObject siteInfo() const { return m_siteInfo; }
  int postsPage() const { return m_postsPage; }
  int communitiesPage() const { return m_communitiesPage; }
  QString currentSort() const { return m_currentSort; }
  QString commentSort() const { return m_commentSort; }

  // Property setters
  void setInstanceUrl(const QString &url);
  void setUsername(const QString &username);
  void setPostsPage(int page);
  void setCommunitiesPage(int page);
  void setCurrentSort(const QString &sort);
  void setCommentSort(const QString &sort);

  // Invokable from QML
  Q_INVOKABLE void login(const QString instanceUrl, const QString username,
                         const QString password,
                         const QString totp = QString());
  Q_INVOKABLE void logout();
  Q_INVOKABLE void clearError();
  Q_INVOKABLE void setPostsModel(PostsModel *model);

  Q_INVOKABLE void getSite();
  Q_INVOKABLE void listPosts(const QString &jsonParams = QString());
  Q_INVOKABLE void loadMorePosts();
  Q_INVOKABLE void getPost(int postId);
  Q_INVOKABLE void likePost(int postId, int score);
  Q_INVOKABLE void listComments(const QString &jsonParams = QString());
  Q_INVOKABLE void likeComment(int commentId, int score);
  Q_INVOKABLE void createComment(int postId, const QString &content,
                                 int parentId = 0);
  Q_INVOKABLE void loadMoreComments();
  Q_INVOKABLE void listCommunities(const QString &jsonParams = QString());
  Q_INVOKABLE void loadMoreCommunities();
  Q_INVOKABLE void getCommunity(const QString &jsonParams);
  Q_INVOKABLE void getPerson(const QString &jsonParams = QString());
  Q_INVOKABLE void search(const QString &jsonParams);
  Q_INVOKABLE void followCommunity(const QString &jsonParams);

signals:
  void instanceUrlChanged();
  void usernameChanged();
  void loggedInChanged();
  void errorChanged();
  void busyChanged();
  void postsChanged();
  void communitiesChanged();
  void commentsChanged();
  void siteInfoChanged();
  void commentsPageChanged();

  void loginSuccess();
  void loginFailed(const QString &message);
  void requestFinished(const QString &method, const QJsonObject &result);
  void requestFailed(const QString &method, const QString &message);
  void postsPageChanged();
  void currentSortChanged();
  void commentSortChanged();

private slots:
  void onLoginFinished(const QString &json);
  void onLogoutFinished(const QString &json);
  void onGetSiteFinished(const QString &json);
  void onListPostsFinished(const QString &json);
  void onGetPostFinished(const QString &json);
  void onLikePostFinished(const QString &json);
  void onListCommentsFinished(const QString &json);
  void onLikeCommentFinished(const QString &json);
  void onListCommunitiesFinished(const QString &json);
  void onGetCommunityFinished(const QString &json);
  void onGetPersonFinished(const QString &json);
  void onSearchFinished(const QString &json);
  void onFollowCommunityFinished(const QString &json);
  void onCreateCommentFinished(const QString &json);

private:
  void setBusy(bool busy);
  void setLoggedIn(bool loggedIn);
  void setError(const QString &error);
  void ensureClient();
  QJsonObject parseJson(const QString &json);
  void appendCommunities(const QJsonArray &newCommunities);
  void buildCommentTree(const QJsonArray &comments);

  // Persisted state
  QSettings *m_settings;
  QString m_instanceUrl;
  QString m_username;
  QString m_jwt;
  bool m_loggedIn;
  QString m_error;
  bool m_busy;
  QString m_currentSort;
  QString m_commentSort;

  // Data caches
  PostsModel *m_posts;
  QJsonArray m_communities;
  QVariantList m_comments;
  QJsonObject m_siteInfo;
  QJsonArray m_allCommentItems; // Accumulates raw comment data for pagination
  int m_postsPage;
  bool m_loadingMore;
  QJsonObject m_postsFilter;
  int m_communitiesPage;
  bool m_loadingMoreCommunities;
  QJsonObject m_communitiesFilter;
  int m_commentsPage;
  bool m_loadingMoreComments;
  QJsonObject m_commentsFilter;

  QThread m_workerThread;
  LemmyWorker *m_worker;
  SecureStorage *m_secureStorage;
};

#endif // LEMMYAPI_H
