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
	buffer = addJSONkeyval(buffer, "SamplingFreq", num2str(getFADCspeed(instrID)), addquotes=0)
	buffer = addJSONkeyval(buffer, "MeasureFreq", num2str(getFADCmeasureFreq(instrID)), addquotes=0)

	// DAC values
	for(i=0;i<str2num(stringbykey("numDACCh"+num2istr(dev),fdackeys,":",","));i+=1)
		sprintf key, "DAC%d{%s}", i, fdacvalstr[i][3]
		buffer = addJSONkeyval(buffer, key, num2numstr(getfdacOutput(instrID,i)))
	endfor

	
	// ADC values
	for(i=0;i<str2num(stringbykey("numADCCh"+num2istr(dev),fdackeys,":",","));i+=1)
		buffer = addJSONkeyval(buffer, "ADC"+num2istr(i), num2numstr(getfadcChannel(instrID,adcChs+i)))
	endfor
	
	// AWG info if used
	nvar sc_AWG_used
	if(sc_AWG_used == 1)
		buffer = addJSONkeyval(buffer, "AWG", add_AWG_status())  //NOTE: AW saved in add_AWG_status()
	endif
	
	return addJSONkeyval("", "FastDAC "+num2istr(dev), buffer)
end


function/s add_AWG_status()
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

	// Add AWs used to HDF file
	variable i
	string wn
	for(i=0;i<AWG.numWaves;i++)
		// Get IGOR AW
		wn = fdAWG_get_AWG_wave(str2num(stringfromlist(i, AWG.AW_waves, ",")))
		savesinglewave(wn)
	endfor
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

function rampOutputFDAC(instrID,channel,output,[ramprate, ignore_lims]) // Units: mV, mV/s
	// ramps a channel to the voltage specified by "output".
	// ramp is controlled locally on DAC controller.
	// channel must be the channel set by the GUI.
	variable instrID, channel, output, ramprate, ignore_lims
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

function RampMultipleFDAC(InstrID, channels, setpoint, [ramprate, ignore_lims])
	variable InstrID, setpoint, ramprate, ignore_lims
	string channels
	
	channels = SF_get_channels(channels, fastdac=1)
	
	nvar fd_ramprate
	ramprate = paramIsDefault(ramprate) ? fd_ramprate : ramprate
	
	variable i=0, channel, nChannels = ItemsINList(channels, ",")
	for(i=0;i<nChannels;i+=1)
		channel = str2num(StringFromList(i, channels, ","))
		rampOutputfdac(instrID, channel, setpoint, ramprate=ramprate, ignore_lims=ignore_lims)
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


function fd_get_numpts_from_sweeprate(fd, start, fin, sweeprate)
/// Convert sweeprate in mV/s to numptsx for fdacrecordvalues
	variable fd, start, fin, sweeprate
	variable numpts, adcspeed, numadc = 0, i
	numadc = getNumFADC()
	adcspeed = getfadcspeed(fd)
	numpts = round(abs(fin-start)*(adcspeed/numadc)/sweeprate)   // distance * steps per second / sweeprate
	return numpts
end

function fd_get_sweeprate_from_numpts(fd, start, fin, numpts)
	// Convert numpts into sweeprate in mV/s
	variable fd, start, fin, numpts
	variable sweeprate, adcspeed, numadc = 0, i
	numadc = getNumFADC()
	adcspeed = getfadcspeed(fd)
	sweeprate = round(abs(fin-start)*(adcspeed/numadc)/numpts)   // distance * steps per second / numpts
	return sweeprate
end



function ClearFdacBuffer(instrID)
	variable instrID
	
	variable count=0, total = 0
	string buffer=""
	do 
		viRead(instrID, buffer, 2000, count)
		total += count
	while(count != 0)
	printf "Cleared %d bytes of data from buffer\r", total
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
		rampOutputfdac(instrID,channel,0, ramprate=100000, ignore_lims=1)
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
		rampOutputfdac(instrID,channel,-10000, ramprate=100000, ignore_lims=1)
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
	string graphlist = winlist("*",";","WIN:1"), graphname = "", graphtitle="", graphnumlist=""
	string plottitle="", graphnum=""			
	j=0
	variable index
	for (i=0;i<itemsinlist(graphlist);i=i+1)
		index = strsearch(graphlist,";",j)
		graphname = graphlist[j,index-1]
