//#pragma TextEncoding = "UTF-8"
//#pragma rtGlobals=3		// Use modern global access method and strict wave access.
//
//// Fast DAC (8 DAC channels + 4 ADC channels). Build in-house by Mark (Electronic work shop).
//// This is the instrument specific .ipf for FastDACs. For interface integration into IgorAqc see ScanController_FastDAC.ipf
//// Note: the Fast DAC is generally "stand alone", no other instruments can read at the same time (unless taking point by point measurements with fastdac, in which case you should be using a DMM)
////		Open a connection to the FastDAC FIRST, and then InitFastDAC() from ScanController_FastDAC
//// 		The fastdac will only run with the scancontroller_fastdac window specifically (not the regular scancontroller windowm, except for point by point measurements)
//// 	   In order to save fastdac waves with Scancontroller the user must add the fastdac=1 flag to initWaves() and SaveWaves()
////
//// The fastdac can also act as a spectrum analyzer method. See the Spectrum Analyzer section at the bottom. 
//// As for everyting else, you must open a connection to a FastDAC first and then run "InitFastDAC" before you can use the
//// spectrum analyzer method.
////
//// Written by Christian Olsen and Tim Child, 2020-03-27
//// Modified by Tim Child, 2020-06-06 -- Separated Fastdac device from scancontroller_fastdac
//// Added PID related functions by Ruiheng Su, 2021-06-02  
//// Massive refactoring of code, 2021-11 -- Tim Child
//
//////////////////////
////// Connection ////
//////////////////////
//
//function openFastDACconnection(instrID, visa_address, [verbose,numDACCh,numADCCh, optical,fill])
//	// instrID is the name of the global variable that will be used for communication
//	// visa_address is the VISA address string, i.e. ASRL1::INSTR
//	// Most FastDAC communication relies on the info in "sc_fdackeys". Pass numDACCh and
//	// numADCCh to fill info into "sc_fdackeys"
//	string instrID, visa_address
//	variable verbose, numDACCh, numADCCh   //idk what the point of this master variable is.
//	variable optical  // Whether connected by optical (or usb)
//	int fill
//
//	optical  = paramisDefault(optical)  ? 1 : optical
//	verbose  = paramisDefault(verbose)  ? 1 : verbose
//	numDACCh = paramisDefault(numDACCh) ? 8 : numDACCh
//	numADCCh = paramisDefault(numADCCh) ? 4 : numADCCh
//	fill     = paramIsDefault(fill)     ? 1 : fill	
//		
//	variable localRM
//	variable status = viOpenDefaultRM(localRM) // open local copy of resource manager
//	if(status < 0)
//		VISAerrormsg("open FastDAC connection:", localRM, status)
//		abort
//	endif
//	
//	string comm = ""
//	sprintf comm, "name=FastDAC,instrID=%s,visa_address=%s" instrID, visa_address
//	string options
//	if(optical)
// 		options = "baudrate=1750000,databits=8,parity=0,test_query=*IDN?"  // For Optical
//	else
//		options = "baudrate=57600,databits=8,parity=0,test_query=*IDN?"  // For USB
//	endif
//	openVISAinstr(comm, options=options, localRM=localRM, verbose=verbose)
//	
//	// fill info into "sc_fdackeys"
//	
//	if(fill)
//		scf_addFDinfos(instrID,visa_address,numDACCh,numADCCh)
//	endif
//	return localRM
//end
//
//
//function openMultipleFDACs(VISAnums, [verbose])
//	// This function is added to ease opening up multiple fastDAC connections in order
//	// It assumes the default options for verbose, numDACCh, numADCCh, and optical,
//	// The values can be found in the function openfastDACconnection()
//	// it will create the variables fd1,fd2,fd3.......
//	// it also reorders the list seen in the FastDacWindow because sc_fdackeys is killed everytime
//	//  	implying if the order changes -> the channels in the GUI will represent the new order.
//	
//	string VISAnums
//	variable verbose
//	
//	killstrings /z sc_fdackeys
//	
//	int i
//	for(i=0;i<itemsinlist(VISAnums, ",");i++)	
//		string instrID      = "fd" + num2str(i+1)
//		string visa_address = "ASRL" + removewhitespace(stringfromlist(i,VISAnums, ",")) + "::INSTR"
//		openFastDACconnection(instrID, visa_address, verbose=verbose)
//	endfor
//
//end
//
//
//
//
//
/////////////////////////
////// Get functions ////
/////////////////////////
//
//
//function getFADCmeasureFreq(instrID)
//	// Calculates measurement frequency as sampleFreq/numadc 
//	// NOTE: This assumes ALL recorded ADCs are on ONE fastdac. I.e. does not support measuring with multiple fastdacs
//	variable instrID
//	
//	svar sc_fdackeys	
//	variable numadc, samplefreq
//	numadc = scf_getNumRecordedADCs() 
//	if (numadc == 0)
//		numadc = 1
//	endif
//	samplefreq = getFADCspeed(instrID)
//	return samplefreq/numadc
//end
//
//function getFADCspeed(instrID)
//	// Returns speed in Hz (but arduino thinks in microseconds)
//	variable instrID
//	svar fadcSpeeds
//
//	string response="", compare="", cmd="", command=""
//
//	command = "READ_CONVERT_TIME"
//	cmd = command+",0"  // Read convert time on channel 0
//	response = queryInstr(instrID,cmd+"\r",read_term="\n")  // Get conversion time for channel 0 (should be same for all channels)
//	response = sc_stripTermination(response,"\r\n")
//	if(!scf_checkFDResponse(response,cmd))
//		abort "ERROR[getFADCspeed]: Failed to read speed from fastdac"
//	endif
//	
//	variable numDevice = scf_getFDnumber(instrID)
//	variable numADCs = scf_getFDInfoFromID(instrID, "numADC")
//
////	// Note: This extra check takes ~45ms (15ms per read)
////	variable i
////	for(i=1;i<numADCs;i+=1)  // Start from 1 because 0th channel already checked
////		cmd  = command+","+num2istr(i)
////		compare = queryInstr(instrID,cmd+"\r",read_term="\n")
////		compare = sc_stripTermination(compare,"\r\n")
////		if(!scf_checkFDResponse(compare,cmd))
////			abort
////		elseif(str2num(compare) != str2num(response)) // Ensure ADC channels all have same conversion time
////			print "WARNING[getfadcSpeed]: ADC channels 0 & "+num2istr(i)+" have different conversion times!"
////		endif
////	endfor
//	
//	return 1.0/(str2num(response)*1.0e-6) // return value in Hz
//end
//
//function getFADCchannel(channel, [len_avg])
//	// Instead of just grabbing one single datapoint which is susceptible to high f noise, this averages data over len_avg and returns a single value
//	variable channel, len_avg
//	
//	len_avg = paramisdefault(len_avg) ? 0.5 : len_avg
//	// Get the fd ID based on the ADC channel number
//	string fdIDname = stringfromlist(0, scc_getDeviceIDs(adc=1, channels=num2str(channel)))
//	
//	nvar fdID = $fdIDname 
//	variable numpts = ceil(getFADCspeed(fdID)*len_avg)
//	if(numpts <= 0)
//		numpts = 1
//	endif
//	
//	fd_readChunk(num2str(channel), numpts, fdIDname)  // Creates fd_readChunk_# wave	
//
//	wave w = $"fd_readChunk_"+num2str(channel)
//	wavestats/q w
//	wave/t fadcvalstr
//	fadcvalstr[channel][1] = num2str(v_avg)
//	return V_avg
//end
//
//function getFADCvalue(channel, [len_avg])
//	// Same as FADCchannel except it also applies the Calc Function before returning
//	// Note: Min read time is ~60ms because of having to check SamplingFreq a couple of times -- Could potentially be optimized further if necessary
//	variable channel, len_avg
//	len_avg = paramisdefault(len_avg) ? 0.05 : len_avg
//
//	variable/g scfd_val_mv = getFADCchannel(channel, len_avg=len_avg)  // Must be global so can use execute
//	variable/g scfd_val_real
//	wave/t fadcvalstr
//	string func = fadcvalstr[channel][4]
//
//	string cmd = replaceString("ADC"+num2str(channel), func, "scfd_val_mv")
//	sprintf cmd, "scfd_val_real = %s", cmd
//	execute/q/z cmd
//
//	return scfd_val_real
//end
//
//
//function getFADCChannelSingle(instrID,channel) // Units: mV
//	// channel must be the channel number given by the GUI!
//	// Gets a single FADC reading only, likely to be very noisy because no filtering of high f noise
//	// Use getFADCchannelAVG for averaged value
//	
//	variable instrID, channel
//	wave/t fadcvalstr
//	svar sc_fdackeys
//	
//
//	variable device // to store device num
//	string devchannel = scf_getChannelNumsOnFD(num2str(channel), device) 
//	scf_checkInstrIDmatchesDevice(instrID, device)
//
//	// query ADC
//	string cmd = ""
//	sprintf cmd, "GET_ADC,%d", devchannel
//	string response
//	response = queryInstr(instrID, cmd+"\r", read_term="\n")
//	response = sc_stripTermination(response,"\r\n")
//	
//	// check response
//	string err = ""
//	if(scf_checkFDResponse(response,cmd)) 
//		// good response, update window
//		fadcvalstr[channel][1] = num2str(str2num(response))
//		return str2num(response)
//	else
//		abort
//	endif
//end
//
//function getFDACOutput(instrID,channel,[same_as_window]) // Units: mV
//	// NOTE: Channel is the same as in FasDAC window
//	// same_as_window (1/0) - > checks if CHstart needs to be calculated.
//	variable instrID, channel, same_as_window
//	
//	variable CHstart
//	
//	same_as_window = paramisDefault(same_as_window)  ? 1 : same_as_window
//	
//	if(same_as_window)
//		CHstart = scf_getChannelStartNum(instrID, adc=0)
//	else
//		CHstart = 0
//	endif
//		
//	wave/t old_fdacvalstr, fdacvalstr
//	string cmd="", response="",warn=""
//	sprintf cmd, "GET_DAC,%d", channel - CHstart
//	response = queryInstr(instrID, cmd+"\r", read_term="\n")
//	response = sc_stripTermination(response,"\r\n")
//	
//	// check response
//	if(scf_checkFDResponse(response,cmd))
//		// good response
//		return str2num(response)
//	else
//		abort
//	endif
//end
//
//function getmultipleFDstatus(fdIDnames)
//	string fdIDnames
//	int i
//	for(i=0; i<itemsinlist(fdIDnames, ","); i++)
//		string fdIDname = stringfromlist(i, fdIDnames, ",")
//		fdIDname = removewhiteSpace(fdIDname)
//		getfdstatus(fdIDname)
//	endfor
//end
//
//function/s getFDstatus(fdIDname)
//	string fdIDname
//	string  buffer = "", key = ""
//	wave/t fdacvalstr	
//	svar sc_fdackeys
//	nvar instrID = $fdIDname
//		
//	buffer = addJSONkeyval(buffer, "visa_address", getResourceAddress(instrID), addquotes=1)
//	buffer = addJSONkeyval(buffer, "SamplingFreq", num2str(getFADCspeed(instrID)), addquotes=0)
//	buffer = addJSONkeyval(buffer, "MeasureFreq", num2str(getFADCmeasureFreq(instrID)), addquotes=0)
//
//	variable device = scf_getFDnumber(instrID)
//	variable i
//	variable CHstart
//
//	// DAC values
//	CHstart = scf_getChannelStartNum(instrID, adc=0)
//	for(i=0;i<scf_getFDInfoFromID(instrID, "numDAC");i+=1)
//		sprintf key, "DAC%d{%s}", CHstart+i, fdacvalstr[CHstart+i][3]
//		buffer = addJSONkeyval(buffer, key, num2numstr(getfdacOutput(instrID,CHstart+i))) // getfdacOutput is PER instrument
//	endfor
//	 
//	// ADC values
//	CHstart = scf_getChannelStartNum(instrID, adc=1)
//	for(i=0;i<scf_getFDInfoFromID(instrID, "numADC");i+=1)
//		buffer = addJSONkeyval(buffer, "ADC"+num2istr(CHstart+i), num2numstr(getfadcChannel(CHstart+i)))
//	endfor
//	
//	
//	// AWG info
//	buffer = addJSONkeyval(buffer, "AWG", getFDAWGstatus())  //NOTE: AW saved in getFDAWGstatus()
//	return addJSONkeyval("", "FastDAC "+num2istr(device), buffer)
//end
//
//
//function/s getFDAWGstatus() 
//	// Function to be called from getFDstatus() to add a section with information about the AWG used
//	// Also adds AWs used to HDF
//	
//	string buffer = ""// For storing JSON to return
//	
//	// Get the Global AWG list (which has info about what was used in scan)
//	struct AWGVars AWG
//	fd_getGlobalAWG(AWG)
//	
//	buffer = addJSONkeyval(buffer, "AWG_used", num2istr(AWG.use_AWG), addquotes=0)				// Was the AWG used in this scan? 
//	buffer = addJSONkeyval(buffer, "AW_Waves", AWG.AW_Waves, addquotes=1)							// Which waves were used (e.g. "0,1" for both AW0 and AW1)
//	buffer = addJSONkeyval(buffer, "AW_Dacs", AWG.AW_Dacs, addquotes=1)								// Which Dacs output each wave (e.g. "01,2" for Dacs 0,1 outputting AW0 and Dac 2 outputting AW1)
//	buffer = addJSONkeyval(buffer, "waveLen", num2str(AWG.waveLen), addquotes=0)					// How are the AWs in total samples
//	buffer = addJSONkeyval(buffer, "numADCs", num2str(AWG.numADCs), addquotes=0)					// How many ADCs were selected to record when the AWG was set up
//	buffer = addJSONkeyval(buffer, "samplingFreq", num2str(AWG.samplingFreq), addquotes=0)		// Sample rate of the Fastdac at time AWG was set up
//	buffer = addJSONkeyval(buffer, "measureFreq", num2str(AWG.measureFreq), addquotes=0)			// Measure freq at time AWG was set up (i.e. sampleRate/numADCs)
//	buffer = addJSONkeyval(buffer, "numWaves", num2str(AWG.numWaves), addquotes=0)				// How many AWs were used in total (should be 1 or 2)
//	buffer = addJSONkeyval(buffer, "numCycles", num2str(AWG.numCycles), addquotes=0)				// How many full cycles of the AWs per DAC step
//	buffer = addJSONkeyval(buffer, "numSteps", num2str(AWG.numSteps), addquotes=0)				// How many DAC steps for the full ramp
//	
//
//	return buffer
//end
//
//
/////////////////////////
////// Set functions ////
/////////////////////////
//
//function setFADCSpeed(instrID,speed,[loadCalibration]) // Units: Hz
//	// set the ADC speed in Hz
//	// set loadCalibration=1 to load save calibration
//	variable instrID, speed, loadCalibration
//	
//	if(paramisdefault(loadCalibration))
//		loadCalibration = 1
//	elseif(loadCalibration != 1)
//		loadCalibration = 0
//	endif
//	
//	// check formatting of speed
//	if(speed <= 0)
//		print "[ERROR] \"setfadcSpeed\": Speed must be positive"
//		abort
//	endif
//	
////	svar sc_fdackeys
//	variable numDevices = scf_getNumFDs()
//	string instrAddress = getResourceAddress(instrID)
//	variable i, numADCCh, numDevice	
//	string deviceAddress = "", cmd = "", response = ""
//	for(i=0;i<numDevices;i+=1)
//		deviceAddress = scf_getFDVisaAddress(i+1)
//		if(cmpstr(deviceAddress,instrAddress) == 0)
//			numADCCh = scf_getFDInfoFromDeviceNum(i+1, "numADC")
//			numDevice = i+1
//			break
//		endif
//	endfor
//	for(i=0;i<numADCCh;i+=1)
//		sprintf cmd, "CONVERT_TIME,%d,%d\r", i, 1.0/speed*1.0e6  // Convert from Hz to microseconds
//		response = queryInstr(instrID, cmd, read_term="\n")  //Set all channels at same time (generally good practise otherwise can't read from them at the same time)
//		response = sc_stripTermination(response,"\r\n")
//		if(!scf_checkFDResponse(response,cmd))
//			abort
//		endif
//	endfor
//	
//	speed = roundNum(1.0/str2num(response)*1.0e6,0)
//	
//	if(loadCalibration)
//		try
//			fd_loadFadcCalibration(instrID,speed)
//		catch
//			variable rte = getrterror(1)
//			print "WARNING[setFADCspeed]: fd_loadFadcCalibration failed. If no calibration file exists, run CalibrateFADC() to create one"
//		endtry			
//	else
//		print "[WARNING] \"setfadcSpeed\": Changing the ADC speed without ajdusting the calibration might affect the precision."
//	endif
//	
//	// update window
//	string adcSpeedMenu = "fadcSetting"+num2istr(numDevice)
//	svar value = $("sc_fadcSpeed"+num2istr(numDevice))
//	variable isoldvalue = findlistitem(num2str(speed),value,";")
//	if(isoldvalue < 0)
//		value = addlistItem(num2str(speed),value,";",Inf)
//	endif
//	value = sortlist(value,";",2)
//	variable mode = whichlistitem(num2str(speed),value,";")+1
//	popupMenu $adcSpeedMenu,mode=mode
//	
//	// Set Arbitrary Wave Generator global struct .initialized to 0 (i.e. force user to update AWG because sample rate affects it)
//	fd_setAWGuninitialized()
//end
//
//
//function RampMultipleChannels(channels, setpoints, [ignore_lims])
//	// uses ramp RampMultipleFDAC() without worrying about the IDs, figures it out internally
//	// inputs:   comma seperated channel labels or numbers
//	// examples: channels = "0, 1, 18" , setpoints = "0, 100, 1000" (mV)
//	string channels
//	string setpoints
//	variable ignore_lims
//	
//	channels = scu_getChannelNumbers(channels, fastdac=1)
//	string channelIDs = scc_getDeviceIDs(channels = channels)
//	int i
//	for(i=0;i<itemsinlist(channels, ","); i++)
//		nvar fdID = $(stringfromlist(i, channelIDs))
//		string channel = stringfromlist(i, channels, ",")
//		string setpoint = stringfromlist(i, setpoints, ",")
//		rampMultipleFDAC(fdID, channel, str2num(setpoint), ignore_lims = ignore_lims)
//	endfor
//	
//end
//
//function RampMultipleFDAC(InstrID, channels, setpoint, [ramprate, setpoints_str, ignore_lims])
//	// Ramps multiple channels to setpoint(s) (this is the ramp function that SHOULD be used)
//	// InstrID - FastDAC connection variable (e.g. fd)
//	// channels - comma separated list of channels to sweep
//	// setpoint - Value to sweep channels to (ignored if using setpoints_str)
//	// ramprate - sweeprate of channels to setpoint mV/s
//	// setpoints_str - comma separated list of setpoints for each channel in channels (setpoint ignored)
//	// Note: If ramprate is left default, then each channel will ramp at speed specified in FastDAC window
//	variable InstrID, setpoint, ramprate, ignore_lims
//	string channels, setpoints_str
//	
//	ramprate = numtype(ramprate) == 0 ? ramprate : 0  // If not a number, then set to zero (which means will be overridden by ramprate in window)
//
//	scu_assertSeparatorType(channels, ",")
//	channels = scu_getChannelNumbers(channels, fastdac=1)
//	
//	if (!paramIsDefault(setpoints_str) && (itemsInList(channels, ",") != itemsInList(setpoints_str, ",")))
//		abort "ERROR[RampMultipleFdac]: number of channels does not match number of setpoints in setpoints_str"	
//	endif
//	
//	variable i=0, channel, nChannels = ItemsInList(channels, ",")
//	variable channel_ramp
//	for(i=0;i<nChannels;i+=1)
//		if (!paramIsDefault(setpoints_str))
//			setpoint = str2num(StringFromList(i, setpoints_str, ","))
//		endif
//		channel = str2num(StringFromList(i, channels, ","))
//		channel_ramp = ramprate != 0 ? ramprate : str2num(scf_getDacInfo(num2str(channel), "ramprate"))
//		fd_rampOutputFDAC(instrID, channel, setpoint, channel_ramp, ignore_lims=ignore_lims)  
//	endfor
//end
//
//
//function fd_rampOutputFDAC(instrID,channel,output, ramprate, [ignore_lims]) // Units: mV, mV/s
//	// NOTE: This is an internal function ONLY. Use RampMultipleFDAC instead.
//	// ramps a channel to the voltage specified by "output".
//	// ramp is controlled locally on DAC controller.
//	// channel must be the channel set by the GUI.
//	
//	//update - if inputing actual DAC channel, it should not find the start channel
//	
//	variable instrID, channel, output, ramprate, ignore_lims
//	wave/t fdacvalstr, old_fdacvalstr
//	svar sc_fdackeys
//	
//	// TOOD: refactor with scf_getFDInfoFromID()/scf_getChannelNumsOnFD() etc
//
//	variable numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",","))
//	variable i=0, devchannel = 0, startCh = 0, numDACCh = 0
//	string deviceAddress = "", err = "", instrAddress = getResourceAddress(instrID)
//	for(i=0;i<numDevices;i+=1)
//		numDACCh =  str2num(stringbykey("numDACCh"+num2istr(i+1),sc_fdackeys,":",","))
//		if(startCh+numDACCh-1 >= channel)
//			// this is the device, now check that instrID is pointing at the same device
//			deviceAddress = stringbykey("visa"+num2istr(i+1),sc_fdackeys,":",",")
//			if(cmpstr(deviceAddress,instrAddress) == 0)
//				devchannel = channel-startCh
//				break
//			else
//				sprintf err, "[ERROR] \"fd_rampOutputFDAC\": channel %d is not present on device with address %s", channel, instrAddress
//				print(err)
//				scfw_resetfdacwindow(channel)
//				abort
//			endif
//		endif
//		startCh += numDACCh
//	endfor
//	
//	// check that output is within hardware limit
//	nvar fdac_limit
//	if(abs(output) > fdac_limit || numtype(output) != 0)
//		sprintf err, "[ERROR] \"fd_rampOutputFDAC\": Output voltage on channel %d outside hardware limit", channel
//		print err
//		scfw_resetfdacwindow(channel)
//		abort
//	endif
//
//	if(ignore_lims != 1)  // I.e. ignore if already checked in pre scan checks
//		// check that output is within software limit
//		// overwrite output to software limit and warn user
//		string softLimitPositive = "", softLimitNegative = "", expr = "(-?[[:digit:]]+),\s*([[:digit:]]+)"
//		splitstring/e=(expr) fdacvalstr[channel][2], softLimitNegative, softLimitPositive
//		if(output < str2num(softLimitNegative) || output > str2num(softLimitPositive))
//			switch(sign(output))
//				case -1:
//					output = str2num(softLimitNegative)
//					break
//				case 1:
//					if(output != 0)
//						output = str2num(softLimitPositive)
//					else
//						output = 0
//					endif
//					break
//			endswitch
//			string warn
//			sprintf warn, "[WARNING] \"fd_rampOutputFDAC\": Output voltage must be within limit. Setting channel %d to %.3fmV\n", channel, output
//			print warn
//		endif
//	
//		// Check that ramprate is within software limit, otherwise use software limit
//		if (ramprate > str2num(fdacvalstr[channel][4]) || numtype(ramprate) != 0)
//			printf "[WARNING] \"fd_rampOutputFDAC\": Ramprate of %.0fmV/s requested for channel %d. Using max_ramprate of %.0fmV/s instead\n" ramprate, channel, str2num(fdacvalstr[channel][4])
//			ramprate = str2num(fdacvalstr[channel][4])
//			if (numtype(ramprate) != 0)
//				abort "ERROR[fd_rampOutputFDAC]: Bad ramprate in ScanController_Fastdac window for channel "+num2str(channel)
//			endif
//		endif
//	endif 
//		
//	// read current dac output and compare to window
//	variable currentoutput = getfdacOutput(instrID,channel)
//	
//	// ramp channel to output
//	variable delay = abs(output-currentOutput)/ramprate
//	string cmd = "", response = ""
//	sprintf cmd, "RAMP_SMART,%d,%.4f,%.3f", devchannel, output, ramprate 
//	if(delay > 2)
//		string delaymsg = ""
//		sprintf delaymsg, "Waiting for fastdac Ch%d\n\tto ramp to %dmV", channel, output
//		response = queryInstrProgress(instrID, cmd+"\r", delay, delaymsg, read_term="\n")
//	else
//		response = queryInstr(instrID, cmd+"\r", read_term="\n", delay=delay)
//	endif
//	response = sc_stripTermination(response,"\r\n")
//	
//	// check respose
//	if(scf_checkFDResponse(response,cmd,isString=1,expectedResponse="RAMP_FINISHED"))
//		output = getfdacOutput(instrID, channel)
//		scfw_updateFdacValStr(channel, output, update_oldValStr=1)
//	else
//		scfw_resetfdacwindow(channel)
//		abort
//	endif
//end
//
//
//
//
//
//
//
/////////////////////////
////// PID functions ////
/////////////////////////
//
//function startPID(instrID)
//	// Starts the PID algorithm on DAC and ADC channels 0
//	// make sure that the PID algorithm does not return any characters.
//	variable instrID
//	
//	string cmd=""
//	sprintf cmd, "START_PID"
//	writeInstr(instrID, cmd+"\r")
//end
//
//
//function stopPID(instrID)
//	// stops the PID algorithm on DAC and ADC channels 0
//	variable instrID
//	
//	string cmd=""
//	sprintf cmd, "STOP_PID"
//	writeInstr(instrID, cmd+"\r")
//end
//
//function setPIDTune(instrID, kp, ki, kd)
//	// sets the PID tuning parameters
//	variable instrID, kp, ki, kd
//	
//	string cmd=""
//	// specify to print 9 digits after the decimal place
//	sprintf cmd, "SET_PID_TUNE,%.9f,%.9f,%.9f",kp,ki,kd
//
//	writeInstr(instrID, cmd+"\r")
//end
//
//function setPIDSetp(instrID, setp)
//	// sets the PID set point, in mV
//	variable instrID, setp
//	
//	string cmd=""
//	sprintf cmd, "SET_PID_SETP,%f",setp
//
//   	writeInstr(instrID, cmd+"\r")
//end
//
//
//function setPIDLims(instrID, lower,upper) //mV, mV
//	// sets the limits of the controller output, in mV 
//	variable instrID, lower, upper
//	
//	string cmd=""
//	sprintf cmd, "SET_PID_LIMS,%f,%f",lower,upper
//
//   	writeInstr(instrID, cmd+"\r")
//end
//
//function setPIDDir(instrID, direct) // 0 is reverse, 1 is forward
//	// sets the direction of PID control
//	// The default direction is forward 
//	// The process variable of a reverse process decreases with increasing controller output 
//	// The process variable of a direct process increases with increasing controller output 
//	variable instrID, direct 
//	
//	string cmd=""
//	sprintf cmd, "SET_PID_DIR,%d",direct
//   	writeInstr(instrID, cmd+"\r")
//end
//
//function setPIDSlew(instrID, [slew]) // maximum slewrate in mV per second
//	// the slew rate is proportional how fast the controller output is allowed to ramp
//	variable instrID, slew 
//	
//	if(paramisdefault(slew))
//		slew = 10000000.0
//	endif
//		
//	string cmd=""
//	sprintf cmd, "SET_PID_SLEW,%.9f",slew
//	print/D cmd
//   	writeInstr(instrID, cmd+"\r")
//end
//
//
//
///////////////////////////////////////////////////////////////////////////////////////
////////////////////////// Calibration /////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
//function fd_loadFadcCalibration(instrID,speed)
//	variable instrID,speed
//	
//	string regex = "", filelist = "", jstr=""
//	variable i=0,k=0
//	
//	svar sc_fdackeys
//	variable numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",",")), numADCCh=0, numDACCh=0,deviceNum=0
//	string instrAddress = getResourceAddress(instrID), deviceAddress = ""
//	for(i=0;i<numDevices;i+=1)
//		deviceAddress = stringbykey("visa"+num2istr(i+1),sc_fdackeys,":",",")
//		if(cmpstr(deviceAddress,instrAddress) == 0)
//			numDACCh = str2num(stringbykey("numDACCh"+num2istr(i+1),sc_fdackeys,":",","))
//			numADCCh = str2num(stringbykey("numADCCh"+num2istr(i+1),sc_fdackeys,":",","))
//			deviceNum = i+1
//			break
//		endif
//	endfor
//	
//	sprintf regex, "fADC%dCalibration_%d", deviceNum, speed
////	print regex
//	filelist = indexedfile(config,-1,".txt")
//	filelist = greplist(filelist,"^"+regex)  // ^ to force matching from start of string
//	if(itemsinlist(filelist) == 1)
//		// we have a calibration file
//		jstr = readtxtfile(stringfromlist(0,filelist),"config")
//	elseif(itemsinlist(filelist) > 1)
//		// somehow there is more than one file. Try to find the correct one!
//		for(i=0;i<itemsinlist(filelist);i+=1)
//			if(cmpstr(stringfromlist(i,filelist),regex+".txt") == 0)
//				// this is the correct file
//				k = -1
//				break
//			endif
//		endfor
//		if(k < 0)
//			jstr = readtxtfile(stringfromlist(i,filelist),"config")
//		else
//			// no calibration file found!
//			// raise error
//			print "[ERROR] \"fd_loadFadcCalibration\": No calibration file found!"
//			abort
//		endif
//	else
//		// no calibration file found!
//		// raise error
//		print "[ERROR] \"fd_loadFadcCalibration\": No calibration file found!"
//		abort
//	endif
//	
//	// do some checks
//	if(cmpstr(getresourceaddress(instrID),getJSONvalue(jstr, "visa_address")) == 0)
//		// it's the same instrument
//	else
//		// not the same visa address, likely not the same instrument, abort!
//		print "[ERORR] \"fd_loadFadcCalibration\": visa address' not the same!"
//		abort
//	endif
//	if(speed == str2num(getJSONvalue(jstr, "speed")))
//		// it's the correct speed
//	else
//		// not the same speed, abort!
//		print "[ERORR] \"fd_loadFadcCalibration\": speed is not correct!"
//		abort
//	endif
//	
//	// update the calibration on the the instrument
//	variable zero_scale = 0, full_scale = 0
//	string response = ""
//	for(i=0;i<str2num(getJSONvalue(jstr, "num_channels"));i+=1)
//		zero_scale = str2num(getJSONvalue(jstr, "zero-scale"+num2istr(i)))
//		full_scale = str2num(getJSONvalue(jstr, "full-scale"+num2istr(i)))
//		fd_updateFadcCalibration(instrID,i,zero_scale,full_scale)
//	endfor
//end
//
//function CalibrateFDAC(instrID)
//	// Use this function to calibrate all dac channels.
//	// You need a DMM that you really trust (NOT a hand held one)!
//	// The calibration will only work if initFastDAC() has been executed first.
//	// Follow the instructions on screen.
//	variable instrID
//	
//	sc_openinstrconnections(0)
//	
//	svar/z sc_fdackeys
//	if(!svar_exists(sc_fdackeys))
//		print "[ERROR] \"fdacCalibrate\": Run initFastDAC() before calibration."
//		abort
//	endif
//	
//	// check that user has all the bits needed!
//	variable user_response = 0
//	user_response = ask_user("You will need a DMM you trust set to return six decimal places. Press OK to continue",type=1)
//	if(user_response == 0)
//		print "[ERROR] \"fdacCalibrate\": User abort!"
//		abort
//	endif
//	
//	variable numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",",")), i=0, numDACCh=0, deviceNum=0
//	string instrAddress = getResourceAddress(instrID), deviceAddress = ""
//	for(i=0;i<numDevices;i+=1)
//		deviceAddress = stringbykey("visa"+num2istr(i+1),sc_fdackeys,":",",")
//		if(cmpstr(deviceAddress,instrAddress) == 0)
//			numDACCh = str2num(stringbykey("numDACCh"+num2istr(i+1),sc_fdackeys,":",","))
//			deviceNum = i+1
//			break
//		endif
//	endfor
//	
//	// reset calibrations on all DAC channels
//	for(i=0;i<numDACCh;i+=1)
//		fd_ResetFdacCalibration(instrID,i)
//	endfor
//	
//	// start calibration
//	string question = "", offsetReg = "", gainReg = "", message = "", result="", key=""
//	variable user_input = 0, channel = 0, offset = 0
//	for(i=0;i<numDACCh;i+=1)
//		channel = i
//		sprintf question, "Calibrating DAC Channel %d. Connect DAC Channel %d to the DMM. Press YES to continue", channel, channel
//		user_response = ask_user(question,type=1)
//		if(user_response == 0)
//			print "[ERROR] \"fdacCalibrate\": User abort! DAC's are NOT calibrated anymore.\rYou must re-run the calibration before you can trust the output values!"
//			abort
//		endif
//		
//		// ramp channel to 0V
//		fd_rampOutputFDAC(instrID,channel+scf_getChannelStartNum(instrID, adc=0),0, 100000, ignore_lims=1)
//		sprintf question, "Input value displayed by DMM in volts."
//		user_input = prompt_user("DAC offset calibration",question)
//		if(numtype(user_input) == 2)
//			print "[ERROR] \"fdacCalibrate\": User abort! DAC's are NOT calibrated anymore.\rYou must re-run the calibration before you can trust the output values!"
//			abort
//		endif
//		
//		// write offset to FastDAC
//		// FastDAC returns the gain value used in uV
//		offsetReg = fd_setFdacCalibrationOffset(instrID,channel,user_input)
//		sprintf key, "offset%d_", channel
//		result = replacenumberbykey(key+"stepsize",result,str2num(stringfromlist(1,offsetReg,",")),":",",")
//		result = replacenumberbykey(key+"register",result,str2num(stringfromlist(2,offsetReg,",")),":",",")
//		sprintf message, "Offset calibration of DAC channel %d finished. Final values are:\rOffset stepsize = %.2fuV\rOffset register = %d", channel, str2num(stringfromlist(1,offsetReg,",")), str2num(stringfromlist(2,offsetReg,","))
//		print message
//		
//		// ramp channel to -10V
//		fd_rampOutputFDAC(instrID,channel+scf_getChannelStartNum(instrID, adc=0),-10000, 100000, ignore_lims=1)
//		sprintf question, "Input value displayed by DMM in volts."
//		user_input = prompt_user("DAC gain calibration",question)
//		if(numtype(user_input) == 2)
//			print "[ERROR] \"fdacCalibrate\": User abort! DAC's are NOT calibrated anymore.\rYou must re-run the calibration before you can trust the output values!"
//			abort
//		endif
//		
//		// write offset to FastDAC
//		// FastDAC returns the gain value used in uV
//		offset = user_input+10 
//		gainReg = fd_setFdacCalibrationGain(instrID,channel,offset)
//		sprintf key, "gain%d_", channel
//		result = replacenumberbykey(key+"stepsize",result,str2num(stringfromlist(1,gainReg,",")),":",",")
//		result = replacenumberbykey(key+"register",result,str2num(stringfromlist(2,gainReg,",")),":",",")
//		sprintf message, "Gain calibration of DAC channel %d finished. Final values are:\rGain stepsize = %.2f uV\rGain register = %d", channel, str2num(stringfromlist(0,gainReg,",")), str2num(stringfromlist(1,gainReg,","))
//		print message
//	endfor
//	
//	// calibration complete
//	fd_saveFdacCalibration(deviceAddress,deviceNum,numDACCh,result)
//	ask_user("DAC calibration complete! Result has been written to file on \"config\" path.", type=0)
//end
//
//function CalibrateFADC(instrID)
//	// Use this function to calibrate all adc channels.
//	// The calibration will only work if initFastDAC() has been executed first.
//	// The calibration uses the DAC channels to calibrate the ADC channels,
//	// if the DAC's aren't calibrated this won't give good results!
//	// Follow the instructions on screen.
//	variable instrID
//	
//	svar/z sc_fdackeys
//	if(!svar_exists(sc_fdackeys))
//		print "[ERROR] \"fadcCalibrate\": Run initFastDAC() before calibration."
//		abort
//	endif
//	
//	variable numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",",")), i=0, numADCCh=0, numDACCh=0,deviceNum=0
//	string instrAddress = getResourceAddress(instrID), deviceAddress = ""
//	for(i=0;i<numDevices;i+=1)
//		deviceAddress = stringbykey("visa"+num2istr(i+1),sc_fdackeys,":",",")
//		if(cmpstr(deviceAddress,instrAddress) == 0)
//			numDACCh = str2num(stringbykey("numDACCh"+num2istr(i+1),sc_fdackeys,":",","))
//			numADCCh = str2num(stringbykey("numADCCh"+num2istr(i+1),sc_fdackeys,":",","))
//			deviceNum = i+1
//			break
//		endif
//	endfor
//	
//	if(numADCCh > numDACCh)
//		print "[ERROR] \"fadcCalibrate\": The number of ADC channels is greater than the number of DAC channels.\rUse \"ADC_CH_ZERO_SC_CAL\" & \"ADC_CH_FULL_SC_CAL\" to calibrate each ADC channel seperately!"
//		abort
//	endif
//	
//	// get current speed
//	variable adcSpeed = roundNum(getfadcSpeed(instrID),0) // round to integer
//	
//	// check that user has all the bits needed!
//	variable user_response = 0
//	string question = ""
//	sprintf question, "Connect the DAC channel 0-%d --> ADC channel 0-%d. Press YES to continue", numADCCh-1, numADCCh-1
//	user_response = ask_user(question,type=1)
//	if(user_response != 1)
//		print "[ERROR] \"fadcCalibrate\": User abort!"
//		abort
//	endif
//	
//	// Do calibration
//	string cmd = "CAL_ADC_WITH_DAC\r"
//	string response = queryInstr(instrID,cmd,read_term="\n",delay=2)
//	response = sc_stripTermination(response,"\r\n")
//
//	print response
//	// turn result into key/value string
//	// response is formatted like this: "numCh0,zero,numCh1,zero,numCh0,full,numCh1,full,"
//	string result="", key_zero="", key_full=""
//	variable zeroIndex=0,fullIndex=0, calibrationFail = 0, j=0
//	for(i=0;i<numADCCh;i+=1)
//		zeroIndex = whichlistitem("ch"+num2istr(i),response,",",0)+1
//		fullIndex = whichlistitem("ch"+num2istr(i),response,",",zeroIndex)+1
//		if(zeroIndex <= 0 || fullIndex <= 0)
//			calibrationFail = 1
//			break
//		endif
//		sprintf key_zero, "zero-scale%d", i
//		sprintf key_full, "full-scale%d", i
//		result = replaceNumberByKey(key_zero,result,str2num(stringfromlist(zeroIndex,response,",")),":",",")
//		result = replaceNumberByKey(key_full,result,str2num(stringfromlist(fullIndex,response,",")),":",",")
//	endfor
//	
//	// read calibration completion
//	response = readInstr(instrID,read_term="\n")
//	response = sc_stripTermination(response,"\r\n")
//	if(scf_checkFDResponse(response,cmd,isString=1,expectedResponse="CALIBRATION_FINISHED") && calibrationFail == 0)
//		// all good, calibration complete
//		for(j=0;j<4;j++)
////			rampMultipleFDAC(instrID, "0,1,2,3", 0, ramprate=10000)
//			fd_rampOutputFDAC(instrID, j+scf_getChannelStartNum(instrID, adc=0), 0, 100000)
//		endfor
//		fd_saveFadcCalibration(deviceAddress,deviceNum,numADCCh,result,adcSpeed)
//		ask_user("ADC calibration complete! Result has been written to file on \"config\" path.", type=0)
//	else
//		print "[ERROR] \"fadcCalibrate\": Calibration failed."
//		abort
//	endif
//end
//
//function fd_saveFadcCalibration(deviceAddress,deviceNum,numADCCh,result,adcSpeed)
//	string deviceAddress, result
//	variable deviceNum, numADCCh, adcSpeed
//	
//	svar/z sc_fdackeys
//	
//	// create JSON string
//	string buffer = "", zeroScale = "", fullScale = "", key = ""
//	variable i=0
//	
//	buffer = addJSONkeyval(buffer,"visa_address",deviceAddress,addQuotes=1)
//	buffer = addJSONkeyval(buffer,"speed",num2str(adcspeed))
//	buffer = addJSONkeyval(buffer,"num_channels",num2istr(numADCCh))
//	for(i=0;i<numADCCh;i+=1)
//		sprintf key, "zero-scale%d", i
//		zeroScale = stringbykey(key,result,":",",")
//		buffer = addJSONkeyval(buffer,key,zeroScale)
//		sprintf key, "full-scale%d", i
//		fullScale = stringbykey(key,result,":",",")
//		buffer = addJSONkeyval(buffer,key,fullScale)
//	endfor
//	
//	// create ADC calibration file
//	string filename = ""
//	sprintf filename, "fADC%dCalibration_%d.txt", deviceNum, adcSpeed
//	writetofile(prettyJSONfmt(buffer),filename,"config")
//end
//
//function fd_saveFdacCalibration(deviceAddress,deviceNum,numDACCh,result)
//	string deviceAddress, result
//	variable deviceNum, numDACCh
//	
//	svar/z sc_fdackeys
//	
//	// create JSON string
//	string buffer = "", offset = "", gain = "", key = ""
//	variable i=0
//	
//	buffer = addJSONkeyval(buffer,"visa_address",deviceAddress,addQuotes=1)
//	buffer = addJSONkeyval(buffer,"num_channels",num2istr(numDACCh))
//	for(i=0;i<numDACCh;i+=1)
//		sprintf key, "offset%d_stepsize", i
//		offset = stringbykey(key,result,":",",")
//		buffer = addJSONkeyval(buffer,key,offset)
//		sprintf key, "offset%d_register", i
//		offset = stringbykey(key,result,":",",")
//		buffer = addJSONkeyval(buffer,key,offset)
//		sprintf key, "gain%d_stepsize", i
//		gain = stringbykey(key,result,":",",")
//		buffer = addJSONkeyval(buffer,key,gain)
//		sprintf key, "gain%d_register", i
//		gain = stringbykey(key,result,":",",")
//		buffer = addJSONkeyval(buffer,key,gain)
//	endfor
//
//	// create DAC calibration file
//	string filename = ""
//	sprintf filename, "fDAC%dCalibration_%d.txt", deviceNum, scu_unixTime()
//	writetofile(prettyJSONfmt(buffer),filename,"config")
//end
//
//function fd_ResetFdacCalibration(instrID,channel)
//	variable instrID, channel
//	
//	string cmd="", response="", err=""
//	sprintf cmd, "DAC_RESET_CAL,%d\r", channel
//	response = queryInstr(instrID,cmd,read_term="\n")
//	response = sc_stripTermination(response,"\r\n")
//	if(scf_checkFDResponse(response,cmd,isString=1,expectedResponse="CALIBRATION_RESET"))
//		// all good
//	else
//		sprintf err, "[ERROR] \"fdacResetCalibration\": Reset of DAC channel %d failed! - Response from Fastdac was %s", channel, response
//		print err
//		abort
//	endif 
//end
//
//function/s fd_setFdacCalibrationOffset(instrID,channel,offset)
//	variable instrID, channel, offset
//	
//	string cmd="", response="", err="",result=""
//	sprintf cmd, "DAC_OFFSET_ADJ,%d,%.6f\r", channel, offset
//	response = queryInstr(instrID,cmd,read_term="\n")
//	result = sc_stripTermination(response,"\r\n")
//	
//	// response is formatted like this: "channel,offsetStepsize,offsetRegister"
//	response = readInstr(instrID,read_term="\n")
//	response = sc_stripTermination(response,"\r\n")
//	
//	if(scf_checkFDResponse(response,cmd,isString=1,expectedResponse="CALIBRATION_FINISHED"))
//		return result
//	else
//		sprintf err, "[ERROR] \"fdacResetCalibrationOffset\": Calibrating offset on DAC channel %d failed!", channel
//		print err
//		abort
//	endif
//end
//
//function/s fd_setFdacCalibrationGain(instrID,channel,offset)
//	variable instrID, channel, offset
//	
//	string cmd="", response="", err="",result=""
//	sprintf cmd, "DAC_GAIN_ADJ,%d,%.6f\r", channel, offset
//	response = queryInstr(instrID,cmd,read_term="\n")
//	result = sc_stripTermination(response,"\r\n")
//	
//	// response is formatted like this: "channel,offsetStepsize,offsetRegister"
//	response = readInstr(instrID,read_term="\n")
//	response = sc_stripTermination(response,"\r\n")
//	
//	if(scf_checkFDResponse(response,cmd,isString=1,expectedResponse="CALIBRATION_FINISHED"))
//		return result
//	else
//		sprintf err, "[ERROR] \"fdacResetCalibrationGain\": Calibrating gain of DAC channel %d failed!", channel
//		print err
//		abort
//	endif
//end
//
//function fd_updateFadcCalibration(instrID,channel,zeroScale,fullScale)
//	variable instrID,channel,zeroScale,fullScale
//	
//	string cmd="", response="", err=""
//	sprintf cmd, "WRITE_ADC_CAL,%d,%d,%d\r", channel, zeroScale, fullScale
//	response = queryInstr(instrID,cmd,read_term="\n")
//	response = sc_stripTermination(response,"\r\n")
//	
//	if(scf_checkFDResponse(response,cmd,isString=1,expectedResponse="CALIBRATION_CHANGED"))
//		// all good!
//	else
//		sprintf err, "[ERROR] \"fd_updateFadcCalibration\": Updating calibration of ADC channel %d failed!", channel
//		print err
//		abort
//	endif
//end
//
//
/////////////////////
////// Utilities ////
/////////////////////
//function fd_get_numpts_from_sweeprate(start, fin, sweeprate, measureFreq)
///// Convert sweeprate in mV/s to numptsx for fdacrecordvalues
//	variable start, fin, sweeprate, measureFreq
//	if (start == fin)
//		abort "ERROR[fd_get_numpts_from_sweeprate]: Start == Fin so can't calculate numpts"
//	endif
//	variable numpts = round(abs(fin-start)*measureFreq/sweeprate)   // distance * steps per second / sweeprate
//	return numpts
//end
//
//function fd_get_sweeprate_from_numpts(start, fin, numpts, measureFreq)
//	// Convert numpts into sweeprate in mV/s
//	variable start, fin, numpts, measureFreq
//	if (numpts == 0)
//		abort "ERROR[fd_get_numpts_from_sweeprate]: numpts = 0 so can't calculate sweeprate"
//	endif
//	variable sweeprate = round(abs(fin-start)*measureFreq/numpts)   // distance * steps per second / numpts
//	return sweeprate
//end
//
//function ClearFdacBuffer(instrID)
//	// Stops any sweeps which might be running and clears the buffer
//	variable instrID
//	
//	variable count=0, total = 0
//	string buffer=""
//	writeInstr(instrID,"STOP\r")
//	total = -5 //Stop command makes fastdac return a 5 character string
//	do 
//		viRead(instrID, buffer, 2000, count) 
//		total += count
//	while(count != 0)
//	printf "Cleared %d bytes of data from buffer\r", total
//end
//
//function fd_stopFDACsweep(instrID)  
//	// Stops sweep and clears buffer 
//	variable instrID
//	ClearfdacBuffer(instrID)
//end
//
//function fd_Char2Num(c1, c2)
//	// Conversion of bytes to float
//	//
//	// Given two strings of length 1
//	//  - c1 (higher order) and
//	//  - c2 lower order
//	// Calculate effective FastDac value
//	string c1, c2
//	variable minVal = -10000, maxVal = 10000
//
//	// Check params for violation
//	if(strlen(c1) != 1 || strlen(c2) != 1)
//		print "[ERROR] strlen violation -- strings passed to fastDacChar2Num must be length 1"
//		return 0
//	endif
//	variable b1, b2
//	// Calculate byte values
//	b1 = char2num(c1[0])
//	b2 = char2num(c2[0])
//	// Convert to unsigned
//	if (b1 < 0)
//		b1 += 256
//	endif
//	if (b2 < 0)
//		b2 += 256
//	endif
//	// Return calculated FastDac value
//	return (((b1*2^8 + b2)*(maxVal-minVal)/(2^16 - 1))+minVal)
//end
//
////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////// Spectrum Analyzer //////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////
//function FDSpectrumAnalyzer(scanlength,[numAverage, raw_graphs, calc_graphs, comments,nosave])
//	// NOTE: Make sure the Calc function is set up in Scancontroller_Fastdac such that the result is in nA (not A)
//	// scanlength is in sec
//	// raw_graphs: whether to show the raw ADC readings
//	// calc_graphs: Whether to show the readings after converting to nA (assuming Calc function is set up correctly)
//	variable scanlength, numAverage, raw_graphs, calc_graphs, nosave
//	string comments
//	
//	comments = selectString(paramisdefault(comments), comments, "")	
//	numAverage = paramisDefault(numAverage) ? 1 : numAverage
//	raw_graphs = paramisdefault(raw_graphs) ? 0 : raw_graphs
//	calc_graphs = paramisdefault(calc_graphs) ? 1 : calc_graphs	
//	
//	
//	// Turn off resampling during noise spectrum scan
//	nvar sc_resampleFreqCheckFadc
//	variable original_resample_state = sc_resampleFreqCheckFadc 
//	sc_resampleFreqCheckFadc = 0
//
//	// Initialize ScanVars
//	Struct ScanVars S
//	initScanVarsFD2(S, 0, scanlength, duration=scanlength, starty=1, finy=numAverage, numptsy=numAverage, x_label="Time /s", y_label="Current /nA", comments="spectrum,"+comments)
//	S.readVsTime = 1
//
//	// Check limits (not as much to check when using FastDAC slow)
//	scc_checkLimsFD(S)
//	S.lims_checked = 1
//	
//	// Ramp to start without checks because checked above
//	RampStartFD(S, ignore_lims=1)
//
//	// Let gates settle 
//	sc_sleep(S.delayy)
//
//	// Initialize graphs and waves
//	initializeScan(S, init_graphs=0)  // Going to open graphs below
//
//	// Initialize Spectrum waves
//	string wn, wn_lin, wn_int
//	string lin_freq_wavenames = ""
//	string int_freq_wavenames = ""	
//	variable numChannels = scf_getNumRecordedADCs()
//	string adc_channels = scf_getRecordedFADCinfo("channels")
//	variable i
//	for(i=0;i<numChannels;i+=1)
//		wn_lin = "spectrum_fftADClin"+stringfromlist(i,adc_channels, ";")
//		make/o/n=(S.numptsx/2) $wn_lin = nan
//		setscale/i x, 0, S.measureFreq/(2.0), $wn_lin
//		lin_freq_wavenames = addListItem(wn_lin, lin_freq_wavenames, ";", INF)
//		
//		wn_int = "spectrum_fftADCint"+stringfromlist(i,adc_channels, ";")
//		make/o/n=(S.numptsx/2) $wn_int = nan
//		setscale/i x, 0, S.measureFreq/(2.0), $wn_int
//		int_freq_wavenames = addListItem(wn_int, int_freq_wavenames, ";", INF)		
//	endfor
//
//	// Initialize all graphs
//	string all_graphIDs = ""
//	if (raw_graphs)
//		all_graphIDs += scg_initializeGraphsForWavenames(sci_get1DWaveNames(1,1), "Time /s", for_2d=0, y_label="ADC /mV")  // RAW ADC readings
//		if (S.is2d)
//			all_graphIDs += scg_initializeGraphsForWavenames(sci_get1DWaveNames(1,1), "Time /s", for_2d=1, y_label="Repeats")  // RAW ADC readings
//		endif
//	endif
//	if (calc_graphs)
//		all_graphIDs += scg_initializeGraphsForWavenames(sci_get1DWaveNames(0,1), "Time /s", for_2d=0, y_label="Current /nA")    // Calculated data (should be in nA)
//		if (S.is2d)
//			all_graphIDs += scg_initializeGraphsForWavenames(sci_get1DWaveNames(1,1), "Time /s", for_2d=1, y_label="Repeats")  // RAW ADC readings
//		endif
//	endif
//	
//	string graphIDs
//	graphIDs = scg_initializeGraphsForWavenames(lin_freq_wavenames, "Frequency /Hz", for_2d=0, y_label="nA^2/Hz")
//	string gid
//	for (i=0;i<itemsInList(graphIDs);i++)
//		gid = StringFromList(i, graphIDs)
//		modifyGraph/W=$gid log(left)=1
//	endfor
//	all_graphIDs = all_graphIDs+graphIDs
//	all_graphIDs += scg_initializeGraphsForWavenames(int_freq_wavenames, "Frequency /Hz", for_2d=0, y_label="nA^2")
//	scg_arrangeWindows(all_graphIDs)
//
//	// Record data
//	string wavenames = scf_getRecordedFADCinfo("calc_names")  // ";" separated list of recorded calculated waves
//	variable j
//	for (i=0; i<numAverage; i++)
//		scfd_RecordValues(S, i)		
//
//		for (j=0;j<itemsInList(wavenames);j++)
//			// Calculate spectrums from calc wave
//			wave w = $stringFromList(j, wavenames)
//			wave fftwlin = fd_calculate_spectrum(w, linear=1)  // Linear spectrum
//
//			// Add to averaged waves
//			wave fftwavelin = $stringFromList(j, lin_freq_wavenames)
//			if(i==0) // If first pass, initialize waves
//				fftwavelin = fftwlin
//			else  // Else add and average
//				fftwavelin = fftwavelin*i + fftwlin
//				fftwavelin = fftwavelin/(i+1)
//			endif
//			wave fftwaveint = $stringFromList(j, int_freq_wavenames)
//			integrate fftwavelin /D=fftwaveint
//			
//			
//			
//		endfor
//		doupdate
//	endfor
//
//	if (!nosave)
//		EndScan(S=S, additional_wavenames=lin_freq_wavenames+int_freq_wavenames) 		
//	endif
//
//	// Return resampling state to whatever it was before
//	sc_resampleFreqCheckFadc = original_resample_state
//end
//
//
//function/WAVE fd_calculate_spectrum(time_series, [scan_duration, linear])
//	// Takes time series data and returns power spectrum
//	wave time_series  // Time series (in correct units -- i.e. check that it's in nA first)
//	variable scan_duration // If passing a wave which does not have Time as x-axis, this will be used to rescale
//	variable linear // Whether to return with linear scale (or log scale)
//	
//	linear = paramisDefault(linear) ? 1 : linear
//
//	duplicate/free time_series tseries
//	if (scan_duration)
//		setscale/i x, 0, scan_duration, tseries
//	else
//		scan_duration = DimDelta(time_series, 0) * DimSize(time_series, 0)
//	endif
//
//	variable last_val = dimSize(time_series,0)-1
//	if (mod(dimsize(time_series, 0), 2) != 0)  // ODD number of points, must be EVEN to do powerspec
//		last_val = last_val - 1
//	endif
//		
//	
//	// Built in powerspectrum function
//
//	if (!linear)  // Use log scale
//		DSPPeriodogram/PARS/DBR=1/NODC=2/R=[0,(last_val)] tseries  
//		wave w_Periodogram
//		duplicate/free w_Periodogram, powerspec
//		powerspec = powerspec+10*log(scan_duration)  // This is so that the powerspec is independent of scan_duration
//	else  // Use linear scale
//		DSPPeriodogram/PARS/NODC=2/R=[0, (last_val)] tseries
//		wave w_Periodogram
//		duplicate/free w_Periodogram, powerspec
//		// TODO: I'm not sure this is correct, but I don't know what should be done to fix it -- TIM
//		powerspec = powerspec*scan_duration  // This is supposed to be so that the powerspec is independent of scan_duration
//	endif
////	powerspec[0] = NaN
//	return powerspec
//end
//
//function plotPowerSpectrum(w, [scan_duration, linear, powerspec_name])
//	wave w
//	variable scan_duration, linear
//	string powerspec_name // Wavename to save powerspectrum in (useful if you want to display more than one at a time)
//	
//	linear = paramisDefault(linear) ? 1 : linear
//	wave powerspec = fd_calculate_spectrum(w, scan_duration=scan_duration, linear=linear)
//	
//	if(!paramIsDefault(powerspec_name))
//		duplicate/o powerspec $powerspec_name
//		wave tempwave = $powerspec_name
//	else
//		duplicate/o powerspec tempwave
//	endif
//
//	string y_label = selectString(linear, "Spectrum [dBnA/sqrt(Hz)]", "Spectrum [nA/sqrt(Hz)]")
//	scg_initializeGraphsForWavenames(NameOfWave(tempwave), "Frequency /Hz", for_2d=0, y_label=y_label)
//	 doWindow/F $winName(0,1)
//end
//
////////////////////////////////////
/////// Load FastDACs from HDF /////
////////////////////////////////////
//
//function FDLoadFromHDF(datnum, [no_check])
//	// Function to load fastDAC values and labels from a previously save HDF file in sweeplogs in current data directory
//	// Requires Dac info to be saved in "DAC{label} : output" format
//	// with no_check = 0 (default) a window will be shown to user where values can be changed before committing to ramping, also can chose not to load from there
//	// setting no_check = 1 will ramp to loaded settings without user input
//	// Fastdac_num is which fastdacboard to load. 3/2020 - Not tested
//	variable datnum, no_check
//	variable response
//	
//	svar sc_fdackeys
//	variable numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",","))
//	if (numDevices !=1)
//		print "WARNING[FDLoadFromHDF]: Only tested to load 1 Fastdac, only first FastDAC will be loaded without code changes"
//	endif	
//	fd_get_fastdacs_from_hdf(datnum, fastdac_num=1) // Creates/Overwrites load_fdacvalstr
//	
//	if (no_check == 0)  //Whether to show ask user dialog or not
//		response = fd_LoadAskUser()
//	else
//		response = -1 
//	endif 
//	if(response == 1)
//		// Do_nothing
//		print "Keep current FastDAC state chosen, no changes made"
//	elseif(response == -1)
//		// Load from HDF
//		printf "Loading FastDAC values and labels from dat%d\r", datnum
//		wave/t load_fdacvalstr
//		duplicate/o/t load_fdacvalstr, fdacvalstr //Overwrite dacvalstr with loaded values
//
//		// Ramp to new values
//		scfw_update_all_fdac()
//	else
//		print "[WARNING] Bad user input -- FastDAC will remain in current state"
//	endif
//end
//
//
//function fd_get_fastdacs_from_hdf(datnum, [fastdac_num])
//	//Creates/Overwrites load_fdacvalstr by duplicating the current fdacvalstr then changing the labels and outputs of any values found in the metadata of HDF at dat[datnum].h5
//	//Leaves fdacvalstr unaltered	
//	variable datnum, fastdac_num
//	variable sl_id, fd_id  //JSON ids
//	
//	fastdac_num = paramisdefault(fastdac_num) ? 1 : fastdac_num 
//	
//	if(fastdac_num != 1)
//		abort "WARNING: This is untested... remove this abort if you're feeling lucky!"
//	endif
//	
//	sl_id = get_sweeplogs(datnum)  // Get Sweep_logs JSON
//	fd_id = getJSONXid(sl_id, "FastDAC "+num2istr(fastdac_num)) // Get FastDAC JSON from Sweeplogs
//
//	wave/t keys = JSON_getkeys(fd_id, "")
//	wave/t fdacvalstr
//	duplicate/o/t fdacvalstr, load_fdacvalstr
//	
//	variable i
//	string key, label_name, str_ch
//	variable ch = 0
//	for (i=0; i<numpnts(keys); i++)  // These are in a random order. Keys must be stored as "DAC#{label}:output" in JSON
//		key = keys[i]
//		if (strsearch(key, "DAC", 0) != -1)  // Check it is actually a DAC key and not something like com_port
//			SplitString/E="DAC(\d*){" key, str_ch //Gets DAC# so that I store values in correct places
//			ch = str2num(str_ch)
//			
//			load_fdacvalstr[ch][1] = num2str(JSON_getvariable(fd_id, key))
//			SplitString/E="{(.*)}" key, label_name  //Looks for label inside {} part of e.g. BD{label}
//			label_name = replaceString("~1", label_name, "/")  // Somehow igor reads '/' as '~1' don't know why...
//			load_fdacvalstr[ch][3] = label_name
//		endif
//	endfor
//	JSONXOP_Release /A  //Clear all stored JSON strings
//end
//
//function fd_LoadAskUser()
//	variable/g fd_load_answer
//	wave/t load_fdacvalstr
//	wave/t fdacvalstr
//	wave fdacattr
//	if (waveexists(load_fdacvalstr) && waveexists(fdacvalstr) && waveexists(fdacattr))	
//		execute("fd_LoadWindow()")
//		PauseForUser fd_LoadWindow
//		return fd_load_answer
//	else
//		abort "ERROR[bd_LoadAskUser]: either load_fdacvalstr, fdacvalstr, or fdacattr doesn't exist when it should!"
//	endif
//end
//
//function fd_LoadAskUserButton(action) : ButtonControl
//	string action
//	variable/g fd_load_answer
//	strswitch(action)
//		case "do_nothing":
//			fd_load_answer = 1
//			dowindow/k fd_LoadWindow
//			break
//		case "load_from_hdf":
//			fd_load_answer = -1
//			dowindow/k fd_LoadWindow
//			break
//	endswitch
//end
//
//
//Window fd_LoadWindow() : Panel
//	PauseUpdate; Silent 1 // building window
//	NewPanel /W=(0,0,740,390) // window size
//	ModifyPanel frameStyle=2
//	SetDrawLayer UserBack
//	
//	variable tcoord = 80
//	
//	SetDrawEnv fsize= 25,fstyle= 1
//	DrawText 90, 35,"FastDAC Load From HDF" // Headline
//	
//	SetDrawEnv fsize= 20,fstyle= 1
//	DrawText 70, 65,"Current Setup" 
//	
//	SetDrawEnv fsize=14, fstyle=1
//	DrawText 15, tcoord, "Ch"
//	SetDrawEnv fsize=14, fstyle=1
//	DrawText 50, tcoord, "Output"
//	SetDrawEnv fsize=14, fstyle=1
//	DrawText 120, tcoord, "Limit"
//	SetDrawEnv fsize=14, fstyle=1
//	DrawText 220, tcoord, "Label"
//	SetDrawEnv fsize=14, fstyle=1
//	DrawText 287, tcoord, "Ramprate"
//	ListBox fdaclist,pos={10,tcoord+5},size={360,270},fsize=14,frame=2,widths={30,70,100,65}
//	ListBox fdaclist,listwave=root:fdacvalstr,selwave=root:fdacattr,mode=1
//	
//	variable x_offset = 360
//	SetDrawEnv fsize= 20,fstyle= 1
//	DrawText 70+x_offset, 65,"Load from HDF Setup" 
//
//	SetDrawEnv fsize=14, fstyle=1
//	DrawText 15+x_offset, tcoord, "Ch"
//	SetDrawEnv fsize=14, fstyle=1
//	DrawText 50+x_offset, tcoord, "Output"
//	SetDrawEnv fsize=14, fstyle=1
//	DrawText 120+x_offset, tcoord, "Limit"
//	SetDrawEnv fsize=14, fstyle=1
//	DrawText 220+x_offset, tcoord, "Label"
//	SetDrawEnv fsize=14, fstyle=1
//	DrawText 287+x_offset, tcoord, "Ramprate"
//	ListBox load_fdaclist,pos={10+x_offset,tcoord+5},size={360,270},fsize=14,frame=2,widths={30,70,100,65}
//	ListBox load_fdaclist,listwave=root:load_fdacvalstr,selwave=root:fdacattr,mode=1
//	
//
//
//	Button do_nothing,pos={80,tcoord+280},size={120,20},proc=fd_LoadAskUserButton,title="Keep Current Setup"
//	Button load_from_hdf,pos={80+x_offset,tcoord+280},size={100,20},proc=fd_LoadAskUserButton,title="Load From HDF"
//EndMacro
//
//
//////////////////////////////////////////////////////
////////////// Arbitrary Wave Generator //////////////
//////////////////////////////////////////////////////
//
//
//function setFdacAWGSquareWave(instrID, amps, times, wave_num, [verbose])
//	// Wrapper around fd_addAWGwave to make waves with 'amps' and their durations indicated with 'times'
//	// inputs: instrID - FastDac ID variable
//	//         amps - wave with the setpoints in mV
//	//			 times - wave with all the durations (seconds) for the setpoints.
//	//         note* amps and times should be the same length
//	//         wave_num - used to name the wave holding the information about the squarewave, printed at the end of the function
//	   
//	variable instrID
//	wave amps, times
//	int wave_num, verbose
//	struct AWGVars S
//	fd_getGlobalAWG(S) 
//	S.numADCs = scf_getnumRecordedADCs() // dont think I would need this anymore
//	S.maxADCs = scf_getMaxRecordedADCs()
//	fd_setGlobalAWG(S)
//	
//	verbose = paramIsDefault(verbose) ? 1 : verbose
//	// checking if amps and times are the same length
//	if (numpnts(amps) != numpnts(times))
//		abort nameofwave(amps) + " and " + nameofwave(times) +" are not the same size"  
//	endif
//
//	
//	make/o/free/n=(numpnts(amps), 2) awg_sqw          //awg_sqw will hold the information about the squarewave
//	variable samplingFreq = getFADCspeed(instrID)     //sampling frequency is needed to properly implement time
//	variable numSamples = 0, i=0, j=0
//   for(i=0;i<numpnts(amps);i++)                            
//   		numSamples = round(times[i]*samplingFreq/S.maxADCs)   // Convert to # samples
//         
//      	if(numSamples == 0)                         // Prevent adding zero length setpoint
//       	abort "ERROR[setFdacAWGSquareWave]: trying to add setpoint with zero length, duration too short for sampleFreq"
//      	endif
//         
//       awg_sqw[j][0] = {amps[i]}
//       awg_sqw[j][1] = {numSamples}
//       j++
//        
//   endfor
//  
//	// aborts if awg_sqw has no information
//	if(numpnts(awg_sqw) == 0)
//      abort "ERROR[setFdacAWGSquareWave]: No setpoints added to awg_sqw"
//   endif
//   
//   fd_clearAWGwave(instrID, wave_num)                // clears any old existing wave named "fDAW_" + wave_num
//   fd_addAWGwave(instrID, wave_num, awg_sqw)         // creats wave named "fDAW_" + wave_num
//   	
//   	if(verbose)
//   		printf "Set square wave on fdAW_%d\r", wave_num
//   	endif
//   	
//end
//
//
//function setupAWG([channels_AW0, channels_AW1, numCycles, verbose])
//	// Function which initializes AWGVars s.t. selected DACs will use selected AWs when called in fd_Record_Values
//	// Required because fd_Record_Values needs to know the total number of samples it will get back, which is calculated from values in AWG_list
//	// IGOR AWs must be set in a separate function (which should reset AWG_List.initialized to 0)
//	// Sets AWG_list.initialized to 1 to allow fd_Record_Values to run
//	// If either parameter is not provided it will assume using previous settings
//	string channels_AW0, channels_AW1  // CSV for AWs to select which AWs (0,1) to use. // CSV sets for DACS e.g. "02, 1" for DACs 0, 2 to output AW0, and DAC 1 to output AW1
//	variable numCycles // How many full waves to execute for each ramp step
//	variable verbose  // Whether to print setup of AWG
//	
//	
//	//might be useful to take an instrID as a string rather than a variable
//	
//	struct AWGVars S
//	fd_getGlobalAWG(S)
//	channels_AW0 = selectString(paramisdefault(channels_AW0), channels_AW0, "")
//	channels_AW1 = selectString(paramisdefault(channels_AW1), channels_AW1, "")
//	string channels
//	string channels_AW0_check = scu_getChannelNumbers(channels_AW0, fastdac=1)
//	string channels_AW1_check = scu_getChannelNumbers(channels_AW1, fastdac=1)
//	
//	if(!cmpstr(channels_AW0_check, "") && !cmpstr(channels_AW1_check,""))
//		abort "atleast channels for AW0 should be specified"
//	elseif(!cmpstr(channels_AW0_check, "") && cmpstr(channels_AW1_check, ""))
//		abort "cant have channels just for AW1, if only using one, please use AW0"
//		
//	elseif(cmpstr(channels_AW0_check, "") && !cmpstr(channels_AW1_check, ""))
//		S.AW_Waves = "0"
//		S.channels_AW0 = channels_AW0_check
//		S.channels_AW1 = ""
//		S.numWaves = 1
//	else
//		S.AW_Waves = "0,1"
//		S.channels_AW1 = channels_AW1_check
//		S.channels_AW0 = channels_AW0_check
//		S.numWaves = 2
//	endif
//	
//	S.channels_AW1 = ReplaceString(";", S.channels_AW1, ",")
//	S.channels_AW0= ReplaceString(";", S.channels_AW0, ",")
//	
//	int i
//	for(i=0; i<itemsinlist(S.channels_AW1, ","); i++)
//	   	if(whichlistItem(stringfromlist(i, S.channels_AW1, ","), S.channels_AW0, ",") != -1)
//	   		abort "Please remove any channels existing in both AW0 and AW1, and setup AWG again"
//	   	endif
//	endfor
//	//S.AW_DACs = selectstring(paramisdefault(channels), channels, S.AW_Dacs) //im not using this // Formatted 01,23  == wave 0 on channels 0 and 1, wave 1 on channels 2 and 3
//	S.numCycles = paramisDefault(numCycles) ? S.numCycles : numCycles
//	
//	// For checking things don't change before scanning
//	if (S.maxADCs != scf_getMaxRecordedADCs())
//		abort "The number of ADCs being recorded changed, please set up the squarewaves again"
//	endif
//	
//	S.numADCs = scf_getNumRecordedADCs()  // Store number of ADCs selected in window so can check if this changes // shouldnt matter anymore
//	S.maxADCs = scf_getMaxRecordedADCs()  // Store number of ADCs selected in window so can check if this changes
//	S.channelIDs = scc_getDeviceIDs(channels = S.channels_AW0 +","+ S.channels_AW1)
//	wave /t IDs = listToTextWave(S.channelIDs, ";")
//	findDuplicates /z /free /rt = syncIDs IDs
//	if(!wavetype(syncIDs))
//		S.instrIDs = textWavetolist(IDs)
//	else
//		S.instrIDs = textWavetolist(syncIDs)
//	endif
//	
//	scv_setFreq2(A=S)
//	
//	variable waveLen = 0
//	string wn
//	variable min_samples = INF  // Minimum number of samples at a setpoint
//	for(i=0;i<S.numWaves;i++)
//		// Get IGOR AW
//		wn = fd_getAWGwave(str2num(stringfromlist(i, S.AW_waves, ",")))
//		wave w = $wn
//		// Check AW has correct form and meets criteria. Checks length of wave = waveLen (or sets waveLen if == 0)
//		fd_checkAW(w,len=waveLen)
//		
//		// Get length of shortest setpoint in samples
//		duplicate/o/free/r=[][1] w samples
//		wavestats/q samples
//		if(V_min < min_samples)
//			min_samples = V_min
//		endif
//	endfor
//	S.waveLen = waveLen
//	// Note: numSteps must be set in Scan... (i.e. based on numptsx or sweeprate)
//	
//	// Set initialized
//	S.initialized = 1
//	
//	// Store as global to be access in fd_Record_Values
//	fd_setGlobalAWG(S)
//	
//	// Print with current settings (changing settings will affect square wave!)
//	variable j = 0
//	string buffer = ""
//	string dacs4wave, dac_list, aw_num
//	for(i=0;i<2;i++)
//		aw_num = num2str(i)
//		if((i == 0 && !cmpstr(channels_AW0, "")) || (i == 1 && !cmpstr(channels_AW1, "")))
//			continue
//		endif
//		dacs4wave = selectstring(i, channels_AW0, channels_AW1)
//		sprintf buffer "%s\tAW%s on channel(s) %s\r", buffer, aw_num, dacs4wave
//	endfor 
//
//	variable awFreq = 1/(s.waveLen/S.measureFreq)
//	variable duration_per_step = s.waveLen/S.measureFreq*S.numCycles
//	if (verbose)
//		printf "\r\rAWG set with:\r\tAWFreq = %.2fHz\r\tMin Samples for step = %d\r\tCycles per step = %d\r\tDuration per step = %.3fs\r\tnumADCs = %d\r\tSamplingFreq = %.1f/s\r\tMeasureFreq = %.1f/s\rOutputs are:\r%s\r",\
//  									awFreq,											min_samples,			S.numCycles,						duration_per_step,		S.numADCs, 		S.samplingFreq,					S.measureFreq,						buffer											
//	endif
//   
//end
//
//function fd_setAWGuninitialized()
//	// sets global AWG_list.initialized to 0 so that it will fail pre scan checks. (to be used when changing things like sample rate, AWs etc)
//	
//	// Get current AWG_list
//	struct AWGVars S
//	fd_getGlobalAWG(S)
//	
//	// Set initialized to zero to prevent fd_Record_values from running without AWG_list being set up again first
//	S.initialized = 0
//
//	// Store changes
//	fd_setGlobalAWG(S)
//end
//
//
//function fd_checkAW(w, [len])
//	// Internal function - not to be used directly by user
//	// Checks wave w meets criteria for AW, and if len provided will check w has same length or will set len if == 0
//	wave w
//	variable &len  // length in samples (all AWs must have the same sample length)
//	
//	// Check 2D (i.e. setpoints, samples)
//	if(dimsize(w, 1) != 2)
//		abort "AWs are required to be 2D wave. 1st row = setpoints, 2nd row = numSamples for corresponding setpoint"
//	endif
//	
//	// Check all sampleLens are integers
//	duplicate/o/free/r=[][1] w samples	
//	variable i = 0
//	for(i=0;i<numpnts(samples);i++)
//		if(samples[i] != trunc(samples[i])) // IGORs bs way of checking if integer
//			abort "ERROR[fd_checkAW]: Received a non-integer number of samples for setpoint " + num2str(i)
//		endif
//	endfor
//	
//	// Check length of AWs is equal (if passed in len to compare to)
//	if(!paramisdefault(len)) // Check length of wave matches len, or set len if len == 0
//		if (len == 0)
//			len = sum(samples)
//			if(len == 0)
//				abort "ERROR[fd_checkAW]: AW has zero length!"
//			endif
//		else
//			if(sum(samples) != len)
//				abort "ERROR[fd_checkAW]: Length of AW does not match len which is " + num2str(len)
//			endif
//		endif
//	endif
//end
//
//
//function fd_addAWGwave(instrID, wave_num, add_wave)
//	// Internal function - not to be used directly by user
//	// See	"setFdacAWGSquareWave()" as an example of how to use this
//	// Very basic command which adds to the AWGs stored in the fastdac
//	variable instrID
//	variable wave_num  	// Which AWG to add to (currently allowed 0 or 1)
//	wave add_wave		// add_wave should be 2D with add_wave[0] = mV setpoint for each step in wave
//					   		// 									 add_wave[1] = how many samples to stay at each setpoint
//
//
//
//                        // ADD_WAVE,<wave number (for now just 0 or 1)>,<Setpoint 0 in mV>,<Number of samples at setpoint 0>,….<Setpoint n in mV>,<Number of samples at Setpoint n>
//                        //
//                        // Response:
//                        //
//                        // WAVE,<wavenumber>,<total number of setpoints accumulated in waveform>
//                        //
//                        // Example:
//                        //
//                        // ADD_WAVE,0,300.1,50,-300.1,200
//                        //
//                        // Response:
//                        //
//                        // WAVE,0,2
//
//	variable i=0
//
//   waveStats/q add_wave
//   if (dimsize(add_wave, 1) != 2 || V_numNans !=0 || V_numINFs != 0) 
//      abort "ERROR[fd_addAWGwave]: must be 2D (setpoints, samples) and contain no NaNs or INFs"
//   endif
//   if (wave_num != 0 && wave_num != 1)  // Check adding to AWG 0 or 1
//      abort "ERROR[fd_addAWGwave]: Only supports AWG wave 0 or 1"
//   endif
//
//	// Check all sample lengths are integers
// 	duplicate/o/free/r=[][1] add_wave samples
//	for(i=0;i<numpnts(samples);i++)
//		if(samples[i] != trunc(samples[i])) // IGORs bs way of checking if integer
//			abort "ERROR[fd_addAWGwave]: Received a non-integer number of samples for setpoint " + num2str(i)
//		endif
//	endfor
//
//	// Compile wave part of command
//   string buffer = ""
//   for(i=0;i<dimsize(add_wave, 0);i++)
//		buffer = addlistitem(num2str(add_wave[i][0]), buffer, ",", INF)
//		buffer = addlistitem(num2str(add_wave[i][1]), buffer, ",", INF)
//   endfor
//   buffer = buffer[0,strlen(buffer)-2]  // chop off last ","
//
//	// Make full command in form "ADD_WAVE,<wave_num>,<sp0>,<#sp0>,...,<spn>,<#spn>"
//   string cmd = ""
//   sprintf cmd "ADD_WAVE,%d,%s", wave_num, buffer
//   
//	// Check within FD input buffer length
//   if (strlen(cmd) > 256)
//      sprintf buffer "ERROR[fd_addAWGwave]: command length is %d, which exceeds fDAC buffer size of 256. Add to AWG in smaller chunks", strlen(cmd)
//      abort buffer
//   endif
//
//	// Send command
//	string response
//	response = queryInstr(instrID, cmd+"\r", read_term="\n")
//	response = sc_stripTermination(response, "\r\n")
//
//	// Check response and add to IGOR fdAW_<wave_num> if successful
//	string wn = fd_getAWGwave(wave_num)
//	wave AWG_wave = $wn
//	variable awg_len = dimsize(AWG_wave,0)
//	string expected_response
//	sprintf expected_response "WAVE,%d,%d", wave_num, awg_len+dimsize(add_wave,0)
//	if(scf_checkFDResponse(response, cmd, isString=1, expectedResponse=expected_response))
//		concatenate/o/Free/NP=0 {AWG_wave, add_wave}, tempwave
//		redimension/n=(awg_len+dimsize(add_wave,0), -1) AWG_wave 
//		AWG_wave[awg_len,][] = tempwave[p][q]
//	else
//		abort "ERROR[fd_addAWGwave]: Failed to add add_wave to AWG_wave"+ num2str(wave_num)
//	endif
//end
//
//
//function/s fd_getAWGwave(wave_num)
//   // Returns name of AW wave (and creates the wave first if necessary)
//   variable wave_num
//   if (wave_num != 0 && wave_num != 1)  // Check adding to AWG 0 or 1
//      abort "ERROR[fd_getAWGwave]: Only supports AWG wave 0 or 1"
//   endif
//
//   string wn = ""
//   sprintf wn, "fdAW_%d", wave_num
//  //wave AWG_wave = $wn
//   if(!waveExists($wn))
//      make/o/n=(0,2) $wn
//   endif
//   return wn
//end
//
//function fd_clearAWGwave(instrID, wave_num)
//	// Clears AWG# from the fastdac and the corresponding global wave in IGOR
//	variable instrID
//	variable wave_num // Which AWG to clear (currently allowed 0 or 1)
//
//   // CLR_WAVE,<wave number>
//   //
//   // Response:
//   //
//   // WAVE,<wave number>,0
//   //
//   // Example:
//   //
//   // CLR_WAVE,1
//   //
//   // Response:
//   //
//   // WAVE,1,0
//
//	string cmd
//	sprintf cmd, "CLR_WAVE,%d", wave_num
//
//	//send command
//	string response
//   response = queryInstr(instrID, cmd+"\r", read_term="\n")
//   response = sc_stripTermination(response, "\r\n")
//
//   string expected_response
//   sprintf expected_response "WAVE,%d,0", wave_num
//   if(scf_checkFDResponse(response, cmd, isstring=1,expectedResponse=expected_response))
//		string wn = fd_getAWGwave(wave_num)
//		wave AWG_wave = $wn
//		killwaves AWG_wave 
//   else
//      abort "ERROR[fd_clearAWGwave]: Error while clearing AWG_wave"+num2str(wave_num)
//   endif
//end
//
//
//////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////// FastDAC Sweeps /////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//
//
//
//function/s fd_start_sweep(S, [AWG_list])
//// Starts one of:
//// regular sweep (INT_RAMP in arduino) 
//// sweep with arbitrary wave generator on (AWG_RAMP in arduino)
//// readvstime sweep (SPEC_ANA in arduino)
//// updated for multiple fastdacs:
//
//// before reading the code below, it is important to understand the strategy for syncing all the fastDACs. The sync
//// happens by sending the same command to all fastDACs. First sending it to devices set to slaves first and master
//// last. To ensure syncing is done correctly, the number of adcs selected to record must be equal across all fastDACs.
//// to ensure user flexibility, we do some "fakerecording" as well as "fakeramping" if neccesary.
////
//// Fakerecording:
//// for example, if we use fastDAC1 to record 2 channels, and fastDAC2 to record 1 channel. The code below will find an
//// extra channel to select for recording and list the fastDAC ID and channel number in S.fakeRecords. This will be later
//// used to ensure the random channel selected to record is not distributed into any waves in Igor.
//// 
//// Fakeramping:
//// A fake ramp might be needed if an adc is selected for a device where a channel for ramping is not. For example if you
//// ramp a channel(dac) in fastDAC1 and record a channel(adc) in FastDAC2, we will need to select a channel(dac) to ramp to satisfy
//// the command sent. the channel(dac) selected to ramp will be held at its value for the duration of the ramp, thus "fakeramped".
//// A bonus from this example is that, it would require a fake recording as well in fastDAC1.
//// 
//// to sync for AWG_RAMP, we also need to consider dac channels that are selected for awg. A "fakeramp" or similiarly "fakeAWG" 
//// might be required as well. The dac channels are checked along with the AW_dacs to ensure no two channels are used twice. 
//	
//	Struct ScanVars &S
//	Struct AWGVars &AWG_List
//	int i
//
//	// this is a seperator check for the adclist selected to record in the fastdac Window
//	// might not be neccesary
//	scu_assertSeparatorType(S.ADCList, ";")
//	
//	
//	if(S.sync)
//		// here we check if master/slave has been initiated
//		// and we send commands to the first ID in S.instrIDs (Because this ID is set to Master)
//		// this will not be passed if only using one fastdac. S.sync is set in set_master_slave(S) 
//		nvar fdID = $(stringfromlist(0,S.instrIDs))
//		
//		// we send a command to master to arm sync and we check if we get the expected response
//		string response = queryInstr(fdID, "ARM_SYNC\r\n")
//		if(cmpstr(response,"SYNC_ARMED\r\n"))
//			abort "[fd_start_sweep()]: Unable to arm sync :("
//		endif
//		
//		// we send a command to master to check sync and we check if we get the expected response
//		response = queryInstr(fdID, "CHECK_SYNC\r\n")
//		if(cmpstr(response,"CLOCK_SYNC_READY\r\n"))
//			abort "[fd_start_sweep()]: clock sync bad :("
//		endif
//	endif	
//	
//	string fdIDname; S.adcLists = ""; S.fakeRecords = ""
//	
//	// here we loop through all the fastdacs that are used for the scan and send commands
//	for(i=0;i<itemsinlist(S.instrIDs);i++)
//		
//		
//		// the master needs to get the command last, so first we go through all fdacs that are 
//		// slaves first. The first item in S.instrIDs is always set to master. We do this through
//		// the if-statement below. We first retrieve the IDname. 
//		 
//		if(i != itemsinlist(S.instrIDs) - 1)
//			fdIDname = stringfromlist(i+1,S.instrIDs)
//		else
//			fdIDname = stringfromlist(0,S.instrIDs)
//		endif
//		
//		nvar fdID = $fdIDname    // we point fdID to the global variable associated with fdIDname
//		
//		// the below function takes all the adcs selected to record in the fastdac Window and returns
//		// only the adcs associated with the fdID
//		string adcs = scu_getDeviceChannels(fdID, S.adclist, adc_flag=1) 
//		if (cmpstr(adcs, "") == 0) // If adcs is an empty string
//			string err
//			sprintf err, "ERROR[fd_start_sweep]: ADClist = %s, Not on FD %s.\r\nRemeber, ADCs are indexed e.g. 0 - 11 for 3 fastdacs", S.adclist, fdIDname
//			abort err
//		endif
//		string cmd = ""
//	
//		if (S.readVsTime) // this is passed at either the end of the scan (EndScan()) or it is passed
//			// when update ADC is pressed on the fastDac window. The point here is an ADC channel is 
//			// read for a small number of points to minimize noise and get a good average
//			adcs = replacestring(";",adcs,"")
//			S.adcLists = replacestringbykey(fdIDname, S.adcLists, adcs)
//			sprintf cmd, "SPEC_ANA,%s,%s\r", adcs, num2istr(S.numptsx)
//		else
//			scu_assertSeparatorType(S.channelsx, ",")
//			string starts, fins, temp
//			
//			// here we decide which direction the sweeps are happening in, This is for sweeps
//			// to happen at alternating directions. Standard scans have S.direction = 1
//			if(S.direction == 1)
//				starts = stringByKey(fdIDname, S.IDstartxs)
//				fins = stringByKey(fdIDname, S.IDfinxs)
//			elseif(S.direction == -1)
//				starts = stringByKey(fdIDname, S.IDfinxs)
//				fins = stringByKey(fdIDname, S.startxs)
//			else
//				abort "ERROR[fd_start_sweep]: S.direction must be 1 or -1, not " + num2str(S.direction)
//			endif
//			
//			starts = starts[1,INF] //removing the comma at the start
//			fins = fins [1, INF]   //removing the comma at the start
//
//			
//			// the below function takes all the dacs to be ramped (passed as a parameter in any scan function)
//			// and returns only the dacs associated with the fdID
//			string dacs = scu_getDeviceChannels(fdID, S.channelsx)
//	   		dacs = replacestring(",",dacs,"")
//		 	
//		 	
//			// checking the need for a fakeramp, the voltage is held at the current value.
//			int fakeChRamp = 0; string AW_dacs; int j
//			if(!cmpstr(dacs,""))
//			
//				// find global value of channel 0 in that ID, set it to start and fin, and dac = 0
//				if(!paramisDefault(AWG_list) && AWG_List.use_AWG == 1 && AWG_List.lims_checked == 1)
//					AW_dacs = scu_getDeviceChannels(fdID, AWG_list.channels_AW0)
//					AW_dacs = addlistitem(scu_getDeviceChannels(fdID, AWG_list.channels_AW1), AW_dacs, ",", INF)
//					AW_dacs = removeSeperator(AW_dacs, ",")
//					for(j=0 ; j<8 ; j++)
//						if(whichlistItem(num2str(j),AW_dacs, ",") == -1)
//							fakeChRamp = j
//							break
//						endif
//					endfor
//				endif
//				string value = num2str(getfdacOutput(fdID,fakeChRamp, same_as_window = 0))
//				starts = value 
//				fins = value 
//				dacs = num2str(fakeChRamp)
//			endif
//	
//			//checking the need for fake recordings
//			if(itemsInList(adcs) != S.maxADCs)				
//				j = 0
//				do	
//					if(whichlistItem(num2str(j),adcs) == -1)
//						adcs = addListItem(num2str(j), adcs,";", INF)
//						S.fakeRecords = replaceStringByKey(fdIDname, S.fakeRecords, stringbykey(fdIDname, S.fakeRecords) + num2str(j))
//
//					endif
//					j++
//				while (itemsInList(adcs) != S.maxADCs)			
//			endif
//		
//			adcs = replacestring(";",adcs,"")
//			S.adcLists = replacestringbykey(fdIDname, S.adcLists, adcs)
//			
//			///// WARNING THIS SETUP OF AWG MAY NOT WORK IN ALL CASES I JUTS WANTED TO GET A SCAN GOING ////./
//			// this is all for AWG //////////////////////////////////////////////////////////////////////////////////////////////////////////
//			if(!paramisDefault(AWG_list) && AWG_List.use_AWG == 1 && AWG_List.lims_checked == 1 && ((stringmatch(fdIDname, stringFromList(0,  AWG_list.channelIDs)) == 1) || (stringmatch(fdIDname, stringFromList(1,  AWG_list.channelIDs)) == 1)))
//				int numWaves  // this numwaves must be one or two. If two, the command to the fastDAC assumes both AW0 and AW1 are being used.
//				
//				// we first figure out all the AW dacs corresponding to the current fdID
//				if (stringmatch(fdIDname, stringFromList(0,  AWG_list.channelIDs)) == 1)
//					string AW0_dacs = replacestring(",",scu_getDeviceChannels(fdID, AWG_list.channels_AW0), "")
//				endif
//				if (stringmatch(fdIDname, stringFromList(1,  AWG_list.channelIDs)) == 1)
//					string AW1_dacs = replacestring(",",scu_getDeviceChannels(fdID, AWG_list.channels_AW1), "")
//				endif
//				// we need to run through some tests to see which one of AW0, AW1 is populated
//				// if both are unpopulated and we are using AWG then a fake squarewave will be implemented on a channel
//				
//				// if only AW1 is populated, it is remapped to AW0 because the command AWG_RAMP only knows how many waves to use. So if we say
//				// numWaves = 1, it will always assume AW0
//				if (numtype(strlen(AW1_dacs)) == 2)
//					AW1_dacs = ""
//				endif
//				if(!cmpstr(AW0_dacs,"") && !cmpstr(AW1_dacs,""))
//					for(j=0 ; j<8 ; j++)
//						if(strsearch(num2str(j),dacs,0) == -1)
//							value = num2str(getfdacOutput(fdID,j, same_as_window = 0))
//							AW_dacs = num2str(j)
//							//setup squarewave to have this output
//							setupfakesquarewave(fdID, str2num(value))
//							break
//						endif
//					endfor
//					AWG_list.numWaves  = 1
//				elseif(cmpstr(AW1_dacs,"") && !cmpstr(AW0_dacs,""))  //AW1 is populated, AW0 is not
//					AW_dacs = AW1_dacs
//					scw_setupAWG("setupAWG", instrID = fdID, mapOnetoZero = 1)
//					AWG_list.numWaves  = 1
//				elseif(cmpstr(AW0_dacs,"") && !cmpstr(AW1_dacs,"")) //AW0 is populated, AW1 is not
//					AW_dacs = AW0_dacs
//					AWG_list.numWaves  = 1
//				else															
//					AW_dacs = AW0_dacs + "," + AW1_dacs
//					AWG_list.numWaves  = 2
//				endif
//
//				sprintf cmd, "AWG_RAMP,%d,%s,%s,%s,%s,%s,%d,%d\r", AWG_list.numWaves, AW_dacs, dacs, adcs, starts, fins, AWG_list.numCycles, AWG_list.numSteps
//			else			
//				sprintf cmd, "INT_RAMP,%s,%s,%s,%s,%d\r", dacs, adcs, starts, fins, S.numptsx
//			endif
//		endif
//	
//		writeInstr(fdID,cmd)
//	endfor
//	return cmd
//end
//
//function fd_readChunk(adc_channels, numpts, fdIDname)
//	// Reads numpnts data without ramping anywhere, does not update graphs or anything, just returns full waves in 
//	// waves named fd_readChunk_# where # is 0, 1 etc for ADC0, 1 etc
//	variable numpts
//	string adc_channels
//	string fdIDname
//	adc_channels = replaceString(",", adc_channels, ";")  // Going to list with this separator later anyway
//	adc_channels = replaceString(" ", adc_channels, "")  // Remove blank spaces
//	variable i
//	string wn, ch
//	string wavenames = ""
//	for(i=0; i<itemsInList(adc_channels); i++)
//		ch = stringFromList(i, adc_channels)
//		wn = "fd_readChunk_"+ch // Use this to not clash with possibly initialized raw waves
//		make/o/n=(numpts) $wn = NaN
//		wavenames = addListItem(wn, wavenames, ";", INF)
//	endfor
//	
//	// Create a temporary minimal struct for doing a basic readvstime scan
//	Struct ScanVars S
//	S.numptsx = numpts
//	S.instrIDx = -1                 // Specifying fdIDs in S.instrIDs instead
//	S.readVsTime = 1  					// No ramping
//	S.adcList = adc_channels  		// Recording specified channels, not ticked boxes in ScanController_Fastdac
//	S.numADCs = itemsInList(S.adcList) // gives me an error if i leave this out
//	S.maxADCs = itemsInList(S.adcList) 
//	nvar instrID = $fdIDname
//	S.samplingFreq = getFADCspeed(instrID)
//	S.raw_wave_names = wavenames  	// Override the waves the rawdata gets saved to
//	S.never_save = 1
//	S.instrIDs = fdIDname
//	
//	scfd_RecordValues(S, 0, skip_data_distribution=1, skip_raw2calc=1)
//end
//
//
//
////////////////////////////////////////
/////////////// Structs ////////////////
////////////////////////////////////////
//
//Structure AWGVars
//	// strings/waves/etc //
//	// Convenience
//	string AW_Waves		// Which AWs to use e.g. "2" for AW_2 only, "1,2" for fdAW_1 and fdAW_2. (only supports 1 and 2 so far)
//	
//	// Used in AWG_RAMP
//	string AW_dacs		// Dacs to use for waves
//							// Note: AW_dacs is formatted (dacs_for_wave0, dacs_for_wave1, .... e.g. '01,23' for Dacs 0,1 to output wave0, Dacs 2,3 to output wave1)
//
//	// Variables //
//	// Convenience	
//	variable initialized	// Must set to 1 in order for this to be used in fd_Record_Values (this is per setup change basis)
//	variable use_AWG 		// Is AWG going to be on during the scan
//	variable lims_checked 	// Have limits been checked before scanning
//	variable waveLen			// in samples (i.e. sum of samples at each setpoint for a single wave cycle)
//	
//	// Checking things don't change
//	variable numADCs  	// num ADCs selected to measure when setting up AWG
//	variable samplingFreq // SampleFreq when setting up AWG
//	variable measureFreq // MeasureFreq when setting up AWG
//
//	// Used in AWG_Ramp
//	variable numWaves	// Number of AWs being used
//	variable numCycles 	// # wave cycles per DAC step for a full 1D scan
//	variable numSteps  	// # DAC steps for a full 1D scan
//	
//	//for master/slave use
//	string AW_dacs2    //stringkey with fdIDs
//	variable maxADCs   //max amount of ADCs
//	string channels_AW0
//	string channels_AW1			
//	string channelIDs
//	string InstrIDs     
//	 
//	
//	
//endstructure
//
//
//function fd_initGlobalAWG()
//	Struct AWGVars S
//	// Set empty strings instead of null
//	S.AW_waves   = ""
//	S.AW_dacs    = ""
//	S.AW_dacs2   = ""
//	S.channels_AW0   = ""
//	S.channels_AW1   = ""
//	S.channelIDs = ""
//	S.InstrIDs   = "" 
//	
//	fd_setGlobalAWG(S)
//	make/o/s/n=(2, 2) fdaw_0
//end
//
//
//function fd_setGlobalAWG(S)
//	// Function to store values from AWG_list to global variables/strings/waves
//	// StructPut ONLY stores VARIABLES so have to store other parts separately
//	struct AWGVars &S
//
//	// Store String parts  
//	make/o/t fd_AWGglobalStrings = {S.AW_Waves, S.AW_dacs, S.AW_dacs2, S.channels_AW0, S.channels_AW1, S.channelIDs, S.InstrIDs}
//
//	// Store variable parts
//	make/o fd_AWGglobalVars = {S.initialized, S.use_AWG, S.lims_checked, S.waveLen, S.numADCs, S.samplingFreq,\
//		S.measureFreq, S.numWaves, S.numCycles, S.numSteps, S.maxADCs}
//end
//
//
//function SetAWG(A, state)
//	// Set use_awg state to 1 or 0
//	struct AWGVars &A
//	variable state
//	
//	if (state != 0 && state != 1)
//		abort "ERROR[SetAWGuseState]: value must be 0 or 1"
//	endif
//	if (A.initialized == 0 || numtype(strlen(A.AW_Waves)) != 0 || numtype(strlen(A.AW_dacs)) != 0)
//		fd_getGlobalAWG(A)
//	endif
//	A.use_awg = state
//	fd_setGlobalAWG(A)
//end
//
//
//function fd_getGlobalAWG(S)
//	// Function to get global values for AWG_list that were stored using set_global_AWG_list()
//	// StructPut ONLY gets VARIABLES
//	struct AWGVars &S
//	// Get string parts
//	wave/T t = fd_AWGglobalStrings
//	
//		if (!WaveExists(t))
//		fd_initGlobalAWG()
//		wave/T t = fd_AWGglobalStrings
//	endif
//	
//	S.AW_waves = t[0]
//	S.AW_dacs = t[1]
//	S.AW_dacs2 = t[2]
//	S.channels_AW0 = t[3]
//	S.channels_AW1 = t[4]
//	S.channelIDs = t[5]
//	S.instrIDs = t[6]
//
//	// Get variable parts
//	wave v = fd_AWGglobalVars
//	S.initialized = v[0]
//	S.use_AWG = v[1]  
//	S.lims_checked = 0 // Always initialized to zero so that checks have to be run before using in scan (see SetCheckAWG())
//	S.waveLen = v[3]
//	S.numADCs = v[4]
//	S.samplingFreq = v[5]
//	S.measureFreq = v[6]
//	S.numWaves = v[7]
//	S.numCycles = v[8]
//	S.numSteps = v[9]
//	S.maxADCs = v[10]
//	
//end
//
