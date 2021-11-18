#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Fast DAC (8 DAC channels + 4 ADC channels). Build in-house by Mark (Electronic work shop).
// This is the ScanController extention to the ScanController code. Running measurements with
// the Fast DAC must be "stand alone", no other instruments can read at the same time.
// The Fast DAC extention will open a seperate "Fast DAC window" that holds all the information
// nessesary to run a Fast DAC measurement. Any "normal" measurements should still be set up in
// the standard ScanController window.
//
// This driver also provides a spectrum analyzer method. See the Spectrum Analyzer section at the bottom.
// As for everyting else, you must open a connection to a FastDAC and run "InitFastDAC" before you can use the
// spectrum analyzer method.
//
// Written by Christian Olsen and Tim Child, 2020-03-27
// Massive refactoring by Tim Child 2021-11

/////////////////////
//// Util  //////////
/////////////////////
function checkInstrIDmatchesDevice(instrID, device)
	// checks instrID is the correct Visa address for device number
	// e.g. if instrID is to FD1, but if when checking DevChannels device 2 was returned, this will fail
	variable instrID, device

	string instrAddress = getResourceAddress(instrID)
	svar sc_fdacKeys
	string deviceAddress = stringbykey("visa"+num2istr(device), sc_fdacKeys, ":", ",") 
	if (cmpstr(deviceAddress, instrAddress) != 0)
		string buffer
		sprintf buffer, "ERROR[checkInstrIDmatchesDevice]: (instrID %d => %s) != device %d => %s", instrID, instrAddress, device, deviceAddress 
		abort buffer
	endif
	return 1
end


function getDeviceNumber(instrID)
	// Returns which connected FastDAC instrID points to (e.g. 1, 2 etc)
	variable instrID

	svar sc_fdackeys
	variable numDevices = getNumDevices(), i=0, numADCCh = 0, numDevice=-1
	string instrAddress = getResourceAddress(instrID), deviceAddress = ""
	for(i=0;i<numDevices;i+=1)
		deviceAddress = getDeviceResourceAddress(i+1)
		if(cmpstr(deviceAddress,instrAddress) == 0)
			numDevice = i+1
			break
		endif
	endfor
	if (numDevice < 0)
		abort "ERROR[getDeviceNumber]: Device not found for given instrID"
	endif
	return numDevice
end


function getNumDevices()
	// Returns number of connected FastDACs
	svar sc_fdacKeys
	return str2num(stringbykey("numDevices",sc_fdackeys,":",","))
end


function/S getDeviceResourceAddress(device)
	// Get visa address from device number (has to be it's own function because this returns a string)
	variable device
	if(device > getNumDevices())
		string buffer
		sprintf buffer,  "ERROR[getDeviceInfoDeviceNum]: Asking for device %d, but only %d devices connected\r", device, getNumDevices()
		abort buffer
	endif

	svar sc_fdacKeys
	return stringByKey("visa"+num2str(device), sc_fdacKeys, ":", ",")
end


function getDeviceInfoDeviceNum(device, info)
	// Returns the value for selected info of numbered fastDAC device (i.e. 1, 2 etc)
	variable device
	string info

	svar sc_fdacKeys

	if(device > getNumDevices())
		string buffer
		sprintf buffer,  "ERROR[getDeviceInfoDeviceNum]: Asking for device %d, but only %d devices connected\r", device, getNumDevices()
		abort buffer
	endif

	string cmd
	strswitch (info)
		case "master":
			cmd = "master"
			break
		case "name":
			cmd = "name"
			break
		case "numADC":
			cmd = "numADCch"
			break
		case "numDAC":
			cmd = "numDACch"
			break
		default:
			abort "ERROR[getDeviceInfo]: Requested info (" + info + ") not understood"
			break
	endswitch
	return str2num(stringByKey(cmd+num2str(device), sc_fdacKeys, ":", ","))
end

function getDeviceInfo(instrID, info)
	// Returns the value for selected info of fastDAC pointed to by instrID
	// Basically a nice way to interact with sc_fdacKeys
	variable instrID
	string info

	variable deviceNum = getDeviceNumber(instrID)
	return getDeviceInfoDeviceNum(deviceNum, info)
end


function/S getDeviceChannels(channels, device, [adc])
	// Convert from absolute channel number to device channel number (i.e. DAC 9 is actually FastDAC2s 1 channel)
	// Returns device number in device variable
	// Note: Comma separated list
	// Note: Must be channel NUMBERS
	// Note: Error thrown if not all channels are on the same device
	string channels // DACs or ADCs to check
	variable adc  // Whether we are checking DACs or ADCs
	variable &device // Returns device number in device (starting from 1)

	svar sc_fdacKeys  // Holds info about connected FastDACs
	
	assertSeparatorType(channels, ";")

	variable numDevices = getNumDevices()
	device = -1 // Init invalid (so can set when first channel is found)
	variable i=0, j=0, numCh=0, startCh=0, Ch=0
	string dev_channels=""
	for(i=0;i<itemsInList(channels);i+=1)
		ch = str2num(stringfromlist(i,channels))  // Looking for where this channel lives
		startCh = 0
		for(j=0;j<numDevices+1;j+=1)  // Cycle through connected devices
			if(!adc) // Looking at DACs
				numCh = getDeviceInfoDeviceNum(j+1, "numDAC")
			else  // Looking at ADCs
				numCh = getDeviceInfoDeviceNum(j+1, "numADC")
			endif

			if(startCh+numCh-1 >= Ch)
				// this is the device
				if(device <= 0)
					device = j+1  // +1 to account for device numbering starting from 1 not zero
				elseif (j+1 != device)
					abort "ERROR[getDeviceChannels]: Channels are distributed across multiple devices. Not implemented"
				endif
				dev_channels = addlistitem(num2istr(Ch),dev_channels,";",INF)  // Add to list of Device Channels
				break
			endif
			startCh += numCh
		endfor
	endfor

	return dev_channels
end


function getDeviceChannelStart(instrID, [adc])
	// Returns first channel number for given instrID (i.e. if second Fastdac, first DAC is probably channel 8)
	variable instrID
	variable adc // set to 1 if checking where ADCs start instead
	
	string ch_request = selectString(adc, "numDAC", "numADC")

	variable numDevices = getNumDevices()
	variable devNum = getDeviceNumber(instrID)

	variable startCh = 0
	variable valid = 0 // Set to 1 when device is found
	variable i
	for(i=0; i<numDevices; i++)
		if (devNum == i+1) // If this is the device (i+1 because device numbering starts at 1)
			valid = 1
			break
		endif
		startCh += getDeviceInfo(i+1, ch_request)
	endfor

	if(!valid)
		abort "ERROR[getDeviceChannelStart]: Device not found"
	endif

	return startCh
