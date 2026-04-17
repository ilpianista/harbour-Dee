import QtQuick 2.6
import Sailfish.Share 1.0
import Sailfish.Silica 1.0
import harbour.dee 1.0
import "utils.js" as Utils

Page {
    id: page

    property var api
    property string community
    property int postId
    property string postTitle
    property string postBody
    property string postUrl
    property string postDate
    property var postData
    property string postAuthor
    property int postScore
    property int postComments
    property int postMyVote
    property bool postLocked
    readonly property var threadColors: [Theme.highlightColor, Theme.secondaryHighlightColor, Theme.primaryColor, Theme.secondaryColor]

    function loadComments() {
        api.listComments(JSON.stringify({
            "post_id": postId,
            "limit": 50
        }));
    }

    function refresh() {
        api.getPost(postId);
        loadComments();
    }

    function previewText(text) {
        if (!text || text.trim().length === 0)
            return "";

        return text.trim().substring(0, 200);
    }

    Component.onCompleted: {
        loadComments();
        appWindow.postTitle = postTitle;
        appWindow.postScore = postScore;
        appWindow.postComments = postComments;
    }
    onStatusChanged: {
        if (status === PageStatus.Active) {
            if (postUrl && !/^\s*$/.test(postUrl))
                pageStack.pushAttached(Qt.resolvedUrl("PostWebView.qml"), {
                    "postUrl": postUrl
                });
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Share")
                onClicked: share.trigger()
            }

            MenuItem {
                text: qsTr("Refresh")
                onClicked: refresh()
            }

            MenuItem {
                enabled: !postLocked
                text: qsTr("Reply")
                onClicked: pageStack.push(Qt.resolvedUrl("ReplyPage.qml"), {
                    "api": api,
                    "postId": postId,
                    "parentId": 0,
                    "previewText": qsTr("In reply to \"%1\"").arg(previewText(postTitle))
                })
            }

            MenuItem {
                text: postMyVote === 0 ? qsTr("Upvote") : qsTr("Undo upvote")
                onClicked: api.likePost(postId, postMyVote === 0 ? 1 : 0)
                enabled: postMyVote >= 0
            }

            MenuItem {
                text: postMyVote === 0 ? qsTr("Downvote") : qsTr("Undo downvote")
                onClicked: api.likePost(postId, postMyVote === 0 ? -1 : 0)
                enabled: postMyVote <= 0
            }
        }

        PushUpMenu {
            visible: api.comments.length < postComments

            MenuItem {
                text: qsTr("Load more comments")
                enabled: !api.busy
                onClicked: api.loadMoreComments()
            }
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
            spacing: 0

            Item {
                width: 1
                height: Theme.paddingLarge * 2
            }

            Label {
                width: parent.width
                text: postTitle
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
                wrapMode: Text.Wrap
            }

            Rectangle {
                visible: postUrl && !/^\s*$/.test(postUrl)
                width: parent.width
                height: urlLabel.implicitHeight + Theme.paddingMedium * 2
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.1)
                radius: Theme.paddingSmall
                anchors.topMargin: Theme.paddingMedium

                Text {
                    id: urlLabel

                    textFormat: Text.RichText
                    font.pixelSize: Theme.fontSizeExtraSmall
                    wrapMode: Text.WrapAnywhere
                    text: {
                        var c = Theme.secondaryHighlightColor;
                        return "<style>a:link{color:" + c + ";}</style>" + "<a href=\"" + postUrl + "\">" + postUrl + "</a>";
                    }
                    onLinkActivated: Qt.openUrlExternally(link)

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: Theme.paddingMedium
                    }
                }
            }

            Label {
                visible: postBody && postBody.length > 0
                width: parent.width
                topPadding: Theme.paddingMedium
                text: postBody || ""
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
            }

            Row {
                width: parent.width
                topPadding: Theme.paddingMedium
                spacing: Theme.paddingSmall

                Label {
                    text: "c/" + community
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryHighlightColor
                }

                Label {
                    text: "·"
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                }

                Row {
                    spacing: Theme.paddingSmall

                    Label {
                        text: {
                            if (postMyVote > 0)
                                return "▲ " + postScore;

                            if (postMyVote < 0)
                                return "▼ " + postScore;

                            return postScore;
                        }
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: postMyVote > 0 ? Theme.highlightColor : postMyVote < 0 ? "#e05050" : Theme.secondaryColor
                    }

                    Image {
                        source: "image://theme/icon-s-like"
                        width: Theme.iconSizeExtraSmall
                        height: Theme.iconSizeExtraSmall
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: 0.7
                    }
                }

                Label {
                    text: "·"
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                }

                Label {
                    text: Utils.getRelativeTime(postDate)
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                }
            }

            Label {
                text: Utils.formatAuthor(postAuthor)
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                width: parent.width
                horizontalAlignment: Text.AlignRight
            }

            SectionHeader {
                text: qsTr("Comments") + " (" + (api ? api.comments.length : 0) + "/" + postComments + ")"
                topPadding: Theme.paddingLarge
            }

            Label {
                width: parent.width
                visible: api && api.comments.length === 0 && !api.busy
                text: qsTr("No comments yet.")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                topPadding: Theme.paddingLarge
                bottomPadding: Theme.paddingLarge
            }

            Repeater {
                model: api ? api.comments : []

                delegate: Item {
                    id: commentItem

                    property var commentData: modelData.commentData
                    property var counts: modelData.counts
                    property int depth: modelData.depth
                    property int myVote: modelData.myVote

                    width: col.width
                    height: (commentMenu.active ? commentMenu.height : 0) + commentRow.height + Theme.paddingSmall * 2

                    Rectangle {
                        visible: depth > 1
                        x: (depth - 1) * Theme.paddingLarge - Theme.paddingSmall
                        width: 2
                        height: parent.height
                        color: threadColors[Math.min((depth - 1) % threadColors.length, threadColors.length - 1)]
                        opacity: Math.max(0.3, 1 - (depth - 1) * 0.15)
                    }

                    BackgroundItem {
                        id: commentBg

                        anchors.fill: parent
                        onPressAndHold: commentMenu.open(commentBg)
                    }

                    Row {
                        id: commentRow

                        x: depth > 1 ? (depth - 1) * Theme.paddingLarge + Theme.paddingSmall : 0
                        width: col.width - x
                        y: Theme.paddingSmall
                        spacing: 0

                        Column {
                            width: parent.width
                            spacing: Theme.paddingSmall / 2

                            // Comment body
                            Label {
                                width: parent.width
                                text: commentData.content || ""
                                color: commentBg.highlighted ? Theme.highlightColor : Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: Text.Wrap
                            }

                            Row {
                                spacing: Theme.paddingSmall

                                Label {
                                    text: Utils.formatAuthor((modelData.creator || {}).actor_id || "")
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: Theme.secondaryHighlightColor
                                }

                                Label {
                                    text: "·"
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: Theme.secondaryColor
                                }

                                Row {
                                    spacing: Theme.paddingSmall

                                    Label {
                                        text: {
                                            if (myVote > 0)
                                                return "▲ " + (counts.score || 0);

                                            if (myVote < 0)
                                                return "▼ " + (counts.score || 0);

                                            return (counts.score || 0);
                                        }
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: myVote > 0 ? Theme.highlightColor : myVote < 0 ? Theme.highlightDimmerColor : Theme.secondaryColor
                                    }

                                    Image {
                                        source: "image://theme/icon-s-like"
                                        width: Theme.iconSizeExtraSmall
                                        height: Theme.iconSizeExtraSmall
                                        anchors.verticalCenter: parent.verticalCenter
                                        opacity: 0.7
                                    }
                                }

                                Label {
                                    text: "·"
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: Theme.secondaryColor
                                }

                                Label {
                                    text: Utils.getRelativeTime(commentData.published || "")
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: Theme.secondaryColor
                                }
                            }
                        }
                    }

                    ContextMenu {
                        id: commentMenu

                        MenuItem {
                            text: myVote === 0 ? qsTr("Upvote") : qsTr("Undo upvote")
                            onClicked: api.likeComment(commentData.id, myVote === 0 ? 1 : 0)
                            enabled: myVote >= 0
                        }

                        MenuItem {
                            text: myVote === 0 ? qsTr("Downvote") : qsTr("Undo downvote")
                            onClicked: api.likeComment(commentData.id, myVote === 0 ? -1 : 0)
                            enabled: myVote <= 0
                        }

                        MenuItem {
                            enabled: !postLocked
                            text: qsTr("Reply")
                            onClicked: pageStack.push(Qt.resolvedUrl("ReplyPage.qml"), {
                                "api": api,
                                "postId": postId,
                                "parentId": commentData.id,
                                "previewText": qsTr("In reply to \"%1\"").arg(previewText(commentData.content))
                            })
                        }
                    }
                }
            }

            Item {
                width: 1
                height: Theme.paddingLarge * 2
            }
        }
    }

    Connections {
        target: api
        onRequestFinished: {
            if (method === "likePost" || method === "getPost") {
                var pv = result.post_view;
                postMyVote = pv.my_vote ? pv.my_vote : 0;
                postComments = pv.counts.comments;
                postScore = pv.counts.score;
                postTitle = pv.post.name;
                appWindow.postTitle = postTitle;
                appWindow.postScore = postScore;
                appWindow.postComments = postComments;
            } else if (method === "likeComment") {
                loadComments();
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
