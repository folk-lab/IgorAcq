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

	InitializeWaves(0, 1, 1, x_label="time (s)")
	nvar sc_scanstarttime // Global variable set when InitializeWaves is called
	do
		sc_sleep(delay)
		RecordValues(i, 0,readvstime=1)
		i+=1
	while (1)
	SaveWaves(msg=comments)
end


function ScanBabyDAC(instrID, start, fin, channels, numpts, delay, ramprate, [comments, nosave]) //Units: mV
	// sweep one or more babyDAC channels
	// channels should be a comma-separated string ex: "0, 4, 5"
	variable instrID, start, fin, numpts, delay, ramprate, nosave
	string channels, comments

   // Reconnect instruments
   sc_openinstrconnections(0)

   // Set defaults
   comments = selectstring(paramisdefault(comments), comments, "")

   // Set sc_ScanVars struct
   struct BD_ScanVars SV
   SF_init_BDscanVars(SV, instrID, startx=start, finx=fin, channelsx=channels, numptsx=numpts, delayx=delay, rampratex=ramprate)

   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
   SFbd_pre_checks(SV)  

	// Ramp to start without checks because checked above
	SFbd_ramp_start(SV, ignore_lims=1)

   // Let gates settle 
	sc_sleep(1.0)

   // Get labels for waves
   string x_label
   x_label = GetLabel(SV.channelsx)

   // Make waves
	InitializeWaves(SV.startx, SV.finx, SV.numptsx, x_label=x_label)

   // Main measurement loop
	variable i=0, j=0, setpoint
	do
		setpoint = SV.startx + (i*(SV.finx-SV.startx)/(SV.numptsx-1))
		RampMultipleBD(SV.instrID, SV.channelsx, setpoint, ramprate=SV.rampratex, ignore_lims=1)
		sc_sleep(SV.delayx)
		RecordValues(i, 0)
		i+=1
	while (i<SV.numptsx)

   // Save by default
   if (nosave == 0)
  		SaveWaves(msg=comments)
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
	
	// Set sc_ScanVars struct
	struct BD_ScanVars SV
	SF_init_BDscanVars(SV, instrID, startx=startx, finx=finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
	                             starty=starty, finy=finy, channelsy=channelsy, numptsy=numptsy, delayy=delayy, rampratey=rampratey)

	// Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
	SFbd_pre_checks(SV)  
	
	// Ramp to start without checks because checked above
	SFbd_ramp_start(SV, ignore_lims=1)
	
	// Let gates settle 
	sc_sleep(SV.delayy)
	
	// Get labels for waves
	string x_label, y_label
	x_label = GetLabel(SV.channelsx)
	y_label = GetLabel(SV.channelsy)

	// Initialize waves
	InitializeWaves(SV.startx, SV.finx, SV.numptsx, starty=SV.starty, finy=SV.finy, numptsy=SV.numptsy, x_label=x_label, y_label=y_label)
	
	// Main measurement loop
	variable i=0, j=0, setpointx, setpointy
	do
		setpointx = SV.startx
		setpointy = SV.starty + (i*(SV.finy-SV.starty)/(SV.numptsy-1))
		RampMultipleBD(SV.instrID, SV.channelsy, setpointy, ramprate=SV.rampratey, ignore_lims=1)
		RampMultipleBD(SV.instrID, SV.channelsx, setpointx, ramprate=SV.rampratex, ignore_lims=1)
		sc_sleep(SV.delayy)
		j=0
		do
			setpointx = SV.startx + (j*(SV.finx-SV.startx)/(SV.numptsx-1))
			RampMultipleBD(SV.instrID, SV.channelsx, setpointx, ramprate=SV.rampratex)
			sc_sleep(SV.delayx)
			RecordValues(i, j)
			j+=1
		while (j<SV.numptsx)
	i+=1
	while (i<SV.numptsy)
	
	// Save by default
	if (nosave == 0)
		 SaveWaves(msg=comments)
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
	
	// Set sc_ScanVars struct
	struct BD_ScanVars SV
	SF_init_BDscanVars(SV, instrID, startx=startx, finx=finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
	                      numptsy=numptsy, delayy=delayy)

	// Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
	SFbd_pre_checks(SV)  
	
	// Ramp to start without checks because checked above
	SFbd_ramp_start(SV, ignore_lims=1)
	
	// Let gates settle 
	sc_sleep(SV.delayy)
	
	// Get labels for waves
   string x_label, y_label
   x_label = GetLabel(SV.channelsx)
	y_label = "Sweep Num"

	// Intialize waves
	InitializeWaves(SV.startx, SV.finx, SV.numptsx, starty=1, finy=SV.numptsy, numptsy=SV.numptsy, x_label=x_label, y_label=y_label)

   // Main measurement loop
   variable i=0, j=0, setpointx, setpointy, scandirection=0
	do
		if(mod(i-1,2)!=0 && alternate == 1)  // If on odd row and alternate is on
			j=numptsx-1
			scandirection=-1
		else
			j=0
			scandirection=1
		endif

		setpointx = SV.startx + (j*(SV.finx-SV.startx)/(SV.numptsx-1)) // reset start point
		RampMultipleBD(SV.instrID, SV.channelsx, setpointx, ramprate=SV.rampratex, ignore_lims=1)
		sc_sleep(delayy) // wait at start point
		do
			setpointx = SV.startx + (j*(SV.finx-SV.startx)/(SV.numptsx-1))
			RampMultipleBD(SV.instrID, SV.channelsx, setpointx, ramprate=SV.rampratex, ignore_lims=1)
			sc_sleep(SV.delayx)
			RecordValues(i, j)
			j+=scandirection
		while (j>-1 && j<SV.numptsx)
		i+=1
	while (i<SV.numptsy)
   
   // Save by default
   if (nosave == 0)
       SaveWaves(msg=comments)
   else
       dowindow /k SweepControl
   endif
