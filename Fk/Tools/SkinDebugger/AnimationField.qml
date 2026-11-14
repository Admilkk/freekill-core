import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: root
    property string animationName: ""
    property var animations: []
    property string emptyText: "默认姿势（留空）"
    signal committed(string name)
    editable: true
    textRole: "name"
    valueRole: "name"
    model: [{name: "", duration: 0}].concat(animations)
    currentIndex: {
        for (let i = 0; i < model.length; ++i) if (model[i].name === animationName) return i;
        return -1;
    }
    editText: animationName
    onActivated: committed(currentValue)
    onAccepted: committed(editText.trim())
    onActiveFocusChanged: if (!activeFocus && editText !== animationName) committed(editText.trim())
    delegate: ItemDelegate {
        required property var modelData
        width: root.popup.width
        text: modelData.name ? modelData.name + "  ·  " + Number(modelData.duration).toFixed(2) + " 秒" : root.emptyText
        highlighted: root.highlightedIndex === index
        required property int index
    }
}
