// SPDX-License-Identifier: GPL-3.0-or-later

let callbacks={}

callbacks["AskForExchange"] = (sender, data) => {
  const cards = [];
  const cards_name = [];
  const capacities = [];
  const limits = [];
  roomScene.dataModel.activate();
  const component =
    Qt.createComponent("LunarLtk.Pages.Popups", "GuanxingBox");
  let for_i = 0;
  roomScene.showPopup(component);
  const box = roomScene.popupItem;
  box.org_cards = data.piles;
  data.piles.forEach(ids => {
    if (ids.length > 0) {
      ids.forEach(id => cards.push(Ltk.getCardData(id)));
      capacities.push(ids.length);
      limits.push(0);
      cards_name.push(Lua.tr(data.piles_name[for_i]));
      for_i ++;
    }
  });
  box.cards = cards;
  box.areaCapacities = capacities
  box.areaLimits = limits
  box.areaNames = cards_name
  box.initializeCards();
  box.accepted.connect(() => {
    roomScene.dataModel.replyToServer(box.getResult());
  });
}

callbacks["MiniGame"] = (sender, data) => {
  const game = data.type;
  const dat = data.data;
  const gdata = Ltk.getMiniGame(game, Cpp.self.id, JSON.stringify(dat));
  roomScene.dataModel.activate();
  roomScene.popupBox.source = AppPath + "/" + gdata.qml_path + ".qml";
  if (dat) {
    roomScene.popupBox.item.loadData(dat);
  }
}

callbacks["UpdateMiniGame"] = (sender, data) => {
  if (roomScene.popupBox.item) {
    roomScene.popupBox.item.updateData(data);
  }
}

callbacks["ChangeSkin"] = (sender, data) => {
  const photo = getPhoto(Number(data[0]));
  const path = data[2];
  const deputypath = data[3];
  if (path) {
    if (Number(data[0]) === Cpp.self.id) {
      Config.enabledSkins[photo.general] = path === "-" ? "" : path;
    }
    photo.skinSource = path === "-" ? "" : (AppPath + "/" + path);
  }
  if (deputypath) {
    if (Number(data[0]) === Cpp.self.id) {
      Config.enabledSkins[photo.deputyGeneral] = deputypath === "-" ? "" : deputypath;
    }
    photo.deputySkinSource = deputypath === "-" ? "" : (AppPath + "/" + deputypath);
  }
  photo.changeSkinTimer.start()
}

callbacks["UpdateRequestUI"] = (sender, uiUpdate) => {
  if (uiUpdate["_prompt"])
    roomScene.dataModel.prompt = uiUpdate["_prompt"];

  if (uiUpdate._type == "Room") {
    roomScene.applyChange(uiUpdate);
  }
}

