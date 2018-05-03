#pragma rtGlobals=1		// Use modern global access method

//	Driver communicates over serial, remember to set the DAC board number in InitBabyDAC() and the serial port in SetSerialPort()
//	Has interactive window like BabyDAC Procedures, but the driver is much more flexible.
//	Supports up to four DAC boards
//	Procedure written by Christian, 2016-0X-XX
//    Updated by Nik for binary control, ADC reading, and software limits

/////////////////////////////////
///// Initiate DAC board(s) /////
/////////////////////////////////

function InitBabyDACs(instrID, boards, ranges, [custom])
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

    variable instrID, custom
	string boards, ranges
	variable /g bd_ramprate = 200 // default ramprate
    string /g bd_controller_addr = getResourceAddress(instrID) // for use by window functions

	if(paramisdefault(custom))
		custom = 0
	endif

    // setup serial port attributes
	bdCommSetup(instrID) // setup DAC com port

    // functions to handle a bunch of ugly waves
    //     these keep track of the current state of the outputs
	bdSetBoardNumbers(boards,custom) // handle board numbering
	bdSetChannelRange(ranges) // set DAC output ranges
	bdCheckForOldInit(custom) // Will update the user window to the last known values.

	// open window
	dowindow /k BabyDACWindow
	execute("BabyDACWindow()")

	if(custom)
		dowindow /k CustomDACWindow
		execute("CustomDACWindow()")
	endif
end

//// setup functions ////

function bdCommSetup(instrID)
	// baud=57600, databits=8, stopbits=1, parity=0

	variable instrID

	visaSetBaudRate(instrID, 57600)
    visaSetDataBits(instrID, 8)
    visaSetStopBits(instrID, 10)
    visaSetParity(instrID, 0)

end

function bdSetBoardNumbers(boards, custom)
	// Leave board numbers blank or NaN if not all 4 boards are used.
	// First board will have channels 0-3, second baord will have channels 4-7,
	// third board will have channels 8-11, fourth board will have channels 12-15
	string boards
	variable custom
	variable numBoards = ItemsInList(boards, ",")
	variable /g bd_num_custom = 0
	wave/t dacvalstr=dacvalstr

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
		bd_num_custom += 4
	endif

	if(numtype(bd_boardnumbers[1])==2)
		dacvalstr[4] = "0"
		dacvalstr[5] = "0"
		dacvalstr[6] = "0"
		dacvalstr[7] = "0"
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
			bd_num_custom += 4
		endif
	endif

	if(numtype(bd_boardnumbers[2])==2)
		dacvalstr[8] = "0"
		dacvalstr[9] = "0"
		dacvalstr[10] = "0"
		dacvalstr[11] = "0"
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
			bd_num_custom += 4
		endif
	endif

	if(numtype(bd_boardnumbers[3])==2)
		dacvalstr[12] = "0"
		dacvalstr[13] = "0"
		dacvalstr[14] = "0"
		dacvalstr[15] = "0"
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
			bd_num_custom += 4
		endif
	endif
end

function bdSetChannelRange(ranges)
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

function bdCheckForOldInit(custom)
	variable custom
	variable response
	nvar bd_num_custom

	if(waveexists(dacvalstr) && waveexists(oldvalue))
		response = bdInitAskUser()
		if(response == 1)
			// Init at old values
			print "Init BabyDAC to OLD values"
			if(custom)
				bdCreateCustomWaves(1)
				bdCalcCustomValues() // here!
			endif
		elseif(response == -1)
			// Init to Zero
			bdInitZeros()
			if(custom)
				bdCreateCustomWaves(0)
				bdCalcCustomValues()
			endif
			print "Init all BabyDAC channels to 0V"
		else
			print "[WARNING] Bad user input -- BabyDAC will init to defualt values"
			bdInitZeros()
			if(custom)
				bdCreateCustomWaves(0)
				bdCalcCustomValues()
			endif
		endif
	else
		// Init to Zero
		bdInitZeros()
		if(custom)
			bdCreateCustomWaves(0)
			bdCalcCustomValues()
		endif
		print "Init all channels to 0V"
	endif
end

