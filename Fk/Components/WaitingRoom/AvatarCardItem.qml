import QtQuick
import Qt5Compat.GraphicalEffects

import Fk
import Fk.Components.GameCommon
import Fk.Components.Common

BasicItem {
  id: root

  width: 170
  height: 115

  property string screenName: ""
  property string avatar: "caocao"
  property bool ready: false
  property real winGame: 0
  property real runGame: 0
  property real totalGame: 0
  property real gameTime: 0

  property real winRate: (winGame / (totalGame ? totalGame : 1) * 100).toFixed(1)
  property real escapeRate: (runGame / (totalGame ? totalGame : 1) * 100).toFixed(1)

  property bool isOwner: false
  property int playerid: 0

  readonly property bool hasPlayer: screenName && playerid !== 0

  Rectangle {
    anchors.fill: parent
    color: '#e8bad8c9'
    radius: 10
    rotation: root.hasPlayer ? 5 : 0
    Behavior on rotation {
      NumberAnimation{ easing.type: Easing.OutCubic; duration: 300 }
    }
  }

  Rectangle {
    anchors.fill: parent
    color: '#efe9e9e6'
    border.width: root.hasPlayer ? 1 : 0
    border.color: '#4e7963'
    radius: 10
    clip: true

    Rectangle {
      width: root.hasPlayer ? parent.width - 2 : 0
      height: 17
      x: 1; y: 9
      color: '#efced5dd'
      Behavior on width {
        NumberAnimation{ easing.type: Easing.OutCubic; duration: 300 }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: '#008165'
      opacity: root.hasPlayer ? 0 : 0.15
      radius: 10
      Behavior on opacity {
        NumberAnimation{ easing.type: Easing.OutCubic; duration: 200 }
      }
    }
  }

  Rectangle {
    anchors.fill: avatarImg
    anchors.margins: -2
    color: '#7c918d'
    radius: 6
    visible: avatarImg.visible
  }

  Rectangle {
    id: avatarImg
    height: 58
    width: 58
    radius: 5
    color: "white"
    visible: root.hasPlayer
    anchors {
      left: parent.left
      top: parent.top
      margins: 10
    }

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

  Text {
    id: screenNameText
    text: root.screenName
    font.pixelSize: 14
    font.family: "Arial"
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignTop
    anchors {
      left: avatarImg.right
      top: avatarImg.top
      right: parent.right
      leftMargin: 10
      rightMargin: 10
    }
  }

  Column {
    anchors {
      top: screenNameText.bottom
      left: avatarImg.right
      right: parent.right
      margins: 10
      topMargin: 5
    }
    height: implicitHeight
    spacing: 4

    Rectangle {
      width: root.ready ? 30 : 40
      height: 16
      anchors.horizontalCenter: parent.horizontalCenter
      radius: 3
      color: root.ready ? '#81aa65' : '#555555'
      visible: root.hasPlayer && !root.isOwner
      Text {
        text: root.ready ? "准备" : "未准备"
        font.bold: true
        anchors.fill: parent
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: 10
      }
      Behavior on width {
        NumberAnimation{ easing.type: Easing.OutCubic; duration: 300 }
      }
    }

    Rectangle {
      width: 30
      height: 16
      anchors.horizontalCenter: parent.horizontalCenter
      radius: 3
      color: '#920707'
      visible: root.isOwner
      Text {
        text: "房主"
        font.bold: true
        anchors.fill: parent
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: 10
      }
    }
  }

  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 1
    width: parent.width - 20
    height: 40
    clip: true
    color: "transparent"
    visible: root.hasPlayer
    Column {
      width: parent.width

      WChatBubble {
        id: chatBubble
        width: parent.width
        z: 9
      }

      Row {
        width: implicitWidth
        Column {
          anchors.bottom: parent.bottom
          width: 50
          Text {
            text: root.escapeRate.toString() + "%"
            font.pixelSize: 14
            font.bold: true
            color: '#212627'
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
          }
          Text {
            text: "逃跑率"
            font.pixelSize: 13
            font.bold: true
            color: '#585858'
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
          }
        }

        Column {
          anchors.bottom: parent.bottom
          width: 50
          Text {
            text: root.winRate.toString() + "%"
            font.pixelSize: 14
            font.bold: true
            color: '#212627'
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
          }
          Text {
            text: "胜率"
            font.pixelSize: 13
            font.bold: true
            color: '#585858'
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
          }
        }

        Column {
          anchors.bottom: parent.bottom
          width: 50
          Text {
            text: (root.gameTime / 3600).toFixed(1).toString() + "h"
            font.pixelSize: 14
            font.bold: true
            color: '#212627'
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
          }
          Text {
            text: "游戏时长"
            font.pixelSize: 13
            font.bold: true
            color: '#585858'
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
          }
        }

      }
    }
  }

  function chat(msg) {
    chatBubble.text = msg;
    chatBubble.show();
  }
}
