-- Variable Setup
-- Command Line input Table
local argTable = {...}

-- Flag Variables: These are conditions for different features (all flags are named foo_bar, all other variables are named fooBar)
local cmd_line = false
local cmd_line_resume = false
local cmd_line_cost_only = false
local chain_next_shape = false -- This tells goHome() where to end, if true it goes to (0, 0, positionZ) if false it goes to (-1, -1, 0)
local special_chain = false -- For certain shapes that finish where the next chained shape should start, goHome() will  only turn to face 0 if true
local cost_only = false
local sim_mode = false
local resupply = false
local enderchest_refilling = false
local can_use_gps = false
local return_to_home = false -- whether the turtle shall return to start after build

-- Record Keeping Variables: These are for recoding the blocks and fuel used
local blocks = 0
local fuel = 0

-- Position Tracking Variables: These are for keeping track of the turtle's position
local positionX = 0
local positionY = 0
local positionZ = 0
local facing = 0
local gpsPositionX = 0
local gpsPositionY = 0
local gpsPositionZ = 0
local gpsFacing = 0

-- General Variables: Other variables that don't fit in the other categories
local choice = ""

-- Progress Table: These variables are the tables that the turtle's progress is tracked in
local tempProgTable = {}
local progTable = {} --This is the LOCAL table!  used for local stuff only, and is ONLY EVER WRITTEN when sim_mode is FALSE
local progFileName = "ShapesProgressFile"

-- Utility functions

function writeOut(...) -- ... lets writeOut() pass any arguments to print(). so writeOut(1,2,3) is the same as print(1,2,3). previously writeOut(1,2,3) would have been the same as print(1)
	for i, v in ipairs(arg) do
		print(v)
	end
end

function getInput(inputType, message, option1, option2)
	local input = ""
	if inputType == "string" then
		writeOut(message.. "(" ..option1 .. " or "..option2..")" )
		while true do
			input = io.read()
			input = string.lower(input)
			if input ~= option1 and input ~= option2 then
				writeOut("You didn't enter a valid option. Please try again.")
			else
				return input
			end
		end
	end
	if inputType == "int" then
		writeOut(message)
		while true do
			input = io.read()
			if tonumber(input) ~= nil then
				return tonumber(input)
			else
				writeOut("Need a number. Please try again")
			end
		end
	end	
end

function wrapModules() -- checks for and wraps turtle modules
	local test = 0
	if peripheral.getType("left" )== "resupply" then 
		resupplymodule=peripheral.wrap("left")
		resupply = true
	elseif peripheral.getType("right") == "resupply" then
		resupplymodule=peripheral.wrap("right")
		resupply = true
	end
	if peripheral.getType("left") == "modem" then
		modem=peripheral.wrap("left")
		test, _, _ = gps.locate(1)
		if test ~= nil then
			can_use_gps = true
		end
	elseif peripheral.getType("right") == "modem" then
		modem=peripheral.wrap("right")
		test, _, _ = gps.locate(1)
		if test ~= nil then
			can_use_gps = true
		end
	end
	if resupply then
		return "resupply"
	end
end

function linkToRSStation() -- Links to resupply station
	if resupplymodule.link() then
		return true
	else
		writeOut("Please put Resupply Station to the left of the turtle and press Enter to continue")
		io.read()
		linkToRSStation()
	end
end

function compareResources()
	if (turtle.compareTo(1) == false) then
		turtle.drop()
	end
end

function firstFullSlot()
	for i = 1, 16 do
		if (turtle.getItemCount(i) > 1) then
			return i
		end
	end
end

function turtleEmpty()
	for i = 1, 16 do
		if (turtle.getItemCount(i) > 1) then
			return false
		end
	end
	return true
end

function checkResources()
	if resupply then
		if turtle.getItemCount(activeSlot) <= 1 then
			while not(resupplymodule.resupply(1)) do
				os.sleep(0.5)
			end
		end
	elseif enderchest_refilling then
		compareResources()
		while (turtle.getItemCount(activeSlot) <= 1) do
			if (activeSlot == 15) and (turtle.getItemCount(activeSlot)<=1) then
				turtle.select(16)
				turtle.digUp()
				for i = 1, 15 do
					turtle.select(i)
					turtle.drop()
				end
				turtle.select(16)
				turtle.placeUp()
				turtle.select(1)				
				for i = 1, 15 do
					turtle.suckUp()
				end
				turtle.select(16)
				turtle.digUp()
				activeSlot = 1
				turtle.select(activeSlot)
			else
				activeSlot = activeSlot + 1
				-- writeOut("Turtle slot empty, trying slot "..activeSlot)
				turtle.select(activeSlot)
			end
			compareResources()
			os.sleep(0.2)
		end
	else
		compareResources()
		while (turtle.getItemCount(activeSlot) <= 1) do 
			if turtleEmpty() then
				writeOut("Turtle is empty, please put building block in slots and press enter to continue")
				io.read()
				activeSlot = 1
				turtle.select(activeSlot)
			else
				activeSlot = firstFullSlot()
				turtle.select(activeSlot)
			end
			compareResources()
		end
	end
end

function checkFuel()
	if (not(tonumber(turtle.getFuelLevel()) == nil)) then
		while turtle.getFuelLevel() < 50 do
			writeOut("Turtle almost out of fuel, pausing. Please drop fuel in inventory. And press enter.")
			io.read()
			turtle.refuel()
		end
	end
end

function placeBlock()
	blocks = blocks + 1
	simulationCheck()
	if cost_only then
		return
	end
	if turtle.detectDown() and not turtle.compareDown() then
		turtle.digDown()
	end
	checkResources()
	turtle.placeDown()
	progressUpdate()
end

function round(toRound, decimalPlace) -- Needed for Polygons
	local mult = 10 ^ (decimalPlace or 0)
	local sign = toRound / math.abs(toRound)
	return sign * math.floor(((math.abs(toRound) * mult) + 0.5)) / mult
end

-- Navigation functions
-- Allow the turtle to move while tracking its position
-- This allows us to just give a destination point and have it go there

function turnRightTrack()
	simulationCheck()
	facing = facing + 1
	if facing >= 4 then
		facing = 0
	end
	progressUpdate()
	if cost_only then
		return
	end
	turtle.turnRight()
end

function turnLeftTrack()
	simulationCheck()
	facing = facing - 1
	if facing < 0 then
		facing = 3
	end
	progressUpdate()
	if cost_only then
		return
	end
	turtle.turnLeft()
end

function turnAroundTrack()
	turnLeftTrack()
	turnLeftTrack()
end

function turnToFace(direction)
	if (direction < 0) then
		return false
	end
	direction = direction % 4
	while facing ~= direction do
		turnRightTrack()
	end
	return true
end

function safeForward()
	simulationCheck()
	if facing == 0 then
		positionY = positionY + 1
	elseif facing == 1 then
		positionX = positionX + 1
	elseif facing == 2 then
		positionY = positionY - 1
	elseif facing == 3 then
		positionX = positionX - 1
	end
	fuel = fuel + 1
	progressUpdate()
	if cost_only then
		return
	end
	checkFuel()
	local success = false
	local tries = 0
	while not success do
		success = turtle.forward()
		if not success then
			while (not success) and tries < 6 do
				tries = tries + 1
				turtle.dig() 
				success = turtle.forward()
				sleep(0.3)
			end
			if not success then
				writeOut("Blocked attempting to move forward.")
				writeOut("Please clear and press enter to continue.")
				io.read()
			end
		end
	end
