import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: sortDialog

    property string selectedSort
    property var options: appWindow.sortOptions
    property string headerTitle

    DialogHeader {
        id: header
        title: headerTitle
    }

    Column {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        width: parent.width

        Repeater {
            model: options

            ListItem {
                id: sortItem
                contentHeight: Theme.itemSizeSmall
                highlighted: modelData.value === selectedSort

                Label {
                    text: modelData.text
                    anchors.centerIn: parent
                    color: sortItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                onClicked: {
                    selectedSort = modelData.value;
                    sortDialog.accept();
                }
            }
        }
    }
}
