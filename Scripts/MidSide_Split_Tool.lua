-- Mid/Side Split Tool for REAPER
-- Author: Hosi Prod with the support of Claude AI.


-- Configuration
local CONFIG = {
  -- Track naming
  folder_suffix = " MS",
  orig_prefix = "ORIG ",
  mid_prefix = "MID ",
  side_prefix = "SIDE ",
  
  -- Colors (RGB)
  colors = {
    mid = {255, 200, 100},     -- Orange
    side = {100, 200, 255},    -- Blue  
    orig = {180, 180, 180},    -- Gray
    folder = {220, 220, 220}   -- Light gray
  },
  
  -- Processing options
  preserve_item_colors = true,
  auto_solo_ms_tracks = false,
  create_send_to_master = true,
  add_spectrum_analyzer = false,
  vocal_mode = false
}


function ShowGUI()
  -- Simple configuration GUI using REAPER's input dialog
  local retval, retvals_csv = reaper.GetUserInputs(
    "Mid/Side Split Options", 
    6,
    "Preserve item colors (1/0):,Auto-solo M/S tracks (1/0):,Create sends to master (1/0):,Add spectrum analyzer (1/0):,Folder suffix:,Vocal (0=Normal, 1=Focused):",
    string.format("%d,%d,%d,%d,%s,0", 
      CONFIG.preserve_item_colors and 1 or 0,
      CONFIG.auto_solo_ms_tracks and 1 or 0, 
      CONFIG.create_send_to_master and 1 or 0,
      CONFIG.add_spectrum_analyzer and 1 or 0,
      CONFIG.folder_suffix
    )
  )
  
  if not retval then return false end
  
  local values = {}
  for value in string.gmatch(retvals_csv, "([^,]+)") do
    table.insert(values, value)
  end
  
  if #values >= 6 then
    CONFIG.preserve_item_colors = (values[1] == "1")
    CONFIG.auto_solo_ms_tracks = (values[2] == "1") 
    CONFIG.create_send_to_master = (values[3] == "1")
    CONFIG.add_spectrum_analyzer = (values[4] == "1")
    CONFIG.folder_suffix = values[5] ~= "" and values[5] or " MS"
    
    -- Processing mode for different content types
    local mode = tonumber(values[6]) or 0
    if mode == 1 then
      CONFIG.vocal_mode = true
    end
  end
  
  return true
end