//		setaxis/w=$graphname /a
		getwindow $graphname wtitle
		splitstring /e="(.*):(.*)" s_value, graphnum, plottitle
		graphtitle+= plottitle+"|"  // Use a weird separator so that it doesn't clash with ':' or ';' or ',' which all get used in graph names
		graphnumlist+= graphnum+";"
		j=index+1
	endfor

	// open plots and distribute on screen
	variable graphopen=0
	string openplots=""
	string num
	string match_str
	for(i=0;i<itemsinlist(channels,",");i+=1)
		num = stringfromlist(i,channels,",")
		wn = "timeSeriesADC"+num
		graphopen=0
		for(j=0;j<itemsinlist(graphtitle, "|");j+=1)
			sprintf match_str, "*%s*", wn
			if(stringmatch(stringfromlist(j,graphtitle, "|"), match_str))
				graphopen = 1
				openplots+= stringfromlist(j,graphnumlist)+";"
				label /w=$stringfromlist(j,graphnumlist) bottom,  "time [s]"
				TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 strTime()
			endif
		endfor
		if(!graphopen)
			display $wn
			setwindow kwTopWin, graphicsTech=0
			label bottom, "time [s]"
			TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 strTime()
			openplots+= winname(0,1)+";"
		endif
		
		wn = "fftADC"+num
		graphopen=0
		for(j=0;j<itemsinlist(graphtitle, "|");j+=1)
			sprintf match_str, "*%s*", wn
			if(stringmatch(stringfromlist(j,graphtitle, "|"), match_str))
				graphopen = 1
				openplots+= stringfromlist(j,graphnumlist)+";"
				label /w=$stringfromlist(j,graphnumlist) bottom,  "frequency [Hz]"
				if(linear)
					label/w=$stringfromlist(j,graphnumlist) left, "Spectrum [V/sqrt(Hz)]"
				else
					label/w=$stringfromlist(j,graphnumlist) left, "Spectrum [dBV/sqrt(Hz)]"
				endif
				TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 strTime()
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
			TextBox/W=$stringfromlist(j,graphnumlist,",")/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 strTime()
			openplots+= winname(0,1)+";"
		endif
	endfor

	// tile windows
	string cmd1, cmd2, window_string
	sprintf cmd1, "TileWindows/O=1/A=(%d,1) ", numChannels*2 
	cmd2 = ""
	// Tile graphs
	for(i=0;i<itemsinlist(openplots);i=i+1)
		window_string = stringfromlist(i,openplots)
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
			
			
			// USING PERIODOGRAM INSTEAD OF FFT /////
			if(linear)
				DSPPeriodogram/PARS/NODC=1 fftinput
			else
				DSPPeriodogram/DBR=1/PARS/NODC=1 fftinput
			endif
			wave w_Periodogram
			duplicate/o w_Periodogram, $ffttemps
			wave fftwn = $ffttemps
			setscale/i x, 0, bandwidth, fftwn
			
			////////////////////////////////////////
			
			///// USING FFT /////////////////////////////
//			fft/out=3/dest=$ffttemps fftinput
//			wave fftwn = $ffttemps
//			setscale/i x, 0, bandwidth, fftwn
//
////			fftwn = fftwn/sqrt(bandwidth)
//			if(linear)
//				fftwn = fftwn/sqrt(bandwidth)
//			else
//				fftwn = 20*log(fftwn/sqrt(bandwidth))
//			endif
			////////////////////////////////////////////// 
			
			fftnames = "fftADC"+stringfromlist(j,channels,",")
			wave fftwave = $fftnames
			if(i==0)
				fftwave = fftwn
			else
				fftwave = fftwave*i + fftwn  // So weighting of rows is correct when averaging
				fftwave = fftwave/(i+1)      // ""
			endif
		endfor
