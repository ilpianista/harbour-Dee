import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.dee 1.0

Page {
    property var api
    property int postId
    property int parentId
    property string previewText

    // Internal state
    property bool submitting: false

    function submit() {
        submitting = true;
        var jsonObj = {
            "post_id": postId,
            "content": comment.text.trim()
        };
        if (parentId > 0) {
            jsonObj.parent_id = parentId;
        }
        var jsonParams = JSON.stringify(jsonObj);
        api.createComment(postId, comment.text.trim(), parentId);
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        VerticalScrollDecorator {}

        Column {
            id: column

            x: Theme.horizontalPageMargin
            width: parent.width - Theme.horizontalPageMargin * 2
            spacing: Theme.paddingLarge

            SectionHeader {
                text: parentId === 0 ? qsTr("Reply to post") : qsTr("Reply to comment")
            }

            Label {
                width: parent.width
                text: previewText
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 5
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                opacity: previewText ? 0.8 : 0.0
                visible: previewText.length > 0
            }

            TextArea {
                id: comment

                width: parent.width
                focus: true
                placeholderText: qsTr("Type here to comment…")
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            Button {
                width: parent.width
                text: parentId === 0 ? qsTr("Post") : qsTr("Reply")
                enabled: !submitting && comment.text.trim().length > 0
                onClicked: submit()
            }
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: submitting
    }

    Label {
        id: error

        x: Theme.horizontalPageMargin
        width: parent.width - 2 * Theme.horizontalPageMargin
        wrapMode: Text.Wrap
        color: Theme.errorColor
        visible: text.length > 0
    }

    Connections {
        target: api
        onRequestFinished: {
            if (method === "createComment") {
                comment.text = "";
                submitting = false;
                pageStack.pop();
            }
        }

        onRequestFailed: {
            if (method === "createComment") {
                error.text = message;
                submitting = false;
            }
        }
    }
}
