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
// Written by Christian Olsen, 2019-11-xx

function openFastDACconnection(instrID, visa_address, [verbose,numDACCh,numADCCh])
	// instrID is the name of the global variable that will be used for communication
	// visa_address is the VISA address string, i.e. ASRL1::INSTR
	// Most FastDAC communication relies on the info in "fdackeys". Pass numDACCh and
	// numADCCh to fill info into "fdackeys"
	string instrID, visa_address
	variable verbose, numDACCh, numADCCh

	if(paramisdefault(verbose))
		verbose=1
	elseif(verbose!=1)
		verbose=0
	endif

	variable localRM
	variable status = viOpenDefaultRM(localRM) // open local copy of resource manager
	if(status < 0)
		VISAerrormsg("open FastDAC connection:", localRM, status)
		abort
	endif

	string comm = ""
	sprintf comm, "name=FastDAC,instrID=%s,visa_address=%s" instrID, visa_address
	string options = "baudrate=57600,databits=8,stopbits=1,parity=0"
	openVISAinstr(comm, options=options, localRM=localRM, verbose=verbose)

	// fill info into "fdackeys"
	if(!paramisdefault(numDACCh) && !paramisdefault(numADCCh))
		sc_fillfdacKeys(instrID,visa_address,numDACCh,numADCCh)
	endif

	return localRM
end

function sc_fillfdacKeys(instrID,visa_address,numDACCh,numADCCh)
	string instrID, visa_address
	variable numDACCh, numADCCh

	variable numDevices
	svar fdackeys
	if(!svar_exists(fdackeys))
		string/g fdackeys = ""
		numDevices = 0
	else
		numDevices = str2num(stringbykey("numDevices",fdackeys,":",","))
	endif

	variable i=0, deviceNum=numDevices+1
	for(i=0;i<4;i+=1)
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
	fdackeys = sortlist(fdackeys,",")
end

function fdacRecordValues(instrID,rowNum,rampCh,start,fin,numpts,[ramprate,RCcutoff,numAverage,notch, ignore_positive]) //TIM: "ignore_positive" is a temporary protection against ramping to positive voltages
	// RecordValues for FastDAC's. This function should replace RecordValues in scan functions.
	// j is outer scan index, if it's a 1D scan just set j=0.
	// rampCh is a comma seperated string containing the channels that should be ramped.
	// start/fin are comma separated strings which should have same length as rampCh (and ARE in mV)
	// Data processing:
	// 		- RCcutoff set the lowpass cutoff frequency
	//		- average set the number of points to average
	//		- nocth sets the notch frequencie, as a comma seperated list (width is fixed at 5Hz)
	variable instrID, rowNum, ignore_positive
	string rampCh, start, fin
	variable numpts, ramprate, RCcutoff, numAverage
	string notch
	nvar sc_is2d, sc_startx, sc_starty, sc_finx, sc_starty, sc_finy, sc_numptsx, sc_numptsy
	nvar sc_abortsweep, sc_pause, sc_scanstarttime
	wave/t fadcvalstr
	wave fadcattr

	if(paramisdefault(ramprate))
		ramprate = 1000
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
	svar sc_fastadc
	variable dev_adc=0
	dev_adc = sc_fdacSortChannels(rampCh,start,fin)
	struct fdacChLists scanList
	scanList.daclist = rampCh
	scanList.adclist = sc_fastadc
	scanList.startVal = start
	scanList.finVal = fin

	variable startlen = itemsinlist(scanList.startVal, ",")
	variable finlen = itemsinlist(scanList.finVal, ",")
	variable daclen = itemsinlist(scanlist.daclist, ",")
	if ((startlen != finlen) || (startlen != daclen))
		printf "Starvals has %d items, Finvals has %d items, Daclist has %d items", startlen, finlen, daclen
		abort "[ERROR]\"fdacRecordValues\": Must have same number of DAC channels, Start values, and Fin values"
	endif

	// move DAC channels to starting point
	variable i=0
	for(i=0;i<itemsinlist(scanList.daclist,",");i+=1)
		rampOutputfdac(instrID,str2num(stringfromlist(i,scanList.daclist,",")),str2num(stringfromlist(i,scanList.startVal,",")),ramprate=ramprate)
	endfor
	// build command and start ramp
	// for now we only have to send one command to one device.

	string cmd = "", dacs, adcs
	dacs = replacestring(",", scanList.daclist, "") //INT_RAMP requires e.g. "023" for DACs 0,2,3
	dacs = replacestring(" ", dacs, "")
	adcs = replacestring(",", scanList.adclist, "") //INT_RAMP requires e.g. "023" for DACs 0,2,3
	adcs = replacestring(" ", adcs, "")

	if (rownum == 0)
		variable r, highramprate = 0, ch
		for (i=0;i<itemsinlist(scanList.startval,",");i++)
			r = abs(str2num(stringfromlist(i, scanlist.finval, ","))-str2num(stringfromlist(i, scanlist.startval, ",")))*(getfadcspeed(instrID)/numpts) //abs(fin-start)*(freq/numpts)
			if (r>highramprate)  //If fastest ramprate yet
				highramprate = r
				ch = str2num(stringfromlist(i, scanlist.daclist, ","))  //fastest channel
			endif
		endfor

		if (highramprate > 10000)
			string question
			sprintf question, "Do you really want to ramp FastDAC ch%d faster than 10000mV/s?", ch
			if (ask_user(question) == 2)
				abort "Phew, ramprate was going to be too high, but scan was aborted"
			endif
		endif
	endif


	/////////////// TEMPORARY 11/2/2020 TIM
	if (ignore_positive != 1)
		string rampvals
		variable val
		rampvals = addlistitem(scanList.startval, scanList.finval, ",")
		for(i=0; i<daclen*2; i++)
			val = str2num(stringfromlist(i, rampvals, ","))
			if (val > 100)
				dowindow/k SweepControl
				abort "INT_RAMP was going to ramp > 100mV without ignore_positive flag set"
			endif
		endfor
	endif
	////////////////////////
	
	sprintf cmd, "INT_RAMP,%s,%s,%s,%s,%d\r", dacs, adcs, scanList.startVal, scanList.finVal, numpts
	writeInstr(instrID,cmd)

	// read returned values
	variable totalByteReturn = itemsInList(scanList.adclist, ",")*numpts*2, read_chunk=0
