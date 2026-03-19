// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk
import LunarLtk.Components
import LunarLtk

ColumnLayout {
  id: root
  anchors.fill: parent
  property var extra_data: ({})
  signal finish()

  BigGlowText {
    Layout.fillWidth: true
    Layout.preferredHeight: childrenRect.height + 4

    text: Lua.tr(root.extra_data.name)
  }

  GridView {
    cellWidth: 93 + 4
    cellHeight: 130 + 4
    Layout.preferredWidth: root.width - root.width % 97
    Layout.fillHeight: true
    Layout.alignment: Qt.AlignHCenter
    clip: true

    model: root.extra_data.ids || root.extra_data.cardNames

    delegate: GeneralCardItem {
      required property string modelData
      id: cardItem
      autoBack: false
      dataModel: Ltk.createGeneralModel(modelData, { detailed: false })
      onClicked: { // FIXME: rightClicked不能覆写
        roomScene.startCheat("GeneralDetail", { generals: [modelData] });
      }
    }
  }
}
