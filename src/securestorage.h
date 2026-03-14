#ifndef SECURESTORAGE_H
#define SECURESTORAGE_H

#include <QObject>
#include <QString>
#include <Sailfish/Secrets/createcollectionrequest.h>
#include <Sailfish/Secrets/deletesecretrequest.h>
#include <Sailfish/Secrets/result.h>
#include <Sailfish/Secrets/secret.h>
#include <Sailfish/Secrets/secretmanager.h>
#include <Sailfish/Secrets/storedsecretrequest.h>
#include <Sailfish/Secrets/storesecretrequest.h>

class SecureStorage : public QObject {
  Q_OBJECT

public:
  explicit SecureStorage(QObject *parent = nullptr);

  Q_INVOKABLE void saveAccessToken(const QString &token);
  Q_INVOKABLE QString loadAccessToken() const;

  Q_INVOKABLE void clearAll();

  Q_INVOKABLE void initialize();

signals:
  void initialized();
  void error(const QString &message);

private:
  void ensureCollection();
  void storeSecret(const QString &name, const QString &value);
  QString getSecret(const QString &name) const;
  void deleteSecret(const QString &name);

  Sailfish::Secrets::SecretManager m_secretManager;
  QString m_collectionName;
  bool m_initialized;

  // Cache for synchronous access (loaded at init)
  mutable QString m_cachedAccessToken;
  mutable bool m_cacheLoaded;
};

#endif
