// SPDX-License-Identifier: GPL-3.0-or-later

let callbacks={}

function arrangeManyPhotos() {
  /* Layout of photos:
   * +----------------+
   * |    -2 ... 2    |
   * | -1           1 |
   * |              0 |
   * +----------------+
   */

  const playerNum = roomScene.dataModel.playerNum;
  const photoBaseWidth = 175 * 0.75;
  const photoMaxWidth = 175 * 0.75;
  // const verticalSpacing = 32;
  const verticalSpacing = roomArea.height * 0.08;
  // Padding is negative, because photos are scaled.
  const roomAreaPadding = 16;

  let horizontalSpacing = 8;
  let photoWidth = (roomArea.width - horizontalSpacing * playerNum)
                 / (playerNum - 1);
  let photoScale = 1;
  if (photoWidth > photoMaxWidth) {
    photoWidth = photoMaxWidth;
    horizontalSpacing = (roomArea.width - photoWidth * (playerNum - 1))
                      / playerNum;
  } else {
    photoScale = photoWidth / photoBaseWidth;
  }

  const horizontalPadding = (photoWidth - photoBaseWidth) / 2;
  const startX = horizontalPadding + horizontalSpacing;
  const padding = photoWidth + horizontalSpacing;
  let regions = [
    {
      x: startX + padding * (playerNum - 2),
      y: roomScene.height - 192,
      scale: photoScale
    },
  ];
  let i;
  for (i = 0; i < playerNum - 1; i++) {
    regions.push({
      x: startX + padding * (playerNum - 2 - i),
      y: roomAreaPadding,
      scale: photoScale,
    });
  }
  regions[1].y += verticalSpacing * 3;
  regions[regions.length - 1].y += verticalSpacing * 3;
  regions[2].y += verticalSpacing;
  regions[regions.length - 2].y += verticalSpacing;

  let item, region;

  for (i = 0; i < playerNum; i++) {
    item = photos.itemAt(i);
    if (!item)
      continue;

    region = regions[photoModel[i].index];
    item.x = region.x;
    item.y = region.y;
    item.scale = region.scale;
  }
}

function arrangePhotos() {
  const playerNum = roomScene.dataModel.playerNum;
  if (playerNum > 8) {
    return arrangeManyPhotos();
  }

  /* Layout of photos:
   * +---------------+
   * |   6 5 4 3 2   |
   * | 7           1 |
   * |             0 |
   * +---------------+
   */

  const photoWidth = 175 * 0.75;
  // Padding is negative, because photos are scaled.
  const roomAreaPadding = 16;
  const verticalPadding = 0;
  const verticalSpacing = roomArea.height * 0.08;
  const horizontalSpacing = (roomArea.width - photoWidth * 7) / 8;

  // Position 1-7
  const startX = verticalPadding + horizontalSpacing;
  const padding = photoWidth + horizontalSpacing;
  const regions = [
    { x: startX + padding * 6, y: roomScene.height - 192 },
    { x: startX + padding * 6, y: roomAreaPadding + verticalSpacing * 3 },
    { x: startX + padding * 5, y: roomAreaPadding + verticalSpacing },
    { x: startX + padding * 4, y: roomAreaPadding },
    { x: startX + padding * 3, y: roomAreaPadding },
    { x: startX + padding * 2, y: roomAreaPadding },
    { x: startX + padding, y: roomAreaPadding + verticalSpacing },
    { x: startX, y: roomAreaPadding + verticalSpacing * 3 },
  ];

  const regularSeatIndex = [
    [0],
    [0, 4],
    [0, 3, 5],
    [0, 1, 4, 7],
    [0, 1, 3, 5, 7],
    [0, 1, 3, 4, 5, 7],
    [0, 1, 2, 3, 5, 6, 7],
    [0, 1, 2, 3, 4, 5, 6, 7],
  ];
  const seatIndex = regularSeatIndex[playerNum - 1];

  let item, region, i;

  for (i = 0; i < playerNum; i++) {
    item = photos.itemAt(i);
    if (!item)
      continue;

    region = regions[seatIndex[photoModel[i].index]];
    item.x = region.x;
    item.y = region.y;
  }
}

function getAreaItem(area, id) {
  const publicArea = roomScene.getAreaItem(area);
  if (publicArea) return publicArea;

  const photo = getPhoto(id);
  if (!photo) {
    return null;
  }

  if (area === Ltk.Card.PlayerHand && id === Cpp.self.id) {
    return dashboard.handcardArea;
  }

  return photo.getAreaItem(area);
}

