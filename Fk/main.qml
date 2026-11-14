import QtQuick
import QtQuick.Dialogs
import QtQuick.Window
import Fk

Window {
  id: root
  width: 1200
  height: 540
  minimumWidth: 200
  minimumHeight: 90
  readonly property bool skinDebuggerMode: Qt.application.arguments.indexOf("--skin-debugger") !== -1
  visible: !skinDebuggerMode

  title: qsTr("FreeKill") + " v" + Cpp.version

  onXChanged: if (!skinDebuggerMode) Config.winX = x;
  onYChanged: if (!skinDebuggerMode) Config.winY = y;
  onWidthChanged: if (!skinDebuggerMode) Config.winWidth = width;
  onHeightChanged: if (!skinDebuggerMode) Config.winHeight = height;

  Loader {
    id: gamePage
    objectName: "gameViewport"
    active: !root.skinDebuggerMode
    // Android can update the drawable area after hiding system bars or rotating.
    // Size the Loader explicitly; its loaded page always fills these logical bounds.
    readonly property real viewportWidth: Math.max(1, root.contentItem.width)
    readonly property real viewportHeight: Math.max(1, root.contentItem.height)
    width: Math.max(1200, 540 * viewportWidth / viewportHeight)
    height: Math.max(540, 1200 * viewportHeight / viewportWidth)
    scale: viewportWidth / width
    x: (viewportWidth - width) / 2
    y: (viewportHeight - height) / 2
    onViewportWidthChanged: if (active) Config.winWidth = viewportWidth;
    onViewportHeightChanged: if (active) Config.winHeight = viewportHeight;
    onScaleChanged: if (active) Config.winScale = scale;
    onLoaded: Config.winScale = scale;
    sourceComponent: Component {
      RootPage {
        id: mainWindow
        onConfLoaded: {
          if (Cpp.os != "Android") {
            root.x = Config.winX;
            root.y = Config.winY;
            root.width = Config.winWidth;
            root.height = Config.winHeight;
          } else {
            // Let Android own fullscreen geometry instead of freezing an early Screen size.
            root.showFullScreen();
            Config.winWidth = gamePage.viewportWidth;
            Config.winHeight = gamePage.viewportHeight;
          }
        }
      }
    }
  }

  Loader {
    objectName: "skinDebuggerLoader"
    active: root.skinDebuggerMode
    source: active ? Qt.resolvedUrl("Tools/SkinDebugger/Main.qml") : ""
  }

  MessageDialog {
    id: exitMessageDialog
    title: root.title
    informativeText: qsTr("Are you sure to exit?")
    buttons: MessageDialog.Ok | MessageDialog.Cancel
    onButtonClicked: function (button, role) {
      switch (button) {
        case MessageDialog.Ok: {
          gamePage.item.closing = true;
          Config.saveConf();
          Cpp.quitLobby(false);
          root.close();
          break;
        }
        case MessageDialog.Cancel: {
          exitMessageDialog.close();
        }
      }
    }
  }

  Shortcut {
    sequences: [ "F11", "Ctrl+F", "Alt+Return" ]
    onActivated: {
      if (root.visibility === Window.FullScreen)
        root.showNormal();
      else
        root.showFullScreen();
    }
  }

  onClosing: (closeEvent) => {
    if (root.skinDebuggerMode) {
      Qt.quit();
    } else if (gamePage.item && !gamePage.item.closing) {
      closeEvent.accepted = false;
      exitMessageDialog.open();
    }
  }
}
