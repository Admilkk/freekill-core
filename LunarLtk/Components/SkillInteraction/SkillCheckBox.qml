// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Models.Popups

MetroButton {
  id: root
  property ChoicesModel dataModel
  property var answer: []

  text: answer.length === 0 ? Lua.tr("AskForChoices") : answer.map(v => Ltk.processPrompt(v)).join("+")

  onAnswerChanged: {
    if (!answer) return;
    Ltk.updateRequestUI("Interaction", "1", "update", answer);
  }

  onClicked: {
    Ltk.updateRequestUI("Interaction", "1", "update", []);
    roomScene.popupBox.sourceComponent = Qt.createComponent("LunarLtk.Pages.Popups", "ChoicesBox");
    const box = roomScene.popupBox.item;
    dataModel.accepted.connect(() => {
      answer = dataModel.result;
      box?.finished();
    });
    dataModel.rejected.connect(() => {
      box?.finished();
    });
    box.dataModel = dataModel;
  }
}
