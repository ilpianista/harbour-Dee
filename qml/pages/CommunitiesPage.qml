import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.dee 1.0

Page {
    id: page

    property var api

    allowedOrientations: Orientation.All

    SilicaListView {
        id: listView

        anchors.fill: parent
        model: api ? api.communities : []

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: {
                    api.listCommunities("");
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
            text: qsTr("No communities")
            hintText: qsTr("Pull down to refresh")
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: api ? api.busy : false
        }

        VerticalScrollDecorator {
        }

        header: PageHeader {
            title: qsTr("Communities")
        }

        delegate: BackgroundItem {
            id: delegate

            height: contentColumn.height + 2 * Theme.paddingMedium

            Column {
                id: contentColumn

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingSmall

                Label {
                    width: parent.width
                    text: {
                        var community = modelData.community || {
                        };
                        return community.title || community.name || "";
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: delegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                Label {
                    width: parent.width
                    text: {
                        var counts = modelData.counts || {
                        };
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
