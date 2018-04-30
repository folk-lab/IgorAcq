#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method

// SRS830 driver, using the VISA library.
// Driver supports async data collection, via the *Async functions.
// Still a test driver, use InitSRS.
// Units: mV, nA or Hz
// Written by Christian Olsen, 2018-05-01

function InitSRS(instID,gpibadresse,[gpibboard])
	string instID
	variable gpibadresse, gpibboard
	string resource, error
	variable session=0, inst=0, status
	
	if(paramisdefault(gpibboard))
		gpibboard = 0
	endif
	
	sprintf resource, "GPIB%d::%d::INSTR",gpibboard,gpibadresse
	status = viOpenDefaultRM(session)
	if (status < 0)
		viStatusDesc(session, status, error)
		abort "OpenDefaultRM error: " + error
	endif
	
	status = viOpen(session,resource,0,0,inst) //not sure what to do with openTimeout, setting it to 0!
	if (status < 0)
		viStatusDesc(session, status, error)
		abort "viOpen error: " + error
	endif
	
	variable/g $instID = inst
end

/////////////////////////////
//// Sync get functions ////
////////////////////////////

function ReadSRSx(instID) //Units: mV
	variable instID
	string response
	
	response = QuerySRS("OUTP? 1",InstID)
	return str2num(response)
end

function ReadSRSy(InstID) //Units: mV
	variable instID
	string response
	
	response = QuerySRS("OUTP? 2",InstID)
	return str2num(response)
end

function ReadSRSr(instID) //Units: mV
	variable instID
	string response
	
	response = QuerySRS("OUTP? 3",InstID)
	return str2num(response)
end

function ReadSRSt(instID) //Units: rad
	variable instID
	string response
	
	response = QuerySRS("OUTP? 4",InstID)
	return str2num(response)
end

function GetSRSHarmonic(instID) // Units: AU
	variable instID
	string response
	
	response = QuerySRS("HARM?",instID)
	return str2num(response)
end

function GetSRSTimeConst(instID) // Return units: s
	variable instID
	variable response
	
	response = str2num(QuerySRS("OFLT?",instID))
	
	if(mod(response,2) == 0)
		return 10^(response/2-5)
	else
		return 3*10^((response-1)/2-5)
	endif
end

function GetSRSPhase(instID) // Units: AU
	variable instID
	string response
	
	response = QuerySRS("PHAS?",instID)
	return str2num(response)
end

function GetSRSAmplitude(instID) // Units: mV
	variable instID
	string response
	
	response = QuerySRS("SLVL?",instID)
	return str2num(response)*1000
end

function GetSRSFrequency(instID) // Units: Hz
	variable instID
	string response
	
	response = QuerySRS("FREQ?",instID)
	return str2num(response)
end

function GetSRSSensitivity(instID,[integer]) // Units: mV or nA
	variable instID, integer
	variable response, modulo, expo
	
	if(paramisdefault(integer))
		integer = 0
	endif
	
	response = str2num(QuerySRS("SENS?",instID))
	if(integer)
		return response
	endif
	modulo = mod(response,3)
	expo = (response-modulo)/3
	
	response = str2num(QuerySRS("ISRC?",instID))
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

function GetSRSJunk(instID)
	variable instID
	variable i=0
	string response
	
	do
		VisaRead/Q/T="\n" instID, response
		i+=1
	while(v_flag > 0)
	printf "Buffer had %d items of junk!\r", i
end

/////////////////////////////
//// Async get functions ////
////////////////////////////

threadsafe function ReadSRSx_Async(datafolderID) // Units: mV
	string datafolderID
	string response
	
	// get instrument ID from datafolder
	DFREF dfr = ThreadGroupGetDFR(0,inf)
	setdatafolder dfr
	nvar instID = $(":"+datafolderID+":instID")
	killdatafolder dfr // We don't need the datafolder anymore!
	
	response = QuerySRS("OUTP? 1",InstID)
	return str2num(response)
end

threadsafe function ReadSRSy_Async(datafolderID) // Units: mV
	string datafolderID
	string response
	
	// get instrument ID from datafolder
	DFREF dfr = ThreadGroupGetDFR(0,inf)
	setdatafolder dfr
	nvar instID = $(":"+datafolderID+":instID")
	killdatafolder dfr // We don't need the datafolder anymore!
	
	response = QuerySRS("OUTP? 2",instID)
	return str2num(response)
end

threadsafe function ReadSRSr_Async(datafolderID) // Units: mV
	string datafolderID
	string response
	
	// get instrument ID from datafolder
	DFREF dfr = ThreadGroupGetDFR(0,inf)
	setdatafolder dfr
	nvar instID = $(":"+datafolderID+":instID")
	killdatafolder dfr // We don't need the datafolder anymore!
	
	response = QuerySRS("OUTP? 3",instID)
	return str2num(response)
end

