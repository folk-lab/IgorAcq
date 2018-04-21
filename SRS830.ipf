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

function GetSRSHarmonic(instID)
	variable instID
	string response
	
	response = QuerySRS("HARM?",instID)
	return str2num(response)
end

function GetSRSTimeConst(instID) // Return units: s
	variable instID
	variable srsreturn
	
	srsreturn = str2num(QuerySRS("OFLT?",instID))
	
	if(mod(srsreturn,2) == 0)
		return 10^(srsreturn/2-5)
	else
		return 3*10^((srsreturn-1)/2-5)
	endif
end

function GetSRSPhase(instID)
	variable instID
	string response
	
	response = QuerySRS("PHAS?",instID)
	return str2num(response)
end

function GetSRSAmplitude(instID)
	variable instID
	string response
	
	response = QuerySRS("SLVL?",instID)
	return str2num(response)
end

function GetSRSFrequency(instID)
	variable instID
	string response
	
	response = QuerySRS("FREQ?",instID)
	return str2num(response)
end

function GetSRSSensitivity(instID) // Return units: V or A
	variable instID
	variable srsreturn, modulo, expo
	
	srsreturn = str2num(QuerySRS("SENS?",instID))
	modulo = mod(srsreturn,3)
	expo = (srsreturn-modulo)/3
	
	srsreturn = str2num(QuerySRS("ISRC?",instID))
	if(srsreturn >= 2)
		expo -= 15 //current mode
	else
		expo -= 9 // voltage mode
	endif
	
	if(modulo == 0)
		return 2*10^expo
	elseif(modulo == 1)
		return 5*10^expo
	elseif(modulo == 2)
		return 10*10^expo
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


/////////////////////////
//// Status function ////
////////////////////////

function/s GetSRSStatus(instID)
	variable instID
	string  buffer = ""
	
	//string gpib = num2istr(returnGPIBaddress(srs)) FIX "GPIB procedure"
	string gpib = ""
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