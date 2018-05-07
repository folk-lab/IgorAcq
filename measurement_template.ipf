#pragma rtGlobals=1    // Use modern global access method.

///////////////////////
/////    SETUP    /////
///////////////////////

macro initexp()
    // customize this setup to each individual experiment
    // try write all functions such that initexp() can be run
    //     at any time without losing any setup/configuration info
    
    ///// setup ScanController /////
    
    // define instruments --
    //      this wave should have columns with {instrument name, VISA address, test function}
    //      use test = "" to skip query tests when connecting instruments
	make /o/t connInstr = {{"srs1", "GPIB::1::INSTR",  "*IDN?", ""}, {\
	                        "srs2", "GPIB::2::INSTR",  "*IDN?", ""}, {\
	                        "dmm18","GPIB::18::INSTR", ""     , ""}, {\
	                        "ips2", "ASRL2::INSTR",    "",      "ipsCommSetup(ips2)"}, {\
	                        "bd1",  "ASRL1::INSTR",    "",      "bdCommSetup(bd1)"  }}

	InitScanController(connInstr, srv_push=0) // pass instrument list wave to scan controller
	sc_ColorMap = "VioletOrangeYellow" // change default colormap (default=Grays)

	///// configure instruments /////
	// setup individual instruments here for particular readings
//	initIPS120(ips2)
	setup3478Adcvolts(dmm18, 3, 1)
	initIPS120(ips2)
	InitBabyDACs(bd1, "5,6,1,2", "55,55,50,50")
	
end

function testReadTime(numpts, delay) //Units: s
  variable numpts, delay
  wave /t connInstr

  InitializeWaves(0, numpts, numpts, x_label="index")

  variable i=0, ttotal = 0, tstart = datetime
  do
    sc_sleep(delay)
    RecordValues(i, 0, fillnan=0)
    i+=1
  while (i<numpts)
  ttotal = datetime-tstart
  printf "each RecordValues(...) call takes ~%.1fms \n", ttotal/numpts*1000 - delay*1000

  saveWaves(msg = "readtime tests")
end

////////////////////////////
//// MEAUREMENT SCRIPTS ////
////////////////////////////

threadsafe function read51adc(instrID)
	variable instrID
	return readBDadc(instrID, 1, 5)/10.0
end

threadsafe function read52adc(instrID)
	variable instrID
	return readBDadc(instrID, 2, 5)/10.0
end


threadsafe function read61adc(instrID)
	variable instrID
	return readBDadc(instrID, 1, 6)
end

threadsafe function read62adc(instrID)
	variable instrID
	return readBDadc(instrID, 2, 6)
end

///////////////////////////
//     Read VS Time      //
///////////////////////////

function ReadvsTimeForever(delay) //Units: s
  variable delay
  string comments
  variable  i

  InitializeWaves(0, 1, 1, x_label="time (s)")
  do
    sc_sleep(delay)
    RecordValues(i, 0,readvstime=1)
    i+=1
  while (1==1)
  // no point in SaveWaves since the program will never reach this point
end

function ReadVsTimeOut(delay, timeout, [comments]) // Units: s
  variable delay, timeout
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
  while (datetime-sc_scanstarttime < timeout)
  SaveWaves(msg=comments)
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
    sc_sleep(delay)
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

/////////////////////////////
//         BabyDAC         //
/////////////////////////////

function ScanBabyDAC(instrID, start, fin, channels, numpts, delay, ramprate, [comments]) //Units: mV
  // sweep one or more babyDAC channels
  // channels should be a comma-separated string ex: "0, 4, 5"
  variable instrID, start, fin, numpts, delay, ramprate
  string channels, comments
  string x_label
  variable i=0, j=0, setpoint

  if(paramisdefault(comments))
    comments=""
  endif

  sprintf x_label, "BD %s (mV)", channels

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

  sprintf x_label, "BD %s (mV)", channels

  // set starting values
  setpoint = start
  RampMultipleBD(instrID, channels, setpoint, ramprate=ramprate)

  InitializeWaves(start, fin, numpts, x_label=x_label)
  sc_sleep(1.0)

  wave w = $checkwave
  do
    setpoint = start + (i*(fin-start)/(numpts-1))
    RampMultipleBD(instrID, channels, setpoint, ramprate=ramprate)
    sc_sleep(delay)
    RecordValues(i, 0)
    if( a*(w[i] - value) < 0 )
      break
    endif
    i+=1
  while (i<numpts)

  if(scansave==1)
    SaveWaves(msg=comments)
  endif

