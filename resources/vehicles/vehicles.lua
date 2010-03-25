--[[
Copyright (c) 2010 MTA: Paradise

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
]]

local addCommandHandler_ = addCommandHandler
      addCommandHandler  = function( commandName, fn, restricted, caseSensitive )
	-- add the default command handlers
	if type( commandName ) ~= "table" then
		commandName = { commandName }
	end
	for key, value in ipairs( commandName ) do
		if key == 1 then
			addCommandHandler_( value, fn, restricted, caseSensitive )
		else
			addCommandHandler_( value,
				function( player, ... )
					-- check if he has permissions to execute the command, default is not restricted (aka if the command is restricted - will default to no permission; otherwise okay)
					if hasObjectPermissionTo( player, "command." .. commandName[ 1 ], not restricted ) then
						fn( player, ... )
					end
				end
			)
		end
	end
	
	-- check for alternative handlers, such as gotovehicle = gotoveh, gotocar
	for k, v in ipairs( commandName ) do
		if v:find( "vehicle" ) then
			for key, value in pairs( { "veh", "car" } ) do
				local newCommand = v:gsub( "vehicle", value )
				if newCommand ~= v then
					-- add a second (replaced) command handler
					addCommandHandler_( newCommand,
						function( player, ... )
							-- check if he has permissions to execute the command, default is not restricted (aka if the command is restricted - will default to no permission; otherwise okay)
							if hasObjectPermissionTo( player, "command." .. commandName[ 1 ], not restricted ) then
								fn( player, ... )
							end
						end
					)
				end
			end
		end
	end
end

local vehicleIDs = { }
local vehicles = { }

addEventHandler( "onResourceStart", resourceRoot,
	function( )
		local result = exports.sql:query_assoc( "SELECT * FROM vehicles ORDER BY vehicleID ASC" )
		if result then
			for key, data in ipairs( result ) do
				local vehicle = createVehicle( data.model, data.posX, data.posY, data.posZ, data.rotX, data.rotY, data.rotZ, numberplate )
				
				-- tables for ID -> vehicle and vehicle -> data
				vehicleIDs[ data.vehicleID ] = vehicle
				vehicles[ vehicle ] = { vehicleID = data.vehicleID, respawnInterior = data.respawnInterior, respawnDimension = data.respawnDimension, characterID = data.characterID }
				
				-- some properties
				setElementHealth( vehicle, data.health )
				setVehicleColor( vehicle, data.color1, data.color2, data.color1, data.color2 ) -- most vehicles don't use second/third color anyway
				setVehicleRespawnPosition( vehicle, data.respawnPosX, data.respawnPosY, data.respawnPosZ, data.respawnRotX, data.respawnRotY, data.respawnRotZ )
				setElementInterior( vehicle, data.interior )
				setElementDimension( vehicle, data.dimension )
			end
		end
	end
)

addCommandHandler( "createvehicle", 
	function( player, commandName, ... )
		model = table.concat( { ... }, " " )
		model = getVehicleModelFromName( model ) or tonumber( model )
		if model then
			local x, y, z, rz = getPositionInFrontOf( player )
			
			local vehicle = createVehicle( model, x, y, z, 0, 0, rz )
			if vehicle then
				local color1, color2 = getVehicleColor( vehicle )
				local vehicleID, error = exports.sql:query_insertid( "INSERT INTO vehicles (model, posX, posY, posZ, rotX, rotY, rotZ, numberplate, color1, color2, respawnPosX, respawnPosY, respawnPosZ, respawnRotX, respawnRotY, respawnRotZ, interior, dimension, respawnInterior, respawnDimension) VALUES (" .. table.concat( { model, x, y, z, 0, 0, rz, '"%s"', color1, color2, x, y, z, 0, 0, rz, getElementInterior( player ), getElementDimension( player ), getElementInterior( player ), getElementDimension( player ) }, ", " ) .. ")", getVehiclePlateText( vehicle ) )
				if vehicleID then
					-- tables for ID -> vehicle and vehicle -> data
					vehicleIDs[ vehicleID ] = vehicle
					vehicles[ vehicle ] = { vehicleID = vehicleID, respawnInterior = getElementInterior( player ), respawnDimension = getElementDimension( player ), characterID = 0 }
					
					-- some properties
					setElementInterior( vehicle, getElementInterior( player ) )
					setElementDimension( vehicle, getElementDimension( player ) )
					
					-- success message
					outputChatBox( "Created " .. getVehicleName( vehicle ) .. " (ID " .. vehicleID .. ")", player, 0, 255, 0 )
				else
					destroyElement( vehicle )
					outputChatBox( "MySQL-Query failed.", player, 255, 0, 0 )
				end
			else
				outputChatBox( "Invalid Vehicle Model.", player, 255, 0, 0 )
			end
		else
			outputChatBox( "Syntax: /" .. commandName .. " [model]", player, 255, 255, 255 )
		end
	end,
	true
)

