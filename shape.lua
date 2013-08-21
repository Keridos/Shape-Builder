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
local resupply = false
local can_use_gps = false
local returntohome = false -- whether the turtle shall return to start after build
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

function getInput(inputtype, message, option1, option2)
	local input = ""
	if inputtype == "string" then
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
	if inputtype == "int" then
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

function wrapmodules() -- checks for and wraps turtle modules
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

function checkResources()
	if resupply then
		if turtle.getItemCount(activeslot) <= 1 then
			while not(resupplymodule.resupply(1)) do
				os.sleep(0.5)
			end
		end
	else
		compareResources()
		while (turtle.getItemCount(activeslot) <= 1) do
			if (activeslot == 16) and (turtle.getItemCount(activeslot)<=1) then
				writeOut("Turtle is empty, please put building block in slots and press enter to continue")
				io.read()
				activeslot = 1
				turtle.select(activeslot)
			else
				activeslot = activeslot+1
				-- writeOut("Turtle slot almost empty, trying slot "..activeslot)
				turtle.select(activeslot)
			end
			compareResources()
			os.sleep(0.2)
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

function round(toBeRounded, decimalPlace) -- Needed for hexagon and octagon
	local multiplier = 10^(decimalPlace or 0)
	return math.floor(toBeRounded * multiplier + 0.5) / multiplier
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
	if direction >= 4 or direction < 0 then
		return false
	end
	while facing ~= direction do
		turnLeftTrack()
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
			while (not success) and tries < 3 do
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
			while turtle.detect() and tries < 3 do
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
		navigateTo(-1, -1, 0) -- So the user can collect the turtle when it is done -- also not 0,0,0 because some shapes use the 0,0 column
	end
	turnToFace(0)
end

-- Shape Building functions

function line(length)
	if length <= 0 then
		error("Error, length can not be 0")
	end
	local i
	for i = 1, length do
		placeBlock()
		if i ~= length then
			safeForward()
		end
	end
end

function rectangle(depth, width)
	if depth <= 0 then
		error("Error, depth can not be 0")
	end
	if width <= 0 then
		error("Error, width can not be 0")
	end
	local lengths = {depth, width, depth, width }
	local j
	for j=1,4 do
		line(lengths[j])
		turnRightTrack()
	end
end

function square(width)
	rectangle(width, width)
end

function wall(length, height)
	local i
	local j
	for i = 1, length do
		for j = 1, height do
			placeBlock()
			if j < height then
				safeUp()
			end
		end
		safeForward()
		for j = 1, height - 1 do
			safeDown()
		end
	end
	turnLeftTrack()
end

function platform(x, y)
	local forward = true
	for counterY = 0, y - 1 do
		for counterX = 0, x - 1 do
			if forward then
				navigateTo(counterX, counterY)
			else
				navigateTo(x - counterX - 1, counterY)
			end
			placeBlock()
		end
		if forward then
			forward = false
		else
			forward = true
		end
	end
end

function cuboid(depth, width, height, hollow)
	platform(depth, width)
	while (facing > 0) do
		turnLeftTrack()
	end
	turnAroundTrack()
	if ((width % 2) == 0) then -- This is for reorienting the turtle to build the walls correct in relation to the floor and ceiling
		turnLeftTrack()
	end
	if not(hollow == "n") then
		for i = 1, height - 2 do
			safeUp()
			if ((width % 2) == 0) then -- This as well
			rectangle(depth, width)
			else
			rectangle(width, depth)
			end
		end
	else
		for i = 1, height - 2 do
			safeUp()
			platform(depth,width)
		end
	end
	safeUp()
	platform(depth, width)
end

function pyramid(length, hollow)
	height = math.ceil(length / 2)
	for i = 1, height do
		if hollow=="y" then
			rectangle(length, length)
		else
			platform(length, length)
			navigateTo(0,0)
			while facing ~= 0 do
				turnRightTrack()
			end
		end
		if i ~= height then
			safeUp()
			safeForward()
			turnRightTrack()
			safeForward()
			turnLeftTrack()
			length = length - 2
		end
	end
end

