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
	string x_label
	variable i=0, j=0, setpoint

	if(paramisdefault(comments))
	comments=""
	endif

	x_label = GetLabel(channels)

	// set starting values
	setpoint = start
	RampMultipleBD(instrID, channels, setpoint, ramprate=ramprate)

	sc_sleep(1.0)
	InitializeWaves(start, fin, numpts, x_label=x_label)
	do
		setpoint = start + (i*(fin-start)/(numpts-1))
		RampMultipleBD(instrID, channels, setpoint, ramprate=ramprate)
		sc_sleep(delay)
		RecordValues(i, 0)
		i+=1
	while (i<numpts)
	if (nosave == 0)
  		SaveWaves(msg=comments)
  	else
  		dowindow /k SweepControl
	endif
end


function ScanBabyDAC2D(instrID, startx, finx, channelsx, numptsx, delayx, rampratex, starty, finy, channelsy, numptsy, delayy, rampratey, [comments, eta]) //Units: mV
  variable instrID, startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, rampratey, eta
  string channelsx, channelsy, comments
  variable i=0, j=0, setpointx, setpointy
  string x_label, y_label

  if(paramisdefault(comments))
    comments=""
  endif

	if (eta==1)
		Eta = (delayx+0.08)*numptsx*numptsy+delayy*numptsy+numptsy*abs(finx-startx)/(rampratex/3)  //0.06 for time to measure from lockins etc, Ramprate/3 because it is wrong otherwise
		Print "Estimated time for scan = " + num2str(eta/60) + "mins, ETA = " + secs2time(datetime+eta, 0)
	endif
  x_label = GetLabel(channelsx)
  y_label = GetLabel(channelsy)

  // set starting values
  setpointx = startx
  setpointy = starty
  RampMultipleBD(instrID, channelsx, setpointx, ramprate=rampratex)
  RampMultipleBD(instrID, channelsy, setpointy, ramprate=rampratey)

  // initialize waves
  InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)

  // main loop
  do
    setpointx = startx
    setpointy = starty + (i*(finy-starty)/(numptsy-1))
    RampMultipleBD(instrID, channelsy, setpointy, ramprate=rampratey)
    RampMultipleBD(instrID, channelsx, setpointx, ramprate=rampratex)
    sc_sleep(delayy)
    j=0
    do
      setpointx = startx + (j*(finx-startx)/(numptsx-1))
      RampMultipleBD(instrID, channelsx, setpointx, ramprate=rampratex)
      sc_sleep(delayx)
      RecordValues(i, j)
      j+=1
    while (j<numptsx)
    i+=1
  while (i<numptsy)
  SaveWaves(msg=comments)
end


function ScanBabyDACRepeat(instrID, startx, finx, channelsx, numptsx, delayx, rampratex, numptsy, delayy, [offsetx, comments]) //Units: mV, mT
	// x-axis is the dac sweep
	// y-axis is an index
	// this will sweep: start -> fin, fin -> start, start -> fin, ....
	// each sweep (whether up or down) will count as 1 y-index

	variable instrID, startx, finx, numptsx, delayx, rampratex, numptsy, delayy, offsetx
	string channelsx, comments
	variable i=0, j=0, setpointx, setpointy
	string x_label, y_label

	if(paramisdefault(comments))
		comments=""
	endif

	if( ParamIsDefault(offsetx))
		offsetx=0
	endif

	// setup labels
	x_label = GetLabel(channelsx)
	y_label = "Sweep Num"

	// intialize waves
	variable starty = 0, finy = numptsy-1, scandirection=0
	InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)

	// set starting values
	setpointx = startx-offsetx
	RampMultipleBD(instrID, channelsx, setpointx, ramprate=rampratex)
	sc_sleep(2.0)

	do
		if(mod(i,2)==0)
			j=0
			scandirection=1
		else
			j=numptsx-1
			scandirection=-1
		endif

		setpointx = startx - offsetx + (j*(finx-startx)/(numptsx-1)) // reset start point
		RampMultipleBD(instrID, channelsx, setpointx, ramprate=rampratex)
		sc_sleep(delayy) // wait at start point
		do
			setpointx = startx - offsetx + (j*(finx-startx)/(numptsx-1))
			RampMultipleBD(instrID, channelsx, setpointx, ramprate=rampratex)
			sc_sleep(delayx)
			RecordValues(i, j)
			j+=scandirection
		while (j>-1 && j<numptsx)
		i+=1
	while (i<numptsy)
	SaveWaves(msg=comments)
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


