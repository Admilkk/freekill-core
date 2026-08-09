
local wild = fk.CreateSkill {
  name = "renegade_wild&",
  mode_skill = true,
}

Fk:loadTranslationTable{
  ["renegade_wild&"] = "自立",
  [":renegade_wild&"] = "内奸可以成为野心家：获得野心家标记（出牌阶段，弃置以摸两张牌或回复1点体力）" ..
      "和〖飞扬〗〖跋扈〗，杀死角色摸三张牌。（出牌阶段或每个回合结束时结算）" ..
      "<br/><font color='gray'><small>操作提示：需预亮以发动；出牌阶段空闲时从不预亮点为预亮需等待至下个空闲时发动</small></font>",

  ["#renegade_wild&"] = "侍奉明主：你可以变为忠臣",
}

---@type TrigSkelSpec<TurnFunc|>
local spec = {
  can_trigger = function (self, event, target, player, data)
    return player:hasSkill(wild.name) and player.role == "renegade" and (event == fk.TurnEnd or player == target)
  end,
  on_use = function (self, event, target, player, data)
    local room = player.room
    room:setPlayerProperty(player, "role", "wild")
    room:setPlayerProperty(player, "role_shown", true)
    room:addPlayerMark(player, "@!!m_role_wild", 1)
    player:loseFakeSkill("renegade_wild&")
    player:loseFakeSkill("renegade_loyalty&")
    room:handleAddLoseSkills(player, "m_feiyang|m_bahu|m_role_wild_draw&", nil, false, true)
  end,
}

wild:addEffect(fk.TurnEnd, {
  anim_type = "big",
  can_trigger = spec.can_trigger,
  on_use = spec.on_use,
})

wild:addEffect(fk.BeforePlayCard, {
  anim_type = "big",
  can_trigger = spec.can_trigger,
  on_use = spec.on_use,
})

return wild
