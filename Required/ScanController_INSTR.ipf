#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//////////////////////////////
/// generic VISA functions ///
//////////////////////////////

function killVISA()
	VISAControl killIO	  //Terminate all VISA sessions
	
end

function /s getResourceAddress(instrID)
	variable instrID
	string address=""
	viGetAttributeString(instrID, VI_ATTR_RSRC_NAME , address  )

	return address
end

threadsafe function VISAerrormsg(descriptor, localRM, status)
	String descriptor			// string to identify where this problem originated, e.g., viRead
	Variable localRM			// Session ID obtained from viOpen
	Variable status				// Status code from VISA library

	String desc

	viStatusDesc(localRM, status, desc)
	Printf "%s error (%x): %s\r", descriptor, status, desc

end

function openResourceManager()
	variable status, localRM

	// check for old call to viOpenDefaultRM and close it
	nvar /z globalRM
	if(nvar_exists(globalRM))
		viClose(globalRM)
	endif

	// open VISA session and store ID in localRM
	status = viOpenDefaultRM(localRM)
	if(status < 0)
		VISAerrormsg("OpenDefaultRM:", localRM, status)
		abort
	else
		variable /g globalRM = localRM
	endif

end

function openVISAinstr(mandatory, [options, localRM, verbose])

	string mandatory //  mandatory: "name= ,instrID= ,visa_address= "
	string options   //  options: "test_query= ,baudrate= ,stopbits= ,databits= ,parity= ,timeout= "

	variable localRM, verbose
	
	if(paramisdefault(options))
		options=""
	endif
	
	if(paramisdefault(verbose))
		verbose=1
	elseif(verbose!=1)
		verbose=0
	endif
	
	if(paramisdefault(localRM))
		nvar globalRM
		localRM = globalRM
	endif

	///// create VISA instance /////
	string name = StringByKey("name", mandatory, "=", ",")
	string var_name = StringByKey("instrID", mandatory, "=", ",")
	string instrDesc = StringByKey("visa_address", mandatory, "=", ",")
	
	// check if a global variable with var_name exists
	// if it does, close that VISA connection
	// this will prevent the experiment from hitting the 500 instrument limit
	nvar /z existingID = $(var_name)
	if(nvar_exists(existingID))
		closeVISAInstr(existingID, verbose=verbose)
		killvariables $var_name
	endif
	
	variable instrID, status
	string error
	status = viOpen(localRM,instrDesc,0,0,instrID)
	if (status < 0)
		VISAerrormsg("openInstr() -- viOpen", localRM, status)
		abort
	else 
		variable /g $var_name = instrID
		if(verbose)
			printf "%s (%s) connected as %s\r", name, instrDesc, var_name
		endif
	endif

	// look for optional parameters and set them
	if(strlen(options)!=0)
	
		setVISAoptions(instrID,options)
	
		// run test query
		string cmd
		cmd = StringByKey("test_query",options,"=", ",")
		if(strlen(cmd)>0)
		
			string response = queryInstr(instrID, cmd+"\r\n") // throw a bunch of write term characters at it
			
			if(cmpstr(TrimString(response), "NaN")==0)
				abort
			endif
			if(verbose)
				printf "\t-- %s responded to %s with: %s\r", name, cmd, response
			endif
		else
			if(verbose)
				printf "\t-- No test\r"
			endif
		endif
		
	endif
	
end

function closeVISAInstr(instrID, [verbose])
	variable instrID, verbose
	
	if(paramisdefault(verbose))
		verbose=1
	elseif(verbose!=1)
		verbose=0
	endif

	variable status = viClose(instrID)
	if (status < 0)
		if( verbose == 1)
			VISAerrormsg("closeInstr() -- viClose", instrID, status)
		endif
	else
		if (verbose ==1 )
			printf "closed VISA session ID: %d \n", instrID
		endif
	endif
	return status
end

function closeAllVISA()
	// closing the current VISA session will close all instruments
	nvar /z globalRM
	if(!nvar_exists(globalRM))
		print "[WARNING]: no global VISA session available to close"
		return 0
	else
		viClose(globalRM)
	endif
end

//////////////////
/// HTTP INSTR ///
//////////////////


function openHTTPinstr(mandatory, [options, verbose])
	string mandatory // mandatory: "name= ,instrID= ,url = "
	string options   // options: "test_ping= "
	variable verbose

	if(paramisdefault(options))
		options=""
	endif
	
	if(paramisdefault(verbose))
		verbose=1
	elseif(verbose!=1)
		verbose=0
	endif
	
	// create global variable
	string name = StringByKey("name", mandatory, "=", ",")
	string url = StringByKey("url", mandatory, "=", ",")
	string var_name = StringByKey("instrID", mandatory, "=", ",")

	string /g $var_name = url
	if(verbose==1)
		printf "%s (%s) connected as %s\r", name, url, var_name
	endif

	if(strlen(options)>0)
	
		// run test query
		string cmd
		cmd = StringByKey("test_ping",options,"=", ",")
		if(strlen(cmd)>0)
			
			// do something here with that command
			string response = ""
			
			if(verbose)
				printf "\t-- %s responded with: %s\r", name, response
			endif
		else
			if(verbose)
				printf "\t-- No test\r"
			endif
		endif

	endif

end

////////////////////////
/// READ/WRITE/QUERY ///
////////////////////////

threadsafe function writeInstr(instrID, cmd)
	// generic error checking write function
	variable instrID
	string cmd

    variable count = strlen(cmd) // strlen is a problem
                                 // with non-ascii characters
                                 // it does not equal numBytes
	
	 // printf "COMMAND: %s\r", cmd				// DEBUG
    variable return_count = 0    // how many bytes were written
    variable status = viWrite(instrID, cmd, count, return_count)
    if (status)
		VISAerrormsg("writeInstr() -- viWrite", instrID, status)
    	return NaN // abort not supported in threads (v7)
	endif

end

threadsafe function/s readInstr(instrID, [read_term, read_bytes, binary])
	// generic error checking read function
	// binary only ticked when reading long binary data from fdac
	variable instrID, read_bytes, binary
	string read_term

    if(!paramisdefault(read_term))
        // here we are going to make sure to use a
        // read termination character read_term
        visaSetReadTerm(instrID, read_term)
        visaSetReadTermEnable(instrID, 1)

    else
        // in this case it will read until some END signal
        // specified by the interface being used
        visaSetReadTermEnable(instrID, 0)
    endif
    
    if(!paramIsDefault(binary))
    	 visaSetSerialEndIn(instrID, 0)
   	 else
   	    binary = 0
   	 	 visaSetSerialEndIn(instrID, 2)
    endif

    if(paramisdefault(read_bytes))
        read_bytes = 1024
    endif

    string buffer, err
    variable return_count
    variable status = viRead(instrID, buffer, read_bytes, return_count)
    if(status != 0 && status != 0x3fff0006 && status != 0x3fff0005) // 0x3fff0006 means read_bytes = return_count (NOT AN ERROR).
        VISAerrormsg("readInstr() -- viRead", instrID, status)
    	return "NaN" // abort not supported in threads (v7)
	 endif
	 if(binary)
	 	if(read_bytes != return_count)
	 		sprintf err, "[ERROR] Returned bytes: %d. Expeted bytes: %d", return_count, read_bytes
	 		print err
	 		return "Nan"
	 	endif
	 endif
	 return buffer
