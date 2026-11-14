import QtQuick

import Fk

BasicCard {
  id: root

  property string suit: "club"
  property int number: 7
  property string color: ""
  property string originalSuit: ""
  property int originalNumber: -1
  property string originalColor: ""

  readonly property real originalNumberOffset: originalNumber >= 0 ? 15 * cardScale : 0

  property real cardScale: 1

  Image {
    id: suitItem
    visible: parent.known
    source: (parent.suit != "" && parent.number > 0) ?
      SkinBank.searchBuiltinPic("/image/card/suit/", parent.suit === "nosuit" ? parent.color : parent.suit) : ""
    x: 3 * root.cardScale
    y: 19 * root.cardScale + root.originalNumberOffset
    width: 21 * root.cardScale
    height: 17 * root.cardScale
  }

  Image {
    id: numberItem
    visible: parent.known
    source: (parent.suit != "" && parent.number > 0) ?
      SkinBank.searchBuiltinPic(`/image/card/number/${parent.getColor()}/`, parent.number) : ""
    x: 0
    y: 0
    width: 27 * root.cardScale
    height: 28 * root.cardScale
  }

  Image { // 没点数的时候的suit位置
    id: colorItem
    visible: parent.known && parent.number <= 0
    source: (visible && parent.color !== "") ? SkinBank.cardSuitDir + "/" + ((parent.suit === "" || parent.suit === "nosuit") ? parent.color : parent.suit)
                                      : ""
    x: 3 * root.cardScale
    y: 9.5 * root.cardScale + root.originalNumberOffset
    width: 21 * root.cardScale
    height: 17 * root.cardScale
  }

  Item {
    visible: root.known && root.originalNumber >= 0
    x: 3 * root.cardScale
    y: 21 * root.cardScale
    width: 21 * root.cardScale
    height: 15 * root.cardScale

    Text {
      anchors.centerIn: parent
      visible: root.originalNumber === 0
      text: "0"
      font.pixelSize: 14 * root.cardScale
      color: root.originalColor === "red" ? "#a00000" : "black"
    }

    Image {
      anchors.centerIn: parent
      width: 21 * root.cardScale
      height: 22 * root.cardScale
      source: root.originalNumber > 0 ?
        SkinBank.searchBuiltinPic(`/image/card/number/${root.originalColor}/`, root.originalNumber) : ""
    }

    Rectangle { // 原始点数上的斜线
      anchors.centerIn: parent
      width: 15 * root.cardScale
      height: Math.max(2, 2 * root.cardScale)
      rotation: -45
      color: "#555555"
    }
  }

  Item {
    visible: root.known && root.originalSuit !== ""
    x: 3 * root.cardScale
    y: (root.number > 0 ? 34 : 25) * root.cardScale + root.originalNumberOffset
    width: 21 * root.cardScale
    height: 17 * root.cardScale

    Image {
      anchors.fill: parent
      source: root.originalSuit !== "" ? SkinBank.searchBuiltinPic("/image/card/suit/",
        root.originalSuit === "nosuit" ? root.originalColor : root.originalSuit) : ""
    }

    Rectangle { // 原始花色上的斜线
      anchors.centerIn: parent
      width: 15 * root.cardScale
      height: Math.max(2, 2 * root.cardScale)
      rotation: -45
      color: "#555555"
    }
  }

  function getColor() {
    if (suit != "")
      return (suit == "heart" || suit == "diamond") ? "red" : "black";
    else return color != "nocolor" ? "black" : color;
  }
}
