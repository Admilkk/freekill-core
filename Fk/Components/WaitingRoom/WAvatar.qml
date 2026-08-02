import QtQuick
import Qt5Compat.GraphicalEffects

import Fk

Item {
  id: root
  height: 64
  width: 64

  property string avatar: ""
  property string screenName: ""

  Rectangle {
    anchors.fill: parent
    anchors.margins: -3
    radius: 5
    color: '#394850'
  }
  
  Rectangle {
    id: avatarImg
    anchors.fill: parent
    radius: 5
    color: '#394850'

    Image {
      id: img
      anchors.fill: parent
      source: SkinBank.getGeneralExtraPic(root.avatar, "avatar/")
      ?? SkinBank.getGeneralPicture(root.avatar)
      sourceClipRect: !!SkinBank.getGeneralExtraPic(root.avatar, "avatar/") ? undefined : Qt.rect(61, 20, 128, 128)
      clip: true
      visible: false
    }
    OpacityMask {
      anchors.fill: img
      source: img
      maskSource: parent
    }
  }

  Rectangle {
    width: parent.width
    height: Math.round(0.25 * root.height)
    anchors.bottom: parent.bottom
    color: "black"
    opacity: 0.5
  }

  Text {
    text: root.screenName
    color: "white"
    width: root.width
    anchors.bottom: parent.bottom
    horizontalAlignment: Text.AlignHCenter
    font.family: Config.libianName
    font.bold: true
  }
}