end

threadsafe function/s queryInstr(instrID, cmd, [read_term, delay])
	// generic error checking query function
	variable instrID, delay
	string cmd, read_term
	string response
	
	writeInstr(instrID, cmd)
	if(!paramisdefault(delay))
		sleep/s delay
	endif
    if(paramisdefault(read_term))
        response = readInstr(instrID)
    else
        response = readInstr(instrID, read_term = read_term)
    endif
//	printf "RESPONSE: %s\r", response 		//DEBUG
	return response
end

function/s queryInstrProgress(instrID, cmd, delay, delaymsg, [read_term])
	variable instrID, delay
	string cmd, delaymsg, read_term
	
	writeInstr(instrID, cmd)
	
	sc_progressbarDelay(delay,delaymsg)
	
	string response = ""
	if(paramisdefault(read_term))
        response = readInstr(instrID)
    else
        response = readInstr(instrID, read_term = read_term)
    endif

	return response
end

function/s postHTTP(instrID,cmd,payload,headers)
	string instrID, cmd, payload, headers
	string response=""

//	print instrID+cmd, payload
	URLRequest /TIME=15.0 /DSTR=payload url=instrID+cmd, method=post, headers=headers

	if (V_flag == 0)    // No error
		response = S_serverResponse // response is a JSON string
		if (V_responseCode != 200)  // 200 is the HTTP OK code
			print "[ERROR] HTTP response code " + num2str(V_responseCode)
			if(strlen(response)>0)
		   	printf "[MESSAGE] %s\r", getJSONvalue(response, "error")
		   endif
		   return ""
		else
			return response
		endif
   else
        abort "HTTP connection error."
   endif
end


function/s putHTTP(instrID,cmd,payload,headers)
	string instrID, cmd, payload, headers
	string response=""

//	print instrID+cmd, payload
	URLRequest /TIME=15.0 /DSTR=payload url=instrID+cmd, method=put, headers=headers

	if (V_flag == 0)    // No error
		response = S_serverResponse // response is a JSON string
		if (V_responseCode != 200)  // 200 is the HTTP OK code
			print "[ERROR] HTTP response code " + num2str(V_responseCode)
			if(strlen(response)>0)
		   	printf "[MESSAGE] %s\r", getJSONvalue(response, "error")
		   endif
		   return ""
		else
			return response
		endif
   else
        abort "HTTP connection error."
   endif
end


function/s getHTTP(instrID,cmd,headers)
	string instrID, cmd, headers
	string response, error

	//print instrID+cmd
	URLRequest /TIME=25.0 url=instrID+cmd, method=get, headers=headers

	if (V_flag == 0)    // No error
		response = S_serverResponse // response is a JSON string
		//print response
		if (V_responseCode != 200)  // 200 is the HTTP OK code
			print "[ERROR] HTTP response code " + num2str(V_responseCode)
		   return ""
		else
			return response
		endif
   else
    	print "HTTP connection error."
		return ""
   endif
end

//// Util ////

function/s sc_stripTermination(visaString,termChar)
	string visaString, termChar
	
	string regex = "(.*)"+termChar, value=""
	splitstring/e=regex visaString, value
	
	return value
end

function sc_progressbarDelay(delay,delaymsg)
	variable delay
	string delaymsg
	
	variable/g progress = 0
	string/g progressStr = delaymsg
	execute("progressBar()")
	
	delay = delay*1e6
	variable start_time = stopMStimer(-2)
	do
		doupdate/w=ProgressBar
		progress = (stopMStimer(-2)-start_time)/delay*100 // progress in procent
		
	while(stopMStimer(-2)-start_time < delay)
	dowindow/k ProgressBar
end

window progressBar() : Panel
	PauseUpdate; Silent 1       // building window...
	NewPanel /W=(267+400,122+400,480+400,200+400)/N=ProgressBar
	SetDrawLayer UserBack
	SetDrawEnv fsize= 14
	DrawText 72,23, "Progress ..."
	ValDisplay valdispProgress,pos={8,28},size={200,15},mode=3,frame=2
	ValDisplay valdispProgress,limits={0,100,0},barmisc={0,0},bodyWidth=200
	ValDisplay valdispProgress,value=progress
	SetDrawEnv fsize= 14
	variable msglength = strlen(progressStr), doubleline = strsearch(progressStr,"\n",0)
	if(msglength > 0)
		if(doubleline < 0)
			DrawText 102-msglength*3,65, progressStr
		else
			DrawText 90-(msglength-doubleline)*3,77, progressStr
		endif
	endif
endmacro

////////////
/// GPIB ///
////////////

function gpibRENassert()
	nvar globalRM
	viGpibControlREN(globalRM, 1)  // assert remote control enable
end

function listGPIBinstr()
	// find all gpib address with an active device
	variable findlist=0, instrcnt=0, i=0
	string instrDesc="", instrtype, instrname, error, summary
	variable instrID

	// open resource manager
	nvar /z globalRM
	if(!nvar_exists(globalRM))
		openResourceManager()
		nvar globalRM
	endif
	
//	variable localRM
//	variable status = viOpenDefaultRM(localRM) // open local copy of resource manager
//	if(status < 0)
//		VISAerrormsg("[ERROR]: problem opening resource manager", localRM, status)
//		abort
//	endif
	variable status
	
	// print list of serial ports/instruments
	status = viFindRsrc(globalRM,"GPIB?*INSTR",findlist,instrcnt,instrDesc)
	if(status < 0)
		viStatusDesc(globalRM, status, error)
		VISAerrormsg("listGPIBAddress -- OpenDefaultRM:", instrID, status)
		return 0
	elseif(instrcnt==0)
		printf "viFindRsrc found no available GPIB devices"
		return 0
	endif

	for(i=0;i<instrcnt;i+=1)

		if(i!=0)
			viFindNext(findlist,instrDesc) // get the next instrument descriptor
		endif

		printf "%d) \t%s\r", i, instrDesc
	endfor

end

