#pragma rtGlobals=1		// Use modern global access method

//	Supports a single AnalogShield/Arduino
//	Procedure written by Nik Sept 2016 (borrows heavily from babyDAC procedures)
//  update for VISA by Nik May XX 2018 (needs to be tested!)

////////////////////////
/// AnalogShield COM ///
////////////////////////

function AS_CommSetup(instrID)
	// baud=115200, databits=8, stopbits=1, parity=0
	variable instrID

	visaSetBaudRate(instrID, 115200)
    visaSetDataBits(instrID, 8)
    visaSetStopBits(instrID, 10)
    visaSetParity(instrID, 0)

end

///// CALIBRATION CONSTANTS /////

function AS_setADCcalibration()
	variable /g as_adc0_mult = 0.97807
	variable /g as_adc0_offset = 18.27185
	variable /g as_adc2_mult = 0.97490
	variable /g as_adc2_offset = -18.90508
end

///// Initiate board /////

function InitAnalogShield(instrID)
	variable instrID
	variable /g as_range_low, as_range_high, as_range_span
	string /g as_controller_addr = getResourceAddress(instrID) // for use by window functions
	variable /g as_ramprate = 50 // default ramprate

	as_range_low = -5000
	as_range_high = 5000
	as_range_span = abs(as_range_low-as_range_high)
	
	AS_CommSetup(instrID)
	AS_setADCcalibration()
	AS_CheckForOldInit()
	
	// open window
	dowindow /k AnalogShieldWindow
	execute("AnalogShieldWindow()")
	
//	ClearBufferAS(instrID)
end

function AS_CheckForOldInit()
	variable response
	if(WaveExists(as_valsstr) && WaveExists(as_oldvalue))
		response = AS_AskUser()
		if(response == 1)
			// Init at old values
			print "Init to old values"
		elseif(response == -1)
			// Init to Zero
			AS_InitToZero()
			print "Init all channels to 0V"
		else
			print "Something went wrong, will init to defualt"
			AS_InitToZero()
		endif
	else
		// Init to Zero
		AS_InitToZero()
		print "Init all channels to 0V"
	endif
end

function AS_InitToZero()
	// setup software limit
	string out
	nvar as_range_high, as_range_low
	out = num2str(max(abs(as_range_high), abs(as_range_low)))

	// Init all channels to 0V.
	make/t/o as_valsstr = {{"0","1","2","3"},{"0","0","0","0"}, {out, out, out, out}}
	make/t/o as_oldvalue = {{"0","0","0","0"}}
	make/o as_listboxattr = {{0,0,0,0},{2,2,2,2}, {2,2,2,2}}
end

function AS_AskUser()
	wave/t as_valsstr=as_valsstr
	variable/g as_answer 
	make /o as_attinitlist = {{0,0,0,0},{0,0,0,0}}
	make /o/t/n=4 as_oldinit
	make /o/t/n=4 as_defaultinit = {"0","0","0","0"}
	make /o/t/n=(4,2) as_initwave
	as_oldinit = as_valsstr[p][1]
	as_initwave[0,3][1] = as_defaultinit[p]
	as_initwave[0,3][0] = as_oldinit[p]
	execute("AskUserWindowAS()")
	PauseForUser AskUserWindowAS
	return as_answer
end

//// READ Functions ////

threadsafe function readSingleByteAS(instrID)
	// reads a single byte from the AS buffer
	// returns an 8 bit integer
	variable instrID

	// read serial port here
	variable return_count = 0
	string buffer = ""
	variable status = viRead(instrID , buffer , 1 , return_count )

	if (status==1073676294)
		// do nothing
	elseif(status>0)
		VISAerrormsg("readSingleByteBD --", instrID, status)
		return NaN // abort not supported in threads (v7)
	endif

	return char2num(buffer)
end

threadsafe function /WAVE readBytesAS(instrID, nBytes)
	// creates a wave of 8 bit integers with a given number of bytes
	//    access this wave as bd_response_wave
	//    returns number of waves read, if successful
	//    returns NaN on read error (prints message as well)"
	variable instrID, nBytes // number of bytes to read

	// read serial port here
	make /O/B/U/N=(nBytes) /FREE response_wave
	variable i=0
	for(i=0;i<nBytes;i+=1)
		response_wave[i] = readSingleByteBD(instrID)
	endfor
	
	return response_wave

