// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import LunarLtk
import LunarLtk.Components

Item {
  id: root
  anchors.fill: parent
  property var extra_data: ({})

  signal finish()

  Flickable {
    height: parent.height
    width: generalButtons.width
    anchors.centerIn: parent
    contentHeight: generalButtons.height
    ScrollBar.vertical: ScrollBar {}
    ColumnLayout {
      id: generalButtons
      Repeater {
        model: ListModel {
          id: glist
        }

        ColumnLayout {
          id: generalColumn
          required property string gname
          Text {
            color: "#E4D5A0"
            text: Lua.tr(generalColumn.gname)
          }
          GridLayout {
            columns: 6

            Repeater {
              model: Ltk.getSameGenerals(generalColumn.gname)

              GeneralCardItem {
                required property string modelData
                dataModel: Ltk.createGeneralModel(modelData)
                selectable: true

                onClicked: {
                  let idx = 0;
                  for (; idx < root.extra_data.cards.count; idx++) {
                    if (root.extra_data.cards.get(idx).dataModel.name === generalColumn.gname)
                      break;
                  }

                  if (idx < root.extra_data.cards.count) {
                    dataModel.name = modelData;
                    root.extra_data.cards.get(idx).dataModel.name = modelData;
                  }

                  root.finish();
                }
              }
            }
          }
        }
      }
    }
  }

  onExtra_dataChanged: {
    if (!extra_data.cards) return;
    for (let i = 0; i < extra_data.cards.count; i++) {
      glist.set(i, { gname: extra_data.cards.get(i).dataModel.name });
    }
  }
}