end


function fdacCheckResponse(response,command,[isString,expectedResponse])
	// Checks response (that fastdac returns at the end of most commands) meets expected response (e.g. "RAMP_FINISHED")
	string response, command, expectedResponse
	variable isString

	if(paramisdefault(expectedResponse))
		expectedResponse = ""
	endif

	variable errorCheck = 0
	string err="",callingfunc = getrtStackInfo(2)
	// FastDAC will return "NOP" if the commands isn't understood
	if(cmpstr(response,"NOP") == 0)
		sprintf err, "[ERROR] \"%s\": Command not understood! Command: %s", callingfunc, command
		print err
	elseif(numtype(str2num(response)) != 0 && !isString)
		sprintf err, "[ERROR] \"%s\": Bad response: %s", callingfunc, response
		print err
	elseif(cmpstr(response,expectedResponse) != 0 && isString)
		sprintf err, "[ERROR] \"%s\": Bad response: %s", callingfunc, response
		print err
	else
		errorCheck = 1
	endif

	return errorCheck
end


function sc_fillfdacKeys(instrID,visa_address,numDACCh,numADCCh,[master])
	// Puts FastDAC information into global sc_fdackeys which is a list of such entries for each connected FastDAC
	string instrID, visa_address
	variable numDACCh, numADCCh, master

	if(paramisdefault(master))
		master = 0
	elseif(master > 1)
		master = 1
	endif

	variable numDevices
		svar/z sc_fdackeys
	if(!svar_exists(sc_fdackeys))
		string/g sc_fdackeys = ""
		numDevices = 0
	else
		numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",","))
	endif

	variable i=0, deviceNum=numDevices+1
	for(i=0;i<numDevices;i+=1)
		if(cmpstr(instrID,stringbykey("name"+num2istr(i+1),sc_fdackeys,":",","))==0)
			deviceNum = i+1
			break
		endif
	endfor

	sc_fdackeys = replacenumberbykey("numDevices",sc_fdackeys,deviceNum,":",",")
	sc_fdackeys = replacestringbykey("name"+num2istr(deviceNum),sc_fdackeys,instrID,":",",")
	sc_fdackeys = replacestringbykey("visa"+num2istr(deviceNum),sc_fdackeys,visa_address,":",",")
	sc_fdackeys = replacenumberbykey("numDACCh"+num2istr(deviceNum),sc_fdackeys,numDACCh,":",",")
	sc_fdackeys = replacenumberbykey("numADCCh"+num2istr(deviceNum),sc_fdackeys,numADCCh,":",",")
	sc_fdackeys = replacenumberbykey("master"+num2istr(deviceNum),sc_fdackeys,master,":",",")
	sc_fdackeys = sortlist(sc_fdackeys,",")
end


//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////// Taking Data and processing //////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////



function postFilterNumpts(raw_numpts, measureFreq)
    // Returns number of points that will exist after applying lowpass filter specified in ScanController_Fastdac
    variable raw_numpts, measureFreq
	
	nvar boxChecked = sc_ResampleFreqCheckFadc
	nvar targetFreq = sc_ResampleFreqFadc
	if (boxChecked)
	  	RatioFromNumber (targetFreq / measureFreq)
	  	return round(raw_numpts*(V_numerator)/(V_denominator))  // TODO: Is this actually how many points are returned?
	else
		return raw_numpts
	endif
end

function/S getRecordedFastdacInfo(info_name)
	// Return a list of strings for specified column in fadcattr based on whether "record" is ticked
    string info_name  // ("calc_names", "raw_names", "calc_funcs", "inputs", "channels")
    string return_list = ""
    variable i
    wave fadcattr

    wave/t fadcvalstr
    for (i = 0; i<dimsize(fadcvalstr, 0); i++)
        if (fadcattr[i][2] == 48) // Checkbox checked
			strswitch(info_name)
				case "calc_names":
                return_list = addlistItem(fadcvalstr[i][3], return_list, ";", INF)  												
					break
				case "raw_names":
                return_list = addlistItem("ADC"+num2str(i), return_list, ";", INF)  						
					break
				case "calc_funcs":
                return_list = addlistItem(fadcvalstr[i][4], return_list, ";", INF)  						
					break						
				case "inputs":
                return_list = addlistItem(fadcvalstr[i][1], return_list, ";", INF)  												
					break						
				case "channels":
                return_list = addlistItem(fadcvalstr[i][0], return_list, ";", INF)  																		
					break
				default:
					abort "bad name requested: " + info_name
					break
			endswitch						
        endif
    endfor
    return return_list
end


function resampleWaves(w, measureFreq, targetFreq)
	// resamples wave w from measureFreq
	// to targetFreq (which should be lower than measureFreq)
	Wave w
	variable measureFreq, targetFreq
	
	RatioFromNumber (targetFreq / measureFreq)
	resample/UP=(V_numerator)/DOWN=(V_denominator)/N=201 w
  		// TODO: Need to test N more (simple testing suggests we may need >200 in some cases!)
  		// TODO: Need to decide what to do with end effect. Possibly /E=2 (set edges to 0) and then turn those zeros to NaNs? 
  		// TODO: Or maybe /E=3 is safest (repeat edges). The default /E=0 (bounce) is awful.
end

