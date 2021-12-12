#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Fast DAC (8 DAC channels + 4 ADC channels). Build in-house by Mark (Electronic work shop).
// This is the instrument specific .ipf for FastDACs. For interface integration into IgorAqc see ScanController_FastDAC.ipf
// Note: the Fast DAC is generally "stand alone", no other instruments can read at the same time (unless taking point by point measurements with fastdac, in which case you should be using a DMM)
//		Open a connection to the FastDAC FIRST, and then InitFastDAC() from ScanController_FastDAC
// 		The fastdac will only run with the scancontroller_fastdac window specifically (not the regular scancontroller windowm, except for point by point measurements)
// 	   In order to save fastdac waves with Scancontroller the user must add the fastdac=1 flag to initWaves() and SaveWaves()
//
// The fastdac can also act as a spectrum analyzer method. See the Spectrum Analyzer section at the bottom. 
// As for everyting else, you must open a connection to a FastDAC first and then run "InitFastDAC" before you can use the
// spectrum analyzer method.
//
// Written by Christian Olsen and Tim Child, 2020-03-27
// Modified by Tim Child, 2020-06-06 -- Separated Fastdac device from scancontroller_fastdac
// Added PID related functions by Ruiheng Su, 2021-06-02  
// Massive refactoring of code, 2021-11 -- Tim Child

////////////////////
//// Connection ////
////////////////////

function openFastDACconnection(instrID, visa_address, [verbose,numDACCh,numADCCh,master, optical])
	// instrID is the name of the global variable that will be used for communication
	// visa_address is the VISA address string, i.e. ASRL1::INSTR
	// Most FastDAC communication relies on the info in "sc_fdackeys". Pass numDACCh and
	// numADCCh to fill info into "sc_fdackeys"
	string instrID, visa_address
	variable verbose, numDACCh, numADCCh, master
	variable optical  // Whether connected by optical (or usb)

	master = paramisDefault(master) ? 0 : master
	optical = paramisDefault(optical) ? 1 : optical
	verbose = paramisDefault(verbose) ? 1 : verbose
		
	variable localRM
	variable status = viOpenDefaultRM(localRM) // open local copy of resource manager
	if(status < 0)
		VISAerrormsg("open FastDAC connection:", localRM, status)
		abort
	endif
	
	string comm = ""
	sprintf comm, "name=FastDAC,instrID=%s,visa_address=%s" instrID, visa_address
	string options
	if(optical)
 		options = "baudrate=1750000,databits=8,stopbits=1,parity=0,test_query=*IDN?"  // For Optical
	else
		options = "baudrate=57600,databits=8,stopbits=1,parity=0,test_query=*IDN?"  // For USB
	endif
	openVISAinstr(comm, options=options, localRM=localRM, verbose=verbose)
	
	// fill info into "sc_fdackeys"
	if(!paramisdefault(numDACCh) && !paramisdefault(numADCCh))
		sc_fillfdacKeys(instrID,visa_address,numDACCh,numADCCh,master=master)
	endif
	
	return localRM
end

///////////////////////
//// PID functions ////
///////////////////////

function startPID(instrID)
	// Starts the PID algorithm on DAC and ADC channels 0
	// make sure that the PID algorithm does not return any characters.
	variable instrID
	
	string cmd=""
	sprintf cmd, "START_PID"
	writeInstr(instrID, cmd+"\r")
end


function stopPID(instrID)
	// stops the PID algorithm on DAC and ADC channels 0
	variable instrID
	
	string cmd=""
	sprintf cmd, "STOP_PID"
	writeInstr(instrID, cmd+"\r")
end

function setPIDTune(instrID, kp, ki, kd)
	// sets the PID tuning parameters
	variable instrID, kp, ki, kd
	
	string cmd=""
	// specify to print 9 digits after the decimal place
	sprintf cmd, "SET_PID_TUNE,%.9f,%.9f,%.9f",kp,ki,kd

	writeInstr(instrID, cmd+"\r")
end

function setPIDSetp(instrID, setp)
	// sets the PID set point, in mV
	variable instrID, setp
	
	string cmd=""
	sprintf cmd, "SET_PID_SETP,%f",setp

   	writeInstr(instrID, cmd+"\r")
end


function setPIDLims(instrID, lower,upper) //mV, mV
	// sets the limits of the controller output, in mV 
	variable instrID, lower, upper
	
	string cmd=""
	sprintf cmd, "SET_PID_LIMS,%f,%f",lower,upper

   	writeInstr(instrID, cmd+"\r")
end

function setPIDDir(instrID, direct) // 0 is reverse, 1 is forward
	// sets the direction of PID control
	// The default direction is forward 
	// The process variable of a reverse process decreases with increasing controller output 
	// The process variable of a direct process increases with increasing controller output 
	variable instrID, direct 
	
	string cmd=""
	sprintf cmd, "SET_PID_DIR,%d",direct
   	writeInstr(instrID, cmd+"\r")
end

function setPIDSlew(instrID, [slew]) // maximum slewrate in mV per second
	// the slew rate is proportional how fast the controller output is allowed to ramp
	variable instrID, slew 
	
	if(paramisdefault(slew))
		slew = 10000000.0
	endif
		
	string cmd=""
	sprintf cmd, "SET_PID_SLEW,%.9f",slew
	print/D cmd
   	writeInstr(instrID, cmd+"\r")
end


///////////////////////
//// Get functions ////
///////////////////////

function getFADCmeasureFreq(instrID)
	// Calculates measurement frequency as sampleFreq/numadc 
	// NOTE: This assumes ALL recorded ADCs are on ONE fastdac. I.e. does not support measuring with multiple fastdacs
	variable instrID
	
	svar sc_fdackeys	
	variable numadc, samplefreq
	numadc = getnumfadc() 
	if (numadc == 0)
		numadc = 1
	endif
	samplefreq = getFADCspeed(instrID)
	return samplefreq/numadc
end

function getNumFADC() 
	// Returns how many ADCs are set to be recorded
	// Note: Gets this info from ScanController_Fastdac
	string adcs = getRecordedFastdacInfo("channels")
	variable numadc = itemsInList(adcs)
	if(numadc == 0)
		print "WARNING[getNumFADC]: No ADCs set to record. Behaviour may be unpredictable"
	endif
		
	return numadc
end

function getFADCspeed(instrID)
	// Returns speed in Hz (but arduino thinks in microseconds)
	variable instrID
	svar fadcSpeeds

	string response="", compare="", cmd="", command=""

	command = "READ_CONVERT_TIME"
	cmd = command+",0"  // Read convert time on channel 0
	response = queryInstr(instrID,cmd+"\r",read_term="\n")  // Get conversion time for channel 0 (should be same for all channels)
	response = sc_stripTermination(response,"\r\n")
	if(!fd_checkResponse(response,cmd))
		abort "ERROR[getFADCspeed]: Failed to read speed from fastdac"
	endif
	
	variable numDevice = getDeviceNumber(instrID)
	variable numADCs = getFDInfoFromID(instrID, "numADC")

//	// Note: This extra check takes ~45ms (15ms per read)
//	variable i
//	for(i=1;i<numADCs;i+=1)  // Start from 1 because 0th channel already checked
//		cmd  = command+","+num2istr(i)
//		compare = queryInstr(instrID,cmd+"\r",read_term="\n")
//		compare = sc_stripTermination(compare,"\r\n")
//		if(!fd_checkResponse(compare,cmd))
//			abort
//		elseif(str2num(compare) != str2num(response)) // Ensure ADC channels all have same conversion time
//			print "WARNING[getfadcSpeed]: ADC channels 0 & "+num2istr(i)+" have different conversion times!"
//		endif
//	endfor
	
	return 1.0/(str2num(response)*1.0e-6) // return value in Hz
end

function getFADCchannel(fdid, channel, [len_avg])
	// Instead of just grabbing one single datapoint which is susceptible to high f noise, this averages data over len_avg and returns a single value
	variable fdid, channel, len_avg
	
	len_avg = paramisdefault(len_avg) ? 0.05 : len_avg
	
	variable numpts = ceil(getFADCspeed(fdid)*len_avg)
	if(numpts <= 0)
		numpts = 1
	endif
	
	fd_readChunk(fdid, num2str(channel), numpts)  // Creates fd_readChunk_# wave	

	wave w = $"fd_readChunk_"+num2str(channel)
	wavestats/q w
	wave/t fadcvalstr
	fadcvalstr[channel][1] = num2str(v_avg)
	return V_avg
end

function getFADCvalue(fdid, channel, [len_avg])
	// Same as FADCchannel except it also applies the Calc Function before returning
	// Note: Min read time is ~60ms because of having to check SamplingFreq a couple of times -- Could potentially be optimized further if necessary
	variable fdid, channel, len_avg
	
	len_avg = paramisdefault(len_avg) ? 0.05 : len_avg

	variable/g fd_val_mv = getFADCchannel(fdid, channel, len_avg=len_avg)  // Must be global so can use execute
	variable/g fd_val_real
	wave/t fadcvalstr
	string func = fadcvalstr[channel][4]

	string cmd = replaceString("ADC"+num2str(channel), func, "fd_val_mv")
	sprintf cmd, "fd_val_real = %s", cmd
	execute/q/z cmd

	return fd_val_real
end


function getFADCChannelSingle(instrID,channel) // Units: mV
	// channel must be the channel number given by the GUI!
	// Gets a single FADC reading only, likely to be very noisy because no filtering of high f noise
	// Use getFADCchannelAVG for averaged value
	
	variable instrID, channel
	wave/t fadcvalstr
	svar sc_fdackeys
	

	variable device // to store device num
	string devchannel = getChannelsOnFD(num2str(channel), device) 
	checkInstrIDmatchesDevice(instrID, device)

	// query ADC
	string cmd = ""
	sprintf cmd, "GET_ADC,%d", devchannel
	string response
	response = queryInstr(instrID, cmd+"\r", read_term="\n")
	response = sc_stripTermination(response,"\r\n")
	
	// check response
	string err = ""
	if(fd_checkResponse(response,cmd)) 
		// good response, update window
		fadcvalstr[channel][1] = num2str(str2num(response))
		return str2num(response)
	else
		abort
	endif
