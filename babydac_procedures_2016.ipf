#pragma rtGlobals=1		// Use modern global access method

//	Driver communicates over serial, remember to set the DAC board number in InitBabyDAC() and the serial port in SetSerialPort()
//	Has interactive window like BabyDAC Procedures, but the driver is much more flexible.
//	Supports up to four DAC boards
//	Procedure written by Christian, 2016-0X-XX
//    Updated by Nik for binary control, ADC reading, and software limits

///// Initiate DAC board(s) /////

function InitBabyDACs(boards, ranges, [custom])
	// boards and ranges should be a comma separated list.
	// custom should be set to 1 if you want to bring up the custom
	// babydac window as well.
	
	// ranges: 
	//     1010 = -10 to +10
	//     55 = -5 to +5
	//     05 = 0 to +5
	//     50 = -5 to 0
	//     010 = 0 to +10
	//     100 = -10 to 0
	// if all boards have the same range, you can pass just one number
	// otherwise number of boards must equal number of ranges given
	
	string boards, ranges
	variable custom
	variable /g bd_ramprate = 200 // default ramprate
	
	if(paramisdefault(custom))
		custom = 0
	endif
	
	DACSetup() // setup DAC com port
	SetBoardNumbers(boards,custom) // handle board numbering
	
	SetChannelRange(ranges) // set DAC output ranges
	
	CheckForOldInit(custom) // Will update the user window to the last known values.
	
	// open window
	dowindow /k BabyDACWindow
	execute("BabyDACWindow()")
	
	if(custom)
		dowindow /k CustomDACWindow
		execute("CustomDACWindow()")
	endif
end

function CheckForOldInit(custom)
	variable custom
	variable response
	nvar numCustom
	
	if(WaveExists(dacvalsstr) && WaveExists(oldvalue))
		response = AskUser()
		if(response == 1)
			// Init at old values
			print "Init to old values"
			if(custom)
				CreateCustomWaves(1)
				CalcCustomValues()
			endif
		elseif(response == -1)
			// Init to Zero
			InitToZero()
			if(custom)
				CreateCustomWaves(0)
				CalcCustomValues()
			endif
			print "Init all channels to 0V"
		else
			print "Something went wrong, will init to defualt"
			InitToZero()
			if(custom)
				CreateCustomWaves(0)
				CalcCustomValues()
			endif
		endif
	else
		// Init to Zero
		InitToZero()
		if(custom)
			CreateCustomWaves(0)
			CalcCustomValues()
		endif
		print "Init all channels to 0V"
	endif
end

function CalcCustomValues()
	nvar numCustom
	wave/t dacvalsstr
	wave/t customdacvalstr
	wave bdtocustom_vec
	wave customtobd_vec
	wave offsets
	wave oldcustom
	variable i
	
	make/o/n=(numCustom) customoutput = nan
	make/o/n=(numCustom) bdoutput = nan
	make/o/n=(numCustom) scalefunc = nan
	make/o/n=(numCustom) offset = nan
	bdoutput = str2num(dacvalsstr[p][1])
	for(i=0;i<numCustom;i=i+1)
		scalefunc = bdtocustom_vec[p][i]
		offset = offsets[p][i]
		matrixop/o placeholder = (scalefunc.(bdoutput + offset))
		customoutput[i] = placeholder[0]
	endfor
	oldcustom = customoutput[p]
	customdacvalstr[][1] = num2str(customoutput[p])
end

function InitToZero()
	wave bd_boardnumbers
	nvar numCustom
	
	// Init all channels to 0V.
	make/t/o dacvalsstr = {{"0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15"},{"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"}, {"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"}}
	make/t/o oldvalue = {{"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"}}

	// setup software limit
	variable i = 0, board_index = 0
	wave bd_range_high, bd_range_low
	for(i=0; i<16; i+=1)
		board_index = floor(i/4)
		if(numtype(bd_boardnumbers[board_index])==0)
			dacvalsstr[i][2] = num2str(max(abs(bd_range_high[board_index]), abs(bd_range_low[board_index])))
		endif
	endfor
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

