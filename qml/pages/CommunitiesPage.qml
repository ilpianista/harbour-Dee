import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.dee 1.0

Page {
    id: page

    property var api: appWindow.api
    property bool redirectToHome: false

    function showHome(listingType, immediate) {
        var home = pageStack.find(function (p) {
            return p.communityId === 0;
        });
        if (home) {
            home.listingType = listingType;
            home.refresh();
            pageStack.pop(home);
        } else {
            var properties = {
                "api": api,
                "listingType": listingType
            };
            if (immediate)
                pageStack.push(Qt.resolvedUrl("SubscribedPage.qml"), properties, PageStackAction.Immediate);
            else
                pageStack.animatorPush(Qt.resolvedUrl("SubscribedPage.qml"), properties);
        }
    }

    function refreshCommunities() {
        api.listCommunities(JSON.stringify({
            "type_": "Subscribed",
            "limit": 50
        }));
    }

    allowedOrientations: Orientation.All
    onStatusChanged: {
        if (status === PageStatus.Active && redirectToHome) {
            redirectToHome = false;
            homeRedirectTimer.start();
        }
    }

    Timer {
        id: homeRedirectTimer

        interval: 0
        repeat: false
        onTriggered: {
            // Go Home first so the posts request is queued ahead of the
            // communities one (the native worker handles requests serially).
            page.showHome(AppSettings.defaultListingType, true);
            page.refreshCommunities();
        }
    }

    Component.onCompleted: {
        if (!redirectToHome)
            refreshCommunities();
    }

    SilicaListView {
        id: listView

        anchors.fill: parent
        model: api ? api.communities : []

        onAtYEndChanged: {
            if (atYEnd && !api.busy && listView.count > 0)
                api.loadMoreCommunities();
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Inbox") + (api.unreadCount > 0 ? " (" + api.unreadCount + ")" : "")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("InboxPage.qml"), {
                    "api": api
                })
            }

            MenuItem {
                text: qsTr("Go to community")
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("GoToCommunityDialog.qml"), {
                        "api": api
                    });
                }
            }

            MenuItem {
                text: qsTr("Refresh")
                onClicked: page.refreshCommunities()
            }
        }

        ViewPlaceholder {
            enabled: (!api || api.communities.length === 0) && (!api || !api.busy)
            verticalOffset: appWindow.listingTypes.length * Theme.itemSizeSmall / 2
            text: qsTr("No subscribed communities")
            hintText: qsTr("Pull down to refresh")
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: api && api.busy && listView.count === 0
        }

        VerticalScrollDecorator {}

        header: Column {
            width: listView.width

            PageHeader {
                title: qsTr("Communities")
            }

            Repeater {
                model: appWindow.listingTypes

                delegate: BackgroundItem {
                    id: listingItem

                    width: parent.width
                    onClicked: page.showHome(modelData.value)

                    Label {
                        anchors {
                            left: parent.left
                            leftMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                        text: modelData.text
                        color: listingItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                    }
                }
            }

            Separator {
                width: parent.width
                color: Theme.primaryColor
            }
        }

        footer: LoadingFooter {
            busy: api ? api.busy : false
            itemCount: listView.count
        }

        delegate: BackgroundItem {
            id: delegate

            width: ListView.view.width
            height: contentColumn.height + 2 * Theme.paddingMedium
            onClicked: {
                var community = modelData.community || {};
                pageStack.animatorPush(Qt.resolvedUrl("SubscribedPage.qml"), {
                    "api": api,
                    "communityId": community.id,
                    "pageTitle": community.title || community.name
                });
            }

            Column {
                id: contentColumn

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingSmall / 2

                Label {
                    width: parent.width
                    text: {
                        var c = modelData.community || {};
                        return c.title || c.name || "";
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: delegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                    truncationMode: TruncationMode.Fade
                }

                Row {
                    spacing: Theme.paddingSmall

                    Label {
                        text: {
                            var n = (modelData.counts || {}).subscribers || 0;
                            return n + " " + qsTr("subscribers");
                        }
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }

                    Label {
                        text: "·"
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }

                    Label {
                        text: {
                            var n = (modelData.counts || {}).posts || 0;
                            return n + " " + qsTr("posts");
                        }
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }
                }
            }

            Image {
                source: "image://theme/icon-m-right"
                opacity: delegate.highlighted ? 1 : 0.4

                anchors {
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
