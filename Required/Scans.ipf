#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method

// Standard Scan Functions
// Written by Tim Child, 2021-12

// Note: This .ipf is not intended to be included in the experiment as it has many dependencies.
// Note: You should copy the functions you will use from here into your own .ipf or procedure.ipf file

// Full list of scans here:
// ReadVsTime
// ScanBabyDAC
// ScanBabyDACUntil
// ScanBabyDAC2D
// ScanBabyDAC_SRSAmplitude
// ReadVsTimeFastdac
// ScanFastDAC
// ScanFastDACSlow
// ScanFastDACSlow2D
// ScanFastDAC2D
// ScanK2400
// ScanK24002D
// ScanBabyDACK24002D
// ScanBabyDACMultipleK24002D
// ScanFastDACK24002D
// ScanMultipleK2400
// ScanMutipleK2400LS625Magnet2D
// ScanLS625Magnet
// ScanBabyDACLS625Magnet2D
// ScanFastDACLS625Magenet2D
// ScanK2400LS625Magent2D
// ScanSRSFrequency

// Templates:
// ScanMultiVarTemplate -- Helpful template for running a scan inside multiple loops where other variables can change (i.e. up to 5D scans)
// StepTempScanSomething -- Scanning at multiple fridge temperatures


function ReadVsTime(delay, [y_label, max_time, comments]) // Units: s
	variable delay, max_time
	string y_label, comments
	variable i=0

	comments = selectString(paramIsDefault(comments), comments, "")
	y_label = selectString(paramIsDefault(y_label), y_label, "")	
	max_time = paramIsDefault(max_time) ? INF : max_time
	
	Struct ScanVars S
	initScanVarsBD(S, 0, 0, 1, numptsx=1, delayx=delay, x_label="time /s", y_label=y_label, comments=comments)
	initializeScan(S)
	S.readVsTime = 1

	variable/g sc_scanstarttime = datetime
	S.start_time = datetime
	do
		asleep(delay)
		RecordValues(S, i, 0)
		doupdate
		i+=1
	while (datetime-S.start_time < max_time)
	S.end_time = datetime
	S.numptsx = i 
	EndScan(S=S)
end


function ScanBabyDAC(instrID, start, fin, channels, numpts, delay, [ramprate, starts, fins, repeats, y_label, alternate, comments, nosave]) //Units: mV
	// sweep one or more babyDAC channels
	// channels should be a comma-separated string ex: "0, 4, 5" or "LABEL1,LABEL2" 
	variable instrID, start, fin, numpts, delay, ramprate, repeats, alternate, nosave
	string channels, comments, y_label
	string starts, fins // For different start/finish points for each channel (must match length of channels if used)

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	starts = selectstring(paramisdefault(starts), starts, "")
	fins = selectstring(paramisdefault(fins), fins, "")
	repeats = (repeats == 0) ? 1 : repeats

	// Initialize ScanVars
	struct ScanVars S
	initScanVarsBD(S, instrID, start, fin, channelsx=channels, numptsx=numpts, delayx=delay, rampratex=ramprate, startxs=starts, finxs=fins, starty=1, finy=repeats, numptsy=repeats, alternate=alternate, comments=comments, y_label=y_label)

	// Check software limits and ramprate limits
	PreScanChecksBD(S)  

	// Ramp to start without checks because checked above
	RampStartBD(S, ignore_lims=1)

	// Let gates settle 
	sc_sleep(5*S.delayx)

	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0
	for (i=0;i<S.numptsx;i++)
		rampToNextSetpoint(S, i, ignore_lims=1)
		sc_sleep(S.delayx)
		RecordValues(S, i, 0)
	endfor

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		dowindow /k SweepControl
	endif
end


function ScanBabyDACUntil(instrID, start, fin, channels, numpts, delay, checkwave, value, [ramprate, starts, fins, operator, y_label, comments, nosave])
	// sweep one or more babyDAC channels until checkwave < (or >) value
	// channels should be a comma-separated string ex: "0, 4, 5"
	// operator is "<" or ">", meaning end on "checkwave[i] < value" or "checkwave[i] > value"
	variable instrID, start, fin, numpts, delay, ramprate, value, nosave
	string channels, operator, checkwave, y_label, comments
	string starts, fins // For different start/finish points for each channel (must match length of channels if used)

	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	operator = selectstring(paramisdefault(operator), operator, "<")
	starts = selectstring(paramisdefault(starts), starts, "")
	fins = selectstring(paramisdefault(fins), fins, "")

	variable a = 0
	if ( stringmatch(operator, "<")==1 )
		a = 1
	elseif ( stringmatch(operator, ">")==1 )
		a = -1
	else
		abort "Choose a valid operator (<, >)"
	endif

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Initialize ScanVars
	struct ScanVars S
	initScanVarsBD(S, instrID, start, fin, channelsx=channels, numptsx=numpts, delayx=delay, rampratex=ramprate, startxs=starts, finxs=fins, comments=comments, y_label=y_label)

	// Check software limits and ramprate limits
	PreScanChecksBD(S)  

	// Ramp to start without checks because checked above
	RampStartBD(S, ignore_lims=1)

	// Let gates settle 
	sc_sleep(5*S.delayx)

	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0
	wave w = $checkwave
	do
		rampToNextSetpoint(S, i, ignore_lims=1)
		sc_sleep(S.delayx)
		RecordValues(S, i, 0)
		if (a*w[i] - value < 0)
			break
		endif
		i+=1
	while (i<S.numptsx)

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		dowindow /k SweepControl
	endif
end


function ScanBabyDAC2D(instrID, startx, finx, channelsx, numptsx, delayx, starty, finy, channelsy, numptsy, delayy, [rampratex, rampratey, startxs, finxs, startys, finys, comments, nosave]) //Units: mV
	variable instrID, startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, rampratey, nosave
	string channelsx, channelsy, comments
	string startxs, finxs, startys, finys  // For ramping multiple gates with different start/end points
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	startxs = selectstring(paramisdefault(startxs), startxs, "")
	finxs = selectstring(paramisdefault(finxs), finxs, "")
	startys = selectstring(paramisdefault(startys), startys, "")
	finys = selectstring(paramisdefault(finys), finys, "")
	
	// Initialize ScanVars
	struct ScanVars S
	initScanVarsBD(S, instrID, startx, finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
							starty=starty, finy=finy, channelsy=channelsy, numptsy=numptsy, delayy=delayy, rampratey=rampratey, \
							startxs=startxs, finxs=finxs, startys=startys, finys=finys, comments=comments)

	// Check software limits and ramprate limits
	PreScanChecksBD(S)  
	
	// Ramp to start without checks because checked above
	RampStartBD(S, ignore_lims=1)
	
	// Let gates settle 
	sc_sleep(S.delayy)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, k=0
	for(i=0; i<S.numptsy; i++)
		rampToNextSetpoint(S, 0, outer_index=i, ignore_lims=1)  // Ramp x to start and y to next setpoint
		sc_sleep(S.delayy)
		for(j=0; j<S.numptsx; j++)
			// Ramp X to next setpoint
			rampToNextSetpoint(S, j, ignore_lims=1)  // Ramp x to next setpoint
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
		endfor
	endfor
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end


