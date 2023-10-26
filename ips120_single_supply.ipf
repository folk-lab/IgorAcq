#pragma rtGlobals=1		// Use modern global access method.

//	Currents are returned in amps, while field values are return in mT
//	Procedure written by Christian Olsen 2016-01-26
// Updated to use VISA/async Nik/Christian 05-XX-2018
// Nik -- Rewritten without window to handle an arbitrary number of IPS controllers connected to the same system 01-XX-2019

/////////////////////////
/// IPS specific COMM ///
/////////////////////////

function openIPS120connection(instrVarName, visa_address, amps_per_tesla, max_field, max_ramprate, [verbose, hold])
	// instrID is the name of the global variable that will be used for communication
	// visa_address is the VISA address string, i.e. ASRL1::INSTR
	// verbose=0 will not print any information about the connection
	// hold=1 will put the magnet into hold mode when this command is run
	//     this is only necessary when first turning on the magnet to unclamp the output

	/////   amps_per_tesla, max_field, max_ramprate /////
	/////        in A/T, mT, mT/min
	// 			BFXLD 3" magnet
	//      		 z -- 9.569, 9000, 182

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
		VISAerrormsg("open IPS120 connection:", localRM, status)
		abort
	endif

	string comm = ""
	sprintf comm, "name=IPS120,instrID=%s,visa_address=%s" instrVarName, visa_address

	openVISAinstr(comm, localRM=localRM, verbose=verbose)
	nvar localID = $(instrVarName)

	svar/z ips120_names
	if(!svar_exists(ips120_names))
		string /g ips120_names = AddListItem(instrVarName, "")
		string /g ips120_visaIDs =AddListItem(num2istr(localID), "")
	else
		svar ips120_visaIDs
		variable idx = WhichListItem(instrVarName, ips120_names) // lookup name
		if(idx>-1)
			// found an instrument with that name
			// replace the visaID value in the other list
			ips120_visaIDs = RemoveListItem(idx, ips120_visaIDs)
			ips120_visaIDs = AddListItem(num2istr(localID), ips120_visaIDs, ";", idx)
		else
			// this is a new variable name
			// add additional entries to both lists
			ips120_names = AddListItem(instrVarName, ips120_names)
			ips120_visaIDs = AddListItem(num2istr(localID), ips120_visaIDs)
		endif
	endif

	variable /g $("amps_per_tesla_"+instrVarName) = amps_per_tesla
	variable /g $("max_field_"+instrVarName) = max_field
	variable /g $("max_ramprate_"+instrVarName) = max_ramprate

	// a few quick setup commands to make sure this is in the right mode(s)
	writeIPScheck(localID, "C3\r") // Remote and unlocked
	sc_sleep(0.02)
	writeIPScheck(localID, "M9\r") // Set display to Tesla
	writeInstr(localID, "Q4\r")    // Use extented resolusion (0.0001 amp/0.01 mT), no response from magnet

	if(!paramisdefault(hold) && hold==1)
		writeIPScheck(localID, "A0\r") // Set to Hold
	endif

end

function /s ips120_lookupVarName(instrID)
	variable instrID
	
	svar ips120_names, ips120_visaIDs
	variable idx = WhichListItem(num2istr(instrID), ips120_visaIDs)
	if(idx>-1)
		return StringFromList(idx, ips120_names)
	else
		abort "[ERROR]: Could not find global variables matching ips120 instrument name"
	endif
		
end

function writeIPScheck(instrID, cmd)	// Checks response for error
	variable instrID
	string cmd

	string response = queryInstr(instrID, cmd, read_term = "\r")
	if (cmpstr(response[0],"?") == 0)
		printf "[WARNING] IPS command did not execute correctly: %s\r", cmd
	endif
end

///////////////////////
//// Get functions ////
///////////////////////

threadsafe function getIPS120volts(instrID) // return in A
	variable instrID
	string buffer = queryInstr(instrID, "R1\r", read_term = "\r")[1,inf] // get value

	return str2num(buffer)
end

threadsafe function getIPS120current(instrID) // return in A
	variable instrID

	variable current = str2num(queryInstr(instrID, "R0\r", read_term = "\r")[1,inf]) // get value

	return current
end

function getIPS120field(instrID) // return in mT
	variable instrID
	nvar apt = $("amps_per_tesla_"+ips120_lookupVarName(instrID))
	variable current,field

	current = str2num(queryInstr(instrID, "R0\r", read_term = "\r")[1,inf]) // get current
	field = roundNum(current/apt*1000,2) // calculate field

	return field
end

function getIPS120rate(instrID) // returns in mT/min
	variable instrID
	variable ramprate_amps,ramprate_field
	nvar apt = $("amps_per_tesla_"+ips120_lookupVarName(instrID))

	ramprate_amps = str2num(queryInstr(instrID, "R6\r", read_term = "\r")[1,inf])
	ramprate_field = roundNum(ramprate_amps/apt*1000,0)
	return ramprate_field
end