function NEW_fd_record_values(S, rowNum, [AWG_list, linestart])
	struct ScanVars &S
	variable rowNum, linestart
	struct fdAWG_list &AWG_list
	// If passed AWG_list with AWG_list.use_AWG == 1 then it will run with the Arbitrary Wave Generator on
	// Note: Only works for 1 FastDAC! Not sure what implementation will look like for multiple yet

	// Check if AWG_list passed with use_AWG = 1
	variable/g sc_AWG_used = 0  // Global so that this can be used in SaveWaves() to save AWG info if used
	if(!paramisdefault(AWG_list) && AWG_list.use_AWG == 1)  // TODO: Does this work?
		sc_AWG_used = 1
		if(rowNum == 0)
			print "fd_Record_Values: Using AWG"
		endif
	endif

	// Check if this is a linecut scan and update centers if it is
	if(!paramIsDefault(linestart))
		abort "Not Implemented again yet, should update something in ScanVars probably"
		wave sc_linestart
		sc_linestart[rowNum] = linestart
	endif

	if (rowNum == 0 && S.start_time == 0)
		S.start_time = datetime
	endif

   // Check that checks have been carried out in main scan function where they belong
	if(S.lims_checked != 1)
	 	abort "ERROR[fd_record_values]: FD_ScanVars.lims_checked != 1. Probably called before limits/ramprates/sweeprates have been checked in the main Scan Function!"
	endif

   	// Check that DACs are at start of ramp (will set if necessary but will give warning if it needs to)
	fdRV_check_ramp_start(S)

	// Send command and read values
	fdRV_send_command_and_read(S, AWG_list, rowNum) 
	S.end_time = datetime  
	
	// Process 1D read and distribute
	fdRV_process_and_distribute(S, rowNum) 
	
	// return looptime
end

function fdRV_send_command_and_read(S, AWG_list, rowNum)
	// Send 1D Sweep command to fastdac and record the raw data it returns ONLY
	struct ScanVars &S
	struct fdAWG_list &AWG_list
	variable rowNum
	string cmd_sent = ""
	variable totalByteReturn
	nvar sc_AWG_used
	if(sc_AWG_used)  	// Do AWG_RAMP
	   cmd_sent = fd_start_AWG_RAMP(S, AWG_list)
	else				// DO normal INT_RAMP  
		cmd_sent = fd_start_INT_RAMP(S)
	endif
	
	totalByteReturn = S.numADCs*2*S.numptsx
	sc_sleep(0.1) 	// Trying to get 0.2s of data per loop, will timeout on first loop without a bit of a wait first
	variable looptime = 0
   looptime = fdRV_record_buffer(S, rowNum, totalByteReturn)
	
   // update window
	string endstr
	endstr = readInstr(S.instrID)
	endstr = sc_stripTermination(endstr,"\r\n")
	if(fdacCheckResponse(endstr,cmd_sent,isString=1,expectedResponse="RAMP_FINISHED"))
		fdRV_update_window(S, S.numADCs) 
		if(sc_AWG_used)  // Reset AWs back to zero (I don't see any reason the user would want them left at the final position of the AW)
			rampmultiplefdac(S.instrID, AWG_list.AW_DACs, 0)
		endif
	endif

end


function fdRV_process_and_distribute(ScanVars, rowNum)
	// Get 1D wave names, duplicate each wave then resample and copy into calc wave (and do calc string)
	struct ScanVars &ScanVars
	variable rowNum
		
	// Get all raw 1D wave names in a list
	string RawWaveNames1D = get1DWaveNames(1, 1)
	string CalcWaveNames1D = get1DwaveNames(0, 1)
	string CalcStrings = getRecordedFastdacInfo("calc_funcs")
	if (itemsinList(RawWaveNames1D) != itemsinList(CalCWaveNames1D))
		abort "Different number of raw wave names compared to calc wave names"
	endif

	nvar sc_ResampleFreqCheckfadc
	nvar sc_ResampleFreqfadc
	
	variable i = 0
	string rwn, cwn
	string calc_string
	for (i=0; i<itemsinlist(RawWaveNames1D); i++)
		rwn = StringFromList(i, RawWaveNames1D)
		cwn = StringFromList(i, CalcWaveNames1D)		
		calc_string = StringFromList(i, CalcStrings)
		duplicate/o $rwn sc_tempwave
	
		if (sc_ResampleFreqCheckfadc != 0)
			resampleWaves(sc_tempwave, ScanVars.measureFreq, sc_ResampleFreqfadc)
		endif
		calc_string = ReplaceString(rwn, calc_string, "sc_tempwave")
		
		execute("sc_tempwave ="+calc_string)
		execute(cwn+" = sc_tempwave")
		
		if (ScanVars.is2d)
			// Copy 1D raw into 2D
			wave raw1d = $rwn
			wave raw2d = $rwn+"_2d"
			raw2d[][rowNum] = raw1d[p]
			
			// Copy 1D calc into 2D
			cwn = cwn+"_2d"
			wave calc2d = $cwn
			calc2d[][rowNum] = sc_tempwave[p]		
		endif
	endfor	
	doupdate // Update all the graphs with their new data
end


function fd_readvstime(instrID, channels, numpts, samplingFreq, [named_waves])
	//	Just measures for a fixed number of points without ramping anything, stores in ADC# or timeSeriesADC# if spectrum_analyser set
	variable instrID, numpts, samplingFreq
	string channels
	string named_waves // Named waves to store raw data in (; separated same length as channels)
	
	assertSeparatorType(channels, ";")
	variable numChannels = itemsInList(channels)
	if (numChannels == 0)
		abort "ERROR[fd_readvstime]: No channels selected to record"
	endif

	// If storing in named_waves, check they make sense
	if (!paramisDefault(named_waves))
		assertSeparatorType(named_waves, ";")
		if (itemsInList(channels) != itemsInList(named_waves))
			abort "ERROR[fd_readvstime]: named_waves provided but length doesn't match channels"
		endif
	else
		named_waves = ""
	endif
	
	string cmd = ""
	channels = replaceString(";", channels, "")
	channels = replaceString(" ", channels, "")
	sprintf cmd, "SPEC_ANA,%s,%s\r", channels, num2istr(numpts)
//	print(cmd) // DEBUGGING
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
	
	read_chunk = (totalbytesreturn > read_chunk) ? read_chunk : totalbytesreturn
	
	//print bytesSec, read_chunk, totalbytesreturn  // DEBUGGING
	do
		fdRV_read_chunk(instrID, read_chunk, buffer)
		// add data to datawave
		sc_distribute_data(buffer, channels, read_chunk, 0, bytes_read/(2*numChannels), named_waves = named_waves)

		bytes_read += read_chunk
		totaldump = bytesSec*(stopmstimer(-2)-bufferDumpStart)*1e-6
		if(totaldump-bytes_read < saveBuffer)
			fdRV_check_sweepstate(instrID)
			fdRV_update_graphs() // Only updates sc_RawGraphs1D
		else
			print "DEBUGGING[fd_readvstime]: Getting behind!"
		endif
	while(totalbytesreturn-bytes_read > read_chunk)
	// do one last read if any data left to read
	bytes_left = totalbytesreturn-bytes_read
	if(bytes_left > 0)
		buffer = readInstr(instrID,read_bytes=bytes_left,binary=1)
		sc_distribute_data(buffer, channels, bytes_left, 0, bytes_read/(2*numChannels), named_waves = named_waves)
		doupdate
	endif
	
	buffer = readInstr(instrID,read_term="\n")
	buffer = sc_stripTermination(buffer,"\r\n")
	if(!fdacCheckResponse(buffer,cmd,isString=1,expectedResponse="READ_FINISHED"))
		print "[ERROR] \"fd_readvstime\": Error during read. Not all data recived!"
		abort
	endif
