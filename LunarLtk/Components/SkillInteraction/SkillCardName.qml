// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk.Components.Common
import LunarLtk
import LunarLtk.Models.Popups

MetroButton {
  id: root

  property ChoicesModel dataModel

  property string answer: dataModel?.result[0] ?? ""

  text: Ltk.processPrompt(answer)

  onAnswerChanged: {
    if (!answer) return;
    Ltk.updateRequestUI("Interaction", "1", "update", answer);
  }

  onClicked: {
    if (!dataModel.cancelable && dataModel.choices.length < 2) return;
    roomScene.popupBox.sourceComponent = Qt.createComponent("LunarLtk.Pages.Popups", "CardNamesBox");
    const box = roomScene.popupBox.item;
    dataModel.accepted.connect(() => {
      answer = dataModel.result[0];
    });
    box.dataModel = dataModel;
  }
}