end

function getFDACOutput(instrID,channel) // Units: mV
	// NOTE: Channel is PER INSTRUMENT
	variable instrID, channel
	
	wave/t old_fdacvalstr, fdacvalstr
	string cmd="", response="",warn=""
	sprintf cmd, "GET_DAC,%d", channel
	response = queryInstr(instrID, cmd+"\r", read_term="\n")
	response = sc_stripTermination(response,"\r\n")
	
	// check response
	if(fd_checkResponse(response,cmd))
		// good response
		return str2num(response)
	else
		abort
	endif
end

function/s getFDACStatus(instrID)
	variable instrID
	string  buffer = "", key = ""
	wave/t fdacvalstr	
	svar sc_fdackeys
	
	buffer = addJSONkeyval(buffer, "visa_address", getResourceAddress(instrID), addquotes=1)
	buffer = addJSONkeyval(buffer, "SamplingFreq", num2str(getFADCspeed(instrID)), addquotes=0)
	buffer = addJSONkeyval(buffer, "MeasureFreq", num2str(getFADCmeasureFreq(instrID)), addquotes=0)

	variable device = getDeviceNumber(instrID)
	variable i
	variable CHstart

	// DAC values
	CHstart = getFDChannelStartNum(instrID, adc=0)
	for(i=0;i<getFDInfoFromID(instrID, "numDAC");i+=1)
		sprintf key, "DAC%d{%s}", CHstart+i, fdacvalstr[CHstart+i][3]
		buffer = addJSONkeyval(buffer, key, num2numstr(getfdacOutput(instrID,i))) // getfdacOutput is PER instrument
	endfor

	// ADC values
	CHstart = getFDChannelStartNum(instrID, adc=1)
	for(i=0;i<getFDInfoFromID(instrID, "numADC");i+=1)
		buffer = addJSONkeyval(buffer, "ADC"+num2istr(CHstart+i), num2numstr(getfadcChannel(instrID,CHstart+i)))
	endfor
	
	// AWG info if used
	nvar sc_AWG_used
	if(sc_AWG_used == 1)
		buffer = addJSONkeyval(buffer, "AWG", getAWGstatus())  //NOTE: AW saved in getAWGstatus()
	endif
	
	return addJSONkeyval("", "FastDAC "+num2istr(device), buffer)
end


function/s getAWGstatus() 
	// Function to be called from getFDACstatus() to add a section with information about the AWG used
	// Also adds AWs used to HDF
	
	string buffer = ""// For storing JSON to return
	
	// Get the Global AWG list (which has info about what was used in scan)
	struct fdAWG_list AWG
	fdAWG_get_global_AWG_list(AWG)
	
	buffer = addJSONkeyval(buffer, "AW_Waves", AWG.AW_Waves, addquotes=1)							// Which waves were used (e.g. "0,1" for both AW0 and AW1)
	buffer = addJSONkeyval(buffer, "AW_Dacs", AWG.AW_Dacs, addquotes=1)								// Which Dacs output each wave (e.g. "01,2" for Dacs 0,1 outputting AW0 and Dac 2 outputting AW1)
	buffer = addJSONkeyval(buffer, "waveLen", num2str(AWG.waveLen), addquotes=0)					// How are the AWs in total samples
	buffer = addJSONkeyval(buffer, "numADCs", num2str(AWG.numADCs), addquotes=0)					// How many ADCs were selected to record when the AWG was set up
	buffer = addJSONkeyval(buffer, "samplingFreq", num2str(AWG.samplingFreq), addquotes=0)		// Sample rate of the Fastdac at time AWG was set up
	buffer = addJSONkeyval(buffer, "measureFreq", num2str(AWG.measureFreq), addquotes=0)			// Measure freq at time AWG was set up (i.e. sampleRate/numADCs)
	buffer = addJSONkeyval(buffer, "numWaves", num2str(AWG.numWaves), addquotes=0)				// How many AWs were used in total (should be 1 or 2)
	buffer = addJSONkeyval(buffer, "numCycles", num2str(AWG.numCycles), addquotes=0)				// How many full cycles of the AWs per DAC step
	buffer = addJSONkeyval(buffer, "numSteps", num2str(AWG.numSteps), addquotes=0)				// How many DAC steps for the full ramp

	return buffer
end


///////////////////////
//// Set functions ////
///////////////////////

function setFADCSpeed(instrID,speed,[loadCalibration]) // Units: Hz
	// set the ADC speed in Hz
	// set loadCalibration=1 to load save calibration
	variable instrID, speed, loadCalibration
	
	if(paramisdefault(loadCalibration))
		loadCalibration = 1
	elseif(loadCalibration != 1)
		loadCalibration = 0
	endif
	
	// check formatting of speed
	if(speed <= 0)
		print "[ERROR] \"setfadcSpeed\": Speed must be positive"
		abort
	endif
	
//	svar sc_fdackeys
	// variable numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",",")), i=0, numADCCh = 0, numDevice = 0
	variable numDevices = getNumDevices()
	string instrAddress = getResourceAddress(instrID)
	variable i, numADCCh, numDevice	
	string deviceAddress = "", cmd = "", response = ""
	for(i=0;i<numDevices;i+=1)
		deviceAddress = getFastdacVisaAddress(i+1)
		if(cmpstr(deviceAddress,instrAddress) == 0)
			numADCCh = getFDInfoFromDeviceNum(i+1, "numADC")
			numDevice = i+1
			break
		endif
	endfor
	for(i=0;i<numADCCh;i+=1)
		sprintf cmd, "CONVERT_TIME,%d,%d\r", i, 1.0/speed*1.0e6  // Convert from Hz to microseconds
		response = queryInstr(instrID, cmd, read_term="\n")  //Set all channels at same time (generally good practise otherwise can't read from them at the same time)
		response = sc_stripTermination(response,"\r\n")
		if(!fd_checkResponse(response,cmd))
			abort
		endif
	endfor
	
	speed = roundNum(1.0/str2num(response)*1.0e6,0)
	
	if(loadCalibration)
		try
			loadfADCCalibration(instrID,speed)
		catch
			variable rte = getrterror(1)
			print "WARNING[setFADCspeed]: loadFADCCalibration failed. If no calibration file exists, run CalibrateFADC() to create one"
		endtry			
	else
		print "[WARNING] \"setfadcSpeed\": Changing the ADC speed without ajdusting the calibration might affect the precision."
	endif
	
	// update window
	string adcSpeedMenu = "fadcSetting"+num2istr(numDevice)
	svar value = $("sc_fadcSpeed"+num2istr(numDevice))
	variable isoldvalue = findlistitem(num2str(speed),value,";")
	if(isoldvalue < 0)
		value = addlistItem(num2str(speed),value,";",Inf)
	endif
	value = sortlist(value,";",2)
	variable mode = whichlistitem(num2str(speed),value,";")+1
	popupMenu $adcSpeedMenu,mode=mode
	
	// Set Arbitrary Wave Generator global struct .initialized to 0 (i.e. force user to update AWG because sample rate affects it)
	fdAWG_reset_init()
end

function rampOutputFDAC(instrID,channel,output, ramprate, [ignore_lims]) // Units: mV, mV/s
	// ramps a channel to the voltage specified by "output".
	// ramp is controlled locally on DAC controller.
	// channel must be the channel set by the GUI.
	variable instrID, channel, output, ramprate, ignore_lims
	wave/t fdacvalstr, old_fdacvalstr
	svar sc_fdackeys
	
	// TOOD: refactor with getFDInfoFromID()/getChannelsOnFD() etc

	variable numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",","))
	variable i=0, devchannel = 0, startCh = 0, numDACCh = 0
	string deviceAddress = "", err = "", instrAddress = getResourceAddress(instrID)
	for(i=0;i<numDevices;i+=1)
		numDACCh =  str2num(stringbykey("numDACCh"+num2istr(i+1),sc_fdackeys,":",","))
		if(startCh+numDACCh-1 >= channel)
			// this is the device, now check that instrID is pointing at the same device
			deviceAddress = stringbykey("visa"+num2istr(i+1),sc_fdackeys,":",",")
			if(cmpstr(deviceAddress,instrAddress) == 0)
				devchannel = channel-startCh
				break
			else
				sprintf err, "[ERROR] \"rampOutputfdac\": channel %d is not present on device with address %s", channel, instrAddress
				print(err)
				resetfdacwindow(channel)
				abort
			endif
		endif
		startCh += numDACCh
	endfor
	
	// check that output is within hardware limit
	nvar fdac_limit
	if(abs(output) > fdac_limit || numtype(output) != 0)
		sprintf err, "[ERROR] \"rampOutputfdac\": Output voltage on channel %d outside hardware limit", channel
		print err
		resetfdacwindow(channel)
		abort
	endif

	if(ignore_lims != 1)  // I.e. ignore if already checked in pre scan checks
		// check that output is within software limit
		// overwrite output to software limit and warn user
		string softLimitPositive = "", softLimitNegative = "", expr = "(-?[[:digit:]]+),\s*([[:digit:]]+)"
		splitstring/e=(expr) fdacvalstr[channel][2], softLimitNegative, softLimitPositive
		if(output < str2num(softLimitNegative) || output > str2num(softLimitPositive))
			switch(sign(output))
				case -1:
					output = str2num(softLimitNegative)
					break
				case 1:
					if(output != 0)
						output = str2num(softLimitPositive)
					else
						output = 0
					endif
					break
			endswitch
			string warn
			sprintf warn, "[WARNING] \"rampOutputfdac\": Output voltage must be within limit. Setting channel %d to %.3fmV\n", channel, output
			print warn
		endif
	
		// Check that ramprate is within software limit, otherwise use software limit
		if (ramprate > str2num(fdacvalstr[channel][4]) || numtype(ramprate) != 0)
			printf "[WARNING] \"rampOutputfdac\": Ramprate of %.0fmV/s requested for channel %d. Using max_ramprate of %.0fmV/s instead\n" ramprate, channel, str2num(fdacvalstr[channel][4])
			ramprate = str2num(fdacvalstr[channel][4])
			if (numtype(ramprate) != 0)
				abort "ERROR[rampOutputFDAC]: Bad ramprate in ScanController_Fastdac window for channel "+num2str(channel)
			endif
		endif
	endif 
		
	// read current dac output and compare to window
	variable currentoutput = getfdacOutput(instrID,devchannel)
	
	// ramp channel to output
	variable delay = abs(output-currentOutput)/ramprate
	string cmd = "", response = ""
	sprintf cmd, "RAMP_SMART,%d,%.4f,%.3f", devchannel, output, ramprate
	if(delay > 2)
		string delaymsg = ""
		sprintf delaymsg, "Waiting for fastdac Ch%d\n\tto ramp to %dmV", channel, output
		response = queryInstrProgress(instrID, cmd+"\r", delay, delaymsg, read_term="\n")
	else
		response = queryInstr(instrID, cmd+"\r", read_term="\n", delay=delay)
	endif
	response = sc_stripTermination(response,"\r\n")
	
	// check respose
	if(fd_checkResponse(response,cmd,isString=1,expectedResponse="RAMP_FINISHED"))
		output = getfdacOutput(instrID, devchannel)
		updatefdacValStr(channel, output, update_oldValStr=1)
	else
		resetfdacwindow(channel)
		abort
	endif
