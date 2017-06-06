#pragma rtGlobals=1		// Use modern global access method

//	Driver communicates over serial, remember to set the DAC board number in InitBabyDAC() and the serial port in SetSerialPort()
//	Has interactive window like BabyDAC Procedures, but the driver is much more flexible.
//	Supports up to four DAC boards
//	Procedure written by Christian, 2016-0X-XX
//    Updated by Nik for binary control, ADC reading, and software limits

///// Initiate DAC board(s) /////

function InitBabyDACs(b1, [b2, b3, b4, range])
	variable b1, b2, b3, b4, range
	
	// set DAC output range
	if(ParamIsDefault(range))
		range=2
	endif
	SetChannelRange(range) // set to 1 for +-10V or 2 for +-5V
	
	CheckForOldInit() // Will update the user window to the last known values.
	
	// handle board numbering
	if(ParamIsDefault(b2))
		b2=nan
	endif
	if(ParamIsDefault(b3))
		b3=nan
	endif
	if(ParamIsDefault(b4))
		b4=nan
	endif
	SetBoardNumbers(b1, b2=b2, b3=b3, b4=b4) // Set the boards numbers of the used boards.
	
	DACSetup() // setup DAC com port
	
	variable /g bd_ramprate = 200 // default ramprate
	
	// open window
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
	// setup software limit
	string out
	nvar bd_range_high, bd_range_low
	out = num2str(max(abs(bd_range_high), abs(bd_range_low)))

	// Init all channels to 0V.
	make/t/o dacvalsstr = {{"0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15"},{"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"}, {out, out, out, out, out, out, out, out, out, out, out, out, out, out, out, out}}
	make/t/o oldvalue = {{"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"}}

end

function AskUser()
	wave/t dacvalsstr=dacvalsstr
	variable/g bd_answer
	make /o attinitlist = {{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}}
	make /o/t/n=16 oldinit
	make /o/t/n=16 defaultinit = {"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"}
	make /o/t/n=(16,2) initwave
	oldinit = dacvalsstr[p][1]
	initwave[0,15][1] = defaultinit[p]
	initwave[0,15][0] = oldinit[p]
	execute("AskUserWindow()")
	PauseForUser AskUserWindow
	return bd_answer
end

function SetSerialPort()
	svar bd_comport
	execute("VDTOperationsPort2 $bd_comport")
end

function DACSetup()
	SetSerialPort()
	execute("VDT2 baud=57600, databits=8, stopbits=1, parity=0, killio") // Communication Settings
end

function SetChannelRange(range_index)
	variable range_index
	variable/g bd_range_high, bd_range_low, bd_range_span
	if(range_index == 1)
		bd_range_low = -10000
		bd_range_high = 10000
	elseif(range_index == 2)
		bd_range_low = -5000
		bd_range_high = 5000
	else
		abort "Not a valid range! Set to 1 for +-10V or 2 for +-5V"
	endif
	bd_range_span = abs(bd_range_low-bd_range_high)
end

function SetBoardNumbers(b1,[b2,b3,b4])
	// Leave board numbers blank or NaN if not all 4 boards are used.
	// First board will have channels 0-3, second baord will have channels 4-7,
	// third board will have channels 8-11, fourth board will have channels 12-15
	variable b1,b2,b3,b4
	wave/t dacvalsstr=dacvalsstr
	make/o listboxattr = {{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},{2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0}, {2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0}}
	if(ParamIsDefault(b2) || numtype(b2)==2)
		b2 = nan
		
		dacvalsstr[4] = "0"
		dacvalsstr[5] = "0"
		dacvalsstr[6] = "0"
		dacvalsstr[7] = "0"
	else
		listboxattr[4][1] = 2
		listboxattr[5][1] = 2
		listboxattr[6][1] = 2
		listboxattr[7][1] = 2
		
		listboxattr[4][2] = 2
		listboxattr[5][2] = 2
		listboxattr[6][2] = 2
		listboxattr[7][2] = 2
	endif
	if(ParamIsDefault(b3) || numtype(b3)==2)
		b3 = nan
		
		dacvalsstr[8] = "0"
		dacvalsstr[9] = "0"
		dacvalsstr[10] = "0"
		dacvalsstr[11] = "0"
	else
		listboxattr[8][1] = 2
		listboxattr[9][1] = 2
		listboxattr[10][1] = 2
		listboxattr[11][1] = 2
		
		listboxattr[8][2] = 2
		listboxattr[9][2] = 2
		listboxattr[10][2] = 2
		listboxattr[11][2] = 2
	endif
	if(ParamIsDefault(b4) || numtype(b4)==2)
		b4 = nan
		
		dacvalsstr[12] = "0"
		dacvalsstr[13] = "0"
		dacvalsstr[14] = "0"
		dacvalsstr[15] = "0"
	else
		listboxattr[12][1] = 2
		listboxattr[13][1] = 2
		listboxattr[14][1] = 2
		listboxattr[15][1] = 2
		
		listboxattr[12][2] = 2
		listboxattr[13][2] = 2
		listboxattr[14][2] = 2
		listboxattr[15][2] = 2
	endif
	make/o boardnumbers = {{b1,b2,b3,b4}}