function getAddressGPIB(instrID)
	variable instrID
	variable gpib_address

	viGetAttribute(instrID,VI_ATTR_GPIB_PRIMARY_ADDR,gpib_address) // get primary adresse
	return gpib_address
end

//////////////
/// serial ///
//////////////

function /s getSerialInstrInfo(instrDesc, instrID)
	string instrDesc
	variable instrID
	variable status, baudrate
	string instrname, instrbaud, serialname, error, serialinfo=""

	// open resource manager
	nvar /z globalRM
	if(!nvar_exists(globalRM))
		openResourceManager()
		nvar globalRM
	endif

	// get full name
	status = viGetAttributeString(instrID, VI_ATTR_INTF_INST_NAME, serialname)
	if (status < 0)
		VISAerrormsg("getSerialInstrInfo -- viGetAttributeString:", instrID, status)
		abort
	else
		printf instrname, "serial object connected at %s is called: %s\r", instrDesc, serialname
		serialinfo += instrname
	endif

	// get baud rate
	status = viGetAttribute(instrID,VI_ATTR_ASRL_BAUD,baudrate)
	if (status < 0)
		VISAerrormsg("getSerialInstrInfo -- viGetAttribute:", instrID, status)
		abort
	else
		sprintf instrbaud, "baudrate set to: %g\r", baudrate
		serialinfo += instrbaud
	endif
end

function listSerialports()
	// find all serial (ports)
	variable status, findlist=0, instrcnt=0, i=0
	string instrDesc="", instrtype, instrname, error, summary
	variable instrID

	// open resource manager
	nvar /z globalRM
	if(!nvar_exists(globalRM))
		openResourceManager()
		nvar globalRM
	endif

	// print list of serial ports/instruments
	status = viFindRsrc(globalRM,"ASRL?*INSTR",findlist,instrcnt,instrDesc)
	if(status < 0)
		viStatusDesc(globalRM, status, error)
		printf "viFindRsrc error (serial): %s\r", error
		return 0
	elseif(instrcnt==0)
		printf "viFindRsrc found no available serial ports"
		return 0
	endif

	for(i=0;i<instrcnt;i+=1)

		if(i!=0)
			viFindNext(findlist,instrDesc) // get the next instrument descriptor
		endif

		printf "%d) \t%s\r", i, instrDesc
	endfor

end

/////////////////////////
/// VISA ATTR Set/Get ///
/////////////////////////

function setVISAoptions(instrID,options)
	variable instrID
	string options
	variable status=0

	variable i=0
	string keyval="", reg="(.*)=(.*)", key="", value=""
	for(i=0;i<ItemsInList(options, ",");i+=1)
		
		// get key/value from list
		keyval = StringFromList(i, options, ",")
		splitstring/E=reg keyval, key, value
		value = TrimString(value)
		
		if(strlen(value)==0)
			continue // if there is no value, move on
		endif
		status = 0
		strswitch(key)
			case "baudrate":
			    status = visaSetBaudRate(instrID, str2num(value))
			    break
			case "stopbits":
			    status = visaSetStopBits(instrID, str2num(value))
			    break
			case "databits":
			    status = visaSetDataBits(instrID, str2num(value))
			    break
			case "parity":
			    status = visaSetParity(instrID, str2num(value))
			    break
			case "timeout":
			    status = visaSetTimeout(instrID, str2num(value))
			    break
		endswitch
		
		if(status<0)
			VISAerrormsg("viSetAttribute "+key, instrID, status)
		endif
		
	endfor
end

threadsafe function visaSetReadTerm(instrID, termChar)
	// set the read termination character for this instrument
	variable instrID	// An instrument referenced obtained from viOpen
	string termChar     // set read termination character

	variable status
	status = viSetAttribute(instrID, VI_ATTR_TERMCHAR, char2num(termChar))
	return status
end

threadsafe function visaSetReadTermEnable(instrID, enable)
	// enable use of read termination character
	variable instrID	// An instrument referenced obtained from viOpen
	variable enable   // 1 = yes, 0 = no

	variable status
	status = viSetAttribute(instrID, VI_ATTR_TERMCHAR_EN, enable)
	return status
end

function visaSetTimeout(instrID, timeout) // timeout value in ms
	variable instrID, timeout
	variable status
	status = viSetAttribute(instrID, VI_ATTR_TMO_VALUE, timeout)
	return status
end

function visaSetBaudRate(instrID, baud)
	variable instrID	// An instrument referenced obtained from viOpen
	variable baud

	variable status
	status = viSetAttribute(instrID, VI_ATTR_ASRL_BAUD, baud)
	return status
end

function visaSetDataBits(instrID, bits)
	// acceptable values for data bits
    //   5, 6, 7, 8 (default)
	variable instrID	// An instrument referenced obtained from viOpen
	variable bits

	variable status
	status = viSetAttribute(instrID, VI_ATTR_ASRL_DATA_BITS, bits)
	return status
end

function visaSetStopBits(instrID, bits)
	// acceptable values for stop bits:
    //    1 (1 bit), 1.5 (1.5 bits), and 2.0 (2 bits)
	variable instrID	// An instrument referenced obtained from viOpen
	variable bits

	variable stopbits = 1
	if(bits == 1)
		stopbits = 10
	elseif(bits == 1.5)
		stopbits = 15
	elseif(bits == 	2)
		stopbits = 20
	endif
	
	variable status = viSetAttribute(instrID, VI_ATTR_ASRL_STOP_BITS, bits)
	
	return status
end

function visaSetSerialEndOut(instrID, out)
//	VI_ASRL_END_NONE (0)
//	VI_ASRL_END_LAST_BIT (1)
//	VI_ASRL_END_TERMCHAR (2)
//	VI_ASRL_END_BREAK (3)
	variable instrID, out

	variable status = viSetAttribute(instrID, VI_ATTR_ASRL_END_OUT, out)
	return status
end

threadsafe function visaSetSerialEndIn(instrID, in)
	variable instrID, in
	variable status = viSetAttribute(instrID, VI_ATTR_ASRL_END_IN, in)
	return status
end

function visaSetParity(instrID, parity)
	// acceptable values for parity:
   // VI_ASRL_PAR_NONE (0)
	// VI_ASRL_PAR_ODD (1)
	// VI_ASRL_PAR_EVEN (2)
	// VI_ASRL_PAR_MARK (3)
	// VI_ASRL_PAR_SPACE (4)

	variable instrID	// An instrument referenced obtained from viOpen
	variable parity

	variable status
	status = viSetAttribute(instrID, VI_ATTR_ASRL_PARITY, parity)
	return status
end

//////////////////////
/// VISA CONSTANTS ///
//////////////////////