function ScanBabyDAC_SRS(babydacID, srsID, startx, finx, channelsx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, [comments]) //Units: mV, mV
	// Example of how to make new babyDAC scan stepping a different instrument (here SRS)
  variable babydacID, srsID, startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy
  string channelsx, comments
  variable i=0, j=0, setpointx, setpointy
  string x_label, y_label

  if(paramisdefault(comments))
    comments=""
  endif

  sprintf x_label, "BD %s (mV)", channelsx
  sprintf y_label, "SRS%d (mV)", getAddressGPIB(srsID)

  // set starting values
  setpointx = startx
  setpointy = starty
  RampMultipleBD(babydacID, channelsx, setpointx, ramprate=rampratex)
  SetSRSAmplitude(srsID,setpointy)

  // initialize waves
  InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)

  // main loop
  do
    setpointx = startx
    setpointy = starty + (i*(finy-starty)/(numptsy-1))
    RampMultipleBD(babydacID, channelsx, setpointx, ramprate=rampratex)
    SetSRSAmplitude(srsID,setpointy)
    sc_sleep(delayy)
    j=0
    do
      setpointx = startx + (j*(finx-startx)/(numptsx-1))
      RampMultipleBD(babydacID, channelsx, setpointx, ramprate=rampratex)
      sc_sleep(delayx)
      RecordValues(i, j)
      j+=1
    while (j<numptsx)
    i+=1
  while (i<numptsy)
  SaveWaves(msg=comments)
end


function ScanFastDAC(instrID, start, fin, channels, [numpts, sweeprate, ramprate, delay, y_label, comments, RCcutoff, numAverage, notch, nosave]) //Units: mV
	// sweep one or more FastDac channels from start to fin using either numpnts or sweeprate /mV/s
	// Note: ramprate is for ramping to beginning of scan ONLY
	// Note: Delay is the wait after rampoint to start position ONLY
	// channels should be a comma-separated string ex: "0,4,5"
	variable instrID, start, fin, numpts, sweeprate, ramprate, delay, RCcutoff, numAverage, nosave
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
   SF_init_FDscanVars(SV, instrID, start, fin, channels, numpts, ramprate, delay, sweeprate=sweeprate)  // Note: Stored as SV.startx etc
	
   // Set ProcessList struct
   struct fdRV_ProcessList PL
   SFfd_init_ProcessList(PL, RCcutoff, numAverage, notch)  // Puts values into FilterOpts.<name>

   // Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
   SFfd_pre_checks(SV)  

   // Ramp to start without checks since checked above
   SFfd_ramp_start(SV, ignore_lims = 1)

	// Let gates settle 
	sc_sleep(SV.delayx)

	// Get labels for waves
   string x_label
	x_label = GetLabel(SV.channelsx, fastdac=1)
   y_label = selectstring(paramisdefault(y_label), y_label, "")

	// Make waves
	InitializeWaves(SV.startx, SV.finx, SV.numptsx, x_label=x_label, y_label=y_label, fastdac=1)

	// Do 1D scan (rownum set to 0)  // TODO: Replace with much more concise version after fixing fdacRecordValues
	fd_Record_Values(SV, PL, 0)

	// Save by default
	if (nosave == 0)
  		SaveWaves(msg=comments, fastdac=1)
  	else
  		dowindow /k SweepControl
	endif
end