function create( player, vehicle )
	if isElement( player ) and isElement( vehicle ) then
		local characterID = exports.players:getCharacterID( player )
		if characterID then
			local model = getElementModel( vehicle )
			local x, y, z = getElementPosition( vehicle )
			local rx, ry, rz = getVehicleRotation( vehicle )
			local interior = getElementInterior( vehicle )
			local dimension = getElementDimension( vehicle )
			local color1, color2 = getVehicleColor( vehicle )
			
			local vehicleID, error = exports.sql:query_insertid( "INSERT INTO vehicles (model, posX, posY, posZ, rotX, rotY, rotZ, numberplate, color1, color2, respawnPosX, respawnPosY, respawnPosZ, respawnRotX, respawnRotY, respawnRotZ, interior, dimension, respawnInterior, respawnDimension) VALUES (" .. table.concat( { model, x, y, z, rx, ry, rz, '"%s"', color1, color2, x, y, z, rx, ry, rz, interior, dimension, interior, dimension }, ", " ) .. ")", getVehiclePlateText( vehicle ) )
			if vehicleID then
				local newVehicle = createVehicle( model, x, y, z, rx, ry, rz, getVehiclePlateText( vehicle ) )
				
				-- tables for ID -> vehicle and vehicle -> data
				vehicleIDs[ vehicleID ] = newVehicle
				vehicles[ newVehicle ] = { vehicleID = vehicleID, respawnInterior = interior, respawnDimension = dimension, characterID = characterID }
				
				-- some properties
				setVehicleColor( newVehicle, color1, color2, color1, color2 ) -- most vehicles don't use second/third color anyway
				setVehicleRespawnPosition( newVehicle, x, y, z, rx, ry, rz )
				setElementInterior( newVehicle, interior )
				setElementDimension( newVehicle, dimension )
				
				return newVehicle, vehicleID
			end
		end
	end
end

addCommandHandler( "deletevehicle", 
	function( player, commandName, vehicleID )
		vehicleID = tonumber( vehicleID )
		if vehicleID then
			local vehicle = vehicleIDs[ vehicleID ]
			if vehicle then
				if exports.sql:query_free( "DELETE FROM vehicles WHERE vehicleID = " .. vehicleID ) then
					outputChatBox( "You deleted vehicle " .. vehicleID .. " (" .. getVehicleName( vehicle ) .. ").", player, 0, 255, 153 )
					
					-- remove from vehicles list
					vehicleIDs[ vehicleID ] = nil
					vehicles[ vehicle ] = nil
					
					destroyElement( vehicle )
				else
					outputChatBox( "MySQL-Query failed.", player, 255, 0, 0 )
				end
			else
				outputChatBox( "Vehicle not found.", player, 255, 0, 0 )
			end
		else
			outputChatBox( "Syntax: /" .. commandName .. " [id]", player, 255, 255, 255 )
		end
	end,
	true
)

addCommandHandler( { "repairvehicle", "fixvehicle" },
	function( player, commandName, otherPlayer )
		if otherPlayer then
			target, targetName = exports.players:getFromName( player, otherPlayer )
		else
			target = player
			targetName = getPlayerName( player ):gsub( "_", " " )
		end
		
		if target then
			local vehicle = getPedOccupiedVehicle( target )
			if vehicle then
				fixVehicle( vehicle )
			end
			outputChatBox( "Your vehicle has been repaired by " .. getPlayerName( player ):gsub( "_", " " ) .. ".", target, 0, 255, 153 )
			if player ~= target then
				outputChatBox( "You repaired " .. targetName .. "'s vehicle.", target, 0, 255, 153 )
			end
		end
	end,
	true
)

addCommandHandler( { "repairvehicles", "fixvehicles" },
	function( player, commandName )
		for vehicle in pairs( vehicles ) do
			fixVehicle( vehicle )
		end
		outputChatBox( "*** " .. getPlayerName( player ):gsub( "_", " " ) .. " repaired all vehicles. ***", root, 0, 255, 153 )
	end,
	true
)