/// Below are constant declarations for most of the standard VISA #defines ///

// Attributes
Constant VI_ATTR_RSRC_CLASS = 0xBFFF0001
Constant VI_ATTR_RSRC_NAME = 0xBFFF0002
Constant VI_ATTR_RSRC_IMPL_VERSION = 0x3FFF0003
Constant VI_ATTR_RSRC_LOCK_STATE = 0x3FFF0004
Constant VI_ATTR_MAX_QUEUE_LENGTH = 0x3FFF0005
Constant VI_ATTR_USER_DATA = 0x3FFF0007
Constant VI_ATTR_FDC_CHNL = 0x3FFF000D
Constant VI_ATTR_FDC_MODE = 0x3FFF000F
Constant VI_ATTR_FDC_GEN_SIGNAL_EN = 0x3FFF0011
Constant VI_ATTR_FDC_USE_PAIR = 0x3FFF0013
Constant VI_ATTR_SEND_END_EN = 0x3FFF0016
Constant VI_ATTR_TERMCHAR = 0x3FFF0018
Constant VI_ATTR_TMO_VALUE = 0x3FFF001A
Constant VI_ATTR_GPIB_READDR_EN = 0x3FFF001B
Constant VI_ATTR_IO_PROT = 0x3FFF001C
Constant VI_ATTR_DMA_ALLOW_EN = 0x3FFF001E
Constant VI_ATTR_ASRL_BAUD = 0x3FFF0021
Constant VI_ATTR_ASRL_DATA_BITS = 0x3FFF0022
Constant VI_ATTR_ASRL_PARITY = 0x3FFF0023
Constant VI_ATTR_ASRL_STOP_BITS = 0x3FFF0024
Constant VI_ATTR_ASRL_FLOW_CNTRL = 0x3FFF0025
Constant VI_ATTR_RD_BUF_OPER_MODE = 0x3FFF002A
Constant VI_ATTR_RD_BUF_SIZE = 0x3FFF002B
Constant VI_ATTR_WR_BUF_OPER_MODE = 0x3FFF002D
Constant VI_ATTR_WR_BUF_SIZE = 0x3FFF002E
Constant VI_ATTR_SUPPRESS_END_EN = 0x3FFF0036
Constant VI_ATTR_TERMCHAR_EN = 0x3FFF0038
Constant VI_ATTR_DEST_ACCESS_PRIV = 0x3FFF0039
Constant VI_ATTR_DEST_BYTE_ORDER = 0x3FFF003A
Constant VI_ATTR_SRC_ACCESS_PRIV = 0x3FFF003C
Constant VI_ATTR_SRC_BYTE_ORDER = 0x3FFF003D
Constant VI_ATTR_SRC_INCREMENT = 0x3FFF0040
Constant VI_ATTR_DEST_INCREMENT = 0x3FFF0041
Constant VI_ATTR_WIN_ACCESS_PRIV = 0x3FFF0045
Constant VI_ATTR_WIN_BYTE_ORDER = 0x3FFF0047
Constant VI_ATTR_GPIB_ATN_STATE = 0x3FFF0057
Constant VI_ATTR_GPIB_ADDR_STATE = 0x3FFF005C
Constant VI_ATTR_GPIB_CIC_STATE = 0x3FFF005E
Constant VI_ATTR_GPIB_NDAC_STATE = 0x3FFF0062
Constant VI_ATTR_GPIB_SRQ_STATE = 0x3FFF0067
Constant VI_ATTR_GPIB_SYS_CNTRL_STATE = 0x3FFF0068
Constant VI_ATTR_GPIB_HS488_CBL_LEN = 0x3FFF0069
Constant VI_ATTR_CMDR_LA = 0x3FFF006B
Constant VI_ATTR_VXI_DEV_CLASS = 0x3FFF006C
Constant VI_ATTR_MAINFRAME_LA = 0x3FFF0070
Constant VI_ATTR_MANF_NAME = 0xBFFF0072
Constant VI_ATTR_MODEL_NAME = 0xBFFF0077
Constant VI_ATTR_VXI_VME_INTR_STATUS = 0x3FFF008B
Constant VI_ATTR_VXI_TRIG_STATUS = 0x3FFF008D
Constant VI_ATTR_VXI_VME_SYSFAIL_STATE = 0x3FFF0094
Constant VI_ATTR_WIN_BASE_ADDR = 0x3FFF0098
Constant VI_ATTR_WIN_SIZE = 0x3FFF009A
Constant VI_ATTR_ASRL_AVAIL_NUM = 0x3FFF00AC
Constant VI_ATTR_MEM_BASE = 0x3FFF00AD
Constant VI_ATTR_ASRL_CTS_STATE = 0x3FFF00AE
Constant VI_ATTR_ASRL_DCD_STATE = 0x3FFF00AF
Constant VI_ATTR_ASRL_DSR_STATE = 0x3FFF00B1
Constant VI_ATTR_ASRL_DTR_STATE = 0x3FFF00B2
Constant VI_ATTR_ASRL_END_IN = 0x3FFF00B3
Constant VI_ATTR_ASRL_END_OUT = 0x3FFF00B4
Constant VI_ATTR_ASRL_REPLACE_CHAR = 0x3FFF00BE
Constant VI_ATTR_ASRL_RI_STATE = 0x3FFF00BF
Constant VI_ATTR_ASRL_RTS_STATE = 0x3FFF00C0
Constant VI_ATTR_ASRL_XON_CHAR = 0x3FFF00C1
Constant VI_ATTR_ASRL_XOFF_CHAR = 0x3FFF00C2
Constant VI_ATTR_WIN_ACCESS = 0x3FFF00C3
Constant VI_ATTR_RM_SESSION = 0x3FFF00C4
Constant VI_ATTR_VXI_LA = 0x3FFF00D5
Constant VI_ATTR_MANF_ID = 0x3FFF00D9
Constant VI_ATTR_MEM_SIZE = 0x3FFF00DD
Constant VI_ATTR_MEM_SPACE = 0x3FFF00DE
Constant VI_ATTR_MODEL_CODE = 0x3FFF00DF
Constant VI_ATTR_SLOT = 0x3FFF00E8
Constant VI_ATTR_INTF_INST_NAME = 0xBFFF00E9
Constant VI_ATTR_IMMEDIATE_SERV = 0x3FFF0100
Constant VI_ATTR_INTF_PARENT_NUM = 0x3FFF0101
Constant VI_ATTR_RSRC_SPEC_VERSION = 0x3FFF0170
Constant VI_ATTR_INTF_TYPE = 0x3FFF0171
Constant VI_ATTR_GPIB_PRIMARY_ADDR = 0x3FFF0172
Constant VI_ATTR_GPIB_SECONDARY_ADDR = 0x3FFF0173
Constant VI_ATTR_RSRC_MANF_NAME = 0xBFFF0174
Constant VI_ATTR_RSRC_MANF_ID = 0x3FFF0175
Constant VI_ATTR_INTF_NUM = 0x3FFF0176
Constant VI_ATTR_TRIG_ID = 0x3FFF0177
Constant VI_ATTR_GPIB_REN_STATE = 0x3FFF0181
Constant VI_ATTR_GPIB_UNADDR_EN = 0x3FFF0184
Constant VI_ATTR_DEV_STATUS_BYTE = 0x3FFF0189
Constant VI_ATTR_FILE_APPEND_EN = 0x3FFF0192
Constant VI_ATTR_VXI_TRIG_SUPPORT = 0x3FFF0194
Constant VI_ATTR_TCPIP_ADDR = 0xBFFF0195
Constant VI_ATTR_TCPIP_HOSTNAME = 0xBFFF0196
Constant VI_ATTR_TCPIP_PORT = 0x3FFF0197
Constant VI_ATTR_TCPIP_DEVICE_NAME = 0xBFFF0199
Constant VI_ATTR_TCPIP_NODELAY = 0x3FFF019A
Constant VI_ATTR_TCPIP_KEEPALIVE = 0x3FFF019B
Constant VI_ATTR_4882_COMPLIANT = 0x3FFF019F
Constant VI_ATTR_USB_SERIAL_NUM = 0xBFFF01A0
Constant VI_ATTR_USB_INTFC_NUM = 0x3FFF01A1
Constant VI_ATTR_USB_PROTOCOL = 0x3FFF01A7
Constant VI_ATTR_USB_MAX_INTR_SIZE = 0x3FFF01AF

