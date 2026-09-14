import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: selectionDialog

    property string selectedValue
    property var options
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
                id: selectionItem
                contentHeight: Theme.itemSizeSmall
                highlighted: modelData.value === selectedValue

                Label {
                    text: modelData.text
                    anchors.centerIn: parent
                    color: selectionItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                onClicked: {
                    selectedValue = modelData.value;
                    selectionDialog.accept();
                }
            }
        }
    }
}
