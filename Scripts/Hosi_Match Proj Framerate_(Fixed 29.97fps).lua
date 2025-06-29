-- @description Match Proj Framerate (Fixed 29.97fps)
-- @author Aaron Cendan (Modified)
-- @version 1.4
-- @metapackage
-- @provides
--   [main] . > acendan_Prompt to match project frame rate with first video item import.lua
-- @link https://aaroncendan.me
-- @about
--   This is a background/toggle script! It works best when set up as a startup action, or enabled in a default project template. 
--   It just checks to see if the first imported video item has a framerate that matches the project. It will self-terminate after scanning.
--   It requires: ACendan Lua Utilities, Ultraschall API, and FFPROBE to be installed
--   FIXED: Proper 29.97fps detection and handling
-- @changelog
--   # Fixed 29.97fps detection and conversion logic
--   # Improved framerate parsing accuracy
--   # Added better debugging for framerate detection
 
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- ~~~~~~~~~~~ GLOBAL VARS ~~~~~~~~~~
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- Refresh rate (in seconds)
local refresh_rate = 1.0

-- Get action context info (needed for toolbar button toggling)
local _, _, section, cmdID = reaper.get_action_context()

-- Get this script's name and directory
local script_name = ({reaper.get_action_context()})[2]:match("([^/\\_]+)%.lua$")
local script_directory = ({reaper.get_action_context()})[2]:sub(1,({reaper.get_action_context()})[2]:find("\\[^\\]*$"))

-- Enable/disable debugging
local dbg = false

-- Confirm OS
local windows = string.find(reaper.GetOS(), "Win") ~= nil
local separator = windows and '\\' or '/'

-- Load lua utilities
acendan_LuaUtils = reaper.GetResourcePath()..'/Scripts/ACendan Scripts/Development/acendan_Lua Utilities.lua'
if reaper.file_exists( acendan_LuaUtils ) then dofile( acendan_LuaUtils ); if not acendan or acendan.version() < 3.0 then acendan.msg('This script requires a newer version of ACendan Lua Utilities. Please run:\n\nExtensions > ReaPack > Synchronize Packages',"ACendan Lua Utilities"); return end else reaper.ShowConsoleMsg("This script requires ACendan Lua Utilities! Please install them here:\n\nExtensions > ReaPack > Browse Packages > 'ACendan Lua Utilities'"); return end

-- Load Ultraschall API
ultraschall_path = reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua"
if reaper.file_exists( ultraschall_path ) then dofile( ultraschall_path ) else reaper.ShowConsoleMsg("This script requires the Ultraschall API, available via Reapack. Extensions > ReaPack > Import Repositories:\n\nhttps://raw.githubusercontent.com/Ultraschall/ultraschall-lua-api-for-reaper/master/ultraschall_api_index.xml"); return end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- ~~~~~~~~~~~~ FUNCTIONS ~~~~~~~~~~~
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- Setup runs once on script startup
function setup()
  -- Timing control
  local start = reaper.time_precise()
  check_time = start
  
  -- Toggle command state on
  reaper.SetToggleCommandState( section, cmdID, 1 )
  reaper.RefreshToolbar2( section, cmdID )
  
  -- Init do-once
  do_once = true
end

