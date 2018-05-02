#pragma rtGlobals=1		// Use modern global access method.

//	Driver communicates over serial, remenber to set the correct port in SetSerial()
//	Adding an interavtive window
//	Currents are returned in amps, while field values are return in mT
//	Procedure written by Christian Olsen 2016-01-26
// Updated to used VISA/async Nik/Christian 05-XX-2018

/////////////////////////
/// IPS specific COMM ///
/////////////////////////

function ipsCommSetup(instrID)
	// baud=9600, stopbits=2
	// write_term = "\r"
	// read_term = "\r"
	variable instrID

	visaSetBaudRate(instrID, 9600)
	visaSetStopBits(instrID, 20)
	
end

function writeIPScheck(instrID, cmd)	// Checks response for error
	variable instrID
	string cmd

	string response = queryInstr(instrID, cmd, "\r", "\r")
	if (cmpstr(response[0],"?") == 0)
		printf "[WARNING] IPS command did not execute correctly: %s\r", cmd
	endif
end

///////////////////////
/// Initiate Magnet ///
///////////////////////

function initIPS120(instrID)
	variable instrID
	variable /g ips_window_ctrl=instrID // copy of instrID to be used for the window
	
	// currently hard coded for BFXLD 3" magnet
	variable/g ampspertesla=9.569 // A/T
	variable/g maxfield=9         // mT
	variable/g maxramprate=182    // mT/min, depends on max field
	
	ipsCommSetup(instrID) // Setting up serial communication
	
	writeIPScheck(instrID, "C3") // Remote and unlocked
	sc_sleep(0.02)
	writeIPScheck(instrID, "M9") // Set display to Tesla
	writeInstr(instrID, "Q4", "\r")    // Use extented resolusion (0.0001 amp/0.01 mT), no response from magnet
	writeIPScheck(instrID, "A0") // Set to Hold
	
//	dowindow/k IPS_Window
	make /t/o magnetvalsstr = {{"Current field [mT]","Current amp [A]","Set point [mT]","Set point [A]","Sweep rate [mT/min]","Sweep rate [A/min]","Switch heater"},{"0","0","0","0","0","0","OFF"}}
//	make /o listboxattr_mag={{0,0,0,0,0,0,0},{0,0,2,0,2,0,0}} // Setting list attributes. 0 = non-interactive, 2 = interactive
	
	setIPS120rate(instrID, 100)
	
	string/g oldsweeprate = magnetvalsstr[4][1]
	string/g oldsetpoint = "0"
	
//	execute("IPS_window()")
//	execute("Magnetsettings_window()")
//	PauseForUser Magnetsettings

end

///// Talk to Magnet /////

function getIPS120volts(instrID) // return in A
	variable instrID
	wave/t magnetvalsstr=magnetvalsstr
	NVAR ampspertesla=ampspertesla
	variable volts
	
	volts = str2num(queryInstr(instrID, "R1", "\r", "\r")[1,inf]) // get value
	
	return volts
end

threadsafe function getIPS120volts_Async(datafolderID) // Units: mV
	string datafolderID
	
	// get instrument ID from datafolder
	DFREF dfr = ThreadGroupGetDFR(0,inf)
	setdatafolder dfr
	nvar instrID = $(":"+datafolderID+":instrID")
	killdatafolder dfr // We don't need the datafolder anymore!
	
	variable volts
	volts = str2num(queryInstr(instrID, "R1", "\r", "\r")[1,inf]) // get value
	return volts
end

function getIPS120current(instrID) // return in A
	variable instrID
	wave/t magnetvalsstr=magnetvalsstr
	NVAR ampspertesla=ampspertesla
	variable current
	
	current = str2num(queryInstr(instrID, "R0", "\r", "\r")[1,inf]) // get value
	
	// save to waves for window
	magnetvalsstr[1][1] = num2str(current)
	magnetvalsstr[0][1] = num2str(roundNum(current/ampspertesla*1000,2))
	
	return current
end

function getIPS120field(instrID) // return in mT
	variable instrID
	wave/t magnetvalsstr=magnetvalsstr
	NVAR ampspertesla=ampspertesla
	variable current,field
	
	current = str2num(queryInstr(instrID, "R0", "\r", "\r")[1,inf]) // get current
	field = roundNum(current/ampspertesla*1000,2) // calculate field
	
	// save to waves for window
	magnetvalsstr[0][1] = num2str(field)
	magnetvalsstr[1][1] = num2str(current)
	
	return field
end

//function SetCurrentIPS(amps) // in A
//	variable amps
//	NVAR maxfield=maxfield
//	NVAR ampspertesla=ampspertesla
//	wave/t magnetvalsstr=magnetvalsstr
//	if (abs(amps) > maxfield*ampspertesla/1000)
//		print "Max current is "+num2str(maxfield*ampspertesla/1000)+" A"
//		return -1
//	else
//		WriteMagnetCheckResponse("I"+num2str(amps))
//		WriteMagnet("$A1")
//		magnetvalsstr[3][1] = num2str(amps)
//		magnetvalsstr[2][1] = num2str(roundNum(amps/ampspertesla*1000,2))
//	endif
//end

