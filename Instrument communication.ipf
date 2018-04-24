#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function Initeverything() //add serial support!
	variable status, sessionID, findlist=0,instrcnt=0,instrcntserial=0,i=0
	string instrDesc="", instrtype, instrname, error, summary
	variable instrID
	string/g serialinfo = "\rSerial instruments:\r\t"
	
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
		printf "FindRSrc error (GPIB): %s\r", error
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
	status = viFindRsrc(sessionID,"ASRL?*INSTR",findlist,instrcntserial,instrDesc)
	if(status < 0)
		viStatusDesc(sessionID, status, error)	
		printf "FindRSrc error (Serial): %s\r", error
	else
		instrID = openinstr(sessionID,instrDesc)
		GetSerialInstrInfo(instrDesc,sessionID,instrID,0)
	endif
	
	// find the remaining Serial instruments
	for(i=1;i<instrcntserial;i+=1)
		viFindNext(findlist,instrDesc)
		instrID = openinstr(sessionID,instrDesc)
		GetSerialInstrInfo(instrDesc,sessionID,instrID,i)
	endfor
	
	if(instrcnt>0)
		CreateGPIBSummary(instrcnt)
	endif
	if(instrcntserial>0)
		print serialinfo
	endif
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

function/s GetSerialInstrInfo(instrDesc,sessionID,instrID,counter)
	string instrDesc
	variable sessionID, instrID, counter
	variable status, baudrate
	string instrname, instrbaud, serialname, error,counterString
	svar serialinfo
	
	sprintf counterString, "%d)\t", counter+1
	serialinfo += counterString+instrDesc+"\r\t"
	
	// get full name
	status = viGetAttributeString(instrID,0xBFFF00E9,serialname)
	if (status < 0)
		viStatusDesc(sessionID, status, error)
		abort "viGetAttribute error: "+error
	else
		sprintf instrname, "\tSerial object connected is called: %s\r\t", serialname
		serialinfo += instrname
	endif
	
	// get baud rate
	status = viGetAttribute(instrID,0x3FFF0021,baudrate)
	if (status < 0)
		viStatusDesc(sessionID, status, error)
		abort "viGetAttribute error: "+error
	else
		sprintf instrbaud, "\tThe baudrate is currently set to: %g\r\t", baudrate
		serialinfo += instrbaud
	endif
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

function/s CreateGPIBSummary(instrcnt)
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
	
	header = "\rGPIB instruments connected to the setup:\r\t"
	sprintf srsline, "%d SR830's are connected. They are: %s\r\t", counter[0], srsid
	sprintf k2400line, "%d Keithley's are connected. They are: %s\r\t", counter[1], k2400id
	sprintf dmmline, "%d DMM's are connected. They are: %s\r\t", counter[2], dmmid
	sprintf awgline, "%d AWG's are connected. They are: %s\r\t", counter[3], awgid
	sprintf unknownline, "%d unknown instruments are connected. They are: %s", counter[4], unknownid
	
	print header+srsline+k2400line+dmmline+awgline+unknownline 
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
	
	viGetAttribute(instID,0x3FFF0172,gpibadresse) // get primary adresse
	return gpibadresse
end