addCommandHandler( "respawnvehicle",
	function( player, commandName, vehicleID )
		vehicleID = tonumber( vehicleID )
		if vehicleID then
			local vehicle = vehicleIDs[ vehicleID ]
			if vehicle then
				respawnVehicle( vehicle )
				saveVehicle( vehicle )
				outputChatBox( "You respawned vehicle " .. vehicleID .. " (" .. getVehicleName( vehicle ) .. ").", player, 0, 255, 153 )
			else
				outputChatBox( "Vehicle not found.", player, 255, 0, 0 )
			end
		else
			outputChatBox( "Syntax: /" .. commandName .. " [id]", player, 255, 255, 255 )
		end
	end,
	true
)

addCommandHandler( "respawnvehicles",
	function( player, commandName )
		for vehicle in pairs( vehicles ) do
			if isVehicleEmpty( vehicle ) then
				respawnVehicle( vehicle )
			end
		end
		outputChatBox( "*** " .. getPlayerName( player ):gsub( "_", " " ) .. " respawned all vehicles. ***", root, 0, 255, 153 )
	end,
	true
)

addCommandHandler( "park",
	function( player, commandName )
		local vehicle = getPedOccupiedVehicle( player )
		if vehicle then
			local data = vehicles[ vehicle ]
			if data then
				if exports.players:getCharacterID( player ) == data.characterID or hasObjectPermissionTo( player, "command.createvehicle", false ) then
					local x, y, z = getElementPosition( vehicle )
					local rx, ry, rz = getVehicleRotation( vehicle )
					local success, error = exports.sql:query_free( "UPDATE vehicles SET respawnPosX = " .. x .. ", respawnPosY = " .. y .. ", respawnPosZ = " .. z .. ", respawnRotX = " .. rx .. ", respawnRotY = " .. ry .. ", respawnRotZ = " .. rz .. ", respawnInterior = " .. getElementInterior( vehicle ) .. ", respawnDimension = " .. getElementDimension( vehicle ) .. " WHERE vehicleID = " .. data.vehicleID )			
					if success then
						setVehicleRespawnPosition( vehicle, x, y, z, rx, ry, rz )
						data.respawnInterior = getElementInterior( vehicle )
						data.respawnDimension = getElementDimension( vehicle )
						saveVehicle( vehicle )
						outputChatBox( "Vehicle " .. data.vehicleID .. " (" .. getVehicleName( vehicle ) .. ") has been parked.", player, 0, 255, 0 )
					else
						outputChatBox( "Parking Vehicle failed.", player, 255, 0, 0 )
					end
				else
					outputChatBox( "You cannot park this vehicle.", player, 255, 0, 0 )
				end
			end
		else
			outputChatBox( "You aren't driving a vehicle.", player, 255, 0, 0 )
		end
	end
)

addCommandHandler( "getvehicle",
	function( player, commandName, vehicleID )
		vehicleID = tonumber( vehicleID )
		if vehicleID then
			local vehicle = vehicleIDs[ vehicleID ]
			if vehicle then
				local x, y, z, rz = getPositionInFrontOf( player )
				setElementPosition( vehicle, x, y, z )
				setElementDimension( vehicle, getElementDimension( player ) )
				setElementInterior( vehicle, getElementInterior( player ) )
				setVehicleRotation( vehicle, 0, 0, rz )
				outputChatBox( "You teleported vehicle " .. vehicleID .. " (" .. getVehicleName( vehicle ) .. ") to you.", player, 0, 255, 153 )
				
				-- save the vehicle delayed since it might fall down/position might be adjusted to ground position
				setTimer( saveVehicle, 2000, 1, vehicle )
			else
				outputChatBox( "Vehicle not found.", player, 255, 0, 0 )
			end
		else
			outputChatBox( "Syntax: /" .. commandName .. " [id]", player, 255, 255, 255 )
		end
	end,
	true
)