end


function RampMultipleFDAC(InstrID, channels, setpoint, [ramprate, ignore_lims])
	variable InstrID, setpoint, ramprate, ignore_lims
	string channels
	
	ramprate = numtype(ramprate) == 0 ? ramprate : 0  // If not a number, then set to zero (which means will be overridden by ramprate in window)
	
	assertSeparatorType(channels, ",")
	channels = SF_get_channels(channels, fastdac=1)
	
	variable i=0, channel, nChannels = ItemsInList(channels, ",")
	variable channel_ramp
	for(i=0;i<nChannels;i+=1)
		channel = str2num(StringFromList(i, channels, ","))
		channel_ramp = ramprate != 0 ? ramprate : str2num(getFdacInfo(num2str(channel), "ramprate"))
		rampOutputfdac(instrID, channel, setpoint, channel_ramp, ignore_lims=ignore_lims)  
	endfor
end


/////////////////////////////////////////////////////////////////////////////////////
//////////////////////// Calibration /////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
function loadFadcCalibration(instrID,speed)
	variable instrID,speed
	
	string regex = "", filelist = "", jstr=""
	variable i=0,k=0
	
	svar sc_fdackeys
	variable numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",",")), numADCCh=0, numDACCh=0,deviceNum=0
	string instrAddress = getResourceAddress(instrID), deviceAddress = ""
	for(i=0;i<numDevices;i+=1)
		deviceAddress = stringbykey("visa"+num2istr(i+1),sc_fdackeys,":",",")
		if(cmpstr(deviceAddress,instrAddress) == 0)
			numDACCh = str2num(stringbykey("numDACCh"+num2istr(i+1),sc_fdackeys,":",","))
			numADCCh = str2num(stringbykey("numADCCh"+num2istr(i+1),sc_fdackeys,":",","))
			deviceNum = i+1
			break
		endif
	endfor
	
	sprintf regex, "fADC%dCalibration_%d", deviceNum, speed
	print regex
	filelist = indexedfile(config,-1,".txt")
	filelist = greplist(filelist,regex)
	if(itemsinlist(filelist) == 1)
		// we have a calibration file
		jstr = readtxtfile(stringfromlist(0,filelist),"config")
	elseif(itemsinlist(filelist) > 1)
		// somehow there is more than one file. Try to find the correct one!
		for(i=0;i<itemsinlist(filelist);i+=1)
			if(cmpstr(stringfromlist(i,filelist),regex) == 0)
				// this is the correct file
				k = -1
				break
			endif
		endfor
		if(k < 0)
			jstr = readtxtfile(stringfromlist(i,filelist),"config")
		else
			// no calibration file found!
			// raise error
			print "[ERROR] \"loadfADCCalibration\": No calibration file found!"
			abort
		endif
	else
		// no calibration file found!
		// raise error
		print "[ERROR] \"loadfADCCalibration\": No calibration file found!"
		abort
	endif
	
	// do some checks
	if(cmpstr(getresourceaddress(instrID),getJSONvalue(jstr, "visa_address")) == 0)
		// it's the same instrument
	else
		// not the same visa address, likely not the same instrument, abort!
		print "[ERORR] \"loadfADCCalibration\": visa address' not the same!"
		abort
	endif
	if(speed == str2num(getJSONvalue(jstr, "speed")))
		// it's the correct speed
	else
		// not the same speed, abort!
		print "[ERORR] \"loadfADCCalibration\": speed is not correct!"
		abort
	endif
	
	// update the calibration on the the instrument
	variable zero_scale = 0, full_scale = 0
	string response = ""
	for(i=0;i<str2num(getJSONvalue(jstr, "num_channels"));i+=1)
		zero_scale = str2num(getJSONvalue(jstr, "zero-scale"+num2istr(i)))
		full_scale = str2num(getJSONvalue(jstr, "full-scale"+num2istr(i)))
		updatefadcCalibration(instrID,i,zero_scale,full_scale)
	endfor
end

function CalibrateFDAC(instrID)
	// Use this function to calibrate all dac channels.
	// You need a DMM that you really trust (NOT a hand held one)!
	// The calibration will only work if initFastDAC() has been executed first.
	// Follow the instructions on screen.
	variable instrID
	
	sc_openinstrconnections(0)
	
	svar/z sc_fdackeys
	if(!svar_exists(sc_fdackeys))
		print "[ERROR] \"fdacCalibrate\": Run initFastDAC() before calibration."
		abort
	endif
	
	// check that user has all the bits needed!
	variable user_response = 0
	user_response = ask_user("You will need a DMM you trust set to return six decimal places. Press OK to continue",type=1)
	if(user_response == 0)
		print "[ERROR] \"fdacCalibrate\": User abort!"
		abort
	endif
	
	variable numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",",")), i=0, numDACCh=0, deviceNum=0
	string instrAddress = getResourceAddress(instrID), deviceAddress = ""
	for(i=0;i<numDevices;i+=1)
		deviceAddress = stringbykey("visa"+num2istr(i+1),sc_fdackeys,":",",")
		if(cmpstr(deviceAddress,instrAddress) == 0)
			numDACCh = str2num(stringbykey("numDACCh"+num2istr(i+1),sc_fdackeys,":",","))
			deviceNum = i+1
			break
		endif
	endfor
	
	// reset calibrations on all DAC channels
	for(i=0;i<numDACCh;i+=1)
		ResetfdacCalibration(instrID,i)
	endfor
	
	// start calibration
	string question = "", offsetReg = "", gainReg = "", message = "", result="", key=""
	variable user_input = 0, channel = 0, offset = 0
	for(i=0;i<numDACCh;i+=1)
		channel = i
		sprintf question, "Calibrating DAC Channel %d. Connect DAC Channel %d to the DMM. Press YES to continue", channel, channel
		user_response = ask_user(question,type=1)
		if(user_response == 0)
			print "[ERROR] \"fdacCalibrate\": User abort! DAC's are NOT calibrated anymore.\rYou must re-run the calibration before you can trust the output values!"
			abort
		endif
		
		// ramp channel to 0V
		rampOutputfdac(instrID,channel,0, 100000, ignore_lims=1)
		sprintf question, "Input value displayed by DMM in volts."
		user_input = prompt_user("DAC offset calibration",question)
		if(numtype(user_input) == 2)
			print "[ERROR] \"fdacCalibrate\": User abort! DAC's are NOT calibrated anymore.\rYou must re-run the calibration before you can trust the output values!"
			abort
		endif
		
		// write offset to FastDAC
		// FastDAC returns the gain value used in uV
		offsetReg = setfdacCalibrationOffset(instrID,channel,user_input)
		sprintf key, "offset%d_", channel
		result = replacenumberbykey(key+"stepsize",result,str2num(stringfromlist(1,offsetReg,",")),":",",")
		result = replacenumberbykey(key+"register",result,str2num(stringfromlist(2,offsetReg,",")),":",",")
		sprintf message, "Offset calibration of DAC channel %d finished. Final values are:\rOffset stepsize = %.2fuV\rOffset register = %d", channel, str2num(stringfromlist(1,offsetReg,",")), str2num(stringfromlist(2,offsetReg,","))
		print message
		
		// ramp channel to -10V
		rampOutputfdac(instrID,channel,-10000, 100000, ignore_lims=1)
		sprintf question, "Input value displayed by DMM in volts."
		user_input = prompt_user("DAC gain calibration",question)
		if(numtype(user_input) == 2)
			print "[ERROR] \"fdacCalibrate\": User abort! DAC's are NOT calibrated anymore.\rYou must re-run the calibration before you can trust the output values!"
			abort
		endif
		
		// write offset to FastDAC
		// FastDAC returns the gain value used in uV
		offset = user_input+10 
		gainReg = setfdacCalibrationGain(instrID,channel,offset)
		sprintf key, "gain%d_", channel
		result = replacenumberbykey(key+"stepsize",result,str2num(stringfromlist(1,gainReg,",")),":",",")
		result = replacenumberbykey(key+"register",result,str2num(stringfromlist(2,gainReg,",")),":",",")
		sprintf message, "Gain calibration of DAC channel %d finished. Final values are:\rGain stepsize = %.2f uV\rGain register = %d", channel, str2num(stringfromlist(0,gainReg,",")), str2num(stringfromlist(1,gainReg,","))
		print message
	endfor
	
	// calibration complete
	savefdaccalibration(deviceAddress,deviceNum,numDACCh,result)
	ask_user("DAC calibration complete! Result has been written to file on \"config\" path.", type=0)