end

function fdRV_record_buffer(S, rowNum, totalByteReturn)
   struct ScanVars &S
   variable rowNum, totalByteReturn

   // hold incoming data chunks in string and distribute to data waves
   string buffer = ""
   variable bytes_read = 0, plotUpdateTime = 15e-3, totaldump = 0,  saveBuffer = 2000
   variable bufferDumpStart = stopMSTimer(-2)

   variable bytesSec = roundNum(2*S.measureFreq*S.numADCs,0)
   variable read_chunk = fdRV_get_read_chunk_size(S.numADCs, S.numptsx, bytesSec, totalByteReturn)
   do
      fdRV_read_chunk(S.instrID, read_chunk, buffer)  // puts data into buffer
      fdRV_distribute_data(buffer, S, bytes_read, totalByteReturn, read_chunk, rowNum, S.direction) ///////////// TODO: Change THIS
      bytes_read += read_chunk
      totaldump = bytesSec*(stopmstimer(-2)-bufferDumpStart)*1e-6  // Expected amount of bytes in buffer
      if(totaldump-bytes_read < saveBuffer)  // if we aren't too far behind then update Raw 1D graphs
         fdRV_update_graphs() 
         fdRV_check_sweepstate(S.instrID)
         
//         print "keeping up"
		else
			printf "DEBUGGING: getting behind: Bytes Requested: %d, Expected Dump: %d, Bytes Read: %d\r" totalByteReturn, totaldump, bytes_read
		endif
      fdRV_check_sweepstate(S.instrID)
   while(totalByteReturn-bytes_read > read_chunk)

   // do one last read if any data left to read
   variable bytes_left = totalByteReturn-bytes_read
   if(bytes_left > 0)
      fdRV_read_chunk(S.instrID, bytes_left, buffer)  // puts data into buffer
      fdRV_distribute_data(buffer, S, bytes_read, totalByteReturn, bytes_left, rowNum, S.direction)
      fdRV_check_sweepstate(S.instrID)
      fdRV_update_graphs() 
   endif
   variable looptime = (stopmstimer(-2)-bufferDumpStart)*1e-6
   return looptime
end

function fdRV_get_read_chunk_size(numADCs, numpts, bytesSec, totalByteReturn)
  // Returns the size of chunks that should be read at a time
  variable numADCs, numpts, bytesSec, totalByteReturn

  variable read_chunk=0
  variable chunksize = (round(bytesSec/5) - mod(round(bytesSec/5),numADCs*2))
  if(chunksize < 50)
    chunksize = 50 - mod(50,numADCs*2)
  endif
  if(totalByteReturn > chunksize)
    read_chunk = chunksize
  else
    read_chunk = totalByteReturn
  endif
  return read_chunk
end

function fdRV_update_graphs()
  // updates activegraphs which takes about 15ms
  svar sc_rawGraphs1D

  variable i
  for(i=0;i<itemsinlist(sc_rawGraphs1D,";");i+=1)
    doupdate/w=$stringfromlist(i,sc_rawGraphs1D,";")
  endfor
end

function fdRV_check_sweepstate(instrID)
  	// if abort button pressed then stops FDAC sweep then aborts
  	variable instrID
	variable errCode
	nvar sc_abortsweep
	nvar sc_pause
  	try
    	sc_checksweepstate()
  	catch
		errCode = GetRTError(1)
		stopFDACsweep(instrID)
		if(v_abortcode == -1)
				sc_abortsweep = 0
				sc_pause = 0
		endif
		abortonvalue 1,10
	endtry
end

function fdRV_read_chunk(instrID, read_chunk, buffer)
  variable instrID, read_chunk
  string &buffer
  buffer = readInstr(instrID, read_bytes=read_chunk, binary=1)
  // If failed, abort
  if (cmpstr(buffer, "NaN") == 0)
    stopFDACsweep(instrID)
    abort
  endif
end


function fdRV_distribute_data(buffer, S, bytes_read, totalByteReturn, read_chunk, rowNum, direction)
  // add data to rawwaves
  struct ScanVars &S
  string &buffer  // Passing by reference for speed of execution
  variable bytes_read, totalByteReturn, read_chunk, rowNum, direction

  variable col_num_start
  if (direction == 1)
    col_num_start = bytes_read/(2*S.numADCs)
  elseif (direction == -1)
    col_num_start = (totalByteReturn-bytes_read)/(2*S.numADCs)-1
  endif
  sc_distribute_data(buffer,replaceString(",", S.adclist, ";"),read_chunk,rowNum,col_num_start, direction=direction)
end


function fdRV_update_window(S, numAdcs)
  struct ScanVars &S
  variable numADCs

  wave/T fdacvalstr

  variable i, channel
  for(i=0;i<itemsinlist(S.channelsx,",");i+=1)
    channel = str2num(stringfromlist(i,S.channelsx,","))
    fdacvalstr[channel][1] = stringfromlist(i,S.finxs,",")
    // updatefdacWindow(channel)
    updateOldFDacStr(channel)
  endfor
  for(i=0;i<numADCs;i+=1)
    channel = str2num(stringfromlist(i,S.adclist,","))
    getfadcChannel(S.instrID,channel)
  endfor
end

