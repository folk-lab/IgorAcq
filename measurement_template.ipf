#pragma rtGlobals=1		// Use modern global access method.

// These scripts are all based around ScanController.ipf
// Nik -- Dec 2016

// do not import this into your Igor experiment
// make a copy and edit from there
// if you have a good addition -- submit changes to this template through GitHub

/////////////////////////////
/////    SETUP    /////
/////////////////////////////

macro initexp()
    // comment out what you don't need to use
    // there should be no harm in running this multiple times if you have problems
    // although you will lose all of the changes you made in the
    // ScanController Window
    
    /////// setup ScanController /////////
    // this will automatically handle the filenum variable
    
	InitScanController() 
	sc_ColorMap = "VioletOrangeYellow" // change the colormap (default=Grays)
	
	/////// auto-initialize GPIB instruments /////////
	// check that you have the board number set correctly
	
	InitAllGPIB(gpib_board="GPIB0")
	
	/////// initialize serial instruments //////////
	// COM ports must be set here
	// this ensures that the code works on all measurement setup
	
	string /g ips_comport = "COM3" // set magnet COM port
	initmagnet()
	
	string/g bd_comport = "COM5" // set babydac COM port
	initbabydacs(5, b2=6, range=2)
	
	// small magnet calibration
	// assuming the magnet is using a kepco current source
	// in voltage control mode
	
//	variable /g kepco_cal = 4 // Amps/Volt
//	variable /g magnet_cal = 85.86 //Amps/Tesla
//	variable /g power_resistor = 0.0131 //Ohms
	
end

////////////////////////////////////////////
/////    THINGS TO READ   /////
////////////////////////////////////////////

// SRS830 //

function getg9x()
	nvar srs9
	return readsrsx(srs9)
end

function getg9y()
	nvar srs9
	return readsrsy(srs9)
end

function getg8x()
	nvar srs8
	return readsrsx(srs8)
end

function getg8y()
	nvar srs8
	return readsrsy(srs8)
end

function getg7x()
	nvar srs7
	return readsrsx(srs7)
end

function getg7y()
	nvar srs7
	return readsrsy(srs7)
end

function getg6x()
	nvar srs6
	return readsrsx(srs6)
end

function getg6y()
	nvar srs6
	return readsrsy(srs6)
end

function getg5x()
	nvar srs5
	return readsrsx(srs5)
end

function getg5y()
	nvar srs5
	return readsrsy(srs5)
end

function getg4x()
	nvar srs4
	return readsrsx(srs4)
end

function getg4y()
	nvar srs4
	return readsrsy(srs4)
end

function getg3x()
	nvar srs3
	return readsrsx(srs3)
end

function getg3y()
	nvar srs3
	return readsrsy(srs3)
end

function getg2x()
	nvar srs2
	return readsrsx(srs2)
end

function getg2y()
	nvar srs2
	return readsrsy(srs2)
end

function getg1x()
	nvar srs1
	return readsrsx(srs1)
end

function getg1y()
	nvar srs1
	return readsrsy(srs1)
end

// BabyDAC ADC //

function getADC61()
	// BabyDAC board 6 ADC channel 1
	return ReadADCBD(1, 6)
end

function getADC62()
	// BabyDAC board 6 ADC channel 2
	return ReadADCBD(2, 6)
end

function getADC51()
	// BabyDAC board 5 ADC channel 1
	// board 5 has a gain of 10
	return ReadADCBD(1, 5)/10.0
end

function getADC52()
	// BabyDAC board 5 ADC channel 2
	// board 5 has a gain of 10
	return ReadADCBD(1, 5)/10.0
end

// K2400 //

function getCurrentK2400()
	nvar k240014
	return readCurrent(k240014)
end

// SMALL MAGNET //

//function getSmallField()
//    nvar magnet_cal, power_resistor
//   // get the value of the small field magnet in mT
//    return (((ReadADCBD(1, 6))/power_resistor)/magnet_cal)  // measured offset
//end

// FRIDGE //

// this depends on what fridge you are using and is kind of a mess right now
// hopefully switching all temperature measurements over to LakeShores will 
// simplify things

//function getMCtemp()
//	return GetTemp("mc")
//end
//
//function get4Ktemp()
//	return GetTemp("4k")
//end
//
//function get50Ktemp()
//	return GetTemp("50k")
//end

////////////////////////////////////////////////
//// MEAUREMENT SCRIPTS ////
///////////////////////////////////////////////

////////////////////////////////////
//     Read VS Time      //
////////////////////////////////////

