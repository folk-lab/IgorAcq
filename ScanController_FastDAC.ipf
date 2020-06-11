#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Fast DAC (8 DAC channels + 4 ADC channels). Build in-house by Mark (Electronic work shop).
// This is the ScanController extention to the ScanController code. Running measurements with
// the Fast DAC must be "stand alone", no other instruments can read at the same time.
// The Fast DAC extention will open a seperate "Fast DAC window" that holds all the information
// nessesary to run a Fast DAC measurement. Any "normal" measurements should still be set up in 
// the standard ScanController window.
// It is the users job to add the fastdac=1 flag to initWaves() and SaveWaves()
//
// This driver also provides a spectrum analyzer method. See the Spectrum Analyzer section at the bottom. 
// As for everyting else, you must open a connection to a FastDAC and run "InitFastDAC" before you can use the
// spectrum analyzer method.
//
// Written by Christian Olsen and Tim Child, 2020-03-27
//

/////////////////////
//// Util  //////////
/////////////////////
function prompt_user(promptTitle,promptStr)
	string promptTitle, promptStr
	
	variable x=0
	prompt x, promptStr
	doprompt promptTitle, x
	if(v_flag == 0)
		return x
	else
		return nan
	endif
end

function ask_user(question, [type])
	//type = 0,1,2 for OK, Yes/No, Yes/No/Cancel returns are V_flag = 1: Yes, 2: No, 3: Cancel
	string question
	variable type
	type = paramisdefault(type) ? 1 : type
	doalert type, question
	return V_flag
end


function sc_fillfdacKeys(instrID,visa_address,numDACCh,numADCCh,[master])
	string instrID, visa_address
	variable numDACCh, numADCCh, master
	
	if(paramisdefault(master))
		master = 0
	elseif(master > 1)
		master = 1
	endif
	
	variable numDevices
	svar/z fdackeys
	if(!svar_exists(fdackeys))
		string/g fdackeys = ""
		numDevices = 0
	else
		numDevices = str2num(stringbykey("numDevices",fdackeys,":",","))
	endif
	
	variable i=0, deviceNum=numDevices+1
	for(i=0;i<numDevices;i+=1)
		if(cmpstr(instrID,stringbykey("name"+num2istr(i+1),fdackeys,":",","))==0)
			deviceNum = i+1
			break
		endif
	endfor
	
	fdackeys = replacenumberbykey("numDevices",fdackeys,deviceNum,":",",")
	fdackeys = replacestringbykey("name"+num2istr(deviceNum),fdackeys,instrID,":",",")
	fdackeys = replacestringbykey("visa"+num2istr(deviceNum),fdackeys,visa_address,":",",")
	fdackeys = replacenumberbykey("numDACCh"+num2istr(deviceNum),fdackeys,numDACCh,":",",")
	fdackeys = replacenumberbykey("numADCCh"+num2istr(deviceNum),fdackeys,numADCCh,":",",")
	fdackeys = replacenumberbykey("master"+num2istr(deviceNum),fdackeys,master,":",",")
	fdackeys = sortlist(fdackeys,",")
end
 

function fdacCheckResponse(response,command,[isString,expectedResponse])
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


////////////////////////
//// ScanController ////
///////////////////////

