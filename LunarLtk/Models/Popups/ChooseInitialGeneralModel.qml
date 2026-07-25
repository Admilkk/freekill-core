import QtQuick
import Fk
import LunarLtk

// 继承自ChooseGeneralModel

ChooseGeneralModel {
  id: root

  property string lordGeneral: ""
  property string lordDeputy: ""
  property string lordRole: ""
  property string selfRole: ""
  property bool hideRole: false

  property string selectedKingdom: ""
  readonly property list<string> generalResult: resultInt.map(e => generals[e])
  readonly property list<string> kingdoms: {
    if (generalResult.length > 0) return Ltk.getEnableKingdoms(generalResult[0]);
    return []
  }
  readonly property bool newFeasible: choiceNum === resultInt.length && (kingdoms.length == 0 || selectedKingdom !== "")

  result: [generalResult, ["kingdom", selectedKingdom]]

  function selectGeneralCard(index) {
    if (resultInt.indexOf(index) !== -1) {
      return resultInt.splice(resultInt.indexOf(index), 1)
    } else {
      if (resultInt.length >= choiceNum) {
        resultInt.splice(0, resultInt.length - choiceNum + 1)
      }
      resultInt.push(index)
    }
  }

  // 武将牌变更（自选或者同名替换）
  function changeGeneral(idx, newModel) {
    const numberfiedIdx = Number(idx);
    const newName = newModel.name;
    generalDict[numberfiedIdx] = newModel;
    generals[numberfiedIdx] = newName;

    resultInt = resultInt;
    const origIdx = resultInt.findIndex(e => Number(e) === numberfiedIdx);
    if (origIdx >= 0) {
      moveGeneral(numberfiedIdx, false);
      if (generalFilter(numberfiedIdx)) {
        moveGeneral(numberfiedIdx, true, origIdx);
      }
    }
    generalChanged(numberfiedIdx, newName);
  }

  function initGeneralModels() {
    generalDict = [];

    for (const name of generals) {
      const model = Ltk.createGeneralCardModel(name);
      generalDict.push(model);
    }
  }

  function initialize() {
    this.initGeneralModels();
  }

}