function ScanBabyDAC_SRSAmplitude(babydacID, srsID, startx, finx, channelsx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, [starts, fins, comments, nosave]) //Units: mV, mV
	// Example of how to make new babyDAC scan stepping a different instrument (here SRS)
	variable babydacID, srsID, startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, nosave
	string channelsx, comments
	string starts, fins // For ramping multiple gates with different start/end points
	abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	starts = selectstring(paramisdefault(starts), starts, "")
	fins = selectstring(paramisdefault(fins), fins, "")
	
	// Initialize ScanVars
	struct ScanVars S
	initScanVarsBD(S, babydacID, startx, finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
							starty=starty, finy=finy, numptsy=numptsy, delayy=delayy, startxs=starts, finxs=fins,\
	 						y_label="SRS Amplitude", comments=comments)
	S.instrIDy = srsID

	// Check software limits and ramprate limits
	PreScanChecksBD(S, x_only=1)  
	
	// Ramp to start without checks because checked above
	RampStartBD(S, ignore_lims=1)
	
	// Let gates settle 
	sc_sleep(S.delayy)
	
	// Make waves and graphs etc
	initializeScan(S)

	// main loop
	variable i=0, j=0, setpointy
	do
		rampToNextSetpoint(S, 0, ignore_lims=1)  // Ramp BD to start
		setpointy = starty + (i*(finy-starty)/(S.numptsy-1))
		SetSRSAmplitude(S.instrIDy,setpointy)
		sc_sleep(S.delayy)
		j=0
		do
			rampToNextSetpoint(S, j, ignore_lims=1)  // Ramp x to next setpoint
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
			j+=1
		while (j<S.numptsx)
		i+=1
	while (i<S.numptsy)
  
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end


function ReadVsTimeFastdac(instrID, duration, [y_label, comments, nosave]) // Units: s 
	variable instrID, duration, nosave
	string comments, y_label
	
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")

	wave fadcattr
	variable i=0

	string channels = scf_getRecordedFADCinfo("channels")  // Get ADCs ticked to record
	
	if(itemsinlist(channels, ",") == 0)
		abort "[ERROR] \"ReadVsTimeFastdac\": No ADC channels selected"
	endif

	Struct ScanVars S
	initScanVarsFD(S, instrID, 0, duration, duration=duration, x_label="time /s", y_label="Current /nA", comments=comments)
	S.readVsTime = 1
	
	initializeScan(S)

	scfd_RecordValues(S, 0)

	if (!nosave)	
		EndScan(S=S)
	else
		dowindow/k SweepControl
	endif
end


function ScanFastDAC(instrID, start, fin, channels, [numptsx, sweeprate, delay, ramprate, repeats, alternate, starts, fins, x_label, y_label, comments, nosave, use_awg])
	// 1D repeat scan for FastDAC
	// Note: to alternate scan direction set alternate=1
	// Note: Ramprate is only for ramping gates between scans
	variable instrID, start, fin, repeats, numptsx, sweeprate, delay, ramprate, alternate, nosave, use_awg
	string channels, x_label, y_label, comments, starts, fins
	variable i=0, j=0

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Set defaults
	delay = ParamIsDefault(delay) ? 0.01 : delay
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	x_label = selectstring(paramisdefault(x_label), x_label, "")
	comments = selectstring(paramisdefault(comments), comments, "")
	starts = selectstring(paramisdefault(starts), starts, "")
	fins = selectstring(paramisdefault(fins), fins, "")

	// Set sc_ScanVars struct
	struct ScanVars S
	initScanVarsFD(S, instrID, start, fin, channelsx=channels, numptsx=numptsx, rampratex=ramprate, starty=1, finy=repeats, delayy=delay, sweeprate=sweeprate,  \
					numptsy=repeats, startxs=starts, finxs=fins, x_label=x_label, y_label=y_label, alternate=alternate, comments=comments)
//	S.finy = S.starty+S.numptsy  // Repeats
	if (s.is2d && strlen(S.y_label) == 0)
		S.y_label = "Repeats"
	endif
	
	// Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
	PreScanChecksFD(S, x_only=1)  

  	// If using AWG then get that now and check it
	struct AWGVars AWG
	if(use_AWG)	
		fd_getGlobalAWG(AWG)
		CheckAWG(AWG, S)  // Note: sets S.numptsx here and AWG.lims_checked = 1
	endif
	SetAWG(AWG, use_AWG)


	// Ramp to start without checks since checked above
	RampStartFD(S, ignore_lims = 1)

	// Let gates settle
	sc_sleep(S.delayy)

	// Init Scan
	initializeScan(S)

	// Main measurement loop
	variable d=1
	for (j=0; j<S.numptsy; j++)
		S.direction = d  // Will determine direction of scan in fd_Record_Values

		// Ramp to start of fast axis
		RampStartFD(S, ignore_lims=1, x_only=1)
		sc_sleep(S.delayy)

		// Record values for 1D sweep
		scfd_RecordValues(S, j, AWG_List = AWG)

		if (alternate!=0) // If want to alternate scan scandirection for next row
			d = d*-1
		endif
	endfor

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
		// SaveWaves(msg=comments, fastdac=1)
	else
		dowindow /k SweepControl
	endif
end


function ScanFastDacSlow(instrID, start, fin, channels, numpts, delay, ramprate, [starts, fins, y_label, repeats, alternate, delayy, until_checkwave, until_stop_val, until_operator, comments, nosave]) //Units: mV
	// sweep one or more FastDAC channels but in the ScanController way (not ScanControllerFastdac). I.e. ramp, measure, ramp, measure...
	// channels should be a comma-separated string ex: "0, 4, 5"
	variable instrID, start, fin, numpts, delay, ramprate, nosave, until_stop_val, repeats, alternate, delayy
	string channels, y_label, comments, until_operator, until_checkwave
	string starts, fins // For different start/finish points for each channel (must match length of channels if used)

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	starts = selectstring(paramisdefault(starts), starts, "")
	fins = selectstring(paramisdefault(fins), fins, "")
	until_operator = selectstring(paramisdefault(until_operator), until_operator, "not_set")
	delayy = ParamIsDefault(delayy) ? 5*delay : delayy
	
	variable a
	if (stringmatch(until_operator, "not_set") == 1)
		a = 0
	else
		if (paramisdefault(until_checkwave) || paramisdefault(until_stop_val))
			abort "If scanning until condition met, you must set a checkwave and stop_val"
		else
			wave cw = $until_checkwave
		endif
		
		if ( stringmatch(until_operator, "<")==1 )
			a = 1
		elseif ( stringmatch(until_operator, ">")==1 )
			a = -1
		else
			abort "Choose a valid operator (<, >)"
		endif
	endif
	

	// Initialize ScanVars
	struct ScanVars S  // Note, more like a BD scan if going slow
	initScanVarsFD(S, instrID, start, fin, channelsx=channels, numptsx=numpts, delayx=delay, rampratex=ramprate, startxs = starts, finxs = fins, comments=comments, y_label=y_label,\
	 		starty=1, finy=repeats,  numptsy=repeats, alternate=alternate, delayy=delay)  
	if (s.is2d && strlen(S.y_label) == 0)
		S.y_label = "Repeats"
	endif	 		
	S.using_fastdac = 0 // Explicitly showing that this is not a normal fastDac scan
	S.duration = numpts*max(0.05, delay) // At least 50ms per point is a good estimate 
	S.sweeprate = abs((fin-start)/S.duration) // Better estimate of sweeprate (Not really valid for a slow scan)

	// Check limits (not as much to check when using FastDAC slow)
	scc_checkLimsFD(S)
	S.lims_checked = 1

	// Ramp to start without checks because checked above
	RampStartFD(S, ignore_lims=1)

	// Let gates settle 
	sc_sleep(S.delayy)

	// Make Waves and Display etc
	InitializeScan(S)

	// Main measurement loop
	variable i=0, j=0
	variable d=1
	for (j=0; j<S.numptsy; j++)
		S.direction = d  // Will determine direction of scan in fd_Record_Values

		// Ramp to start of fast axis
		RampStartFD(S, ignore_lims=1, x_only=1)
		sc_sleep(S.delayy)
		i = 0
		do
			rampToNextSetpoint(S, i, fastdac=1, ignore_lims=1)  // Ramp x to next setpoint
			sc_sleep(S.delayx)
			if (s.is2d)
				RecordValues(S, j, i)
			else
				RecordValues(S, i, 0)
			endif
			if (a!=0)  // If running scan until condition is met
				if (a*cw[i] - until_stop_val < 0)
					break
				endif
			endif
			i+=1
		while (i<S.numptsx)
		
		if (alternate!=0) // If want to alternate scan scandirection for next row
			d = d*-1
		endif
	endfor
	

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		dowindow /k SweepControl
	endif