end

function CalibrateFADC(instrID)
	// Use this function to calibrate all adc channels.
	// The calibration will only work if initFastDAC() has been executed first.
	// The calibration uses the DAC channels to calibrate the ADC channels,
	// if the DAC's aren't calibrated this won't give good results!
	// Follow the instructions on screen.
	variable instrID
	
	svar/z sc_fdackeys
	if(!svar_exists(sc_fdackeys))
		print "[ERROR] \"fadcCalibrate\": Run initFastDAC() before calibration."
		abort
	endif
	
	variable numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",",")), i=0, numADCCh=0, numDACCh=0,deviceNum=0
	string instrAddress = getResourceAddress(instrID), deviceAddress = ""
	for(i=0;i<numDevices;i+=1)
		deviceAddress = stringbykey("visa"+num2istr(i+1),sc_fdackeys,":",",")
		if(cmpstr(deviceAddress,instrAddress) == 0)
			numDACCh = str2num(stringbykey("numDACCh"+num2istr(i+1),sc_fdackeys,":",","))
			numADCCh = str2num(stringbykey("numADCCh"+num2istr(i+1),sc_fdackeys,":",","))
			deviceNum = i+1
			break
		endif
	endfor
	
	if(numADCCh > numDACCh)
		print "[ERROR] \"fadcCalibrate\": The number of ADC channels is greater than the number of DAC channels.\rUse \"ADC_CH_ZERO_SC_CAL\" & \"ADC_CH_FULL_SC_CAL\" to calibrate each ADC channel seperately!"
		abort
	endif
	
	// get current speed
	variable adcSpeed = roundNum(getfadcSpeed(instrID),0) // round to integer
	
	// check that user has all the bits needed!
	variable user_response = 0
	string question = ""
	sprintf question, "Connect the DAC channel 0-%d --> ADC channel 0-%d. Press YES to continue", numADCCh-1, numADCCh-1
	user_response = ask_user(question,type=1)
	if(user_response != 1)
		print "[ERROR] \"fadcCalibrate\": User abort!"
		abort
	endif
	
	// Do calibration
	string cmd = "CAL_ADC_WITH_DAC\r"
	string response = queryInstr(instrID,cmd,read_term="\n",delay=2)
	response = sc_stripTermination(response,"\r\n")

	print response
	// turn result into key/value string
	// response is formatted like this: "numCh0,zero,numCh1,zero,numCh0,full,numCh1,full,"
	string result="", key_zero="", key_full=""
	variable zeroIndex=0,fullIndex=0, calibrationFail = 0
	for(i=0;i<numADCCh;i+=1)
		zeroIndex = whichlistitem("ch"+num2istr(i),response,",",0)+1
		fullIndex = whichlistitem("ch"+num2istr(i),response,",",zeroIndex)+1
		if(zeroIndex <= 0 || fullIndex <= 0)
			calibrationFail = 1
			break
		endif
		sprintf key_zero, "zero-scale%d", i
		sprintf key_full, "full-scale%d", i
		result = replaceNumberByKey(key_zero,result,str2num(stringfromlist(zeroIndex,response,",")),":",",")
		result = replaceNumberByKey(key_full,result,str2num(stringfromlist(fullIndex,response,",")),":",",")
	endfor
	
	// read calibration completion
	response = readInstr(instrID,read_term="\n")
	response = sc_stripTermination(response,"\r\n")
	if(fd_checkResponse(response,cmd,isString=1,expectedResponse="CALIBRATION_FINISHED") && calibrationFail == 0)
		// all good, calibration complete
		rampMultipleFDAC(instrID, "0,1,2,3", 0, ramprate=10000)
		savefadccalibration(deviceAddress,deviceNum,numADCCh,result,adcSpeed)
		ask_user("ADC calibration complete! Result has been written to file on \"config\" path.", type=0)
	else
		print "[ERROR] \"fadcCalibrate\": Calibration failed."
		abort
	endif
end

function saveFadcCalibration(deviceAddress,deviceNum,numADCCh,result,adcSpeed)
	string deviceAddress, result
	variable deviceNum, numADCCh, adcSpeed
	
	svar/z sc_fdackeys
	
	// create JSON string
	string buffer = "", zeroScale = "", fullScale = "", key = ""
	variable i=0
	
	buffer = addJSONkeyval(buffer,"visa_address",deviceAddress,addQuotes=1)
	buffer = addJSONkeyval(buffer,"speed",num2str(adcspeed))
	buffer = addJSONkeyval(buffer,"num_channels",num2istr(numADCCh))
	for(i=0;i<numADCCh;i+=1)
		sprintf key, "zero-scale%d", i
		zeroScale = stringbykey(key,result,":",",")
		buffer = addJSONkeyval(buffer,key,zeroScale)
		sprintf key, "full-scale%d", i
		fullScale = stringbykey(key,result,":",",")
		buffer = addJSONkeyval(buffer,key,fullScale)
	endfor
	
	// create ADC calibration file
	string filename = ""
	sprintf filename, "fADC%dCalibration_%d.txt", deviceNum, adcSpeed
	writetofile(prettyJSONfmt(buffer),filename,"config")
end

function saveFdacCalibration(deviceAddress,deviceNum,numDACCh,result)
	string deviceAddress, result
	variable deviceNum, numDACCh
	
	svar/z sc_fdackeys
	
	// create JSON string
	string buffer = "", offset = "", gain = "", key = ""
	variable i=0
	
	buffer = addJSONkeyval(buffer,"visa_address",deviceAddress,addQuotes=1)
	buffer = addJSONkeyval(buffer,"num_channels",num2istr(numDACCh))
	for(i=0;i<numDACCh;i+=1)
		sprintf key, "offset%d_stepsize", i
		offset = stringbykey(key,result,":",",")
		buffer = addJSONkeyval(buffer,key,offset)
		sprintf key, "offset%d_register", i
		offset = stringbykey(key,result,":",",")
		buffer = addJSONkeyval(buffer,key,offset)
		sprintf key, "gain%d_stepsize", i
		gain = stringbykey(key,result,":",",")
		buffer = addJSONkeyval(buffer,key,gain)
		sprintf key, "gain%d_register", i
		gain = stringbykey(key,result,":",",")
		buffer = addJSONkeyval(buffer,key,gain)
	endfor

	// create DAC calibration file
	string filename = ""
	sprintf filename, "fDAC%dCalibration_%d.txt", deviceNum, unixtime()
	writetofile(prettyJSONfmt(buffer),filename,"config")
end

function ResetFdacCalibration(instrID,channel)
	variable instrID, channel
	
	string cmd="", response="", err=""
	sprintf cmd, "DAC_RESET_CAL,%d\r", channel
	response = queryInstr(instrID,cmd,read_term="\n")
	response = sc_stripTermination(response,"\r\n")
	if(fd_checkResponse(response,cmd,isString=1,expectedResponse="CALIBRATION_RESET"))
		// all good
	else
		sprintf err, "[ERROR] \"fdacResetCalibration\": Reset of DAC channel %d failed! - Response from Fastdac was %s", channel, response
		print err
		abort
	endif 
end

function/s setFdacCalibrationOffset(instrID,channel,offset)
	variable instrID, channel, offset
	
	string cmd="", response="", err="",result=""
	sprintf cmd, "DAC_OFFSET_ADJ,%d,%.6f\r", channel, offset
	response = queryInstr(instrID,cmd,read_term="\n")
	result = sc_stripTermination(response,"\r\n")
	
	// response is formatted like this: "channel,offsetStepsize,offsetRegister"
	response = readInstr(instrID,read_term="\n")
	response = sc_stripTermination(response,"\r\n")
	
	if(fd_checkResponse(response,cmd,isString=1,expectedResponse="CALIBRATION_FINISHED"))
		return result
	else
		sprintf err, "[ERROR] \"fdacResetCalibrationOffset\": Calibrating offset on DAC channel %d failed!", channel
		print err
		abort
	endif
end

function/s setFdacCalibrationGain(instrID,channel,offset)
	variable instrID, channel, offset
	
	string cmd="", response="", err="",result=""
	sprintf cmd, "DAC_GAIN_ADJ,%d,%.6f\r", channel, offset
	response = queryInstr(instrID,cmd,read_term="\n")
	result = sc_stripTermination(response,"\r\n")
	
	// response is formatted like this: "channel,offsetStepsize,offsetRegister"
	response = readInstr(instrID,read_term="\n")
	response = sc_stripTermination(response,"\r\n")
	
	if(fd_checkResponse(response,cmd,isString=1,expectedResponse="CALIBRATION_FINISHED"))
		return result
	else
		sprintf err, "[ERROR] \"fdacResetCalibrationGain\": Calibrating gain of DAC channel %d failed!", channel
		print err
		abort
	endif
end

function updateFadcCalibration(instrID,channel,zeroScale,fullScale)
	variable instrID,channel,zeroScale,fullScale
	
	string cmd="", response="", err=""
	sprintf cmd, "WRITE_ADC_CAL,%d,%d,%d\r", channel, zeroScale, fullScale
	response = queryInstr(instrID,cmd,read_term="\n")
	response = sc_stripTermination(response,"\r\n")
	
	if(fd_checkResponse(response,cmd,isString=1,expectedResponse="CALIBRATION_CHANGED"))
		// all good!
	else
		sprintf err, "[ERROR] \"updatefadcCalibration\": Updating calibration of ADC channel %d failed!", channel
		print err
		abort
	endif
