local skill = fk.CreateSkill {
  name = "#axe_skill",
  attached_equip = "axe",
}

skill:addEffect(fk.CardEffectCancelledOut, {
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and
      data.from == player and data.card.trueName == "slash" and not data.to.dead and
      #player:getCardIds("he") > 1
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local cards = {}
    for _, id in ipairs(player:getCardIds("he")) do
      if not player:prohibitDiscard(id) and
        not (table.contains(player:getEquipments(Card.SubtypeWeapon), id)
         and (player:getVirtualEquip(id) or Fk:getCardById(id)).name == "axe") then
        table.insert(cards, id)
      end
    end
    cards = room:askToDiscard(player, {
      min_num = 2,
      max_num = 2,
      include_equip = true,
      skill_name = skill.name,
      cancelable = true,
      pattern = tostring(Exppattern{ id = cards }),
      prompt = "#axe-invoke::"..data.to.id,
      skip = true,
    })
    if #cards > 0 then
      event:setCostData(self, { cards = cards })
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    player.room:throwCard(event:getCostData(self).cards, skill.name, player, player)
    data.isCancellOut = false
    data:setDisresponsive(data.to)
  end,
})

skill:addAI(Fk.Ltk.AI.newDiscardStrategy {
  choose_cards = function(self, ai)
    local effect = ai.room.logic:getCurrentEvent().data._data
    local available_cards = ai:getEnabledCards()
    ai:sortCards(available_cards, "keep_value")
    available_cards = table.slice(available_cards, 1, 3)
    if #available_cards == 2 then
      local benefit = ai:getBenefitOfEvents(function(logic)
        logic:moveCardTo(available_cards, Card.DiscardPile, nil, fk.ReasonDiscard, ai.data[1], nil, false, ai.player)
        logic:doCardEffect(effect)
      end)
      if benefit >= 0 then
        return available_cards, benefit
      end
    end
  end,
})

return skill
