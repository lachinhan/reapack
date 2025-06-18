--[[
   * Category:    Item
   * Description: Remove silence by grid in selected media items (ReaImGui Version)
   * Author:      Archie (Setting GUI with ReaImGui By Hosi) 
   * Version:     1.08 - ReaImGui
   * AboutScript: Original Archie algorithm with ReaImGui interface
   
--]]

--======================================================================================
--////////////  REAIMGUI INTERFACE  \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
--======================================================================================

-- Check if ReaImGui is available
if not reaper.ImGui_CreateContext then
    reaper.ShowMessageBox("ReaImGui is required for this script.\nPlease install ReaImGui extension.", "Missing Extension", 0)
    return
end

-- GUI Variables
local ctx = reaper.ImGui_CreateContext('Remove Silence Settings')
local font = reaper.ImGui_CreateFont('sans-serif', 14)
reaper.ImGui_Attach(ctx, font)

-- Default values
local thresh_db = -60.0
local attack_rel = 0.0
local show_gui = true
local apply_settings = false

-- GUI Function
function draw_gui()
    local rv
    
    -- Set window size and position
    reaper.ImGui_SetNextWindowSize(ctx, 280, 220, reaper.ImGui_Cond_FirstUseEver())
    reaper.ImGui_SetNextWindowPos(ctx, 100, 100, reaper.ImGui_Cond_FirstUseEver())
    
    local visible, open = reaper.ImGui_Begin(ctx, 'Remove Silence Settings', true)
    
    if visible then
        -- Title
        reaper.ImGui_PushFont(ctx, font)
        reaper.ImGui_Text(ctx, "Configure silence removal parameters:")
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- Threshold input
        reaper.ImGui_Text(ctx, "Threshold (dB):")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetNextItemWidth(ctx, 120)
        rv, thresh_db = reaper.ImGui_DragDouble(ctx, '##thresh', thresh_db, 0.1, -150.0, 24.0, '%.1f')
        
        -- Help text for threshold
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextDisabled(ctx, "(-150 to 24)")
        
        reaper.ImGui_Spacing(ctx)
        
        -- Attack/Release input
        reaper.ImGui_Text(ctx, "Attack/Release:")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetNextItemWidth(ctx, 120)
        rv, attack_rel = reaper.ImGui_DragDouble(ctx, '##attack', attack_rel, 1.0, 0.0, 1000.0, '%.0f')
        
        -- Help text for attack/release
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextDisabled(ctx, "(0 to 1000)")
        
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- Info text
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
        reaper.ImGui_TextWrapped(ctx, "This will remove silence from selected media items using grid alignment.")
        reaper.ImGui_PopStyleColor(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- Buttons
        local button_width = 90
        local window_width = reaper.ImGui_GetContentRegionAvail(ctx)
        local total_button_width = button_width * 2 + 10 -- 10 for spacing
        local start_pos = (window_width - total_button_width) * 0.5
        
        reaper.ImGui_SetCursorPosX(ctx, start_pos)
        
        -- Apply button
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x4CAF50FF)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x45A049FF)
        if reaper.ImGui_Button(ctx, 'Apply', button_width, 32) then
            apply_settings = true
            show_gui = false
        end
        reaper.ImGui_PopStyleColor(ctx, 2)
        
        reaper.ImGui_SameLine(ctx)
        
        -- Cancel button
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x757575FF)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x616161FF)
        if reaper.ImGui_Button(ctx, 'Cancel', button_width, 32) then
            show_gui = false
        end
        reaper.ImGui_PopStyleColor(ctx, 2)
        
        reaper.ImGui_PopFont(ctx)
        
    end
    
    reaper.ImGui_End(ctx)
    
    -- Check if window was closed
    if not open then
        show_gui = false
    end
    
    if show_gui then
        reaper.defer(draw_gui)
    else
        -- Process after GUI closes
        if apply_settings then
            process_silence_removal()
        end
        -- No need to explicitly destroy context in newer ReaImGui versions
    end
end

--======================================================================================
--////////////// ORIGINAL ARCHIE SCRIPT PROCESSING \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
--======================================================================================

