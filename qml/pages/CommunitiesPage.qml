import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.dee 1.0

Page {
    id: page

    property var api

    allowedOrientations: Orientation.All

    Component.onCompleted: {
        api.listCommunities(JSON.stringify({
            "type_": "Subscribed"
        }));
    }

    SilicaListView {
        id: listView

        anchors.fill: parent
        model: api ? api.communities : []

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: {
                    api.listCommunities(JSON.stringify({
                        "type_": "Subscribed"
                    }));
                }
            }
        }

        PushUpMenu {
            MenuItem {
                text: qsTr("Load more")
                enabled: !api.busy
                onClicked: api.loadMoreCommunities()
            }
        }

        ViewPlaceholder {
            enabled: (!api || api.communities.length === 0) && (!api || !api.busy)
            text: qsTr("You aren't following any communities")
            hintText: qsTr("Pull down to refresh")
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: api ? api.busy : false
        }

        VerticalScrollDecorator {}

        header: Column {
            width: parent.width

            PageHeader {
                title: qsTr("Communities")
            }
        }

        delegate: BackgroundItem {
            id: delegate

            height: contentRow.height + 2 * Theme.paddingMedium

            Row {
                id: contentRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingMedium
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin

                Column {
                    id: contentColumn

                    width: parent.width - Theme.itemSizeExtraSmall - Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: {
                            var community = modelData.community || {};
                            return community.title || community.name || "";
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: delegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                    }

                    Label {
                        width: parent.width
                        text: {
                            var counts = modelData.counts || {};
                            return (counts.subscribers || 0) + " subscribers, " + (counts.posts || 0) + " posts";
                        }
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        truncationMode: TruncationMode.Fade
                    }
                }
            }
        }
    }
}
