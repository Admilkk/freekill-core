// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Components.WaitingRoom
import Fk.Widgets as W

import LunarLtk

W.PageBase {
  id: roomScene

  property int playerNum: 0

  property bool isAllReady: false
  property bool canAddRobot: false
  property bool canChangeRoom: false
  property bool isOwner: false
  property bool isFull: false
  property bool isReady: false
  property bool canKickOwner: false
  property bool playersAltered: false // 有人加入或离开房间
  readonly property bool isRoomObserver: Config.observing

  onPlayersAlteredChanged: {
    if (playersAltered) {
      checkCanAddRobot();
      playersAltered = false;
    }
  }

  onIsOwnerChanged: {
    if (isOwner && !isFull && !isRoomObserver) {
      addInitComputers();
    }
  }

  onIsAllReadyChanged: {
    if (!isAllReady) {
      canKickOwner = false;
      kickOwnerTimer.stop();
    } else {
      Backend.playSound("./audio/system/ready");
      kickOwnerTimer.start();
    }
  }

  Timer {
    id: opTimer
    interval: 1000
  }

  Timer {
    id: kickOwnerTimer
    interval: 15000
    onTriggered: {
      canKickOwner = true;
    }
  }

  Rectangle {
    id: roomSettings

    x: 40
    y: 40

    color: "snow"
    opacity: 0.8
    radius: 6
    width: 280
    height: parent.height - 80

    Flickable {
      id: flickableContainer
      ScrollBar.vertical: ScrollBar {}
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: 10
      flickableDirection: Flickable.VerticalFlick
      width: parent.width - 10
      height: parent.height - 10
      contentHeight: roominfo.height
      clip: true

      Text {
        id: roominfo
        font.pixelSize: 16
        width: parent.width
        wrapMode: TextEdit.WordWrap
        function refresh() {
          const data = Lua.client.settings;
          let cardpack = Ltk.getAllCardPack();
          cardpack = cardpack.filter(p => !data.disabledPack.includes(p));
          const gameMode = data.gameMode;
          const boardgameSettingsData = Lua.getUIDataOfSettings(gameMode, data, true);
          const gameSettingsData = Lua.getUIDataOfSettings(gameMode, data, false);

          let retText = Lua.tr("GameMode") + Lua.tr(gameMode) + "<br />"
            + Lua.tr("ResponseTime") + "<b>" + Config.roomTimeout + "</b><br />";

          for (const group of boardgameSettingsData) {
            for (const prop of group['_children']) {
              retText += `${Lua.tr(prop.title)}:<b>
              ${Lua.tr(data?.['_game']?.[prop['_settingsKey']])}</b><br />`
            }
          }
          for (const group of gameSettingsData) {
            for (const prop of group['_children']) {
              retText += `${Lua.tr(prop.title)}:<b>
              ${Lua.tr(data?.['_mode']?.[prop['_settingsKey']])}</b><br />`
            }
          }

          retText += Lua.tr('CardPackages') + cardpack.map(e => {
            let ret = Lua.tr(e);
            // TODO: 这种东西最好还是变量名规范化= =
            if (ret.search(/特殊牌|衍生牌/) === -1) {
              ret = "<b>" + ret + "</b>";
            }
            return ret;
          }).join('，');

          text = retText;
        }

        Component.onCompleted: refresh();
      }
    }
  }

  ListModel {
    id: photoModel
  }

  ListModel {
    id: observerModel
  }

  W.PopupLoader {
    id: room_drawer
    padding: 0
    width: Config.winWidth * 0.80
    height: Config.winHeight * 0.95
    anchors.centerIn: parent
  }

  GridLayout {
    id: roomArea

    anchors.left: roomSettings.right
    anchors.leftMargin: 40
    y: 40
    width: roomScene.width - 120 - roomSettings.width
    height: roomScene.height - 80

    columns: 5
    rowSpacing: -60
    columnSpacing: -20

    Repeater {
      id: photos
      model: photoModel
      WaitingPhoto {
        playerid: model.id
        general: model.avatar
        avatar: model.avatar
        screenName: model.screenName
        kingdom: "unknown"
        seatNumber: model.seatNumber
        dead: false
        surrendered: false
        isOwner: model.isOwner
        ready: model.ready
        opacity: model.sealed ? 0 : 1
        winGame: model.win
        runGame: model.run
        totalGame: model.total

        onClicked: {
          if (photoMenu.visible){
            photoMenu.close();
          } else if (model.id !== -1) {
            photoMenu.open();
          }
        }

        onRightClicked: clicked(this);

        Menu {
          id: photoMenu
          y: 64
          width: parent.width * 0.8

          onAboutToShow: {
            flowerButton.enabled = true;
            eggButton.enabled = true;
            wineButton.enabled = Math.random() < 0.3;
            shoeButton.enabled = Math.random() < 0.3;
          }

          W.ButtonContent {
            id: flowerButton
            text: Lua.tr("Give Flower")
            icon.source: SkinBank.pixAnimDir + "/flower/egg3"
            onClicked: {
              enabled = false;
              roomScene.givePresent("Flower", model.id);
              photoMenu.close();
            }
          }

          W.ButtonContent {
            id: eggButton
            text: Lua.tr("Give Egg")
            icon.source: SkinBank.pixAnimDir + "/egg/egg"
            onClicked: {
              enabled = false;
              if (Math.random() < 0.03) {
                roomScene.givePresent("GiantEgg", model.id);
              } else {
                roomScene.givePresent("Egg", model.id);
              }
              photoMenu.close();
            }
          }

          W.ButtonContent {
            id: wineButton
            text: Lua.tr("Give Wine")
            icon.source: SkinBank.pixAnimDir + "/wine/shoe"
            onClicked: {
              enabled = false;
              roomScene.givePresent("Wine", model.id);
              photoMenu.close();
            }
          }

          W.ButtonContent {
            id: shoeButton
            text: Lua.tr("Give Shoe")
            icon.source: SkinBank.pixAnimDir + "/shoe/shoe"
            onClicked: {
              enabled = false;
              roomScene.givePresent("Shoe", model.id);
              photoMenu.close();
            }
          }

          W.ButtonContent {
            id: blockButton
            text: {
              const name = model.screenName;
              const blocked = !Config.blockedUsers.includes(name);
              return blocked ? Lua.tr("Block Chatter") : Lua.tr("Unblock Chatter");
            }
            enabled: model.id !== Self.id && model.id > 0 // 旁观屏蔽不了正在被旁观的人
            onClicked: {
              const name = model.screenName;
              const idx = Config.blockedUsers.indexOf(name);
              if (idx === -1) {
                if (name === "") return;
                Config.blockedUsers.push(name);
              } else {
                Config.blockedUsers.splice(idx, 1);
              }
              Config.blockedUsersChanged();
            }
          }

          W.ButtonContent {
            id: kickButton
            text: Lua.tr("Kick From Room")
            enabled: {
              if (!roomScene.isOwner) return false;
              if (model.id === Self.id) return false;
              if (model.id < -1) {
                const { minComp, curComp } = Lua.getCompNum();
                return curComp > minComp;
              }
              return true;
            }
            onClicked: {
              // 傻逼qml喜欢加1.0
              // FIXME 留下image
              Cpp.notifyServer("KickPlayer", Math.floor(model.id));
              photoMenu.close();
            }
          }
        }
      }
    }
  }

  RowLayout {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 40

    W.ButtonContent{
      visible: isOwner && canChangeRoom
      text: Lua.tr("Change Room Config")
      onClicked: {
        room_drawer.sourceComponent =
          Qt.createComponent("../Lobby/CreateRoom.qml");
        room_drawer.item.isChangeRoom = true;
        room_drawer.open();
        Config.observing = false;
        Config.replaying = false;
      }
    }

    W.ButtonContent {
      text: Lua.tr("Chat")
      font.pixelSize: 28
      onClicked: Mediator.notify(this, Command.IWantToChat);
    }

    W.ButtonContent {
      id: kickOwner
      text: Lua.tr("Kick Owner")
      visible: canKickOwner && isFull && !isOwner
      onClicked: {
        for (let i = 0; i < playerNum; i++) {
          let item = photoModel.get(i);
          if (item.isOwner) {
            // 傻逼qml喜欢加1.0
            Cpp.notifyServer("KickPlayer", Math.floor(item.id));
          }
        }
      }
    }

    W.ButtonContent {
      text: Lua.tr("Spectate")
      visible: !photoModel.count < 2 && !roomScene.isRoomObserver
      enabled: true
      onClicked: {
        Cpp.notifyServer("SwitchToObserver", "");
      }
    }

    Item {
      Layout.preferredWidth: childrenRect.width
      Layout.preferredHeight: childrenRect.height
      W.ButtonContent {
        text: isReady ? Lua.tr("Cancel Ready") : Lua.tr("Ready")
        visible: !isOwner && !roomScene.isRoomObserver
        enabled: !opTimer.running
        onClicked: {
          opTimer.start();
          Cpp.notifyServer("Ready", "");
        }
      }

      W.ButtonContent {
        text: Lua.tr("Add Robot")
        visible: isOwner && !isFull
        enabled: Config.serverFeatures.includes("AddRobot") && canAddRobot
        onClicked: {
          Cpp.notifyServer("AddRobot", "");
        }
        onPressAndHold: { // 长按以机器人补全
          for (let i = 0; i < playerNum; i++) {
            if (!canAddRobot) break;
            Cpp.notifyServer("AddRobot", "");
          }
        }
      }

      W.ButtonContent {
        text: Lua.tr("Start Game")
        visible: isOwner && isFull
        enabled: isAllReady
        onClicked: {
          Cpp.notifyServer("StartGame", "");
        }
      }
    }
  }

  // 旁观者区域
  Rectangle {
    id: observerArea
    visible: observerModel.count > 0
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.top: parent.top
    anchors.topMargin: 40
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 72
    width: 180
    color: "#DDF0F0F0"
    radius: 8

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      y: 8
      text: Lua.tr("Spectators") + " (" + observerModel.count + ")"
      font.pixelSize: 16
      font.bold: true
    }

    ListView {
      anchors.top: parent.top
      anchors.topMargin: 36
      anchors.left: parent.left
      anchors.leftMargin: 8
      anchors.right: parent.right
      anchors.rightMargin: 8
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 8
      model: observerModel
      clip: true
      spacing: 4
      delegate: Text {
        required property var modelData
        width: ListView.view.width
        text: modelData.screenName + (modelData.isOwner ? "[房主]" :"")
        font.pixelSize: 14
        color: "#555"
        elide: Text.ElideRight
      }
    }
  }

  // 旁观者等待提示
  Text {
    id: observerHint
    visible: roomScene.isRoomObserver
    anchors.centerIn: roomArea
    text: Lua.tr("Waiting for game to start as spectator...")
    font.pixelSize: 20
    color: "#888"
  }

  // 旁观者操作按钮
  W.ButtonContent {
    visible: roomScene.isRoomObserver && !isFull
    anchors.top: observerHint.bottom
    anchors.topMargin: 12
    anchors.horizontalCenter: roomArea.horizontalCenter
    text: Lua.tr("Take Seat")
    enabled: !isFull
    onClicked: Cpp.notifyServer("SwitchToPlayer", "")
  }

  // TODO 扬了这玩意
  function givePresent(tp, pid) {
    ClientInstance.notifyServer(
      "Chat",
      {
        type: 2,
        msg: "$@" + tp + ":" + pid
      }
    );
  }


  function getPhotoModel(id) {
    for (let i = 0; i < playerNum; i++) {
      const item = photoModel.get(i);
      if (item.id === id) {
        return item;
      }
    }
    return undefined;
  }

  function getPhoto(id) {
    for (let i = 0; i < playerNum; i++) {
      const item = photoModel.get(i);
      if (item.id === id) {
        return photos.itemAt(i);
      }
    }
    return undefined;
  }

  function checkCanAddRobot() {
    if (Config.serverFeatures.includes("AddRobot")) {
      const num = Lua.getCompNum();
      canAddRobot = num.maxComp > num.curComp;
    }
  }

  function addInitComputers() {
    const num = Lua.getCompNum();
    const min = num.minComp;
    const cur = num.curComp;
    const robotsToAdd = Math.max(0, min - cur);
    for (let i = 0; i < robotsToAdd; i++) {
      Cpp.notifyServer("AddRobot", "");
    }
  }

  function checkAllReady() {
    let allReady = true;
    for (let i = 0; i < playerNum; i++) {
      const item = photoModel.get(i);
      if (!item.isOwner && !item.ready) {
        allReady = false;
        break;
      }
    }
    roomScene.isAllReady = allReady;

    if (roomScene.isAllReady && roomScene.isOwner && !isRoomObserver && Cpp.quickStartMode) {
      Cpp.notifyServer("StartGame", "");
    }
  }

  function updateGameData(sender, data) {
    const id = data[0];
    const total = data[1];
    const win = data[2];
    const run = data[3];
    const photo = getPhotoModel(id);
    if (photo) {
      photo.total = total;
      photo.win = win;
      photo.run = run;
    }
  }

  function setRoomOwner(sender, data) {
    // jsonData: int uid of the owner
    const uid = data[0];

    roomScene.isOwner = (Self.id === uid);

    const model = getPhotoModel(uid);
    if (typeof(model) !== "undefined") {
      model.isOwner = true;
    }

    checkAllReady();
  }

  function readyChanged(sender, data) {
    const id = data[0];
    const ready = data[1];

    if (id === Self.id) {
      roomScene.isReady = !!ready;
    }

    const model = getPhotoModel(id);
    if (typeof(model) !== "undefined") {
      model.ready = ready ? true : false;
      checkAllReady();
    }
  }

  function addPlayer(sender, data) {
    // jsonData: int id, string screenName, string avatar, bool ready
    for (let i = 0; i < playerNum; i++) {
      const item = photoModel.get(i);
      if (item.id === -1) {
        const uid = data[0];
        const name = data[1];
        const avatar = data[2];
        const ready = data[3];

        item.id = uid;
        item.screenName = name;
        item.general = avatar;
        item.avatar = avatar;
        item.ready = ready;
        item.sealed = false;

        checkAllReady();

        if (getPhoto(-1)) {
          roomScene.isFull = false;
        } else {
          roomScene.isFull = true;
        }
        roomScene.playersAltered = true;

        return;
      }
    }
  }

  function removePlayer(sender, data) {
    // jsonData: int uid
    const uid = data[0];
    const model = getPhotoModel(uid);
    if (typeof(model) !== "undefined") {
      model.id = -1;
      model.screenName = "";
      model.avatar = "";
      model.general = "";
      model.isOwner = false;
      roomScene.isFull = false;
      roomScene.playersAltered = true;
    }
  }

  function resetPhotos() {
    photoModel.clear();
    if (roomScene.isRoomObserver) {
      // 旁观者不占座位
      for (let i = 0; i < 10; i++) {
        photoModel.append({
          id: -1,
          avatar: "",
          screenName: "",
          seatNumber: i + 1,
          kingdom: "unknown",
          isOwner: false,
          ready: false,
          sealed: i > playerNum - 1,
          win: 0,
          run: 0,
          total: 0,
        });
      }
      // 把自己加入旁观列表
      addObserver(null, [Self.id, Self.screenName, Self.avatar]);
    } else {
      for (let i = 0; i < 10; i++) {
        photoModel.append({
          id: i ? -1 : Self.id,
          avatar: i ? "" : Self.avatar,
          screenName: i ? "" : Self.screenName,
          seatNumber: i + 1,
          kingdom: "unknown",
          isOwner: false,
          ready: false,
          sealed: i >= playerNum,
          win: 0,
          run: 0,
          total: 0,
        });
      }
    }

    checkCanAddRobot();
    checkAllReady();
    isFull = !getPhoto(-1);
  }

  function loadPlayerData(sender) {
    const datalist = Lua.evaluate(`table.map(ClientInstance.players, function(p)
      local cp = p.player
      local gameData = cp:getGameData()
      return {
        id = p.id,
        name = cp:getScreenName(),
        avatar = cp:getAvatar(),
        ready = p.ready,
        isOwner = p.owner,
        gameTime = cp:getTotalGameTime(),
        total = gameData:at(0),
        win = gameData:at(1),
        run = gameData:at(2),
      }
    end)`);

    resetPhotos();

    for (const d of datalist) {
      if (d.id === Self.id) {
        roomScene.isOwner = d.isOwner;
      } else {
        addPlayer(null, [d.id, d.name, d.avatar, d.ready, d.gameTime]);
      }
      const model = getPhotoModel(d.id);
      model.ready = d.ready;
      model.isOwner = d.isOwner;
      model.total = d.total;
      model.win = d.win;
      model.run = d.run;
    }

    const obdatalist = Lua.evaluate(`table.map(ClientInstance.observers, function(t)
      local cp = t[2]
      return {
        id = cp:getId(),
        name = cp:getScreenName(),
        avatar = cp:getAvatar(),
      }
    end)`);

    for (const d of datalist) {
      addObserver(null, [d.id, d.name, d.avatar]);
    }

    checkAllReady();
  }

  function restartGame(sender) {
    loadPlayerData(sender);
    Cpp.notifyServer("StartGame", "");
  }

  function startGame() {
    canKickOwner = false;
    kickOwnerTimer.stop();
    Backend.playSound("./audio/system/gamestart");

    let data ;
    const boardgame = Lua.evaluate(`Fk:getBoardGame(ClientInstance.settings.gameMode).name`);
    const ui_config = Config.enabledUIPackages[boardgame];
    if (ui_config !== undefined && ui_config !== "default" && Lua.evaluate(`not not Fk:getUIPackage("${ui_config}")`)) {
      data = Lua.evaluate(`Fk.ui_packages["${ui_config}"].page`)
    } else {
      data = Lua.evaluate(`Fk:getBoardGame(ClientInstance.settings.gameMode).page`)
    }
    App.changeRoomPage(data);
  }

  function changeRoomConfig(_, data) {
    App.setBusy(false);

    Config.roomCapacity = data[0];
    Config.roomTimeout = data[1] - 1;
    const roomSettings = data[2];
    Config.heg = roomSettings.gameMode.includes('heg_mode');

    let displayName = roomSettings.roomName;
    if (roomSettings.roomId !== undefined) {
      displayName += "[{id}]".replace("{id}", roomSettings.roomId);
    }
    Config.headerName = Lua.tr("Current room: %1").arg(displayName);

    playerNum = Config.roomCapacity;
    for (let i = 0; i < 10; i++) {
      photoModel.get(i).sealed = i >= playerNum;
    }
    roominfo.refresh();

    checkAllReady();
    checkCanAddRobot();
    if (getPhoto(-1)) {
      isFull = false;
    } else {
      isFull = true;
    }

    App.showToast(Lua.tr("$RoomConfigChanged"));
  }

  function autoAddRobot() {
    const robotNum = playerNum - 1
    if (Cpp.quickStartMode !== "") {
      for (let i = 0; i < robotNum; i++) Cpp.notifyServer("AddRobot", "");
    }
  }

  function addObserver(sender, data) {
    const [id, name, avatar] = data;
    for (let i = 0; i < observerModel.count; i++) {
      if (observerModel.get(i).id === id) return;
    }
    observerModel.append({ id, screenName: name, avatar });
  }

  function removeObserver(sender, data) {
    const uid = data[0];
    for (let i = 0; i < observerModel.count; i++) {
      if (observerModel.get(i).id === uid) {
        observerModel.remove(i);
        return;
      }
    }
  }

  function handleSwitchToPlayer(_, data) {
    // TODO: 应该不能这么草率，下同，还没仔细思考
    const uid = data[0];
    const dat = { id: uid };
    for (let i = 0; i < observerModel.count; i++) {
      const model = observerModel.get(i);
      if (model.id === uid) {
        dat.screenName = model.screenName;
        dat.avatar = model.avatar;
        observerModel.remove(i);
        break;
      }
    }

    addPlayer(_, [ dat.id, dat.screenName, dat.avatar, false ]);

    if (uid == Cpp.self.id) {
      Config.observing = false;
    }
  }

  function handleSwitchToObserver(_, data) {
    const uid = data[0];
    const model = getPhotoModel(uid);
    if (typeof(model) !== "undefined") {
      addObserver(_, [ model.id, model.screenName, model.avatar ]);

      model.id = -1;
      model.screenName = "";
      model.avatar = "";
      model.general = "";
      model.isOwner = false;
      roomScene.isFull = false;
      roomScene.playersAltered = true;
    }

    if (uid == Cpp.self.id) {
      Config.observing = true;
    }
  }

  Component.onCompleted: {
    addCallback(Command.UpdateGameData, updateGameData);
    addCallback(Command.RoomOwner, setRoomOwner);

    addCallback(Command.ReadyChanged, readyChanged);
    addCallback(Command.AddPlayer, addPlayer);
    addCallback(Command.RemovePlayer, removePlayer);

    addCallback(Command.StartGame, startGame);
    addCallback(Command.BackToRoom, loadPlayerData);
    addCallback(Command.RestartGame, restartGame);

    addCallback(Command.ChangeRoom, changeRoomConfig);

    addCallback("SwitchToPlayer", handleSwitchToPlayer);
    addCallback("SwitchToObserver", handleSwitchToObserver);

    playerNum = Config.roomCapacity;
    canChangeRoom = Config.serverFeatures.includes("ChangeRoom");
    resetPhotos();
    autoAddRobot();

    if (roomScene.isRoomObserver) {
      App.showToast(Lua.tr("$EnterRoomObserve"));
      // 从EnterRoom数据中读取已有玩家列表(必须在resetPhotos之后)
      const playerList = Lua.client.settings._players;
      if (playerList) {
        for (const p of playerList) {
          addPlayer(null, [p[0], p[1], p[2], !!p[3], p[4]]);
          if (p[5]) setRoomOwner(null, [p[0]]);
        }
      }
      // 从EnterRoom数据中同步已有旁观者列表
      const observerList = Lua.client.settings._observers;
      if (observerList) {
        for (const o of observerList) {
          addObserver(null, [o[0], o[1], o[2]]);
        }
      }
    } else {
      App.showToast(Lua.tr("$EnterRoom"));
    }
  }
}
