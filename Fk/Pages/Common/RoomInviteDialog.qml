// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Fk
import Fk.Components.WaitingRoom

Popup {
  id: root
  objectName: "roomInviteDialog"
  readonly property real uiScale: 0.8
  width: Math.min(420 * uiScale, parent.width - 24)
  height: Math.min(470 * uiScale, parent.height - 24)
  x: (parent.width - width) / 2
  y: (parent.height - height) / 2
  padding: 16 * uiScale
  function tr(key) { return visible ? Lua.tr(key) : key; }
  modal: false
  closePolicy: Popup.CloseOnEscape
  background: Rectangle {
    radius: 10 * root.uiScale
    color: "#f2f6f3"
    border.color: "#8eb1ab"
    border.width: 2
  }
  onOpened: RoomInvites.subscribe(true)
  onClosed: RoomInvites.subscribe(false)
  Connections {
    target: RoomInvites
    function onCanInviteChanged() { if (!RoomInvites.canInvite) root.close(); }
  }

  contentItem: ColumnLayout {
    spacing: 12 * root.uiScale
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: 36 * root.uiScale
      MouseArea {
        objectName: "roomInviteDragArea"
        anchors.fill: parent
        anchors.rightMargin: 46 * root.uiScale
        cursorShape: Qt.SizeAllCursor
        property point origin
        onPressed: mouse => { origin = mapToItem(root.parent, mouse.x, mouse.y); }
        onPositionChanged: mouse => {
          if (!pressed) return;
          const point = mapToItem(root.parent, mouse.x, mouse.y);
          root.x = Math.max(0, Math.min(root.parent.width - root.width, root.x + point.x - origin.x));
          root.y = Math.max(0, Math.min(root.parent.height - root.height, root.y + point.y - origin.y));
          origin = point;
        }
      }
      Text {
        objectName: "roomInviteDialogTitle"
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.tr("Invite Players")
        font.pixelSize: 22 * root.uiScale
        font.bold: true
        color: "#42685f"
      }
      WButton {
        objectName: "roomInviteCloseButton"
        anchors.right: parent.right
        width: 36 * root.uiScale; height: 32 * root.uiScale
        text: "×"
        textFont.pixelSize: 24 * root.uiScale
        onClicked: root.close()
      }
    }
    Text {
      Layout.fillWidth: true
      text: root.tr("Online players in the lobby · updates automatically")
      font.pixelSize: 14 * root.uiScale
      color: "#617d75"
      wrapMode: Text.Wrap
    }
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1 * root.uiScale; color: "#cadbd4" }
    ListView {
      id: list
      objectName: "roomInvitePlayerList"
      Layout.fillWidth: true
      Layout.fillHeight: true
      model: RoomInvites.players
      clip: true
      spacing: 8 * root.uiScale
      ScrollBar.vertical: ScrollBar {}
      delegate: Rectangle {
        id: row
        required property var modelData
        width: list.width - 12 * root.uiScale
        height: 52 * root.uiScale
        radius: 6 * root.uiScale
        color: "#e3ece6"
        Text {
          anchors.left: parent.left
          anchors.leftMargin: 12 * root.uiScale
          anchors.right: inviteButton.left
          anchors.rightMargin: 8 * root.uiScale
          anchors.verticalCenter: parent.verticalCenter
          text: row.modelData.name
          textFormat: Text.PlainText
          font.pixelSize: 18 * root.uiScale
          color: "#2f4941"
          elide: Text.ElideRight
        }
        WButton {
          id: inviteButton
          objectName: "invitePlayer_" + row.modelData.id
          anchors.right: parent.right
          anchors.rightMargin: 8 * root.uiScale
          anchors.verticalCenter: parent.verticalCenter
          width: 118 * root.uiScale; height: 34 * root.uiScale
          property int remaining: RoomInvites.remaining(row.modelData.id)
          property bool pending: !!RoomInvites.pendingPlayers[String(row.modelData.id)]
          enabled: !pending && remaining === 0
          text: pending ? root.tr("Inviting...") : remaining ? root.tr("Invited (%1s)").arg(remaining) : root.tr("Invite")
          textFont.pixelSize: 16 * root.uiScale
          title.color: "#f4faf6"
          bg.color: "#8eb1ab"
          bg.radius: 6 * root.uiScale
          border.width: 0
          onClicked: RoomInvites.invite(row.modelData.id)
        }
      }
      Text {
        anchors.centerIn: parent
        width: parent.width - 24 * root.uiScale
        visible: list.count === 0
        text: RoomInvites.listError || root.tr("No players available to invite")
        textFormat: Text.PlainText
        font.pixelSize: 14 * root.uiScale
        color: "#617d75"
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
      }
    }
    Text {
      Layout.fillWidth: true
      text: root.tr("Drag the header to move · invite again after 5 seconds")
      color: "#617d75"
      font.pixelSize: 13 * root.uiScale
      wrapMode: Text.Wrap
    }
  }
}