end


function ScanFastDacSlow2D(instrID, startx, finx, channelsx, numptsx, delayx, starty, finy, channelsy, numptsy, [rampratex, rampratey, delayy, startxs, finxs, startys, finys, comments, nosave])
	// sweep one or more FastDAC channels but in the ScanController way (not ScanControllerFastdac). I.e. ramp, measure, ramp, measure...
	// channels should be a comma-separated string ex: "0, 4, 5"
	variable instrID, startx, finx, starty, finy, numptsy, numptsx, rampratex, rampratey, delayx, delayy, nosave
	string channelsx, channelsy, comments, startxs, finxs, startys, finys

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	startxs = selectstring(paramisdefault(startxs), startxs, "")
	finxs = selectstring(paramisdefault(finxs), finxs, "")
	startys = selectstring(paramisdefault(startys), startys, "")
	finys = selectstring(paramisdefault(finys), finys, "")

	// Initialize ScanVars
	struct ScanVars S  
	 	initScanVarsFD(S, instrID, startx, finx, channelsx=channelsx, rampratex=rampratex, numptsx=numptsx, delayx=delayx,\
		  numptsy=numptsy, delayy=delayy, starty=starty, finy=finy, channelsy=channelsy, rampratey=rampratey,\
		  startxs=startxs, finxs=finxs, startys=startys, finys=finys, comments=comments)
	S.using_fastdac = 0   // This is not a normal fastDac scan
	S.duration = S.numptsx*max(0.05, S.delayx) // At least 50ms per point is a good estimate 
	S.sweeprate = abs((S.finx-S.startx)/S.duration) // Better estimate of sweeprate (Not really valid for a slow scan)

	// Check limits (not as much to check when using FastDAC slow)
	scc_checkLimsFD(S)
	S.lims_checked = 1

	// Ramp to start without checks because checked above
	RampStartFD(S, ignore_lims=1)

	// Let gates settle 
	sc_sleep(S.delayy*5)

	// Make Waves and Display etc
	InitializeScan(S)

	// Main measurement loop
	variable i=0, j=0, k=0, setpointx, setpointy
	for(i=0; i<S.numptsy; i++)
		rampToNextSetpoint(S, 0, outer_index=i, fastdac=1, ignore_lims=1)  // Ramp x to start and y to next setpoint
		sc_sleep(S.delayy)
		for(j=0; j<S.numptsx; j++)
			// Ramp X to next setpoint
			rampToNextSetpoint(S, j, fastdac=1, ignore_lims=1)  // Ramp x to next setpoint
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
		endfor
	endfor

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		dowindow /k SweepControl
	endif
end

//////////////////////
///// DEPRECATED /////
//////////////////////
// removed this older scanfastdac2d and renamed the scanfastdac2dinterlaced as scanfastdac2d
// keepin old scanfastdac2d for now (if all works during cooldown then it will be removed)
//function ScanFastDAC2D(fdID, startx, finx, channelsx, starty, finy, channelsy, numptsy, [numpts, sweeprate, bdID, fdyID, rampratex, rampratey, delayy, startxs, finxs, startys, finys, comments, nosave, use_AWG])
//	// 2D Scan for FastDAC only OR FastDAC on fast axis and BabyDAC on slow axis
//	// Note: Must provide numptsx OR sweeprate in optional parameters instead
//	// Note: To ramp with babyDAC on slow axis provide the BabyDAC variable in bdID
//	// Note: channels should be a comma-separated string ex: "0,4,5"
//	variable fdID, startx, finx, starty, finy, numptsy, numpts, sweeprate, bdID, fdyID, rampratex, rampratey, delayy, nosave, use_AWG
//	string channelsx, channelsy, comments, startxs, finxs, startys, finys
//
//	// Set defaults
//	delayy = ParamIsDefault(delayy) ? 0.01 : delayy
//	comments = selectstring(paramisdefault(comments), comments, "")
//	startxs = selectstring(paramisdefault(startxs), startxs, "")
//	finxs = selectstring(paramisdefault(finxs), finxs, "")
//	startys = selectstring(paramisdefault(startys), startys, "")
//	finys = selectstring(paramisdefault(finys), finys, "")
//	variable use_bd = paramisdefault(bdid) ? 0 : 1 			// Whether using both FD and BD or just FD
//	variable use_second_fd = paramisdefault(fdyID) ? 0 : 1  // Whether using a second FD for the y axis gates
//	
//
//	// Reconnect instruments
//	sc_openinstrconnections(0)
//
//	// Put info into scanVars struct (to more easily pass around later)
// 	struct ScanVars S
// 	if (use_bd == 0 && use_second_fd == 0)
//	 	initScanVarsFD(S, fdID, startx, finx, channelsx=channelsx, rampratex=rampratex, numptsx=numpts, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
//		   						 starty=starty, finy=finy, channelsy=channelsy, rampratey=rampratey, startxs=startxs, finxs=finxs, startys=startys, finys=finys, comments=comments)
//	
//	else  				// Using BabyDAC for Y axis so init x in FD_ScanVars, and init y in BD_ScanVars
//		initScanVarsFD(S, fdID, startx, finx, channelsx=channelsx, rampratex=rampratex, numptsx=numpts, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
//		   						rampratey=rampratey, startxs=startxs, finxs=finxs, comments=comments)
//		s.is2d = 1		   						
//		S.starty = starty
//		S.finy = finy		
//		if (use_bd)
//			S.instrIDy = bdID
//			S.channelsy = scu_getChannelNumbers(channelsy, fastdac=0)
//			S.y_label = scu_getDacLabel(S.channelsy, fastdac=0)
//			scv_setSetpoints(S, S.channelsx, S.startx, S.finx, S.channelsy, S.starty, S.finy, S.startxs, S.finxs, S.startys, S.finys)
//		else  // use_second_fd
//			S.instrIDy = fdyID
//			S.channelsy = scu_getChannelNumbers(channelsy, fastdac=1)
//			S.y_label = scu_getDacLabel(S.channelsy, fastdac=1)
//			scv_setSetpoints(S, S.channelsx, S.startx, S.finx, S.channelsy, S.starty, S.finy, S.startxs, S.finxs, S.startys, S.finys)
//		endif
//	endif
//      
//   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
//
//   if(use_bd == 1)
////   		PreScanChecksBD(Bsv)
//		PreScanChecksFD(S, x_only=1)
//		PreScanChecksBD(S, y_only=1)
//   	else  // Should work for 1 or 2 FDs
//   	   PreScanChecksFD(S)  
//   	endif
//   	
//  	// If using AWG then get that now and check it
//	struct AWGVars AWG
//	if(use_AWG)	
//		fd_getGlobalAWG(AWG)
//		CheckAWG(AWG, S)  // Note: sets S.numptsx here and AWG.lims_checked = 1
//	endif
//	SetAWG(AWG, use_AWG)
//   
//   // Ramp to start without checks
//   if(use_bd == 1)
//	   RampStartFD(S, x_only=1, ignore_lims=1)
//	   RampStartBD(S, y_only=1, ignore_lims=1)
//   	else  // Should work for 1 or 2 FDs
//   	   RampStartFD(S, ignore_lims=1)
//   	endif
//   	
//   	// Let gates settle
//	sc_sleep(S.delayy)
//
//	// Initialize waves and graphs
//	initializeScan(S)
//
//	// Main measurement loop
//	variable i=0, j=0
//	variable setpointy, sy, fy
//	string chy
//	for(i=0; i<S.numptsy; i++)
//		// Ramp fast axis to start
//		rampToNextSetpoint(S, 0, fastdac=1, ignore_lims=1)
//
//		// Ramp slow axis
//		rampToNextSetpoint(S, 0, outer_index=i, y_only=1, fastdac=!use_bd, ignore_lims=1)
//
//		// Let gates settle
//		sc_sleep(S.delayy)
//		
//		// Record fast axis
//		scfd_RecordValues(S, i, AWG_list=AWG)
//	endfor
//
//	// Save by default
//	if (nosave == 0)
//		EndScan(S=S)
//  	else
//  		dowindow /k SweepControl
//	endif
//
//end