end

//// Keep track of channel/board numbers ////
	
function CheckForBoard(board_number)
	variable board_number
	variable i=0, found_board = 0
	wave boardnumbers = boardnumbers
	do
		if(boardnumbers[i]==board_number)
			return 1
		endif
		i+=1
	while(i<numpnts(boardnumbers))
	return 0
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

//// UTILITY ////

function ResetStartupVoltageBD(board_number)
	// sometimes you will find that when a board is powered on 
	// all of the output voltages are -5V or -10V
	// this command will reset that default so the board powers on at 0V
	variable board_number
	variable setpoint

	ClearBufferBD()

	// set all channels to 0V
	setpoint = GetSetpointBD(0.0) // DAC setpoint as an integer
	print setpoint
	
	// build output 0V command
	variable id_byte, alt_id_byte, command_byte, parity_byte
	variable data_byte_1, data_byte_2, data_byte_3
	
	id_byte = 0xc0+board_number // 11{gggggg}, g = board number
	alt_id_byte = 0x40+board_number // id_byte with MSB = 0
	
	data_byte_1 = (setpoint & 0xfc000)/0x4000 // 00{aaaaaa}, a = most significant 6 bits
	data_byte_2 = (setpoint & 0x3f80)/0x80 // 0{bbbbbbb}, b = middle 7 bits
	data_byte_3 = (setpoint & 0x7f) // 0{ccccccc}, c = least significant 7 bits

	variable i = 0
	for(i=0;i<4;i+=1)
		command_byte = 0x40+i // 010000{hh}, h = channel number
		parity_byte=alt_id_byte%^command_byte%^data_byte_1%^data_byte_2%^data_byte_3 // XOR all previous bytes
		make/o bd_cmd_wave={id_byte, command_byte, data_byte_1, data_byte_2, data_byte_3, parity_byte, 0}
	
		// send command to DAC
		SetSerialPort()
		execute "VDTWriteBinaryWave2 /O=10 bd_cmd_wave"
	
		// read the response from the buffer
		ReadBytesBD(7)
		sleep /s 0.3
	endfor

	// backup settings to non-volatile memory
	command_byte = 0x8 // 00001000
	parity_byte=alt_id_byte%^command_byte // XOR all previous bytes
	make/o bd_cmd_wave={id_byte, command_byte, parity_byte, 0}
	
	// send command to DAC
	SetSerialPort()
	execute "VDTWriteBinaryWave2 /O=10 bd_cmd_wave"
	
	// read the response from the buffer
	print ReadBytesBD(4) 
	
	sleep /s 0.3
end

//// SET and RAMP outputs ////
	
function GetSetpointBD(output)
	variable output
	NVAR bd_range_low,bd_range_high,bd_range_span
	variable frac
	// calculate fraction of full output
	frac = (output-bd_range_low)/bd_range_span
	// convert to 20 bit number
	return round((2^20-1)*frac)
end	
	
