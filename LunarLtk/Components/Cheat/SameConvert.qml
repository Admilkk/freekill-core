// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import LunarLtk
import LunarLtk.Models.Popups
import LunarLtk.Components

Item {
  id: root
  anchors.fill: parent
  property var extra_data: ({})

  signal finish()

  property ChooseGeneralModel dataModel

  Component {
    id: generalColumnComponent

    ColumnLayout {
      id: generalColumn
      required property string modelData
      visible: toConvertRepeater.model.length > 0
      Text {
        color: "#E4D5A0"
        text: Lua.tr(parent.modelData)
      }
      GridLayout {
        columns: 6

        Repeater {
          id: toConvertRepeater
          model: Ltk.getSameGenerals(generalColumn.modelData)

          GeneralCardItem {
            required property string modelData
            dataModel: Ltk.createGeneralCardModel(modelData)
            selectable: true

            onClicked: {
              root.dataModel.changeGeneral(generalColumn.modelData, dataModel);

              root.finish();
            }
          }
        }
      }
    }
  }

  Flickable {
    height: parent.height
    width: generalButtons.width
    anchors.centerIn: parent
    contentHeight: generalButtons.height
    ScrollBar.vertical: ScrollBar {}

    ColumnLayout {
      id: generalButtons
      Repeater {
        model: root.dataModel?.generals ?? []
        delegate: generalColumnComponent
      }
    }
  }

  onExtra_dataChanged: {
    if (!extra_data.dataModel) return;
    root.dataModel = extra_data.dataModel;
  }
}
