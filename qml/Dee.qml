import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Notifications 1.0
import harbour.dee 1.0
import "pages"

ApplicationWindow {
    id: appWindow

    property string postTitle: ""
    property int postScore: 0
    property int postComments: 0
    property string currentSort: ""
    property string commentSort: "Hot"
    property string listingType: ""

    readonly property var sortOptions: [
        {
            "text": qsTr("Hot"),
            "value": "Hot"
        },
        {
            "text": qsTr("Scaled"),
            "value": "Scaled",
        },
        {
            "text": qsTr("Active"),
            "value": "Active"
        },
        {
            "text": qsTr("Controversial"),
            "value": "Controversial"
        },
        {
            "text": qsTr("New"),
            "value": "New"
        },
        {
            "text": qsTr("Most Comments"),
            "value": "MostComments"
        },
        {
            "text": qsTr("New Comments"),
            "value": "NewComments"
        },
        {
            "text": qsTr("Top Day"),
            "value": "TopDay"
        },
        {
            "text": qsTr("Top Week"),
            "value": "TopWeek"
        },
        {
            "text": qsTr("Top Month"),
            "value": "TopMonth"
        },
        {
            "text": qsTr("Top Year"),
            "value": "TopYear"
        },
        {
            "text": qsTr("Top All Time"),
            "value": "TopAll"
        }
    ]

    function sortLabel(value) {
        for (var i = 0; i < sortOptions.length; i++) {
            if (sortOptions[i].value === value)
                return sortOptions[i].text;
        }
        return value;
    }

    readonly property var commentSortOptions: [
        {
            "text": qsTr("Hot"),
            "value": "Hot"
        },
        {
            "text": qsTr("Top"),
            "value": "Top"
        },
        {
            "text": qsTr("New"),
            "value": "New"
        },
        {
            "text": qsTr("Old"),
            "value": "Old"
        }
    ]

    function commentSortLabel(value) {
        for (var i = 0; i < commentSortOptions.length; i++) {
            if (commentSortOptions[i].value === value)
                return commentSortOptions[i].text;
        }
        return value;
    }

    readonly property var listingTypeOptions: [
        {
            "text": qsTr("Subscribed"),
            "value": "Subscribed"
        },
        {
            "text": qsTr("Local"),
            "value": "Local"
        },
        {
            "text": qsTr("All"),
            "value": "All"
        }
    ]

    function listingTypeLabel(value) {
        for (var i = 0; i < listingTypeOptions.length; i++) {
            if (listingTypeOptions[i].value === value)
                return listingTypeOptions[i].text;
        }
        return value;
    }

    LemmyAPI {
        id: _api
    }

    property alias api: _api

    Notification {
        id: systemNotification
        appName: "Dee"
        icon: "harbour-dee"
        category: "x-harbour.dee.notification"
        summary: qsTr("New messages")
        remoteActions: [
            {
                "name": "default"
            }
        ]
        onClicked: {
            appWindow.activate();
            pageStack.animatorPush(Qt.resolvedUrl("InboxPage.qml"), {
                "api": api
            });
        }
    }

    Connections {
        target: _api
        onNewNotificationsReceived: {
            systemNotification.body = count === 1 ? qsTr("1 unread message") : qsTr("%1 unread messages").arg(count);
            systemNotification.publish();
        }
    }

    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    initialPage: Component {
        LoginPage {}
    }
}
