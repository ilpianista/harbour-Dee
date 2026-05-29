import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.dee 1.0

Page {
    id: page

    property alias api: _api

    function doLogin() {
        _api.serverKind = serverSoftware.currentIndex === 1 ? "piefed" : "lemmy";
        _api.login(instance.text, username.text, password.text, useTwoFactor.checked ? totp.text : "");
    }

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
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: column

            width: page.width
            spacing: 0

            PageHeader {
                title: qsTr("Sign in")
            }

            SectionHeader {
                text: qsTr("Instance")
            }

            TextField {
                id: instance

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                label: qsTr("Instance URL")
                placeholderText: "https://lemmy.world"
                inputMethodHints: Qt.ImhUrlCharactersOnly
                text: _api.instanceUrl
                EnterKey.enabled: text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: username.focus = true
            }

            ComboBox {
                id: serverSoftware

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                label: qsTr("Server software")
                currentIndex: _api.serverKind === "piefed" ? 1 : 0
                enabled: !_api.busy

                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("Lemmy")
                    }

                    MenuItem {
                        text: qsTr("PieFed")
                    }
                }
            }

            SectionHeader {
                text: qsTr("Credentials")
            }

            TextField {
                id: username

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                label: qsTr("Email or Username")
                placeholderText: qsTr("Email or Username")
                text: _api.username
                EnterKey.enabled: text.length > 0 && instance.text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: password.focus = true
            }

            TextField {
                id: password

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                label: qsTr("Password")
                placeholderText: qsTr("Password")
                echoMode: TextInput.Password
                EnterKey.enabled: text.length > 0 && username.text.length > 0
                EnterKey.iconSource: useTwoFactor.checked ? "image://theme/icon-m-enter-next" : "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: {
                    if (useTwoFactor.checked)
                        totp.focus = true;
                    else
                        doLogin();
                }
            }

            // 2FA toggle – hidden by default
            TextSwitch {
                id: useTwoFactor

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Two-factor authentication")
                checked: false
            }

            TextField {
                id: totp

                visible: useTwoFactor.checked
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                label: qsTr("Authentication code")
                placeholderText: qsTr("6-digit code")
                inputMethodHints: Qt.ImhDigitsOnly
                EnterKey.enabled: text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: doLogin()
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }

            Button {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                enabled: !_api.busy && instance.text.length > 0 && username.text.length > 0 && password.text.length > 0
                text: _api.busy ? qsTr("Signing in…") : qsTr("Sign in")
                onClicked: doLogin()
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                topPadding: Theme.paddingMedium
                wrapMode: Text.Wrap
                color: Theme.errorColor
                text: _api.error
                visible: _api.error.length > 0
                font.pixelSize: Theme.fontSizeSmall
            }

            Item {
                width: 1
                height: Theme.paddingLarge * 2
            }
        }
    }

    Connections {
        target: _api
        onLoginSuccess: pageStack.replace(Qt.resolvedUrl("SubscribedPage.qml"))
        onLoginFailed: {}
    }
}
