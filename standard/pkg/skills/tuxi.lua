local tuxi = fk.CreateSkill {
  name = "tuxi",
}

tuxi:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(tuxi.name) and player.phase == Player.Draw and not data.phase_end and
      table.find(player.room.alive_players, function(p)
        return p ~= player and not p:isKongcheng()
      end)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local targets = table.filter(room.alive_players, function(p)
      return p ~= player and not p:isKongcheng()
    end)

    local result = room:askToChoosePlayers(player, {
      targets = targets,
      min_num = 1,
      max_num = 2,
      prompt = "#tuxi-ask",
      skill_name = tuxi.name,
    })
    if #result > 0 then
      room:sortByAction(result)
      event:setCostData(self, {tos = result})
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data.phase_end = true
    for _, p in ipairs(event:getCostData(self).tos) do
      if player.dead then break end
      if not p.dead and not p:isKongcheng() then
        local c = room:askToChooseCard(player, {
          target = p,
          flag = "h",
          skill_name = tuxi.name,
        })
        room:obtainCard(player, c, false, fk.ReasonPrey, player, tuxi.name)
      end
    end
  end,
})

tuxi:addAI(Fk.Ltk.AI.newChoosePlayersStrategy{
  choose_players = function(self, ai)
    local player = ai.player
    -- 选出界面上所有可选的目标
    local players = ai:getEnabledTargets()
    -- 对所有目标计算他们被拿走一张手牌后对自己的收益
    local benefits = table.map(players, function(p)
      local ret, _ = player.ai:askToChooseCards({
        cards = p:getCardIds("h"),
        skill_name = tuxi.name,
        data = {
          to_place = Card.PlayerHand,
          target = player,
          reason = fk.ReasonPrey,
          proposer = player,
        },
      })
      return { p, ai:getBenefitOfEvents(function(logic)
        logic:obtainCard(player, ret, false, fk.ReasonPrey, player, tuxi.name)
      end) }
    end)
    -- 选择收益最高且大于0的两位 判断偷两位的收益加上放弃摸牌的负收益是否可以补偿
    local total_benefit = -ai:getBenefitOfEvents(function(logic)
      logic:drawCards(player, 2, "phase_draw")
    end)
    local targets = {}
    table.sort(benefits, function(a, b) return a[2] > b[2] end)
    for i, benefit in ipairs(benefits) do
      local p, val = table.unpack(benefit)
      if val < 0 then break end
      table.insert(targets, p)
      total_benefit = total_benefit + val
      if i == 2 then break end
    end
    if #targets == 0 or total_benefit <= 0 then return {} end
    return targets, total_benefit
  end,
})

return tuxi