function ScanFastDAC2D(fdID, startx, finx, channelsx, starty, finy, channelsy, numptsy, [numpts, sweeprate, bdID, rampratex, rampratey, delayy, comments, RCcutoff, numAverage, notch, nosave])
	// 2D Scan for FastDAC only OR FastDAC on fast axis and BabyDAC on slow axis
	// Note: Must provide numptsx OR sweeprate in optional parameters instead
	// Note: To ramp with babyDAC on slow axis provide the BabyDAC variable in bdID
	// Note: channels should be a comma-separated string ex: "0,4,5"
	variable fdID, startx, finx, starty, finy, numptsy, numpts, sweeprate, bdID, rampratex, rampratey, delayy, RCcutoff, numAverage, nosave
	string channelsx, channelsy, comments, notch
	variable i=0, j=0

	// Chose which input to use for numpts of scan
	if (ParamIsDefault(numpts) && ParamIsDefault(sweeprate))
		abort "ERROR[ScanFastDac]: User must provide either numpts OR sweeprate for scan [neither provided]"
	elseif (!ParamIsDefault(numpts) && !ParamIsDefault(sweeprate))
		abort "ERROR[ScanFastDac]: User must provide either numpts OR sweeprate for scan [both provided]"
	elseif (!ParamIsDefault(numpts)) // If numpts provided, just use that
		numpts = numpts
	elseif (!ParamIsDefault(sweeprate)) // If sweeprate provided calculate numpts required
		numpts = fd_get_numpts_from_sweeprate(fdID, startx, finx, sweeprate)
	endif

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Set defaults
	nvar fd_ramprate
	rampratex = paramisdefault(rampratex) ? fd_ramprate : rampratex
	rampratey = ParamIsDefault(rampratey) ? fd_ramprate : rampratey
	delayy = ParamIsDefault(delayy) ? 0.5 : delayy
	if (paramisdefault(notch))
		notch = ""
	endif
	if (paramisdefault(comments))
		comments = ""
	endif

	// Ramp to startx and format inputs for fdacRecordValues
	string startxs = "", finxs = ""
	RampMultipleFDac(fdID, channelsx, startx)
	SFfd_format_setpoints(startx, finx, channelsx, startxs, finxs)

	if (ParamIsDefault(bdID)) // If using FastDAC on slow axis
		string startys = "", finys = ""
		RampMultipleFDac(fdID, channelsy, starty)
		SFfd_format_setpoints(starty, finy, channelsy, startys, finys)
	elseif (!ParamIsDefault(bdID)) // If using BabyDAC on slow axis
		RampMultipleBD(bdID, channelsy, starty, ramprate=rampratey)
	endif

	// Let gates settle
	sc_sleep(delayy)

	// Get Labels for waves
	string x_label, y_label
	x_label = GetLabel(channelsx, fastdac=1)
	if (ParamIsDefault(bdID)) // If using FastDAC on slow axis
		y_label = GetLabel(channelsy, fastdac=1)
	elseif (!ParamIsDefault(bdID)) // If using BabyDAC on slow axislabels
		y_label = GetLabel(channelsy, fastdac=0)
	endif

	// Make waves
	InitializeWaves(startx, finx, numpts, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label= y_label, fastdac=1)

	// Main measurement loop
	variable setpointy, channely
	for(i=0; i<numptsy; i++)
		// Ramp slow axis
		setpointy = starty + (i*(finy-starty)/(numptsy-1))
		if (ParamIsDefault(bdID)) // If using FastDAC on slow axis
			RampMultipleFDac(fdID, channelsy, setpointy, ramprate=rampratey)
		elseif (!ParamIsDefault(bdID)) // If using BabyDAC on slow axislabels
			RampMultipleBD(bdID, channelsy, setpointy, ramprate=rampratey)
		endif

		// Record fast axis
//		fdacRecordValues(fdID,i,channelsx,startxs,finxs,numpts,delay=delayy,ramprate=rampratex,RCcutoff=RCcutoff,numAverage=numAverage,notch=notch)
	endfor

	// Save by default
	if (nosave == 0)
  		SaveWaves(msg=comments, fastdac=1)
  	else
  		dowindow /k SweepControl
	endif
end