//	variable chunksize = itemsinlist(scanList.adclist,",")*2*30
	variable chunksize = 512
	if(totalByteReturn > chunksize)
		read_chunk = chunksize

	else
		read_chunk = totalByteReturn
	endif

	// make temp wave to hold incomming data chunks
	// and distribute to data waves
	string buffer = ""
	variable bytes_read = 0, numadc = itemsInList(scanList.adclist, ",")
	i = 0
	do
		buffer = readInstr(instrID,read_bytes=read_chunk, binary=1)
		if (cmpstr(buffer, "NaN") == 0) // If failed, abort
      		clear_buffer(instrID) // Try empty out whatever crap is left in buffer
			abort
		endif
		// add data to rawwaves and datawaves
		sc_distribute_data(buffer,scanList.adclist,read_chunk,rowNum,bytes_read/(2*numadc))
		bytes_read += read_chunk
		if (mod(i,10) == 0) //Slows down fastdac if updating faster
			doupdate
		endif
		i++
	while(totalByteReturn-bytes_read > read_chunk)
	// do one last read if any data left to read
	variable bytes_left = totalByteReturn-bytes_read
	if(bytes_left > 0)
		buffer = readInstr(instrID,read_bytes=bytes_left,binary=1)
		sc_distribute_data(buffer,scanList.adclist,bytes_left,rowNum,bytes_read/(2*numadc))
	endif

	buffer = remove_rn(readInstr(instrID, binary=0, read_term="\n"))
	if (cmpstr(buffer, "RAMP_FINISHED") != 0)
		printf "[WARNING]: \"fdacRecordValues\" - End of data was \"%s\" instead of \"RAMP_FINISHED\"", buffer
	else //Update values
		wave/t fdacvalstr, old_fdacvalstr
		variable channel, output
		for (i=0;i<itemsinlist(scanList.daclist, ",");i++)
			channel = str2num(stringfromList(i, scanList.daclist, ","))
			output = str2num(stringfromList(i, scanList.finVal, ","))
			fdacvalstr[channel][1] = num2str(output)
			old_fdacvalstr[channel] = fdacvalstr[channel][1]
		endfor
	endif



	/////////////////////////
	//// Post processing ////
	/////////////////////////

	variable samplingFreq=0
	samplingFreq = getfadcSpeed(instrID)/itemsinlist(scanList.adclist, ",")

	string warn = ""
	variable doLowpass=0,cutoff_frac=0
	if(RCcutoff!=0)
		// add lowpass filter
		doLowpass = 1
		cutoff_frac = RCcutoff/samplingFreq
		if(cutoff_frac > 0.5)
			print("[WARNING] \"fdacRecordValues\": RC cutoff frequency must be lower than half the sampling frequency!")
			sprintf warn, "Setting it to %.2f", 0.5*samplingFreq
			print(warn)
			cutoff_frac = 0.5
		endif
	endif

	variable doNotch=0,numNotch=0
	string notch_fracList = ""
	if(cmpstr(notch, "") != 0)
		// add notch filter(s)
		doNotch = 1
		numNotch = itemsinlist(notch,",")
		for(i=0;i<numNotch;i+=1)
			notch_fracList = addlistitem(num2str(str2num(stringfromlist(i,notch,","))/samplingFreq),notch_fracList,",",itemsinlist(notch_fracList))
		endfor
	endif

	variable doAverage=0
	if(numAverage != 0)
		// do averaging
		doAverage = 1
	endif

	// setup FIR (Finite Impluse Response) filter(s)
	variable FIRcoefs=0
	if(numpts < 101)
		FIRcoefs = numpts
	else
		FIRcoefs = 101
	endif

	string coef = "", coefList = ""
	variable j=0
	if(doLowpass == 1 && doNotch == 1)
		for(j=0;j<numNotch;j+=1)
			coef = "coefs"+num2istr(j)
			make/o/d/n=0 $coef
			if(j==0)
				// add RC filter in first round
				filterfir/lo={cutoff_frac,cutoff_frac,FIRcoefs}/nmf={str2num(stringfromlist(j,notch_fraclist,",")),10.0/samplingFreq,1.0e-12,2}/coef $coef
				coefList = addlistitem(coef,coefList,",",itemsinlist(coefList))
			else
				// make an aditional filter per extra notch
				filterfir/nmf={str2num(stringfromlist(j,notch_fraclist,",")),10.0/samplingFreq,1.0e-12,2}/coef $coef
				coefList = addlistitem(coef,coefList,",",itemsinlist(coefList))
			endif
		endfor
	elseif(doLowpass == 1 && doNOtch == 0)
		coef = "coefs"+num2istr(0)
		make/o/d/n=0 $coef
		// add RC filter in first round
		filterfir/lo={cutoff_frac,cutoff_frac,FIRcoefs}/coef $coef
		coefList = addlistitem(coef,coefList,",",itemsinlist(coefList))
	elseif(doNotch == 1 && doLowpass == 0)
		for(j=0;j<numNotch;j+=1)
			coef = "coefs"+num2istr(j)
			make/o/d/n=0 $coef
			filterfir/nmf={str2num(stringfromlist(j,notch_fraclist,",")),10.0/samplingFreq,1.0e-12,2}/coef $coef
			coefList = addlistitem(coef,coefList,",",itemsinlist(coefList))
		endfor
	endif

	// apply filters
	if(doLowpass == 1 || doNotch == 1)
		sc_applyfilters(coefList,scanList.adclist,doLowpass,doNotch,cutoff_frac,samplingFreq,FIRcoefs,notch_fraclist)
	endif

	// average datawaves
	if(doAverage == 1)
		sc_averageDataWaves(numAverage,scanList.adcList)
	endif

	return 0
