#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1	// Use modern global access method

// Driver communicates over serial.
// Procedure written by Christian Olsen 2017-03-15
// Updated to VISA by Christian Olsen, 2018-05-xx
// Nik -- Rewritten without window to handle an arbitrary number of 
//         LS controllers connected to the same system 01-XX-2019

// If you want to write a vector magnet driver, use this procedure to provide
//   communiction with the magnet supplies, write another procedure 
//   to handle GUI/axes/angles...

////////////////////////////
//// Lakeshore 625 COMM ////
////////////////////////////

function openLS625connection(instrVarName, visa_address, amps_per_tesla, max_field, max_ramprate, [verbose, hold])
	// instrID is the name of the global variable that will be used for communication
	// visa_address is the VISA address string, i.e. ASRL1::INSTR
	// hold is not used here, it is included to match the IPS driver
	
	/////   amps_per_tesla, max_field, max_ramprate /////
	/////        in A/T, mT, mT/min
	// LD50 (AMI vector):
	//    x -- 55.4939, 1000, 154.287
	//    y -- 55.2181, 1000, 155.058
	//    z -- 9.95025, 6000, 1159.57
	
	
	//////////////////////////////////////////////////////////////////////////////////
	//// This part is added my Manab : XLD system AMI magnet specifications
	/////////////////////////////////////////////////////////////////////////////////
	////Rated operating current = 86.13 Amperes
	/// Field to current ratio =1.045 kG/Ampere
	/// Ramp rate (0 to 55kG) = 0.058 Ampere/second
	/// Ramp rate (55kG to 80kG) = 0.029 Ampere/second
	/// Ramp rate (80kG to 90kG) = 0.014 Ampere/second
	//////////Performance test result////////////////
	//// Sweep rate used: 0 to 8T: 100 mT/min
	/// Sweep rate used: 8 to 9T: 87.78 mT/min
	
	
	//// amps_per_tesla, max_field, max_ramprate////
	///////   in A/T, mT, mT/min
	///// z -- 9.57 , 9000, 362
	
	
	string instrVarName, visa_address
	variable amps_per_tesla, max_field, max_ramprate, verbose, hold
	
	if(paramisdefault(verbose))
		verbose=1
	elseif(verbose!=1)
		verbose=0
	endif
	
	variable localRM
	variable status = viOpenDefaultRM(localRM) // open local copy of resource manager
	if(status < 0)
		VISAerrormsg("open LS625 connection:", localRM, status)
		abort
	endif
	
	string comm = ""
	sprintf comm, "name=LS625,instrID=%s,visa_address=%s" instrVarName, visa_address
//	string options = "baudrate=57600,databits=7,stopbits=1,parity=1,test_query=*IDN?"
	string options = "test_query=*IDN?"	

	openVISAinstr(comm, options=options, localRM=localRM, verbose=verbose)

	nvar localID = $(instrVarName)
	
	svar/z ls625_names
	if(!svar_exists(ls625_names))
		string /g ls625_names = AddListItem(instrVarName, "")
		string /g ls625_visaIDs =AddListItem(num2istr(localID), "")
	else
		svar ls625_visaIDs
		variable idx = WhichListItem(instrVarName, ls625_names) // lookup name
		if(idx>-1)
			// found an instrument with that name
			// replace the visaID value in the other list
			ls625_visaIDs = RemoveListItem(idx, ls625_visaIDs)
			ls625_visaIDs = AddListItem(num2istr(localID), ls625_visaIDs, ";", idx)
		else
			// this is a new variable name
			// add additional entries to both lists
			ls625_names = AddListItem(instrVarName, ls625_names)
			ls625_visaIDs = AddListItem(num2istr(localID), ls625_visaIDs)
		endif
	endif
	
	variable /g $("amps_per_tesla_"+instrVarName) = amps_per_tesla
	variable /g $("max_field_"+instrVarName) = max_field
	variable /g $("max_ramprate_"+instrVarName) = max_ramprate

end

function /s ls625_lookupVarName(instrID)
	variable instrID
	
	svar ls625_names, ls625_visaIDs
	variable idx = WhichListItem(num2istr(instrID), ls625_visaIDs)
	if(idx>-1)
		return StringFromList(idx, ls625_names)
	else
		abort "[ERROR]: Could not find global variables matching ls625 instrument name"
	endif
		
end

////////////////////////
//// Get functions ////
///////////////////////

threadsafe function getLS625current(instrID) // Units: A
	variable instrID
	variable current

	current = str2num(queryInstr(instrID,"RDGI?\r\n"))//, read_term = "\r\n"))
	
	return current
end

function getLS625field(instrID) // Units: mT
	variable instrID
	nvar apt = $("amps_per_tesla_"+ls625_lookupVarName(instrID))
	variable field, current
	
	current = getLS625current(instrID)
	field = roundNum(current/apt*1000,5)

	return field
end