Constant VI_ATTR_JOB_ID = 0x3FFF4006
Constant VI_ATTR_EVENT_TYPE = 0x3FFF4010
Constant VI_ATTR_SIGP_STATUS_ID = 0x3FFF4011
Constant VI_ATTR_RECV_TRIG_ID = 0x3FFF4012
Constant VI_ATTR_INTR_STATUS_ID = 0x3FFF4023
Constant VI_ATTR_STATUS = 0x3FFF4025
Constant VI_ATTR_RET_COUNT = 0x3FFF4026
Constant VI_ATTR_BUFFER = 0x3FFF4027
Constant VI_ATTR_RECV_INTR_LEVEL = 0x3FFF4041
Constant VI_ATTR_OPER_NAME = 0xBFFF4042
Constant VI_ATTR_GPIB_RECV_CIC_STATE = 0x3FFF4193
Constant VI_ATTR_RECV_TCPIP_ADDR = 0xBFFF4198
Constant VI_ATTR_USB_RECV_INTR_SIZE = 0x3FFF41B0
Constant VI_ATTR_USB_RECV_INTR_DATA = 0xBFFF41B1

// Event Types
Constant VI_EVENT_IO_COMPLETION = 0x3FFF2009
Constant VI_EVENT_TRIG = 0xBFFF200A
Constant VI_EVENT_SERVICE_REQ = 0x3FFF200B
Constant VI_EVENT_CLEAR = 0x3FFF200D
Constant VI_EVENT_EXCEPTION = 0xBFFF200E
Constant VI_EVENT_GPIB_CIC = 0x3FFF2012
Constant VI_EVENT_GPIB_TALK = 0x3FFF2013
Constant VI_EVENT_GPIB_LISTEN = 0x3FFF2014
Constant VI_EVENT_VXI_VME_SYSFAIL = 0x3FFF201D
Constant VI_EVENT_VXI_VME_SYSRESET = 0x3FFF201E
Constant VI_EVENT_VXI_SIGP = 0x3FFF2020
Constant VI_EVENT_VXI_VME_INTR = 0xBFFF2021
Constant VI_EVENT_TCPIP_CONNECT = 0x3FFF2036
Constant VI_EVENT_USB_INTR = 0x3FFF2037
Constant VI_ALL_ENABLED_EVENTS = 0x3FFF7FFF

Constant VI_SUCCESS = 0					// From visatype.h
Constant VI_NULL = 0						// From visatype.h
Constant VI_TRUE = 1						// From visatype.h
Constant VI_FALSE = 0						// From visatype.h

// Completion and Error Codes
Constant VI_SUCCESS_EVENT_EN = 0x3FFF0002
Constant VI_SUCCESS_EVENT_DIS = 0x3FFF0003
Constant VI_SUCCESS_QUEUE_EMPTY = 0x3FFF0004
Constant VI_SUCCESS_TERM_CHAR = 0x3FFF0005
Constant VI_SUCCESS_MAX_CNT = 0x3FFF0006
Constant VI_SUCCESS_DEV_NPRESENT = 0x3FFF007D
Constant VI_SUCCESS_TRIG_MAPPED = 0x3FFF007E
Constant VI_SUCCESS_QUEUE_NEMPTY = 0x3FFF0080
Constant VI_SUCCESS_NCHAIN = 0x3FFF0098
Constant VI_SUCCESS_NESTED_SHARED = 0x3FFF0099
Constant VI_SUCCESS_NESTED_EXCLUSIVE = 0x3FFF009A
Constant VI_SUCCESS_SYNC = 0x3FFF009B

Constant VI_WARN_QUEUE_OVERFLOW = 0x3FFF000C
Constant VI_WARN_CONFIG_NLOADED = 0x3FFF0077
Constant VI_WARN_NULL_OBJECT = 0x3FFF0082
Constant VI_WARN_NSUP_ATTR_STATE = 0x3FFF0084
Constant VI_WARN_UNKNOWN_STATUS = 0x3FFF0085
Constant VI_WARN_NSUP_BUF = 0x3FFF0088
Constant VI_WARN_EXT_FUNC_NIMPL = 0x3FFF00A9

