// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk.Components.Common
import LunarLtk
import LunarLtk.Models.Popups

pragma ComponentBehavior: Bound

MetroButton {
  id: root

  property ChoicesModel model

  property string default_choice
  property string answer: default_choice

  text: Ltk.processPrompt(answer)

  onAnswerChanged: {
    if (!answer) return;
    Ltk.updateRequestUI("Interaction", "1", "update", answer);
  }

  onClicked: {
    if (!model.cancelable && model.allChoices.length < 2) return;
    roomScene.popupBox.sourceComponent = Qt.createComponent("LunarLtk.Pages.Popups", "ChoicesBox");
    const box = roomScene.popupBox.item;
    model.accepted.connect(() => {
      answer = model.result[0];
      box.finished();
    });
    model.rejected.connect(() => {
      box.finished();
    });
    box.dataModel = model;
  }
}