function bdCreateCustomWaves(keepold)
	variable keepold
	string customname = "ABCDEFGHIJKLMNOP", default_vec ="", specific_vec = "", offset_vec = ""
	variable i
	nvar bd_num_custom

	make/o/n=(bd_num_custom, 3) customlistboxattr = 2

	if(keepold && waveexists(customdacvalstr))
		print("Initialized BabyDAC to old values")
		print("REMINDER: Update the scale functions and channel names in BabyDAC Custom window")
	else
		make/o/n=(bd_num_custom) oldcustom = 0
	endif
	make/o/t/n=(bd_num_custom,3) customdacvalstr
	for(i=0;i<bd_num_custom;i=i+1)
		default_vec = addlistitem("0",default_vec,",")
		offset_vec = addlistitem("0",offset_vec,",")
	endfor
	offset_vec = "("+offset_vec[0,strlen(offset_vec)-2]+")"
	for(i=0;i<bd_num_custom;i=i+1)
		specific_vec = removelistitem(i,default_vec,",")
		specific_vec = addlistitem("1",specific_vec,",",i)
		specific_vec = "("+specific_vec[0,strlen(specific_vec)-2]+")"
		customdacvalstr[i][0] = customname[i]
		customdacvalstr[i][1] = ""
		customdacvalstr[i][2] = specific_vec+";"+offset_vec+";"+"CH"+num2istr(i)
	endfor
	bdCreateVectors()
end

function bdCalcCustomValues()
	nvar bd_num_custom
	wave/t dacvalstr
	wave/t customdacvalstr
	wave bdtocustom_vec
	wave customtobd_vec
	wave offsets
	wave oldcustom
	variable i

	make/o/n=(bd_num_custom) customoutput = nan
	make/o/n=(bd_num_custom) bdoutput = nan
	make/o/n=(bd_num_custom) scalefunc = nan
	make/o/n=(bd_num_custom) offset = nan
	bdoutput = str2num(dacvalstr[p][1])
	for(i=0;i<bd_num_custom;i=i+1)
		scalefunc = bdtocustom_vec[p][i]
		offset = offsets[p][i]
		matrixop/o placeholder = (scalefunc.(bdoutput + offset))
		customoutput[i] = placeholder[0]
	endfor
	oldcustom = customoutput[p]
	customdacvalstr[][1] = num2str(customoutput[p])
end

function bdCreateVectors()
	wave/t customdacvalstr
	nvar bd_num_custom
	string vector
	variable i,j

	make/t/o/n=(bd_num_custom) textplaceholder
	make/o/n=(bd_num_custom) numplaceholder
	make/o/n=(bd_num_custom,bd_num_custom) bdtocustom_vec = nan
	make/o/n=(bd_num_custom,bd_num_custom) customtobd_vec = nan
	make/o/n=(bd_num_custom,bd_num_custom) offsets = nan
	for(i=0;i<bd_num_custom;i=i+1)
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
	for(i=0;i<bd_num_custom;i=i+1)
		for(j=0;j<bd_num_custom;j=j+1)
			customtobd_vec[i][j] = 1.0/bdtocustom_vec[i][j]
		endfor
	endfor
end

function bdInitZeros()
    // does not actually ramp anything
	wave bd_boardnumbers
	nvar bd_num_custom

	// Init all channels to 0V.
	make/t/o dacvalstr = {{"0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15"},{"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"}, {"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"}}
	make/t/o oldvalue = {{"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"}}

	// setup software limit
	variable i = 0, board_index = 0
	wave bd_range_high, bd_range_low
	for(i=0; i<16; i+=1)
		board_index = floor(i/4)
		if(numtype(bd_boardnumbers[board_index])==0)
			dacvalstr[i][2] = num2str(max(abs(bd_range_high[board_index]), abs(bd_range_low[board_index])))
		endif
	endfor
end

function bdInitAskUser()
	wave/t dacvalstr=dacvalstr
	variable/g bd_answer
	make /o attinitlist = {{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}}
	make /o/t/n=16 oldinit
	make /o/t/n=16 defaultinit = {"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"}
	make /o/t/n=(16,2) initwave
	oldinit = dacvalstr[p][1]
	initwave[0,15][1] = defaultinit[p]
	initwave[0,15][0] = oldinit[p]
	execute("bdInitWindow()")
	PauseForUser bdInitWindow
	return bd_answer
