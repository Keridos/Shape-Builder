-- Variable Setup
local cost_only = false
local sim_mode = false
local blocks = 0
local fuel = 0
local positionx = 0
local positiony = 0
local positionz = 0
local facing = 0
local resupply = 0

local prog_table = {} --this is the LOCAL table!  used for local stuff only, and is ONLY EVER WRITTEN when sim_mode is FALSE
local prog_file_name = "ShapesProgressFile"


-- Utility functions

function writeOut(message)
  print(message)
end

function wraprsmodule() --checks for and wraps rs module
	if peripheral.getType("left")=="resupply" then 
		rs=peripheral.wrap("left")
		resupply = 1
		return true
	elseif peripheral.getType("right")=="resupply" then
		rs=peripheral.wrap("right")
		resupply = 1
		return true
	else
		resupply = 0
		return false
	end
end

function linktorsstation() --links to rs station
	if rs.link() then
		return true
	else
		writeOut("Please put Resupply Station to the left of the turtle and press Enter to continue")
		io.read()
		linktorsstation()
	end
end

function checkResources()
	if resupply == 1 then
		if turtle.getItemCount(activeslot) <= 1 then
			while not(rs.resupply(1)) do
				os.sleep(0.5)
			end
		end
	else
		while turtle.getItemCount(activeslot) <= 0 do
			if activeslot == 16 then
				writeOut("Turtle is empty, please put building block in slots and press enter to continue")
				io.read()
				activeslot = 1
				turtle.select(activeslot)
			else
				activeslot = activeslot+1
				writeOut("Turtle slot empty, trying slot "..activeslot)
				turtle.select(activeslot)
			end
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
	-- Cost calculation mode - don't move
	ProgressUpdate()
	SimulationCheck()
	blocks = blocks + 1
	if cost_only then
		return
	end
	if turtle.detectDown() and not turtle.
	Down() then
		turtle.digDown()
	end
	checkResources()
	turtle.placeDown()
	ProgressUpdate()
	WriteProgress()
end

-- Navigation features
-- allow the turtle to move while tracking its position
-- this allows us to just give a destination point and have it go there

function turnRightTrack()
	ProgressUpdate()
	SimulationCheck()
	facing = facing + 1
	if facing >= 4 then
		facing = 0
	end
	if cost_only then
		return
	end
	turtle.turnRight()
	ProgressUpdate()
	WriteProgress()
end

function turnLeftTrack()
	ProgressUpdate()
	SimulationCheck()
	facing = facing - 1
	if facing < 0 then
		facing = 3
	end
	if cost_only then
		return
	end
	turtle.turnLeft()
	ProgressUpdate()
	WriteProgress()
end

function turnAroundTrack()
	turnLeftTrack()
	turnLeftTrack()
end

function safeForward()
	ProgressUpdate()
	SimulationCheck()
	fuel = fuel + 1
	if cost_only then
		return
	end
	checkFuel()
	success = false
	while not success do
		success = turtle.forward()
		if not success then
			while turtle.detect() do
				if not turtle.dig() then
					print("Blocked attempting to move forward.")
					print("Please clear and press enter to continue.")
					io.read()
				end
			end
		end
	end
end

function safeBack()
	ProgressUpdate()
	SimulationCheck()
	fuel = fuel + 1
	if cost_only then
		return
	end
	checkFuel()
	success = false
	while not success do
		success = turtle.back()
		if not success then
			turnAroundTrack();
			while turtle.detect() do
				if not turtle.dig() then
					break;
				end
			end
			turnAroundTrack()
			success = turtle.back()
			if not success then
				print("Blocked attempting to move back.")
				print("Please clear and press enter to continue.")
				io.read()
			end
		end
	end
end

function safeUp()
	ProgressUpdate()
	SimulationCheck()
	fuel = fuel + 1	
	if cost_only then
		return
	end
	checkFuel()
	success = false
	while not success do
		success = turtle.up()
		if not success then
			while turtle.detectUp() do
				if not turtle.digUp() then
					print("Blocked attempting to move up.")
					print("Please clear and press enter to continue.")
					io.read()
				end
			end
		end
	end
