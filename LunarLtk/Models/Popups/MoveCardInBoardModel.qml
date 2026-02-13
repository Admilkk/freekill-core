// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import LunarLtk

QtObject {
  id: root

  property list<int> cardIds
  property list<int> cardsPosition
  property list<string> generalNames
  property list<int> playerIds
  property string prompt: ""

  readonly property var cardModels: {
    const dict = {};
    cardIds.forEach(id => {
      const cardPos = cardsPosition[cards.findIndex(cid => cid === id)];
      let d = Ltk.getCardData(id);
      const vcard = Ltk.getVirtualEquipData(playerIds[cardPos], id);
      if (vcard) {
        d.virt_name = vcard.name;
      }
      dict[id] = Ltk.createCardModel(id, {
        virt_name: vcard?.name,
      });
      dict.push(d);
    });
    return dict;
  }

  readonly property string promptText: {
    return Ltk.processPrompt(prompt)
  }

  signal accepted()
  signal rejected()
}
