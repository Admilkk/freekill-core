import QtQuick
import "native/SkinInspector" as Native

Item {
    id: root
    readonly property bool busy: probe.busy
    signal completed(var result)
    function inspect(skeleton, atlas, animations, whole, token) {
        probe.inspect(skeleton, atlas, animations, whole, token);
    }
    Native.SkeletonProbe { id: probe; onCompleted: function(result) { root.completed(result); } }
}
