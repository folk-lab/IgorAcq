#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


// DMM Procedures
// works for HP34401A and HP????
// Nik and Elyjah 8/17
// Async support added by Christian Olsen, May 2018

///////////////////////////////
///// 34401A specific COM /////
///////////////////////////////

function openHP34401Aconnection(instrID, visa_address, [verbose])
	// works for GPIB -- may need to add some more 'option' paramters if using serial
	//                -- does not hurt to send extra parameters when using GPIB, they are ignored
	// instrID is the name of the global variable that will be used for communication
	// visa_address is the VISA address string, i.e. GPIB0::23::INSTR
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
		VISAerrormsg("open HP34401A connection:", localRM, status)
		abort
	endif
	
	string comm = ""
	sprintf comm, "name=HP34401A,instrID=%s,visa_address=%s" instrID, visa_address
	string options = "test_query=*IDN?"
	openVISAinstr(comm, options=options, localRM=localRM, verbose=verbose)
	
end

/////////////////////
///// Init mode /////
////////////////////

function  setup34401Adcvolts(instrID, range, linecycles)
	// setup dmm to take dc voltage readings
	Variable instrID, range, linecycles
	// Ranges: 0.1, 1, 10, 100, 1000V
	// Linecycles: 0.02, 0.2, 1, 10, 100 (60Hz cycles)

	// autozero off (set in this function) with 1NPLC gives 5.5 digits of resolution
	// according to the manual
	// this is a pretty good default and makes the read time comparable to an srs830

	writeInstr(instrID,"*RST\r\n")
	sc_sleep(0.05)
	writeInstr(instrID,"*CLS\r\n")
	sc_sleep(0.05)
	writeInstr(instrID,"conf:volt:dc "+num2str(range)+"\r\n")
	sc_sleep(0.05)
	writeInstr(instrID,"zero:auto off\r\n")
	sc_sleep(0.05)
	writeInstr(instrID,"volt:dc:nplc "+num2str(linecycles)+"\r\n")
end

function  setup34401Aacvolts(instrID, range, linecycles)
	// setup dmm to take dc voltage readings
	Variable instrID, range, linecycles
	// Ranges: 0.1, 1, 10, 100, 1000V
	// Linecycles: 0.02, 0.2, 1, 10, 100 (60Hz cycles)

	// autozero off (set in this function) with 1NPLC gives 5.5 digits of resolution
	// according to the manual
	// this is a pretty good default and makes the read time comparable to an srs830

	writeInstr(instrID,"*RST\r\n")
	sc_sleep(0.05)
	writeInstr(instrID,"*CLS\r\n")
	sc_sleep(0.05)
	writeInstr(instrID,"conf:volt:ac "+num2str(range)+"\r\n")
	sc_sleep(0.05)
	writeInstr(instrID,"zero:auto off\r\n")
	sc_sleep(0.05)
	writeInstr(instrID,"volt:dc:nplc "+num2str(linecycles)+"\r\n")
end

/////////////////////
//// Utility ///////
///////////////////

function/s get34401AIDN(instrID)
	variable instrID

	return queryInstr(instrID,"*IDN?\r\n",read_term="\r\n")
end

function get34401Ajunk(instrID)
	// for those times when your dmm gpib got messed up and there's something in the buffer, and
	// your scans are always off by some buffered reading... call this procedure.
	variable instrID
	string response
	variable i=0

	do
		VisaRead /N=1/Q/T="\r\n" instrID, response
		print i, V_flag, response
		i+=1
	while(V_flag > 0)
	printf "this read %d characters of junk \r", i-1
end

function geterrors34401A(instrID)
	variable instrID
	string response
	variable i=1

	do
		response = queryInstr(instrID,"SYST:ERR?\r\n",read_term="\r\n")
		print num2str(i) + ":  " + response
		if(stringmatch(response[0,1],"+0")==1 || i>19)
			break
		endif
		i+=1
	while(1==1)
end

function setspeed34401A(instrID, speed)
	variable instrID, speed
	string linecycles="1"

	if (speed == -2)
		linecycles = ".02"
	elseif (speed == -1)
		linecycles = ".2"
	elseif (speed == 0)
		linecycles = "1"
	elseif (speed == 1)
		linecycles = "10"
	elseif (speed == 2)
		linecycles = "100"
	endif

	writeInstr(instrID,"volt:dc:nplc "+linecycles+"\r\n")
end

function/s check34401Aconfig(instrID)
	variable instrID

	return queryInstr(instrID,"CONF?\r\n",read_term="\r\n")
end

// more fun than useful!
function settext34401A(instrID, text)
	variable instrID
	string text

	sprintf text, ":DISP:TEXT '%s'\r\n", text
	writeInstr(instrID,text)
end

////////////////////////
//// get functions ////
///////////////////////

threadsafe function read34401A(instrID)
	Variable instrID
	string response

	response = queryInstr(instrID,"READ?\r\n",read_term="\r\n")
	variable reading = str2num(response)
	if(reading > 2^64)
		return NaN
	else
		return reading
	endif
end

/////////////////////////
//// Status function ////
////////////////////////

function/s get34401AStatus(instrID)
	variable instrID
	string  buffer = ""
	string temp = ""
	string gpib = num2istr(getAddressGPIB(instrID))
	buffer = addJSONkeyval(buffer, "gpib_address", gpib)

	// get configuration
	string config = TrimString(check34401Aconfig(instrID))
	variable i=0
	do
		if(CmpStr(config[i], "+")==0 || CmpStr(config[i], "-")==0)
			break
		endif
		i+=1
	while(i<strlen(config))
	buffer = addJSONkeyval(buffer, "units", TrimString(config[1,i-1]), addQuotes=1)
	
	temp = StringFromList(0, config[i,strlen(config)-2],",")
	if (cmpstr(temp[0], "+")==0)  // Not valid JSON to start with +
		temp = temp[1, strlen(temp)-1]
	endif
	buffer = addJSONkeyval(buffer, "range", temp)
	
	temp = StringFromList(1, config[i,strlen(config)-2],",")
	if (cmpstr(temp[0], "+")==0)  // Not valid JSON to start with +
		temp = temp[1, strlen(temp)-1]
	endif
	buffer = addJSONkeyval(buffer, "resolution", temp)

	return addJSONkeyval("", "HP34401A_"+gpib, buffer)
end