function ScanFastDAC2D(fdID, startx, finx, channelsx, starty, finy, channelsy, numptsy, [numpts, sweeprate, bdID, fdyID, rampratex, rampratey, delayy, startxs, finxs, startys, finys, comments, nosave, use_AWG, interlace_channels, interlace_values, virtual_gates, virtual_ratios, virtual_mids, virtual_width])
	// using virtual gates supply gate, ratio and mid. The mid will be based on P*2 value. Supplying virtual gates ignores startys and finys.
	variable fdID, startx, finx, starty, finy, numptsy, numpts, sweeprate, bdID, fdyID, rampratex, rampratey, delayy, nosave, use_AWG, virtual_width
	string channelsx, channelsy, comments, startxs, finxs, startys, finys, interlace_channels, interlace_values, virtual_gates, virtual_ratios, virtual_mids
	
	// 2D Scan for FastDAC only OR FastDAC on fast axis and BabyDAC on slow axis
	// Note: Must provide numptsx OR sweeprate in optional parameters instead
	// Note: To ramp with babyDAC on slow axis provide the BabyDAC variable in bdID
	// Note: channels should be a comma-separated string ex: "0,4,5"
	// Note: assumes virtual sweeps are on the x_axis and ratios based off index 0 in channelsx
	
	// Example :: Interlaced parameters 
	// Interlaced period of 3 rows where ohmic1 and ohmic2 change on each row.
	// interlace_channels = "ohmic1, ohmic2"
	// interlace_values = "500,10,0;10,10,10"
	// ohmic1 will change between 500,10,0 each row
	
	// Example :: Virtual parameters 
	// Interlaced period of 3 rows where ohmic1 and ohmic2 change on each row.
	// virtual_gates = "CSQ*1000"
	// virtual_ratios = "-0.319"
	// virtual_mids = "0"
	// virtual_width = "1000"
	// CSQ*1000 will be scanned from 319 -> -319

	// Set defaults
	delayy = ParamIsDefault(delayy) ? 0.01 : delayy
	comments = selectstring(paramisdefault(comments), comments, "")
	startxs = selectstring(paramisdefault(startxs), startxs, "")
	finxs = selectstring(paramisdefault(finxs), finxs, "")
	startys = selectstring(paramisdefault(startys), startys, "")
	finys = selectstring(paramisdefault(finys), finys, "")
	variable use_bd = paramisdefault(bdid) ? 0 : 1 			// Whether using both FD and BD or just FD
	variable use_second_fd = paramisdefault(fdyID) ? 0 : 1  // Whether using a second FD for the y axis gates
	
	
	///// IF USING INTERLACE ON Y-AXIS (add to comment) /////
	string interlace_comment = ",interlaced scans channels=" + interlace_channels + " values=" + interlace_values
	interlace_comment = ReplaceString(",", interlace_comment, " ")
	comments = comments + interlace_comment
	
	
	///// IF USING VIRTUAL GATES ON X-AXIS /////
	if (!paramisdefault(virtual_gates) && (paramisdefault(virtual_mids) || paramisdefault(virtual_ratios) ))
		ABORT "ERROR[ScanTransition]: virtual_gates specified but virtual_mids or virtual_ratios MISSING"
	endif
	variable k
	if (!paramisdefault(virtual_gates) && !paramisdefault(virtual_mids))
	 	rampmultiplefDAC(fdID, virtual_gates, 0, setpoints_str=virtual_mids) // ramp virtual gates
		variable mid = str2num(scu_getChannelNumbers(StringFromList(0, channelsx, ","), fastdac=1)) // If using virtual ratios assume mid is middle of P*2
		string starts = num2str(startx)
		string fins = num2str(finx)
		string sweep_channels = addlistitem(StringFromList(0, channelsx, ","), virtual_gates, ",", 0)
		variable temp_mid, temp_ratio, temp_start, temp_fin
		for (k=0; k<ItemsInList(virtual_gates, ","); k++)
		
				temp_mid = str2num(StringFromList(k, virtual_mids, ","))
				temp_ratio = str2num(StringFromList(k, virtual_ratios, ","))
				
				temp_start = temp_mid - temp_ratio*virtual_width
				temp_fin = temp_mid + temp_ratio*virtual_width
				
				starts = addlistitem(num2str(temp_start), starts, ",", inf)
				fins = addlistitem(num2str(temp_fin), fins, ",", inf)
		 endfor
	endif

	
	// Reconnect instruments
	sc_openinstrconnections(0)

	// Put info into scanVars struct (to more easily pass around later)
 	struct ScanVars S
 	if (use_bd == 0 && use_second_fd == 0)
 		if (!paramisdefault(virtual_gates) && !paramisdefault(virtual_mids))
 		   // give new starts and fins (calculated from virtual ratios to startxs and finxs) 
	 		initScanVarsFD(S, fdID, startx, finx, channelsx=channelsx, rampratex=rampratex, numptsx=numpts, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
				   						 starty=starty, finy=finy, channelsy=sweep_channels, rampratey=rampratey, startxs=starts, finxs=fins, startys=startys, finys=finys, comments=comments)
 		else
		 	initScanVarsFD(S, fdID, startx, finx, channelsx=channelsx, rampratex=rampratex, numptsx=numpts, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
			   						 starty=starty, finy=finy, channelsy=channelsy, rampratey=rampratey, startxs=startxs, finxs=finxs, startys=startys, finys=finys, comments=comments)
		endif
	
	else  				// Using BabyDAC for Y axis so init x in FD_ScanVars, and init y in BD_ScanVars
		initScanVarsFD(S, fdID, startx, finx, channelsx=channelsx, rampratex=rampratex, numptsx=numpts, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
		   						rampratey=rampratey, startxs=startxs, finxs=finxs, comments=comments)
		s.is2d = 1		   						
		S.starty = starty
		S.finy = finy		
		if (use_bd)
			S.instrIDy = bdID
			S.channelsy = scu_getChannelNumbers(channelsy, fastdac=0)
			S.y_label = scu_getDacLabel(S.channelsy, fastdac=0)
			scv_setSetpoints(S, S.channelsx, S.startx, S.finx, S.channelsy, S.starty, S.finy, S.startxs, S.finxs, S.startys, S.finys)
		else  // use_second_fd
			S.instrIDy = fdyID
			S.channelsy = scu_getChannelNumbers(channelsy, fastdac=1)
			S.y_label = scu_getDacLabel(S.channelsy, fastdac=1)
			scv_setSetpoints(S, S.channelsx, S.startx, S.finx, S.channelsy, S.starty, S.finy, S.startxs, S.finxs, S.startys, S.finys)
		endif
	endif
	
      
   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC

   if(use_bd == 1)