Constant VI_ERROR_SYSTEM_ERROR = -1073807360			// 0xBFFF0000
Constant VI_ERROR_INV_OBJECT = -1073807346				// 0xBFFF000E
Constant VI_ERROR_RSRC_LOCKED = -1073807345			// 0xBFFF000F
Constant VI_ERROR_INV_EXPR = -1073807344				// 0xBFFF0010
Constant VI_ERROR_RSRC_NFOUND = -1073807343			// 0xBFFF0011
Constant VI_ERROR_INV_RSRC_NAME = -1073807342			// 0xBFFF0012
Constant VI_ERROR_INV_ACC_MODE = -1073807341			// 0xBFFF0013
Constant VI_ERROR_TMO = -1073807339						// 0xBFFF0015
Constant VI_ERROR_CLOSING_FAILED = -1073807338		// 0xBFFF0016
Constant VI_ERROR_INV_DEGREE = -1073807333				// 0xBFFF001B
Constant VI_ERROR_INV_JOB_ID = -1073807332				// 0xBFFF001C
Constant VI_ERROR_NSUP_ATTR = -1073807331				// 0xBFFF001D
Constant VI_ERROR_NSUP_ATTR_STATE = -1073807330		// 0xBFFF001E
Constant VI_ERROR_ATTR_READONLY = -1073807329			// 0xBFFF001F
Constant VI_ERROR_INV_LOCK_TYPE = -1073807328			// 0xBFFF0020
Constant VI_ERROR_INV_ACCESS_KEY = -1073807327		// 0xBFFF0021
Constant VI_ERROR_INV_EVENT = -1073807322				// 0xBFFF0026
Constant VI_ERROR_INV_MECH = -1073807321				// 0xBFFF0027
Constant VI_ERROR_HNDLR_NINSTALLED = -1073807320		// 0xBFFF0028
Constant VI_ERROR_INV_HNDLR_REF = -1073807319			// 0xBFFF0029
Constant VI_ERROR_INV_CONTEXT = -1073807318			// 0xBFFF002A
Constant VI_ERROR_QUEUE_OVERFLOW = -1073807315		// 0xBFFF002D
Constant VI_ERROR_NENABLED = -1073807313				// 0xBFFF002F
Constant VI_ERROR_ABORT = -1073807312						// 0xBFFF0030
Constant VI_ERROR_RAW_WR_PROT_VIOL = -1073807308		// 0xBFFF0034
Constant VI_ERROR_RAW_RD_PROT_VIOL = 1073807307		// 0xBFFF0035
Constant VI_ERROR_OUTP_PROT_VIOL = -1073807306		// 0xBFFF0036
Constant VI_ERROR_INP_PROT_VIOL = -1073807305			// 0xBFFF0037
Constant VI_ERROR_BERR = -1073807304						// 0xBFFF0038
Constant VI_ERROR_IN_PROGRESS = -1073807303			// 0xBFFF0039
Constant VI_ERROR_INV_SETUP = -1073807302				// 0xBFFF003A
Constant VI_ERROR_QUEUE_ERROR = -1073807301			// 0xBFFF003B
Constant VI_ERROR_ALLOC = -1073807300						// 0xBFFF003C
Constant VI_ERROR_INV_MASK = -1073807299				// 0xBFFF003D
Constant VI_ERROR_IO = -1073807298							// 0xBFFF003E
Constant VI_ERROR_INV_FMT = -1073807297					// 0xBFFF003F
Constant VI_ERROR_NSUP_FMT = -1073807295				// 0xBFFF0041
Constant VI_ERROR_LINE_IN_USE = -1073807294			// 0xBFFF0042
Constant VI_ERROR_NSUP_MODE = -1073807290				// 0xBFFF0046
Constant VI_ERROR_SRQ_NOCCURRED = -1073807286			// 0xBFFF004A
Constant VI_ERROR_INV_SPACE = -1073807282				// 0xBFFF004E
Constant VI_ERROR_INV_OFFSET = -1073807279				// 0xBFFF0051
Constant VI_ERROR_INV_WIDTH = -1073807278				// 0xBFFF0052
Constant VI_ERROR_NSUP_OFFSET = -1073807276			// 0xBFFF0054
Constant VI_ERROR_NSUP_VAR_WIDTH = -1073807275		// 0xBFFF0055
Constant VI_ERROR_WINDOW_NMAPPED = -1073807273		// 0xBFFF0057
Constant VI_ERROR_RESP_PENDING = -1073807271			// 0xBFFF0059
Constant VI_ERROR_NLISTENERS = -1073807265				// 0xBFFF005F
Constant VI_ERROR_NCIC = -1073807264						// 0xBFFF0060
Constant VI_ERROR_NSYS_CNTLR = -1073807263				// 0xBFFF0061
Constant VI_ERROR_NSUP_OPER = -1073807257				// 0xBFFF0067
Constant VI_ERROR_INTR_PENDING = -1073807256			// 0xBFFF0068
Constant VI_ERROR_ASRL_PARITY = -1073807254			// 0xBFFF006A
Constant VI_ERROR_ASRL_FRAMING = -1073807253			// 0xBFFF006B
Constant VI_ERROR_ASRL_OVERRUN = -1073807252			// 0xBFFF006C
Constant VI_ERROR_TRIG_NMAPPED = -1073807250			// 0xBFFF006E
Constant VI_ERROR_NSUP_ALIGN_OFFSET = -1073807248	// 0xBFFF0070
Constant VI_ERROR_USER_BUF = -1073807247				// 0xBFFF0071
Constant VI_ERROR_RSRC_BUSY = -1073807246				// 0xBFFF0072
Constant VI_ERROR_NSUP_WIDTH = -1073807242				// 0xBFFF0076
Constant VI_ERROR_INV_PARAMETER = -1073807240			// 0xBFFF0078
Constant VI_ERROR_INV_PROT = -1073807239				// 0xBFFF0079
Constant VI_ERROR_INV_SIZE = -1073807237				// 0xBFFF007B
Constant VI_ERROR_WINDOW_MAPPED = -1073807232			// 0xBFFF0080
Constant VI_ERROR_NIMPL_OPER = -1073807231				// 0xBFFF0081
Constant VI_ERROR_INV_LENGTH = -1073807229				// 0xBFFF0083
Constant VI_ERROR_INV_MODE = -1073807215				// 0xBFFF0091
Constant VI_ERROR_SESN_NLOCKED = -1073807204			// 0xBFFF009C
Constant VI_ERROR_MEM_NSHARED = -1073807203			// 0xBFFF009D
Constant VI_ERROR_LIBRARY_NFOUND = -1073807202		// 0xBFFF009E
Constant VI_ERROR_NSUP_INTR = -1073807201				// 0xBFFF009F
Constant VI_ERROR_INV_LINE = -1073807200				// 0xBFFF00A0
Constant VI_ERROR_FILE_ACCESS = -1073807199			// 0xBFFF00A1
Constant VI_ERROR_FILE_IO = -1073807198					// 0xBFFF00A2
Constant VI_ERROR_NSUP_LINE = -1073807197				// 0xBFFF00A3
Constant VI_ERROR_NSUP_MECH = -1073807196				// 0xBFFF00A4
Constant VI_ERROR_INTF_NUM_NCONFIG = -1073807195		// 0xBFFF00A5
Constant VI_ERROR_CONN_LOST = 1073807194				// 0xBFFF00A6
Constant VI_ERROR_MACHINE_NAVAIL = -1073807193		// 0xBFFF00A7
Constant VI_ERROR_NPERMISSION = -1073807192			// 0xBFFF00A8