function ScanfastdacRepeat(instrID, start, fin, channels, numptsy, [numptsx, sweeprate, delayy, ramprate, alternate, comments, RCcutoff, numAverage, notch, nosave])
	// 1D repeat scan for FastDAC
	// Note: to alternate scan direction set alternate=1
	// Note: Ramprate is only for ramping gates between scans
	variable instrID, start, fin, numptsy, numptsx, sweeprate, delayy, ramprate, alternate, RCcutoff, numAverage, nosave
	string channels, comments, notch
	variable i=0, j=0

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Chose which input to use for numpts of scan
	if (ParamIsDefault(numptsx) && ParamIsDefault(sweeprate))
		abort "ERROR[ScanFastDac]: User must provide either numpts OR sweeprate for scan [neither provided]"
	elseif (!ParamIsDefault(numptsx) && !ParamIsDefault(sweeprate))
		abort "ERROR[ScanFastDac]: User must provide either numpts OR sweeprate for scan [both provided]"
	elseif (!ParamIsDefault(numptsx)) // If numpts provided, just use that
		numptsx = numptsx
	elseif (!ParamIsDefault(sweeprate)) // If sweeprate provided calculate numpts required
		numptsx = fd_get_numpts_from_sweeprate(instrID, start, fin, sweeprate)
	endif

	// Set defaults
	nvar fd_ramprate
	ramprate = ParamIsDefault(ramprate) ? fd_ramprate : ramprate
	delayy = ParamIsDefault(delayy) ? 0 : delayy
	if (paramisdefault(notch))
		notch = ""
	endif
	if (paramisdefault(comments))
		comments = ""
	endif

	// Ramp to startx and format inputs for fdacRecordValues
	string starts = "", fins = ""
	RampMultipleFDac(instrID, channels, start)
	SFfd_format_setpoints(start, fin, channels, starts, fins)

	// Let gates settle
	sc_sleep(delayy)

	// Get labels for waves
	string x_label, y_label
	x_label = GetLabel(channels, fastdac=1)
	y_label = "Repeats"

	// Make waves
	InitializeWaves(start, fin, numptsx, x_label=x_label, y_label=y_label, starty=1, finy=numptsy, numptsy=numptsy, fastdac=1)

	// Main measurement loop
	variable d=1
	for (j=0; j<numptsy; j++)

		// Record values for 1D sweep
//		fdacRecordValues(instrID,j,channels,starts,fins,numptsx,delay=delayy, ramprate=ramprate,RCcutoff=RCcutoff,numAverage=numAverage,notch=notch, direction=d)
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


function steptempscanSomething()
	// nvar bd6, srs1
	svar ls370

	make/o targettemps =  {300, 275, 250, 225, 200, 175, 150, 125, 100, 75, 50, 40, 30, 20}
	make/o heaterranges = {10, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 3.1, 1, 1, 1, 1}
	setLS370exclusivereader(ls370,"bfsmall_mc")

	variable i=0
	do
		setLS370Temp(ls370,6,targettemps[i],maxcurrent = heaterranges[i])
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

   variable eff_ramprate = 0, answer = 0, i=0
   string question = ""
	SFfd_check_same_device(S) // Checks DACs and ADCs are on same device
	SFfd_check_ramprates(S)	// Check ramprates of x and y
	SFfd_check_lims(S)			// Check within software lims for x and y
	S.lims_checked = 1  		// So record_values knows that limits have been checked!
end


function SFfd_ramp_start(scanVars, [ignore_lims])
  // move DAC channels to starting point
  struct FD_ScanVars &scanVars
  variable ignore_lims

  variable i
  for(i=0;i<itemsinlist(scanVars.channelsx,",");i+=1)
    rampOutputfdac(scanVars.instrID,str2num(stringfromlist(i,scanVars.channelsx,",")),str2num(stringfromlist(i,scanVars.startxs,",")),ramprate=scanVars.rampratex, ignore_lims=ignore_lims)
  endfor
  
  // TODO: Make this ramp Y channels as well if they exist
  
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


function SFbd_check_Lims_RRs(SV)
   struct BD_ScanVars &SV
   SFbd_check_lims(SV)
   SFbd_check_RRs(SV)
end

function SFbd_check_lims(SV)
   struct BD_ScanVars &SV
   // TODO: Make these for BabyDACs
   abort "Not implemented"
