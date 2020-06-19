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

////////////////////
//// Connection ////
////////////////////

function openFastDACconnection(instrID, visa_address, [verbose,numDACCh,numADCCh,master])
	// instrID is the name of the global variable that will be used for communication
	// visa_address is the VISA address string, i.e. ASRL1::INSTR
	// Most FastDAC communication relies on the info in "fdackeys". Pass numDACCh and
	// numADCCh to fill info into "fdackeys"
	string instrID, visa_address
	variable verbose, numDACCh, numADCCh, master
	
	if(paramisdefault(verbose))
		verbose=1
	elseif(verbose!=1)
		verbose=0
	endif
	
	// Set default fd_ramprate if not already set
	NVAR/Z fd_ramprate 
	if( !NVAR_Exists(fd_ramprate) )
		variable/g fd_ramprate=1000
	endif
	
	variable localRM
	variable status = viOpenDefaultRM(localRM) // open local copy of resource manager
	if(status < 0)
		VISAerrormsg("open FastDAC connection:", localRM, status)
		abort
	endif
	
	string comm = ""
	sprintf comm, "name=FastDAC,instrID=%s,visa_address=%s" instrID, visa_address
	string options = "baudrate=57600,databits=8,stopbits=1,parity=0,test_query=*IDN?"
	openVISAinstr(comm, options=options, localRM=localRM, verbose=verbose)
	
	if(paramisdefault(master))
		master = 0
	endif
		
	// fill info into "fdackeys"
	if(!paramisdefault(numDACCh) && !paramisdefault(numADCCh))
		sc_fillfdacKeys(instrID,visa_address,numDACCh,numADCCh,master=master)
	endif
	
	return localRM
end

///////////////////////
//// Get functions ////
///////////////////////

function getFADCmeasureFreq(instrID)
	// Calculates measurement frequency as sampleFreq/numadc 
	// NOTE: This will not currently work if more than one fastdac is connected
	variable instrID
	
	svar fdackeys
	variable numDevices = str2num(stringbykey("numDevices",fdackeys,":",","))
	if (numDevices != 1)
		abort "ERROR[getFADCmeasureFreq]: This function only works for 1 fastdac currently"
	endif
	
	variable numadc, samplefreq
	numadc = getnumfadc() 
	samplefreq = getFADCspeed(instrID)
	return samplefreq/numadc
end

function getNumFADC() // Getting from scancontroller_Fastdac window but makes sense to put here as a get function
	// Just looks at which boxes are ticked to see how many will be recorded
	variable i=0, numadc=0
	wave fadcattr
	for (i=0; i<dimsize(fadcattr, 1)-1; i++) // Count how many ADCs are being measured
		if (fadcattr[i][2] == 48)
			numadc++
		endif
	endfor
	return numadc
end

function getFADCspeed(instrID)
	// Returns speed in Hz (but arduino thinks in microseconds)
	variable instrID
	svar fadcSpeeds

	string response="", compare="", cmd="", command=""

	command = "READ_CONVERT_TIME"
	cmd = command+",0"
	response = queryInstr(instrID,cmd+"\r",read_term="\n")  // Get conversion time for channel 0 (should be same for all channels)
	response = sc_stripTermination(response,"\r\n")
	if(!fdacCheckResponse(response,cmd))
		abort
	endif
	
	svar fdackeys
	variable numDevices = str2num(stringbykey("numDevices",fdackeys,":",",")), i=0, numADCCh = 0, numDevice=0
	string instrAddress = getResourceAddress(instrID), deviceAddress = ""
	for(i=0;i<numDevices;i+=1)
		deviceAddress = stringbykey("visa"+num2istr(i+1),fdackeys,":",",")
		if(cmpstr(deviceAddress,instrAddress) == 0)
			numADCCh = str2num(stringbykey("numADCCh"+num2istr(i+1),fdackeys,":",","))
			numDevice = i+1
			break
		endif
	endfor
	for(i=1;i<numADCCh;i+=1)
		cmd  = command+","+num2istr(i)
		compare = queryInstr(instrID,cmd+"\r",read_term="\n")
		compare = sc_stripTermination(compare,"\r\n")
		if(!fdacCheckResponse(compare,cmd))
			abort
		elseif(str2num(compare) != str2num(response)) // Ensure ADC channels all have same conversion time
			print "[WARNING] \"getfadcSpeed\": ADC channels 0 & "+num2istr(i)+" have different conversion times!"
		endif
	endfor
	
	return 1.0/(str2num(response)*1.0e-6) // return value in Hz