end

function ask_user(question, [type])
	//type = 0,1,2 for OK, Yes/No, Yes/No/Cancel returns are V_flag = 1: Yes, 2: No, 3: Cancel
	string question
	variable type
	type = paramisdefault(type) ? 1 : type
	doalert type, question
	return V_flag
end


function sc_applyfilters(coefList,adcList,doLowpass,doNotch,cutoff_frac,samplingFreq,FIRcoefs,notch_fraclist)
	string coefList, adcList
	variable doLowpass, doNotch, cutoff_frac, samplingFreq, FIRcoefs
	string notch_fraclist
	wave/t fadcvalstr

	variable i=0,j=0
	for(i=0;i<itemsinlist(adcList,",");i+=1)
		wave datawave = $fadcvalstr[str2num(stringfromlist(i,adcList,","))][3]
		for(j=0;j<itemsinlist(coefList,",");j+=1)
			wave coefs = $stringfromlist(j,coefList,",")
			if(doLowpass == 1 && j == 0)
				filterfir/lo={cutoff_frac,cutoff_frac,FIRcoefs}/nmf={str2num(stringfromlist(j,notch_fraclist,",")),10.0/samplingFreq,1.0e-12,2}/coef=coefs datawave
			else
				filterfir/nmf={str2num(stringfromlist(j,notch_fraclist,",")),10.0/samplingFreq,1.0e-12,2}/coef=coefs datawave
			endif
		endfor
	endfor
end