function SetOutputBD(channel, output)
	variable output // in mV
	variable channel // 0 to 15
	wave boardnumbers=boardnumbers
	wave/t dacvalsstr=dacvalsstr
	wave/t oldvalue=oldvalue
	NVAR bd_range_span, bd_range_high, bd_range_low
	variable board,board_channel,setpoint,sw_limit
	
	// Check that the DAC board is initialized
	CheckDACBoard(channel)
	
	// Check that the voltage is valid
	if(output > bd_range_high || output < bd_range_low)
		string err
		sprintf err, "voltage out of DAC range, %.3fmV", output
		abort err
	endif
	
	// check that the voltage is within software limits
	// if it is outside the limit, do not interrupt
	// set output to maximum value according to limits
	sw_limit = str2num(dacvalsstr[channel][2])
	if(abs(output) > sw_limit)
		if(output > 0)
			output = sw_limit
		else
			output = -1*sw_limit
		endif
	endif

	board = GetBoard(channel) // which DAC that channel number is on
	board_channel = GetBoardChannel(channel) // which channel of that board 
	
	setpoint = GetSetpointBD(output) // DAC setpoint as an integer
	
	// build output command
	variable id_byte, alt_id_byte, command_byte, parity_byte
	variable data_byte_1, data_byte_2, data_byte_3
	
	id_byte = 0xc0+board // 11{gggggg}, g = board number
	alt_id_byte = 0x40+board // id_byte with MSB = 0
	command_byte = 0x40+board_channel // 010000{hh}, h = channel number
	
	data_byte_1 = (setpoint & 0xfc000)/0x4000 // 00{aaaaaa}, a = most significant 6 bits
	data_byte_2 = (setpoint & 0x3f80)/0x80 // 0{bbbbbbb}, b = middle 7 bits
	data_byte_3 = (setpoint & 0x7f) // 0{ccccccc}, c = least significant 7 bits

	parity_byte=alt_id_byte%^command_byte%^data_byte_1%^data_byte_2%^data_byte_3 // XOR all previous bytes
	
	make/o bd_cmd_wave={id_byte, command_byte, data_byte_1, data_byte_2, data_byte_3, parity_byte, 0}
	
	// send command to DAC
	SetSerialPort()
	execute "VDTWriteBinaryWave2 /O=10 bd_cmd_wave"
	
	// read the response from the buffer
	ReadBytesBD(7) // does not seem to slow things down significantly
					 // prevents the buffer from over filling with crap
	
	// Update stored values
	dacvalsstr[channel][1] = num2str(output)
	oldvalue[channel][1] = num2str(output)
	return 1
end

function RampOutputBD(channel, output, [ramprate, noupdate])
	variable channel, output,ramprate, noupdate // output is in mV, ramprate in mV/s
	wave/t dacvalsstr=dacvalsstr
	wave /t oldvalue=oldvalue
	variable voltage, sgn, step
	variable sleeptime // seconds per ramp cycle (must be at least 0.002)
	
	// calculate step direction
	voltage = str2num(oldvalue[channel][1])
	sgn = sign(output-voltage)
	
	if(paramisdefault(noupdate))
		noupdate = 0
	endif
	
	if(noupdate==0)
		// pauseupdate
		sleeptime = 0.01 // account for screen-update delays
	else
		pauseupdate
		sleeptime = 0.002 // can ramp finely if there's no updating!
	endif
	
	if(paramisdefault(ramprate))
		nvar bd_ramprate
		ramprate = bd_ramprate 
	endif
	
	step = ramprate*sleeptime

	voltage+=sgn*step
	if(sgn*voltage >= sgn*output)
		//// we started less than one step away from the target. set voltage and leave
		SetOutputBD(channel, output)
		return 1
	endif
	
	variable starttime, endtime

	starttime = stopmstimer(-2)
	do
		if(!noupdate)
			doupdate
		endif
		SetOutputBD(channel, voltage)

		endtime = starttime + 1e6*sleeptime
		do
		while(stopmstimer(-2) < endtime)
		starttime = stopmstimer(-2)

		voltage+=sgn*step
	while(sgn*voltage<sgn*output-step)
	SetOutputBD(channel, output)
	
	if(noupdate!=0)
		resumeupdate
	endif
	
	return 1
end

