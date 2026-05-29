import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"

ApplicationWindow {
    id: appWindow

    property string postTitle: ""
    property int postScore: 0
    property int postComments: 0
    property string currentSort: ""
    property string commentSort: "Hot"

    readonly property var sortOptions: [
        {
            "text": qsTr("Hot"),
            "value": "Hot"
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

    function isImageUrl(url) {
        if (!url || url.trim().length === 0)
            return false;
        // Direct image URLs (allow query/hash)
        if (/^https?:\/\/\S+\.(?:jpe?g|png|gif|webp|avif)(?:\?.*)?(?:#.*)?$/i.test(url))
            return true;
        // Only accept direct imgur image host
        if (/^https?:\/\/i\.imgur\.com\/\S+\.(?:jpe?g|png|gif|webp)(?:\?.*)?(?:#.*)?$/i.test(url))
            return true;
        // Lemmy/pict-rs commonly uses /media/ paths
        if (/^https?:\/\/\S+\/media\/\S+/i.test(url))
            return true;
        return false;
    }

    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    initialPage: Component {
        LoginPage {}
    }
}