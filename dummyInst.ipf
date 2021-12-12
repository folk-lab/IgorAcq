#pragma rtGlobals=3		// Use modern global access method and strict wave access

/// a sweep function to test ///
function ScanDummy(start, fin, numpts, delay, [comments]) 
	// sweep dummy instrument
	variable start, fin, numpts, delay
	string comments
	string x_label
	variable i=0, j=0, setpoint

	comments = selectString(paramIsDefault(comments), comments, "")

	Struct ScanVars S
	initScanVarsBD(S, -1, start, fin, numptsx=numpts, delayx=delay, x_label="x_var", comments=comments)  // -1 for instrID (used for babyDac or FastDac)
	
	initializeScan(S)

	// set starting values
	setpoint = start

	sc_sleep(5*delay)
	variable tstart = stopmstimer(-2)  // Time in us
	S.start_time = datetime  // Time in s
	do
		setpoint = start + (i*(fin-start)/(numpts-1))
		setDummy(setpoint)
		sc_sleep(delay)
		RecordValues(S, i, 0)
		i+=1
	while (i<numpts)
	variable telapsed = stopmstimer(-2) - tstart
	S.end_time = datetime
//	printf "each RecordValues(...) call takes ~%.1fms \n", telapsed/numpts/1000 - delay*1000
	EndScan(S=S)
end

/// open connection to this fake instrument ///
function openDummyInstr(var_name, address)
	// address can be some number
	string var_name
	variable address
	variable /g $var_name = address
end

// some get and set functions
threadsafe function getDummyX(instrID)
	variable instrID

	sc_sleep_noupdate(0.025)
	return enoise(1)+instrID
end

threadsafe function getDummyY(instrID)
	variable instrID

	sc_sleep_noupdate(0.025)
	return enoise(1)+instrID*10
end

function setDummy(setpoint, [delay])
	// put it where you would set a parameter
	// add a delay if you like
	variable setpoint, delay
	if(paramisdefault(delay))
		return setpoint
	else
		sc_sleep(delay)
		return setpoint
	endif
end

function /s GetDummyStatus(instrID, message)
	variable instrID
	string message

   return "message = "+message
end
