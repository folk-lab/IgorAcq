


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// Scans /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function AAScans()
end

function ReadVsTime(delay, [comments]) // Units: s
	variable delay
	string comments
	variable i=0

	if (paramisdefault(comments))
		comments=""
	endif
	
	Struct ScanVars S
	initBDscanVars(S, 0, 0, 1, "", numptsx=1, delayx=delay, x_label="time /s")
	initializeScan(S)

//	InitializeWaves(0, 1, 1, x_label="time (s)")

	variable/g sc_scanstarttime = datetime
	do
		asleep(delay)
		New_RecordValues(S, i, 0,readvstime=1)
		doupdate
		i+=1
	while (1)
	EndScan(S=S)
end


function ReadVsTimeFastdac(instrID, duration, [y_label, comments, nosave]) // Units: s 
	variable instrID, duration, nosave
	string comments, y_label
	
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "Not Set")

	wave fadcattr
	variable i=0

	string channels = getRecordedFastdacInfo("channels")  // Get ADCs ticked to record
	
	if(itemsinlist(channels, ",") == 0)
		abort "[ERROR] \"ReadVsTimeFastdac\": No ADC channels selected"
	endif

	Struct ScanVars S
	initFDscanVars(S, instrID, 0, duration, "", x_label="time /s", y_label="Current /nA", comments=comments)
	S.numptsx = round(S.measureFreq*duration)
	
	initializeScan(S)
	S.start_time = datetime

//	InitializeWaves(0, duration, numpts, x_label="Time /s", y_label=y_label ,fastdac=1)
//	nvar sc_scanstarttime // Global variable set when InitializeWaves is called
	fd_readvstime(S.instrID, channels, S.numptsx, S.samplingFreq)
	fdRV_process_and_distribute(S, 0)  // Update calculated wave

	if (!nosave)	
		EndScan(S=S)
	endif
//	SaveWaves(msg=comments, fastdac=1)
end