end

function getFADCChannel(instrID,channel) // Units: mV
	// channel must be the channel number given by the GUI!
	variable instrID, channel
	wave/t fadcvalstr
	svar fdackeys
	
	variable numDevices = str2num(stringbykey("numDevices",fdackeys,":",","))
	variable i=0, devchannel = 0, startCh = 0, numADCCh = 0
	string visa_address = "", err = "", instr_address = getResourceAddress(instrID)
	for(i=0;i<numDevices;i+=1)
		numADCCh = str2num(stringbykey("numADCCh"+num2istr(i+1),fdackeys,":",","))
		if(startCh+numADCCh-1 >= channel)
			// this is the device, now check that instrID is pointing at the same device
			visa_address = stringbykey("visa"+num2istr(i+1),fdackeys,":",",")
			if(cmpstr(visa_address, instr_address) == 0)
				devchannel = channel-startCh
				break
			else
				sprintf err, "[ERROR] \"getfdacChannel\": channel %d is not present on device on with address %s", channel, instr_address
				print(err)
				abort
			endif
		endif
		startCh =+ numADCCh
	endfor
	
	// query ADC
	string cmd = ""
	sprintf cmd, "GET_ADC,%d", devchannel
	string response
	response = queryInstr(instrID, cmd+"\r", read_term="\n")
	response = sc_stripTermination(response,"\r\n")
	
	// check response
	err = ""
	if(fdacCheckResponse(response,cmd)) 
		// good response, update window
		fadcvalstr[channel][1] = num2str(str2num(response))
		return str2num(response)
	else
		abort
	endif
end

function getFDACOutput(instrID,channel) // Units: mV
	variable instrID, channel
	
	wave/t old_fdacvalstr, fdacvalstr
	string cmd="", response="",warn=""
	sprintf cmd, "GET_DAC,%d", channel
	response = queryInstr(instrID, cmd+"\r", read_term="\n")
	response = sc_stripTermination(response,"\r\n")
	
	// check response
	variable currentOutput=0
	if(fdacCheckResponse(response,cmd))
		// good response
		currentOutput = str2num(response)
		fdacvalstr[channel][1] = num2str(currentOutput)
		updatefdacwindow(channel)
	else
		resetfdacwindow(channel)
		abort
	endif
	
	return currentOutput
end

function/s getFDACStatus(instrID)
	variable instrID
	string  buffer = "", key = ""
	wave/t fdacvalstr	
	svar fdackeys

	// find the correct fastdac
	string visa = getresourceaddress(instrID)
	variable i=0, dev = 0, numDevices = str2num(stringbykey("numDevices",fdackeys,":",","))
	variable adcChs = 0
	for(i=0;i<numDevices;i+=1)
		if(cmpstr(visa,stringbykey("visa"+num2istr(i+1),fdackeys,":",","))==0)
			dev = i+1
			break
		endif
		adcChs += str2num(stringbykey("numADCCh"+num2istr(i+1),fdackeys,":",","))
	endfor
	
	buffer = addJSONkeyval(buffer, "visa_address", visa, addquotes=1)
	buffer = addJSONkeyval(buffer, "SamplingFreq", num2str(getFADCspeed(instrID)), addquotes=1)
	buffer = addJSONkeyval(buffer, "MeasureFreq", num2str(getFADCmeasureFreq(instrID)), addquotes=1)

	// DAC values
	for(i=0;i<str2num(stringbykey("numDACCh"+num2istr(dev),fdackeys,":",","));i+=1)
		sprintf key, "DAC%d{%s}", i, fdacvalstr[i][3]
		buffer = addJSONkeyval(buffer, key, num2numstr(getfdacOutput(instrID,i)))
	endfor

	
	// ADC values
	for(i=0;i<str2num(stringbykey("numADCCh"+num2istr(dev),fdackeys,":",","));i+=1)
		buffer = addJSONkeyval(buffer, "ADC"+num2istr(i), num2numstr(getfadcChannel(instrID,adcChs+i)))
	endfor

	return addJSONkeyval("", "FastDAC "+num2istr(dev), buffer)
