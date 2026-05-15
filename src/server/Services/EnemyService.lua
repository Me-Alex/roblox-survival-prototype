-- EnemyService.lua
-- Stub — no enemies yet. Full AI in Milestone 4.

local EnemyService = {}
local ctx

function EnemyService:init(context)
    ctx = context
    print("[EnemyService] Initialised (stub)")
end

function EnemyService:tick(dt) end

return EnemyService