function UpdateMultipleBD([action, ramprate, noupdate])

	// usage:
	// function Experiment(....)
	//         ...
	//         wave /t dacvalsstr = dacvalsstr // this wave keeps track of new DAC values
	//         dacvalsstr[channelA][1] = num2str(1000) // set new values with a strings
	//         dacvalsstr[channelB][1] = num2str(-500)
	//         UpdateMultipleBD(action="ramp") // ramps all channels to updated values
	
	string action // "set" or "ramp"
	variable ramprate, noupdate
	wave/t dacvalsstr=dacvalsstr
	wave/t oldvalue=oldvalue
	variable output,i
	variable check = nan

	if(ParamIsDefault(action))
		action="ramp"
	endif
	
	if(paramisdefault(ramprate))
		nvar bd_ramprate
		ramprate = bd_ramprate    // (mV/s)
	endif
	
	if(paramisdefault(noupdate))
		noupdate=0
	endif

	for(i=0;i<16;i+=1)
		if(str2num(dacvalsstr[i][1]) != str2num(oldvalue[i][1]))
			output = str2num(dacvalsstr[i][1])
			strswitch(action)
				case "set":
					check = SetOutputBD(i,output)
				case "ramp":
					check = RampOutputBD(i,output,ramprate=ramprate, noupdate=noupdate)
			endswitch
			if(check == 1)
				oldvalue[i][1] = dacvalsstr[i][1]
			else
				dacvalsstr[i][1] = oldvalue[i][1]
			endif
		endif
	endfor
	return 1
end

function RampMultipleBD(channels, setpoint, nChannels, [ramprate, noupdate])
	variable setpoint, nChannels, ramprate, noupdate
	string channels
	variable i, channel
	wave /t dacvalsstr = dacvalsstr

	if(paramisdefault(ramprate))
		nvar bd_ramprate
		ramprate = bd_ramprate    // (mV/s)
	endif
	
	if(paramisdefault(noupdate))
		noupdate = 0	
	endif
	
	for(i=0;i<nChannels;i+=1)
		channel = str2num(StringFromList(i, channels, ","))
		dacvalsstr[channel][1] = num2str(setpoint) // set new values with a strings
	endfor
	UpdateMultipleBD(action="ramp", ramprate=ramprate, noupdate = noupdate)
end

///// ACD readings /////

function BD_Reading2Voltage()
	wave bd_response_wave
	variable a, b, c, int_reading // declare a bunch of integers
	variable frac, volts // should be floats
	variable /g bd_adc_low=-2500, bd_adc_high=2500
	a = bd_response_wave[2] * 2^14
	b = bd_response_wave[3] * 2^7
	c = bd_response_wave[4]
	int_reading = a+b+c
	
    	frac = int_reading/(2^21-1)
    	// print frac
       volts = (frac*(bd_adc_high-bd_adc_low)+bd_adc_low)
       // printf "Reading = %.7f", volts
       return volts
end

function ReadBytesBD(bytes)
	// creates a wave of 8 bit integers with a given number of bytes //
	variable bytes // number of bytes to read
	string response // response string
	string cmd
	NVAR V_VDT
	
	// read serial port here
	make /O/B/U/N=(bytes) bd_response_wave
	SetSerialPort()
	cmd="VDTReadBinaryWave2 /O=1.0 /Q bd_response_wave"
	execute (cmd)
	
	if(V_VDT == 0)
		abort "Failed to read"
	endif
	
	return 1
end

Function ClearBufferBD()
	// probably smart to put this at the beginning of any script that reads the ADC //
	string cmd
	string /g bd_response
	NVAR V_VDT
	SetSerialPort()
	do
		cmd="VDTReadBinary2 /O=1.0 /S=1/Q bd_response"
		execute (cmd)
		print bd_response
	while(V_VDT)
end

function ReadADCBD(channel, board_number)
	// you can only get a new reading here once every 300ms //
	// it is left to the user to figure out how to time things correctly //
	variable channel // 1 or 2
	variable board_number // which babydac board
	variable channel_bit
	variable reading
	
	// check if board is initialized
	if(CheckForBoard(board_number)!=1)
		string err
		sprintf err, "BabyDAC %d is not connected", board_number
		abort err
	endif
	
	if(channel==1)
		channel_bit = 0
	elseif(channel==2)
		channel_bit = 2
	else
		abort "pick a valid input channel, 1 or 2"
	endif
	
	// build  command
	variable id_byte, alt_id_byte, command_byte, parity_byte
	variable data_byte_1, data_byte_2, data_byte_3
	wave bd_response_wave=bd_response_wave
	
	id_byte = 0xc0+board_number // 11{gggggg}, g = board number
	alt_id_byte = 0x40+board_number // id_byte with MSB = 0
	
	command_byte = 0x60+(channel_bit) // 011000{h}0, h=0 for channel 1, 1 for channel 2
	
	data_byte_1 = 0 // 00{aaaaaa}, a = most significant 6 bits
	data_byte_2 = 0 // 0{bbbbbbb}, b = middle 7 bits
	data_byte_3 = 0 // 0{ccccccc}, c = least significant 7 bits

	parity_byte=alt_id_byte%^command_byte%^data_byte_1%^data_byte_2%^data_byte_3 // XOR all previous bytes
	
	make/o bd_cmd_wave={id_byte, command_byte, data_byte_1, data_byte_2, data_byte_3, parity_byte, 0}
	
	// send command to babydac
	SetSerialPort()
	execute "VDTWriteBinaryWave2 /O=10 bd_cmd_wave"
	
	// read response
	do
		ReadBytesBD(7) // reads into bd_response_wave
		// print bd_response_wave
	while(bd_response_wave[1]!=bd_cmd_wave[1]) // stop when the right response comes back
	
	// get the reading out of that mess
	reading = BD_Reading2Voltage()

	return reading
