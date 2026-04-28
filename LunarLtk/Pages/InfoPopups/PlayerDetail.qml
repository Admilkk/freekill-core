// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Models
import LunarLtk.Components

Flickable {
  id: root
  anchors.fill: parent

  signal finish()

  required property PhotoModel dataModel

  contentHeight: details.height
  ScrollBar.vertical: ScrollBar {}

  ColumnLayout {
    id: details
    width: parent.width - 40
    x: 20

    RowLayout {
      spacing: 8
      Avatar {
        id: avatar
        Layout.preferredWidth: 56
        Layout.preferredHeight: 56
        general: root.dataModel.avatar
      }

      ColumnLayout {
        Text {
          id: screenName
          font.pixelSize: 18
          color: "#E4D5A0"
          text: {
            const id = dataModel.playerid;
            if (id === 0 || id === undefined) return "";

            let ret = root.dataModel.screenName;

            const gamedata = Lua.getPlayerGameData(id);
            const totalTime = gamedata[3];
            const h = (totalTime / 3600).toFixed(2);
            const m = Math.floor(totalTime / 60);
            if (m < 100) {
              ret += " (" + Lua.tr("TotalGameTime: %1 min").arg(m) + ")";
            } else {
              ret += " (" + Lua.tr("TotalGameTime: %1 h").arg(h) + ")";
            }

            return ret;
          }
        }

        Text {
          id: playerGameData
          Layout.fillWidth: true
          font.pixelSize: 18
          color: "#E4D5A0"
          text: {
            const id = dataModel.playerid;
            if (id === 0 || id === undefined) return "";

            const gamedata = Lua.getPlayerGameData(id);
            const total = gamedata[0];
            const win = gamedata[1];
            const run = gamedata[2];
            const winRate = (win / total) * 100;
            const runRate = (run / total) * 100;

            return total === 0 ? Lua.tr("Newbie") :
              Lua.tr("Win=%1 Run=%2 Total=%3").arg(winRate.toFixed(2))
                .arg(runRate.toFixed(2)).arg(total);
          }
        }
      }
    }

    RowLayout {
      MetroButton {
        text: Lua.tr("Give Flower")
        visible: !Config.observing
        onClicked: {
          enabled = false;
          root.givePresent("Flower");
          root.finish();
        }
      }

      MetroButton {
        text: Lua.tr("Give Egg")
        visible: !Config.observing
        onClicked: {
          enabled = false;
          if (Math.random() < 0.03) {
            root.givePresent("GiantEgg");
          } else {
            root.givePresent("Egg");
          }
          root.finish();
        }
      }

      MetroButton {
        text: Lua.tr("Give Wine")
        visible: !Config.observing
        enabled: Math.random() < 0.3
        onClicked: {
          enabled = false;
          root.givePresent("Wine");
          root.finish();
        }
      }

      MetroButton {
        text: Lua.tr("Give Shoe")
        visible: !Config.observing
        enabled: Math.random() < 0.3
        onClicked: {
          enabled = false;
          root.givePresent("Shoe");
          root.finish();
        }
      }

      MetroButton {
        text: {
          const name = dataModel.screenName;
          const blocked = !Config.blockedUsers.includes(name);
          return blocked ? Lua.tr("Block Chatter") : Lua.tr("Unblock Chatter");
        }
        enabled: root.dataModel.playerid !== Cpp.self.id && root.dataModel.playerid > 0 // 旁观屏蔽不了正在被旁观的人
        onClicked: {
          const name = dataModel.screenName;
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
    }

    RowLayout {
      spacing: 20
      ColumnLayout {
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: 16

        GeneralCardItem {
          id: mainChara
          dataModel: Ltk.createGeneralCardModel(root.dataModel.general)
          visible: true
        }
        GeneralCardItem {
          id: deputyChara
          dataModel: Ltk.createGeneralCardModel(root.dataModel.deputyGeneral || "caocao")
          visible: !!root.dataModel.deputyGeneral
        }
      }

      TextEdit {
        id: skillDesc

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: 10
        font.pixelSize: 18
        color: "#E4D5A0"

        readOnly: true
        selectByKeyboard: true
        selectByMouse: false
        wrapMode: TextEdit.WordWrap
        textFormat: TextEdit.RichText
        property var savedtext: []
        function clearSavedText() {
          savedtext = [];
        }
        onLinkActivated: (link) => {
          if (link === "back") {
            text = savedtext.pop();
          } else {
            savedtext.push(text);
            text = '<a href="back">' + Lua.tr("Click to back") + '</a><br>' + Lua.tr(link);
          }
        }

        text: root.getSkillDescText();
      }
    }
  }

  function givePresent(p) {
    ClientInstance.notifyServer(
      "Chat",
      {
        type: 2,
        msg: "$@" + p + ":" + dataModel.playerid
      }
    );
  }

  function getSkillDescText() {
    const skillnamecss = `
    <style>
    .skill-name {
      color: "#9FD49C";
      font-size: 20px;
      font-weight: bold;
    }
    .skill-name.locked {
      color: "grey";
    }
    </style>
    `;
    skillDesc.text = "";
    skillDesc.clearSavedText();

    const id = dataModel.playerid;
    if (id === 0 || id === undefined) return;
    const player = Ltk.getPlayer(id);
    const self = Lua.selfPlayer;

    Ltk.getPlayerSkills(id).forEach(t => {
      // TODO 等core更新强制重启后把这个智慧杀了 GetPlayerSkill直接返回invalid
      const invalid = t.name.endsWith(Lua.tr('skill_invalidity'));
      let skillText = `${skillnamecss}<font class='${invalid ? "skill-name locked" : "skill-name"}'>${t.name}</font> `;
      if (invalid) {
        skillText += `<font color='grey'>${t.description}</font>`;
      } else {
        skillText += `${t.description}`;
      }

      skillDesc.append(skillText);
    });

    const ej = player.getCardIds("ej");
    let unknownCardsNum = 0;
    ej.forEach(cid => {
      const t = Ltk.getCardData(cid);
      if (self.cardVisible(cid)) {
        skillDesc.append("------------------------------------")
        const v = Ltk.getVirtualEquipData(id, cid);
        if (v) {
          skillDesc.append(
            "<b>" + "(" + Lua.tr(t.name) + Lua.tr("log_" + t.suit) + Lua.tr(t.number.toString()) + ")" 
            + Lua.tr(v.name) + "</b>: " + Lua.tr(":" + v.name)
          );
        } else {
          skillDesc.append(
            "<b>" + Lua.tr(t.name) + "(" + Lua.tr("log_" + t.suit) + Lua.tr(t.number.toString()) + ")"
            + "</b>: " + Lua.tr(":" + t.name)
          );
        }
      } else {
        unknownCardsNum++;
      }
    });
    if (unknownCardsNum > 0) {
      skillDesc.append("------------------------------------")
      skillDesc.append(Lua.tr("unknown") + " * " + (unknownCardsNum));
    }

    // 幽默记牌器环节 FIXME：帮忙补补翻译表 FIXME: 帮忙补补区域 FIXME: 帮忙整个重做
    skillDesc.append("------------------------------------");
    const knownHandcards = Lua.evaluate(`Self.card_tracker:getPlayerKnownCards(${id}, Player.Hand)`);
    if (!knownHandcards) {
      skillDesc.append("没有已知手牌");
    } else {
      const realKnown = knownHandcards.known_cards;
      const uncertain = knownHandcards.uncertain_cards;
      if (realKnown.length === 0 && uncertain.length === 0) {
        skillDesc.append("没有已知手牌");
      } else {
        if (realKnown.length > 0) {
          skillDesc.append("已知手牌：" +
            realKnown.map(id => Ltk.getCard(id).toLogString(false)).join(","));
        }
        if (uncertain.length > 0) {
          skillDesc.append("不确定手中是否拥有的手牌：" +
            uncertain.map(id => Ltk.getCard(id).toLogString(false)).join(","));
        }
      }
    }
  }
}
