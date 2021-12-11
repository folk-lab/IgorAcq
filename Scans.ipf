#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method

// Standard Scan Functions for both BabyDAC and FastDAC scans
// Written by Tim Child, 2021-11


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// Standard Scancontroller (Slow) Scans /////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function ReadVsTime(delay, [y_label, max_time, comments]) // Units: s
	variable delay, max_time
	string y_label, comments
	variable i=0

	comments = selectString(paramIsDefault(comments), comments, "")
	y_label = selectString(paramIsDefault(y_label), y_label, "")	
	max_time = paramIsDefault(max_time) ? INF : max_time
	
	Struct ScanVars S
	initBDscanVars(S, 0, 0, 1, numptsx=1, delayx=delay, x_label="time /s", y_label=y_label, comments=comments)
	initializeScan(S)
	S.readVsTime = 1

	variable/g sc_scanstarttime = datetime
	S.start_time = datetime
	do
		asleep(delay)
		New_RecordValues(S, i, 0)
		doupdate
		i+=1
	while (datetime-S.start_time < max_time)
	S.end_time = datetime
	S.numptsx = i 
	EndScan(S=S)
end


function ScanBabyDAC(instrID, start, fin, channels, numpts, delay, ramprate, [y_label, comments, nosave]) //Units: mV
	// sweep one or more babyDAC channels
	// channels should be a comma-separated string ex: "0, 4, 5" or "LABEL1,LABEL2" 
	variable instrID, start, fin, numpts, delay, ramprate, nosave
	string channels, comments, y_label

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")

	// Initialize ScanVars
	struct ScanVars S
	InitBDscanVars(S, instrID, start, fin, channelsx=channels, numptsx=numpts, delayx=delay, rampratex=ramprate, comments=comments, y_label=y_label)

	// Check software limits and ramprate limits
	SFbd_pre_checks(S)  

	// Ramp to start without checks because checked above
	SFbd_ramp_start(S, ignore_lims=1)

	// Let gates settle 
	sc_sleep(5*S.delayx)

	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpoint
	do
		setpoint = S.startx + (i*(S.finx-S.startx)/(S.numptsx-1))
		RampMultipleBD(S.instrID, S.channelsx, setpoint, ramprate=S.rampratex, ignore_lims=1)
		sc_sleep(S.delayx)
		New_recordValues(S, i, 0)
		i+=1
	while (i<S.numptsx)

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		dowindow /k SweepControl
	endif
end


function ScanBabyDACUntil(instrID, start, fin, channels, numpts, delay, ramprate, checkwave, value, [operator, y_label, comments, nosave])
	// sweep one or more babyDAC channels until checkwave < (or >) value
	// channels should be a comma-separated string ex: "0, 4, 5"
	// operator is "<" or ">", meaning end on "checkwave[i] < value" or "checkwave[i] > value"
	variable instrID, start, fin, numpts, delay, ramprate, value, nosave
	string channels, operator, checkwave, y_label, comments
	string x_label

	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	operator = selectstring(paramisdefault(operator), operator, "<")

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
	InitBDscanVars(S, instrID, start, fin, channelsx=channels, numptsx=numpts, delayx=delay, rampratex=ramprate, comments=comments, y_label=y_label)

	// Check software limits and ramprate limits
	SFbd_pre_checks(S)  

	// Ramp to start without checks because checked above
	SFbd_ramp_start(S, ignore_lims=1)

	// Let gates settle 
	sc_sleep(5*S.delayx)

	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpoint
	wave w = $checkwave
	do
		setpoint = S.startx + (i*(S.finx-S.startx)/(S.numptsx-1))
		RampMultipleBD(S.instrID, S.channelsx, setpoint, ramprate=S.rampratex, ignore_lims=1)
		sc_sleep(S.delayx)
		New_recordValues(S, i, 0)
		if (a*w[i] - value < 0)
			break
		endif
		i+=1
	while (i<S.numptsx)
	S.numptsx = i   // In case scan ended early

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		dowindow /k SweepControl
	endif
end