end

//// Keep track of channel/board numbers ////

// function bdCheckForBoard(board_number)
//     // check if board_number is listed
// 	variable board_number
// 	variable i=0, found_board = 0
// 	wave bd_boardnumbers = bd_boardnumbers
// 	do
// 		if(bd_boardnumbers[i]==board_number)
// 			return 1
// 		endif
// 		i+=1
// 	while(i<numpnts(bd_boardnumbers))
// 	return 0
// end

function bdGetBoard(channel)
    // given a channel number
    //    return a board number
	variable channel
	wave bd_boardnumbers=bd_boardnumbers
	variable index
	string err
	index = floor(channel/4)
	if(bd_boardnumbers[index] == nan)
		sprintf err, "BabyDAC board %d is not defined/connected!", index
		abort err
	else
		return bd_boardnumbers[index]
	endif
end

function bdGetBoardChannel(channel)
	variable channel
	variable index
	index = mod(channel,4)
	return index
end

//// UTILITY ////

function setAllZeroBD()
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

function resetStartupVoltageBD(board_number, range)
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
	wave/t dacvalstr=dacvalstr
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
	sw_limit = str2num(dacvalstr[channel][2])
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
	dacvalstr[channel][1] = num2str(output)
	oldvalue[channel][1] = num2str(output)
	return 1
end

function RampOutputBD(channel, output, [ramprate, update])
	variable channel, output,ramprate, update // output is in mV, ramprate in mV/s
	wave/t dacvalstr=dacvalstr
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
	else
		ramprate=abs(ramprate)
	endif

	step = ramprate*sleeptime

	voltage+=sgn*step
	if(sgn*voltage >= sgn*output)
		//// we started less than one step away from the target. set voltage and leave
		SetOutputBD(channel, output)
		return 1
	endif

	do
		if(update==1)
			doupdate
		endif
		SetOutputBD(channel, voltage)

		sc_sleep(sleeptime)

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
	//         wave /t dacvalstr = dacvalstr // this wave keeps track of new DAC values
	//         dacvalstr[channelA][1] = num2str(1000) // set new values with a strings
	//         dacvalstr[channelB][1] = num2str(-500)
	//         UpdateMultipleBD(action="ramp") // ramps all channels to updated values

	string action // "set" or "ramp"
	variable ramprate, update
	wave/t dacvalstr=dacvalstr
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
		if(str2num(dacvalstr[i][1]) != str2num(oldvalue[i][1]))
			output = str2num(dacvalstr[i][1])
			strswitch(action)
				case "set":
					check = SetOutputBD(i,output)
				case "ramp":
					check = RampOutputBD(i,output,ramprate=ramprate, update=update)
			endswitch
			if(check == 1)
				oldvalue[i][1] = dacvalstr[i][1]
			else
				dacvalstr[i][1] = oldvalue[i][1]
			endif
		endif
	endfor
	return 1
end

function RampMultipleBD(channels, setpoint, nChannels, [ramprate, update])
	variable setpoint, nChannels, ramprate, update
	string channels
	variable i, kind
	string channel
	wave /t dacvalstr = dacvalstr
	wave /t customdacvalstr
	nvar bd_num_custom

	if(paramisdefault(ramprate))
		nvar bd_ramprate
		ramprate = bd_ramprate    // (mV/s)
	endif

	if(paramisdefault(update))
		update = 1
	endif

	for(i=0;i<nChannels;i+=1)
		channel = StringFromList(i, channels, ",")
		kind = ChannelLookUp(channel)
		if(kind == 0) //Not a custom channel
			dacvalstr[str2num(channel)][1] = num2str(setpoint) // set new value with a string
		elseif(kind == 1) // Custom channel
			UpdateCustom(channel,setpoint)
		endif
	endfor
	UpdateMultipleBD(action="ramp", ramprate=ramprate, update = update)
	if(bd_num_custom > 0)
		bdCalcCustomValues()
	endif
end