end

function ScanBabyDAC2D(instrID, startx, finx, channelsx, numptsx, delayx, rampratex, starty, finy, channelsy, numptsy, delayy, rampratey, [comments]) //Units: mV
  variable instrID, startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, rampratey
  string channelsx, channelsy, comments
  variable i=0, j=0, setpointx, setpointy
  string x_label, y_label

  if(paramisdefault(comments))
    comments=""
  endif

  sprintf x_label, "BD %s (mV)", channelsx
  sprintf y_label, "BD %s (mV)", channelsy

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
    RampMultipleBD(instrID, channelsx, setpointx, ramprate=rampratex)
    RampMultipleBD(instrID, channelsy, setpointy, ramprate=rampratey)
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

function ScanBabyDACRepeat(instrID, startx, finx, channelsx, numptsx, delayx, rampratex, numptsy, delayy, [comments]) //Units: mV, mT
  // x-axis is the dac sweep
  // y-axis is an index
  // this will sweep: start -> fin, fin -> start, start -> fin, ....
  // each sweep (whether up or down) will count as 1 y-index

  variable instrID, startx, finx, numptsx, delayx, rampratex, numptsy, delayy
  string channelsx, comments
  variable i=0, j=0, setpointx, setpointy
  string x_label, y_label

  if(paramisdefault(comments))
    comments=""
  endif

  // setup labels
  sprintf x_label, "BD %s (mV)", channelsx
  y_label = "Sweep Num"

  // intialize waves
  variable starty = 0, finy = numptsy
  InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)

  // set starting values
  setpointx = startx
  RampMultipleBD(instrID, channelsx, setpointx, ramprate=rampratex)
  sc_sleep(2.0)

  do
    if(mod(i,2)==0)
      j=0
    else
      j=numptsx-1
    endif

    setpointx = startx + (j*(finx-startx)/(numptsx-1)) // reset start point
    RampMultipleBD(instrID, channelsx, setpointx, ramprate=rampratex)
    sc_sleep(delayy) // wait at start point
    do
      setpointx = startx + (j*(finx-startx)/(numptsx-1))
      RampMultipleBD(instrID, channelsx, setpointx, ramprate=rampratex)
      sc_sleep(delayx)
      RecordValues(i, j)
    while (j>-1 && j<numptsx)
    i+=1
  while (i<numptsy)
  SaveWaves(msg=comments)
end

function ScanBabyDACRepeatOneWay(instrID, startx, finx, channelsx, numptsx, delayx, rampratex, numptsy, delayy, [comments]) //Units: mV, mT
  // x-axis is the dac sweep
  // y-axis is an index
  // this will sweep: start -> fin, start -> fin, start -> fin, ....
  // each sweep will count as 1 y-index

  variable instrID, startx, finx, numptsx, delayx, rampratex, numptsy, delayy
  string channelsx, comments
  variable i=0, j=0, setpointx, setpointy
  string x_label, y_label

  if(paramisdefault(comments))
    comments=""
  endif

  // setup labels
  sprintf x_label, "BD %s (mV)", channelsx
  y_label = "Sweep Num"

  // set starting values
  setpointx = startx
  RampMultipleBD(instrID, channelsx, setpointx, ramprate=rampratex)
  sc_sleep(2.0)

  // intialize waves
  variable starty = 0, finy = numptsy

  InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)

  do
    j=0
    setpointx = startx + (j*(finx-startx)/(numptsx-1)) // reset start point
    RampMultipleBD(instrID, channelsx, setpointx, ramprate=rampratex)
    sc_sleep(delayy) // wait at start point

    do
      setpointx = startx + (j*(finx-startx)/(numptsx-1))
      RampMultipleBD(instrID, channelsx, setpointx, ramprate=rampratex)
      sc_sleep(delayx)
      RecordValues(i, j)
      j+=1
    while (j>-1 && j<numptsx)
    i+=1
  while (i<numptsy)
  SaveWaves(msg=comments)
end

function cutFunc(valx, valy)
  // this is a dummy function
  // do not remove it
  // it acts as a template for the function you pass to ScanBabyDAC2Dcut
  // your function takes valx, valy
  // returns 1 if a measureent should be made
  // returns 0 to fill that point with NaN
  variable valx, valy
