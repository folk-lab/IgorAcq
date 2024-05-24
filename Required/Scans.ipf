#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method

// Standard Scan Functions
// Written by Tim Child, 2021-12
// Update by Johann, 2024-05 (To be in-line with new Swagger methods)

// Note: This .ipf is not intended to be included in the experiment as it has many dependencies.
// Note: You should copy the functions you will use from here into your own .ipf or procedure.ipf file

// Full list of scans here:
// ReadVsTime
// ScanK2400
// ScanK24002D
// ScanFastDACK24002D
// ScanMultipleK2400
// ScanMutipleK2400LS625Magnet2D
// ScanLS625Magnet
// ScanFastDACLS625Magenet2D
// ScanK2400LS625Magent2D
// ScanSRSFrequency

// Templates:
// ScanMultiVarTemplate -- Helpful template for running a scan inside multiple loops where other variables can change (i.e. up to 5D scans)
// StepTempScanSomething -- Scanning at multiple fridge temperatures


function ReadVsTime(delay,N [y_label, comments]) // Units: s
	variable delay,N
	string y_label, comments
	variable i = 0

	comments = selectString(paramIsDefault(comments), comments, "")
	y_label = selectString(paramIsDefault(y_label), y_label, "")	

	Struct ScanVars S
	initScanVars(S, numptsx=N)
	initializeScan(S)
	S.readVsTime = 1

	variable/g sc_scanstarttime = datetime
	S.start_time = datetime
	do
		asleep(delay)
		RecordValues(S, i, 0)
		doupdate
		i+=1
	while (i<N)
	S.end_time = datetime
	EndScan(S=S)
end




function Scank2400(instrID, startx, finx, channelsx, numptsx, delayx, rampratex, [y_label, comments, nosave]) //Units: mV
	variable instrID, startx, finx, numptsx, delayx, rampratex,  nosave
	string channelsx, y_label, comments
	//abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=instrID, startx=startx, finx=finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
	 						y_label=y_label, x_label = "k2400", comments=comments)

	// Check software limits and ramprate limits
	// PreScanChecksKeithley(S)  
	
	// Ramp to start without checks because checked above
	rampK2400Voltage(S.instrIDx, startx)
	
	// Let gates settle 
	sc_sleep(S.delayy*20)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, setpointx
	do
		setpointx = S.startx + (i*(S.finx-S.startx)/(S.numptsx-1))
//		rampK2400Voltage(S.instrIDx, setpointx, ramprate=S.rampratex)
		setK2400Voltage(S.instrIDx, setpointx)
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
	//abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	y_label = selectstring(paramisdefault(y_label), y_label, "k2400 (mV)")

	
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=instrIDx, startx=startx, finx=finx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
							instrIDy=instrIDy, starty=starty, finy=finy, numptsy=numptsy, delayy=delayy, rampratey=rampratey, \
	 						y_label=y_label, x_label = "k2400 (mV)", comments=comments)

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
//			rampK2400Voltage(S.instrIDx, setpointx, ramprate=S.rampratex)
			setK2400Voltage(S.instrIDx, setpointx)
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




function ScanFastDACK24002D(startx, finx, channelsx, keithleyID, starty, finy, numptsy, [numpts, sweeprate, rampratex, rampratey, delayy, startxs, finxs, y_label, comments, nosave, use_AWG])
	// not tested but should likely work - master/slave updated.
	
	
	// 2D Scan with Fastdac on x-axis and keithley on y-axis
	// Note: Must provide numptsx OR sweeprate in optional parameters instead
	// Note: channels should be a comma-separated string ex: "0,4,5"
	variable startx, finx, starty, finy, numptsy, numpts, sweeprate, keithleyID, rampratex, rampratey, delayy, nosave, use_AWG
	string y_label, comments
	string startxs, finxs, channelsx // For different start/finish points for each channel (must match length of channels if used)

	// Set defaults
	delayy = ParamIsDefault(delayy) ? 0.01 : delayy
	comments = selectstring(paramisdefault(comments), comments, "")
	startxs = selectstring(paramisdefault(startxs), startxs, "")
	finxs = selectstring(paramisdefault(finxs), finxs, "")
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Put info into scanVars struct (to more easily pass around later)
 	struct ScanVars S
	initScanVarsFD(S, startx, finx, channelsx = channelsx, rampratex=rampratex, numptsx=numpts, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
							rampratey=rampratey, startxs=startxs, finxs=finxs, comments=comments)
							
	S.instrIDy = keithleyID
	s.is2d = 1
	S.starty = starty
	S.finy = finy
	S.y_label = selectString(paramIsDefault(y_label), y_label, "Keithley /mV")
      
   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
	PreScanChecksFD(S)
   	
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