end

function safeDown()
	ProgressUpdate()
	SimulationCheck()
	fuel = fuel + 1
	if cost_only then
		return
	end
	checkFuel()
	success = false
	while not success do
		success = turtle.down()
		if not success then
			while turtle.detectDown() do
				if not turtle.digDown() then
					print("Blocked attempting to move down.")
					print("Please clear and press enter to continue.")
					io.read()
				end
			end
		end
	end
end

function moveY(targety)
	if targety == positiony then
		return
	end
	if (facing ~= 0 and facing ~= 2) then -- check axis
		turnRightTrack()
	end
	while targety > positiony do
		if facing == 0 then
			safeForward()
		else
			safeBack()
		end
		positiony = positiony + 1
		ProgressUpdate()
		WriteProgress()
	end
	while targety < positiony do
		if facing == 2 then
			safeForward()
		else
			safeBack()
		end
		positiony = positiony - 1
		ProgressUpdate()
		WriteProgress()
	end
end

function moveX(targetx)
	if targetx == positionx then
		return
	end
	if (facing ~= 1 and facing ~= 3) then -- check axis
		turnRightTrack()
	end
	while targetx > positionx do
		if facing == 1 then
			safeForward()
		else
			safeBack()
		end
		positionx = positionx + 1
		ProgressUpdate()
		WriteProgress()
	end
	while targetx < positionx do
		if facing == 3 then
			safeForward()
		else
			safeBack()
		end
		positionx = positionx - 1
		ProgressUpdate()
		WriteProgress()
	end
end

--this is unused right now.  Ignore.
function moveZ(targetz) --this function for now, will ONLY be used to CHECK AND RECORD PROGRESS.  It does NOTHING currently because targetz ALWAYS equals positionz
	if targetz == positionz then
		return
	end
	for z = positionz,targetz do
		if targetz>positionz then
			safeUp()
			positionz = positionz + 1
			ProgressUpdate()
			WriteProgress()
		else
			safeDown()
			positionz = positionz - 1
			ProgressUpdate()
			WriteProgress()
	end
end

-- I *HIGHLY* suggest formatting all shape subroutines to use the format that dome() uses;  specifically, navigateTo(x,y,z) placeBlock().  This should ensure proper "data recording" and alos makes readability better
function navigateTo(targetx, targety)  
	if facing == 0 or facing == 2 then -- Y axis
		moveY(targety)
		moveX(targetx)
	else
		moveX(targetx)
		moveY(targety)
	end
end

-- Shape Building Routines

function line(length)
	if length <= 0 then
		error("Error, length can not be 0")
	end
	local i
	for i=1, length do
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
		for j = 1, height-1 do
			safeDown()
		end
	end
	turnLeftTrack()
end

function platform(x, y)
	local forward = true
	for cy = 0, y-1 do
		for cx = 0, x-1 do
			if forward then
				navigateTo(cx, cy)
			else
				navigateTo(x - cx - 1, cy)
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

function stair(width, height)
	turnRightTrack()
	local cx=1
	local cy=0
	local goforward=0
	while cy < height do
		while cx < width do
			placeBlock()
			safeForward()
			cx = cx + 1
		end
		placeBlock()
		cx = 1
		cy = cy + 1
		if cy < height then
			if goforward == 1 then
				turnRightTrack()
				safeUp()
				safeForward()
				turnRightTrack()
				goforward = 0
			else
				turnLeftTrack()
				safeUp()
				safeForward()
				turnLeftTrack()
				goforward = 1
			end
		end
	end
end

