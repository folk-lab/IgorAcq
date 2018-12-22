#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1	// Use modern global access method

// Driver communicates over serial.
// Procedure written by Christian Olsen 2017-03-15
// Updated to VISA by Christian Olsen, 2018-05-xx
// Both axes are powered by Lakeshore 625 power supplies.


////////////////////////////
//// Lakeshore 625 COMM ////
////////////////////////////

function openLS625connection(instrID, visa_address, [verbose])
	// instrID is the name of the global variable that will be used for communication
	// visa_address is the VISA address string, i.e. ASRL1::INSTR
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
		VISAerrormsg("open LS625 connection:", localRM, status)
		abort
	endif
	
	string comm = ""
	sprintf comm, "name=LS625,instrID=%s,visa_address=%s" instrID, visa_address
	string options = "baudrate=57600,databits=7,stopbits=1,parity=1"
	openVISAinstr(comm, options=options, localRM=localRM, verbose=verbose)
end

///////////////////////
/// Initiate Magnet ///
///////////////////////

function initLS625zOnly(instrIDz)

	variable instrIDz

	// local copies of the serial port addresses
	string/g instrDescZ = getResourceAddress(instrIDz)

	variable/g ampsperteslaz=9.950// A/T
	variable/g maxfieldz=6000 // mT
	variable/g maxrampratez=300 // mT/min

	setLS625rate(instrIDz,100)
	
end

////////////////////////
//// Get functions ////
///////////////////////

function getLS625current(instrID) // Units: A
	variable instrID
	nvar ampsperteslaz
	wave/t outputvalstr
	variable current

	current = str2num(queryInstr(instrID,"RDGI?\r\n", read_term = "\r\n"))
	
	return current
end


function getLS625field(instrID) // Units: mT
	variable instrID
	nvar ampsperteslaz
	variable field, current
	
	current = getLS625current(instrID)
	field = Round_Number(current/ampsperteslaz*1000,5)

	return field
end

function getL625allfield(instrIDx,instrIDz) // Units: mT
	variable instrIDx,instrIDz
	make/n=2/o fieldwave

	fieldwave[0] = getLS625field(instrIDx)
	fieldwave[1] = getLS625field(instrIDz)
end

function getLS625rate(instrID) // Units: mT/min
	variable instrID
	nvar ampsperteslax,ampsperteslaz
	wave/t sweepratevalstr
	variable rampratefield, currentramprate
	svar instrDescX,instrDescZ

	string l625 = getResourceAddress(instrID)

	currentramprate = str2num(queryInstr(instrID,"RATE?\r\n", read_term = "\r\n")) // A/s
	// Update control window
	if(cmpstr(l625,instrDescX)==0)
		rampratefield = Round_Number(currentramprate/ampsperteslax*60*1000,5)
		sweepratevalstr[0][1] = num2str(rampratefield)
	elseif(cmpstr(l625,instrDescZ)==0)
		rampratefield = Round_Number(currentramprate/ampsperteslaz*60*1000,5)
		sweepratevalstr[1][1] = num2str(rampratefield)
	else
		abort "Couldn't determine which axis to address"
	endif

	return rampratefield
end

function getLS625allrate(instrIDx,instrIDz)
	variable instrIDx,instrIDz
	make/o/n=2 sweepratewave

	sweepratewave[0] = getLS625rate(instrIDx)
	sweepratewave[1] = getLS625rate(instrIDz)
end

////////////////////////
//// Set functions ////
//////////////////////

function setLS625current(instrID,output) // Units: A
	variable instrID,output
	string cmd
	nvar maxfieldz,ampsperteslaz
	
	// check for NAN and INF
	if(sc_check_naninf(output) != 0)
		abort "trying to set output to NaN or Inf"
	endif


	if (abs(output) > maxfieldz*ampsperteslaz/1000)
		print "Max current is "+num2str(maxfieldz*ampsperteslaz/1000)+" A"
	else
		cmd = "SETI "+num2str(output)
		writeInstr(instrID, cmd+"\r\n")
	endif
	
end

function setLS625field(instrID,output) // Units: mT
	variable instrID, output
	nvar maxfieldz,ampsperteslaz
	variable round_amps
	string cmd

	if (abs(output) > maxfieldz)
		print "Max field is "+num2str(maxfieldz)+" mT"
		return 0
	else
		round_amps = Round_Number(output*ampsperteslaz/1000,5)
		setLS625current(instrID,round_amps)
		return 1
	endif
end

function setLS625fieldwait(instrID,output)
	variable instrID, output

	setLS625field(instrID,output)
	do
		sc_sleep(0.1)
		getLS625field(instrID)
	while(checkLS625ramp(instrID))
end

function setLS625rate(instrID,output) // Units: mT/min
	variable instrID, output
	nvar maxrampratez,ampsperteslaz
	variable ramprate_amps
	string cmd
	
	// check for NAN and INF
	if(sc_check_naninf(output) != 0)
		abort "trying to set ramp rate to NaN or Inf"
	endif


	if (output < 0 || output > maxrampratez)
		print "Max sweep rate is "+num2str(maxrampratez)+" mT/min"
		return 0
	else
		ramprate_amps = Round_Number(output*(ampsperteslaz/(1000*60)),5) // A/s
		cmd = "RATE "+num2str(ramprate_amps)
		writeInstr(instrID,cmd+"\r\n")
		return 1
	endif
	
end

///////////////////
//// Utilities ////
///////////////////

function Round_Number(number,decimalplace) //for integer pass 0 as decimalplace
	variable number, decimalplace
	variable multiplier
	multiplier = 10^decimalplace
	return round(number*multiplier)/multiplier
end

function RoundtoZero(input)
	variable input

	if(abs(input) < 1e-03)
		input=0
	endif

	return input
end

function checkLS625ramp(instrID)
	variable instrID
	string response
	variable ramping

	response = queryInstr(instrID,"OPST?\r\n",read_term = "\r\n")
	if(str2num(response) == 6)
		ramping = 0
	else
		ramping = 1
	endif

	return ramping
end

//////////////////
//// Logging /////
//////////////////

function/s GetLS625Status(instrIDx,instrIDz)
	variable instrIDx,instrIDz
	string buffer = "", subbuffer = ""

	subbuffer = ""
	subbuffer = addJSONkeyval(subbuffer, "x", num2str(getLS625field(instrIDx)))
	subbuffer = addJSONkeyval(subbuffer, "z", num2str(getLS625field(instrIDz)))
	buffer = addJSONkeyval(buffer, "field mT", subbuffer)

	subbuffer = ""
	subbuffer = addJSONkeyval(subbuffer, "x", num2str(getLS625rate(instrIDx)))
	subbuffer = addJSONkeyval(subbuffer, "z", num2str(getLS625rate(instrIDz)))
	buffer = addJSONkeyval(buffer, "rate mT/min", subbuffer)

	return addJSONkeyval("", "Two Axis Magnet", buffer)
end