function getLS625rate(instrID) // Units: mT/min
	variable instrID
	nvar apt = $("amps_per_tesla_"+ls625_lookupVarName(instrID))
	wave/t sweepratevalstr
	variable rampratefield, currentramprate
	svar instrDescX,instrDescZ

	currentramprate = str2num(queryInstr(instrID,"RATE?\r\n"))//, read_term = "\r\n")) // A/s
	rampratefield = roundNum(currentramprate/apt*60*1000,5)

	return rampratefield
end

function getLS625rampStatus(instrID)
	variable instrID
	string response
	variable ramping

	response = queryInstr(instrID,"OPST?\r\n")//,read_term = "\r\n")
	if(str2num(response) == 6)
		ramping = 0
	else
		ramping = 1
	endif

	return ramping
end

////////////////////////
//// Set functions ////
//////////////////////

function setLS625current(instrID,output) // Units: A
	variable instrID,output
	string cmd
	nvar maxf = $("max_field_"+ls625_lookupVarName(instrID))
	nvar apt = $("amps_per_tesla_"+ls625_lookupVarName(instrID))
	
	// check for NAN and INF
	if(numtype(output) != 0)
		abort "trying to set output to NaN or Inf"
	endif


	if (abs(output) > maxf*apt/1000)
		print "Max current is "+num2str(maxf*apt/1000)+" A"
	else
		cmd = "SETI "+num2str(output, "%.15f")  // Ensure does not send e.g. "1e-4" instead of "0.0001"
		writeInstr(instrID, cmd+"\r\n")
	endif
	
end

function setLS625field(instrID,output) // Units: mT
	variable instrID, output
	nvar maxf = $("max_field_"+ls625_lookupVarName(instrID))
	nvar apt = $("amps_per_tesla_"+ls625_lookupVarName(instrID))
	variable round_amps
	string cmd

	if (abs(output) > maxf)
		print "Max field is "+num2str(maxf)+" mT"
		return 0
	else
		round_amps = roundNum(output*apt/1000,5)
		setLS625current(instrID,round_amps)
		return 1
	endif
end

function setLS625fieldWait(instrID,output, [short_wait])
	// Set short_wait = 1 if you want the waiting to be a very tight loop (i.e. Useful if trying to ramp very short distances quickly)
	variable instrID, output, short_wait
//	print("Going to field")
//	print(output)
	setLS625field(instrID,output)
	variable start_time = stopmsTimer(-2)
	do
		if (short_wait)
			asleep(0.1)
		else
			asleep(2.1) // Over 2s makes the waiting abortable
		endif
	while(getLS625rampStatus(instrID) && (stopmstimer(-2)-start_time) < 3600e6)  //Max wait for an hour
end

function setLS625rate(instrID,output) // Units: mT/min
	variable instrID, output
	nvar maxrr = $("max_ramprate_"+ls625_lookupVarName(instrID))
	nvar apt = $("amps_per_tesla_"+ls625_lookupVarName(instrID))
	variable ramprate_amps, actual_ramprate_mTmin
	string cmd
	
	// check for NAN and INF
	if(numtype(output) != 0)
		abort "trying to set ramp rate to NaN or Inf"
	endif


	if (output < 0 || output > maxrr)
		print "Max sweep rate is "+num2str(maxrr)+" mT/min"
		return 0
	else
	 	// LS625 Specs from datasheet: Ramp rate	0.1 mA/s to 99.999 A/s
	 	ramprate_amps = output*(apt/(1000*60))
		ramprate_amps = roundNum(ramprate_amps, 4) // A/s  (4 d.p. is max precision)
		if (ramprate_amps == 0)
			printf "WARNING: Desired ramprate is too small, setting to minimum ramprate of 0.0001 A/s\n"
			ramprate_amps = 0.0001
		endif
		actual_ramprate_mTmin = ramprate_amps/(apt/(1000*60))
		if (abs(actual_ramprate_mTmin/output - 1) > 0.1)
			printf "WARNING: Actual ramprate (%.5f mT/min) deviates by more than 10%% from desired ramprate (%.5f mT/min)\n" actual_ramprate_mTmin, output 
		endif
		
		cmd = "RATE "+num2str(ramprate_amps, "%.4f")  // Ensure does not send e.g. "1e-4" instead of "0.0001"
		writeInstr(instrID,cmd+"\r\n")
		return 1
	endif
	
end

//////////////////
//// Logging /////
//////////////////

function/s GetLS625Status(instrID)
	variable instrID
	string buffer = ""

	buffer = addJSONkeyval(buffer, "variable name", ls625_lookupVarName(instrID), addquotes=1)
	buffer = addJSONkeyval(buffer, "field mT", num2str(getLS625field(instrID)))
	buffer = addJSONkeyval(buffer, "rate mT/min", num2str(getLS625rate(instrID)))

	return addJSONkeyval("", "LS625 Magnet Supply", buffer)
end
