#pragma rtGlobals=1		// Use modern global access method.

//	Driver communicates over serial, remenber to set the correct port in SetSerial()
//	Adding an interavtive window
//	Currents are returned in amps, while field values are return in mT
//	Procedure written by Christian Olsen 2016-01-26
//  Updated to use VISA/async Nik/Christian 05-XX-2018

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

	string response = queryInstr(instrID, cmd+"\r", read_term = "\r")
	if (cmpstr(response[0],"?") == 0)
		printf "[WARNING] IPS command did not execute correctly: %s\r", cmd
	endif
end

///////////////////////
/// Initiate Magnet ///
///////////////////////

function initIPS120(instrID)
	variable instrID
	string /g ips_controller_addr = getResourceAddress(instrID) // for use by window functions

	// currently hard coded for BFXLD 3" magnet
	variable/g ampspertesla=9.569 // A/T
	variable/g maxfield=9         // mT
	variable/g maxramprate=182    // mT/min, depends on max field

	ipsCommSetup(instrID) // Setting up serial communication
							// possibly redundant if setup done with ScanController_VISA
						  	// but it doesn't hurt (or take any time) to do it again


	writeIPScheck(instrID, "C3") // Remote and unlocked
	sc_sleep(0.02)
	writeIPScheck(instrID, "M9") // Set display to Tesla
	writeInstr(instrID, "Q4")    // Use extented resolusion (0.0001 amp/0.01 mT), no response from magnet
	writeIPScheck(instrID, "A0") // Set to Hold

	dowindow/k IPS_Window
	make /t/o magnetvalsstr = {{"Current field [mT]","Current amp [A]","Set point [mT]","Set point [A]","Sweep rate [mT/min]","Sweep rate [A/min]","Switch heater"},{"0","0","0","0","0","0","OFF"}}
	make /o listboxattr_mag={{0,0,0,0,0,0,0},{0,0,2,0,2,0,0}} // Setting list attributes. 0 = non-interactive, 2 = interactive

	setIPS120rate(instrID, 100)

	string/g ips_oldsweeprate = magnetvalsstr[4][1]
	string/g ips_oldsetpoint = "0"

	execute("IPS_window()")
	execute("Magnetsettings_window()")
	PauseForUser Magnetsettings
end

///// Talk to Magnet /////

function getIPS120volts(instrID) // return in A
	variable instrID
	string buffer = queryInstr(instrID, "R1", read_term = "\r")[1,inf] // get value

	return str2num(buffer)
end

threadsafe function getIPS120volts_async(instrID) // Units: mV
	variable instrID
	string buffer = queryInstr(instrID, "R1", read_term = "\r")[1,inf] // get value

	return str2num(buffer)
end

function getIPS120current(instrID) // return in A
	variable instrID
	wave/t magnetvalsstr=magnetvalsstr
	NVAR ampspertesla=ampspertesla
	variable current

	current = str2num(queryInstr(instrID, "R0", read_term = "\r")[1,inf]) // get value

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

	current = str2num(queryInstr(instrID, "R0\r", read_term = "\r")[1,inf]) // get current
	field = roundNum(current/ampspertesla*1000,2) // calculate field

	// save to waves for window
	magnetvalsstr[0][1] = num2str(field)
	magnetvalsstr[1][1] = num2str(current)

	return field
end

function setIPS120current(instrID, amps) // in A
	variable instrID, amps
	NVAR maxfield=maxfield
	NVAR ampspertesla=ampspertesla
	wave/t magnetvalsstr=magnetvalsstr
	if (abs(amps) > maxfield*ampspertesla/1000)
		print "Magnet current not set, exceeds limit: "+num2str(maxfield*ampspertesla/1000)+" A"
		return -1
	else
		writeIPScheck(instrID, "I"+num2str(amps))
		writeInstr(instrID, "$A1\r")
		magnetvalsstr[3][1] = num2str(amps)
		magnetvalsstr[2][1] = num2str(roundNum(amps/ampspertesla*1000,2))
	endif
end

function setIPS120field(instrID, field) // in mT
	variable instrID, field
	NVAR maxfield=maxfield
	NVAR ampspertesla
	variable amps
	wave/t magnetvalsstr=magnetvalsstr
	if (abs(field) > maxfield)
		print "Max field is "+num2str(maxfield)+" mT"
		return -1
	else
		amps = roundNum(field*ampspertesla/1000,4)
		writeIPScheck(instrID, "I"+num2str(amps))
		writeInstr(instrID, "$A1\r")
		magnetvalsstr[2][1] = num2str(field)
		magnetvalsstr[3][1] = num2str(amps)
		return 1
	endif