end

function safeBack()
	simulationCheck()
	if facing == 0 then
		positionY = positionY - 1
	elseif facing == 1 then
		positionX = positionX - 1
	elseif facing == 2 then
		positionY = positionY + 1
	elseif facing == 3 then
		positionX = positionX + 1
	end
	fuel = fuel + 1
	progressUpdate()
	if cost_only then
		return
	end
	checkFuel()
	local success = false
	local tries = 0
	while not success do
		success = turtle.back()
		if not success then
			turnAroundTrack()
			while turtle.detect() and tries < 6 do
				tries = tries + 1
				if turtle.dig() then
					break
				end
				sleep(0.3)
			end
			turnAroundTrack()
			success = turtle.back()
			if not success then
				writeOut("Blocked attempting to move back.")
				writeOut("Please clear and press enter to continue.")
				io.read()
			end
		end
	end
end

function safeUp()
	simulationCheck()
	positionZ = positionZ + 1
	fuel = fuel + 1	
	progressUpdate()
	if cost_only then
		return
	end
	checkFuel()
	local success = false
	while not success do
		success = turtle.up()
		if not success then
			while turtle.detectUp() do
				if not turtle.digUp() then
					writeOut("Blocked attempting to move up.")
					writeOut("Please clear and press enter to continue.")
					io.read()
				end
			end
		end
	end
end

function safeDown()
	simulationCheck()
	positionZ = positionZ - 1
	fuel = fuel + 1
	progressUpdate()
	if cost_only then
		return
	end
	checkFuel()
	local success = false
	while not success do
		success = turtle.down()
		if not success then
			while turtle.detectDown() do
				if not turtle.digDown() then
					writeOut("Blocked attempting to move down.")
					writeOut("Please clear and press enter to continue.")
					io.read()
				end
			end
		end
	end
end

function moveY(targetY)
	if targetY == positionY then
		return
	end
	if (facing ~= 0 and facing ~= 2) then -- Check axis
		turnRightTrack()
	end
	while targetY > positionY do
		if facing == 0 then
			safeForward()
		else
			safeBack()
		end
	end
	while targetY < positionY do
		if facing == 2 then
			safeForward()
		else
			safeBack()
		end
	end
end

function moveX(targetX)
	if targetX == positionX then
		return
	end
	if (facing ~= 1 and facing ~= 3) then -- Check axis
		turnRightTrack()
	end
	while targetX > positionX do
		if facing == 1 then
			safeForward()
		else
			safeBack()
		end
	end
	while targetX < positionX do
		if facing == 3 then
			safeForward()
		else
			safeBack()
		end
	end
end

function moveZ(targetZ)
	if targetZ == positionZ then
		return
	end
	while targetZ < positionZ do
		safeDown()
	end
	while targetZ > positionZ do
		safeUp()
	end
end

-- I *HIGHLY* suggest formatting all shape subroutines to use the format that dome() uses;  specifically, navigateTo(x,y,[z]) then placeBlock().  This should ensure proper "data recording" and also makes readability better
function navigateTo(targetX, targetY, targetZ, move_z_first)
	targetZ = targetZ or positionZ -- If targetZ isn't used in the function call, it defaults to its current z position, this should make it compatible with all previous implementations of navigateTo()
	move_z_first = move_z_first or false -- Defaults to moving z last, if true is passed as 4th argument, it moves vertically first
	
	if move_z_first then
		moveZ(targetZ)
	end
	
	if facing == 0 or facing == 2 then -- Y axis
		moveY(targetY)
		moveX(targetX)
	else
		moveX(targetX)
		moveY(targetY)
	end
	
	if not move_z_first then
		moveZ(targetZ)
	end
end

function goHome()
	if chain_next_shape then
		if not special_chain then
			navigateTo(0, 0) -- So another program can chain multiple shapes together to create bigger structures
		end
	else
		navigateTo(-1, -1, 0) -- So the user can collect the turtle when it is done, not 0,0,0 because some shapes use the 0,0 column
	end
	turnToFace(0)
end

-- Shape Building functions

function drawLine(endX, endY, startX, startY)
	startX = startX or positionX
	startY = startY or positionY
	deltaX = math.abs(endX - startX)
	deltaY = math.abs(endY - startY)
	errorVar = 0
	if deltaX >= deltaY then
		deltaErr = math.abs(deltaY/deltaX)
		if startX < endX then
			if startY < endY then
				counterY = startY
				for counterX = startX, endX do
					navigateTo(counterX, counterY)
					placeBlock()
					errorVar = errorVar + deltaErr
					if errorVar >= 0.5 then
						counterY = counterY + 1
						errorVar = errorVar - 1
					end
				end
			else
				counterY = startY
				for counterX = startX, endX do
					navigateTo(counterX, counterY)
					placeBlock()
					errorVar = errorVar + deltaErr
					if errorVar >= 0.5 then
						counterY = counterY - 1
						errorVar = errorVar - 1
					end
				end
			end
		else
			if startY < endY then
				counterY = startY
				for counterX = startX, endX, -1 do
					navigateTo(counterX, counterY)
					placeBlock()
					errorVar = errorVar + deltaErr
					if errorVar >= 0.5 then
						counterY = counterY + 1
						errorVar = errorVar - 1
					end
				end
			else
				counterY = startY
				for counterX = startX, endX, -1 do
					navigateTo(counterX, counterY)
					placeBlock()
					errorVar = errorVar + deltaErr
					if errorVar >= 0.5 then
						counterY = counterY - 1
						errorVar = errorVar - 1
					end
				end
			end
		end
	else
		deltaErr = math.abs(deltaX/deltaY)
		if startY < endY then
			if startX < endX then
				counterX = startX
				for counterY = startY, endY do
					navigateTo(counterX, counterY)
					placeBlock()
					errorVar = errorVar + deltaErr
					if errorVar >= 0.5 then
						counterX = counterX + 1
						errorVar = errorVar - 1
					end
				end
			else
				counterX = startX
				for counterY = startY, endY do
					navigateTo(counterX, counterY)
					placeBlock()
					errorVar = errorVar + deltaErr
					if errorVar >= 0.5 then
						counterX = counterX - 1
						errorVar = errorVar - 1
					end
				end
			end
		else
			if startX < endX then
				counterX = startX
				for counterY = startY, endY, -1 do
					navigateTo(counterX, counterY)
					placeBlock()
					errorVar = errorVar + deltaErr
					if errorVar >= 0.5 then
						counterX = counterX + 1
						errorVar = errorVar - 1
					end
				end
			else
				counterX = startX
				for counterY = startY, endY, -1 do
					navigateTo(counterX, counterY)
					placeBlock()
					errorVar = errorVar + deltaErr
					if errorVar >= 0.5 then
						counterX = counterX - 1
						errorVar = errorVar - 1
					end
				end
			end
		end
	end
end

function rectangle(width, depth, startX, startY)
	startX = startX or positionX
	startY = startY or positionY
	endX = startX + width - 1
	endY = startY + depth - 1
	drawLine(startX, endY, startX, startY)
	drawLine(endX, endY, startX, endY)
	drawLine(endX, startY, endX, endY)
	drawLine(startX, startY, endX, startY)