function SetBoardNumbers(boards,custom)
	// Leave board numbers blank or NaN if not all 4 boards are used.
	// First board will have channels 0-3, second baord will have channels 4-7,
	// third board will have channels 8-11, fourth board will have channels 12-15
	string boards
	variable custom
	variable numBoards = ItemsInList(boards, ",")
	variable/g numCustom = 0
	wave/t dacvalsstr=dacvalsstr
	
	make/o listboxattr = {{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},{2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0}, {2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0}}
	
	switch(numBoards)
		case 1:
			make/o bd_boardnumbers = {{str2num(StringFromList(0, boards, ",")),nan,nan,nan}}
		case 2:
			make/o bd_boardnumbers = {{str2num(StringFromList(0, boards, ",")),str2num(StringFromList(1, boards, ",")),nan,nan}}
		case 3:
			make/o bd_boardnumbers = {{str2num(StringFromList(0, boards, ",")),str2num(StringFromList(1, boards, ",")),str2num(StringFromList(2, boards, ",")),nan}}
		case 4:
			make/o bd_boardnumbers = {{str2num(StringFromList(0, boards, ",")),str2num(StringFromList(1, boards, ",")),str2num(StringFromList(2, boards, ",")),str2num(StringFromList(3, boards, ","))}}
	endswitch
	
	if(custom)
		numCustom += 4
	endif
	
	if(numtype(bd_boardnumbers[1])==2)
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
		
		if(custom)
			numCustom += 4
		endif
	endif
	
	if(numtype(bd_boardnumbers[2])==2)
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
		
		if(custom)
			numCustom += 4
		endif
	endif
	
	if(numtype(bd_boardnumbers[3])==2)
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
		
		if(custom)
			numCustom += 4
		endif
	endif
end

function CreateCustomWaves(keepold)
	variable keepold
	string customname = "ABCDEFGHIJKLMNOP", default_vec ="", specific_vec = "", offset_vec = ""
	variable i
	nvar numCustom
	
	make/o/n=(numCustom,3) customlistboxattr = 2
	
	if(keepold && waveexists(customdacvalstr))
		print("BabyDAC is initialized to old values.")
		print("Remember to update the scale functions and channel names in the Custom window.")
	else
		make/o/n=(numCustom) oldcustom = 0
	endif
	make/o/t/n=(numCustom,3) customdacvalstr
	for(i=0;i<numCustom;i=i+1)
		default_vec = addlistitem("0",default_vec,",")
		offset_vec = addlistitem("0",offset_vec,",")
	endfor
	offset_vec = "("+offset_vec[0,strlen(offset_vec)-2]+")"
	for(i=0;i<numCustom;i=i+1)
		specific_vec = removelistitem(i,default_vec,",")
		specific_vec = addlistitem("1",specific_vec,",",i)
		specific_vec = "("+specific_vec[0,strlen(specific_vec)-2]+")"
		customdacvalstr[i][0] = customname[i]
		customdacvalstr[i][1] = ""
		customdacvalstr[i][2] = specific_vec+";"+offset_vec+";"+"CH"+num2istr(i)
	endfor
	CreateVectors()
end

function CreateVectors()
	wave/t customdacvalstr
	nvar numCustom
	string vector
	variable i,j
	
	make/t/o/n=(numCustom) textplaceholder
	make/o/n=(numCustom) numplaceholder
	make/o/n=(numCustom,numCustom) bdtocustom_vec = nan
	make/o/n=(numCustom,numCustom) customtobd_vec = nan
	make/o/n=(numCustom,numCustom) offsets = nan
	for(i=0;i<numCustom;i=i+1)
		vector = stringfromlist(0,customdacvalstr[i][2])
		vector = vector[1,strlen(vector)-2]
		textplaceholder = StringFromList(p, vector, ",")
		numplaceholder = str2num(textplaceholder)
		bdtocustom_vec[][i] = numplaceholder[p]
		
		vector = stringfromlist(1,customdacvalstr[i][2])
		vector = vector[1,strlen(vector)-2]
		textplaceholder = StringFromList(p, vector, ",")
		numplaceholder = str2num(textplaceholder)
		offsets[][i] = numplaceholder[p]
	endfor
	for(i=0;i<numCustom;i=i+1)
		for(j=0;j<numCustom;j=j+1)
			customtobd_vec[i][j] = 1.0/bdtocustom_vec[i][j]
		endfor
	endfor
