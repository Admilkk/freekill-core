import QtQuick
import LunarLtk

QtObject {
  id: root

  property string poxiType
  property list<var> cardData // var为如此list: [ name, ids ]
  property bool cancelable: true
  property var extraData // 这啥啊

  // list<int>会无法传递到Lua 只做了QVariantList的适配
  // 写list的话无需手动触发changed信号
  property list<var> selectedIds: []

  readonly property var cardModels: {
    const dict = {};
    const visibleData = extraData?.visible_data ?? {};

    for (const tab of cardData) {
      for (const cid of tab[1]) {
        dict[cid] = Ltk.createCardModel(cid, {
          known: visibleData[cid.toString()] !== false,
        });
      }
    }
    return dict;
  }

  readonly property string promptText: {
    if (!poxiType) return "";
    const rawPrompt = Ltk.poxiPrompt(poxiType, cardData, extraData);
    return Ltk.processPrompt(rawPrompt)
  }

  readonly property bool feasible: {
    if (!poxiType) return false;

    return Ltk.poxiFeasible(poxiType, selectedIds, cardData, extraData);
  }

  // signal名出自QDialog点击“确定”后发出的信号；符合常理
  signal accepted()
  signal rejected()

  function cardFilter(cid) {
    return Ltk.poxiFilter(poxiType, cid, selectedIds, cardData, extraData);
  }

  function shuffleAndOk() {
    const visibleData = extraData?.visible_data;

    if (visibleData) {
      let output = selectedIds.slice();
      let invisible = [];
      for (const cid in cardModels) {
        if (visibleData[cid.toString()] == false) {
          invisible.push(cid);
        }
      }

      // 洗牌invisible
      for (let i = invisible.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [invisible[i], invisible[j]] = [invisible[j], invisible[i]];
      }

      // 将output中属于invisible的，填入打乱后的invisible
      let p = 0;
      for (let i = 0; i < output.length; i++) {
        if (invisible.includes(output[i])) {
          output[i] = invisible[p++];
        }
      }

      selectedIds = output;
    }

    accepted();
  }
}