// Other VISA Definitions
Constant VI_INTF_GPIB = 1
Constant VI_INTF_VXI = 2
Constant VI_INTF_GPIB_VXI = 3
Constant VI_INTF_ASRL = 4
Constant VI_INTF_TCPIP = 6
Constant VI_INTF_USB = 7

Constant VI_PROT_NORMAL = 1
Constant VI_PROT_FDC = 2
Constant VI_PROT_HS488 = 3
Constant VI_PROT_4882_STRS = 4
Constant VI_PROT_USBTMC_VENDOR = 5

Constant VI_FDC_NORMAL = 1
Constant VI_FDC_STREAM = 2

Constant VI_LOCAL_SPACE = 0
Constant VI_A16_SPACE = 1
Constant VI_A24_SPACE = 2
Constant VI_A32_SPACE = 3
Constant VI_OPAQUE_SPACE = -1	// 0xFFFF

Constant VI_UNKNOWN_LA = -1
Constant VI_UNKNOWN_SLOT = -1
Constant VI_UNKNOWN_LEVEL = -1

Constant VI_QUEUE = 1
Constant VI_HNDLR = 2
Constant VI_SUSPEND_HNDLR = 4
Constant VI_ALL_MECH = -1			// 0xFFFF

Constant VI_ANY_HNDLR = 0

Constant VI_TRIG_ALL = -2
Constant VI_TRIG_SW = -1
Constant VI_TRIG_TTL0 = 0
Constant VI_TRIG_TTL1 = 1
Constant VI_TRIG_TTL2 = 2
Constant VI_TRIG_TTL3 = 3
Constant VI_TRIG_TTL4 = 4
Constant VI_TRIG_TTL5 = 5
Constant VI_TRIG_TTL6 = 6
Constant VI_TRIG_TTL7 = 7
Constant VI_TRIG_ECL0 = 8
Constant VI_TRIG_ECL1 = 9
Constant VI_TRIG_PANEL_IN = 27
Constant VI_TRIG_PANEL_OUT = 28

Constant VI_TRIG_PROT_DEFAULT = 0
Constant VI_TRIG_PROT_ON = 1
Constant VI_TRIG_PROT_OFF = 2
Constant VI_TRIG_PROT_SYNC = 5

Constant VI_READ_BUF = 1
Constant VI_WRITE_BUF = 2
Constant VI_READ_BUF_DISCARD = 4
Constant VI_WRITE_BUF_DISCARD = 8
Constant VI_IO_IN_BUF = 16
Constant VI_IO_OUT_BUF = 32
Constant VI_IO_IN_BUF_DISCARD = 64
Constant VI_IO_OUT_BUF_DISCARD = 128

Constant VI_FLUSH_ON_ACCESS = 1
Constant VI_FLUSH_WHEN_FULL = 2
Constant VI_FLUSH_DISABLE = 3

Constant VI_NMAPPED = 1
Constant VI_USE_OPERS = 2
Constant VI_DEREF_ADDR = 3

Constant VI_TMO_IMMEDIATE = 0
Constant VI_TMO_INFINITE = -1	// 0xFFFFFFFF

Constant VI_NO_LOCK = 0
Constant VI_EXCLUSIVE_LOCK = 1
Constant VI_SHARED_LOCK = 2
Constant VI_LOAD_CONFIG = 4

Constant VI_NO_SEC_ADDR = -1		// 0xFFFF

Constant VI_ASRL_PAR_NONE = 0
Constant VI_ASRL_PAR_ODD = 1
Constant VI_ASRL_PAR_EVEN = 2
Constant VI_ASRL_PAR_MARK = 3
Constant VI_ASRL_PAR_SPACE = 4

Constant VI_ASRL_STOP_ONE = 10
Constant VI_ASRL_STOP_ONE5 = 15
Constant VI_ASRL_STOP_TWO = 20

Constant VI_ASRL_FLOW_NONE = 0
Constant VI_ASRL_FLOW_XON_XOFF = 1
Constant VI_ASRL_FLOW_RTS_CTS = 2
Constant VI_ASRL_FLOW_DTR_DSR = 4

Constant VI_ASRL_END_NONE = 0
Constant VI_ASRL_END_LAST_BIT = 1
Constant VI_ASRL_END_TERMCHAR = 2
Constant VI_ASRL_END_BREAK = 3

Constant VI_STATE_ASSERTED = 1
Constant VI_STATE_UNASSERTED = 0
Constant VI_STATE_UNKNOWN = -1

Constant VI_BIG_ENDIAN = 0
Constant VI_LITTLE_ENDIAN = 1

Constant VI_DATA_PRIV = 0
Constant VI_DATA_NPRIV = 1
Constant VI_PROG_PRIV = 2
Constant VI_PROG_NPRIV = 3
Constant VI_BLCK_PRIV = 4
Constant VI_BLCK_NPRIV = 5
Constant VI_D64_PRIV = 6
Constant VI_D64_NPRIV = 7

Constant VI_WIDTH_8 = 1
Constant VI_WIDTH_16 = 2
Constant VI_WIDTH_32 = 4

Constant VI_GPIB_REN_DEASSERT = 0
Constant VI_GPIB_REN_ASSERT = 1
Constant VI_GPIB_REN_DEASSERT_GTL = 2
Constant VI_GPIB_REN_ASSERT_ADDRESS = 3
Constant VI_GPIB_REN_ASSERT_LLO = 4
Constant VI_GPIB_REN_ASSERT_ADDRESS_LLO = 5
Constant VI_GPIB_REN_ADDRESS_GTL = 6

Constant VI_GPIB_ATN_DEASSERT = 0
Constant VI_GPIB_ATN_ASSERT = 1
Constant VI_GPIB_ATN_DEASSERT_HANDSHAKE = 2
Constant VI_GPIB_ATN_ASSERT_IMMEDIATE = 3

Constant VI_GPIB_HS488_DISABLED = 0
Constant VI_GPIB_HS488_NIMPL = -1

Constant VI_GPIB_UNADDRESSED = 0
Constant VI_GPIB_TALKER = 1
Constant VI_GPIB_LISTENER = 2

Constant VI_VXI_CMD16 = 0x0200
Constant VI_VXI_CMD16_RESP16 = 0x0202
Constant VI_VXI_RESP16 = 0x0002
Constant VI_VXI_CMD32 = 0x0400
Constant VI_VXI_CMD32_RESP16 = 0x0402
Constant VI_VXI_CMD32_RESP32 = 0x0404
Constant VI_VXI_RESP32 = 0x0004