function fdacRecordValues(instrID,rowNum,rampCh,start,fin,numpts,[delay,ramprate,RCcutoff,numAverage,notch,direction])
	// RecordValues for FastDAC's. This function should replace RecordValues in scan functions.
	// j is outer scan index, if it's a 1D scan just set j=0.
	// rampCh is a comma seperated string containing the channels that should be ramped.
	// Data processing:
	// 		- RCcutoff set the lowpass cutoff frequency
	//		- average set the number of points to average
	//		- nocth sets the notch frequency, as a comma seperated list (width is fixed at 5Hz)
	// direction - used to reverse direction of scan (e.g. in alternating repeat scan) - leave start/fin unchanged
	// 	   It is not sufficient to reverse start/fin because sc_distribute_data also needs to know
	variable instrID, rowNum
	string rampCh, start, fin
	variable numpts, delay, ramprate, RCcutoff, numAverage, direction
	string notch
	nvar sc_is2d, sc_startx, sc_starty, sc_finx, sc_starty, sc_finy, sc_numptsx, sc_numptsy
	nvar sc_abortsweep, sc_pause, sc_scanstarttime
	wave/t fadcvalstr, fdacvalstr
	wave fadcattr
	
	ramprate = paramisdefault(ramprate) ? 1000 : ramprate
	delay = paramisdefault(delay) ? 0 : delay
	direction = paramisdefault(direction) ? 1 : direction
	if (!(direction == 1 || direction == -1))  // Abort if direction is not 1 or -1
		abort "ERROR[fdacRecordValues]: Direction must be 1 or -1"
	endif 
	if (direction == -1)  // Switch start and end values to scan in reverse direction
		string temp = start
		start = fin
		fin = temp
	endif
	
	// compare to earlier call of InitializeWaves
	nvar fastdac_init
	if(fastdac_init != 1)
		print("[ERROR] \"RecordValues\": Trying to record fastDACs, but they weren't initialized by \"InitializeWaves\"")
		abort
	endif
	
	// Everything below has to be changed if we get hardware triggers!
	// Check that dac and adc channels are all on the same device and sort lists
	// of DAC and ADC channels for scan.
	// When (if) we get hardware triggers on the fastdacs, this function call should
	// be replaced by a function that sorts DAC and ADC channels based on which device
	// they belong to.
	
	struct fdacChLists scanList
	variable dev_adc=0
	dev_adc = sc_fdacSortChannels(scanlist,rampCh,start,fin)
	
	string err = ""
	// check that the number of dac channels equals the number of start and end values
	if(itemsinlist(scanlist.daclist,",") != itemsinlist(scanlist.startval,",") || itemsinlist(scanlist.daclist,",") != itemsinlist(scanlist.finval,","))
		print("The number of DAC channels must be equal to the number of starting and ending values!")
		sprintf err, "Number of DAC Channel = %d, number of starting values = %d & number of ending values = %d", itemsinlist(scanlist.daclist,","), itemsinlist(scanlist.startval,","), itemsinlist(scanlist.finval,",")
		print err
		abort
	endif
	
	// get ADC sampling speed
	variable samplingFreq=0
	samplingFreq = getfadcSpeed(instrID)/getNumFADC()  //Because sampling is split between number of ADCs being read //TODO: This needs to be adapted for multiple FastDacs
	
	variable eff_ramprate = 0, answer = 0, i=0
	string question = ""
	
	svar activegraphs
	variable k=0, channel
	if(rowNum == 0)
		// check if effective ramprate is higher than software limits
		for(i=0;i<itemsinlist(rampCh,",");i+=1)
			eff_ramprate = abs(str2num(stringfromlist(i,scanlist.startval,","))-str2num(stringfromlist(i,scanlist.finval,",")))*(samplingFreq/numpts)
			channel = str2num(stringfromlist(i, rampCh, ","))
			if(eff_ramprate > str2num(fdacvalstr[channel][4])*1.05)  // Allow 5% too high for convenience
				// we are going too fast
				sprintf question, "DAC channel %d will be ramped at %.1f mV/s, software limit is set to %s mV/s. Continue?", channel, eff_ramprate, fdacvalstr[channel][4]
				answer = ask_user(question, type=1)
				if(answer == 2)
					print("[ERROR] \"RecordValues\": User abort!")
					dowindow/k SweepControl // kill scan control window
					for(k=0;k<itemsinlist(activegraphs,";");k+=1)
						dowindow/k $stringfromlist(k,activegraphs,";")
					endfor
					abort
				endif
			endif
		endfor
	
		// check that start and end values are within software limits
		string softLimitPositive = "", softLimitNegative = "", expr = "(-?[[:digit:]]+),([[:digit:]]+)"
		variable startval = 0, finval = 0
		for(i=0;i<itemsinlist(scanlist.daclist,",");i+=1)
			splitstring/e=(expr) fdacvalstr[str2num(stringfromlist(i,scanlist.daclist,","))][2], softLimitNegative, softLimitPositive
			startval = str2num(stringfromlist(i,scanlist.startval,","))
			finval = str2num(stringfromlist(i,scanlist.finval,","))
			if(startval < str2num(softLimitNegative) || startval > str2num(softLimitPositive) || finval < str2num(softLimitNegative) || finval > str2num(softLimitPositive))
				// we are outside limits
				sprintf question, "DAC channel %s will be ramped outside software limits. Continue?", stringfromlist(i,scanlist.daclist,",")
				answer = ask_user(question, type=1)
				if(answer == 2)
					print("[ERROR] \"RecordValues\": User abort!")
					dowindow/k SweepControl // kill scan control window
					for(k=0;k<itemsinlist(activegraphs,";");k+=1)
						dowindow/k $stringfromlist(k,activegraphs,";")
					endfor
					abort
				endif
			endif
		endfor
	endif
	
	// move DAC channels to starting point
	for(i=0;i<itemsinlist(scanList.daclist,",");i+=1)
		rampOutputfdac(instrID,str2num(stringfromlist(i,scanList.daclist,",")),str2num(stringfromlist(i,scanList.startVal,",")),ramprate=ramprate)
	endfor
	sc_sleep(delay)  // Settle time for 2D sweeps
	
	// build command and start ramp
	// for now we only have to send one command to one device.
	string cmd = "", dacs="", adcs=""
	dacs = replacestring(",",scanlist.daclist,"")
	adcs = replacestring(",",scanlist.adclist,"")
	// OPERATION, DAC CHANNELS, ADC CHANNELS, INITIAL VOLTAGES, FINAL VOLTAGES, # OF STEPS
	sprintf cmd, "INT_RAMP,%s,%s,%s,%s,%d\r", dacs, adcs, scanList.startVal, scanList.finVal, numpts
	writeInstr(instrID,cmd)
	
	// read returned values
	variable numADCs = itemsinlist(scanList.adclist,",")
	variable totalByteReturn = numADCs*2*numpts, read_chunk=0, bytesSec = roundNum(2*samplingFreq,0)
	variable chunksize = roundNum(numADCs*bytesSec/50,0) - mod(roundNum(numADCs*bytesSec/50,0),numADCs*2)
	if(chunksize < 50)
		chunksize = 50 - mod(50,numADCs*2) // 50 or 48 //TIM: If this is so chunksize is a multiple of numADCs*2 then it will fail for 7ADCs
	endif
	if(totalByteReturn > chunksize)
		read_chunk = chunksize
	else
		read_chunk = totalByteReturn
	endif
	
	// hold incoming data chunks in string and distribute to data waves
	string buffer = ""
	variable bytes_read = 0, plotUpdateTime = 15e-3, totaldump = 0,  saveBuffer = 1000
	variable errCode = 0
	variable bufferDumpStart = stopMSTimer(-2)
	variable col_num_start
	svar activegraphs
	do
		buffer = readInstr(instrID, read_bytes=read_chunk, binary=1)
		// If failed, abort
		if (cmpstr(buffer, "NaN") == 0)
			stopFDACsweep(instrID)
			abort
		endif
		// add data to rawwaves and datawaves
		if (direction == 1)
			col_num_start = bytes_read/(2*numADCs)
		elseif (direction == -1)
			col_num_start = (totalByteReturn-bytes_read)/(2*numADCs)-1
		endif
		sc_distribute_data(buffer,scanList.adclist,read_chunk,rowNum,col_num_start, direction=direction)
		bytes_read += read_chunk
		totaldump = bytesSec*(stopmstimer(-2)-bufferDumpStart)*1e-6
		if(totaldump-bytes_read < saveBuffer)
			// we can update all plots
			// should take ~15ms extra
			for(i=0;i<itemsinlist(activegraphs,";");i+=1)
				doupdate/w=$stringfromlist(i,activegraphs,";")
			endfor
			try
				sc_checksweepstate(fastdac=1)
			catch
				errCode = GetRTError(1)
				stopFDACsweep(instrID)
				abortonvalue 1,10
			endtry
		else
			// just check sweep state
			try
				sc_checksweepstate(fastdac=1)
			catch
				errCode = GetRTError(1)
				stopFDACsweep(instrID)
				abortonvalue 1,10
			endtry
		endif
	while(totalByteReturn-bytes_read > read_chunk)
	// do one last read if any data left to read
	variable bytes_left = totalByteReturn-bytes_read
	if(bytes_left > 0)
		buffer = readInstr(instrID,read_bytes=bytes_left,binary=1)
		if (direction == 1)
			col_num_start = bytes_read/(2*numADCs)
		elseif (direction == -1)
			col_num_start = (totalByteReturn-bytes_read)/(2*numADCs)-1
		endif
		sc_distribute_data(buffer,scanList.adclist,bytes_left,rowNum,col_num_start, direction=direction)
		doupdate
		try
			sc_checksweepstate(fastdac=1)
		catch
			errCode = GetRTError(1)
			stopFDACsweep(instrID)
			abortonvalue 1,10
		endtry
	endif
	variable looptime = (stopmstimer(-2)-bufferDumpStart)*1e-6
	
	// update window
	buffer = readInstr(instrID)
	buffer = sc_stripTermination(buffer,"\r\n")
	if(fdacCheckResponse(buffer,cmd,isString=1,expectedResponse="RAMP_FINISHED"))
		for(i=0;i<itemsinlist(scanlist.daclist,",");i+=1)
			channel = str2num(stringfromlist(i,scanlist.daclist,","))
			fdacvalstr[channel][1] = stringfromlist(i,scanlist.finval,",")
			updatefdacWindow(channel)
		endfor
		for(i=0;i<numADCs;i+=1)
			channel = str2num(stringfromlist(i,scanlist.adclist,","))
			getfadcChannel(instrID,channel)
		endfor
	endif

	/////////////////////////
	//// Post processing ////
	/////////////////////////
	
	string warn = "", notch_fracList = ""
	variable doLowpass=0,cutoff_frac=0
	if(RCCutoff != 0)
		// add lowpass filter
		doLowpass = 1
		cutoff_frac = RCcutoff/samplingFreq
		if(cutoff_frac > 0.5)
			print("[WARNING] \"fdacRecordValues\": RC cutoff frequency must be lower than half the sampling frequency!")
			sprintf warn, "Setting it to %.2f", 0.5*samplingFreq
			print(warn)
			cutoff_frac = 0.5
		endif
		notch_fraclist = "0,"
	endif
	
	variable doNotch=0,numNotch=0
	if(cmpstr(notch, "")!=0)
		// add notch filter(s)
		doNotch = 1
		numNotch = itemsinlist(notch,",")
		for(i=0;i<numNotch;i+=1)
			notch_fracList = addlistitem(num2str(str2num(stringfromlist(i,notch,","))/samplingFreq),notch_fracList,",",itemsinlist(notch_fracList))
		endfor
	endif
	
	variable doAverage=0
	doaverage = (numAverage != 0) ? 1 : 0 // If numaverage isn't zero then do average
	
	// setup FIR (Finite Impluse Response) filter(s)
	variable FIRcoefs=0
	if(numpts < 101)
		FIRcoefs = numpts
	else
		FIRcoefs = 101
	endif
	
	string coef = "", coefList = ""
	variable j=0,numfilter=0
	// add RC filter
	if(doLowpass == 1)
		coef = "coefs"+num2istr(numfilter)
		make/o/d/n=0 $coef
		filterfir/lo={cutoff_frac,cutoff_frac,FIRcoefs}/coef $coef
		coefList = addlistitem(coef,coefList,",",itemsinlist(coefList))
		numfilter += 1
	endif
	// add notch filter(s)
	if(doNotch == 1)
		for(j=0;j<numNotch;j+=1)
			coef = "coefs"+num2istr(numfilter)
			make/o/d/n=0 $coef
			filterfir/nmf={str2num(stringfromlist(j,notch_fraclist,",")),15.0/samplingFreq,1.0e-8,1}/coef $coef
			coefList = addlistitem(coef,coefList,",",itemsinlist(coefList))
			numfilter += 1
		endfor
	endif
	
	// apply filters
	if(doLowpass == 1 || doNotch == 1)
		sc_applyfilters(coefList,scanList.adclist,doLowpass,doNotch,cutoff_frac,samplingFreq,FIRcoefs,notch_fraclist,rowNum)
	endif
	
	// average datawaves
	variable lastRow = sc_lastrow(rowNum)
	if(doAverage == 1)
		sc_averageDataWaves(numAverage,scanList.adcList,lastRow,rowNum)
	endif
	
		// check abort/pause status
	try
		sc_checksweepstate(fastdac=1)
	catch
		variable error = GetRTError(1)
		
		// reset sweep control parameters if igor about button is used
		if(v_abortcode == -1)
			sc_abortsweep = 0
			sc_pause = 0
		endif
		
		//silent abort
		abortonvalue 1,10 
	endtry
	
	return looptime
