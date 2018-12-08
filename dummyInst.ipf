#pragma rtGlobals=3		// Use modern global access method and strict wave access

/// a sweep function to test ///
function ScanDummy(start, fin, numpts, delay, [comments])
	// sweep dummy instrument
	variable start, fin, numpts, delay
	string comments
	string x_label
	variable i=0, j=0, setpoint

	if(paramisdefault(comments))
		comments=""
	endif

	// set starting values
	setpoint = start
	x_label = "x_var"

	InitializeWaves(start, fin, numpts, x_label=x_label)
	sc_sleep(5*delay)
	variable tstart = stopmstimer(-2)
	do
		setpoint = start + (i*(fin-start)/(numpts-1))
		setDummy(setpoint)
		sc_sleep(delay)
		RecordValues(i, 0)
		i+=1
	while (i<numpts)
	variable telapsed = stopmstimer(-2) - tstart
	printf "each RecordValues(...) call takes ~%.1fms \n", telapsed/numpts/1000 - delay*1000
	SaveWaves(msg=comments)
end

/// open connection to this fake instrument ///
function openDummyInstr(var_name, address)
	// address can be some number
	string var_name
	variable address
	variable /g $var_name = address
end

// some 
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

function /s GetDummyStatus(instrID)
	variable instrID
	string  buffer = ""

	string id = num2istr(instrID)
	buffer = addJSONkeyvalpair(buffer, "id", id)
	buffer = addJSONkeyvalpair(buffer, "time", num2str(datetime))

	return addJSONkeyvalpair("", "dum"+id, buffer)
end
