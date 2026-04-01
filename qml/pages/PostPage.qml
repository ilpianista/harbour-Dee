import QtQuick 2.0
import Sailfish.Share 1.0
import Sailfish.Silica 1.0
import harbour.dee 1.0

Page {
    id: page

    property var api
    property int postId
    property string postTitle
    property string postBody
    property string postUrl
    property string postDate
    property var postData
    property string postAuthor
    property int postScore
    property int postComments

    function loadComments() {
        if (api && postId > 0) {
            var params = JSON.stringify({
                "post_id": postId,
                "limit": 50
            });
            api.listComments(params);
        }
    }

    function loadPostDetails() {
        if (api && postId > 0)
            api.getPost(postId);
    }

    Component.onCompleted: {
        loadPostDetails();
        loadComments();
        appWindow.postTitle = postTitle;
    }

    onPostIdChanged: {
        loadPostDetails();
        loadComments();
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col.height

        PullDownMenu {
            MenuItem {
                text: qsTr("Copy external URL")
                onClicked: {
                    Clipboard.text = postUrl;
                }
            }

            MenuItem {
                text: qsTr("Share")
                onClicked: {
                    share.trigger();
                }
            }

            MenuItem {
                text: qsTr("Refresh")
                onClicked: {
                    loadPostDetails();
                    loadComments();
                }
            }
        }

        PushUpMenu {
            MenuItem {
                text: qsTr("Load more")
                enabled: !api.busy && api.comments.length < postComments
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

        VerticalScrollDecorator {}

        Column {
            id: col

            x: Theme.horizontalPageMargin
            width: parent.width - Theme.horizontalPageMargin * 2
            spacing: Theme.paddingMedium

            SectionHeader {}

            Label {
                width: parent.width
                text: postTitle
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
                wrapMode: Text.Wrap
            }

            // Workaround for Label that does not provide onClick?
            Text {
                width: parent.implicitWidth
                visible: (postUrl && !(/^\s*$/.test(postUrl)))
                textFormat: Text.RichText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WrapAnywhere
                text: {
                    var txt = "<style>a:link{color: " + Theme.secondaryHighlightColor + ";}</style>";
                    txt += "<a href=\"" + postUrl + "\" rel=\"nofollow\">" + postUrl + "</a>";
                    return txt;
                }
                onLinkActivated: {
                    console.log("Opening external browser: " + link);
                    Qt.openUrlExternally(link);
                }
            }

            Label {
                width: parent.width
                text: postBody || ""
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
                visible: postBody && postBody.length > 0
            }

            Label {
                width: parent.width
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignRight
                text: {
                    var actorId = postAuthor || "";
                    var username = "";
                    var domain = "";
                    if (actorId) {
                        var parts = actorId.split("/u/");
                        if (parts.length >= 2) {
                            username = parts[1];
                            var urlParts = actorId.split("://");
                            if (urlParts.length >= 2) {
                                domain = urlParts[1].split("/")[0];
                            }
                        }
                    }
                    return (username + "@" + domain) + " - " + Qt.formatDateTime(postDate, "ddd, hh:mm");
                }
            }

            SectionHeader {
                text: qsTr("Comments") + " (" + (api ? api.comments.length : 0) + "/" + postComments + ")"
            }

            Repeater {
                model: api ? api.comments : []

                delegate: BackgroundItem {
                    property var commentData: modelData.commentData
                    property var counts: modelData.counts
                    property int depth: modelData.depth

                    height: commentColumn.height + 2 * Theme.paddingMedium

                    Column {
                        id: commentColumn

                        x: (depth > 1 ? (depth - 1) * Theme.horizontalPageMargin : 0)
                        width: parent.width - (depth > 1 ? (depth - 1) * Theme.horizontalPageMargin : 0)
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width
                            text: commentData.content || ""
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                        }

                        Label {
                            width: parent.width
                            text: {
                                var creator = modelData.creator || {};
                                var actorId = creator.actor_id || "";
                                var username = "";
                                var domain = "";
                                if (actorId) {
                                    var parts = actorId.split("/u/");
                                    if (parts.length >= 2) {
                                        username = parts[1];
                                        var urlParts = actorId.split("://");
                                        if (urlParts.length >= 2) {
                                            domain = urlParts[1].split("/")[0];
                                        }
                                    }
                                }
                                return (username + "@" + domain) + " - " + (counts.score || 0) + " pts";
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

    ShareAction {
        id: share

        title: qsTr("Share url")
        mimeType: "text/x-url"
        resources: [
            {
                "type": "text/x-url",
                "linkTitle": postTitle,
                "status": postUrl.toString()
            }
        ]
    }
}
