import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.dee 1.0
import "../lib/Utils.js" as Utils

Page {
    id: page

    property int communityId: 0
    property string pageTitle: ""
    property string communitySubscribed: "NotSubscribed"
    property string communityHandle: ""
    property bool postingRestrictedToMods: false
    property bool isCommunityModerator: false
    property int postMyVote: 0
    property int postComments: 0
    property int postScore: 0
    property string postTitle: ""

    function isSubscribed() {
        return communitySubscribed === "Subscribed";
    }

    function updateModeratorStatus(result) {
        var myPersonId = api.siteInfo.my_user ? api.siteInfo.my_user.local_user_view.person.id : -1;
        var mods = result.moderators || [];
        isCommunityModerator = false;
        for (var i = 0; i < mods.length; i++) {
            if (mods[i].moderator && mods[i].moderator.id === myPersonId) {
                isCommunityModerator = true;
                break;
            }
        }
    }

    function refresh() {
        var params = {
            "limit": 50,
            "sort": appWindow.currentSort
        };
        if (communityId > 0)
            params.community_id = communityId;
        else
            params.type_ = appWindow.listingType;

        api.listPosts(JSON.stringify(params));
    }

    function setSort(sortType) {
        appWindow.currentSort = sortType;
        api.currentSort = sortType;
        refresh();
    }

    function setListingType(type) {
        appWindow.listingType = type;
        api.listingType = type;
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

    property var api: appWindow.api

    Component.onCompleted: {
        api.setPostsModel(posts);
        appWindow.currentSort = api.currentSort;
        appWindow.listingType = api.listingType;
        var params = {
            "limit": 50,
            "sort": appWindow.currentSort
        };
        if (communityId > 0) {
            params.community_id = communityId;
            api.getCommunity(JSON.stringify({
                "id": communityId
            }));
        } else {
            params.type_ = appWindow.listingType;
        }

        api.listPosts(JSON.stringify(params));
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
                    var dialog = pageStack.push(Qt.resolvedUrl("SelectionDialog.qml"), {
                        "selectedValue": appWindow.currentSort,
                        "options": appWindow.sortOptions,
                        "headerTitle": qsTr("Sort posts")
                    });
                    dialog.accepted.connect(function () {
                        setSort(dialog.selectedValue);
                    });
                }
            }

            MenuItem {
                text: qsTr("Feed") + ": " + appWindow.listingTypeLabel(appWindow.listingType)
                visible: communityId === 0
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("SelectionDialog.qml"), {
                        "selectedValue": appWindow.listingType,
                        "options": appWindow.listingTypeOptions,
                        "headerTitle": qsTr("Feed")
                    });
                    dialog.accepted.connect(function () {
                        setListingType(dialog.selectedValue);
                    });
                }
            }

            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("SettingsPage.qml"), {
                    "api": api
                })
                visible: communityId === 0
            }

            MenuItem {
                text: isSubscribed() ? qsTr("Unsubscribe") : qsTr("Subscribe")
                visible: communityId > 0
                onClicked: {
                    api.followCommunity(JSON.stringify({
                        "community_id": communityId,
                        "follow": !isSubscribed()
                    }));
                }
            }

            MenuItem {
                text: qsTr("Create post")
                visible: communityId > 0
                enabled: !postingRestrictedToMods || isCommunityModerator
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("NewPostPage.qml"), {
                    "api": api,
                    "communityId": communityId,
                    "communityName": communityHandle
                })
            }

            MenuItem {
                text: qsTr("Inbox") + (api.unreadCount > 0 ? " (" + api.unreadCount + ")" : "")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("InboxPage.qml"), {
                    "api": api
                })
                visible: communityId === 0
            }

            MenuItem {
                text: qsTr("Home")
                visible: communityId > 0
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("SubscribedPage.qml"))
            }

            MenuItem {
                text: qsTr("Communities")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("CommunitiesPage.qml"), {
                    "api": api
                })
                visible: communityId === 0
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
            title: communityId > 0 ? pageTitle : qsTr("Home")
            description: communityId > 0 ? communityHandle : ""
        }

        footer: LoadingFooter {
            busy: api.busy
            itemCount: listView.count
        }

        delegate: ListItem {
            id: delegate

            property var post: postData.post
            property var community: postData.community || {}
            property var counts: postData.counts || {}
            property int myVote: postData.my_vote ? postData.my_vote : 0

            menu: contextMenu
            contentHeight: contentColumn.height + 2 * Theme.paddingMedium

            function openPost() {
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

            onClicked: openPost()

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

                Item {
                    id: fullMediaBox
                    visible: AppSettings.fullSizeMediaEnabled && !!post.thumbnail_url
                    width: parent.width
                    height: visible ? width * 3 / 4 : 0

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.rgba(Theme.highlightBackgroundColor, 0.08)
                        radius: Theme.paddingSmall
                    }

                    Thumbnail {
                        id: fullMedia
                        width: parent.width
                        height: parent.height
                        fillMode: Image.PreserveAspectFit
                        imageUrl: post.thumbnail_url || ""
                        onClicked: delegate.openPost()
                    }
                }

                Row {
                    spacing: Theme.paddingSmall

                    Row {
                        spacing: Theme.paddingSmall
                        visible: page.communityId === 0

                        Label {
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

                    Label {
                        text: "·"
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: delegate.highlighted ? Theme.highlightColor : Theme.secondaryColor
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
                        visible: counts.comments > 0
                        text: "·"
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: delegate.highlighted ? Theme.highlightColor : Theme.secondaryColor
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
                imageUrl: post.thumbnail_url || ""
                visible: !!post.thumbnail_url && !AppSettings.fullSizeMediaEnabled
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: Theme.paddingMedium
                }
                onClicked: delegate.openPost()
            }
        }
    }

    Connections {
        target: api
        onRequestFinished: {
            if (method === "likePost" || method === "getPost") {
                Utils.applyPostViewResult(result, page, appWindow, api);
            } else if (method === "getCommunity") {
                var cv = result.community_view;
                if (cv) {
                    communitySubscribed = cv.subscribed || "NotSubscribed";
                    var community = cv.community;
                    if (community) {
                        pageTitle = community.title || community.name;
                        communityHandle = Utils.resolveCommunityHandle(community.actor_id || "");
                        postingRestrictedToMods = community.posting_restricted_to_mods || false;
                    }
                    updateModeratorStatus(result);
                }
            } else if (method === "followCommunity") {
                var cv = result.community_view;
                if (cv) {
                    communitySubscribed = cv.subscribed || "NotSubscribed";
                    var community = cv.community;
                    if (community)
                        postingRestrictedToMods = community.posting_restricted_to_mods || false;
                    updateModeratorStatus(result);
                }
            } else if (method === "createPost") {
                refresh();
            }
        }
    }
}