end

function SetChannelRange(ranges)
	string ranges
	variable numRanges = ItemsInList(ranges, ",")
	wave bd_boardnumbers = bd_boardnumbers
	variable numBoards = 0, i=0
	do
		if(numtype(bd_boardnumbers[i])==0)
			numBoards += 1
		endif
		i += 1
	while(i<numpnts(bd_boardnumbers))

	make /O/N=4 bd_range_high = nan
	make /O/N=4 bd_range_low = nan
	make /O/N=4 bd_range_span = nan

	// make sure I have as many ranges as I do boards
	if(numRanges != numBoards)
		if(numRanges == 1)
			// create new range list with correct number of elements
			string rng = StringFromList(0, ranges, ",")
			ranges = ""
			for(i=0; i<numBoards; i+=1)
				ranges += rng+","
			endfor
			ranges = ranges[0,strlen(ranges)-2] // drop last comma
			numRanges = numBoards
		else
			abort "Length of ranges list must equal 1 or length of boards list"
		endif
	endif

	rng = ""
	for(i=0; i<numBoards; i+=1)
		rng = StringFromList(i, ranges, ",")
		strswitch(rng)
    		case "1010": // -10 to +10
    			bd_range_high[i] = 10000
    			bd_range_low[i] = -10000
    			break
    		case "010":  // 0 to +10
    			bd_range_high[i] = 10000
    			bd_range_low[i] = 0
    			break
     		case "100":  // -10 to 0
     			bd_range_high[i] = 0
    			bd_range_low[i] = -10000
    			break
     		case "55":   // -5 to +5
     			bd_range_high[i] = 5000
    			bd_range_low[i] = -5000
    			break
     		case "05":   // 0 to +5
     			bd_range_high[i] = 5000
    			bd_range_low[i] = 0
    			break
     		case "50":   // -5 to 0
				bd_range_high[i] = 0
    			bd_range_low[i] = -5000
    			break
		endswitch
		bd_range_span[i] = abs(bd_range_low[i]-bd_range_high[i])
	endfor

end

//// Keep track of channel/board numbers ////
	
function CheckForBoard(board_number)
	variable board_number
	variable i=0, found_board = 0
	wave bd_boardnumbers = bd_boardnumbers
	do
		if(bd_boardnumbers[i]==board_number)
			return 1
		endif
		i+=1
	while(i<numpnts(bd_boardnumbers))
	return 0
end
	
function CheckDACBoard(channel)
	variable channel
	wave bd_boardnumbers=bd_boardnumbers
	variable index
	string err
	index = floor(channel/4)
	if(bd_boardnumbers[index] == nan)
		sprintf err, "Board %d is not defined!", index
		abort err
	else
		return bd_boardnumbers[index]
	endif
end

function GetBoard(channel)
	variable channel
	variable index
	wave bd_boardnumbers=bd_boardnumbers
	index =floor(channel/4)
	return bd_boardnumbers[index] 
end

function GetBoardChannel(channel)
	variable channel
	variable index
	index = mod(channel,4)
	return index
end

//// UTILITY ////

