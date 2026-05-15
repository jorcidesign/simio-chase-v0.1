-- =============================================================================
-- RemoteRegistry.lua
-- Ubicación: src/ReplicatedStorage/Network/RemoteRegistry.lua
--
-- SPRINT 2 — Adiciones:
--   + OvertimeStarted  : Server → Client. Avisa que el overtime/escape comenzó.
--   + EscapeTimerTick  : Server → Client. Timer de los 20s de escape.
--   + EscapeSuccess    : Server → Client. Avisamos a un survivor que escapó.
-- =============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getFolder(name: string): Folder
    local f = ReplicatedStorage:FindFirstChild(name)
    if not f then
        f = Instance.new("Folder")
        f.Name = name
        f.Parent = ReplicatedStorage
    end
    return f
end

local function getOrCreateRemote(parent: Instance, name: string): RemoteEvent
    local ev = parent:FindFirstChild(name)
    if not ev then
        ev = Instance.new("RemoteEvent")
        ev.Name = name
        ev.Parent = parent
    end
    return ev
end

local function getOrCreateBindable(name: string): BindableEvent
    local ev = ReplicatedStorage:FindFirstChild(name)
    if not ev then
        ev = Instance.new("BindableEvent")
        ev.Name = name
        ev.Parent = ReplicatedStorage
    end
    return ev
end

local eventsFolder = getFolder("GameEvents")

local RemoteRegistry = {
    -- Estado del juego
    UpdateGameState  = getOrCreateRemote(eventsFolder, "UpdateGameState"),
    AssignRole       = getOrCreateRemote(eventsFolder, "AssignRole"),
    ExitOpen         = getOrCreateRemote(eventsFolder, "ExitOpen"),
    LMSStart         = getOrCreateRemote(eventsFolder, "LMSStart"),
    ShowRespawnMenu  = getOrCreateRemote(eventsFolder, "ShowRespawnMenu"),
    RequestRespawn   = getOrCreateRemote(eventsFolder, "RequestRespawn"),
    SetupCharacter   = getOrCreateRemote(eventsFolder, "SetupCharacter"),
    TimeUpdated      = getOrCreateRemote(eventsFolder, "TimeUpdated"),

    -- SPRINT 2: Overtime / Escape
    -- Server → Client: Avisa que el overtime comenzó. Args: ninguno.
    OvertimeStarted  = getOrCreateRemote(eventsFolder, "OvertimeStarted"),
    -- Server → Client: Tick del timer de escape. Args: (remaining: number).
    EscapeTimerTick  = getOrCreateRemote(eventsFolder, "EscapeTimerTick"),
    -- Server → Client: Avisamos a un survivor que escapó con éxito.
    EscapeSuccess    = getOrCreateRemote(eventsFolder, "EscapeSuccess"),

    -- Combate
    M1Attack            = getOrCreateRemote(eventsFolder, "M1Attack"),
    UseKillerAbility    = getOrCreateRemote(eventsFolder, "UseAbility"),
    UseSurvivorAbility  = getOrCreateRemote(eventsFolder, "UseSurvivorAbility"),
    DamageEffect        = getOrCreateRemote(eventsFolder, "DamageEffect"),
    StunEffect          = getOrCreateRemote(eventsFolder, "StunEffect"),
    BlindKiller         = getOrCreateRemote(eventsFolder, "eventBlindKiller"),
    MudScreen           = getOrCreateRemote(eventsFolder, "MudScreen"),
    PopupHack           = getOrCreateRemote(eventsFolder, "PopupHack"),
    ActivateDoubleJump  = getOrCreateRemote(eventsFolder, "ActivateDoubleJump"),
    RageUpdated         = getOrCreateRemote(eventsFolder, "RageUpdated"),
    SetSprintState      = getOrCreateRemote(eventsFolder, "SetSprintState"),
    SkillAnimStop       = getOrCreateRemote(eventsFolder, "SkillAnimStop"),
    SkillCastConfirmed  = getOrCreateRemote(eventsFolder, "SkillCastConfirmed"),

    -- Escape
    PlayerEscaped = getOrCreateRemote(eventsFolder, "PlayerEscaped"),
    KillExecution = getOrCreateRemote(eventsFolder, "KillExecution"),

    -- Selección
    SelectCharacter     = getOrCreateRemote(eventsFolder, "SelectCharacter"),
    StartSelectionPhase = getOrCreateRemote(eventsFolder, "StartSelectionPhase"),
    SyncSelectionList   = getOrCreateRemote(eventsFolder, "SyncSelectionList"),
    LoadSelection       = getOrCreateRemote(eventsFolder, "LoadSelection"),
    ShowMatchIntro      = getOrCreateRemote(eventsFolder, "ShowMatchIntro"),

    -- Stats
    DisplayStats = getOrCreateRemote(eventsFolder, "DisplayStats"),

    -- Bindables (Server → Server)
    LMSTimeout = getOrCreateBindable("LMSTimeout"),
    -- Debug API
    DebugSetTime   = getOrCreateRemote(eventsFolder, "DebugSetTime"),
    DebugSkipPhase = getOrCreateRemote(eventsFolder, "DebugSkipPhase"),
}

return RemoteRegistry