//function SetField(field) // in mT
//	variable field
//	NVAR maxfield=maxfield
//	NVAR ampspertesla
//	variable round_amps
//	wave/t magnetvalsstr=magnetvalsstr
//	if (abs(field) > maxfield)
//		print "Max field is "+num2str(maxfield)+" mT"
//		return -1
//	else
//		round_amps = roundNum(field*ampspertesla/1000,4)
//		WriteMagnetCheckResponse("I"+num2str(round_amps))
//		WriteMagnet("$A1")
//		magnetvalsstr[2][1] = num2str(field)
//		magnetvalsstr[3][1] = num2str(round_amps)
//		return 1
//	endif
//end

function setIPS120rate(instrID, ramprate) // mT/min
	variable instrID, ramprate
	NVAR maxramprate=maxramprate
	NVAR ampspertesla=ampspertesla
	wave/t magnetvalsstr=magnetvalsstr
	variable ramprate_amps
	
	if (ramprate < 0 || ramprate > maxramprate)
		print "Max sweep rate is "+num2str(maxramprate)+" mT/min"
		return -1
	else
		ramprate_amps = roundNum(ramprate*ampspertesla/1000,3)
		writeIPScheck(instrID, "S"+num2str(ramprate_amps))
		magnetvalsstr[4][1] = num2str(ramprate)
		magnetvalsstr[5][1] = num2str(ramprate_amps)
		return 1
	endif
	
end

function getIPS120rate(instrID) // returns in mT/min
	variable instrID
	variable ramprate_amps,ramprate_field
	wave/t magnetvalsstr=magnetvalsstr
	NVAR ampspertesla=ampspertesla
	
	ramprate_amps = str2num(queryInstr(instrID, "R6", "\r", "\r")[1,inf])
	ramprate_field = roundNum(ramprate_amps/ampspertesla*1000,0)
	magnetvalsstr[4][1] = num2str(ramprate_field)
	magnetvalsstr[5][1] = num2str(ramprate_amps)
	return ramprate_field
end

//function GetSweepRateCurrent() // returns in A/min
//	variable ramprate_amps,round_field
//	wave/t magnetvalsstr=magnetvalsstr
//	NVAR ampspertesla=ampspertesla
//	ramprate_amps = str2num(QueryMagnet("R6")[1,inf])
//	round_field = roundNum(ramprate_amps/ampspertesla*1000,0)
//	magnetvalsstr[4][1] = num2str(round_field)
//	magnetvalsstr[5][1] = num2str(ramprate_amps)
//	return ramprate_amps
//end

//function/s ExamineStatus()
//	string status
//	WriteMagnet("X")
//	status = ReadMagnet()
//	return status
//end

//function GetHeaterStatus()
//	string status
//	status = ExamineStatus()
//	return str2num(status[8])
//end

//function SwitchHeater(newstate) // Call with "ON" or "OFF"
//	string newstate
//	string oldstate
//	variable heaterstate
//	wave/t magnetvalsstr=magnetvalsstr
//
//	heaterstate = GetHeaterStatus()
//
//	if (heaterstate == 5)
//		print "Heater error"
//		return -1
//	endif
//
//	variable start_time = datetime
//	strswitch(newstate)
//		case "ON":
//			if (heaterstate == 0)
//				WriteMagnetCheckResponse("H1")
//				print "waiting 20 sec for heater to respond"
//				magnetvalsstr[6][1] = newstate
//				do
//					sleep /T 1
//				while(datetime - start_time < 20.0)
//			elseif (heaterstate == 1)
//				print "Heater already on"
//			else
//				printf "Heater state is H%d, check manual",heaterstate
//			endif
//			break
//		case "OFF":
//			if (heaterstate == 0)
//				print "Heater already off"
//			elseif (heaterstate == 1)
//				WriteMagnetCheckResponse("H0")
//				print "waiting 20 sec for heater to respond"
//				magnetvalsstr[6][1] = newstate
//				do
//					sleep /T 1
//				while(datetime - start_time < 20.0)
//			else
//				printf "Heater state is H%d, check manual",heaterstate
//			endif
//			break
//		default:
//			printf "Command: (%s) not understood. Pass ON or OFF",newstate
//			break
//	endswitch
//end

//// Advanced functions ////

//function SetFieldWait(field) // in mT
//	// Setting new set point and waiting for magnet to reach new set point
//	variable field
//	variable status, count = 0
//
//	SetField(field)
//	do
//
//		do
//			sc_sleep(0.02)
//			GetField() // forces the window to update
//			status = str2num(QueryMagnet("X")[11])
//		while(numtype(status)==2)
//
//	while(status!=0)
//
//end

//function CalcSweepTime(currentfield,newfield,sweeprate)
//	variable currentfield // in mT
//	variable newfield // in mT
//	variable sweeprate // in mT/min
//	return abs(currentfield - newfield)/sweeprate*60 // in sec
//end

