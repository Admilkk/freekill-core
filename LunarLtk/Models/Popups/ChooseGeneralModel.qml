import QtQuick
import Fk
import LunarLtk

QtObject {
  id: root

  property var generals: [] // string[]
  property int choiceNum: 1
  property bool convertDisabled: false
  property bool cancelable: false
  property string skillName
  property string prompt: ""
  property bool detailed
  property string ruleType: ""
  property var extraData
  property bool hegemony: false

  // 已选择的武将
  property list<string> result: [] // string[]

  property var generalDict: ({}) // 武将名到GeneralModel的映射

  signal generalChanged(string oldname, string newname)

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

  readonly property bool feasible: {
    return choiceNum === result.length;
  }

  readonly property bool canConvert: {
    for (const name of generals) {
      if (Ltk.getSameGenerals(name).length > 0) return true;
    }
    return false;
  }

  function generalFilter(choice) {
    const len = result.length;
    // 因为list<string>作为ListModel传不到lua只好复制
    const luaResult = result.map(e => e);
    return choiceNum > len && Ltk.chooseGeneralFilter(ruleType, choice, luaResult,
        generals, extraData);
  }

  function selectGeneralCard(choice) {
    if (result.includes(choice)) {
      moveGeneral(choice, false);
    } else if (generalFilter(choice)) {
      result.push(choice);
    }
  }

  function moveGeneral(general, toSelect, toIndex) {
    const idx = result.findIndex(e => e === general);
    if (!toSelect) {
      if (idx !== -1) result.splice(idx, 1);
      return;
    }

    if (!generalFilter(general)) return;

    toIndex = Math.min(result.length, toIndex);

    if (idx !== toIndex) {
      const to_pos = toIndex ?? (result.length - 1)
      result[to_pos] = general;
    }
  }

  // 武将牌变更（自选或者同名替换）
  function changeGeneral(oldName, newModel) {
    const newName = newModel.name;
    for (let i = 0; i < generals.length; i++) {
      if (generals[i] === oldName) {
        generals[i] = newName;
      }
    }
    for (let i = 0; i < result.length; i++) {
      if (result[i] === oldName) {
        result[i] = newName;
      }
    }
    generalDict[newModel.name] = newModel;
    generalChanged(oldName, newName);
  }

  function initGeneralModels() {
    generalDict = {};

    for (const name of generals) {
      const model = Ltk.createGeneralCardModel(name)
      generalDict[name] = model;
    }
  }
}