//
//
//function ReadVsTimeUntil(delay,readtime, [comments])
//	variable delay, readtime
//	string comments
//	
//	if (paramisdefault(comments))
//		comments=""
//	endif
//
//	InitializeWaves(0, 1, 1, x_label="time (s)")
//	nvar sc_scanstarttime // Global variable set when InitializeWaves is called
//	variable i=0
//	do
//		sc_sleep(delay)
//		RecordValues(i, 0,readvstime=1)
//		i+=1
//	while(datetime-sc_scanstarttime < readtime)
//	SaveWaves(msg=comments)
//end
//
//
//function ScanBabyDAC(instrID, start, fin, channels, numpts, delay, ramprate, [comments, nosave]) //Units: mV
//	// sweep one or more babyDAC channels
//	// channels should be a comma-separated string ex: "0, 4, 5"
//	variable instrID, start, fin, numpts, delay, ramprate, nosave
//	string channels, comments
//
//   // Reconnect instruments
//   //sc_openinstrconnections(0)
//
//   // Set defaults
//   comments = selectstring(paramisdefault(comments), comments, "")
//
//   // Set sc_ScanVars struct
//   struct BD_ScanVars SV
//   SF_init_BDscanVars(SV, instrID, startx=start, finx=fin, channelsx=channels, numptsx=numpts, delayx=delay, rampratex=ramprate)
//
//   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
//   SFbd_pre_checks(SV)  
//
//	// Ramp to start without checks because checked above
//	SFbd_ramp_start(SV, ignore_lims=1)
//
//   // Let gates settle 
//	sc_sleep(1.0)
//
//   // Get labels for waves
//   string x_label
//   x_label = GetLabel(SV.channelsx)
//
//   // Make waves
//	InitializeWaves(SV.startx, SV.finx, SV.numptsx, x_label=x_label)
//
//   // Main measurement loop
//	variable i=0, j=0, setpoint
//	do
//		setpoint = SV.startx + (i*(SV.finx-SV.startx)/(SV.numptsx-1))
//		RampMultipleBD(SV.instrID, SV.channelsx, setpoint, ramprate=SV.rampratex, ignore_lims=1)
//		sc_sleep(SV.delayx)
//		RecordValues(i, 0)
//		i+=1
//	while (i<SV.numptsx)
//
//   // Save by default
//   if (nosave == 0)
//  		SaveWaves(msg=comments)
//  	else
//  		dowindow /k SweepControl
//	endif
//end
//
//
//function ScanFastDacSlow(instrID, start, fin, channels, numpts, delay, ramprate, [comments, nosave]) //Units: mV
//	// sweep one or more FastDAC channels but in the ScanController way (not ScanControllerFastdac). I.e. ramp, measure, ramp, measure...
//	// channels should be a comma-separated string ex: "0, 4, 5"
//	variable instrID, start, fin, numpts, delay, ramprate, nosave
//	string channels, comments
//
//   // Reconnect instruments
//   //sc_openinstrconnections(0)
//
//   // Set defaults
//   comments = selectstring(paramisdefault(comments), comments, "")
//
//   // Set sc_ScanVars struct
//   struct FD_ScanVars SV
//   nvar fd_ramprate
//   SF_init_FDscanVars(SV, instrID, start, fin, channels, 0, ramprate, sweeprate=1)  // Numpts and sweeprate won't actually be used in this 
//
//   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
//   SFfd_pre_checks(SV)  
//   SV.numptsx = numpts  // Can be put in AFTER checks, otherwise looks like it is going to sweep super fast, but it isn't because this is ramp, measure, ramp, measure...
//
//	// Ramp to start without checks because checked above
//	SFfd_ramp_start(SV, ignore_lims=1)
//
//   // Let gates settle 
//	sc_sleep(delay*5)
//
//   // Get labels for waves
//   string x_label
//   x_label = GetLabel(SV.channelsx)
//
//   // Make waves
//	InitializeWaves(SV.startx, SV.finx, SV.numptsx, x_label=x_label)
//
//   // Main measurement loop
//	variable i=0, j=0, setpoint
//	do
//		setpoint = SV.startx + (i*(SV.finx-SV.startx)/(SV.numptsx-1))
//		RampMultipleFDac(SV.instrID, SV.channelsx, setpoint, ramprate=SV.rampratex, ignore_lims=1)
//		sc_sleep(delay)
//		RecordValues(i, 0)
//		i+=1
//	while (i<SV.numptsx)
//
//   // Save by default
//   if (nosave == 0)
//  		SaveWaves(msg=comments)
//  	else
//  		dowindow /k SweepControl
//	endif
//end
//
//
//
//function ScanBabyDAC2D(instrID, startx, finx, channelsx, numptsx, delayx, rampratex, starty, finy, channelsy, numptsy, delayy, rampratey, [comments, nosave]) //Units: mV
//	variable instrID, startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, rampratey, nosave
//	string channelsx, channelsy, comments
//	
//	// Reconnect instruments
//	//sc_openinstrconnections(0)
//	
//	// Set defaults
//	comments = selectstring(paramisdefault(comments), comments, "")
//	
//	// Set sc_ScanVars struct
//	struct BD_ScanVars SV
//	SF_init_BDscanVars(SV, instrID, startx=startx, finx=finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
//	                             starty=starty, finy=finy, channelsy=channelsy, numptsy=numptsy, delayy=delayy, rampratey=rampratey)
//
//	// Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
//	SFbd_pre_checks(SV)  
//	
//	// Ramp to start without checks because checked above
//	SFbd_ramp_start(SV, ignore_lims=1)
//	
//	// Let gates settle 
//	sc_sleep(SV.delayy)
//	
//	// Get labels for waves
//	string x_label, y_label
//	x_label = GetLabel(SV.channelsx)
//	y_label = GetLabel(SV.channelsy)
//
//	// Initialize waves
//	InitializeWaves(SV.startx, SV.finx, SV.numptsx, starty=SV.starty, finy=SV.finy, numptsy=SV.numptsy, x_label=x_label, y_label=y_label)
//	
//	// Main measurement loop
//	variable i=0, j=0, setpointx, setpointy
//	do
//		setpointx = SV.startx
//		setpointy = SV.starty + (i*(SV.finy-SV.starty)/(SV.numptsy-1))
//		RampMultipleBD(SV.instrID, SV.channelsy, setpointy, ramprate=SV.rampratey, ignore_lims=1)
//		RampMultipleBD(SV.instrID, SV.channelsx, setpointx, ramprate=SV.rampratex, ignore_lims=1)
//		sc_sleep(SV.delayy)
//		j=0
//		do
//			setpointx = SV.startx + (j*(SV.finx-SV.startx)/(SV.numptsx-1))
//			RampMultipleBD(SV.instrID, SV.channelsx, setpointx, ramprate=SV.rampratex)
//			sc_sleep(SV.delayx)
//			RecordValues(i, j)
//			j+=1
//		while (j<SV.numptsx)
//	i+=1
//	while (i<SV.numptsy)
//	
//	// Save by default
//	if (nosave == 0)
//		 SaveWaves(msg=comments)
//	else
//		 dowindow /k SweepControl
//	endif
//end
//
//
//function ScanBabyDACRepeat(instrID, startx, finx, channelsx, numptsx, delayx, rampratex, numptsy, delayy, [comments, alternate, nosave]) //Units: mV, mT
//	// x-axis is the dac sweep
//	// y-axis is an index
//	// if alternate = 1 then will sweep: start -> fin, fin -> start, start -> fin, ....
//	// each sweep (whether up or down) will count as 1 y-index
//	variable instrID, startx, finx, numptsx, delayx, rampratex, numptsy, delayy, alternate, nosave
//	string channelsx, comments
//
//   // Reconnect instruments
//	//sc_openinstrconnections(0)
//
//   // Set defaults
//	comments = selectstring(paramisdefault(comments), comments, "")
//	
//	// Set sc_ScanVars struct
//	struct BD_ScanVars SV
//	SF_init_BDscanVars(SV, instrID, startx=startx, finx=finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
//	                      numptsy=numptsy, delayy=delayy)
//
//	// Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
//	SFbd_pre_checks(SV)  
//	
//	// Ramp to start without checks because checked above
//	// Ramp inner loop to finx if alternate=1
//	if(alternate == 1)
//		SV.startx = finx
//		SFbd_ramp_start(SV, ignore_lims=1)
//		SV.startx = startx
//	else
//		SFbd_ramp_start(SV, ignore_lims=1)
//	endif
//	
//	// Let gates settle 
//	sc_sleep(SV.delayy)
//	
//	// Get labels for waves
//   string x_label, y_label
//   x_label = GetLabel(SV.channelsx)
//	y_label = "Sweep Num"
//
//	// Intialize waves
//	InitializeWaves(SV.startx, SV.finx, SV.numptsx, starty=1, finy=SV.numptsy, numptsy=SV.numptsy, x_label=x_label, y_label=y_label)
//
//   // Main measurement loop
//   variable i=0, j=0, setpointx, setpointy, scandirection=0
//	do
//		if(mod(i-1,2)!=0 && alternate == 1)  // If on odd row and alternate is on
//			j=numptsx-1
//			scandirection=-1
//		else
//			j=0
//			scandirection=1
//		endif
//
//		setpointx = SV.startx + (j*(SV.finx-SV.startx)/(SV.numptsx-1)) // reset start point
//		RampMultipleBD(SV.instrID, SV.channelsx, setpointx, ramprate=SV.rampratex, ignore_lims=1)
//		sc_sleep(delayy) // wait at start point
//		do
//			setpointx = SV.startx + (j*(SV.finx-SV.startx)/(SV.numptsx-1))
//			RampMultipleBD(SV.instrID, SV.channelsx, setpointx, ramprate=SV.rampratex, ignore_lims=1)
//			sc_sleep(SV.delayx)
//			RecordValues(i, j)
//			j+=scandirection
//		while (j>-1 && j<SV.numptsx)
//		i+=1
//	while (i<SV.numptsy)
//   
//   // Save by default
//   if (nosave == 0)
//       SaveWaves(msg=comments)
//   else
//       dowindow /k SweepControl
//   endif
//end
//
//
//
//function ScanBabyDACUntil(instrID, start, fin, channels, numpts, delay, ramprate, checkwave, value, [operator, comments, scansave]) //Units: mV
//  // sweep one or more babyDAC channels until checkwave < (or >) value
//  // channels should be a comma-separated string ex: "0, 4, 5"
//  // operator is "<" or ">", meaning end on "checkwave[i] < value" or "checkwave[i] > value"
//  variable instrID, start, fin, numpts, delay, ramprate, value, scansave
//  string channels, operator, checkwave, comments
//  string x_label
//  variable i=0, j=0, setpoint
//
//  if(paramisdefault(comments))
//    comments=""
//  endif
//
//  if(paramisdefault(operator))
//    operator = "<"
//  endif
//
//  if(paramisdefault(scansave))
//    scansave=1
//  endif
//
//  variable a = 0
//  if ( stringmatch(operator, "<")==1 )
//    a = 1
//  elseif ( stringmatch(operator, ">")==1 )
//    a = -1
//  else
//    abort "Choose a valid operator (<, >)"
//  endif
//
//  x_label = GetLabel(channels)
//
//  // set starting values
//  setpoint = start
//  RampMultipleBD(instrID, channels, setpoint, ramprate=ramprate)
//
//  InitializeWaves(start, fin, numpts, x_label=x_label)
//  sc_sleep(1.0)
//
//  wave w = $checkwave
//  wave resist  //TODO: What is this?
//  do
//    setpoint = start + (i*(fin-start)/(numpts-1))
//    RampMultipleBD(instrID, channels, setpoint, ramprate=ramprate)
//    sc_sleep(delay)
//    RecordValues(i, 0)
//    if (a*(w[i] - value) < 0 )
//			break
//    endif
//    i+=1
//  while (i<numpts)
//
//  if(scansave==1)
//    SaveWaves(msg=comments)
//  endif
//end
//
//
////function ScanBabyDAC_SRS(babydacID, srsID, startx, finx, channelsx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, [comments, nosave]) //Units: mV, mV
////	// Example of how to make new babyDAC scan stepping a different instrument (here SRS)
////	variable babydacID, srsID, startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, nosave
////	string channelsx, comments
////	
////   // Reconnect instruments
////   sc_openinstrconnections(0)
////   
////   // Set defaults
////   comments = selectstring(paramisdefault(comments), comments, "")
////   
////   // Set sc_ScanVars struct
////   struct BD_ScanVars SV
////   SF_init_BDscanVars(SV, BabydacID, startx=startx, finx=finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
////                                numptsy=numptsy, delayy=delayy)
////   
////   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
////   SFbd_pre_checks(SV)  
////   
////   // Ramp to start without checks because checked above
////   SFbd_ramp_start(SV, ignore_lims=1)
////   SetSRSAmplitude(srsID, starty)
////   
////   // Let gates settle 
////   sc_sleep(SV.delayy)
////   
////   // Get labels for waves
////   string x_label, y_label
////   x_label = GetLabel(SV.channelsx)
////   sprintf y_label, "SRS%d (mV)", getAddressGPIB(srsID)
////	
////	// initialize waves
////	InitializeWaves(SV.startx, SV.finx, SV.numptsx, starty=starty, finy=finy, numptsy=SV.numptsy, x_label=x_label, y_label=y_label)
////
////	// main loop
////   variable i=0, j=0, setpointx, setpointy
////   do
////		setpointx = SV.startx
////		setpointy = starty + (i*(finy-starty)/(SV.numptsy-1))
////		RampMultipleBD(SV.instrID, SV.channelsx, setpointx, ramprate=SV.rampratex, ignore_lims=1)
////		SetSRSAmplitude(srsID,setpointy)
////		sc_sleep(SV.delayy)
////		j=0
////		do
////			setpointx = SV.startx + (j*(SV.finx-SV.startx)/(SV.numptsx-1))
////			RampMultipleBD(SV.instrID, SV.channelsx, setpointx, ramprate=SV.rampratex, ignore_lims=1)
////			sc_sleep(SV.delayx)
////			RecordValues(i, j)
////			j+=1
////		while (j<SV.numptsx)
////		i+=1
////	while (i<SV.numptsy)
////   
////   // Save by default
////	if (nosave == 0)
////		 SaveWaves(msg=comments)
////	else
////		 dowindow /k SweepControl
////	endif
////end
//
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
   nvar fd_ramprate
   ramprate = paramisdefault(ramprate) ? fd_ramprate : ramprate
   delay = ParamIsDefault(delay) ? 0.01 : delay
   comments = selectstring(paramisdefault(comments), comments, "")
   starts = selectstring(paramisdefault(starts), starts, "")
   fins = selectstring(paramisdefault(fins), fins, "")
   x_label = selectString(paramisdefault(x_label), x_label, "")
   y_label = selectString(paramisdefault(y_label), y_label, "")   
 
   // Set sc_ScanVars struct
   struct ScanVars S