function circle(radius)
	radius = tonumber(radius)
	width = radius * 2 + 1
	sqrt3 = 3 ^ 0.5
	boundary_radius = radius + 1.0
	boundary2 = boundary_radius ^ 2
	z = radius
	cz2 = (radius - z) ^ 2
	limit_offset_y = (boundary2 - cz2) ^ 0.5
	max_offset_y = math.ceil(limit_offset_y)
	-- We do first the +x side, then the -x side to make movement efficient
	for side = 0,1 do
		-- On the right we go from small y to large y, on the left reversed
		-- This makes us travel clockwise around each layer
		if (side == 0) then
			ystart = radius - max_offset_y
			yend = radius + max_offset_y
			ystep = 1
		else
			ystart = radius + max_offset_y
			yend = radius - max_offset_y
			ystep = -1
		end
		for y = ystart,yend,ystep do
			cy2 = (radius - y) ^ 2
			remainder2 = (boundary2 - cz2 - cy2)
			if remainder2 >= 0 then
				-- This is the maximum difference in x from the centre we can be without definitely being outside the radius
				max_offset_x = math.ceil((boundary2 - cz2 - cy2) ^ 0.5)
					-- Only do either the +x or -x side
				if (side == 0) then
					-- +x side
					xstart = radius
					xend = radius + max_offset_x
				else
					-- -x side
					xstart = radius - max_offset_x
					xend = radius - 1
				end
				-- Reverse direction we traverse xs when in -y side
				if y > radius then
					temp = xstart
					xstart = xend
					xend = temp
					xstep = -1
				else
					xstep = 1
				end
					for x = xstart,xend,xstep do
					cx2 = (radius - x) ^ 2
					distance_to_centre = (cx2 + cy2 + cz2) ^ 0.5
					-- Only blocks within the radius but still within 1 3d-diagonal block of the edge are eligible
					if distance_to_centre < boundary_radius and distance_to_centre + sqrt3 >= boundary_radius then
						offsets = {{0, 1, 0}, {0, -1, 0}, {1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1}}
						for i=1,6 do
							offset = offsets[i]
							dx = offset[1]
							dy = offset[2]
							dz = offset[3]
							if ((radius - (x + dx)) ^ 2 + (radius - (y + dy)) ^ 2 + (radius - (z + dz)) ^ 2) ^ 0.5 >= boundary_radius then
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
	-- Return to where we started in x,y place and turn to face original direction
	-- Don't change vertical place though - should be solid under us!
	navigateTo(0, 0)
	while (facing > 0) do
		turnLeftTrack()
	end
end

function dome(type, radius)
	type = type
	radius = tonumber(radius)
	-- Main dome and sphere building routine
	width = radius * 2 + 1
	sqrt3 = 3 ^ 0.5
	boundary_radius = radius + 1.0
	boundary2 = boundary_radius ^ 2
	if type == "dome" then
		zstart = radius
	elseif type == "sphere" then
		zstart = 0
	elseif type == "bowl" then
		zstart = 0
	end
	if type == "bowl" then
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
		limit_offset_y = (boundary2 - cz2) ^ 0.5
		max_offset_y = math.ceil(limit_offset_y)
		-- We do first the +x side, then the -x side to make movement efficient
		for side = 0,1 do
			-- On the right we go from small y to large y, on the left reversed
			-- This makes us travel clockwise around each layer
			if (side == 0) then
				ystart = radius - max_offset_y
				yend = radius + max_offset_y
				ystep = 1
			else
				ystart = radius + max_offset_y
				yend = radius - max_offset_y
				ystep = -1
			end
			for y = ystart,yend,ystep do
				cy2 = (radius - y) ^ 2
				remainder2 = (boundary2 - cz2 - cy2)
				if remainder2 >= 0 then
					-- This is the maximum difference in x from the centre we can be without definitely being outside the radius
					max_offset_x = math.ceil((boundary2 - cz2 - cy2) ^ 0.5)
					-- Only do either the +x or -x side
					if (side == 0) then
						-- +x side
						xstart = radius
						xend = radius + max_offset_x
					else
						-- -x side
						xstart = radius - max_offset_x
						xend = radius - 1
					end
					-- Reverse direction we traverse xs when in -y side
					if y > radius then
						temp = xstart
						xstart = xend
						xend = temp
						xstep = -1
					else
						xstep = 1
					end

					for x = xstart,xend,xstep do
						cx2 = (radius - x) ^ 2
						distance_to_centre = (cx2 + cy2 + cz2) ^ 0.5
						-- Only blocks within the radius but still within 1 3d-diagonal block of the edge are eligible
						if distance_to_centre < boundary_radius and distance_to_centre + sqrt3 >= boundary_radius then
							offsets = {{0, 1, 0}, {0, -1, 0}, {1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1}}
							for i=1,6 do
								offset = offsets[i]
								dx = offset[1]
								dy = offset[2]
								dz = offset[3]
								if ((radius - (x + dx)) ^ 2 + (radius - (y + dy)) ^ 2 + (radius - (z + dz)) ^ 2) ^ 0.5 >= boundary_radius then
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
	-- Return to where we started in x,y place and turn to face original direction
	-- Don't change vertical place though - should be solid under us!
	navigateTo(0, 0)
	while (facing > 0) do
		turnLeftTrack()
	end