end



function ScanBabyDACUntil(instrID, start, fin, channels, numpts, delay, ramprate, checkwave, value, [operator, comments, scansave]) //Units: mV
  // sweep one or more babyDAC channels until checkwave < (or >) value
  // channels should be a comma-separated string ex: "0, 4, 5"
  // operator is "<" or ">", meaning end on "checkwave[i] < value" or "checkwave[i] > value"
  variable instrID, start, fin, numpts, delay, ramprate, value, scansave
  string channels, operator, checkwave, comments
  string x_label
  variable i=0, j=0, setpoint

  if(paramisdefault(comments))
    comments=""
  endif

  if(paramisdefault(operator))
    operator = "<"
  endif

  if(paramisdefault(scansave))
    scansave=1
  endif

  variable a = 0
  if ( stringmatch(operator, "<")==1 )
    a = 1
  elseif ( stringmatch(operator, ">")==1 )
    a = -1
  else
    abort "Choose a valid operator (<, >)"
  endif

  x_label = GetLabel(channels)

  // set starting values
  setpoint = start
  RampMultipleBD(instrID, channels, setpoint, ramprate=ramprate)

  InitializeWaves(start, fin, numpts, x_label=x_label)
  sc_sleep(1.0)

  wave w = $checkwave
  wave resist
  do
    setpoint = start + (i*(fin-start)/(numpts-1))
    RampMultipleBD(instrID, channels, setpoint, ramprate=ramprate)
    sc_sleep(delay)
    RecordValues(i, 0)
    if (a*(w[i] - value) < 0 )
			break
    endif
    i+=1
  while (i<numpts)

  if(scansave==1)
    SaveWaves(msg=comments)
  endif
end


function ScanBabyDAC_SRS(babydacID, srsID, startx, finx, channelsx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, [comments, nosave]) //Units: mV, mV
	// Example of how to make new babyDAC scan stepping a different instrument (here SRS)
	variable babydacID, srsID, startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, nosave
	string channelsx, comments
	
   // Reconnect instruments
   sc_openinstrconnections(0)
   
   // Set defaults
   comments = selectstring(paramisdefault(comments), comments, "")
   
   // Set sc_ScanVars struct
   struct BD_ScanVars SV
   SF_init_BDscanVars(SV, BabydacID, startx=startx, finx=finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
                                numptsy=numptsy, delayy=delayy)
   
   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
   SFbd_pre_checks(SV)  
   
   // Ramp to start without checks because checked above
   SFbd_ramp_start(SV, ignore_lims=1)
   SetSRSAmplitude(srsID, starty)
   
   // Let gates settle 
   sc_sleep(SV.delayy)
   
   // Get labels for waves
   string x_label, y_label
   x_label = GetLabel(SV.channelsx)
   sprintf y_label, "SRS%d (mV)", getAddressGPIB(srsID)
	
	// initialize waves
	InitializeWaves(SV.startx, SV.finx, SV.numptsx, starty=starty, finy=finy, numptsy=SV.numptsy, x_label=x_label, y_label=y_label)

	// main loop
   variable i=0, j=0, setpointx, setpointy
   do
		setpointx = SV.startx
		setpointy = starty + (i*(finy-starty)/(SV.numptsy-1))
		RampMultipleBD(SV.instrID, SV.channelsx, setpointx, ramprate=SV.rampratex, ignore_lims=1)
		SetSRSAmplitude(srsID,setpointy)
		sc_sleep(SV.delayy)
		j=0
		do
			setpointx = SV.startx + (j*(SV.finx-SV.startx)/(SV.numptsx-1))
			RampMultipleBD(SV.instrID, SV.channelsx, setpointx, ramprate=SV.rampratex, ignore_lims=1)
			sc_sleep(SV.delayx)
			RecordValues(i, j)
			j+=1
		while (j<SV.numptsx)
		i+=1
	while (i<SV.numptsy)
   
   // Save by default
	if (nosave == 0)
		 SaveWaves(msg=comments)
	else
		 dowindow /k SweepControl
	endif