//   SF_init_FDscanVars(S, instrID, start, fin, channels, numpts, ramprate, startxs=starts, finxs=fins, delayy=delay, sweeprate=sweeprate)  // Note: Stored as SV.startx etc
   initFDscanVars(S, instrID, start, fin, channels, numptsx=numpts, sweeprate=sweeprate, rampratex=ramprate, delayy=delay, startxs=starts, finxs=fins, x_label=x_label, y_label=y_label, comments=comments)
//   // Set ProcessList struct
//   struct fdRV_ProcessList PL
//   SFfd_init_ProcessList(PL, RCcutoff, numAverage, notch)  // Puts values into PL.<name>

   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
   SFfd_pre_checks(S)  
   
   	// If using AWG then get that now and check it
	struct fdAWG_list AWG
	if(use_AWG)	
		fdAWG_get_global_AWG_list(AWG)
		SFawg_set_and_precheck(AWG, S)  // Note: sets SV.numptsx here and AWG.use_AWG = 1 if pass checks
	else  // Don't use AWG
		AWG.use_AWG = 0  	// This is the default, but just putting here explicitly
	endif

   // Ramp to start without checks since checked above
   SFfd_ramp_start(S, ignore_lims = 1)

	// Let gates settle 
	sc_sleep(S.delayy)

//	// Get labels for waves
//   string x_label
//	  x_label = GetLabel(S.channelsx, fastdac=1)
//   y_label = selectstring(paramisdefault(y_label), y_label, "")

	// Make waves
//	InitializeWaves(SV.startx, SV.finx, SV.numptsx, x_label=x_label, y_label=y_label, fastdac=1)
	initializeScan(S)

	// Do 1D scan (rownum set to 0)
//	fd_Record_Values(S, PL, 0, AWG_list=AWG)
	NEW_fd_record_values(S, 0, AWG_list=AWG)

	// Save by default
	if (nosave == 0)
		EndScan(S=S, save_experiment=1)
//  		SaveWaves(msg=comments, fastdac=1)
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
	nvar fd_ramprate
	rampratex = paramisdefault(rampratex) ? fd_ramprate : rampratex
	rampratey = ParamIsDefault(rampratey) ? fd_ramprate : rampratey
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
	 	initFDscanVars(S, fdID, startx, finx, channelsx, rampratex=rampratex, numptsx=numpts, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
		   						 starty=starty, finy=finy, channelsy=channelsy, rampratey=rampratey, startxs=startxs, finxs=finxs, startys=startys, finys=finys, comments=comments)
	
	else  				// Using BabyDAC for Y axis so init x in FD_ScanVars, and init y in BD_ScanVars
		abort "Not implemented again yet"
//	   SF_init_FDscanVars(Fsv, fdID, startx, finx, channelsx, numpts, rampratex, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, startxs=startxs, finxs=finxs)
//		struct BD_ScanVars Bsv
//		SF_init_BDscanVars(Bsv, bdID, starty=starty, finy=finy, channelsy=channelsy, rampratey=rampratey)
	endif
      
   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
   SFfd_pre_checks(S)  
   if(use_bd == 1)
//   		SFbd_pre_checks(Bsv)
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
   SFfd_ramp_start(S, ignore_lims=1)
   if(use_bd == 1)
//   		SFbd_ramp_start(Bsv, ignore_lims=1)
   	endif
   	
   	// Let gates settle
	sc_sleep(S.delayy)

//	// Get Labels for waves
	if(use_bd == 1)
		abort "Need to implement"
		// Something like S.y_label = BDS.y_label
	endif
//	string x_label, y_label
//	x_label = GetLabel(Fsv.channelsx, fastdac=1)
//	if (use_bd == 0) // If using FastDAC on slow axis
//		y_label = GetLabel(Fsv.channelsy, fastdac=1)
//	else // If using BabyDAC on slow axislabels
//		y_label = GetLabel(Bsv.channelsy, fastdac=0)
//	endif

	// Make waves												// Note: Using just starty, finy because initwaves doesn't care if it's FD/BD
//	InitializeWaves(Fsv.startx, Fsv.finx, Fsv.numptsx, starty=starty, finy=finy, numptsy=Fsv.numptsy, x_label=x_label, y_label=y_label, fastdac=1)
	initializeScan(S)

	// Main measurement loop
	variable setpointy, sy, fy
	string chy
	for(i=0; i<S.numptsy; i++)
		// Ramp slow axis
		if(use_bd == 0)
			for(j=0; j<itemsinlist(S.channelsy,","); j++)
				sy = str2num(stringfromList(j, S.startys, ","))
				fy = str2num(stringfromList(j, S.finys, ","))
				chy = stringfromList(j, S.channelsy, ",")
				setpointy = sy + (i*(fy-sy)/(S.numptsy-1))	
				RampMultipleFDac(S.instrID, chy, setpointy, ramprate=S.rampratey, ignore_lims=1)
			endfor
		else // If using BabyDAC on slow axislabels
			setpointy = starty + (i*(finy-starty)/(S.numptsy-1))	
			abort "Not implemented"
//			RampMultipleBD(Bsv.instrID, Bsv.channelsy, setpointy, ramprate=Bsv.rampratey, ignore_lims=1)
		endif
		// Ramp to start of fast axis
		SFfd_ramp_start(S, ignore_lims=1, x_only=1)
		sc_sleep(S.delayy)
		// Record fast axis
		NEW_Fd_record_values(S, i, AWG_list=AWG)
