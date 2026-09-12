import QtQuick 2.0
import Sailfish.Silica 1.0

Rectangle {
    color: Theme.rgba(Theme.overlayBackgroundColor, 0.92)

    Label {
        anchors.centerIn: parent
        text: qsTr("NSFW")
        font.pixelSize: Theme.fontSizeExtraSmall
        color: Theme.primaryColor
    }
}