function ValidateSelection()
  local sel_tracks = reaper.CountSelectedTracks(0)
  
  if sel_tracks == 0 then
    reaper.ShowMessageBox("Please select at least one track.", "Error", 0)
    return nil
  elseif sel_tracks > 1 then
    -- Ask user if they want to process multiple tracks
    local result = reaper.ShowMessageBox(
      "Multiple tracks selected. Process all selected tracks?", 
      "Multiple Tracks", 
      4
    )
    if result == 7 then return nil end -- User clicked No
    
    -- Return all selected tracks
    local tracks = {}
    for i = 0, sel_tracks - 1 do
      tracks[#tracks + 1] = reaper.GetSelectedTrack(0, i)
    end
    return tracks
  end
  
  return {reaper.GetSelectedTrack(0, 0)}
end

function GetAudioItems(track)
  local items = {}
  local item_count = reaper.CountTrackMediaItems(track)
  
  for i = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    local take = reaper.GetActiveTake(item)
    
    if take and not reaper.TakeIsMIDI(take) then
      -- Check if it's actually audio
      local source = reaper.GetMediaItemTake_Source(take)
      local source_type = reaper.GetMediaSourceType(source, "")
      
      if source_type == "WAVE" or source_type == "FLAC" or source_type == "MP3" or source_type == "AIFF" then
        items[#items + 1] = item
      end
    end
  end
  
  return items
end

function CreateTrackStructure(track, track_name, track_idx)
  -- Create folder track
  reaper.InsertTrackAtIndex(track_idx, true)
  local folder_track = reaper.GetTrack(0, track_idx)
  reaper.GetSetMediaTrackInfo_String(folder_track, "P_NAME", track_name .. CONFIG.folder_suffix, true)
  reaper.SetMediaTrackInfo_Value(folder_track, "I_FOLDERDEPTH", 1)
  
  -- Set folder track color
  local folder_color = reaper.ColorToNative(
    CONFIG.colors.folder[1], 
    CONFIG.colors.folder[2], 
    CONFIG.colors.folder[3]
  ) | 0x1000000
  reaper.SetTrackColor(folder_track, folder_color)
  
  -- Original track setup
  local orig_track = reaper.GetTrack(0, track_idx + 1)
  reaper.GetSetMediaTrackInfo_String(orig_track, "P_NAME", CONFIG.orig_prefix .. track_name, true)
  
  -- Create Mid and Side tracks
  reaper.InsertTrackAtIndex(track_idx + 2, true)
  local mid_track = reaper.GetTrack(0, track_idx + 2)
  reaper.GetSetMediaTrackInfo_String(mid_track, "P_NAME", CONFIG.mid_prefix .. track_name, true)
  
  reaper.InsertTrackAtIndex(track_idx + 3, true)
  local side_track = reaper.GetTrack(0, track_idx + 3)
  reaper.GetSetMediaTrackInfo_String(side_track, "P_NAME", CONFIG.side_prefix .. track_name, true)
  
  -- Set folder structure
  reaper.SetMediaTrackInfo_Value(orig_track, "I_FOLDERDEPTH", 0)
  reaper.SetMediaTrackInfo_Value(mid_track, "I_FOLDERDEPTH", 0)
  reaper.SetMediaTrackInfo_Value(side_track, "I_FOLDERDEPTH", -1)
  
  -- Mute original track
  reaper.SetMediaTrackInfo_Value(orig_track, "B_MUTE", 1)
  
  -- Add Mid/Side Decoder to folder track
  local folder_fx = reaper.TrackFX_AddByName(folder_track, "JS: Mid/Side Decoder", false, -1)
  if folder_fx >= 0 then
    reaper.TrackFX_SetOpen(folder_track, folder_fx, false)
  end
  
  -- Add spectrum analyzer if requested
  if CONFIG.add_spectrum_analyzer then
    local analyzer_fx = reaper.TrackFX_AddByName(folder_track, "ReaEQ", false, -1)
    if analyzer_fx >= 0 then
      reaper.TrackFX_SetOpen(folder_track, analyzer_fx, false)
    end
  end
  
  -- Color the tracks
  local mid_color = reaper.ColorToNative(CONFIG.colors.mid[1], CONFIG.colors.mid[2], CONFIG.colors.mid[3]) | 0x1000000
  local side_color = reaper.ColorToNative(CONFIG.colors.side[1], CONFIG.colors.side[2], CONFIG.colors.side[3]) | 0x1000000
  local orig_color = reaper.ColorToNative(CONFIG.colors.orig[1], CONFIG.colors.orig[2], CONFIG.colors.orig[3]) | 0x1000000
  
  reaper.SetTrackColor(mid_track, mid_color)
  reaper.SetTrackColor(side_track, side_color)
  reaper.SetTrackColor(orig_track, orig_color)
  
  -- Auto-solo Mid/Side tracks if requested
  if CONFIG.auto_solo_ms_tracks then
    reaper.SetMediaTrackInfo_Value(mid_track, "I_SOLO", 1)
    reaper.SetMediaTrackInfo_Value(side_track, "I_SOLO", 1)
  end
  
  -- Create sends to master bus if requested
  if CONFIG.create_send_to_master then
    local master_track = reaper.GetMasterTrack(0)
    reaper.CreateTrackSend(mid_track, master_track)
    reaper.CreateTrackSend(side_track, master_track)
  end
  
  return folder_track, orig_track, mid_track, side_track
end

function ProcessItemEnhanced(item, orig_track, mid_track, side_track, temp_track)
  -- Store original item properties
  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_vol = reaper.GetMediaItemInfo_Value(item, "D_VOL")
  local item_color = reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
  
  local take = reaper.GetActiveTake(item)
  if not take then return false end
  
  local source = reaper.GetMediaItemTake_Source(take)
  local orig_name = reaper.GetTakeName(take)
  if orig_name == "" then
    orig_name = "Item"
  end
  
  -- Clear temp track
  local temp_item_count = reaper.CountTrackMediaItems(temp_track)
  for i = temp_item_count - 1, 0, -1 do
    local temp_item = reaper.GetTrackMediaItem(temp_track, i)
    reaper.DeleteTrackMediaItem(temp_track, temp_item)
  end
  
  -- Copy item to temp track
  reaper.SetOnlyTrackSelected(temp_track)
  reaper.SetMediaItemSelected(item, true)
  reaper.Main_OnCommand(40698, 0) -- Copy
  reaper.Main_OnCommand(40058, 0) -- Paste
  
  -- Check if paste was successful
  if reaper.CountTrackMediaItems(temp_track) == 0 then
    return false
  end
  
  -- Process the copied item
  local temp_item = reaper.GetTrackMediaItem(temp_track, 0)
  local temp_take = reaper.GetActiveTake(temp_item)
  
  if not temp_take then return false end
  
  -- Add Mid/Side Encoder
  local fx_idx = reaper.TakeFX_AddByName(temp_take, "JS: Mid/Side Encoder", 1)
  if fx_idx >= 0 then
    reaper.TakeFX_SetEnabled(temp_take, fx_idx, true)
  end
  
  -- Add vocal-specific processing if in vocal mode
if CONFIG.vocal_mode then
    -- Add ReaEQ to Mid track for vocal presence boost at 3kHz
    local mid_eq = reaper.TrackFX_AddByName(mid_track, "ReaEQ", false, -1)
    if mid_eq >= 0 then
  -- ReaEQ parameter structure cho Band 1:
  -- Parameter 4: Enable/Disable Band 1
  -- Parameter 5: Frequency (normalized 0-1)
  -- Parameter 6: Gain (normalized, 0.5 = 0dB)
  -- Parameter 7: Bandwidth/Q factor
  -- Parameter 8: Filter Type
  
  -- Band 2 300Hz
  reaper.TrackFX_SetParam(mid_track, mid_eq, 4, 0.25) 
   
  -- Set frequency to 3kHz 
  -- Frequency calculation: 3000Hz trong range 20Hz-24kHz
  -- Normalized value: (3000-20)/(24000-20) ≈ 0.124
  reaper.TrackFX_SetParam(mid_track, mid_eq, 5, 0.124) -- 3kHz frequency
  
  -- Set gain boost cho vocal presence
  -- 0.5 = 0dB, 0.6 ≈ +3dB boost
  reaper.TrackFX_SetParam(mid_track, mid_eq, 6, 0.6) -- +3dB boost
  
  -- Set bandwidth/Q factor (moderate setting)
  reaper.TrackFX_SetParam(mid_track, mid_eq, 7, 0.4) -- Moderate Q
  
  -- Set filter type to Band/Parametric EQ
  -- 0.5 = Band type cho parametric boost/cut
  reaper.TrackFX_SetParam(mid_track, mid_eq, 8, 0.5) -- Band type
  
  -- Open EQ window để verify settings
  reaper.TrackFX_SetOpen(mid_track, mid_eq, true) -- Open để kiểm tra
end
    
    -- Optional: Add subtle high-frequency air to Side track
    local side_eq = reaper.TrackFX_AddByName(side_track, "ReaEQ", false, -1)
    if side_eq >= 0 then
      -- Enable high shelf filter
      reaper.TrackFX_SetParam(side_track, side_eq, 8, 1.0) -- Enable high shelf
      reaper.TrackFX_SetParam(side_track, side_eq, 9, 0.75) -- 8kHz shelf frequency  
      reaper.TrackFX_SetParam(side_track, side_eq, 10, 0.45) -- +5dB boost Band 4
      reaper.TrackFX_SetOpen(side_track, side_eq, false)
    end
end


  
  -- Glue the item
  reaper.SetOnlyTrackSelected(temp_track)
  reaper.SetMediaItemSelected(temp_item, true)
  reaper.Main_OnCommand(40362, 0) -- Glue
  
  -- Get processed source
  local glued_item = reaper.GetTrackMediaItem(temp_track, 0)
  if not glued_item then return false end
  
  local glued_take = reaper.GetActiveTake(glued_item)
  if not glued_take then return false end
  
  local glued_source = reaper.GetMediaItemTake_Source(glued_take)
  
  -- Create Mid item with enhanced properties
  local mid_item = reaper.AddMediaItemToTrack(mid_track)
  reaper.SetMediaItemInfo_Value(mid_item, "D_POSITION", item_pos)
  reaper.SetMediaItemInfo_Value(mid_item, "D_LENGTH", item_len)
  reaper.SetMediaItemInfo_Value(mid_item, "D_VOL", item_vol)
  
  local mid_take = reaper.AddTakeToMediaItem(mid_item)
  reaper.SetMediaItemTake_Source(mid_take, glued_source)
  reaper.GetSetMediaItemTakeInfo_String(mid_take, "P_NAME", CONFIG.mid_prefix .. orig_name, true)
  reaper.SetMediaItemTakeInfo_Value(mid_take, "I_CHANMODE", 3) -- Left channel only
  
  -- Set item color (preserve original or use default)
  local mid_item_color = CONFIG.preserve_item_colors and item_color ~= 0 and item_color or 
                        (reaper.ColorToNative(CONFIG.colors.mid[1], CONFIG.colors.mid[2], CONFIG.colors.mid[3]) | 0x1000000)
  reaper.SetMediaItemInfo_Value(mid_item, "I_CUSTOMCOLOR", mid_item_color)
  
  -- Create Side item with enhanced properties
  local side_item = reaper.AddMediaItemToTrack(side_track)
  reaper.SetMediaItemInfo_Value(side_item, "D_POSITION", item_pos)
  reaper.SetMediaItemInfo_Value(side_item, "D_LENGTH", item_len)
  reaper.SetMediaItemInfo_Value(side_item, "D_VOL", item_vol)
  
  local side_take = reaper.AddTakeToMediaItem(side_item)
  reaper.SetMediaItemTake_Source(side_take, glued_source)
  reaper.GetSetMediaItemTakeInfo_String(side_take, "P_NAME", CONFIG.side_prefix .. orig_name, true)
  reaper.SetMediaItemTakeInfo_Value(side_take, "I_CHANMODE", 4) -- Right channel only
  
  local side_item_color = CONFIG.preserve_item_colors and item_color ~= 0 and item_color or
                         (reaper.ColorToNative(CONFIG.colors.side[1], CONFIG.colors.side[2], CONFIG.colors.side[3]) | 0x1000000)
  reaper.SetMediaItemInfo_Value(side_item, "I_CUSTOMCOLOR", side_item_color)
  
  -- Enhanced panning with slight adjustment for better stereo imaging
  reaper.SetMediaTrackInfo_Value(mid_track, "D_PAN", -0.95) -- Slightly less than full left
  reaper.SetMediaTrackInfo_Value(side_track, "D_PAN", 0.95)  -- Slightly less than full right
  
  return true
end

function ProcessTrack(track)
  local track_name = ""
  local _, track_name = reaper.GetTrackName(track)
  if track_name == "" then track_name = "Track" end
  
  local track_idx = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
  
  -- Get audio items
  local items = GetAudioItems(track)
  
  if #items == 0 then
    reaper.ShowMessageBox("Track '" .. track_name .. "' has no audio items.", "Warning", 0)
    return false
  end
  
  -- Create track structure
  local folder_track, orig_track, mid_track, side_track = CreateTrackStructure(track, track_name, track_idx)
  
  -- Create temp track
  reaper.InsertTrackAtIndex(reaper.GetNumTracks(), true)
  local temp_track = reaper.GetTrack(0, reaper.GetNumTracks() - 1)
  reaper.GetSetMediaTrackInfo_String(temp_track, "P_NAME", "temp_ms_processing", true)
  
  -- Process each item
  local processed_count = 0
  for i = 1, #items do
    if ProcessItemEnhanced(items[i], orig_track, mid_track, side_track, temp_track) then
      processed_count = processed_count + 1
    end
  end
  
  -- Clean up temp track
  reaper.DeleteTrack(temp_track)
  
  return processed_count > 0
end

function Main()
  -- Check if required plugins are available
   
  -- Show configuration GUI
  if not ShowGUI() then
    return
  end
  
  -- Validate track selection
  local tracks = ValidateSelection()
  if not tracks then return end
  
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  
  local success_count = 0
  local total_tracks = #tracks
  
  -- Process each selected track
  for i = 1, total_tracks do
    if ProcessTrack(tracks[i]) then
      success_count = success_count + 1
    end
  end
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Enhanced Track Mid/Side Split", -1)
  
  -- Show completion message
  if success_count > 0 then
    local message = string.format(
      "Successfully processed %d of %d tracks.\n\nCreated Mid/Side splits with enhanced features.",
      success_count, total_tracks
    )
    reaper.ShowMessageBox(message, "Mid/Side Split Complete", 0)
  else
    reaper.ShowMessageBox("No tracks were processed successfully.", "Processing Failed", 0)
  end
end

-- Execute the script
Main()
