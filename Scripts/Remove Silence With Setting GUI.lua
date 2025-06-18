--[[
   * Category:    Item
   * Description: Remove silence by grid in selected media items
   * Author:      Archie (GUI Input Added by Hosi)
   * Version:     1.07 - Silent Version
   * AboutScript: Original Archie algorithm with GUI input, no console messages
   * Changelog:   +  Disabled all console output v.1.07
--]]

    --======================================================================================
    --////////////  GUI INPUT ONLY - NO CONSOLE OUTPUT  \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    --======================================================================================

    -- Simple GUI for Thresh_dB and Attack_Rel input
    local retval, user_input = reaper.GetUserInputs(
        "Remove Silence Settings", 
        2, 
        "Threshold (dB):,Attack/Release:",
        "-60,0"
    )
    
    if not retval then 
        return -- User cancelled
    end
    
    -- Parse input
    local values = {}
    for value in user_input:gmatch("([^,]+)") do
        table.insert(values, tonumber(value:match("^%s*(.-)%s*$")))
    end
    
    -- Set variables exactly as in original script
    local Thresh_dB = values[1] or -60;
    local Attack_Rel = values[2] or 0;
    
    -- Original validation from Archie's script
    if not tonumber(Thresh_dB ) or Thresh_dB  < -150 or Thresh_dB  > 24   then Thresh_dB  = -80 end;
    if not tonumber(Attack_Rel) or Attack_Rel <  0   or Attack_Rel > 1000 then Attack_Rel =   0 end;

    -- Console output disabled
    -- reaper.ShowConsoleMsg("Settings: Threshold=" .. Thresh_dB .. "dB, Attack=" .. Attack_Rel .. "\n")

    --======================================================================================
    --////////////// ORIGINAL ARCHIE SCRIPT - NO CONSOLE OUTPUT \\\\\\\\\\\\\\\\\\\\\\\\\\\\
    --======================================================================================

    --=========================================
    local function MODULE(file);
        local E,A=pcall(dofile,file);if not(E)then;
            -- Console output disabled
            -- reaper.ShowConsoleMsg("\n\nError - "..debug.getinfo(1,'S').source:match('.*[/\\](.+)')..'\nMISSING FILE / ОТСУТСТВУЕТ ФАЙЛ!\n'..file:gsub('\\','/'))
            return;
        end;
        if not A.VersArcFun("2.8.5",file,'')then;A=nil;return;end;return A;
    end; local Arc = MODULE((reaper.GetResourcePath()..'/Scripts/Archie-ReaScripts/Functions/Arc_Function_lua.lua'):gsub('\\','/'));
    if not Arc then return end;
    --=========================================
  
    local CountSelItem = reaper.CountSelectedMediaItems(0);
    if CountSelItem == 0 then Arc.no_undo() return end;
    ---------------------------------------------------

    local ValInDB = 10^(Thresh_dB/20);
    ----------------------------------

    local zeroPeak,item_Sp_Left,item_Sp,leftCheck,rightEdge,rightCheck,Undo;

    for i = CountSelItem-1,0,-1 do;
        local Selitem = reaper.GetSelectedMediaItem(0,i); 
        local Track = reaper.GetMediaItem_Track(Selitem);
        -------------------------------------------
        local take = reaper.GetActiveTake(Selitem);
        local source = reaper.GetMediaItemTake_Source(take);
        local samples_skip = reaper.GetMediaSourceSampleRate(source)/100;-- обработается 100 сэмплов в секунду
        local CountSamples_AllChannels,
              CountSamples_OneChannel,
              NumberSamplesAllChan,
              NumberSamplesOneChan,
              Sample_min,
              Sample_max,
              TimeSample = Arc.GetSampleNumberPosValue(take,samples_skip,true,true,true);
              ---------------------------------------------------------------------------

        for i = #TimeSample,1,-1 do;

            if Sample_max[i] < ValInDB and i ~= 1 then;

                if not PosRight then PosRight = i end;
                zeroPeak = (zeroPeak or 0) + 1;

            elseif Sample_max[i] >= ValInDB or i == 1 then;

                if zeroPeak and zeroPeak >= 5 then;

                    if not TimeSample[PosRight-Attack_Rel] then TimeSample[PosRight-Attack_Rel] = 0   end;
                    if not TimeSample[i + 1 + Attack_Rel ] then TimeSample[i + 1 + Attack_Rel ] = 9^9 end;

                    if PosRight == #TimeSample then rightCheck = PosRight else rightCheck = PosRight-Attack_Rel end;
                    if i == 1 then leftCheck = i else leftCheck = i+1+Attack_Rel end;
                    -- grid -------------------
                    ---------------------------
                    if PosRight ~= #TimeSample then;  
                        TimeSample[rightCheck] = reaper.BR_GetPrevGridDivision(TimeSample[rightCheck]);
                    end;
                    if i ~= 1 then;  
                        TimeSample[leftCheck] = reaper.BR_GetNextGridDivision(TimeSample[leftCheck]);
                    end;
                    ---------------------------
                    ---------------------------
                    if TimeSample[rightCheck] > TimeSample[leftCheck] then;

                        if i == 1 then;
                            item_Sp_Left = Selitem;
                        else;
                            item_Sp_Left = reaper.SplitMediaItem(Selitem,TimeSample[i+1+Attack_Rel]);
                        end;
                        ----

                        if not rightEdge then;
                            item_Sp = reaper.SplitMediaItem(item_Sp_Left,TimeSample[PosRight]);
                        else;
                            item_Sp = reaper.SplitMediaItem(item_Sp_Left,TimeSample[PosRight-Attack_Rel]);
                        end;
                        ----
                        ----------------------------------
                        Arc.DeleteMediaItem(item_Sp_Left);

                        if not Undo then;
                            reaper.Undo_BeginBlock();
                            Undo = "Active";
                        end;
                        --------------------
                    end;
                end;
                rightEdge = 1;
                PosRight = nil;
                zeroPeak = 0;
            end;
        end;
    end;

    if Undo then;
        reaper.Undo_EndBlock("Remove silence by grid (Thresh: " .. Thresh_dB .. "dB)",-1);
        -- Console output disabled
        -- reaper.ShowConsoleMsg("Silence removal completed! Threshold: " .. Thresh_dB .. "dB\n")
    else;
        Arc.no_undo();
        -- Console output disabled
        -- reaper.ShowConsoleMsg("No silence found with threshold: " .. Thresh_dB .. "dB\n")
    end;

    reaper.UpdateArrange();