end

function sc_fdacSortChannels(s,rampCh,start,fin)
	struct fdacChLists &s
	string rampCh, start, fin
	wave fadcattr
	wave/t fadcvalstr
	svar fdacKeys
	
	// check that all DAC channels are on the same device
	variable numRampCh = itemsinlist(rampCh,","),i=0,j=0,dev_dac=0,dacCh=0,startCh=0
	variable numDevices = str2num(stringbykey("numDevices",fdacKeys,":",",")),numDACCh=0
	for(i=0;i<numRampCh;i+=1)
		dacCh = str2num(stringfromlist(i,rampCh,","))
		startCh = 0
		for(j=0;j<numDevices;j+=1)
			numDACCh = str2num(stringbykey("numDACCh"+num2istr(j+1),fdacKeys,":",","))
			if(startCh+numDACCh-1 >= dacCh)
				// this is the device
				if(i > 0 && dev_dac != j)
					print "[ERROR] \"sc_checkfdacDevice\": All DAC channels must be on the same device!"
					abort
				else
					dev_dac = j
					break
				endif
			endif
			startCh += numDACCh
		endfor
	endfor
	
	// check that all adc channels are on the same device
	variable q=0,numReadCh=0,h=0,dev_adc=0,adcCh=0,numADCCh=0
	string  adcList = ""
	for(i=0;i<dimsize(fadcattr,0);i+=1)
		if(fadcattr[i][2] == 48)
			adcCh = str2num(fadcvalstr[i][0])
			startCh = 0
			for(j=0;j<numDevices+1;j+=1)
				numADCCh = str2num(stringbykey("numADCCh"+num2istr(j+1),fdacKeys,":",","))
				if(startCh+numADCCh-1 >= adcCh)
					// this is the device
					if(i > 0 && dev_adc != j)
						print "[ERROR] \"sc_checkfdacDevice\": All ADC channels must be on the same device!"
						abort
					elseif(j != dev_dac)
						print "[ERROR] \"sc_checkfdacDevice\": DAC & ADC channels must be on the same device!"
						abort
					else
						dev_adc = j
						adcList = addlistitem(num2istr(adcCh),adcList,",",itemsinlist(adcList,","))
						break
					endif
				endif
				startCh += numADCCh
			endfor
		endif
	endfor
	
	// add result to structure
	s.daclist = rampCh
	s.adclist = adcList
	s.startVal = start
	s.finVal = fin
	
	return dev_adc