function ReadvsTimeforever(delay) //Units: s
	variable delay
	string comments
	variable  i

	InitializeWaves(0, 1, 1, x_label="time (s)")
	do
		sleep /s delay
		RecordValues(i, 0,readvstime=1) 
		i+=1
	while (1==1)
	// no point in SaveWaves since the program will never reach this point
end

function ReadvsTimeUntil(delay, checkwave, value, timeout, [comments, operator]) //Units: s
	// read versus time until condition is met or timeout is reached
	// operator is "<" or ">", meaning end on "checkwave[i] < value" or "checkwave[i] > value" 
	
	variable delay, value, timeout
	string checkwave, comments, operator
	variable i

	if(paramisdefault(comments))
		comments=""
	endif
	
	variable a = 0
	if ( stringmatch(operator, "<")==1 )
		a = 1
	elseif ( stringmatch(operator, ">")==1 )
		a = -1
	else 
		abort "Choose a valid operator (<, >)"
	endif

	InitializeWaves(0, 1, 1, x_label="time (s)")
	wave w = $checkwave
	nvar sc_scanstarttime
	do
		sleep /s delay
		RecordValues(i, 0,readvstime=1) 
		if( a*(w[i] - value) < 0 )
			print "Exit on checkwave"
			break
		elseif((datetime-sc_scanstarttime)>timeout)
			print "Exit on timeout"
			break
		endif
		i+=1
	while (1==1)
	SaveWaves(msg=comments)
end

////////////////////////////////////
//         BabyDAC         //
////////////////////////////////////

function ScanBabyDAC(start, fin, channels, numpts, delay, ramprate, [offsetx, comments]) //Units: mV
	// sweep one or more babyDAC channels
	// channels should be a comma-separated string ex: "0, 4, 5"
	variable start, fin, numpts, delay, ramprate, offsetx
	string channels, comments
	string x_label
	variable i=0, j=0, setpoint, nChannels
	nChannels = ItemsInList(channels, ",")

	if( ParamIsDefault(offsetx))
		offsetx=0
	endif

	if(paramisdefault(comments))
		comments=""
	endif
	
	sprintf x_label, "BD %s (mV)", channels

	// set starting values
	setpoint = start-offsetx
	RampMultipleBD(channels, setpoint, nChannels, ramprate=ramprate)
		
	sleep /S 1.0
	InitializeWaves(start, fin, numpts, x_label=x_label)
	do
		setpoint = start-offsetx + (i*(fin-start)/(numpts-1))
		RampMultipleBD(channels, setpoint, nChannels, ramprate=ramprate)
		sleep /s delay
		RecordValues(i, 0) 
		i+=1
	while (i<numpts)
	SaveWaves(msg=comments)
end

function ScanBabyDACUntil(start, fin, channels, numpts, delay, ramprate, checkwave, value, [operator, comments]) //Units: mV
	// sweep one or more babyDAC channels until checkwave < (or >) value
	// channels should be a comma-separated string ex: "0, 4, 5"
	// operator is "<" or ">", meaning end on "checkwave[i] < value" or "checkwave[i] > value" 
	variable start, fin, numpts, delay, ramprate, value
	string channels, operator, checkwave, comments
	string x_label
	variable i=0, j=0, setpoint, nChannels
	nChannels = ItemsInList(channels, ",")

	if(paramisdefault(comments))
		comments=""
	endif
	
	if(paramisdefault(operator))
		operator = "<"
	endif
		
	variable a = 0
	if ( stringmatch(operator, "<")==1 )
		a = 1
	elseif ( stringmatch(operator, ">")==1 )
		a = -1
	else 
		abort "Choose a valid operator (<, >)"
	endif
	
	sprintf x_label, "BD %s (mV)", channels

	// set starting values
	setpoint = start
	RampMultipleBD(channels, setpoint, nChannels, ramprate=ramprate)
		
	sleep /S 1.0
	InitializeWaves(start, fin, numpts, x_label=x_label)
	wave w = $checkwave
	do
		setpoint = start + (i*(fin-start)/(numpts-1))
		RampMultipleBD(channels, setpoint, nChannels, ramprate=ramprate)
		sleep /s delay
		RecordValues(i, 0)
		if( a*(w[i] - value) < 0 )
			print "Exit on checkwave"
			break
		endif
		i+=1	
	while (i<numpts)
	SaveWaves(msg=comments)
end

