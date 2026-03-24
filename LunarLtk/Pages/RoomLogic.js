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

callbacks["AskForCardsAndChoice"] = (sender, data) => {
  // jsonData: [ int[] handcards, int[] equips, int[] delayedtricks,
  //  int min, int max, string reason ]
  const { cards, choices, prompt, cancel_choices, min, max, filter_skel, disabled, extra_data } = data;

  roomScene.dataModel.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("LunarLtk.Pages.Popups", "ChooseCardsAndChoiceBox");

  const boxCards = [];
  cards.forEach(id => boxCards.push(Ltk.getCardData(id)));

  const box = roomScene.popupBox.item;
  box.cards = boxCards;
  box.ok_options = choices;
  box.prompt = prompt ?? "";
  box.cancel_options = cancel_choices ?? [];
  box.min = min ?? 1;
  box.max = max ?? 1;
  box.disable_cards = disabled ?? [];
  box.filter_skel = filter_skel ?? "";
  box.extra_data = extra_data;

  roomScene.popupBox.moveToCenter();
}

callbacks["CustomDialog"] = (sender, data) => {
  const path = data.path;
  const dat = data.data;
  roomScene.dataModel.activate();
  roomScene.popupBox.source = AppPath + "/" + path;
  if (dat) {
    roomScene.popupBox.item.loadData(dat);
  }
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

