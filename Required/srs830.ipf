#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method

// SRS830 driver, using the VISA library.
// Driver supports async data collection, via the *Async functions.
// Still a test driver, use InitSRS.
// Units: mV, nA or Hz
// Written by Christian/Nik, 2018-05-01
// Modified by Tim Child to add more set/get commands, 2020-03

/////////////////////////
/// SRS specific COMM ///
/////////////////////////

function openSRSconnection(instrID, visa_address, [verbose])
	// works for GPIB -- may need to add some more 'option' paramters if using serial
	//                -- does not hurt to send extra parameters when using GPIB, they are ignored
	// instrID is the name of the global variable that will be used for communication
	// visa_address is the VISA address string, i.e. GPIB0::1::INSTR
	string instrID, visa_address
	variable verbose
	
	if(paramisdefault(verbose))
		verbose=1
	elseif(verbose!=1)
		verbose=0
	endif
	
	variable localRM
	variable status = viOpenDefaultRM(localRM) // open local copy of resource manager
	if(status < 0)
		VISAerrormsg("open SRS connection:", localRM, status)
		abort
	endif
	
	string comm = ""
	sprintf comm, "name=SRS,instrID=%s,visa_address=%s" instrID, visa_address
	string options = "test_query=*IDN?"
	openVISAinstr(comm, options=options, localRM=localRM, verbose=verbose)
	
end

/////////////////////////////
//// Sync get functions ////
////////////////////////////

threadsafe function ReadSRSx(instrID) //Units: mV
	variable instrID
	string response

	response = queryInstr(instrID, "OUTP? 1\n")
	return str2num(response)
end

threadsafe function ReadSRSy(instrID) //Units: mV
	variable instrID
	string response

	response = queryInstr(instrID, "OUTP? 2\n")
	return str2num(response)
end

threadsafe function ReadSRSr(instrID) //Units: mV
	variable instrID
	string response

	response = queryInstr(instrID, "OUTP? 3\n")
	return str2num(response)
end

threadsafe function ReadSRSt(instrID) //Units: rad
	variable instrID
	string response

	response = queryInstr(instrID, "OUTP? 4\n")
	return str2num(response)
end

threadsafe function GetSRSHarmonic(instrID) // Units: AU
	variable instrID
	string response

	response = queryInstr(instrID, "HARM?\n")
	return str2num(response)
end

threadsafe function GetSRSTimeConst(instrID) // Return units: s
	variable instrID
	variable response

	response = str2num(queryInstr(instrID, "OFLT?\n"))
	if(mod(response,2) == 0)
		return 10^(response/2-5)
	else
		return 3*10^((response-1)/2-5)
	endif
end

threadsafe function GetSRSPhase(instrID) // Units: AU
	variable instrID
	string response

	response = queryInstr(instrID, "PHAS?\n")
	return str2num(response)
end

threadsafe function GetSRSAmplitude(instrID) // Units: mV
	variable instrID
	string response

	response = queryInstr(instrID, "SLVL?\n")
	return str2num(response)*1000
end

threadsafe function GetSRSFrequency(instrID) // Units: Hz
	variable instrID
	string response

	response = queryInstr(instrID, "FREQ?\n")
	return str2num(response)
end

function GetSRSreadout(instrID, [ch]) //Useful when reading output of SRS with ADC. 
	//Returns 0,1,2,3 (for CH1: 0 = x, 1 = r, 2 = xnoise, 3=?.  For CH2: 0 = y, 1 = theta, 2 = rnoise?, 3=?)
	variable instrID
	variable ch
	ch = paramisdefault(ch) ? 1 : ch //defaults to reading ch1 output
	string response

	response = queryInstr(instrID, "DDEF?"+num2str(ch)+"\n")
	return str2num(response)
end

function GetSRSSensitivity(instrID,[integer]) // Units: mV or nA
	variable instrID, integer
	variable response, modulo, expo

	if(paramisdefault(integer))
		integer = 0
	endif

	response = str2num(queryInstr(instrID, "SENS?\n"))
	if(integer)
		return response
	endif                                                            
	modulo = mod(response,3)
	expo = (response-modulo)/3

	response = str2num(queryInstr(instrID, "ISRC?\n"))
	if(response >= 2)
		expo -= 15 //current mode
	else
		expo -= 9 // voltage mode
	endif

	if(modulo == 0)
		if(response >= 2)
			return (2*10^expo)*1e9
		else
			return (2*10^expo)*1e3
		endif
	elseif(modulo == 1)
		if(response >= 2)
			return (5*10^expo)*1e9
		else
			return (5*10^expo)*1e3
		endif
	elseif(modulo == 2)
		if(response >= 2)
			return (10*10^expo)*1e9
		else
			return (10*10^expo)*1e3
		endif
	endif
end

function readSRSjunk(instrID)
	variable instrID
	variable i=0
	string response

	do
		VisaRead/Q/N=1 instrID, response
		if(strlen(response) == 0)
			break
		endif
		sleep /T 1
		i+=1
	while(1)
	printf "Read %d chars of junk from buffer.\r", i
end

////////////////////////
//// Set functions ////
///////////////////////

threadsafe function SetSRSHarmonic(instrID,harm) // Units: AU
	variable instrID,harm
	
	// check for NAN and INF
	if(numtype(harm) != 0)
		print "trying to set harmonic to NaN or Inf"
		return 0
	endif
	
	writeInstr(instrID, "HARM "+num2str(harm)+"\n")
end

