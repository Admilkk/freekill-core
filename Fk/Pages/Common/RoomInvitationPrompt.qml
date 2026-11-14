// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Fk
import Fk.Components.WaitingRoom

Popup {
  id: root
  objectName: "roomInvitationPrompt"
  readonly property real uiScale: 0.8
  anchors.centerIn: parent
  width: Math.min(440 * uiScale, parent.width - 24)
  height: Math.min(content.implicitHeight + padding * 2, 360 * uiScale, parent.height - 24)
  padding: 24 * uiScale
  // RootPage creates this popup before ClientInstance exists. Translate again when opened.
  function tr(key) { return visible ? Lua.tr(key) : key; }
  modal: true
  closePolicy: Popup.NoAutoClose
  background: Rectangle {
    radius: 10 * root.uiScale; color: "#f2f6f3"
    border.color: "#8eb1ab"; border.width: 2
  }
  Connections {
    target: RoomInvites
    function onCurrentInvitationChanged() {
      if (RoomInvites.currentInvitation) root.open(); else root.close();
    }
  }
  Component.onCompleted: { if (RoomInvites.currentInvitation) open(); }
  contentItem: ColumnLayout {
    id: content
    spacing: 14 * root.uiScale
    Text {
      objectName: "roomInvitationTitle"
      text: root.tr("Room Invitation")
      font.pixelSize: 23 * root.uiScale; font.bold: true; color: "#42685f"
      Layout.alignment: Qt.AlignHCenter
    }
    Text {
      Layout.fillWidth: true
      text: root.tr("%1 invites you to a room").arg(RoomInvites.currentInvitation?.inviterName || "")
      textFormat: Text.PlainText
      font.pixelSize: 18 * root.uiScale; color: "#2f4941"
      wrapMode: Text.WrapAnywhere
      maximumLineCount: 2; elide: Text.ElideRight
    }
    Text {
      Layout.fillWidth: true
      text: root.tr("Room: %1").arg(RoomInvites.currentInvitation?.roomName || "")
      textFormat: Text.PlainText
      font.pixelSize: 17 * root.uiScale; color: "#2f4941"
      wrapMode: Text.WrapAnywhere
      maximumLineCount: 2; elide: Text.ElideRight
    }
    Text {
      Layout.fillWidth: true
      text: root.tr("Mode: %1").arg(root.tr(RoomInvites.currentInvitation?.mode || ""))
      textFormat: Text.PlainText
      font.pixelSize: 17 * root.uiScale; color: "#2f4941"
      wrapMode: Text.WrapAnywhere
      maximumLineCount: 2; elide: Text.ElideRight
    }
    Text {
      objectName: "roomInvitationHint"
      Layout.fillWidth: true
      text: root.tr("Accept to join; no password needed. Spectate if full or started.")
      font.pixelSize: 14 * root.uiScale; color: "#617d75"
      wrapMode: Text.Wrap
    }
    Item {
      objectName: "roomInvitationButtonGap"
      Layout.preferredHeight: 32 * root.uiScale
      Layout.minimumHeight: 0
      Layout.fillHeight: true
      Layout.maximumHeight: Layout.preferredHeight
    }
    RowLayout {
      Layout.alignment: Qt.AlignRight
      spacing: 12 * root.uiScale
      WButton {
        objectName: "declineRoomInvitation"
        Layout.preferredWidth: 100 * root.uiScale; Layout.preferredHeight: 38 * root.uiScale
        text: root.tr("Decline")
        textFont.pixelSize: 18 * root.uiScale
        property string invitationToken: ""
        onPressedChanged: { if (pressed) invitationToken = RoomInvites.currentInvitation?.token || ""; }
        onClicked: RoomInvites.respond(false, invitationToken)
      }
      WButton {
        objectName: "acceptRoomInvitation"
        Layout.preferredWidth: 100 * root.uiScale; Layout.preferredHeight: 38 * root.uiScale
        text: root.tr("OK")
        textFont.pixelSize: 18 * root.uiScale
        title.color: "#f4faf6"; bg.color: "#8eb1ab"; border.width: 0
        property string invitationToken: ""
        onPressedChanged: { if (pressed) invitationToken = RoomInvites.currentInvitation?.token || ""; }
        onClicked: RoomInvites.respond(true, invitationToken)
      }
    }
  }
}
