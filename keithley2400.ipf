#pragma rtGlobals=1		// Use modern global access method

// Keithley 2400 driver
// Most be in 488.1 mode to function correctly!
// Voltages are in mV and Currents in nA
// By Christian Olsen, 2016-10-19
// Async supprt added by Christian Olsen, May 2018

//////////////////////////
///// COMM functions /////
//////////////////////////

function openK2400connection(instrID, visa_address, [verbose])
	// works for GPIB -- may need to add some more 'option' paramters if using serial
	//                -- does not hurt to send extra parameters when using GPIB, they are ignored
	// instrID is the name of the global variable that will be used for communication
	// visa_address is the VISA address string, i.e. GPIB0::23::INSTR
	
	string instrID, visa_address
	variable verbose
	
	if(paramisdefault(verbose))
		verbose=1
	elseif(verbose!=1)
		verbose=0
	endif
	
	variable localRM
	variable status = viOpenDefaultRM(localRM) // open local copy of resource manager
	if(status < 0)
		VISAerrormsg("open K2400 connection:", localRM, status)
		abort
	endif
	
	string comm = ""
	sprintf comm, "name=K2400,instrID=%s,visa_address=%s" instrID, visa_address
	string options = "test_query=*IDN?"
	openVISAinstr(comm, options=options, localRM=localRM, verbose=verbose)
	
end

///////////////////////
//// Set functions ////
//////////////////////

function setK2400Current(instrID,curr) //Units: nA
	variable instrID,curr
	string cmd
	
	// check for NAN and INF
	if(numtype(curr) != 0)
		abort "trying to set current to NaN or Inf"
	endif

	sprintf cmd, ":sour:func curr;:sour:curr:mode fix;:sour:curr:lev %.10f\n", curr*1e-9
	writeInstr(instrID,cmd)
end

function setK2400Voltage(instrID,volt) // Units: mV
	variable instrID,volt
	string cmd
	
	// check for NAN and INF
	if(numtype(volt) != 0)
		abort "trying to set voltage to NaN or Inf"
	endif
	
	sprintf cmd, ":sour:func volt;:sour:volt:mode fix;:sour:volt:lev %.10f\n", volt*1e-3
	writeInstr(instrID,cmd)
end

////////////////////////
//// Get functions ////
///////////////////////

threadsafe function getK2400current(instrID) // Units: nA
	variable instrID
	string response
	//response = queryInstr(instrID,":sens:func \"curr\";:form:elem curr\n",read_term="\n")
	writeInstr(instrID,":sens:func \"curr\";:form:elem curr\n")

	response = queryInstr(instrID,"READ?",read_term="\n")
	return str2num(response)*1e9
end

threadsafe function getK2400voltage(instrID) // Units: mV
	variable instrID
	string response

	writeInstr(instrID,":sens:func \"volt\";:form:elem volt\n")
	response = queryInstr(instrID,"READ?",read_term="\n")
	return str2num(response)*1e3
end

/////////////////////////
//// Ramp functions ////
///////////////////////

function rampMultipleK2400s(instrIDs, index, numpts, starts, fins, [ramprate])
	// Ramp multiple K2400s to respective start/end points 
	string instrIDs, starts, fins   // start/fin for each instrID (All "," separated lists with equal length)
	variable index   // What position on axis
	variable numpts  // Total numpts for axis
	variable ramprate
	
	checkStartsFinsChannels(starts, fins, instrIDs)  // Checks separators and matching length
	string InstrString
	variable k=0, sx, fx, instrID, setpoint
	for (k=0; k<itemsinlist(instrIDs, ","); k++)
		sx = str2num(stringfromList(k, starts, ","))
		fx = str2num(stringfromList(k, fins, ","))
		InstrString = stringfromList(k, instrIDs, ",")
		setpoint = sx + (index*(fx-sx)/(numpts-1))	
		nvar id = $instrString
		rampK2400Voltage(id, setpoint, ramprate=ramprate)  
	endfor
end