end

function ScanBabyDAC2Dcut(instrID, startx, finx, channelsx, numptsx, delayx, rampratex, starty, finy, channelsy, numptsy, delayy, rampratey, func, [comments]) //Units: mV
  // func should return 1 when a point is to be read
  // func returns 0 when a point is to be skipped and filled with NaN
  variable instrID, startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, rampratey
  string channelsx, channelsy, func, comments
  variable i=0, j=0, setpointx, setpointy
  string x_label, y_label

  FUNCREF cutFunc fcheck = $func

  if(paramisdefault(comments))
    comments=""
  endif

  sprintf x_label, "BD %s (mV)", channelsx
  sprintf y_label, "BD %s (mV)", channelsy

  // set starting values
  setpointx = startx
  setpointy = starty

  // initialize waves
  InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)

  // main loop
  do
    setpointx = startx
    setpointy = starty + (i*(finy-starty)/(numptsy-1))
    RampMultipleBD(instrID, channelsx, setpointx, ramprate=rampratex, update=1)
    RampMultipleBD(instrID, channelsy, setpointy, ramprate=rampratey, update=1)
    sc_sleep(delayy)
    j=0
    do
      setpointx = startx + (j*(finx-startx)/(numptsx-1))
      if (fcheck(setpointx, setpointy) == 0)
        RecordValues(i, j, fillnan=1)
      else
        RampMultipleBD(instrID, channelsx, setpointx, ramprate=rampratex, update=0)
        sc_sleep(delayx)
        RecordValues(i, j)
      endif
      j+=1
    while (j<numptsx)
    i+=1
  while (i<numptsy)
  SaveWaves(msg=comments)
end

function ScanBabyDACMultiRange(instrID, startvalues,finvalues,channels,numpts,delay,ramprate, [comments]) //Units: mV
  // This function will sweep multiple dac channels in seperate defined ranges.
  // startvalues, finvalues and channels must be comma seperated lists.
  string  startvalues, finvalues, channels
  variable instrID, numpts, delay, ramprate
  string comments
  string x_label
  variable i=0, j=0,k=0, setpoint, start, fin, channel

  if(paramisdefault(comments))
    comments=""
  endif

  sprintf x_label, "BD %s (mV)", channels

  // set starting values
  variable nChannels = ItemsInList(channels, ",")
  for(k=0;k<nChannels;k+=1)
    channel = Str2num(StringFromList(k,channels,","))
    start = Str2num(StringFromList(k,startvalues,","))
  endfor
  UpdateMultipleBD(instrID, action="ramp", ramprate=ramprate)

  sc_sleep(1.0)
  start = Str2num(StringFromList(0,startvalues,","))
  fin = Str2num(StringFromList(0,finvalues,","))
  InitializeWaves(start, fin, numpts, x_label=x_label)
  do
  
    for(k=0;k<nChannels;k+=1)
      start = Str2num(StringFromList(k,startvalues,","))
      fin = Str2num(StringFromList(k,finvalues,","))
      channel = Str2num(StringFromList(k,channels,","))
      setpoint = start + (i*(fin-start)/(numpts-1))
    endfor
    UpdateMultipleBD(instrID, action="ramp", ramprate=ramprate)
    
    sc_sleep(delay)
    RecordValues(i, 0)
    i+=1
    
  while (i<numpts)
  
  SaveWaves(msg=comments)
end

/////////////////////////////
//       Keithley 2400     //
/////////////////////////////

function ScanK2400(instrID, start, fin, numpts, delay, ramprate, [compl, comments]) //Units: mV, nA (compliance)
  // sweep K2400 output voltage
  variable instrID, start, fin, numpts, delay, ramprate, compl
  string comments
  string x_label
  variable i=0, j=0, setpoint

  if( ParamIsDefault(compl))
    compl = 20 // nA
  endif

  if(paramisdefault(comments))
    comments=""
  endif

  sprintf x_label, "K2400 (mV)"

  // set starting values
  setK2400compl(instrID, "curr", compl)

  setpoint = start
  RampK2400Voltage(instrID, setpoint/1000, ramprate = ramprate)

  sc_sleep(1.0)
  InitializeWaves(start, fin, numpts, x_label=x_label)
  do
    setpoint = start + (i*(fin-start)/(numpts-1))
    RampK2400Voltage(instrID, setpoint/1000, ramprate = ramprate)
    sc_sleep(delay)
    RecordValues(i, 0)
    i+=1
  while (i<numpts)
  SaveWaves(msg=comments)
