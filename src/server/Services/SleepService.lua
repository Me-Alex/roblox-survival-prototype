-- SleepService.lua  (Milestone 6b)
--
-- PURPOSE:
--   Listen to every Bedroll's ProximityPrompt in the world.
--   When a player triggers one, validate that:
--     1. The bedroll belongs to them (Owner tag matches UserId)
--     2. The bedroll is not on cooldown (only one sleep per day)
--   If valid:
--     • Fire SleepResponse { success=true } to the client.
--     • Wait for the client to fire SleepRequest (sent after the fade-out).
--     • Skip time to morning via WorldService:skipToMorning().
--     • Restore stamina to MaxStamina via VitalsService.
--     • Mark the bedroll Cooldown = true so it can't be used again until dawn.
--     • Fire SleepResponse { success=true, wakeUp=true } to trigger fade-in.
--
-- WHY WAIT FOR SleepRequest?
--   The client needs ~2 seconds to play the fade-to-black animation before
--   anything actually changes on the server. We wait for its signal so the
--   time-skip and stamina restore happen while the screen is black —
--   the player never sees the world pop to daytime.

local Workspace = game:GetService("Workspace")

local SleepService = {}
local ctx

-- Track which players are currently in the sleep sequence
-- (prevents double-triggering if they spam the prompt)
local sleeping = {}

-- ── Hook a single bedroll model ───────────────────────────────────────────

local function hookBedroll(model)
    -- The ProximityPrompt sits on the BedrollFrame part inside the model
    local frame  = model:FindFirstChild("BedrollFrame")
    if not frame then return end
    local prompt = frame:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then return end

    prompt.Triggered:Connect(function(player)
        -- Guard: already sleeping
        if sleeping[player] then return end

        local ownerVal   = frame:FindFirstChild("Owner")
        local cooldownVal= frame:FindFirstChild("Cooldown")

        -- Validate ownership
        if ownerVal and ownerVal.Value ~= "" then
            if ownerVal.Value ~= tostring(player.UserId) then
                ctx.Remotes.SleepResponse:FireClient(player, {
                    success = false,
                    message = "This bedroll belongs to someone else.",
                })
                return
            end
        end

        -- Validate cooldown (already slept today)
        if cooldownVal and cooldownVal.Value == true then
            ctx.Remotes.SleepResponse:FireClient(player, {
                success = false,
                message = "You already slept today. Wait for tomorrow.",
            })
            return
        end

        -- ── Valid — start sequence ───────────────────────────────────────
        sleeping[player] = true

        -- Tell the client to start fading out
        ctx.Remotes.SleepResponse:FireClient(player, {
            success  = true,
            fadeOut  = true,
            message  = "Sleeping...",
        })

        -- Wait for the client to confirm it has faded to black
        -- We use a one-shot connection with a 5-second timeout
        local received = false
        local conn
        conn = ctx.Remotes.SleepRequest.OnServerEvent:Connect(function(requestPlayer)
            if requestPlayer ~= player then return end
            received = true
            conn:Disconnect()

            -- ── Do all world changes while screen is black ────────────
            ctx.WorldService:skipToMorning()

            -- Restore stamina
            local v = ctx.VitalsService:get(player)
            if v then
                v.stamina = ctx.Config.Vitals.MaxStamina
            end

            -- Mark bedroll as used for today
            if cooldownVal then cooldownVal.Value = true end

            -- Small pause so the world has a frame to update
            task.wait(0.3)

            -- Tell client to fade back in
            ctx.Remotes.SleepResponse:FireClient(player, {
                success = true,
                wakeUp  = true,
            })

            sleeping[player] = nil
        end)

        -- Timeout: if client never fires SleepRequest within 5s, clean up
        task.delay(5, function()
            if not received then
                conn:Disconnect()
                sleeping[player] = nil
            end
        end)
    end)
end

-- ── Watch Workspace for new Bedroll models ─────────────────────────────────
-- WorldService:spawnBedroll() adds a Model named "Bedroll" to Workspace.
-- We hook it immediately when it appears.

function SleepService:init(context)
    ctx = context

    -- Hook any bedrolls already in the world (shouldn't be any at init, but safe)
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name == "Bedroll" then
            hookBedroll(obj)
        end
    end

    -- Hook future bedrolls as players place them
    Workspace.ChildAdded:Connect(function(child)
        if child:IsA("Model") and child.Name == "Bedroll" then
            -- Small wait to ensure all child Parts are parented
            task.wait()
            hookBedroll(child)
        end
    end)

    -- Clean up sleeping state if a player leaves mid-sequence
    game:GetService("Players").PlayerRemoving:Connect(function(player)
        sleeping[player] = nil
    end)

    print("[SleepService] Initialised")
end

return SleepService