function sc_distribute_data(buffer,adcList,bytes,rowNum,colNumStart)
	string buffer, adcList
	variable bytes, rowNum, colNumStart
	wave/t fadcvalstr

	nvar sc_is2d
	variable i=0, j=0, k=0, numADCCh = itemsinlist(adcList,","), adcIndex=0, dataPoint=0
	string wave1d = "", wave2d = "", s1, s2
	// load data into raw wave
	for(i=0;i<numADCCh;i+=1)
		adcIndex = str2num(stringfromlist(i,adcList,","))
		wave1d = "ADC"+num2istr(str2num(stringfromlist(i,adcList,",")))
		wave rawwave = $wave1d
		k = 0
		for(j=0;j<bytes;j+=numADCCh*2)
			s1 = buffer[j + (i*2)]
			s2 = buffer[j + (i*2) + 1]
			// dataPoint = str2num(stringfromlist(i+j*numADCCh,buffer,","))
			datapoint = fdacChar2Num(s1, s2)
			rawwave[colNumStart+k] = dataPoint
			k += 1
		endfor
		if(sc_is2d)
			wave2d = wave1d+"_2d"
			wave rawwave2d = $wave2d
			rawwave2d[][rowNum] = rawwave[p]
		endif
	endfor

	// load calculated data into datawave
	string script="", cmd=""
	string calcwn1d = "", rawwn1d = ""
	for(i=0;i<numADCCh;i+=1)
		adcIndex = str2num(stringfromlist(i,adcList,","))
		calcwn1d = fadcvalstr[adcIndex][3]
		rawwn1d = "ADC"+num2istr(str2num(stringfromlist(i,adcList,",")))
		script = trimstring(fadcvalstr[adcIndex][4])
		if (strlen(script)>0)
			variable multiplier
			sprintf cmd, "%s = %s*%s", calcwn1d, rawwn1d, script
			execute/q/z cmd
		else
			sprintf cmd, "%s = %s", calcwn1d, rawwn1d
			execute/q/z cmd
		endif
		if(v_flag!=0)
			print "[WARNING] \"sc_distribute_data\": Wave calculation falied! Error: "+GetErrMessage(V_Flag,2)
		endif
		if(sc_is2d)
			wave datawave = $calcwn1d
			wave2d = calcwn1d+"_2d"
			wave datawave2d = $wave2d
			datawave2d[][rowNum] = datawave[p]
		endif
	endfor
end

function sc_averageDataWaves(numAverage,adcList)
	variable numAverage
	string adcList
	wave/t fadcvalstr
	nvar sc_is2d

	variable i=0,j=0,k=0,newsize=0,adcIndex=0,numADCCh=itemsinlist(adcList,","),h=numAverage-1
	string wave1d="",wave2d="",newname1d="",newname2d=""
	for(i=0;i<numADCCh;i+=1)
		adcIndex = str2num(stringfromlist(i,adcList,","))
		wave1d = fadcvalstr[adcIndex][3]
		wave datawave = $wave1d
		newsize = floor(dimsize(datawave,0)/numAverage)
		// rename original waves
		newname1d = "temp_"+wave1d
		killwaves/z $newname1d
		rename datawave, newname1d
		// make new wave with old name
		make/o/n=(newsize) $wave1d
		wave newdatawave = $wave1d
		for(j=0;j<newsize;j+=1)
			newdatawave[j] = mean($newname1d,j+j*h,j+h+j*h)
		endfor
		if(sc_is2d)
			wave2d = wave1d+"_2d"
			wave datawave2d = $wave2d
			newname2d = "temp_"+wave2d
			killwaves/z $newname2d
			rename datawave2d, newname2d
			// make new wave with old name
			make/o/n=(newsize,dimsize($newname2d,1)) $wave2d
			wave newdatawave2d = $wave2d
			for(k=0;k<dimsize(newdatawave2d,1);k+=1)
				for(j=0;j<newsize;j+=1)
					newdatawave2d[j][k] = mean($newname2d,j+j*h,j+h+j*h)
				endfor
			endfor
		endif
	endfor
end

function sc_fdacSortChannels(rampCh,start,fin)
	string rampCh, start, fin
	wave fadcattr
	wave/t fadcvalstr
	svar fdacKeys
	struct fdacChLists s

	// check that all DAC channels are on the same device
	variable numRampCh = itemsinlist(rampCh,","),i=0,j=0,dev_dac=0,dacCh=0,startCh=0
	variable numDevices = str2num(stringbykey("numDevices",fdacKeys,":",",")),numDACCh=0
	for(i=0;i<numRampCh;i+=1)
		dacCh = str2num(stringfromlist(i,rampCh,","))
		startCh = 0
		for(j=0;j<numDevices;j+=1)
			numDACCh = str2num(stringbykey("numDACCh"+num2istr(j),fdacKeys,":",","))
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
			for(j=0;j<numDevices;j+=1)
				numADCCh = str2num(stringbykey("numADCCh"+num2istr(j),fdacKeys,":",","))
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

function getfadcSpeed(instrID)
	// Returns speed in Hz (but arduino thinks in microseconds)
	variable instrID

	string response="", compare="", cmd=""

	cmd = "READ_CONVERT_TIME"
	response = remove_rn(queryInstr(instrID,cmd+",0\r",read_term="\n"))  // Get conversion time for channel 0 (should be same for all channels)
	if (numtype(str2num(response)) != 0)
		abort "[ERROR] \"getfadcSpeed\": device is not connected"
	endif
	variable i
	for(i=1;i<4;i+=1)
		compare = remove_rn(queryInstr(instrID,cmd+","+num2str(i)+"\r",read_term="\n"))
		if (cmpstr(compare, response) != 0) // Ensure ADC channels all have same conversion time
			print "WARNING: ADC channels have different conversion times!!!"
		endif
	endfor
	variable speed = 1/(str2num(response)*1e-6)  // Convert to Hz
	return speed
