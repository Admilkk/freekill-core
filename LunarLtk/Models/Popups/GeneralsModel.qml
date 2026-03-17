import QtQuick
import Fk
import LunarLtk

QtObject {
  id: root

  property list<var> allGenerals
  property int choiceNum: 1
  property bool convertDisabled: false
  property bool cancelable: false
  property string skillName
  property string prompt
  property bool detailed
  property string ruleType: ""
  property var extraData
  property bool hegemony: false

  property list<var> generals: [] // 当前场上所有的武将
  property list<var> result: [] // 已选择的武将

  signal accepted()
  signal rejected()

  readonly property string promptText: {
    if (prompt !== "") return prompt;
    const pre_prompt = Ltk.processPrompt(Ltk.chooseGeneralPrompt(ruleType, generals, extraData));
    if (pre_prompt !== "") return pre_prompt;
    const suffix = Lua.client.getSettings("enableFreeAssign") ? `(${Lua.tr("Enable free assign")})` : "";
    const ret = Lua.tr("$ChooseGeneral").arg(choiceNum) + suffix;
    return ret;
  }

  readonly property var generalModels: {
    const dict = {};

    for (const name of generals) {
      dict[name] = { name };
    }
    return dict;
  }

  readonly property bool feasible: {
    return !hasEmptySlot();
  }

  readonly property bool canConvert: {
    for (const name of generals) {
      if (Ltk.getSameGenerals(name).length > 0) return true;
    }
    return false;
  }

  function hasEmptySlot() {
    const length = result.length;
    return result.findIndex(s => s === undefined) !== -1;
  }

  function generalFilter(choice) {
    const len = result.length;
    return hasEmptySlot() && Ltk.chooseGeneralFilter(ruleType, choice, result,
        generals, extraData);
  }

  function toggleResult(choice) {
    if (result.includes(choice)) {
      moveGeneral(choice, false);
    } else if (hasEmptySlot() && generalFilter(choice)) {
      const emptyIdx = result.findIndex(s => s === undefined);
      if (emptyIdx !== -1) {
        result[emptyIdx] = choice;
      } else {
        result.push(choice);
      }
      resultChanged();
    }
  }

  function changeGeneral(index, new_name) {
    const orig_name = generals[index];
    generals[index] = new_name;
    const idx = result.findIndex(e => e === orig_name);
    if (idx !== -1) {
      result[idx] = new_name;
    }
    resultChanged();
  }

  function moveGeneral(general, toSelect, toIndex) {
    const idx = result.findIndex(e => e === general);
    if (idx !== toIndex && toSelect) {
      const to_pos = toIndex ?? (result.length - 1)
      let tmp = result[to_pos];
      result[to_pos] = undefined;
      if (generalFilter(general)) {
        if (idx !== -1) result[idx] = undefined;
        result[to_pos] = general;
      } else {
        result[to_pos] = tmp;
        return;
      }
    } else if (idx !== -1 && !toSelect) {
      result[idx] = undefined;
    }

    resultChanged();
  }

  function initializeGenerals() {
    generals = [];
    result = new Array(choiceNum).fill(undefined);
    for (const name of allGenerals) {
      generals.push(name);
    }
  }
}