Constant VI_ASSERT_SIGNAL = -1
Constant VI_ASSERT_USE_ASSIGNED = 0
Constant VI_ASSERT_IRQ1 = 1
Constant VI_ASSERT_IRQ2 = 2
Constant VI_ASSERT_IRQ3 = 3
Constant VI_ASSERT_IRQ4 = 4
Constant VI_ASSERT_IRQ5 = 5
Constant VI_ASSERT_IRQ6 = 6
Constant VI_ASSERT_IRQ7 = 7

Constant VI_UTIL_ASSERT_SYSRESET = 1
Constant VI_UTIL_ASSERT_SYSFAIL = 2
Constant VI_UTIL_DEASSERT_SYSFAIL = 3

Constant VI_VXI_CLASS_MEMORY = 0
Constant VI_VXI_CLASS_EXTENDED = 1
Constant VI_VXI_CLASS_MESSAGE = 2
Constant VI_VXI_CLASS_REGISTER = 3
Constant VI_VXI_CLASS_OTHER = 4

// National Instruments Extensions for PXI
Constant VI_ATTR_PXI_DEV_NUM         = 0x3FFF0201
Constant VI_ATTR_PXI_FUNC_NUM        = 0x3FFF0202
Constant VI_ATTR_PXI_BUS_NUM         = 0x3FFF0205
Constant VI_ATTR_PXI_CHASSIS         = 0x3FFF0206
Constant VI_ATTR_PXI_SLOTPATH        = 0xBFFF0207
Constant VI_ATTR_PXI_SLOT_LBUS_LEFT  = 0x3FFF0208
Constant VI_ATTR_PXI_SLOT_LBUS_RIGHT = 0x3FFF0209
Constant VI_ATTR_PXI_TRIG_BUS        = 0x3FFF020A
Constant VI_ATTR_PXI_STAR_TRIG_BUS   = 0x3FFF020B
Constant VI_ATTR_PXI_STAR_TRIG_LINE  = 0x3FFF020C
Constant VI_ATTR_PXI_SRC_TRIG_BUS    = 0x3FFF020D
Constant VI_ATTR_PXI_DEST_TRIG_BUS   = 0x3FFF020E
Constant VI_ATTR_PXI_MEM_TYPE_BAR0   = 0x3FFF0211
Constant VI_ATTR_PXI_MEM_TYPE_BAR1   = 0x3FFF0212
Constant VI_ATTR_PXI_MEM_TYPE_BAR2   = 0x3FFF0213
Constant VI_ATTR_PXI_MEM_TYPE_BAR3   = 0x3FFF0214
Constant VI_ATTR_PXI_MEM_TYPE_BAR4   = 0x3FFF0215
Constant VI_ATTR_PXI_MEM_TYPE_BAR5   = 0x3FFF0216
Constant VI_ATTR_PXI_MEM_BASE_BAR0   = 0x3FFF0221
Constant VI_ATTR_PXI_MEM_BASE_BAR1   = 0x3FFF0222
Constant VI_ATTR_PXI_MEM_BASE_BAR2   = 0x3FFF0223
Constant VI_ATTR_PXI_MEM_BASE_BAR3   = 0x3FFF0224
Constant VI_ATTR_PXI_MEM_BASE_BAR4   = 0x3FFF0225
Constant VI_ATTR_PXI_MEM_BASE_BAR5   = 0x3FFF0226
Constant VI_ATTR_PXI_MEM_SIZE_BAR0   = 0x3FFF0231
Constant VI_ATTR_PXI_MEM_SIZE_BAR1   = 0x3FFF0232
Constant VI_ATTR_PXI_MEM_SIZE_BAR2   = 0x3FFF0233
Constant VI_ATTR_PXI_MEM_SIZE_BAR3   = 0x3FFF0234
Constant VI_ATTR_PXI_MEM_SIZE_BAR4   = 0x3FFF0235
Constant VI_ATTR_PXI_MEM_SIZE_BAR5   = 0x3FFF0236
Constant VI_ATTR_PXI_RECV_INTR_SEQ   = 0x3FFF4240
Constant VI_ATTR_PXI_RECV_INTR_DATA  = 0x3FFF4241
Constant VI_EVENT_PXI_INTR           = 0x3FFF2022
Constant VI_INTF_PXI            = 5
Constant VI_PXI_ALLOC_SPACE     = 9
Constant VI_PXI_CFG_SPACE       = 10
Constant VI_PXI_BAR0_SPACE      = 11
Constant VI_PXI_BAR1_SPACE      = 12
Constant VI_PXI_BAR2_SPACE      = 13
Constant VI_PXI_BAR3_SPACE      = 14
Constant VI_PXI_BAR4_SPACE      = 15
Constant VI_PXI_BAR5_SPACE      = 16
Constant VI_PXI_ADDR_NONE       = 0
Constant VI_PXI_ADDR_MEM        = 1
Constant VI_PXI_ADDR_IO         = 2
Constant VI_PXI_ADDR_CFG        = 3
Constant VI_TRIG_PROT_RESERVE   = 6
Constant VI_TRIG_PROT_UNRESERVE = 7
Constant VI_UNKNOWN_CHASSIS     = -1

// National Instruments Extensions for USB
Constant VI_ATTR_USB_BK_OUT_PIPE   = 0x3FFF01A2
Constant VI_ATTR_USB_BK_IN_PIPE    = 0x3FFF01A3
Constant VI_ATTR_USB_INTR_IN_PIPE    = 0x3FFF01A4
Constant VI_ATTR_USB_CLASS           = 0x3FFF01A5
Constant VI_ATTR_USB_SUBCLASS        = 0x3FFF01A6
Constant VI_ATTR_USB_ALT_SETTING     = 0x3FFF01A8
Constant VI_ATTR_USB_END_IN          = 0x3FFF01A9
Constant VI_ATTR_USB_NUM_INTFCS      = 0x3FFF01AA
Constant VI_ATTR_USB_NUM_PIPES       = 0x3FFF01AB
Constant VI_ATTR_USB_BK_OUT_STATUS = 0x3FFF01AC
Constant VI_ATTR_USB_BK_IN_STATUS  = 0x3FFF01AD
Constant VI_ATTR_USB_INTR_IN_STATUS  = 0x3FFF01AE
Constant VI_USB_PIPE_STATE_UNKNOWN   = -1
Constant VI_USB_PIPE_READY           = 0
Constant VI_USB_PIPE_STALLED         = 1
Constant VI_USB_END_NONE             = 0
Constant VI_USB_END_SHORT            = 4
Constant VI_USB_END_SHORT_OR_COUNT   = 5