function MakeAllZeroBD()
	// ramp all gates to +/-10mV
	
	wave bd_boardnumbers, bd_range_high
	variable numCh = 0, i=0, idxBrd
	
	do
		if(numtype(bd_boardnumbers[i])==0)
			numCh += 4
		endif
		i += 1
	while(i<numpnts(bd_boardnumbers))
	
	print "Set all channels to +/-10mV."
	
	for(i=0;i<numCh;i+=1)
		idxBrd =floor(i/4)
		if(bd_range_high[idxBrd] > 0)
			RampOutputBD(i, 10.0)
		else
			RampOutputBD(i, -10.0)
		endif
	endfor
	
	sc_sleep(2.0)
	print "Set all channels back to 0mV."
	
	for(i=0;i<numCh;i+=1)
		RampOutputBD(i, 0.0)
	endfor
	
end

function ResetStartupVoltageBD(board_number, range)
	// sometimes you will find that when a board is powered on 
	// all of the output voltages are non-zero
	// this command will reset that default so the board powers on at 0V
	
	// ranges: 
	//     1010 = -10 to +10
	//     55 = -5 to +5
	//     05 = 0 to +5
	//     50 = -5 to 0
	//     010 = 0 to +10
	//     100 = -10 to 0
	
	variable board_number
	string range
	variable setpoint, frac

	ClearBufferBD()

	strswitch(range)
		case "1010": // -10 to +10
			frac = (0.0-(-10000))/20000
			break
		case "010":  // 0 to +10
			frac = (0.0-(0))/10000
			break
 		case "100":  // -10 to 0
			frac = (0.0-(-10000))/10000
			break
 		case "55":   // -5 to +5
			frac = (0.0-(-5000))/10000
			break
 		case "05":   // 0 to +5
			frac = (0.0-(0))/5000
			break
 		case "50":   // -5 to 0
			frac = (0.0-(-5000))/5000
			break
	endswitch
			
	setpoint = round((2^20-1)*frac)
	
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
		sc_sleep(0.3)
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
	
	sc_sleep(0.3)
end

//// SET and RAMP outputs ////
	
function GetSetpointBD(channel, output)
	variable channel, output
	wave bd_range_low, bd_range_high, bd_range_span
	variable frac = 0, board_index = floor(channel/4)
	
	// calculate fraction of full output
	frac = (output-bd_range_low[board_index])/bd_range_span[board_index]
	// convert to 20 bit number
	return round((2^20-1)*frac)
end	
	
function SetOutputBD(channel, output)
	variable output // in mV
	variable channel // 0 to 15
	wave bd_boardnumbers=bd_boardnumbers
	wave/t dacvalsstr=dacvalsstr
	wave/t oldvalue=oldvalue
	wave bd_range_span, bd_range_high, bd_range_low
	variable board_index, board, board_channel, setpoint, sw_limit
	
	// Check that the DAC board is initialized
	CheckDACBoard(channel)
	board_index = floor(channel/4)
	
	// Check that the voltage is valid
	if(output > bd_range_high[board_index] || output < bd_range_low[board_index])
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
	
	setpoint = GetSetpointBD(channel, output) // DAC setpoint as an integer
	
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

function RampOutputBD(channel, output, [ramprate, update])
	variable channel, output,ramprate, update // output is in mV, ramprate in mV/s
	wave/t dacvalsstr=dacvalsstr
	wave /t oldvalue=oldvalue
	variable voltage, sgn, step
	variable sleeptime // seconds per ramp cycle (must be at least 0.002)
	
	// calculate step direction
	voltage = str2num(oldvalue[channel][1])
	sgn = sign(output-voltage)
	
	if(paramisdefault(update))
		update = 1
	endif
	
	if(update==1)
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
	do
		if(update==1)
			doupdate
		endif
		SetOutputBD(channel, voltage)

		starttime = stopmstimer(-2)
		do
			sc_checksweepstate()
		while(stopmstimer(-2) - starttime < 1e6*sleeptime)

		voltage+=sgn*step
	while(sgn*voltage<sgn*output-step)
	
	SetOutputBD(channel, output)
	
	if(update==0)
		resumeupdate
	endif
	
	return 1
end

