import QtQuick
import QtQuick.Controls.Basic

TextField {
    id: root
    property real value: 0
    property real minimum: -100
    property real maximum: 100
    property int decimals: 4
    signal committed(real number)
    implicitHeight: 34
    selectByMouse: true
    text: Number(value.toFixed(decimals)).toString()
    validator: DoubleValidator { bottom: root.minimum; top: root.maximum; locale: "C" }
    onEditingFinished: {
        const number = Number(text);
        if (text.trim() && isFinite(number) && number >= minimum && number <= maximum)
            committed(number);
        text = Qt.binding(function() { return Number(root.value.toFixed(root.decimals)).toString(); });
    }
}