end

-- Previous Progress Resuming, Sim Functions, and File Backend

-- will check for a "progress" file.
function CheckForPrevious() 
	if fs.exists(prog_file_name) then
		return true
	else
		return false
	end
end

-- creates a progress file, containing a serialized table consisting of the shape type, shape input params, and the last known x, y, and z coords of the turtle (beginning of build project)
function ProgressFileCreate() 
	if CheckForPrevious() then
		fs.makeDir(prog_file_name)
		return true
	else
		return false
	end
end

-- deletes the progress file (at the end of the project, also at beginning if user chooses to delete old progress)
function ProgressFileDelete() 
	if fs.exists(prog_file_name) then
		fs.delete(prog_file_name)
		return true
	else 
		return false
	end
end

-- to read the shape params from the file.  Shape type, and input params (e.g. "dome" and radius)
function ReadShapeParams()
	-- TODO unneeded for now, can just use the table elements directly
end

function WriteShapeParams()
	--TODO
	-- actually can't do anything right now, because all the param-gathering in Choicefunct() uses different variables
end

-- function to write the progress to the file (x, y, z)
function WriteProgress() 
	ProgressFileCreate()
	local prog_file = fs.open(prog_file_name,"w")
	local prog_string = textutils.serialize(prog_table)
	prog_file.write(prog_string)
	prog_file.close()
end

-- reads progress from file (shape, x, y, z, facing, blocks, param1, param2, param3)
function ReadProgress()
	prog_file = fs.open(prog_file_name, "r")
	local temp_prog_table = textutils.unserialize(prog_file.readAll())
	prog_file.close()
	return temp_prog_table
end

-- compares the progress read from the file to the current sim progress.  needs all four params 
function CompareProgress(prog_table_in) -- return boolean
	local temp_prog_table = ReadProgress()
	if prog_table_in.shape == temp_prog_table.shape and prog_table_in.x == temp_prog_table.x and prog_table_in.y == temp_prog_table.y and prog_table_in.blocks == temp_prog_table.blocks and prog_table_in.facing == temp_prog_table.facing then
		writeOut("All caught up!")
		return true -- we're caught up!
	else
		return false -- not there yet...
	end
end

function SetSimFlags(boolean)
	sim_mode = boolean
	cost_only = boolean
end

function SimulationCheck(prog_table_in)  -- DID rename SimulationCheck() for clarity DONE
	if sim_mode then
		if CompareProgress(prog_table_in) then
			SetSimFlags(false) -- if we're caught up, un-set flags
		else
			SetSimFlags(true)  -- if not caught up, just re-affirm that the flags are set
		end
	end
end

function ContinueQuery()
	writeOut("Do you want to continue the last job?")
	local yes = io.read()
	if yes = "y" then
		return true
	else
		return false
	end
end

function ProgressUpdate()  -- this ONLY updates the local table variable.  Writing is handled above.
	prog_table = {x = positionx, y = positiony, facing = facing, blocks = blocks}
end

