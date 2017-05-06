#pragma rtGlobals=1		// Use modern global access method

// Figure out how to deal with device responses

function InitZaber()
	variable/g xmax, ymax,xposition=0,yposition=0,curposx,curposy,pos1x=0,pos1y=0,pos2x=0,pos2y=0,pos3x=0,pos3y=0
	string/g unitx="micro step",unity="micro step",relabsx = "abs",relabsy = "abs"
	
	// Max position in microsteps
	xmax = 1066667
	ymax = 1066667
	
	// Setup serial communication
	SetSerialPortZaber()
	VDT2 baud=115200, databits=8, stopbits=1, parity=0, terminalEOL=1, killio
	
	sleep/s 1
	// Home all
	HomeZaber()
	
	//create Interface window
	dowindow/k ZaberWindow
	execute("ZaberWindow()")
end

function SetSerialPortZaber()
	string/g comport_zaber = "usbserial-AL00BUXW"
	VDTOperationsPort2 $comport_zaber
end

function HomeZaber()
	string cmd
	
	cmd = "/home"
	WriteZaber(cmd)
	
	UpdatePositionZaber()
end

function UnloadZaber()
	string cmd
	
	cmd="/move max"
	WriteZaber(cmd)
	
	UpdatePositionZaber()
end

function MoveCenterZaber()
	nvar xmax
	variable xcenter, ycenter
	
	xcenter = round(xmax/2.0)
	ycenter = 494057
	
	MoveXMicrosteps(xcenter, "abs")
	MoveYMicrosteps(ycenter, "abs")
	
	UpdatePositionZaber()
end

function StopZaber()
	string cmd
	
	cmd = "/estop"
	WriteZaber(cmd)

	UpdatePositionZaber()
end

function MoveXMicrosteps(xpos, absrel)
	variable xpos
	string absrel
	string cmd
	
	if(stringmatch(absrel,"!abs") && stringmatch(absrel,"!rel"))
		abort("Must specific if movement is abs or rel")
	endif
	
	if(xpos < 0 && stringmatch(absrel,"!rel"))
		Abort("You have to move in reletive coordinates")
	endif
	
	sprintf cmd, "/2 move %s %d", absrel, xpos
	WriteZaber(cmd)
end

function MoveYMicrosteps(ypos, absrel)
	variable ypos
	string absrel
	string cmd
	
	if(stringmatch(absrel,"!abs") && stringmatch(absrel,"!rel"))
		abort("Must specific if movement is abs or rel")
	endif
	
	if(ypos < 0 && stringmatch(absrel,"!rel"))
		Abort("You have to move in reletive coordinates")
	endif
	
	sprintf cmd, "/3 move %s %d", absrel, ypos
	WriteZaber(cmd)
end

function MoveXZaber(xpos,[unit,absrel]) // unit: {mm, in, mstep}, absrel: {abs, rel}
	variable xpos
	string unit, absrel
	variable mstepPos
	string cmd
	
	if(paramisdefault(unit))
		unit = "mm"
	endif
	
	if(paramisdefault(absrel))
		AbsRel = "abs"
	endif
	
	mstepPos = ConvertToMStep(xpos,unit)
	MoveXMicrosteps(mstepPos,absrel)
	
	UpdatePositionZaber()
end

function MoveYZaber(ypos,[unit,absrel]) // unit: {mm, in, mstep}, absrel: {abs, rel}
	variable ypos
	string unit, absrel
	variable mstepPos
	string cmd
	
	if(paramisdefault(unit))
		unit = "mm"
	endif
	
	if(paramisdefault(absrel))
		AbsRel = "abs"
	endif
	
	mstepPos = ConvertToMStep(ypos,unit)
	MoveYMicrosteps(mstepPos,absrel)

	UpdatePositionZaber()
end


//// Communication ////

function WriteZaber(cmd)
	string cmd
	string command, response
	
	SetSerialPortZaber()
	// Write command
	command = cmd+"\n"
	VDTWrite2 /O=0.5 command
end

function/s ReadZaber()
	string response
	
	SetSerialPortZaber()
	// Read response
	VDTRead2 /Q /O=0.5/T="\n" response
	return response
end

//// Util ////

function ConvertToMStep(pos,unit)
	variable pos
	string unit
	variable mstepPos, intomm
	nvar xmax
	
	strswitch(unit)
		case "mm":
			mstepPos = round(xmax/50.0*pos)
			break
		case "in":
			intomm = 50.0/25.4
			mstepPos = round(xmax/intomm*pos)
			break
		case "micro step":
			mstepPos = pos
			break
		default:
			Abort("Not a valid unit")
	endswitch
	
	if(abs(mstepPos) > xmax)
		Abort("Trying to move out of range")
	endif
	
	return mstepPos
end

function ReadAllHistory()
	nvar v_vdt
	string response
	do
			response = ReadZaber()
	while(strlen(response) > 0)
end

function UpdatePositionZaber()
	nvar curposx, curposy
	string cmdx,cmdy, xanswer, yanswer, statusx, statusy
	
	// Clear buffer
	ReadAllHistory()
	
	do
		cmdx = "/2 get pos"
		cmdy = "/3 get pos"
		WriteZaber(cmdx)
		xanswer = ReadZaber()
		WriteZaber(cmdy)
		yanswer = ReadZaber()
		sscanf xanswer, "@02 0 OK %s -- %d", statusx, curposx
		sscanf yanswer, "@03 0 OK %s -- %d", statusy, curposy
		doupdate
		sleep/s 0.5
	while(stringmatch(statusx,"BUSY") || stringmatch(statusy,"BUSY"))