function ScanBabyDAC2D(startx, finx, channelsx, numptsx, delayx, rampratex, starty, finy, channelsy, numptsy, delayy, rampratey, [offsetx, comments]) //Units: mV
	variable startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, rampratey, offsetx
	string channelsx, channelsy, comments
	variable i=0, j=0, setpointx, setpointy, nChannelsx, nChannelsy
	string x_label, y_label
	
	nChannelsx = ItemsInList(channelsx, ",")
	nChannelsy = ItemsInList(channelsy, ",")
	
	if(paramisdefault(comments))
		comments=""
	endif
	
	if( ParamIsDefault(offsetx))
		offsetx=0
	endif

	sprintf x_label, "BD %s (mV)", channelsx
	sprintf y_label, "BD %s (mV)", channelsy
	
	// set starting values
	setpointx = startx-offsetx
	setpointy = starty
	RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
	RampMultipleBD(channelsy, setpointy, nChannelsy, ramprate=rampratey)
	
	// initialize waves
	InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)
	
	// main loop
	do
		setpointx = startx - offsetx
		setpointy = starty + (i*(finy-starty)/(numptsy-1))
		RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
		RampMultipleBD(channelsy, setpointy, nChannelsy, ramprate=rampratey)
		sleep /s delayy
		j=0
		do
			setpointx = startx - offsetx + (j*(finx-startx)/(numptsx-1))
			RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
			sleep /s delayx
			RecordValues(i, j)
			j+=1
		while (j<numptsx)
		i+=1
	while (i<numptsy)
	SaveWaves(msg=comments)
end

function ScanBabyDACRepeat(startx, finx, channelsx, numptsx, delayx, rampratex, numptsy, delayy, [offsetx, comments]) //Units: mV, mT
	// x-axis is the dac sweep
	// y-axis is an index
	// this will sweep: start -> fin, fin -> start, start -> fin, ....
	// each sweep (whether up or down) will count as 1 y-index
	
	variable startx, finx, numptsx, delayx, rampratex, numptsy, delayy, offsetx
	string channelsx, comments
	variable i=0, j=0, setpointx, setpointy, nChannelsx
	string x_label, y_label
	
	nChannelsx = ItemsInList(channelsx, ",")
	
	if(paramisdefault(comments))
		comments=""
	endif
	
	if( ParamIsDefault(offsetx))
		offsetx=0
	endif

	// setup labels
	sprintf x_label, "BD %s (mV)", channelsx
	y_label = "Sweep Num"
	
	// set starting values
	setpointx = startx-offsetx
	RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
	sleep /S 2.0
	
	// intialize waves
	variable starty = 0, finy = numptsy, scandirection=0

	InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)
	
	do
		if(mod(i,2)==0)
			j=0
			scandirection=1
		else
			j=numptsx-1
			scandirection=-1
		endif
		
		setpointx = startx - offsetx + (j*(finx-startx)/(numptsx-1)) // reset start point
		RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
		sleep /s delayy // wait at start point
		do
			// switch directions with if statement?
			setpointx = startx - offsetx + (j*(finx-startx)/(numptsx-1))
			RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
			sleep /s delayx
			RecordValues(i, j, scandirection=scandirection)
			j+=scandirection
		while (j>-1 && j<numptsx)
		i+=1
	while (i<numptsy)
	SaveWaves(msg=comments)
end

function ScanBabyDACRepeatOneWay(startx, finx, channelsx, numptsx, delayx, rampratex, numptsy, delayy, [offsetx, comments]) //Units: mV, mT
	// x-axis is the dac sweep
	// y-axis is an index
	// this will sweep: start -> fin, start -> fin, start -> fin, ....
	// each sweep will count as 1 y-index
	
	variable startx, finx, numptsx, delayx, rampratex, numptsy, delayy, offsetx
	string channelsx, comments
	variable i=0, j=0, setpointx, setpointy, nChannelsx
	string x_label, y_label
	
	nChannelsx = ItemsInList(channelsx, ",")
	
	if(paramisdefault(comments))
		comments=""
	endif
	
	if( ParamIsDefault(offsetx))
		offsetx=0
	endif

	// setup labels
	sprintf x_label, "BD %s (mV)", channelsx
	y_label = "Sweep Num"
	
	// set starting values
	setpointx = startx-offsetx
	RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
	sleep /S 2.0
	
	// intialize waves
	variable starty = 0, finy = numptsy, scandirection=0

	InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)
	
	do
		j=0
		setpointx = startx - offsetx + (j*(finx-startx)/(numptsx-1)) // reset start point
		RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
		sleep /s delayy // wait at start point
		
		do
			setpointx = startx - offsetx + (j*(finx-startx)/(numptsx-1))
			RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
			sleep /s delayx
			RecordValues(i, j)
			j+=1
		while (j>-1 && j<numptsx)
		i+=1
	while (i<numptsy)
	SaveWaves(msg=comments)
