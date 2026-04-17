import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.dee 1.0
import "utils.js" as Utils

Page {
    id: page

    property int communityId: 0
    property string pageTitle: ""

    function refresh() {
        var params = {
            "limit": 50
        };
        if (communityId > 0)
            params.community_id = communityId;

        api.listPosts(JSON.stringify(params));
    }

    allowedOrientations: Orientation.All
    onStatusChanged: {
        if (status === PageStatus.Active) {
            appWindow.postTitle = "";
            appWindow.postScore = 0;
            appWindow.postComments = 0;
        }
    }

    PostsModel {
        id: posts
    }

    LemmyAPI {
        id: api

        Component.onCompleted: {
            api.setPostsModel(posts);
            var params = {
                "limit": 50
            };
            if (communityId > 0)
                params.community_id = communityId;

            api.listPosts(JSON.stringify(params));
        }
    }

    SilicaListView {
        id: listView

        anchors.fill: parent
        model: posts
        spacing: 0
        onAtYEndChanged: {
            if (atYEnd && !api.busy && listView.count > 0)
                api.loadMorePosts();
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("SettingsPage.qml"), {
                    "api": api
                })
            }

            MenuItem {
                text: communityId > 0 ? qsTr("Subscribed") : qsTr("Communities")
                onClicked: {
                    if (communityId > 0)
                        pageStack.animatorPush(Qt.resolvedUrl("SubscribedPage.qml"));
                    else
                        pageStack.animatorPush(Qt.resolvedUrl("CommunitiesPage.qml"), {
                            "api": api
                        });
                }
            }

            MenuItem {
                text: qsTr("Refresh")
                onClicked: refresh()
            }
        }

        ViewPlaceholder {
            enabled: listView.count === 0 && !api.busy
            text: qsTr("No posts")
            hintText: qsTr("Pull down to refresh")
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: api.busy && listView.count === 0
        }

        VerticalScrollDecorator {}

        header: PageHeader {
            title: pageTitle ? pageTitle : qsTr("Subscribed")
        }

        footer: Column {
            width: parent.width
            height: visible ? implicitHeight + Theme.paddingLarge * 2 : 0
            visible: api.busy && listView.count > 0

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                size: BusyIndicatorSize.Small
                running: api.busy
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Loading more…")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
            }
        }

        delegate: ListItem {
            id: delegate

            property var post: postData.post
            property var community: postData.community || {}
            property var counts: postData.counts || {}
            property int myVote: postData.my_vote ? postData.my_vote : 0

            menu: contextMenu
            contentHeight: contentColumn.height + 2 * Theme.paddingMedium
            onClicked: {
                if (post.id)
                    pageStack.animatorPush(Qt.resolvedUrl("PostPage.qml"), {
                        "api": api,
                        "community": community.name,
                        "postId": post.id,
                        "postTitle": post.name,
                        "postBody": post.body,
                        "postUrl": post.url ? post.url : "",
                        "postAuthor": postData.creator.actor_id,
                        "postScore": counts.score,
                        "postDate": post.published,
                        "postComments": counts.comments,
                        "postMyVote": postData.my_vote ? postData.my_vote : 0
                    });
            }

            Column {
                id: contentColumn

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall

                Label {
                    visible: page.communityId === 0
                    text: "c/" + (community.name || "")
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryHighlightColor
                }

                // Post title
                Label {
                    width: parent.width
                    text: post.name || ""
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                    color: delegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                Label {
                    visible: post.url ? (post.url.length > 0 && !/^\s*$/.test(post.url)) : false
                    text: {
                        try {
                            var u = new URL(post.url);
                            return u.hostname;
                        } catch (e) {
                            return post.url || "";
                        }
                    }
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryHighlightColor
                    truncationMode: TruncationMode.Fade
                    width: parent.width
                }

                Row {
                    spacing: Theme.paddingSmall

                    Label {
                        text: {
                            var s = counts.score || 0;
                            if (myVote > 0)
                                return "▲ " + s;

                            if (myVote < 0)
                                return "▼ " + s;

                            return s + " " + qsTr("pts");
                        }
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: myVote > 0 ? Theme.highlightColor : myVote < 0 ? Theme.highlightDimmerColor : Theme.secondaryColor
                    }

                    Label {
                        text: "·"
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        visible: (counts.comments || 0) > 0
                    }

                    Label {
                        text: (counts.comments || 0) + " " + qsTr("comments")
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        visible: (counts.comments || 0) > 0
                    }

                    Label {
                        text: "·"
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }

                    Label {
                        text: Utils.getRelativeTime(post.published)
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }
                }
            }

            Component {
                id: contextMenu

                ContextMenu {
                    MenuItem {
                        text: myVote === 0 ? qsTr("Upvote") : qsTr("Undo upvote")
                        onClicked: api.likePost(post.id, myVote === 0 ? 1 : 0)
                        enabled: myVote >= 0
                    }

                    MenuItem {
                        text: myVote === 0 ? qsTr("Downvote") : qsTr("Undo downvote")
                        onClicked: api.likePost(post.id, myVote === 0 ? -1 : 0)
                        enabled: myVote <= 0
                    }
                }
            }
        }
    }

    Connections {
        target: api
        onRequestFinished: {
            if (method === "likePost")
                refresh();
        }
    }
}
