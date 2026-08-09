
local loyalty = fk.CreateSkill {
  name = "renegade_loyalty&",
  mode_skill = true,
}

Fk:loadTranslationTable{
  ["renegade_loyalty&"] = "侍奉明主",
  [":renegade_loyalty&"] = "场上人数＞4且有忠臣死亡时，你可以变为忠臣。（出牌阶段或每个回合结束时结算）" ..
      "<br/><font color='gray'><small>操作提示：需预亮以发动；出牌阶段空闲时从不预亮点为预亮需等待至下个空闲时发动</small></font>",

  ["#renegade_loyalty&"] = "侍奉明主：你可以变为忠臣",
}

local spec = {
  can_trigger = function (self, event, target, player, data)
    if not player:hasSkill(loyalty.name) or player.role ~= "renegade" or not (event == fk.TurnEnd or player == target) then return end
    local room = player.room
    return #room.alive_players > 4 and table.find(room.players, function(p) return p.dead and p.role == "loyalist" end)
  end,
  on_use = function (self, event, target, player, data)
    local room = player.room
    room:setPlayerProperty(player, "role", "loyalist")
    room:setPlayerProperty(player, "role_shown", true)
    player:loseFakeSkill("renegade_wild&")
    player:loseFakeSkill("renegade_loyalty&")
  end,
}

loyalty:addEffect(fk.TurnEnd, {
  anim_type = "big",
  can_trigger = spec.can_trigger,
  on_use = spec.on_use,
})

loyalty:addEffect(fk.BeforePlayCard, {
  anim_type = "big",
  can_trigger = spec.can_trigger,
  on_use = spec.on_use,
})

return loyalty