function UpdateMultipleBD([action, ramprate, update])

	// usage:
	// function Experiment(....)
	//         ...
	//         wave /t dacvalsstr = dacvalsstr // this wave keeps track of new DAC values
	//         dacvalsstr[channelA][1] = num2str(1000) // set new values with a strings
	//         dacvalsstr[channelB][1] = num2str(-500)
	//         UpdateMultipleBD(action="ramp") // ramps all channels to updated values
	
	string action // "set" or "ramp"
	variable ramprate, update
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
	
	if(paramisdefault(update))
		update=1
	endif

	for(i=0;i<16;i+=1)
		if(str2num(dacvalsstr[i][1]) != str2num(oldvalue[i][1]))
			output = str2num(dacvalsstr[i][1])
			strswitch(action)
				case "set":
					check = SetOutputBD(i,output)
				case "ramp":
					check = RampOutputBD(i,output,ramprate=ramprate, update=update)
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

function RampMultipleBD(channels, setpoint, nChannels, [ramprate, update])
	variable setpoint, nChannels, ramprate, update
	string channels
	variable i, channel
	wave /t dacvalsstr = dacvalsstr
	nvar numCustom

	if(paramisdefault(ramprate))
		nvar bd_ramprate
		ramprate = bd_ramprate    // (mV/s)
	endif
	
	if(paramisdefault(update))
		update = 1
	endif
	
	for(i=0;i<nChannels;i+=1)
		channel = str2num(StringFromList(i, channels, ","))
		dacvalsstr[channel][1] = num2str(setpoint) // set new value with a string
	endfor
	UpdateMultipleBD(action="ramp", ramprate=ramprate, update = update)
	if(numCustom > 0)
		CalcCustomValues()
	endif
end

function RampMultipleCustom(channels, setpoints, [ramprate, update]) //Units = mV and mV/s
	// Ramps Custom Channels. Will only work if custom window is activated at Init!
	// channels and setpoints are comma separeted string lists. Eg. channels = "channelx,channely", setpoints = "10,26"
	// Channel names are case sensitive.
	variable ramprate, update
	string channels,setpoints
	variable i,j, bd_channel, bd_setpoint, channel_scale, bd_output, nChannels, offset
	string channel, moving_channel, scale_vec, offset_vec
	wave/t dacvalsstr
	wave/t customdacvalstr
	
	if(waveexists(customdacvalstr) == 0)
		abort "Custom channels are not supported. Re-init the BabyDAC with custom=1"
	endif

	if(paramisdefault(ramprate))
		nvar bd_ramprate
		ramprate = bd_ramprate    // (mV/s)
	endif
	
	if(paramisdefault(update))
		update = 1
	endif
	
	nChannels = itemsinlist(channels,",")
	
	for(i=0;i<nChannels;i+=1)
		channel = StringFromList(i, channels, ",")
		make/t/o/n=(dimsize(customdacvalstr,0)) testswave = customdacvalstr[p][0]
		extract/indx testswave, indexwave, (cmpstr(customdacvalstr[p][0], channel) == 0)
		if(numpnts(indexwave) > 1)
			abort "More than two Custom channels have the same name"
		elseif(numpnts(indexwave) == 0)
			abort "No channel found with the name "+channel
		endif
		moving_channel = stringfromlist(2,customdacvalstr[indexwave[0]][2],";")
		moving_channel = moving_channel[2]
		scale_vec = stringfromlist(0,customdacvalstr[indexwave[0]][2],";")
		scale_vec = scale_vec[1,strlen(scale_vec)-2]
		offset_vec = stringfromlist(1,customdacvalstr[indexwave[0]][2],";")
		offset_vec = offset_vec[1,strlen(offset_vec)-2]
		bd_setpoint = str2num(stringfromlist(i,setpoints,","))
		for(j=0;j<itemsinlist(scale_vec,",");j=j+1)
			channel_scale = str2num(stringfromlist(j,scale_vec,","))
			offset = str2num(stringfromlist(j,offset_vec,","))
			bd_output = str2num(dacvalsstr[j][1])
			if(str2num(moving_channel) == j)
				bd_setpoint -= offset
			else
				bd_setpoint -= channel_scale*(bd_output+offset)
			endif
		endfor
		bd_setpoint = bd_setpoint/str2num(stringfromlist(str2num(moving_channel),scale_vec,","))
		dacvalsstr[str2num(moving_channel)][1] = num2str(bd_setpoint) // set new values with a string
	endfor
	UpdateMultipleBD(action="ramp", ramprate=ramprate, update = update)
	CalcCustomValues()
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