end

function ScanBabyDACMultiRange(startvalues,finvalues,channels,numpts,delay,ramprate, [comments]) //Units: mV
	// This function will sweep multiple dac channels in seperate defined ranges.
	// startvalues, finvalues and channels must be comma seperated lists.
	string  startvalues, finvalues, channels
	variable numpts, delay, ramprate
	string comments
	string x_label
	variable i=0, j=0,k=0, setpoint, nChannels, start, fin, channel

	nChannels = ItemsInList(channels, ",")
	
	if(paramisdefault(comments))
		comments=""
	endif
	
	sprintf x_label, "BD %s (mV)", channels
	
	// set starting values
	for(k=0;k<nChannels;k+=1)
		channel = Str2num(StringFromList(k,channels,","))
		start = Str2num(StringFromList(k,startvalues,","))
		RampOutputBD(channel, start, ramprate=ramprate)
	endfor
		
	sleep /S 1.0
	start = Str2num(StringFromList(0,startvalues,","))
	fin = Str2num(StringFromList(0,finvalues,","))
	InitializeWaves(start, fin, numpts, x_label=x_label)
	do
		for(k=0;k<nChannels;k+=1)
			start = Str2num(StringFromList(k,startvalues,","))
			fin = Str2num(StringFromList(k,finvalues,","))
			channel = Str2num(StringFromList(k,channels,","))
			setpoint = start + (i*(fin-start)/(numpts-1))
			RampOutputBD(channel, setpoint, ramprate=ramprate)
		endfor
		sleep /s delay
		RecordValues(i, 0) 
		i+=1
	while (i<numpts)
	SaveWaves(msg=comments)
end

function ScanBabyDAC2DSlice(startx, finx, channelsx, numpts_slice, delayx, rampratex, starty, finy, channelsy, numptsy, delayy, rampratey,slicewidthx, [comments]) //Units: mV
	// This function will scan a slice in a 2D plane. channelsx will run on the inner loop.
	variable startx, finx, numpts_slice, delayx, rampratex, starty, finy, numptsy, delayy, rampratey, slicewidthx
	string channelsx, channelsy, comments
	variable i=0, j=0, setpointx, setpointy, nChannelsx, nChannelsy, slope, stepsizey, stepsizex, startslice, scandirection=0,omega, numptsx,endslice
	string x_label, y_label
	
	nChannelsx = ItemsInList(channelsx, ",")
	nChannelsy = ItemsInList(channelsy, ",")
	
	if(paramisdefault(comments))
		comments=""
	endif
	
	if(abs(finx-startx)-slicewidthx<0)
		abort("Slice size can't be lager than the difference in x coordinates.")
	endif
	sprintf x_label, "BD %s (mV)", channelsx
	sprintf y_label, "BD %s (mV)", channelsy
	
	// set starting values
	setpointx = startx
	setpointy = starty
	RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
	RampMultipleBD(channelsy, setpointy, nChannelsy, ramprate=rampratey)
	
	omega = abs(finx-startx)/slicewidthx
	numptsx = omega*numpts_slice
	
	// initialize waves
	InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)
	
	
	slope = (finy - starty)/(finx-(startx + sign(finx-startx)*slicewidthx))
	stepsizey = (finy-starty)/(numptsy-1)
	stepsizex = stepsizey/slope

	// main loop
	do
		startslice = startx + i*stepsizex
		endslice = startslice-slicewidthx
		setpointy = starty + (i*(finy-starty)/(numptsy-1))
		RampMultipleBD(channelsx, startslicex, nChannelsx, ramprate=rampratex)
		RampMultipleBD(channelsy, setpointy, nChannelsy, ramprate=rampratey)
		sleep /s delayy
		j=0
		do
			setpointx = startx + (j*(finx-startx)/(numptsx-1))
			if(startslice < setpointx || setpointx < endslice)
				RecordValues(i, j,sliceaddnan=1)
			else
				RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
				sleep /s delayx
				RecordValues(i, j)
			endif
			j+=1
		while (j<numptsx)
		i+=1
	while (i<numptsy)
	SaveWaves(msg=comments)
end

////////////////////////////////////
//       Keithley 2400     //
////////////////////////////////////

