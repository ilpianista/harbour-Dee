import QtQuick 2.0
import Sailfish.Silica 1.0

Image {
    id: thumbnail

    property url imageUrl
    property bool enabled: true

    width: Theme.iconSizeLarge
    height: Theme.iconSizeLarge
    source: imageUrl
    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    smooth: true
    cache: true

    onStatusChanged: {
        if (status === Image.Error)
            console.warn("Failed to load thumbnail:", imageUrl);
    }

    MouseArea {
        anchors.fill: parent
        enabled: thumbnail.enabled && imageUrl
        onClicked: thumbnail.clicked()
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: thumbnail.status === Image.Loading
        visible: thumbnail.status === Image.Loading
        size: BusyIndicatorSize.Small
    }

    signal clicked()
}