end

function setfadcSpeed(instrID,speed)
	// speed should be a number between 1-4.
	// slowest=1, medium=2, fast=3 and fastest=4
	variable instrID, speed
	make/n=3/o/free speeds = {372, 2008, 6060, 12195}  //These can be changed, but readfadcSpeed after to check exact frequency
	// check formatting of speed
	if(speed < 0 || speed > 4)
		print "[ERROR] \"setfadcSpeeed\": Speed must be integer between 1-4"
		abort
	endif

	string cmd = ""
	string response = ""
	variable i
	for (i=0;i<4;i++)
		sprintf cmd, "CONVERT_TIME,%d,%d\r", i, 1/(speeds[speed-1]*1e-6)  // Convert from Hz to microseconds
		response = queryInstr(instrID, cmd, read_term="\n")  //Set all channels at same time (generally good practise otherwise can't read from them at the same time)
		if (numtype(str2num(response) != 0))
			abort "[ERROR] \"setfadcSpeeed\": Bad response = " + response
		endif
	endfor
	//TODO:
	//updatewindow

end

function resetfdacwindow(fdacCh)
	variable fdacCh
	wave/t fdacvalstr, old_fdacvalstr

	fdacvalstr[fdacCh][1] = old_fdacvalstr[fdacCh]
end

function updatefdacWindow(fdacCh)
	variable fdacCh
	wave/t fdacvalstr, old_fdacvalstr
	print "Not implemented"

end


function fastdac_connected(deviceName)
	string deviceName
	nvar instrID = $deviceName
	if (check_fastdac_connected(instrID))
		return 1
	else
		sc_openinstrconnections(0)
		nvar instrID = $deviceName
		if (check_fastdac_connected(instrID))
			return 1
		else
			return 0
		endif
	endif
end

function check_fastdac_connected(instrID)
/// Returns 1 if connected, 0 if not
	variable instrID

	string response
	response = queryInstr(instrID, "*RDY?\r\n", read_term="\n")  //Check the fastdac responds at visa_handle
	response = remove_rn(response)
	if(cmpstr(response, "READY") == 0)
		return 1
	else
		return 0
	endif
end

function rampOutputfdac(instrID,channel,output,[ramprate, ignore_positive]) // Units: mV, mV/s
	// ramps a channel to the voltage specified by "output".
	// ramp is controlled locally on DAC controller.
	// channel must be the channel set by the GUI.
	// instrID not used, only here to maintain same format
	variable instrID, channel, output, ramprate, ignore_positive
	wave/t fdacvalstr, old_fdacvalstr
	svar fdackeys
	nvar fd_ramprate

	if(paramIsDefault(ramprate))
		ramprate = fd_ramprate
	endif

	///////////////// TEMPORARY 11/2/2020 TIM
	if(ignore_positive != 1)
		if (output > 100)
			resetfdacwindow(channel)
			abort "\"RampOutputFdac\": Trying to ramp > 100mV without ignore_positive flag set"
		endif
	endif
	////////////////////////////////

	variable numDevices = str2num(stringbykey("numDevices",fdackeys,":",","))
	variable i=0, devchannel = 0, startCh = 0, numDACCh = 0
	string deviceName = "", err = "", response= ""
	for(i=0;i<numDevices;i+=1)
		numDACCh =  str2num(stringbykey("numDACCh"+num2istr(i+1),fdackeys,":",","))
		if(startCh+numDACCh-1 >= channel)
			// this is the device, now check that instrID is pointing at the same device
			deviceName = stringbykey("name"+num2istr(i+1),fdackeys,":",",")
			if(fastdac_connected(deviceName))
				nvar visa_handle = $deviceName
				devchannel = channel-startCh  //The actual channel number on the specific board
			else
				sprintf err, "[ERROR] \"rampOutputfdac\": device %s is not connected (must be connected with its own name)", deviceName
				print(err)
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
	if(abs(output) > str2num(fdacvalstr[channel][2]))
		output = sign(output)*str2num(fdacvalstr[channel][2])
		string warn
		sprintf warn, "[WARNING] \"rampOutputfdac\": Output voltage must be within limit. Setting channel %d to %.3fmV", channel, output
		print warn
	endif

	// read current dac output and compare to window
	string cmd = ""
	response = ""
	sprintf cmd, "GET_DAC,%d", channel
	response = queryInstr(visa_handle, cmd+"\r", read_term="\n")
	response = remove_rn(response)
	variable initial = str2num(response)*1000  // Fastdac returns value in Volts not mV
	if(numtype(initial) == 0)
		// good response
		if(abs(initial-str2num(old_fdacvalstr[channel]))<1)
			// no discrepancy
		else
			sprintf warn, "[WARNING] \"rampOutputfdac\": Actual output of channel %d is different than expected", channel
			print warn
		endif
	else
		sprintf err, "[ERROR] \"rampOutputfdac\": Bad response in GET_DAC!"
		print err
		resetfdacwindow(channel)
		abort
	endif


	// Ramp the fastdac
	cmd = ""
	response = ""
	sprintf cmd, "RAMP_SMART,%d,%.4f,%.3f", channel, output, ramprate
	variable delay = abs(output-initial)/ramprate
	writeinstr(visa_handle, cmd+"\r")//Delay the expected amount of time
	if (delay > 2)
		string msg
		sprintf msg, "Waiting for fastdac Ch%d to ramp to %dmV", channel, output
		sleep/S/C=6/Q/M=msg delay
	else
		sleep/s delay
	endif
	response = readInstr(visa_handle, read_term = "\n")