function ScanLS625Magnet(instrID, startx, finx, numptsx, delayx, [y_label, comments, nosave, fast]) //set fast=1 to run quickly
	variable instrID, startx, finx, numptsx, delayx,  nosave, fast
	string y_label, comments
	
	
	variable ramprate
	
	if(paramisdefault(fast))
		fast=0
	endif
	
	
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	

	
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=instrID, startx=startx, finx=finx, numptsx=numptsx, delayx=delayx, \
	 						y_label=y_label, comments=comments)
							

	// Check software limits and ramprate limits
	// PreScanChecksMagnet(S)
	ramprate = getLS625rate(S.instrIDx)
	
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
		if(fast==1)
			setlS625field(S.instrIDx, setpointx) 
			sc_sleep(max(S.delayx, (0.05+60*abs(finx-startx)/numptsx/ramprate)))
		else
			setlS625fieldwait(S.instrIDx, setpointx) 
			sc_sleep(S.delayx)
		endif
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


function ScanFastDACLS625Magnet2D(startx, finx, channelsx, magnetID, starty, finy, numptsy, [numpts, sweeprate, rampratex, delayy, startxs, finxs, y_label, comments, nosave, use_AWG])

	// not tested but should likely work - master/slave updated.
	
	// 2D Scan with Fastdac on x-axis and magnet on y-axis
	// Note: Must provide numptsx OR sweeprate in optional parameters instead
	// Note: channels should be a comma-separated string ex: "0,4,5"
	variable startx, finx, starty, finy, numptsy, numpts, sweeprate, magnetID, rampratex, delayy, nosave, use_AWG
	string channelsx, y_label, comments, startxs, finxs
	//abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	
	
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
	initScanVarsFD(S, startx, finx, channelsx=channelsx, rampratex=rampratex, numptsx=numpts, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
							startxs=startxs, finxs=finxs, comments=comments)
	S.instrIDy = magnetID
	s.is2d = 1
	S.starty = starty
	S.finy = finy
	S.y_label = selectString(paramIsDefault(y_label), y_label, "Magnet /mT")
      
   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
	PreScanChecksFD(S)
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
		setlS625fieldWait(S.instrIDy, setpointy)  // Ramprate should be set beforehand for magnets

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


function ScanFastDacSlowLS625Magnet2D(instrIDx, startx, finx, channelsx, numptsx, delayx, rampratex, magnetID, starty, finy, numptsy, delayy, [rampratey, y_label, comments, nosave])
	// sweep one or more FastDAC channels but in the ScanController way (not ScanControllerFastdac). I.e. ramp, measure, ramp, measure...
	// channels should be a comma-separated string ex: "0, 4, 5"
	
	
	// not tested - should be tested - master/slave updated.
	variable instrIDx, startx, finx, numptsx, delayx, rampratex, magnetID, starty, finy, numptsy, delayy, nosave, rampratey
	string channelsx, comments, y_label
	
	//check if rawdata needs to be saved
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	
	// Initialize ScanVars
	struct ScanVars S
	initScanVarsFD(S, startx, finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, starty=starty, finy=finy, delayy=delayy,\
	 					rampratey=rampratey, numptsy=numptsy, y_label=y_label, comments=comments)
	
	S.instrIDy = magnetID 
	
	
	
	// Check limits (not as much to check when using FastDAC slow)
	scc_checkLimsFD(S)
	S.lims_checked = 1

	//set_master_slave(S): we do not need master-slave for slow scans
	
	// Ramp to start without checks since checked above
	RampStartFD(S, ignore_lims = 1)
	
	if (!paramIsDefault(rampratey))
		setLS625rate(magnetID,rampratey)
	endif
	setlS625fieldWait(S.instrIDy, starty)
	
	// Let gates settle 
	asleep(S.delayy*10)

	// Make Waves and Display etc
	InitializeScan(S)
	
	// Main measurement loop
	variable i=0, j=0, setpointx, setpointy
	do
		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))
		setlS625field(S.instrIDy, setpointy)
		RampStartFD(S, ignore_lims=1, x_only=1)
		setlS625fieldwait(S.instrIDy, setpointy, short_wait = 1)
		sc_sleep(S.delayy)
		j=0
		do
			rampToNextSetpoint(S, j, ignore_lims=1)  // Ramp x to next setpoint
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
			j++
		while (j<S.numptsx)
	i++
	while (i<S.numptsy)

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		dowindow /k SweepControl
	endif
