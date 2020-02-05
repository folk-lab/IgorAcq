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

function fdacRecordValues(instrID,rowNum,rampCh,start,fin,numpts,[ramprate,RCcutoff,numAverage,notch])
	// RecordValues for FastDAC's. This function should replace RecordValues in scan functions.
	// j is outer scan index, if it's a 1D scan just set j=0.
	// rampCh is a comma seperated string containing the channels that should be ramped.
	// Data processing:
	// 		- RCcutoff set the lowpass cutoff frequency
	//		- average set the number of points to average
	//		- nocth sets the notch frequencie, as a comma seperated list (width is fixed at 5Hz)
	variable instrID, rowNum
	string rampCh, start, fin
	variable numpts, ramprate, RCcutoff, numAverage
	string notch
	nvar sc_is2d, sc_startx, sc_starty, sc_finx, sc_starty, sc_finy, sc_numptsx, sc_numptsy
	nvar sc_abortsweep, sc_pause, sc_scanstarttime
	wave/t fadcvalstr
	wave fadcattr
	
	if(paramisdefault(ramprate))
		ramprate = 500
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
	
	variable dev_adc=0
	dev_adc = sc_fdacSortChannels(rampCh,start,fin)
	struct fdacChLists scanList
	
	// move DAC channels to starting point
	variable i=0
	for(i=0;i<itemsinlist(scanList.daclist,",");i+=1)
		rampOutputfdac(instrID,str2num(stringfromlist(i,scanList.daclist,",")),str2num(stringfromlist(i,scanList.startVal,",")),ramprate=ramprate)
	endfor
	
	// build command and start ramp
	// for now we only have to send one command to one device.
	string cmd = ""
	sprintf cmd, "BUFFERRAMP %s,%s,%s,%s ...\r", scanList.daclist, scanList.startVal, scanList.finVal, scanlist.adclist //FIX
	writeInstr(instrID,cmd)
	
	// read returned values
	variable totalByteReturn = itemsinlist(scanList.adclist,",")*numpts,read_chunk=0
	if(totalByteReturn > 500)
		read_chunk = 500
	else
		read_chunk = totalByteReturn
	endif
	
	// make temp wave to hold incomming data chunks
	// and distribute to data waves
	string buffer = ""
	variable bytes_read = 0
	do
		buffer = readInstr(instrID,read_bytes=read_chunk)
		// add data to rawwaves and datawaves
		sc_distribute_data(buffer,scanList.adclist,read_chunk,rowNum,bytes_read)
		bytes_read += read_chunk
	while(totalByteReturn-bytes_read > read_chunk)
	// do one last read if any data left to read
	variable bytes_left = totalByteReturn-bytes_read
	if(bytes_left > 0) 
		buffer = readInstr(instrID,read_bytes=bytes_left)
		sc_distribute_data(buffer,scanList.adclist,read_chunk,rowNum,bytes_read)
	endif
	
	// read sweeptime
	variable sweeptime = 0
	buffer = readInstr(instrID,read_bytes=10) // FIX read_bytes
	sweeptime = str2num(buffer)
	
	/////////////////////////
	//// Post processing ////
	/////////////////////////
	
	variable samplingFreq=0
	samplingFreq = getfadcSpeed(instrID)
	
	string warn = ""
	variable doLowpass=0,cutoff_frac=0
	if(!paramisdefault(RCcutoff))
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
	if(!paramisdefault(notch))
		// add notch filter(s)
		doNotch = 1
		numNotch = itemsinlist(notch,",")
		for(i=0;i<numNotch;i+=1)
			notch_fracList = addlistitem(num2str(str2num(stringfromlist(i,notch,","))/samplingFreq),notch_fracList,",",itemsinlist(notch_fracList))
		endfor
	endif
	
	variable doAverage=0
	if(!paramisdefault(numAverage))
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
		sc_averageDataWaves(numAverage)
	endif
	
	return sweeptime
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
	
	variable i=0, j=0, numADCCh = itemsinlist(adcList,","), adcIndex=0, dataPoint=0
	// load data into raw wave
	for(i=0;i<numADCCh;i+=1)
		adcIndex = str2num(stringfromlist(i,adcList,","))
		wave rawwave = $"ADC"+num2istr(str2num(stringfromlist(i,adcList,",")))
		for(j=0;j<bytes;j+=1)
			dataPoint = str2num(stringfromlist(i+j*numADCCh,buffer,","))
			rawwave[colNumStart+j][rowNum] = dataPoint
		endfor
	endfor
	
	// load calculated data into datawave
	string script="", cmd=""
	for(i=0;i<numADCCh;i+=1)
		adcIndex = str2num(stringfromlist(i,adcList,","))
		wave datawave = $fadcvalstr[adcIndex][3]
		script = trimstring(fadcvalstr[adcIndex][4])
		sprintf cmd, "datawave = %s", script
		execute/q/z cmd
		if(v_flag!=0)
			print "[WARNING] \"sc_distribute_data\": Wave calculation falied! Error: "+GetErrMessage(V_Flag,2)
		endif
	endfor