//		if(!linear)
//			fftwn = 20*log(fftwn)
//		endif
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

function fdAWG_setup_AWG(instrID, [AWs, DACs, numCycles])
	// Function which initializes AWG_List s.t. selected DACs will use selected AWs when called in fd_Record_Values
	// Required because fd_Record_Values needs to know the total number of samples it will get back, which is calculated from values in AWG_list
	// IGOR AWs must be set in a separate function (which should reset AWG_List.initialized to 0)
	// Sets AWG_list.initialized to 1 to allow fd_Record_Values to run
	// If either parameter is not provided it will assume using previous settings
	variable instrID  // For printing information about frequency etc
	string AWs, DACs  // CSV for AWs to select which AWs (0,1) to use. // CSV sets for DACS e.g. "02, 1" for DACs 0, 2 to output AW0, and DAC 1 to output AW1
	variable numCycles // How many full waves to execute for each ramp step
	
	struct fdAWG_List S
	fdAWG_get_global_AWG_list(S)
	
	DACs = SF_get_channels(DACs, fastdac=1)  // Convert from label to numbers
	
	S.AW_Waves = selectstring(paramisdefault(AWs), AWs, S.AW_Waves)
	S.AW_DACs = selectstring(paramisdefault(DACs), DACs, S.AW_Dacs)
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
	
	printf "\r\rAWG set with:\r\tAWFreq = %.2fHz\r\tMin Samples for step = %d\r\tCycles per step = %d\r\tDuration per step = %.3fs\r\tnumADCs = %d\r\tSamplingFreq = %.1f/s\r\tMeasureFreq = %.1f/s\rOutputs are:\r%s\r",\
  									awFreq,											min_samples,			S.numCycles,						duration_per_step,		S.numADCs, 		S.samplingFreq,					S.measureFreq,						buffer											

   
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
   if (dimsize(add_wave, 1) != 2 || V_numNans !=0 || V_numINFs != 0) // Check 2D(TODO: Check 0/1) and no NaNs
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
	if(fdacCheckResponse(response, cmd, isString=1, expectedResponse=expected_response))
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
   if(fdacCheckResponse(response, cmd, isstring=1,expectedResponse=expected_response))
		string wn = fdAWG_get_AWG_wave(wave_num)
		wave AWG_wave = $wn
		killwaves AWG_wave 
   else
      abort "ERROR[fdAWG_clear_wave]: Error while clearing AWG_wave"+num2str(wave_num)
   endif
end


function/s fd_start_AWG_RAMP(S, AWG_list)
   struct FD_ScanVars &S
   struct fdAWG_list &AWG_list

   // AWG_RAMP,<number of waveforms>,<dac channel(s) to output waveform 0>,<dac channel(s) to output waveform n>,<dac channel(s) to ramp>,<adc channel(s)>,<initial dac voltage 1>,<…>,<initial dac voltage n>,<final dac voltage 1>,<…>,<final dac voltage n>,<# of waveform repetitions at each ramp step>,<# of ramp steps>
   //
   // Example:
   //
   // AWG_RAMP,2,012,345,67,0,-1000,1000,-2000,2000,50,50
   //
   // Response:
   //
   // <(2500 * waveform length) samples from ADC0>RAMP_FINISHED

	string starts, fins, temp
	if(S.direction == 1)
		starts = S.startxs
		fins = S.finxs
	elseif(S.direction == -1)
		starts = S.finxs
		fins = S.startxs
	else
		abort "ERROR[fdRV_start_INT_RAMP]: S.direction must be 1 or -1, not " + num2str(S.direction)
	endif

   string cmd = "", dacs="", adcs=""
   dacs = replacestring(",",S.channelsx,"")
	adcs = replacestring(",",S.adclist,"")
   // OPERATION, #N AWs, AW_dacs, DAC CHANNELS, ADC CHANNELS, INITIAL VOLTAGES, FINAL VOLTAGES, # OF Wave cycles per step, # ramp steps
   // Note: AW_dacs is formatted (dacs_for_wave0, dacs_for_wave1, .... e.g. '01,23' for Dacs 0,1 to output wave0, Dacs 2,3 to output wave1)
	sprintf cmd, "AWG_RAMP,%d,%s,%s,%s,%s,%s,%d,%d\r", AWG_list.numWaves, AWG_list.AW_dacs, dacs, adcs, starts, fins, AWG_list.numCycles, AWG_list.numSteps
	writeInstr(S.instrID,cmd)
	return cmd