//   		PreScanChecksBD(Bsv)
		PreScanChecksFD(S, x_only=1)
		PreScanChecksBD(S, y_only=1)
   	else  // Should work for 1 or 2 FDs
   	   PreScanChecksFD(S)  
   	endif
   	
  	// If using AWG then get that now and check it
	struct AWGVars AWG
	if(use_AWG)	
		fd_getGlobalAWG(AWG)
		CheckAWG(AWG, S)  // Note: sets S.numptsx here and AWG.lims_checked = 1
	endif
	SetAWG(AWG, use_AWG)
   
   // Ramp to start without checks
   if(use_bd == 1)
	   RampStartFD(S, x_only=1, ignore_lims=1)
	   RampStartBD(S, y_only=1, ignore_lims=1)
   	else  // Should work for 1 or 2 FDs
   	   RampStartFD(S, ignore_lims=1)
   	endif
   	
   	// Let gates settle
	sc_sleep(S.delayy)

	// Initialize waves and graphs
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0
	variable setpointy, sy, fy
	string chy
	string interlace_channel, interlace_values_for_channel
	variable interlace_value
	for(i=0; i<S.numptsy; i++)

		///// LOOP FOR INTERLACE SCANS /////
		if (!paramisdefault(interlace_channels) && !paramisdefault(interlace_values))
				for (k=0; k<ItemsInList(interlace_channels, ","); k++)
					interlace_channel = StringFromList(k, interlace_channels, ",")  // return one of the channels in interlace_channels
					interlace_values_for_channel = StringFromList(k, interlace_values, ";") // return string of values to interlace between for one of the channels in interlace_channels
					interlace_value = str2num(StringFromList(mod(i, ItemsInList(interlace_values_for_channel, ",")), interlace_values_for_channel, ",")) // return the interlace value for specific channel, changes per 1d sweep
			   		rampmultiplefDAC(fdID, interlace_channel, interlace_value)
			   	endfor
//				printf "DEBUG: Ramping channel %s to %.1f\r", interlace_channel, interlace_values[mod(i, numpnts(interlace_values))]							
		endif
		
		
		///// DO NORMAL SCANFASTDAC2D /////
		// Ramp fast axis to start
		rampToNextSetpoint(S, 0, fastdac=1, ignore_lims=1)

		// Ramp slow axis
		rampToNextSetpoint(S, 0, outer_index=i, y_only=1, fastdac=!use_bd, ignore_lims=1)

		// Let gates settle
		sc_sleep(S.delayy)
		
		// Record fast axis
		scfd_RecordValues(S, i, AWG_list=AWG)
		
		
		
	endfor

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
  	else
  		dowindow /k SweepControl
	endif

end





function Scank2400(instrID, startx, finx, channelsx, numptsx, delayx, rampratex, [y_label, comments, nosave]) //Units: mV
	variable instrID, startx, finx, numptsx, delayx, rampratex,  nosave
	string channelsx, y_label, comments
	abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=instrID, startx=startx, finx=finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
	 						y_label=y_label, comments=comments)

	// Check software limits and ramprate limits
	// PreScanChecksKeithley(S)  
	
	// Ramp to start without checks because checked above
	rampK2400Voltage(S.instrIDx, startx)
	
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, setpointx
	do
		setpointx = S.startx + (i*(S.finx-S.startx)/(S.numptsx-1))
		rampK2400Voltage(S.instrIDx, setpointx, ramprate=S.rampratex)
		sc_sleep(S.delayx)
		RecordValues(S, i, i)
		i+=1
	while (i<S.numptsx)
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end


function Scank24002D(instrIDx, startx, finx, numptsx, delayx, rampratex, instrIDy, starty, finy, numptsy, delayy, rampratey, [y_label, comments, nosave]) //Units: mV
	variable instrIDx, startx, finx, numptsx, delayx, rampratex, instrIDy, starty, finy, numptsy, delayy, rampratey, nosave
	string y_label, comments
	abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	y_label = selectstring(paramisdefault(y_label), y_label, "Keithley /mV")

	
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=instrIDx, startx=startx, finx=finx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
							instrIDy=instrIDy, starty=starty, finy=finy, numptsy=numptsy, delayy=delayy, rampratey=rampratey, \
	 						y_label=y_label, comments=comments)

	// Check software limits and ramprate limits
	// PreScanChecksKeithley(S)  
	
	// Ramp to start without checks because checked above
	rampK2400Voltage(S.instrIDx, startx)
	rampK2400Voltage(S.instrIDy, starty)
	
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpointx, setpointy
	do
		setpointx = S.startx
		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))
		rampK2400Voltage(S.instrIDy, setpointy, ramprate=S.rampratey)
		rampK2400Voltage(S.instrIDx, setpointx, ramprate=S.rampratex)

		sc_sleep(S.delayy)
		j=0
		do
			setpointx = S.startx + (j*(S.finx-S.startx)/(S.numptsx-1))
			rampK2400Voltage(S.instrIDx, setpointx, ramprate=S.rampratex)
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
			j+=1
		while (j<S.numptsx)
	i+=1
	while (i<S.numptsy)
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end


