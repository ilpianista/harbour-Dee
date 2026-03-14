#ifdef QT_QML_DEBUG
#include <QtQuick>
#endif

#include "lemmyapi.h"
#include <QQmlEngine>
#include <sailfishapp.h>

int main(int argc, char *argv[]) {
  QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
  QScopedPointer<QQuickView> view(SailfishApp::createView());

  QCoreApplication::setApplicationName(QStringLiteral("harbour-dee"));
  QCoreApplication::setOrganizationName(QStringLiteral("scarpino.dev"));

  // Register LemmyAPI type with QML
  qmlRegisterType<LemmyAPI>("harbour.dee", 1, 0, "LemmyAPI");

  view->setSource(SailfishApp::pathTo("qml/Dee.qml"));
  view->show();

  return app->exec();
}
