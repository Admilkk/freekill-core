// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.Common

import LunarLtk.Components
import LunarLtk.Models.Popups

pragma ComponentBehavior: Bound

GraphicsBox {
  id: root

  // 因为弹窗在Loader中加载，不能用required. 其他同理
  // 所以这位初始条件会为null 后面比较急迫用到model的地方需要判空
  /* required */ property PoxiModel dataModel

  title.text: dataModel?.promptText

  // TODO: Adjust the UI design in case there are more than 7 cards
  width: 70 + 700
  height: 64 + Math.min(cardView.contentHeight, 400) + 30

  ListView {
    id: cardView
    anchors.fill: parent
    anchors.topMargin: 40
    anchors.leftMargin: 20
    anchors.rightMargin: 20
    anchors.bottomMargin: 30
    spacing: 20
    model: root.dataModel?.cardData ?? []
    clip: true

    delegate: RowLayout {
      id: cardRow
      spacing: 15
      required property var modelData

      Rectangle {
        border.color: "#A6967A"
        radius: 5
        color: "transparent"
        Layout.preferredWidth: 18
        Layout.preferredHeight: 130
        Layout.alignment: Qt.AlignTop

        Text {
          color: "#E4D5A0"
          text: Lua.tr(cardRow.modelData[0])
          anchors.fill: parent
          wrapMode: Text.WrapAnywhere
          verticalAlignment: Text.AlignVCenter
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 15
        }
      }

      GridLayout {
        columns: 7
        Repeater {
          model: cardRow.modelData[1]

          CardItem {
            required property int modelData
            dataModel: root.dataModel.cardModels[modelData]
            autoBack: false
            selectable: chosenInBox || root.dataModel.cardFilter(modelData)

            onSelectedChanged: {
              if (selected) {
                chosenInBox = true;
                root.dataModel.selectedIds.push(modelData);
              } else {
                chosenInBox = false;
                root.dataModel.selectedIds.splice(root.dataModel.selectedIds.indexOf(modelData), 1);
              }
            }
          }
        }
      }
    }
  }

  Row {
    anchors.margins: 8
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 32

    MetroButton {
      width: 120
      height: 35
      text: Lua.tr("OK")
      enabled: root.dataModel?.feasible ?? false
      onClicked: root.dataModel.shuffleAndOk()
    }

    MetroButton {
      width: 120
      height: 35
      text: Lua.tr("Cancel")
      visible: root.dataModel?.cancelable ?? false
      onClicked: root.dataModel.rejected()
    }

    // 反选再说吧 反正逻辑挪到model中
    // MetroButton {
    //   text: Lua.tr("Revert Selection")
    //   onClicked: {
    //     let old_selected = root.selected_ids.slice();
    //     for (let i = 0; i < old_selected.length; i++) {
    //       let cid = old_selected[i];
    //       let item = findCardItem(cid);
    //       item.selected = false;
    //     }
    //     for (let i = 0; i < cardModel.count; i++) {
    //       let cards = cardModel.get(i).areaCards;
    //       for (let j = 0; j < cards.count; j++) {
    //         let card = cards.get(j);
    //         if (old_selected.indexOf(card.cid) === -1 && Ltk.poxiFilter(root.poxi_type, card.cid, root.selected_ids,
    //           root.card_data, root.extra_data)) {
    //           let item = findCardItem(card.cid);
    //           item.selected = true;
    //         }
    //       }
    //     }
    //     root.selected_idsChanged();
    //     refreshPrompt();
    //   }
    // }

  }
}
