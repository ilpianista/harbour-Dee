import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.dee 1.0
import "utils.js" as Utils

Page {
    id: page

    property int communityId: 0
    property string pageTitle: ""

    allowedOrientations: Orientation.All

    LemmyAPI {
        id: api

        Component.onCompleted: {
            var params = {
                "limit": 50
            };
            if (communityId > 0) {
                params.community_id = communityId;
            }
            api.listPosts(JSON.stringify(params));
        }
    }

    SilicaListView {
        id: listView

        anchors.fill: parent
        model: api.posts

        PullDownMenu {
            MenuItem {
                text: qsTr("Logout")
                onClicked: {
                    api.logout();
                    pageStack.replace(Qt.resolvedUrl("LoginPage.qml"));
                }
            }

            MenuItem {
                text: communityId > 0 ? qsTr("Subscribed") : qsTr("Communities")
                onClicked: {
                    if (communityId > 0) {
                        pageStack.animatorPush(Qt.resolvedUrl("SubscribedPage.qml"));
                    } else {
                        pageStack.animatorPush(Qt.resolvedUrl("CommunitiesPage.qml"), {
                            "api": api
                        });
                    }
                }
            }

            MenuItem {
                text: qsTr("Refresh")
                onClicked: {
                    var params = {
                        "limit": 50
                    };
                    if (communityId > 0) {
                        params.community_id = communityId;
                    }
                    api.listPosts(JSON.stringify(params));
                }
            }
        }

        PushUpMenu {
            MenuItem {
                text: qsTr("Load more")
                enabled: !api.busy
                onClicked: api.loadMorePosts()
            }
        }

        ViewPlaceholder {
            enabled: api.posts.length === 0 && !api.busy
            text: qsTr("No posts")
            hintText: qsTr("Pull down to refresh")
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: api.busy
        }

        VerticalScrollDecorator {}

        header: PageHeader {
            title: pageTitle ? pageTitle : qsTr("Subscribed")
        }

        delegate: ListItem {
            id: delegate

            property var post: modelData.post
            property int myVote: modelData.my_vote ? modelData.my_vote : 0

            menu: contextMenu

            contentHeight: contentColumn.height + 2 * Theme.paddingMedium
            onClicked: {
                if (post.id)
                    pageStack.animatorPush(Qt.resolvedUrl("PostPage.qml"), {
                        "api": api,
                        "postId": post.id,
                        "postTitle": post.name,
                        "postBody": post.body,
                        "postUrl": post.url,
                        "postAuthor": modelData.creator.actor_id,
                        "postScore": modelData.counts.score,
                        "postDate": post.published,
                        "postComments": modelData.counts.comments,
                        "postMyVote": modelData.my_vote ? modelData.my_vote : 0
                    });
            }

            Column {
                id: contentColumn

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall

                Label {
                    width: parent.width
                    text: post.name
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                    color: delegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                Label {
                    width: parent.width
                    text: {
                        var text = "";

                        if (page.communityId === 0) {
                            text += "c/" + (modelData.community.name);
                        }

                        var counts = modelData.counts || {};
                        text += " - " + (counts.score || 0) + " " + qsTr("points");
                        text += " - " + (counts.comments || 0) + " " + qsTr("comments");
                        text += " - " + Utils.getRelativeTime(modelData.post.published);

                        return text;
                    }
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
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
}