threadsafe function ReadSRSt_Async(datafolderID) // Units: rad
	string datafolderID
	string response
	
	// get instrument ID from datafolder
	DFREF dfr = ThreadGroupGetDFR(0,inf)
	setdatafolder dfr
	nvar instID = $(":"+datafolderID+":instID")
	killdatafolder dfr // We don't need the datafolder anymore!
	
	response = QuerySRS("OUTP? 4",instID)
	return str2num(response)
end

////////////////////////
//// Set functions ////
///////////////////////

function SetSRSHarmonic(instID,harm) // Units: AU
	variable instID,harm
	
	WriteSRS("HARM "+num2str(harm),instID)
end

function SetSRSTimeConst(instID,timeConst) // Units: s
	variable instID, timeConst
	variable range
	make/o lookuptable = {0.00001,0.00003,0.0001,0.0003,0.001,0.003,0.01,0.03,0.1,0.3,1,3,10,30,100,300,1000,3000,10000,30000}
	
	// check that time constant is within range
	if(timeConst > 30000)
		print "Time constant not within range, setting to nearest possible."
		timeConst = 30000
	elseif(timeConst < 0.01)
		print "Time constant not within range, setting to nearest possible."
		timeConst = 0.01
	endif
	
	// transform to integer
	make/o mintime = abs(lookuptable-timeConst)
	findvalue/v=(wavemin(minstime)) mintime
	
	WriteSRS("OFLT "+num2istr(v_value),instID)
end

function SetSRSPhase(instID,phase) // Units: AU
	variable instID, phase
	
	WriteSRS("PHAS "+num2str(phase),instID)
end

function SetSRSAmplitude(instID,amplitude) // Units: mV
	variable instID, amplitude
	
	if(amplitude > 4)
		print "max amplitude is 4mV."
		amplitude = 4
	endif
	
	WriteSRS("SLVL "+num2str(amplitude/1000),instID)
end

function SetSRSFrequency(instID,frequency)
	variable instID, frequency
	
	WriteSRS("FREQ "+num2str(frequency),instID)
end

function SetSRSSensitivity(instID,sens) // Units: mV or nA
	variable instID, sens
	make/o lookuptable={0.000002,0.000005,0.00001,0.00002,0.00005,0.0001,0.0002,0.0005,0.001,0.002,0.005,0.01,0.02,0.05,0.1,0.2,0.5,1,2,5,10,20,50,100,200,500,1000}
	
	make/o minsens = abs(lookuptable-sens)
	findvalue/v=(wavemin(minsens)) minsens
	
	WriteSRS("SENS "+num2str(v_value),instID)
end

function SetSRSSensUp(instID)
	variable instID
	variable sens
	
	sens = GetSRSSensitivity(instID,integer=1)
	if(sens < 26)
		WriteSRS("SENS "+num2str(sens+1),instID)
	else
		print "Sensitivity is at max already!"
	endif
end

function SetSRSSensDown(instID)
	variable instID
	variable sens
	
	sens = GetSRSSensitivity(instID,integer=1)
	if(sens > 0)
		WriteSRS("SENS "+num2str(sens+1),instID)
	else
		print "Sensitivity is at min already!"
	endif
end

/////////////////////////
//// Status function ////
////////////////////////

function/s GetSRSStatus(instID)
	variable instID
	string  buffer = ""
	
	string gpib = num2istr(instGPIB(instID))
	buffer = addJSONKeyVal(buffer, "gpib_address", strVal=gpib)
	
	buffer = addJSONKeyVal(buffer, "amplitude V", numVal=GetSRSAmplitude(instID), fmtNum="%.3f")
	buffer = addJSONKeyVal(buffer, "time_const ms", numVal= GetSRSTimeConst(instID)*1000, fmtNum="%.2f")
	buffer = addJSONKeyVal(buffer, "frequency Hz", numVal= GetSRSFrequency(instID), fmtNum="%.3f")
	buffer = addJSONKeyVal(buffer, "phase deg", numVal=GetSRSPhase(instID), fmtNum="%.2f")
	buffer = addJSONKeyVal(buffer, "sensitivity V", numVal=GetSRSSensitivity(instID), fmtNum="%.4f")
	buffer = addJSONKeyVal(buffer, "harmonic", numVal=GetSRSHarmonic(instID), fmtNum="%d")

	return addJSONKeyVal("", "SRS_"+gpib, strVal=buffer)
end

////////////////////////////
//// Visa communication ////
////////////////////////////

threadsafe function WriteSRS(cmd,instID)
	string cmd
	variable instID
	
	cmd = cmd+"\n"
	VisaWrite instID, cmd
end

threadsafe function/s ReadSRS(instID)
	variable instID
	string response
	
	VisaRead/T="\n" instID, response
	return response
end

threadsafe function/s QuerySRS(cmd,instID)
	string cmd
	variable instID
	
	WriteSRS(cmd,instID)
	return ReadSRS(instID)
end