end


///////////////////////
//// Set functions ////
///////////////////////


function setFADCSpeed(instrID,speed,[loadCalibration]) // Units: Hz
	// set the ADC speed in Hz
	// set loadCalibration=1 to load save calibration
	variable instrID, speed, loadCalibration
	
	if(paramisdefault(loadCalibration))
		loadCalibration = 0
	elseif(loadCalibration != 1)
		loadCalibration = 0
	endif
	
	// check formatting of speed
	if(speed <= 0)
		print "[ERROR] \"setfadcSpeed\": Speed must be positive"
		abort
	endif
	
	svar fdackeys
	variable numDevices = str2num(stringbykey("numDevices",fdackeys,":",",")), i=0, numADCCh = 0, numDevice = 0
	string instrAddress = getResourceAddress(instrID), deviceAddress = "", cmd = "", response = ""
	for(i=0;i<numDevices;i+=1)
		deviceAddress = stringbykey("visa"+num2istr(i+1),fdackeys,":",",")
		if(cmpstr(deviceAddress,instrAddress) == 0)
			numADCCh = str2num(stringbykey("numADCCh"+num2istr(i+1),fdackeys,":",","))
			numDevice = i+1
			break
		endif
	endfor
	for(i=0;i<numADCCh;i+=1)
		sprintf cmd, "CONVERT_TIME,%d,%d\r", i, 1.0/speed*1.0e6  // Convert from Hz to microseconds
		response = queryInstr(instrID, cmd, read_term="\n")  //Set all channels at same time (generally good practise otherwise can't read from them at the same time)
		response = sc_stripTermination(response,"\r\n")
		if(!fdacCheckResponse(response,cmd))
			abort
		endif
	endfor
	
	speed = roundNum(1.0/str2num(response)*1.0e6,0)
	
	if(loadCalibration)
		loadfADCCalibration(instrID,speed)
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
end

function rampOutputFDAC(instrID,channel,output,[ramprate]) // Units: mV, mV/s
	// ramps a channel to the voltage specified by "output".
	// ramp is controlled locally on DAC controller.
	// channel must be the channel set by the GUI.
	variable instrID, channel, output, ramprate
	wave/t fdacvalstr, old_fdacvalstr
	svar fdackeys
	
	if(paramIsDefault(ramprate))
		nvar fd_ramprate
		ramprate = fd_ramprate
	endif
	
	variable numDevices = str2num(stringbykey("numDevices",fdackeys,":",","))
	variable i=0, devchannel = 0, startCh = 0, numDACCh = 0
	string deviceAddress = "", err = "", instrAddress = getResourceAddress(instrID)
	for(i=0;i<numDevices;i+=1)
		numDACCh =  str2num(stringbykey("numDACCh"+num2istr(i+1),fdackeys,":",","))
		if(startCh+numDACCh-1 >= channel)
			// this is the device, now check that instrID is pointing at the same device
			deviceAddress = stringbykey("visa"+num2istr(i+1),fdackeys,":",",")
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
	if(abs(output) > fdac_limit)
		sprintf err, "[ERROR] \"rampOutputfdac\": Output voltage on channel %d outside hardware limit", channel
		print err
		resetfdacwindow(channel)
		abort
	endif
	
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
	if (ramprate > str2num(fdacvalstr[channel][4]))
		printf "[WARNING] \"rampOutputfdac\": Ramprate of %.0fmV/s requested for channel %d. Using max_ramprate of %.0fmV/s instead\n" ramprate, channel, str2num(fdacvalstr[channel][4])
		ramprate = str2num(fdacvalstr[channel][4])
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
	if(fdacCheckResponse(response,cmd,isString=1,expectedResponse="RAMP_FINISHED"))
		fdacvalstr[channel][1] = num2str(output)
		updatefdacWindow(channel)
	else
		resetfdacwindow(channel)
		abort
	endif
end