function ScanK2400(device, start, fin, numpts, delay, ramprate, [offsetx, compl, comments]) //Units: mV
	// sweep K2400 output voltage
	variable device, start, fin, numpts, delay, ramprate, offsetx, compl
	string comments
	string x_label
	variable i=0, j=0, setpoint

	if( ParamIsDefault(offsetx))
		offsetx=0
	endif
	
	if( ParamIsDefault(compl))
		compl = 20e-9
	endif

	if(paramisdefault(comments))
		comments=""
	endif
	
	sprintf x_label, "K2400 (mV)"

	// set starting values
	setpoint = start-offsetx
	rampkvoltage(device, setpoint/1000, ramprate, compl = compl)
		
	sleep /S 1.0
	InitializeWaves(start, fin, numpts, x_label=x_label)
	do
		setpoint = start-offsetx + (i*(fin-start)/(numpts-1))
		rampkvoltage(device, setpoint/1000, ramprate, compl = compl)
		sleep /s delay
		RecordValues(i, 0) 
		i+=1
	while (i<numpts)
	SaveWaves(msg=comments)
end

//////////////////////////////
//          IPS           //
//////////////////////////////

function ScanIPS(start, fin, numpts, delay, ramprate, [comments]) //Units: mT
	variable start, fin, numpts, delay, ramprate
	string comments
	variable i=0
	
	if(paramisdefault(comments))
		comments=""
	endif
	
	SetSweepRate(ramprate) // mT/min
	SetFieldWait(start)
	sleep/s 5 // wait 5 seconds at start point
	InitializeWaves(start, fin, numpts, x_label="Field (mT)")
	do
		SetFieldWait(start + (i*(fin-start)/(numpts-1)))
		sleep /s delay
		RecordValues(i, 0) 
		i+=1
	while (i<numpts)
	SaveWaves(msg=comments)
end

function ScanBabyDACIPS(startx, finx, channelsx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, rampratey, [offsetx, comments]) //Units: mV, mT
	// x-axis is the dac sweep
	// y-axis is the field sweep
	
	variable startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, rampratey, offsetx
	string channelsx, comments
	variable i=0, j=0, setpointx, setpointy, nChannelsx
	string x_label, y_label
	
	nChannelsx = ItemsInList(channelsx, ",")
	
	if(paramisdefault(comments))
		comments=""
	endif
	
	if( ParamIsDefault(offsetx))
		offsetx=0
	endif

	// setup labels
	sprintf x_label, "BD %s (mV)", channelsx
	y_label = "Field (mT)"
	
	// set starting values
	setpointx = startx-offsetx
	setpointy = starty
	SetSweepRate(rampratey)
	SetFieldWait(setpointy)
	RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
	sleep /S 2.0
	
	// intialize waves
	InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)
	
	do
		setpointx = startx - offsetx
		setpointy = starty + (i*(finy-starty)/(numptsy-1))
		SetFieldWait(setpointy)
		RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
		sleep /s delayy
		j=0
		do
			setpointx = startx - offsetx + (j*(finx-startx)/(numptsx-1))
			RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
			sleep /s delayx
			RecordValues(i, j)
			j+=1
		while (j<numptsx)
		i+=1
	while (i<numptsy)
	SaveWaves(msg=comments)
end

////////////////////////////////////
//     Small Magnet       //
////////////////////////////////////

//function ScanSmallMagnet(start, fin, channels, numpts, delay, ramprate, [comments]) //Units: mT (mT/min)
//	// sweep small magnet using babyDAC and Kepco current source
//	variable start, fin, numpts, delay, ramprate
//	string channels, comments
//	string x_label
//	variable i=0, j=0, setpoint
//	nvar kepco_cal // Amps/Volt
//	nvar magnet_cal //Amps/Tesla
//	variable scaling = magnet_cal/kepco_cal // mV/mT
//	variable corrected_ramp = ramprate*scaling/60 // mV/s 
//	
//	if(paramisdefault(comments))
//		comments=""
//	endif
//	
//	sprintf x_label, "Field (mT)"
//
//	// set starting values
//	setpoint = start
//	RampMultipleBD(channels, setpoint*scaling, 1, ramprate=corrected_ramp)
//		
//	sleep /S 1.0
//	InitializeWaves(start, fin, numpts, x_label=x_label)
//	do
//		setpoint = start + (i*(fin-start)/(numpts-1))
//		RampMultipleBD(channels, setpoint*scaling, 1, ramprate=corrected_ramp)
//		sleep /s delay
//		//RecordValues(i, 0) 
//		i+=1
//	while (i<numpts)
//	//SaveWaves(msg=comments)
//end