end

function square(length, startX, startY)
	startX = startX or positionX
	startY = startY or positionY
	rectangle(length, length, startX, startY)
end

function wall(depth, height)
	for i = 1, depth do
		for j = 1, height do
			placeBlock()
			if j < height then
				navigateTo(positionX, positionY, positionZ + 1)
			end
		end
		if (i ~= depth) then
			navigateTo(positionX, positionY + 1, 0)
		end
	end
end

function platform(width, depth, startX, startY)
	startX = startX or positionX
	startY = startY or positionY
	endX = startX + width - 1
	endY = startY + depth - 1
	forward = true
	for counterY = startY, endY do
		if forward then
			for counterX = startX, endX do
				navigateTo(counterX, counterY)
				placeBlock()
			end
		else
			for counterX = endX, startX, -1 do
				navigateTo(counterX, counterY)
				placeBlock()
			end
		end
		forward = not forward
	end
end

function cuboid(width, depth, height, hollow)
	for i = 0, height - 1 do
		navigateTo(0, 0, i)
		if (hollow == "n") then
			platform(width, depth, 0, 0)
		else
			rectangle(width, depth, 0, 0)
		end
	end
end

function pyramid(length, hollow)
	-- local height = math.ceil(length / 2) - 1
	i = 0
	while (length > 0) do
		navigateTo(i, i, i)
		if (hollow == "y") then
			rectangle(length, length, i, i)
		else
			platform(length, length, i, i)
		end
		i = i + 1
		length = length - 2
	end
end

function stair(width, height, startX, startY) -- Last two might be able to be used to make a basic home-like shape later?
	startX = startX or positionX
	startY = startY or positionY
	endX = startX + width - 1
	endY = startY + height - 1
	forward = true
	for counterY = startY, endY do
		if forward then
			for counterX = startX, endX do
				navigateTo(counterX, counterY)
				placeBlock()
			end
		else
			for counterX = endX, startX, -1 do
				navigateTo(counterX, counterY)
				placeBlock()
			end
		end
		if counterY ~= endY then
			navigateTo(positionX, positionY, positionZ + 1)
			forward = not forward
		end
	end
end

function circle(diameter)
	odd = not (math.fmod(diameter, 2) == 0)
	radius = diameter / 2
	if odd then
		width = (2 * math.ceil(radius)) + 1
		offset = math.floor(width/2)
	else
		width = (2 * math.ceil(radius)) + 2
		offset = math.floor(width/2) - 0.5		
	end
	--diameter --radius * 2 + 1
	sqrt3 = 3 ^ 0.5
	boundaryRadius = radius + 1.0
	boundary2 = boundaryRadius ^ 2
	radius2 = radius ^ 2
	z = math.floor(radius)
	cz2 = (radius - z) ^ 2
	limitOffsetY = (boundary2 - cz2) ^ 0.5
	maxOffsetY = math.ceil(limitOffsetY)
	-- We do first the +x side, then the -x side to make movement efficient
	for side = 0,1 do
			-- On the right we go from small y to large y, on the left reversed
			-- This makes us travel clockwise (from below) around each layer
			if (side == 0) then
				yStart = math.floor(radius) - maxOffsetY
				yEnd = math.floor(radius) + maxOffsetY
				yStep = 1
			else
				yStart = math.floor(radius) + maxOffsetY
				yEnd = math.floor(radius) - maxOffsetY
				yStep = -1
			end
			for y = yStart,yEnd,yStep do
				cy2 = (radius - y) ^ 2
				remainder2 = (boundary2 - cz2 - cy2)
				if remainder2 >= 0 then
					-- This is the maximum difference in x from the centre we can be without definitely being outside the radius
					maxOffsetX = math.ceil((boundary2 - cz2 - cy2) ^ 0.5)
					-- Only do either the +x or -x side
					if (side == 0) then
						-- +x side
						xStart = math.floor(radius)
						xEnd = math.floor(radius) + maxOffsetX
					else
						-- -x side
						xStart = math.floor(radius) - maxOffsetX
						xEnd = math.floor(radius) - 1
					end
					-- Reverse direction we traverse xs when in -y side
					if y > math.floor(radius) then
						temp = xStart
						xStart = xEnd
						xEnd = temp
						xStep = -1
					else
						xStep = 1
					end

					for x = xStart,xEnd,xStep do
						-- Only blocks within the radius but still within 1 3d-diagonal block of the edge are eligible
						if isSphereBorder(offset, x, y, z, radius2) then
							navigateTo(x, y)
							placeBlock()
						end
					end
				end
			end
		end
end

function blockInSphereIsFull(offset, x, y, z, radiusSq)
	x = x - offset
	y = y - offset
	z = z - offset
	x = x ^ 2
	y = y ^ 2
	z = z ^ 2
	return x + y + z <= radiusSq
end

function isSphereBorder(offset, x, y, z, radiusSq)
	spot = blockInSphereIsFull(offset, x, y, z, radiusSq)
	if spot then
		spot = not blockInSphereIsFull(offset, x, y - 1, z, radiusSq) or
			not blockInSphereIsFull(offset, x, y + 1, z, radiusSq) or
			not blockInSphereIsFull(offset, x - 1, y, z, radiusSq) or
			not blockInSphereIsFull(offset, x + 1, y, z, radiusSq) or
			not blockInSphereIsFull(offset, x, y, z - 1, radiusSq) or
			not blockInSphereIsFull(offset, x, y, z + 1, radiusSq)
	end
	return spot
end

function dome(typus, diameter)
	-- Main dome and sphere building routine
	odd = not (math.fmod(diameter, 2) == 0)
	radius = diameter / 2
	if odd then
		width = (2 * math.ceil(radius)) + 1
		offset = math.floor(width/2)
	else
		width = (2 * math.ceil(radius)) + 2
		offset = math.floor(width/2) - 0.5		
	end
	--diameter --radius * 2 + 1
	sqrt3 = 3 ^ 0.5
	boundaryRadius = radius + 1.0
	boundary2 = boundaryRadius ^ 2
	radius2 = radius ^ 2
	
	if typus == "dome" then
		zstart = math.ceil(radius)
	elseif typus == "sphere" then
		zstart = 1
	elseif typus == "bowl" then
		zstart = 1
	end
	if typus == "bowl" then
		zend = math.floor(radius)
	else
		zend = width - 1
	end

	-- This loop is for each vertical layer through the sphere or dome.
	for z = zstart,zend do
		if not cost_only and z ~= zstart then
			navigateTo(positionX, positionY, positionZ + 1)
		end
		--writeOut("Layer " .. z)
		cz2 = (radius - z) ^ 2
		limitOffsetY = (boundary2 - cz2) ^ 0.5
		maxOffsetY = math.ceil(limitOffsetY)
		-- We do first the +x side, then the -x side to make movement efficient
		for side = 0,1 do
			-- On the right we go from small y to large y, on the left reversed
			-- This makes us travel clockwise (from below) around each layer
			if (side == 0) then
				yStart = math.floor(radius) - maxOffsetY
				yEnd = math.floor(radius) + maxOffsetY
				yStep = 1
			else
				yStart = math.floor(radius) + maxOffsetY
				yEnd = math.floor(radius) - maxOffsetY
				yStep = -1
			end
			for y = yStart,yEnd,yStep do
				cy2 = (radius - y) ^ 2
				remainder2 = (boundary2 - cz2 - cy2)
				if remainder2 >= 0 then
					-- This is the maximum difference in x from the centre we can be without definitely being outside the radius
					maxOffsetX = math.ceil((boundary2 - cz2 - cy2) ^ 0.5)
					-- Only do either the +x or -x side
					if (side == 0) then
						-- +x side
						xStart = math.floor(radius)
						xEnd = math.floor(radius) + maxOffsetX
					else
						-- -x side
						xStart = math.floor(radius) - maxOffsetX
						xEnd = math.floor(radius) - 1
					end
					-- Reverse direction we traverse xs when in -y side
					if y > math.floor(radius) then
						temp = xStart
						xStart = xEnd
						xEnd = temp
						xStep = -1
					else
						xStep = 1
					end

					for x = xStart,xEnd,xStep do
						-- Only blocks within the radius but still within 1 3d-diagonal block of the edge are eligible
						if isSphereBorder(offset, x, y, z, radius2) then
							navigateTo(x, y)
							placeBlock()
						end
					end
				end
			end
		end
	end