-- will resume the previous job
function ResumePrevious() -- PLAN:  basically take out io.read()'s, replace "choice = shape" with 
	-- will read the file and extract shape type, params.
	-- will then enter the corresponding build subroutine
	sim_mode = true
	cost_only = true
	local resume_prog_table = ReadProgress()
	local choice = resume_prog_table.shape
	if choice == "rectangle" then -- fixed
		--writeOut("How deep do you want it to be?")
		h = resume_prog_table.param1
		h = tonumber(h)
		--writeOut("How wide do you want it to be?")
		v = resume_prog_table.param2
		v = tonumber(v)
		rectangle(h,v)
	end
	if choice == "square" then 
		--writeOut("How long does it need to be?")
		local s = resume_prog_table.param1
		s = tonumber(s)
		square(s)
	end
	if choice == "line" then 
		--writeOut("How long does the line need to be?")
		local ll = resume_prog_table.param1
		ll = tonumber(ll)
		line(ll)
	end
	if choice == "wall" then 
		--writeOut("How long does it need to be?")
		local wl = resume_prog_table.param1
		wl = tonumber(wl)
		--writeOut("How high does it need to be?")
		local wh = resume_prog_table.param2
		wh = tonumber(wh)
		if  wh <= 0 then
			error("Error, the height can not be zero")
		end
		if wl <= 0 then
			error("Error, the length can not be 0")
		end
		wall(wl, wh)
	end
	if choice == "platform" then
		--writeOut("How wide do you want it to be?")
		x = resume_prog_table.param1
		x = tonumber(x)
		--writeOut("How long do you want it to be?")
		y = resume_prog_table.param2
		y = tonumber(y)
		platform(x, y)
		writeOut("Done")
	end
	if choice == "stair" then 
		--writeOut("How wide do you want it to be?")
		x = resume_prog_table.param1
		x = tonumber(x)
		--writeOut("How high do you want it to be?")
		y = resume_prog_table.param2
		y = tonumber(y)
		stair(x, y)
		--writeOut("Done")
	end
	if choice == "room" then
		--writeOut("How deep does it need to be?")
		local cl = resume_prog_table.param1
		cl = tonumber(cl)
		--writeOut("How wide does it need to be?")
		local ch = resume_prog_table.param2
		ch = tonumber(ch)
		--writeOut("How high does it need to be?")
		local hi = resume_prog_table.param3
		hi = tonumber(hi)
		if hi < 3 then
			hi = 3
		end
		if cl < 3 then
			cl = 3
		end
		if ch < 3 then
			ch = 3
		end
		platform(cl, ch)
		while (facing > 0) do
			turnLeftTrack()
		end
		turnAroundTrack()
		if ((ch % 2)==0) then
			-- this is for reorienting the turtle to build the walls correct in relation to the floor and ceiling
			turnLeftTrack()
		end
		for i = 1, hi-2 do
			safeUp()
			if ((ch % 2)==0) then -- this aswell
			rectangle(cl, ch)
			else
			rectangle(ch, cl)
			end
		end
		safeUp()
		platform(cl, ch)
	end
	if choice == "dome" then --fixed
		--writeOut("What radius do you need it to be?")
		local rad = resume_prog_table.param1
		rad = tonumber(rad)
		dome("dome", rad)
	end
	if choice == "sphere" then
		--writeOut("What radius do you need it to be?")
		local rad = resume_prog_table.param1
		rad = tonumber(rad)
		dome("sphere", rad)
	end
	if choice == "circle" then
		--writeOut("What radius do you need it to be?")
		local rad = resume_prog_table.param1
		rad = tonumber(rad)
		circle(rad)
	end
	if choice == "cylinder" then
		--writeOut("What radius do you need it to be?")
		local rad = resume_prog_table.param1
		rad = tonumber(rad)
		--writeOut("What height do you need it to be?")
		local height = resume_prog_table.param2
		height = tonumber(height)
		for i = 1, height do
			circle(rad)
			safeUp()
		end
		for i = 1, height do
			safeDown()
		end
	end
	if choice == "pyramid" then
		--writeOut("What width/depth do you need it to be?")
		local width = resume_prog_table.param1
		width = tonumber(width)
		--writeOut("Do you want it to be hollow [y/n]?")
		local hollow = resume_prog_table.param2
		if hollow == 'y' then
			hollow = true
		else
			hollow = false
		end
		height = math.ceil(width / 2)
		for i = 1, height do
			if hollow then
				rectangle(width, width)
			else
				platform(width, width)
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
				width = width - 2
			end
		end
	end