function ChannelLookUp(channel)
	string channel
	wave/t dacvalstr
	wave/t customdacvalstr

	if(waveexists(customdacvalstr) == 0)
		return 0
	endif

	make/t/o/n=(dimsize(customdacvalstr,0)) testswavecustom = customdacvalstr[p][0]
	extract/indx testswavecustom, indexwavecustom, (cmpstr(customdacvalstr[p][0], channel) == 0)
	make/t/o/n=(dimsize(dacvalstr,0)) testswave = dacvalstr[p][0]
	extract/indx testswave, indexwave, (cmpstr(dacvalstr[p][0], channel) == 0)

	if(numpnts(indexwave) == 0 && numpnts(indexwavecustom) == 0)
		abort "No channel found with the name "+channel
	elseif(numpnts(indexwavecustom) == 0)
		return 0
	elseif(numpnts(indexwave) == 0)
		if(numpnts(indexwavecustom) > 1)
			abort "More than two Custom channels have the same name"
		else
			return 1
		endif
	endif
end

function UpdateCustom(channel,setpoint)
	string channel
	variable setpoint
	string moving_channel, scale_vec, offset_vec
	variable channel_scale, offset, bd_output, j=0
	wave/t customdacvalstr
	wave/t dacvalstr
	wave indexwavecustom // updated in ChannelLookUp()

	moving_channel = stringfromlist(2,customdacvalstr[indexwavecustom[0]][2],";")
	moving_channel = moving_channel[2]
	scale_vec = stringfromlist(0,customdacvalstr[indexwavecustom[0]][2],";")
	scale_vec = scale_vec[1,strlen(scale_vec)-2]
	offset_vec = stringfromlist(1,customdacvalstr[indexwavecustom[0]][2],";")
	offset_vec = offset_vec[1,strlen(offset_vec)-2]
	for(j=0;j<itemsinlist(scale_vec,",");j=j+1)
		channel_scale = str2num(stringfromlist(j,scale_vec,","))
		offset = str2num(stringfromlist(j,offset_vec,","))
		bd_output = str2num(dacvalstr[j][1])
		if(str2num(moving_channel) == j)
			setpoint -= offset
		else
			setpoint -= channel_scale*(bd_output+offset)
		endif
	endfor
	setpoint = setpoint/str2num(stringfromlist(str2num(moving_channel),scale_vec,","))
	dacvalstr[str2num(moving_channel)][1] = num2str(setpoint) // set new values with a string
end

////////////////////////
///// ACD readings /////
////////////////////////

function bdReading2Voltage()
	wave bd_response_wave
	variable a, b, c, int_reading // declare a bunch of integers
	variable frac, volts // should be floats
	variable /g bd_adc_low=-2500, bd_adc_high=2500
	a = bd_response_wave[2] * 2^14
	b = bd_response_wave[3] * 2^7
	c = bd_response_wave[4]
	int_reading = a+b+c

    frac = int_reading/(2^21-1)
    volts = (frac*(bd_adc_high-bd_adc_low)+bd_adc_low)
    return volts
end

function readBytesBD(bytes)
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

Function clearBufferBD()
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

function readBDadc(channel, board_number)
	// you can only get a new reading here once every 300ms //
	// it is left to the user to figure out how to time things correctly //
	variable channel // 1 or 2
	variable board_number // which babydac board
	variable channel_bit
	variable reading

	// check if board is initialized
	if((board_number)!=1)
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
	reading = bdReading2Voltage()

	return reading
end

//////////////////////////
///// User interface /////
//////////////////////////

window CustomDACWindow() : Panel
	variable channelhight = 23.5

	PauseUpdate; Silent 1 // building window
	NewPanel /W=(0,0,320,150+bd_num_custom*channelhight) // window size
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
	ListBox daccustomlist,pos={10,90},size={300,bd_num_custom*channelhight},fsize=16,frame=2
	ListBox daccustomlist,fStyle=1,listWave=root:customdacvalstr,selWave=root:customlistboxattr,mode= 1
	Button ramp,pos={30,105+bd_num_custom*channelhight},size={65,20},proc=update_BabyDAC_custom,title="Ramp"
	Button calcvectors,pos={150,105+bd_num_custom*channelhight},size={150,20},proc=calcvectors,title="Update scale functions"
endmacro