end

function cylinder(diameter, height)
	for i = 1, height do
		circle(diameter)
		navigateTo(positionX, positionY, positionZ + 1)
	end
end

function isINF(value)
	return (value == math.huge or value == -math.huge)
end

function isNAN(value)
	return value ~= value
end

polygonCornerList = {} -- Public list of corner coords for n-gons, will be used for hexagons, octagons, and future polygons.
-- It should be a nested list eg. {{x0,y0},{x1,y1},{x2,y2}...}

function constructPolygon() -- Uses polygonCornerList to draw sides between each point
	if #polygonCornerList == 0 then
		return false
	end
	for i = 1, #polygonCornerList do
		if (isINF(polygonCornerList[i][1]) or isNAN(polygonCornerList[i][1])) then
			polygonCornerList[i][1] = 0
		end
		if (isINF(polygonCornerList[i][2]) or isNAN(polygonCornerList[i][2])) then
			polygonCornerList[i][2] = 0
		end
	end
	for i = 1, #polygonCornerList do
		startX = polygonCornerList[i][1]
		startY = polygonCornerList[i][2]
		if i == #polygonCornerList then
			j = 1
		else
			j = i + 1
		end
		stopX = polygonCornerList[j][1]
		stopY = polygonCornerList[j][2]
		drawLine(stopX, stopY, startX, startY)
	end
	return true
end

function circleLikePolygon(numberOfSides, diameter, offsetAngle) -- works like the circle code, allows building a circle with the same diameter from the same start point to inscribe the polygon
	radius = diameter / 2
	if (numberOfSides % 2 == 1) then -- if numberOfSides is odd
		startAngle = math.pi / 2 -- always have a vertex at 90 deg (+y) and at least one grid aligned edge
	else -- if numberOfSides is even
		startAngle = (math.pi / 2) + (math.pi / numberOfSides) -- always have at least two grid aligned edges
	end
	startAngle = startAngle + ((offsetAngle or 0) * (math.pi / 180)) -- offsetAngle will be a degree measurement
	
	for i = 1, numberOfSides do
		polygonCornerList[i] = {radius * math.cos(startAngle + ((i - 1) * ((math.pi * 2) / numberOfSides))), radius * math.sin(startAngle + ((i - 1) * ((math.pi * 2) / numberOfSides)))}
	end

	for i = 1, #polygonCornerList do
		polygonCornerList[i][1] = round(polygonCornerList[i][1] + radius + 1)
		polygonCornerList[i][2] = round(polygonCornerList[i][2] + radius + 1)
	end
	
	if not constructPolygon() then
		error("This error should never happen.")
	end
end

function polygon(numberOfSides, sideLength, offsetAngle)
	currentAngle = 0 + ((offsetAngle or 0) * (math.pi / 180)) -- start at 0 or offset angle
	addAngle = ((math.pi * 2) / numberOfSides)
	pointerX, pointerY = 0, 0
	
	for i = 1, numberOfSides do
		polygonCornerList[i] = {pointerX, pointerY}
		pointerX = sideLength * math.cos(currentAngle) + pointerX
		pointerY = sideLength * math.sin(currentAngle) + pointerY
		currentAngle = currentAngle + addAngle
	end
	
	minX, minY = 0, 0
	for i = 1, #polygonCornerList do -- find the smallest x and y
		if (polygonCornerList[i][1] <= minX) then
			minX = polygonCornerList[i][1]
		end
		if (polygonCornerList[i][2] <= minY) then
			minY = polygonCornerList[i][2]
		end
	end
	minX = math.abs(minX)
	minY = math.abs(minY)
	
	for i = 1, #polygonCornerList do -- make it bounded to 0, 0
		polygonCornerList[i][1] = round(polygonCornerList[i][1] + minX)
		polygonCornerList[i][2] = round(polygonCornerList[i][2] + minY)
	end
	
	if not constructPolygon() then
		error("This error should never happen.")
	end
end

function hexagon(sideLength) -- Fills out polygonCornerList with the points for a hexagon
	sideLength = sideLength - 1
	local changeX = sideLength / 2
	local changeY = round(math.sqrt(3) * changeX, 0)
	changeX = round(changeX, 0)
	polygonCornerList[1] = {changeX, 0}
	polygonCornerList[2] = {(changeX + sideLength), 0}
	polygonCornerList[3] = {((2 * changeX) + sideLength), changeY}
	polygonCornerList[4] = {(changeX + sideLength), (2 * changeY)}
	polygonCornerList[5] = {changeX, (2 * changeY)}
	polygonCornerList[6] = {0, changeY}
	if not constructPolygon() then
		error("This error should never happen.")
	end
end

function octagon(sideLength) -- Fills out polygonCornerList with the points for an octagon
	sideLength = sideLength - 1
	local change = round((sideLength - 1) / math.sqrt(2), 0)
	polygonCornerList[1] = {change, 0}
	polygonCornerList[2] = {(change + sideLength), 0}
	polygonCornerList[3] = {((2 * change) + sideLength), change}
	polygonCornerList[4] = {((2 * change) + sideLength), (change + sideLength)}
	polygonCornerList[5] = {(change + sideLength), ((2 * change) + sideLength)}
	polygonCornerList[6] = {change, ((2 * change) + sideLength)}
	polygonCornerList[7] = {0, (change + sideLength)}
	polygonCornerList[8] = {0, change}
	if not constructPolygon() then
		error("This error should never happen.")
	end
end

function sixprism(length, height)
	for i = 1, height do
		hexagon(length)
		if i ~= height then
			navigateTo(positionX, positionY, positionZ + 1)
		end
	end
end

function eightprism(length, height)
	for i = 1, height do
		octagon(length)
		if i ~= height then
			navigateTo(positionX, positionY, positionZ + 1)
		end
	end
end

-- Previous Progress Resuming, Simulation functions, Command Line, and File Backend
-- Will check for a "progress" file.
function CheckForPrevious() 
	if fs.exists(progFileName) then
		return true
	else
		return false
	end
end

