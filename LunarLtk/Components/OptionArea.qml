pragma ComponentBehavior: Bound
import QtQuick

import Fk
import Fk.Components.Common

import LunarLtk
import LunarLtk.Models

Row {
  id: root

  required property OptionsModel dataModel
  property bool toggleable: !!((dataModel?.minNum ?? 1) > 1 || dataModel?.enableOK)

  MetroButton {
    id: okButton
    text: Lua.tr("OK")
    enabled: !!root.dataModel?.feasible
    visible: root.toggleable

    onClicked: {
      root.dataModel.accepted()
    }
  }

  Repeater {
    id: optionRepeater
    model: root.dataModel?.allOptions ?? []

    MetroButton {
      required property string modelData
      text: Lua.tr(Ltk.processPrompt(modelData))
      enabled: (root.dataModel?.options ?? []).indexOf(modelData) !== -1

      onClicked: {
        if (root.toggleable) {
          checked = !checked
        }
        root.dataModel.toggleChoose(modelData)

        for (let i = 0; i < optionRepeater.model.length; i++) {
          const item = optionRepeater.itemAt(i)
          if (root.dataModel.result.indexOf(optionRepeater.model[i]) === -1) {
            item.checked = false
          }
        }
      }
    }
  }

  MetroButton {
    id: cancelButton
    text: Lua.tr("Cancel")
    enabled: !!root.dataModel?.cancelable
    visible: enabled

    onClicked: {
      root.dataModel.rejected()
    }
  }
}