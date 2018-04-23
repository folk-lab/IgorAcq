#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function Initeverything() //add serial support!
	variable status, sessionID, findlist=0,instrcnt=0,instrcntserial=0,i=0
	string instrDesc="", instrtype, instrname, error, summary
	variable instrID
	
	// check for old call to viOpenDefaultRM and close it
	nvar/z sessionRM
	if(nvar_exists(sessionRM))
		viClose(sessionRM)
	endif
	
	make/o/t/n=30 idwave=""
	make/o/n=5 counter=0
	
	// open VISA session and store ID in sessionID
	status = viOpenDefaultRM(sessionID)
	if(status < 0)
		viStatusDesc(sessionID, status, error)
		abort "OpenDefaultRM error: " + error
	else
		variable/g sessionRM = sessionID
	endif
	
	// find all GPIB intruments, with an adresse that ends wth INSTR
	status = viFindRsrc(sessionID,"GPIB?*INSTR",findlist,instrcnt,instrDesc)
	if(status < 0)
		viStatusDesc(sessionID, status, error)	
		abort "FindRSrc error: " + error
	else
		// init first instrument returned by viFindRsrc
		instrID = openinstr(sessionID,instrDesc)
		instrtype = DetermineGPIBInstrType(instrDesc,sessionID,instrID)
		instrname = CreateGPIBInstrID(instrtype,instrDesc,instrID)
		idwave[0] = instrname
	endif
	
	// find the remaining GPIB instruments
	for(i=1;i<instrcnt;i+=1)
		viFindNext(findlist,instrDesc)
		instrID = openinstr(sessionID,instrDesc)
		instrtype = DetermineGPIBInstrType(instrDesc,sessionID,instrID)
		instrname = CreateGPIBInstrID(instrtype,instrDesc,instrID)
		idwave[i] = instrname
	endfor
	
	// find all serial (instrument and ports)
	viClose(findlist)
	status = viFindRsrc(sessionID,"ASRL?*INSTR",findlist,instrcntserial,instrDesc)
	if(status < 0)
		viStatusDesc(sessionID, status, error)	
		abort "FindRSrc error: " + error
	else
		// init first instrument returned by viFindRsrc
		// try communicating ....
	endif
	
	summary = CreateSummary(instrcnt)
	print summary
end

function openinstr(sessionID,instrDesc)
	variable sessionID
	string instrDesc
	variable instrID=0,status
	string error
	
	status = viOpen(sessionID,instrDesc,0,0,instrID)
	if (status < 0)
		viStatusDesc(sessionID, status, error)
		abort "viOpen error: " + error
	endif
	
	return instrID
end

function/s DetermineSerialInstrType(instrDesc,sessionID,instrID)
	string instrDesc
	variable sessionID, instrID
	
end

function/s DetermineGPIBInstrType(instrDesc,sessionID,instrID)
	string instrDesc
	variable sessionID,instrID
	string answer_long, answer, instrtype
	wave counter
	
	answer_long = QueryInstr(instrID,"*IDN?")
	
	answer = stringfromlist(1,answer_long,",")
	strswitch(answer)
		case "SR830": // SR830 lockin
			instrtype = "srs"
			counter[0] += 1
			break
		case "MODEL 2400": // Keithley 2400
			instrtype = "k2400"
			counter[1] += 1
			break
		case "34401A": // HP34401A DMM
			instrtype = "dmm"
			counter[2] += 1
			break
		case "3478A": // HP3478A DMM FIX!
			instrtype = "dmm"
			counter[2] += 1
			break
		case "33250A": // Agilent AWG 33250A
			instrtype = "awg"
			counter[3] += 1
			break
		default:
			instrtype = "unknown"
			counter[4] += 1
			break
	endswitch
	
	return instrtype
end

function/s CreateGPIBInstrID(instrtype,instrDesc,instrID)
	string instrtype, instrDesc
	variable instrID
	string instrname, expr, gpibadresse, gpibboard
	
	expr = "GPIB([[:digit:]])::([[:digit:]]+)::INSTR"
	splitstring/e=(expr) instrDesc, gpibboard, gpibadresse
	instrname = instrtype+gpibadresse
	variable/g $instrname = instrID
	
	return instrname
end

function/s CreateSummary(instrcnt)
	variable instrcnt
	wave/t idwave
	wave counter
	string header, srsline, k2400line, dmmline, awgline, unknownline, expr, type, gpibadresse
	string srsid = "", k2400id = "", dmmid = "", awgid = "", unknownid = ""
	variable i
	
	expr = "([[:alpha:]]+)([[:digit:]]+)"
	for(i=0;i<instrcnt;i+=1)
			splitstring/E=(expr) idwave[i], type, gpibadresse
			strswitch(type)
				case "srs":
					srsid += idwave[i]+", "
					break
				case "k":
					k2400id += idwave[i]+", "
					break
				case "dmm":
					dmmid += idwave[i]+", "
					break
				case "awg":
					awgid += idwave[i]+", "
					break
				case "unknown":
					unknownid += idwave[i]+", "
					break
			endswitch
	endfor
	
	header = "Instruments connected to the setup:\r\t"
	sprintf srsline, "%d SR830's are connected. They are: %s\r\t", counter[0], srsid
	sprintf k2400line, "%d Keithley's are connected. They are: %s\r\t", counter[1], k2400id
	sprintf dmmline, "%d DMM's are connected. They are: %s\r\t", counter[2], dmmid
	sprintf awgline, "%d AWG's are connected. They are: %s\r\t", counter[3], awgid
	sprintf unknownline, "%d unknown instruments are connected. They are: %s", counter[4], unknownid
	
	return header+srsline+k2400line+dmmline+awgline+unknownline 
end

function/s QueryInstr(instrID,cmd)
	variable instrID
	string cmd
	string response
	
	cmd = cmd+"\n"
	VISAwrite instrID, cmd
	VISAread/T="\n" instrID, response
	
	return response
end

function instGPIB(instID)
	variable instID
	variable gpibadresse
	
	viGetAttribute(instID,VI_ATTR_GPIB_PRIMARY_ADDR,gpibadresse)
	return gpibadresse
end