-- Creates a progress file, containing a serialized table consisting of the shape type, shape input params, and the last known x, y, and z coords of the turtle (beginning of build project)
function ProgressFileCreate() 
	if not CheckForPrevious() then
		fs.makeDir(progFileName)
		return true
	else
		return false
	end
end

-- Deletes the progress file (at the end of the project, or at beginning if user chooses to delete old progress)
function ProgressFileDelete() 
	if fs.exists(progFileName) then
		fs.delete(progFileName)
		return true
	else 
		return false
	end
end

-- To read the shape params from the file.  Shape type, and input params (e.g. "dome" and radius)
function ReadShapeParams()
	-- TODO. Unneeded for now, can just use the table elements directly
end

function WriteShapeParams(...) -- The ... lets it take any number of arguments and stores it to the table arg{} | This is still unused anywhere
	local paramTable = arg
	local paramName = "param"
	local paramName2 = paramName
	for i, v in ipairs(paramTable) do -- Iterates through the args passed to the function, ex. paramTable[1] i = 1 so paramName2 should be "param1", tested and works!
		paramName2 = paramName .. i
		tempProgTable[paramName2] = v
		progTable[paramName2] = v
	end
end

-- function to write the progress to the file (x, y, z)
function writeProgress()
	local progFile
	local progString = ""
	if not (sim_mode or cost_only) then
		progString = textutils.serialize(progTable) -- Put in here to save processing time when in cost_only
		progFile = fs.open(progFileName, "w")
		progFile.write(progString)
		progFile.close()
	end

end

-- Reads progress from file (shape, x, y, z, facing, blocks, param1, param2, param3)
function readProgress()
	local progFile = fs.open(progFileName, "r")
	local readProgTable = textutils.unserialize(progFile.readAll())
	progFile.close()
	return readProgTable
end

-- compares the progress read from the file to the current sim progress.  needs all four params 
function compareProgress()
	local progTableIn = progTable
	local readProgTable = readProgress()
	if (progTableIn.shape == readProgTable.shape and progTableIn.x == readProgTable.x and progTableIn.y == readProgTable.y and progTableIn.blocks == readProgTable.blocks and progTableIn.facing == readProgTable.facing) then
		writeOut("All caught up!")
		return true -- We're caught up!
	else
		return false -- Not there yet...
	end
end

function getGPSInfo() -- TODO: finish this
	position = gps.locate()
	gpsPositionX = position.x
	gpsPositionZ = position.y
	gpsPositionY = position.z
	
end

function setSimFlags(b)
	sim_mode = b
	cost_only = b
	if cmd_line_cost_only then
		cost_only = true
	end
end

function simulationCheck() -- checks state of the simulation
	if sim_mode then
		if compareProgress() then
			setSimFlags(false) -- If we're caught up, un-set flags
		else
			setSimFlags(true)  -- If not caught up, just re-affirm that the flags are set
		end
	end
end

function continueQuery()
	if cmd_line_resume then
		 return true
	else
		 if not cmd_line then
			 writeOut("Do you want to continue the last job?")
			 local yes = io.read()
			 if yes == "y" then
				 return true
			 else
				 return false
			 end
		 end
	end
end

function progressUpdate()  -- This ONLY updates the local table variable.  Writing is handled above. -- I want to change this to allow for any number of params
	progTable = {shape = choice, enderchest_refilling = tempProgTable.enderchest_refilling, param1 = tempProgTable.param1, param2 = tempProgTable.param2, param3 = tempProgTable.param3, param4 = tempProgTable.param4, x = positionX, y = positionY, z = positionZ, facing = facing, blocks = blocks}
	if not sim_mode then 
		writeProgress()
	end
end

 -- Command Line
function checkCommandLine() --True if arguments were passed
	if #argTable > 0 then
		cmd_line = true
		return true
	else
		cmd_line = false
		return false
	end
end

function needsHelp() -- True if -h is passed
	for i, v in pairs(argTable) do
		if v == "-h" or v == "-help" or v == "--help" then
			return true
		else
			return false
		end
	end
end

function setFlagsFromCommandLine() -- Sets count_only, chain_next_shape, and sim_mode
	for i, v in pairs(argTable) do
		if v == "-c" or v == "-cost" or v == "--cost" then
			cost_only = true
			cmd_line_cost_only = true
			writeOut("Cost Only Mode")
		end
		if v == "-z" or v == "-chain" or v == "--chain" then
			chain_next_shape = true
			writeOut("Chained Shape Mode")
		end
		if v == "-r" or v == "-resume" or v == "--resume" then
			cmd_line_resume = true
			writeOut("Resuming")
		end
		if v == "-e" or v == "-ender" or v == "--ender" then
			enderchest_refilling = true
			tempProgTable.enderchest_refilling = true
			writeOut("Enderchest Mode")
		end
		if v == "-g" or v == "-home" or v == "--home" then
			return_to_home = true
			writeOut("Will return home")
		end
	end
end

function setTableFromCommandLine() -- Sets progTable and tempProgTable from command line arguments
	progTable.shape = argTable[1]
	tempProgTable.shape = argTable[1]
	local paramName = "param"
	local paramName2 = paramName
	for i = 2, #argTable do
		local addOn = tostring(i - 1)
		paramName2 = paramName .. addOn
		progTable[paramName2] = argTable[i]
		tempProgTable[paramName2] = argTable[i]
	end
end

-- Menu, Drawing and Main functions

function choiceIsValidShape(choice)
	local validShapes = {"rectangle", "square", "line", "wall", "platform", "stair", "stairs", "cuboid", "1/2-sphere", "1/2 sphere", "half-sphere", "half sphere", "dome", "bowl", "sphere", "circle", "cylinder", "pyramid", "polygon", "polyprism", "poly prism", "poly-prism", "polygon prism"}
	for i = 1, #validShapes do
		if choice == validShapes[i] then
			return true
		end
	end
	return false
end