function SetSRSTimeConst(instrID,timeConst) // Units: s
	variable instrID, timeConst
	variable range
	make/o srs_tc_lookup = {0.00001,0.00003,0.0001,0.0003,0.001,0.003,0.01,0.03,0.1,0.3,1,3,10,30,100,300,1000,3000,10000,30000}
	
	// check for NAN and INF
	if(numtype(timeconst) != 0)
		abort "trying to set time constant to NaN or Inf"
	endif
	
	// check that time constant is within range
	if(timeConst > 30000)
		print "Time constant not within range, setting to nearest possible."
		timeConst = 30000
	elseif(timeConst < 0.001)
		print "Time constant not within range, setting to nearest possible."
		timeConst = 0.001
	endif

	// transform to integer
	make/o mintime = abs(srs_tc_lookup-timeConst)
	findvalue/v=(wavemin(mintime)) mintime
	writeInstr(instrID, "OFLT "+num2istr(v_value)+"\n")
end

function SetSRSPhase(instrID,phase) // Units: deg
	variable instrID, phase
	
	// check for NAN and INF
	if(numtype(phase) != 0)
		abort "trying to set phase to NaN or Inf"
	endif
	
	writeInstr(instrID, "PHAS "+num2str(phase)+"\n")
end

function AutoSRSPhase(instrID) // Units: deg
	variable instrID
	writeInstr(instrID, "APHS \n")
end

function SetSRSreadout(instrID, readout, [ch, ratio]) //e.g. for Ch1: readout 0 = x, 1 = r, 2 = xnoise etc
	variable instrID, readout
	variable ch, ratio
	variable disp //if =1 ch1 and ch2 output x and y, if 0 ch1 and ch2 output display
	ch = paramisdefault(ch) ? 1 : ch //Defaults to channel 1
	ratio = paramisdefault(ratio) ? 0 : ratio //Defaults to no ratio
	if (readout != 0)
		disp = 0
	else
		disp = 1
	endif
	// check for NAN and INF
	if(numtype(ch) != 0 || numtype(readout) != 0 || numtype(ratio) != 0)
		abort "trying to set ch/readout/ratio to NaN or Inf"
	endif
	string buffer = ""
	sprintf buffer, "DDEF %d, %d, %d\n", ch, readout, ratio
	writeInstr(instrID, buffer)
	sprintf buffer, "FPOP %d, %d", ch, disp 
	writeInstr(instrID, buffer)
end

function SetSRSAmplitude(instrID,amplitude) // Units: mV
	variable instrID, amplitude
	
	// check for NAN and INF
	if(numtype(amplitude) != 0)
		abort "trying to set amplitude to NaN or Inf"
	endif
	
	if(amplitude < 4)
		print "min amplitude is 4mV."
		amplitude = 4
	endif

	writeInstr(instrID, "SLVL "+num2str(amplitude/1000)+"\n")
end

function SetSRSFrequency(instrID,frequency)
	variable instrID, frequency
	
	// check for NAN and INF
	if(numtype(frequency) != 0)
		abort "trying to set frequency to NaN or Inf"
	endif
	
	writeInstr(instrID, "FREQ "+num2str(frequency)+"\n")
end

function SetSRSSensitivity(instrID,sens) // Units: mV or nA
	variable instrID, sens
	make/o lookuptable={0.000002,0.000005,0.00001,0.00002,0.00005,0.0001,0.0002,0.0005,0.001,0.002,0.005,0.01,0.02,0.05,0.1,0.2,0.5,1,2,5,10,20,50,100,200,500,1000}
	
	// check for NAN and INF
	if(numtype(sens) != 0)
		abort "trying to set sensitivity to NaN or Inf"
	endif
	
	make/o minsens = abs(lookuptable-sens)
	findvalue/v=(wavemin(minsens)) minsens

	writeInstr(instrID, "SENS "+num2str(v_value)+"\n")
end

function SetSRSSensUp(instrID)
	variable instrID
	variable sens

	sens = GetSRSSensitivity(instrID,integer=1)
	if(sens < 26)
		writeInstr(instrID, "SENS "+num2str(sens+1)+"\n")
	else
		print "SRS sensitivity already at maximum!"
	endif
end

function SetSRSSensDown(instrID)
	variable instrID
	variable sens

	sens = GetSRSSensitivity(instrID,integer=1)
	if(sens > 0)
		writeInstr(instrID, "SENS "+num2str(sens+1)+"\n")
	else
		print "Sensitivity is at min already!"
	endif
end

/////////////////////////
//// Status function ////
////////////////////////

function/s GetSRSStatus(instrID)
	variable instrID
	string  buffer = ""

	string gpib = num2istr(getAddressGPIB(instrID))
	buffer = addJSONkeyval(buffer, "gpib_address", gpib)

	buffer = addJSONkeyval(buffer, "amplitude V", num2numStr(GetSRSAmplitude(instrID)))
	buffer = addJSONkeyval(buffer, "time_const ms", num2numStr(GetSRSTimeConst(instrID)*1000))
	buffer = addJSONkeyval(buffer, "frequency Hz", num2numStr(GetSRSFrequency(instrID)))
	buffer = addJSONkeyval(buffer, "phase deg", num2numStr(GetSRSPhase(instrID)))
	buffer = addJSONkeyval(buffer, "sensitivity V", num2numStr(GetSRSSensitivity(instrID)))
	buffer = addJSONkeyval(buffer, "harmonic", num2numStr(GetSRSHarmonic(instrID)))
	buffer = addJSONkeyval(buffer, "CH1readout", num2numstr(Getsrsreadout(instrID, ch=1)))
	buffer = addJSONkeyval(buffer, "CH2readout", num2numstr(Getsrsreadout(instrID, ch=2)))
	return addJSONkeyval("", "SRS_"+gpib, buffer)
end