function ScanBabyDACK24002D(bdID, startx, finx, channelsx, numptsx, delayx, rampratex, keithleyID, starty, finy, numptsy, delayy, rampratey, [startxs, finxs, y_label, comments, nosave]) //Units: mV
	// Sweeps BabyDAC on x-axis and Keithley on y-axis
	variable bdID, startx, finx, numptsx, delayx, rampratex, keithleyID, starty, finy, numptsy, delayy, rampratey, nosave
	string channelsx, y_label, comments
	string startxs, finxs
	abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "Keithley /mV")
	startxs = selectstring(paramisdefault(startxs), startxs, "")
	finxs = selectstring(paramisdefault(finxs), finxs, "")
	
	// Initialize ScanVars
	struct ScanVars S
	initScanVarsBD(S, bdID, startx, finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
							starty=starty, finy=finy, numptsy=numptsy, delayy=delayy, rampratey=rampratey, \
	 						startxs=startxs, finxs=finxs, comments=comments)
	S.startx = str2num(stringFromList(0, S.startxs, ","))
	S.finx = str2num(stringFromList(0, S.finxs, ","))
	S.instrIDy = keithleyID
	S.y_label = y_label

	// Check software limits and ramprate limits
	PreScanChecksBD(S, x_only=1)  
	// PreScanChecksKeithley(S, y_only=1)
	
	// Ramp to start without checks because checked above
	RampStartBD(S, x_only=1, ignore_lims=1)
	rampK2400Voltage(S.instrIDy, starty, ramprate=S.rampratey)
	
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpointy
	for (i=0;i<S.numptsy;i++)
		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))
		rampK2400Voltage(S.instrIDy, setpointy, ramprate=S.rampratey)
		rampToNextSetpoint(S, 0, ignore_lims=1) // Ramp BDs back to start(s)
		sc_sleep(S.delayy)
		j=0
		for (j=0;j<S.numptsx;j++)
			rampToNextSetpoint(S, j, ignore_lims=1) // Ramp BDs to next setpoint(s)
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
		endfor
	endfor
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end


function ScanBabyDACMultipleK24002D(bdID, startx, finx, channelsx, numptsx, delayx, rampratex, keithleyIDs, starty, finy, numptsy, [startxs, finxs, startys, finys, delayy, rampratey, y_label, comments, nosave]) //Units: mV
	// Sweeps BabyDACs in fast axis and multiple Keithleys on y-axis
	variable startx, finx, numptsx, delayx, rampratex, bdID, starty, finy, numptsy, delayy, rampratey, nosave
	string channelsx, keithleyIDs, y_label, comments
	string startxs, finxs, startys, finys // For different start/finish points for each channel (must match length of instrIDs if used)
	abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	y_label = selectstring(paramisdefault(y_label), y_label, "Keithleys /mV")
	startxs = selectstring(paramisdefault(startxs), startxs, "")
	finxs = selectstring(paramisdefault(finxs), finxs, "")
	startys = selectstring(paramisdefault(startys), startys, "")
	finys = selectstring(paramisdefault(finys), finys, "")

	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=bdID, startx=startx, finx=finx, numptsx=numptsx, channelsx=channelsx, delayx=delayx, rampratex=rampratex, starty=starty, finy=finy, numptsy=numptsy, delayy=delayy, rampratey=rampratey, \
	 						startxs=startxs, finxs=finxs, startys=startys, finys=finys, y_label=y_label, comments=comments)
	scv_setSetpoints(S, S.channelsx, S.startx, S.finx, keithleyIDs, S.starty, S.finy, S.startxs, S.finxs, S.startys, S.finys)  // Sets up startxs,finxs,startys,finys

	// Check software limits and ramprate limits
	PreScanChecksBD(S, x_only=1)
	// PreScanChecksKeithley(S)  
	// PreScanChecksMagnet(S, y_only=1)
	
	// Ramp to start without checks because checked above
	rampToNextSetpoint(S, 0, ignore_lims=1)  // Ramp BDs to start(s) 
	rampMultipleK2400s(keithleyIDs, 0, S.numptsy, S.startys, S.finys, ramprate=S.rampratey)  // Ramp Keithleys to start(s)
	
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)  

	// Main measurement loop
	variable i=0, j=0, setpointy
	for(i=0;i<S.numptsy;i++)
		rampToNextSetpoint(S, 0, ignore_lims=1)  // Ramp BDs to start(s) 
		rampMultipleK2400s(keithleyIDs, i, S.numptsy, S.startys, S.finys, ramprate=S.rampratey)  // Ramp Keithleys to next setpoint(s)
		
		// Delay
		sc_sleep(S.delayy)
		for(j=0;j<S.numptsx;j++)
			rampToNextSetpoint(S, j, ignore_lims=1)  // Ramp BDs to next setpoint(s)
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
		endfor
	endfor
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end


function ScanFastDACK24002D(fdID, startx, finx, keithleyID, starty, finy, numptsy, [numpts, sweeprate, rampratex, rampratey, delayy, startxs, finxs, y_label, comments, nosave, use_AWG])
	// 2D Scan with Fastdac on x-axis and keithley on y-axis
	// Note: Must provide numptsx OR sweeprate in optional parameters instead
	// Note: channels should be a comma-separated string ex: "0,4,5"
	variable fdID, startx, finx, starty, finy, numptsy, numpts, sweeprate, keithleyID, rampratex, rampratey, delayy, nosave, use_AWG
	string y_label, comments
	string startxs, finxs // For different start/finish points for each channel (must match length of channels if used)
	abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	

	// Set defaults
	delayy = ParamIsDefault(delayy) ? 0.01 : delayy
	comments = selectstring(paramisdefault(comments), comments, "")
	startxs = selectstring(paramisdefault(startxs), startxs, "")
	finxs = selectstring(paramisdefault(finxs), finxs, "")

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Put info into scanVars struct (to more easily pass around later)
 	struct ScanVars S
	// Init FastDAC part like usual, then manually set the rest
	initScanVarsFD(S, fdID, startx, finx, rampratex=rampratex, numptsx=numpts, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
							rampratey=rampratey, startxs=startxs, finxs=finxs, comments=comments)
	S.instrIDy = keithleyID
	s.is2d = 1
	S.starty = starty
	S.finy = finy
	S.y_label = selectString(paramIsDefault(y_label), y_label, "Keithley /mV")
      
   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
	PreScanChecksFD(S, x_only=1)
	// PreScanChecksKeithley(S, y_only=1)
   	
   // Ramp to start without checks
	RampStartFD(S, x_only=1, ignore_lims=1)
	rampK2400Voltage(S.instrIDy, S.starty, ramprate=S.rampratey)
   	
   	// Let gates settle
	sc_sleep(S.delayy*5)

	// Initialize waves and graphs
	initializeScan(S)

	// Main measurement loop
	variable setpointy
	variable i=0, j=0
	string chy
	for(i=0; i<S.numptsy; i++)
		// Ramp slow axis
		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))	
		rampK2400Voltage(S.instrIDy, setpointy, ramprate=S.rampratey)

		// Ramp to start of fast axis
		RampStartFD(S, ignore_lims=1, x_only=1)
		sc_sleep(S.delayy)
		
		// Record fast axis
		scfd_RecordValues(S, i)
	endfor

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
  	else
  		dowindow /k SweepControl
	endif

end