//		fd_Record_Values(Fsv, PL, i, AWG_list = AWG)
	endfor

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
//  		SaveWaves(msg=comments, fastdac=1)
  	else
  		dowindow /k SweepControl
	endif
end
//
////function/T ScanFastDAC2DLineCut(fdID, width, minx, maxx, channelsx, starty, finy, channelsy, numptsy, [x1, y1, x2, y2, cs_wname, cs_gate, channelsxfast, fastch_ratio, slope, y_int, numpts, sweeprate, bdID, rampratex, rampratey, delayy, comments, RCcutoff, numAverage, notch, nosave, use_AWG])
////	// /T because it returns the final slope and gradient in a ';' separated list
////
////	// 2D Linecut Scan for FastDAC only OR FastDAC on fast axis and BabyDAC on slow axis
////	// Scan will go +/- width, minx and maxx indicate the farthest the channelsx parameter should vary
////	// Note: Must provide numptsx OR sweeprate in optional parameters instead
////	// Note: To ramp with babyDAC on slow axis provide the BabyDAC variable in bdID
////	// Note: channels should be a comma-separated string ex: "0,4,5"
////	variable fdID, width, minx, maxx, starty, finy, numptsy, x1, y1, x2, y2, fastch_ratio, slope, y_int, numpts, sweeprate, bdID, rampratex, rampratey, delayy, RCcutoff, numAverage, nosave, use_AWG
////	string channelsx, channelsy, channelsxfast, comments, notch, cs_wname, cs_gate
////	variable i=0, j=0, center=0
////	string line_eq_str
////
////	// Check inputs
////	if ((paramisdefault(slope) || paramisdefault(y_int)) && (paramisdefault(x1) || paramisdefault(y1) || paramisdefault(x2) || paramisdefault(y2)))
////		abort "Must provide slope and y_int, or all of x1, y1, x2, y2"
////	endif
////
////	// Reconnect instruments
////	sc_openinstrconnections(0)
////
////	// Set defaults
////	nvar fd_ramprate
////	variable has_fchan
////	rampratex = paramisdefault(rampratex) ? fd_ramprate : rampratex
////	rampratey = ParamIsDefault(rampratey) ? fd_ramprate : rampratey
////	delayy = ParamIsDefault(delayy) ? 0.5 : delayy
////	if (paramisdefault(channelsxfast))
////		channelsxfast = channelsx
////		has_fchan = 0
////	else
////		if (ParamIsDefault(fastch_ratio))
////			abort "Must include a multiplier for finest axis"
////		endif
////		has_fchan = 1
////	endif
////	fastch_ratio = ParamIsDefault(fastch_ratio) ? 1 : fastch_ratio
////	notch = selectstring(paramisdefault(notch), notch, "")
////   comments = selectstring(paramisdefault(comments), comments, "")
////   cs_wname = selectstring(paramisdefault(cs_wname), cs_wname, "cscurrent")
////   // Calculate starting center
////   // center = LC_next_transition(x1, y1, x2, y2, starty)
////   if (ParamIsDefault(slope) || ParamIsDefault(y_int))
////   		slope = (y2 - y1)/(x2 - x1) // Calculate slope
////   		Y_int = y1 - (slope * x1) // Calculate y intercept
////   endif
////   
////   variable use_bd = paramisdefault(bdid) ? 0 : 1 		// Whether using both FD and BD or just FD
////   // Set sc_scanVars struct
//// 	struct FD_ScanVars Fsv
//// 	if(use_bd == 0)  	// if not using BabyDAC then fully init FDscanVars
////	   SF_init_FDscanVars(Fsv, fdID, center-width, center+width, channelsxfast, numpts, rampratex, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
////	   						 starty=starty, finy=finy, channelsy=channelsy, rampratey=rampratey)
////	else  				// Using BabyDAC for Y axis so init x in FD_ScanVars, and init y in BD_ScanVars
////	   SF_init_FDscanVars(Fsv, fdID, center-width, center+width, channelsxfast, numpts, rampratex, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy)
////		struct BD_ScanVars Bsv
////		SF_init_BDscanVars(Bsv, bdID, starty=starty, finy=finy, channelsy=channelsy, rampratey=rampratey)
////	endif
////   
////   // Set ProcessList Struct
////   struct fdRV_ProcessList PL
////   SFfd_init_ProcessList(PL, RCcutoff, numAverage, notch)
////   
////   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
////   SFfd_pre_checks(Fsv)  
////   if(use_bd == 1)
////   		SFbd_pre_checks(Bsv)
////   	endif
////   	
////   
////   // Ramp to start without checks
////   SFfd_ramp_start(Fsv, y_only = 1, ignore_lims=1)
////   if(use_bd == 1)
////   		SFbd_ramp_start(Bsv, ignore_lims=1)
////   	endif
////   	
////   	// Let gates settle
////	sc_sleep(Fsv.delayy)
////
////	// Get Labels for waves
////	string x_label, y_label
////	x_label = GetLabel(Fsv.channelsx, fastdac=1)
////	if (use_bd == 0) // If using FastDAC on slow axis
////		y_label = GetLabel(Fsv.channelsy, fastdac=1)
////	else // If using BabyDAC on slow axislabels
////		y_label = GetLabel(Bsv.channelsy, fastdac=0)
////	endif
////
////	
////	
////	// Main measurement loop
////	variable setpointy, mid
////	variable stepsize = (finy-starty)/(Fsv.numptsy-1)
////	// Make "real" centers wave for reference
////	make/o/N=(Fsv.numptsy) lc_centers
////	make/o/N=(Fsv.numptsy) lc_centers_y
////	for(i=0; i<Fsv.numptsy; i++)
////		// Calculate setpoint
////		setpointy = starty + (i*stepsize)	// Note: Again, setpointy is independent of FD/BD
////		
////		// Calculate next center
////	   center = LC_next_center(slope, y_int, setpointy, starty, stepsize, i)
////	  
////	   // Check that scan is in bounds
////	   if (has_fchan == 1)
////	   		if (center < minx || center > maxx)
////		   		print "Last used slope " + num2str(slope) + " and intercept " + num2str(y_int)
////	   			abort "Scan out of bounds, run SaveWaves(msg=\"linecut\",fastdac=1)"
////	   		endif
////	   else
////	   		if (center-width < minx || center+width>maxx)
////		   		print "Last used slope " + num2str(slope) + " and intercept " + num2str(y_int)
////	   			abort "Scan out of bounds, run SaveWaves(msg=\"linecut\",fastdac=1)"
////	   		endif
////	   endif
////	   
////	   // Only update after checks are passed
////	   	line_eq_str = ""
////		line_eq_str = addlistItem(num2str(slope), line_eq_str, ";", INF)
////		line_eq_str = addlistItem(num2str(y_int), line_eq_str, ";", INF)
////	   
////	   // Update Fsv 
////	   if(use_bd == 0)  	// if not using BabyDAC then fully init FDscanVars
////	  		mid = 0
////	   		if (has_fchan == 0)
////				mid = center
////	   		endif
////	   		SF_init_FDscanVars(Fsv, fdID, mid-width, mid+width, channelsxfast, numpts, rampratex, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
////	   						 starty=starty, finy=finy, channelsy=channelsy, rampratey=rampratey)
////		else  				// Using BabyDAC for Y axis so init x in FD_ScanVars, and init y in BD_ScanVars
////	   		SF_init_FDscanVars(Fsv, fdID, mid-width, mid+width, channelsxfast, numpts, rampratex, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy)
////	   	endif
////	   	
////	   	// If using AWG then get that now and check it
////		struct fdAWG_list AWG
////		if(use_AWG)	
////			fdAWG_get_global_AWG_list(AWG)
////			SFawg_set_and_precheck(AWG, Fsv)  // Note: sets SV.numptsx here and AWG.use_AWG = 1 if pass checks
////		else  // Don't use AWG
////			AWG.use_AWG = 0  	// This is the default, but just putting here explicitly
////		endif
////	  
////	   if (i == 0)
////		   // Make waves												// Note: Using just starty, finy because initwaves doesn't care if it's FD/BD
////			InitializeWaves(Fsv.startx, Fsv.finx, Fsv.numptsx, starty=starty, finy=finy, numptsy=Fsv.numptsy, x_label=x_label, y_label=y_label, linecut=1, fastdac=1)
////		endif
////	    
////		if (use_bd == 0) // If using FastDAC on slow axis
////			RampMultipleFDac(Fsv.instrID, Fsv.channelsy, setpointy, ramprate=Fsv.rampratey, ignore_lims=1)
////		else // If using BabyDAC on slow axislabels
////			RampMultipleBD(Bsv.instrID, Bsv.channelsy, setpointy, ramprate=Bsv.rampratey, ignore_lims=1)
////		endif
////		
////		
////		// Ramp X and set charge sensor
////	   	if (has_fchan == 1)
////			RampMultipleFDac(Fsv.instrID, channelsxfast, 0 - (0.1*width), ramprate=sweeprate*10, ignore_lims=1)
////			RampMultipleFDac(Fsv.instrID, channelsx, center, ignore_lims=1)
////		else
////			RampMultipleFDac(Fsv.instrID, channelsx, center - (0.1*width), ignore_lims=1)
////	   	endif
////
////		if (!paramisdefault(cs_gate))
////		   CorrectChargeSensor(fd=Fsv.instrID, fdchannelstr=cs_gate, fadcID=Fsv.instrID, fadcchannel=0, check=0, direction=1)
////		endif	
////		
////		// Ramp back again
////		if (has_fchan == 1)
////			RampMultipleFDac(Fsv.instrID, channelsxfast, 0, ramprate=10*fastch_ratio, ignore_lims=1)
////		else
////			RampMultipleFDac(Fsv.instrID, channelsx, center, ramprate=100, ignore_lims=1)
////	   	endif
////		
////		// Ramp to start of fast axis
////		SFfd_ramp_start(Fsv, ignore_lims=1, x_only=1)
////		sc_sleep(Fsv.delayy)
////		// Record fast axis
////		fd_Record_Values(Fsv, PL, i, AWG_list = AWG, linestart=center)
////		// Record real center for reference
////		lc_centers[i] = center + (findtransitionmid($cs_wname)/fastch_ratio) // Real center in LP space
////		lc_centers_y[i] = setpointy
////	endfor
////	
////	// Fast channel x back to 0
////	if (has_fchan == 1)
////		RampMultipleFDac(Fsv.instrID, channelsxfast, 0, ramprate=10*fastch_ratio, ignore_lims=1)
////	endif
////
////	// Save by default
////	if (nosave == 0)
////  		SaveWaves(msg=comments, fastdac=1)
////  	else
////  		dowindow /k SweepControl
////	endif
////	
////	/////////////////////// something like this, but maybe should be updated each time and printed on abort or something? 
////	line_eq_str = ""
////	line_eq_str = addlistItem(num2str(slope), line_eq_str, ";", INF)
////	line_eq_str = addlistItem(num2str(y_int), line_eq_str, ";", INF)
////	
////	print "Completed linecut with final slope " + num2str(slope) + " and intercept " + num2str(y_int)
////	
////	return line_eq_str
////	////////////////////////////
////	
////end
//
//
//
//// Updates values of slope and y_int as well as returning new center
//function LC_next_center(slope, y_int, nexty, starty, stepsize, nextrownum, [Y_LENGTH])
//	variable &slope, &y_int, nexty, starty, stepsize, nextrownum
//	variable Y_LENGTH
//	Y_LENGTH = paramisdefault(Y_LENGTH) ? 5 : Y_LENGTH
//	
//	wave lc_centers
//	wave lc_centers_y
//	
//	variable center = 0
//	variable old_center, t_slope, t_y_int
//	if (abs((nexty - stepsize) - starty) <= Y_LENGTH || nextrownum < 2) // Not yet in a regime where anything is updated
//		center = (1/slope) * (nexty - y_int) // base case
//	else // In a regime where things are updated
//		// fit last data points to a line
//		variable pointnum = max(ceil(abs(Y_LENGTH/stepsize)),2) 
//		duplicate/o/free/r=[nextrownum-1-pointnum, nextrownum-1] lc_centers short_lc_centers
//		wavestats/Q short_lc_centers
//		if (V_numNans/pointnum < 0.5 && pointnum - V_numNans >= 2)
//			CurveFit/Q line lc_centers_y[nextrownum-1-pointnum, nextrownum-1] /X=lc_centers[nextrownum-1-pointnum, nextrownum-1] 
//			wave W_coef
//			slope = W_coef[1]
//			y_int = W_coef[0] 
//		endif
//		center = (1/slope) * (nexty - y_int)
//	endif
//	//Check to make sure center is a number
//	if (numtype(center) >= 1)
//		abort "Center not a number"
//	endif 
//	return center
//end
//
//
function ScanfastDACRepeat(instrID, start, fin, channels, numptsy, [numptsx, sweeprate, delay, ramprate, alternate, starts, fins, comments, nosave, use_awg])
	// 1D repeat scan for FastDAC
	// Note: to alternate scan direction set alternate=1
	// Note: Ramprate is only for ramping gates between scans
	variable instrID, start, fin, numptsy, numptsx, sweeprate, delay, ramprate, alternate, nosave, use_awg
	string channels, comments, starts, fins
	variable i=0, j=0

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Set defaults
	nvar fd_ramprate
	ramprate = paramisdefault(ramprate) ? fd_ramprate : ramprate
	delay = ParamIsDefault(delay) ? 0.5 : delay
	comments = selectstring(paramisdefault(comments), comments, "")
	starts = selectstring(paramisdefault(starts), starts, "")
	fins = selectstring(paramisdefault(fins), fins, "")

	// Set sc_ScanVars struct
	struct ScanVars S
	initFDscanVars(S, instrID, start, fin, channels, numptsx=numptsx, rampratex=ramprate, delayy=delay, sweeprate=sweeprate,  \
					numptsy=numptsy, direction=1, startxs=starts, finxs=fins, y_label="Repeats", comments=comments)
	S.is2d = 1 // Doesn't otherwise get detected because of no y channels
	S.starty = 1
	S.finy = numptsy
	
	// Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
	SFfd_pre_checks(S)  

  	// If using AWG then get that now and check it
	struct fdAWG_list AWG
	if(use_AWG)	
		fdAWG_get_global_AWG_list(AWG)
		abort "Not Implemented yet"
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
//
////function ScanSRSFreq(instrID, start, fin, numpts, delay, [comments, nosave]) //Units: Hz
////	// sweep SRS output freq
////	variable instrID, start, fin, numpts, delay, nosave
////	string comments
////
////   // Reconnect instruments
////   //sc_openinstrconnections(0)
////
////   // Set defaults
////   comments = selectstring(paramisdefault(comments), comments, "")
////
////	// Ramp to start without checks because checked above
////	SetSRSFrequency(instrID, start)
////
////   // Let things settle
////	sc_sleep(1.0)
////
////   // Get labels for waves
////   string x_label
////   x_label = "Freq [Hz]"
////
////   // Make waves
////	InitializeWaves(start, fin, numpts, x_label=x_label)
////
////   // Main measurement loop
////	variable i=0, j=0, setpoint
////	do
////		setpoint = start + (i*(fin-start)/(numpts-1))
////		SetSRSFrequency(instrID, setpoint)
////		sc_sleep(delay)
////		RecordValues(i, 0)
////		i+=1
////	while (i<numpts)
////
////   // Save by default
////   if (nosave == 0)
////  		SaveWaves(msg=comments)
////  	else
////  		dowindow /k SweepControl
////	endif
////end
////
//
////function MeasurevsTemp(instrID, numpts, delay, [comments]) 
////	variable instrID, numpts, delay
////	string comments
////
////
////   // Set defaults
////   comments = selectstring(paramisdefault(comments), comments, "")
////
////   // Get labels for waves
////   string x_label
////   x_label = "Temp [K]"
////
////   // Make waves
////	InitializeWaves(start, fin, numpts, x_label=x_label)
////
////   // Main measurement loop
////	variable i=0, j=0, setpoint
////	do
////		setpoint = start + (i*(fin-start)/(numpts-1))
////		SetSRSFrequency(instrID, setpoint)
////		sc_sleep(delay)
////		RecordValues(i, 0)
////		i+=1
////	while (i<numpts)
////
////   // Save by default
////   if (nosave == 0)
////  		SaveWaves(msg=comments)
////  	else
////  		dowindow /k SweepControl
////	endif
////end