function ScanBabyDAC2D(instrID, startx, finx, channelsx, numptsx, delayx, rampratex, starty, finy, channelsy, numptsy, delayy, rampratey, [comments, nosave]) //Units: mV
	variable instrID, startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, rampratey, nosave
	string channelsx, channelsy, comments
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	
	// Initialize ScanVars
	struct ScanVars S
	InitBDscanVars(S, instrID, startx, finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
							starty=starty, finy=finy, channelsy=channelsy, numptsy=numptsy, delayy=delayy, rampratey=rampratey, \
	 						comments=comments)

	// Check software limits and ramprate limits
	SFbd_pre_checks(S)  
	
	// Ramp to start without checks because checked above
	SFbd_ramp_start(S, ignore_lims=1)
	
	// Let gates settle 
	sc_sleep(S.delayy)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpointx, setpointy
	do
		setpointx = S.startx
		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))
		RampMultipleBD(S.instrID, S.channelsy, setpointy, ramprate=S.rampratey, ignore_lims=1)
		RampMultipleBD(S.instrID, S.channelsx, setpointx, ramprate=S.rampratex, ignore_lims=1)
		sc_sleep(S.delayy)
		j=0
		do
			setpointx = S.startx + (j*(S.finx-S.startx)/(S.numptsx-1))
			RampMultipleBD(S.instrID, S.channelsx, setpointx, ramprate=S.rampratex)
			sc_sleep(S.delayx)
			new_RecordValues(S, i, j)
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


function ScanBabyDACRepeat(instrID, startx, finx, channelsx, numptsx, delayx, rampratex, numptsy, delayy, [comments, alternate, nosave]) //Units: mV, mT
	// x-axis is the dac sweep
	// y-axis is an index
	// if alternate = 1 then will sweep: start -> fin, fin -> start, start -> fin, ....
	// each sweep (whether up or down) will count as 1 y-index
	variable instrID, startx, finx, numptsx, delayx, rampratex, numptsy, delayy, alternate, nosave
	string channelsx, comments

	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	
	// Initialize ScanVars
	struct ScanVars S
	InitBDscanVars(S, instrID, startx, finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
							starty=1, finy=numptsy, numptsy=numptsy, delayy=delayy, y_label="Repeats", comments=comments)

	// Check software limits and ramprate limits
	SFbd_pre_checks(S, x_only=1)  
	
	// Ramp to start without checks because checked above
	SFbd_ramp_start(S, ignore_lims=1)
	
	// Let gates settle 
	sc_sleep(S.delayy)
	
	// Make waves and graphs etc
	initializeScan(S)
	
	// Let gates settle 
	sc_sleep(S.delayy)
	
	// Main measurement loop
	variable i=0, j=0, setpointx, setpointy, scandirection=0
	do
		if(mod(i,2)!=0 && alternate == 1)  // If on odd row and alternate is on
			j=numptsx-1
			scandirection=-1
		else
			j=0
			scandirection=1
		endif

		setpointx = S.startx + (j*(S.finx-S.startx)/(S.numptsx-1)) // reset start point
		RampMultipleBD(S.instrID, S.channelsx, setpointx, ramprate=S.rampratex, ignore_lims=1)
		sc_sleep(delayy) // wait at start point
		do
			setpointx = S.startx + (j*(S.finx-S.startx)/(S.numptsx-1))
			RampMultipleBD(S.instrID, S.channelsx, setpointx, ramprate=S.rampratex, ignore_lims=1)
			sc_sleep(S.delayx)
			new_RecordValues(S, i, j)
			j+=scandirection
		while (j>-1 && j<S.numptsx)
		i+=1
	while (i<S.numptsy)
  
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		dowindow /k SweepControl
	endif
end


