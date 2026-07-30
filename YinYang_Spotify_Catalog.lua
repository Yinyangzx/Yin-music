--[[
Yin Yang / Spotify repository manifest
======================================

This file is meant to live in a separate GitHub repo and be consumed by the
Spotify tab in the main library.

It centralizes:
- The music catalog (name, artist, duration, cover image, audio URL)
- The visual assets for buttons/icons if needed
- A local-cache workflow so Delta only downloads once per file
- A simple API the main library can call later

How to use from the main library later:
1) Load this file as a remote script or copy it into your repo.
2) Read the catalog from `YYSpotify.Catalog`.
3) Call `YYSpotify.GetTrack(index)` or `YYSpotify.GetTrackByName(name)`.
4) Call `YYSpotify.FetchAndCacheTrack(track)` before playing audio.
5) Use the returned `localAudio` / `localCover` paths with getcustomasset().

IMPORTANT:
- Replace the placeholder URLs with your real GitHub raw links.
- Keep the URLs stable so cached files remain valid.
- The `cacheDir` should exist in Delta's filesystem.
--]]

local YYSpotify = {}

YYSpotify.Version = "1.0.0"
YYSpotify.RepoName = "YinYang_Spotify_Catalog"
YYSpotify.CacheDir = "YinYang/SpotifyCache"

--// Global catalog controlled by a separate repository
YYSpotify.Catalog = {
    {
        id = "demo_1",
        name = "The Hills",
        artist = "The Weeknd",
        duration = 242,
        coverUrl = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/covers/the_hills.png",
        audioUrl = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/audio/the_hills.mp3",
        coverFile = "the_hills.png",
        audioFile = "the_hills.mp3",
        themeColor = Color3.fromRGB(35, 35, 35),
    },
    {
        id = "demo_2",
        name = "Save Your Tears",
        artist = "The Weeknd",
        duration = 215,
        coverUrl = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/covers/save_your_tears.png",
        audioUrl = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/audio/save_your_tears.mp3",
        coverFile = "save_your_tears.png",
        audioFile = "save_your_tears.mp3",
        themeColor = Color3.fromRGB(30, 30, 30),
    },
    {
        id = "demo_3",
        name = "Die For You",
        artist = "The Weeknd",
        duration = 260,
        coverUrl = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/covers/die_for_you.png",
        audioUrl = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/audio/die_for_you.mp3",
        coverFile = "die_for_you.png",
        audioFile = "die_for_you.mp3",
        themeColor = Color3.fromRGB(28, 28, 28),
    },
    {
        id = "demo_4",
        name = "Luna - En Vivo",
        artist = "Zoé",
        duration = 201,
        coverUrl = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/covers/luna_en_vivo.png",
        audioUrl = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/audio/luna_en_vivo.mp3",
        coverFile = "luna_en_vivo.png",
        audioFile = "luna_en_vivo.mp3",
        themeColor = Color3.fromRGB(26, 26, 26),
    },
}

local function normalize(str)
    return string.lower(tostring(str or "")):gsub("%s+", " "):match("^%s*(.-)%s*$")
end

function YYSpotify.GetTrack(index)
    return YYSpotify.Catalog[index]
end

function YYSpotify.GetTrackByName(name)
    local target = normalize(name)
    for _, track in ipairs(YYSpotify.Catalog) do
        if normalize(track.name) == target then
            return track
        end
    end
    return nil
end

function YYSpotify.GetTrackById(id)
    local target = normalize(id)
    for _, track in ipairs(YYSpotify.Catalog) do
        if normalize(track.id) == target then
            return track
        end
    end
    return nil
end

local function ensureCacheFolder()
    if makefolder and not isfolder(YYSpotify.CacheDir) then
        pcall(function()
            makefolder(YYSpotify.CacheDir)
        end)
    end
end

local function filePath(fileName)
    return YYSpotify.CacheDir .. "/" .. tostring(fileName)
end

local function exists(path)
    if isfile then
        local ok, res = pcall(isfile, path)
        return ok and res
    end
    return false
end

local function downloadIfNeeded(url, path)
    if exists(path) then
        return true, "cached"
    end

    local ok, data = pcall(function()
        return game:HttpGet(url, true)
    end)

    if not ok or not data or #data < 10 then
        return false, data
    end

    if writefile then
        local okWrite = pcall(function()
            writefile(path, data)
        end)
        if not okWrite then
            return false, "writefile_failed"
        end
    end

    return true, "downloaded"
end

-- Fetches and caches both cover image and audio for one track.
-- Returns:
--   success, resultTable
-- resultTable fields:
--   localCover, localAudio, coverStatus, audioStatus
function YYSpotify.FetchAndCacheTrack(track)
    if not track then
        return false, "track_missing"
    end

    ensureCacheFolder()

    local coverPath = filePath(track.coverFile)
    local audioPath = filePath(track.audioFile)

    local coverOk, coverStatus = downloadIfNeeded(track.coverUrl, coverPath)
    if not coverOk then
        return false, "cover_error:" .. tostring(coverStatus)
    end

    local audioOk, audioStatus = downloadIfNeeded(track.audioUrl, audioPath)
    if not audioOk then
        return false, "audio_error:" .. tostring(audioStatus)
    end

    local localCover = coverPath
    local localAudio = audioPath

    if getcustomasset then
        pcall(function()
            localCover = getcustomasset(coverPath)
        end)
        pcall(function()
            localAudio = getcustomasset(audioPath)
        end)
    end

    return true, {
        localCover = localCover,
        localAudio = localAudio,
        coverStatus = coverStatus,
        audioStatus = audioStatus,
        coverPath = coverPath,
        audioPath = audioPath,
    }
end

-- Helper for the UI layer:
-- returns a plain table with what the Spotify tab needs to render.
function YYSpotify.GetUIData(track)
    if not track then
        return nil
    end

    return {
        title = track.name,
        artist = track.artist,
        duration = track.duration,
        coverUrl = track.coverUrl,
        audioUrl = track.audioUrl,
        coverFile = track.coverFile,
        audioFile = track.audioFile,
        id = track.id,
        themeColor = track.themeColor,
    }
end

-- Convenience function for playing one selected track.
-- The UI layer can use this directly once you connect it.
function YYSpotify.PlayTrack(track, volume, looped)
    if not track then
        return false, "track_missing"
    end

    local okCache, result = YYSpotify.FetchAndCacheTrack(track)
    if not okCache then
        return false, result
    end

    if getgenv().YY_TestSound then
        pcall(function()
            getgenv().YY_TestSound:Stop()
            getgenv().YY_TestSound:Destroy()
        end)
    end

    local sound = Instance.new("Sound")
    sound.SoundId = result.localAudio
    sound.Volume = volume or 0.5
    sound.Looped = (looped ~= false)
    sound.Parent = game:GetService("Workspace")
    sound:Play()

    getgenv().YY_TestSound = sound

    return true, {
        sound = sound,
        cover = result.localCover,
        audio = result.localAudio,
        cache = result,
    }
end

return YYSpotify