end

function ClearBufferAS(instrID)
	variable instrID
	variable i=0

//	do
//
//		i+=1
//	while()
	if(i>1)
		print "Cleared " + num2istr(4*(i-1)) + " bytes of junk"
	endif
end

//// SET and RAMP outputs ////
	
function GetSetpointAS(output)
	variable output
	NVAR as_range_low,as_range_high,as_range_span
	variable frac

	frac = (output-as_range_low)/as_range_span

	return round((2^16-1)*frac)
end	
	
function SetOutputAS(instrID, channel, output) // mV
	variable instrID, output, channel
	wave/t as_valsstr=as_valsstr
	wave/t as_oldvalue=as_oldvalue
	NVAR as_range_span, as_range_high, as_range_low
	variable setpoint,sw_limit
	string cmd
	
	// Check that the voltage is valid
	if(output > as_range_high || output < as_range_low)
		string err
		sprintf err, "voltage out of DAC range, %.3fmV", output
		abort err
	endif
	
	// check that the voltage is within software limits
	// if it is outside the limit, do not interrupt
	// set output to maximum value according to limits
	sw_limit = str2num(as_valsstr[channel][2])
	if(abs(output) > sw_limit)
		if(output > 0)
			output = sw_limit
		else
			output = -1*sw_limit
		endif
	endif
	
	// send command
	sprintf cmd, "DAC %d,%.2f\n", channel, output
	writeInstr(instrID, cmd)
	
	// Update stored values
	as_valsstr[channel][1] = num2str(output)
	as_oldvalue[channel][1] = num2str(output)
	return 1
end

function RampOutputAS(instrID, channel, output, [ramprate, update])
	variable instrID, channel, output,ramprate, update // output is in mV, ramprate in mV/s
	wave/t as_valsstr=as_valsstr
	wave /t as_oldvalue=as_oldvalue
	variable voltage, sgn, step
	variable sleeptime // seconds per ramp cycle (must be at least 0.002)
	nvar as_ramprate
	
	// calculate step direction
	voltage = str2num(as_oldvalue[channel][1])
	sgn = sign(output-voltage)
	
	if(update==0)
		pauseupdate
		sleeptime = 0.002 // can ramp finely if there's no updating!
	else
		sleeptime = 0.01 // account for screen-update delays
	endif
	
	if(paramisdefault(ramprate))
		ramprate = as_ramprate  // (~mV/s) 
	endif
	
	step = ramprate*sleeptime

	voltage+=sgn*step
	if(sgn*voltage >= sgn*output)
		//// we started less than one step away from the target. set voltage and leave
		SetOutputAS(instrID, channel, output)
		return 1
	endif
	
	variable starttime, endtime

	starttime = stopmstimer(-2)
	do
		if(update==1)
			doupdate
		endif
		SetOutputAS(instrID, channel, voltage)

		endtime = starttime + 1e6*sleeptime
		do
		while(stopmstimer(-2) < endtime)
		starttime = stopmstimer(-2)

		voltage+=sgn*step
	while(sgn*voltage<sgn*output-step)
	SetOutputAS(instrID, channel, output)
	return 1
end

function UpdateMultipleAS(instrID, [action, ramprate])

	// usage:
	// function Experiment(....)
	//         ...
	//         wave /t as_valsstr = as_valsstr // this wave keeps track of new DAC values
	//         as_valsstr[channelA][1] = num2str(1000) // set new values with a strings
	//         as_valsstr[channelB][1] = num2str(-500)
	//         UpdateMultipleAS(action="ramp") // ramps all channels to updated values
	
	string action // "set" or "ramp"
	variable instrID, ramprate
	wave/t as_valsstr=as_valsstr
	wave/t as_oldvalue=as_oldvalue
	variable output,i
	variable check = nan
	nvar as_ramprate

	if(ParamIsDefault(action))
		action="ramp"
	endif
	
	if(paramisdefault(ramprate))
		ramprate = as_ramprate  
	endif

	for(i=0;i<4;i+=1)
		if(str2num(as_valsstr[i][1]) != str2num(as_oldvalue[i][1]))
			output = str2num(as_valsstr[i][1])
			strswitch(action)
				case "set":
					check = SetOutputAS(instrID, i,output)
				case "ramp":
					check = RampOutputAS(instrID, i,output, ramprate=ramprate)
			endswitch
			if(check == 1)
				as_oldvalue[i][1] = as_valsstr[i][1]
			else
				as_valsstr[i][1] = as_oldvalue[i][1]
			endif
		endif
	endfor
	return 1