function ScanMultipleK2400(instrIDs, start, fin, numptsx, delayx, rampratex, [starts, fins, numptsy, delayy, y_label, comments, nosave]) //Units: mV
	variable start, fin, numptsx, delayx, rampratex, numptsy, delayy, nosave
	string instrIDs, y_label, comments
	string starts, fins // For different start/finish points for each channel (must match length of instrIDs if used)
	abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	starts = selectstring(paramisdefault(starts), starts, "")
	fins = selectstring(paramisdefault(fins), fins, "")

	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, startx=start, finx=fin, numptsx=numptsx, delayx=delayx, rampratex=rampratex, numptsy=numptsy, delayy=delayy, \
	 						startxs=starts, finxs=fins, y_label=y_label, comments=comments)
	scv_setSetpoints(S, instrIDs, S.startx, S.finx, "", 0, 0, S.startxs, S.finxs, "", "")  // Sets up startxs,finxs

	// Check software limits and ramprate limits
	// PreScanChecksKeithley(S)  
	
	// Ramp to start without checks because checked above
	rampMultipleK2400s(instrIDs, 0, S.numptsx, S.startxs, S.finxs, ramprate=S.rampratex)
	
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)  

	// Main measurement loop
	variable i=0, j=0
	for(i=0;i<S.numptsy;i++)
		for(j=0;j<S.numptsx;j++)
			rampMultipleK2400s(instrIDs, j, S.numptsx, S.startxs, S.finxs, ramprate=S.rampratex)
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
		endfor
	endfor
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end



function ScanMultipleK2400LS625Magnet2D(keithleyIDs, start, fin, numptsx, delayx, rampratex, magnetID, starty, finy, numptsy, [starts, fins, delayy, y_label, comments, nosave]) //Units: mV
	variable start, fin, numptsx, delayx, rampratex, magnetID, starty, finy, numptsy, delayy, nosave
	string keithleyIDs, y_label, comments
	string starts, fins // For different start/finish points for each channel (must match length of instrIDs if used)
	abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	y_label = selectstring(paramisdefault(y_label), y_label, "Field /mT")
	starts = selectstring(paramisdefault(starts), starts, "")
	fins = selectstring(paramisdefault(fins), fins, "")

	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, startx=start, finx=fin, numptsx=numptsx, delayx=delayx, rampratex=rampratex, starty=starty, finy=finy, numptsy=numptsy, delayy=delayy, \
	 						startxs=starts, finxs=fins, y_label=y_label, comments=comments)
	S.instrIDy = magnetID

	// Check software limits and ramprate limits
	// PreScanChecksKeithley(S)  
	// PreScanChecksMagnet(S, y_only=1)
	
	// Ramp to start without checks because checked above
	rampMultipleK2400s(keithleyIDs, 0, S.numptsx, S.startxs, S.finxs, ramprate=S.rampratex)
	setlS625fieldWait(S.instrIDy, S.starty)
	
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)  

	// Main measurement loop
	variable i=0, j=0, setpointy
	for(i=0;i<S.numptsy;i++)
		// Ramp Keithleys back to start
		rampMultipleK2400s(keithleyIDs, 0, S.numptsx, S.startxs, S.finxs, ramprate=S.rampratex)

		// Ramp Magnet to next setpoint
		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))	
		setlS625fieldWait(S.instrIDy, S.starty)
		
		// Delay
		sc_sleep(S.delayy)
		for(j=0;j<S.numptsx;j++)
			rampMultipleK2400s(keithleyIDs, j, S.numptsx, S.startxs, S.finxs, ramprate=S.rampratex)
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
		endfor
	endfor
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end



function ScanLS625Magnet(instrID, startx, finx, numptsx, delayx, [y_label, comments, nosave]) 
	variable instrID, startx, finx, numptsx, delayx,  nosave
	string y_label, comments
	abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "Field /mT")
	
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=instrID, startx=startx, finx=finx, numptsx=numptsx, delayx=delayx, \
	 						y_label=y_label, comments=comments)
							

	// Check software limits and ramprate limits
	// PreScanChecksMagnet(S)
	
	// Ramp to start without checks because checked above
	setlS625fieldWait(S.instrIDx, S.startx)
	
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, setpointx
	do
		setpointx = S.startx + (i*(S.finx-S.startx)/(S.numptsx-1))
		setlS625fieldWait(S.instrIDx, setpointx) 
		sc_sleep(S.delayx)
		RecordValues(S, i, i)
		i+=1
	while (i<S.numptsx)
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end


function ScanBabyDACLS625Magnet2D(bdID, startx, finx, channelsx, numptsx, delayx, rampratex, magnetID, starty, finy, numptsy, delayy, rampratey, [startxs, finxs, y_label, comments, nosave]) //Units: mV
	// Sweeps BabyDAC on x-axis and Keithley on y-axis
	variable bdID, startx, finx, numptsx, delayx, rampratex, magnetID, starty, finy, numptsy, delayy, rampratey, nosave
	string channelsx, y_label, comments
	string startxs, finxs // For different start/finish points for each channel (must match length of channels if used)
	abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "Field /mT")
	startxs = selectstring(paramisdefault(startxs), startxs, "")
	finxs = selectstring(paramisdefault(finxs), finxs, "")
	
	// Initialize ScanVars
	struct ScanVars S
	initScanVarsBD(S, bdID, startx, finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
							starty=starty, finy=finy, numptsy=numptsy, delayy=delayy, rampratey=rampratey, \
	 						startxs=startxs, finxs=finxs, comments=comments)
	S.instrIDy = magnetID
	S.y_label = y_label

	// Check software limits and ramprate limits
	PreScanChecksBD(S, x_only=1)  
	// PreScanChecksMagnet(S, y_only=1)
	
	// Ramp to start without checks because checked above
	RampStartBD(S, x_only=1, ignore_lims=1)
	setlS625fieldWait(S.instrIDy, S.starty) 
	
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpointy
	for(i=0;i<S.numptsy;i++)
		rampToNextSetpoint(S, 0, ignore_lims=1)  // Ramp BDs back to start(s)
		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))
		setlS625fieldWait(S.instrIDy, setpointy) 
		sc_sleep(S.delayy)
		j=0
		for(j=0;j<S.numptsx;j++)
			rampToNextSetpoint(S, j, ignore_lims=1)  // Ramp BDs to next setpoint(s)
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
		endfor
	endfor
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end


