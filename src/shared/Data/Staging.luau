--!strict
-- The Rofront Staging experience (2026-10-04: a separate game to test changes in before they go to
-- prod): its universe id, for what differs there (Data/Products' ids, the game menu's
-- "Replay as new player").
local Staging = {}

--- Rofront Staging's universe id.
--- 0: WorldWar has no staging experience yet (the original RoWorld's was 10769439627).
Staging.UNIVERSE = 0

--- True in the Rofront Staging experience.
function Staging.here(): boolean
	-- (an unpublished place has GameId 0 too: with no staging experience, nothing is staging)
	return Staging.UNIVERSE ~= 0 and typeof(game) == "Instance" and (game :: any).GameId == Staging.UNIVERSE
end

return Staging
