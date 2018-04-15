#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method

// SRS830 driver, using the VISA library.
// Driver supports async data collection, via the *Async functions.
// Still a test driver, use InitSRS.
// Units: mV, nA or Hz
// Written by Christian Olsen, 2018-05-01

function InitSRS(id,gpibadresse,[gpibboard])
	string id
	variable gpibadresse, gpibboard
	string resource, error
	variable session=0, instID=0, status
	
	if(paramisdefault(gpibboard))
		gpibboard = 0
	endif
	
	sprintf resource, "GPIB%d::%d::INSTR",gpibboard,gpibadresse
	status = viOpenDefaultRM(session)
	if (status < 0)
		viStatusDesc(session, status, error)
		abort "OpenDefaultRM error: " + error
	endif
	
	status = viOpen(session,resource,0,0,instID) //not sure what to do with openTimeout, setting it to 0!
	if (status < 0)
		viStatusDesc(session, status, error)
		abort "viOpen error: " + error
	endif
	
	variable/g $id = instID
end

/////////////////////////////
//// Sync get functions ////
////////////////////////////

function ReadSRSx(id) //Units: mV
	variable id
	
	return ReadSRSxAsync(id)
end

function ReadSRSy(id) //Units: mV
	variable id
	
	return ReadSRSyAsync(id)
end

function ReadSRSr(id) //Units: mV
	variable id
	
	return ReadSRSrAsync(id)
end

function ReadSRSt(id) //Units: rad
	variable id
	
	return ReadSRStAsync(id)
end

/////////////////////////////
//// Async get functions ////
////////////////////////////

threadsafe function ReadSRSxAsync(id) // Units: mV
	variable id
	string response
	
	response = QuerySRS("OUTP? 1",id)
	return str2num(response)
end

threadsafe function ReadSRSyAsync(id) // Units: mV
	variable id
	string response
	
	response = QuerySRS("OUTP? 2",id)
	return str2num(response)
end

threadsafe function ReadSRSrAsync(id) // Units: mV
	variable id
	string response
	
	response = QuerySRS("OUTP? 3",id)
	return str2num(response)
end

threadsafe function ReadSRStAsync(id) // Units: rad
	variable id
	string response
	
	response = QuerySRS("OUTP? 4",id)
	return str2num(response)
end

////////////////////////////
//// Visa communication ////
////////////////////////////

threadsafe function WriteSRS(cmd,id)
	string cmd
	variable id
	
	cmd = cmd+"\n"
	VisaWrite id, cmd
end

threadsafe function/s ReadSRS(id)
	variable id
	string response
	
	VisaRead/T="\n" id, response
	return response
end

threadsafe function/s QuerySRS(cmd,id)
	string cmd
	variable id
	
	WriteSRS(cmd,id)
	return ReadSRS(id)
end