function ScanBabyDAC_SRSAmplitude(babydacID, srsID, startx, finx, channelsx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, [comments, nosave]) //Units: mV, mV
	// Example of how to make new babyDAC scan stepping a different instrument (here SRS)
	variable babydacID, srsID, startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, nosave
	string channelsx, comments
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	
	// Initialize ScanVars
	struct ScanVars S
	InitBDscanVars(S, babydacID, startx, finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
							starty=starty, finy=finy, numptsy=numptsy, delayy=delayy, \
	 						y_label="SRS Amplitude", comments=comments)

	// Check software limits and ramprate limits
	SFbd_pre_checks(S, x_only=1)  
	
	// Ramp to start without checks because checked above
	SFbd_ramp_start(S, ignore_lims=1)
	
	// Let gates settle 
	sc_sleep(S.delayy)
	
	// Make waves and graphs etc
	initializeScan(S)

	// main loop
	variable i=0, j=0, setpointx, setpointy
	do
		setpointx = S.startx
		setpointy = starty + (i*(finy-starty)/(S.numptsy-1))
		RampMultipleBD(S.instrID, S.channelsx, setpointx, ramprate=S.rampratex, ignore_lims=1)
		SetSRSAmplitude(srsID,setpointy)
		sc_sleep(S.delayy)
		j=0
		do
			setpointx = S.startx + (j*(S.finx-S.startx)/(S.numptsx-1))
			RampMultipleBD(S.instrID, S.channelsx, setpointx, ramprate=S.rampratex, ignore_lims=1)
			sc_sleep(S.delayx)
			New_RecordValues(S, i, j)
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


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////// Standard FastDAC Scans ///////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function ReadVsTimeFastdac(instrID, duration, [y_label, comments, nosave]) // Units: s 
	variable instrID, duration, nosave
	string comments, y_label
	
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")

	wave fadcattr
	variable i=0

	string channels = getRecordedFastdacInfo("channels")  // Get ADCs ticked to record
	
	if(itemsinlist(channels, ",") == 0)
		abort "[ERROR] \"ReadVsTimeFastdac\": No ADC channels selected"
	endif

	Struct ScanVars S
	initFDscanVars(S, instrID, 0, duration, duration=duration, x_label="time /s", y_label="Current /nA", comments=comments)
	S.readVsTime = 1
	
	initializeScan(S)

	NEW_fd_record_values(S, 0)

	if (!nosave)	
		EndScan(S=S)
	else
		dowindow/k SweepControl
	endif
end


function ScanFastDAC(instrID, start, fin, channels, [numpts, sweeprate, ramprate, delay, starts, fins, x_label, y_label, comments, use_AWG, nosave]) //Units: mV
	// sweep one or more FastDac channels from start to fin using either numpnts or sweeprate /mV/s
	// Note: ramprate is for ramping to beginning of scan ONLY
	// Note: Delay is the wait after rampoint to start position ONLY
	// channels should be a comma-separated string ex: "0,4,5"
	// use_AWG is option to use Arbitrary Wave Generator. AWG
	// starts/fins are overwrite start/fin and are used to provide a start/fin for EACH channel in channels 
	variable instrID, start, fin, numpts, sweeprate, ramprate, delay, nosave, use_AWG
	string channels, comments, x_label, y_label, starts, fins

   // Reconnect instruments
   sc_openinstrconnections(0)

   // Set defaults
   delay = ParamIsDefault(delay) ? 0.01 : delay
   comments = selectstring(paramisdefault(comments), comments, "")
   starts = selectstring(paramisdefault(starts), starts, "")
   fins = selectstring(paramisdefault(fins), fins, "")
   x_label = selectString(paramisdefault(x_label), x_label, "")
   y_label = selectString(paramisdefault(y_label), y_label, "")   
 
   // Initialize ScanVars 
   struct ScanVars S
   initFDscanVars(S, instrID, start, fin, channelsx=channels, numptsx=numpts, sweeprate=sweeprate, rampratex=ramprate, delayy=delay, startxs=starts, finxs=fins, x_label=x_label, y_label=y_label, comments=comments)

   // Check hardware/software limits and that DACs/ADCs are on same device
   SFfd_pre_checks(S)  
   
   	// If using AWG then get that now and check it
	struct fdAWG_list AWG
	if(use_AWG)	
		fdAWG_get_global_AWG_list(AWG)
		SFawg_set_and_precheck(AWG, S)  // Note: sets S.numptsx here and AWG.use_AWG = 1 if pass checks
	else  // Don't use AWG
		AWG.use_AWG = 0  	// This is the default, but just putting here explicitly
	endif

   // Ramp to start without checks since checked above
   SFfd_ramp_start(S, ignore_lims = 1)

	// Let gates settle 
	sc_sleep(S.delayy)

	// Make Waves and Display etc
	initializeScan(S)

	// Do 1D scan (rownum set to 0)
	NEW_fd_record_values(S, 0, AWG_list=AWG)

	// Save by default
	if (nosave == 0)
		EndScan(S=S, save_experiment=1)
  	else
  		dowindow /k SweepControl
	endif
end


