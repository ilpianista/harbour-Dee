import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.dee 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    LemmyAPI {
        id: api

        Component.onCompleted: {
            // Fetch front-page posts on load
            api.listPosts("");
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
                    api.listCommunities("");
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

        VerticalScrollDecorator {
        }

        header: PageHeader {
            title: qsTr("Subscribed")
        }

        delegate: BackgroundItem {
            id: delegate

            height: contentColumn.height + 2 * Theme.paddingMedium
            onClicked: {
                var post = modelData.post || {
                };
                if (post.id)
                    pageStack.animatorPush(Qt.resolvedUrl("PostPage.qml"), {
                        "api": api,
                        "postId": post.id,
                        "postTitle": post.name || "",
                        "postBody": post.body || ""
                    });

            }

            Column {
                id: contentColumn

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingSmall

                Label {
                    width: parent.width
                    text: {
                        var post = modelData.post || {
                        };
                        return post.name || "";
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                    color: delegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                Label {
                    width: parent.width
                    text: {
                        var community = modelData.community || {
                        };
                        var counts = modelData.counts || {
                        };
                        return (community.name || "") + " - " + (counts.score || 0) + " pts, " + (counts.comments || 0) + " comments";
                    }
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                }

            }

        }

    }

}
