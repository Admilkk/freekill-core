// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

Item {
  id: root

  property alias title: titleItem
  property alias background: background
  signal accepted() //Read result
  signal finished() //Close the box

  signal shown() // 对话框刚刚展示时触发的信号

  Rectangle {
    id: background
    anchors.fill: parent
    color: "#020302"
    opacity: 0.8
    radius: 5
    border.color: "#A6967A"
    border.width: 1
  }

  Text {
    id: titleItem
    color: "#E4D5A0"
    font.pixelSize: 18
    horizontalAlignment: Text.AlignHCenter
    anchors.top: parent.top
    anchors.topMargin: 4
    anchors.horizontalCenter: parent.horizontalCenter
  }

  DragHandler {
    enabled: background.visible
    grabPermissions: PointHandler.TakeOverForbidden
    xAxis.enabled: true
    yAxis.enabled: true
  }

  function close()
  {
    accepted();
    finished();
  }
}