function getIPS120rate_current(instrID) // returns in A/min
   variable instrID
   variable ramprate_amps,ramprate_field
	nvar apt = $("amps_per_tesla_"+ips120_lookupVarName(instrID))
	
	ramprate_amps = str2num(queryInstr(instrID, "R6\r", read_term = "\r")[1,inf])
	ramprate_field = roundNum(ramprate_amps/apt*1000,0)
	
	return ramprate_amps
end

function /s getIPS120status(instrID)
	variable instrID
	string status

	writeInstr(instrID, "X\r")
	status = readInstr(instrID, read_term = "\r")
	return status
end

function getIPS120HeaterStatus(instrID)
    variable instrID
	string status
	status = getIPS120status(instrID)
	return str2num(status[8])
end

///////////////////////
//// Set functions ////
///////////////////////

function setIPS120current(instrID, amps) // in A
	variable instrID, amps
	nvar maxf = $("max_field_"+ips120_lookupVarName(instrID))
	nvar apt = $("amps_per_tesla_"+ips120_lookupVarName(instrID))

	// check for NAN and INF
	if(numtype(amps) != 0)
		abort "trying to set output to NaN or Inf"
	endif

	if (abs(amps) > maxf*apt/1000)
		print "Magnet current not set, exceeds limit: "+num2str(maxf*apt/1000)+"A"
		return -1
	else
		writeIPScheck(instrID, "I"+num2str(amps)+"\r")
		writeInstr(instrID, "$A1\r")
	endif
end

function setIPS120field(instrID, field) // in mT
	variable instrID, field
	nvar maxf = $("max_field_"+ips120_lookupVarName(instrID))
	nvar apt = $("amps_per_tesla_"+ips120_lookupVarName(instrID))
	variable amps

	// check for NAN and INF
	if(numtype(field) != 0)
		abort "trying to set output to NaN or Inf"
	endif

	if (abs(field) > maxf)
		print "Magnet current not set, exceeds limit: "+num2str(maxf)+"mT"
		return -1
	else
		amps = roundNum(field*apt/1000,4)
		writeIPScheck(instrID, "I"+num2str(amps)+"\r")
		writeInstr(instrID, "$A1\r")
		return 1
	endif
end

function setIPS120rate(instrID, ramprate) // mT/min
	variable instrID, ramprate
	nvar maxrr = $("max_ramprate_"+ips120_lookupVarName(instrID))
	nvar apt = $("amps_per_tesla_"+ips120_lookupVarName(instrID))
	variable ramprate_amps

	// check for NAN and INF
	if(numtype(ramprate) != 0)
		abort "trying to set ramp rate to NaN or Inf"
	endif

	if (ramprate < 0 || ramprate > maxrr)
		print "Max sweep rate is "+num2str(maxrr)+" mT/min"
		return -1
	else
		ramprate_amps = roundNum(ramprate*apt/1000,3)
		writeIPScheck(instrID, "S"+num2str(ramprate_amps)+"\r")
		return 1
	endif

end

function setIPS120switchHeater(instrID, newstate) // Call with "ON" or "OFF"
	variable instrID
	string newstate
	string oldstate
	variable heaterstate

	heaterstate = getIPS120HeaterStatus(instrID)

	if (heaterstate == 5)
		print "Heater error"
		return -1
	endif

	variable start_time = datetime
	strswitch(newstate)
		case "ON":
			if (heaterstate == 0)
				writeIPScheck(instrID, "H1"+"\r")
				print "waiting 20 sec for heater to respond"
				do
					sleep /T 1
				while(datetime - start_time < 20.0)
			elseif (heaterstate == 1)
				print "Heater already on"
			else
				printf "Heater state is H%d, check manual",heaterstate
			endif
			break
		case "OFF":
			if (heaterstate == 0)
				print "Heater already off"
			elseif (heaterstate == 1)
				writeIPScheck(instrID, "H0\r")
				print "waiting 20 sec for heater to respond"
				do
					sleep /T 1
				while(datetime - start_time < 20.0)
			else
				printf "Heater state is H%d, check manual",heaterstate
			endif
			break
		default:
			printf "Command: (%s) not understood. Pass ON or OFF",newstate
			break
	endswitch
end

function setIPS120fieldWait(instrID, field) // in mT
	// Setting new set point and waiting for magnet to reach new set point
	variable instrID, field
	variable status, count = 0

	setIPS120field(instrID, field)
//	asleep(10)
	do
		do
			asleep(1)
			//getIPS120field(instrID) // forces the window to update
			status = str2num(queryInstr(instrID, "X\r", read_term = "\r")[11])
		while(numtype(status)==2)

	while(status!=0)
end

////////////////////////////
//// Status for logging ////
////////////////////////////

function/s GetIPSStatus(instrID)
	variable instrID
	string buffer = ""
	buffer = addJSONkeyval(buffer, "field mT", num2str(getIPS120field(instrID)))
	buffer = addJSONkeyval(buffer, "rate mT/min", num2str(getIPS120rate(instrID)))
	buffer = addJSONkeyval(buffer, "com_port", getResourceAddress(instrID), addQuotes=1)
	return addJSONkeyval("", "IPS", buffer)
end