//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////// Macros //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function AAMacros()
end

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


//function StepTempScanSomething()
//	// nvar bd6, srs1
//	svar ls370
//
//	make/o targettemps =  {300, 275, 250, 225, 200, 175, 150, 125, 100, 75, 50, 40, 30, 20}
//	make/o heaterranges = {10, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 1, 1, 1, 1}
//	setLS370exclusivereader(ls370,"bfsmall_mc")
//
//	variable i=0
//	do
//		setLS370Temp(ls370,targettemps[i],maxcurrent = heaterranges[i])
//		sc_sleep(2.0)
//		WaitTillTempStable(ls370, targettemps[i], 5, 20, 0.10)
//		sc_sleep(60.0)
//		print "MEASURE AT: "+num2str(targettemps[i])+"mK"
//
//		//SCAN HERE
//
//		i+=1
//	while ( i<numpnts(targettemps) )
//
//	// kill temperature control
////	turnoffLS370MCheater(ls370)
//	resetLS370exclusivereader(ls370)
//	sc_sleep(60.0*30)
//
//	// 	SCAN HERE for base temp
//end
//




/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// SCAN FUNCTIONS //////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////



function SFfd_pre_checks(S)
   struct ScanVars &S
	SFfd_check_same_device(S) // Checks DACs and ADCs are on same device
	SFfd_check_ramprates(S)	// Check ramprates of x and y
	SFfd_check_lims(S)			// Check within software lims for x and y
	S.lims_checked = 1  		// So record_values knows that limits have been checked!