function sc_distribute_data(buffer,adcList,bytes,rowNum,colNumStart,[direction, named_waves])
	string &buffer, adcList  //passing buffer by reference for speed of execution
	variable bytes, rowNum, colNumStart, direction
	string named_waves
	wave/t fadcvalstr

	variable i
	direction = paramisdefault(direction) ? 1 : direction
	if (!(direction == 1 || direction == -1))  // Abort if direction is not 1 or -1
		abort "ERROR[sc_distribute_data]: Direction must be 1 or -1"
	endif

	variable numADCCh = itemsinlist(adcList)
	string waveslist = ""
	if (!paramisDefault(named_waves) && strlen(named_waves) > 0)
		waveslist = named_waves
	else
		for(i=0;i<numADCCh;i++)
			waveslist = addListItem("ADC"+stringFromList(i, adcList), waveslist, ";", INF)
		endfor
	endif

	variable j, k, dataPoint
	string wave1d, s1, s2
	// load data into raw wave
	for(i=0;i<numADCCh;i+=1)
		wave1d = stringFromList(i, waveslist)
		wave rawwave = $wave1d
		k = 0
		for(j=0;j<bytes;j+=numADCCh*2)
		// convert to floating point
			s1 = buffer[j + (i*2)]
			s2 = buffer[j + (i*2) + 1]
			datapoint = fdacChar2Num(s1, s2)
			rawwave[colNumStart+k] = dataPoint
			k += 1*direction
		endfor
	endfor
end

function/s sc_samegraph(wave1,wave2)
	// Return list of graphs which contain both waves
	string wave1,wave2

	string graphs1="",graphs2=""
	graphs1 = sc_findgraphs(wave1)
	graphs2 = sc_findgraphs(wave2)

	variable graphLen1 = itemsinlist(graphs1,","), graphLen2 = itemsinlist(graphs2,","), result=0, i=0, j=0
	string testitem="",graphlist="", graphitem=""
	graphlist=addlistItem("result:0",graphlist,",",0)
	if(graphLen1 > 0 && graphLen2 > 0)
		for(i=0;i<graphLen1;i+=1)
			testitem = stringfromlist(i,graphs1,",")
			for(j=0;j<graphLen2;j+=1)
				if(cmpstr(testitem,stringfromlist(j,graphs2,",")) == 0)
					result += 1
					graphlist = replaceStringbykey("result",graphlist,num2istr(result),":",",")
					sprintf graphitem, "graph%d:%s",result-1,testitem
					graphlist = addlistitem(graphitem,graphlist,",",result)
				endif
			endfor
		endfor
	endif

	return graphlist
end

function/s sc_findgraphs(inputwave)
	// Return list of graphs which contain inputwave
	string inputwave
	string opengraphs = winlist("*",",","WIN:1"), waveslist = "", graphlist = "", graphname = ""
	variable i=0, j=0
	for(i=0;i<itemsinlist(opengraphs,",");i+=1)
		sprintf graphname, "WIN:%s", stringfromlist(i,opengraphs,",")
		waveslist = wavelist("*",",",graphname)
		for(j=0;j<itemsinlist(waveslist,",");j+=1)
			if(cmpstr(inputwave,stringfromlist(j,waveslist,",")) == 0)
				graphlist = addlistItem(stringfromlist(i,opengraphs,","),graphlist,",")
			endif
		endfor
	endfor
	return graphlist
end


////////////////////////////////////////////////////////////////////////////////////////
////////////////////// CHECKS  /////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////


function fdRV_check_ramp_start(S)
	// Checks that DACs are at the start of the ramp. If not it will ramp there and wait the delay time, but
	// will give the user a WARNING that this should have been done already in the top level scan function
   struct ScanVars &S

   variable i=0, require_ramp = 0, ch, sp, diff
   for(i=0;i<itemsinlist(S.channelsx);i++)
      ch = str2num(stringfromlist(i, S.channelsx, ";"))
      if(S.direction == 1)
	      sp = str2num(stringfromlist(i, S.startxs, ","))
	   elseif(S.direction == -1)
	      sp = str2num(stringfromlist(i, S.finxs, ","))
	   endif
      diff = getFDACOutput(S.instrID, ch)-sp
      if(abs(diff) > 0.5)  // if DAC is more than 0.5mV from start of ramp
         require_ramp = 1
      endif
   endfor

   if(require_ramp == 1)
      print "WARNING[fdRV_check_ramp_start]: At least one DAC was not at start point, it has been ramped and slept for delayx, but this should be done in top level scan function!"
      SFfd_ramp_start(S, ignore_lims = 1, x_only=1)
      sc_sleep(S.delayy) // Settle time for 2D sweeps
   endif
end


///////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Processing /////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////


function sc_lastrow(rowNum)
	variable rowNum

	nvar sc_is2d, sc_numptsy
	variable check = 0
	if(sc_is2d)
		check = sc_numptsy-1
	else
		check = sc_numptsy
	endif

	if(rowNum != check)
		return 0
	elseif(rowNum == check)
		return 1
	else
		return 0
	endif
end


/////////////////////////////////////////////////////////////////////////////////
////////////////////// SCAN INFORMATION /////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////
////////////////////////// FastDAC Scancontroller window /////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////

function resetfdacwindow(fdacCh)
	variable fdacCh
	wave/t fdacvalstr, old_fdacvalstr

	fdacvalstr[fdacCh][1] = old_fdacvalstr[fdacCh]
end

//function updatefdacWindow(fdacCh)
function updateOldFDacStr(fdacCh)
	variable fdacCh
	wave/t fdacvalstr, old_fdacvalstr

	old_fdacvalstr[fdacCh] = fdacvalstr[fdacCh][1]
end


function initFastDAC()
	// use the key:value list "sc_fdackeys" to figure out the correct number of
	// DAC/ADC channels to use. "sc_fdackeys" is created when calling "openFastDACconnection".
	svar sc_fdackeys
	if(!svar_exists(sc_fdackeys))
		print("[ERROR] \"initFastDAC\": No devices found!")
		abort
	endif

	// create path for spectrum analyzer
	string datapath = getExpPath("data", full=3)
	newpath/c/o/q spectrum datapath+"spectrum:" // create/overwrite spectrum path

	// Init Arbitrary Wave Generator global Struct
	fdAWG_init_global_AWG_list()

	// hardware limit (mV)
	variable/g fdac_limit = 10000

	variable i=0, numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",","))
	variable numDACCh=0, numADCCh=0
	for(i=0;i<numDevices+1;i+=1)
		if(cmpstr(stringbykey("name"+num2istr(i+1),sc_fdackeys,":",","),"")!=0)
			numDACCh += str2num(stringbykey("numDACCh"+num2istr(i+1),sc_fdackeys,":",","))
			numADCCh += str2num(stringbykey("numADCCh"+num2istr(i+1),sc_fdackeys,":",","))
		endif
	endfor

	// create waves to hold control info
	variable oldinit = fdacCheckForOldInit(numDACCh,numADCCh)

	variable/g num_fdacs = 0
	if(oldinit == -1)
		string/g sc_fadcSpeed1="2538",sc_fadcSpeed2="2538",sc_fadcSpeed3="2538"
		string/g sc_fadcSpeed4="2538",sc_fadcSpeed5="2538",sc_fadcSpeed6="2538"
	endif

	// create GUI window
	string cmd = ""
	//variable winsize_l,winsize_r,winsize_t,winsize_b
	getwindow/z ScanControllerFastDAC wsizeRM
	killwindow/z ScanControllerFastDAC
	sprintf cmd, "FastDACWindow(%f,%f,%f,%f)", v_left, v_right, v_top, v_bottom
	execute(cmd)
	fdacSetGUIinteraction(numDevices)
