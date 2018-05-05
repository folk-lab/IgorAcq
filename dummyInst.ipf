// depends on scan controller

#pragma rtGlobals=3		// Use modern global access method and strict wave access

threadsafe function getDummy1x(instrID)
	variable instrID
	
	sc_sleep_noupdate(0.05)
	return datetime
end

threadsafe function getDummy2x(instrID)
	variable instrID
	
	sc_sleep_noupdate(0.05)
	return enoise(1)
end

function getDummy3y(instrID, num_input)
	variable instrID, num_input
	
	sc_sleep_noupdate(0.05)
	return mod(datetime, 2)
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
		
	sc_sleep(5*delay)
	InitializeWaves(start, fin, numpts, x_label=x_label)
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

function setDummyInstrID(instrID)
	variable instrID
	nvar dum1, dum2, dum3
	dum1 = 1
	dum2 = 2
	dum3 = 3
end

macro initDummyExp()
	// customize this setup to each individual experiment
	// try write all functions such that initexp() can be run
	//     at any time without losing any setup/configuration info
	
	///// setup ScanController /////
	
	// define instruments --
	//      this wave should have columns with {instrument name, VISA address, test function, setup function}
	//      use test = "" to skip query tests when connecting instruments

	make /o/t connInstr = {{"dum1",  "",  "", "setDummyInstrID(dum1)"  },{\
				               "dum2",  "",  "", "setDummyInstrID(dum2)"  },{\
				               "dum3",  "",  "", "setDummyInstrID(dum3)"  }}
	InitScanController(connInstr, srv_push=0) // pass instrument list wave to scan controller
	sc_ColorMap = "VioletOrangeYellow" // change default colormap (default=Grays)

end

function /s GetDummyStatus(instrID)
	variable instrID
	string  buffer = ""
	
	string id = num2istr(instrID)
	buffer = addJSONKeyVal(buffer, "id", strVal=id)	
	buffer = addJSONKeyVal(buffer, "time", numVal=datetime, fmtNum = "%d")
	
	return addJSONKeyVal("", "dum"+id, strVal=buffer)
end