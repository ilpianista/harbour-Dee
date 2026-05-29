#include "securestorage.h"
#include <QCoreApplication>
#include <QDebug>
#include <QEventLoop>
#include <QSettings>

using namespace Sailfish::Secrets;

SecureStorage::SecureStorage(QObject *parent)
    : QObject(parent), m_collectionName(QStringLiteral("Dee")),
      m_initialized(false), m_cacheLoaded(false) {}

void SecureStorage::initialize() { ensureCollection(); }

void SecureStorage::ensureCollection() {
  CreateCollectionRequest *request = new CreateCollectionRequest(this);
  request->setManager(&m_secretManager);
  request->setCollectionName(m_collectionName);
  request->setAccessControlMode(SecretManager::OwnerOnlyMode);
  request->setCollectionLockType(CreateCollectionRequest::DeviceLock);
  request->setDeviceLockUnlockSemantic(SecretManager::DeviceLockKeepUnlocked);
  request->setStoragePluginName(
      SecretManager::DefaultEncryptedStoragePluginName);
  request->setEncryptionPluginName(
      SecretManager::DefaultEncryptedStoragePluginName);

  connect(request, &CreateCollectionRequest::statusChanged, this,
          [this, request]() {
            if (request->status() == Request::Finished) {
              if (request->result().code() == Result::Succeeded ||
                  request->result().errorCode() ==
                      Result::CollectionAlreadyExistsError) {
                m_initialized = true;
                // Load cached credentials
                m_cachedAccessToken = getSecret(QStringLiteral("accessToken"));
                m_cacheLoaded = true;
                emit initialized();
              } else {
                qWarning() << "Failed to create secrets collection:"
                           << request->result().errorMessage();
                emit error(request->result().errorMessage());
              }
              request->deleteLater();
            }
          });

  request->startRequest();
}

void SecureStorage::storeSecret(const QString &name, const QString &value) {
  // First delete any existing secret with this name (to allow updates)
  DeleteSecretRequest deleteRequest;
  deleteRequest.setManager(&m_secretManager);
  deleteRequest.setIdentifier(
      Secret::Identifier(name, m_collectionName,
                         SecretManager::DefaultEncryptedStoragePluginName));
  deleteRequest.setUserInteractionMode(SecretManager::SystemInteraction);

  QEventLoop deleteLoop;
  connect(&deleteRequest, &DeleteSecretRequest::statusChanged, &deleteLoop,
          [&deleteLoop, &deleteRequest]() {
            if (deleteRequest.status() == Request::Finished)
              deleteLoop.quit();
          });
  deleteRequest.startRequest();
  if (deleteRequest.status() != Request::Finished)
    deleteLoop.exec();

  // Now store the new secret. This is deliberately synchronous so callers that
  // navigate to another QML page can immediately construct a new LemmyAPI and
  // read the token from secure storage.
  Secret secret(Secret::Identifier(
      name, m_collectionName, SecretManager::DefaultEncryptedStoragePluginName));
  secret.setData(value.toUtf8());
  secret.setType(Secret::TypeBlob);

  StoreSecretRequest storeRequest;
  storeRequest.setManager(&m_secretManager);
  storeRequest.setSecretStorageType(StoreSecretRequest::CollectionSecret);
  storeRequest.setUserInteractionMode(SecretManager::SystemInteraction);
  storeRequest.setSecret(secret);

  QEventLoop storeLoop;
  connect(&storeRequest, &StoreSecretRequest::statusChanged, &storeLoop,
          [&storeLoop, &storeRequest]() {
            if (storeRequest.status() == Request::Finished)
              storeLoop.quit();
          });
  storeRequest.startRequest();
  if (storeRequest.status() != Request::Finished)
    storeLoop.exec();

  if (storeRequest.result().code() != Result::Succeeded) {
    qWarning() << "Failed to store secret" << name << ":"
               << storeRequest.result().errorMessage();
  }
}

QString SecureStorage::getSecret(const QString &name) const {
  StoredSecretRequest request;
  request.setManager(const_cast<SecretManager *>(&m_secretManager));
  request.setIdentifier(
      Secret::Identifier(name, m_collectionName,
                         SecretManager::DefaultEncryptedStoragePluginName));
  request.setUserInteractionMode(SecretManager::SystemInteraction);

  // Use event loop for synchronous retrieval
  QEventLoop loop;
  QObject::connect(&request, &StoredSecretRequest::statusChanged, &loop,
                   [&loop, &request]() {
                     if (request.status() == Request::Finished) {
                       loop.quit();
                     }
                   });

  request.startRequest();

  if (request.status() != Request::Finished) {
    loop.exec();
  }

  if (request.result().code() == Result::Succeeded) {
    return QString::fromUtf8(request.secret().data());
  }

  return QString();
}

void SecureStorage::deleteSecret(const QString &name) {
  DeleteSecretRequest request;
  request.setManager(&m_secretManager);
  request.setIdentifier(
      Secret::Identifier(name, m_collectionName,
                         SecretManager::DefaultEncryptedStoragePluginName));
  request.setUserInteractionMode(SecretManager::SystemInteraction);

  QEventLoop loop;
  connect(&request, &DeleteSecretRequest::statusChanged, &loop,
          [&loop, &request]() {
            if (request.status() == Request::Finished)
              loop.quit();
          });
  request.startRequest();
  if (request.status() != Request::Finished)
    loop.exec();
}

void SecureStorage::saveAccessToken(const QString &token) {
  m_cachedAccessToken = token;
  storeSecret(QStringLiteral("accessToken"), token);
}

QString SecureStorage::loadAccessToken() const {
  if (m_cacheLoaded) {
    return m_cachedAccessToken;
  }
  return getSecret(QStringLiteral("accessToken"));
}

void SecureStorage::clearAll() {
  m_cachedAccessToken.clear();

  // Delete secrets
  deleteSecret(QStringLiteral("accessToken"));
}
