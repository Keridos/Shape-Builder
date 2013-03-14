cost_only = false
blocks = 0
fuel = 0

positionx = 0
positiony = 0
facing = 0

function writeOut(message)
  print(message)
end

function checkResources()
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
	blocks = blocks + 1
	if cost_only then
		return
	end

	if turtle.detectDown() and not turtle.compareDown() then
		turtle.digDown()
	end

	checkResources()

	turtle.placeDown()
end

-- Navigation features
-- allow the turtle to move while tracking its position
-- this allows us to just give a destination point and have it go there

function turnRightTrack()
	if cost_only then
		return
	end

	turtle.turnRight()
	facing = facing + 1
	if facing >= 4 then
		facing = 0
	end
end

function turnLeftTrack()
	if cost_only then
		return
	end

	turtle.turnLeft()
	facing = facing - 1
	if facing < 0 then
		facing = 3
	end
end

function turnAroundTrack()
	turnLeftTrack()
	turnLeftTrack()
end

function safeForward()
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
	end

	while targety < positiony do
		if facing == 2 then
			safeForward()
		else
			safeBack()
		end
		positiony = positiony - 1
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
	end

	while targetx < positionx do
		if facing == 3 then
			safeForward()
		else
			safeBack()
		end
		positionx = positionx - 1
	end
end

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
	turnRightTrack()
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

	-- Main dome and sphere building routine

	width = radius * 2 + 1
	sqrt3 = 3 ^ 0.5
	boundary_radius = radius + 1.0
	boundary2 = boundary_radius ^ 2

	zstart = radius

	-- This loop is for each vertical layer through the sphere or dome.
	for z = zstart,zstart do
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
	end
	zend = width - 1

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

writeOut("Shape Maker 1.1. Created by Michiel using a bit of Vliekkie's code")
writeOut("Fixed and made readable by Aeolun ;)")
writeOut("Additional Fixes and moved to GitHub by Keridos/Git Hub Commits");
writeOut("");
writeOut("What should be built?")
writeOut("+---------+-----------+-------+-------+")
writeOut("| line    | rectangle | wall  | room  |")
writeOut("| square  | platform  | stair | dome  |")
writeOut("| pyramid | cylinder  | circle| sphere|")
writeOut("+---------+-----------+-------+-------+")
writeOut("")

local choice = io.read()
writeOut("Building a "..choice)
writeOut("Want to just calculate the cost? [y/n]")
local yes = io.read()
if yes == 'y' then
	cost_only = true
end
if not cost_only then
	turtle.select(1)
	activeslot = 1
	if turtle.getItemCount(activeslot) == 0 then
		writeOut("Please put building blocks in the first slot (and more if you need them)")
		while turtle.getItemCount(activeslot) == 0 do
			os.sleep(2)
		end
	end
end
if choice == "rectangle" then -- fixed
	writeOut("How deep do you want it to be?")
	h = io.read()
	h = tonumber(h)
	writeOut("How wide do you want it to be?")
	v = io.read()
	v = tonumber(v)
	rectangle(h, v)
end
if choice == "square" then --fixed
	writeOut("How long does it need to be?")
	local s = io.read()
	s = tonumber(s)
	square(s)
end
if choice == "line" then --fixed
	writeOut("How long does the line need to be?")
	local ll = io.read()
	ll = tonumber(ll)
	line(ll)
end
if choice == "wall" then --fixed
	writeOut("How long does it need to be?")
	local wl = io.read()
	wl = tonumber(wl)
	writeOut("How high does it need to be?")
	local wh = io.read()
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
	writeOut("How wide do you want it to be?")
	x = io.read()
	x = tonumber(x)
	writeOut("How long do you want it to be?")
	y = io.read()
	y = tonumber(y)
	platform(x, y)
	writeOut("Done")
end
if choice == "stair" then --fixed
	writeOut("How wide do you want it to be?")
	x = io.read()
	x = tonumber(x)
	writeOut("How high do you want it to be?")
	y = io.read()
	y = tonumber(y)
	stair(x, y)
	writeOut("Done")
end
if choice == "room" then
	writeOut("How deep does it need to be?")
	local cl = io.read()
	cl = tonumber(cl)
	writeOut("How wide does it need to be?")
	local ch = io.read()
	ch = tonumber(ch)
	writeOut("How high does it need to be?")
	local hi = io.read()
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
if choice == "dome" then
	writeOut("What radius do you need it to be?")
	local rad = io.read()
	rad = tonumber(rad)
	dome("dome", rad)
end
if choice == "sphere" then
	writeOut("What radius do you need it to be?")
	local rad = io.read()
	rad = tonumber(rad)
	dome("sphere", rad)
end
if choice == "circle" then
	writeOut("What radius do you need it to be?")
	local rad = io.read()
	rad = tonumber(rad)
	circle(rad)
end
if choice == "cylinder" then
	writeOut("What radius do you need it to be?")
	local rad = io.read()
	rad = tonumber(rad)
	writeOut("What height do you need it to be?")
	local height = io.read()
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
	writeOut("What width/depth do you need it to be?")
	local width = io.read()
	width = tonumber(width)
	writeOut("Do you want it to be hollow [y/n]?")
	local hollow = io.read()
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

print("Blocks used: " .. blocks)
print("Fuel used: " .. fuel)
