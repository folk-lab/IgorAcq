#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// written by Nik -- September 2017
// -- only works with sine and square waves


////////////////////////////////
//// communication utility /////
////////////////////////////////

function writeAWG(dev, cmd)
	variable dev
	string cmd
	
	GPIB2 device = dev
	GPIBWrite2 cmd+"\n"
	if(V_flag==0)
		print "[WARNING] Problem writing AWG command: "+cmd
	endif
end

function /S readAWG(dev)
	variable dev
	string response
	GPIBRead2 /Q/T="\r\n" response
	if(V_flag==0)
		print "[WARNING] No data read from AWG buffer"
	endif
	return response
end

function /S queryAWG(dev, cmd)
	// write then read response over GPIB
	variable dev
	string cmd
	string response = ""
	
	writeAWG(dev, cmd)

	return readAWG(dev)
end

function ReadAWGjunk(dev)
	// for those times when your gpib communitaction got messed up and there's something in the buffer
	variable dev
	variable readval

	variable i
	do
		GPIB2 device = dev
		GPIBRead2 /Q/N=1 readval
		i+=1
	while(v_flag)
	printf "this read %d characters of junk \r", i-1
End

/////////////////
//// get/set ////
/////////////////

function setAWGunits(dev, units)
	// valid units are VPP, VRMS, DBM
	// you probably want VRMS 
	//    if you're used to thinking about lockins
	variable dev
	string units
	
	string cmd=""
	sprintf cmd, "VOLT:UNIT %s", units
	
	writeAWG(dev, cmd)
end

function setAWGwaveshape(dev, shape)
	// valid inputs are SIN, SQU, RAMP, PULS, NOIS, DC, USER
	variable dev
	string shape
	
	string cmd=""
	sprintf cmd, "FUNC %s", shape
	
	writeAWG(dev, cmd)
end

function /S getAWGwaveshape(dev)
	// valid inputs are SIN, SQU, RAMP, PULS, NOIS, DC, USER
	variable dev
	
	return queryAWG(dev, "FUNC?")
end


//function setAWGwaveform(dev, shape, freq, peakmV)
//	// valid shapes SIN, SQU
//	// this is a quick way to do it
//	// i wouldn't use it in a sweep
//	// run this once at the beginning, then sweep the parameter you want
//	
//	// set the shape of the output waveform
//	// peakmV is the peak-to-peak output voltage
//	
//	variable dev, freq, peakmV
//	string shape
//	
//	// setup frequency
//	variable minFreq = 1e-6, maxFreq = 80e6 // Hz
//	string strFreq = ""
//	
//	if(freq<=minFreq)
//		strFreq = "MIN"
//	elseif(freq>=maxFreq)
//		strFreq = "MAX"
//	else
//		sprintf strFreq, "%.3f", freq
//	endif
//
//	string cmd = ""
//	sprintf cmd, "APPLY:%s %s, %.4f, %.4f", shape, strFreq, peakmV/1000, 0.0
//	writeAWG(dev, cmd)
//end

function setAWGfrequency(dev, freq)
	// set the frequency in HZ
	variable dev, freq

	variable minFreq = 1e-6, maxFreq = 80e6 // Hz
	string cmd = ""
	
	if(freq<=minFreq)
		cmd = "FREQ MIN"
	elseif(freq>=maxFreq)
		cmd = "FREQ MAX"
	else
		sprintf cmd, "FREQ %.3f", freq
	endif
	
	writeAWG(dev, cmd)
	
end

function getAWGfrequency(dev)
	// get the frequency
	variable dev
	
	string response = queryAWG(dev, "FREQ?")
	
	if(stringmatch(LowerStr(response), "min")==1)
		return 1e-6
	elseif(stringmatch(LowerStr(response), "max")==1)
		return 80e6
	else
		return str2num(response)
	endif
	
end

function setAWGload(dev, load)
	// set the otuput load in Ohms
	// use load = -1 to set High Z mode
	
	variable dev, load

	variable minLoad = 1, maxLoad = 10e3 // Ohms
	string cmd = ""
	
	if(load<=minLoad)
		cmd = "OUTP:LOAD MIN"
	elseif(load>=maxLoad)
		cmd = "OUTP:LOAD MAX"
	elseif(load==-1)
		sprintf cmd, "OUTP:LOAD INF"
	else
		sprintf cmd, "OUTP:LOAD %.0f", load
	endif
	
	writeAWG(dev, cmd)
end

function setAWGamplitude(dev, vout)
	// vout is in the units specified by setAWGunits()
	//    that is VPP, VRMS, or DBM
	// vout is scaled by 1000 (assuming you like using mV)

	variable dev, vout

	string cmd = "", strVolt
	if(vout<0.1)
		strVolt = "MIN"
	else
		sprintf strVolt, "%.4f", vout/1000.0
	endif
	sprintf cmd, ":VOLT %s", strVolt
	
	writeAWG(dev, cmd)
end

function setAWGoffset(dev, vout)
	// set dc offset of AWG output in mV
	variable dev, vout
	string cmd = ""
	
	sprintf cmd, ":VOLT:OFFS %.5f", vout
	writeAWG(dev, cmd)
end

function getAWGamplitude(dev)
	// returns Vpp in mV
	
	variable dev
	
	string response = queryAWG(dev, "VOLT?")
	return str2num(response)*1000.0
	
end

function getAWGoffset(dev)
	// returns peak amplitude in mV
	
	variable dev
	
	string response = queryAWG(dev, ":VOLT:OFFS?")
	return str2num(response)*1000.0
	
end