// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls

import LunarLtk

SpinBox {
  id: root
  background: Rectangle { color: "#88EEEEEE" }
  property alias answer: root.value
  property string skill
  // from, to

  onValueChanged: {
    Ltk.updateRequestUI("Interaction", "1", "update", value);
  }
}