end

function ScanFastDAC(instrID, start, fin, channels, [numpts, sweeprate, ramprate, delay, y_label, comments, RCcutoff, numAverage, notch, use_AWG, nosave]) //Units: mV
	// sweep one or more FastDac channels from start to fin using either numpnts or sweeprate /mV/s
	// Note: ramprate is for ramping to beginning of scan ONLY
	// Note: Delay is the wait after rampoint to start position ONLY
	// channels should be a comma-separated string ex: "0,4,5"
	// use_AWG is option to use Arbitrary Wave Generator. AWG 
	variable instrID, start, fin, numpts, sweeprate, ramprate, delay, RCcutoff, numAverage, nosave, use_AWG
	string channels, comments, notch, y_label

   // Reconnect instruments
   sc_openinstrconnections(0)

   // Set defaults
   nvar fd_ramprate
   ramprate = paramisdefault(ramprate) ? fd_ramprate : ramprate
   delay = ParamIsDefault(delay) ? 0.5 : delay
   notch = selectstring(paramisdefault(notch), notch, "")
   comments = selectstring(paramisdefault(comments), comments, "")

   // Set sc_ScanVars struct
   struct FD_ScanVars SV
   SF_init_FDscanVars(SV, instrID, start, fin, channels, numpts, ramprate, delayy=delay, sweeprate=sweeprate)  // Note: Stored as SV.startx etc
	
   // Set ProcessList struct
   struct fdRV_ProcessList PL
   SFfd_init_ProcessList(PL, RCcutoff, numAverage, notch)  // Puts values into PL.<name>

   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
   SFfd_pre_checks(SV)  
   
   // If using AWG then get that now and check it
	if(use_AWG)
		struct fdAWG_List AWG
		fdAWG_get_global_AWG_list(AWG)
		AWG.numSteps = round(SV.numptsx/(AWG.waveLen*AWG.numCycles))  
		SV.numptsx = (AWG.numSteps*AWG.waveLen*AWG.numCycles)
		SFawg_check_AWG_list(AWG, SV)	// Check AWG for clashes/exceeding lims etc
	endif

   // Ramp to start without checks since checked above
   SFfd_ramp_start(SV, ignore_lims = 1)

	// Let gates settle 
	sc_sleep(SV.delayy)

	// Get labels for waves
   string x_label
	x_label = GetLabel(SV.channelsx, fastdac=1)
   y_label = selectstring(paramisdefault(y_label), y_label, "")

	// Make waves
	InitializeWaves(SV.startx, SV.finx, SV.numptsx, x_label=x_label, y_label=y_label, fastdac=1)

	// Do 1D scan (rownum set to 0)
	if(!use_AWG) // If not then use normal scan
		fd_Record_Values(SV, PL, 0)
	else			// Otherwise use AWG
		fd_Record_Values(SV, PL, 0, AWG_list=AWG)
	endif

	// Save by default
	if (nosave == 0)
  		SaveWaves(msg=comments, fastdac=1)
  	else
  		dowindow /k SweepControl
	endif
end