function RampMultipleFDAC(InstrID, channels, setpoint, [ramprate])
	variable InstrID, setpoint, ramprate
	string channels
	
	nvar fd_ramprate
	ramprate = paramIsDefault(ramprate) ? fd_ramprate : ramprate
	
	variable i=0, channel, nChannels = ItemsINList(channels, ",")
	for(i=0;i<nChannels;i+=1)
		channel = str2num(StringFromList(i, channels, ","))
		rampOutputfdac(instrID, channel, setpoint, ramprate=ramprate)
	endfor
end

	
function ResetFdacCalibration(instrID,channel)
	variable instrID, channel
	
	string cmd="", response="", err=""
	sprintf cmd, "DAC_RESET_CAL,%d\r", channel
	response = queryInstr(instrID,cmd,read_term="\n")
	response = sc_stripTermination(response,"\r\n")
	if(fdacCheckResponse(response,cmd,isString=1,expectedResponse="CALIBRATION_RESET"))
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
	
	if(fdacCheckResponse(response,cmd,isString=1,expectedResponse="CALIBRATION_FINISHED"))
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
	
	if(fdacCheckResponse(response,cmd,isString=1,expectedResponse="CALIBRATION_FINISHED"))
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
	
	if(fdacCheckResponse(response,cmd,isString=1,expectedResponse="CALIBRATION_CHANGED"))
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

function ClearFdacBuffer(instrID)
	variable instrID
	
	variable count=0
	string buffer=""
	do 
		viRead(instrID, buffer, 2000, count)
	while(count != 0)
end

function loadFadcCalibration(instrID,speed)
	variable instrID,speed
	
	string regex = "", filelist = "", jstr=""
	variable i=0,k=0
	
	svar fdackeys
	variable numDevices = str2num(stringbykey("numDevices",fdackeys,":",",")), numADCCh=0, numDACCh=0,deviceNum=0
	string instrAddress = getResourceAddress(instrID), deviceAddress = ""
	for(i=0;i<numDevices;i+=1)
		deviceAddress = stringbykey("visa"+num2istr(i+1),fdackeys,":",",")
		if(cmpstr(deviceAddress,instrAddress) == 0)
			numDACCh = str2num(stringbykey("numDACCh"+num2istr(i+1),fdackeys,":",","))
			numADCCh = str2num(stringbykey("numADCCh"+num2istr(i+1),fdackeys,":",","))
			deviceNum = i+1
			break
		endif
	endfor
	
	sprintf regex, "fADC%dCalibration_%d", deviceNum, speed
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
	
	svar/z fdackeys
	if(!svar_exists(fdackeys))
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
	
	variable numDevices = str2num(stringbykey("numDevices",fdackeys,":",",")), i=0, numDACCh=0, deviceNum=0
	string instrAddress = getResourceAddress(instrID), deviceAddress = ""
	for(i=0;i<numDevices;i+=1)
		deviceAddress = stringbykey("visa"+num2istr(i+1),fdackeys,":",",")
		if(cmpstr(deviceAddress,instrAddress) == 0)
			numDACCh = str2num(stringbykey("numDACCh"+num2istr(i+1),fdackeys,":",","))
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
		rampOutputfdac(instrID,channel,0)
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
		sprintf message, "Offset calibration of DAC channel %d finished. Final values are:\rOffset stepsize = %.2f uV\rOffset register = %d", channel, str2num(stringfromlist(0,offsetReg,",")), str2num(stringfromlist(1,offsetReg,","))
		print message
		
		// ramp channel to -10V
		rampOutputfdac(instrID,channel,-10000, ramprate=100000)
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
	
	svar/z fdackeys
	if(!svar_exists(fdackeys))
		print "[ERROR] \"fadcCalibrate\": Run initFastDAC() before calibration."
		abort
	endif
	
	variable numDevices = str2num(stringbykey("numDevices",fdackeys,":",",")), i=0, numADCCh=0, numDACCh=0,deviceNum=0
	string instrAddress = getResourceAddress(instrID), deviceAddress = ""
	for(i=0;i<numDevices;i+=1)
		deviceAddress = stringbykey("visa"+num2istr(i+1),fdackeys,":",",")
		if(cmpstr(deviceAddress,instrAddress) == 0)
			numDACCh = str2num(stringbykey("numDACCh"+num2istr(i+1),fdackeys,":",","))
			numADCCh = str2num(stringbykey("numADCCh"+num2istr(i+1),fdackeys,":",","))
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
	if(user_response == 0)
		print "[ERROR] \"fadcCalibrate\": User abort!"
		abort
	endif
	
	// Do calibration
	string cmd = "CAL_ADC_WITH_DAC\r"
	string response = queryInstr(instrID,cmd,read_term="\n",delay=2)
	response = sc_stripTermination(response,"\r\n")

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
	if(fdacCheckResponse(response,cmd,isString=1,expectedResponse="CALIBRATION_FINISHED") && calibrationFail == 0)
		// all good, calibration complete
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
	
	svar/z fdackeys
	
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
	
	svar/z fdackeys
	
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


