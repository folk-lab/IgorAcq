#pragma rtGlobals=1		// Use modern global access method

// Keithley 2400 driver
// Initiate using Initeverything(). Use local init function for debugging!
// Voltages are in mV and Currents in nA
// By Christian Olsen, 2016-10-19
// Async supprt added by Christian Olsen, May 2018

///////////////////////
//// Set functions ////
//////////////////////

function setK2400Current(instrID,curr) //Units: nA
	variable instrID,curr
	string cmd

	sprintf cmd, ":sour:func curr;:sour:curr:mode fix;:sour:curr:lev %.10f\n", curr*1e-9
	writeInstr(instrID,cmd)
end

function setK2400Voltage(instrID,volt) // Units: mV
	variable instrID,volt
	string cmd

	sprintf cmd, ":sour:func volt;:sour:volt:mode fix;:sour:volt:lev %.10f\n", volt*1e-3
	writeInstr(instrID,cmd)
end

////////////////////////
//// Get functions ////
///////////////////////

threadsafe function getK2400current(instrID) // Units: nA
	variable instrID
	string response

	response = queryInstr(instrID,":sens:func \"curr\";:form:elem curr\n",read_term="\n")
	return str2num(response)*1e9
end

threadsafe function getK2400voltage(instrID) // Units: mV
	variable instrID
	string response

	response = queryInstr(instrID,":sens:func \"volt\";:form:elem volt\n",read_term="\n")
	return str2num(response)*1e3
end

/////////////////////////
//// Ramp functions ////
///////////////////////

function rampK2400Voltage(instrID,output,[ramprate]) // Units: mV, mV/s
	variable instrID,output,ramprate
	variable startpoint, sgn, step, new_output
	variable sleeptime = 0.01 //s

	if(paramisdefault(ramprate))
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

function/s getK2400status(instrID)
	variable instrID
	string  buffer = ""

	string gpib = num2istr(getAddressGPIB(instrID))
	buffer = addJSONKeyVal(buffer, "gpib_address", strVal=gpib)

	return addJSONKeyVal("", "K2400_"+gpib, strVal=buffer)
end