function process_silence_removal()
    -- Validate input values (using math functions to ensure proper conversion)
    local Thresh_dB = tonumber(thresh_db) or -60
    local Attack_Rel = tonumber(attack_rel) or 0
    
    if Thresh_dB < -150 or Thresh_dB > 24 then Thresh_dB = -80 end
    if Attack_Rel < 0 or Attack_Rel > 1000 then Attack_Rel = 0 end
    
    --=========================================
    local function MODULE(file)
        local E,A=pcall(dofile,file)
        if not(E) then
            reaper.ShowMessageBox("Missing required Archie Functions file:\n" .. file, "Error", 0)
            return
        end
        if not A.VersArcFun("2.8.5",file,'') then 
            A=nil
            return
        end
        return A
    end
    
    local Arc = MODULE((reaper.GetResourcePath()..'/Scripts/Archie-ReaScripts/Functions/Arc_Function_lua.lua'):gsub('\\','/'))
    if not Arc then return end
    --=========================================
  
    local CountSelItem = reaper.CountSelectedMediaItems(0)
    if CountSelItem == 0 then 
        reaper.ShowMessageBox("No media items selected!\nPlease select one or more media items.", "Info", 0)
        Arc.no_undo() 
        return 
    end

    local ValInDB = 10^(Thresh_dB/20)
    
    local zeroPeak,item_Sp_Left,item_Sp,leftCheck,rightEdge,rightCheck,Undo

    for i = CountSelItem-1,0,-1 do
        local Selitem = reaper.GetSelectedMediaItem(0,i)
        local Track = reaper.GetMediaItem_Track(Selitem)
        
        local take = reaper.GetActiveTake(Selitem)
        if not take then
            -- Skip items without active takes
            goto continue
        end
        
        local source = reaper.GetMediaItemTake_Source(take)
        if not source then
            -- Skip items without source
            goto continue
        end
        
        local samples_skip = reaper.GetMediaSourceSampleRate(source)/100
        local CountSamples_AllChannels,
              CountSamples_OneChannel,
              NumberSamplesAllChan,
              NumberSamplesOneChan,
              Sample_min,
              Sample_max,
              TimeSample = Arc.GetSampleNumberPosValue(take,samples_skip,true,true,true)

        for i = #TimeSample,1,-1 do
            if Sample_max[i] < ValInDB and i ~= 1 then
                if not PosRight then PosRight = i end
                zeroPeak = (zeroPeak or 0) + 1

            elseif Sample_max[i] >= ValInDB or i == 1 then
                if zeroPeak and zeroPeak >= 5 then
                    if not TimeSample[PosRight-Attack_Rel] then TimeSample[PosRight-Attack_Rel] = 0 end
                    if not TimeSample[i + 1 + Attack_Rel] then TimeSample[i + 1 + Attack_Rel] = 9^9 end

                    if PosRight == #TimeSample then rightCheck = PosRight else rightCheck = PosRight-Attack_Rel end
                    if i == 1 then leftCheck = i else leftCheck = i+1+Attack_Rel end
                    
                    -- Grid alignment
                    if PosRight ~= #TimeSample then  
                        TimeSample[rightCheck] = reaper.BR_GetPrevGridDivision(TimeSample[rightCheck])
                    end
                    if i ~= 1 then  
                        TimeSample[leftCheck] = reaper.BR_GetNextGridDivision(TimeSample[leftCheck])
                    end
                    
                    if TimeSample[rightCheck] > TimeSample[leftCheck] then
                        if i == 1 then
                            item_Sp_Left = Selitem
                        else
                            item_Sp_Left = reaper.SplitMediaItem(Selitem,TimeSample[i+1+Attack_Rel])
                        end

                        if not rightEdge then
                            item_Sp = reaper.SplitMediaItem(item_Sp_Left,TimeSample[PosRight])
                        else
                            item_Sp = reaper.SplitMediaItem(item_Sp_Left,TimeSample[PosRight-Attack_Rel])
                        end
                        
                        Arc.DeleteMediaItem(item_Sp_Left)

                        if not Undo then
                            reaper.Undo_BeginBlock()
                            Undo = "Active"
                        end
                    end
                end
                rightEdge = 1
                PosRight = nil
                zeroPeak = 0
            end
        end
        
        ::continue::
    end

    if Undo then
        reaper.Undo_EndBlock("Remove silence by grid (Thresh: " .. Thresh_dB .. "dB)",-1)
        -- reaper.ShowMessageBox("Silence removal completed successfully!\n\nSettings used:\n• Threshold: " .. Thresh_dB .. " dB\n• Attack/Release: " .. Attack_Rel, "Success", 0)
    else
        Arc.no_undo()
        reaper.ShowMessageBox("No silence found with current settings.\n\nTry adjusting the threshold value.\nCurrent threshold: " .. Thresh_dB .. " dB", "Info", 0)
    end

    reaper.UpdateArrange()
end

-- Start the GUI
draw_gui()