function ScanFastDacSlow(instrID, start, fin, channels, numpts, delay, ramprate, [y_label, comments, nosave]) //Units: mV
	// sweep one or more FastDAC channels but in the ScanController way (not ScanControllerFastdac). I.e. ramp, measure, ramp, measure...
	// channels should be a comma-separated string ex: "0, 4, 5"
	variable instrID, start, fin, numpts, delay, ramprate, nosave
	string channels, y_label, comments

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")

	// Initialize ScanVars
	struct ScanVars S  // Note, more like a BD scan if going slow
	initFDscanVars(S, instrID, start, fin, channelsx=channels, numptsx=numpts, delayx=delay, rampratex=ramprate, comments=comments, y_label=y_label)  
	S.using_fastdac = 0 // Explicitly showing that this is not a normal fastDac scan
	S.duration = numpts*max(0.05, delay) // At least 50ms per point is a good estimate 
	S.sweeprate = abs((fin-start)/S.duration) // Better estimate of sweeprate (Not really valid for a slow scan)

	// Check limits (not as much to check when using FastDAC slow)
	SFfd_check_lims(S)
	S.lims_checked = 1

	// Ramp to start without checks because checked above
	SFfd_ramp_start(S, ignore_lims=1)

	// Let gates settle 
	sc_sleep(delay*5)

	// Make Waves and Display etc
	InitializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpoint
	do
		setpoint = S.startx + (i*(S.finx-S.startx)/(S.numptsx-1))
		RampMultipleFDac(S.instrID, S.channelsx, setpoint, ramprate=S.rampratex, ignore_lims=1)
		sc_sleep(delay)
		New_RecordValues(S, i, 0)
		i+=1
	while (i<S.numptsx)

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		dowindow /k SweepControl
	endif
end


function ScanFastDAC2D(fdID, startx, finx, channelsx, starty, finy, channelsy, numptsy, [numpts, sweeprate, bdID, rampratex, rampratey, delayy, startxs, finxs, startys, finys, comments, nosave, use_AWG])
	// 2D Scan for FastDAC only OR FastDAC on fast axis and BabyDAC on slow axis
	// Note: Must provide numptsx OR sweeprate in optional parameters instead
	// Note: To ramp with babyDAC on slow axis provide the BabyDAC variable in bdID
	// Note: channels should be a comma-separated string ex: "0,4,5"
	variable fdID, startx, finx, starty, finy, numptsy, numpts, sweeprate, bdID, rampratex, rampratey, delayy, nosave, use_AWG
	string channelsx, channelsy, comments, startxs, finxs, startys, finys
	variable i=0, j=0

	// Set defaults
	delayy = ParamIsDefault(delayy) ? 0.01 : delayy
   comments = selectstring(paramisdefault(comments), comments, "")
   startxs = selectstring(paramisdefault(startxs), startxs, "")
   finxs = selectstring(paramisdefault(finxs), finxs, "")
   startys = selectstring(paramisdefault(startys), startys, "")
   finys = selectstring(paramisdefault(finys), finys, "")
   variable use_bd = paramisdefault(bdid) ? 0 : 1 		// Whether using both FD and BD or just FD

   if (!paramisdefault(bdID) && (!paramisdefault(startys) || !paramisdefault(finys)))
   		abort "NotImplementedError: Cannot do virtual sweep with Babydacs"
   	endif

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Put info into scanVars struct (to more easily pass around later)
 	struct ScanVars S
 	if (use_bd == 0)
	 	initFDscanVars(S, fdID, startx, finx, channelsx=channelsx, rampratex=rampratex, numptsx=numpts, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
		   						 starty=starty, finy=finy, channelsy=channelsy, rampratey=rampratey, startxs=startxs, finxs=finxs, startys=startys, finys=finys, comments=comments)
	
	else  				// Using BabyDAC for Y axis so init x in FD_ScanVars, and init y in BD_ScanVars
		initFDscanVars(S, fdID, startx, finx, channelsx=channelsx, rampratex=rampratex, numptsx=numpts, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
		   						rampratey=rampratey, startxs=startxs, finxs=finxs, comments=comments)
		S.bdID = bdID
       s.is2d = 1
		S.starty = starty
		S.finy = finy
		S.channelsy = SF_get_channels(channelsy, fastdac=0)
		S.y_label = GetLabel(S.channelsy, fastdac=0)
	endif
      
   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC

   if(use_bd == 1)