end


///////////////////
//// Utilities ////
///////////////////
function fd_get_numpts_from_sweeprate(start, fin, sweeprate, measureFreq)
/// Convert sweeprate in mV/s to numptsx for fdacrecordvalues
	variable start, fin, sweeprate, measureFreq
	if (start == fin)
		abort "ERROR[fd_get_numpts_from_sweeprate]: Start == Fin so can't calculate numpts"
	endif
	variable numpts = round(abs(fin-start)*measureFreq/sweeprate)   // distance * steps per second / sweeprate
	return numpts
end

function fd_get_sweeprate_from_numpts(start, fin, numpts, measureFreq)
	// Convert numpts into sweeprate in mV/s
	variable start, fin, numpts, measureFreq
	if (numpts == 0)
		abort "ERROR[fd_get_numpts_from_sweeprate]: numpts = 0 so can't calculate sweeprate"
	endif
	variable sweeprate = round(abs(fin-start)*measureFreq/numpts)   // distance * steps per second / numpts
	return sweeprate
end

function ClearFdacBuffer(instrID)
	// Stops any sweeps which might be running and clears the buffer
	variable instrID
	
	variable count=0, total = 0
	string buffer=""
	writeInstr(instrID,"STOP\r")
	total = -5 //Stop command makes fastdac return a 5 character string
	do 
		viRead(instrID, buffer, 2000, count) 
		total += count
	while(count != 0)
	printf "Cleared %d bytes of data from buffer\r", total
end

function stopFDACsweep(instrID)  
	// Stops sweep and clears buffer 
	variable instrID
	ClearfdacBuffer(instrID)
end

function fdacChar2Num(c1, c2)
	// Conversion of bytes to float
	//
	// Given two strings of length 1
	//  - c1 (higher order) and
	//  - c2 lower order
	// Calculate effective FastDac value
	string c1, c2
	variable minVal = -10000, maxVal = 10000

	// Check params for violation
	if(strlen(c1) != 1 || strlen(c2) != 1)
		print "[ERROR] strlen violation -- strings passed to fastDacChar2Num must be length 1"
		return 0
	endif
	variable b1, b2
	// Calculate byte values
	b1 = char2num(c1[0])
	b2 = char2num(c2[0])
	// Convert to unsigned
	if (b1 < 0)
		b1 += 256
	endif
	if (b2 < 0)
		b2 += 256
	endif
	// Return calculated FastDac value
	return (((b1*2^8 + b2)*(maxVal-minVal)/(2^16 - 1))+minVal)
end

//////////////////////////////////////////////////////////////////////////////////////////
///////////////////////// Spectrum Analyzer //////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////

function FDacSpectrumAnalyzer(instrID, scanlength,[numAverage,comments,nosave])
	// scanlength is in sec
	// if linear is set to 1, the spectrum will be plotted on a linear scale
	variable instrID, scanlength, numAverage, nosave
	string comments
	string datestring = strTime()
	
	comments = selectString(paramisdefault(comments), comments, "")	
	numAverage = paramisDefault(numAverage) ? 1 : numAverage
	
	// Turn off resampling during noise spectrum scan
	nvar sc_resampleFreqCheckFadc
	variable original_resample_state = sc_resampleFreqCheckFadc 
	sc_resampleFreqCheckFadc = 0

	// Initialize ScanVars
	Struct ScanVars S
	initFDscanVars(S, instrID, 0, scanlength, duration=scanlength, x_label="Time /s", y_label="Current /nA", comments="spectrum,"+comments)
	S.readVsTime = 1

	// Check things like ADCs on same device
	SFfd_pre_checks(S)

	// Initialize graphs and waves
	initializeScan(S)  // Going to reopen graphs below anyway (to include frequency graphs)

	// Initialize Spectrum waves
	string wn, wn_lin
	string log_freq_wavenames = ""
	string lin_freq_wavenames = ""
	variable numChannels = getNumFADC()
	string adc_channels = getRecordedFastdacInfo("channels")
	variable i
	for(i=0;i<numChannels;i+=1)
		wn = "spectrum_fftADC"+stringfromlist(i,adc_channels, ";")
		make/o/n=(S.numptsx/2) $wn = nan
		setscale/i x, 0, S.measureFreq/(2.0), $wn
		log_freq_wavenames = addListItem(wn, log_freq_wavenames, ";", INF)
				
		wn_lin = "spectrum_fftADClin"+stringfromlist(i,adc_channels, ";")
		make/o/n=(S.numptsx/2) $wn_lin = nan
		setscale/i x, 0, S.measureFreq/(2.0), $wn_lin
		lin_freq_wavenames = addListItem(wn_lin, lin_freq_wavenames, ";", INF)
	endfor

	// Initialize all graphs
	string all_graphIDs = initializeGraphsForWavenames(get1DWaveNames(1,1), "Time /s", is2d=S.is2d, y_label="ADC /mV")  // RAW ADC readings
	all_graphIDs += initializeGraphsForWavenames(get1DWaveNames(0,1), "Time /s", is2d=S.is2d, y_label="Current /nA")    // Calculated data (should be in nA)
	
	string graphIDs
	graphIDs = initializeGraphsForWavenames(log_freq_wavenames, "Frequency /Hz", is2d=0, y_label="Ylabel for log spectrum?")
	all_graphIDs = all_graphIDs+graphIDs
	graphIDs = initializeGraphsForWavenames(lin_freq_wavenames, "Frequency /Hz", is2d=0, y_label="Ylabel for lin spectrum?")
	all_graphIDs = all_graphIDs+graphIDs
	arrangeWindows(all_graphIDs)

	// Record data
	string wavenames = getRecordedFastdacInfo("calc_names")  // ";" separated list of recorded calculated waves
	variable j
	for (i=0; i<numAverage; i++)
		NEW_Fd_record_values(S, i)		

		for (j=0;j<itemsInList(wavenames);j++)
			// Calculate spectrums from calc wave
			wave w = $stringFromList(j, wavenames)
			wave fftw = calculate_spectrum(w)  // Log spectrum
			wave fftwlin = calculate_spectrum(w, linear=1)  // Linear spectrum

			// Add to averaged waves
			wave fftwave = $stringFromList(j, log_freq_wavenames)
			wave fftwavelin = $stringFromList(j, lin_freq_wavenames)
			if(i==0) // If first pass, initialize waves
				fftwave = fftw
				fftwavelin = fftwlin
			else  // Else add and average
				fftwave = fftwave*i + fftw  // So weighting of rows is correct when averaging
				fftwave = fftwave/(i+1)      // ""
				
				fftwavelin = fftwavelin*i + fftwlin
				fftwavelin = fftwavelin/(i+1)
			endif
		endfor
	endfor

	// Return resampling state to whatever it was before
	sc_resampleFreqCheckFadc = original_resample_state

	if (!nosave)
		EndScan(S=S, additional_wavenames=log_freq_wavenames+lin_freq_wavenames) 
	endif
end


function/WAVE calculate_spectrum(time_series, [scan_duration, linear])
	// Takes time series data and returns power spectrum
	wave time_series  // Time series (in correct units -- i.e. check that it's in nA first)
	variable scan_duration // If passing a wave which does not have Time as x-axis, this will be used to rescale
	variable linear // Whether to return with linear scale (or log scale)

	duplicate/free time_series tseries
	if (scan_duration)
		setscale/i x, 0, scan_duration, tseries
	else
		scan_duration = DimDelta(time_series, 0) * DimSize(time_series, 0)
	endif

	variable last_val = dimSize(time_series,0)-1
	if (mod(dimsize(time_series, 0), 2) != 0)  // ODD number of points, must be EVEN to do powerspec
		last_val = last_val - 1
	endif
		
	
	// Built in powerspectrum function
	wave w_Periodogram
	wave powerspec
	if (!linear)  // Use log scale
		DSPPeriodogram/PARS/DBR=1/NODC=1/R=[0,(last_val)] tseries  
		duplicate/free w_Periodogram, powerspec
		powerspec = powerspec+10*log(scan_duration)  // This is so that the powerspec is independent of scan_duration
	else  // Use linear scale
		DSPPeriodogram/PARS/NODC=1/R=[0, (last_val)] tseries
		duplicate/free w_Periodogram, powerspec
		// TODO: I'm not sure this is correct, but I don't know what should be done to fix it -- TIM
		powerspec = powerspec*scan_duration  // This is supposed to be so that the powerspec is independent of scan_duration
	endif
	powerspec[0] = NaN
	return powerspec
end

function plot_PowerSpectrum(w, [scan_duration, linear, powerspec_name])
	wave w
	variable scan_duration, linear
	string powerspec_name // Wavename to save powerspectrum in (useful if you want to display more than one at a time)
	
	wave powerspec = calculate_spectrum(w, scan_duration=scan_duration, linear=linear)
	
	if(!paramIsDefault(powerspec_name))
		duplicate/o powerspec $powerspec_name
		wave tempwave = $powerspec_name
	else
		duplicate/o powerspec tempwave
	endif

	string y_label = selectString(linear, "Spectrum [dBnA/sqrt(Hz)]", "Spectrum [nA/sqrt(Hz)]")
	initializeGraphsForWavenames(NameOfWave(tempwave), "Frequency /Hz", is2d=0, y_label=y_label)
	 doWindow/F $winName(0,1)
end

//////////////////////////////////
///// Load FastDACs from HDF /////
//////////////////////////////////

