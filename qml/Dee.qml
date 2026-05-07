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
        return /^https?:\/\/\S+\.(jpe?g|png|gif|webp|avif)/i.test(url) ||
               /^https?:\/\/(i\.|www\.)?imgur\.com\//.test(url) ||
               /^https?:\/\/\S+\/media\//.test(url);
    }

    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    initialPage: Component {
        LoginPage {}
    }
}