function stopFDACsweep(instrID)
	variable instrID
	
	// stop the current sweep
	writeInstr(instrID,"STOP\r")
	
	// clear the buffer
	ClearfdacBuffer(instrID)
end


// Given two strings of length 1
//  - c1 (higher order) and
//  - c2 lower order
// Calculate effective FastDac value
// @optparams minVal, maxVal (units mV)

function fdacChar2Num(c1, c2, [minVal, maxVal])
	// Conversion of bytes to float
	string c1, c2
	variable minVal, maxVal
	// Set default values for minVal & maxVal
	if(paramisdefault(minVal))
		minVal = -10000
	endif
	
	if(paramisdefault(maxVal))
		maxVal = 10000
	endif
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

///////////////////////////
//// Spectrum Analyzer ////
//////////////////////////

function FDacSpectrumAnalyzer(instrID,channels,scanlength,[numAverage,linear,comments,nosave])
	// channels must a comma seperated string, refering
	// to the numbering in the ScanControllerFastDAC window.
	// scanlength is in sec
	// if linear is set to 1, the spectrum will be plotted on a linear scale
	variable instrID, scanlength, numAverage, linear, nosave
	string channels, comments
	
	if(paramisdefault(comments))
		comments = ""
	endif
	
	if(paramisdefault(linear) || linear != 1)
		linear = 0
	endif
	
	if(paramisdefault(numAverage))
		numAverage = 1
	endif
	
	svar fdackeys
	
	// num ADC channels
	channels = sortlist(channels,",",2)
	variable numChannels = itemsinlist(channels,",")
	
	// calculate number of points needed
	variable samplingFreq = getfadcSpeed(instrID)
	variable measureFreq = samplingFreq/(numChannels)  // sampling split between channels
	variable numpts = RoundNum(scanlength*measureFreq,0)
	
	// make sure numpts is even
	// otherwise FFT will fail
	numpts = numpts - mod(numpts,2)
	
	// resolve the ADC channel
	variable numDevices = str2num(stringbykey("numDevices",fdacKeys,":",","))
	variable i=0, j=0, numADCCh=0, startCh=0, dev_adc=0, adcCh=0
	string adcList=""
	for(i=0;i<numChannels;i+=1)
		adcCh = str2num(stringfromlist(i,channels,","))
		startCh = 0
		for(j=0;j<numDevices+1;j+=1)
			numADCCh = str2num(stringbykey("numADCCh"+num2istr(j+1),fdacKeys,":",","))
			if(startCh+numADCCh-1 >= adcCh)
				// this is the device
				if(i > 0 && dev_adc != j)
					print "[ERROR] \"fdacSpectrumAnalyzer\": All ADC channels must be on the same device!"
					abort
				endif
				dev_adc = j
				adcList = addlistitem(num2istr(adcCh),adcList,",",itemsinlist(adcList,","))
				break
			endif
			startCh += numADCCh
		endfor
	endfor
	
	// generate waves to hold time series data
	string wn = ""
	for(i=0;i<numChannels;i+=1)
		wn = "timeSeriesADC"+stringfromlist(i,channels,",")
		make/o/n=(numpts) $wn = nan
		setscale/i x, 0, scanlength, $wn
	endfor
	
	// create waves for final fft output
	for(i=0;i<numChannels;i+=1)
		wn = "fftADC"+stringfromlist(i,channels,",")
		make/o/n=(numpts/2) $wn = nan
		setscale/i x, 0, measureFreq/(2.0), $wn
	endfor
	
	// find all open plots
	string graphlist = winlist("*",",","WIN:1"), graphname = "", graphtitle="", graphnumlist=""
	string plottitle="", graphnum=""			
	for(i=0;i<itemsinlist(graphlist,",");i=i+1) 			
		graphname = stringfromlist(i,graphlist,",")
		setaxis/w=$graphname /a
		getwindow $graphname wtitle
		splitstring /e="(.*):(.*)" s_value, graphnum, plottitle
		graphtitle+= plottitle+","
		graphnumlist+= graphnum+","
	endfor
	
	// open plots and distribute on screen
	variable graphopen=0
	string openplots=""
	string num
	for(i=0;i<itemsinlist(channels,",");i+=1)
		num = stringfromlist(i,channels,",")
		wn = "timeSeriesADC"+num
		graphopen=0
		for(j=0;j<itemsinlist(graphtitle,",");j+=1)
			if(stringmatch(wn,stringfromlist(j,graphtitle,",")))
				graphopen = 1
				openplots+= stringfromlist(j,graphnumlist,",")+","
				label /w=$stringfromlist(j,graphnumlist,",") bottom,  "time [s]"
			endif
		endfor
		if(!graphopen)
			display $wn
			setwindow kwTopWin, graphicsTech=0
			label bottom, "time [s]"
			openplots+= winname(0,1)+","
		endif
		
		wn = "fftADC"+num
		graphopen=0
		for(j=0;j<itemsinlist(graphtitle,",");j+=1)
			if(stringmatch(wn,stringfromlist(j,graphtitle,",")))
				graphopen = 1
				openplots+= stringfromlist(j,graphnumlist,",")+","
				label /w=$stringfromlist(j,graphnumlist,",") bottom,  "frequency [Hz]"
				if(linear)
					label/w=$stringfromlist(j,graphnumlist,",") left, "Spectrum [V/sqrt(Hz)]"
				else
					label/w=$stringfromlist(j,graphnumlist,",") left, "Spectrum [dBV/sqrt(Hz)]"
				endif
			endif
		endfor
		if(!graphopen)
			display $wn
			setwindow kwTopWin, graphicsTech=0
			label bottom, "frequency [Hz]"
			if(linear)
				label left, "Spectrum [V/sqrt(Hz)]"
			else
				label left, "Spectrum [dBV/sqrt(Hz)]"
			endif
			openplots+= winname(0,1)+","
		endif
	endfor

	// tile windows
	string cmd1, cmd2, window_string
	sprintf cmd1, "TileWindows/O=1/A=(%d,1) ", numChannels*2 
	cmd2 = ""
	// Tile graphs
	for(i=0;i<itemsinlist(openplots, ",");i=i+1)
		window_string = stringfromlist(i,openplots, ",")
		cmd1+= window_string +","
		cmd2 = "DoWindow/F " + window_string
		execute(cmd2)
	endfor
	execute(cmd1)

	for(i=0;i<numAverage;i+=1)
		// set up and execute command
		// SPEC_ANA,adcCh,numpts
		string cmd = ""
		sprintf cmd, "SPEC_ANA,%s,%s\r", replacestring(",",channels,""), num2str(numpts)
		writeInstr(instrID,cmd)
		
		variable bytesSec = roundNum(2*samplingFreq,0)
		variable read_chunk = roundNum(numChannels*bytesSec/50,0) - mod(roundNum(numChannels*bytesSec/50,0),numChannels*2)
		if(read_chunk < 50)
			read_chunk = 50 - mod(50,numChannels*2) // 50 or 48
		endif
		
		// read incoming data
		string buffer=""
		variable bytes_read = 0, bytes_left = 0, totalbytesreturn = numChannels*numpts*2, saveBuffer = 1000, totaldump = 0
		variable bufferDumpStart = stopMSTimer(-2)
		
		//print bytesSec, read_chunk, totalbytesreturn
		do
			buffer = readInstr(instrID, read_bytes=read_chunk, binary=1)
			// If failed, abort
			if (cmpstr(buffer, "NaN") == 0)
				stopFDACsweep(instrID)
				abort
			endif
			// add data to datawave
			specAna_distribute_data(buffer,read_chunk,channels,bytes_read/(2*numChannels))
			bytes_read += read_chunk
			totaldump = bytesSec*(stopmstimer(-2)-bufferDumpStart)*1e-6
			if(totaldump-bytes_read < saveBuffer)
				for(j=0;j<itemsinlist(openplots,",");j+=1)
					doupdate/w=$stringfromlist(j,openplots,",")
				endfor
			endif
		while(totalbytesreturn-bytes_read > read_chunk)
		// do one last read if any data left to read
		bytes_left = totalbytesreturn-bytes_read
		if(bytes_left > 0)
			buffer = readInstr(instrID,read_bytes=bytes_left,binary=1)
			specAna_distribute_data(buffer,bytes_left,channels,bytes_read/(2*numChannels))
			doupdate
		endif
		
		buffer = readInstr(instrID,read_term="\n")
		buffer = sc_stripTermination(buffer,"\r\n")
		if(!fdacCheckResponse(buffer,cmd,isString=1,expectedResponse="READ_FINISHED"))
			print "[ERROR] \"fdacSpectrumAnalyzer\": Error during read. Not all data recived!"
			abort
		endif
		
		// convert time series to spectrum
		variable bandwidth = measureFreq/2.0
		string fftnames = ""
		string ffttemps = ""
		for(j=0;j<numChannels;j+=1)
			ffttemps = "ffttempADC"+stringfromlist(j,channels,",")
			wn = "timeSeriesADC"+stringfromlist(j,channels,",")
			wave timewn = $wn
			duplicate/o timewn, fftinput
			fftinput = fftinput*1.0e-3
			fft/out=3/dest=$ffttemps fftinput
			wave fftwn = $ffttemps
			setscale/i x, 0, bandwidth, fftwn
			if(linear)
				fftwn = fftwn/sqrt(bandwidth)
			else
				fftwn = 20*log(fftwn/sqrt(bandwidth))
			endif
			fftnames = "fftADC"+stringfromlist(j,channels,",")
			wave fftwave = $fftnames
			if(i==0)
				fftwave = fftwn
			else
				fftwave = fftwave*i + fftwn  // So weighting of rows is correct when averaging
				fftwave = fftwave/(i+1)      // ""
			endif
		endfor
	endfor	
	
