#include "appsettings.h"

#include <QCoreApplication>
#include <QDir>
#include <QStandardPaths>

AppSettings::AppSettings(QObject *parent)
    : QObject(parent), m_fullSizeMediaEnabled(false),
      m_blurNsfwEnabled(true) {
  // Shares the same config file as LemmyAPI (same path formula), so this is
  // just another set of keys in the app's one settings file, not a second
  // settings file.
  const QString settingsPath =
      QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) +
      QDir::separator() + QCoreApplication::applicationName() + ".conf";
  m_settings = new QSettings(settingsPath, QSettings::NativeFormat, this);

  m_fullSizeMediaEnabled =
      m_settings->value(QStringLiteral("feed/fullSizeMedia"), false).toBool();
  m_blurNsfwEnabled =
      m_settings->value(QStringLiteral("feed/blurNsfw"), true).toBool();
}

void AppSettings::setFullSizeMediaEnabled(bool enabled) {
  if (m_fullSizeMediaEnabled == enabled)
    return;
  m_fullSizeMediaEnabled = enabled;
  m_settings->setValue(QStringLiteral("feed/fullSizeMedia"), enabled);
  emit fullSizeMediaEnabledChanged();
}

void AppSettings::setBlurNsfwEnabled(bool enabled) {
  if (m_blurNsfwEnabled == enabled)
    return;
  m_blurNsfwEnabled = enabled;
  m_settings->setValue(QStringLiteral("feed/blurNsfw"), enabled);
  emit blurNsfwEnabledChanged();
}