addCommandHandler( "gotovehicle",
	function( player, commandName, vehicleID )
		vehicleID = tonumber( vehicleID )
		if vehicleID then
			local vehicle = vehicleIDs[ vehicleID ]
			if vehicle then
				setElementPosition( player, getPositionInFrontOf( vehicle, nil, 180 ) )
				setElementDimension( player, getElementDimension( vehicle ) )
				setElementInterior( player, getElementInterior( vehicle ) )
				outputChatBox( "You teleported to vehicle " .. vehicleID .. " (" .. getVehicleName( vehicle ) .. ").", player, 0, 255, 153 )
				
				-- save the vehicle delayed since it might fall down/position might be adjusted to ground position
				setTimer( saveVehicle, 2000, 1, vehicle )
			else
				outputChatBox( "Vehicle not found.", player, 255, 0, 0 )
			end
		else
			outputChatBox( "Syntax: /" .. commandName .. " [id]", player, 255, 255, 255 )
		end
	end,
	true
)

addCommandHandler( { "vehicleid", "thisvehicle" },
	function( player, commandName )
		local vehicle = getPedOccupiedVehicle( player )
		if vehicle then
			local vehicleID = vehicles[ vehicle ] and vehicles[ vehicle ].vehicleID
			if vehicleID then
				outputChatBox( "The ID of this " .. getVehicleName( vehicle ) .. " is " .. vehicleID .. ".", player, 0, 255, 0 )
			else
				outputChatBox( "This " .. getVehicleName( vehicle ) .. " has no ID.", player, 255, 0, 0 )
			end
		else
			outputChatBox( "You are not in any vehicle.", player, 255, 0, 0 )
		end
	end
)

function saveVehicle( vehicle )
	if vehicle then
		local data = vehicles[ vehicle ]
		if data then
			local x, y, z = getElementPosition( vehicle )
			local rx, ry, rz = getVehicleRotation( vehicle )
			local success, error = exports.sql:query_free( "UPDATE vehicles SET posX = " .. x .. ", posY = " .. y .. ", posZ = " .. z .. ", rotX = " .. rx .. ", rotY = " .. ry .. ", rotZ = " .. rz .. ", health = " .. math.min( 1000, math.ceil( getElementHealth( vehicle ) ) ) .. ", interior = " .. getElementInterior( vehicle ) .. ", dimension = " .. getElementDimension( vehicle ) .. " WHERE vehicleID = " .. data.vehicleID )			
			if error then
				outputDebugString( error )
			end
		end
	end
end

addEventHandler( "onVehicleExit", root,
	function( )
		saveVehicle( source )
	end
)

setTimer(
	function( )
		-- save all vehicles
		for vehicle in pairs( vehicles ) do
			saveVehicle( vehicle )
		end
	end,
	60000,
	0
)

addEventHandler( "onResourceStop", resourceRoot,
	function( )
		-- save all occupied vehicles on resource start
		local occupiedVehicles = { }
		for _, value in ipairs( getElementsByType( "player" ) ) do
			local vehicle = getPedOccupiedVehicle( value )
			if vehicle then
				occupiedVehicles[ vehicle ] = true
			end
		end
		
		for vehicle in pairs( occupiedVehicles ) do
			saveVehicle( vehicle )
		end
		
		-- we won't have any vehicles left, but show no message in onElementDestroy
		vehicles = { }
		vehicleIDs = { }
	end
)

addEventHandler( "onVehicleRespawn", resourceRoot,
	function( )
		local data = vehicles[ source ]
		if data then
			setElementInterior( source, data.respawnInterior )
			setElementDimension( source, data.respawnDimension )
			saveVehicle( source )
		end
	end
)

addEventHandler( "onPlayerQuit", root,
	function( )
		local vehicle = getPedOccupiedVehicle( source )
		if vehicle then
			saveVehicle( vehicle )
		end
	end
)

addEventHandler( "onElementDestroy", resourceRoot,
	function( )
		if vehicles[ source ] then
			outputDebugString( "Deleted vehicle ID " .. vehicles[ source ].vehicleID .. " (" .. getVehicleName( source ) .. ", even though it's still referenced. Removing references...", 2 )
			vehicleIDs[ vehicles[ source ].vehicleID ] = nil
			vehicles[ source ] = nil
		end
	end
)

addEventHandler( "onVehicleEnter", resourceRoot,
	function( player )
		local data = vehicles[ source ]
		if data then
			if data.characterID > 0 then
				local name = exports.players:getCharacterName( data.characterID )
				if name then
					outputChatBox( "(( This " .. getVehicleName( source ) .. " belongs to " .. name .. ". ))", player, 255, 204, 0 )
				else
					outputDebugString( "Vehicle " .. data.vehicleID .. " (" .. getVehicleName( source ) .. ") has an invalid owner.", 2 )
				end
			end
		end
	end
)