function stair(width, height)
	turnRightTrack()
	local counterX = 1
	local counterY = 0
	local goForward = 0
	while counterY < height do
		while counterX < width do
			placeBlock()
			safeForward()
			counterX = counterX + 1
		end
		placeBlock()
		counterX = 1
		counterY = counterY + 1
		if counterY < height then
			if goForward == 1 then
				turnRightTrack()
				safeUp()
				safeForward()
				turnRightTrack()
				goForward = 0
			else
				turnLeftTrack()
				safeUp()
				safeForward()
				turnLeftTrack()
				goForward = 1
			end
		end
	end
end

function circle(radius)
	width = radius * 2 + 1
	sqrt3 = 3 ^ 0.5
	boundaryRadius = radius + 1.0
	boundary2 = boundaryRadius ^ 2
	z = radius
	cz2 = (radius - z) ^ 2
	limitOffsetY = (boundary2 - cz2) ^ 0.5
	maxOffestY = math.ceil(limitOffsetY)
	-- We do first the +x side, then the -x side to make movement efficient
	for side = 0, 1 do
		-- On the right we go from small y to large y, on the left reversed
		-- This makes us travel clockwise (from below) around each layer
		if (side == 0) then
			yStart = radius - maxOffestY
			yEnd = radius + maxOffestY
			yStep = 1
		else
			yStart = radius + maxOffestY
			yEnd = radius - maxOffestY
			yStep = -1
		end
		for y = yStart, yEnd, yStep do
			cy2 = (radius - y) ^ 2
			remainder2 = (boundary2 - cz2 - cy2)
			if remainder2 >= 0 then
				-- This is the maximum difference in x from the centre we can be without definitely being outside the radius
				maxOffsetX = math.ceil((boundary2 - cz2 - cy2) ^ 0.5)
					-- Only do either the +x or -x side
				if (side == 0) then
					-- +x side
					xStart = radius
					xEnd = radius + maxOffsetX
				else
					-- -x side
					xStart = radius - maxOffsetX
					xEnd = radius - 1
				end
				-- Reverse direction we traverse xs when in -y side
				if y > radius then
					temp = xStart
					xStart = xEnd
					xEnd = temp
					xStep = -1
				else
					xStep = 1
				end
					for x = xStart, xEnd, xStep do
					cx2 = (radius - x) ^ 2
					distanceToCentre = (cx2 + cy2 + cz2) ^ 0.5
					-- Only blocks within the radius but still within 1 3d-diagonal block of the edge are eligible
					if distanceToCentre < boundaryRadius and distanceToCentre + sqrt3 >= boundaryRadius then
						offsets = {{0, 1, 0}, {0, -1, 0}, {1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1}}
						for i=1,6 do
							offset = offsets[i]
							dx = offset[1]
							dy = offset[2]
							dz = offset[3]
							if ((radius - (x + dx)) ^ 2 + (radius - (y + dy)) ^ 2 + (radius - (z + dz)) ^ 2) ^ 0.5 >= boundaryRadius then
								-- This is a point to use
								navigateTo(x, y)
								placeBlock()
								break
							end
						end
					end
				end
			end
		end
	end
end