//	response = queryInstr(visa_handle, cmd+"\r", read_term="\n", delay=abs(output-initial)/ramprate) //Delay the expected amount of time
	response = remove_rn(response)
	if(cmpstr(response, "RAMP_FINISHED") == 0)
		// good response so update values in strings
		fdacvalstr[channel][1] = num2str(output)
		old_fdacvalstr[channel] = fdacvalstr[channel][1]
	else
		sprintf err, "[ERROR] \"rampOutputfdac\": Bad response! %s", response
		print err
		resetfdacwindow(channel)
		abort
	endif
end

function readfadcChannel(instrID,channel) // Units: mV
	// channel must be the channel number given by the GUI!
	// instrID not used, only here to maintain same format
	variable instrID, channel
	wave/t fadcvalstr
	svar fdackeys

	variable numDevices = str2num(stringbykey("numDevices",fdackeys,":",","))
	variable i=0, devchannel = 0, startCh = 0, numADCCh = 0
	string deviceName = "", err = "", response = ""
	for(i=0;i<numDevices;i+=1)
		numADCCh = str2num(stringbykey("numADCCh"+num2istr(i+1),fdackeys,":",","))
		if(startCh+numADCCh-1 >= channel)
			// this is the device, now check that instrID is pointing at the same device
			deviceName = stringbykey("name"+num2istr(i+1),fdackeys,":",",")
			if(fastdac_connected(deviceName))
				nvar visa_handle = $deviceName
				devchannel = channel-startCh  //The actual channel number on the specific board
			else
				sprintf err, "[ERROR] \"readfdacChannel\": device %s is not connected (must be connected with its own name)", deviceName
				print(err)
				abort
			endif
		endif
		startCh =+ numADCCh
	endfor

	// query ADC
	string cmd = "GET_ADC," + num2str(devchannel)
	response = ""
	response = queryInstr(visa_handle, cmd+"\r", read_term="\n")
	response = remove_rn(response)
	if(	numtype(str2num(response)) == 0)
		// good response, update window
		fadcvalstr[channel][1] = num2str(str2num(response)) // in Volts not mV
		return str2num(response)*1000
	else
		sprintf err, "[ERROR] \"readfadcChannel\": Bad response! %s", response
		print err
		abort
	endif
end

function initFastDAC()
	// use the key:value list "fdackeys" to figure out the correct number of
	// DAC/ADC channels to use. "fdackeys" is created when calling "openFastDACconnection".
	svar fdackeys
	if(!svar_exists(fdackeys))
		print("[ERROR] \"initFastDAC\": No devices found!")
		abort
	endif

	// hardware limit (mV)
	variable/g fdac_limit = 10000
	variable/g fd_ramprate = 1000

	variable i=0, numDevices = str2num(stringbykey("numDevices",fdackeys,":",","))
	variable numDACCh=0, numADCCh=0
	for(i=0;i<numDevices+1;i+=1)
		if(cmpstr(stringbykey("name"+num2istr(i+1),fdackeys,":",","),"")!=0)
			numDACCh += str2num(stringbykey("numDACCh"+num2istr(i+1),fdackeys,":",","))
			numADCCh += str2num(stringbykey("numADCCh"+num2istr(i+1),fdackeys,":",","))
		endif
	endfor

	// create waves to hold control info
	fdacCheckForOldInit(numDACCh,numADCCh)

	variable/g num_fdacs = 0

	// create GUI window
	string cmd = ""
	killwindow/z ScanControllerFastDAC
	sprintf cmd, "FastDACWindow()"
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
		endif
	else
		// Init to default values
		fdacCreateControlWaves(numDACCh,numADCCh)
	endif
end

function fdacAskUser(numDACCh)
	variable numDACCh
	wave/t fdacvalstr

	// can only init to old settings if the same
	// number of DAC channels are used
	if(dimsize(fdacvalstr,0) == numDACCh)
		make/o/t/n=(numDACCh) fdacdefaultinit
		duplicate/o/rmd=[][1] fdacvalstr ,fdacvalsinit
		concatenate/o {fdacdefaultinit,fdacvalsinit}, fdacinit
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

