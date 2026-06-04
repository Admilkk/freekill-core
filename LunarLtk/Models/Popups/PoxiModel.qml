import QtQuick
import LunarLtk

QtObject {
  id: root

  property string poxiType
  property list<var> cardData // var为如此list: [ name, ids ]
  property bool cancelable: true
  property var extraData // 储存卡牌可见性，或者用于cardFilter的额外信息

  // list<int>会无法传递到Lua 只做了QVariantList的适配
  // 写list的话无需手动触发changed信号
  property list<var> selectedIds: []

  readonly property var cardModels: {
    const dict = {};
    const visibleData = extraData?.visible_data ?? {};

    for (const tab of cardData) {
      for (const cid of tab[1]) {
        // 神姜维约定：为0也不可见，但不参与后续随机
        const known = visibleData[cid.toString()];
        dict[cid] = Ltk.createCardModel(cid, {
          known: known === undefined || !!known,
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
          invisible.push(Number(cid));
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
          output[i] = invisible[p];
          p++;
        }
      }

      selectedIds = output;
    }

    accepted();
  }

  function revertSelection() {
    let old_selected = selectedIds.slice();
    for (var i = 0; i < old_selected.length; ++i) {
      var cid = old_selected[i];
      let model = cardModels[cid];
      model.selected = false;
    }
    for (const cidstr in cardModels) {
      let cid = Number(cidstr); // 为啥这里变成字符串了
      if (old_selected.indexOf(cid) === -1 && cardFilter(cid)) {
        let model = cardModels[cid];
        model.selected = true;
      }
    }
  }
}