function dome(typus, radius)
	-- Main dome and sphere building routine
	width = radius * 2 + 1
	sqrt3 = 3 ^ 0.5
	boundaryRadius = radius + 1.0
	boundary2 = boundaryRadius ^ 2
	if typus == "dome" then
		zstart = radius
	elseif typus == "sphere" then
		zstart = 0
	elseif typus == "bowl" then
		zstart = 0
	end
	if typus == "bowl" then
		zend = radius
	else
		zend = width - 1
	end

	-- This loop is for each vertical layer through the sphere or dome.
	for z = zstart,zend do
		if not cost_only and z ~= zstart then
			safeUp()
		end
		--writeOut("Layer " .. z)
		cz2 = (radius - z) ^ 2
		limitOffsetY = (boundary2 - cz2) ^ 0.5
		maxOffestY = math.ceil(limitOffsetY)
		-- We do first the +x side, then the -x side to make movement efficient
		for side = 0,1 do
			-- On the right we go from small y to large y, on the left reversed
			-- This makes us travel clockwise (from below) around each layer
			if (side == 0) then
				yStart = radius - maxOffestY
				yEnd = radius + maxOffestY
				yStep = 1
			else
				yStart = radius + maxOffestY
				yEnd = radius - maxOffestY
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
						xStart = radius
						xEnd = radius + maxOffsetX
					else
						-- -x side
						xStart = radius - maxOffsetX
						xEnd = radius - 1
					end
					-- Reverse direction we traverse xs when in -y side
					if y > radius then
						temp = xStart
						xStart = xEnd
						xEnd = temp
						xStep = -1
					else
						xStep = 1
					end

					for x = xStart,xEnd,xStep do
						cx2 = (radius - x) ^ 2
						distanceToCentre = (cx2 + cy2 + cz2) ^ 0.5
						-- Only blocks within the radius but still within 1 3d-diagonal block of the edge are eligible
						if distanceToCentre < boundaryRadius and distanceToCentre + sqrt3 >= boundaryRadius then
							offsets = {{0, 1, 0}, {0, -1, 0}, {1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1}}
							for i=1,6 do
								offset = offsets[i]
								dx = offset[1]
								dy = offset[2]
								dz = offset[3]
								if ((radius - (x + dx)) ^ 2 + (radius - (y + dy)) ^ 2 + (radius - (z + dz)) ^ 2) ^ 0.5 >= boundaryRadius then
									-- This is a point to use
									navigateTo(x, y)
									placeBlock()
									break
								end
							end
						end
					end
				end
			end
		end
	end
end

function cylinder(radius, height)
	for i = 1, height do
		circle(radius)
		safeUp()
	end
end

function hexagon(sideLength)
	local changeX = sideLength / 2
	local changeY = round(math.sqrt(3) * changeX, 0)
	changeX = round(changeX, 0)
	local counter = 0

	navigateTo(changeX, 0)

	for currentSide = 1, 6 do
		counter = 0

		if currentSide == 1 then
			for placed = 1, sideLength do
				navigateTo(positionX + 1, positionY)
				placeBlock()
			end
		elseif currentSide == 2 then
			navigateTo(positionX, positionY + 1)
			while positionY <= changeY do
				if counter == 0 or counter == 2 or counter == 4 then
					navigateTo(positionX + 1, positionY)
				end
				placeBlock()
				navigateTo(positionX, positionY + 1)
				counter = counter + 1
				if counter == 5 then
					counter = 0
				end
			end
		elseif currentSide == 3 then
			while positionY <= (2 * changeY) do
				if counter == 0 or counter == 2 or counter == 4 then
					navigateTo(positionX - 1, positionY)
				end
				placeBlock()
				navigateTo(positionX, positionY + 1)
				counter = counter + 1
				if counter == 5 then
					counter = 0
				end
			end
		elseif currentSide == 4 then
			for placed = 1, sideLength do
				navigateTo(positionX - 1, positionY)
				placeBlock()
			end
		elseif currentSide == 5 then
			navigateTo(positionX, positionY - 1)
			while positionY >= changeY do
				if counter == 0 or counter == 2 or counter == 4 then
					navigateTo(positionX - 1, positionY)
				end
				placeBlock()
				navigateTo(positionX, positionY - 1)
				counter = counter + 1
				if counter == 5 then
					counter = 0
				end
			end
		elseif currentSide == 6 then
			while positionY >= 0 do
				if counter == 0 or counter == 2 or counter == 4 then
					navigateTo(positionX + 1, positionY)
				end
				placeBlock()
				navigateTo(positionX, positionY - 1)
				counter = counter + 1
				if counter == 5 then
					counter = 0
				end
			end
		end
	end
end

function octagon(sideLength)
	local sideLength2 = sideLength - 1
	local change = round(sideLength2 / math.sqrt(2), 0)

	navigateTo(change, 0)

	for currentSide = 1, 8 do
		if currentSide == 1 then
			for placed = 1, sideLength2 do
				navigateTo(positionX + 1, positionY)
				placeBlock()
			end
		elseif currentSide == 2 then
			for placed = 1, change do
				navigateTo(positionX + 1, positionY + 1)
				placeBlock()
			end
		elseif currentSide == 3 then
			for placed = 1, sideLength2 do
				navigateTo(positionX, positionY + 1)
				placeBlock()
			end
		elseif currentSide == 4 then
			for placed = 1, change do
				navigateTo(positionX - 1, positionY + 1)
				placeBlock()
			end
		elseif currentSide == 5 then
			for placed = 1, sideLength2 do
				navigateTo(positionX - 1, positionY)
				placeBlock()
			end
		elseif currentSide == 6 then
			for placed = 1, change do
				navigateTo(positionX - 1, positionY - 1)
				placeBlock()
			end
		elseif currentSide == 7 then
		for placed = 1, sideLength2 do
				navigateTo(positionX, positionY - 1)
				placeBlock()
			end
		elseif currentSide == 8 then
			for placed = 1, change do
				navigateTo(positionX + 1, positionY - 1)
				placeBlock()
			end
		end
	end
