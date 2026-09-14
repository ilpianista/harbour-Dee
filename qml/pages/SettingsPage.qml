import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.dee 1.0

Page {
    id: page

    property var api

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        RemorsePopup {
            id: remorseLogout
        }

        VerticalScrollDecorator {}

        Column {
            id: column

            width: page.width
            spacing: 0

            PageHeader {
                title: qsTr("Settings")
            }

            SectionHeader {
                text: qsTr("Account")
            }

            DetailItem {
                label: qsTr("Username")
                value: api.username
            }

            DetailItem {
                label: qsTr("Instance")
                value: api.instanceUrl
            }

            SectionHeader {
                text: qsTr("Feed")
            }

            TextSwitch {
                text: qsTr("Full size media")
                description: qsTr("Show post images at full width instead of small thumbnails")
                checked: AppSettings.fullSizeMediaEnabled
                onCheckedChanged: AppSettings.fullSizeMediaEnabled = checked
            }

            SectionHeader {
                text: qsTr("Notifications")
            }

            TextSwitch {
                text: qsTr("Background checking")
                description: qsTr("Poll for new notifications while the app is running")
                checked: api.backgroundCheckEnabled
                onCheckedChanged: api.backgroundCheckEnabled = checked
            }

            ComboBox {
                label: qsTr("Check interval")
                enabled: api.backgroundCheckEnabled
                currentIndex: {
                    var mins = api.checkIntervalMinutes;
                    if (mins <= 5)
                        return 0;
                    if (mins <= 15)
                        return 1;
                    if (mins <= 30)
                        return 2;
                    return 3;
                }
                onCurrentIndexChanged: {
                    var vals = [5, 15, 30, 60];
                    api.checkIntervalMinutes = vals[currentIndex];
                }
                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("5 minutes")
                    }
                    MenuItem {
                        text: qsTr("15 minutes")
                    }
                    MenuItem {
                        text: qsTr("30 minutes")
                    }
                    MenuItem {
                        text: qsTr("1 hour")
                    }
                }
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }

            Button {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Sign out")
                onClicked: {
                    remorseLogout.execute(qsTr("Logging out"), function () {
                        api.logout();
                        pageStack.replace(Qt.resolvedUrl("LoginPage.qml"));
                    });
                }
            }

            Item {
                width: 1
                height: Theme.paddingLarge * 2
            }
        }
    }
}