function moveCards(move, data) {
  const from = getAreaItem(move.fromArea, move.from);
  const to = getAreaItem(move.toArea, move.to);
  if (!from || !to) return;
  if (from === to && from !== tablePile) return;
  if (from === tablePile && move.toArea === Ltk.Card.DiscardPile) return;

  const items = from.remove(data, move.fromSpecialName);
  if (items.length > 0)
    to.add(items, move.specialName);
  to.updateCardPosition(true);
}

callbacks["ShowVirtualCard"] = (sender, data) => {
  const [card_data, playerid, footnote, event_id] = data;
  let from = drawPile;
  const photo = getPhoto(playerid);
  if (photo) {
    from = (playerid === Cpp.self.id ? dashboard.handcardArea : photo.handcardArea);
  }

  const items = [];
  for (let i = 0; i < card_data.length; i++) {
    const dat = Lua.call("ToQml", card_data[i]);
    const card = Lua.createQmlObject(dat, roomScene.dynamicCardArea);
    const parentPos = roomScene.mapFromItem(from, 0, 0);
    card.x = parentPos.x - card.width / 2;
    card.y = parentPos.y - card.height / 2;
    // card.holding_event_id = event_id;
    card.known = true;
    if (footnote) {
      card.footnote = footnote;
      card.footnoteVisible = true;
    }
    items.push(card);
  }

  tablePile.add(items);
  tablePile.updateCardPosition(true);
}

callbacks["AskForGeneral"] = (sender, data) => {
  // jsonData: string[] generals, integer n, boolean no_convert, boolean heg, string rule, table extra_data
  const [ generals, n, no_convert, heg, rule, extra_data ] = data;

  roomScene.dataModel.prompt = "#AskForGeneral";
  roomScene.dataModel.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("LunarLtk.Pages.Popups", "ChooseGeneralBox");
  const box = roomScene.popupBox.item;
  box.accepted.connect(() => {
    roomScene.dataModel.replyToServer(box.choices);
  });
  box.generals = generals;
  box.choiceNum = n ?? 1;
  box.convertDisabled = !!no_convert;
  box.hegemony = !!heg;
  box.rule_type = rule ?? (heg? "heg_general_choose" : "askForGeneralsChosen"); // 若heg为true，默认应用国战选将
  box.extra_data = extra_data ?? { n : n };
  for (let i = 0; i < generals.length; i++)
    box.generalList.append({ "name": generals[i] });
  box.updatePosition();
  box.refreshPrompt();
}

callbacks["AskForExchange"] = (sender, data) => {
  const cards = [];
  const cards_name = [];
  const capacities = [];
  const limits = [];
  roomScene.dataModel.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("LunarLtk.Pages.Popups", "GuanxingBox");
  let for_i = 0;
  const box = roomScene.popupBox.item;
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

callbacks["AskForUseCard"] = (sender, data) => {
  // jsonData: card, pattern, prompt, cancelable, {}
  const [ cardname, pattern, prompt, cancelable, extra_data, disabledSkillNames ] = data;

  roomScene.dataModel.prompt = prompt || `#AskForUseCard:::${cardname}`;
  roomScene.dataModel.activate();
  roomScene.dataModel.okCancelVisible = true;
  if (extra_data != null) {
    if ((extra_data.effectTo !== Cpp.self.id && // 忽略本轮无懈可击，但目标是自己时不忽略
        roomScene.skippedUseEventId.find(id => id === extra_data.useEventId)) ||
        (Config.noSelfNullification && extra_data.effectFrom === Cpp.self.id &&
        !Ltk.getCardData(extra_data.effectCardId).multiple_targets)) { // 不对自己使用的单目标锦囊牌无懈
      Ltk.updateRequestUI("Button", "Cancel");
      return;
    } else {
      roomScene.extra_data = extra_data;
    }
  }
}

callbacks["FillAG"] = (sender, data) => {
  const ids = data[0];
  roomScene.manualBox.sourceComponent =
    Qt.createComponent("LunarLtk.Pages.Popups", "AG");
  roomScene.manualBox.item.addIds(ids);
}

callbacks["AskForAG"] = (sender, j) => {
  roomScene.dataModel.activate();
  roomScene.manualBox.item.interactive = true;
}

callbacks["TakeAG"] = (sender, data) => {
  if (!roomScene.manualBox.item) return;
  const pid = data[0];
  const cid = data[1];
  const item = getPhoto(pid);
  const general = Lua.tr(item.general);

  // the item should be AG box
  roomScene.manualBox.item.takeAG(general, cid);
}

callbacks["CloseAG"] = () => roomScene.manualBox.item.close();

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