window CustomDACWindow() : Panel
	variable channelhight = 23.5
	
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(0,0,320,150+numCustom*channelhight) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 50, 45,"BabyDAC Custom" // Headline
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 12,85,"NAME"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 108,85,"OUTPUT"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 208,85,"FUNC"
	ListBox daccustomlist,pos={10,90},size={300,numCustom*channelhight},fsize=16,frame=2
	ListBox daccustomlist,fStyle=1,listWave=root:customdacvalstr,selWave=root:customlistboxattr,mode= 1
	Button ramp,pos={30,105+numCustom*channelhight},size={65,20},proc=update_BabyDAC_custom,title="Ramp"
	Button calcvectors,pos={150,105+numCustom*channelhight},size={150,20},proc=calcvectors,title="Update scale functions"
endmacro

function update_BabyDAC_custom(action) : ButtonControl
	string action
	nvar numCustom
	variable i, check
	string output="", channel=""
	wave/t customdacvalstr
	wave oldcustom
	
	for(i=0;i<numCustom;i=i+1)
		if(str2num(customdacvalstr[i][1]) != oldcustom[i])
			output = AddListItem(customdacvalstr[i][1],output,",",Inf)
			channel = AddListItem(customdacvalstr[i][0],channel,",",Inf)
		endif
	endfor
	RampMultipleCustom(channel,output)
end

function calcvectors(action) : ButtonControl
	string action
	
	CreateVectors()
	CalcCustomValues()
end


window BabyDACWindow() : Panel
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
	ListBox daclist,pos={10,90},size={300,390},fsize=16,frame=2 // interactive list
	ListBox daclist,fStyle=1,listWave=root:dacvalsstr,selWave=root:listboxattr,mode= 1
	Button ramp,pos={50,495},size={65,20},proc=update_BabyDAC,title="RAMP"
	Button rampallzero,pos={170,495},size={90,20},proc=update_BabyDAC,title="RAMP ALL 0"
endMacro

function update_BabyDAC(action) : ButtonControl
	string action
	wave/t dacvalsstr=dacvalsstr
	wave/t oldvalue=oldvalue
	variable output,i
	variable check = nan
	nvar numCustom
	
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
	if(numCustom > 0)
		CalcCustomValues()
	endif
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
	wave /t dacvalsstr = dacvalsstr
	wave bd_boardnumbers = bd_boardnumbers
	svar bd_comport
	nvar numCustom


	string buffer=""
	variable i=0, j=0
	do
		if(numtype(bd_boardnumbers[i])==0)
			for(j=0;j<4;j+=1)
				buffer = addJSONKeyVal(buffer, "CH"+num2istr(4*i+j), strVal=dacvalsstr[4*i+j][1])
			endfor
		endif
		i+=1
	while(i<numpnts(bd_boardnumbers))
	i=0
	
	wave /z/t customdacvalstr = customdacvalstr
	if(WaveExists(customdacvalstr))
		do
			buffer = addJSONKeyVal(buffer, customdacvalstr[i][0], strVal=customdacvalstr[i][1])
			i=i+1
		while(i<numCustom)
	endif
	
	buffer = addJSONKeyVal(buffer, "com_port", strVal=bd_comport, addQuotes=1)
	
	return addJSONKeyVal("", "BabyDAC", strVal = buffer)
end

//// testing ////

