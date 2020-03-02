local AceLocale = LibStub ("AceLocale-3.0")
local Loc = AceLocale:GetLocale ("Details_CHUNT")

local _GetNumSubgroupMembers = GetNumSubgroupMembers --> wow api
local _GetNumGroupMembers = GetNumGroupMembers --> wow api
local _UnitIsFriend = UnitIsFriend --> wow api
local _UnitName = UnitName --> wow api
--local _UnitDetailedThreatSituation = UnitDetailedThreatSituation
local _IsInRaid = IsInRaid --> wow api
local _IsInGroup = IsInGroup --> wow api
--local _UnitGroupRolesAssigned = DetailsFramework.UnitGroupRolesAssigned --> wow api
local GetUnitName = GetUnitName

local ANIMATION_TIME_DILATATION = 1.005321

local _UnitGroupRolesAssigned = function (unitId) 
	if (type (unitId) == "string") then
		local guid = UnitGUID (unitId)
		if (guid) then
			local playerSpec = Details.cached_specs [guid]
			if (playerSpec) then
				
				local role = Details:GetRoleFromSpec (playerSpec, guid) or "NONE"
				--print ("tt:24", "playerSpec", playerSpec, "role", role)
				return role
			end
		end
		return "NONE"
	end
end

local _DEBUG = true


local _ipairs = ipairs --> lua api
local _table_sort = table.sort --> lua api
local _cstr = string.format --> lua api
local _unpack = unpack
local _math_floor = math.floor
local _math_abs = math.abs
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

--> Create the plugin Object
ChuntMeter = _detalhes:NewPluginObject ("Details_CHUNT")
--> Main Frame
local ChuntMeterFrame = ChuntMeter.Frame

ChuntMeter:SetPluginDescription ("Small tool for track the C.H.U.N.T. score for you and other healers in your raid.")

local _

function table.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
  end

