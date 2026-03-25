// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

import Fk
import Fk.Components.Common
import Fk.Widgets as W

import LunarLtk
import LunarLtk.Components
import LunarLtk.Components.Photo as PhotoElement
import "RoomLogic.js" as Logic

W.PageBase {
  id: roomScene

  property var agItem // 五谷框
  property var popupItem // 弹窗
  property alias bigAnim: bigAnim
  property alias okCancel: okCancel
  property alias okButton: okButton
  property alias cancelButton: cancelButton
  property alias dynamicCardArea: dynamicCardArea
  property alias tableCards: tablePile.cards
  property alias dashboard: dashboard
  property alias drawPile: drawPile
  property alias skillInteraction: skillInteraction
  property alias banner: banner

  // 权宜之计 后面全改
  property alias cheatDrawer: cheatLoader

  property alias dataModel: dataModel

  RoomModel {
    id: dataModel
    roomPage: roomScene

    onSeatChanged: arrangePhotos();
    onPlayerAdded: model => roomScene.photoModel.push(model);
    onCardsMoved: (move, data) => roomScene.moveCards(move, data);

    onActivated: {
      progressAnim.from = (dataModel.requestDuration / dataModel.requestTotal) * 100.0;
      progressAnim.duration = dataModel.requestDuration;
      progress.visible = true;
    }

    onDeActivated: {
      skillInteraction.sourceComponent = undefined;
      progress.visible = false;

      dashboard.disableAllCards();

      if (popupItem != null) {
        popupItem.finished();
      }

      Ltk.finishRequestUI();
      applyChange({});
    }

    onPopupReady: (command, data, model) => {
      let component;
      let prop = { dataModel: model };
      if (!model) delete prop.dataModel;

      const componentTable = {
        [Command.AskForArrangeCards]: "ArrangeCardsBox",
        [Command.AskForChoices]: "ChoicesBox",
        [Command.AskForGeneral]: "ChooseGeneralBox",
        [Command.AskForCardChosen]: "PlayerCardBox",
        [Command.AskForPoxi]: "PoxiBox",
        [Command.AskForMoveCardInBoard]: "MoveCardInBoardBox",
        [Command.AskForCardsAndChoice]: "ChooseCardsAndChoiceBox",

        [Command.GameOver]: "GameOver",
      };

      if (command == Command.CustomDialog) {
        component = Lua.createComponent(data.component);
      } else {
        component = Qt.createComponent("LunarLtk.Pages.Popups", componentTable[command]);
      }

      showPopup(component, prop);
    }

    onAgReady: roomScene.showAG();
  }

  MediaPlayer {
    id: bgm
    source: Config.bgmFile

    loops: MediaPlayer.Infinite
    onPlaybackStateChanged: {
      if (playbackState == MediaPlayer.StoppedState)
        play();
    }
    audioOutput: AudioOutput {
      volume: Config.bgmVolume / 100
    }
  }

  /* Layout:
   * +---------------------+
   * |   Photos, get more  |
   * | in arrangePhotos()  |
   * |      tablePile      |
   * | progress,prompt,btn |
   * +---------------------+
   * |      dashboard      |
   * +---------------------+
   */

  property list<PhotoModel> photoModel

  Item {
    id: roomArea
    width: roomScene.width
    height: roomScene.height - dashboard.height + 20

    Repeater {
      id: photos
      model: photoModel
      Photo {
        required property PhotoModel modelData
        dataModel: modelData

        onRightClicked: {
          if (playerid === 0 || playerid === -1) return;
          roomScene.startCheat("PlayerDetail", { photo: this });
        }

        Component.onCompleted: {
          if (dataModel.index === 0) {
            enableChangeSkin = true;
          }
        }
      }
    }

    onWidthChanged: arrangePhotos();
    onHeightChanged: arrangePhotos();

    InvisibleCardArea {
      id: drawPile
      x: parent.width / 2
      y: roomScene.height / 2
    }

    TablePile {
      id: tablePile
      width: parent.width * 0.7
      height: 150
      x: parent.width * 0.15
      y: parent.height * 0.6 + 10
    }
  }

  Item {
    id: dashboardBtn
    width: childrenRect.width
    height: childrenRect.height
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 8
    anchors.left: parent.left
    anchors.leftMargin: 8
    ColumnLayout {
      MetroButton {
        text: Lua.tr("Choose one handcard")
        textFont.pixelSize: 28
        visible: {
          if (!progressAnim.running) return false;
          if (dashboard.handcardArea.length <= 15) {
            return false;
          }
          const cards = dashboard.handcardArea.cards;
          for (const card of cards) {
            if (card.selectable) return true;
          }
          return false;
        }
        onClicked: roomScene.startCheat("ChooseHandcard");
      }
      MetroButton {
        id: trustBtn
        text: Lua.tr("Trust")
        enabled: !Config.observing && !Config.replaying
        visible: !Config.observing && !Config.replaying
        textFont.pixelSize: 28
        onClicked: {
          Cpp.notifyServer("Trust", "");
          trustBtn.enabled = false;
          roomScene.dataModel.deActivate();
        }
      }
      MetroButton {
        id: revertSelectionBtn
        text: Lua.tr("Revert Selection")
        textFont.pixelSize: 28
        onClicked: Ltk.revertSelection();
      }
      MetroButton {
        id: sortBtn
        text: Lua.tr("Sort Cards")
        textFont.pixelSize: 28
        enabled: dashboard.sortable
        onClicked: {
          if (dashboard.sortable) {
            let sortMethod = 0;
            for (let index = 0; index < sortMenuRepeater.count; index++) {
              var tCheckBox = sortMenuRepeater.itemAt(index)
              if (tCheckBox.checked) sortMethod = index;
            }
            roomScene.dataModel.dashboard.sortHandcards(sortMethod);
          }
        }

        onRightClicked: {
          if (sortMenu.visible) {
            sortMenu.close();
          } else {
            sortMenu.open();
          }
        }

        ToolTip {
          id: sortTip
          x: 20
          y: -20
          visible: parent.hovered && !sortMenu.visible
          delay: 1500
          timeout: 6000
          text: Lua.tr("Right click or long press to choose sort method")
          font.pixelSize: 20
        }

        Menu {
          id: sortMenu
          x: parent.width
          y: -25
          width: parent.width * 2
          background: Rectangle {
            color: "black"
            border.width: 3
            border.color: "white"
            opacity: 0.8
          }

          Repeater {
            id: sortMenuRepeater
            model: ["Sort by Type", "Sort by Number", "Sort by Suit"]

            RadioButton {
              id: control
              text: "<font color='white'>" + Lua.tr(modelData) + "</font>"
              checked: modelData === "Sort by Type"
              font.pixelSize: 20

              indicator: Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                x: control.leftPadding
                y: control.height / 2 - height / 2
                radius: 3
                border.color: "white"

                Rectangle {
                  width: 14
                  height: 14
                  x: 6
                  y: 6
                  radius: 2
                  color: control.down ? "#17a81a" : "#21be2b"
                  visible: control.checked
                }
              }
            }
          }
        }
      }
      MetroButton {
        text: Lua.tr("Chat")
        textFont.pixelSize: 28
        onClicked: Mediator.notify(this, Command.IWantToChat);
      }
    }
  }

  Dashboard {
    id: dashboard
    width: roomScene.width - dashboardBtn.width
    anchors.top: roomArea.bottom
    anchors.left: dashboardBtn.right

    dataModel: roomScene.dataModel.dashboard
  }

  Item {
    id: controls
    anchors.bottom: dashboard.top
    anchors.bottomMargin: -60
    width: roomScene.width

    Text {
      id: prompt
      visible: progress.visible
      anchors.bottom: progress.bottom
      z: 1
      text: roomScene.dataModel.promptText
      color: "#F0E5DA"
      font.pixelSize: 16
      font.family: Config.libianName
      style: Text.Outline
      styleColor: "#3D2D1C"
      textFormat: TextEdit.RichText
      anchors.horizontalCenter: progress.horizontalCenter
    }

    ProgressBar {
      id: progress
      width: parent.width * 0.6
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: okCancel.top
      anchors.bottomMargin: 4
      from: 0.0
      to: 100.0

      visible: false

      background: Rectangle {
        implicitWidth: 200
        implicitHeight: 12
        color: "black"
        radius: 6
      }

      contentItem: Item {
        implicitWidth: 196
        implicitHeight: 10

        Rectangle {
          width: progress.visualPosition * parent.width
          height: parent.height
          radius: 6
          gradient: Gradient {
            GradientStop { position: 0.0; color: "orange" }
            GradientStop { position: 0.3; color: "red" }
            GradientStop { position: 0.7; color: "red" }
            GradientStop { position: 1.0; color: "orange" }
          }
        }
      }

      NumberAnimation on value {
        id: progressAnim
        running: progress.visible
        from: 100.0
        to: 0.0
        duration: Config.roomTimeout * 1000

        onFinished: {
          roomScene.dataModel.deActivate();
        }
      }
    }

    Rectangle {
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 8
      anchors.right: okCancel.left
      anchors.rightMargin: 20
      color: "#88EEEEEE"
      radius: 8
      visible: {
        if (roomScene.state !== "active") {
          return false;
        }
        if (!specialCardSkills) {
          return false;
        }
        if (specialCardSkills.count > 1) {
          return true;
        }
        return (specialCardSkills.model ?? false)
            && specialCardSkills.model[0] !== "_normal_use"
      }
      width: childrenRect.width
      height: childrenRect.height - 20

      RowLayout {
        y: -10
        Repeater {
          id: specialCardSkills
          RadioButton {
            property string orig_text: modelData
            text: Lua.tr(modelData)
            checked: index === 0
            onCheckedChanged: {
              Ltk.updateRequestUI("SpecialSkills", "1", "click", modelData);
            }
          }
        }
      }
    }

    Loader {
      id: skillInteraction
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 8
      anchors.right: okCancel.left
      anchors.rightMargin: 20
    }

    Row {
      id: okCancel
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: progress.horizontalCenter
      spacing: 20
      visible: dataModel.okCancelVisible

      Button {
        id: skipNullificationButton
        text: Lua.tr("SkipNullification")
        visible: dataModel.canSkipNullification
        onClicked: {
          dataModel.skipNullification();
        }
      }

      Button {
        id: okButton
        enabled: dataModel.okEnabled
        text: Lua.tr("OK")
        onClicked: Ltk.updateRequestUI("Button", "OK");
      }

      Button {
        id: cancelButton
        enabled: dataModel.cancelEnabled
        text: Lua.tr("Cancel")
        onClicked: Ltk.updateRequestUI("Button", "Cancel");
      }
    }

    Button {
      id: endPhaseButton
      text: Lua.tr("End")
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 40
      anchors.right: parent.right
      anchors.rightMargin: 30
      visible: dataModel.endButtonVisible
      onClicked: Ltk.updateRequestUI("Button", "End");
    }
  }

  Loader {
    id: bigAnim
    anchors.fill: parent
    z: 999
  }

  function activateSkill(skill_name, selected, action) {
    let data;
    if (action === "click") data = { selected, autoTarget: Config.autoTarget };
    else if (action === "doubleClick") data = { selected, doubleClickUse: Config.doubleClickUse, autoTarget: Config.autoTarget };
    else data = { selected };
    Ltk.updateRequestUI("SkillButton", skill_name, action, data);
  }

  W.PopupItem {
    id: cheatLoader
    width: Config.winWidth * 0.60
    height: Config.winHeight * 0.8
    anchors.centerIn: parent
    background: Rectangle {
      color: "#CC2E2C27"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }
  }

  Item {
    id: dynamicCardArea
    anchors.fill: parent
  }

  GlowText {
    anchors.centerIn: dashboard
    visible: getPhoto(Cpp.self.id).rest > 0 && !Config.observing
    text: Lua.tr("Resting, don't leave!")
    color: "#DBCC69"
    font.family: Config.libianName
    font.pixelSize: 28
    glow.color: "#2E200F"
    glow.spread: 0.6
  }

  Rectangle {
    anchors.fill: dashboard
    visible: Config.observing && !Config.replaying
    color: "transparent"
    GlowText {
      anchors.centerIn: parent
      text: Lua.tr("Observing ...")
      color: "#4B83CD"
      font.family: Config.li2Name
      font.pixelSize: 48
    }
  }

  MiscStatus {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 108
    anchors.topMargin: 8

    dataModel: roomScene.dataModel
  }

  PhotoElement.MarkArea {
    id: banner
    x: 12; y: 12
    width: ((roomScene.width - 175 * 0.75 * 7) / 4 + 175 - 16) * 0.75
    transformOrigin: Item.TopLeft
    bgColor: "#BB838AEA"

    markModel: roomScene.dataModel.marks
  }

  Shortcut {
    sequence: "D"
    property bool show_distance: false
    onActivated: {
      show_distance = !show_distance;
      showDistance(show_distance);
    }
  }

  Shortcut {
    sequence: "Return"
    enabled: dataModel.okEnabled
    onActivated: Ltk.updateRequestUI("Button", "OK");
  }

  Shortcut {
    sequence: "Space"
    enabled: dataModel.cancelEnabled || endPhaseButton.visible;
    onActivated: if (dataModel.cancelEnabled) {
      Ltk.updateRequestUI("Button", "Cancel");
    } else {
      dataModel.replyToServer("");
    }
  }

  Timer {
    id: statusSkillTimer
    interval: 200
    running: true
    repeat: true
    onTriggered: {
      dataModel.refreshData();
      Ltk.refreshStatusSkills();
      // 刷托管按钮
      trustBtn.enabled = true;
    }
  }

  // 当创建新的ui时，可以重写该函数以显示自定义组件（如卡牌等）。
  function createComponent(spec, parent) {
    return Lua.createComponent(spec, parent);
  }

  function showDistance(show) {
    for (const model of photoModel) {
      if (show) {
        model.distance = Lua.selfPlayer.distanceTo(model.luaPlayer);
      } else {
        model.distance = -1;
      }
    }
  }

  function showPopup(component, prop) {
    const item = component.createObject(roomScene, prop);
    popupItem = item;

    const moveToCenter = () => {
      item.x = Math.round((roomArea.width - item.width) / 2);
      item.y = Math.round(roomArea.height * 0.67 - item.height / 2);
    }

    item.finished.connect(() => {
      item.destroy();
      roomScene.popupItem = null;
    });
    item.widthChanged.connect(() => moveToCenter());
    item.heightChanged.connect(() => moveToCenter());

    moveToCenter();

    item?.shown();
  }

  function showAG() {
    const component = Qt.createComponent("LunarLtk.Pages.Popups", "AG");
    const item = component.createObject(roomScene, { dataModel: dataModel.agModel });
    agItem = item;

    const moveToCenter = () => {
      item.x = Math.round((roomArea.width - item.width) / 2);
      item.y = Math.round(roomArea.height * 0.67 - item.height / 2);
    }

    item.finished.connect(() => {
      item.destroy();
      roomScene.agItem = null;
    });
    item.widthChanged.connect(() => moveToCenter());
    item.heightChanged.connect(() => moveToCenter());

    moveToCenter();
  }

  function startCheat(type, data) {
    let component = Qt.createComponent(type);
    if (component.status !== Component.Ready) {
      component = Qt.createComponent("LunarLtk.Components.Cheat", type);
    }
    cheatLoader.setSourceComponent(component, { extra_data: data });
    cheatLoader.open();
  }

  function startCheatByPath(path, data) {
    const component = Qt.createComponent(`${Cpp.path}/${path}.qml`);
    cheatLoader.setSourceComponent(component, { extra_data: data });
    cheatLoader.open();
  }

  function closeCheat() {
    cheatLoader.close();
  }

  function getPhoto(id) {
    return dataModel.getPhoto(id)?.photoItem;
  }

  function getPhotoOrDashboard(id) {
    if (id === Cpp.self.id) return dashboard;
    return getPhoto(id);
  }

  function applyChange(uiUpdate) {
    const sskilldata = uiUpdate["SpecialSkills"]?.[0]
    if (sskilldata) {
      specialCardSkills.model = sskilldata?.skills ?? [];
    }

    dataModel.applyChange(uiUpdate);
    dashboard.applyChange(uiUpdate);

    // Interaction最后上桌 太给脸了居然插结
    uiUpdate["_delete"]?.forEach(data => {
      if (data.type == "Interaction") {
        skillInteraction.sourceComponent = undefined;
        if (roomScene.popupItem)
          roomScene.popupItem.finished();
      }
    });
    uiUpdate["_new"]?.forEach(dat => {
      if (dat.type == "Interaction") {
        const data = dat.data.spec;
        const skill_name = dat.data.skill_name;
        switch (data.type) {
        case "combo":
        case "checkbox":
        case "cardname":
          const pages = {
            "combo": "SkillCombo",
            "checkbox": "SkillCheckBox",
            "cardname": "SkillCardName",
          };
          skillInteraction.sourceComponent = Qt.createComponent(
            "LunarLtk.Components.SkillInteraction", pages[data.type]);
          const modelComponent = Qt.createComponent("LunarLtk.Models.Popups", "ChoicesModel");
          const model = modelComponent.createObject(null, {
            choices: data.choices,
            allChoices: data.all_choices,
            cancelable: data.cancelable ?? false,
            skillName: skill_name,
            detailed: data.detailed ?? false,
            result: data.default ? [data.default] : [],
            minNum: data.min_num ?? 1,
            maxNum: data.max_num ?? 1,
          });
          skillInteraction.item.dataModel = model;
          skillInteraction.item.clicked();
          break;
        case "spin":
          skillInteraction.sourceComponent =
            Qt.createComponent("LunarLtk.Components.SkillInteraction", "SkillSpin");
          skillInteraction.item.skill = skill_name;
          skillInteraction.item.from = data.from;
          skillInteraction.item.to = data.to;
          skillInteraction.item.value = data.default;
          skillInteraction.item?.clicked();
          break;
        case "custom":
          skillInteraction.sourceComponent = Lua.createComponent(data.qml);
          if (data.qml.model) {
            const model = Lua.createQmlObject(data.qml.model);
            if ("skillName" in model) {
              model.skillName = skill_name;
            }
            skillInteraction.item.model = model;
          }
          skillInteraction.item?.clicked();
          break;
        default:
          skillInteraction.sourceComponent = undefined;
          break;
        }
      }
    });
  }

  function cancelAllFocus() {
    for (const model of dataModel.players) {
      const item = model.photoItem;
      item.progressBar.visible = false;
      item.progressTip = "";
    }
  }

  function moveFocus(sender, data) {
    const [ focuses, command ] = data;
    const timeout = data[2] ?? (Config.roomTimeout * 1000);

    cancelAllFocus();

    let item, model;
    for (const pid of focuses) {
      const model = dataModel.getPhoto(pid);
      if (!model) continue;
      // 这样其实不好。应该用signal从model传递到item，或者item建立绑定
      const item = model.photoItem;
      item.progressBar.duration = timeout;
      item.progressBar.visible = true;
      item.progressTip = Lua.tr(command)
        + Lua.tr(" thinking...");
    }
  }

  function doIndicate(from, tos) {
    const component = Qt.createComponent("LunarLtk.Components", "IndicatorLine");
    if (component.status !== Component.Ready)
      return;

    const fromItem = getPhotoOrDashboard(from);
    const fromPos = mapFromItem(fromItem, fromItem.width / 2,
                                fromItem.height / 2);

    const end = [];
    for (let i = 0; i < tos.length; i++) {
      if (from === tos[i])
        continue;
      const toItem = getPhotoOrDashboard(tos[i]);
      const toPos = mapFromItem(toItem, toItem.width / 2, toItem.height / 2);
      end.push(toPos);
    }

    const color = "#96943D";
    const line = component.createObject(roomScene, { start: fromPos, end: end, color: color });
    line.finished.connect(line.destroy);
    line.running = true;
  }

  function setPicEmotion(id, path, permanent) {
    const photo = getPhoto(id);
    if (!photo) return;
    photo.setEmotion(path, permanent);
  }

  function setEmotion(id, emotion, isCardId, permanent) {
    let path = Fs.convertUrlToPath(SkinBank.pixAnimDir + emotion);
    if (!Fs.exists(path) && !Fs.exists(path + ".png")) {
      path = Fs.convertUrlToPath(`${Cpp.path}/${emotion}`);
    }
    if (!Fs.exists(path)) {
      if (Fs.exists(path + ".png") && !isCardId) {
        setPicEmotion(id, path + ".png", permanent);
      }
      return;
    }

    if (!Fs.isDir(path)) {
      return;
    }

    const component = Qt.createComponent("LunarLtk.Components", "PixmapAnimation");
    if (component.status !== Component.Ready) {
      return;
    }

    let photo;
    if (isCardId === true) {
      photo = roomScene.tableCards.find(v => v.dataModel.cardId === id);
    } else {
      photo = getPhoto(id);
    }
    if (!photo) return;

    const animation = component.createObject(photo, {
      source: (OS === "Win" ? "file:///" : "") + path,
      scale: 0.75,
    });
    animation.anchors.centerIn = photo;
    if (isCardId) {
      animation.started.connect(() => photo.busy = true);
      animation.finished.connect(() => {
        photo.busy = false;
        animation.destroy()
      });
    } else {
      animation.finished.connect(animation.destroy);
    }
    animation.start();
  }

  function hideEmotion(playerId) {
    const photo = getPhoto(playerId);
    if (!photo) {
      return;
    }

    photo.hideEmotion();
  }

  function doSuperLightBox(path, data) {
    bigAnim.source = Cpp.path + "/" + path;
    if (data) {
      bigAnim.item.loadData(data);
    }
  }

  function notifySkillInvoked(playerId, skillName, skillType) {
    const photo = getPhoto(playerId);
    if (!photo) {
      return;
    }

    const component = Qt.createComponent("LunarLtk.Components", "SkillInvokeAnimation");
    if (component.status !== Component.Ready) {
      return;
    }

    const animation = component.createObject(photo, { skillName, skillType });
    animation.anchors.centerIn = photo;
    animation.finished.connect(animation.destroy);
  }

  function notifyUltSkillInvoked(playerId, skillName, isDeputy) {
    const photo = getPhoto(playerId);
    if (!photo) {
      return;
    }

    bigAnim.sourceComponent = Qt.createComponent("LunarLtk.Components", "UltSkillAnimation");
    bigAnim.item.loadData({
      skillName,
      general: data.deputy ? photo.deputyGeneral : photo.general,
    });
  }

  function doAnimate(sender, data) {
    switch (data.type) {
      case "Indicate":
        data.to.forEach(item => {
          doIndicate(data.from, [item[0]]);
          if (item[1]) {
            doIndicate(item[0], item.slice(1));
          }
        })
        break;
      case "Emotion":
        setEmotion(data.player, data.emotion, data.is_card, data.permanent);
        break;
      case "HideEmotion":
        hideEmotion(data.player);
        break;
      case "SuperLightBox": {
        doSuperLightBox(data.path, data.data);
        break;
      }
      case "InvokeSkill": {
        notifySkillInvoked(data.player, Lua.tr(data.name), data.skill_type || "special");
        break;
      }
      case "InvokeUltSkill": {
        notifyUltSkillInvoked(data.player, data.name, data.deputy);
        break;
      }
      default:
        break;
    }
  }

  function playDamageEffect(playerId, damageType, damageNum) {
    const photo = getPhoto(playerId);
    if (!photo) {
      return;
    }

    setEmotion(playerId, "damage");
    photo.tremble();
    Backend.playSound("./audio/system/" + damageType + (damageNum > 1 ? "2" : ""));
  }

  function playLoseHpEffect() {
    Backend.playSound("./audio/system/losehp");
  }

  function playChangeMaxEffect() {
    if (data.num < 0) {
      Backend.playSound("./audio/system/losemaxhp");
    }
  }

  function playGeneralSkillSound(skill, idx, general) {
    if (!general) {
      return false;
    }

    const dat = Ltk.getGeneralData(general);
    const extension = dat.extension;
    const path = SkinBank.getAudio(skill + "_" + general, extension, "skill");
    if (path) {
      Backend.playSound(path, idx);
      return true;
    }
  }

  function playSkillSound(skill, idx) {
    if (playGeneralSkillSound(data.general)) {
      return;
    }

    if (playGeneralSkillSound(data.deputy)) {
      return;
    }

    const dat = Ltk.getSkillData(skill);
    const path = SkinBank.getAudio(skill, dat.extension, "skill");
    Backend.playSound(path, idx);
  }

  function playSound(path) {
    const _path = SkinBank.getAudioByPath(path);
    Backend.playSound(_path);
  }

  function playDeathSound(playerId) {
    const photo = getPhoto(playerId);
    if (!photo) {
      return;
    }
    const general = photo.general;
    const extension = Ltk.getGeneralData(general).extension;
    const path = SkinBank.getAudio(general, extension, "death");
    Backend.playSound(path);
  }

  function logEvent(sender, data) {
    switch (data.type) {
      case "Damage": {
        playDamageEffect(data.to, data.damageType || "normal_damage", data.damageNum);
        break;
      }
      case "LoseHP": {
        playLoseHpEffect();
        break;
      }
      case "ChangeMaxHp": {
        playChangeMaxEffect();
        break;
      }
      case "PlaySkillSound": {
        playSkillSound(data.name, data.i, data.extension);
        break;
      }
      case "PlaySound": {
        playSound(data.name);
        break;
      }
      case "Death": {
        playDeathSound(data.to);
        break;
      }
      default:
        break;
    }
  }

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
    if (area === Ltk.Card.DrawPile) {
      return drawPile;
    } else if (area === Ltk.Card.DiscardPile || area === Ltk.Card.Processing ||
             area === Ltk.Card.Void) {
      return tablePile;
    }

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

  function showVirtualCard(sender, data) {
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

  function setupCallbacks() {
    dataModel.setupCallbacks();

    // TODO 摆烂了 反正这些后面也是得重构 懒得搬砖了
    addCallback(Command.MiniGame, Logic.callbacks["MiniGame"]);
    addCallback(Command.UpdateMiniGame, Logic.callbacks["UpdateMiniGame"]);
    addCallback(Command.UpdateRequestUI, Logic.callbacks["UpdateRequestUI"]);
    addCallback(Command.ChangeSkin, Logic.callbacks["ChangeSkin"]);

    addCallback(Command.MoveFocus, moveFocus);
    addCallback(Command.Animate, doAnimate);
    addCallback(Command.LogEvent, logEvent);

    addCallback(Command.CloseAG, () => agItem.close());

    addCallback(Command.ShowVirtualCard, showVirtualCard);
  }

  Component.onCompleted: {
    setupCallbacks();
    dataModel.initialize();

    bgm.play();

    for (let i = 0; i < dataModel.playerNum; i++) {
      photoModel.push(dataModel.players[i]);
    }

    arrangePhotos();
  }
}
