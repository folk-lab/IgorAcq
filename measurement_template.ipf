#pragma rtGlobals=1    // Use modern global access method.

///////////////////////
/////    SETUP    /////
///////////////////////

mmamacro initexp()
    // customize this setup to each individual experiment
    // try write all functions such that initexp() can be run
    //     at any time without losing any setup/configuration info

    ///// setup ScanController /////

    // define instruments* --
    //      this wave should have columns with {instrument name, VISA address, test function}
    //      use test = "" to skip query tests when connecting instruments
    // *the goofy formatting is thanks to Igor's strange line continuation rules
  make /o/t connInstr = {{"srs1",  "GPIB::1::INSTR",  "*IDN?" },{\
                          "srs2",  "GPIB::2::INSTR",  "*IDN?"}, {\
                          "dmm18", "GPIB::18::INSTR", ""     }, {\
                          "ips2",  "ASRL2::INSTR",    "R1"   }}
  InitScanController(connInstr, srv_push=0) // pass instrument list wave to scan controller
                                            // this connects to all Instruments
                                            // and prints their test function output
  sc_ColorMap = "VioletOrangeYellow" // change default colormap (default=Grays)

  ///// configure instruments and GUI(s) /////
  setup3478Adcvolts(dmm18, 3, 0.1)
  initIPS120(ips2)

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

///////////////////////////////
/////    THINGS TO READ   /////
///////////////////////////////

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

// Analog Shield //

function getASch0()
  // get ADC reading from channel 0-1
  return ReadADCsingleAS(0, 96)
end

function getASch2()
  // get ADC reading from channel 2-3
  return ReadADCsingleAS(2, 96)
end

// K2400 //

function getCurrentK2400()
  nvar k240014
  return GetK2400Current(k240014)
end

// HP 34401A //

function getDMMval()
  nvar dmm23
  return ReadDMM(dmm23)
end

// SMALL MAGNET //

function getSmField()
    // get the value of the small field magnet in mT
    nvar pwr_resistor, kepco_cal, sm_mag_offset, sm_mag_cal

    return (-1000.0/0.953)*((ReadADCsingleAS(0, 64)-sm_mag_offset)*0.001*kepco_cal/pwr_resistor)/sm_mag_cal // Amps
end

// FRIDGE //

// this depends on what fridge you are using and is kind of a mess right now
// hopefully switching all temperature measurements over to LakeShores will
// simplify things

//function getMCtemp()
//  return GetTemp("mc")
//end
//
//function get4Ktemp()
//  return GetTemp("4k")
//end
//
//function get50Ktemp()
//  return GetTemp("50k")
//end

////////////////////////////
//// MEAUREMENT SCRIPTS ////
////////////////////////////

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

  sc_sleep(1.0)
  InitializeWaves(start, fin, numpts, x_label=x_label)
  do
    setpoint = start-offsetx + (i*(fin-start)/(numpts-1))
    RampMultipleBD(channels, setpoint, nChannels, ramprate=ramprate)
    sc_sleep(delay)
    RecordValues(i, 0)
    i+=1
  while (i<numpts)
  SaveWaves(msg=comments)
end

function ScanBabyDACUntil(start, fin, channels, numpts, delay, ramprate, checkwave, value, [operator, comments, scansave]) //Units: mV
  // sweep one or more babyDAC channels until checkwave < (or >) value
  // channels should be a comma-separated string ex: "0, 4, 5"
  // operator is "<" or ">", meaning end on "checkwave[i] < value" or "checkwave[i] > value"
  variable start, fin, numpts, delay, ramprate, value, scansave
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
  RampMultipleBD(channels, setpoint, nChannels, ramprate=ramprate)

  InitializeWaves(start, fin, numpts, x_label=x_label)
  sc_sleep(1.0)

  wave w = $checkwave
  do
    setpoint = start + (i*(fin-start)/(numpts-1))
    RampMultipleBD(channels, setpoint, nChannels, ramprate=ramprate)
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
    sc_sleep(delayy)
    j=0
    do
      setpointx = startx - offsetx + (j*(finx-startx)/(numptsx-1))
      RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
      sc_sleep(delayx)
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

  // intialize waves
  variable starty = 0, finy = numptsy, scandirection=0
  InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)

  // set starting values
  setpointx = startx-offsetx
  RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
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
    RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
    sc_sleep(delayy) // wait at start point
    do
      setpointx = startx - offsetx + (j*(finx-startx)/(numptsx-1))
      RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
      sc_sleep(delayx)
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
  sc_sleep(2.0)

  // intialize waves
  variable starty = 0, finy = numptsy, scandirection=0

  InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)

  do
    j=0
    setpointx = startx - offsetx + (j*(finx-startx)/(numptsx-1)) // reset start point
    RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
    sc_sleep(delayy) // wait at start point

    do
      setpointx = startx - offsetx + (j*(finx-startx)/(numptsx-1))
      RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
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