end


-- Menu and Mainfunctions

function Choicefunct()
	if sim_mode = false then -- if we are NOT resuming progress
		local choice = io.read()
		prog_table = {shape = choice}
		writeOut("Building a "..choice)
		writeOut("Want to just calculate the cost? [y/n]")
		local yes = io.read()
		if yes == 'y' then
			cost_only = true
		end
	elseif sim_mode = true then -- if we ARE resuming progress
		local resume_prog_table = ReadProgress()
		local choice = resume_prog_table.shape
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
	end
	
	if choice == "rectangle" then
		if sim_mode = false then
			writeOut("How deep do you want it to be?")
			local h = io.read()
			writeOut("How wide do you want it to be?")
			local v = io.read()
		elseif sim_mode = true then
			local h = resume_prog_table.param1
			local v = resume_prog_table.param2
		end
		h = tonumber(h)
		v = tonumber(v)
		prog_table = {param1 = h, param2 = v}  -- THIS is here because we NEED to update the local table!
		rectangle(h, v)
	end
	if choice == "square" then
		if sim_mode = false then
			writeOut("How long does it need to be?")
			s = io.read()
		elseif sim_mode = true then
			s = resume_prog_table.param1
		s = tonumber(s)
		prog_table = {param1 = s}
		square(s)
	end
	if choice == "line" then
		if sim_mode = false then
			writeOut("How long does the line need to be?")
			local ll = io.read()
		elseif sim_mode = true then
			local ll = resume_prog_table.param1
		end
		ll = tonumber(ll)
		prog_table = {param1 = ll}
		line(ll)
	end
	if choice == "wall" then
		if sim_mode = false then
			writeOut("How long does it need to be?")
			local wl = io.read()
			writeOut("How high does it need to be?")
			local wh = io.read()
			if  wh <= 0 then
				error("Error, the height can not be zero")
			end
			if wl <= 0 then
				error("Error, the length can not be 0")
			end
		elseif sim_mode = true then
			local wl = resume_prog_table.param1
			local wh = resume_prog_table.param2
		end			
		wl = tonumber(wl)
		wh = tonumber(wh)
		prog_table {param1 = wl, param2 = wh}
		wall(wl, wh)
	end
	if choice == "platform" then
		if sim_mode = false then
			writeOut("How wide do you want it to be?")
			local x = io.read()
			writeOut("How long do you want it to be?")
			local y = io.read()
		elseif sim_mode = true then
			local x = resume_prog_table.param1	
			local y = resume_prog_table.param2		
		end		
		x = tonumber(x)
		y = tonumber(y)
		prog_table {param1 = x, param2 = y}
		platform(x, y)
		writeOut("Done")
	end
	if choice == "stair" then
		if sim_mode = true then
			writeOut("How wide do you want it to be?")
			local x = io.read()
			writeOut("How high do you want it to be?")
			local y = io.read()
		elseif sim_mode = false then
			local x = resume_prog_table.param1
			local y = resume_prog_table.param2
		end
		x = tonumber(x)
		y = tonumber(y)
		prog_table {param1 = x, param2 = y}
		stair(x, y)
		writeOut("Done")
	end
	if choice == "room" then
		if sim_mode = false then
			writeOut("How deep does it need to be?")
			local cl = io.read()
			writeOut("How wide does it need to be?")
			local ch = io.read()
			writeOut("How high does it need to be?")
			local hi = io.read()
			if hi < 3 then
				hi = 3
			end
			if cl < 3 then
				cl = 3
			end
			if ch < 3 then
				ch = 3
			end
		elseif sim_mode = true then
			local cl = resume_prog_table.param1
			local ch = resume_prog_table.param2
			local hi = resume_prog_table.param3
		end
		cl = tonumber(cl)
		ch = tonumber(ch)
		hi = tonumber(hi)		
		prog_table = {param1 = cl, param2 = ch, param3 = hi}
		platform(cl, ch)		
		while (facing > 0) do
			turnLeftTrack()
		end
		turnAroundTrack()
		if ((ch % 2)==0) then
			-- this is for reorienting the turtle to build the walls correct in relation to the floor and ceiling
			turnLeftTrack()
		end
		for i = 1, hi-2 do
			safeUp()
			if ((ch % 2)==0) then -- this aswell
			rectangle(cl, ch)
			else
			rectangle(ch, cl)
			end
		end
		safeUp()
		platform(cl, ch)
	end
	if choice == "dome" then
		if sim_mode = false then
			writeOut("What radius do you need it to be?")
			local rad = io.read()
			writeOut("What half of the sphere do you want to build?(bottom/top)")
			local half = io.read()
		elseif sim_mode = true then
			local rad = resume_prog_table.param1
			local half = resume_prog_table.param2
		end			
		rad = tonumber(rad)
		prog_table = {param1 = rad, param2 = half}
		if half == "bottom" then
			dome("bowl", rad)
		else
			dome("dome", rad)
		end
	end
	if choice == "sphere" then
		if sim_mode = false then
			writeOut("What radius do you need it to be?")
			local rad = io.read()
		elseif sim_mode = true then
			local rad = resume_prog_table.param1
		end
		rad = tonumber(rad)
		prog_table {param1 = rad}
		dome("sphere", rad)
	end
	if choice == "circle" then
		if sim_mode = false then
			writeOut("What radius do you need it to be?")
			local rad = io.read()
		elseif sim_mode = false then
			local rad = resume_prog_table.param1
		end
		rad = tonumber(rad)
		prog_table {param1 = rad}
		circle(rad)
	end
	if choice == "cylinder" then
		if sim_mode = false then
			writeOut("What radius do you need it to be?")
			local rad = io.read()
			writeOut("What height do you need it to be?")
			local height = io.read()
		elseif sim_mode = true then
			local rad = resume_prog_table.param1
			local height = resume_prog_table.param2
		end
		rad = tonumber(rad)
		height = tonumber(height)
		prog_table {param1 = rad, param2 = height}
		for i = 1, height do
			circle(rad)
			safeUp()
		end
		for i = 1, height do
			safeDown()
		end
	end
	if choice == "pyramid" then
		writeOut("What width/depth do you need it to be?")
		local width = io.read()
		width = tonumber(width)
		writeOut("Do you want it to be hollow [y/n]?")
		local hollow = io.read()
		prog_table = {param1 = width, param2 = hollow}
		if hollow == 'y' then
			hollow = true
		else
			hollow = false
		end
		height = math.ceil(width / 2)
		for i = 1, height do
			if hollow then
				rectangle(width, width)
			else
				platform(width, width)
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
				width = width - 2
			end
		end
	end