end


function SFfd_ramp_start(S, [ignore_lims, x_only, y_only])
	// move DAC channels to starting point
	struct ScanVars &S
	variable ignore_lims, x_only, y_only

	variable i, setpoint
	// If x exists ramp them to start
	if(numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0 && y_only != 1)  // If not NaN and not ""
		for(i=0;i<itemsinlist(S.channelsx,",");i+=1)
			if(S.direction == 1)
				setpoint = str2num(stringfromlist(i,S.startxs,","))
			elseif(S.direction == -1)
				setpoint = str2num(stringfromlist(i,S.finxs,","))
			else
				abort "ERROR[SFfd_ramp_start]: S.direction not set to 1 or -1"
			endif
			rampOutputfdac(S.instrID,str2num(stringfromlist(i,S.channelsx,",")),setpoint,ramprate=S.rampratex, ignore_lims=ignore_lims)			
		endfor
	endif  
	
	// If y exists ramp them to start
	if(numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0 && x_only != 1)  // If not NaN and not "" and not x only
		for(i=0;i<itemsinlist(S.channelsy,",");i+=1)
			rampOutputfdac(S.instrID,str2num(stringfromlist(i,S.channelsy,",")),str2num(stringfromlist(i,S.startys,",")),ramprate=S.rampratey, ignore_lims=ignore_lims)
		endfor
	endif
  
end


function SFfd_set_measureFreq(S)
   struct ScanVars &S
   S.samplingFreq = getfadcSpeed(S.instrID)
   S.numADCs = getNumFADC()
   S.measureFreq = S.samplingFreq/S.numADCs  //Because sampling is split between number of ADCs being read //TODO: This needs to be adapted for multiple FastDacs
end

function SFfd_check_ramprates(S)
  // check if effective ramprate is higher than software limits
  struct ScanVars &S

  wave/T fdacvalstr
  svar activegraphs

	variable kill_graphs = 0
	// Check x's won't be swept to fast by calculated sweeprate for each channel in x ramp
	// Should work for different start/fin values for x
	variable eff_ramprate, answer, i, k, channel
	string question

	if(!numtype(strlen(s.channelsx)) == 0 == 0 && strlen(s.channelsx) != 0)  // if s.Channelsx != (null or "")
		for(i=0;i<itemsinlist(S.channelsx,",");i+=1)
			eff_ramprate = abs(str2num(stringfromlist(i,S.startxs,","))-str2num(stringfromlist(i,S.finxs,",")))*(S.measureFreq/S.numptsx)
			channel = str2num(stringfromlist(i, S.channelsx, ","))
			if(eff_ramprate > str2num(fdacvalstr[channel][4])*1.05 || s.rampratex > str2num(fdacvalstr[channel][4])*1.05)  // Allow 5% too high for convenience
				// we are going too fast
				sprintf question, "DAC channel %d will be ramped at (%.1f mV/s or %.1f mV/s), software limit is set to %s mV/s. Continue?", channel, eff_ramprate, s.rampratex, fdacvalstr[channel][4]
				answer = ask_user(question, type=1)
				if(answer == 2)
					kill_graphs = 1
					break
				endif
			endif
		endfor
	endif
  
	// if Y channels exist, then check against rampratey (not sweeprate because only change on slow axis)	
	if(numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0  && kill_graphs == 0)  // if s.Channelsy != (NaN or "") and not killing graphs yet 
		for(i=0;i<itemsinlist(S.channelsy,",");i+=1)
			channel = str2num(stringfromlist(i, S.channelsy, ","))
			if(s.rampratey > str2num(fdacvalstr[channel][4]))
				sprintf question, "DAC channel %d will be ramped at %.1f mV/s, software limit is set to %s mV/s. Continue?", channel, S.rampratey, fdacvalstr[channel][4]
				answer = ask_user(question, type=1)
				if(answer == 2)
					kill_graphs = 1
					break
				endif
			endif
		endfor
	endif

	if(kill_graphs == 1)  // If user selected do not continue, then kill graphs and abort
		print("[ERROR] \"RecordValues\": User abort!")
		dowindow/k SweepControl // kill scan control window
		for(k=0;k<itemsinlist(activegraphs,";");k+=1)
			dowindow/k $stringfromlist(k,activegraphs,";")
		endfor
		abort
	endif
  
end