end

// structure to hold DAC and ADC channels to be used in fdac scan.
structure fdacChLists
		string dacList
		string adcList
		string startVal
		string finVal
endstructure

function sc_distribute_data(buffer,adcList,bytes,rowNum,colNumStart,[direction])
	string buffer, adcList
	variable bytes, rowNum, colNumStart, direction
	wave/t fadcvalstr
	nvar sc_is2d
	
	direction = paramisdefault(direction) ? 1 : direction
	if (!(direction == 1 || direction == -1))  // Abort if direction is not 1 or -1
		abort "ERROR[sc_distribute_data]: Direction must be 1 or -1"
	endif
	
	variable i=0, j=0, k=0, numADCCh = itemsinlist(adcList,","), adcIndex=0, dataPoint=0
	string wave1d = "", wave2d = "", s1, s2
	// load data into raw wave
	for(i=0;i<numADCCh;i+=1)
		adcIndex = str2num(stringfromlist(i,adcList,","))
		wave1d = "ADC"+num2istr(str2num(stringfromlist(i,adcList,",")))
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
		if(sc_is2d)
			wave2d = wave1d+"_2d"
			wave rawwave2d = $wave2d
			rawwave2d[][rowNum] = rawwave[p]
		endif
	endfor
	
	// load calculated data into datawave
	string script="", cmd=""
	for(i=0;i<numADCCh;i+=1)
		adcIndex = str2num(stringfromlist(i,adcList,","))
		wave1d = fadcvalstr[adcIndex][3]
		wave datawave = $wave1d
		script = trimstring(fadcvalstr[adcIndex][4])
		sprintf cmd, "%s = %s", wave1d, script
		execute/q/z cmd
		if(v_flag!=0)
			print "[WARNING] \"sc_distribute_data\": Wave calculation falied! Error: "+GetErrMessage(V_Flag,2)
		endif
		if(sc_is2d)
			wave2d = wave1d+"_2d"
			wave datawave2d = $wave2d
			datawave2d[][rowNum] = datawave[p]
		endif
	endfor
