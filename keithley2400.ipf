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

threadsafe function GetK2400voltage(instrID) // Units: mV
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

	startpoint = getK2400Voltage(instrID)
	sgn = sign(output-startpoint)

	step = ramprate*sleeptime

	if(abs(output-startpoint) <= step)
		// We are within one step of the final output
		SetK2400Voltage(instrID,output)
		return 1
	endif
	new_output = startpoint
	do
		new_output += step*sgn
		setK2400Voltage(instrID,new_output)
		sc_sleep(sleeptime)
	while(sgn*new_output < sgn*output-step)
	setK2400Voltage(instrID,output) // Set final value
end

function RampK2400Current(output, instID, [ramprate]) // Units: nA
	variable output, instID, ramprate
	variable startpoint, sgn, step, new_output
	variable sleeptime = 0.01 //s

	if(paramisdefault(ramprate))
		ramprate = 1  // nA/s
	endif

	startpoint = GetK2400Current(instID)
	sgn = sign(output-startpoint)

	step = ramprate*sleeptime

	if(abs(output-startpoint) <= step)
		// We are within one step of the final output
		SetK2400Current(output,instID)
		return 1
	endif
	new_output = startpoint
	do
		new_output += step*sgn
		SetK2400Current(new_output,instID)
		sc_sleep(sleeptime)
	while(sgn*new_output < sgn*output-step)
	SetK2400Current(output,instID) // Set final value
end

//////////////////
//// Utility ////
////////////////

function SetK2400Compl(voltcurr,compl,instID) // Pass "volt" or "curr", the value and the device instID
	string voltcurr
	variable compl, instID
	string cmd

	strswitch(voltcurr)
		case "volt":
			sprintf cmd, ":sens:vol:prot %g", compl*1e-3 //Units: mV
			WriteK2400(cmd,instID)
			break
		case "curr":
			sprintf cmd, ":sens:curr:prot %g", compl*1e-9 //Units: nA
			WriteK2400(cmd,instID)
			break
		default:
			abort "Pass \"volt\" or \"curr\""
			break
	endswitch
end

function SetK2400Range(voltcurr,range,instID)
	string voltcurr
	variable range, instID
	string cmd

	strswitch(voltcurr)
		case "volt":
			sprintf cmd, ":sens:vol:rang %g", range*1e-3 //Units: mV
			WriteK2400(cmd,instID)
			break
		case "curr":
			sprintf cmd, ":sens:curr:range %g", range*1e-9 //Units: nA
			WriteK2400(cmd,instID)
			break
		default:
			abort "Pass \"volt\" or \"curr\""
			break
	endswitch
end

function K2400Output(onoff,instID) // "on" or "off"
	string onoff
	variable instID
	strswitch(onoff)
		case "on":
			WriteK2400(":outp on",instID)
			break
		case "off":
			WriteK2400(":outp off",instID)
			break
		default:
			abort "Pass \"on\" or \"off\""
			break
	endswitch
end

function K2400AutoRange(onoff,voltcurr,instID) // Turn autorange on/off
	string onoff, voltcurr
	variable instID
	string cmd

	strswitch(voltcurr)
		case "volt":
			sprintf cmd, "sour:volt:rang:auto %s", onoff
			WriteK2400(cmd,instID)
			break
		case "curr":
			sprintf cmd, "sour:curr:rang:auto %s", onoff
			WriteK2400(cmd,instID)
			break
		default:
			abort "Pass \"volt\" or \"curr\""
			break
	endswitch
end

/////////////////////////////
//// Visa Communication ////
///////////////////////////

threadsafe function WriteK2400(cmd,instID)
	string cmd
	variable instID

	cmd = cmd+"\r"
	VisaWrite instID, cmd
end

threadsafe function/s ReadK2400(instID)
	variable instID
	string response

	WriteK2400(":read?",instID)
	VisaRead/T="\r" instID, response
	return response
end

threadsafe function/s QueryK2400(cmd,instID)
	string cmd
	variable instID

	WriteK2400(cmd,instID)
	return ReadK2400(instID)
end

//// Logging functions ////

function/s GetK2400Status(instrID)
	variable instrID
	string  buffer = ""

	string gpib = num2istr(getAddressGPIB(instrID))
	buffer = addJSONKeyVal(buffer, "gpib_address", strVal=gpib)

	return addJSONKeyVal("", "K2400_"+gpib, strVal=buffer)
end