function SFfd_check_lims(S)
	// check that start and end values are within software limits
	struct ScanVars &S

	wave/T fdacvalstr
	svar activegraphs
	variable answer, i, k
	
	// Make single list out of X's and Y's (checking if each exists first)
	string channels = "", starts = "", fins = ""
	if(numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0)  // If not NaN and not ""
		channels = addlistitem(S.channelsx, channels, ",")
		starts = addlistitem(S.startxs, starts, ",")
		fins = addlistitem(S.finxs, fins, ",")
	endif
	if(numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0)  // If not NaN and not ""
		channels = addlistitem(S.channelsy, channels, ",")
		starts = addlistitem(S.startys, starts, ",")
		fins = addlistitem(S.finys, fins, ",")
	endif

	// Check channels were concatenated correctly (Seems unnecessary, but possibly killed my device because of this...)
	if(stringmatch(channels, "*,,*") == 1)
		abort "ERROR[SFfd_check_lims]: Channels list contains ',,' which means something has gone wrong and limit checking WONT WORK!!"
	endif

	// Check that start/fin for each channel will stay within software limits
	string softLimitPositive = "", softLimitNegative = "", expr = "(-?[[:digit:]]+)\\s*,\\s*([[:digit:]]+)", question
	variable startval = 0, finval = 0
	string buffer
	for(i=0;i<itemsinlist(channels,",");i+=1)
		splitstring/e=(expr) fdacvalstr[str2num(stringfromlist(i,channels,","))][2], softLimitNegative, softLimitPositive
 		if(!numtype(str2num(softLimitNegative)) == 0 || !numtype(str2num(softLimitPositive)) == 0)
 			sprintf buffer, "No Lower or Upper Limit found for Channel %s. Low limit = %s. High limit = %s, Limit string = %s\r", stringfromlist(i,channels,","), softLimitNegative, softLimitPositive, fdacvalstr[str2num(stringfromlist(i,channels,","))][2]
 			abort buffer
 		endif
 		
		startval = str2num(stringfromlist(i,starts,","))
		finval = str2num(stringfromlist(i,fins,","))
		if(startval < str2num(softLimitNegative) || startval > str2num(softLimitPositive) || finval < str2num(softLimitNegative) || finval > str2num(softLimitPositive))
			// we are outside limits
			sprintf question, "DAC channel %s will be ramped outside software limits. Continue?", stringfromlist(i,channels,",")
			answer = ask_user(question, type=1)
			if(answer == 2)
				print("[ERROR] \"RecordValues\": User abort!")
				dowindow/k SweepControl // kill scan control window
				for(k=0;k<itemsinlist(activegraphs,";");k+=1)
					dowindow/k $stringfromlist(k,activegraphs,";")
				endfor
				abort
			endif
		endif
	endfor		
end


function SFfd_check_same_device(S)
	// Checks all rampChs and ADCs (selected in fd_scancontroller window)
	// are on the same device. 
	struct ScanVars &s
	wave fadcattr
	wave/t fadcvalstr
	svar sc_fdacKeys
	
	// check that all DAC channels are on the same device
	variable numRampCh = itemsinlist(S.channelsx,","),i=0,j=0,dev_dac=0,dacCh=0,startCh=0
	variable numDevices = str2num(stringbykey("numDevices",sc_fdacKeys,":",",")),numDACCh=0
	for(i=0;i<numRampCh;i+=1)
		dacCh = str2num(stringfromlist(i,S.channelsx,","))
		startCh = 0
		for(j=0;j<numDevices;j+=1)
			numDACCh = str2num(stringbykey("numDACCh"+num2istr(j+1),sc_fdacKeys,":",","))
			if(startCh+numDACCh-1 >= dacCh)
				// this is the device
				if(i > 0 && dev_dac != j)
					print "[ERROR] \"sc_checkfdacDevice\": All DAC channels must be on the same device!"
					abort
				else
					dev_dac = j
					break
				endif
			endif
			startCh += numDACCh
		endfor
	endfor
	
	// check that all adc channels are on the same device
	variable q=0,numReadCh=0,h=0,dev_adc=0,adcCh=0,numADCCh=0
	for(i=0;i<itemsinlist(S.adcList, ",");i+=1)
		adcCh = str2num(stringfromList(i, S.adcList, ","))
		startCh = 0
		for(j=0;j<numDevices+1;j+=1)
			numADCCh = str2num(stringbykey("numADCCh"+num2istr(j+1),sc_fdacKeys,":",","))
			if(startCh+numADCCh-1 >= adcCh)
				// this is the device
				if(i > 0 && dev_adc != j)
					print "[ERROR] \"sc_checkfdacDevice\": All ADC channels must be on the same device!"
					abort
				elseif(j != dev_dac)
					print "[ERROR] \"sc_checkfdacDevice\": DAC & ADC channels must be on the same device!"
					abort
				else
					dev_adc = j
					break
				endif
			endif
			startCh += numADCCh
		endfor
	endfor
	return dev_adc
end


function SFfd_format_setpoints(start, fin, channels, starts, fins)
	// Returns strings in starts and fins in the format that fdacRecordValues takes
	// e.g. fd_format_setpoints(-10, 10, "1,2,3", s, f) will make string s = "-10,-10,-10" and string f = "10,10,10"
	variable start, fin
	string channels, &starts, &fins
	
	variable i
	starts = ""
	fins = ""
	for(i=0; i<itemsInList(channels, ","); i++)
		starts = addlistitem(num2str(start), starts, ",", INF)
		fins = addlistitem(num2str(fin), fins, ",", INF)
	endfor
	starts = starts[0,strlen(starts)-2] // Remove comma at end
	fins = fins[0,strlen(fins)-2]	 		// Remove comma at end
end
//
//
//function SFbd_pre_checks(S)
//   struct BD_ScanVars &S
////	SFbd_check_ramprates(S)	// Check ramprates of x and y
//	SFbd_check_lims(S)			// Check within software lims for x and y
//	S.lims_checked = 1  		// So record_values knows that limits have been checked!
//end
//

function SFfd_sanitize_setpoints(start_list, fin_list, channels, starts, fins)
	// Makes sure starts/fins make sense for number of channels and have no bad formatting
	// Modifies the starts/fins strings passed in
	string start_list, fin_list, channels
	string &starts, &fins
	
	string buffer
	
	if (itemsinlist(channels, ",") != itemsinlist(start_list, ",") || itemsinlist(channels, ",") != itemsinlist(fin_list, ","))
		sprintf buffer, "length of start_list/fin_list/channels not equal!!! start_list:(%s), fin_list:(%s), channels:(%s)\r", start_list, fin_list, channels
		abort buffer
	endif
	
	starts = replaceString(" ", start_list, "")
	fins = replaceString(" ", fin_list, "")
end