function fdLoadFromHDF(datnum, [no_check])
	// Function to load fastDAC values and labels from a previously save HDF file in sweeplogs in current data directory
	// Requires Dac info to be saved in "DAC{label} : output" format
	// with no_check = 0 (default) a window will be shown to user where values can be changed before committing to ramping, also can chose not to load from there
	// setting no_check = 1 will ramp to loaded settings without user input
	// Fastdac_num is which fastdacboard to load. 3/2020 - Not tested
	variable datnum, no_check
	variable response
	
	svar sc_fdackeys
	variable numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",","))
	if (numDevices !=1)
		print "WARNING[fdLoadFromHDF]: Only tested to load 1 Fastdac, only first FastDAC will be loaded without code changes"
	endif	
	get_fastdacs_from_hdf(datnum, fastdac_num=1) // Creates/Overwrites load_fdacvalstr
	
	if (no_check == 0)  //Whether to show ask user dialog or not
		response = fdLoadAskUser()
	else
		response = -1 
	endif 
	if(response == 1)
		// Do_nothing
		print "Keep current FastDAC state chosen, no changes made"
	elseif(response == -1)
		// Load from HDF
		printf "Loading FastDAC values and labels from dat%d\r", datnum
		wave/t load_fdacvalstr
		duplicate/o/t load_fdacvalstr, fdacvalstr //Overwrite dacvalstr with loaded values

		// Ramp to new values
		update_all_fdac()
	else
		print "[WARNING] Bad user input -- FastDAC will remain in current state"
	endif
end


function get_fastdacs_from_hdf(datnum, [fastdac_num])
	//Creates/Overwrites load_fdacvalstr by duplicating the current fdacvalstr then changing the labels and outputs of any values found in the metadata of HDF at dat[datnum].h5
	//Leaves fdacvalstr unaltered	
	variable datnum, fastdac_num
	variable sl_id, fd_id  //JSON ids
	
	fastdac_num = paramisdefault(fastdac_num) ? 1 : fastdac_num 
	
	if(fastdac_num != 1)
		abort "WARNING: This is untested... remove this abort if you're feeling lucky!"
	endif
	
	sl_id = get_sweeplogs(datnum)  // Get Sweep_logs JSON
	fd_id = getJSONXid(sl_id, "FastDAC "+num2istr(fastdac_num)) // Get FastDAC JSON from Sweeplogs

	wave/t keys = JSON_getkeys(fd_id, "")
	wave/t fdacvalstr
	duplicate/o/t fdacvalstr, load_fdacvalstr
	
	variable i
	string key, label_name, str_ch
	variable ch = 0
	for (i=0; i<numpnts(keys); i++)  // These are in a random order. Keys must be stored as "DAC#{label}:output" in JSON
		key = keys[i]
		if (strsearch(key, "DAC", 0) != -1)  // Check it is actually a DAC key and not something like com_port
			SplitString/E="DAC(\d*){" key, str_ch //Gets DAC# so that I store values in correct places
			ch = str2num(str_ch)
			
			load_fdacvalstr[ch][1] = num2str(JSON_getvariable(fd_id, key))
			SplitString/E="{(.*)}" key, label_name  //Looks for label inside {} part of e.g. BD{label}
			label_name = replaceString("~1", label_name, "/")  // Somehow igor reads '/' as '~1' don't know why...
			load_fdacvalstr[ch][3] = label_name
		endif
	endfor
	JSONXOP_Release /A  //Clear all stored JSON strings
end

function fdLoadAskUser()
	variable/g fd_load_answer
	wave/t load_fdacvalstr
	wave/t fdacvalstr
	wave fdacattr
	if (waveexists(load_fdacvalstr) && waveexists(fdacvalstr) && waveexists(fdacattr))	
		execute("fdLoadWindow()")
		PauseForUser fdLoadWindow
		return fd_load_answer
	else
		abort "ERROR[bdLoadAskUser]: either load_fdacvalstr, fdacvalstr, or fdacattr doesn't exist when it should!"
	endif
end

function fdLoadAskUserButton(action) : ButtonControl
	string action
	variable/g fd_load_answer
	strswitch(action)
		case "do_nothing":
			fd_load_answer = 1
			dowindow/k fdLoadWindow
			break
		case "load_from_hdf":
			fd_load_answer = -1
			dowindow/k fdLoadWindow
			break
	endswitch
end


Window fdLoadWindow() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(0,0,740,390) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	
	variable tcoord = 80
	
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 90, 35,"FastDAC Load From HDF" // Headline
	
	SetDrawEnv fsize= 20,fstyle= 1
	DrawText 70, 65,"Current Setup" 
	
	SetDrawEnv fsize=14, fstyle=1
	DrawText 15, tcoord, "Ch"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 50, tcoord, "Output"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 120, tcoord, "Limit"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 220, tcoord, "Label"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 287, tcoord, "Ramprate"
	ListBox fdaclist,pos={10,tcoord+5},size={360,270},fsize=14,frame=2,widths={30,70,100,65}
	ListBox fdaclist,listwave=root:fdacvalstr,selwave=root:fdacattr,mode=1
	
	variable x_offset = 360
	SetDrawEnv fsize= 20,fstyle= 1
	DrawText 70+x_offset, 65,"Load from HDF Setup" 

	SetDrawEnv fsize=14, fstyle=1
	DrawText 15+x_offset, tcoord, "Ch"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 50+x_offset, tcoord, "Output"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 120+x_offset, tcoord, "Limit"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 220+x_offset, tcoord, "Label"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 287+x_offset, tcoord, "Ramprate"
	ListBox load_fdaclist,pos={10+x_offset,tcoord+5},size={360,270},fsize=14,frame=2,widths={30,70,100,65}
	ListBox load_fdaclist,listwave=root:load_fdacvalstr,selwave=root:fdacattr,mode=1
	


	Button do_nothing,pos={80,tcoord+280},size={120,20},proc=fdLoadAskUserButton,title="Keep Current Setup"
	Button load_from_hdf,pos={80+x_offset,tcoord+280},size={100,20},proc=fdLoadAskUserButton,title="Load From HDF"
EndMacro


////////////////////////////////////////////////////
//////////// Arbitrary Wave Generator //////////////
////////////////////////////////////////////////////

function fdAWG_reset_init()
	// sets global AWG_list.initialized to 0 so that it will fail pre scan checks. (to be used when changing things like sample rate, AWs etc)
	
	// Get current AWG_list
	struct fdAWG_list S
	fdAWG_get_global_AWG_list(S)
	
	// Set initialized to zero to prevent fd_Record_values from running without AWG_list being set up again first
	S.initialized = 0

	// Store changes
	fdAWG_set_global_AWG_list(S)
end

function fdAWG_setup_AWG(instrID, [AWs, DACs, numCycles, verbose])
	// Function which initializes AWG_List s.t. selected DACs will use selected AWs when called in fd_Record_Values
	// Required because fd_Record_Values needs to know the total number of samples it will get back, which is calculated from values in AWG_list
	// IGOR AWs must be set in a separate function (which should reset AWG_List.initialized to 0)
	// Sets AWG_list.initialized to 1 to allow fd_Record_Values to run
	// If either parameter is not provided it will assume using previous settings
	variable instrID  // For printing information about frequency etc
	string AWs, DACs  // CSV for AWs to select which AWs (0,1) to use. // CSV sets for DACS e.g. "02, 1" for DACs 0, 2 to output AW0, and DAC 1 to output AW1
	variable numCycles // How many full waves to execute for each ramp step
	variable verbose  // Whether to print setup of AWG
	
	struct fdAWG_List S
	fdAWG_get_global_AWG_list(S)
	
	// Note: This needs to be changed if using same AW on multiple DACs
	DACs = SF_get_channels(DACs, fastdac=1)  // Convert from label to numbers 
	DACs = ReplaceString(";", DACs, ",")  
	/////////////////
	
	S.AW_Waves = selectstring(paramisdefault(AWs), AWs, S.AW_Waves)
	S.AW_DACs = selectstring(paramisdefault(DACs), DACs, S.AW_Dacs)  // Formatted 01,23  == wave 0 on channels 0 and 1, wave 1 on channels 2 and 3
	S.numCycles = paramisDefault(numCycles) ? S.numCycles : numCycles
	
	S.numWaves = itemsinlist(AWs, ",")
	
	// For checking things don't change before scanning
	S.numADCs = getNumFADC()  // Store number of ADCs selected in window so can check if this changes
	S.samplingFreq = getfadcspeed(instrID)
	S.measureFreq = S.samplingFreq/S.numADCs
	
	variable i, waveLen = 0
	string wn
	variable min_samples = INF  // Minimum number of samples at a setpoint
	for(i=0;i<S.numWaves;i++)
		// Get IGOR AW
		wn = fdAWG_get_AWG_wave(str2num(stringfromlist(i, S.AW_waves, ",")))
		wave w = $wn
		// Check AW has correct form and meets criteria. Checks length of wave = waveLen (or sets waveLen if == 0)
		fdAWG_check_AW(w,len=waveLen)
		
		// Get length of shortest setpoint in samples
		duplicate/o/free/r=[][1] w samples
		wavestats/q samples
		if(V_min < min_samples)
			min_samples = V_min
		endif
	endfor
	S.waveLen = waveLen
	// Note: numSteps must be set in Scan... (i.e. based on numptsx or sweeprate)
	
	// Set initialized
	S.initialized = 1
	
	// Store as global to be access in fd_Record_Values
	fdAWG_set_global_AWG_list(S)
	
	// Print with current settings (changing settings will affect square wave!)
	variable j = 0
	string buffer = ""
	string dacs4wave, dac_list, aw_num
	for(i=0;i<S.numWaves;i++)
		aw_num = stringfromlist(i, AWs, ",")
		dacs4wave = stringfromlist(i, DACs, ",")
		dac_list = ""
		for(j=0;j<strlen(dacs4wave);j++)  // Go through DACs for AW#i (i.e. 012 means DACs 0,1,2)
			dac_list = addlistitem(dacs4wave[j], dac_list, ",")
		endfor
		dac_list = dac_list[0,strlen(dac_list)-2] // remove comma at end
		sprintf buffer "%s\tAW%s on DAC(s) %s\r", buffer, aw_num, dac_list
	endfor 

	variable awFreq = 1/(s.waveLen/S.measureFreq)
	variable duration_per_step = s.waveLen/S.measureFreq*S.numCycles
	if (verbose)
		printf "\r\rAWG set with:\r\tAWFreq = %.2fHz\r\tMin Samples for step = %d\r\tCycles per step = %d\r\tDuration per step = %.3fs\r\tnumADCs = %d\r\tSamplingFreq = %.1f/s\r\tMeasureFreq = %.1f/s\rOutputs are:\r%s\r",\
  									awFreq,											min_samples,			S.numCycles,						duration_per_step,		S.numADCs, 		S.samplingFreq,					S.measureFreq,						buffer											
	endif
   