window FastDACWindow() : Panel
	PauseUpdate; Silent 1 // pause everything else, while building the window
	NewPanel/w=(0,0,790,570)/n=ScanControllerFastDAC // window size
	ModifyPanel/w=ScanControllerFastDAC framestyle=2, fixedsize=1
	SetDrawLayer userback
	SetDrawEnv fsize=25, fstyle=1
	DrawText 130, 45, "DAC"
	SetDrawEnv fsize=25, fstyle=1
	DrawText 516, 45, "ADC"
	DrawLine 315,15,315,385
	DrawLine 10,385,780,385
	SetDrawEnv dash=7
	Drawline 325,295,780,295
	// DAC, 12 channels shown
	SetDrawEnv fsize=14, fstyle=1
	DrawText 15, 70, "Ch"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 50, 70, "Output (mV)"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 140, 70, "Limit (mV)"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 213, 70, "Label"
	ListBox fdaclist,pos={10,75},size={290,270},fsize=14,frame=2,widths={35,90,75,70}
	ListBox fdaclist,listwave=root:fdacvalstr,selwave=root:fdacattr,mode=1
	Button fdacramp,pos={50,354},size={65,20},proc=update_fdac,title="Ramp"
	Button fdacrampzero,pos={170,354},size={90,20},proc=update_fdac,title="Ramp all 0"
	// ADC, 8 channels shown
	SetDrawEnv fsize=14, fstyle=1
	DrawText 330, 70, "Ch"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 390, 70, "Input (V)"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 480, 70, "Record"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 540, 70, "Wave Name"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 650, 70, "Calc Function"
	ListBox fadclist,pos={325,75},size={450,180},fsize=14,frame=2,widths={35,90,45,90,90}
	ListBox fadclist,listwave=root:fadcvalstr,selwave=root:fadcattr,mode=1
	button updatefadc,pos={325,265},size={90,20},proc=update_fadc,title="Update ADC"
	checkbox sc_PrintfadcBox,pos={425,265},proc=sc_CheckBoxClicked,value=sc_Printfadc,side=1,title="\Z14Print filenames "
	checkbox sc_SavefadcBox,pos={545,265},proc=sc_CheckBoxClicked,value=sc_Saverawfadc,side=1,title="\Z14Save raw data "
	popupMenu fadcSetting1,pos={380,300},proc=update_fadcSpeed,mode=1,title="\Z14ADC1 speed",size={100,20},value="Slow;Medium;Fast;Fastest"
	popupMenu fadcSetting2,pos={580,300},proc=update_fadcSpeed,mode=1,title="\Z14ADC2 speed",size={100,20},value="Slow;Medium;Fast;Fastest"
	popupMenu fadcSetting3,pos={380,330},proc=update_fadcSpeed,mode=1,title="\Z14ADC3 speed",size={100,20},value="Slow;Medium;Fast;Fastest"
	popupMenu fadcSetting4,pos={580,330},proc=update_fadcSpeed,mode=1,title="\Z14ADC4 speed",size={100,20},value="Slow;Medium;Fast;Fastest"
	popupMenu fadcSetting5,pos={380,360},proc=update_fadcSpeed,mode=1,title="\Z14ADC5 speed",size={100,20},value="Slow;Medium;Fast;Fastest"
	popupMenu fadcSetting6,pos={580,360},proc=update_fadcSpeed,mode=1,title="\Z14ADC6 speed",size={100,20},value="Slow;Medium;Fast;Fastest"

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
	variable num
	if(s.eventcode == 2)
		// a menu item has been selected
		strswitch(s.ctrlname)
			case "fadcSetting1":
				num = 1
				break
			case "fadcSetting2":
				num = 2
				break
			case "fadcSetting3":
				num = 3
				break
			case "fadcSetting4":
				num = 4
				break
			case "fadcSetting5":
				num = 5
				break
			case "fadcSetting6":
				num = 6
				break
		endswitch

		svar fdackeys
		string deviceName
		deviceName = stringbykey("name"+num2istr(num),fdackeys,":",",")
		if(fastdac_connected(deviceName))
			nvar instrID = $deviceName
		else
			abort "[ERROR]\"update_fadcSpeed\": Device not connected"
		endif
		setfadcSpeed(instrID,s.popnum)
		return 0
	else
		// do nothing
		return 0
	endif
end

function update_fdac(action) : ButtonControl
	string action
	svar fdackeys
	nvar fd_ramprate
	wave/t fdacvalstr
	wave/t old_fdacvalstr

	// open temporary connection to FastDACs
	// and update values if needed
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
				strswitch(action)
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
				endswitch
			catch
				// reset error code, so VISA connection can be closed!
				variable err = GetRTError(1)

				viClose(tempname)
				viClose(viRM)
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
					readfadcChannel(tempname,startCh+j)
				endfor
			catch
				// reset error
				variable err = GetRTError(1)

				viClose(tempname)
				viClose(viRM)
				// silent abort
				abortonvalue 1,10
			endtry

			// close temp visa connection
			viClose(tempname)
			viClose(viRM)
		endif
		startCh += numADCCh
	endfor
