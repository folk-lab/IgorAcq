#pragma rtGlobals=1		// Use modern global access method.

function InitAllGPIB([gpib_board])
	string gpib_board // GPIB boards are named like GPIB0, GPIB1, ....
	variable limitparam = 30
	variable ii, jj, board, numdevices, adresse
	string instype, idname, summary
	
	if(paramisdefault(gpib_board))
		gpib_board="gpib0"
	endif
	variable gpib_index = str2num(gpib_board[strlen(gpib_board)-1]) // assumes the last character is the board index
	
	make/o/n=(limitparam) adlist=0 // GPIB address list wave. Only adresses 0-30 are supported by IEEE-448
	make/o/n=(limitparam) aclist=0 // Active GPIB list reutrned by FindLstn
	make/o/t/n=(limitparam) idwave // Holds the instrument id's
	make/o/n=5 counter=0 // Keeps track of how many instruments of the same type is connected
	
	for(ii=0;ii<limitparam;ii=ii+1)
		adlist[ii] = ii
	endfor
	
	NI4882 ibfind={gpib_board} // Get id for GPIB board
	board=v_flag
	
	NI4882 ibrsc={board,1} // Configure the GPIB board as system controller
	NI4882 ibsic={board} // Clear interface
	
	NI4882 FindLstn={gpib_index,adlist,aclist,limitparam} // Find all connected GPIB instruments on board 0. 
	numdevices = v_ibcnt-1
	
	for(jj=0;jj<numpnts(aclist);jj=jj+1)
		if(aclist[jj] != 0)
			NI4882 ibdev={gpib_index,aclist[jj],0,10,1,0} //Init device and get identifier
			if(v_flag == -1)
				printf "Encoutered a problem trying to initiate the instrument on GPIB adresse %d/r", aclist[jj]
			else
				adresse = v_flag
				instype = DetermineInsType(adresse)
				idname = CreateInsID(instype,adresse,aclist[jj])
				idwave[jj] = idname
			endif
		endif
	endfor
	
	summary = CreateSummary()
	print summary
end

function/s CreateSummary()
	wave/t idwave
	wave counter, aclist
	string header, srsline, k2400line, dmmline, awgline, unknownline, expr, type, gpibadresse
	string srsid = " ", k2400id = " ", dmmid = " ", awgid = " ", unknownid = " "
	variable ii
	
	for(ii=0;ii<30;ii+=1)
		if(aclist[ii] != 0)
			expr = "([[:alpha:]]+)([[:digit:]]+)"
			splitstring/E=(expr) idwave[ii], type, gpibadresse
			strswitch(type)
				case "srs":
					srsid += idwave[ii]+", "
					break
				case "k":
					k2400id += idwave[ii]+", "
					break
				case "dmm":
					dmmid += idwave[ii]+", "
					break
				case "awg":
					awgid += idwave[ii]+", "
					break
				case "unknown":
					unknownid += idwave[ii]+", "
					break
			endswitch
		endif
	endfor
	
	header = "Instruments connected to the setup:\r\t"
	sprintf srsline, "%d SR830's are connected. They are:%s\r\t", counter[0], srsid
	sprintf k2400line, "%d Keithley's are connected. They are:%s\r\t", counter[1], k2400id
	sprintf dmmline, "%d DMM's are connected. They are:%s\r\t", counter[2], dmmid
	sprintf awgline, "%d AWG's are connected. They are:%s\r\t", counter[3], awgid
	sprintf unknownline, "%d unknown instruments are connected. They are:%s", counter[4], unknownid
	
	return header+srsline+k2400line+dmmline+awgline+unknownline 
end

function/s CreateInsID(instype,id,gpibadresse)
	string instype
	variable id,gpibadresse
	string idname, inscount
	wave counter
	
	if(cmpstr(instype,"k2400") == 0 && counter[1] == 0) // The first Keithley can also be called with k2400
		variable/g $instype = id
	endif
	
	idname = instype+num2istr(gpibadresse)
	variable/g $idname = id
	return idname
end

function/s DetermineInsType(id)
	variable id
	string answer_long, answer, instype
	wave counter
	
	GPIB2 device=id
	GPIBWrite2 "*IDN?\n"
	sleep/s 0.5
	GPIBRead2/T="\n" answer_long
	
	answer = stringfromlist(1,answer_long,",")
	strswitch(answer)
		case "SR830": // SR830 lockin
			instype = "srs"
			counter[0] += 1
			break
		case "MODEL 2400": // Keithley 2400
			instype = "k2400"
			counter[1] += 1
			break
		case "34401A": // HP34401A DMM
			instype = "dmm"
			counter[2] += 1
			break
		case "33250A": // Agilent AWG 33250A
			instype = "awg"
			counter[3] += 1
			break
		default:
			instype = "unknown"
			counter[4] += 1
			break
	endswitch
	
	return instype
end

function returnGPIBaddress(ud)
	variable ud
	variable address = -1
	
	NI4882 ibask={ud, 1}
	address = v_flag
	
	return address
end

function /S getInstIDN(boardnum, devnum)
	// get IDN string for a particular device
	// boardnum specifies which GPIB interface, boardnum=0 for "GPIB0"
	// devnum is the GPIB address of the device (0-15)
	variable boardnum, devnum
	variable ud
	string readstr=""

	NI4882 ibdev={boardnum,devnum,0,10,1,0}
	ud = v_flag
	GPIB2 device=ud
	GPIBWrite2 "*IDN?"
	GPIBRead2 /Q/T="\n" readstr
	
	return readstr
end

function resetGPIB(boardnum)
	// reset GPIB{boardnum}
	variable boardnum
	GPIB2 board=boardnum
	GPIB2 KillIO
	InitAllGPIB()
	printf "GPIB%d RESET", boardnum
end


function FindListeners(boardnum, devnum)  
	// Look for device on GPIB{boardnum} at address=devnum
	// returns 1 if there is a device
	// returns 0 if no devices are at that {boardnum, devnum}
	variable boardnum, devnum

	Make/O gAddressList = {devnum, -1} // -1 is NOADDR - marks end of list.
	Make/O/N=(numpnts(gAddressList)), gResultList
	NI4882 FindLstn={boardnum, gAddressList, gResultList, numpnts(gResultList)}
	
	if(V_ibcnt==1)
		return 1
	else
		return 0
	endif
	
End