end

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

	ramprate_amps = str2num(queryInstr(instrID, "R6\r", read_term = "\r")[1,inf])
	ramprate_field = roundNum(ramprate_amps/ampspertesla*1000,0)
	magnetvalsstr[4][1] = num2str(ramprate_field)
	magnetvalsstr[5][1] = num2str(ramprate_amps)
	return ramprate_field
end

function getIPS120rate_current(instrID) // returns in A/min
    variable instrID
    variable ramprate_amps,ramprate_field
	wave/t magnetvalsstr=magnetvalsstr
	NVAR ampspertesla=ampspertesla
	ramprate_amps = str2num(queryInstr(instrID, "R6\r", read_term = "\r")[1,inf])
	ramprate_field = roundNum(ramprate_amps/ampspertesla*1000,0)
	magnetvalsstr[4][1] = num2str(ramprate_field)
	magnetvalsstr[5][1] = num2str(ramprate_amps)
	return ramprate_amps
end

function /s getIPS120status(instrID)
	variable instrID
	string status
	writeInstr(instrID, "X\r")
	status = readInstr(instrID, read_term = "\r")
	return status
end

function getIPS120status_heater(instrID)
    variable instrID
	string status
	status = getIPS120status(instrID)
	return str2num(status[8])
end

function switchHeaterIPS120(instrID, newstate) // Call with "ON" or "OFF"
	variable instrID
	string newstate
	string oldstate
	variable heaterstate
	wave/t magnetvalsstr=magnetvalsstr

	heaterstate = getIPS120status_heater(instrID)

	if (heaterstate == 5)
		print "Heater error"
		return -1
	endif

	variable start_time = datetime
	strswitch(newstate)
		case "ON":
			if (heaterstate == 0)
				writeIPScheck(instrID, "H1")
				print "waiting 20 sec for heater to respond"
				magnetvalsstr[6][1] = newstate
				do
					sleep /T 1
				while(datetime - start_time < 20.0)
			elseif (heaterstate == 1)
				print "Heater already on"
			else
				printf "Heater state is H%d, check manual",heaterstate
			endif
			break
		case "OFF":
			if (heaterstate == 0)
				print "Heater already off"
			elseif (heaterstate == 1)
				writeIPScheck(instrID, "H0")
				print "waiting 20 sec for heater to respond"
				magnetvalsstr[6][1] = newstate
				do
					sleep /T 1
				while(datetime - start_time < 20.0)
			else
				printf "Heater state is H%d, check manual",heaterstate
			endif
			break
		default:
			printf "Command: (%s) not understood. Pass ON or OFF",newstate
			break
	endswitch
end

//// Advanced functions ////

function waitIPS120field(instrID, field) // in mT
	// Setting new set point and waiting for magnet to reach new set point
	variable instrID, field
	variable status, count = 0

	setIPS120field(instrID, field)
	do

		do
			sc_sleep(0.02)
			getIPS120field(instrID) // forces the window to update
			status = str2num(queryInstr(instrID, "X\r", read_term = "\r")[11])
		while(numtype(status)==2)

	while(status!=0)

end

function CalcSweepTime(currentfield,newfield,sweeprate)
	variable currentfield // in mT
	variable newfield // in mT
	variable sweeprate // in mT/min
	return abs(currentfield - newfield)/sweeprate*60 // in sec
end

///// User interface /////

Window IPS_Window() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(0,0,430,300) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 150, 45,"Magnet" // Headline
	ListBox maglist,pos={10,60},size={410,180},fsize=16,frame=2 // interactive list
	ListBox maglist,fStyle=1,listWave=root:magnetvalsstr,selWave=root:listboxattr_mag,mode= 1
	Button setfield,pos={170,250},size={110,20},proc=update_magnet,title="Change setpoint" // adding buttons
	Button setrate,pos={290,250},size={130,20},proc=update_magnet,title="Change sweep rate"
	Button updatevals, pos={10,250},size={150,20},proc=update_magnet,title="Update current values"
EndMacro