function update_BabyDAC_custom(action) : ButtonControl
	string action
	nvar bd_num_custom
	variable i, check, output
	string channel=""
	wave/t customdacvalstr
	wave oldcustom

	for(i=0;i<bd_num_custom;i=i+1)
		if(str2num(customdacvalstr[i][1]) != oldcustom[i])
			output = str2num(customdacvalstr[i][1])
			channel = customdacvalstr[i][0]
			RampMultipleBD(channel,output,1)
			oldcustom[i] = str2num(customdacvalstr[i][1])
		endif
	endfor
end

function calcvectors(action) : ButtonControl
	string action

	bdCreateVectors()
	bdCalcCustomValues()
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
	ListBox daclist,fStyle=1,listWave=root:dacvalstr,selWave=root:listboxattr,mode= 1
	Button ramp,pos={50,495},size={65,20},proc=update_BabyDAC,title="RAMP"
	Button rampallzero,pos={170,495},size={90,20},proc=update_BabyDAC,title="RAMP ALL 0"
endMacro

function update_BabyDAC(action) : ButtonControl
	string action
	wave/t dacvalstr=dacvalstr
	wave/t oldvalue=oldvalue
	variable output,i
	variable check = nan
	nvar bd_num_custom

	strswitch(action)
		case "ramp":
			for(i=0;i<16;i+=1)
				if(str2num(dacvalstr[i][1]) != str2num(oldvalue[i][1]))
					output = str2num(dacvalstr[i][1])
					check = RampOutputBD(i,output)
					if(check == 1)
						oldvalue[i][1] = dacvalstr[i][1]
					else
						dacvalstr[i][1] = oldvalue[i][1]
					endif
				endif
			endfor
			break
		case "rampallzero":
			for(i=0;i<16;i+=1)
				check = RampOutputBD(i, 0)
				if(check==1)
					oldvalue[i][1] = dacvalstr[i][1]
				endif
			endfor
			break
	endswitch
	if(bd_num_custom > 0)
		bdCalcCustomValues()
	endif
end

Window bdInitWindow() : Panel
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
	Button oldinit,pos={40,490},size={70,20},proc=bdAskUserUpdate,title="OLD INIT"
	Button defaultinit,pos={170,490},size={70,20},proc=bdAskUserUpdate,title="DEFAULT"
EndMacro

function bdAskUserUpdate(action) : ButtonControl
	string action
	variable/g bd_answer
	strswitch(action)
		case "oldinit":
			bd_answer = 1
			dowindow/k bdInitWindow
			break
		case "defaultinit":
			bd_answer = -1
			dowindow/k bdInitWindow
			break
	endswitch
end

///////////////////////////////////
//// Status String for Logging ////
///////////////////////////////////

function/s GetBDDACStatus(instrID)
    // this doesn't actually require CreateGPIBInstrID
    //     it is only there to be consistent with the other devices
	wave /t dacvalstr = dacvalstr
	wave bd_boardnumbers = bd_boardnumbers
	svar bd_controller_addr
	nvar bd_num_custom


	string buffer=""
	variable i=0, j=0
	do
		if(numtype(bd_boardnumbers[i])==0)
			for(j=0;j<4;j+=1)
				buffer = addJSONKeyVal(buffer, "CH"+num2istr(4*i+j), strVal=dacvalstr[4*i+j][1])
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
		while(i<bd_num_custom)
	endif

	buffer = addJSONKeyVal(buffer, "com_port", strVal=bd_controller_addr, addQuotes=1)

	return addJSONKeyVal("", "BabyDAC", strVal = buffer)
end

/////////////////
//// testing ////
/////////////////

// function testBabyDACramprate(start, fin, channels, ramprate, update)
// 	string channels
// 	variable start, fin, ramprate, update
// 	variable nChannels = ItemsInList(channels, ",")
//
// 	RampMultipleBD(channels, start, nChannels, ramprate=ramprate, update=1)
//
// 	print "ramping..."
// 	variable ttotal = 0, tstart = datetime
// 	RampMultipleBD(channels, fin, nChannels, ramprate=ramprate, update=update)
// 	ttotal = datetime - tstart
// 	printf "the effective ramprate is: %.1fmV/s\n", abs(fin-start)/ttotal
//
// end