end

function fdacCreateControlWaves(numDACCh,numADCCh)
	variable numDACCh,numADCCh

	// create waves for DAC part
	make/o/t/n=(numDACCh) fdacval0 = ""  		// Channel
	make/o/t/n=(numDACCh) fdacval1 = "0"  		// Output/mV
	make/o/t/n=(numDACCh) fdacval2 = "10000"  // Limit/mV
	make/o/t/n=(numDACCh) fdacval3 = ""  		// Label
	variable i=0
	for(i=0;i<numDACCh;i+=1)
		fdacval0[i] = num2istr(i)
	endfor
	concatenate/o {fdacval0,fdacval1,fdacval2,fdacval3}, fdacvalstr
	make/o/n=(numDACCh) fdacattr0 = 0
	make/o/n=(numDACCh) fdacattr1 = 2
	concatenate/o {fdacattr0,fdacattr1,fdacattr1,fdacattr1}, fdacattr

	make/t/o/n=(numDACCh) old_fdacvalstr = "0"

	//create waves for ADC part
	make/o/t/n=(numADCCh) fadcval0 = ""		// Channel
	make/o/t/n=(numADCCh) fadcval1 = ""		// Input
	make/o/t/n=(numADCCh) fadcval2 = ""		// Record
	make/o/t/n=(numADCCh) fadcval3 = ""		// Calc Wave Name
	make/o/t/n=(numADCCh) fadcval4 = ""		// Calc Script (Raw wave is ADC#)
	for(i=0;i<numADCCh;i+=1)
		fadcval0[i] = num2istr(i)
		fadcval3[i] = "wave"+num2istr(i)
	endfor
	concatenate/o {fadcval0,fadcval1,fadcval2,fadcval3,fadcval4}, fadcvalstr
	make/o/n=(numADCCh) fadcattr0 = 0
	make/o/n=(numADCCh) fadcattr1 = 2
	make/o/n=(numADCCh) fadcattr2 = 32
	concatenate/o {fadcattr0,fadcattr0,fadcattr2,fadcattr1,fadcattr1}, fadcattr


	variable/g sc_printfadc = 0
	variable/g sc_saverawfadc = 0

	// clean up
	killwaves fdacval0,fdacval1,fdacval2,fdacval3
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

function/t remove_rn(str)
	string str
//	str = removeleadingwhitespace(str)
//	str = removetrailingwhitespace(str)
	str = str[0,strlen(str)-3]  // To chop off last two characters (\r\n)
	return str
end


// Given two strings of length 1
//  - c1 (higher order) and
//  - c2 lower order
// Calculate effective FastDac value
// @optparams minVal, maxVal (units V)

function fdacChar2Num(c1, c2, [minVal, maxVal])
	// converts byts to Volts (not mV) because most measurements are in V.
	string c1, c2
	variable minVal, maxVal
	// Set default values for minVal & maxVal
	if(paramisdefault(minVal))
		minVal = -10
	endif

	if(paramisdefault(maxVal))
		maxVal = 10
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


function clear_buffer(instrID)
	variable instrID
	variable count = 1
	string buffer
	do
		viRead(instrID, buffer, 20000, count)
	while (count != 0)
//	readinstr(instrID, read_bytes=20000)
	return count
end


function/s getfdacStatus(instrID)
	variable instrID
	wave /t fdacvalstr = fdacvalstr
	svar fdackeys

	variable numdacs = dimsize(fdacvalstr, 0)
	variable i=0
	string buffer = ""
	for(i=0;i<numdacs;i+=1)
		buffer = addJSONkeyval(buffer, "CH"+fdacvalstr[i][0], fdacvalstr[i][1])
	endfor

	for(i=0;i<numdacs;i+=1)
		if (cmpstr(fdacvalstr[i][3], "")!=0)
			buffer = addJSONkeyval(buffer, "CH"+fdacvalstr[i][0]+"name", "\""+fdacvalstr[i][3]+"\"")
		endif
	endfor
	
	variable samplingfreq = getfadcspeed(instrID)
	buffer = addJSONkeyval(buffer, "SamplingFreq", num2str(samplingfreq))
	buffer = addJSONkeyval(buffer, "fdacKeys", "\""+fdackeys+"\"")  // TODO: Make this nicer, this is temporary way to get all data into json

	nvar hdf5_id
	HDF5SaveData /IGOR=-1 /WRIT=1 /Z fdacvalstr , hdf5_id//Saving full fdacvalstr text wave so it can easily be loaded from hdf5 later

	return addJSONkeyval("", "FastDAC", buffer)
end