end


function ScanFastDACIPS120Magnet2D(startx, finx, channelsx, magnetID, starty, finy, numptsy, [numpts, sweeprate, rampratex, delayy, startxs, finxs, y_label, comments, nosave, use_AWG])	
	// 2D Scan with Fastdac on x-axis and magnet on y-axis
	// Note: Must provide numptsx OR sweeprate in optional parameters instead
	// Note: channels should be a comma-separated string ex: "0,4,5"
	variable startx, finx, starty, finy, numptsy, numpts, sweeprate, magnetID, rampratex, delayy, nosave, use_AWG
	string channelsx, y_label, comments, startxs, finxs
	//abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	

	// Set defaults
	delayy = ParamIsDefault(delayy) ? 0.01 : delayy
	comments = selectstring(paramisdefault(comments), comments, "")
	startxs = selectstring(paramisdefault(startxs), startxs, "")
	finxs = selectstring(paramisdefault(finxs), finxs, "")
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Put info into scanVars struct (to more easily pass around later)
 	struct ScanVars S
	initScanVarsFD(S, startx, finx, channelsx=channelsx, rampratex=rampratex, numptsx=numpts, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
							startxs=startxs, finxs=finxs, comments=comments)
	S.instrIDy = magnetID
	s.is2d = 1
	S.starty = starty
	S.finy = finy
	S.y_label = selectString(paramIsDefault(y_label), y_label, "Magnet mT")
      
   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
	PreScanChecksFD(S)
	// PreScanChecksMagnet(S, y_only=1)
	
   // Ramp to start without checks
	RampStartFD(S, x_only=1, ignore_lims=1)
	setIPS120fieldWait(S.instrIDy, S.starty)  // Ramprate should be set beforehand for magnets
   	
   	// Let gates settle
	sc_sleep(S.delayy*5)

	// Initialize waves and graphs
	initializeScan(S)

	// Main measurement loop
	variable setpointy, sy, fy
	
	//
	sy = starty
	//
	
	variable i=0, j=0
	string chy
	for(i=0; i<S.numptsy; i++)
		// Ramp slow axis
		setpointy = sy + (i*(S.finy-S.starty)/(S.numptsy-1))	
		setIPS120fieldWait(S.instrIDy, setpointy)  // Ramprate should be set beforehand for magnets

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

function ScanFastDacSlowIPS120Magnet2D(instrIDx, startx, finx, channelsx, numptsx, delayx, rampratex, magnetID, starty, finy, numptsy, delayy, [rampratey, y_label, comments, nosave])
	// sweep one or more FastDAC channels but in the ScanController way (not ScanControllerFastdac). I.e. ramp, measure, ramp, measure...
	// channels should be a comma-separated string ex: "0, 4, 5"
	
	
	// not tested - should be tested - master/slave updated.
	variable instrIDx, startx, finx, numptsx, delayx, rampratex, magnetID, starty, finy, numptsy, delayy, nosave, rampratey
	string channelsx, comments, y_label
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	
	// Initialize ScanVars
	struct ScanVars S
	initScanVarsFD(S, startx, finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, starty=starty, finy=finy, delayy=delayy,\
	 					rampratey=rampratey, numptsy=numptsy, y_label=y_label, comments=comments)
	
	S.instrIDy = magnetID 
	
	
	// Check limits (not as much to check when using FastDAC slow)
	scc_checkLimsFD(S)
	S.lims_checked = 1

	//set_master_slave(S): we do not need master-slave for slow scans
	
	// Ramp to start without checks since checked above
	RampStartFD(S, ignore_lims = 1)
	// no need to check the ramprate for the magnet, assume that it's slow enough
	setIPS120fieldWait(S.instrIDy, starty)
	
	// Let gates settle 
	asleep(S.delayy*10)

	// Make Waves and Display etc
	InitializeScan(S)
	
	// Main measurement loop
	variable i=0, j=0, setpointx, setpointy
	do
		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))
		setIPS120field(S.instrIDy, setpointy)
		RampStartFD(S, ignore_lims=1, x_only=1)
		setIPS120fieldWait(S.instrIDy, setpointy)
		sc_sleep(S.delayy)
		j=0
		do
			rampToNextSetpoint(S, j, ignore_lims=1)  // Ramp x to next setpoint
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
			j++
		while (j<S.numptsx)
	i++
	while (i<S.numptsy)

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		dowindow /k SweepControl
	endif
