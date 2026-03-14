import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.dee 1.0

Page {
    id: page

    property alias api: _api

    allowedOrientations: Orientation.All
    Component.onCompleted: {
        if (_api.loggedIn)
            replaceTimer.start();

    }

    LemmyAPI {
        id: _api
    }

    Timer {
        id: replaceTimer

        interval: 0
        onTriggered: pageStack.replace(Qt.resolvedUrl("SubscribedPage.qml"))
        repeat: false
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column

            width: page.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("Login")
            }

            TextField {
                id: instanceField

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                placeholderText: qsTr("https://lemmy.world")
                inputMethodHints: Qt.ImhUrlCharactersOnly
                text: _api.instanceUrl
                onTextChanged: _api.instanceUrl = text
                EnterKey.enabled: text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: usernameField.focus = true
            }

            TextField {
                id: usernameField

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                placeholderText: qsTr("Email or Username")
                text: _api.username
                onTextChanged: _api.username = text
                EnterKey.enabled: text.length > 0 && passwordField.text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: passwordField.focus = true
            }

            TextField {
                id: passwordField

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                placeholderText: qsTr("Password")
                echoMode: TextInput.Password
                text: _api.password
                onTextChanged: _api.password = text
                EnterKey.enabled: text.length > 0 && usernameField.text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: _api.login()
            }

            Button {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                enabled: !_api.busy && instanceField.text.length > 0 && usernameField.text.length > 0 && passwordField.text.length > 0
                text: _api.busy ? qsTr("Logging in...") : qsTr("Login")
                onClicked: _api.login()
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: _api.error.length > 0 ? Theme.errorColor : Theme.secondaryColor
                text: _api.error
                visible: _api.error.length > 0
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }

        }

    }

    Connections {
        // Error is already displayed via binding

        target: _api
        onLoginSuccess: {
            pageStack.replace(Qt.resolvedUrl("SubscribedPage.qml"));
        }
        onLoginFailed: {
        }
    }

}