function rampK2400Voltage(instrID,output,[ramprate]) // Units: mV, mV/s
	variable instrID,output,ramprate
	variable startpoint, sgn, step, new_output
	variable sleeptime = 0.01 //s

	if(paramisdefault(ramprate) || ramprate == 0)
		ramprate = 500  // mV/s
	endif

	startpoint = getK2400voltage(instrID)
	sgn = sign(output-startpoint)

	step = ramprate*sleeptime

	if(abs(output-startpoint) <= step)
		// We are within one step of the final output
		setK2400voltage(instrID,output)
		return 1
	endif
	new_output = startpoint
	do
		new_output += step*sgn
		setK2400voltage(instrID,new_output)
		sc_sleep(sleeptime)
	while(sgn*new_output < sgn*output-step)
	setK2400voltage(instrID,output) // Set final value
end

function rampK2400current(instrID, output,[ramprate]) // Units: nA
	variable output, instrID, ramprate
	variable startpoint, sgn, step, new_output
	variable sleeptime = 0.01 //s

	if(paramisdefault(ramprate))
		ramprate = 1  // nA/s
	endif

	startpoint = getK2400current(instrID)
	sgn = sign(output-startpoint)

	step = ramprate*sleeptime

	if(abs(output-startpoint) <= step)
		// We are within one step of the final output
		setK2400current(instrID,output)
		return 1
	endif
	new_output = startpoint
	do
		new_output += step*sgn
		setK2400current(instrID,new_output)
		sc_sleep(sleeptime)
	while(sgn*new_output < sgn*output-step)
	setK2400current(instrID,output) // Set final value
end

//////////////////
//// Utility ////
////////////////

function setK2400compl(instrID, voltcurr, compl) // Pass "volt" or "curr", the value and the device instID
	variable instrID
	string voltcurr
	variable compl
	string cmd
	
	// check for NaN and INF
	if(numtype(compl) != 0)
		abort "trying to set compl to NaN or Inf"
	endif

	strswitch(voltcurr)
		case "volt":
			sprintf cmd, ":sens:vol:prot %g\n", compl*1e-3 //Units: mV
			writeInstr(instrID,cmd)
			break
		case "curr":
			sprintf cmd, ":sens:curr:prot %g\n", compl*1e-9 //Units: nA
			writeInstr(instrID,cmd)
			break
		default:
			abort "Pass \"volt\" or \"curr\""
			break
	endswitch
end

function setK2400range(instrID,voltcurr,range)
	variable instrID
	string voltcurr
	variable range
	string cmd
	
	// check for NAN and INF
	if(numtype(range) != 0)
		abort "trying to set range to NaN or Inf"
	endif

	strswitch(voltcurr)
		case "volt":
			sprintf cmd, ":sens:vol:rang %g\n", range*1e-3 //Units: mV
			writeInstr(instrID,cmd)
			break
		case "curr":
			sprintf cmd, ":sens:curr:range %g\n", range*1e-9 //Units: nA
			writeInstr(instrID,cmd)
			break
		default:
			abort "Pass \"volt\" or \"curr\""
			break
	endswitch
end

function setK2400output(instrID,onoff) // "on" or "off"
	variable instrID
	string onoff
	strswitch(onoff)
		case "on":
			writeInstr(instrID,":outp on\n")
			break
		case "off":
			writeInstr(instrID,":outp off\n")
			break
		default:
			abort "Pass \"on\" or \"off\""
			break
	endswitch
end

function setK2400autorange(instrID,onoff,voltcurr) // Turn autorange on/off
	variable instrID
	string onoff, voltcurr
	string cmd

	strswitch(voltcurr)
		case "volt":
			sprintf cmd, "sour:volt:rang:auto %s\n", onoff
			writeInstr(instrID,cmd)
			break
		case "curr":
			sprintf cmd, "sour:curr:rang:auto %s\n", onoff
			writeInstr(instrID,cmd)
			break
		default:
			abort "Pass \"volt\" or \"curr\""
			break
	endswitch
end

//// Logging functions ////

function/s getK2400Status(instrID)
	variable instrID
//	string  buffer = ""
//
//	string gpib = num2istr(getAddressGPIB(instrID))
//	buffer = addJSONkeyvalpair(buffer, "gpib_address", gpib)
//
//	return addJSONkeyvalpair("", "K2400_"+gpib, buffer)
end
