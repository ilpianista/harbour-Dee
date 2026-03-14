import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    CoverPlaceholder {
        text: "Dee"
        icon.source: "/usr/share/icons/hicolor/86x86/apps/harbour-dee.png"
        visible: !appWindow.postTitle || appWindow.postTitle.length === 0
    }

    Column {
        anchors.centerIn: parent
        x: Theme.paddingSmall
        width: parent.width - Theme.paddingSmall * 2
        visible: appWindow.postTitle && appWindow.postTitle.length > 0

        Label {
            width: parent.width
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeMedium
            text: appWindow.postTitle
        }

    }

}
