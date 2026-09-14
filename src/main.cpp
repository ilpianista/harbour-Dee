
#include "appsettings.h"
#include "lemmyapi.h"
#include <QQmlEngine>
#include <QtQuick>
#include <sailfishapp.h>

int main(int argc, char *argv[]) {
  QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
  QScopedPointer<QQuickView> view(SailfishApp::createView());

  QCoreApplication::setApplicationName(QStringLiteral("harbour-dee"));
  QCoreApplication::setOrganizationName(QStringLiteral("dev.scarpino"));

  qmlRegisterType<LemmyAPI>("harbour.dee", 1, 0, "LemmyAPI");
  qmlRegisterType<PostsModel>("harbour.dee", 1, 0, "PostsModel");
  qmlRegisterSingletonType<AppSettings>(
      "harbour.dee", 1, 0, "AppSettings",
      [](QQmlEngine *, QJSEngine *) -> QObject * { return new AppSettings(); });

  view->setSource(SailfishApp::pathTo("qml/Dee.qml"));
  view->show();

  return app->exec();
}
