--[[
   * Category:    Item
   * Description: Select content items from cursor position with roomtone
   * Author:      Modified from Archie's original
   * Version:     2.1
--==========================================]]

--[[
 * ReaScript Name: Add all items on selected track into item selection
 * Author: X-Raym
 * Version: 1.0
--]]

function selected_items_on_tracks()
    reaper.Undo_BeginBlock()
    
    -- Loop through all selected tracks
    local selected_tracks_count = reaper.CountSelectedTracks(0)
    
    for i = 0, selected_tracks_count - 1 do
        -- Get the i-th selected track
        local track_sel = reaper.GetSelectedTrack(0, i)
        local item_num = reaper.CountTrackMediaItems(track_sel)
        
        -- Select all items in the track
        for j = 0, item_num - 1 do
            local item = reaper.GetTrackMediaItem(track_sel, j)
            reaper.SetMediaItemSelected(item, true)
        end
    end
    
    reaper.Undo_EndBlock("Select all items on selected tracks", 0)
end

selected_items_on_tracks()

-----------------------------------------------------------------------------
local function No_Undo()end; local function no_undo()reaper.defer(No_Undo)end
-----------------------------------------------------------------------------
local ENABLE_CONSOLE_OUTPUT = false  -- true: enable console, false: disable console
-- Configuration
local ROOM_TONE_KEYWORDS = {
    "room tone",
    "roomtone", 
    "ambient",
    "silence",
    "pause"
}

-- Function to check if item is room tone
local function isRoomTone(take_name)
    if not take_name or take_name == "" then return false end
    
    local name_lower = string.lower(take_name)
    for _, keyword in ipairs(ROOM_TONE_KEYWORDS) do
        if string.find(name_lower, keyword) then
            return true
        end
    end
    return false
end

-- Get cursor position
local cursor_pos = reaper.GetCursorPosition()

-- Get selected track
local SelTrack = reaper.GetSelectedTrack(0, 0)
if not SelTrack then no_undo() return end

-- Count items in track
local CountTrItem = reaper.CountTrackMediaItems(SelTrack)
if CountTrItem == 0 then no_undo() return end

local undo = 0
local selected_count = 0

-- Deselect all items first
reaper.SelectAllMediaItems(0, false)

-- Loop through all items in track
for i = 0, CountTrItem - 1 do 
    local item = reaper.GetTrackMediaItem(SelTrack, i)
    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    
    -- Only process items from cursor position onwards
    if item_pos >= cursor_pos then
        local take = reaper.GetActiveTake(item)
        local should_select = true
        
        if take ~= nil then
            local take_name = reaper.GetTakeName(take)
            if isRoomTone(take_name) then
                should_select = false
            end
        end
        
        if should_select then
            reaper.SetMediaItemSelected(item, true)
            selected_count = selected_count + 1
            undo = 1
        end
    end
end

-- Display message
if ENABLE_CONSOLE_OUTPUT and selected_count > 0 then
    reaper.ShowConsoleMsg("Selected " .. selected_count .. " content items from cursor position onwards\n")
end

-- Handle undo
if undo == 1 then 
    reaper.Undo_BeginBlock()   
    reaper.Undo_EndBlock("Select content items from cursor (" .. selected_count .. " items)", -1)
else   
    no_undo()
end                          

reaper.UpdateArrange()