end

function/s fd_start_INT_RAMP(S)
	// build command and start ramp
	// for now we only have to send one command to one device.
	struct FD_ScanVars &S
	
	
	string cmd = "", dacs="", adcs=""
	dacs = replacestring(",",S.channelsx,"")
	adcs = replacestring(",",S.adclist,"")
	
	string starts, fins, temp
	if(S.direction == 1)
		starts = S.startxs
		fins = S.finxs
	elseif(S.direction == -1)
		starts = S.finxs
		fins = S.startxs
	else
		abort "ERROR[fdRV_start_INT_RAMP]: S.direction must be 1 or -1, not " + num2str(S.direction)
	endif
		
	// OPERATION, DAC CHANNELS, ADC CHANNELS, INITIAL VOLTAGES, FINAL VOLTAGES, # OF STEPS
	sprintf cmd, "INT_RAMP,%s,%s,%s,%s,%d\r", dacs, adcs, starts, fins, S.numptsx
	writeInstr(S.instrID,cmd)
	return cmd
end


function fdAWG_make_multi_square_wave(instrID, v0, vP, vM, v0len, vPlen, vMlen, wave_num)
   // Make square waves with form v0, +vP, v0, -vM (useful for Tim's Entropy)
   // Stores copy of wave in Igor (accessible by fdAWG_get_AWG_wave(wave_num))
   // Note: Need to call, fdAWG_setup_AWG() after making new wave
   // To make simple square wave set length of unwanted setpoints to zero.
   variable instrID, v0, vP, vM, v0len, vPlen, vMlen, wave_num  // lens in seconds
	
	// Open connection
	sc_openinstrconnections(0)

   // put inputs into waves to make them easier to work with
   make/o/free sps = {v0, vP, v0, vM}
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

   // make wave to store setpoints/sample_lengths
   make/o/free/n=(0, 2) awg_sqw

	// Get current measureFreq to calculate require sampleLens to achieve durations in s
   variable measureFreq = getFADCmeasureFreq(instrID) 
   variable numSamples = 0

	// Make wave
   variable i=0, j=0
   for(i=0;i<numpnts(sps);i++)
      if(lens[i] != 0)  // Only add to wave if duration is non-zero
         numSamples = round(lens[i]*measureFreq)  // Convert to # samples
         if(numSamples == 0)  // Prevent adding zero length setpoint
            abort "ERROR[Set_multi_square_wave]: trying to add setpoint with zero length, duration too short for sampleFreq"
         endif
         awg_sqw[j][0] = {sps[i]}
         awg_sqw[j][1] = {numSamples}
         j++ // Increment awg_sqw position for storing next setpoint/sampleLen
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






//////////////////////////////////////
///////////// Structs ////////////////
//////////////////////////////////////



structure fdAWG_list
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
	
	// Get variable parts
//	wave fdAWG_globals_stuct_vars
	svar fdAWG_globals_stuct_vars
	structGet/S S fdAWG_globals_stuct_vars
	S.use_AWG = 0  // Always initialized to zero so that checks have to be run before using in scan (see SFawg_set_and_precheck())
	
	// Get string parts
	svar fdAWG_globals_AW_Waves
	svar fdAWG_globals_AW_dacs
	S.AW_waves = fdAWG_globals_AW_Waves
	S.AW_dacs = fdAWG_globals_AW_dacs
end