end

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

function sc_applyfilters(coefList,adcList,doLowpass,doNotch,cutoff_frac,samplingFreq,FIRcoefs,notch_fraclist,rowNum)
	string coefList, adcList, notch_fraclist
	variable doLowpass, doNotch, cutoff_frac, samplingFreq, FIRcoefs, rowNum
	wave/t fadcvalstr
	nvar sc_is2d
	
	string wave1d = "", wave2d = "", errmes=""
	variable i=0,j=0,err=0
	for(i=0;i<itemsinlist(adcList,",");i+=1)
		wave1d = fadcvalstr[str2num(stringfromlist(i,adcList,","))][3]
		wave datawave = $wave1d
		for(j=0;j<itemsinlist(coefList,",");j+=1)
			wave coefs = $stringfromlist(j,coefList,",")
			if(doLowpass == 1 && j == 0)
				filterfir/lo={cutoff_frac,cutoff_frac,FIRcoefs}/coef=coefs datawave
			elseif(doNotch == 1)
				try
					filterfir/nmf={str2num(stringfromlist(j,notch_fraclist,",")),15.0/samplingFreq,1.0e-8,1}/coef=coefs datawave
					abortonrte
				catch
					err = getrTError(1)
					if(dimsize(coefs,0) > 2.0*dimsize(datawave,0))
						// nothing we can do. Don't apply filter!
						sprintf errmes, "[WARNING] \"sc_applyfilters\": Notch filter at %.1f Hz not applied. Length of datawave is too short!",str2num(stringfromlist(j,notch_fraclist,","))*samplingFreq
						print errmes
					else
						// try increasing the filter width to 30Hz
						try
							make/o/d/n=0 coefs2
							filterfir/nmf={str2num(stringfromlist(j,notch_fraclist,",")),30.0/samplingFreq,1.0e-8,1}/coef coefs2, datawave
							abortonrte
							if(rowNum == 0 && i == 0)
								sprintf errmes, "[WARNING] \"sc_applyfilters\": Notch filter at %.1f Hz applied with a filter width of 30Hz.", str2num(stringfromlist(j,notch_fraclist,","))*samplingFreq
								print errmes
							endif
						catch
							err = getrTError(1)
							// didn't work
							if(rowNum == 0 && i == 0)
								sprintf errmes, "[WARNING] \"sc_applyfilters\": Notch filter at %.1f Hz not applied. Increasing filter width to 30 Hz wasn't enough.", str2num(stringfromlist(j,notch_fraclist,","))*samplingFreq
								print errmes
							endif
						endtry
					endif
				endtry
			endif
		endfor
		if(sc_is2d)
			wave2d = wave1d+"_2d"
			wave datawave2d = $wave2d
			datawave2d[][rowNum] = datawave[p]
		endif
	endfor