end

function sc_averageDataWaves(numAverage)
	variable numAverage
	
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
	variable instrID
	
	string response="",cmd=""
	
	cmd = "ADD REAL COMMAND"
	response = queryInstr(instrID,cmd,read_term="\r\n")
	return str2num(response)
end

function setfadcSpeed(instrID,speed) //FIX
	// speed should be a number between 1-3.
	// slow=1, fast=2 and fastest=3
	variable instrID, speed
	
	// check formatting of speed
	if(speed < 0 || speed > 3)
		print "[ERROR] \"setfadcSpeeed\": Speed must be integer between 1-3"
		abort
	endif
	
	string cmd = "ADD REAL COMMAND!"
	string response = queryInstr(instrID, cmd+"\r\n", read_term="\r\n")
	
	// check respose
	// not sure what to expect!
	if(1)
		// update window
	else
		string err
		sprintf err, "[ERROR] \"setfadcSpeed\": Bad response! %s", response
		print err
		abort
	endif
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

function rampOutputfdac(instrID,channel,output,[ramprate]) // Units: mV, mV/s
	// ramps a channel to the voltage specified by "output".
	// ramp is controlled locally on DAC controller.
	// channel must be the channel set by the GUI.
	variable instrID, channel, output, ramprate
	wave/t fdacvalstr, old_fdacvalstr
	svar fdackeys
	
	if(paramIsDefault(ramprate))
		ramprate = 500
	endif
	
	variable numDevices = str2num(stringbykey("numDevices",fdackeys,":",","))
	variable i=0, devchannel = 0, startCh = 0, numDACCh = 0
	string deviceName = "", err = ""
	for(i=0;i<numDevices;i+=1)
		numDACCh =  str2num(stringbykey("numADCCh"+num2istr(i+1),fdackeys,":",","))
		if(startCh+numDACCh-1 >= channel)
			// this is the device, now check that instrID is pointing at the same device
			deviceName = stringbykey("name"+num2istr(i+1),fdackeys,":",",")
			nvar visa_handle = $deviceName
			if(visa_handle == instrID)
				devchannel = startCh+numDACCh-channel
				break
			else
				sprintf err, "[ERROR] \"rampOutputfdac\": channel %d is not present on device %s", channel, deviceName
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
	if(abs(output) > str2num(fdacvalstr[channel][2]))
		output = sign(output)*str2num(fdacvalstr[channel][2])
		string warn
		sprintf warn, "[WARNING] \"rampOutputfdac\": Output voltage must be within limit. Setting channel %d to %.3fmV", channel, output
		print warn
	endif
	
	// read current dac output and compare to window
	string cmd = "ADD REAL COMMAND!"
	string response
	response = queryInstr(instrID, cmd+"\r\n", read_term="\r\n")
	
	// check response
	// not sure what to expect!
	if(1)
		// good response
		if(abs(str2num(response)-str2num(old_fdacvalstr[channel][1]))<0.1)
			// no discrepancy
		else
			sprintf warn, "[WARNING] \"rampOutputfdac\": Actual output of channel %d is different than expected", channel
			print warn
		endif
	else
		sprintf err, "[ERROR] \"rampOutputfdac\": Bad response! %s", response
		print err
		resetfdacwindow(channel)
		abort
	endif
	
	// set ramprate
	cmd = "ADD REAL COMMAND!"
	response = queryInstr(instrID, cmd+"\r\n", read_term="\r\n")
	
	// check respose
	// not sure what to expect!
	if(1) 
		// not a good response
		sprintf err, "[ERROR] \"rampOutputfdac\": Bad response! %s", response
		print err
		resetfdacwindow(channel)
		abort
	endif
	
	// ramp channel to output
	cmd = "ADD REAL COMMAND!"
	response = queryInstr(instrID, cmd+"\r\n", read_term="\r\n")
	
	// check respose
	// not sure what to expect! if good update window
	if(1)
		fdacvalstr[channel][1] = num2str(output)
		updatefdacWindow(channel)
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
	string deviceName = "", err = ""
	for(i=0;i<numDevices;i+=1)
		numADCCh = str2num(stringbykey("numADCCh"+num2istr(i+1),fdackeys,":",","))
		if(startCh+numADCCh-1 >= channel)
			// this is the device, now check that instrID is pointing at the same device
			deviceName = stringbykey("name"+num2istr(i+1),fdackeys,":",",")

			nvar visa_handle = $deviceName
			if(numtype(visa_handle) == 0)
				devchannel = channel-startCh  //The actual channel number on the specific board
				break
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
	string response
	response = queryInstr(instrID, cmd+"\r\n", read_term="\r\n")

	if(	numtype(str2num(response)) == 0) 
		// good response, update window
		fadcvalstr[channel][1] = response
		return str2num(response)
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
	variable/g fdac_limit = 5000
	
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
	DrawText 370, 70, "Input (mV)"
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
	popupMenu fadcSetting1,pos={380,300},proc=update_fadcSpeed,mode=1,title="\Z14ADC1 speed",size={100,20},value="Slow;Fast;Fastest"
	popupMenu fadcSetting2,pos={580,300},proc=update_fadcSpeed,mode=1,title="\Z14ADC2 speed",size={100,20},value="Slow;Fast;Fastest"
	popupMenu fadcSetting3,pos={380,330},proc=update_fadcSpeed,mode=1,title="\Z14ADC3 speed",size={100,20},value="Slow;Fast;Fastest"
	popupMenu fadcSetting4,pos={580,330},proc=update_fadcSpeed,mode=1,title="\Z14ADC4 speed",size={100,20},value="Slow;Fast;Fastest"
	popupMenu fadcSetting5,pos={380,360},proc=update_fadcSpeed,mode=1,title="\Z14ADC5 speed",size={100,20},value="Slow;Fast;Fastest"
	popupMenu fadcSetting6,pos={580,360},proc=update_fadcSpeed,mode=1,title="\Z14ADC6 speed",size={100,20},value="Slow;Fast;Fastest"
	
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
	
	variable instrID
	if(s.eventcode == 2)
		// a menu item has been selected
		strswitch(s.ctrlname)
			case "fadcSetting1":
				nvar fdac1_addr
				instrID = fdac1_addr
				break
			case "fadcSetting2":
				nvar fdac2_addr
				instrID = fdac2_addr
				break
			case "fadcSetting3":
				nvar fdac3_addr
				instrID = fdac3_addr
				break
			case "fadcSetting4":
				nvar fdac4_addr
				instrID = fdac4_addr
				break
		endswitch
		
		setfadcSpeed(instrID,s.popnum)
		return 0
	else
		// do nothing
		return 0
	endif
