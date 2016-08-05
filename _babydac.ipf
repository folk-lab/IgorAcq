#pragma rtGlobals=1		// Use modern global access method.

//	Driver communicates over serial, remember to set the DAC board number in InitBabyDAC() and the serial port in SetSerialPort()
//	Has interactive window like BabyDAC Procedures, but the driver is much more flexible.
//	Supports up to four DAC boards
//	Procedure written by Christian, 2016-0X-XX

///// Initiate DAC board(s) /////

function InitBabyDACs()
CheckForOldInit() // Will update the user window to the last known values.
SetBoardNumbers(7,b2=8) // Set the boards numbers of the used boards.
DACSetup()
SetChannelRange(1) // set to 1 for +-10V or 2 for +-5V
dowindow /k BabyDACWindow
execute("BabyDACWindow()")
end

function CheckForOldInit()
	variable response
	if(WaveExists(dacvalsstr) && WaveExists(oldvalue))
		response = AskUser()
		if(response == 1)
			// Init at old values
			print "Init to old values"
		elseif(response == -1)
			// Init to Zero
			InitToZero()
			print "Init all channels to 0V"
		else
			print "Something went wrong, will init to defualt"
			InitToZero()
		endif
	else
		// Init to Zero
		InitToZero()
		print "Init all channels to 0V"
	endif
end

function InitToZero()
	// Init all channels to 0V.
	make/t/o dacvalsstr = {{"0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15"},{"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"}}
	make/t/o oldvalue = {{"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"}}
end

function AskUser()
	wave/t dacvalsstr=dacvalsstr
	variable/g answer
	make /o attinitlist = {{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}}
	make /o/t/n=16 oldinit
	make /o/t/n=16 defaultinit = {"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"}
	make /o/t/n=(16,2) initwave
	oldinit = dacvalsstr[p][1]
	initwave[0,15][1] = defaultinit[p]
	initwave[0,15][0] = oldinit[p]
	execute("AskUserWindow()")
	PauseForUser AskUserWindow
	return answer
end

function SetSerialPort()
	string/g comport = "COM19" // Set to the right COM Port
	string cmd
	sprintf cmd, "VDTOperationsPort2 %s", comport
	execute(cmd)
end

function DACSetup()
	string cmd
	SetSerialPort()
	sprintf cmd, "VDT2 baud=57600, databits=8, stopbits=1, parity=0, killio" // Communication Settings
	execute(cmd)
end

function SetChannelRange(range_index)
	variable range_index
	variable/g range_high,range_low,range_span
	if(range_index == 1)
		range_low = -10000
		range_high = 10000
	elseif(range_index == 2)
		range_low = -5000
		range_high = 5000
	else
		abort "Not a valid range! Set to 1 for +-10V or 2 for +-5V"
	endif
	range_span = abs(range_low-range_high)
end

function SetBoardNumbers(b1,[b2,b3,b4])
	// Leave board numbers blank if not all 4 boards are used.
	// First board will have channels 0-3, second baord will have channels 4-7,
	// third board will have channels 8-11, fourth board will have channels 12-15
	variable b1,b2,b3,b4
	make/o listboxattr = {{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},{2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0}}
	if(ParamIsDefault(b2))
		b2 = nan
	else
		listboxattr[4][1] = 2
		listboxattr[5][1] = 2
		listboxattr[6][1] = 2
		listboxattr[7][1] = 2
	endif
	if(ParamIsDefault(b3))
		b3 = nan
	else
		listboxattr[8][1] = 2
		listboxattr[9][1] = 2
		listboxattr[10][1] = 2
		listboxattr[11][1] = 2
	endif
	if(ParamIsDefault(b4))
		b4 = nan
	else
		listboxattr[12][1] = 2
		listboxattr[13][1] = 2
		listboxattr[14][1] = 2
		listboxattr[15][1] = 2
	endif
	make/o boardnumbers = {{b1,b2,b3,b4}}
end

///// Talk to DAC boards /////

	//// Base functions ////
	
function SetOutput(output,channel)
	variable output // in mV
	variable channel // 0 to 15
	wave boardnumbers=boardnumbers
	wave/t dacvalsstr=dacvalsstr
	wave/t oldvalue=oldvalue
	NVAR range_span
	NVAR range_high
	NVAR range_low
	string cmd
	variable board,board_channel,setpoint
	// Check that the DAC board is initialized
	CheckDACBoard(channel)
	// Check that the requiested output is with the range
	if(abs(output) > range_high)
		printf "The output can't be set to more than +-%d mV", range_high
		return -1
	endif
	board = GetBoard(channel)
	board_channel = GetBoardChannel(channel)
	setpoint = GetSetpoint(output)
	// Set the output
	sprintf cmd, "B%d;C%d;D%d;",board,board_channel,setpoint 
	WriteDac(cmd)
	// Update the window
	dacvalsstr[channel][1] = num2str(output)
	oldvalue[channel][1] = num2str(output)
	return 1
end
	