Window Magnetsettings_window() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(0,0, 290,120)/N=MagnetSettings // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 20,fstyle= 1
	DrawText 50, 40,"Choose Magnet" // Headline
	Button CMmagnet,pos={10,60},size={130,20},proc=magnet_button,title="Marcus 10T Magnet"
    Button XLD3INmagnet, pos={150,60},size={130,20},proc=magnet_button,title="XLD 3\" 9T Magnet"
	Button IGHmagnet,pos={10,90},size={130,20},proc=magnet_button,title="IGHN 12T Magnet"
	Button AMmagnet,pos={150,90},size={130,20},proc=magnet_button,title="AM 6T z-axis"
end

function magnet_button(action) : ButtonControl
	string action
	nvar ampspertesla, maxfield, maxramprate
	strswitch(action)
		case "CMmagnet":
			ampspertesla = 9.6768//A/T
			maxfield = 10000//mT
			maxramprate = 300//mT/min
			dowindow /k MagnetSettings
			break
        case "XLD3INmagnet":
			ampspertesla = 9.569 // A/T
			maxfield = 9000.585//mT
			maxramprate = 174 //mT/min
			dowindow /k MagnetSettings
			break
		case "IGHmagnet":
			ampspertesla = 8.2061452674//A/T
			maxfield = 12000//mT
			maxramprate = 400//mT/min
			dowindow /k MagnetSettings
			break
		case "AMmagnet":
			ampspertesla =9.9502//A/T
			maxfield = 6000 //mT
			maxramprate = 1150 //mT/min
			dowindow /k MagnetSettings
			break
	endswitch
end

function update_magnet(action) : ButtonControl
	string action
	variable check=0
	wave/t magnetvalsstr=magnetvalsstr
	controlinfo /W=IPS_Window maglist

    // open temporary connection to IPS
    svar ips_controller_addr
    variable status, localRM

    status = viOpenDefaultRM(localRM) // open local copy of resource manager
    if(status < 0)
        VISAerrormsg("open IPS connection:", localRM, status)
        abort
    endif
    openInstr("ips_window_resource", ips_controller_addr, localRM=localRM, verbose=0)
    nvar ips_window_resource

	strswitch(action)
		case "updatevals":
            nvar ampspertesla
            string heater_state

			// Update current field and amp values
			variable field = getIPS120field(ips_window_resource)
			variable ramprate = getIPS120rate_current(ips_window_resource)
			variable heater = getIPS120status_heater(ips_window_resource)
			if (heater == 0)
				heater_state = "OFF"
			elseif (heater == 1)
				heater_state = "ON"
			else
				heater_state = "Heater fault"
			endif
			magnetvalsstr[0][1] = num2str(field)
			magnetvalsstr[1][1] = num2str(roundNum(field*ampspertesla/1000,4))
			magnetvalsstr[4][1] = num2str(roundNum(ramprate/ampspertesla*1000,0))
			magnetvalsstr[5][1] = num2str(ramprate)
			magnetvalsstr[6][1] = heater_state
			print "UPDATED: IPS120 window data"
			break

		case "setfield":
            svar ips_oldsetpoint

			// Update the field setpoint
			variable setpoint = roundNum(str2num(magnetvalsstr[2][1]),2)
			check = setIPS120field(ips_window_resource, setpoint)
			if (check == 1)
				printf "Setting IPS120 field: %.2fmT\r", setpoint
				ips_oldsetpoint = magnetvalsstr[2][1]
			else
				magnetvalsstr[2][1] = ips_oldsetpoint
			endif
			break

		case "setrate":
            svar ips_oldsweeprate

			// Update the sweep rate
			check = setIPS120rate(ips_window_resource, str2num(magnetvalsstr[4][1]))
			if (check == 1)
				printf "Setting IPS120 ramprate: %.0f mT/min\r", str2num(magnetvalsstr[4][1])
				ips_oldsweeprate = magnetvalsstr[4][1]
			else
				magnetvalsstr[4][1] = ips_oldsweeprate
			endif
			break

	endswitch

    viClose(ips_window_resource) // close VISA resource

end

////////////////////////////
//// Status for logging ////
////////////////////////////

function/s GetIPSStatus(instrID)
    variable instrID
	string buffer = ""
	buffer = addJSONKeyVal(buffer, "field mT", numVal=getIPS120field(instrID), fmtNum="%.3f")
	buffer = addJSONKeyVal(buffer, "rate mT/min", numVal=getIPS120rate(instrID), fmtNum="%.1f")
    svar ips_controller_addr
	buffer = addJSONKeyVal(buffer, "com_port", strVal=ips_controller_addr, addQuotes=1)
	return addJSONKeyVal("", "IPS", strVal = buffer)
end
