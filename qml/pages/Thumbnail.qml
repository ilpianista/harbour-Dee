import QtQuick 2.0
import Sailfish.Silica 1.0

Image {
    id: thumbnail

    property url imageUrl

    width: Theme.iconSizeLarge
    height: Theme.iconSizeLarge
    source: imageUrl
    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    smooth: true
    cache: true
    clip: true

    sourceSize.width: width * Screen.devicePixelRatio
    sourceSize.height: height * Screen.devicePixelRatio

    opacity: status === Image.Ready ? 1 : 0
    Behavior on opacity {
        FadeAnimation {}
    }

    onStatusChanged: {
        if (status === Image.Error)
            console.warn("Failed to load thumbnail:", imageUrl);
    }
}