function ScanBabyDAC2Dcut(startx, finx, channelsx, numptsx, delayx, rampratex, starty, finy, channelsy, numptsy, delayy, rampratey, func, [offsetx, comments]) //Units: mV
  // func should return 1 when a point is to be read
  // func returns 0 when a point is to be skipped and filled with NaN
  variable startx, finx, numptsx, delayx, rampratex, starty, finy, numptsy, delayy, rampratey, offsetx
  string channelsx, channelsy, func, comments
  variable i=0, j=0, setpointx, setpointy, nChannelsx, nChannelsy
  string x_label, y_label

  FUNCREF cutFunc fcheck = $func

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

  // initialize waves
  InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)


  // main loop
  do
    setpointx = startx - offsetx
    setpointy = starty + (i*(finy-starty)/(numptsy-1))
    RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex, noupdate=0)
    RampMultipleBD(channelsy, setpointy, nChannelsy, ramprate=rampratey, noupdate=0)
    sc_sleep(delayy)
    j=0
    do
      setpointx = startx - offsetx + (j*(finx-startx)/(numptsx-1))
      if (fcheck(setpointx, setpointy) == 0)
        RecordValues(i, j, fillnan=1)
      else
        RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex, noupdate=1)
        sc_sleep(delayx)
        RecordValues(i, j)
      endif
      j+=1
    while (j<numptsx)
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
      RampOutputBD(channel, setpoint, ramprate=ramprate)
    endfor
    sc_sleep(delay)
    RecordValues(i, 0)
    i+=1
  while (i<numpts)
  SaveWaves(msg=comments)
end

/////////////////////////////
//       Keithley 2400     //
/////////////////////////////

function ScanK2400(device, start, fin, numpts, delay, ramprate, [offsetx, compl, comments]) //Units: mV, nA (compliance)
  // sweep K2400 output voltage
  variable device, start, fin, numpts, delay, ramprate, offsetx, compl
  string comments
  string x_label
  variable i=0, j=0, setpoint

  if( ParamIsDefault(offsetx))
    offsetx=0
  endif

  if( ParamIsDefault(compl))
    compl = 20 // nA
  endif

  if(paramisdefault(comments))
    comments=""
  endif

  sprintf x_label, "K2400 (mV)"

  // set starting values
  SetK2400Compl("curr", compl, device)

  setpoint = start-offsetx
  RampK2400Voltage(setpoint/1000, device, ramprate = ramprate)

  sc_sleep(1.0)
  InitializeWaves(start, fin, numpts, x_label=x_label)
  do
    setpoint = start-offsetx + (i*(fin-start)/(numpts-1))
    RampK2400Voltage(setpoint/1000, device, ramprate = ramprate)
    sc_sleep(delay)
    RecordValues(i, 0)
    i+=1
  while (i<numpts)
  SaveWaves(msg=comments)
end

////////////////////////////
//          IPS           //
////////////////////////////

function ScanIPS(start, fin, numpts, delay, ramprate, [comments]) //Units: mT
  variable start, fin, numpts, delay, ramprate
  string comments
  variable i=0

  if(paramisdefault(comments))
    comments=""
  endif

  InitializeWaves(start, fin, numpts, x_label="Field (mT)")

  SetSweepRate(ramprate) // mT/min
  SetFieldWait(start)
  sc_sleep(5.0) // wait 5 seconds at start point

  do
    SetFieldWait(start + (i*(fin-start)/(numpts-1)))
    sc_sleep(delay)
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

  // intialize waves
  InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)

  // set starting values
  setpointx = startx-offsetx
  setpointy = starty
  SetSweepRate(rampratey)
  SetFieldWait(setpointy)
  RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
  sc_sleep(2.0)

  do
    setpointx = startx - offsetx
    setpointy = starty + (i*(finy-starty)/(numptsy-1))
    SetFieldWait(setpointy)
    RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
    sc_sleep(delayy)
    j=0
    do
      setpointx = startx - offsetx + (j*(finx-startx)/(numptsx-1))
      RampMultipleBD(channelsx, setpointx, nChannelsx, ramprate=rampratex)
      sc_sleep(delayx)
      RecordValues(i, j)
      j+=1
    while (j<numptsx)
    i+=1
  while (i<numptsy)
  SaveWaves(msg=comments)