function SFbd_check_lims(S)
	// check that start and end values are within software limits
   struct ScanVars &S
	
	// Make single list out of X's and Y's (checking if each exists first)
	string all_channels = "", outputs = ""
	if(numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0)  // If not NaN and not ""
		all_channels = addlistitem(S.channelsx, all_channels, ";")
		outputs = addlistitem(num2str(S.startx), outputs, ",")
		outputs = addlistitem(num2str(S.finx), outputs, ",")
	endif

	if(numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0)  // If not NaN and not ""
		all_channels = addlistitem(S.channelsy, all_channels, ";")
		outputs = addlistitem(num2str(S.starty), outputs, ",")
		outputs = addlistitem(num2str(S.finy), outputs, ",")
	endif
	

	wave/T dacvalstr
	svar activegraphs
	wave bd_range_span, bd_range_high, bd_range_low

	variable board_index, sw_limit
	variable answer, i, j, k, channel, output, kill_graphs = 0
	string channels, abort_msg = "", question
	for(i=0;i<itemsinlist(all_channels, ";");i++)  		// channelsx then channelsy if it exists
		channels = stringfromlist(i, all_channels, ";")
		for(j=0;j<itemsinlist(channels, ",");j++)			// each channel from channelsx/channelsy
			channel = str2num(stringfromlist(j, channels, ","))
			for(k=0;k<2;k++)  									// Start/Fin for each channel
				output = str2num(stringfromlist(2*i+k, outputs, ","))  // 2 per channelsx/channelsy
				// Check that the DAC board is initialized
				bdGetBoard(channel)
				board_index = floor(channel/4)
			
				// check for NAN and INF
				if(numtype(output) != 0)
					abort "trying to set voltage to NaN or Inf"
				endif
			
				// Check that the voltage is valid
				if(output > bd_range_high[board_index] || output < bd_range_low[board_index])
					sprintf abort_msg, "voltage out of DAC range, %.3fmV", output
					kill_graphs = 1
					break
				endif
			
				// check that the voltage is within software limits
				// if outside, ask user if want to continue anyway
				sw_limit = str2num(dacvalstr[channel][2])
				if(abs(output) > sw_limit)
					sprintf question, "DAC channel %s will be ramped outside software limits. Continue?", stringfromlist(i,channels,",")
					answer = ask_user(question, type=1)
					if(answer == 2)
						sprintf abort_msg "User aborted"
						kill_graphs = 1
						break
					endif
				endif
				if(kill_graphs == 1)  // Don't bother checking the rest
					break
				endif
			endfor
			if(kill_graphs == 1)  // Don't bother checking the rest
				break
			endif
		endfor
		if(kill_graphs == 1)  // Don't bother checking the rest
			break
		endif
	endfor

	if(kill_graphs == 1)
		dowindow/k SweepControl // kill scan control window
		for(k=0;k<itemsinlist(activegraphs,";");k+=1)
			dowindow/k $stringfromlist(k,activegraphs,";")
		endfor		
		abort abort_msg
	endif
end


function SFbd_ramp_start(S, [ignore_lims])
	// move DAC channels to starting point
	struct ScanVars &S
	variable ignore_lims

	variable i
	// If x exists ramp them to start
	if(numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0)  // If not NaN and not ""
		RampMultipleBD(S.instrID, S.channelsx, S.startx, ramprate=S.rampratex, ignore_lims=ignore_lims)
	endif  
	
	// If y exists ramp them to start
	if(numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0)  // If not NaN and not ""
		RampMultipleBD(S.instrID, S.channelsy, S.starty, ramprate=S.rampratey, ignore_lims=ignore_lims)
	endif
end


function SFawg_check_AWG_list(AWG, Fsv)
	// Check that AWG and FastDAC ScanValues don't have any clashing DACs and check AWG within limits etc
	struct fdAWG_List &AWG
	struct ScanVars &Fsv
	
	string AWdacs  // Used for storing all DACS for 1 channel  e.g. "123" = Dacs 1,2,3
	string err_msg
	variable i=0, j=0
		
	// Check initialized
	if(AWG.initialized == 0)
		abort "ERROR[SFawg_check_AWG_list]: AWG_List needs to be initialized. Maybe something changed since last use!"
	endif
	
	// Check numADCs hasn't changed since setting up waves
	if(AWG.numADCs != getNumFADC())
		abort "ERROR[SFawg_check_AWG_list]: Number of ADCs being measured has changed since setting up AWG, this will change AWG frequency. Set up AWG again to continue"
	endif
	
	// Check measureFreq hasn't change since setting up waves
	if(AWG.measureFreq != Fsv.measureFreq  || AWG.samplingFreq != Fsv.samplingFreq)
		sprintf err_msg, "ERROR[SFawg_check_AWG_list]: MeasureFreq has changed from %.2f/s to %.2f/s since setting up AWG. Set up AWG again to continue", AWG.measureFreq, Fsv.measureFreq
		abort err_msg
	endif
	
	// Check numSteps is an integer and not zero
	if(AWG.numSteps != trunc(AWG.numSteps) || AWG.numSteps == 0)
		abort "ERROR[SFawg_check_AWG_list]: numSteps must be an integer, not " + num2str(AWG.numSteps)
	endif
			
	// Check there are DACs set for each AW_wave (i.e. if using 2 AWs, need at least 1 DAC for each)
	if(itemsInList(AWG.AW_waves, ",") != (itemsinlist(AWG.AW_Dacs,",")))
		sprintf err_msg "ERROR[SFawg_check_AWG_list]: Number of AWs doesn't match sets of AW_Dacs. AW_Waves: %s; AW_Dacs: %s", AWG.AW_waves, AWG.AW_Dacs
		abort err_msg
	endif	
	
	// Check no overlap between DACs for sweeping, and DACs for AWG
	string channel // Single DAC channel
	string FDchannels = addlistitem(Fsv.Channelsy, Fsv.Channelsx, ",") // combine channels lists
	for(i=0;i<itemsinlist(AWG.AW_Dacs, ",");i++)
		AWdacs = stringfromlist(i, AWG.AW_Dacs, ",")
		for(j=0;j<strlen(AWdacs);j++)
			channel = AWdacs[j]
			if(findlistitem(channel, FDchannels, ",") != -1)
				abort "ERROR[SFawg_check_AWG_list]: Trying to use same DAC channel for FD scan and AWG at the same time"
			endif
		endfor
	endfor

	// Check that all setpoints for each AW_Dac will stay within software limits
	wave/T fdacvalstr	
	string softLimitPositive = "", softLimitNegative = "", expr = "(-?[[:digit:]]+),([[:digit:]]+)", question
	variable setpoint, answer, ch_num
	for(i=0;i<itemsinlist(AWG.AW_Dacs,",");i+=1)
		AWdacs = stringfromlist(i, AWG.AW_Dacs, ",")
		string wn = fdAWG_get_AWG_wave(str2num(stringfromlist(i, AWG.AW_Waves, ",")))  // Get IGOR wave of AW#
		wave w = $wn
		duplicate/o/r=[0][] w setpoints  							// Just get setpoints part
		for(j=0;j<strlen(AWdacs);j++)  // Check for each DAC that will be outputting this wave
			ch_num = str2num(AWdacs[j])
			splitstring/e=(expr) fdacvalstr[ch_num][2], softLimitNegative, softLimitPositive
			for(j=0;j<numpnts(setpoints);j++)	// Check against each setpoint in AW
				if(setpoint < str2num(softLimitNegative) || setpoint > str2num(softLimitPositive))
					// we are outside limits
					sprintf question, "DAC channel %s will be ramped outside software limits. Continue?", AWdacs[j]
					answer = ask_user(question, type=1)
					if(answer == 2)
						print("ERROR[SFawg_check_AWG_list]: User abort!")
						abort
					endif
				endif
			endfor
		endfor
	endfor		
end


function SFawg_set_and_precheck(AWG, S)
	struct fdAWG_List &AWG
	struct ScanVars &S

	
	// Set numptsx in Scan s.t. it is a whole number of full cycles
	AWG.numSteps = round(S.numptsx/(AWG.waveLen*AWG.numCycles))  
	S.numptsx = (AWG.numSteps*AWG.waveLen*AWG.numCycles)
	
	// Check AWG for clashes/exceeding lims etc
	SFawg_check_AWG_list(AWG, S)	
	AWG.use_AWG = 1
	
	// Save numSteps in AWG_list for sweeplogs later
	fdAWG_set_global_AWG_list(AWG)
end
	
