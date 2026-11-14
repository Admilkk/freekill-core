import QtQuick
import Spine
import "Geometry.js" as Geometry
import "../../../LunarLtk/Components/Photo" as Skin

Item {
    id: root
    required property var info
    property real renderScale: 1
    property bool paused: false
    property bool showIntro: false
    property bool includeActionsInFit: false
    property int replayKey: 0
    property bool debugBones: false
    property string status: info.skeleton ? "等待加载" : "未导入"
    readonly property bool loaded: !!loader.item && loader.item.loadOk
    readonly property string assetKey: info.skeleton + "|" + info.atlas + "|" + renderScale
    readonly property var transformData: Geometry.skeletonTransform(info, width, height, renderScale)
    property var metadata: ({animations: []})
    property string inspectionStatus: ""
    readonly property bool inspecting: !!probeLoader.item && probeLoader.item.busy
    readonly property string inspectionKey: info.skeleton + "|" + info.atlas
    signal metadataReady(var data)
    signal fitReady(var result)
    property string fitToken: ""
    visible: info.visible

    function replay() {
        controller.start(showIntro);
    }
    function playAction(action) {
        if (!loaded || !info.visible) return false;
        if (metadata.animations.length && Geometry.animationDuration(metadata.animations, info[action] || "") < 0) return false;
        return controller.playAction(action);
    }
    readonly property string activeAction: controller.activeAction
    readonly property bool artworkVisible: loaded && info.visible && controller.artworkEnabled
    Skin.SkinAnimationController {
        id: controller
        target: loader.item
        ready: root.loaded
        normalAnim: root.info.normal
        shownAnim: root.info.shown
        attackAnim: root.info.attack || ""
        skillAnim: root.info.skill || ""
        hurtAnim: root.info.hurt || ""
    }
    function isPlaying() { return !!loader.item && loader.item.isPlaying(0); }
    function inspectMetadata() {
        metadata = {animations: []};
        metadataReady(metadata);
        if (!info.skeleton || !info.atlas) { inspectionStatus = ""; return; }
        if (!probeLoader.item) {
            inspectionStatus = probeLoader.status === Loader.Error ? "检测模块不可用，可手动填写动画和参数。" : "检测模块加载中…";
            return;
        }
        inspectionStatus = "正在读取动画信息…";
        probeLoader.item.inspect(info.skeleton, info.atlas, [], false, "metadata|" + inspectionKey);
    }
    function requestFit(whole, token) {
        if (!probeLoader.item || inspecting) return false;
        fitToken = token;
        const events = [info.attack, info.skill, info.hurt].filter(function(name) { return !!name; });
        const eventOnly = !info.normal && !info.shown && events.length > 0;
        const names = whole && eventOnly ? [] : [info.normal];
        if (whole && showIntro && info.shown && names.indexOf(info.shown) === -1) names.push(info.shown);
        if (whole && (includeActionsInFit || eventOnly)) events.forEach(function(name) { if (names.indexOf(name) === -1) names.push(name); });
        probeLoader.item.inspect(info.skeleton, info.atlas, names, whole, "fit|" + token);
        return true;
    }
    function reload() {
        loader.active = false;
        status = info.skeleton ? "等待加载" : "未导入";
        const expected = assetKey;
        Qt.callLater(function() {
            if (root.assetKey === expected && root.info.skeleton && root.info.atlas)
                loader.active = true;
        });
    }
    onAssetKeyChanged: reload()
    onInspectionKeyChanged: inspectMetadata()
    onReplayKeyChanged: replay()
    Component.onCompleted: reload()

    Loader {
        id: probeLoader
        source: "Probe.qml"
        onLoaded: root.inspectMetadata()
        onStatusChanged: if (status === Loader.Error) root.inspectionStatus = "检测模块不可用，可手动填写动画和参数。"
    }
    Connections {
        target: probeLoader.item
        function onCompleted(result) {
            if (result.token === "metadata|" + root.inspectionKey) {
                root.metadata = result.animations ? result : {animations: []};
                root.inspectionStatus = result.error || ("Spine " + result.version + " · " + result.animations.length + " 个动画");
                root.metadataReady(result);
            } else if (result.token === "fit|" + root.fitToken) root.fitReady(result);
        }
    }

    Loader {
        id: loader
        active: false
        onLoaded: if (item.loadOk) Qt.callLater(root.replay)
        sourceComponent: SkeletonAnimation {
            atlasFile: root.info.atlas
            skeletonDataFile: root.info.skeleton
            skeletonScale: root.renderScale
            spineVersion: SpineVersion.Auto
            premultipliedAlapha: false
            timeScale: root.paused ? 0 : 1
            debugBones: root.debugBones
            x: root.transformData.x
            y: root.transformData.y
            scale: root.transformData.scale
            onSkeletonLoadFinished: function(ok) {
                root.status = ok ? "已加载（Spine 自动识别）" : "加载失败：检查骨骼、图集及 PNG 是否配套";
                if (ok) root.replay();
            }
        }
    }
}
