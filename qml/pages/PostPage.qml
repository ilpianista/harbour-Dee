import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.dee 1.0

Page {
    id: page

    property var api
    property int postId
    property string postTitle
    property string postBody

    function loadComments() {
        if (api && postId > 0) {
            var params = JSON.stringify({
                "post_id": postId
            });
            api.listComments(params);
        }
    }

    Component.onCompleted: {
        loadComments();
        appWindow.postTitle = postTitle;
    }

    SilicaListView {
        anchors.fill: parent
        model: api ? api.comments : []

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                onClicked: loadComments()
            }

        }

        PushUpMenu {
            MenuItem {
                text: qsTr("Load more")
                enabled: !api.busy
                onClicked: api.loadMoreComments()
            }

        }

        ViewPlaceholder {
            enabled: api && api.comments.length === 0 && !api.busy
            text: qsTr("No comments")
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
            title: postTitle
        }

        delegate: BackgroundItem {
            id: commentDelegate

            property var commentData: modelData.comment || modelData
            property int depth: {
                var path = commentData.path || "";
                return path ? path.split('.').length : 1;
            }

            height: contentColumn.height + 2 * Theme.paddingMedium

            Column {
                id: contentColumn

                x: Theme.horizontalPageMargin + (depth > 1 ? (depth - 1) * Theme.paddingLarge : 0)
                width: parent.width - 2 * Theme.horizontalPageMargin - (depth > 1 ? (depth - 1) * Theme.paddingLarge : 0)
                spacing: Theme.paddingSmall

                Label {
                    width: parent.width
                    text: commentData.content || ""
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: commentDelegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                Label {
                    width: parent.width
                    text: {
                        var creator = modelData.creator || {
                        };
                        var counts = modelData.counts || {
                        };
                        return (creator.name || "") + " - " + (counts.score || 0) + " pts";
                    }
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                }

            }

        }

    }

}