end

function ScanIPSRepeat(startx, finx, numptsx, delayx, rampratex, numptsy, delayy, [comments]) //Units: mT, mT/min
  // x-axis is the dac sweep
  // y-axis is an index
  // this will sweep: start -> fin, fin -> start, start -> fin, ....
  // each sweep (whether up or down) will count as 1 y-index

  variable startx, finx, numptsx, delayx, rampratex, numptsy, delayy
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
  variable starty = 0, finy = numptsy-1, scandirection=0
  InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)

  // set starting values
  SetSweepRate(rampratex) // mT/min
  SetFieldWait(startx)
  sc_sleep(5.0) // wait 5 seconds at start point

  do
    if(mod(i,2)==0)
      j=0
      scandirection=1
    else
      j=numptsx-1
      scandirection=-1
    endif

    setpointx = startx + (j*(finx-startx)/(numptsx-1)) // reset start point
    SetFieldWait(setpointx)
    sc_sleep(delayy) // wait at start point
    do
      // switch directions with if statement?
      setpointx = startx + (j*(finx-startx)/(numptsx-1))
      SetFieldWait(setpointx)
      sc_sleep(delayx)
      RecordValues(i, j, scandirection=scandirection)
      j+=scandirection
    while (j>-1 && j<numptsx)
    i+=1
  while (i<numptsy)
  SaveWaves(msg=comments)
end

////////////////////////////
//     Small Magnet       //
////////////////////////////

function RampSmallMagnet(setpoint, ramprate, [noupdate])
  // ramp small magnet to a given value
  variable setpoint, ramprate, noupdate
  nvar sm_mag_channel // analog shield channel connected to kepco
  nvar kepco_cal // A/V
  nvar sm_mag_cal //A/T
  variable scaling = (sm_mag_cal)/(kepco_cal) // mV/mT
  variable corrected_ramp = ramprate*scaling/60.0 // mV/s

  if(paramisdefault(noupdate))
    noupdate=0
  endif

  RampOutputAS(sm_mag_channel, setpoint*scaling, ramprate=corrected_ramp, noupdate=noupdate)
end


function ScanSmallMagnet(start, fin, numpts, delay, ramprate, [comments]) //Units: mT, mT/min
  // sweep small magnet using analog shield and Kepco current source
  variable start, fin, numpts, delay, ramprate
  string comments
  string x_label
  variable i=0, setpoint


  if(paramisdefault(comments))
    comments=""
  endif

  sprintf x_label, "mag current (A)"

  // set starting values
  setpoint = start
  RampSmallMagnet(setpoint, ramprate, noupdate=0)
  sc_sleep(1.0)
  InitializeWaves(start, fin, numpts, x_label=x_label)
  do
    setpoint = start + (i*(fin-start)/(numpts-1))
    RampSmallMagnet(setpoint, ramprate, noupdate=1)
    sc_sleep(delay)
    RecordValues(i, 0)
    i+=1
  while (i<numpts)
  SaveWaves(msg=comments)
end

function ScanSmMagnetRepeat(startx, finx, numptsx, delayx, rampratex, numptsy, delayy, [comments]) //Units: mT, mT/min
  // x-axis is the dac sweep
  // y-axis is an index
  // this will sweep: start -> fin, fin -> start, start -> fin, ....
  // each sweep (whether up or down) will count as 1 y-index

  variable startx, finx, numptsx, delayx, rampratex, numptsy, delayy
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
  variable starty = 0, finy = numptsy-1, scandirection=0
  InitializeWaves(startx, finx, numptsx, starty=starty, finy=finy, numptsy=numptsy, x_label=x_label, y_label=y_label)

  // set starting values
  RampSmallMagnet(startx, rampratex, noupdate=0)
  sc_sleep(5.0) // wait 5 seconds at start point

  do
    if(mod(i,2)==0)
      j=0
      scandirection=1
    else
      j=numptsx-1
      scandirection=-1
    endif

    setpointx = startx + (j*(finx-startx)/(numptsx-1)) // reset start point
    RampSmallMagnet(setpointx, rampratex, noupdate=1)
    sc_sleep(delayy) // wait at start point
    do
      // switch directions with if statement?
      setpointx = startx + (j*(finx-startx)/(numptsx-1))
      RampSmallMagnet(setpointx, rampratex, noupdate=1)
      sc_sleep(delayx)
      RecordValues(i, j, scandirection=scandirection)
      j+=scandirection
    while (j>-1 && j<numptsx)
    i+=1
  while (i<numptsy)
  SaveWaves(msg=comments)
