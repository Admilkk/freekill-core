// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.Common

import LunarLtk.Components
import LunarLtk.Models
import LunarLtk.Models.Popups

pragma ComponentBehavior: Bound

GraphicsBox {
  id: root
  // property var cards: []
  // property var cardsPosition: []
  // property var generalNames: []
  property MoveCardInBoardModel dataModel
  property alias cardsPosition: root.dataModel.cardsPosition
  property alias generalNames: root.dataModel.generalNames
  property var result: {}

  property int padding: 25

  title.text: Lua.tr("Please click to move card")
  width: body.width + padding * 2
  height: title.height + body.height + padding * 2

  ColumnLayout {
    id: body
    x: root.padding
    y: parent.height - root.padding - height
    spacing: 20

    Repeater {
      id: areaRepeater
      model: root.generalNames

      Row {
        id: cardRow
        spacing: 5
        required property var modelData

        PoxiLabel {
          Layout.alignment: Qt.AlignVCenter
          text: Lua.tr(cardRow.modelData)
        }

        Repeater {
          id: cardRepeater
          model: root.dataModel.cardModels

          Rectangle {
            required property CardModel modelData
            id: cardBox
            color: "#4A4139"
            width: 93
            height: 130
            opacity: 0.5

            Text {
              horizontalAlignment: Text.AlignHCenter
              anchors.centerIn: parent
              text: Lua.tr(cardBox.modelData.subtype)
              color: "#90765F"
              font.family: Config.libianName
              font.pixelSize: 16
              width: parent.width * 0.8
              wrapMode: Text.WordWrap
            }
          }
        }
        property alias cardRepeater: cardRepeater
      }
    }

    MetroButton {
      Layout.alignment: Qt.AlignHCenter
      id: buttonConfirm
      text: Lua.tr("OK")
      implicitWidth: 120
      implicitHeight: 35
      enabled: false

      onClicked: root.dataModel.accepted();
    }
  }

  Repeater {
    id: cardItem
    model: root.dataModel.cardModels

    CardItem {
      required property int index
      required property CardModel modelData
      x: index
      y: -1
      dataModel: modelData

      selectable: !root.result || root.result.item === this
      onClicked: {
        if (!selectable) return;
        if ((root.result || {}).item === this) {
          root.result = undefined;
        } else {
          root.result = { item: this };
        }

        root.updatePosition(this);
      }
    }
  }

  function arrangeCards() {
    for (let i = 0; i < root.dataModel.cardModels.length; i++) {
      const curCard = cardItem.itemAt(i);
      curCard.origX = i * 98 + 50;
      curCard.origY = cardsPosition[i] * 150 + body.y;
      curCard.goBack();
    }
  }

  function updatePosition(item) {
    for (let i = 0; i < 2; i++) {
      const index = root.dataModel.cardModels.findIndex(data => item.cid === data.cid);
      result && (result.pos = cardsPosition[index]);

      const cardPos = cardsPosition[index] === 0 ? (result ? 1 : 0)
                                                 : (result ? 0 : 1);
      const curArea = areaRepeater.itemAt(cardPos);
      const curBox = curArea.cardRepeater.itemAt(index);
      const curPos = mapFromItem(curArea, curBox.x, curBox.y);

      item.origX = curPos.x;
      item.origY = curPos.y;
      item.goBack(true);

      buttonConfirm.enabled = !!result;
    }
  }

  function getResult() {
    return result ? { cardId: result.item.cid, pos: result.pos } : '';
  }
}