function ScanFastDACLS625Magnet2D(fdID, startx, finx, channelsx, magnetID, starty, finy, numptsy, [numpts, sweeprate, rampratex, delayy, startxs, finxs, y_label, comments, nosave, use_AWG])
	// 2D Scan with Fastdac on x-axis and keithley on y-axis
	// Note: Must provide numptsx OR sweeprate in optional parameters instead
	// Note: channels should be a comma-separated string ex: "0,4,5"
	variable fdID, startx, finx, starty, finy, numptsy, numpts, sweeprate, magnetID, rampratex, delayy, nosave, use_AWG
	string channelsx, y_label, comments, startxs, finxs
	abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	

	// Set defaults
	delayy = ParamIsDefault(delayy) ? 0.01 : delayy
	comments = selectstring(paramisdefault(comments), comments, "")
	startxs = selectstring(paramisdefault(startxs), startxs, "")
	finxs = selectstring(paramisdefault(finxs), finxs, "")

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Put info into scanVars struct (to more easily pass around later)
 	struct ScanVars S
	// Init FastDAC part like usual, then manually set the rest
	initScanVarsFD(S, fdID, startx, finx, channelsx=channelsx, rampratex=rampratex, numptsx=numpts, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
							startxs=startxs, finxs=finxs, comments=comments)
	S.instrIDy = magnetID
	s.is2d = 1
	S.starty = starty
	S.finy = finy
	S.y_label = selectString(paramIsDefault(y_label), y_label, "Magnet /mT")
      
   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
	PreScanChecksFD(S, x_only=1)
	// PreScanChecksMagnet(S, y_only=1)
   	
   // Ramp to start without checks
	RampStartFD(S, x_only=1, ignore_lims=1)
	setlS625fieldWait(S.instrIDy, S.starty)  // Ramprate should be set beforehand for magnets
   	
   	// Let gates settle
	sc_sleep(S.delayy*5)

	// Initialize waves and graphs
	initializeScan(S)

	// Main measurement loop
	variable setpointy, sy, fy
	variable i=0, j=0
	string chy
	for(i=0; i<S.numptsy; i++)
		// Ramp slow axis
		setpointy = sy + (i*(S.finy-S.starty)/(S.numptsy-1))	
		setlS625fieldWait(S.instrIDy, S.starty)  // Ramprate should be set beforehand for magnets

		// Ramp to start of fast axis
		RampStartFD(S, ignore_lims=1, x_only=1)
		sc_sleep(S.delayy)
		
		// Record fast axis
		scfd_RecordValues(S, i)
	endfor

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
  	else
  		dowindow /k SweepControl
	endif

end


function ScanK2400LS625Magnet2D(keithleyID, startx, finx, channelsx, numptsx, delayx, rampratex, magnetID, starty, finy, numptsy, delayy, rampratey, [y_label, comments, nosave]) //Units: mV
	variable keithleyID, startx, finx, numptsx, delayx, rampratex, magnetID, starty, finy, numptsy, delayy, rampratey, nosave
	string channelsx, y_label, comments
	abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	y_label = selectstring(paramisdefault(y_label), y_label, "Field /mT")

	
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=keithleyID, startx=startx, finx=finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
							instrIDy=magnetID, starty=starty, finy=finy, numptsy=numptsy, delayy=delayy, rampratey=rampratey, \
	 						y_label=y_label, comments=comments)

	// Check software limits and ramprate limits
	// PreScanChecksKeithley(S, x_only=1)  
	// PreScanChecksMagnet(S, y_only=1)
	
	// Ramp to start without checks because checked above
	rampK2400Voltage(S.instrIDx, startx, ramprate=S.rampratex)
	setlS625fieldWait(S.instrIDy, starty)
	
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpointx, setpointy
	do
		setpointx = S.startx
		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))
		setlS625fieldWait(S.instrIDy, setpointy)
		rampK2400Voltage(S.instrIDx, setpointx, ramprate=S.rampratex)

		sc_sleep(S.delayy)
		j=0
		do
			setpointx = S.startx + (j*(S.finx-S.startx)/(S.numptsx-1))
			rampK2400Voltage(S.instrIDx, setpointx, ramprate=S.rampratex)
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
			j+=1
		while (j<S.numptsx)
	i+=1
	while (i<S.numptsy)
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end

function ScanSRSFrequency(instrID, startx, finx, numptsx, delayx, nosave)
	variable instrID, startx, finx, numptsx, delayx, nosave
	string channelsx, y_label, comments

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Set defaults
	//	comments = selectstring(paramisdefault(comments), comments, "")
	//	y_label = selectstring(paramisdefault(y_label), y_label, "")

	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=instrID, startx=startx, finx=finx, numptsx=numptsx, delayx=delayx)

	// Ramp to start without checks because checked above
	SetSRSFrequency(S.instrIDx,startx)

	// Let gates settle
	sc_sleep(S.delayy*10)

	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, setpointx
	do
		setpointx = S.startx + (i*(S.finx-S.startx)/(S.numptsx-1))
		SetSRSFrequency(S.instrIDx,setpointx)
		sc_sleep(S.delayx)
		RecordValues(S, i, i)
		i+=1
	while (i<S.numptsx)

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		dowindow /k SweepControl
	endif
	//if repeated scans, it may be a good idea to reset the frequency here,
	//SetSRSFrequency(S.instrIDx,startx)

end



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////// Useful Templates //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function ScanMultiVarTemplate()
	//Template loop for varying up to three parameters around any scan
	// nvar fastdac, bd6
	
	/////////// Scan Params  ///////////
	// e.g. start, fin, numpts etc... Just easier to put them all here than in one long scan function
	
	
	////////////////////////////////////
	
	
	//////////// Scan Variables to change between scans ////////////////
	make/o/free Var1 = {0}
	make/o/free Var2 = {0}
	make/o/free Var3 = {0}
	////////////////////////////////////////////////////////////////////
	
	
	variable numi = numpnts(Var1), numj = numpnts(Var2), numk = numpnts(Var3)
	variable ifin = numi, jfin = numj, kfin = numk
	variable istart, jstart, kstart
	
	
	/////// Change range of outer scan variables (useful when retaking a few measurements) ////////
	/// Starts
	istart=0; jstart=0; kstart=0
	
	/// Fins
	ifin=ifin; jfin=jfin; kfin=kfin
	////////////////////////////////////////////////////////////////////////////////////////////////
	
	
	string comments
	variable i, j, k
	i = istart; j=jstart; k=kstart
	for(k=kstart;k<kfin;k++)  // Loop for change k var 3
		kstart = 0  // Reset for next loop if started somewhere in middle
		//RAMP VAR 3
		for(j=jstart;j<jfin;j++)	// Loop for change j var2
			jstart = 0  // Reset for next loop if started somewhere in middle
			//RAMP VAR 2
			for(i=istart;i<ifin;i++) // Loop for changing i var1 and running scan
				istart = 0  // Reset for next loop if started somewhere in middle
				// RAMP VAR 1
				printf "Starting scan at i=%d, j=%d, k=%d, Var1 = %.1fmV, Var2 = %.1fmV, Var3 = %.1fmV\r", i, j, k, Var1[i], Var2[j], Var3[k]
				sprintf comments, ""
			
				//SCAN HERE
				
			endfor
		endfor
	endfor
	print "Finished all scans"
end



function StepTempScanSomething()
 svar ls370


	make/o targettemps =  {300, 275, 250, 225, 200, 175, 150, 125, 100, 75, 50, 40, 30, 20}
	make/o heaterranges = {10, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 1, 1, 1, 1}
	setLS370exclusivereader(ls370,"mc") 
	variable i=0
	do
		setLS370Temp(ls370,targettemps[i],maxcurrent = heaterranges[i])
		sc_sleep(2.0)
		WaitTillTempStable(ls370, targettemps[i], 5, 20, 0.10)
		sc_sleep(60.0)
		print "MEASURE AT: "+num2str(targettemps[i])+"mK"


		//SCAN HERE

		i+=1
	while ( i<numpnts(targettemps) )

	// kill temperature control
	setLS370heaterOff(ls370)
	
	resetLS370exclusivereader(ls370)
	sc_sleep(60.0*30)

	// 	SCAN HERE for base temp
end




