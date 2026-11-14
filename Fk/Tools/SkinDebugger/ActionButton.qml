import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Button {
    implicitHeight: 34
    implicitWidth: Math.max(58, contentItem.implicitWidth + 20)
    Layout.minimumWidth: 0
}