end

////////////////////////////
//          IPS           //
////////////////////////////

function ScanIPS(instrID, start, fin, numpts, delay, ramprate, [comments]) //Units: mT
  variable instrID, start, fin, numpts, delay, ramprate
  string comments
  variable i=0

  if(paramisdefault(comments))
    comments=""
  endif

  InitializeWaves(start, fin, numpts, x_label="Field (mT)")

  setIPS120rate(instrID, ramprate) //mT/min
  setIPS120fieldWait(instrID, start)
  sc_sleep(5.0) // wait 5 seconds at start point

  do
    setIPS120fieldWait(instrID, start + (i*(fin-start)/(numpts-1)))
    sc_sleep(delay)
    RecordValues(i, 0)
    i+=1
  while (i<numpts)

  SaveWaves(msg=comments)

end

function ScanBabyDACIPS(ipsID, babyID, startx, finx, channelsx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, rampratey, [comments]) //Units: mV, mT
  // x-axis is the dac sweep
  // y-axis is the field sweep

  variable ipsID, babyID, startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, rampratey
  string channelsx, comments
  variable i=0, j=0, setpointx, setpointy
  string x_label, y_label

  if(paramisdefault(comments))
    comments=""
  endif

  // setup labels
  sprintf x_label, "BD %s (mV)", channelsx
  y_label = "Field (mT)"

  // intialize waves
  InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)

  // set starting values
  setpointx = startx
  setpointy = starty
  setIPS120rate(ipsID, rampratey) //mT/min
  setIPS120fieldWait(ipsID, starty)
  RampMultipleBD(babyID, channelsx, setpointx, ramprate=rampratex)
  sc_sleep(2.0)

  do
    setpointx = startx
    setpointy = starty + (i*(finy-starty)/(numptsy-1))
    
    setIPS120fieldWait(ipsID, setpointy)
    RampMultipleBD(babyID, channelsx, setpointx, ramprate=rampratex)
    sc_sleep(delayy)
    
    j=0
    do
      setpointx = startx + (j*(finx-startx)/(numptsx-1))
      RampMultipleBD(babyID, channelsx, setpointx, ramprate=rampratex)
      sc_sleep(delayx)
      RecordValues(i, j)
      j+=1
    while (j<numptsx)
    i+=1
  while (i<numptsy)
  SaveWaves(msg=comments)
end

function ScanIPSRepeat(instrID, startx, finx, numptsx, delayx, rampratex, numptsy, delayy, [comments]) //Units: mT, mT/min
  // x-axis is the dac sweep
  // y-axis is an index
  // this will sweep: start -> fin, fin -> start, start -> fin, ....
  // each sweep (whether up or down) will count as 1 y-index

  variable instrID, startx, finx, numptsx, delayx, rampratex, numptsy, delayy
  string comments
  variable i=0, j=0, setpointx
  string x_label, y_label

  if(paramisdefault(comments))
    comments=""
  endif

  // setup labels
  sprintf x_label, "Field (mT)"
  y_label = "Sweep Num"

  // intialize waves
  variable starty = 0, finy = numptsy-1
  InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)

  // set starting values
  setIPS120rate(instrID, rampratex) //mT/min
  setIPS120fieldWait(instrID, startx)
  sc_sleep(5.0) // wait 5 seconds at start point

  do
    if(mod(i,2)==0)
      j=0
    else
      j=numptsx-1
    endif

    setpointx = startx + (j*(finx-startx)/(numptsx-1)) // reset start point
    setIPS120fieldWait(instrID, setpointx)
    sc_sleep(delayy) // wait at start point
    do
      // switch directions with if statement?
      setpointx = startx + (j*(finx-startx)/(numptsx-1))
      setIPS120fieldWait(instrID, setpointx)
      sc_sleep(delayx)
      RecordValues(i, j)
    while (j>-1 && j<numptsx)
    i+=1
  while (i<numptsy)
  SaveWaves(msg=comments)
end

////////////////////////////
//     Small Magnet       //
////////////////////////////

