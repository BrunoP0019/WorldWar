-- Attack stances (Defs.STANCE_*, Rules.STANCE_LOSS / STANCE_TIME): blitz takes land faster for more
-- troops per tile, siege slower for fewer; an order names the stance (intent `kind`), a new order on
-- the same target changes it, a boat's landing keeps the one it sailed with, and the ATTACK event,
-- the snapshot row and the client mirror carry it.
require("./prelude") -- (Roblox datatypes for UICtx; it loads the test maps too)
local F = require("./simsys_fixture")
local Defs = F.Defs
local Ev = F.Ev
local Rules = require("../src/shared/Core/Rules")
local Sim = require("../src/shared/Core/Sim")
local GameState = require("../src/shared/Core/GameState")
local Protocol = require("../src/shared/Net/Protocol")

local expect = F.expect

--- Runs one attack of `troops` in `stance` for `ticks`; returns tiles taken and troops spent.
local function run(stance: number, against_player: boolean, ticks: number, troops: number): (number, number, any)
	local sim = F.new_sim(11)
	local me = F.owner(sim, "Me", Defs.KIND_HUMAN, 0, 0)
	local tg = 0
	if against_player then
		-- (the nation holds the land all around ours)
		tg = F.owner(sim, "Them", Defs.KIND_NATION, 0, 60000)
		F.claim(sim, tg, 540, 150, 14)
	end
	F.claim(sim, me, 540, 150, 5)
	local before = sim.o_tiles[me]
	local a = sim:start_attack(me, tg, troops, -1, stance)
	assert(a ~= nil, "the attack has a front")
	for _ = 1, ticks do
		F.advance(sim, 1)
		sim:attacks_tick()
		if a.dead then
			break
		end
	end
	return sim.o_tiles[me] - before, troops - a.troops, a
end

