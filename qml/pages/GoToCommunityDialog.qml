import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property var api

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: column

            width: parent.width
            spacing: 0

            PageHeader {
                title: qsTr("Go to community")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Enter a community name or full handle (e.g. \"lemmy\" or \"lemmy@lemmy.world\")")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }

            TextField {
                id: nameField
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                placeholderText: "lemmy@lemmy.world"
                enabled: !submitted
                inputMethodHints: Qt.ImhNoAutoUppercase
                EnterKey.enabled: text.trim().length > 0 && !submitted
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: submit()
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }

            Button {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Go")
                enabled: nameField.text.trim().length > 0 && !submitted
                onClicked: submit()
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: errorText.length > 0
                text: errorText
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.errorColor
                wrapMode: Text.Wrap
                topPadding: Theme.paddingMedium
            }
        }
    }

    property bool submitted: false
    property string errorText: ""

    function submit() {
        var name = nameField.text.trim();
        if (name.length === 0 || !api)
            return;
        submitted = true;
        api.getCommunity(JSON.stringify({
            "name": name
        }));
    }

    Connections {
        target: api
        onRequestFinished: {
            if (method === "getCommunity") {
                var cv = result.community_view;
                if (cv && cv.community) {
                    pageStack.replace(Qt.resolvedUrl("SubscribedPage.qml"), {
                        "api": api,
                        "communityId": cv.community.id,
                        "pageTitle": cv.community.title || cv.community.name
                    });
                } else {
                    submitted = false;
                    errorText = qsTr("Community not found. Check the name and try again.");
                }
            }
        }
        onRequestFailed: {
            if (method === "getCommunity") {
                submitted = false;
                errorText = qsTr("Community not found. Check the name and try again.");
            }
        }
    }
}