end

function sc_averageDataWaves(numAverage,adcList,lastRow,rowNum)
	variable numAverage, lastRow, rowNum
	string adcList
	wave/t fadcvalstr
	nvar sc_is2d, sc_startx, sc_finx, sc_starty, sc_finy
	
	variable i=0,j=0,k=0,newsize=0,adcIndex=0,numADCCh=itemsinlist(adcList,","),h=numAverage-1
	string wave1d="",wave2d="",avg1d="",avg2d="",graph="",avggraph="",graphlist="",key=""
	for(i=0;i<numADCCh;i+=1)
		adcIndex = str2num(stringfromlist(i,adcList,","))
		wave1d = fadcvalstr[adcIndex][3]
		wave datawave = $wave1d
		newsize = floor(dimsize(datawave,0)/numAverage)
		avg1d = "avg_"+wave1d
		// check if waves are plotted on the same graph
		graphlist = sc_samegraph(wave1d,avg1d)
		if(str2num(stringbykey("result",graphlist,":",",")) > 1)
			// more than one graph have both waves plotted
			// we need to close one. Let's hope we close the correct one!
			graphlist = removebykey("result",graphlist,":",",")
			for(i=0;i<itemsinlist(graphlist,",")-1;i+=1)
				key = "graph"+num2istr(i)
				killwindow/z $stringbykey(key,graphlist,":",",")
				graphlist = removebykey(key,graphlist,":",",")
			endfor
		endif
		if(lastRow)
			duplicate/o datawave, $avg1d
			make/o/n=(newsize) $wave1d = nan
			wave newdatawave = $wave1d
			setscale/i x, sc_startx, sc_finx, newdatawave
			// average datawave into avgdatawave
			for(j=0;j<newsize;j+=1)
				newdatawave[j] = mean($avg1d,pnt2x($avg1d,j+j*h),pnt2x($avg1d,j+h+j*h))
			endfor
			if(sc_is2d)
				nvar sc_numptsy
				// flip colors of traces in 1d graph
				graph = stringfromlist(0,sc_findgraphs(wave1d),",")
				modifygraph/w=$graph rgb($wave1d)=(0,0,65535), rgb($avg1d)=(65535,0,0)
				// average 2d data
				avg2d = "tempwave_2d"
				wave2d = wave1d+"_2d"
				duplicate/o $wave2d, $avg2d
				make/o/n=(newsize,sc_numptsy) $wave2d = nan
				wave datawave2d = $wave2d
				setscale/i x, sc_startx, sc_finx, datawave2d
				setscale/i y, sc_starty, sc_finy, datawave2d
				for(k=0;k<sc_numptsy;k+=1)
					duplicate/o/rmd=[][k,k] $avg2d, tempwave
					for(j=0;j<newsize;j+=1)
						datawave2d[j][k] = mean(tempwave,pnt2x(tempwave,j+j*h),pnt2x(tempwave,j+h+j*h))
					endfor
				endfor
			endif
		else
			make/o/n=(newsize) $avg1d
			setscale/i x, sc_startx, sc_finx, $avg1d
			wave avgdatawave = $avg1d
			// average datawave into avgdatawave
			for(j=0;j<newsize;j+=1)
				avgdatawave[j] = mean(datawave,pnt2x(datawave,j+j*h),pnt2x(datawave,j+h+j*h))
			endfor
			if(rowNum == 0)
				// plot on top of datawave
				graphlist = sc_findgraphs(wave1d)
				graph = stringfromlist(itemsinlist(graphlist,",")-1,graphlist,",")
				appendtograph/w=$graph/c=(0,0,65535) avgdatawave
			endif
		endif
	endfor
end

function/s sc_samegraph(wave1,wave2)
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

function resetfdacwindow(fdacCh)
	variable fdacCh
	wave/t fdacvalstr, old_fdacvalstr
	
	fdacvalstr[fdacCh][1] = old_fdacvalstr[fdacCh]
end

function updatefdacWindow(fdacCh)
	variable fdacCh
	wave/t fdacvalstr, old_fdacvalstr
	 
	old_fdacvalstr[fdacCh] = fdacvalstr[fdacCh][1]