function choiceFunction()
	if sim_mode == false and cmd_line == false then -- If we are NOT resuming progress
		local page = 1
		choice = io.read()
		choice = string.lower(choice) -- All checks are against lower case words so this is to ensure that
		while ((choice == "next") or (choice == "back")) do
			if (choice == "next") then
				if page == 1 then
					writeMenu2()
					page = 2
				else
					writeMenu()
					page = 1
				end
			end
			if (choice == "back") then
				if page == 1 then
					writeMenu2()
					page = 2
				else
					writeMenu()
					page = 1
				end
			end
			choice = io.read()
			choice = string.lower(choice) -- All checks are aginst lower case words so this is to ensure that
		end
		if choice == "end" or choice == "exit" then
			writeOut("Goodbye.")
			return
		end
		if choice == "help" then
			getHelp()
			return
		end
		if choice == "credits" then
			showCredits()
			return
		end
		tempProgTable = {shape = choice}
		progTable = {shape = choice}
		if not choiceIsValidShape(choice) then
			writeOut(choice ..  " is not a valid shape choice.")
			return
		end
		writeOut("Building a "..choice)
		local yes = getInput("string","Want to just calculate the cost?","y","n")
		if yes == 'y' then
			cost_only = true
		end
		local yes = getInput("string","Want turtle to return to start after build?","y","n")
		if yes == 'y' then
			return_to_home = true
		end
		local yes = getInput("string","Want the turtle to refill from enderchest (slot 16)?","y","n")
		if yes == 'y' then
			enderchest_refilling = true
			tempProgTable.enderchest_refilling = true
		end
	elseif sim_mode == true then -- If we ARE resuming progress
		tempProgTable = readProgress()
		choice = tempProgTable.shape
		choice = string.lower(choice) -- All checks are aginst lower case words so this is to ensure that
		enderchest_refilling =  tempProgTable.enderchest_refilling
	elseif cmd_line == true then -- If running from command line
		if needsHelp() then
			showCmdLineHelp()
			return
		end
		choice = tempProgTable.shape
		choice = string.lower(choice) -- All checks are aginst lower case words so this is to ensure that
		enderchest_refilling =  tempProgTable.enderchest_refilling
		writeOut("Building a "..choice)
	end	
	if not cost_only then
		turtle.select(1)
		activeSlot = 1
		if turtle.getItemCount(activeSlot) == 0 then
			if resupply then
				writeOut("Please put building blocks in the first slot.")
			else
				writeOut("Please put building blocks in the first slot (and more if you need them)")
			end
			while turtle.getItemCount(activeSlot) <= 1 do
				os.sleep(.1)
			end
		end
	else
		activeSlot = 1
	end
	-- Shape selection if cascade
	-- Line based shapes
	if choice == "rectangle" then
		local depth = 0
		local width = 0
		if sim_mode == false and cmd_line == false then
			width = getInput("int","How wide does it need to be?")
			depth = getInput("int","How deep does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			width = tempProgTable.param1
			depth = tempProgTable.param2
		end
		tempProgTable.param1 = width
		tempProgTable.param2 = depth
		progTable = {param1 = width, param2 = depth} -- THIS is here because we NEED to update the local table!
		rectangle(width, depth)
	end
	if choice == "square" then
		local sideLength
		if sim_mode == false and cmd_line == false then
			sideLength = getInput("int","How long does each side need to be?")
		elseif sim_mode == true or cmd_line == true then
			sideLength = tempProgTable.param1
		end
		tempProgTable.param1 = sideLength
		progTable = {param1 = sideLength}
		square(sideLength)
	end
	if choice == "line" then
		local startX = 0
		local startY = 0
		local endX = 0
		local endY = 0
		if sim_mode == false and cmd_line == false then
			writeOut("Note that the turtle's starting position is 0, 0.")
			startX = getInput("int","Where does the start X need to be?")
			startY = getInput("int","Where does the start Y need to be?")
			endX = getInput("int","Where does the end X need to be?")
			endY = getInput("int","Where does the end Y need to be?")
		elseif sim_mode == true or cmd_line == true then
			startX = tempProgTable.param1
			startY = tempProgTable.param2
			endX = tempProgTable.param3
			endY = tempProgTable.param4
		end
		tempProgTable.param1 = startX
		tempProgTable.param2 = startY
		tempProgTable.param3 = endX
		tempProgTable.param4 = endY
		progTable = {param1 = startX, param2 = startY, param3 = endX, param4 = endY}
		drawLine(endX, endY, startX, startY)
	end
	if choice == "wall" then
		local depth = 0
		local height = 0
		if sim_mode == false and cmd_line == false then
			depth = getInput("int","How deep does it need to be?")
			height = getInput("int","How high does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			depth = tempProgTable.param1
			height = tempProgTable.param2
		end			
		tempProgTable.param1 = depth
		tempProgTable.param2 = height
		progTable = {param1 = depth, param2 = height}
		wall(depth, height)
	end
	if choice == "platform" then
		local width = 0
		local depth = 0
		if sim_mode == false and cmd_line == false then
			width = getInput("int","How wide does it need to be?")
			depth = getInput("int","How deep does it need to be?")
		elseif sim_mode == true or cmd_line == true then	
			width = tempProgTable.param1		
			depth = tempProgTable.param2
		end		
		tempProgTable.param1 = width
		tempProgTable.param2 = depth
		progTable = {param1 = width, param2 = depth}
		platform(width, depth)
	end
	if choice == "stair" or choice == "stairs" then
		local width = 0
		local height = 0
		if sim_mode == false and cmd_line == false then
			width = getInput("int","How wide does it need to be?")
			height = getInput("int","How high does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			width = tempProgTable.param1
			height = tempProgTable.param2
		end
		tempProgTable.param1 = width
		tempProgTable.param2 = height
		progTable = {param1 = width, param2 = height}
		stair(width, height)
		special_chain = true
	end
	if choice == "cuboid" then
		local width = 0
		local depth = 0
		local height = 0
		local hollow = ""
		if sim_mode == false and cmd_line == false then
			width = getInput("int","How wide does it need to be?")
			depth = getInput("int","How deep does it need to be?")
			height = getInput("int","How high does it need to be?")
			hollow = getInput("string","Does it need to be hollow?","y","n")
		elseif sim_mode == true or cmd_line == true then
			width = tempProgTable.param1
			depth = tempProgTable.param2
			height = tempProgTable.param3
			hollow = tempProgTable.param4
		end
		tempProgTable.param1 = width
		tempProgTable.param2 = depth
		tempProgTable.param3 = height
		tempProgTable.param4 = hollow	
		progTable = {param1 = width, param2 = depth, param3 = height}
		cuboid(width, depth, height, hollow)
	end
	if choice == "pyramid" then
		local length = 0
		local hollow = ""
		if sim_mode == false and cmd_line == false then
			length = getInput("int","How long does each side of the base layer need to be?")
			hollow = getInput("string","Does it need to be hollow?","y","n")
		elseif sim_mode == true or cmd_line == true then
			length = tempProgTable.param1
			hollow = tempProgTable.param2
		end
		tempProgTable.param1 = length
		tempProgTable.param2 = hollow
		progTable = {param1 = length, param2 = hollow}
		pyramid(length, hollow)
	end
	-- Circle based shapes
	if choice == "1/2-sphere" or choice == "1/2 sphere" then
		local diameter = 0
		local half = ""
		if sim_mode == false and cmd_line == false then
			diameter = getInput("int","What diameter does it need to be?")
			half = getInput("string","What half of the sphere does it need to be?","bottom","top")
		elseif sim_mode == true or cmd_line == true then
			diameter = tempProgTable.param1
			half = tempProgTable.param2
		end	
		tempProgTable.param1 = diameter
		tempProgTable.param2 = half
		progTable = {param1 = diameter, param2 = half}
		if half == "bottom" then
			dome("bowl", diameter)
		elseif half == "top" then
			dome("dome", diameter)
		end
	end
	if choice == "dome" then
		local diameter = 0
		if sim_mode == false and cmd_line == false then
			diameter = getInput("int","What diameter does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			diameter = tempProgTable.param1
		end	
		tempProgTable.param1 = diameter
		progTable = {param1 = diameter}
		dome("dome", diameter)
	end
	if choice == "bowl" then
		local diameter = 0
		if sim_mode == false and cmd_line == false then
			diameter = getInput("int","What diameter does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			diameter = tempProgTable.param1
		end	
		tempProgTable.param1 = diameter
		progTable = {param1 = diameter}
		dome("bowl", diameter)
	end
	if choice == "sphere" then
		local diameter = 0
		if sim_mode == false and cmd_line == false then
			diameter = getInput("int","What diameter does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			diameter = tempProgTable.param1
		end
		tempProgTable.param1 = diameter
		progTable = {param1 = diameter}
		dome("sphere", diameter)
	end
	if choice == "circle" then
		local diameter = 0
		if sim_mode == false and cmd_line == false then
			diameter = getInput("int","What diameter does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			diameter = tempProgTable.param1
		end
		tempProgTable.param1 = diameter
		progTable = {param1 = diameter}
		circle(diameter)
	end
	if choice == "cylinder" then
		local diameter = 0
		local height = 0
		if sim_mode == false and cmd_line == false then
			diameter = getInput("int","What diameter does it need to be?")
			height = getInput("int","How high does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			diameter = tempProgTable.param1
			height = tempProgTable.param2
		end
		tempProgTable.param1 = diameter
		tempProgTable.param2 = height
		progTable = {param1 = diameter, param2 = height}
		cylinder(diameter, height)
	end
	-- Polygon shapes
	if choice == "hexagon" then
		local length = 0
		if sim_mode == false and cmd_line == false then
			length = getInput("int","How long does each side need to be?")
		elseif sim_mode == true or cmd_line == true then
			length = tempProgTable.param1
		end
		tempProgTable.param1 = length
		progTable = {param1 = length}
		hexagon(length)
	end
	if choice == "octagon" then
		local length = 0
		if sim_mode == false and cmd_line == false then
			length = getInput("int","How long does each side need to be?")
		elseif sim_mode == true or cmd_line == true then
			length = tempProgTable.param1
		end
		tempProgTable.param1 = length
		progTable = {param1 = length}
		octagon(length)
	end
	if choice == "polygon" then
		local numberOfSides = 3
		local length = 0
		local circleLike = "n"
		local offSetAngle = 0
		if sim_mode == false and cmd_line == false then
			numberOfSides = getInput("int","How many sides to build?")
			circleLike = getInput("string","Do you want circle style?","y","n")
			if (circleLike == "y") then
				length = getInput("int","What diameter does it need to be?")
			else
				length = getInput("int","How long does each side need to be?")
			end
			offSetAngle = getInput("int","What offset angle does it need to be? (usually 0)")
		elseif sim_mode == true or cmd_line == true then
			numberOfSides = tempProgTable.param1
			circleLike = tempProgTable.param2
			length = tempProgTable.param3
			offSetAngle = tempProgTable.param4
		end
		tempProgTable.param1 = numberOfSides
		progTable = {param1 = numberOfSides}
		tempProgTable.param2 = circleLike
		progTable = {param2 = circleLike}
		tempProgTable.param3 = length
		progTable = {param3 = length}
		tempProgTable.param4 = offSetAngle
		progTable = {param4 = offSetAngle}
		if (circleLike == "y") then
			circleLikePolygon(numberOfSides, length, offSetAngle)
		else
			polygon(numberOfSides, length, offSetAngle)
		end
	end
	if choice == "6-prism" or choice == "6 prism" then
		local length = 0
		local height = 0
		if sim_mode == false and cmd_line == false then
			length = getInput("int","How long does each side need to be?")
			height = getInput("int","How high does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			length = tempProgTable.param1
			height = tempProgTable.param2
		end
		tempProgTable.param1 = length
		tempProgTable.param2 = height
		progTable = {param1 = length, param2 = height}
		sixprism(length, height)
	end
	if choice == "8-prism" or choice == "8 prism" then
		local length = 0
		local height = 0
		if sim_mode == false and cmd_line == false then
			length = getInput("int","How long does each side need to be?")
			height = getInput("int","How high does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			length = tempProgTable.param1
			height = tempProgTable.param2
		end
		tempProgTable.param1 = length
		tempProgTable.param2 = height
		progTable = {param1 = length, param2 = height}
		eightprism(length, height)
	end
	if return_to_home then
		goHome() -- After all shape building has finished
	end
	writeOut("Done") -- Saves a few lines when put here rather than in each if statement
end

function writeMenu()
	term.clear()
	term.setCursorPos(1, 1)
	writeOut("Shape Maker 1.8 by Keridos/CupricWolf/pokemane")
	if resupply then					-- Any ideas to make this more compact/better looking (in terms of code)?
		writeOut("Resupply Mode Active")
	elseif (resupply and can_use_gps) then
		writeOut("Resupply and GPS Mode Active")
	elseif can_use_gps then
		writeOut("GPS Mode Active")
	else
		writeOut("Standard Mode Active")
	end
	if not cmd_line then
		writeOut("What shape do you want to build?")
		writeOut("[page 1/2]")
		writeOut("next for page 2")
		writeOut("+---------+-----------+-------+-------+")
		writeOut("| square  | rectangle | wall  | line  |")
		writeOut("| cylinder| platform  | stair | cuboid|")
		writeOut("| pyramid | 1/2-sphere| sphere| circle|")
		writeOut("+---------+-----------+-------+-------+")
		writeOut("")
	end
end

function writeMenu2()
	term.clear()
	term.setCursorPos(1, 1)
	writeOut("Shape Maker 1.8 by Keridos/CupricWolf/pokemane")
	if resupply then					-- Any ideas to make this more compact/better looking (in terms of code)?
		writeOut("Resupply Mode Active")
	elseif (resupply and can_use_gps) then
		writeOut("Resupply and GPS Mode Active")
	elseif can_use_gps then
		writeOut("GPS Mode Active")
	else
		writeOut("Standard Mode Active")
	end
	writeOut("What shape do you want to build?")
	writeOut("[page 2/2]")
	writeOut("back for page 1")
	writeOut("+---------+-----------+-------+-------+")
	writeOut("| polygon | polyprism | dome  | dome  |")
	writeOut("|         |           |       |       |")
	writeOut("| help    | credits   | end   |       |")
	writeOut("+---------+-----------+-------+-------+")
	writeOut("")
end

function showCmdLineHelp()
	term.clear()
	term.setCursorPos(1, 1)
	writeOut("Command line help")
	writeOut("Usage: shape [shape-type] [param1] [param2] [param3] [param4] [-c] [-h] [-z] [-r]")
	writeOut("-c or -cost or --cost: Activate cost only mode")
	writeOut("-h or -help or --help: Show this information")
	io.read()
	writeOut("-z or -chain or --chain: Lets you chain together multiple shapes")
	writeOut("-g or -home or --home: Make turtle go 'home' after build")
	writeOut("-r or -resume or --resume: Resume the last build if possible")
	io.read()
	writeOut("-e or -ender or --ender: Activate enderchest refilling")
	writeOut("shape-type can be any of the shapes in the menu")
	writeOut("After shape-type input all of the parameters for the shape, varies by shape")
	writeOut("Put any flags (-c, -h, etc.) at the end of your command")
end

function getHelp()
	term.clear()
	term.setCursorPos(1, 1)
	writeOut("Width is to the right of the turtle. (X-Axis)")
	writeOut("Depth is to the front of the turtle. (Y-Axis)")
	writeOut("Height is to the top of the turtle. (Z-Axis)")
	writeOut("Length is the side length of some shapes. (Squares and Polygons)")
	io.read()
	term.clear()
	term.setCursorPos(1, 1)
	local page = 1
	writeOut("What shape do you want help with?")
	writeOut("[page 1/2]")
	writeOut("next for page 2")
	writeOut("+---------+-----------+-------+-------+")
	writeOut("| square  | rectangle | wall  | line  |")
	writeOut("| cylinder| platform  | stair | cuboid|")
	writeOut("| pyramid | 1/2-sphere| sphere| circle|")
	writeOut("+---------+-----------+-------+-------+")
	writeOut("")
	choice = io.read()
	choice = string.lower(choice)
	while ((choice == "next") or (choice == "back")) do
		if (choice == "next") then
			if (page == 1) then
				page = 2
				term.clear()
				term.setCursorPos(1, 1)
				writeOut("What shape do you want help with?")
				writeOut("[page 2/2]")
				writeOut("back for page 1")
				writeOut("+---------+-----------+-------+-------+")
				writeOut("| hexagon | octagon   | dome  |       |")
				writeOut("| 6-prism | 8-prism   | bowl  |       |")
				writeOut("|         |           |       |       |")
				writeOut("+---------+-----------+-------+-------+")
				writeOut("")
			else
				page = 1
				term.clear()
				term.setCursorPos(1, 1)
				writeOut("What shape do you want help with?")
				writeOut("[page 1/2]")
				writeOut("next for page 2")
				writeOut("+---------+-----------+-------+-------+")
				writeOut("| square  | rectangle | wall  | line  |")
				writeOut("| cylinder| platform  | stair | cuboid|")
				writeOut("| pyramid | 1/2-sphere| sphere| circle|")
				writeOut("+---------+-----------+-------+-------+")
				writeOut("")
			end
		end
		if (choice == "back") then
			if (page == 1) then
				page = 2
				term.clear()
				term.setCursorPos(1, 1)
				writeOut("What shape do you want help with?")
				writeOut("[page 2/2]")
				writeOut("back for page 1")
				writeOut("+---------+-----------+-------+-------+")
				writeOut("| hexagon | octagon   | dome  |       |")
				writeOut("| 6-prism | 8-prism   | bowl  |       |")
				writeOut("|         |           |       |       |")
				writeOut("+---------+-----------+-------+-------+")
				writeOut("")
			else
				page = 1
				term.clear()
				term.setCursorPos(1, 1)
				writeOut("What shape do you want help with?")
				writeOut("[page 2/2]")
				writeOut("next for page 2")
				writeOut("+---------+-----------+-------+-------+")
				writeOut("| square  | rectangle | wall  | line  |")
				writeOut("| cylinder| platform  | stair | cuboid|")
				writeOut("| pyramid | 1/2-sphere| sphere| circle|")
				writeOut("+---------+-----------+-------+-------+")
				writeOut("")
			end
		end
		choice = io.read()
		choice = string.lower(choice) 
	end
	if not choiceIsValidShape(choice) then
		writeOut(choice ..  " is not a valid shape choice.")
		return
	end
	-- If cascade time!
	if choice == "rectangle" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The rectangle is a perimeter of width by depth. Use platform if you want a filled in rectangle. The rectangle takes two parameters (two integers) Width then Depth.")
	end
	if choice == "square" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The square is a perimeter of length by length. Use platform if you want a filled in square. The square takes one parameter (one integer) Length.")
	end
	if choice == "line" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The line is drawn between the start and end points given. The turtle's initial position is 0, 0 so that must by taken into account. The line takes four parameters (four integers) Start X then Start Y then End X then End Y.")
	end
	if choice == "wall" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The wall is a vertical plane. The wall takes two parameters (two integers) Depth then Height.")
	end
	if choice == "platform" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The platform is a horizontal plane of width by depth. Use rectangle or square if you want just a perimeter. The platform takes two parameters (two integers) Width then Depth.")
	end
	if choice == "stair" or choice == "stairs" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The stair or stairs are an incline of width by height. The stair takes two parameters (two integers) Width then Height.")
	end
	if choice == "cuboid" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The cuboid is a rectangular prism of width by depth by height. The hollow parameter determines if the shape is solid or like a rectangular tube. The cuboid takes four parameters (three intergers and one y/n) Width then Depth then Height then Hollow(y/n).")
	end
	if choice == "1/2-sphere" or choice == "1/2 sphere" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The half sphere is the top or bottom half of a sphere. The half parameter determines of the top or bottom half of the sphere built. The half sphere takes two parameters (one integer and one top/bottom) Diameter then half(top/bottom).")
	end
	if choice == "dome" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The dome shape is a short-cut to the top half sphere. The dome takes one parameter (one integer) Diameter.")
	end
	if choice == "bowl" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The bowl shape is a short-cut to the bottom half sphere. The bowl takes one parameter (one integer) Diameter.")
	end
	if choice == "sphere" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The sphere is just that, a sphere. It is hollow. The sphere takes one parameter (one integer) Diameter.")
	end
	if choice == "circle" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The circle is just that, a circle. It is just a perimeter. The circle takes one parameter (one integer) Diameter.")
	end
	if choice == "cylinder" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The cylinder is a cylindrical tube of diameter by height. The cylinder takes two parameters (two integers) Diameter then Height.")
	end
	if choice == "pyramid" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The pyramid is a four sided pyramid with base length by length. The hollow parameter determines if the inside is filled. The pyramid takes two parameters (one integer and one y/n) Base Length then Hollow(y/n).")
	end
	if choice == "hexagon" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The hexagon is a hexagonal perimeter. The hexagon takes one parameter (one integer) Length.")
	end
	if choice == "octagon" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The octagon is and octagonal perimeter. The octagon takes one parameter (one integer) Length.")
	end
	if choice == "6-prism" or choice == "6 prism" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The 6 prism is a hexagonal prism shaped tube. The 6 prism takes two parameters (two integers) Length then Height.")
	end
	if choice == "8-prism" or choice == "8 prism" then
		term.clear()
		term.setCursorPos(1, 1)
		writeOut("The 8 prism is an octagonal prism shaped tube. The 8 prism takes two parameters (two integers) Length then Height.")
	end
end

function showCredits()
	term.clear()
	term.setCursorPos(1, 1)
	writeOut("Credits for the shape builder:")
	writeOut("Based on work by Michiel, Vliekkie, and Aeolun")
	writeOut("Sphere/dome code by IMarvinTPA")
	writeOut("Additional improvements by Keridos, CupricWolf, and pokemane")
end

function main()
	if wrapModules()=="resupply" then
		linkToRSStation()
	end
	if checkCommandLine() then
		if needsHelp() then
			showCmdLineHelp()
			return -- Close the program after help info is shown
		end
		setFlagsFromCommandLine()
		setTableFromCommandLine()
	end
	if (CheckForPrevious()) then  -- Will check to see if there was a previous job and gps is enabled, and if so, ask if the user would like to re-initialize to current progress status
		if not continueQuery() then -- If the user doesn't want to continue
			ProgressFileDelete()
			setSimFlags(false) -- Just to be safe
			writeMenu()
			choiceFunction()
		else	-- If the user wants to continue
			setSimFlags(true)
			choiceFunction()
		end
	else
		setSimFlags(false)
		writeMenu()
		choiceFunction()
	end
	if (blocks ~= 0) and (fuel ~= 0) then -- Do not show on help or credits page or when selecting end
		writeOut("Blocks used: " .. blocks)
		writeOut("Fuel used: " .. fuel)
	end
	ProgressFileDelete() -- Removes file upon successful completion of a job, or completion of a previous job.
	progTable = {}
	tempProgTable = {}
end

main()