end


function ScanK2400LS625Magnet2D(keithleyID, startx, finx, numptsx, delayx, rampratex, magnetID, starty, finy, numptsy, delayy, [rampratey, y_label, comments, nosave]) //Units: mV
	variable keithleyID, startx, finx, numptsx, delayx, rampratex, magnetID, starty, finy, numptsy, delayy, rampratey, nosave
	string y_label, comments
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	y_label = selectstring(paramisdefault(y_label), y_label, "Field /mT")

	
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=keithleyID, startx=startx, finx=finx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
							instrIDy=magnetID, starty=starty, finy=finy, numptsy=numptsy, delayy=delayy, rampratey=rampratey, \
	 						y_label=y_label, comments=comments)

	// Check software limits and ramprate limits
	// PreScanChecksKeithley(S, x_only=1)  
	// PreScanChecksMagnet(S, y_only=1)
	
	// Ramp to start without checks because checked above
	rampK2400Voltage(S.instrIDx, startx, ramprate=S.rampratex)
	
	if (!paramIsDefault(rampratey))
		setLS625rate(magnetID,rampratey)
	endif
	setlS625fieldWait(S.instrIDy, starty )
	
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
//		setK2400Voltage(S.instrIDy, setpointy)

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




Function protoFunc_StepTempScan()
	// I.e. Function passed to StepTempScanFunc must take no arguments
End


function StepTempScanFunc(sFunc, targettemps, [mag_fields, base_temp])
	// Master function for running scans at multiple temps and magnetic fields. Assumes the function has no input parameters.
	// Will run function at set targettemps (including base) and mag_fields
	// base_temp sets value at which fridge is at base. If fridge is below base_temp then it will run the scan function at the start of the measurement
	// EXAMPLE USAGE:: stepTempScanFunc("feb17_Scan0to1Peaks_paper", {500, 300, 100}, mag_fields={70, 2000}, base_temp = 20)
	String sFunc // string form of function you want to run
	wave targettemps
	wave mag_fields
	variable base_temp
	
	base_temp = paramisdefault(base_temp) ? 20 : base_temp // base_temp = 20 is default

   FUNCREF protoFunc_StepTempScan func_to_run = $sFunc
	svar ls        
   	nvar fd, magz
   	  	
   	variable use_mag_field = 0  	
	if (paramisDefault(mag_fields))
		make/o/free mag_fields = {0}
		use_mag_field = 0
	else
		use_mag_field = 1
	endif


	variable j = 0
   	for (j=0;j<numpnts(mag_fields);j++)
   		if (use_mag_field) // Only consider ramping field if using mag_fields
   			if (abs(getls625field(magz) - mag_fields[j]) > 1) // Only ramp and wait if change in field necessary
   				setls625fieldWait(magz, mag_fields[j])
	   			asleep(5*60)
	   		endif
   		endif
   	
		// Do Low T scan first (if already at low T)
		variable low_t_scanned = 0
		if (getls370temp(ls, "MC")*1000 < base_temp)
			func_to_run() //run the function
			low_t_scanned = 1
		endif
		setLS370exclusivereader(ls,"mc")
	   
	    // Scan at current temp   
		variable i=0
		for(i=0;i<numpnts(targettemps);i++)
			setLS370temp(ls,targettemps[i])
			asleep(2.0)
			WaitTillTempStable(ls, targettemps[i], 5, 30, 0.05)
			asleep(5*60)
			print "MEASURE AT: "+num2str(targettemps[i])+"mK"
			
			func_to_run() //run the function
		endfor
		setls370heaterOff(ls)
		resetls370exclusivereader(ls)
		
		if (!low_t_scanned)
			asleep(60*60)
			func_to_run() //run the function
		endif
	endfor	
	
end