end


function initFastDAC()
	// use the key:value list "fdackeys" to figure out the correct number of
	// DAC/ADC channels to use. "fdackeys" is created when calling "openFastDACconnection".
	svar fdackeys
	if(!svar_exists(fdackeys))
		print("[ERROR] \"initFastDAC\": No devices found!")
		abort
	endif
	
	// create path for spectrum analyzer
	string datapath = getExpPath("data", full=3)
	newpath/c/o/q spectrum datapath+"spectrum:" // create/overwrite spectrum path
	
	// hardware limit (mV)
	variable/g fdac_limit = 10000
	
	variable i=0, numDevices = str2num(stringbykey("numDevices",fdackeys,":",","))
	variable numDACCh=0, numADCCh=0
	for(i=0;i<numDevices+1;i+=1)
		if(cmpstr(stringbykey("name"+num2istr(i+1),fdackeys,":",","),"")!=0)
			numDACCh += str2num(stringbykey("numDACCh"+num2istr(i+1),fdackeys,":",","))
			numADCCh += str2num(stringbykey("numADCCh"+num2istr(i+1),fdackeys,":",","))
		endif
	endfor
	
	// create waves to hold control info
	variable oldinit = fdacCheckForOldInit(numDACCh,numADCCh)
	
	variable/g num_fdacs = 0
	if(oldinit == -1)
		string/g sc_fadcSpeed1="2532",sc_fadcSpeed2="2532",sc_fadcSpeed3="2532"
		string/g sc_fadcSpeed4="2532",sc_fadcSpeed5="2532",sc_fadcSpeed6="2532"
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
	NewPanel/w=(0,0,790,570)/n=ScanControllerFastDAC // window size
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
	DrawLine 10,385,780,385
	SetDrawEnv dash=7
	Drawline 395,295,780,295
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
	ListBox fdaclist,pos={10,75},size={360,270},fsize=14,frame=2,widths={30,70,100,65}
	ListBox fdaclist,listwave=root:fdacvalstr,selwave=root:fdacattr,mode=1
	Button updatefdac,pos={50,354},size={65,20},proc=update_fdac,title="Update"
	Button fdacramp,pos={150,354},size={65,20},proc=update_fdac,title="Ramp"
	Button fdacrampzero,pos={255,354},size={80,20},proc=update_fdac,title="Ramp all 0"
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
	popupMenu fadcSetting1,pos={420,300},proc=update_fadcSpeed,mode=1,title="\Z14ADC1 speed",size={100,20},value=sc_fadcSpeed1
	popupMenu fadcSetting2,pos={620,300},proc=update_fadcSpeed,mode=1,title="\Z14ADC2 speed",size={100,20},value=sc_fadcSpeed2
	popupMenu fadcSetting3,pos={420,330},proc=update_fadcSpeed,mode=1,title="\Z14ADC3 speed",size={100,20},value=sc_fadcSpeed3
	popupMenu fadcSetting4,pos={620,330},proc=update_fadcSpeed,mode=1,title="\Z14ADC4 speed",size={100,20},value=sc_fadcSpeed4
	popupMenu fadcSetting5,pos={420,360},proc=update_fadcSpeed,mode=1,title="\Z14ADC5 speed",size={100,20},value=sc_fadcSpeed5
	popupMenu fadcSetting6,pos={620,360},proc=update_fadcSpeed,mode=1,title="\Z14ADC6 speed",size={100,20},value=sc_fadcSpeed6
	DrawText 550, 317, "\Z14Hz"
	DrawText 750, 317, "\Z14Hz"
	DrawText 550, 347, "\Z14Hz"
	DrawText 750, 347, "\Z14Hz"
	DrawText 550, 377, "\Z14Hz"
	DrawText 750, 377, "\Z14Hz"
	
	// identical to ScanController window
	// all function calls are to ScanController functions
	// instrument communication
	SetDrawEnv fsize=14, fstyle=1
	DrawText 15, 415, "Connect Instrument"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 265, 415, "Open GUI"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 515, 415, "Log Status"
	ListBox sc_InstrFdac,pos={10,420},size={770,100},fsize=14,frame=2,listWave=root:sc_Instr,selWave=root:instrBoxAttr,mode=1, editStyle=1

	// buttons
	button connectfdac,pos={10,525},size={140,20},proc=sc_OpenInstrButton,title="Connect Instr"
	button guifdac,pos={160,525},size={140,20},proc=sc_OpenGUIButton,title="Open All GUI"
	button killaboutfdac, pos={310,525},size={160,20},proc=sc_controlwindows,title="Kill Sweep Controls"
	button killgraphsfdac, pos={480,525},size={150,20},proc=sc_killgraphs,title="Close All Graphs"
	button updatebuttonfdac, pos={640,525},size={140,20},proc=sc_updatewindow,title="Update"
	
	// helpful text
	DrawText 10, 565, "Press Update to save changes."
