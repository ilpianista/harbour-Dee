#include "appsettings.h"

#include <QCoreApplication>
#include <QDir>
#include <QStandardPaths>

namespace {
// Listing types accepted by lemmy_list_posts' `type_` parameter.
bool isValidListingType(const QString &type) {
  return type == QLatin1String("Subscribed") ||
         type == QLatin1String("Local") || type == QLatin1String("All");
}
} // namespace

AppSettings::AppSettings(QObject *parent)
    : QObject(parent), m_fullSizeMediaEnabled(false), m_blurNsfwEnabled(true),
      m_defaultListingType(QStringLiteral("Subscribed")) {
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
  m_defaultListingType = m_settings
                             ->value(QStringLiteral("feed/defaultListingType"),
                                     QStringLiteral("Subscribed"))
                             .toString();
  if (!isValidListingType(m_defaultListingType))
    m_defaultListingType = QStringLiteral("Subscribed");
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

void AppSettings::setDefaultListingType(const QString &type) {
  if (!isValidListingType(type) || m_defaultListingType == type)
    return;
  m_defaultListingType = type;
  m_settings->setValue(QStringLiteral("feed/defaultListingType"), type);
  emit defaultListingTypeChanged();
}
