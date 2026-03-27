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
    Lua.updateRequestUI("Interaction", "1", "update", answer);
  }

  onClicked: {
    Lua.updateRequestUI("Interaction", "1", "update", []);
    roomScene.showPopup(Qt.createComponent("LunarLtk.Pages.Popups", "ChoicesBox"), { dataModel });
    dataModel.accepted.connect(() => {
      answer = dataModel.result;
      roomScene.popupItem?.finished();
    });
    dataModel.rejected.connect(() => {
      roomScene.popupItem?.finished();
    });
  }
}