function ScanFastDAC2D(fdID, startx, finx, channelsx, starty, finy, channelsy, numptsy, [numpts, sweeprate, bdID, rampratex, rampratey, delayy, comments, RCcutoff, numAverage, notch, nosave, use_AWG])
	// 2D Scan for FastDAC only OR FastDAC on fast axis and BabyDAC on slow axis
	// Note: Must provide numptsx OR sweeprate in optional parameters instead
	// Note: To ramp with babyDAC on slow axis provide the BabyDAC variable in bdID
	// Note: channels should be a comma-separated string ex: "0,4,5"
	variable fdID, startx, finx, starty, finy, numptsy, numpts, sweeprate, bdID, rampratex, rampratey, delayy, RCcutoff, numAverage, nosave, use_AWG
	string channelsx, channelsy, comments, notch
	variable i=0, j=0

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Set defaults
	nvar fd_ramprate
	rampratex = paramisdefault(rampratex) ? fd_ramprate : rampratex
	rampratey = ParamIsDefault(rampratey) ? fd_ramprate : rampratey
	delayy = ParamIsDefault(delayy) ? 0.5 : delayy
	notch = selectstring(paramisdefault(notch), notch, "")
   comments = selectstring(paramisdefault(comments), comments, "")
   
   variable use_bd = paramisdefault(bdid) ? 0 : 1 		// Whether using both FD and BD or just FD
   
   
   // Set sc_scanVars struct
 	struct FD_ScanVars Fsv
 	if(use_bd == 0)  	// if not using BabyDAC then fully init FDscanVars
	   SF_init_FDscanVars(Fsv, fdID, startx, finx, channelsx, numpts, rampratex, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
	   						 starty=starty, finy=finy, channelsy=channelsy, rampratey=rampratey)
	else  				// Using BabyDAC for Y axis so init x in FD_ScanVars, and init y in BD_ScanVars
	   SF_init_FDscanVars(Fsv, fdID, startx, finx, channelsx, numpts, rampratex, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy)
		struct BD_ScanVars Bsv
		SF_init_BDscanVars(Bsv, bdID, starty=starty, finy=finy, channelsy=channelsy, rampratey=rampratey)
	endif
   
   // Set ProcessList Struct
   struct fdRV_ProcessList PL
   SFfd_init_ProcessList(PL, RCcutoff, numAverage, notch)
   
   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
   SFfd_pre_checks(Fsv)  
   if(use_bd == 1)
   		SFbd_pre_checks(Bsv)
   	endif
   	
   	// If using AWG then get that now and check it
	if(use_AWG)
		struct fdAWG_List AWG
		fdAWG_get_global_AWG_list(AWG)
		AWG.numSteps = Fsv.numptsx/AWG.waveLen  // TODO: Check this is correct
		SFawg_check_AWG_list(AWG, Fsv)	// Check AWG for clashes/exceeding lims etc
	endif
   
   // Ramp to start without checks
   SFfd_ramp_start(Fsv, ignore_lims=1)
   if(use_bd == 1)
   		SFbd_ramp_start(Bsv, ignore_lims=1)
   	endif
   	
   	// Let gates settle
	sc_sleep(Fsv.delayy)

	// Get Labels for waves
	string x_label, y_label
	x_label = GetLabel(Fsv.channelsx, fastdac=1)
	if (use_bd == 0) // If using FastDAC on slow axis
		y_label = GetLabel(Fsv.channelsy, fastdac=1)
	else // If using BabyDAC on slow axislabels
		y_label = GetLabel(Bsv.channelsy, fastdac=0)
	endif

	// Make waves												// Note: Using just starty, finy because initwaves doesn't care if it's FD/BD
	InitializeWaves(Fsv.startx, Fsv.finx, Fsv.numptsx, starty=starty, finy=finy, numptsy=Fsv.numptsy, x_label=x_label, y_label=y_label, fastdac=1)

	// Main measurement loop
	variable setpointy
	for(i=0; i<Fsv.numptsy; i++)
		// Ramp slow axis
		setpointy = starty + (i*(finy-starty)/(Fsv.numptsy-1))	// Note: Again, setpointy is independent of FD/BD
		if (use_bd == 0) // If using FastDAC on slow axis
			RampMultipleFDac(Fsv.instrID, Fsv.channelsy, setpointy, ramprate=Fsv.rampratey, ignore_lims=1)
		else // If using BabyDAC on slow axislabels
			RampMultipleBD(Bsv.instrID, Bsv.channelsy, setpointy, ramprate=Bsv.rampratey, ignore_lims=1)
		endif
		// Ramp to start of fast axis
		SFfd_ramp_start(Fsv, ignore_lims=1, x_only=1)
		sc_sleep(Fsv.delayy)
		// Record fast axis
		if(!use_AWG)  	//if not, do normal ramp
			fd_Record_Values(Fsv, PL, i)
		else				// use AWG
			fd_Record_Values(Fsv, PL, i, AWG_list = AWG)
		endif
		
	endfor

	// Save by default
	if (nosave == 0)
  		SaveWaves(msg=comments, fastdac=1)
  	else
  		dowindow /k SweepControl
	endif
end


