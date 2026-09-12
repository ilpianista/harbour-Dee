#ifndef APPSETTINGS_H
#define APPSETTINGS_H

#include <QObject>
#include <QSettings>

// ---------------------------------------------------------------------------
// AppSettings – persisted, purely-local UI/display preferences.
//
// Kept separate from LemmyAPI, which owns network/session state and request
// parameters (e.g. currentSort/commentSort, which are sent to the server).
// Properties here never affect a request; they only affect how already-
// fetched data is displayed.
// ---------------------------------------------------------------------------

class AppSettings : public QObject {
  Q_OBJECT

  Q_PROPERTY(bool fullSizeMediaEnabled READ fullSizeMediaEnabled WRITE
                 setFullSizeMediaEnabled NOTIFY fullSizeMediaEnabledChanged)

public:
  explicit AppSettings(QObject *parent = nullptr);

  bool fullSizeMediaEnabled() const { return m_fullSizeMediaEnabled; }
  void setFullSizeMediaEnabled(bool enabled);

signals:
  void fullSizeMediaEnabledChanged();

private:
  QSettings *m_settings;
  bool m_fullSizeMediaEnabled;
};

#endif // APPSETTINGS_H