local function CreatePluginFrames (data)
	
	--> catch Details! main object
	local _detalhes = _G._detalhes
	local DetailsFrameWork = _detalhes.gump

	--> data
	ChuntMeter.data = data or {}
	
	--> defaults
	ChuntMeter.RowWidth = 294
	ChuntMeter.RowHeight = 14
	--> amount of row wich can be displayed
	ChuntMeter.CanShow = 0
	--> all rows already created
	ChuntMeter.Rows = {}
	--> current shown rows
	ChuntMeter.ShownRows = {}
	-->
	
	--> localize functions
	ChuntMeter.percent_color = ChuntMeter.percent_color
	
	ChuntMeter.GetOnlyName = ChuntMeter.GetOnlyName
	
	--> window reference
	local instance
	local player
	
	--> OnEvent Table
	function ChuntMeter:OnDetailsEvent (event, ...)
	
		if (event == "DETAILS_STARTED") then
			ChuntMeter:RefreshRows()
			
		elseif (event == "HIDE") then --> plugin hidded, disabled
			ChuntMeter:Cancel()
		
		elseif (event == "SHOW") then
		
			instance = ChuntMeter:GetInstance (ChuntMeter.instance_id)
			
			ChuntMeter.RowWidth = instance.baseframe:GetWidth()-6
			
			ChuntMeter:UpdateContainers()
			ChuntMeter:UpdateRows()
			
			ChuntMeter:SizeChanged()
			
			player = GetUnitName ("player", true)
			

			if (ChuntMeter:IsInCombat() or UnitAffectingCombat ("player")) then
				if (not ChuntMeter.initialized) then
					return
				end
				ChuntMeter.UpdateWindowTitle ("start from details event - show")
				ChuntMeter:Start()
			end
		
		elseif (event == "COMBAT_PLAYER_ENTER") then
			ChuntMeter.UpdateWindowTitle ("start from details event - combat player enter")
			ChuntMeter:Start()
		
		elseif (event == "DETAILS_INSTANCE_ENDRESIZE" or event == "DETAILS_INSTANCE_SIZECHANGED") then
		
			local what_window = select (1, ...)
			if (what_window == instance) then
				ChuntMeter:SizeChanged()
				ChuntMeter:RefreshRows()
			end
			
		elseif (event == "DETAILS_OPTIONS_MODIFIED") then
			local what_window = select (1, ...)
			if (what_window == instance) then
				ChuntMeter:RefreshRows()
			end
		
		elseif (event == "DETAILS_INSTANCE_STARTSTRETCH") then
			ChuntMeterFrame:SetFrameStrata ("TOOLTIP")
			ChuntMeterFrame:SetFrameLevel (instance.baseframe:GetFrameLevel()+1)
		
		elseif (event == "DETAILS_INSTANCE_ENDSTRETCH") then
			ChuntMeterFrame:SetFrameStrata ("MEDIUM")
			
		elseif (event == "PLUGIN_DISABLED") then
			ChuntMeterFrame:UnregisterEvent ("PLAYER_TARGET_CHANGED")
			ChuntMeterFrame:UnregisterEvent ("PLAYER_REGEN_DISABLED")
			ChuntMeterFrame:UnregisterEvent ("PLAYER_REGEN_ENABLED")
				
		elseif (event == "PLUGIN_ENABLED") then
			ChuntMeterFrame:RegisterEvent ("PLAYER_TARGET_CHANGED")
			ChuntMeterFrame:RegisterEvent ("PLAYER_REGEN_DISABLED")
			ChuntMeterFrame:RegisterEvent ("PLAYER_REGEN_ENABLED")
		elseif (event == "DETAILS_DATA_RESET") or (event == "DETAILS_DATA_SEGMENTREMOVED") then
			ChuntMeter:Cancel()
		end
	end
	
	ChuntMeterFrame:SetWidth (300)
	ChuntMeterFrame:SetHeight (100)
	
	function ChuntMeter:UpdateContainers()
		for _, row in _ipairs (ChuntMeter.Rows) do 
			row:SetContainer (instance.baseframe)
		end
	end
	
	function ChuntMeter:UpdateRows()
		for _, row in _ipairs (ChuntMeter.Rows) do
			row.width = ChuntMeter.RowWidth
		end
	end
	
	function ChuntMeter:HideBars()
		for _, row in _ipairs (ChuntMeter.Rows) do 
			row:Hide()
		end
	end

	function ChuntMeter:CalculateGrumphScore()
		return 1500
	end


	function ChuntMeter:CalculateChuntScore(player_heals, healer_table)

		local incremental_modified_heal = 0
		local target_overheal = 0
		local target_heal = 0
		for target, total_heal in pairs(player_heals.targets) do
			--ChuntMeter.UpdateWindowTitle (target .. heal)
			
			if player_heals.targets_overheal[target] ~= nil then
				if healer_table [7][target] ~= nil then
					target_overheal = (player_heals.targets_overheal[target] - healer_table [7][target])
				else
					target_overheal = player_heals.targets_overheal[target]
				end
			else
				target_overheal = 0
			end
			if healer_table [6][target] ~= nil then
				target_heal = (total_heal - healer_table [6][target]) - target_overheal
				--incremental_heal = incremental_heal + (actual_heal - healer_table [6][target])
				--ChuntMeter.UpdateWindowTitle ("not nil" .. incremental_heal)
				--local targetHealth = UnitHealth(target)
				--local targetHealthMax = UnitHealthMax(target)
			else
				target_heal = total_heal - target_overheal

				--incremental_heal = incremental_heal + actual_heal
				--ChuntMeter.UpdateWindowTitle ("nil" .. incremental_heal)
			end
					
			--incremental_heal = incremental_heal + target_heal
			--incremental_overheal = incremental_overheal + target_overheal
			--ChuntMeter.UpdateWindowTitle('incremental heal: ' .. incremental_heal .. ' = ' .. targetHealthMax)
			
			local target_health = UnitHealth(healer_table [8])
			local target_health_max = UnitHealthMax(healer_table [8])
			if target_health_max == 0 then
				target_health_max = 3000
			end
			local start_ratio = (target_health - target_heal)/target_health_max
			local end_ratio = target_health / target_health_max
			local overheal_ratio = (target_health_max + target_overheal)/target_health_max
			local positive_heals = 100*(end_ratio - start_ratio)
			local negative_heals = 100*(overheal_ratio - 1)
			ChuntMeter.UpdateWindowTitle('pos_heal: ' .. positive_heals .. ' neg_heal: ' .. negative_heals)
			
			incremental_modified_heal = incremental_modified_heal + positive_heals - negative_heals
			
		end
		
		healer_table [2] = healer_table [2] + incremental_modified_heal
		
	end

	function ChuntMeter:UpdateHeals(player_name)
		local healer_table_index = ChuntMeter.player_list_hash [player_name]
		local healer_table = ChuntMeter.player_list_indexes [healer_table_index]
		if (not healer_table) then
			--> some one joined the group while the player are in combat
			ChuntMeter.UpdateWindowTitle ("start updateheals no threat table")
			ChuntMeter:Start()
			return
		end
		local combat = Details:GetCurrentCombat()
		player_heals = combat:GetActor (_G.DETAILS_ATTRIBUTE_HEAL, player_name)

		if (player_heals) then
			ChuntMeter:CalculateChuntScore(player_heals, healer_table)
			healer_table [3] = true
			-- Store prev targets and prev targets_overheal
			healer_table [6] = table.deepcopy(player_heals.targets)
			healer_table [7] = table.deepcopy(player_heals.targets_overheal)
		end

	end

	function ChuntMeter:GetNameOrder (playerName)
		local name = string.upper (playerName .. "zz")
		local byte1 = math.abs (string.byte (name, 2)-91)/1000000
		return byte1 + math.abs (string.byte (name, 1)-91)/10000
	end
	
	local target = nil
	local timer = 0
	local interval = 1.0
	
	local RoleIconCoord = {
		["TANK"] = {0, 0.28125, 0.328125, 0.625},
		["HEALER"] = {0.3125, 0.59375, 0, 0.296875},
		["DAMAGER"] = {0.3125, 0.59375, 0.328125, 0.625},
		["NONE"] = {0.3125, 0.59375, 0.328125, 0.625}
	}

	function ChuntMeter.UpdateWindowTitle (newTitle)
		local windowInstance = ChuntMeter:GetPluginInstance()
		if (windowInstance and windowInstance.menu_attribute_string) then
			if (not newTitle) then
				windowInstance.menu_attribute_string.text = "C.H.U.N.T."

			else
				--windowInstance.menu_attribute_string.text = newTitle
				windowInstance.menu_attribute_string:SetTextTruncated (newTitle, windowInstance.baseframe:GetWidth() - 60)
			end
		end
	end
	
	--> animation with acceleration ~animation ~healthbaranimation
	function ChuntMeter.AnimateLeftWithAccel (self, deltaTime)
		local distance = (self.AnimationStart - self.AnimationEnd) / self.CurrentPercentMax * 100	--scale 1 - 100
		local minTravel = min (distance / 10, 3) -- 10 = trigger distance to max speed 3 = speed scale on max travel
		local maxTravel = max (minTravel, 0.45) -- 0.45 = min scale speed on low travel speed
		local calcAnimationSpeed = (self.CurrentPercentMax * (deltaTime * ANIMATION_TIME_DILATATION)) * maxTravel --re-scale back to unit health, scale with delta time and scale with the travel speed
		
		self.AnimationStart = self.AnimationStart - (calcAnimationSpeed)
		self:SetValue (self.AnimationStart)
		self.CurrentPercent = self.AnimationStart
		
		if (self.Spark) then
			self.Spark:SetPoint ("center", self, "left", self.AnimationStart / self.CurrentPercentMax * self:GetWidth(), 0)
			self.Spark:Show()
		end
		
		if (self.AnimationStart-1 <= self.AnimationEnd) then
			self:SetValue (self.AnimationEnd)
			self.CurrentPercent = self.AnimationEnd
			self.IsAnimating = false
			if (self.Spark) then
				self.Spark:Hide()
			end
		end
	end

	function ChuntMeter.AnimateRightWithAccel (self, deltaTime)
		local distance = (self.AnimationEnd - self.AnimationStart) / self.CurrentPercentMax * 100	--scale 1 - 100 basis
		local minTravel = math.min (distance / 10, 3) -- 10 = trigger distance to max speed 3 = speed scale on max travel
		local maxTravel = math.max (minTravel, 0.45) -- 0.45 = min scale speed on low travel speed
		local calcAnimationSpeed = (self.CurrentPercentMax * (deltaTime * ANIMATION_TIME_DILATATION)) * maxTravel --re-scale back to unit health, scale with delta time and scale with the travel speed
		
		self.AnimationStart = self.AnimationStart + (calcAnimationSpeed)
		self:SetValue (self.AnimationStart)
		self.CurrentPercent = self.AnimationStart
		
		if (self.AnimationStart+1 >= self.AnimationEnd) then
			self:SetValue (self.AnimationEnd)
			self.CurrentPercent = self.AnimationEnd
			self.IsAnimating = false
		end
	end

	function ChuntMeter:SizeChanged()

		local instance = ChuntMeter:GetPluginInstance()
	
		local w, h = instance.baseframe:GetSize()
		ChuntMeterFrame:SetWidth (w)
		ChuntMeterFrame:SetHeight (h)
		
		local rowHeight = instance and instance.row_info.height or 20

		ChuntMeter.CanShow = math.floor ( h / (rowHeight + 1))
		for i = #ChuntMeter.Rows+1, ChuntMeter.CanShow do
			ChuntMeter:NewRow (i)
		end

		ChuntMeter.ShownRows = {}
		
		for i = 1, ChuntMeter.CanShow do
			ChuntMeter.ShownRows [#ChuntMeter.ShownRows + 1] = ChuntMeter.Rows[i]
			if (_detalhes.in_combat) then
				ChuntMeter.Rows[i]:Show()
			end
			ChuntMeter.Rows[i].width = w - 5
		end
		
		for i = #ChuntMeter.ShownRows + 1, #ChuntMeter.Rows do
			ChuntMeter.Rows [i]:Hide()
		end
		
	end
	
	local SharedMedia = LibStub:GetLibrary ("LibSharedMedia-3.0")

	function ChuntMeter:RefreshRow (row)
	
		local instance = ChuntMeter:GetPluginInstance()
		
		if (instance) then
			local font = SharedMedia:Fetch ("font", instance.row_info.font_face, true) or instance.row_info.font_face
			
			row.textsize = instance.row_info.font_size
			row.textfont = font
			row.texture = instance.row_info.texture
			row.shadow = instance.row_info.textL_outline
			
			local rowHeight = instance and instance.row_info.height or 20
			rowHeight = - ( (row.rowId - 1) * (rowHeight + 1) )

			row:ClearAllPoints()
			row:SetPoint ("topleft", ChuntMeterFrame, "topleft", 1, rowHeight)
			row:SetPoint ("topright", ChuntMeterFrame, "topright", -1, rowHeight)

			--row.width = instance.baseframe:GetWidth()-5
		end
	end
	
	function ChuntMeter:RefreshRows()
		for i = 1, #ChuntMeter.Rows do
			ChuntMeter:RefreshRow (ChuntMeter.Rows [i])
		end
	end

	local onUpdateRow = function (self, deltaTime)
		self = self.MyObject
		if (self.IsAnimating and self.AnimateFunc) then
			self.AnimateFunc (self, deltaTime)
		end
	end
	
	function ChuntMeter:NewRow (i)

		local instance = ChuntMeter:GetPluginInstance()
		local rowHeight = instance and instance.row_info.height or 20

		local newrow = DetailsFrameWork:NewBar (ChuntMeterFrame, nil, "DetailsThreatRow"..i, nil, 300, rowHeight)
		newrow:SetPoint (3, -((i-1)*(rowHeight+1)))
		newrow.lefttext = "bar " .. i
		newrow.color = "skyblue"
		newrow.fontsize = 9.9
		newrow.fontface = "GameFontHighlightSmall"
		newrow:SetIcon ("Interface\\LFGFRAME\\UI-LFG-ICON-PORTRAITROLES", RoleIconCoord ["DAMAGER"])
		newrow.rowId = i

		newrow.widget:SetScript ("OnUpdate", onUpdateRow)

		ChuntMeter.Rows [#ChuntMeter.Rows+1] = newrow
		
		ChuntMeter:RefreshRow (newrow)
		
		newrow:Hide()
		
		return newrow
	end
	
	local sort = function (table1, table2)
		if (table1[2] > table2[2]) then
			return true
		else
			return false
		end
	end

	local GetHealTick = function()

		local options = ChuntMeter.options

		if (_IsInRaid()) then
			ChuntMeter.UpdateWindowTitle ("in raid")
			for i = 1, _GetNumGroupMembers(), 1 do
				local raid_player_name = GetUnitName ("raid"..i, true)
				ChuntMeter:UpdateHeals(raid_player_name)
			end
		elseif (_IsInGroup()) then
			for i = 1, _GetNumGroupMembers(), 1 do
				local group_player_name = GetUnitName ("party"..i, true)
				ChuntMeter:UpdateHeals(group_player_name)
			end
		else
			local this_player_name = GetUnitName ("player", true)
			ChuntMeter:UpdateHeals(this_player_name)
		end
		
		--> sort
		_table_sort (ChuntMeter.player_list_indexes, sort)
		for index, t in _ipairs (ChuntMeter.player_list_indexes) do
			ChuntMeter.player_list_hash [t[1]] = index
		end
		
		local lastIndex = 0
		
		local pullRow = ChuntMeter.ShownRows [1]
		local me = ChuntMeter.player_list_indexes [ ChuntMeter.player_list_hash [player] ]
		if (me) then
			
			
			--local aggro = topThreat [6] * (CheckInteractDistance ("target", 3) and 1.1 or 1.3)
			--local combat = Details:GetCurrentCombat()
			--local combat_time = combat:GetCombatTime()
			--local thisplayer = combat:GetActor (_G.DETAILS_ATTRIBUTE_HEAL, "Chunt")

			--local totalHeal = thisplayer.total
			--local totalOverHeal = thisplayer.totalover
			--local _player_targets = ""
			--for k, v in ipairs(player.spells) do
			--	_player_targets = _player_targets .. "hi" -- .. k .. ":" .. v .. "; "
			--end
			--message(combat_time)
			pullRow:SetLeftText ("G.R.U.M.P.H. score")
			--local realPercent = _math_floor (aggro / max (topThreat [6], 0.01) * 100)
			pullRow:SetRightText ("Total: " .. "???") --
			--pullRow.SetRightText(_player_targets)
			pullRow:SetValue (100)
			
			--local myPercentToAggro = myThreat / aggro * 100
			
			--local r, g = ChuntMeter:percent_color (myPercentToAggro)
			--local r, g = myPercentToAggro / 100, (100-myPercentToAggro) / 100
			--pullRow:SetColor (r, g, 0)
			pullRow._icon:SetTexture ([[Interface\PVPFrame\Icon-Combat]])
			--pullRow._icon:SetVertexColor (r, g, 0)
			pullRow._icon:SetTexCoord (0, 1, 0, 1)
			
			pullRow:Show()
		else
			--ChuntMeter.UpdateWindowTitle ("if not me")
			if (pullRow) then
				pullRow:Hide()
			end
		end
		
		--ChuntMeter.UpdateWindowTitle ("show rows")
		local top_chunt = ChuntMeter.player_list_indexes [1]
		for index = 2, #ChuntMeter.ShownRows do
			local thisRow = ChuntMeter.ShownRows [index]
			local healer_table = ChuntMeter.player_list_indexes [index-1]
			
			if (healer_table) then
				if healer_table [3] then
					local role = healer_table [4]
					thisRow._icon:SetTexCoord (_unpack (RoleIconCoord [role]))
					
					thisRow:SetLeftText (ChuntMeter:GetOnlyName (healer_table [1]))
					
					thisRow.CurrentPercentMax = _math_abs (top_chunt [2])
					local old_chunt_score = thisRow:GetValue() or 0
					local new_chunt_score = _math_abs (healer_table [2] / top_chunt[2])
					
					thisRow:SetRightText ("C.H.U.N.T.: " .. _math_floor (healer_table [2]))

					--do healthbar animation ~animation ~healthbar
					thisRow.AnimationStart = old_chunt_score
					thisRow.AnimationEnd = new_chunt_score*100

					thisRow:SetValue (new_chunt_score*100)
					if healer_table [2] > 0 then
						thisRow:SetColor (0, 0.5 * new_chunt_score + 0.5, 0)
					else
						thisRow:SetColor (0.5 * new_chunt_score + 0.5, 0, 0)
					end
					
					thisRow.IsAnimating = true
					
					if (thisRow.AnimationEnd > thisRow.AnimationStart) then
						thisRow.AnimateFunc = ChuntMeter.AnimateRightWithAccel
					else
						thisRow.AnimateFunc = ChuntMeter.AnimateLeftWithAccel
					end

					--if no animations
					--thisRow:SetValue (pct)
					
					--if (options.useplayercolor and healer_table [1] == player) then
					--	thisRow:SetColor (_unpack (options.playercolor))
					--	
					--elseif (options.useclasscolors) then
					--	local color = RAID_CLASS_COLORS [healer_table [5]]
					--	if (color) then
					--		thisRow:SetColor (color.r, color.g, color.b)
					--	else
					--		thisRow:SetColor (1, 1, 1, 1)
					--	end
					--else
					--	if (index == 2) then
					--		thisRow:SetColor (pct*0.01, _math_abs (pct-100)*0.01, 0, 1)
					--	else
					--		local r, g = ChuntMeter:percent_color (pct, true)
					--		thisRow:SetColor (r, g, 0, 1)
					--	end
					--end
					
					if (not thisRow.statusbar:IsShown()) then
						thisRow:Show()
					end
				else
					thisRow:Hide()
				end
			else
				thisRow:Hide()
			end
		end
		
		--ChuntMeter.UpdateWindowTitle ("GetHealTick done")
		
	end
	i = 0
	function ChuntMeter:Tick()
		ChuntMeter.UpdateWindowTitle('tick ' .. _G.i)
		_G.i = _G.i + 1
		GetHealTick()
	end

	function ChuntMeter:Start()
		if ChuntMeter.started then

			local job_thread = ChuntMeter:ScheduleRepeatingTimer ("Tick", 1)--ChuntMeter.options.updatespeed)
			ChuntMeter.job_thread = job_thread
		else
			if (ChuntMeter.job_thread) then
				ChuntMeter.UpdateWindowTitle('canceltimer start')
				ChuntMeter:CancelTimer (ChuntMeter.job_thread)
				ChuntMeter.job_thread = nil
			end
			ChuntMeter:HideBars()
			ChuntMeter.player_list_indexes = {}
			ChuntMeter.player_list_hash = {}
			
			--> pre build player list
			if (_IsInRaid()) then
				for i = 1, _GetNumGroupMembers(), 1 do
					local player_id = "raid"..i
					local thisplayer_name = GetUnitName (player_id, true)
					local role = _UnitGroupRolesAssigned (player_id)
					local _, class = UnitClass (thisplayer_name)
					local t = {thisplayer_name, 0, false, role, class, {}, {}, player_id}
					ChuntMeter.player_list_indexes [#ChuntMeter.player_list_indexes+1] = t
					ChuntMeter.player_list_hash [thisplayer_name] = #ChuntMeter.player_list_indexes
				end

				

			elseif (_IsInGroup()) then
				for i = 1, _GetNumGroupMembers()-1, 1 do
					local player_id = "party"..i
					local thisplayer_name = GetUnitName (player_id, true)
					local role = _UnitGroupRolesAssigned (player_id)
					local _, class = UnitClass (thisplayer_name)
					local t = {thisplayer_name, 0, false, role, class, {}, {}, player_id}
					ChuntMeter.player_list_indexes [#ChuntMeter.player_list_indexes+1] = t
					ChuntMeter.player_list_hash [thisplayer_name] = #ChuntMeter.player_list_indexes
				end

				local thisplayer_name = GetUnitName ("player", true)
				local role = _UnitGroupRolesAssigned ("player")
				local _, class = UnitClass (thisplayer_name)
				local t = {thisplayer_name, 0, false, role, class, {}, {}, "player"}
				ChuntMeter.player_list_indexes [#ChuntMeter.player_list_indexes+1] = t
				ChuntMeter.player_list_hash [thisplayer_name] = #ChuntMeter.player_list_indexes

				
			else
				local thisplayer_name = GetUnitName ("player", true)
				local role = _UnitGroupRolesAssigned ("player")
				local _, class = UnitClass (thisplayer_name)
				local t = {thisplayer_name, 0, false, role, class, {}, {}, "player"}
				ChuntMeter.player_list_indexes [#ChuntMeter.player_list_indexes+1] = t
				ChuntMeter.player_list_hash [thisplayer_name] = #ChuntMeter.player_list_indexes
				
			end
			
			ChuntMeter.UpdateWindowTitle('timer scheduled start')
			local job_thread = ChuntMeter:ScheduleRepeatingTimer ("Tick", 1)--ChuntMeter.options.updatespeed)
			ChuntMeter.job_thread = job_thread
			ChuntMeter.started = true
		end
	end

	
	function ChuntMeter:End()
		--ChuntMeter:HideBars()

		if (ChuntMeter.job_thread) then
			ChuntMeter.UpdateWindowTitle('canceltimer end')
			ChuntMeter:CancelTimer (ChuntMeter.job_thread)
			ChuntMeter.job_thread = nil
			ChuntMeter.UpdateWindowTitle ("ended")
		end
	end
	
	function ChuntMeter:Cancel()
		ChuntMeter:HideBars()
		ChuntMeter.started = false
		if (ChuntMeter.job_thread) then
			ChuntMeter.UpdateWindowTitle('canceltimer cancel')
			ChuntMeter:CancelTimer (ChuntMeter.job_thread)
			ChuntMeter.job_thread = nil
		end
	end
	
end


-- ##############################################################
-- ##############################################################
-- ##############################################################
-- ##############################################################
--                STOP
-- ##############################################################
-- ##############################################################
-- ##############################################################
-- ##############################################################






local build_options_panel = function()

	local options_frame = ChuntMeter:CreatePluginOptionsFrame ("ChuntMeterOptionsWindow", "C.H.U.N.T. Options", 1)

	local menu = {
		{
			type = "range",
			get = function() return ChuntMeter.saveddata.updatespeed end,
			set = function (self, fixedparam, value) ChuntMeter.saveddata.updatespeed = value end,
			min = 0.2,
			max = 3,
			step = 0.2,
			desc = "How fast the window get updates.",
			name = "Update Speed",
			usedecimals = true,
		},
		{
			type = "toggle",
			get = function() return ChuntMeter.saveddata.useplayercolor end,
			set = function (self, fixedparam, value) ChuntMeter.saveddata.useplayercolor = value end,
			desc = "When enabled, your bar get the following color.",
			name = "Player Color Enabled"
		},
		{
			type = "color",
			get = function() return ChuntMeter.saveddata.playercolor end,
			set = function (self, r, g, b, a) 
				local current = ChuntMeter.saveddata.playercolor
				current[1], current[2], current[3], current[4] = r, g, b, a
			end,
			desc = "If Player Color is enabled, your bar have this color.",
			name = "Color"
		},
		{
			type = "toggle",
			get = function() return ChuntMeter.saveddata.useclasscolors end,
			set = function (self, fixedparam, value) ChuntMeter.saveddata.useclasscolors = value end,
			desc = "When enabled, threat bars uses the class color of the character.",
			name = "Use Class Colors"
		},
	}
	
	_detalhes.gump:BuildMenu (options_frame, menu, 15, -65, 260)

end

ChuntMeter.OpenOptionsPanel = function()
	if (not ChuntMeterOptionsWindow) then
		build_options_panel()
	end
	ChuntMeterOptionsWindow:Show()
end

function ChuntMeter:OnEvent (_, event, ...)

	--if (event == "PLAYER_TARGET_CHANGED") then
	--	ChuntMeter:TargetChanged()
	
	--else
	if (event == "PLAYER_REGEN_DISABLED") then
		ChuntMeter.UpdateWindowTitle ("start - chuntmeter event regen disable")
		ChuntMeter:Start()
		
	elseif (event == "PLAYER_REGEN_ENABLED") then
		ChuntMeter:End()
	
	elseif (event == "ADDON_LOADED") then
		local AddonName = select (1, ...)
		if (AddonName == "Details_CHUNT") then
			
			if (_G._detalhes) then

				--> create widgets
				CreatePluginFrames (data)

				local MINIMAL_DETAILS_VERSION_REQUIRED = 1
				
				--> Install
				local install, saveddata = _G._detalhes:InstallPlugin ("RAID", Loc ["STRING_PLUGIN_NAME"], "Interface\\CHATFRAME\\UI-ChatIcon-D3", ChuntMeter, "DETAILS_PLUGIN_CHUNT", MINIMAL_DETAILS_VERSION_REQUIRED, "Chunt", "v1.0.0")
				if (type (install) == "table" and install.error) then
					print (install.error)
				end
				
				--> Register needed events
				--_G._detalhes:RegisterEvent (ChuntMeter, "COMBAT_PLAYER_ENTER")
				--_G._detalhes:RegisterEvent (ChuntMeter, "COMBAT_PLAYER_LEAVE")
				_G._detalhes:RegisterEvent (ChuntMeter, "DETAILS_INSTANCE_ENDRESIZE")
				_G._detalhes:RegisterEvent (ChuntMeter, "DETAILS_INSTANCE_SIZECHANGED")
				_G._detalhes:RegisterEvent (ChuntMeter, "DETAILS_INSTANCE_STARTSTRETCH")
				_G._detalhes:RegisterEvent (ChuntMeter, "DETAILS_INSTANCE_ENDSTRETCH")
				_G._detalhes:RegisterEvent (ChuntMeter, "DETAILS_OPTIONS_MODIFIED")
				
				--ChuntMeterFrame:RegisterEvent ("PLAYER_TARGET_CHANGED")
				ChuntMeterFrame:RegisterEvent ("PLAYER_REGEN_DISABLED")
				ChuntMeterFrame:RegisterEvent ("PLAYER_REGEN_ENABLED")

				--> Saved data
				ChuntMeter.saveddata = saveddata or {}
				
				ChuntMeter.saveddata.updatespeed = ChuntMeter.saveddata.updatespeed or 0.25
				ChuntMeter.saveddata.animate = ChuntMeter.saveddata.animate or true
				ChuntMeter.saveddata.showamount = ChuntMeter.saveddata.showamount or true
				ChuntMeter.saveddata.useplayercolor = ChuntMeter.saveddata.useplayercolor or true
				ChuntMeter.saveddata.playercolor = ChuntMeter.saveddata.playercolor or {1, 1, 1}
				ChuntMeter.saveddata.useclasscolors = ChuntMeter.saveddata.useclasscolors or true

				ChuntMeter.options = ChuntMeter.saveddata

				ChuntMeter.saveddata.updatespeed = 0.20
				--ChuntMeter.saveddata.animate = true
				
				--> Register slash commands
				SLASH_DETAILS_CHUNT1, SLASH_DETAILS_CHUNT2 = "/chuntttttt", "/chunt"
				
				function SlashCmdList.DETAILS_CHUNT (msg, editbox)
				
					local command, rest = msg:match("^(%S*)%s*(.-)$")
					
					if (command == Loc ["STRING_SLASH_ANIMATE"]) then
					
					elseif (command == Loc ["STRING_SLASH_SPEED"]) then
					
						if (rest) then
							local speed = tonumber (rest)
							if (speed) then
								if (speed > 3) then
									speed = 3
								elseif (speed < 0.3) then
									speed = 0.3
								end
								
								ChuntMeter.saveddata.updatespeed = speed
								ChuntMeter:Msg (Loc ["STRING_SLASH_SPEED_CHANGED"] .. speed)
							else
								ChuntMeter:Msg (Loc ["STRING_SLASH_SPEED_CURRENT"] .. ChuntMeter.saveddata.updatespeed)
							end
						end

					elseif (command == Loc ["STRING_SLASH_AMOUNT"]) then
					
					else
						ChuntMeter:Msg (Loc ["STRING_COMMAND_LIST"])
						print ("|cffffaeae/chunt " .. Loc ["STRING_SLASH_SPEED"] .. "|r: " .. Loc ["STRING_SLASH_SPEED_DESC"])
					
					end
				end
				ChuntMeter.initialized = true
			end
		end

	end
end