end

function fdacCheckForOldInit(numDACCh,numADCCh)
	variable numDACCh, numADCCh

	variable response
	wave/z fdacvalstr
	wave/z old_fdacvalstr
	if(waveexists(fdacvalstr) && waveexists(old_fdacvalstr))
		response = fdacAskUser(numDACCh)
		if(response == 1)
			// Init at old values
			print "[FastDAC] Init to old values"
		elseif(response == -1)
			// Init to default values
			fdacCreateControlWaves(numDACCh,numADCCh)
			print "[FastDAC] Init to default values"
		else
			print "[Warning] \"fdacCheckForOldInit\": Bad user input - Init to default values"
			fdacCreateControlWaves(numDACCh,numADCCh)
			response = -1
		endif
	else
		// Init to default values
		fdacCreateControlWaves(numDACCh,numADCCh)
		response = -1
	endif

	return response
end

function fdacAskUser(numDACCh)
	variable numDACCh
	wave/t fdacvalstr

	// can only init to old settings if the same
	// number of DAC channels are used
	if(dimsize(fdacvalstr,0) == numDACCh)
		make/o/t/n=(numDACCh) fdacdefaultinit = "0"
		duplicate/o/rmd=[][1] fdacvalstr ,fdacvalsinit
		concatenate/o {fdacvalsinit,fdacdefaultinit}, fdacinit
		execute("fdacInitWindow()")
		pauseforuser fdacInitWindow
		nvar fdac_answer
		return fdac_answer
	else
		return -1
	endif
end

window fdacInitWindow() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(100,100,400,630) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 20, 45,"Choose FastDAC init" // Headline
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 40,80,"Old init"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 170,80,"Default"
	ListBox initlist,pos={10,90},size={280,390},fsize=16,frame=2
	ListBox initlist,fStyle=1,listWave=root:fdacinit,mode= 0
	Button old_fdacinit,pos={40,490},size={70,20},proc=fdacAskUserUpdate,title="OLD INIT"
	Button default_fdacinit,pos={170,490},size={70,20},proc=fdacAskUserUpdate,title="DEFAULT"
endmacro

function fdacAskUserUpdate(action) : ButtonControl
	string action
	variable/g fdac_answer

	strswitch(action)
		case "old_fdacinit":
			fdac_answer = 1
			dowindow/k fdacInitWindow
			break
		case "default_fdacinit":
			fdac_answer = -1
			dowindow/k fdacInitWindow
			break
	endswitch
end

window FastDACWindow(v_left,v_right,v_top,v_bottom) : Panel
	variable v_left,v_right,v_top,v_bottom
	PauseUpdate; Silent 1 // pause everything else, while building the window
	NewPanel/w=(0,0,790,630)/n=ScanControllerFastDAC // window size ////// EDIT 570 -> 600
	if(v_left+v_right+v_top+v_bottom > 0)
		MoveWindow/w=ScanControllerFastDAC v_left,v_top,V_right,v_bottom
	endif
	ModifyPanel/w=ScanControllerFastDAC framestyle=2, fixedsize=1
	SetDrawLayer userback
	SetDrawEnv fsize=25, fstyle=1
	DrawText 160, 45, "DAC"
	SetDrawEnv fsize=25, fstyle=1
	DrawText 546, 45, "ADC"
	DrawLine 385,15,385,385 
	DrawLine 10,415,780,415 /////EDIT 385-> 415
	SetDrawEnv dash=7
	Drawline 395,320,780,320 /////EDIT 295 -> 320
	// DAC, 12 channels shown
	SetDrawEnv fsize=14, fstyle=1
	DrawText 15, 70, "Ch"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 50, 70, "Output"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 120, 70, "Limit"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 220, 70, "Label"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 287, 70, "Ramprate"
	ListBox fdaclist,pos={10,75},size={360,300},fsize=14,frame=2,widths={30,70,100,65} 
	ListBox fdaclist,listwave=root:fdacvalstr,selwave=root:fdacattr,mode=1
	Button updatefdac,pos={50,384},size={65,20},proc=update_fdac,title="Update" 
	Button fdacramp,pos={150,384},size={65,20},proc=update_fdac,title="Ramp"
	Button fdacrampzero,pos={255,384},size={80,20},proc=update_fdac,title="Ramp all 0" 
	// ADC, 8 channels shown
	SetDrawEnv fsize=14, fstyle=1
	DrawText 405, 70, "Ch"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 435, 70, "Input (mV)"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 515, 70, "Record"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 575, 70, "Wave Name"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 665, 70, "Calc Function"
	ListBox fadclist,pos={400,75},size={385,180},fsize=14,frame=2,widths={25,65,45,80,80}
	ListBox fadclist,listwave=root:fadcvalstr,selwave=root:fadcattr,mode=1
	button updatefadc,pos={400,265},size={90,20},proc=update_fadc,title="Update ADC"
	checkbox sc_PrintfadcBox,pos={500,265},proc=sc_CheckBoxClicked,value=sc_Printfadc,side=1,title="\Z14Print filenames "
	checkbox sc_SavefadcBox,pos={620,265},proc=sc_CheckBoxClicked,value=sc_Saverawfadc,side=1,title="\Z14Save raw data "
	checkbox sc_FilterfadcCheckBox,pos={400,290},proc=sc_CheckBoxClicked,value=sc_ResampleFreqCheckfadc,side=1,title="\Z14Resample "
	SetVariable sc_FilterfadcBox,pos={500,290},size={200,20},value=sc_ResampleFreqfadc,side=1,title="\Z14Resample Frequency ",help={"Re-samples to specified frequency, 0 Hz == no re-sampling"} /////EDIT ADDED
	DrawText 705,310, "\Z14Hz" 
	popupMenu fadcSetting1,pos={420,330},proc=update_fadcSpeed,mode=1,title="\Z14ADC1 speed",size={100,20},value=sc_fadcSpeed1 
	popupMenu fadcSetting2,pos={620,330},proc=update_fadcSpeed,mode=1,title="\Z14ADC2 speed",size={100,20},value=sc_fadcSpeed2 
	popupMenu fadcSetting3,pos={420,360},proc=update_fadcSpeed,mode=1,title="\Z14ADC3 speed",size={100,20},value=sc_fadcSpeed3 
	popupMenu fadcSetting4,pos={620,360},proc=update_fadcSpeed,mode=1,title="\Z14ADC4 speed",size={100,20},value=sc_fadcSpeed4 
	popupMenu fadcSetting5,pos={420,390},proc=update_fadcSpeed,mode=1,title="\Z14ADC5 speed",size={100,20},value=sc_fadcSpeed5 
	popupMenu fadcSetting6,pos={620,390},proc=update_fadcSpeed,mode=1,title="\Z14ADC6 speed",size={100,20},value=sc_fadcSpeed6 
	DrawText 550, 347, "\Z14Hz" 
	DrawText 750, 347, "\Z14Hz" 
	DrawText 550, 377, "\Z14Hz" 
	DrawText 750, 377, "\Z14Hz" 
	DrawText 550, 407, "\Z14Hz" 
	DrawText 750, 407, "\Z14Hz" 

	// identical to ScanController window
	// all function calls are to ScanController functions
	// instrument communication
	SetDrawEnv fsize=14, fstyle=1
	DrawText 15, 445, "Connect Instrument" 
	SetDrawEnv fsize=14, fstyle=1 
	DrawText 265, 445, "Open GUI" 
	SetDrawEnv fsize=14, fstyle=1
	DrawText 515, 445, "Log Status" 
	ListBox sc_InstrFdac,pos={10,450},size={770,100},fsize=14,frame=2,listWave=root:sc_Instr,selWave=root:instrBoxAttr,mode=1, editStyle=1

	// buttons
	button connectfdac,pos={10,555},size={140,20},proc=sc_OpenInstrButton,title="Connect Instr" 
	button guifdac,pos={160,555},size={140,20},proc=sc_OpenGUIButton,title="Open All GUI" 
	button killaboutfdac, pos={310,555},size={160,20},proc=sc_controlwindows,title="Kill Sweep Controls" 
	button killgraphsfdac, pos={480,555},size={150,20},proc=sc_killgraphs,title="Close All Graphs" 
	button updatebuttonfdac, pos={640,555},size={140,20},proc=sc_updatewindow,title="Update" 

	// helpful text
	DrawText 10, 595, "Press Update to save changes." 