end

function sixprism(length, height)
	for i = 1, height do
		hexagon(length)
		safeUp()
	end
end

function eigthprism(length, height)
	for i = 1, height do
		octagon(length)
		safeUp()
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

-- Deletes the progress file (at the end of the project, also at beginning if user chooses to delete old progress)
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
	progTable = {shape = choice, param1 = tempProgTable.param1, param2 = tempProgTable.param2, param3 = tempProgTable.param3, param4 = tempProgTable.param4, x = positionX, y = positionY, z = positionZ, facing = facing, blocks = blocks}
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
			writeOut("Cost only mode")
		end
		if v == "-z" or v == "-chain" or v == "--chain" then
			chain_next_shape = true
			writeOut("Chained shape mode")
		end
		if v == "-r" or v == "-resume" or v == "--resume" then
			cmd_line_resume = true
			writeOut("Resuming")
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

function choiceFunction()
	if sim_mode == false and cmd_line == false then -- If we are NOT resuming progress
		choice = io.read()
		choice = string.lower(choice) -- All checks are aginst lower case words so this is to ensure that
		tempProgTable = {shape = choice}
		progTable = {shape = choice}
		if choice == "next" then
			WriteMenu2()
			choice = io.read()
			choice = string.lower(choice) -- All checks are aginst lower case words so this is to ensure that
		end
		if choice == "end" or choice == "exit" then
			writeOut("Goodbye.")
			return
		end
		if choice == "help" then
			showHelp()
			return
		end
		if choice == "credits" then
			showCredits()
			return
		end
		writeOut("Building a "..choice)
		local yes = getInput("string","Want to just calculate the cost?","y","n")
		if yes == 'y' then
			cost_only = true
		end
		local yes = getInput("string","Want turtle to return to start after build?","y","n")
		if yes == 'y' then
			returntohome = true
		end
	elseif sim_mode == true then -- If we ARE resuming progress
		tempProgTable = readProgress()
		choice = tempProgTable.shape
		choice = string.lower(choice) -- All checks are aginst lower case words so this is to ensure that
	elseif cmd_line == true then -- If running from command line
		choice = tempProgTable.shape
		choice = string.lower(choice) -- All checks are aginst lower case words so this is to ensure that
		writeOut("Building a "..choice)
	end	
	if not cost_only then
		turtle.select(1)
		activeslot = 1
		if turtle.getItemCount(activeslot) == 0 then
			if resupply then
				writeOut("Please put building blocks in the first slot.")
			else
				writeOut("Please put building blocks in the first slot (and more if you need them)")
			end
			while turtle.getItemCount(activeslot) == 0 do
				os.sleep(2)
			end
		end
	else
		activeslot = 1
	end
	-- shape selection if cascade
	if choice == "rectangle" then
		local depth = 0
		local width = 0
		if sim_mode == false and cmd_line == false then
			depth = getInput("int","How deep does it need to be?")
			width = getInput("int","How wide does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			depth = tempProgTable.param1
			width = tempProgTable.param2
		end
		tempProgTable.param1 = depth
		tempProgTable.param2 = width
		progTable = {param1 = depth, param2 = width} -- THIS is here because we NEED to update the local table!
		rectangle(depth, width)
	end
	if choice == "square" then
		local sideLength
		if sim_mode == false and cmd_line == false then
			writeOut("What depth/width does it need to be?")
			sideLength = io.read()
		elseif sim_mode == true or cmd_line == true then
			sideLength = tempProgTable.param1
		end
		tempProgTable.param1 = sideLength
		progTable = {param1 = sideLength}
		square(sideLength)
	end
	if choice == "line" then
		local lineLength = 0
		if sim_mode == false and cmd_line == false then
			lineLength = getInput("int","How long does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			lineLength = tempProgTable.param1
		end
		tempProgTable.param1 = lineLength
		progTable = {param1 = lineLength}
		line(lineLength)
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
		local depth = 0
		local width = 0
		if sim_mode == false and cmd_line == false then
			depth = getInput("int","How deep does it need to be?")
			width = getInput("int","How wide does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			depth = tempProgTable.param1	
			width = tempProgTable.param2		
		end		
		tempProgTable.param1 = depth
		tempProgTable.param2 = width
		progTable = {param1 = depth, param2 = width}
		platform(depth, width)
	end
	if choice == "stair" then
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
		local depth = 0
		local width = 0
		local height = 0
		local hollow = ""
		if sim_mode == false and cmd_line == false then
			depth = getInput("int","How deep does it need to be?")
			width = getInput("int","How wide does it need to be?")
			height = getInput("int","How high does it need to be?")
			hollow = getInput("string","Does it need to be hollow?","y","n")
		elseif sim_mode == true or cmd_line == true then
			depth = tempProgTable.param1
			width = tempProgTable.param2
			height = tempProgTable.param3
			hollow = tempProgTable.param4
		end
		tempProgTable.param1 = depth
		tempProgTable.param2 = width
		tempProgTable.param3 = height
		tempProgTable.param4 = hollow
		if height < 3 then
			height = 3
		end
		if depth < 3 then
			depth = 3
		end
		if width < 3 then
			width = 3
		end	
		progTable = {param1 = depth, param2 = width, param3 = height}
		cuboid(depth, width, height, hollow)
	end
	if choice == "1/2-sphere" or choice == "1/2 sphere" then
		local radius = 0
		local half = ""
		if sim_mode == false and cmd_line == false then
			radius = getInput("int","What radius does it need to be?")
			half = getInput("string","What half of the sphere does it need to be?","bottom","top")
		elseif sim_mode == true or cmd_line == true then
			radius = tempProgTable.param1
			half = tempProgTable.param2
		end	
		tempProgTable.param1 = radius
		tempProgTable.param2 = half
		progTable = {param1 = radius, param2 = half}
		if half == "bottom" then
			dome("bowl", radius)
		else
			dome("dome", radius)
		end
	end
	if choice == "dome" then
		local radius = 0
		if sim_mode == false and cmd_line == false then
			radius = getInput("int","What radius does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			radius = tempProgTable.param1
		end	
		tempProgTable.param1 = radius
		progTable = {param1 = radius}
		dome("dome", radius)
	end
	if choice == "bowl" then
		local radius = 0
		if sim_mode == false and cmd_line == false then
			radius = getInput("int","What radius does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			radius = tempProgTable.param1
		end	
		tempProgTable.param1 = radius
		progTable = {param1 = radius}
		dome("bowl", radius)
	end
	if choice == "circle" then
		local radius = 0
		if sim_mode == false and cmd_line == false then
			radius = getInput("int","What radius does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			radius = tempProgTable.param1
		end
		tempProgTable.param1 = radius
		progTable = {param1 = radius}
		circle(radius)
	end
	if choice == "cylinder" then
		local radius = 0
		local height = 0
		if sim_mode == false and cmd_line == false then
			radius = getInput("int","What radius does it need to be?")
			height = getInput("int","How high does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			radius = tempProgTable.param1
			height = tempProgTable.param2
		end
		tempProgTable.param1 = radius
		tempProgTable.param2 = height
		progTable = {param1 = radius, param2 = height}
		cylinder(radius, height)
	end
	if choice == "pyramid" then
		local length = 0
		local hollow = ""
		if sim_mode == false and cmd_line == false then
			length = getInput("int","What depth/width does it need to be?")
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
	if choice == "sphere" then
		local radius = 0
		if sim_mode == false and cmd_line == false then
			radius = getInput("int","What radius does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			radius = tempProgTable.param1
		end
		tempProgTable.param1 = radius
		progTable = {param1 = radius}
		dome("sphere", radius)
	end
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
	if choice == "6-prism" or choice == "6 prism" then
		local length = 0
		local height = 0
		if sim_mode == false and cmd_line == false then
			length = getInput("int","How long does each side need to be?")
			height = getInput("int","What height does it need to be?")
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
			height = getInput("int","What height does it need to be?")
		elseif sim_mode == true or cmd_line == true then
			length = tempProgTable.param1
			height = tempProgTable.param2
		end
		tempProgTable.param1 = length
		tempProgTable.param2 = height
		progTable = {param1 = length, param2 = height}
		eightprism(length, height)
	end
	if returntohome then
		goHome() -- After all shape building has finished
	end
	writeOut("Done") -- Saves a few lines when put here rather than in each if statement
end

function WriteMenu()
	term.clear()
	term.setCursorPos(1, 1)
	writeOut("Shape Maker 1.5 by Keridos/Happydude/pokemane")
	if resupply then					-- Any ideas to make this more compact/betterlooking (in terms of code)?
		writeOut("Resupply Mode Active")
	elseif (resupply and can_use_gps) then
		writeOut("Resupply and GPS Mode Active")
	elseif can_use_gps then
		writeOut("GPS Mode Active")
	else
		writeOut("")
	end
	if not cmd_line then
		writeOut("What should be built? [page 1/2]");
		writeOut("next for page 2")
		writeOut("+---------+-----------+-------+-------+")
		writeOut("| square  | rectangle | wall  | line  |")
		writeOut("| cylinder| platform  | stair | cuboid|")
		writeOut("| pyramid | 1/2-sphere| circle| next  |")
		writeOut("+---------+-----------+-------+-------+")
		writeOut("")
	end
end

function WriteMenu2()
	term.clear()
	term.setCursorPos(1, 1)
	writeOut("Shape Maker 1.5 by Keridos/Happydude/pokemane")
	if resupply then					-- Any ideas to make this more compact/betterlooking (in terms of code)?
		writeOut("Resupply Mode Active")
	elseif (resupply and can_use_gps) then
		writeOut("Resupply and GPS Mode Active")
	elseif can_use_gps then
		writeOut("GPS Mode Active")
	else
		writeOut("")
	end
	writeOut("What should be built [page 2/2]?");
	writeOut("")
	writeOut("+---------+-----------+-------+-------+")
	writeOut("| hexagon | octagon   | help  |       |")
	writeOut("| 6-prism | 8-prism   | end   |       |")
	writeOut("| sphere  | credits   |       |       |")
	writeOut("+---------+-----------+-------+-------+")
	writeOut("")
end

function showHelp()
	writeOut("Usage: shape [shape-type [param1 param2 param3 ...]] [-c] [-h] [-z] [-r]")
	writeOut("-c: Activate cost only mode")
	writeOut("-h: Show this page")
	writeOut("-z: Set chain_next_shape to true, lets you chain together multiple shapes")
	io.read() -- Pause here
	writeOut("-r: Resume the last shape if there is a resume file")
	writeOut("shape-type can be any of the shapes in the menu")
	writeOut("After shape-type input all of the paramaters for the shape")
	io.read() -- Pause here, too
end

function showCredits()
	writeOut("Credits for the shape builder:")
	writeOut("Based on work by Michiel,Vliekkie, and Aeolun")
	writeOut("Sphere/dome code by pruby")
	writeOut("Additional improvements by Keridos,Happydude and pokemane")
	io.read() -- Pause here, too
end

function main()
	if wrapmodules()=="resupply" then
		linkToRSStation()
	end
	if checkCommandLine() then
		if needsHelp() then
			showHelp()
			return -- Close the program after help info is shown
		end
		setFlagsFromCommandLine()
		setTableFromCommandLine()
	end
	if (CheckForPrevious()) then  -- Will check to see if there was a previous job and gps is enabled, and if so, ask if the user would like to re-initialize to current progress status
		if not continueQuery() then -- If the user doesn't want to continue
			ProgressFileDelete()
			setSimFlags(false) -- Just to be safe
			WriteMenu()
			choiceFunction()
		else	-- If the user wants to continue
			setSimFlags(true)
			choiceFunction()
		end
	else
		setSimFlags(false)
		WriteMenu()
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