//function RampSmallMagnet(setpoint, ramprate, [noupdate])
//  // ramp small magnet to a given value
//  variable setpoint, ramprate, noupdate
//  nvar sm_mag_channel // analog shield channel connected to kepco
//  nvar kepco_cal // A/V
//  nvar sm_mag_cal //A/T
//  variable scaling = (sm_mag_cal)/(kepco_cal) // mV/mT
//  variable corrected_ramp = ramprate*scaling/60.0 // mV/s
//
//  if(paramisdefault(noupdate))
//    noupdate=0
//  endif
//
//  RampOutputAS(sm_mag_channel, setpoint*scaling, ramprate=corrected_ramp, noupdate=noupdate)
//end
//
//
//function ScanSmallMagnet(start, fin, numpts, delay, ramprate, [comments]) //Units: mT, mT/min
//  // sweep small magnet using analog shield and Kepco current source
//  variable start, fin, numpts, delay, ramprate
//  string comments
//  string x_label
//  variable i=0, setpoint
//
//
//  if(paramisdefault(comments))
//    comments=""
//  endif
//
//  sprintf x_label, "mag current (A)"
//
//  // set starting values
//  setpoint = start
//  RampSmallMagnet(setpoint, ramprate, noupdate=0)
//  sc_sleep(1.0)
//  InitializeWaves(start, fin, numpts, x_label=x_label)
//  do
//    setpoint = start + (i*(fin-start)/(numpts-1))
//    RampSmallMagnet(setpoint, ramprate, noupdate=1)
//    sc_sleep(delay)
//    RecordValues(i, 0)
//    i+=1
//  while (i<numpts)
//  SaveWaves(msg=comments)
//end
//
//function ScanSmMagnetRepeat(startx, finx, numptsx, delayx, rampratex, numptsy, delayy, [comments]) //Units: mT, mT/min
//  // x-axis is the dac sweep
//  // y-axis is an index
//  // this will sweep: start -> fin, fin -> start, start -> fin, ....
//  // each sweep (whether up or down) will count as 1 y-index
//
//  variable startx, finx, numptsx, delayx, rampratex, numptsy, delayy
//  string comments
//  variable i=0, j=0, setpointx
//  string x_label, y_label
//
//  if(paramisdefault(comments))
//    comments=""
//  endif
//
//  // setup labels
//  sprintf x_label, "Field (mT)"
//  y_label = "Sweep Num"
//
//  // intialize waves
//  variable starty = 0, finy = numptsy-1
//  InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)
//
//  // set starting values
//  RampSmallMagnet(startx, rampratex, noupdate=0)
//  sc_sleep(5.0) // wait 5 seconds at start point
//
//  do
//    if(mod(i,2)==0)
//      j=0
//    else
//      j=numptsx-1
//    endif
//
//    setpointx = startx + (j*(finx-startx)/(numptsx-1)) // reset start point
//    RampSmallMagnet(setpointx, rampratex, noupdate=1)
//    sc_sleep(delayy) // wait at start point
//    do
//      // switch directions with if statement?
//      setpointx = startx + (j*(finx-startx)/(numptsx-1))
//      RampSmallMagnet(setpointx, rampratex, noupdate=1)
//      sc_sleep(delayx)
//      RecordValues(i, j)
//    while (j>-1 && j<numptsx)
//    i+=1
//  while (i<numptsy)
//  SaveWaves(msg=comments)
//end

//////////////////////////////
///////      SRS      ////////
//////////////////////////////

function ScanSRSAmplitude(instrID, start, fin, numpts, delay, readtime, [comments])
  // take time series data at different SRS amplitudes
  // save each time series
  variable instrID, start, fin, numpts, delay, readtime
  string comments
  variable i=0, setpoint=0

  nvar srs8, srs6

  if(paramisdefault(comments))
    comments=""
  endif

  InitializeWaves(start, fin, numpts, x_label="SRS Output(V)")

  // set starting values
  setpoint = start
  SetSRSAmplitude(instrID, setpoint)
  sc_sleep(30)

  do
    setpoint = start + (i*(fin-start)/(numpts-1))
    SetSRSAmplitude(instrID, setpoint)
    sc_sleep(delay)
    RecordValues(i, 0)
    i+=1
  while (i<numpts)

  SaveWaves(msg=comments)

end

//////////////////////////
/////      Fridge    /////
//////////////////////////