-- Main function will run in Reaper's defer loop. EFFICIENCY IS KEY.
function main()
  -- System time in seconds (3600 per hour)
  local now = reaper.time_precise()
  
  -- If the amount of time passed is greater than refresh rate, execute code
  if now - check_time >= refresh_rate then

    if do_once then
      -- Loop through all items
      local num_items = reaper.CountMediaItems( 0 )
      if num_items > 0 then
        for i=0, num_items - 1 do
          local item =  reaper.GetMediaItem( 0, i )
          local take = reaper.GetActiveTake( item )
          if take then 
            local src =  reaper.GetMediaItemTake_Source( take )
            local typebuf = reaper.GetMediaSourceType( src, "" )

            -- If video item found, then check frame rate and prompt to match
            if typebuf == "VIDEO" then
            
              -- Save project
              reaper.Main_SaveProject( 0, false )
              if reaper.IsProjectDirty(0) > 0 then
                local r = reaper.MB("To check whether imported videos match the current project's framerate, the project must be saved!\n\nClick 'Retry' to save the project or 'Cancel' to turn off this script.\n\n~~~\nacendan_Prompt to match project frame rate with first video item import.lua","ACendan Project Framerate Checker",5)
                if r == 2 then do_once = false end
                break
              end
              
              -- Get project's current framerate settings
              local project_framerate = getRPPFrameRateSettings()
              if dbg then acendan.dbg("Project Framerate: " .. project_framerate) end
              
              if project_framerate then
                local item_framerate = getVideoItemFramerate(item, take, src)
                -- REMOVED THE PROBLEMATIC LINE THAT FORCED 29.97 TO 30.0
                if dbg then acendan.dbg("Item Framerate: " .. item_framerate) end
                
                -- More accurate framerate comparison
                if not compareFramerates(item_framerate, project_framerate) then
                  -- Prompt to conform
                  local result = reaper.MB("Current project framerate (" .. project_framerate .. "fps) does not match imported video's framerate! Would you like to set project framerate to: " .. item_framerate .. "fps?\n\n~~~\nacendan_Prompt to match project frame rate with first video item import.lua","Project Framerate Mismatch!",4)
                  if result == 6 then
                    local new_proj_framerate = convertFramerateToReaperValue(item_framerate)
                    if dbg then acendan.dbg("New project framerate value: " .. tostring(new_proj_framerate)) end                         
                    local retval = ultraschall.ProjectSettings_SetVideoFramerate(new_proj_framerate, false)
                    if retval then acendan.msg("Succesfully set project to new framerate!\n\nThis script is relatively resource-intensive, so it will be automatically disabled now. To manually re-enable it, search for 'acendan video import' in the actions list. It works best as a startup action or when enabled in a default project template.\n\n~~~\nacendan_Prompt to match project frame rate with first video item import.lua","ACendan Project Framerate Checker") else acendan.msg("Failed to set project to new framerate :( Please do so manually in File > Project Settings.\n\nThis script is relatively resource-intensive, so it will be automatically disabled now. To manually re-enable it, search for 'acendan video import' in the actions list. It works best as a startup action or when enabled in a default project template.","ACendan Project Framerate Checker") end
                  end
                else
                  acendan.msg("Project framerate matches imported video!\n\nThis script is relatively resource-intensive, so it will be automatically disabled now. To manually re-enable it, search for 'acendan video import' in the actions list. It works best as a startup action or when enabled in a default project template.\n\n~~~\nacendan_Prompt to match project frame rate with first video item import.lua","ACendan Project Framerate Checker") 
                end
              else
                if dbg then acendan.dbg("Failed to find project framerate in RPP file.") end
              end
              
              -- Save project and exit loop
              reaper.Main_SaveProject( 0, false )
              do_once = false
              break
            end
          end
        end
      end
    else
      Exit()
    end
    
    -- Reset last used time
    check_time = now
  end

  reaper.defer(main)
end

-- Exit function will run once when the script is terminated
function Exit()
  reaper.UpdateArrange()
  reaper.SetToggleCommandState( section, cmdID, 0 )
  reaper.RefreshToolbar2( section, cmdID )
  return reaper.defer(function() end)
end

-- Get current project's frame rate settings. Project Settings > Video > Frame Rate // Returns String
function getRPPFrameRateSettings()
  local proj, filename = reaper.EnumProjects(-1, "")
  if filename then
    local file = io.open(filename,"r")
    io.input(file)
    local chunk = "TIMEMODE"
    local framerate = nil
    for line in io.lines() do
      if line:find(chunk) then
        local keys = line:sub(line:find(chunk) + 9)
        local second_key = keys:sub(keys:find(" ")+1,keys:find(" ",2)+1)
        framerate = (second_key == "0") and "23.976" or
                    (second_key == "1") and "24.0" or
                    (second_key == "2") and "25.0" or
                    (second_key == "3") and "29.97DF" or
                    (second_key == "4") and "29.97ND" or
                    (second_key == "5") and "30.0" or
                    (second_key == "6") and "75.0" or
                    (second_key == "7") and "48.0" or
                    (second_key == "8") and "50.0" or
                    (second_key == "9") and "60.0" or nil
        break
      end
    end
    io.close(file)
    return framerate
  else
    return nil
  end
end

-- IMPROVED: Get video item framerate using ffprobe with better 29.97fps detection
function getVideoItemFramerate(item, take, source)
  -- Default location for ffprobe is in UserPlugins directory
  executable =  reaper.GetResourcePath() .. separator .. 'UserPlugins' .. separator .. (windows and 'ffprobe.exe' or 'ffprobe')
  
  -- Confirm ffprobe present
  if not reaper.file_exists(executable) then
    acendan.dbg("ffprobe not found!\n\nPlease install ffmpeg and place the 'ffmpeg', 'ffprobe', and 'ffplay' files in your REAPER\\UserPlugins folder.\n\nWINDOWS: https://github.com/BtbN/FFmpeg-Builds/releases\n\nMAC: https://ffmpeg.org/download.html")
  else
    -- Prep file/command for ffprobe
    local file = reaper.GetMediaSourceFileName(source, "")
    local path,name,extension = SplitFilename(file)
    name = removeFileExtension(name)
    local arguments = " -of json -show_streams "
    local command = escape(executable) .. arguments .. escape(file)

    -- Get info on item via ffprobe
    if windows then
      ffprobe_info = reaper.ExecProcess( command, 0 )
    else
      ffprobe_info = reaper.ExecProcess( command, 0 )
    end

    -- Parse info with improved accuracy
    if dbg then acendan.dbg("FFProbe output: " .. ffprobe_info) end
    local key = '"r_frame_rate": "'
    local frames = ffprobe_info:sub(ffprobe_info:find(key) + key:len(),ffprobe_info:find(key) + string.find(ffprobe_info:sub(ffprobe_info:find(key),-1),",") - 3)
    
    if dbg then acendan.dbg("Raw frame rate string: " .. frames) end
    
    local dividend = tonumber(frames:sub(1, frames:find("/")-1))
    local divisor = tonumber(frames:sub(frames:find("/")+1,-1))
    local framerate_float = dividend / divisor
    
    if dbg then acendan.dbg("Calculated framerate (float): " .. tostring(framerate_float)) end
    
    -- More precise framerate detection
    local framerate = detectPreciseFramerate(framerate_float, frames)
    
    if dbg then acendan.dbg("Final detected framerate: " .. framerate) end
    
    return framerate
  end