///// User interface /////

//Window IPS_Window() : Panel
//	PauseUpdate; Silent 1 // building window
//	NewPanel /W=(0,0,430,300) // window size
//	ModifyPanel frameStyle=2
//	SetDrawLayer UserBack
//	SetDrawEnv fsize= 25,fstyle= 1
//	DrawText 150, 45,"Magnet" // Headline
//	ListBox maglist,pos={10,60},size={410,180},fsize=16,frame=2 // interactive list
//	ListBox maglist,fStyle=1,listWave=root:magnetvalsstr,selWave=root:listboxattr_mag,mode= 1
//	Button setfield,pos={170,250},size={110,20},proc=update_magnet,title="Change setpoint" // adding buttons
//	Button setrate,pos={290,250},size={130,20},proc=update_magnet,title="Change sweep rate"
//	Button updatevals, pos={10,250},size={150,20},proc=update_magnet,title="Update current values"
//EndMacro

//Window Magnetsettings_window() : Panel
//	PauseUpdate; Silent 1 // building window
//	NewPanel /W=(0,0, 370,100)/N=MagnetSettings // window size
//	ModifyPanel frameStyle=2
//	SetDrawLayer UserBack
//	SetDrawEnv fsize= 20,fstyle= 1
//	DrawText 50, 40,"Choose Magnet" // Headline
//	Button BFmagnet,pos={10,60},size={110,20},proc=magnet_button,title="BF 10T Magnet"
//	Button IGHmagnet,pos={130,60},size={110,20},proc=magnet_button,title="IGH 12T Magnet"
//	Button AMmagnet,pos={250,60},size={110,20},proc=magnet_button,title="AM z-axis 6T"
//end

//function magnet_button(action) : ButtonControl
//	string action
//	nvar ampspertesla, maxfield, maxramprate
//	strswitch(action)
//		case "BFmagnet":
//			ampspertesla = 9.6768//A/T
//			maxfield = 10000//mT
//			maxramprate = 300//mT/min
//			dowindow /k MagnetSettings
//			break
//		case "IGHmagnet":
//			ampspertesla = 8.2061452674//A/T
//			maxfield = 12000//mT
//			maxramprate = 400//mT/min
//			dowindow /k MagnetSettings
//			break
//		case "AMmagnet":
//			ampspertesla =9.9502//A/T
//			maxfield = 6000 //mT
//			maxramprate = 1150 //mT/min
//			dowindow /k MagnetSettings
//			break
//	endswitch
//end

//function update_magnet(action) : ButtonControl
//	string action
//	wave/t magnetvalsstr=magnetvalsstr
//	NVAR ampspertesla
//	SVAR oldsetpoint
//	SVAR oldsweeprate
//	variable field,ramprate,heater,check,field_setpoint
//	string state
//	controlinfo /W=IPS_Window maglist
//	strswitch(action)
//		case "updatevals":
//			// Update current field and amp values
//			field = GetField()
//			ramprate = GetSweepRateCurrent()
//			heater = GetHeaterStatus()
//			if (heater == 0)
//				state = "OFF"
//			elseif (heater == 1)
//				state = "ON"
//			else
//				state = "Heater fault"
//			endif
//			magnetvalsstr[0][1] = num2str(field)
//			magnetvalsstr[1][1] = num2str(roundNum(field*ampspertesla/1000,4))
//			magnetvalsstr[4][1] = num2str(roundNum(ramprate/ampspertesla*1000,0))
//			magnetvalsstr[5][1] = num2str(ramprate)
//			magnetvalsstr[6][1] = state
//			print "Current values updated"
//			break
//		case "setfield":
//			// Update the field setpoint
//			field_setpoint = roundNum(str2num(magnetvalsstr[2][1]),2)
//			check = SetField(field_setpoint)
//			if (check == 1)
//				print "Setting the magnetic field to", magnetvalsstr[2][1],"mT"
//				oldsetpoint = magnetvalsstr[2][1]
//			else
//				magnetvalsstr[2][1] = oldsetpoint
//			endif
//			break
//		case "setrate":
//			// Update the sweep rate
//			check = SetSweepRate(str2num(magnetvalsstr[4][1]))
//			if (check == 1)
//				print "Setting the sweep rate to", magnetvalsstr[4][1],"mT/min"
//				oldsweeprate = magnetvalsstr[4][1]
//			else
//				magnetvalsstr[4][1] = oldsweeprate
//			endif
//			break
//	endswitch
//end

//// Status for logging ////

//function/s GetIPSStatus()
//	svar ips_comport
//	string buffer = ""
//	buffer = addJSONKeyVal(buffer, "field mT", numVal=GetField(), fmtNum="%.3f")
//	buffer = addJSONKeyVal(buffer, "rate mT/min", numVal=GetSweepRate(), fmtNum="%.1f")
//	buffer = addJSONKeyVal(buffer, "com_port", strVal=ips_comport, addQuotes=1)
//	return addJSONKeyVal("", "IPS", strVal = buffer)
//end`