end

function update_fdac(action) : ButtonControl //FIX
	string action
	svar fdackeys
	wave/t fdacvalstr
	wave/t old_fdacvalstr
	
	// open temporary connection to FastDACs
	// and update values if needed
	variable i=0,j=0,output = 0, numDACCh = 0, startCh = 0
	string visa_address = "", tempnamestr = "fdac_window_resource"
	variable numDevices = str2num(stringbykey("numDevices",fdackeys,":",","))
	for(i=0;i<numDevices;i+=1)
		numDACCh = str2num(stringbykey("numDACCh"+num2istr(i+1),fdackeys,":",","))
		if(numDACCh > 0)
			visa_address = stringbykey("visa"+num2istr(i+1),fdackeys,":",",")
			openFastDACconnection(tempnamestr, visa_address, verbose=0)
			nvar tempname = $tempnamestr
			try
				strswitch(action)
					case "ramp":
						for(j=0;j<numDACCh;j+=1)
							output = str2num(fdacvalstr[startCh+j][1])
							if(output != str2num(old_fdacvalstr[startCh+j][1]))
								rampOutputfdac(tempname,j,output,ramprate=500)
							endif
						endfor
						break
					case "rampallzero":
						for(j=0;j<numDACCh;j+=1)
							rampOutputfdac(tempname,j,0,ramprate=500)
						endfor
						break
				endswitch
			catch
				// reset error code, so VISA connection can be closed!
				variable err = GetRTError(1)
				
				viClose(tempname)
				// silent abort
				abortonvalue 1,10
			endtry
			
			// close temp visa connection
			viClose(tempname)
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
	variable numADCCh = 0, startCh = 0
	for(i=0;i<numDevices;i+=1)
		numADCCh = str2num(stringbykey("numADCCh"+num2istr(i+1),fdackeys,":",","))
		if(numADCCh > 0)
			visa_address = stringbykey("visa"+num2istr(i+1),fdackeys,":",",")
			openFastDACconnection(tempnamestr, visa_address, verbose=0)
			nvar tempname = $tempnamestr
			try
				for(j=0;j<numADCCh;j+=1)
					readfadcChannel(tempname,startCh+j)
				endfor
			catch
				// reset error
				variable err = GetRTError(1)
				
				viClose(tempname)
				// silent abort
				abortonvalue 1,10
			endtry
			
			// close temp visa connection
			viClose(tempname)
		endif
		startCh += numADCCh
	endfor
