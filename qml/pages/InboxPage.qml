import QtQuick 2.0
import Sailfish.Silica 1.0
import "../lib/Utils.js" as Utils

Page {
    id: page

    property var api

    allowedOrientations: Orientation.All

    Component.onCompleted: {
        if (api && api.loggedIn)
            api.listNotifications();
    }

    SilicaListView {
        id: listView

        anchors.fill: parent
        model: api ? api.notifications : []

        PullDownMenu {
            MenuItem {
                text: qsTr("Home")
                onClicked: {
                    var home = pageStack.find(function (p) {
                        return p.communityId === 0;
                    });
                    if (home && home !== page)
                        pageStack.pop(home);
                }
            }

            MenuItem {
                text: qsTr("Mark all as read")
                enabled: api ? api.unreadCount > 0 : false
                onClicked: api.markNotificationsRead(-1)
            }

            MenuItem {
                text: qsTr("Refresh")
                onClicked: api.listNotifications()
            }
        }

        header: PageHeader {
            title: api && api.unreadCount > 0 ? qsTr("Inbox (%1)").arg(api.unreadCount) : qsTr("Inbox")
        }

        ViewPlaceholder {
            enabled: listView.count === 0 && (!api || !api.busy)
            text: qsTr("No notifications")
            hintText: qsTr("Pull down to refresh")
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: api && api.busy && listView.count === 0
        }

        VerticalScrollDecorator {}

        delegate: ListItem {
            id: item

            property var notif: modelData
            property bool isUnread: notif.unread === true
            property string notifType: notif.type || ""
            property var creator: notif.creator || {}
            property var recipient: notif.recipient || {}
            property bool ownPrivate: notifType === "PrivateMessage" && notif.own === true
            property string author: {
                if (ownPrivate)
                    return recipient.actor_id || "";
                return creator.actor_id || "";
            }
            property string previewText: {
                if (notif.comment && notif.comment.content)
                    return notif.comment.content;
                if (notif.private_message && notif.private_message.content)
                    return notif.private_message.content;
                if (notif.post && notif.post.name)
                    return notif.post.name;
                return "";
            }

            contentHeight: contentCol.height + 2 * Theme.paddingMedium
            onClicked: {
                if (isUnread)
                    api.markNotificationsRead(notif.id, notif.type);
                if (notifType === "CommentReply" || notifType === "CommentMention" || notifType === "PostMention") {
                    var post = notif.post || {};
                    var community = notif.community || {};
                    pageStack.animatorPush(Qt.resolvedUrl("PostPage.qml"), {
                        "api": api,
                        "community": community.name || "",
                        "postId": post.id || 0,
                        "postTitle": post.name || "",
                        "postBody": post.body || "",
                        "postUrl": post.url || "",
                        "postScore": 0,
                        "postDate": post.published || "",
                        "postComments": 0,
                        "postMyVote": 0,
                        "postLocked": post.locked || false
                    });
                } else if (notifType === "PrivateMessage") {
                    var other = ownPrivate ? (notif.recipient || {}) : (notif.creator || {});
                    pageStack.animatorPush(Qt.resolvedUrl("PrivateMessagePage.qml"), {
                        "api": api,
                        "content": (notif.private_message || {}).content || "",
                        "otherActor": other.actor_id || "",
                        "recipientId": other.id || 0,
                        "own": ownPrivate,
                        "published": notif.published || ""
                    });
                }
            }

            Rectangle {
                width: Theme.paddingSmall / 2
                color: Theme.highlightColor
                visible: isUnread
                opacity: 0.8

                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
            }

            Column {
                id: contentCol

                x: Theme.horizontalPageMargin
                y: Theme.paddingMedium
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall

                Label {
                    width: parent.width
                    text: {
                        switch (notifType) {
                        case "CommentReply":
                            return qsTr("Reply to your comment");
                        case "PostMention":
                        case "CommentMention":
                            return qsTr("You were mentioned");
                        case "PrivateMessage":
                            return ownPrivate ? qsTr("Sent private message") : qsTr("Private message");
                        default:
                            return qsTr("Notification");
                        }
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: isUnread ? (item.highlighted ? Theme.highlightColor : Theme.primaryColor) : Theme.secondaryColor
                }

                Label {
                    width: parent.width
                    textFormat: Text.StyledText
                    linkColor: item.highlighted ? Theme.primaryColor : Theme.highlightColor
                    text: Utils.linkify(previewText)
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: item.highlighted ? Theme.highlightColor : Theme.secondaryColor
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    visible: previewText.length > 0
                    onLinkActivated: Qt.openUrlExternally(link)
                }

                Row {
                    width: parent.width
                    spacing: Theme.paddingSmall

                    Label {
                        text: Utils.formatAuthor(item.author)
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: item.highlighted ? Theme.highlightColor : Theme.secondaryHighlightColor
                        visible: text.length > 0
                    }

                    Label {
                        text: "·"
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: item.highlighted ? Theme.highlightColor : Theme.secondaryColor
                        visible: Utils.formatAuthor(item.author).length > 0
                    }

                    Label {
                        text: notif.published ? Format.formatDate(notif.published, Formatter.DurationElapsed) : ""
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: item.highlighted ? Theme.highlightColor : Theme.secondaryColor
                    }
                }
            }
        }
    }
}
