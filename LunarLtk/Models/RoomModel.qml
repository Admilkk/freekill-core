import QtQuick
import Fk
import LunarLtk

// 试做型RoomModel
//
// 目标是干掉大部分游戏对局内UI页面/组件的property定义
// 他们只需要一个property RoomModel model就行了，剩下需要的数据从model拿
// 因此，model需要定义对局页面依赖的各种数据
//
// 然后，这个model再负责从Lua中及时取得最新数据。
//
// 预计还需要定义一系列signal
//
// 隔壁PhotoModel同理

QtObject {
  id: root

  property var roomPage

  property int playerNum        // 房间当前游玩人数
  property int dashboardId      // 初次开局时主视角id 用于保存主视角本来的玩家防止被切视角乱掉

  property int drawPileNum      // 牌堆剩余数
  property int roundCount       // 轮数
  property int playedTime       // 对局已经过的时长

  property list<PhotoModel> players: [] // 所有玩家的photo所需数据（包括自己的）

  // banners，细节与PhotoModel的marks一致。
  property list<var> banners: []

  // 我们主视角的数据在此
  property DashboardModel dashboard: DashboardModel {}

  // 处理区中的ui常驻卡牌
  property list<CardModel> processing: [];

  // ====== 活跃状态下的额外UI信息 ======

  // 几个大按钮
  property bool okCancelVisible: false // 确定取消可见？
  property bool okEnabled: false // 可以点确定按钮？
  property bool cancelEnabled: false // 可以点取消按钮？
  property bool endButtonVisible: false // 结束回合可见？

  // 读条信息
  property real requestTotal // 总共的读条时长
  property real requestDuration // 剩余读条时长

  property string prompt

  property var skipNullificationData

  readonly property string promptText: Ltk.processPrompt(prompt)

  signal seatChanged(); // 座位排序后的信号
  signal playerAdded(PhotoModel model); // 新玩家加入的信号（addNpc）
  signal cardsMoved(var move, var models); // 操作完移牌数据后通知ui
  signal popupReady(var model); // 准备好弹窗所需model后通知ui

  signal activated();
  signal deActivated();

  function getTimeString(time) {
    let s = time % 60;
    const m = (time - s) / 60;
    const h = (time - s - m * 60) / 3600;
    if (s < 10) s = '0' + s;
    return h ? `${h}:${m}:${s}` : `${m}:${s}`;
  }

  function getPhoto(pid) {
    for (const model of players) {
      if (model.playerid === pid) {
        return model;
      }
    }
  }

  function replyToServer(jsonData) {
    ClientInstance.replyToServer("", jsonData);
    deActivate();
  }

  function activate() {
    const dat = Backend.getRequestData();
    const total = dat["timeout"] * 1000;
    const now = Date.now(); // ms
    const elapsed = now - (dat["timestamp"] ?? now);

    if (total <= elapsed) {
      return;
    }

    requestTotal = total;
    requestDuration = total - elapsed;
    activated();
  }

  function deActivate() {
    okCancelVisible = false;
    okEnabled = false;
    cancelEnabled = false;
    endButtonVisible = false;
    prompt = "";

    dashboard.disableAllSkills();

    for (const model of players) {
      model.selected = false;
      model.state = "normal";
    }

    deActivated();
  }

  // 一秒5刷智慧
  function refreshData() {
    drawPileNum = Lua.ev("#ClientInstance.draw_pile");
    roundCount = Lua.client.getBanner("RoundCount") || 0;
    for (const model of players) {
      model.refreshData();
    }

    dashboard.refreshData();
  }

  function netStateChanged(sender, data) {
    let [id, state] = data;

    const model = getPhoto(id);
    if (!model) return;
    if (state === "run" && model.dead) {
      state = "leave";
    }
    model.netstate = state;
  }

  function arrangeSeats(_, order) {
    // 先重设座位号
    for (const model of players) {
      model.seatNumber = order.indexOf(model.playerid) + 1;
    }

    // 然后打散order，把Self放到第一个，这样才好调整model们的index以重排photo
    const selfIndex = order.indexOf(Cpp.self.id);
    const after = order.splice(selfIndex);
    after.push(...order);
    const photoOrder = after;

    for (const model of players) {
      model.index = photoOrder.indexOf(model.playerid);
    }

    seatChanged();
  }

  function propertyUpdate(_, data) {
    const [uid, property_name, value] = data;
    const model = getPhoto(uid);
    if (model && property_name in model) {
      model[property_name] = value;
    }
  }

  function startGame() {
    for (const model of players) {
      model.general = "";
    }
  }

  function setPlayerMark(_, data) {
    const [ id, mark, v ] = data;
    const player = getPhoto(id);
    Ltk.setMark(mark.startsWith("@!") ? player.picMarks : player.marks, mark, v, id);
  }

  function setBanner(_, data) {
    const [ mark, v ] = data;
    Ltk.setMark(banners, mark, v);
  }

  function updateLimitSkill(sender, data) {
    const [ id, skill, time ] = data;
    getPhoto(id)?.updateLimitSkill(skill, time);
  }

  function addNpc(_, data) {
    const [id, name, avatar] = data;
    const photoModelComponent = Qt.createComponent("LunarLtk.Models", "PhotoModel");
    const model = photoModelComponent.createObject(null, {
      playerid: id,
      avatar,
      screenName: name,
      index: players.length,
    });
    model.index = players.length;
    players.push(model);
    playerNum++;
    playerAdded(model);
  }

  function moveCards(move, data) {
    const getCardsModel = (area, playerid) => {
      if (area === Ltk.Card.Processing) {
        return processing;
      } else if (area === Ltk.Card.PlayerHand && playerid === Cpp.self.id) {
        return dashboard.handcards;
      } else if (area === Ltk.Card.PlayerEquip) {
        return getPhoto(playerid)?.equips;
      } else if (area === Ltk.Card.PlayerJudge) {
        return getPhoto(playerid)?.delayedTricks;
      }
      return null;
    };

    const fromModel = getCardsModel(move.fromArea, move.from);
    const toModel = getCardsModel(move.toArea, move.to);

    const models = move.ids.map(id => {
      let card;
      if (fromModel) {
        const i = fromModel.findIndex(e => e.cardId === id);
        if (i !== -1) card = fromModel.splice(i, 1)[0];
      }
      return card || Ltk.createCardModel(id, { known: !!data[id.toString()] });
    });

    if (toModel) toModel.push(...models);

    cardsMoved(move, models);
  }

  function setCardFootnote(_, data) {
    const [id, note, virtual] = data;
    const v = processing.find(e => e[virtual ? "virtId" : "cardId"] === id);
    if (v) {
      v.footnote = note;
      v.footnoteVisible = true;
    }
  }

  function setCardVirtName(_, data) {
    const [ids, note, virtual] = data;
    ids.forEach(id => {
      const v = processing.find(e => e[virtual ? "virtId" : "cardId"] === id);
      if (v) v.virtName = note;
    });
  }

  function changeSelf() {
    // move new selfPhoto to dashboard
    let order = new Array(players.length);
    for (const model of players) {
      order[model.seatNumber - 1] = model.playerid;
    }
    arrangeSeats(null, order);

    // update dashboard
    dashboard.changeSelf();
  }

  function loseSkill(sender, data) {
    // jsonData: [ int player_id, string skill_name ]
    const [ id, skill_name, prelight ] = data;
    if (id === Cpp.self.id) {
      dashboard.loseSkill(skill_name, prelight);
    }
  }

  function addSkill(sender, data) {
    // jsonData: [ int player_id, string skill_name ]
    const [ id, skill_name, prelight ] = data;
    if (id === Cpp.self.id) {
      dashboard.addSkill(skill_name, prelight);
    }
  }

  function prelightSkill(sender, data) {
    const [ skill_name, prelight ] = data;
    dashboard.prelightSkill(skill_name, prelight);
  }

  function playerRunned(sender, data) {
    const [ runner, robot ] = data;

    const model = getPhoto(runner);
    if (model) {
      model.playerid = robot;
    }
  }

  function playCard() {
    activate();
    okCancelVisible = true;
  }

  function askForSkillInvoke(sender, data) {
    const [ skill, prompt ] = data;
    root.prompt = prompt || `#AskForSkillInvoke:::${skill}`;
    activate();
  }

  function askForUseActiveSkill(sender, data) {
    const [ skill_name, prompt, cancelable ] = data;
    root.prompt = prompt || `#AskForUseActiveSkill:::${skill_name}`;
    activate();
    okCancelVisible = true;
  }

  function askForResponseCard(sender, data) {
    const [ cardname, pattern, prompt, cancelable, extra_data, disabledSkillNames ] = data;

    root.prompt = prompt || `#AskForResponseCard:::${cardname}`;
    activate();
    okCancelVisible = true;
  }

  // 确定只会修改model属性的逻辑都搬家到这里
  function setupCallbacks() {
    roomPage.addCallback(Command.NetStateChanged, netStateChanged);
    roomPage.addCallback(Command.ArrangeSeats, arrangeSeats);
    roomPage.addCallback(Command.PropertyUpdate, propertyUpdate);
    roomPage.addCallback(Command.StartGame, startGame);
    roomPage.addCallback(Command.SetPlayerMark, setPlayerMark);
    roomPage.addCallback(Command.SetBanner, setBanner);
    roomPage.addCallback(Command.UpdateLimitSkill, updateLimitSkill);
    roomPage.addCallback(Command.MoveCards, (_, data) => {
      for (const move of data.merged) moveCards(move, data);
    });
    roomPage.addCallback(Command.SetCardFootnote, setCardFootnote);
    roomPage.addCallback(Command.SetCardVirtName, setCardVirtName);
    roomPage.addCallback(Command.ChangeSelf, changeSelf);
    roomPage.addCallback(Command.LoseSkill, loseSkill);
    roomPage.addCallback(Command.AddSkill, addSkill);
    roomPage.addCallback(Command.PrelightSkill, prelightSkill);
    roomPage.addCallback("AddNpc", addNpc);

    roomPage.addCallback(Command.EmptyRequest, activate);
    roomPage.addCallback(Command.CancelRequest, deActivate);
    roomPage.addCallback(Command.PlayerRunned, playerRunned);


    // 以下为交互类
    roomPage.addCallback(Command.PlayCard, playCard);
    roomPage.addCallback(Command.AskForSkillInvoke, askForSkillInvoke);
    roomPage.addCallback(Command.AskForUseActiveSkill, askForUseActiveSkill);
    roomPage.addCallback(Command.AskForResponseCard, askForResponseCard);

    roomPage.addCallback(Command.ReplyToServer, (_, data) => replyToServer(data));
  }

  function applyChange(uiUpdate) {
    const pdatas = uiUpdate["Photo"];
    pdatas?.forEach(pdata => {
      const model = getPhoto(pdata.id);
      model.state = pdata.state;
      model.selectable = pdata.enabled;
      model.selected = pdata.selected;
    });
    for (const model of players) {
      model.updateTargetTip();
    }

    const buttons = uiUpdate["Button"];
    if (buttons) {
      okCancelVisible = true;
    }
    buttons?.forEach(bdata => {
      switch (bdata.id) {
        case "OK":
          okEnabled = bdata.enabled;
          break;
        case "Cancel":
          cancelEnabled = bdata.enabled;
          break;
        case "End":
          endButtonVisible = bdata.enabled;
          break;
      }
    });
  }

  function initialize() {
    dashboardId = Cpp.self.id;
    const luaPlayers = Lua.client.players;
    playerNum = luaPlayers.length;
    const photoModelComponent = Qt.createComponent("LunarLtk.Models", "PhotoModel");
    for (const player of luaPlayers) {
      const prop = player.__toqml().prop;
      delete prop.scale;
      delete prop.selectable;
      delete prop.state;
      const model = photoModelComponent.createObject(null, prop);
      model.index = players.length;
      players.push(model);
    }
  }
}