end


function SFbd_check_RRs(SV)
   struct BD_ScanVars &SV
   // TODO: Make these for BabyDACs
   abort "Not implemented"
end

///////////////////////////////// SCAN STRUCTS //////////////////////////////////////////////


structure BD_ScanVars
	// Place to store common ScanVariables for scans with BabyDAC
	// Equivalent to FD_ScanVars for the FastDAC
	// Use SF_set_BDscanVars() as a nice way to initialize scanVars.
   variable instrID
   variable startx, finx, numptsx, delayx, rampratex
   variable starty, finy, numptsy, delayy, rampratey
   
   variable sweeprate  // Used for Fastdac Scans  // TODO: Remove this
   
   string channelsx
   string channelsy
   
   variable direction		// For storing what direction to scan in (for scanRepeat)
endstructure


// TODO: Change to SF_init_BDscanVars()
function SF_set_BDscanVars(s, instrID, startx, finx, channelsx, numptsx, rampratex, delayx, [starty, finy, channelsy, numptsy, rampratey, delayy, direction, sweeprate])
   // Function to make setting up scanVars struct easier. 
   // Note: This is designed to store 2D variables, so if just using 1D you still have to specify x at the end of each variable
   struct BD_ScanVars &s
   variable instrID
   variable startx, finx, numptsx, delayx, rampratex
   variable starty, finy, numptsy, delayy, rampratey
   string channelsx
   string channelsy
   variable direction, sweeprate

   s.instrID = instrID
   s.startx = startx
   s.finx = finx
   s.channelsx = channelsx
   s.numptsx = numptsx
   s.rampratex = rampratex
   s.delayx = delayx
   s.starty = paramisdefault(starty) ? NaN : starty
   s.finy = paramisdefault(finy) ? NaN : finy
   if (paramisdefault(channelsy))
		s.channelsy = ""
	endif
	s.numptsy = paramisdefault(numptsy) ? NaN : numptsy
   s.rampratey = paramisdefault(rampratey) ? NaN : rampratey
   s.delayy = paramisdefault(delayy) ? NaN : delayy
   s.direction = paramisdefault(direction) ? 1 : direction
   s.sweeprate = paramisdefault(direction) ? NaN : sweeprate  // TODO: Remove this
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
	variable delayx, rampratex
	
	string channelsy
	variable starty, finy  	// OK to use starty, finy for things like rampoutputfdac(...)
	string startys, finys		// Note: Although y channels aren't part of fastdac sweep, store as strings so that check functions work for both x and y 
	variable numptsy, delayy, rampratey	
	
	variable direction		// For storing what direction to scan in (for scanRepeat)
endstructure


function SF_init_FDscanVars(s, instrID, startx, finx, channelsx, numptsx, rampratex, delayx, [sweeprate, starty, finy, channelsy, numptsy, rampratey, delayy, direction])
   // Function to make setting up scanVars struct easier. 
   // Note: This is designed to store 2D variables, so if just using 1D you still have to specify x at the end of each variable
   struct FD_ScanVars &s
   variable instrID
   variable startx, finx, numptsx, delayx, rampratex
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
   s.delayx = delayx
   	
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
   if (paramisdefault(channelsy))
		s.channelsy = ""
		// Gets starts/fins in FD string format
	   SFfd_format_setpoints(S.starty, S.finy, S.channelsy, starts, fins)  
		s.startys = starts
		s.finys = fins
	endif
	s.numptsy = paramisdefault(numptsy) ? NaN : numptsy
   s.rampratey = paramisdefault(rampratey) ? NaN : rampratey
   s.delayy = paramisdefault(delayy) ? NaN : delayy

	// Set variables with some calculation
   SFfd_set_numpts_sweeprate(S) 	// Checks that either numpts OR sweeprate was provided, and sets both in SV accordingly
   										// Note: Valid for same start/fin points only (uses S.startx, S.finx NOT S.startxs, S.finxs)
   SFfd_set_measureFreq(S) 		// Sets S.samplingFreq/measureFreq/numADCs	
end