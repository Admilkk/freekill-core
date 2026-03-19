// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk
import Fk.Components.Common

import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Components
import LunarLtk.Models.Popups

pragma ComponentBehavior: Bound

GraphicsBox {
  id: root

  property GeneralsModel dataModel

  property alias generalCardList: generalCardList

  property var draggingCard: null

  title.text: dataModel?.promptText ?? ""
  width: generalArea.width + body.anchors.leftMargin + body.anchors.rightMargin
  height: body.implicitHeight + body.anchors.topMargin +
          body.anchors.bottomMargin

  Column {
    id: body
    anchors.fill: parent
    anchors.margins: 40
    anchors.bottomMargin: 20

    Item {
      id: generalArea
      width: {
        const count = root.dataModel?.generals?.length ?? 0;
        return (count > 8 ? Math.ceil(count / 2) : Math.max(3, count)) * 97;
      }
      height: (root.dataModel?.generals?.length ?? 0) > 8 ? 290 : 150
      z: 1

      Repeater {
        id: generalMagnetList
        model: root.dataModel?.generals?.length ?? 0

        Item {
          required property int index
          width: 93
          height: 130
          x: {
            const count = root.dataModel?.generals?.length ?? 0;
            let columns = count;
            if (columns > 8) {
              columns = Math.ceil(columns / 2);
            }

            let ret = (index % columns) * 98;
            if (count > 8 && index > count / 2 && count % 2 == 1)
              ret += 50;
            return ret;
          }
          y: {
            const count = root.dataModel?.generals?.length ?? 0;
            if (count <= 8)
              return 0;
            return index < count / 2 ? 0 : 135;
          }
        }
      }
    }

    Item {
      id: splitLine
      width: parent.width - 80
      height: 6
      anchors.horizontalCenter: parent.horizontalCenter
      clip: true
    }

    Item {
      width: parent.width
      height: 165

      Row {
        id: resultArea
        anchors.centerIn: parent
        spacing: 10

        Repeater {
          id: resultList
          model: root.dataModel?.choiceNum ?? 1

          Rectangle {
            color: "#1D1E19"
            radius: 3
            width: 93
            height: 130
          }
        }
      }
    }

    Item {
      id: buttonArea
      width: parent.width
      height: 40

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: 8

        MetroButton {
          id: convertBtn
          visible: !root.dataModel?.convertDisabled
          enabled: root.dataModel?.canConvert ?? false
          text: Lua.tr("Same General Convert")
          onClicked: {
            roomScene.startCheat("SameConvert", { cards: generalCardList.model, choices: root.dataModel?.result });
          }
        }

        MetroButton {
          id: fightButton
          text: Lua.tr("OK")
          width: 120
          height: 35
          enabled: root.dataModel?.feasible ?? false;

          onClicked: root.dataModel?.accepted();
        }

        MetroButton {
          id: detailBtn
          enabled: !root.dataModel?.isAllEmpty() ?? false
          text: Lua.tr("Show General Detail")
          onClicked: roomScene.startCheat(
            "GeneralDetail",
            { generals: root.dataModel?.result }
          );
        }
      }
    }
  }

  Repeater {
    id: generalCardList
    model: root.dataModel?.generals ?? []

    GeneralCardItem {
      required property string modelData
      required property int index
      dataModel: root.dataModel?.generalDict?.[modelData]
      selectable: {
        const result = root.dataModel?.result;
        if (result) {
          return result.includes(modelData) || root.dataModel.generalFilter(modelData) || false;
        }
        return false;
      }
      draggable: !root.draggingCard || root.draggingCard === this

      onClicked: {
        if (!selectable) return;
        root.dataModel?.toggleResult(modelData);
        root.arrangeCards();
      }

      onRightClicked: {
        if (root.dataModel?.result.findIndex(e => e === modelData) === -1 && Lua.client.getSettings("enableFreeAssign"))
          roomScene.startCheat("FreeAssign", { card: this });
      }

      onDataModelChanged: {
        root.dataModel.reloadGeneralModels();
        root.arrangeCards();
      }

      opacity: dragging ? 0.5 : 1
      onDraggingChanged: {
        if (dragging) root.draggingCard = this;
      }
      onXChanged : {
        if (!dragging) return;
        root.arrangeCards();
      }
      onYChanged : {
        if (!dragging) return;
        root.arrangeCards();
      }
      onReleased: {
        root.updateCardDragging(this);
        root.draggingCard = null;
        root.arrangeCards();
      }
    }
  }

  function updateCardDragging(item) {
    const name = item.dataModel.name;
    if (item.y > splitLine.y && item.selectable) {
      let i, magnet, pos, itemdiff;
      let diff = 17308, idx = -1;
      for (i = 0; i < resultList.count; i++) {
        magnet = resultList.itemAt(i);
        pos = root.mapFromItem(resultArea, magnet.x, magnet.y);
        itemdiff = Math.max(Math.abs(pos.x - item.x), Math.abs(pos.y - item.y));
        if (itemdiff < diff) {
          diff = itemdiff;
          idx = i;
        };
      }
      if (diff < 50) {
        root.dataModel.moveGeneral(name, true, idx);
      } else {
        root.dataModel.moveGeneral(name, false);
      }
    } else {
      root.dataModel.moveGeneral(name, false);
    }
  }

  function updateCompanion(gcard1, gcard2, overwrite) {
    if (Ltk.isCompanionWith(gcard1.name, gcard1.name)) {
      gcard1.hasCompanions = true;
    } else if (overwrite) {
      gcard1.hasCompanions = false;
    }
  }

  function arrangeCards() {
    if (!root.dataModel) return;
    let item, magnet, pos, i;
    magnet = resultList.itemAt(i);
    pos = root.mapFromItem(resultArea, magnet.x, magnet.y);

    for (i = 0; i < generalMagnetList.count; i++) {
      item = generalCardList.itemAt(i);
      if (!item) break;
      if (item.dragging) {
        item.z = 999;
        continue;
      }
      const resultIdx = root.dataModel.result.findIndex(e => e === item.dataModel.name);
      if (resultIdx !== -1) {
        magnet = resultList.itemAt(resultIdx);
        pos = root.mapFromItem(resultArea, magnet.x, magnet.y);
      } else {
        magnet = generalMagnetList.itemAt(i);
        pos = root.mapFromItem(generalMagnetList.parent, magnet.x, magnet.y);
      }
      item.origX = pos.x;
      item.origY = pos.y;
      item.goBack(true);
    }

    setHegemonyData();
  }

  function setHegemonyData(){
    if (!root.dataModel || !root.dataModel.hegemony) return;

    let item, i;

    // 国战小标记
    const result = root.dataModel.result ?? [];
    const selectedItem = result.slice(0, 2).map(name => root.dataModel.generalDict?.[name]?.dataModel);

    // 主副将认定
    if (selectedItem[0]) {
      if (selectedItem[0].mainMaxHp !== 0) {
        selectedItem[0].inPosition = 1;
      } else if (selectedItem[0].deputyMaxHp !== 0) {
        selectedItem[0].inPosition = -1;
      }
      if (selectedItem[1]) {
        if (selectedItem[1].mainMaxHp !== 0) {
          selectedItem[1].inPosition = -1;
        } else if (selectedItem[1].deputyMaxHp !== 0) {
          selectedItem[1].inPosition = 1;
        }
      }
    }

    // 珠联璧合
    for (i = 0; i < generalCardList.count; i++) {
      item = root.dataModel.generalDict[generalCardList.itemAt(i)]?.dataModel;
      if (!item) break;
      item.inPosition = 0;

      if (selectedItem[0]) {
        if (selectedItem[1]) {
          if (selectedItem[0] === item) {
            updateCompanion(item, selectedItem[1], true);
          } else if (selectedItem[1] === item) {
            updateCompanion(item, selectedItem[0], true);
          } else {
            item.hasCompanions = false;
          }
        } else {
          if (selectedItem[0] !== item) {
            updateCompanion(item, selectedItem[0], true);
          } else {
            for (let j = 0; j < generalCardList.count; j++) {
              updateCompanion(item, root.dataModel.generalDict[generalCardList.itemAt(j)]?.dataModel, false);
            }
          }
        }
      } else {
        for (let j = 0; j < generalCardList.count; j++) {
          updateCompanion(item, root.dataModel.generalDict[generalCardList.itemAt(j)]?.dataModel, false);
        }
      }
    }
  }
}
