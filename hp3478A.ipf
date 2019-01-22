#pragma rtGlobals=1		// Use modern global access method.

// HP3478A proceedure
// Written (mostly) by Nik 05-01-2018

// TODO:
//    Figure out how to interpret binary responses in error and status strings

/////////////////////////
///// setup HP3478A /////
/////////////////////////

function openHP3478Aconnection(instrID, visa_address, [verbose])
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
		VISAerrormsg("open HP3478A connection:", localRM, status)
		abort
	endif
	
	string comm = ""
	sprintf comm, "name=HP3478A,instrID=%s,visa_address=%s" instrID, visa_address
	string options = ""
	openVISAinstr(comm, options=options, localRM=localRM, verbose=verbose)
	
end

function  setup3478Adcvolts(instrID, range, linecycles)
	// setup dmm to take dc voltage readings
	// Ranges: 0.03, 0.3, 3, 30, 300V
	// Linecycles: 0.1, 1, 10 (60Hz cycles)
	// autozero off (set in this function) with 1NPLC gives 5.5 digits of resolution
	// according to the manual
	// this is a pretty good default and makes the read time comparable to an srs830
	Variable instrID, range, linecycles

	writeInstr(instrID, "F1\n")   // set to measure DC voltage
	set3478Arange(instrID, range)     // set range
	set3478Arate(instrID, linecycles) // set NPLC
	writeInstr(instrID, "Z0\n")   // autozero off

end

///////////////////
///// set/get /////
///////////////////

function set3478Arange(instrID, range)
	// Ranges: 0.03, 0.3, 3, 30, 300V
	Variable instrID, range
	string cmd = ""

	if(range == 0.03)
		cmd = "R-2"
	elseif(range == 0.3)
		cmd = "R-1"
	elseif(range == 3)
		cmd = "R0"
	elseif(range == 30)
		cmd = "R1"
	elseif(range == 300)
		cmd = "R2"
	else
		print "[WARNING] Unknown range (HP3478A) -- set to 3V"
		cmd = "R0"
	endif

	writeInstr(instrID, cmd+"\n")
end

function set3478Arate(instrID, linecycles)
	// Linecycles: 0.1, 1, 10 (60Hz cycles)
	Variable instrID, linecycles
	string cmd = ""

	if(linecycles == 0.1)
		cmd = "N3"
	elseif(linecycles == 1)
		cmd = "N4"
	elseif(linecycles == 10)
		cmd = "N5"
	else
		print "[WARNING] Unknown rate (HP3478A) -- set to 1NPLC"
		cmd = "R0"
	endif

	writeInstr(instrID, cmd+"\n")
end

function set3478Atext(instrID, text)
	// set text = "" to reset display
	variable instrID
	string text
	string cmd = ""

	if(strlen(text) == 0)
   	cmd = "D1"
	else
		sprintf cmd, "D3%s", text
	endif
	writeInstr(instrID, cmd+"\n")
end

function /S get3478Ainput(instrID)
	// check if reading from front or rear inputs
	variable instrID
	string response = ""

	switch(str2num(queryInstr(instrID, "S\n", read_term = "\n")))
		case 0:
			return "rear"
		case 1:
			return "front"
		default:
			return "[WARNING] Unknown HP3478A input state"
	endswitch
end

/////////////////
//// readings ///
/////////////////

threadsafe function read3478A(instrID)
	// once everything is setup in the
	// proper mode, the device just keeps putting
	// new points into the buffer
	// viRead until \n gets the most recent buffered reading
	Variable instrID

	string response = readInstr(instrID, read_term = "\n")
	return str2num(response)
end

/////////////////////////
//// Status functions ///
/////////////////////////

function errors3478A(instrID)
	variable instrID

	// get error bytes
	string errors
	writeInstr(instrID, "B\n")
	VISAReadBinary /Q /S=2 /T="\n" instrID, errors
	printf "%s\r", errors

end

function /s GetDMMStatus(instrID)
	variable instrID
//	string  buffer = ""
//
//	string gpib = num2istr(getAddressGPIB(instrID))
//	buffer = addJSONkeyvalpair(buffer, "gpib_address", gpib)
//
//	// get configuration
//	writeInstr(instrID, "B\n")
//	string config = readInstr(instrID, read_bytes=5)
//
//	buffer = addJSONkeyvalpair(buffer, "config_bytes", TrimString(config), addQuotes=1)
//
//	return addJSONkeyvalpair("", "HP3478A"+gpib, buffer)
end
