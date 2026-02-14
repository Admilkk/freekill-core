// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk
import LunarLtk
import LunarLtk.Components

GraphicsBox {
  property int spacing: 5
  property string currentPlayerName: ""
  property bool interactive: false

  id: root
  title.text: Lua.tr("Please choose cards")
  width: cards.length * 100 + spacing * (cards.length - 1) + 25
  height: 180

  property list<var> cards // CardModel[]

  Row {
    x: 20
    y: 35
    spacing: root.spacing

    Repeater {
      model: cards

      CardItem {
        required property var modelData
        dataModel: modelData
        autoBack: false
        footnoteVisible: true
        onClicked: {
          if (root.interactive && selectable) {
            root.interactive = false;
            roomScene.state = "notactive";
            ClientInstance.replyToServer("", dataModel.cardId);
          }
        }
      }
    }
  }

  function addIds(ids) {
    ids.forEach((id) => {
      let data = Ltk.createCardModel(id);
      data.selectable = true;
      data.footnote = "";
      cards.push(data);
    });
  }

  function takeAG(g, cid) {
    for (const model of cards) {
      if (model.cardId !== cid) continue;
      model.footnote = g;
      model.selectable = false;
      break;
    }
  }
}