function testBabyDACramprate(start, fin, channels, ramprate, update)
	string channels
	variable start, fin, ramprate, update
	variable nChannels = ItemsInList(channels, ",")

	RampMultipleBD(channels, start, nChannels, ramprate=ramprate, update=1)
	
	print "ramping..."
	variable ttotal = 0, tstart = datetime
	RampMultipleBD(channels, fin, nChannels, ramprate=ramprate, update=update)
	ttotal = datetime - tstart
	printf "the effective ramprate is: %.1fmV/s\n", abs(fin-start)/ttotal
	
end

//// Wave rescaling for BabyDAC scans ////

function Rescale_BabyDAC(startx,finx,channelsx,[starty,finy,channelsy])
	variable startx, finx
	string channelsx
	variable starty, finy
	string channelsy
	wave/t dacvalsstr, sc_RawWaveNames, sc_CalcWaveNames
	wave sc_RawPlot, sc_RawRecord, sc_CalcPlot, sc_CalcRecord
	variable i=0, j=0
	string rescalefuncx, rescalefuncy, channelx_index, channely_index, channelx, channely
	string rescalestartx, rescalefinx, rescalestarty, rescalefiny, wn, wn2d, cmd
	string sweep_channelx_check, sweep_channely_check
	
	if(ParamIsDefault(channelsy))
		// 1D scan, only x rescaling
		rescalefuncx = dacvalsstr[str2num(stringfromlist(0,channelsx,","))][3]
		channelx_index = SearchFullString(rescalefuncx,"CH")
		sweep_channelx_check = SearchFullString(rescalefuncx,"CH"+channelsx[0])
		if(itemsinlist(sweep_channelx_check,",") == 0)
			abort "Rescale function must contain CH"+channelsx[0]
		endif
		rescalestartx = rescalefuncx
		rescalefinx = rescalefuncx
		do
			channelx = rescalefuncx[str2num(stringfromlist(j,channelx_index,","))+2]
			if(str2num(channelx) == str2num(stringfromlist(0,channelsx,",")))
				rescalestartx = ReplaceString("CH"+channelx, rescalestartx, num2str(startx))
				rescalefinx = ReplaceString("CH"+channelx, rescalefinx, num2str(finx))
			else
				rescalestartx = ReplaceString("CH"+channelx, rescalestartx, dacvalsstr[str2num(channelx)][1])
				rescalefinx = ReplaceString("CH"+channelx, rescalefinx, dacvalsstr[str2num(channelx)][1])
			endif
			j=j+1
		while(j<itemsinlist(channelx_index,","))
		do
			if(sc_RawRecord[i] == 1 && cmpstr(sc_RawWaveNames[i], "") || sc_RawPlot[i] == 1 && cmpstr(sc_RawWaveNames[i], ""))
				wn = sc_RawWaveNames[i]
				cmd = "setscale/I x " + rescalestartx + ", " + rescalefinx + ", \"\", " + wn
				execute(cmd)
			endif
			i=i+1
		while(i<numpnts(sc_RawWaveNames))
		i=0
		do
			if (sc_CalcRecord[i] == 1 && cmpstr(sc_CalcWaveNames[i], "") || sc_CalcPlot[i] == 1 && cmpstr(sc_CalcWaveNames[i], ""))
				wn = sc_CalcWaveNames[i]
				cmd = "setscale/I x " + rescalestartx + ", " + rescalefinx + ", \"\", " + wn
				execute(cmd)
			endif
			i=i+1
		while(i<numpnts(sc_CalcWaveNames))
	else
		// 2D scan, both x and y rescaling
		rescalefuncx = dacvalsstr[str2num(stringfromlist(0,channelsx,","))][3]
		rescalefuncy = dacvalsstr[str2num(stringfromlist(0,channelsy,","))][3]
		channelx_index = SearchFullString(rescalefuncx,"CH")
		channely_index = SearchFullString(rescalefuncy,"CH")
		sweep_channelx_check = SearchFullString(rescalefuncx,"CH"+channelsx[0])
		sweep_channely_check = SearchFullString(rescalefuncy,"CH"+channelsy[0])
		if(itemsinlist(sweep_channelx_check,",") == 0 || itemsinlist(sweep_channely_check,",") == 0)
			abort "Rescale function must contain CH"+channelsx[0]
		endif
		rescalestartx = rescalefuncx
		rescalefinx = rescalefuncx
		rescalestarty = rescalefuncy
		rescalefiny = rescalefuncy
		do
			channelx = rescalefuncx[str2num(stringfromlist(j,channelx_index,","))+2]
			if(str2num(channelx) == str2num(stringfromlist(0,channelsx,",")))
				rescalestartx = ReplaceString("CH"+channelx, rescalestartx, num2str(startx))
				rescalefinx = ReplaceString("CH"+channelx, rescalefinx, num2str(finx))
			else
				rescalestartx = ReplaceString("CH"+channelx, rescalestartx, dacvalsstr[str2num(channelx)][1])
				rescalefinx = ReplaceString("CH"+channelx, rescalefinx, dacvalsstr[str2num(channelx)][1])
			endif
			j=j+1
		while(j<itemsinlist(channelx_index,","))
		j=0
		do
			channely = rescalefuncy[str2num(stringfromlist(j,channely_index,","))+2]
			if(str2num(channely) == str2num(stringfromlist(0,channelsy,",")))
				rescalestarty = ReplaceString("CH"+channely, rescalestarty, num2str(starty))
				rescalefiny = ReplaceString("CH"+channely, rescalefiny, num2str(finy))
			else
				rescalestarty = ReplaceString("CH"+channely, rescalestarty, dacvalsstr[str2num(channely)][1])
				rescalefiny = ReplaceString("CH"+channely, rescalefiny, dacvalsstr[str2num(channely)][1])
			endif
			j=j+1
		while(j<itemsinlist(channely_index,","))
		do
			if(sc_RawRecord[i] == 1 && cmpstr(sc_RawWaveNames[i], "") || sc_RawPlot[i] == 1 && cmpstr(sc_RawWaveNames[i], ""))
				wn = sc_RawWaveNames[i]
				cmd = "setscale/I x " + rescalestartx + ", " + rescalefinx + ", \"\", " + wn
				execute(cmd)
				wn2d = wn+"2d"
				cmd = "setscale/I x " + rescalestartx + ", " + rescalefinx + ", \"\", " + wn2d
				execute(cmd)
				cmd = "setscale/I y " + rescalestarty + ", " + rescalefiny + ", \"\", " + wn2d
				execute(cmd)
			endif
			i=i+1
		while(i<numpnts(sc_RawWaveNames))
		i=0
		do
			if (sc_CalcRecord[i] == 1 && cmpstr(sc_CalcWaveNames[i], "") || sc_CalcPlot[i] == 1 && cmpstr(sc_CalcWaveNames[i], ""))
				wn = sc_CalcWaveNames[i]
				cmd = "setscale/I x " + rescalestartx + ", " + rescalefinx + ", \"\", " + wn
				execute(cmd)
				wn2d = wn+"2d"
				cmd = "setscale/I x " + rescalestartx + ", " + rescalefinx + ", \"\", " + wn2d
				execute(cmd)
				cmd = "setscale/I y " + rescalestarty + ", " + rescalefiny + ", \"\", " + wn2d
				execute(cmd)
			endif
			i=i+1
		while(i<numpnts(sc_CalcWaveNames))
	endif
end

function/s SearchFullString(StringToSearch,SearchForString)
	string StringToSearch, SearchForString
	string index_list=""
	variable test, startpoint=0
	
	do
		test = strsearch(StringToSearch,SearchForString,startpoint)
		if(test != -1)
			index_list = index_list+num2istr(test)+","
			startpoint = test+1
		endif
	while(test > -1)
	
	return index_list
end