#pragma rtGlobals=1		// Use modern global access method

// Keithley 2400 driver
// Initiate using Initeverything(). Use local init function for debugging!
// Voltages are in mV and Currents in nA
// By Christian Olsen, 2016-10-19
// Async supprt added by Christian Olsen, May 2018

///////////////
//// Init ////
/////////////

// Only for debugging use! Init GPIB devices using Initeverything()
function InitK2400(instID,gpibadresse,[gpibboard])
	string instID
	variable gpibadresse, gpibboard
	string resource, error
	variable session=0, inst=0, status
	
	if(paramisdefault(gpibboard))
		gpibboard = 0
	endif
	
	sprintf resource, "GPIB%d::%d::INSTR",gpibboard,gpibadresse
	status = viOpenDefaultRM(session)
	if (status < 0)
		viStatusDesc(session, status, error)
		abort "OpenDefaultRM error: " + error
	endif
	
	status = viOpen(session,resource,0,0,inst) //not sure what to do with openTimeout, setting it to 0!
	if (status < 0)
		viStatusDesc(session, status, error)
		abort "viOpen error: " + error
	endif
	
	variable/g $instID = inst
end

///////////////////////
//// Set functions ////
//////////////////////

function SetK2400Current(curr,instID) //Units: nA
	variable curr, instID
	string cmd
	
	sprintf cmd, ":sour:func curr;:sour:curr:mode fix;:sour:curr:lev %.10f", curr*1e-9
	WriteK2400(cmd,instID)
end

function SetK2400Voltage(volt,instID) // Units: mV
	variable volt, instID
	string cmd
	
	sprintf cmd, ":sour:func volt;:sour:volt:mode fix;:sour:volt:lev %.10f", volt*1e-3
	WriteK2400(cmd,instID)
end

////////////////////////////
//// Sync Get functions ////
///////////////////////////

function GetK2400Current(instID) // Units: nA
	variable instID
	string response
	
	response = QueryK2400(":sens:func \"curr\";:form:elem curr",instID)
	return str2num(response)*1e9
end

function GetK2400Voltage(instID) // Units: mV
	variable instID
	string response
	
	response = QueryK2400(":sens:func \"volt\";:form:elem volt",instID)
	return str2num(response)*1e3
end

//////////////////////////////
//// Async Get functions ////
////////////////////////////

threadsafe GetK2400Current_Async(datafolderID) // Units: nA
	string datafolderID
	string response
	
	// get instrument ID from datafolder
	DFREF dfr = ThreadGroupGetDFR(0,inf)
	setdatafolder dfr
	nvar instID = $(":"+datafolderID+":instID")
	killdatafolder dfr // We don't need the datafolder anymore!
	
	response = QueryK2400(":sens:func \"curr\";:form:elem curr",InstID)
	return str2num(response)*1e9
end

threadsafe GetK2400Voltage(datafolderID) // Units: mV
	string datafolderID
	string response
	
	// get instrument ID from datafolder
	DFREF dfr = ThreadGroupGetDFR(0,inf)
	setdatafolder dfr
	nvar instID = $(":"+datafolderID+":instID")
	killdatafolder dfr // We don't need the datafolder anymore!
	
	response = QueryK2400(":sens:func \"volt\";:form:elem volt",InstID)
	return str2num(response)*1e3
end

/////////////////////////
//// Ramp functions ////
///////////////////////

function RampK2400Voltage(output,instID,[ramprate]) // Units: mV, mV/s
	variable output, instID, ramprate
	variable startpoint, sgn, step, new_output
	variable sleeptime = 0.01 //s
	
	if(paramisdefault(ramprate))
		ramprate = 500  // mV/s 
	endif
	
	startpoint = GetK2400Voltage(instID)
	sgn = sign(output-startpoint)
	
	step = ramprate*sleeptime
	
	if(abs(output-startpoint) <= step)
		// We are within one step of the final output
		SetK2400Voltage(output,instID)
		return 1
	endif
	new_output = startpoint
	do
		new_output += step*sgn
		SetK2400Voltage(new_output,instID)
		sc_sleep(sleeptime)
	while(sgn*new_output < sgn*output-step)
	SetK2400Voltage(output,instID) // Set final value
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

function/s GetK2400Status(instID)
	variable instID
	string  buffer = ""
	
	string gpib = num2istr(instGPIB(instID))
	buffer = addJSONKeyVal(buffer, "gpib_address", strVal=gpib)

	return addJSONKeyVal("", "K2400_"+gpib, strVal=buffer)
end