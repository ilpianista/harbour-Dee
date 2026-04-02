import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.dee 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    LemmyAPI {
        id: api

        Component.onCompleted: {
            var params = JSON.stringify({
                "limit": 50
            });
            api.listPosts(params);
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
                text: qsTr("Communities")
                onClicked: {
                    pageStack.animatorPush(Qt.resolvedUrl("CommunitiesPage.qml"), {
                        "api": api
                    });
                }
            }

            MenuItem {
                text: qsTr("Refresh")
                onClicked: {
                    api.listPosts("");
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
            title: qsTr("Subscribed")
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
                        var community = modelData.community || {};
                        var counts = modelData.counts || {};
                        return "c/" + (community.name || "") + " - " + (counts.score || 0) + " " + qsTr("points") + " - " + (counts.comments || 0) + " " + qsTr("comments");
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
