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
local ChuntMeter = _detalhes:NewPluginObject ("Details_CHUNT")
--> Main Frame
local ChuntMeterFrame = ChuntMeter.Frame

ChuntMeter:SetPluginDescription ("Small tool for track the C.H.U.N.T. score for you and other healers in your raid.")

local ChuntLib = LibStub:GetLibrary("LibChunt")

local _UnitThreatSituation = function (unit, mob)
    return ChuntLib:UnitThreatSituation (unit, mob)
end

local _UnitDetailedThreatSituation = function (unit, mob)
    return ChuntLib:UnitDetailedThreatSituation (unit, mob)
end

--[=
	local CheckStatus = function(...)
		--print (...)
	end

	ChuntLib:RegisterCallback("Activate", CheckStatus)
    ChuntLib:RegisterCallback("Deactivate", CheckStatus)
    ChuntLib:RegisterCallback("ThreatUpdated", CheckStatus)
    ChuntLib:RequestActiveOnSolo (true)
--]=]

local _

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
	ChuntMeter.Actived = false
	
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
			ChuntMeter.Actived = false
			ChuntMeter:Cancel()
		
		elseif (event == "SHOW") then
		
			instance = ChuntMeter:GetInstance (ChuntMeter.instance_id)
			
			ChuntMeter.RowWidth = instance.baseframe:GetWidth()-6
			
			ChuntMeter:UpdateContainers()
			ChuntMeter:UpdateRows()
			
			ChuntMeter:SizeChanged()
			
			player = GetUnitName ("player", true)
			
			ChuntMeter.Actived = false

			if (ChuntMeter:IsInCombat() or UnitAffectingCombat ("player")) then
				if (not ChuntMeter.initialized) then
					return
				end
				ChuntMeter.Actived = true
				ChuntMeter:Start()
			end
		
		elseif (event == "COMBAT_PLAYER_ENTER") then
			if (not ChuntMeter.Actived) then
				ChuntMeter.Actived = true
				ChuntMeter:Start()
			end
		
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

	local Threater = function()

		local options = ChuntMeter.options
	
		if (ChuntMeter.Actived and UnitExists ("target") and not _UnitIsFriend ("player", "target")) then

			ChuntMeter.UpdateWindowTitle (UnitName ("target"))

			if (_IsInRaid()) then
				for i = 1, _GetNumGroupMembers(), 1 do
				
					local thisplayer_name = GetUnitName ("raid"..i, true)
					local threat_table_index = ChuntMeter.player_list_hash [thisplayer_name]
					local threat_table = ChuntMeter.player_list_indexes [threat_table_index]
				
					if (not threat_table) then
						--> some one joined the group while the player are in combat
						ChuntMeter:Start()
						return
					end
				
					local isTanking, status, threatpct, rawthreatpct, threatvalue = _UnitDetailedThreatSituation ("raid"..i, "target")

					isTanking = isTanking or false
					threatpct = threatpct or 0
					rawthreatpct = rawthreatpct or 0

					if (status) then
						threat_table [2] = threatpct
						threat_table [3] = isTanking
						threat_table [6] = threatvalue
					else
						threat_table [2] = 0
						threat_table [3] = false
						threat_table [6] = 0
					end

				end
			elseif (_IsInGroup()) then
				for i = 1, _GetNumGroupMembers()-1, 1 do
					local thisplayer_name = GetUnitName ("party"..i, true)
					local threat_table_index = ChuntMeter.player_list_hash [thisplayer_name]
					local threat_table = ChuntMeter.player_list_indexes [threat_table_index]
				
					if (not threat_table) then
						--> some one joined the group while the player are in combat
						ChuntMeter:Start()
						return
					end
				
					local isTanking, status, threatpct, rawthreatpct, threatvalue = ChuntLib:UnitDetailedThreatSituation ("party"..i, "target")
					--returns nil, 0, nil, nil, 0
					--	print (isTanking, status, threatpct, rawthreatpct, threatvalue)

					local nameOrder = ChuntMeter:GetNameOrder (thisplayer_name or "zzzzzzz")

					isTanking = isTanking or false
					threatpct = threatpct or 0
					rawthreatpct = rawthreatpct or (0 + nameOrder)

					if (status) then
						threat_table [2] = threatpct + nameOrder
						threat_table [3] = isTanking
						threat_table [6] = threatvalue + nameOrder
					else
						threat_table [2] = 0 + nameOrder
						threat_table [3] = false
						threat_table [6] = 0 + nameOrder
					end
				end
				
				local thisplayer_name = GetUnitName ("player", true)
				local threat_table_index = ChuntMeter.player_list_hash [thisplayer_name]
				local threat_table = ChuntMeter.player_list_indexes [threat_table_index]
				local nameOrder = ChuntMeter:GetNameOrder (thisplayer_name or "zzzzzzz")

				local isTanking, status, threatpct, rawthreatpct, threatvalue = _UnitDetailedThreatSituation ("player", "target")

				isTanking = isTanking or false
				threatpct = threatpct or 0
				rawthreatpct = rawthreatpct or (0 + nameOrder)

				if (status) then
					threat_table [2] = threatpct + nameOrder
					threat_table [3] = isTanking
					threat_table [6] = threatvalue + nameOrder
				else
					threat_table [2] = 0 + nameOrder
					threat_table [3] = false
					threat_table [6] = 0 + nameOrder
				end

				--player pet
				--> pet
				if (UnitExists ("pet") and not IsInInstance() and false) then --disabled
					local thisplayer_name = GetUnitName ("pet", true) .. " *PET*"
					local threat_table_index = ChuntMeter.player_list_hash [thisplayer_name]
					local threat_table = ChuntMeter.player_list_indexes [threat_table_index]

					if (threat_table) then

						local isTanking, status, threatpct, rawthreatpct, threatvalue = _UnitDetailedThreatSituation ("pet", "target")

						--threatpct, rawthreatpct are nil on single player, dunno with pets
						threatpct = threatpct or 0
						rawthreatpct = rawthreatpct or 0

						if (status) then
							threat_table [2] = threatpct
							threat_table [3] = isTanking
							threat_table [6] = threatvalue
						else
							threat_table [2] = 0
							threat_table [3] = false
							threat_table [6] = 0
						end
					end
				end
			else
			
				--> player
				local thisplayer_name = GetUnitName ("player", true)
				local threat_table_index = ChuntMeter.player_list_hash [thisplayer_name]
				local threat_table = ChuntMeter.player_list_indexes [threat_table_index]
				local isTanking, status, threatpct, rawthreatpct, threatvalue = _UnitDetailedThreatSituation ("player", "target")

				local nameOrder = ChuntMeter:GetNameOrder (thisplayer_name or "zzzzzzz")
				--local player_heal = Details:GetActor (segmentID = _G.DETAILS_SEGMENTID_CURRENT, attributeID = _G.DETAILS_ATTRIBUTE_HEAL, thisplayer_name)
				
				--threatpct, rawthreatpct are nil on single player
				threatpct = threatpct or 0
				rawthreatpct = rawthreatpct or (0 + nameOrder)

				if (status) then
					threat_table [2] = threatpct
					threat_table [3] = isTanking
					threat_table [6] = threatvalue + nameOrder
				else
					threat_table [2] = 0
					threat_table [3] = false
					threat_table [6] = 0 or nameOrder
				end
				
				if (_DEBUG) then
					for i = 1, 10 do

					end
				end

				--> pet
				if (UnitExists ("pet")) then
					local thisplayer_name = GetUnitName ("pet", true) .. " *PET*"
					local threat_table_index = ChuntMeter.player_list_hash [thisplayer_name]
					local threat_table = ChuntMeter.player_list_indexes [threat_table_index]

					if (threat_table) then

						local isTanking, status, threatpct, rawthreatpct, threatvalue = _UnitDetailedThreatSituation ("pet", "target")

						--threatpct, rawthreatpct are nil on single player, dunno with pets
						threatpct = threatpct or 0
						rawthreatpct = rawthreatpct or 0

						if (status) then
							threat_table [2] = threatpct
							threat_table [3] = isTanking
							threat_table [6] = threatvalue
						else
							threat_table [2] = 0
							threat_table [3] = false
							threat_table [6] = 0
						end
					end
				end
			end
			
			--> sort
			_table_sort (ChuntMeter.player_list_indexes, sort)
			for index, t in _ipairs (ChuntMeter.player_list_indexes) do
				ChuntMeter.player_list_hash [t[1]] = index
			end
			
			--> no threat on this enemy
			if (ChuntMeter.player_list_indexes [1] [2] < 1) then
				ChuntMeter:HideBars()
				return
			end
			
			local lastIndex = 0
			local shownMe = false
			
			local pullRow = ChuntMeter.ShownRows [1]
			local me = ChuntMeter.player_list_indexes [ ChuntMeter.player_list_hash [player] ]
			if (me) then
			
				local myThreat = me [6] or 0
				local myRole = me [4]
				
				local topThreat = ChuntMeter.player_list_indexes [1]
				local aggro = topThreat [6] * (CheckInteractDistance ("target", 3) and 1.1 or 1.3)
				local combat = Details:GetCurrentCombat()
				local combat_time = combat:GetCombatTime()
				local player = combat:GetActor (_G.DETAILS_ATTRIBUTE_HEAL, "Chunt")

				local totalHeal = player.total
				local totalOverHeal = player.totalover
				local _player_targets = ""
				--for k, v in ipairs(player.spells) do
				--	_player_targets = _player_targets .. "hi" -- .. k .. ":" .. v .. "; "
				--end
				--message(combat_time)
				pullRow:SetLeftText ("hi iggy")
				local realPercent = _math_floor (aggro / max (topThreat [6], 0.01) * 100)
				pullRow:SetRightText ("Total: " .. totalHeal .. " Overheal: " .. totalOverHeal) --
				--pullRow.SetRightText(_player_targets)
				pullRow:SetValue (100)
				
				local myPercentToAggro = myThreat / aggro * 100
				
				local r, g = ChuntMeter:percent_color (myPercentToAggro)
				--local r, g = myPercentToAggro / 100, (100-myPercentToAggro) / 100
				pullRow:SetColor (r, g, 0)
				pullRow._icon:SetTexture ([[Interface\PVPFrame\Icon-Combat]])
				--pullRow._icon:SetVertexColor (r, g, 0)
				pullRow._icon:SetTexCoord (0, 1, 0, 1)
				
				pullRow:Show()
			else
				if (pullRow) then
					pullRow:Hide()
				end
			end
			
			for index = 2, #ChuntMeter.ShownRows do
				local thisRow = ChuntMeter.ShownRows [index]
				local threat_actor = ChuntMeter.player_list_indexes [index-1]
				
				if (threat_actor) then
					local role = threat_actor [4]
					thisRow._icon:SetTexCoord (_unpack (RoleIconCoord [role]))
					
					local targetHealth = UnitHealth("player")
					local targetHealthMax = UnitHealthMax("player")
					thisRow:SetLeftText (ChuntMeter:GetOnlyName (threat_actor [1]))
					
					local oldPct = thisRow:GetValue() or 0
					local pct = threat_actor [2]
					
					thisRow:SetRightText ("Chunt: " .. targetHealth .. "/" .. targetHealthMax)

					--do healthbar animation ~animation ~healthbar
						thisRow.CurrentPercentMax = 100
						thisRow.AnimationStart = oldPct
						thisRow.AnimationEnd = pct

						thisRow:SetValue (oldPct)
						
						thisRow.IsAnimating = true
						
						if (thisRow.AnimationEnd > thisRow.AnimationStart) then
							thisRow.AnimateFunc = ChuntMeter.AnimateRightWithAccel
						else
							thisRow.AnimateFunc = ChuntMeter.AnimateLeftWithAccel
						end

					--if no animations
					--thisRow:SetValue (pct)
					
					if (options.useplayercolor and threat_actor [1] == player) then
						thisRow:SetColor (_unpack (options.playercolor))
						
					elseif (options.useclasscolors) then
						local color = RAID_CLASS_COLORS [threat_actor [5]]
						if (color) then
							thisRow:SetColor (color.r, color.g, color.b)
						else
							thisRow:SetColor (1, 1, 1, 1)
						end
					else
						if (index == 2) then
							thisRow:SetColor (pct*0.01, _math_abs (pct-100)*0.01, 0, 1)
						else
							local r, g = ChuntMeter:percent_color (pct, true)
							thisRow:SetColor (r, g, 0, 1)
						end
					end
					
					if (not thisRow.statusbar:IsShown()) then
						thisRow:Show()
					end
					if (threat_actor [1] == player) then
						shownMe = true
					end
				else
					thisRow:Hide()
				end
			end
			
			if (not shownMe) then
				--> show my self into last bar
				local threat_actor = ChuntMeter.player_list_indexes [ ChuntMeter.player_list_hash [player] ]
				if (threat_actor) then
					if (threat_actor [2] and threat_actor [2] > 0.1) then
						local thisRow = ChuntMeter.ShownRows [#ChuntMeter.ShownRows]
						thisRow:SetLeftText (player)
						--thisRow.textleft:SetTextColor (unpack (RAID_CLASS_COLORS [threat_actor [5]]))
						local role = threat_actor [4]
						thisRow._icon:SetTexCoord (_unpack (RoleIconCoord [role]))
						thisRow:SetRightText (ChuntMeter:ToK2 (threat_actor [6]) .. " (" .. _cstr ("%.1f", threat_actor [2]) .. "%)")
						thisRow:SetValue (threat_actor [2])
						
						if (options.useplayercolor) then
							thisRow:SetColor (_unpack (options.playercolor))
						else
							local r, g = ChuntMeter:percent_color (threat_actor [2], true)
							thisRow:SetColor (r, g, 0, .3)
						end
					end
				end
			end
		
		else
			--print ("nao tem target")
		end
		
	end
	
	function ChuntMeter:TargetChanged()
		if (not ChuntMeter.Actived) then
			return
		end
		local NewTarget = _UnitName ("target")
		if (NewTarget and not _UnitIsFriend ("player", "target")) then
			target = NewTarget
			ChuntMeter.UpdateWindowTitle (NewTarget)
			Threater()
		else
			ChuntMeter.UpdateWindowTitle (false)
			ChuntMeter:HideBars()
		end
	end
	
	function ChuntMeter:Tick()
		Threater()
	end

	function ChuntMeter:Start()
		ChuntMeter:HideBars()
		if (ChuntMeter.Actived) then
			if (ChuntMeter.job_thread) then
				ChuntMeter:CancelTimer (ChuntMeter.job_thread)
				ChuntMeter.job_thread = nil
			end
			
			ChuntMeter.player_list_indexes = {}
			ChuntMeter.player_list_hash = {}
			
			--> pre build player list
			if (_IsInRaid()) then
				for i = 1, _GetNumGroupMembers(), 1 do
					local thisplayer_name = GetUnitName ("raid"..i, true)
					local role = _UnitGroupRolesAssigned ("raid"..i)
					local _, class = UnitClass (thisplayer_name)
					local t = {thisplayer_name, 0, false, role, class, 0}
					ChuntMeter.player_list_indexes [#ChuntMeter.player_list_indexes+1] = t
					ChuntMeter.player_list_hash [thisplayer_name] = #ChuntMeter.player_list_indexes
				end

				

			elseif (_IsInGroup()) then
				for i = 1, _GetNumGroupMembers()-1, 1 do
					local thisplayer_name = GetUnitName ("party"..i, true)
					local role = _UnitGroupRolesAssigned ("party"..i)
					local _, class = UnitClass (thisplayer_name)
					local t = {thisplayer_name, 0, false, role, class, 0}
					ChuntMeter.player_list_indexes [#ChuntMeter.player_list_indexes+1] = t
					ChuntMeter.player_list_hash [thisplayer_name] = #ChuntMeter.player_list_indexes
				end
				local thisplayer_name = GetUnitName ("player", true)
				local role = _UnitGroupRolesAssigned ("player")
				local _, class = UnitClass (thisplayer_name)
				local t = {thisplayer_name, 0, false, role, class, 0}
				ChuntMeter.player_list_indexes [#ChuntMeter.player_list_indexes+1] = t
				ChuntMeter.player_list_hash [thisplayer_name] = #ChuntMeter.player_list_indexes

				if (UnitExists ("pet") and not IsInInstance() and false) then --disabled
					local thispet_name = GetUnitName ("pet", true) .. " *PET*"
					local role = "DAMAGER"
					local t = {thispet_name, 0, false, role, class, 0}
					ChuntMeter.player_list_indexes [#ChuntMeter.player_list_indexes+1] = t
					ChuntMeter.player_list_hash [thispet_name] = #ChuntMeter.player_list_indexes
				end
				
			else
				local thisplayer_name = GetUnitName ("player", true)
				local role = _UnitGroupRolesAssigned ("player")
				local _, class = UnitClass (thisplayer_name)
				local t = {thisplayer_name, 0, false, role, class, 0}
				ChuntMeter.player_list_indexes [#ChuntMeter.player_list_indexes+1] = t
				ChuntMeter.player_list_hash [thisplayer_name] = #ChuntMeter.player_list_indexes
				
				if (UnitExists ("pet")) then
					local thispet_name = GetUnitName ("pet", true) .. " *PET*"
					local role = "DAMAGER"
					local t = {thispet_name, 0, false, role, class, 0}
					ChuntMeter.player_list_indexes [#ChuntMeter.player_list_indexes+1] = t
					ChuntMeter.player_list_hash [thispet_name] = #ChuntMeter.player_list_indexes
				end
			end
			
			local job_thread = ChuntMeter:ScheduleRepeatingTimer ("Tick", ChuntMeter.options.updatespeed)
			ChuntMeter.job_thread = job_thread
		end
	end
	
	function ChuntMeter:End()
		ChuntMeter:HideBars()
		if (ChuntMeter.job_thread) then
			ChuntMeter:CancelTimer (ChuntMeter.job_thread)
			ChuntMeter.job_thread = nil
			ChuntMeter.UpdateWindowTitle (false)
		end
	end
	
	function ChuntMeter:Cancel()
		ChuntMeter:HideBars()
		if (ChuntMeter.job_thread) then
			ChuntMeter:CancelTimer (ChuntMeter.job_thread)
			ChuntMeter.job_thread = nil
		end
		ChuntMeter.Actived = false
	end
	
end

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

	if (event == "PLAYER_TARGET_CHANGED") then
		ChuntMeter:TargetChanged()
	
	elseif (event == "PLAYER_REGEN_DISABLED") then
		ChuntMeter.Actived = true
		ChuntMeter:Start()
		
	elseif (event == "PLAYER_REGEN_ENABLED") then
		ChuntMeter:End()
		ChuntMeter.Actived = false
	
	elseif (event == "ADDON_LOADED") then
		local AddonName = select (1, ...)
		if (AddonName == "Details_CHUNT") then
			
			if (_G._detalhes) then

				--> create widgets
				CreatePluginFrames (data)

				local MINIMAL_DETAILS_VERSION_REQUIRED = 1
				
				--> Install
				local install, saveddata = _G._detalhes:InstallPlugin ("SOLO", Loc ["STRING_PLUGIN_NAME"], "Interface\\CHATFRAME\\UI-ChatIcon-D3", ChuntMeter, "DETAILS_PLUGIN_CHUNT", MINIMAL_DETAILS_VERSION_REQUIRED, "Chunt", "v1.0.0")
				if (type (install) == "table" and install.error) then
					print (install.error)
				end
				
				--> Register needed events
				_G._detalhes:RegisterEvent (ChuntMeter, "COMBAT_PLAYER_ENTER")
				_G._detalhes:RegisterEvent (ChuntMeter, "COMBAT_PLAYER_LEAVE")
				_G._detalhes:RegisterEvent (ChuntMeter, "DETAILS_INSTANCE_ENDRESIZE")
				_G._detalhes:RegisterEvent (ChuntMeter, "DETAILS_INSTANCE_SIZECHANGED")
				_G._detalhes:RegisterEvent (ChuntMeter, "DETAILS_INSTANCE_STARTSTRETCH")
				_G._detalhes:RegisterEvent (ChuntMeter, "DETAILS_INSTANCE_ENDSTRETCH")
				_G._detalhes:RegisterEvent (ChuntMeter, "DETAILS_OPTIONS_MODIFIED")
				
				ChuntMeterFrame:RegisterEvent ("PLAYER_TARGET_CHANGED")
				ChuntMeterFrame:RegisterEvent ("PLAYER_REGEN_DISABLED")
				ChuntMeterFrame:RegisterEvent ("PLAYER_REGEN_ENABLED")

				--> Saved data
				ChuntMeter.saveddata = saveddata or {}
				
				ChuntMeter.saveddata.updatespeed = ChuntMeter.saveddata.updatespeed or 0.25
				ChuntMeter.saveddata.animate = ChuntMeter.saveddata.animate or false
				ChuntMeter.saveddata.showamount = ChuntMeter.saveddata.showamount or false
				ChuntMeter.saveddata.useplayercolor = ChuntMeter.saveddata.useplayercolor or false
				ChuntMeter.saveddata.playercolor = ChuntMeter.saveddata.playercolor or {1, 1, 1}
				ChuntMeter.saveddata.useclasscolors = ChuntMeter.saveddata.useclasscolors or false

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