end


function fdAWG_check_AW(w, [len])
	// Internal function - not to be used directly by user
	// Checks wave w meets criteria for AW, and if len provided will check w has same length or will set len if == 0
	wave w
	variable &len  // length in samples (all AWs must have the same sample length)
	
	// Check 2D (i.e. setpoints, samples)
	if(dimsize(w, 1) != 2)
		abort "AWs are required to be 2D wave. 1st row = setpoints, 2nd row = numSamples for corresponding setpoint"
	endif
	
	// Check all sampleLens are integers
	duplicate/o/free/r=[][1] w samples	
	variable i = 0
	for(i=0;i<numpnts(samples);i++)
		if(samples[i] != trunc(samples[i])) // IGORs bs way of checking if integer
			abort "ERROR[fdAWG_check_AW]: Received a non-integer number of samples for setpoint " + num2str(i)
		endif
	endfor
	
	// Check length of AWs is equal (if passed in len to compare to)
	if(!paramisdefault(len)) // Check length of wave matches len, or set len if len == 0
		if (len == 0)
			len = sum(samples)
			if(len == 0)
				abort "ERROR[fdAWG_check_AW]: AW has zero length!"
			endif
		else
			if(sum(samples) != len)
				abort "ERROR[fdAWG_check_AW]: Length of AW does not match len which is " + num2str(len)
			endif
		endif
	endif
end


function fdAWG_add_wave(instrID, wave_num, add_wave)
	// Internal function - not to be used directly by user
	// See	"fdAWG_make_multi_square_wave()" as an example of how to use this
	// Very basic command which adds to the AWGs stored in the fastdac
	variable instrID
	variable wave_num  	// Which AWG to add to (currently allowed 0 or 1)
	wave add_wave		// add_wave should be 2D with add_wave[0] = mV setpoint for each step in wave
					   		// 									 add_wave[1] = how many samples to stay at each setpoint



                        // ADD_WAVE,<wave number (for now just 0 or 1)>,<Setpoint 0 in mV>,<Number of samples at setpoint 0>,….<Setpoint n in mV>,<Number of samples at Setpoint n>
                        //
                        // Response:
                        //
                        // WAVE,<wavenumber>,<total number of setpoints accumulated in waveform>
                        //
                        // Example:
                        //
                        // ADD_WAVE,0,300.1,50,-300.1,200
                        //
                        // Response:
                        //
                        // WAVE,0,2

	variable i=0

   waveStats/q add_wave
   if (dimsize(add_wave, 1) != 2 || V_numNans !=0 || V_numINFs != 0) 
      abort "ERROR[fdAWG_add_wave]: must be 2D (setpoints, samples) and contain no NaNs or INFs"
   endif
   if (wave_num != 0 && wave_num != 1)  // Check adding to AWG 0 or 1
      abort "ERROR[fdAWG_add_wave]: Only supports AWG wave 0 or 1"
   endif

	// Check all sample lengths are integers
 	duplicate/o/free/r=[][1] add_wave samples
	for(i=0;i<numpnts(samples);i++)
		if(samples[i] != trunc(samples[i])) // IGORs bs way of checking if integer
			abort "ERROR[fdAWG_add_wave]: Received a non-integer number of samples for setpoint " + num2str(i)
		endif
	endfor

	// Compile wave part of command
   string buffer = ""
   for(i=0;i<dimsize(add_wave, 0);i++)
		buffer = addlistitem(num2str(add_wave[i][0]), buffer, ",", INF)
		buffer = addlistitem(num2str(add_wave[i][1]), buffer, ",", INF)
   endfor
   buffer = buffer[0,strlen(buffer)-2]  // chop off last ","

	// Make full command in form "ADD_WAVE,<wave_num>,<sp0>,<#sp0>,...,<spn>,<#spn>"
   string cmd = ""
   sprintf cmd "ADD_WAVE,%d,%s", wave_num, buffer
   
	// Check within FD input buffer length
   if (strlen(cmd) > 256)
      sprintf buffer "ERROR[fdAWG_add_wave]: command length is %d, which exceeds fDAC buffer size of 256. Add to AWG in smaller chunks", strlen(cmd)
      abort buffer
   endif

	// Send command
	string response
	response = queryInstr(instrID, cmd+"\r", read_term="\n")
	response = sc_stripTermination(response, "\r\n")

	// Check response and add to IGOR fdAW_<wave_num> if successful
	string wn = fdAWG_get_AWG_wave(wave_num)
	wave AWG_wave = $wn
	variable awg_len = dimsize(AWG_wave,0)
	string expected_response
	sprintf expected_response "WAVE,%d,%d", wave_num, awg_len+dimsize(add_wave,0)
	if(fd_checkResponse(response, cmd, isString=1, expectedResponse=expected_response))
		concatenate/o/Free/NP=0 {AWG_wave, add_wave}, tempwave
		redimension/n=(awg_len+dimsize(add_wave,0), -1) AWG_wave 
		AWG_wave[awg_len,][] = tempwave[p][q]
	else
		abort "ERROR[fdAWG_add_wave]: Failed to add add_wave to AWG_wave"+ num2str(wave_num)
	endif
end


function/s fdAWG_get_AWG_wave(wave_num)
   // Returns name of AW wave (and creates the wave first if necessary)
   variable wave_num
   if (wave_num != 0 && wave_num != 1)  // Check adding to AWG 0 or 1
      abort "ERROR[fdAWG_get_AWG_wave]: Only supports AWG wave 0 or 1"
   endif

   string wn = ""
   sprintf wn, "fdAW_%d", wave_num
   wave AWG_wave = $wn
   if(!waveExists(AWG_wave))
      make/o/n=(0,2) $wn
   endif
   return wn
end

function fdAWG_clear_wave(instrID, wave_num)
	// Clears AWG# from the fastdac and the corresponding global wave in IGOR
	variable instrID
	variable wave_num // Which AWG to clear (currently allowed 0 or 1)

   // CLR_WAVE,<wave number>
   //
   // Response:
   //
   // WAVE,<wave number>,0
   //
   // Example:
   //
   // CLR_WAVE,1
   //
   // Response:
   //
   // WAVE,1,0

	string cmd
	sprintf cmd, "CLR_WAVE,%d", wave_num

	//send command
	string response
   response = queryInstr(instrID, cmd+"\r", read_term="\n")
   response = sc_stripTermination(response, "\r\n")

   string expected_response
   sprintf expected_response "WAVE,%d,0", wave_num
   if(fd_checkResponse(response, cmd, isstring=1,expectedResponse=expected_response))
		string wn = fdAWG_get_AWG_wave(wave_num)
		wave AWG_wave = $wn
		killwaves AWG_wave 
   else
      abort "ERROR[fdAWG_clear_wave]: Error while clearing AWG_wave"+num2str(wave_num)
   endif
end