end

function fdacCreateControlWaves(numDACCh,numADCCh)
	variable numDACCh,numADCCh
	
	// create waves for DAC part
	make/o/t/n=(numDACCh) fdacval0 = "0"
	make/o/t/n=(numDACCh) fdacval1 = "0"
	make/o/t/n=(numDACCh) fdacval2 = "5000"
	make/o/t/n=(numDACCh) fdacval3 = "Label"
	variable i=0
	for(i=0;i<numDACCh;i+=1)
		fdacval0[i] = num2istr(i)
	endfor
	concatenate/o {fdacval0,fdacval1,fdacval2,fdacval3}, fdacvalstr
	make/o/n=(numDACCh) fdacattr0 = 0
	make/o/n=(numDACCh) fdacattr1 = 2
	concatenate/o {fdacattr0,fdacattr1,fdacattr1,fdacattr1}, fdacattr
	
	//create waves for ADC part
	make/o/t/n=(numADCCh) fadcval0 = "0"
	make/o/t/n=(numADCCh) fadcval1 = "0"
	make/o/t/n=(numADCCh) fadcval2 = ""
	make/o/t/n=(numADCCh) fadcval3 = ""
	make/o/t/n=(numADCCh) fadcval4 = ""
	for(i=0;i<numADCCh;i+=1)
		fadcval0[i] = num2istr(i)
		fadcval2[i] = "wave"+num2istr(i)
		fadcval4[i] = "ADC"+num2istr(i)
	endfor
	concatenate/o {fadcval0,fadcval1,fadcval2,fadcval3}, fadcvalstr
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