end

function RampMultipleAS(instrID, channels, setpoint, nChannels, [ramprate])
	// this can be used to replace the single channel ramp function 
	// it is slightly more trouble to use and a tiny bit slower, but offers a huge amount of flexibility
	variable instrID, setpoint, ramprate, nChannels
	string channels
	variable i, channel
	nvar as_ramprate
	wave /t as_valsstr = as_valsstr

	if(paramisdefault(ramprate))
		ramprate = as_ramprate    // (mV/s)
	endif
	
	for(i=0;i<nChannels;i+=1)
		channel = str2num(StringFromList(i, channels, ","))
		as_valsstr[channel][1] = num2str(setpoint) // set new values with a strings
	endfor
	UpdateMultipleAS(instrID, action="ramp", ramprate=ramprate)
end

///// ACD readings /////

threadsafe function AS_Reading2mV(int_reading)
	variable int_reading
	variable as_adc_low=-5000, as_adc_high=5000

    return((int_reading/(2^16-1))*(as_adc_high-as_adc_low)+as_adc_low)
end

function correctReadingAS(readingmV, channel)
	// use this to correct for calibration in ADC readings
	variable readingmV, channel
	nvar as_adc0_mult,  as_adc0_offset,  as_adc2_mult, as_adc2_offset
	if(channel == 0)
		return (readingmV - as_adc0_offset)/as_adc0_mult
	else
		return (readingmV - as_adc2_offset)/as_adc2_mult
	endif
end

threadsafe function ReadADCsingleAS(instrID, channel, numavg)
	// will read up to 100 points of data at ~64kHz
	variable instrID, channel // 0 or 2
	variable numavg // number of points to average over (< 100 )
	variable reading, readingmV
	string cmd
	wave as_response_wave=as_response_wave
	

	// check channel number	
	if(channel!=0 && channel!=2)
		print "[WARNING] readADCsingleAS -- pick a valid input channel, 0 or 2"
		return NaN
	endif
	
	// adc command
//	sprintf cmd, "ADCF %d,%d\n", channel, numavg
//	writeInstr(instrID, cmd)
//	
//	// read response
//	ReadBytesAS(2*numavg + 4, timeout = 0.001*numavg) // reads into as_response_wave
//	
//	variable i=0
//	for(i=0;i<numavg;i+=1)
//		reading += as_response_wave[2*i] + as_response_wave[2*i+1]*256
//	endfor
	
	return AS_Reading2mV(reading/numavg)

end

function AS_get_time()
	wave as_response_wave=as_response_wave
	variable telapsed
	variable n = numpnts(as_response_wave)
	return as_response_wave[n-4] + as_response_wave[n-3]*2^8 + as_response_wave[n-2]*2^16 + as_response_wave[n-1]*2^32
end	

function ReadADCtimeAS(instrID, channel, numpts)
	// will read unlimited data as fast as the serial port will allow
	// this is  significantly faster on a UNIX system (~40kHz)
	// compared to a Windows system (11 kHz)
	variable instrID, channel // 0 or 2
	variable numpts 
	string cmd
	wave as_response_wave=as_response_wave
	nvar as_adc0_mult,  as_adc0_offset,  as_adc2_mult, as_adc2_offset

	// check channel number	
	if(channel!=0 && channel!=2)
		abort "pick a valid input channel, 0 or 2"
	endif
	
	// adc command
	sprintf cmd, "ADC %d,%d\n", channel, numpts
	writeInstr(instrID, cmd)
	
	// read response
	ReadBytesAS(instrID, 2*numpts + 4) // reads into as_response_wave
	
	// create wave to hold results
	make /o/n=(numpts) as_adc_readings
	setscale/I x 0, AS_get_time()/1e6, "", as_adc_readings
	variable i=0
	for(i=0;i<numpts;i+=1)
		as_adc_readings[i] = AS_Reading2mV(as_response_wave[2*i] + as_response_wave[2*i+1]*256)
		if(channel == 0)
			 as_adc_readings[i] = (as_adc_readings[i] - as_adc0_offset)/as_adc0_mult
		else
			 as_adc_readings[i] = (as_adc_readings[i] - as_adc2_offset)/as_adc2_mult
		endif
	endfor
	