function CheckDACBoard(channel)
	variable channel
	wave boardnumbers=boardnumbers
	variable index
	string err
	index = floor(channel/4)
	if(boardnumbers[index] == nan)
		sprintf err, "Board %d is not defined!", index
		abort err
	endif
end

function GetBoard(channel)
	variable channel
	variable index
	wave boardnumbers=boardnumbers
	index =floor(channel/4)
	return boardnumbers[index] 
end

function GetBoardChannel(channel)
	variable channel
	variable index
	index = mod(channel,4)
	return index
end

function GetSetpoint(output)
	variable output
	NVAR range_low,range_high,range_span
	variable frac
	// calculate fraction of full output
	frac = (output-range_low)/range_span
	// convert to 20 bit number
	return round((2^20-1)*frac)
end	

	//// Advanceds functions ////

function RampOutput(output,channel,[ramprate])
	variable channel,output,ramprate // output in mV and ramprate in mV/s
	wave/t dacvalsstr=dacvalsstr
	wave/t oldvalue=oldvalue
	variable sleeptime,current_output,stepsize,new_output,check,sgn
	NVAR range_high
	if(abs(output) > range_high)
		printf "The output can't be set to more than +-%d mV\r", range_high
		return -1
	endif
	if(paramisdefault(ramprate))
		ramprate = 100 //mV/sec
	endif
	sleeptime = 0.015 // allow for window to update
	current_output = str2num(oldvalue[channel][1])
	stepsize = ramprate*sleeptime // default 7.5mV 
	sgn = sign(output-current_output)
	if(abs(output-current_output) <= stepsize)
		// We are within one stepsize of the final output. Just set the final value.
		check = SetOutput(output,channel)
		return check
	endif
	new_output = current_output
	
	do
		doupdate
		new_output += sgn*stepsize
		sleep/s sleeptime
		check = SetOutput(new_output,channel)
	while(abs(output-new_output) > stepsize)
	// Set the last step, if needed
	check = SetOutput(output,channel)
	return check
end

///// DAC communication /////

function WriteDAC(command)
	string command
	string cmd,response
	NVAR V_VDT
	
	// Insert serial communication commands
	SetSerialPort()
	sprintf cmd, "VDTWrite2 /O=2 /Q\"%s\"\n",command
	execute(cmd)
	if(V_VDT == 0)
		abort "Write failed on command "+cmd
	endif
end

function/s ReadDAC()
	string response
	string cmd
	NVAR V_VDT
	
	sprintf cmd, "VDTRead2 /O=2 /Q response"
	execute(cmd)
	if(V_VDT == 0)
		abort "Failed to read"
	endif
	return response
end

///// User interface /////

Window BabyDACWindow() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(0,0,300,530) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 90, 45,"BabyDAC" // Headline
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 40,80,"CHANNEL"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 170,80,"VOLT (mV)"
	ListBox daclist,pos={10,90},size={280,390},fsize=16,frame=2 // interactive list
	ListBox daclist,fStyle=1,listWave=root:dacvalsstr,selWave=root:listboxattr,mode= 1
	Button ramp,pos={40,490},size={65,20},proc=update_BabyDAC,title="RAMP"
	Button rampallzero,pos={170,490},size={90,20},proc=update_BabyDAC,title="RAMP ALL 0"
EndMacro

function update_BabyDAC(action) : ButtonControl
	string action
	wave/t dacvalsstr=dacvalsstr
	wave/t oldvalue=oldvalue
	variable check,output,i
	controlinfo /W=BabyDACWindow daclist
	strswitch(action)
		case "ramp":
			for(i=0;i<16;i+=1)
				if(str2num(dacvalsstr[i][1]) != str2num(oldvalue[i][1]))
					output = str2num(dacvalsstr[i][1])
					check = RampOutput(output,i)
					if(check == 1)
						oldvalue[i][1] = dacvalsstr[i][1]
					else
						dacvalsstr[i][1] = oldvalue[i][1]
					endif
				endif
			endfor
			break
		case "rampallzero":
			for(i=0;i<16;i+=1)
				check = RampOutput(0,i)
				if(check)
					oldvalue[i][1] = dacvalsstr[i][1]
				endif
			endfor
			break
	endswitch
end

Window AskUserWindow() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(100,100,400,630) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 20, 45,"Choose BabyDAC init" // Headline
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 40,80,"Old init"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 170,80,"Default"
	ListBox initlist,pos={10,90},size={280,390},fsize=16,frame=2
	ListBox initlist,fStyle=1,listWave=root:initwave,selWave=root:attinitlist,mode= 0
	Button oldinit,pos={40,490},size={70,20},proc=AskUserUpdate,title="OLD INIT"
	Button defaultinit,pos={170,490},size={70,20},proc=AskUserUpdate,title="DEFAULT"
EndMacro

function AskUserUpdate(action) : ButtonControl
	string action
	variable/g answer
	strswitch(action)
		case "oldinit":
			answer = 1
			dowindow/k AskUserWindow
			break
		case "defaultinit":
			answer = -1
			dowindow/k AskUserWindow
			break
	endswitch
end