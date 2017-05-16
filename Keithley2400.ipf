#pragma rtGlobals=1		// Use modern global access method

// Keithley 2400 driver
// Initiate a Keithley 2400 by calling InitK2400, pass id and GPIB adresse.
// Voltages are in mV and Currents in nA
// By Christian Olsen, 2016-10-19

function InitK2400(id,gpibadresse)
	string id
	variable gpibadresse
	
	NI4882 ibdev={0, gpibadresse, 0, 10, 1, 0}
	if(v_flag == -1)
		abort "Setup error. Must likely the GPIB adresse is taken."
	else
		variable/g $id = v_flag
	endif
end

//// Set/Get functions ////

function SetK2400Current(curr,id) //Units: nA
	variable curr, id
	string cmd
	
	sprintf cmd, ":sour:func curr;:sour:curr:mode fix;:sour:curr:lev %.10f", curr*1e-9
	WriteK2400(cmd,id)
end

function SetK2400Voltage(volt,id) // Units: mV
	variable volt, id
	string cmd
	
	sprintf cmd, ":sour:func volt;:sour:volt:mode fix;:sour:volt:lev %.10f", volt*1e-3
	WriteK2400(cmd,id)
end

function GetK2400Current(id) // Units: nA
	variable id
	variable answer
	
	answer = QueryK2400(":sens:func \"curr\";:form:elem curr",id)
	return answer*1e9
end

function GetK2400Voltage(id) // Units: mV
	variable id
	variable answer
	
	answer = QueryK2400(":sens:func \"volt\";:form:elem volt",id)
	return answer*1e3
end

//// Ramp functions ////

function RampK2400Voltage(output,id,[ramprate]) // Units: mV, mV/s
	variable output, id, ramprate
	variable startpoint, sgn, step, new_output
	variable sleeptime = 0.01 //s
	
	if(paramisdefault(ramprate))
		ramprate = 500  // mV/s 
	endif
	
	startpoint = GetK2400Voltage(id)
	sgn = sign(output-startpoint)
	
	step = ramprate*sleeptime
	
	if(abs(output-startpoint) <= step)
		// We are within one step of the final output
		SetK2400Voltage(output,id)
		return 1
	endif
	new_output = startpoint
	do
		new_output += step*sgn
		SetK2400Voltage(new_output,id)
		sleep/s sleeptime
	while(sgn*new_output < sgn*output-step)
	SetK2400Voltage(output,id) // Set final value
end

function RampK2400Current(output, id, [ramprate]) // Units: nA
	variable output, id, ramprate
	variable startpoint, sgn, step, new_output
	variable sleeptime = 0.01 //s
	
	if(paramisdefault(ramprate))
		ramprate = 1  // nA/s 
	endif
	
	startpoint = GetK2400Current(id)
	sgn = sign(output-startpoint)
	
	step = ramprate*sleeptime
	
	if(abs(output-startpoint) <= step)
		// We are within one step of the final output
		SetK2400Current(output,id)
		return 1
	endif
	new_output = startpoint
	do
		new_output += step*sgn
		SetK2400Current(new_output,id)
		sleep/s sleeptime
	while(sgn*new_output < sgn*output-step)
	SetK2400Current(output,id) // Set final value
end

//// Util ////

function SetK2400Compl(voltcurr,compl,id) // Pass "volt" or "curr", the value and the device id
	string voltcurr
	variable compl, id
	string cmd
	
	strswitch(voltcurr)
		case "volt":
			sprintf cmd, ":sens:vol:prot %g", compl*1e-3 //Units: mV
			WriteK2400(cmd,id)
			break
		case "curr":
			sprintf cmd, ":sens:curr:prot %g", compl*1e-9 //Units: nA
			WriteK2400(cmd,id)
			break
		default:
			abort "Pass \"volt\" or \"curr\""
			break
	endswitch
end

function SetK2400Range(voltcurr,range,id)
	string voltcurr
	variable range, id
	string cmd
	
	strswitch(voltcurr)
		case "volt":
			sprintf cmd, ":sens:vol:rang %g", range*1e-3 //Units: mV
			WriteK2400(cmd,id)
			break
		case "curr":
			sprintf cmd, ":sens:curr:range %g", range*1e-9 //Units: nA
			WriteK2400(cmd,id)
			break
		default:
			abort "Pass \"volt\" or \"curr\""
			break
	endswitch
end

function K2400Output(onoff,id) // "on" or "off"
	string onoff
	variable id
	strswitch(onoff)
		case "on":
			WriteK2400(":outp on",id)
			break
		case "off":
			WriteK2400(":outp off",id)
			break
		default:
			abort "Pass \"on\" or \"off\""
			break
	endswitch
end

//// Communication ////

function WriteK2400(command,id)
	string command
	variable id
	string cmd, msg
	
	cmd = command+"\r"
	GPIB2 device=id
	GPIBWrite2 cmd
	
	if(v_flag != 1)
		sprintf msg, "Write failed on command: %s", cmd
		abort msg
	endif
end

function ReadK2400(id)
	variable id
	variable answer
	
	WriteK2400(":read?",id)
	GPIBRead2 answer
	return answer
end

function QueryK2400(command,id)
	string command
	variable id
	
	WriteK2400(command,id)
	return ReadK2400(id)
end

//// Logging functions ////

function/s GetK2400Status(id)
	variable id
	string winfcomments, buffer
	
	NI4882 ibask={id,01}
	sprintf  winfcomments "Keithley 2400 GPIB%d:\r\t", v_flag
	return winfcomments
end


//// wrappers for old functions ////

// try not to use these

//function readCurrent(id)
//	variable id
//	return GetK2400Current(id)*1e9 //Unit: A
//end
//
//function readVoltage(id)
//	variable id
//	return GetK2400Voltage(id)*1e3 //Unit: V
//end
//
//function setCurrent(current,range,compl,id) //Unit: A
//	variable current,range,compl,id
//	SetK2400Range("curr",range,id)
//	SetK2400Compl("curr",compl,id)
//	SetK2400Current(current*1e9,id)
//end
//
//function setVoltage(volts,range,compl,id) //Unit: V
//	variable volts,range,compl,id
//	SetK2400Range("volt",range,id)
//	SetK2400Compl("volt",compl,id)
//	SetK2400Voltage(volts*1e3,id)
//end
//
//function rampkcurrent(id,curr) //Unit: A
//	variable id,curr
//	RampK2400Current(curr*1e9,id)
//end
//
//function rampkvoltage(id,volts,rate,[range,compl]) //Units: V & mV/s
//	variable id,volts,rate,range,compl
//	if( ParamIsDefault(compl))
//		compl=20e-6
//	endif
//	SetK2400Range("volt",range,id)
//	SetK2400Compl("volt",compl,id)
//	RampK2400Voltage(volts*1e3,id,ramprate=rate)
//end