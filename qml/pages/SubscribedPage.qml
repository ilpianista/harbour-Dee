import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.dee 1.0

Page {
    id: page

    property int communityId: 0
    property string pageTitle: ""

    function refresh() {
        var params = {
            "limit": 50,
            "sort": appWindow.currentSort
        };
        if (communityId > 0)
            params.community_id = communityId;

        api.listPosts(JSON.stringify(params));
    }

    function setSort(sortType) {
        appWindow.currentSort = sortType;
        api.currentSort = sortType;
        refresh();
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
            appWindow.currentSort = api.currentSort;
            var params = {
                "limit": 50,
                "sort": appWindow.currentSort
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
                text: qsTr("Sort") + ": " + appWindow.sortLabel(appWindow.currentSort)
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("SortDialog.qml"), {
                        "selectedSort": appWindow.currentSort,
                        "headerTitle": qsTr("Sort posts")
                    });
                    dialog.accepted.connect(function () {
                        setSort(dialog.selectedSort);
                    });
                }
            }

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
                        "postMyVote": postData.my_vote ? postData.my_vote : 0,
                        "postLocked": post.locked
                    });
            }

            Column {
                id: contentColumn

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin - (thumbnail.visible ? thumbnail.width + Theme.paddingMedium : 0)
                spacing: Theme.paddingSmall

                Row {
                    width: parent.width
                    spacing: Theme.paddingSmall

                    Image {
                        visible: post.featured_community
                        source: "image://theme/icon-s-high-importance"
                    }

                    Image {
                        visible: post.locked
                        source: "image://theme/icon-s-secure"
                    }

                    Label {
                        width: parent.width - (post.featured_community ? (Theme.iconSizeSmall + Theme.paddingSmall) : 0) - (post.locked ? (Theme.iconSizeSmall + Theme.paddingSmall) : 0)
                        text: post.name || ""
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                        color: delegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                    }
                }

                Label {
                    visible: post.url ? (post.url.length > 0 && !/\s*$/.test(post.url)) : false
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

                    Row {
                        spacing: Theme.paddingSmall
                        Label {
                            visible: page.communityId === 0
                            text: "c/" + (community.name || "")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: delegate.highlighted ? Theme.highlightColor : Theme.secondaryHighlightColor
                        }

                        Label {
                            text: "·"
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: delegate.highlighted ? Theme.highlightColor : Theme.secondaryColor
                        }
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

                                return s;
                            }
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: myVote > 0 ? Theme.highlightColor : myVote < 0 ? Theme.highlightDimmerColor : delegate.highlighted ? Theme.highlightColor : Theme.secondaryColor
                        }

                        Image {
                            source: "image://theme/icon-s-like"
                            width: Theme.iconSizeExtraSmall
                            height: Theme.iconSizeExtraSmall
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: 0.7
                        }
                    }

                    Row {
                        visible: counts.comments > 0
                        spacing: Theme.paddingSmall

                        Label {
                            text: counts.comments
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: delegate.highlighted ? Theme.highlightColor : Theme.secondaryColor
                        }

                        Image {
                            source: "image://theme/icon-s-chat"
                            width: Theme.iconSizeExtraSmall
                            height: Theme.iconSizeExtraSmall
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: 0.7
                        }
                    }

                    Label {
                        text: Format.formatDate(post.published, Formatter.DurationElapsed)
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: delegate.highlighted ? Theme.highlightColor : Theme.secondaryColor
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

            Thumbnail {
                id: thumbnail
                imageUrl: post.thumbnail_url || post.url
                visible: appWindow.isImageUrl(thumbnail.imageUrl)
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: Theme.paddingMedium
                }
                onClicked: {
                    pageStack.pushAttached(Qt.resolvedUrl("PostWebView.qml"), {
                        "postUrl": post.url,
                        "postTitle": post.name
                    });
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