function ScanfastDACRepeat(instrID, start, fin, channels, numptsy, [numptsx, sweeprate, delay, ramprate, alternate, comments, RCcutoff, numAverage, notch, nosave])
	// 1D repeat scan for FastDAC
	// Note: to alternate scan direction set alternate=1
	// Note: Ramprate is only for ramping gates between scans
	variable instrID, start, fin, numptsy, numptsx, sweeprate, delay, ramprate, alternate, RCcutoff, numAverage, nosave
	string channels, comments, notch
	variable i=0, j=0

	// Reconnect instruments
	sc_openinstrconnections(0)

   // Set defaults
   nvar fd_ramprate
   ramprate = paramisdefault(ramprate) ? fd_ramprate : ramprate
   delay = ParamIsDefault(delay) ? 0.5 : delay
   notch = selectstring(paramisdefault(notch), notch, "")
   comments = selectstring(paramisdefault(comments), comments, "")

   // Set sc_ScanVars struct
   struct FD_ScanVars SV
   SF_init_FDscanVars(SV, instrID, start, fin, channels, numptsx, ramprate, delayy=delay, sweeprate=sweeprate,  \
                     numptsy=numptsy, direction=1)

   // Set ProcessList struct
   struct fdRV_ProcessList PL
   SFfd_init_ProcessList(PL, RCcutoff, numAverage, notch)  // Puts values into PL.<name>

   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
   SFfd_pre_checks(SV)  

   // Ramp to start without checks since checked above
   SFfd_ramp_start(SV, ignore_lims = 1)

	// Let gates settle
	sc_sleep(SV.delayy)

	// Get labels for waves
	string x_label, y_label
	x_label = GetLabel(SV.channelsx, fastdac=1)
	y_label = "Repeats"

	// Make waves
	InitializeWaves(SV.startx, SV.finx, SV.numptsx, x_label=x_label, y_label=y_label, starty=1, finy=SV.numptsy, numptsy=SV.numptsy, fastdac=1)

	// Main measurement loop
	variable d=1
	for (j=0; j<numptsy; j++)
      SV.direction = d  // Will determine direction of scan in fd_Record_Values
		// Ramp to start of fast axis
		SFfd_ramp_start(SV, ignore_lims=1, x_only=1)
		sc_sleep(SV.delayy)
		// Record values for 1D sweep
		fd_Record_Values(SV,PL,j)
		if (alternate!=0) // If want to alternate scan scandirection for next row
			d = d*-1
		endif
	endfor
   
	// Save by default
	if (nosave == 0)
  		SaveWaves(msg=comments, fastdac=1)
  	else
  		dowindow /k SweepControl
	endif
end




//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////// Macros //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function AAMacros()
end

function Scan3DTemplate()
	//Template loop for varying up to three parameters around any scan
	// nvar fastdac, bd6
	string buffer
	variable i, j, k
	make/o/free Var1 = {0}
	make/o/free Var2 = {0}
	make/o/free Var3 = {0}

	i=0; j=0; k=0
	do // Loop to change k var3
		//RAMP VAR 3
		do	// Loop for change j var2
			//RAMP VAR 2
			do // Loop for changing i var1 and running scan
				// RAMP VAR 1
				sprintf buffer, "Starting scan at Var1 = %.1fmV, Var2 = %.1fmV, Var3 = %.1fmV\r", Var1[i], Var2[j], Var3[k]
				//SCAN HERE
				i+=1
			while (i < numpnts(Var1))
			i=0
			j+=1
		while (j < numpnts(Var2))
		j=0
		k+=1
	while (k< numpnts(Var3))
	print "Finished all scans"
end


function StepTempScanSomething()
	// nvar bd6, srs1
	svar ls370

	make/o targettemps =  {300, 275, 250, 225, 200, 175, 150, 125, 100, 75, 50, 40, 30, 20}
	make/o heaterranges = {10, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 1, 1, 1, 1}
	setLS370exclusivereader(ls370,"bfsmall_mc")

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
//	turnoffLS370MCheater(ls370)
	resetLS370exclusivereader(ls370)
	sc_sleep(60.0*30)

	// 	SCAN HERE for base temp
end





/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// SCAN FUNCTIONS //////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

// Section for functions that are for setting up Scans

// SF = ScanFunction
// SFfd = ScanFunction fastDac specific
// SFbd = ScanFunction babyDac specific

function SFfd_set_numpts_sweeprate(SV)
   struct FD_ScanVars &SV
   
   // If NaN then set to zero so rest of logic works
   if(numtype(SV.sweeprate) == 2)
   		SV.sweeprate = 0
   	endif
   
   // Chose which input to use for numpts of scan
   if (SV.numptsx == 0 && SV.sweeprate == 0)
      abort "ERROR[ScanFastDac]: User must provide either numpts OR sweeprate for scan [neither provided]"
   elseif (SV.numptsx!=0 && SV.sweeprate!=0)
      abort "ERROR[ScanFastDac]: User must provide either numpts OR sweeprate for scan [both provided]"
   elseif (SV.numptsx!=0) // If numpts provided, just use that
      SV.sweeprate = fd_get_sweeprate_from_numpts(SV.instrID, SV.startx, SV.finx, SV.numptsx)
   elseif (SV.sweeprate!=0) // If sweeprate provided calculate numpts required
      SV.numptsx = fd_get_numpts_from_sweeprate(SV.instrID, SV.startx, SV.finx, SV.sweeprate)
   endif
end

