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

  title.text: dataModel?.promptText ?? ""

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

      PoxiLabel {
        Layout.alignment: Qt.AlignVCenter
        text: Lua.tr(cardRow.modelData[0])
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
  }
}
