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

function ReadSRSx(instrID) //Units: mV
	variable instrID
	string response
	
	response = queryInstr(instrID, "OUTP? 1", "\n", "\n")
	return str2num(response)
end

function ReadSRSy(instrID) //Units: mV
	variable instrID
	string response
	
	response = queryInstr(instrID, "OUTP? 2", "\n", "\n")
	return str2num(response)
end

function ReadSRSr(instrID) //Units: mV
	variable instrID
	string response
	
	response = queryInstr(instrID, "OUTP? 3", "\n", "\n")
	return str2num(response)
end

function ReadSRSt(instrID) //Units: rad
	variable instrID
	string response
	
	response = queryInstr(instrID, "OUTP? 4", "\n", "\n")
	return str2num(response)
end

function GetSRSHarmonic(instrID) // Units: AU
	variable instrID
	string response
	
	response = queryInstr(instrID, "HARM?", "\n", "\n")
	return str2num(response)
end

function GetSRSTimeConst(instrID) // Return units: s
	variable instrID
	variable response
	
	response = str2num(queryInstr(instrID, "OFLT?", "\n", "\n"))
	if(mod(response,2) == 0)
		return 10^(response/2-5)
	else
		return 3*10^((response-1)/2-5)
	endif
end

function GetSRSPhase(instrID) // Units: AU
	variable instrID
	string response
	
	response = queryInstr(instrID, "PHAS?", "\n", "\n")
	return str2num(response)
end

function GetSRSAmplitude(instrID) // Units: mV
	variable instrID
	string response
	
	response = queryInstr(instrID, "SLVL?", "\n", "\n")
	return str2num(response)*1000
end

function GetSRSFrequency(instrID) // Units: Hz
	variable instrID
	string response
	
	response = queryInstr(instrID, "FREQ?", "\n", "\n")
	return str2num(response)
end

function GetSRSSensitivity(instrID,[integer]) // Units: mV or nA
	variable instrID, integer
	variable response, modulo, expo
	
	if(paramisdefault(integer))
		integer = 0
	endif

	response = str2num(queryInstr(instrID, "SENS?", "\n", "\n"))
	if(integer)
		return response
	endif
	modulo = mod(response,3)
	expo = (response-modulo)/3

	response = str2num(queryInstr(instrID, "ISRC?", "\n", "\n"))
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

//function GetSRSJunk(instrID)
//	variable instrID
//	variable i=0
//	string response
//	
//	do
//		VisaRead/Q/T="\n" instrID, response
//		i+=1
//	while(v_flag > 0)
//	printf "Buffer had %d items of junk!\r", i
//end

/////////////////////////////
//// async get functions ////
////////////////////////////

threadsafe function ReadSRSx_Async(datafolderID) // Units: mV
	string datafolderID
	string response
	
	// get instrument ID from datafolder
	DFREF dfr = ThreadGroupGetDFR(0,inf)
	setdatafolder dfr
	nvar instrID = $(":"+datafolderID+":instrID")
	killdatafolder dfr // We don't need the datafolder anymore!
	
	response = queryInstr(instrID, "OUTP? 1", "\n", "\n")
	return str2num(response)
end

threadsafe function ReadSRSy_Async(datafolderID) // Units: mV
	string datafolderID
	string response
	
	// get instrument ID from datafolder
	DFREF dfr = ThreadGroupGetDFR(0,inf)
	setdatafolder dfr
	nvar instrID = $(":"+datafolderID+":instrID")
	killdatafolder dfr // We don't need the datafolder anymore!
	
	response = queryInstr(instrID, "OUTP? 2", "\n", "\n")
	return str2num(response)
end

threadsafe function ReadSRSr_Async(datafolderID) // Units: mV
	string datafolderID
	string response
	
	// get instrument ID from datafolder
	DFREF dfr = ThreadGroupGetDFR(0,inf)
	setdatafolder dfr
	nvar instrID = $(":"+datafolderID+":instrID")
	killdatafolder dfr // We don't need the datafolder anymore!
	
	response = queryInstr(instrID, "OUTP? 3", "\n", "\n")
	return str2num(response)
end

threadsafe function ReadSRSt_Async(datafolderID) // Units: rad
	string datafolderID
	string response
	
	// get instrument ID from datafolder
	DFREF dfr = ThreadGroupGetDFR(0,inf)
	setdatafolder dfr
	nvar instrID = $(":"+datafolderID+":instrID")
	killdatafolder dfr // We don't need the datafolder anymore!
	
	response = queryInstr(instrID, "OUTP? 4", "\n", "\n")
	return str2num(response)
end

////////////////////////
//// Set functions ////
///////////////////////

function SetSRSHarmonic(instrID,harm) // Units: AU
	variable instrID,harm
	
	writeInstr(instrID, "HARM "+num2str(harm), "\n")
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
	
	writeInstr(instrID, "OFLT "+num2istr(v_value), "\n")
end

function SetSRSPhase(instrID,phase) // Units: AU
	variable instrID, phase
	
	writeInstr(instrID, "PHAS "+num2str(phase), "\n")
end

function SetSRSAmplitude(instrID,amplitude) // Units: mV
	variable instrID, amplitude
	
	if(amplitude > 4)
		print "max amplitude is 4mV."
		amplitude = 4
	endif
	
	writeInstr(instrID, "SLVL "+num2str(amplitude/1000), "\n")
end

function SetSRSFrequency(instrID,frequency)
	variable instrID, frequency
	
	writeInstr(instrID, "FREQ "+num2str(frequency), "\n")
end

function SetSRSSensitivity(instrID,sens) // Units: mV or nA
	variable instrID, sens
	make/o lookuptable={0.000002,0.000005,0.00001,0.00002,0.00005,0.0001,0.0002,0.0005,0.001,0.002,0.005,0.01,0.02,0.05,0.1,0.2,0.5,1,2,5,10,20,50,100,200,500,1000}
	
	make/o minsens = abs(lookuptable-sens)
	findvalue/v=(wavemin(minsens)) minsens
	
	writeInstr(instrID, "SENS "+num2str(v_value), "\n")
end

function SetSRSSensUp(instrID)
	variable instrID
	variable sens
	
	sens = GetSRSSensitivity(instrID,integer=1)
	if(sens < 26)
		writeInstr(instrID, "SENS "+num2str(sens+1), "\n")
	else
		print "SRS sensitivity already at maximum!"
	endif
end

function SetSRSSensDown(instrID)
	variable instrID
	variable sens
	
	sens = GetSRSSensitivity(instrID,integer=1)
	if(sens > 0)
		writeInstr(instrID, "SENS "+num2str(sens+1), "\n")
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
	buffer = addJSONKeyVal(buffer, "gpib_address", strVal=gpib)
	
	buffer = addJSONKeyVal(buffer, "amplitude V", numVal=GetSRSAmplitude(instrID), fmtNum="%.3f")
	buffer = addJSONKeyVal(buffer, "time_const ms", numVal= GetSRSTimeConst(instrID)*1000, fmtNum="%.2f")
	buffer = addJSONKeyVal(buffer, "frequency Hz", numVal= GetSRSFrequency(instrID), fmtNum="%.3f")
	buffer = addJSONKeyVal(buffer, "phase deg", numVal=GetSRSPhase(instrID), fmtNum="%.2f")
	buffer = addJSONKeyVal(buffer, "sensitivity V", numVal=GetSRSSensitivity(instrID), fmtNum="%.4f")
	buffer = addJSONKeyVal(buffer, "harmonic", numVal=GetSRSHarmonic(instrID), fmtNum="%d")

	return addJSONKeyVal("", "SRS_"+gpib, strVal=buffer)
end