function SFfd_init_ProcessList(PL, RCcutoff, numAverage, notch)
   struct fdRV_ProcessList &PL
   variable RCcutoff, numAverage
   string notch
	
	PL.coefList = ""
   PL.RCCutoff = RCCutoff
   PL.numAverage = numAverage
   PL.notch_list = notch
end


function/s SFfd_get_adcs()	
	wave fadcattr
	wave/t fadcvalstr
	variable adcCh=0
	string  adcList = ""
	variable i = 0
	for(i=0;i<dimsize(fadcattr,0);i+=1)
		if(fadcattr[i][2] == 48)
			adcCh = str2num(fadcvalstr[i][0])
			adcList = addlistitem(num2istr(adcCh),adcList,",",itemsinlist(adcList,","))	
		endif
	endfor
	return adcList
end
	

function SFfd_pre_checks(S)
   struct FD_ScanVars &S
	SFfd_check_same_device(S) // Checks DACs and ADCs are on same device
	SFfd_check_ramprates(S)	// Check ramprates of x and y
	SFfd_check_lims(S)			// Check within software lims for x and y
	S.lims_checked = 1  		// So record_values knows that limits have been checked!
end


function SFfd_ramp_start(S, [ignore_lims, x_only])
	// move DAC channels to starting point
	struct FD_ScanVars &S
	variable ignore_lims, x_only

	variable i, setpoint
	// If x exists ramp them to start
	if(numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0)  // If not NaN and not ""
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
   struct FD_ScanVars &S
   S.samplingFreq = getfadcSpeed(S.instrID)
   S.numADCs = getNumFADC()
   S.measureFreq = S.samplingFreq/S.numADCs  //Because sampling is split between number of ADCs being read //TODO: This needs to be adapted for multiple FastDacs
end

function SFfd_check_ramprates(S)
  // check if effective ramprate is higher than software limits
  struct FD_ScanVars &S

  wave/T fdacvalstr
  svar activegraphs

	variable kill_graphs = 0
	// Check x's won't be swept to fast by calculated sweeprate for each channel in x ramp
	// Should work for different start/fin values for x
	variable eff_ramprate, answer, i, k, channel
	string question

	if(numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0)  // if s.Channelsx != (NaN or "")
		for(i=0;i<itemsinlist(S.channelsx,",");i+=1)
			eff_ramprate = abs(str2num(stringfromlist(i,S.startxs,","))-str2num(stringfromlist(i,S.finxs,",")))*(S.measureFreq/S.numptsx)
			channel = str2num(stringfromlist(i, S.channelsx, ","))
			if(eff_ramprate > str2num(fdacvalstr[channel][4])*1.05)  // Allow 5% too high for convenience
				// we are going too fast
				sprintf question, "DAC channel %d will be ramped at %.1f mV/s, software limit is set to %s mV/s. Continue?", channel, eff_ramprate, fdacvalstr[channel][4]
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
	struct FD_ScanVars &S

	wave/T fdacvalstr
	svar activegraphs
	variable answer, i, k
	
	// Make single list out of X's and Y's (checking if each exists first)
	string channels = "", starts = "", fins = ""
	if(numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0)  // If not NaN and not ""
		channels = addlistitem(S.channelsx, channels, ",")
		starts = addlistitem(S.startxs, starts, ",")
		fins = addlistitem(S.startxs, fins, ",")
	endif
	if(numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0)  // If not NaN and not ""
		channels = addlistitem(S.channelsy, channels, ",")
		starts = addlistitem(S.startys, starts, ",")
		fins = addlistitem(S.startys, fins, ",")
	endif

	// Check that start/fin for each channel will stay within software limits
	string softLimitPositive = "", softLimitNegative = "", expr = "(-?[[:digit:]]+),([[:digit:]]+)", question
	variable startval = 0, finval = 0
	for(i=0;i<itemsinlist(channels,",");i+=1)
		splitstring/e=(expr) fdacvalstr[str2num(stringfromlist(i,channels,","))][2], softLimitNegative, softLimitPositive
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
	struct FD_ScanVars &s
	wave fadcattr
	wave/t fadcvalstr
	svar fdacKeys
	
	// check that all DAC channels are on the same device
	variable numRampCh = itemsinlist(S.channelsx,","),i=0,j=0,dev_dac=0,dacCh=0,startCh=0
	variable numDevices = str2num(stringbykey("numDevices",fdacKeys,":",",")),numDACCh=0
	for(i=0;i<numRampCh;i+=1)
		dacCh = str2num(stringfromlist(i,S.channelsx,","))
		startCh = 0
		for(j=0;j<numDevices;j+=1)
			numDACCh = str2num(stringbykey("numDACCh"+num2istr(j+1),fdacKeys,":",","))
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
			numADCCh = str2num(stringbykey("numADCCh"+num2istr(j+1),fdacKeys,":",","))
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
		starts = addlistitem(num2str(start), starts, ",")
		fins = addlistitem(num2str(fin), fins, ",")
	endfor
	starts = starts[0,strlen(starts)-2] // Remove comma at end
	fins = fins[0,strlen(fins)-2]	 		// Remove comma at end