end

///// User interface /////

Window AnalogShieldWindow() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(0,0,320,250) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 90, 45,"AnalogShield" // Headline
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 12,85,"CHANNEL"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 108,85,"VOLT (mV)"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 208,85,"LIM (mV)"
	ListBox daclist,pos={10,90},size={300,96},fsize=16,frame=2 // interactive list
	ListBox daclist,fStyle=1,listWave=root:as_valsstr,selWave=root:as_listboxattr,mode= 1
	Button ramp,pos={40,200},size={65,20},proc=update_AnalogShield,title="RAMP"
	Button rampallzero,pos={170,200},size={90,20},proc=update_AnalogShield,title="RAMP ALL 0"
EndMacro

function update_AnalogShield(action) : ButtonControl
	string action
	wave/t as_valsstr=as_valsstr
	wave/t as_oldvalue=as_oldvalue
	variable output,i
	variable check = nan
	controlinfo /W=AnalogShieldWindow daclist
	
	// setup temporary control for Analog Shield
    svar as_controller_addr
    variable status, localRM
    
    status = viOpenDefaultRM(localRM) // open local copy of resource manager
    if(status < 0)
        VISAerrormsg("open BD connection:", localRM, status)
        abort
    endif
    openInstr("as_window_resource", as_controller_addr, localRM=localRM, verbose=0)
    nvar as_window_resource
    AS_CommSetup(as_window_resource)
    
	strswitch(action)
		case "ramp":
			for(i=0;i<16;i+=1)
				if(str2num(as_valsstr[i][1]) != str2num(as_oldvalue[i][1]))
					output = str2num(as_valsstr[i][1])
					check = RampOutputAS(as_window_resource, i,output)
					if(check == 1)
						as_oldvalue[i][1] = as_valsstr[i][1]
					else
						as_valsstr[i][1] = as_oldvalue[i][1]
					endif
				endif
			endfor
			break
		case "rampallzero":
			for(i=0;i<16;i+=1)
				check = RampOutputAS(as_window_resource, i, 0)
				if(check==1)
					as_oldvalue[i][1] = as_valsstr[i][1]
				endif
			endfor
			break
	endswitch
	
	viClose(as_window_resource) // close VISA resource
	
end

Window AskUserWindowAS() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(100,100,400,350) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 20, 45,"Choose  init" // Headline
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 40,80,"Old init"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 170,80,"Default"
	ListBox initlist,pos={10,90},size={280,96},fsize=16,frame=2
	ListBox initlist,fStyle=1,listWave=root:as_initwave,selWave=root:attinitlist,mode= 0
	Button oldinit,pos={40,200},size={70,20},proc=AskUserUpdateAS,title="OLD INIT"
	Button defaultinit,pos={170,200},size={70,20},proc=AskUserUpdateAS,title="DEFAULT"
EndMacro

function AskUserUpdateAS(action) : ButtonControl
	string action
	variable/g as_answer
	strswitch(action)
		case "oldinit":
			as_answer = 1
			dowindow/k AskUserWindowAS
			break
		case "defaultinit":
			as_answer = -1
			dowindow/k AskUserWindowAS
			break
	endswitch
end

////// Status String for Logging ////

function/s GetASStatus()
	wave /t as_valsstr = as_valsstr
	svar as_controller_addr

	string buffer=""
	variable j=0
	for(j=0;j<4;j+=1)
		buffer = addJSONkeyvalpair(buffer, "CH"+num2istr(j), as_valsstr[j][1])
	endfor
	buffer = addJSONkeyvalpair(buffer, "com_port", as_controller_addr, addQuotes=1)
	
	return addJSONkeyvalpair("", "AnalogShield", buffer)
end