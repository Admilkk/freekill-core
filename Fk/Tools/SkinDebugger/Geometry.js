.pragma library

// Keep these conversions identical to LunarLtk/Components/Photo/SkinArea.qml.
function skeletonTransform(layer, width, height, renderScale) {
    return { x: width * layer.x, y: height * layer.y,
        scale: layer.scale * height / renderScale / 175 };
}
function newLayer(role) {
    return { role: role, skeleton: "", atlas: "", x: 0.5, y: 0.5,
        scale: 1, normal: "DaiJi", shown: "", attack: "", skill: "", hurt: "", visible: true };
}
function number(value) { return Math.round(value * 1000000) / 1000000; }
// Bounds are in the native renderer's local coordinates, at skeleton scale 1.
// The sampling scale cancels against Item.scale in skeletonTransform().
function fitIntoFrame(bounds, width, height, padding) {
    if (!bounds || ![bounds.x, bounds.y, bounds.width, bounds.height, width, height, padding].every(function(n) {
        return typeof n === "number" && isFinite(n);
    }) || bounds.width <= 0 || bounds.height <= 0 || padding < 0 || width <= 2*padding || height <= 2*padding)
        throw new Error("没有有效的图像范围，无法适配立绘框。");
    var factor = Math.min((width - 2*padding)/bounds.width, (height - 2*padding)/bounds.height);
    var scale = factor * 175 / height;
    var x = (width/2 - (bounds.x + bounds.width/2)*factor)/width;
    var y = (height/2 - (bounds.y + bounds.height/2)*factor)/height;
    if (scale < 0.001 || scale > 100 || Math.abs(x) > 100 || Math.abs(y) > 100)
        throw new Error("适配结果超出可编辑范围，请检查素材单位或立绘框尺寸。");
    // Keep sufficient precision so rounding cannot push an edge outside its padding.
    return {scale: scale, x: x, y: y};
}
function animationDuration(animations, name) {
    for (var i = 0; i < animations.length; ++i) if (animations[i].name === name) return animations[i].duration;
    return -1;
}
function fileUrl(value) {
    value = String(value).trim().replace(/\\/g, "/");
    if (/^file:/i.test(value)) return value;
    if (/^[A-Za-z]:\//.test(value)) return "file:///" + encodeURI(value).replace(/#/g, "%23");
    if (value.indexOf("/") === 0) return "file://" + encodeURI(value).replace(/#/g, "%23");
    throw new Error("请选择本机文件，不支持网络地址或相对路径。");
}
function basename(url) {
    return decodeURIComponent(String(url).split("/").pop()).replace(/\.(skel|json|atlas)$/i, "");
}
function atlasFor(url) { return String(url).replace(/\.(skel|json|atlas)$/i, ".atlas"); }
function localPathKey(url) {
    var key = decodeURI(String(url));
    // FolderListModel canonicalizes Windows drive letters differently from QUrl.
    return /^file:\/\/\/[a-z]:/i.test(key) ? key.toLowerCase() : key;
}
function guessRole(url) {
    var name = basename(url).toLowerCase();
    if (/beijing|background|^bg$|背景/.test(name)) return "bg";
    if (/qianjing|foreground|^front$|前景|shouji|shoushang|hurt|damage|受伤|受击/.test(name)) return "front";
    if (/xingxiang|daiji|^body$|^ren$|人物/.test(name)) return "body";
    return "";
}
function quote(value) {
    return JSON.stringify(String(value)).replace(/\u2028/g, "\\u2028").replace(/\u2029/g, "\\u2029");
}
function extraData(layers, renderScale) {
    var result = { render_scale: number(renderScale) };
    layers.forEach(function(layer) {
        if (!layer.skeleton) return;
        result[layer.role + "_scale"] = number(layer.scale);
        result[layer.role + "_x_offset"] = number(layer.x);
        result[layer.role + "_y_offset"] = number(layer.y);
        result[layer.role + "_normal_anim"] = layer.normal;
        result[layer.role + "_shown_anim"] = layer.shown;
        ["attack", "skill", "hurt"].forEach(function(action) { result[layer.role + "_" + action + "_anim"] = layer[action] || ""; });
    });
    return result;
}
function luaExtra(layers, renderScale) {
    var data = extraData(layers, renderScale);
    return "extra_data = {\n" + Object.keys(data).map(function(key) {
        return "  " + key + " = " + (typeof data[key] === "number" ? data[key] : quote(data[key])) + ",";
    }).join("\n") + "\n},";
}
function validateExtra(data) {
    if (!data || Array.isArray(data) || typeof data !== "object") throw new Error("需要 extra_data 对象。");
    Object.keys(data).forEach(function(key) {
        if (!/^(render_scale|scale|x_offset|y_offset|(normal|shown|attack|skill|hurt|special)_anim|(bg|body|front)_(scale|x_offset|y_offset|(normal|shown|attack|skill|hurt|special)_anim))$/.test(key))
            throw new Error("不支持的字段：" + key + "。请只粘贴位置、缩放和动画参数。");
        var value = data[key];
        if (/anim$/.test(key)) {
            if (typeof value !== "string") throw new Error(key + " 必须是动画名称字符串。");
        } else {
            if (typeof value !== "number" || !isFinite(value)) throw new Error(key + " 必须是有限数字。");
            if (/scale$/.test(key) && (value <= 0 || value > 100)) throw new Error(key + " 需要大于 0 且不超过 100。");
            if (/offset$/.test(key) && Math.abs(value) > 100) throw new Error(key + " 超出可调整范围（-100 到 100）。");
        }
    });
    return data;
}
// Parse a flat Lua literal table. Never execute pasted Lua/JavaScript code.
function parseExtra(text) {
    text = String(text).trim();
    try {
        var json = JSON.parse(text);
        return validateExtra(json.extra_data || json);
    } catch (error) {
        if (text.charAt(0) === "{" && /"\s*:/.test(text)) throw error;
    }
    text = text.replace(/^extra_data\s*=\s*/, "").replace(/,\s*$/, "");
    if (text.charAt(0) !== "{" || text.charAt(text.length - 1) !== "}") throw new Error("请粘贴完整的 extra_data = { ... }。");
    text = text.slice(1, -1);
    var data = {}, position = 0;
    var token = /\s*(?:--[^\n]*(?:\n|$)\s*)*([a-z_]+)\s*=\s*("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)\s*(?:[,;]|$)/g;
    while (position < text.length && text.slice(position).trim()) {
        token.lastIndex = position;
        var match = token.exec(text);
        if (!match || match.index !== position) throw new Error("只接受数字和引号字符串，不执行表达式或函数。");
        if (Object.prototype.hasOwnProperty.call(data, match[1])) throw new Error("重复字段：" + match[1]);
        var raw = match[2];
        if (raw.charAt(0) === "'") {
            var inner = raw.slice(1, -1).replace(/\\'/g, "'").replace(/"/g, '\\"');
            raw = '"' + inner + '"';
        }
        data[match[1]] = raw.charAt(0) === '"' ? JSON.parse(raw) : Number(raw);
        position = token.lastIndex;
    }
    return validateExtra(data);
}
function applyExtra(layers, data) {
    validateExtra(data);
    return layers.map(function(old) {
        var layer = JSON.parse(JSON.stringify(old));
        [["scale", "scale", 1], ["x", "x_offset", 0.5], ["y", "y_offset", 0.5],
         ["normal", "normal_anim", "DaiJi"], ["shown", "shown_anim", ""], ["attack", "attack_anim", ""],
         ["hurt", "hurt_anim", ""]].forEach(function(field) {
            var specific = data[layer.role + "_" + field[1]];
            layer[field[0]] = specific !== undefined ? specific : (data[field[1]] !== undefined ? data[field[1]] : field[2]);
        });
        var skill = data[layer.role + "_skill_anim"];
        if (skill === undefined) skill = data[layer.role + "_special_anim"];
        if (skill === undefined) skill = data.skill_anim;
        if (skill === undefined) skill = data.special_anim;
        layer.skill = skill === undefined ? "" : skill;
        return layer;
    });
}
function project(layers, renderScale, frameWidth, frameHeight, frameRadius) {
    return JSON.stringify({ format: "freekill-skin-debugger", version: 1,
        frame: { width: frameWidth, height: frameHeight, radius: frameRadius || 0 }, renderScale: renderScale, layers: layers }, null, 2);
}
function parseProject(text) {
    var data = JSON.parse(text);
    if (data.format !== "freekill-skin-debugger" || data.version !== 1 || !Array.isArray(data.layers) || data.layers.length !== 3)
        throw new Error("不是支持的调试工程 JSON。");
    validateExtra({ render_scale: data.renderScale });
    if (!data.frame || typeof data.frame.width !== "number" || typeof data.frame.height !== "number"
        || !isFinite(data.frame.width) || !isFinite(data.frame.height)
        || data.frame.width < 20 || data.frame.width > 2000 || data.frame.height < 20 || data.frame.height > 2000)
        throw new Error("立绘框尺寸需在 20 到 2000 之间。");
    if (data.frame.radius !== undefined && (typeof data.frame.radius !== "number" || !isFinite(data.frame.radius)
        || data.frame.radius < 0 || data.frame.radius > 100)) throw new Error("圆角参数无效。");
    ["bg", "body", "front"].forEach(function(role, index) {
        var layer = data.layers[index];
        if (!layer || layer.role !== role) throw new Error("工程图层顺序应为背景、人物、前景。");
        ["skeleton", "atlas", "normal", "shown"].forEach(function(key) {
            if (typeof layer[key] !== "string") throw new Error("图层缺少 " + key);
        });
        ["attack", "skill", "hurt"].forEach(function(key) {
            if (layer[key] === undefined) layer[key] = ""; // Version 1 projects before action support.
            if (typeof layer[key] !== "string") throw new Error("图层的 " + key + " 需要动画名称字符串。");
        });
        if (layer.skeleton) layer.skeleton = fileUrl(layer.skeleton);
        if (layer.atlas) layer.atlas = fileUrl(layer.atlas);
        validateExtra({ scale: layer.scale, x_offset: layer.x, y_offset: layer.y });
        layer.visible = layer.visible !== false;
    });
    return data;
}