end


function SFbd_pre_checks(S)
   struct BD_ScanVars &S
//	SFbd_check_ramprates(S)	// Check ramprates of x and y
	SFbd_check_lims(S)			// Check within software lims for x and y
	S.lims_checked = 1  		// So record_values knows that limits have been checked!
end


function SFbd_check_lims(S)
	// check that start and end values are within software limits
   struct BD_ScanVars &S
	
	// Make single list out of X's and Y's (checking if each exists first)
	string channels = "", outputs = ""
	if(numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0)  // If not NaN and not ""
		channels = addlistitem(S.channelsx, channels, ",")
		outputs = addlistitem(num2str(S.startx), outputs, ",")
		outputs = addlistitem(num2str(S.finx), outputs, ",")
	endif
	if(numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0)  // If not NaN and not ""
		channels = addlistitem(S.channelsy, channels, ",")
		outputs = addlistitem(num2str(S.starty), outputs, ",")
		outputs = addlistitem(num2str(S.finy), outputs, ",")
	endif
	

	wave/T dacvalstr
	svar activegraphs
	wave bd_range_span, bd_range_high, bd_range_low

	variable board_index, sw_limit
	variable answer, i, j, channel, output, kill_graphs = 0
	string abort_msg = "", question
	for(i=0;i<itemsinlist(channels, ",");i++)
		channel = str2num(stringfromlist(i, channels, ","))
		for(j=0;j<2;j++)  // Start/Fin for each channel
			output = str2num(stringfromlist(2*i+j, outputs, ","))
			// Check that the DAC board is initialized
			bdGetBoard(channel)
			board_index = floor(channel/4)
		
			// check for NAN and INF
			if(sc_check_naninf(output) != 0)
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
		endfor
		if(kill_graphs == 1)  // Don't bother checking the rest
			break
		endif
	endfor

	if(kill_graphs == 1)
		variable k
		dowindow/k SweepControl // kill scan control window
		for(k=0;k<itemsinlist(activegraphs,";");k+=1)
			dowindow/k $stringfromlist(k,activegraphs,";")
		endfor		
		abort abort_msg
	endif
end


function SFbd_check_RRs(SV)
   struct BD_ScanVars &SV
   // TODO: Make these for BabyDACs
   abort "Not implemented"
end


function SFbd_ramp_start(S, [ignore_lims])
	// move DAC channels to starting point
	struct BD_ScanVars &S
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
	struct FD_ScanVars &Fsv
	
	string AWdacs  // Used for storing all DACS for 1 channel  e.g. "123" = Dacs 1,2,3
	string err_msg
	variable i=0, j=0
		
	// Check initialized
	if(AWG.initialized == 0)
		abort "ERROR[SFawg_check_AWG_list]: AWG_List needs to be initialized. Maybe something changed since last use!"
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
		string wn = fdAWG_get_AWG_wave(str2num(AWG.AW_Waves[i]))  // Get IGOR wave of AW#
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
	

///////////////////////////////// SCAN STRUCTS //////////////////////////////////////////////


structure BD_ScanVars
	// Place to store common ScanVariables for scans with BabyDAC
	// Equivalent to FD_ScanVars for the FastDAC
	// Use SF_set_BDscanVars() as a nice way to initialize scanVars.
   variable instrID
   variable lims_checked
   
   variable startx, finx, numptsx, delayx, rampratex
   variable starty, finy, numptsy, delayy, rampratey
   
   variable sweeprate  // Used for Fastdac Scans  // TODO: Remove this
   
   string channelsx
   string channelsy
   
   variable direction		// For storing what direction to scan in (for scanRepeat)
endstructure