endmacro

	// set update speed for ADCs
function update_fadcSpeed(s) : PopupMenuControl
	struct wmpopupaction &s

	string visa_address = ""
	svar sc_fdackeys
	if(s.eventcode == 2)
		// a menu item has been selected
		strswitch(s.ctrlname)
			case "fadcSetting1":
				visa_address = stringbykey("visa1",sc_fdackeys,":",",")
				break
			case "fadcSetting2":
				visa_address = stringbykey("visa2",sc_fdackeys,":",",")
				break
			case "fadcSetting3":
				visa_address = stringbykey("visa3",sc_fdackeys,":",",")
				break
			case "fadcSetting4":
				visa_address = stringbykey("visa4",sc_fdackeys,":",",")
				break
			case "fadcSetting5":
				visa_address = stringbykey("visa5",sc_fdackeys,":",",")
				break
			case "fadcSetting6":
				visa_address = stringbykey("visa6",sc_fdackeys,":",",")
				break
		endswitch

		string tempnamestr = "fdac_window_resource"
		try
			variable viRM = openFastDACconnection(tempnamestr, visa_address, verbose=0)
			nvar tempname = $tempnamestr
			setfadcSpeed(tempname,str2num(s.popStr))
		catch
			// reset error code, so VISA connection can be closed!
			variable err = GetRTError(1)

			viClose(tempname)
			viClose(viRM)
			// reopen normal instrument connections
			sc_OpenInstrConnections(0)
			// silent abort
			abortonvalue 1,10
		endtry
			// close temp visa connection
			viClose(tempname)
			viClose(viRM)
			sc_OpenInstrConnections(0)
			return 0
	else
		// do nothing
		return 0
	endif
	// reopen normal instrument connections
	sc_OpenInstrConnections(0)
end


function update_all_fdac([option])
	// Ramps or updates all FastDac outputs
	string option // {"fdacramp": ramp all fastdacs to values currently in fdacvalstr, "fdacrampzero": ramp all to zero, "updatefdac": update fdacvalstr from what the dacs are currently at}
	svar sc_fdackeys
	wave/t fdacvalstr
	wave/t old_fdacvalstr
	nvar fd_ramprate

	if (paramisdefault(option))
		option = "fdacramp"
	endif

	// open temporary connection to FastDACs
	// Either ramp fastdacs or update fdacvalstr
	variable i=0,j=0,output = 0, numDACCh = 0, startCh = 0, viRM = 0
	string visa_address = "", tempnamestr = "fdac_window_resource"
	variable numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",","))
	for(i=0;i<numDevices;i+=1)
		numDACCh = str2num(stringbykey("numDACCh"+num2istr(i+1),sc_fdackeys,":",","))
		if(numDACCh > 0)
			visa_address = stringbykey("visa"+num2istr(i+1),sc_fdackeys,":",",")
			viRM = openFastDACconnection(tempnamestr, visa_address, verbose=0)
			nvar tempname = $tempnamestr
			try
				strswitch(option)
					case "fdacramp":
						for(j=0;j<numDACCh;j+=1)
							output = str2num(fdacvalstr[startCh+j][1])
							if(output != str2num(old_fdacvalstr[startCh+j]))
								// rampOutputfdac(tempname,j,output,ramprate=fd_ramprate)
								rampOutputfdac(tempname,startCh+j,output,ramprate=fd_ramprate)
							endif
						endfor
						break
					case "fdacrampzero":
						for(j=0;j<numDACCh;j+=1)
							// rampOutputfdac(tempname,j,0,ramprate=fd_ramprate)
							rampOutputfdac(tempname,startCh+j,0,ramprate=fd_ramprate)
						endfor
						break
					case "updatefdac":
						variable value
						for(j=0;j<numDACCh;j+=1)
							// getfdacOutput(tempname,j)
							value = getfdacOutput(tempname,j) // j only because this is PER DEVICE
							updateFdacValStr(startCh+j, value, update_oldValStr=1)
						endfor
						break
				endswitch
			catch
				// reset error code, so VISA connection can be closed!
				variable err = GetRTError(1)

				viClose(tempname)
				viClose(viRM)
				// reopen normal instrument connections
				sc_OpenInstrConnections(0)
				// silent abort
				abortonvalue 1,10
			endtry

				// close temp visa connection
				viClose(tempname)
				viClose(viRM)
		endif
		startCh =+ numDACCh
	endfor
