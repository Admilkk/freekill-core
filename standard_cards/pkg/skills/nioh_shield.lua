local skill = fk.CreateSkill {
  name = "#nioh_shield_skill",
  tags = { Skill.Compulsory },
  attached_equip = "nioh_shield",
}

skill:addEffect(fk.PreCardEffect, {
  can_trigger = function(self, event, target, player, data)
    return data.to == player and player:hasSkill(skill.name) and
    data.card.trueName == "slash" and data.card.color == Card.Black
  end,
  on_use = function(self, event, target, player, data)
    data:setNullified(player)
  end,
})

return skill