end

//// Interface ////

window ZaberWindow() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(0,0,370,300) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 150, 45,"Zaber"
	Button home, pos={10,50}, size={80,20},title="Home",proc=home_button
	Button unload, pos={100,50}, size={80,20},title="Unload",proc=unload_button
	Button center, pos={190,50}, size={80,20},title="Center",proc=center_button
	Button stop, pos={280,50}, size={80,20},title="Stop",proc=stop_button
	DrawText 40,100, "\\Z14Position"
	DrawText 160,100,"\\Z14Unit"
	SetVariable xpos, pos={10,103}, size={110,50},value=xposition,title=" ",limits={-xmax,xmax,0}
	PopupMenu unitx, pos={130,100},size={100,50},title="",mode=3,value=("mm;in;micro step"),proc=unitx_set
	PopupMenu relabsx, pos={230,100},size={100,50},title="",mode=1,value=("abs;rel"),proc=relabsx_set
	Button movex, pos={290,100},size={70,20},title="Move X",proc=movex_button
	DrawText 40,150, "\\Z14Position"
	DrawText 160,150,"\\Z14Unit"
	SetVariable ypos, pos={10,153}, size={110,50},value=yposition,title=" ",limits={-xmax,xmax,0}
	PopupMenu unity, pos={130,150},size={100,50},title="",mode=3,value=("mm;in;micro step"),proc=unity_set
	PopupMenu relabsy, pos={230,150},size={100,50},title="",mode=1,value=("abs;rel"),proc=relabsy_set
	Button movey, pos={290,150},size={70,20},title="Move Y",proc=movey_button
	DrawText 75, 200, "\\Z14Current position [micro step]"
	SetVariable curposx, pos={30,210}, size={110,50},value=curposx,title="\\Z14X:",disable=2,limits={-xmax,xmax,0}
	SetVariable curposy, pos={200,210}, size={110,50},value=curposy,title="\\Z14Y:",disable=2,limits={-ymax,ymax,0}
	Button setpos1, pos={30,230}, size={80,20},title="Set pos 1",proc=pos1_button
	Button setpos2, pos={120,230}, size={80,20},title="Set pos 2",proc=pos2_button
	Button setpos3, pos={210,230}, size={80,20},title="Set pos 3",proc=pos3_button
	Button recall1, pos={30,260}, size={80,20},title="Recall 1",proc=recall1_button
	Button recall1, pos={120,260}, size={80,20},title="Recall 2",proc=recall2_button
	Button recall1, pos={210,260}, size={80,20},title="Recall 3",proc=recall3_button
endmacro

function home_button(action) : Buttoncontrol
	string action
	
	HomeZaber()
end

function unload_button(action) : Buttoncontrol
	string action
	
	UnloadZaber()
end

function stop_button(action) : Buttoncontrol
	string action
	
	StopZaber()
end

function center_button(action) : Buttoncontrol
	string action
	
	MoveCenterZaber()
end

function movex_button(action) : Buttoncontrol
	string action
	nvar xposition
	svar unitx,relabsx
	MoveXZaber(xposition,unit=unitx,absrel=relabsx)
end

function movey_button(action) : Buttoncontrol
	string action
	nvar yposition
	svar unity,relabsy
	MoveYZaber(yposition,unit=unity,absrel=relabsy)
end

function unitx_set(action,popnum,popstr) : PopupMenuControl
	string action
	variable popnum
	string popstr
	svar unitx
	
	unitx = popstr
end

function unity_set(action,popnum,popstr) : PopupMenuControl
	string action
	variable popnum
	string popstr
	svar unity
	
	unity = popstr
end

function relabsx_set(action,popnum,popstr) : PopupMenuControl
	string action
	variable popnum
	string popstr
	svar relabsx
	
	relabsx = popstr
end

function relabsy_set(action,popnum,popstr) : PopupMenuControl
	string action
	variable popnum
	string popstr
	svar relabsy
	
	relabsy = popstr
end

function setpos1_button(action) : Buttoncontrol
	string action
	nvar pos1x,pos1y, curposx, curposy
	
	UpdatePositionZaber()
	pos1x = curposx
	pos1y = curposy
end

function setpos2_button(action) : Buttoncontrol
	string action
	nvar pos2x,pos2y, curposx, curposy
	
	UpdatePositionZaber()
	pos2x = curposx
	pos2y = curposy
end

function setpos3_button(action) : Buttoncontrol
	string action
	nvar pos3x,pos3y, curposx, curposy
	
	UpdatePositionZaber()
	pos3x = curposx
	pos3y = curposy
end

function recall1_button(action) : Buttoncontrol
	string action
	nvar pos1x,pos1y
	
	MoveXMicrosteps(pos1x, "abs")
	MoveYMicrosteps(pos1y, "abs")
end

function recall2_button(action) : Buttoncontrol
	string action
	nvar pos2x,pos2y
	
	MoveXMicrosteps(pos2x, "abs")
	MoveYMicrosteps(pos2y, "abs")
end

function recall3_button(action) : Buttoncontrol
	string action
	nvar pos3x,pos3y
	
	MoveXMicrosteps(pos3x, "abs")
	MoveYMicrosteps(pos3y, "abs")
end