//	// close the time series plots
//	for(j=0;j<numChannels;j+=1)
//		killwindow/z $stringfromlist(j,openplots,",")
//	endfor
//	openplots = ""
		
	// display fft plots
//	for(i=0;i<numChannels;i+=1)
//		fftnames = "fftADC"+stringfromlist(i,channels,",")
//		wave fftwave = $fftnames
//		setscale/i x, 0, bandwidth, fftwave
//		display fftwave
//		label bottom, "frequency [Hz]"
//		if(linear)
//			label left, "Spectrum [V/sqrt(Hz)]"
//		else
//			label left, "Spectrum [dBV/sqrt(Hz)]"
//		endif
//		openplots+= winname(0,1)+","
//	endfor
	
	// tile windows
//	cmd1 = "TileWindows/O=1/A=(3,4) "+openplots
//	execute(cmd1)
	
	// try to scale y axis in plot is linear scale
	if(linear)
		variable searchStart = 0, maxpeak = 0, cutoff = 0.1
		for(i=0;i<numChannels;i+=1)
			fftnames = "fftADC"+stringfromlist(i,channels,",")
			wave fftwave = $fftnames
			searchStart = 1.0
			maxpeak = 0
			do
				findpeak/q/r=(searchStart,bandwidth/2.0)/i/m=(cutoff) fftwave
				if(abs(v_peakval) > abs(maxpeak))
					maxpeak = v_peakval
				endif
				searchStart = v_peakloc+1.0
			while(v_flag == 0)
			setaxis/w=$stringfromlist(i,openplots,",") left 0.0,maxpeak
		endfor
	endif
	
	if (nosave == 0)
		
		// save data to "data/spectrum/"
		string filename = "spectrum_"+strTime()+".h5"
		variable hdf5_id=0
		// create empty HDF5 container
		HDF5CreateFile/p=spectrum hdf5_id as filename
		// save the spectrum
		for(i=0;i<numChannels;i+=1)
			fftnames = "fftADC"+stringfromlist(i,channels,",")
			HDF5SaveData/IGOR=-1/WRIT=1/Z $fftnames , hdf5_id
			if (V_flag != 0)
				print "HDF5SaveData failed: ", wn
				return 0
			endif
		endfor
		
		// Create metadata
		// this just creates one big JSON string attribute for the group
		// its... fine
		variable /G meta_group_ID
		HDF5CreateGroup hdf5_id, "metadata", meta_group_ID
	
		
		make /FREE /T /N=1 cconfig = prettyJSONfmt(sc_createconfig())
		make /FREE /T /N=1 sweep_logs = prettyJSONfmt(sc_createSweepLogs(msg=comments))
		
		// Check that prettyJSONfmt actually returned a valid JSON.
		sc_confirm_JSON(sweep_logs, name="sweep_logs")
		sc_confirm_JSON(cconfig, name="cconfig")
		
		HDF5SaveData /A="sweep_logs" sweep_logs, hdf5_id, "metadata"
		HDF5SaveData /A="sc_config" cconfig, hdf5_id, "metadata"
	
		HDF5CloseGroup /Z meta_group_id
		if (V_flag != 0)
			Print "HDF5CloseGroup Failed: ", "metadata"
		endif
	
		// may as well save this config file, since we already have it
		sc_saveConfig(cconfig[0])
		
		// close HDF5 container
		HDF5CloseFile/Z hdf5_id
		if (v_flag != 0)
			print "HDF5CloseFile failed: ", filename
		else
			print "saving all spectra to file: "+filename
		endif
	endif