//   		SFbd_pre_checks(Bsv)
		SFfd_pre_checks(S, x_only=1)
		SFbd_check_lims(S, y_only=1)
   	else
   	   SFfd_pre_checks(S)  
   	endif
   	
   	// If using AWG then get that now and check it
	struct fdAWG_list AWG
	if(use_AWG)	
		fdAWG_get_global_AWG_list(AWG)
		SFawg_set_and_precheck(AWG, S)  // Note: sets SV.numptsx here and AWG.use_AWG = 1 if pass checks
	else  // Don't use AWG
		AWG.use_AWG = 0  	// This is the default, but just putting here explicitly
	endif
   
   // Ramp to start without checks

   if(use_bd == 1)
	   SFfd_ramp_start(S, x_only=1, ignore_lims=1)
	   SFbd_ramp_start(S, y_only=1, ignore_lims=1)
   	else
   	   SFfd_ramp_start(S, ignore_lims=1)
   	endif
   	
   	// Let gates settle
	sc_sleep(S.delayy)

	// Initialize waves and graphs
	initializeScan(S)

	// Main measurement loop
	variable setpointy, sy, fy
	string chy
	for(i=0; i<S.numptsy; i++)
		// Ramp slow axis
		if(use_bd == 0)
			for(j=0; j<itemsinlist(S.channelsy,";"); j++)
				sy = str2num(stringfromList(j, S.startys, ","))
				fy = str2num(stringfromList(j, S.finys, ","))
				chy = stringfromList(j, S.channelsy, ";")
				setpointy = sy + (i*(fy-sy)/(S.numptsy-1))	
				RampMultipleFDac(S.instrID, chy, setpointy, ramprate=S.rampratey, ignore_lims=1)
			endfor
		else // If using BabyDAC on slow axis
			setpointy = starty + (i*(finy-starty)/(S.numptsy-1))	
			RampMultipleBD(S.bdID, S.channelsy, setpointy, ramprate=S.rampratey, ignore_lims=1)
		endif
		// Ramp to start of fast axis
		SFfd_ramp_start(S, ignore_lims=1, x_only=1)
		sc_sleep(S.delayy)
		
		// Record fast axis
		NEW_Fd_record_values(S, i, AWG_list=AWG)
	endfor

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
  	else
  		dowindow /k SweepControl
	endif
end


function ScanFastDACRepeat(instrID, start, fin, channels, numptsy, [numptsx, sweeprate, delay, ramprate, alternate, starts, fins, comments, nosave, use_awg])
	// 1D repeat scan for FastDAC
	// Note: to alternate scan direction set alternate=1
	// Note: Ramprate is only for ramping gates between scans
	variable instrID, start, fin, numptsy, numptsx, sweeprate, delay, ramprate, alternate, nosave, use_awg
	string channels, comments, starts, fins
	variable i=0, j=0

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Set defaults
	delay = ParamIsDefault(delay) ? 0.5 : delay
	comments = selectstring(paramisdefault(comments), comments, "")
	starts = selectstring(paramisdefault(starts), starts, "")
	fins = selectstring(paramisdefault(fins), fins, "")

	// Set sc_ScanVars struct
	struct ScanVars S
	initFDscanVars(S, instrID, start, fin, channelsx=channels, numptsx=numptsx, rampratex=ramprate, starty=1, finy=numptsy, delayy=delay, sweeprate=sweeprate,  \
					numptsy=numptsy, direction=1, startxs=starts, finxs=fins, y_label="Repeats", comments=comments)
	
	// Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
	SFfd_pre_checks(S, x_only=1)  

  	// If using AWG then get that now and check it
	struct fdAWG_list AWG
	if(use_AWG)	
		fdAWG_get_global_AWG_list(AWG)
		SFawg_set_and_precheck(AWG, S)  // Note: sets S.numptsx here and AWG.use_AWG = 1 if pass checks
	else  // Don't use AWG
		AWG.use_AWG = 0  	// This is the default, but just putting here explicitly
	endif

	// Ramp to start without checks since checked above
	SFfd_ramp_start(S, ignore_lims = 1)

	// Let gates settle
	sc_sleep(S.delayy)

	// Init Scan
	initializeScan(S)

	// Main measurement loop
	variable d=1
	for (j=0; j<numptsy; j++)
		S.direction = d  // Will determine direction of scan in fd_Record_Values

		// Ramp to start of fast axis
		SFfd_ramp_start(S, ignore_lims=1, x_only=1)
		sc_sleep(S.delayy)

		// Record values for 1D sweep
		NEW_Fd_record_values(S, j, AWG_List = AWG)

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