end

///// User interface /////

Window BabyDACWindow() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(0,0,320,530) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 90, 45,"BabyDAC" // Headline
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 12,85,"CHANNEL"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 108,85,"VOLT (mV)"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 208,85,"LIM (mV)"
	ListBox daclist,pos={10,90},size={300,370},fsize=16,frame=2 // interactive list
	ListBox daclist,fStyle=1,listWave=root:dacvalsstr,selWave=root:listboxattr,mode= 1
	Button ramp,pos={40,490},size={65,20},proc=update_BabyDAC,title="RAMP"
	Button rampallzero,pos={170,490},size={90,20},proc=update_BabyDAC,title="RAMP ALL 0"
EndMacro

function update_BabyDAC(action) : ButtonControl
	string action
	wave/t dacvalsstr=dacvalsstr
	wave/t oldvalue=oldvalue
	variable output,i
	variable check = nan
	controlinfo /W=BabyDACWindow daclist
	
	strswitch(action)
		case "ramp":
			for(i=0;i<16;i+=1)
				if(str2num(dacvalsstr[i][1]) != str2num(oldvalue[i][1]))
					output = str2num(dacvalsstr[i][1])
					check = RampOutputBD(i,output)
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
				check = RampOutputBD(i, 0)
				if(check==1)
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
	variable/g bd_answer
	strswitch(action)
		case "oldinit":
			bd_answer = 1
			dowindow/k AskUserWindow
			break
		case "defaultinit":
			bd_answer = -1
			dowindow/k AskUserWindow
			break
	endswitch
end

//// Status String for Logging ////

function/s GetDACStatus()
	string winfcomments="", buffer=""
	wave /t dacvalsstr = dacvalsstr
	wave boardnumbers = boardnumbers

	winfcomments += "BabyDAC:\r\t"

	variable i=0, j=0
	variable dacval
	do
		if(numtype(boardnumbers[i])==0)
			for(j=0;j<4;j+=1)
				sprintf buffer, "CH%d = %s mV\r\t", (4*i+j), dacvalsstr[4*i+j][1]
				winfcomments+=buffer
			endfor
		endif
		i+=1
	while(i<numpnts(boardnumbers))	
	return winfcomments
end

//// testing ////
function testBabyDACramprate(start, fin, channels, ramprate, noupdate)
	string channels
	variable start, fin, ramprate, noupdate
	variable nChannels = ItemsInList(channels, ",")

	RampMultipleBD(channels, start, nChannels, ramprate=ramprate, noupdate=0)
	
	print "ramping..."
	variable ttotal = 0, tstart = datetime
	RampMultipleBD(channels, fin, nChannels, ramprate=ramprate, noupdate=noupdate)
	ttotal = datetime - tstart
	printf "the effective ramprate is: %.1fmV/s\n", abs(fin-start)/ttotal
	
end

//// for backwards compatibility ////

// for the record, the names of these functions are way too ambiguous, 
// which is why they were changed in this procedure

//function setvolts(channel, mV)
//	variable channel, mV
//	SetOutputBD(channel, mV)
//end
//
//function rampvolts(channel, mV, [ramprate, noupdate])
//	variable channel, mV, ramprate, noupdate
//	
//	if(paramisdefault(ramprate))
//		nvar bd_ramprate
//		ramprate = bd_ramprate    // (mV/s)
//	endif
//	
//	if(paramisdefault(noupdate))
//		RampOutputBD(channel, mV, ramprate=ramprate)
//	else
//		RampOutputBD(channel, mV, ramprate=ramprate, noupdate=noupdate)
//	endif
//end