endmacro

	// set update speed for ADCs
function update_fadcSpeed(s) : PopupMenuControl
	struct wmpopupaction &s
	
	string visa_address = ""
	svar fdackeys
	if(s.eventcode == 2)
		// a menu item has been selected
		strswitch(s.ctrlname)
			case "fadcSetting1":
				visa_address = stringbykey("visa1",fdackeys,":",",")
				break
			case "fadcSetting2":
				visa_address = stringbykey("visa2",fdackeys,":",",")
				break
			case "fadcSetting3":
				visa_address = stringbykey("visa3",fdackeys,":",",")
				break
			case "fadcSetting4":
				visa_address = stringbykey("visa4",fdackeys,":",",")
				break
			case "fadcSetting5":
				visa_address = stringbykey("visa5",fdackeys,":",",")
				break
			case "fadcSetting6":
				visa_address = stringbykey("visa6",fdackeys,":",",")
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
	svar fdackeys
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
	variable numDevices = str2num(stringbykey("numDevices",fdackeys,":",","))
	for(i=0;i<numDevices;i+=1)
		numDACCh = str2num(stringbykey("numDACCh"+num2istr(i+1),fdackeys,":",","))
		if(numDACCh > 0)
			visa_address = stringbykey("visa"+num2istr(i+1),fdackeys,":",",")
			viRM = openFastDACconnection(tempnamestr, visa_address, verbose=0)
			nvar tempname = $tempnamestr
			try
				strswitch(option)
					case "fdacramp":
						for(j=0;j<numDACCh;j+=1)
							output = str2num(fdacvalstr[startCh+j][1])
							if(output != str2num(old_fdacvalstr[startCh+j]))
								rampOutputfdac(tempname,j,output,ramprate=fd_ramprate)
							endif
						endfor
						break
					case "fdacrampzero":
						for(j=0;j<numDACCh;j+=1)
							rampOutputfdac(tempname,j,0,ramprate=fd_ramprate)
						endfor
						break
					case "updatefdac":
						for(j=0;j<numDACCh;j+=1)
							getfdacOutput(tempname,j)
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
	svar fdackeys
	wave/t fdacvalstr
	wave/t old_fdacvalstr
	nvar fd_ramprate
	
	update_all_fdac(option=action)
	
	// reopen normal instrument connections
	sc_OpenInstrConnections(0)
end

function update_fadc(action) : ButtonControl
	string action
	svar fdackeys
	variable i=0, j=0
	
	string visa_address = "", tempnamestr = "fdac_window_resource"
	variable numDevices = str2num(stringbykey("numDevices",fdackeys,":",","))
	variable numADCCh = 0, startCh = 0, viRm = 0
	for(i=0;i<numDevices;i+=1)
		numADCCh = str2num(stringbykey("numADCCh"+num2istr(i+1),fdackeys,":",","))
		if(numADCCh > 0)
			visa_address = stringbykey("visa"+num2istr(i+1),fdackeys,":",",")
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
	duplicate/o fdacvalstr, old_fdacvalstr
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


//////////////////////////////////
///// Load FastDACs from HDF /////
//////////////////////////////////

function fdLoadFromHDF(datnum, [fastdac_num, no_check])
	// Function to load fastDAC values and labels from a previously save HDF file in current data directory
	// Requires Dac info to be saved in "DAC{label} : output" format
	// with no_check = 0 (default) a window will be shown to user where values can be changed before committing to ramping, also can chose not to load from there
	// setting no_check = 1 will ramp to loaded settings without user input
	// Fastdac_num is which fastdacboard to load. 3/2020 - Not tested
	variable datnum, fastdac_num, no_check
	variable response
	
	fastdac_num = paramisdefault(fastdac_num) ? 1 : fastdac_num  // Which fastdac board to load
	get_fastdacs_from_hdf(datnum, fastdac_num=fastdac_num) // Creates/Overwrites load_fdacvalstr
	
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


function fd_format_setpoints(start, fin, channels, starts, fins)
	// Returns strings in starts and fins in the format that fdacRecordValues takes
	// e.g. fd_format_setpoints(-10, 10, "1,2,3", s, f) will make string s = "-10,-10,-10" and string f = "10,10,10"
	variable start, fin
	string channels, &starts, &fins
	
	variable i
	starts = ""
	fins = ""
	for(i=0; i<itemsInList(channels, ","); i++)
		starts = addlistitem(num2str(start), starts, ",")
		fins = addlistitem(num2str(fin), fins, ",")
	endfor
	starts = starts[0,strlen(starts)-2] // Remove comma at end
	fins = fins[0,strlen(fins)-2]	 		// Remove comma at end
end
