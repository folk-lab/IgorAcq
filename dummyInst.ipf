// depends on scan controller

#pragma rtGlobals=3		// Use modern global access method and strict wave access

function getDummyx()
	svar dummy_instx
	return str2num(dummy_instx)
end

function getDummyy()
	svar dummy_insty
	return str2num(dummy_insty)
end

function /S setProto(idx, setpoint, ramprate, update)
	// idx -- sweep index
	// start -- starting value for the parameter
	// fin -- ending value for the parameter
	// numpts -- number of points in sweep
	// ramprate -- ramprate for the parameter (pass 0 if you don't need it)
	// update -- update windows during sweep (pass 0 if you don't need it)
	
	// use idx=-1 to do any setup before the sweep
	// return axis label when idx=-1 is passed
	
	variable idx, setpoint, ramprate, update
	
end

///// setParam EXAMPLE /////

//function /S setPlungerFine(idx, setpoint, ramprate, update)
//	// dummy instrument to set plunger gate
//	// this will
//	variable idx, setpoint, ramprate, update
//	wave /t dacvalsstr
//	
//	variable courseCh = 0, fineCh = 2
//	variable courseVal = str2num(dacvalsstr[0][1]), fineVal
//	
//	// output = courseVal + fineVal/40.0 + 125 <-- depends on BD setup
//	fineVal = (setpoint - courseVal -125)*40.0
//	RampOutputBD(fineCh, fineVal, ramprate=ramprate, update=update)
//	
//	if(idx==-1)
//		// setup some stuff if necessary
//		return "plunger (mV)"
//	else
//		return num2str(fineVal)
//	endif
//end

////////////////////////////


function ScanDummy(setfunc, start, fin, numpts, delay, ramprate, [comments])
	// sweep dummy instrument
	variable start, fin, numpts, delay, ramprate
	string setfunc, comments
	string x_label
	variable i=0, j=0, setpoint
	string /g dummy_instx

	if(paramisdefault(comments))
		comments=""
	endif
	
	FUNCREF setProto setParam = $setfunc
	
	// set starting values
	setpoint = start
	x_label = setParam(-1, start, ramprate, 1)	
		
	sc_sleep(5*delay)
	InitializeWaves(start, fin, numpts, x_label=x_label)
	do
		setpoint = start + (i*(fin-start)/(numpts-1))
		dummy_instx = setParam(i, setpoint, ramprate, 0)	
		sc_sleep(delay)
		RecordValues(i, 0) 
		i+=1
	while (i<numpts)
	SaveWaves(msg=comments)
end

function ScanDummy2D(setfuncx, setfuncy, startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, rampratey, [comments])
	// sweep TWO dummy instruments
	variable startx, finx, numptsx, delayx, rampratex
	variable starty, finy, numptsy, delayy, rampratey
	string setfuncx, setfuncy, comments
	string x_label, y_label
	variable i=0, j=0, setpointx, setpointy
	string /g dummy_instx, dummy_insty

	if(paramisdefault(comments))
		comments=""
	endif
	
	FUNCREF setProto setParamx = $setfuncx
	FUNCREF setProto setParamy = $setfuncy

	// set starting values
	x_label = setParamx(-1, startx, rampratex, 1)
	y_label = setParamy(-1, starty, rampratey, 1)	
	sc_sleep(delayy)

	InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)
do
		
		setpointx = startx
		setpointy = starty + (i*(finy-starty)/(numptsy-1))
		dummy_instx = setParamx(j, setpointx, rampratex, 1)
		dummy_insty = setParamy(i, setpointy, rampratey, 1)	
		sc_sleep(delayy)
		
		j=0
		do
			setpointx = startx + (j*(finx-startx)/(numptsx-1))
			dummy_instx = setParamx(j, setpointx, rampratex, 1)
			sc_sleep(delayx)
			RecordValues(i, j)
			j+=1
		while (j<numptsx)
		i+=1
	while (i<numptsy)
	SaveWaves(msg=comments)
end