for _, vs in { false, true } do
	local who = if vs then "a nation" else "free land"
	local n_std, l_std = run(Defs.STANCE_STANDARD, vs, 12, 400000)
	local n_blitz, l_blitz = run(Defs.STANCE_BLITZ, vs, 12, 400000)
	local n_siege, l_siege = run(Defs.STANCE_SIEGE, vs, 12, 400000)
	print(
		string.format(
			"  %s, 12 ticks: standard %d tiles (%.0f troops/tile), blitz %d (%.0f), siege %d (%.0f)",
			who,
			n_std,
			l_std / n_std,
			n_blitz,
			l_blitz / n_blitz,
			n_siege,
			l_siege / n_siege
		)
	)
	expect(n_std > 0 and n_blitz > n_std and n_std > n_siege, "blitz takes " .. who .. " fastest, siege slowest")
	expect(
		l_blitz / n_blitz > l_std / n_std and l_std / n_std > l_siege / n_siege,
		"blitz pays the most troops per tile of " .. who .. ", siege the fewest"
	)
	if not vs then
		-- (free land: the troops a tile costs don't depend on the army left, so the ratio is exact)
		expect(
			F.near(l_blitz / n_blitz / (l_std / n_std), Rules.STANCE_LOSS[1], 0.05)
				and F.near(l_siege / n_siege / (l_std / n_std), Rules.STANCE_LOSS[2], 0.05),
			"troops per tile follow STANCE_LOSS"
		)
	end
end

-- a standard attack is what it was before stances: no stance and stance 0 are the same match
do
	local n0, l0 = run(0, true, 20, 90000)
	local n1, l1 = run(nil :: any, true, 20, 90000)
	local n2, l2 = run(7, true, 20, 90000)
	expect(n0 == n1 and l0 == l1, "an order without a stance is a standard attack")
	expect(n0 == n2 and l0 == l2, "an unknown stance is a standard attack")
end

-- the event and the snapshot row carry the stance; a new order changes it
do
	local sim = F.new_sim(12)
	local me = F.owner(sim, "Me", Defs.KIND_HUMAN, 0, 0)
	F.claim(sim, me, 540, 150, 5)
	local a = sim:start_attack(me, 0, 5000, -1, Defs.STANCE_SIEGE)
	local ev = F.events(sim, Ev.ATTACK)
	expect(a.stance == Defs.STANCE_SIEGE and #ev == 1 and ev[1][8] == Defs.STANCE_SIEGE, "ATTACK event carries the stance")
	expect(sim:attack_rows()[1][7] == Defs.STANCE_SIEGE, "the snapshot row carries the stance")
	-- a second order on a later tick is merged at the end of that tick, with its stance
	F.advance(sim, 1)
	sim:start_attack(me, 0, 3000, -1, Defs.STANCE_BLITZ)
	expect(a.stance == Defs.STANCE_SIEGE, "a new order doesn't change the stance mid-tick")
	sim:attacks_tick()
	expect(a.stance == Defs.STANCE_BLITZ, "a new order on the same target changes the attack's stance")
	-- the client mirror
	local gs = { attacks = {} }
	GameState._set_attack(gs :: any, { Ev.ATTACK, 5, 1, 0, 100, 3, false, Defs.STANCE_BLITZ }, 1)
	GameState._set_attack(gs :: any, { 6, 1, 0, 100, 3, false }, 0)
	expect(gs.attacks[5].stance == Defs.STANCE_BLITZ and gs.attacks[6].stance == 0, "GameState keeps the stance (none: standard)")
end

-- the intent: `kind` names the stance and survives the wire
do
	expect(
		Defs.stance_from_name("blitz") == 1
			and Defs.stance_from_name("siege") == 2
			and Defs.stance_from_name("standard") == 0
			and Defs.stance_from_name(nil) == 0
			and Defs.stance_from_name("nonsense") == 0
			and Defs.stance_from_name(12) == 0,
		"stance_from_name: blitz, siege, anything else standard"
	)
	local buf = Protocol.encode_intent({ type = "attack", tile = 77, ratio = 0.4, kind = "siege" })
	local it = buf and Protocol.decode_intent(buf)
	expect(it ~= nil and it.type == "attack" and it.tile == 77 and it.kind == "siege", "an attack intent's stance crosses the wire")
	local buf2 = Protocol.encode_intent({ type = "boat", tile = 78, ratio = 0.2, kind = "blitz" })
	local it2 = buf2 and Protocol.decode_intent(buf2)
	expect(it2 ~= nil and it2.kind == "blitz", "a boat intent's stance crosses the wire")
end

-- a whole Sim: the intent reaches the attack
do
	local sim = Sim.new(nil, { map_id = F.MAP_ID, seed = 5, tribes = 0, nations = 0 })
	local me = sim:add_human("k", "Me")
	local start = -1
	for _, t in F.land_tiles() do
		if sim:human_start(me, t) then
			start = t
			break
		end
	end
	for _ = 1, 400 do
		sim:step()
		if sim.phase == Defs.PHASE_PLAYING then
			break
		end
	end
	expect(start >= 0 and sim.phase == Defs.PHASE_PLAYING and sim.o_tiles[me] > 0, "a solo match starts")
	local target = -1
	for _, t in sim:owned_tiles(me) do
		for _, n in { t - 1, t + 1, t - sim.W, t + sim.W } do
			if n >= 0 and n < sim.N and buffer.readu8(sim.land, n) == 1 and buffer.readi32(sim.owner, n * 4) == 0 then
				target = n
			end
		end
	end
	sim:submit(me, { type = "attack", tile = target, ratio = 0.5, kind = "blitz" })
	sim:step()
	local a = sim:attack_between(me, 0)
	expect(target >= 0 and a ~= nil and a.stance == Defs.STANCE_BLITZ, "an attack intent with kind = blitz starts a blitz")
end

-- the AI's choice (nations and smart bot players; tribes and novice bots stay standard)
do
	local SimAI = require("../src/shared/Core/SimAI")
	local sim = F.new_sim(13)
	sim.is_novice_bot = function(_self: any, _id: number): boolean
		return false
	end
	local nation = F.owner(sim, "Nation", Defs.KIND_NATION, 0, 100000)
	local tribe = F.owner(sim, "Tribe", Defs.KIND_TRIBE, 0, 100000)
	local weak = F.owner(sim, "Weak", Defs.KIND_HUMAN, 0, 10000)
	local even = F.owner(sim, "Even", Defs.KIND_HUMAN, 0, 50000)
	local mid = F.owner(sim, "Mid", Defs.KIND_HUMAN, 0, 30000)
	expect(SimAI.war_stance(sim, nation, weak, 50000) == Defs.STANCE_BLITZ, "a nation blitzes an army a fifth of what it sends")
	expect(SimAI.war_stance(sim, nation, even, 50000) == Defs.STANCE_SIEGE, "a nation lays siege in an even fight")
	expect(SimAI.war_stance(sim, nation, mid, 50000) == Defs.STANCE_STANDARD, "a nation attacks in between in the standard stance")
	expect(SimAI.war_stance(sim, nation, 0, 50000) == Defs.STANCE_STANDARD, "free land: standard")
	expect(SimAI.war_stance(sim, tribe, weak, 50000) == Defs.STANCE_STANDARD, "tribes: standard")
end

-- the client's stance (UICtx): R / a click cycles it, and every attack and boat order carries it
do
	local UICtx = require("../src/client/UI/UICtx") :: any
	local Signal = require("../src/shared/Core/Signal")
	local sent = {}
	local ctx = setmetatable({
		stance = 0,
		stance_changed = Signal.new(),
		sent_log = {},
		session = {
			send_intent = function(_s: any, intent: any)
				table.insert(sent, intent)
			end,
		},
	}, { __index = UICtx })
	local fired = {}
	ctx.stance_changed:Connect(function(v)
		table.insert(fired, v)
	end)
	ctx:cycle_stance()
	ctx:cycle_stance()
	ctx:cycle_stance()
	ctx:set_stance(0)
	ctx:set_stance(9)
	expect(#fired == 3 and fired[1] == 1 and fired[2] == 2 and fired[3] == 0, "cycle: blitz, siege, normal; no signal without a change")
	for st = 0, 2 do
		expect(Defs.stance_from_name(UICtx.STANCE_NAMES[st]) == st, "UICtx's name for stance " .. st .. " is the Sim's")
	end
	local ok = pcall(function()
		ctx:set_stance(2)
		ctx:send({ type = "attack", tile = 1, ratio = 0.25 })
		ctx:send({ type = "boat", tile = 1, ratio = 0.25, kind = "blitz" })
		ctx:send({ type = "build", tile = 1, kind = "city" })
		ctx:set_stance(0)
		ctx:send({ type = "attack", tile = 1, ratio = 0.25 })
	end)
	local log = ctx.sent_log
	expect(
		ok and #log == 4 and log[1].intent.kind == "siege" and log[2].intent.kind == "blitz" and log[3].intent.kind == "city" and log[4].intent.kind == nil,
		"orders carry the stance: siege, a named one kept, a build untouched, normal sends none"
	)
end

F.finish("stances")