end

function WriteMenu()
	writeOut("Shape Maker 1.4 by Michiel/Vliekkie/Aeolun/pruby/Keridos")
	if resupply==1 then
		writeOut("Resupply Mode Active")
	else
		writeOut("")
	end
	writeOut("");
	writeOut("What should be built?")
	writeOut("+---------+-----------+-------+-------+")
	writeOut("| line    | rectangle | wall  | room  |")
	writeOut("| square  | platform  | stair | dome  |")
	writeOut("| pyramid | cylinder  | circle| sphere|")
	writeOut("+---------+-----------+-------+-------+")
	writeOut("")
end

function main()
	if wraprsmodule() then
		linktorsstation()
	end
	if CheckForPrevious() then  -- will check to see if there was a previous job, and if so, ask if the user would like to re-initialize to current progress status
		if not ContinueQuery() then -- if I don't want to continue
			WriteMenu()
			SetSimFlags(false) -- just to be safe
			Choicefunct()
		else	-- if I want to continue
			SetSimFlags(true)
			ChoiceFunct()
		end
	else
		WriteMenu()
		Choicefunct()
	end
	print("Blocks used: " .. blocks)
	print("Fuel used: " .. fuel)
	ProgressFileDelete() -- removes file upon successful completion of a job, or completion of a previous job.
end

main()
