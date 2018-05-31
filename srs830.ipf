#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method

// SRS830 driver, using the VISA library.
// Driver supports async data collection, via the *Async functions.
// Still a test driver, use InitSRS.
// Units: mV, nA or Hz
// Written by Christian/Nik, 2018-05-01

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

	writeInstr(instrID, "HARM "+num2str(harm)+"\n")
end

function SetSRSTimeConst(instrID,timeConst) // Units: s
	variable instrID, timeConst
	variable range
	make/o srs_tc_lookup = {0.00001,0.00003,0.0001,0.0003,0.001,0.003,0.01,0.03,0.1,0.3,1,3,10,30,100,300,1000,3000,10000,30000}

	// check that time constant is within range
	if(timeConst > 30000)
		print "Time constant not within range, setting to nearest possible."
		timeConst = 30000
	elseif(timeConst < 0.01)
		print "Time constant not within range, setting to nearest possible."
		timeConst = 0.01
	endif

	// transform to integer
	make/o mintime = abs(srs_tc_lookup-timeConst)
	findvalue/v=(wavemin(minstime)) mintime

	writeInstr(instrID, "OFLT "+num2istr(v_value)+"\n")
end

function SetSRSPhase(instrID,phase) // Units: AU
	variable instrID, phase

	writeInstr(instrID, "PHAS "+num2str(phase)+"\n")
end

function SetSRSAmplitude(instrID,amplitude) // Units: mV
	variable instrID, amplitude

	if(amplitude > 4)
		print "max amplitude is 4mV."
		amplitude = 4
	endif

	writeInstr(instrID, "SLVL "+num2str(amplitude/1000)+"\n")
end

function SetSRSFrequency(instrID,frequency)
	variable instrID, frequency

	writeInstr(instrID, "FREQ "+num2str(frequency)+"\n")
end

function SetSRSSensitivity(instrID,sens) // Units: mV or nA
	variable instrID, sens
	make/o lookuptable={0.000002,0.000005,0.00001,0.00002,0.00005,0.0001,0.0002,0.0005,0.001,0.002,0.005,0.01,0.02,0.05,0.1,0.2,0.5,1,2,5,10,20,50,100,200,500,1000}

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
	buffer = addJSONkeyvalpair(buffer, "gpib_address", gpib)

	buffer = addJSONkeyvalpair(buffer, "amplitude V", num2str(GetSRSAmplitude(instrID)))
	buffer = addJSONkeyvalpair(buffer, "time_const ms", num2str(GetSRSTimeConst(instrID)*1000))
	buffer = addJSONkeyvalpair(buffer, "frequency Hz", num2str(GetSRSFrequency(instrID)))
	buffer = addJSONkeyvalpair(buffer, "phase deg", num2str(GetSRSPhase(instrID)))
	buffer = addJSONkeyvalpair(buffer, "sensitivity V", num2str(GetSRSSensitivity(instrID)))
	buffer = addJSONkeyvalpair(buffer, "harmonic", num2str(GetSRSHarmonic(instrID)))

	return addJSONkeyvalpair("", "SRS_"+gpib, buffer)
end