end

function specAna_distribute_data(buffer,bytes,channels,colNumStart)
	string buffer, channels
	variable bytes, colNumStart
	
	variable i=0, j=0, k=0, datapoint=0, numChannels = itemsinlist(channels,",")
	string wave1d = "", s1="", s2=""
	for(i=0;i<numChannels;i+=1)
		// load data into wave
		wave1d = "timeSeriesADC"+stringfromlist(i,channels,",")
		wave timewave = $wave1d
		k = 0
		for(j=0;j<bytes;j+=2*numChannels)
		// convert to floating point
			s1 = buffer[j + (i*2)]
			s2 = buffer[j + (i*2) + 1]
			datapoint = fdacChar2Num(s1, s2)
			timewave[colNumStart+k] = dataPoint
			k += 1
		endfor
	endfor
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
	
	svar fdackeys
	variable numDevices = str2num(stringbykey("numDevices",fdackeys,":",","))
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
	fd_id = get_json_from_json_path(sl_id, "FastDAC "+num2istr(fastdac_num)) // Get FastDAC JSON from Sweeplogs

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

function fdAWG_add_wave(instrID, wave_num, add_wave)
	// Adds to the AWGs stored in the fastdac
	variable instrID
	variable wave_num  	// Which AWG to add to (currently allowed 0 or 1)
	wave add_wave		// add_wave should be 2D with add_wave[0] = mV setpoint for each step in wave
					   		// 									 add_wave[1] = how many samples to stay at each setpoint
	
	// assert add_wave is 2D and has no nans/blanks
	// assert wave_num = 0,1
	
	// get fd_address from instrID
	
	// convert to string in form "ADD_WAVE,<wave_num>,<sp0>,<#sp0>,...,<spn>,<#spn>"
	// check len < 128/256/512 characters  (size of buffer input to fd)
		// if not then split into necessary chunks
	
	// send command(s)
	
	// check response(s) ("WAVE,<wave_num>,<len_setpoints>")
	
	// add to wave fdAWG<wave_num> (2D of setpoints and sample times)

end


function fdAWG_clear_wave(instrID, wave_num)
	// Clears AWG# from the fastdac and the corresponding global wave in IGOR
	variable instrID
	variable wave_num // Which AWG to clear (currently allowed 0 or 1)

	// assert wave_num = 0,1
	
	// get fd_address...
	
	string cmd
	sprintf cmd, "CLR_WAVE,%d", wave_num
	//send command
	
	//check response == "WAVE,<wave_num>,0"
	
	//clear fdAWG<wave_num>
	
end


