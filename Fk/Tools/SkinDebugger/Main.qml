import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import "Geometry.js" as Geometry

ApplicationWindow {
    id: root
    objectName: "skinDebuggerWindow"
    title: "新月杀 · 皮肤骨骼调试器"
    width: 1320; height: 900
    minimumWidth: 1080; minimumHeight: 720
    transientParent: null
    visible: true
    color: "#131922"
    palette.window: "#131922"
    palette.windowText: "#dce5f3"
    palette.base: "#111720"
    palette.text: "#dce5f3"
    palette.button: "#28364b"
    palette.buttonText: "#e4edfa"
    palette.highlight: "#4d8ff7"
    palette.accent: "#4d8ff7"
    palette.highlightedText: "#ffffff"
    font.family: "Microsoft YaHei"
    font.pixelSize: 13

    property var layers: [Geometry.newLayer("bg"), Geometry.newLayer("body"), Geometry.newLayer("front")]
    property int selected: 1
    readonly property var current: layers[selected]
    readonly property var roleNames: ["背景", "人物", "前景"]
    property real frameWidth: 103
    property real frameHeight: 166
    property real frameRadius: 6
    property real previewZoom: 2.7
    property real renderScale: 1
    property bool paused: false
    property bool showIntro: false
    property int replayKey: 0
    property bool crop: true
    property bool showGuides: true
    property bool showBones: false
    property color backdrop: "#292e39"
    property string message: "选择皮肤文件夹，或把 .skel / .json 拖入预览区。图集与 PNG 需配套。"
    property var history: []
    property var future: []
    property var layerStates: ["未导入", "未导入", "未导入"]
    property var layerMetadata: [{animations:[]}, {animations:[]}, {animations:[]}]
    property var layerBusy: [false, false, false]
    property var autoAnimations: ({})
    property var pendingFit: null
    property int fitSerial: 0
    readonly property var currentMetadata: layerMetadata[selected]
    readonly property var currentAnimations: currentMetadata.animations || []
    readonly property bool readyForFit: !!currentMetadata.version && !currentMetadata.error
        && !layerBusy[selected] && layerStates[selected].indexOf("已加载") === 0
    property real fitPadding: 4
    property bool fitActions: false
    property bool loadingFolder: false
    property string dialogPurpose: "skeleton"
    property string importKind: "extra"
    readonly property string luaOutput: Geometry.luaExtra(layers, renderScale)
    readonly property string projectOutput: Geometry.project(layers, renderScale, frameWidth, frameHeight, frameRadius)
    property bool smokeTest: Qt.application.arguments.indexOf("--skin-debugger-smoke-test") !== -1
    property bool actionSmokeTest: Qt.application.arguments.indexOf("--skin-debugger-action-test") !== -1
    property bool quitOnClose: true
    function previewLayer(index) { return layerRepeater.itemAt(index); }
    function capturePreview(callback) { captureRoot.grabToImage(callback); }
    function updateStatus(index, value) { const copy = layerStates.slice(); copy[index] = value; layerStates = copy; }
    function updateBusy(index, value) { const copy = layerBusy.slice(); copy[index] = value; layerBusy = copy; }
    function acceptMetadata(index, result) {
        const copy = layerMetadata.slice(); copy[index] = result; layerMetadata = copy;
        if (autoAnimations[index] !== layers[index].skeleton + "|" + layers[index].atlas || result.error || !result.animations.length) return;
        delete autoAnimations[index];
        const names = result.animations.map(function(it) { return it.name; });
        const normal = names.indexOf(layers[index].normal) !== -1 ? layers[index].normal
            : (names.find(function(name) { return /^(daiji|idle|stand|loop|default)$/i.test(name); }) || names[0]);
        const shown = names.find(function(name) { return /^(chuchang|appear|entry|start)$/i.test(name); }) || "";
        const hurtOnly = /shouji|shoushang|hurt|damage|受击|受伤/i.test(Geometry.basename(layers[index].skeleton));
        const attack = names.find(function(name) { return /^(gongji|attack|atk)(?:_\d+)?$/i.test(name); }) || "";
        const skill = names.find(function(name) { return /^(jineng|skill|special|teshu)(?:_\d+)?$/i.test(name); }) || "";
        const hurt = names.find(function(name) { return /^(shouji|shoushang|hurt|damage|hit)(?:_\d+)?$/i.test(name); }) || (hurtOnly ? (names.find(function(n) { return /^play$/i.test(n); }) || names[0]) : "");
        updateLayer(index, {normal:hurtOnly ? "" : normal, shown:hurtOnly ? "" : shown, attack:attack, skill:skill, hurt:hurt}, false); ++replayKey;
    }
    function fitContext(index) {
        return JSON.stringify({layer: layers[index], width: frameWidth, height: frameHeight,
            renderScale: renderScale, intro: showIntro, padding: fitPadding, actions:fitActions});
    }
    function cancelFit() {
        if (pendingFit) { pendingFit = null; message = "参数已变化，已取消适配；可按当前参数重新测量。"; }
    }
    function fitSelected(whole) {
        const preview = previewLayer(selected);
        if (!preview || !preview.loaded || layerBusy[selected]) return;
        const token = String(++fitSerial);
        pendingFit = {token:token, index:selected, context:fitContext(selected), whole:whole};
        if (!preview.requestFit(whole, token)) {
            pendingFit = null; message = "检测模块未就绪，请稍后重试。"; return;
        }
        message = "正在测量" + roleNames[selected] + (whole ? "的整段动画范围（30 帧/秒）…" : "的首帧范围…");
    }
    function acceptFit(index, result) {
        const pending = pendingFit;
        if (!pending || index !== pending.index || result.token !== "fit|" + pending.token) return;
        pendingFit = null;
        if (selected !== index || fitContext(index) !== pending.context) {
            message = "测量期间参数发生变化，已取消适配；可按当前参数重新测量。"; return;
        }
        if (result.error) { message = result.error; return; }
        try {
            const fitted = Geometry.fitIntoFrame(result.bounds, frameWidth, frameHeight, fitPadding);
            updateLayer(index, fitted, true);
            message = roleNames[index] + "已按" + (pending.whole ? "整段动画" : "首帧") + "入框，留白 " + fitPadding
                + " 像素；仅调整当前层，可撤销后继续微调。";
        } catch (error) { message = error.message; }
    }
    function animationSummary(name, optional) {
        if (!name) return optional ? "未配置" : "默认姿势";
        const duration = Geometry.animationDuration(currentAnimations, name);
        return duration >= 0 ? name + " · " + duration.toFixed(2) + " 秒" : name + "（未在动画列表中找到）";
    }
    function previewAction(action) {
        let played = 0;
        for (let i = 0; i < layers.length; ++i) {
            const layer = previewLayer(i);
            if (layer && layer.playAction(action)) ++played;
        }
        const name = {attack:"攻击",skill:"技能",hurt:"受伤"}[action];
        message = played ? "正在试播" + name + "（" + played + " 层），结束后恢复待机；暂停时请点击“继续”。"
            : "没有可试播的" + name + "动画，请选择素材中真实存在的动画名；留空表示不播放。";
    }

    function snapshot() { return { layers: JSON.parse(JSON.stringify(layers)), renderScale: renderScale,
        frameWidth: frameWidth, frameHeight: frameHeight, frameRadius: frameRadius }; }
    function checkpoint() { history = history.concat([snapshot()]).slice(-80); future = []; }
    function restore(state) {
        cancelFit();
        autoAnimations = {};
        layers = state.layers; renderScale = state.renderScale;
        frameWidth = state.frameWidth; frameHeight = state.frameHeight;
        frameRadius = state.frameRadius === undefined ? 0 : state.frameRadius;
    }
    function undo() {
        if (!history.length) return;
        future = future.concat([snapshot()]);
        const states = history.slice(); const previous = states.pop(); history = states; restore(previous);
    }
    function redo() {
        if (!future.length) return;
        history = history.concat([snapshot()]);
        const states = future.slice(); const next = states.pop(); future = states; restore(next);
    }
    function updateLayer(index, values, remember) {
        if (pendingFit && pendingFit.index === index) cancelFit();
        if (remember) checkpoint();
        const copy = layers.slice(); copy[index] = Object.assign({}, copy[index], values); layers = copy;
    }
    function adjust(values) { updateLayer(selected, values, true); }
    function scaleSelected(factor, remember) {
        const value = Math.max(0.001, Math.min(100, current.scale * factor));
        updateLayer(selected, {scale: Geometry.number(value)}, remember);
    }
    function loadSkeleton(url, index, remember) {
        try {
            url = Geometry.fileUrl(url);
            if (!/\.(skel|json)$/i.test(url)) throw new Error("请选择 .skel 或 Spine 的 .json 骨骼文件。");
            autoAnimations[index] = url + "|" + Geometry.atlasFor(url);
            const metadata = layerMetadata.slice(); metadata[index] = {animations:[]}; layerMetadata = metadata;
            updateLayer(index, {skeleton: url, atlas: Geometry.atlasFor(url)}, remember);
            message = "已导入" + roleNames[index] + "：" + Geometry.basename(url) + "，正在识别版本和动画。";
        } catch (error) { message = String(error.message || error); }
    }
    function loadDropped(urls, remember) {
        const files = Array.from(urls).filter(function(url) { return /\.(skel|json)$/i.test(String(url)); });
        if (!files.length) { message = "请拖入 .skel 或 Spine .json 文件；也可用左侧按钮选择文件夹。"; return; }
        if (remember !== false) checkpoint();
        let ignored = 0;
        const used = {};
        const unknown = [];
        files.forEach(function(url) {
            const role = Geometry.guessRole(url);
            if (!role) { unknown.push(url); return; }
            const target = ["bg", "body", "front"].indexOf(role);
            if (used[target]) { ++ignored; return; }
            used[target] = true; loadSkeleton(url, target, false);
        });
        // Many packs use a general's initials for the body (e.g. bg.json + zh.json).
        // Resolve explicit roles first; infer the sole remaining body only when
        // a background is present. Multiple unknown files stay ambiguous.
        if (unknown.length === 1 && (files.length === 1 || (used[0] && !used[1]))) {
            loadSkeleton(unknown[0], files.length === 1 ? selected : 1, false);
        } else ignored += unknown.length;
        if (ignored) message = "已导入可识别的图层；另有 " + ignored + " 个文件未导入，请选中目标层后单独打开。";
    }
    function importFolder() {
        if (!loadingFolder || folderFiles.status !== FolderListModel.Ready) return;
        const candidates = [];
        for (let i = 0; i < folderFiles.count; ++i) candidates.push(String(folderFiles.get(i, "fileUrl")));
        const directory = Geometry.localPathKey(folderFiles.folder).replace(/\/?$/, "/");
        // A folder change can briefly retain the old ready model until its worker
        // responds. Do not consume those stale entries or close the pending import.
        if (candidates.some(function(url) { return Geometry.localPathKey(url).indexOf(directory) !== 0; })) return;
        loadingFolder = false;
        // Prefer binary when both formats share a stem.
        const files = candidates.filter(function(url) {
            return !/\.json$/i.test(url) || candidates.indexOf(url.replace(/\.json$/i, ".skel")) === -1;
        });
        if (!files.length) { message = "该文件夹没有 .skel / .json 骨骼。"; return; }
        checkpoint();
        layers = [Geometry.newLayer("bg"), Geometry.newLayer("body"), Geometry.newLayer("front")];
        renderScale = 1;
        loadDropped(files, false);
    }
    function loadFolder(url) {
        loadingFolder = true;
        folderFiles.folder = url;
        Qt.callLater(importFolder);
    }
    function copyText(value) {
        clipboardBuffer.text = value; clipboardBuffer.selectAll(); clipboardBuffer.copy();
        message = "已复制到剪贴板。";
    }
    function applyImport() {
        try {
            if (importKind === "project") {
                const data = Geometry.parseProject(importText.text); checkpoint(); cancelFit(); autoAnimations = {};
                layers = data.layers; renderScale = data.renderScale;
                frameWidth = data.frame.width; frameHeight = data.frame.height; frameRadius = data.frame.radius || 0;
            } else {
                const data = Geometry.parseExtra(importText.text); checkpoint(); cancelFit(); autoAnimations = {};
                layers = Geometry.applyExtra(layers, data); renderScale = data.render_scale === undefined ? 1 : data.render_scale;
            }
            importDialog.close(); ++replayKey; message = "参数已应用，可以继续拖动微调。";
        } catch (error) { importError.text = String(error.message || error); }
    }
    function preset(index) {
        checkpoint();
        const presets = [[103,166,6],[136,157,0],[172,227,8]];
        if (index < 3) { frameWidth = presets[index][0]; frameHeight = presets[index][1]; frameRadius = presets[index][2]; }
        Qt.callLater(fitPreview);
    }
    function fitPreview() {
        previewZoom = Math.max(0.5, Math.min(4, (stage.width - 48) / frameWidth, (stage.height - 72) / frameHeight));
    }

    onClosing: if (quitOnClose) Qt.quit()
    onSelectedChanged: cancelFit()
    onFrameWidthChanged: cancelFit()
    onFrameHeightChanged: cancelFit()
    onRenderScaleChanged: cancelFit()
    onShowIntroChanged: cancelFit()
    onFitPaddingChanged: cancelFit()
    onFitActionsChanged: cancelFit()
    Loader {
        active: root.smokeTest || root.actionSmokeTest
        source: active ? Qt.resolvedUrl("../../../test/skin_debugger/" + (root.actionSmokeTest ? "ActionSmoke.qml" : "NativeSmoke.qml")) : ""
        onLoaded: { item.editor = root; item.start(); }
    }
    Shortcut { sequence: "Ctrl+Z"; onActivated: root.undo() }
    Shortcut { sequence: "Ctrl+Shift+Z"; onActivated: root.redo() }
    Shortcut { sequence: "Ctrl+Y"; onActivated: root.redo() }
    TextEdit { id: clipboardBuffer; visible: false }

    FileDialog {
        id: fileDialog
        title: root.dialogPurpose === "atlas" ? "选择当前层的 .atlas 图集" : "选择当前层的骨骼文件"
        nameFilters: root.dialogPurpose === "atlas" ? ["Spine 图集 (*.atlas)"] : ["Spine 骨骼 (*.skel *.json)"]
        onAccepted: {
            if (root.dialogPurpose === "atlas") root.adjust({atlas: String(selectedFile)});
            else root.loadSkeleton(String(selectedFile), root.selected, true);
        }
    }
    FolderDialog {
        id: folderDialog
        title: "选择包含骨骼、图集与 PNG 的文件夹"
        onAccepted: {
            root.loadFolder(selectedFolder);
        }
    }
    FolderListModel {
        id: folderFiles
        folder: ""
        nameFilters: ["*.skel", "*.json"]
        showDirs: false; showDotAndDotDot: false
        onStatusChanged: if (status === FolderListModel.Ready) Qt.callLater(root.importFolder)
    }
    Dialog {
        id: importDialog
        title: root.importKind === "project" ? "恢复调试工程 JSON" : "导入现有 extra_data"
        anchors.centerIn: parent
        width: Math.min(root.width - 80, 720); height: 540
        modal: true
        standardButtons: Dialog.Cancel
        ColumnLayout {
            anchors.fill: parent
            Label { text: "粘贴配置后应用；仅解析数据，不执行代码。"; color: "#a6b8d0" }
            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true
                TextArea { id: importText; selectByMouse: true; font.family: "Consolas"; wrapMode: TextEdit.WrapAnywhere }
            }
            Label { id: importError; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: "#ff9d94" }
            ActionButton { text: "应用参数"; onClicked: root.applyImport() }
        }
        onOpened: { importText.text = ""; importError.text = ""; importText.forceActiveFocus(); }
    }

    header: ToolBar {
        height: 68
        background: Rectangle { color: "#1b2431" }
        RowLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 16
            ColumnLayout {
                spacing: 2
                Label { text: "皮肤骨骼调试器"; font.pixelSize: 21; font.bold: true }
                Label { text: "导入 → 拖动与缩放 → 复制到皮肤配置"; color: "#a6b8d0"; font.pixelSize: 12 }
            }
            Item { Layout.fillWidth: true }
            ActionButton { text: "选择皮肤文件夹"; onClicked: folderDialog.open() }
            ActionButton {
                text: "打开谋庞统示例"
                onClicked: {
                    root.checkpoint();
                    root.layers = [Geometry.newLayer("bg"), Geometry.newLayer("body"), Geometry.newLayer("front")];
                    root.renderScale = 1;
                    const base = Geometry.fileUrl(AppPath + "/assets/lunarltk/skel/1OK0I0/");
                    root.loadSkeleton(base + "beijing.skel", 0, false);
                    root.loadSkeleton(base + "daiji.skel", 1, false);
                    root.layers = Geometry.applyExtra(root.layers, {scale:1.2, x_offset:0, y_offset:0.9, normal_anim:"DaiJi", shown_anim:"ChuChang"});
                    root.message = "谋庞统 · 玉帛雕翎（使用本机已有缓存；未缓存时请手动选择素材目录）。";
                }
            }
        }
    }

    footer: ToolBar {
        height: 48
        background: Rectangle { color: "#1b2431" }
        Label { anchors.fill: parent; anchors.margins: 12; text: root.message; wrapMode: Text.WordWrap; color: "#b2c7df"; font.pixelSize: 12 }
    }

    Rectangle {
        id: captureRoot
        anchors.fill: parent
        color: root.color
    RowLayout {
        id: workspace
        anchors.fill: parent; anchors.margins: 14; spacing: 14
        Pane {
            Layout.preferredWidth: 260; Layout.fillHeight: true
            background: Rectangle { color: "#1b2431"; radius: 10 }
            ScrollView {
                id: assetScroll
                anchors.fill: parent; clip: true
            ColumnLayout {
                width: assetScroll.availableWidth; spacing: 10
                Label { text: "01  素材与图层"; font.bold: true; font.pixelSize: 15 }
                Label { Layout.fillWidth: true; text: "从下到上：背景、人物、前景。拖动和滚轮只调整选中层。"; wrapMode: Text.WordWrap; color: "#9eafc8" }
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        Layout.fillWidth: true; height: 76; radius: 7
                        color: root.selected === index ? "#294669" : "#232e3e"
                        border.color: root.selected === index ? "#69a6fa" : "#334256"
                        MouseArea { anchors.fill: parent; onClicked: root.selected = index }
                        Column {
                            anchors.left: parent.left; anchors.right: toggle.left; anchors.margins: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                            Label { text: root.roleNames[index]; font.bold: true }
                            Label { width: parent.width; text: root.layers[index].skeleton ? Geometry.basename(root.layers[index].skeleton) : "未导入"; elide: Text.ElideMiddle; color: "#a9bed8"; font.pixelSize: 12 }
                        }
                        CheckBox { id: toggle; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; checked: root.layers[index].visible; onClicked: root.updateLayer(index, {visible: checked}, true); ToolTip.text: "仅影响预览显隐，不影响导出"; ToolTip.visible: hovered }
                    }
                }
                RowLayout {
                    ActionButton { text: "打开骨骼"; Layout.fillWidth: true; onClicked: { root.dialogPurpose = "skeleton"; fileDialog.open(); } }
                    ActionButton { text: "指定图集"; Layout.fillWidth: true; onClicked: { root.dialogPurpose = "atlas"; fileDialog.open(); } }
                }
                Label { text: "骨骼路径"; color: "#9eafc8" }
                TextField {
                    Layout.fillWidth: true; text: root.current.skeleton; selectByMouse: true; placeholderText: ".skel / .json"
                    onEditingFinished: if (text && text !== root.current.skeleton) root.loadSkeleton(text, root.selected, true)
                }
                Label { text: "图集路径"; color: "#9eafc8" }
                TextField {
                    Layout.fillWidth: true; text: root.current.atlas; selectByMouse: true; placeholderText: ".atlas"
                    onEditingFinished: {
                        try { if (text) root.adjust({atlas: Geometry.fileUrl(text)}); }
                        catch(error) { root.message = error.message; }
                    }
                }
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.layerStates[root.selected]; color: "#9ed5b9"; font.pixelSize: 12 }
                Label {
                    objectName: "skinInspectionStatus"
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 12; color: "#a6b8d0"
                    text: root.layerBusy[root.selected] ? "正在检测骨骼…" : (root.currentMetadata.error
                        || (root.currentMetadata.version ? "Spine " + root.currentMetadata.version + " · " + root.currentAnimations.length + " 个动画"
                            : (root.previewLayer(root.selected) ? root.previewLayer(root.selected).inspectionStatus : "")))
                }
                ActionButton { text: "移除当前层"; enabled: !!root.current.skeleton; onClicked: root.adjust({skeleton:"", atlas:""}) }
                Label { text: "素材不会被移动或修改。\nPNG 由 .atlas 自动读取。\n支持游戏已兼容的 Spine 版本。"; color: "#8296b0"; font.pixelSize: 12; lineHeight: 1.4 }
            }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            RowLayout {
                Label { text: "02  立绘框预览"; font.bold: true; font.pixelSize: 15; Layout.fillWidth: true }
                ActionButton { text: "适应"; onClicked: root.fitPreview() }
                ActionButton { text: root.paused ? "继续" : "暂停"; onClicked: root.paused = !root.paused }
                ActionButton { text: "重播"; onClicked: ++root.replayKey }
            }
            RowLayout {
                ComboBox {
                    Layout.fillWidth: true
                    model: ["默认界面 · 103 × 166", "OL 界面 · 136 × 157", "十周年 · 172 × 227", "自定义宽高"]
                    onActivated: root.preset(currentIndex)
                }
                NumberField { Layout.preferredWidth: 65; value: root.frameWidth; minimum: 20; maximum: 2000; decimals: 0; onCommitted: function(n) { root.checkpoint(); root.frameWidth = n; } }
                Label { text: "×" }
                NumberField { Layout.preferredWidth: 65; value: root.frameHeight; minimum: 20; maximum: 2000; decimals: 0; onCommitted: function(n) { root.checkpoint(); root.frameHeight = n; } }
            }
            Rectangle {
                id: stage
                objectName: "skinDebuggerStage"
                Layout.fillWidth: true; Layout.fillHeight: true
                color: "#10151d"; radius: 10; border.color: "#303e51"; clip: true
                focus: true
                Keys.onPressed: function(event) {
                    let dx = 0, dy = 0;
                    if (event.key === Qt.Key_Left) dx = -1;
                    else if (event.key === Qt.Key_Right) dx = 1;
                    else if (event.key === Qt.Key_Up) dy = -1;
                    else if (event.key === Qt.Key_Down) dy = 1;
                    else return;
                    const step = event.modifiers & Qt.ShiftModifier ? 10 : 1;
                    root.adjust({x: root.current.x + dx * step / root.frameWidth, y: root.current.y + dy * step / root.frameHeight}); event.accepted = true;
                }
                DropArea { anchors.fill: parent; onDropped: function(drop) { if(drop.hasUrls) root.loadDropped(drop.urls); } }
                Item {
                    id: portrait
                    objectName: "skinDebuggerPortrait"
                    width: root.frameWidth * root.previewZoom; height: root.frameHeight * root.previewZoom
                    anchors.centerIn: parent
                    Item {
                        width: root.frameWidth; height: root.frameHeight
                        scale: root.previewZoom; transformOrigin: Item.TopLeft
                        Rectangle { id: frameMask; anchors.fill: parent; radius: root.frameRadius; visible: false; color: "white" }
                        Item {
                            id: artwork
                            // Match the game's supersampled SkinArea/OpacityMask path.
                            // Fractions and height/175 still cancel to the same visible frame.
                            width: parent.width * 4
                            height: parent.height * 4
                            scale: root.crop ? 1 : 0.25
                            transformOrigin: Item.TopLeft
                            visible: !root.crop
                            Rectangle { anchors.fill: parent; color: root.backdrop }
                            Repeater {
                                id: layerRepeater
                                model: 3
                                delegate: SkinLayer {
                                    required property int index
                                    anchors.fill: parent
                                    onStatusChanged: root.updateStatus(index, status)
                                    info: root.layers[index]
                                    renderScale: root.renderScale
                                    paused: root.paused
                                    showIntro: root.showIntro
                                    includeActionsInFit: root.fitActions
                                    replayKey: root.replayKey
                                    debugBones: root.showBones
                                    onInspectingChanged: root.updateBusy(index, inspecting)
                                    onMetadataReady: function(data) { root.acceptMetadata(index, data); }
                                    onFitReady: function(result) { root.acceptFit(index, result); }
                                }
                            }
                        }
                        OpacityMask { anchors.fill: parent; visible: root.crop; source: artwork; maskSource: frameMask }
                        Rectangle { anchors.fill: parent; radius: root.frameRadius; color: "transparent"; border.color: "#7b98bd"; border.width: 1 / root.previewZoom }
                    }
                    Canvas {
                        anchors.fill: parent; visible: root.showGuides
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d"); ctx.clearRect(0,0,width,height);
                            ctx.strokeStyle="#707f9db8"; ctx.lineWidth=1; ctx.setLineDash([4,5]);
                            ctx.beginPath(); ctx.moveTo(width/2,0); ctx.lineTo(width/2,height); ctx.moveTo(0,height/2); ctx.lineTo(width,height/2); ctx.stroke();
                        }
                    }
                    Rectangle {
                        visible: root.showGuides
                        width: 10; height: 10; radius: 5; color: "#6caaff"; border.color: "#eef5ff"
                        x: root.current.x * portrait.width - 5; y: root.current.y * portrait.height - 5
                    }
                    MouseArea {
                        objectName: "skinDebuggerDragArea"
                        anchors.fill: parent
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        preventStealing: true
                        property real startX: 0; property real startY: 0
                        property real offsetX: 0; property real offsetY: 0
                        onPressed: function(mouse) { stage.forceActiveFocus(); root.checkpoint(); startX=mouse.x; startY=mouse.y; offsetX=root.current.x; offsetY=root.current.y; }
                        onPositionChanged: function(mouse) {
                            if(pressed) root.updateLayer(root.selected, {x: Geometry.number(offsetX+(mouse.x-startX)/portrait.width), y: Geometry.number(offsetY+(mouse.y-startY)/portrait.height)}, false);
                        }
                        onWheel: function(wheel) { root.scaleSelected(Math.pow(1.08, wheel.angleDelta.y / 120), true); wheel.accepted=true; }
                    }
                }
                Label { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottomMargin: 16; text: "拖动移动 · 滚轮缩放皮肤 · 方向键微调 · Shift 加速"; font.pixelSize: 11; color: "#8fa4c0" }
            }
            RowLayout {
                Label { text: "预览倍率"; color: "#9eafc8" }
                Slider { Layout.fillWidth: true; from: 0.5; to: 4; value: root.previewZoom; onMoved: root.previewZoom = value }
                Label { text: root.previewZoom.toFixed(1) + "×"; Layout.preferredWidth: 38 }
                CheckBox { text: "裁剪"; checked: root.crop; onClicked: root.crop = checked }
                CheckBox { text: "参考线"; checked: root.showGuides; onClicked: root.showGuides = checked }
            }
        }

        Pane {
            Layout.preferredWidth: 310; Layout.fillHeight: true
            background: Rectangle { color: "#1b2431"; radius: 10 }
            ScrollView {
                id: inspectorScroll
                anchors.fill: parent
                anchors.bottomMargin: 94
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ColumnLayout {
                width: inspectorScroll.availableWidth
                spacing: 8
                Label { text: "03  调整与导出"; font.bold: true; font.pixelSize: 15 }
                Label { text: "当前调整：" + root.roleNames[root.selected]; color: "#9bc4ff" }
                GridLayout {
                    columns: 2; columnSpacing: 10
                    Label { text: "缩放比例" }
                    NumberField { objectName: "skinScaleField"; Layout.fillWidth: true; value: root.current.scale; minimum: 0.001; maximum: 100; onCommitted: function(n) { root.adjust({scale:n}); } }
                    Label { text: "水平偏移" }
                    NumberField { Layout.fillWidth: true; value: root.current.x; onCommitted: function(n) { root.adjust({x:n}); } }
                    Label { text: "垂直偏移" }
                    NumberField { Layout.fillWidth: true; value: root.current.y; onCommitted: function(n) { root.adjust({y:n}); } }
                }
                Label { Layout.fillWidth: true; text: "偏移以框宽 / 框高为 1；0.5 表示中点。预览倍率不会改变这些参数。"; wrapMode: Text.WordWrap; color: "#899fb9"; font.pixelSize: 12 }
                RowLayout {
                    ActionButton { text: "缩小"; onClicked: root.scaleSelected(1/1.1,true) }
                    ActionButton { text: "放大"; onClicked: root.scaleSelected(1.1,true) }
                    ActionButton { text: "位置复位"; onClicked: root.adjust({x:0.5,y:0.5,scale:1}) }
                }
                RowLayout {
                    ActionButton { objectName: "skinFitFirstFrame"; text: "首帧入框"; enabled: root.readyForFit; onClicked: root.fitSelected(false) }
                    ActionButton { objectName: "skinFitAnimation"; text: "整段动画入框"; enabled: root.readyForFit; onClicked: root.fitSelected(true) }
                }
                RowLayout {
                    Label { text: "入框留白（像素）" }
                    NumberField { Layout.fillWidth: true; value: root.fitPadding; minimum: 0; maximum: Math.max(0, Math.min(root.frameWidth,root.frameHeight)/2-1); decimals: 1; onCommitted: function(n) { root.fitPadding = n; } }
                }
                GridLayout {
                    columns: 2
                    Label { text: "待机动画" }
                    AnimationField { objectName: "skinNormalAnimation"; Layout.fillWidth: true; animationName: root.current.normal; animations: root.currentAnimations; onCommitted: function(name) { root.adjust({normal:name}); ++root.replayKey; } }
                    Label { text: "出场动画" }
                    AnimationField { objectName: "skinShownAnimation"; emptyText: "不播放（留空）"; Layout.fillWidth: true; animationName: root.current.shown; animations: root.currentAnimations; onCommitted: function(name) { root.adjust({shown:name}); ++root.replayKey; } }
                    Label { text: "攻击动画" }
                    RowLayout {
                        Layout.fillWidth: true
                        AnimationField { objectName: "skinAttackAnimation"; emptyText: "不播放（留空）"; Layout.fillWidth: true; Layout.minimumWidth: 0; animationName: root.current.attack || ""; animations: root.currentAnimations; onCommitted: function(name) { root.adjust({attack:name}); ++root.replayKey; } }
                        ActionButton { text: "试播"; onClicked: root.previewAction("attack") }
                    }
                    Label { text: "技能动画" }
                    RowLayout {
                        Layout.fillWidth: true
                        AnimationField { objectName: "skinSkillAnimation"; emptyText: "不播放（留空）"; Layout.fillWidth: true; Layout.minimumWidth: 0; animationName: root.current.skill || ""; animations: root.currentAnimations; onCommitted: function(name) { root.adjust({skill:name}); ++root.replayKey; } }
                        ActionButton { text: "试播"; onClicked: root.previewAction("skill") }
                    }
                    Label { text: "受伤动画" }
                    RowLayout {
                        Layout.fillWidth: true
                        AnimationField { objectName: "skinHurtAnimation"; emptyText: "不播放（留空）"; Layout.fillWidth: true; Layout.minimumWidth: 0; animationName: root.current.hurt || ""; animations: root.currentAnimations; onCommitted: function(name) { root.adjust({hurt:name}); ++root.replayKey; } }
                        ActionButton { text: "试播"; onClicked: root.previewAction("hurt") }
                    }
                    Label { text: "渲染比例" }
                    NumberField { Layout.fillWidth: true; value: root.renderScale; minimum: 0.01; maximum: 10; onCommitted: function(n) { root.checkpoint(); root.renderScale=n; } }
                }
                Label { Layout.fillWidth: true; text: "待机：" + root.animationSummary(root.current.normal) + "\n出场：" + root.animationSummary(root.current.shown,true)
                    + "\n攻击：" + root.animationSummary(root.current.attack,true) + "\n技能：" + root.animationSummary(root.current.skill,true) + "\n受伤：" + root.animationSummary(root.current.hurt,true); wrapMode: Text.WordWrap; font.pixelSize: 11; color: "#899fb9" }
                Label { Layout.fillWidth: true; text: "攻击、技能、受伤可留空。入框默认测量待机，可选择同时计入战斗动作。"; wrapMode: Text.WordWrap; font.pixelSize: 11; color: "#899fb9" }
                RowLayout {
                    CheckBox { text: "重播时含出场"; checked: root.showIntro; onClicked: root.showIntro=checked }
                    CheckBox { text: "骨骼"; checked: root.showBones; onClicked: root.showBones=checked }
                }
                CheckBox { text: "入框时包含战斗动作"; checked: root.fitActions; onClicked: root.fitActions=checked }
                RowLayout {
                    ActionButton { text: "撤销"; enabled: root.history.length > 0; onClicked: root.undo() }
                    ActionButton { text: "重做"; enabled: root.future.length > 0; onClicked: root.redo() }
                    ActionButton { text: "背景色"; onClicked: root.backdrop = root.backdrop.toString()==="#e4e8ef" ? "#292e39" : "#e4e8ef" }
                }
                Label { text: "复制到皮肤的 extra_data"; font.bold: true }
                ScrollView {
                    Layout.fillWidth: true; Layout.preferredHeight: 170; Layout.minimumHeight: 170
                    TextArea { id: output; objectName: "skinDebuggerOutput"; text: root.luaOutput; readOnly: true; selectByMouse: true; font.family: "Consolas"; font.pixelSize: 12; wrapMode: TextEdit.NoWrap }
                }
            }
            }
            ColumnLayout {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                spacing: 8
                ActionButton {
                    id: copyButton
                    objectName: "skinDebuggerCopyButton"
                    text: "复制 extra_data"; Layout.fillWidth: true
                    enabled: root.layers.some(function(layer){return !!layer.skeleton})
                    background: Rectangle { radius: 4; color: copyButton.enabled ? (copyButton.down ? "#3265b0" : "#4d8ff7") : "#334256" }
                    contentItem: Text { text: copyButton.text; font: copyButton.font; color: "#ffffff"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: root.copyText(root.luaOutput)
                }
                RowLayout {
                    ActionButton { text: "导入参数"; Layout.fillWidth: true; onClicked: {root.importKind="extra"; importDialog.open();} }
                    ActionButton { text: "复制工程"; Layout.fillWidth: true; onClicked: root.copyText(root.projectOutput) }
                    ActionButton { text: "恢复工程"; Layout.fillWidth: true; onClicked: {root.importKind="project"; importDialog.open();} }
                }
            }
        }
    }
    }
}