end

function update_fdac(action) : ButtonControl
	string action
	svar sc_fdackeys
	wave/t fdacvalstr
	wave/t old_fdacvalstr
	nvar fd_ramprate

	update_all_fdac(option=action)

	// reopen normal instrument connections
	sc_OpenInstrConnections(0)
end

function update_fadc(action) : ButtonControl
	string action
	svar sc_fdackeys
	variable i=0, j=0

	string visa_address = "", tempnamestr = "fdac_window_resource"
	variable numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",","))
	variable numADCCh = 0, startCh = 0, viRm = 0
	for(i=0;i<numDevices;i+=1)
		numADCCh = str2num(stringbykey("numADCCh"+num2istr(i+1),sc_fdackeys,":",","))
		if(numADCCh > 0)
			visa_address = stringbykey("visa"+num2istr(i+1),sc_fdackeys,":",",")
			viRm = openFastDACconnection(tempnamestr, visa_address, verbose=0)
			nvar tempname = $tempnamestr
			try
				for(j=0;j<numADCCh;j+=1)
					getfadcChannel(tempname,startCh+j)
				endfor
			catch
				// reset error
				variable err = GetRTError(1)

				viClose(tempname)
				viClose(viRM)
				// reopen normal instrument connections
				sc_OpenInstrConnections(0)
				// silent abort
				abortonvalue 1,10
			endtry

			// close temp visa connection
			viClose(tempname)
			viClose(viRM)
		endif
		startCh += numADCCh
	endfor
	// reopen normal instrument connections
	sc_OpenInstrConnections(0)
end

function fdacCreateControlWaves(numDACCh,numADCCh)
	variable numDACCh,numADCCh

	// create waves for DAC part
	make/o/t/n=(numDACCh) fdacval0 = "0"				// Channel
	make/o/t/n=(numDACCh) fdacval1 = "0"				// Output /mV
	make/o/t/n=(numDACCh) fdacval2 = "-10000,10000"	// Limits /mV
	make/o/t/n=(numDACCh) fdacval3 = ""					// Labels
	make/o/t/n=(numDACCh) fdacval4 = "1000"			// Ramprate limit /mV/s
	variable i=0
	for(i=0;i<numDACCh;i+=1)
		fdacval0[i] = num2istr(i)
	endfor
	concatenate/o {fdacval0,fdacval1,fdacval2,fdacval3,fdacval4}, fdacvalstr
	duplicate/o/R=[][1] fdacvalstr, old_fdacvalstr
	make/o/n=(numDACCh) fdacattr0 = 0
	make/o/n=(numDACCh) fdacattr1 = 2
	concatenate/o {fdacattr0,fdacattr1,fdacattr1,fdacattr1,fdacattr1}, fdacattr

	//create waves for ADC part
	make/o/t/n=(numADCCh) fadcval0 = "0"	// Channel
	make/o/t/n=(numADCCh) fadcval1 = ""		// Input /mV  (initializes empty otherwise false reading)
	make/o/t/n=(numADCCh) fadcval2 = ""		// Record (1/0)
	make/o/t/n=(numADCCh) fadcval3 = ""		// Wave Name
	make/o/t/n=(numADCCh) fadcval4 = ""		// Calc (e.g. ADC0*1e-6)
	for(i=0;i<numADCCh;i+=1)
		fadcval0[i] = num2istr(i)
		fadcval3[i] = "wave"+num2istr(i)
		fadcval4[i] = "ADC"+num2istr(i)
	endfor
	concatenate/o {fadcval0,fadcval1,fadcval2,fadcval3,fadcval4}, fadcvalstr
	make/o/n=(numADCCh) fadcattr0 = 0
	make/o/n=(numADCCh) fadcattr1 = 2
	make/o/n=(numADCCh) fadcattr2 = 32
	concatenate/o {fadcattr0,fadcattr0,fadcattr2,fadcattr1,fadcattr1}, fadcattr


	variable/g sc_printfadc = 0
	variable/g sc_saverawfadc = 0
	variable/g sc_ResampleFreqCheckfadc = 0 // Whether to use resampling
	variable/g sc_ResampleFreqfadc = 100 // Resampling frequency if using resampling


	// clean up
	killwaves fdacval0,fdacval1,fdacval2,fdacval3,fdacval4
	killwaves fdacattr0,fdacattr1
	killwaves fadcval0,fadcval1,fadcval2,fadcval3,fadcval4
	killwaves fadcattr0,fadcattr1,fadcattr2
end

function fdacSetGUIinteraction(numDevices)
	variable numDevices

	// edit interaction mode popup menus if nessesary
	switch(numDevices)
		case 1:
			popupMenu fadcSetting2, disable=2
			popupMenu fadcSetting3, disable=2
			popupMenu fadcSetting4, disable=2
			popupMenu fadcSetting5, disable=2
			popupMenu fadcSetting6, disable=2
			break
		case 2:
			popupMenu fadcSetting3, disable=2
			popupMenu fadcSetting4, disable=2
			popupMenu fadcSetting4, disable=2
			popupMenu fadcSetting5, disable=2
			popupMenu fadcSetting6, disable=2
			break
		case 3:
			popupMenu fadcSetting4, disable=2
			popupMenu fadcSetting5, disable=2
			popupMenu fadcSetting6, disable=2
			break
		case 4:
			popupMenu fadcSetting5, disable=2
			popupMenu fadcSetting6, disable=2
			break
		case 5:
			popupMenu fadcSetting6, disable=2
			break
		default:
			if(numDevices > 6)
				print("[WARNINIG] \"FastDAC GUI\": More than 6 devices are hooked up.")
				print("Call \"setfadcSpeed\" to set the speeds of the devices not displayed in the GUI.")
			endif
	endswitch
end