end

-- NEW FUNCTION: Detect precise framerate including proper 29.97fps detection
function detectPreciseFramerate(framerate_float, raw_fraction)
  -- Round to reasonable precision for comparison
  local rounded = math.floor(framerate_float * 1000 + 0.5) / 1000
  
  -- Check for common NTSC framerates (29.97, 23.976, 59.94)
  if math.abs(framerate_float - 29.970029970029972) < 0.001 or 
     math.abs(framerate_float - 29.97) < 0.001 or
     raw_fraction == "30000/1001" then
    return "29.97"
  elseif math.abs(framerate_float - 23.976023976023978) < 0.001 or
         raw_fraction == "24000/1001" then
    return "23.976"
  elseif math.abs(framerate_float - 59.940059940059943) < 0.001 or
         raw_fraction == "60000/1001" then
    return "59.94"
  -- Standard framerates
  elseif math.abs(framerate_float - 24.0) < 0.001 then
    return "24.0"
  elseif math.abs(framerate_float - 25.0) < 0.001 then
    return "25.0"
  elseif math.abs(framerate_float - 30.0) < 0.001 then
    return "30.0"
  elseif math.abs(framerate_float - 48.0) < 0.001 then
    return "48.0"
  elseif math.abs(framerate_float - 50.0) < 0.001 then
    return "50.0"
  elseif math.abs(framerate_float - 60.0) < 0.001 then
    return "60.0"
  elseif math.abs(framerate_float - 75.0) < 0.001 then
    return "75.0"
  else
    -- Return the rounded value as string for unknown framerates
    return tostring(rounded)
  end
end

-- NEW FUNCTION: Compare framerates more accurately
function compareFramerates(item_fps, project_fps)
  -- Handle different representations of 29.97
  if (item_fps == "29.97" or item_fps == "29.970") and 
     (project_fps == "29.97DF" or project_fps == "29.97ND") then
    return true
  end
  
  -- Handle 23.976
  if item_fps == "23.976" and project_fps == "23.976" then
    return true
  end
  
  -- Direct string comparison for other cases
  if item_fps == project_fps then
    return true
  end
  
  return false
end

-- NEW FUNCTION: Convert framerate string to REAPER internal value
function convertFramerateToReaperValue(framerate_string)
  if framerate_string == "23.976" then
    return -1
  elseif framerate_string == "24.0" then
    return 1
  elseif framerate_string == "25.0" then
    return 2
  elseif framerate_string == "29.97" then
    return 0  -- Default to drop frame, can be changed to -2 for non-drop
  elseif framerate_string == "30.0" then
    return 5
  elseif framerate_string == "48.0" then
    return 7
  elseif framerate_string == "50.0" then
    return 8
  elseif framerate_string == "60.0" then
    return 9
  elseif framerate_string == "75.0" then
    return 6
  else
    -- Try to parse as number for custom framerates
    local num = tonumber(framerate_string)
    return num or 5  -- Default to 30fps if parsing fails
  end
end

function escape(filename)
  return '"' .. filename .. '"'
end

function SplitFilename(strFilename)
  -- Returns the Path, Filename, and Extension as 3 values
  return string.match(strFilename,"^(.-)([^\\/]-%.([^\\/%.]-))%.?$")
end

function removeFileExtension(name)
  return name:match("(.+)%..+")
end

function split(str,sep)
    local array = {}
    local reg = string.format("([^%s]+)",sep)
    for mem in string.gmatch(str,reg) do
        table.insert(array, mem)
    end
    return array
end

-- parses ffprobe output line which has format k=v|k=v|k=v etc
function parseLine(line)
  --msg(line)
  local result = {}
  for pair in line.gmatch(line, "[^|]+") do
    local s = split(pair, "=")
    local k = s[1]
    local v = s[2]
    result[k] = v
  end
  return result
end


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- ~~~~~~~~~~~~~~ MAIN ~~~~~~~~~~~~~~
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

setup()
reaper.atexit(Exit)
main()