end

//////////////////////////////
///////      SRS      ////////
//////////////////////////////

function ScanSRSAmplitude(start, fin, numpts, delay, readtime, [comments])
  // take time series data at different SRS amplitudes
  // save each time series
  variable start, fin, numpts, delay, readtime
  string comments
  variable i=0, setpoint=0

  nvar srs8, srs6

  if(paramisdefault(comments))
    comments=""
  endif

  InitializeWaves(start, fin, numpts, x_label="SRS Output(V)")

  // set starting values
  setpoint = start
  SetSRSAmplitude(srs8, setpoint)
  SetSRSAmplitude(srs6, setpoint)
  sc_sleep(30)

  do
    setpoint = start + (i*(fin-start)/(numpts-1))
    SetSRSAmplitude(srs8, setpoint)
    SetSRSAmplitude(srs6, setpoint)
    sc_sleep(30)
    RecordValues(i, 0, timeavg = readtime, timeavg_delay = delay)
    i+=1
  while (i<numpts)

  SaveWaves(msg=comments)

end

//////////////////////////
/////      Fridge    /////
//////////////////////////

//function WaitTillPlateTempStable(plate, targetTmK, times, delay, err)
//  variable targetTmK, times, delay, err
//  string plate
//  variable passCount, targetT=targetTmK/1000, currentT = 0
//
//  // check for stable temperature
//  print "Target temperature: ", targetT, "K"
//
//  variable j = 0
//  for (passCount=0; passCount<times; )
//    sc_sleep(delay)
//    for (j = 0; j<10; j+=1)
//      currentT += GetTemp(plate)/10
//      sc_sleep(1.0)
//    endfor
//    if (ABS(currentT-targetT) < err*targetT)
//      passCount+=1
//      print "Accepted", passCount, " @ ", GetTemp(plate), "K"
//    else
//      print "Rejected", passCount, " @ ", GetTemp(plate), "K"
//      passCount = 0
//    endif
//    currentT = 0
//  endfor
//end
//
//macro sweep_temp_readvstime()
//  make/o targettemps =  { 800, 700, 600, 500, 400, 350, 300, 250, 200, 180, 160, 140, 120, 100, 80, 60, 40, 20 }
//  make/o heaterranges = { 31.6, 31.6, 31.6, 31.6, 31.6, 31.6, 31.6, 10, 10, 10, 10, 10, 10, 3, 3, 1, 1 }
//
//  variable i=0, j=0
//  string comments
//
//  // set fridge controls
//  StillHeater(10.0)                  // set still heater to 10mW
//  sc_sleep(2.0)
//  SetTempSequence(preset="temp_control")       // set temperature sequence on LS
//  sc_sleep(2.0)
//  SetControlMode(1)               // set control mode to closed loop PID
//  sc_sleep(2.0)
//  SetControlParameters(channel=6)        // set control channel to Mixing Chamber
//  sc_sleep(2.0)
//  SetPIDParameters(10,5,0)
//  sc_sleep(2.0)
//
//  SetSRSAmplitude(srs8, 0.144)          // 0.072V = 0.5nA
//
//  // set temperatures and measure
//  i=0
//  do
//    SetPointTemp(targettemps[i])        // mK
//    sc_sleep(2.0)
//    SetHeaterRange(heaterranges[i])
//    sc_sleep(2.0)
//    WaitTillPlateTempStable("mc", targettemps[i], 6, 30, 0.05)
//    sc_sleep(3*60)
//
//    sprintf comments, "Closed Loop PID=10, 5, 0. MC Heater Range (mA)=  %g mA", GetMCHeaterRange()
//    ReadVsTimeOut(0.3, 240, comments=comments)
//    i+=1
//  while ( i<numpnts(targettemps))
//
//end
//
//function WaitTillMCStable(times, delay, delta)
//  variable times, delay, delta
//  string plate = "mc"
//
//  variable j = 0, passCount = 0, dirCount = 0, lastT = GetTemp(plate), currentT = 0
//  do
//    sc_sleep(delay)
//    for (j = 0; j<10; j+=1)
//      currentT += GetTemp(plate)*1000/10
//      sc_sleep(2.0)
//    endfor
//    if (ABS(currentT-lastT) < delta)
//      passCount+=1
//      if (currentT-lastT < 0)
//        dirCount += -1
//      else
//        dirCount +=1
//      endif
//      print "Accepted", passCount, " @ ", GetTemp(plate)*1000, "mK"
//    else
//      print "Rejected", passCount, " @ ", GetTemp(plate)*1000, "mK"
//      passCount = 0
//      dirCount = 0
//    endif
//    lastT = currentT
//    currentT = 0
//    if (passCount==times && ABS(dirCount)<passCount)
//      print "Accepted: Stable temperature reached."
//      break
//    elseif (passCount==times && ABS(dirCount)>=passCount)
//      print "Rejected: Temperature drifting"
//      passCount = 0
//      dirCount = 0
//    endif
//  while (1 == 1)
//end
//
//function cooling_power_test()
//  make/o targetpowers =  { 50, 40, 30, 20, 10, 8, 6, 4, 2, 1 }
//  make/o heaterranges =  { 1.0, 1.0, 1.0, 1.0, 0.316, 0.316, 0.316, 0.316, 0.316, 0.1}
//
//  string comments = "Heater Powers: "
//
//  variable ii = 0
//  do
//    if (ii < numpnts(targetpowers) - 1)
//      comments+=num2str(targetpowers[ii]) + ", "
//    else
//      comments+=num2str(targetpowers[ii]) + "uW \n"
//    endif
//    ii+=1
//  while ( ii<numpnts(targetpowers))
//
//  print comments
//
//  // intialize waves
//  InitializeWaves(0, numpnts(targetpowers), numpnts(targetpowers), x_label="Power (uW)")
//
//  // set fridge controls
//  StillHeater(5.0)                  // set still heater to 10mW
//  sc_sleep(2.0)
//  SetTempSequence(preset="temp_control")       // set temperature sequence on LS
//  sc_sleep(2.0)
//  SetControlMode(3)               // set control mode to open loop
//  sc_sleep(2.0)
//  SetControlParameters(channel=6)        // set control channel to Mixing Chamber
//  sc_sleep(2.0)
//
//  // set temperatures and measure
//  variable i=0, setpoint = 0, delay = 0.3
//  do
//    setpoint = sqrt(targetpowers[i]/120)
//    printf "MC power set to: %.1f uW with %.3f mA \r", targetpowers[i], setpoint
//    SetHeaterRange(heaterranges[i])
//    sc_sleep(2.0)
//    MCHeater(setpoint)  // mA
//    sc_sleep(2.0)
//    WaitTillMCStable(8, 60, 0.25)
//    sc_sleep(30)
//
//    RecordValues(i, 0, timeavg = 120, timeavg_delay = delay)
//
//    i+=1
//  while ( i<numpnts(targetpowers))
//
//  SaveWaves(msg=comments)
//
//end
//
//function WaitTillCarbonStable(times, delay, delta)
//  variable times, delay, delta
//  string plate = "mc"
//
//  variable j = 0, passCount = 0, dirCount = 0, lastR = ((20e-6)/(getg8x()*1e-7)-1200), currentR = 0
//  do
//    sc_sleep(delay)
//    for (j = 0; j<50; j+=1)
//      currentR +=((20e-6)/(getg8x()*1e-7)-1200)/50
//      sc_sleep(0.3)
//    endfor
//    if (ABS(currentR-lastR) < delta)
//      passCount+=1
//      if (currentR-lastR < 0)
//        dirCount += -1
//      else
//        dirCount +=1
//      endif
//      print "Accepted", passCount, " @ ", ((20e-6)/(getg8x()*1e-7)-1200), "Ohms"
//    else
//      print "Rejected", passCount, " @ ", ((20e-6)/(getg8x()*1e-7)-1200), "Ohms"
//      passCount = 0
//      dirCount = 0
//    endif
//    lastR = currentR
//    currentR = 0
//    if (passCount==times && ABS(dirCount)<passCount)
//      print "Accepted: Stable temperature reached."
//      break
//    elseif (passCount==times && ABS(dirCount)>=passCount)
//      print "Rejected: Temperature drifting"
//      passCount = 0
//      dirCount = 0
//    endif
//  while (1 == 1)
//end
//
//function cooling_power_test_2()
//  make/o targetpowers =  { 50, 40, 30, 20, 10, 8, 6, 4, 2, 1 }
//  variable Rgraphene = 3400
//  nvar k2400
//
//  string comments = "Heater Powers: "
//
//  variable ii = 0
//  do
//    if (ii < numpnts(targetpowers) - 1)
//      comments+=num2str(targetpowers[ii]) + ", "
//    else
//      comments+=num2str(targetpowers[ii]) + "uW \n"
//    endif
//    ii+=1
//  while ( ii<numpnts(targetpowers))
//
//  print comments
//
//  // intialize waves
//  InitializeWaves(0, numpnts(targetpowers)-1, numpnts(targetpowers))
//
//  // set fridge controls
//  StillHeater(5.0)    // set still heater to 10mW
//  sc_sleep(2.0)
//  SetTempSequence(preset="temp_control")   // set temperature sequence on LS
//  sc_sleep(2.0)
//
//  // set temperatures and measure
//  variable i=0, setpoint = 0, delay = 0.3
//  do
//    // set graphene current for approximate power
//    setpoint = sqrt(targetpowers[i]/Rgraphene)*1e6 // setpoint current in nA
//    SetK2400Current(setpoint, k2400)
//    sc_sleep(30)
//
//    // update graphene resistance and tweek bias current
//    Rgraphene = (GetK2400Voltage(k2400)*1e-3)/(setpoint*1e-9) - 1200
//    printf "Current graphene resistance = %.3f Ohms \r", Rgraphene
//    setpoint = sqrt(targetpowers[i]/Rgraphene)*1e6
//    SetK2400Current(setpoint, k2400)
//    printf "graphene power set to: %.1f uW with %.3f uA \r", targetpowers[i], setpoint/1000
//
//    WaitTillCarbonStable(8, 60, 5)
//    sc_sleep(3*60)
//
//    RecordValues(i, 0, timeavg = 120, timeavg_delay = delay)
//
//    i+=1
//  while ( i<numpnts(targetpowers))
//
//  SaveWaves(msg=comments)
//
//end
//
//macro step_temp_scanIPS()
//
////  make/o targettemps =  { 800, 700, 600, 500, 400, 350, 300, 250, 200, 180, 160, 140, 120, 100, 80, 60, 40, 20 }
////  make/o heaterranges = { 31.6, 31.6, 31.6, 31.6, 31.6, 31.6, 31.6, 10, 10, 10, 10, 10, 10, 3, 3, 1, 1 }
//
//  make/o targettemps =  {20, 200, 400, 600, 800}
//  make/o heaterranges = {1, 10, 31.6, 31.6, 31.6}
//
//  variable i=0
//  string comments
//
//  // set fridge controls
//  StillHeater(10.0)    // set still heater to 10mW
//  sc_sleep(2.0)
//  SetTempSequence(preset="temp_control") // set temperature sequence on LS
//  sc_sleep(2.0)
//  SetControlMode(1)  // set control mode to closed loop PID
//  sc_sleep(2.0)
//  SetControlParameters(channel=6) // set control channel to Mixing Chamber
//  sc_sleep(2.0)
//  SetPIDParameters(10,5,0)
//  sc_sleep(2.0)
//
//  // set temperatures and sweep field
//  i=0
//  do
//    SetHeaterRange(heaterranges[i])
//    sc_sleep(2.0)
//    SetPointTemp(targettemps[i]) // mK
//    sc_sleep(2.0)
//    WaitTillPlateTempStable("mc", targettemps[i], 6, 30, 0.05)
//    sc_sleep(3*60.0)
//
//    sprintf comments, "Setpoint: MC Heater Range (mA)=  %g mA", targettemps[i], GetMCHeaterRange()
//    ScanIPSRepeat(1000, -1000, 2001, 0.3, 80, 2, 1.2, comments=comments)
//
//    i+=1
//  while ( i<numpnts(targettemps))
//
//end