function fdAWG_make_multi_square_wave(instrID, v0, vP, vM, v0len, vPlen, vMlen, wave_num, [ramplen])  // TODO: move this to Tim's igor procedures
   // Make square waves with form v0, +vP, v0, -vM (useful for Tim's Entropy)
   // Stores copy of wave in Igor (accessible by fdAWG_get_AWG_wave(wave_num))
   // Note: Need to call, fdAWG_setup_AWG() after making new wave
   // To make simple square wave set length of unwanted setpoints to zero.
   variable instrID, v0, vP, vM, v0len, vPlen, vMlen, wave_num
   variable ramplen  // lens in seconds
   variable max_setpoints = 26


	ramplen = paramisdefault(ramplen) ? 0.003 : ramplen

	if (ramplen < 0)
		abort "ERROR[fdAWG_make_multi_square_wave]: Cannot use a negative ramplen"
	endif
	
    // Open connection
    sc_openinstrconnections(0)

   // put inputs into waves to make them easier to work with
   make/o/free sps = {v0, vP, v0, vM} // CHANGE refers to output
   make/o/free lens = {v0len, vPlen, v0len, vMlen}

   // Sanity check on period
   // Note: limit checks happen in AWG_RAMP 
   if (sum(lens) > 1)
      string msg
      sprintf msg "Do you really want to make a square wave with period %.3gs?", sum(lens)
      variable ans = ask_user(msg, type=1)
      if (ans == 2)
         abort "User aborted"
      endif
   endif
   // Ensure that ramplen is not too long (will never reach setpoints)
   variable i=0
   for(i=0;i<numpnts(lens);i++)
    if (lens[i] < ramplen)
      msg = "Do you really want to ramp for longer than the duration of a setpoint? You will never reach the setpoint"
      ans = ask_user(msg, type=1)
      if (ans == 2)
         abort "User aborted"
      endif
    endif
   endfor


    // Get current measureFreq to calculate require sampleLens to achieve durations in s
   variable measureFreq = getFADCmeasureFreq(instrID) 
   variable numSamples = 0

   // Make wave
   variable j=0, k=0
   variable max_ramp_per_setpoint = floor((max_setpoints - numpnts(sps))/numpnts(sps)) // CHANGE setpoint per ramp
   variable ramp_per_setpoint = min(max_ramp_per_setpoint, floor(measureFreq * ramplen)) // CHANGE to ramp_step_size
   variable ramp_setpoint_duration = 0

   if (ramp_per_setpoint != 0)
     ramp_setpoint_duration = ramplen / ramp_per_setpoint 
   endif

   // make wave to store setpoints/sample_lengths, correctly sized
   make/o/free/n=((numpnts(sps)*ramp_per_setpoint + numpnts(sps)), 2) awg_sqw

   //Initialize prev_setpoint to the last setpoint
   variable prev_setpoint = sps[numpnts(sps) - 1]
   variable ramp_step = 0
   for(i=0;i<numpnts(sps);i++)
      if(lens[i] != 0)  // Only add to wave if duration is non-zero
         // Ramps happen at the beginning of a setpoint and use the 'previous' wave setting to compute
         // where to ramp from. Obviously this does not work for the first wave length, is that avoidable?
         ramp_step = (sps[i] - prev_setpoint)/(ramp_per_setpoint + 1)
         for (k = 1; k < ramp_per_setpoint+1; k++)
          // THINK ABOUT CASE CASE RAMPLEN 0 -> ramp_setpoint_furation = 0
          numSamples = round(ramp_setpoint_duration * measureFreq)
          awg_sqw[j][0] = {prev_setpoint + (ramp_step * k)}
          awg_sqw[j][1] = {numSamples}
          j++
         endfor 
         numSamples = round((lens[i]-ramplen)*measureFreq)  // Convert to # samples
         if(numSamples == 0)  // Prevent adding zero length setpoint
            abort "ERROR[Set_multi_square_wave]: trying to add setpoint with zero length, duration too short for sampleFreq"
         endif
         awg_sqw[j][0] = {sps[i]}
         awg_sqw[j][1] = {numSamples}
         j++ // Increment awg_sqw position for storing next setpoint/sampleLen
         prev_setpoint = sps[i]
      endif
   endfor


    // Check there is a awg_sqw to add
   if(numpnts(awg_sqw) == 0)
      abort "ERROR[Set_multi_square_wave]: No setpoints added to awg_sqw"
   endif

    // Clear current wave and then reset with new awg_sqw
   fdAWG_clear_wave(instrID, wave_num)
   fdAWG_add_wave(instrID, wave_num, awg_sqw)

   // Make sure user sets up AWG_list again after this change using fdAWG_setup_AWG()
   fdAWG_reset_init()
end


////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////// FastDAC Sweeps /////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////

function/s fd_start_sweep(S, [AWG_list])
	// Starts one of:
	// regular sweep (INT_RAMP in arduino) 
	// sweep with arbitrary wave generator on (AWG_RAMP in arduino)
	// readvstime sweep (SPEC_ANA in arduino)
	Struct ScanVars &S
	Struct fdAWG_list &AWG_List

	assertSeparatorType(S.ADCList, ";")	
	string adcs = replacestring(";",S.adclist,"")

	if (!S.readVsTime)
		assertSeparatorType(S.channelsx, ",")
		string starts, fins, temp
		if(S.direction == 1)
			starts = S.startxs
			fins = S.finxs
		elseif(S.direction == -1)
			starts = S.finxs
			fins = S.startxs
		else
			abort "ERROR[fd_start_sweep]: S.direction must be 1 or -1, not " + num2str(S.direction)
		endif

	   string dacs = replacestring(",",S.channelsx,"")
	endif

	string cmd = ""

	if (!paramisDefault(AWG_list) && AWG_List.use_AWG == 1)  
		// Example:
		// AWG_RAMP,2,012,345,67,0,-1000,1000,-2000,2000,50,50
		// Response:
		// <(2500 * waveform length) samples from ADC0>RAMP_FINISHED
		//
		// OPERATION, #N AWs, AW_dacs, DAC CHANNELS, ADC CHANNELS, INITIAL VOLTAGES, FINAL VOLTAGES, # OF Wave cycles per step, # ramp steps
		// Note: AW_dacs is formatted (dacs_for_wave0, dacs_for_wave1, .... e.g. '01,23' for Dacs 0,1 to output wave0, Dacs 2,3 to output wave1)
		sprintf cmd, "AWG_RAMP,%d,%s,%s,%s,%s,%s,%d,%d\r", AWG_list.numWaves, AWG_list.AW_dacs, dacs, adcs, starts, fins, AWG_list.numCycles, AWG_list.numSteps
	elseif (S.readVsTime == 1)
		sprintf cmd, "SPEC_ANA,%s,%s\r", adcs, num2istr(S.numptsx)
	else
		// OPERATION, DAC CHANNELS, ADC CHANNELS, INITIAL VOLTAGES, FINAL VOLTAGES, # OF STEPS
		sprintf cmd, "INT_RAMP,%s,%s,%s,%s,%d\r", dacs, adcs, starts, fins, S.numptsx
	endif
	writeInstr(S.instrID,cmd)
	return cmd
end

function fd_readChunk(fdid, adc_channels, numpts)
	// Reads numpnts data without ramping anywhere, does not update graphs or anything, just returns full waves in 
	// waves named fd_readChunk_# where # is 0, 1 etc for ADC0, 1 etc
	variable fdid, numpts
	string adc_channels

	adc_channels = replaceString(",", adc_channels, ";")  // Going to list with this separator later anyway
	adc_channels = replaceString(" ", adc_channels, "")  // Remove blank spaces
	variable i
	string wn, ch
	string wavenames = ""
	for(i=0; i<itemsInList(adc_channels); i++)
		ch = stringFromList(i, adc_channels)
		wn = "fd_readChunk_"+ch // Use this to not clash with possibly initialized raw waves
		make/o/n=(numpts) $wn = NaN
		wavenames = addListItem(wn, wavenames, ";", INF)
	endfor

	Struct ScanVars S
	S.numptsx = numpts
	S.instrID = fdid
	S.readVsTime = 1  					// No ramping
	S.adcList = adc_channels  		// Recording specified channels, not ticked boxes in ScanController_Fastdac
	S.numADCs = itemsInList(S.adcList)
	S.samplingFreq = getFADCspeed(S.instrID)
	S.raw_wave_names = wavenames  	// Override the waves the rawdata gets saved to
	S.never_save = 1

	new_fd_record_values(S, 0, skip_data_distribution=1)
end




//////////////////////////////////////
///////////// Structs ////////////////
//////////////////////////////////////

Structure fdAWG_list
	// Note: Variables must come after all strings/waves/etc so that structPut will save them!!

	// strings/waves/etc //
	// Convenience
	string AW_Waves		// Which AWs to use e.g. "2" for AW_2 only, "1,2" for fdAW_1 and fdAW_2. (only supports 1 and 2 so far)
	
	// Used in AWG_RAMP
	string AW_dacs		// Dacs to use for waves
							// Note: AW_dacs is formatted (dacs_for_wave0, dacs_for_wave1, .... e.g. '01,23' for Dacs 0,1 to output wave0, Dacs 2,3 to output wave1)

	// Variables //
	// Convenience	
	variable initialized	// Must set to 1 in order for this to be used in fd_Record_Values (this is per setup change basis)
	variable use_AWG 		// Must be set to 1 in order to use in fd_Record_Values (this is per scan basis)
	variable waveLen			// in samples (i.e. sum of samples at each setpoint for a single wave cycle)
	
	// Checking things don't change
	variable numADCs  	// num ADCs selected to measure when setting up AWG
	variable samplingFreq // SampleFreq when setting up AWG
	variable measureFreq // MeasureFreq when setting up AWG

	// Used in AWG_Ramp
	variable numWaves	// Number of AWs being used
	variable numCycles 	// # wave cycles per DAC step for a full 1D scan
	variable numSteps  	// # DAC steps for a full 1D scan

endstructure


function fdAWG_init_global_AWG_list()
	// Makes an empty AWG_List and stores as global
	struct fdAWG_list S
	S.AW_waves = ""
	S.AW_dacs = ""
	fdAWG_set_global_AWG_list(S)
end


function fdAWG_set_global_AWG_list(S)
	// Function to store values from AWG_list to global variables/strings/waves
	// StructPut ONLY stores VARIABLES so have to store other parts separately
	struct fdAWG_list &S

	// TODO: switch to storing in a single text wave (not sure if structPut can store into a text wave)

	// Store String parts  
	string/g fdAWG_globals_AW_Waves = S.AW_waves
	string/g fdAWG_globals_AW_dacs = S.AW_dacs
	
	// Store variable parts
//	make/o fdAWG_globals_stuct_vars
	string/g fdAWG_globals_stuct_vars 
	structPut/S S, fdAWG_globals_stuct_vars
end


function fdAWG_get_global_AWG_list(S)
	// Function to get global values for AWG_list that were stored using set_global_AWG_list()
	// StructPut ONLY gets VARIABLES
	struct fdAWG_list &S

	// TODO: Switch to loading from a single text wave (not sure if structGet can load from text wave)
	
	// Get variable parts
	svar fdAWG_globals_stuct_vars
	structGet/S S fdAWG_globals_stuct_vars
	S.use_AWG = 0  // Always initialized to zero so that checks have to be run before using in scan (see SFawg_set_and_precheck())
	
	// Get string parts
	svar fdAWG_globals_AW_Waves
	svar fdAWG_globals_AW_dacs
	S.AW_waves = fdAWG_globals_AW_Waves
	S.AW_dacs = fdAWG_globals_AW_dacs
end

