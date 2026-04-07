
#include "lemmyapi.h"
#include <QQmlEngine>
#include <QtQuick>
#include <sailfishapp.h>

int main(int argc, char *argv[]) {
  QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
  QScopedPointer<QQuickView> view(SailfishApp::createView());

  QCoreApplication::setApplicationName(QStringLiteral("harbour-dee"));
  QCoreApplication::setOrganizationName(QStringLiteral("scarpino.dev"));

  qmlRegisterType<LemmyAPI>("harbour.dee", 1, 0, "LemmyAPI");
  qmlRegisterType<PostsModel>("harbour.dee", 1, 0, "PostsModel");

  view->setSource(SailfishApp::pathTo("qml/Dee.qml"));
  view->show();

  return app->exec();
}