// TODO: Change to SF_init_BDscanVars()
function SF_init_BDscanVars(s, instrID, [startx, finx, channelsx, numptsx, rampratex, delayx, starty, finy, channelsy, numptsy, rampratey, delayy, direction])
   // Function to make setting up scanVars struct easier. 
   // Note: This is designed to store 2D variables, so if just using 1D you still have to specify x at the end of each variable
   struct BD_ScanVars &s
   variable instrID
   variable startx, finx, numptsx, delayx, rampratex
   variable starty, finy, numptsy, delayy, rampratey
   string channelsx
   string channelsy
   variable direction

   s.instrID = instrID
   
   // Set X's			// NOTE: All optional because may be used for just slow axis of FastDac scan for example
	s.startx = paramisdefault(startx) ? NaN : startx
	s.finx = paramisdefault(finx) ? NaN : finx
	if (paramisdefault(channelsx))
		s.channelsx = ""
	endif
	s.numptsx = paramisdefault(numptsx) ? NaN : numptsx
	s.rampratex = paramisdefault(rampratex) ? NaN : rampratex
	s.delayx = paramisdefault(delayx) ? NaN : delayx
   
   // Set Y's
   s.starty = paramisdefault(starty) ? NaN : starty
   s.finy = paramisdefault(finy) ? NaN : finy
   if (paramisdefault(channelsy))
		s.channelsy = ""
	endif
	s.numptsy = paramisdefault(numptsy) ? NaN : numptsy
   s.rampratey = paramisdefault(rampratey) ? NaN : rampratey
   s.delayy = paramisdefault(delayy) ? NaN : delayy
   s.direction = paramisdefault(direction) ? 1 : direction
end



// structure to hold DAC and ADC channels to be used in fdac scan.
structure FD_ScanVars
	// Place to store common ScanVariables for scans with FastDAC
	// Equivalent to BD_ScanVars for the BabyDAC
	variable instrID
	
	variable lims_checked  	// This is a flag to make sure that checks on software limits/ramprates/sweeprates have
									// been carried out before executing ramps in record_values

	variable numADCs				// number of ADCs being from (sample rate is split between them)
	variable samplingFreq		// from getFdacSpeed()
	variable measureFreq		// MeasureFreq is sampleFreq/numADCs
	variable sweeprate  		// Sweeprate and numptsx are tied together by measureFreq
									// Note: Does not work for multiple start/end points! 
	variable numptsx				// Linked to sweeprate and measureFreq

	string adcList	 
	
	string channelsx   
	variable startx, finx		// Only here to match BD format and because current use is 1 start/fin value for all DACs.
									// Should use startxs, finxs strings as soon as possible
	string startxs, finxs 		// Use this ASAP because FastDAC supports different start/fin values for each DAC
	variable rampratex
	
	string channelsy
	variable starty, finy  	// OK to use starty, finy for things like rampoutputfdac(...)
	string startys, finys		// Note: Although y channels aren't part of fastdac sweep, store as strings so that check functions work for both x and y 
	variable numptsy, delayy, rampratey	
	
	variable direction		// For storing what direction to scan in (for scanRepeat)
endstructure


function SF_init_FDscanVars(s, instrID, startx, finx, channelsx, numptsx, rampratex, [sweeprate, starty, finy, channelsy, numptsy, rampratey, delayy, direction])
   // Function to make setting up scanVars struct easier. 
   // Note: This is designed to store 2D variables, so if just using 1D you still have to specify x at the end of each variable
   struct FD_ScanVars &s
   variable instrID
   variable startx, finx, numptsx, rampratex
   variable starty, finy, numptsy, delayy, rampratey
   string channelsx
   string channelsy
   variable direction, sweeprate

	string starts = "", fins = ""  // Used for getting string start/fin for x and y

	// Set Variables in Struct
   s.instrID = instrID
   s.channelsx = channelsx
   s.adcList = SFfd_get_adcs()
   
	s.startx = startx
	s.finx = finx	
   s.numptsx = numptsx
   s.rampratex = rampratex
   	
   	// Gets starts/fins in FD string format
   SFfd_format_setpoints(S.startx, S.finx, S.channelsx, starts, fins)  
	s.startxs = starts
	s.finxs = fins
	
   s.sweeprate = paramisdefault(sweeprate) ? NaN : sweeprate
	
	// For repeat scans
   s.direction = paramisdefault(direction) ? 1 : direction
	
	// Optionally set variables for 2D scan
   s.starty = paramisdefault(starty) ? NaN : starty
   s.finy = paramisdefault(finy) ? NaN : finy
   if (!paramisdefault(channelsy))
		s.channelsy = channelsy
		// Gets starts/fins in FD string format
	   SFfd_format_setpoints(S.starty, S.finy, S.channelsy, starts, fins)  
		s.startys = starts
		s.finys = fins
	else
		s.channelsy = ""
	endif
	s.numptsy = paramisdefault(numptsy) ? NaN : numptsy
   s.rampratey = paramisdefault(rampratey) ? NaN : rampratey
   s.delayy = paramisdefault(delayy) ? NaN : delayy

	// Set variables with some calculation
   SFfd_set_numpts_sweeprate(S) 	// Checks that either numpts OR sweeprate was provided, and sets both in SV accordingly
   										// Note: Valid for same start/fin points only (uses S.startx, S.finx NOT S.startxs, S.finxs)
   SFfd_set_measureFreq(S) 		// Sets S.samplingFreq/measureFreq/numADCs	
end