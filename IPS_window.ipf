#pragma rtGlobals=1		// Use modern global access method.

//	Driver communicates over serial, remenber to set the correct port in SetSerial()
//	Adding an interavtive window
//	Currents are returned in amps, while field values are return in mT
//	Edit ampspertesla, maxfield and maxramprate according to the magnet in use
//	Procedure written by Christian Olsen 2016-01-26

///// Initiate Magnet /////

function InitMagnet()
	// BF 10T magnet: x.xx A/T, 10000 mT, 300 mT/min
	// IGH 12T magnet: 8.2061452674 A/T, 12000 mT, 400 mT/min
	variable/g ampspertesla = 8.2061452674 // A/T
	variable/g maxfield = 12000 // mT
	variable/g maxramprate = 400 // mT/min
	MagnetSetup() // Setting up serial communication
	WriteMagnetCheckResponse("C3") // Remote and unlocked
	WriteMagnetCheckResponse("M9") // Set display to Tesla
	WriteMagnet("Q4") // Use extented resolusion (0.0001 amp/0.01 mT), no return given by magnet
	WriteMagnetCheckResponse("A0") // Set to Hold
	dowindow/k IPS_Window
	make /t/o magnetvalsstr = {{"Current field [mT]","Current amp [A]","Set point [mT]","Set point [A]","Sweep rate [mT/min]","Sweep rate [A/min]","Switch heater"},{"0","0","0","0","0","0","OFF"}}
	make /o listboxattr_mag={{0,0,0,0,0,0,0},{0,0,2,0,2,0,0}} // Setting list attributes. 0 = non-interactive, 2 = interactive
	SetSweepRate(100)
	string/g oldsweeprate = magnetvalsstr[4][1]
	string/g oldsetpoint = "0"
	execute("IPS_window()")
	execute("Reminder_window()")
	PauseForUser Reminder_window
end

function TestMagnet()
	MagnetSetup() // Setting up serial communication
	WriteMagnet("C3") // Remote and unlocked
	print "Write completed"
	ReadMagnet()
	print "Read completed"
	print "Test completed"
end

function SetSerial()
	string/g comport = "COM3" // Set to the right COM Port
	string cmd
	sprintf cmd, "VDTOperationsPort2 %s", comport
	execute(cmd)
end

function MagnetSetup()
	string cmd
	SetSerial()
	sprintf cmd, "VDT2 baud=9600, stopbits=2, terminalEOL=0, killio"
	execute(cmd)
end

///// Talk to Magnet /////

	//// Base functions ////

function GetCurrent() // return in A
	wave/t magnetvalsstr=magnetvalsstr
	NVAR ampspertesla=ampspertesla
	variable current
	current = QueryMagnet("R0")
	magnetvalsstr[1][1] = num2str(current)
	magnetvalsstr[0][1] = num2str(round_num(current/ampspertesla*1000,2))
	return current
end 

function GetField() // return in mT
	wave/t magnetvalsstr=magnetvalsstr
	NVAR ampspertesla=ampspertesla
	variable current,round_field
	current = QueryMagnet("R0")
	round_field = round_num(current/ampspertesla*1000,2)
	magnetvalsstr[0][1] = num2str(round_field)
	magnetvalsstr[1][1] = num2str(current)
	return round_field
end

function SetCurrent(amps) // in A
	variable amps
	NVAR maxfield=maxfield
	NVAR ampspertesla=ampspertesla
	wave/t magnetvalsstr=magnetvalsstr
	if (abs(amps) > maxfield*ampspertesla/1000)
		print "Max current is "+num2str(maxfield*ampspertesla/1000)+" A"
		return -1
	else	
		WriteMagnetCheckResponse("I"+num2str(amps))
		WriteMagnet("$A1")
		magnetvalsstr[3][1] = num2str(amps)
		magnetvalsstr[2][1] = num2str(round_num(amps/ampspertesla*1000,2))
	endif
end

function SetField(field) // in mT
	variable field
	NVAR maxfield=maxfield
	NVAR ampspertesla
	variable round_amps
	wave/t magnetvalsstr=magnetvalsstr
	if (abs(field) > maxfield)
		print "Max field is "+num2str(maxfield)+" mT"
		return -1
	else
		round_amps = round_num(field*ampspertesla/1000,4)
		WriteMagnetCheckResponse("I"+num2str(round_amps))
		WriteMagnet("$A1")
		magnetvalsstr[2][1] = num2str(field)
		magnetvalsstr[3][1] = num2str(round_amps)
		return 1
	endif
end

function SetSweepRate(ramprate) // mT/min
	variable ramprate
	NVAR maxramprate=maxramprate
	NVAR ampspertesla=ampspertesla
	wave/t magnetvalsstr=magnetvalsstr
	variable round_amps
	if (ramprate < 0 || ramprate > maxramprate)
		print "Max sweep rate is "+num2str(maxramprate)+" mT/min"
		return -1
	else
		round_amps = round_num(ramprate*ampspertesla/1000,3)
		WriteMagnetCheckResponse("S"+num2str(round_amps))
		magnetvalsstr[5][1] = num2str(round_amps)
		magnetvalsstr[4][1] = num2str(ramprate)
		return 1
	endif	
end

function GetSweepRate() // returns in mT/min
	variable ramprate_amps,round_field
	wave/t magnetvalsstr=magnetvalsstr
	NVAR ampspertesla=ampspertesla
	ramprate_amps = QueryMagnet("R6")
	round_field = round_num(ramprate_amps/ampspertesla*1000,0)
	magnetvalsstr[4][1] = num2str(round_field)
	magnetvalsstr[5][1] = num2str(ramprate_amps)
	return round_field
end

function GetSweepRateCurrent() // returns in A/min
	variable ramprate_amps,round_field
	wave/t magnetvalsstr=magnetvalsstr
	NVAR ampspertesla=ampspertesla
	ramprate_amps = QueryMagnet("R6")
	round_field = round_num(ramprate_amps/ampspertesla*1000,0)
	magnetvalsstr[4][1] = num2str(round_field)
	magnetvalsstr[5][1] = num2str(ramprate_amps)
	return ramprate_amps
end

function/s ExamineStatus()
	string status
	WriteMagnet("X")
	status = ReadMagnet()
	return status
end

function GetHeaterStatus()
	string status
	status = ExamineStatus()
	return str2num(status[8])
end

function SwitchHeater(newstate) // Call with "ON" or "OFF"
	string newstate
	string oldstate
	variable heaterstate
	wave/t magnetvalsstr=magnetvalsstr
	heaterstate = GetHeaterStatus()
	if (heaterstate == 5)
		print "Heater error"
		return -1
	endif
	strswitch(newstate)
		case "ON":
			if (heaterstate == 0)
				WriteMagnetCheckResponse("H1")
				print "waiting 20 sec for heater to respond"
				magnetvalsstr[6][1] = newstate
				sleep/S 20
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
				WriteMagnetCheckResponse("H0")
				print "waiting 20 sec for heater to respond"
				magnetvalsstr[6][1] = newstate
				sleep/S 20
			else
				printf "Heater state is H%d, check manual",heaterstate
			endif
			break
		default:
			printf "Command: (%s) not understood. Pass ON or OFF",newstate
			break
	endswitch
end

function round_num(number,decimalplace) //for integer pass 0 as decimalplace
	variable number, decimalplace
	variable multiplier
	multiplier = 10^decimalplace
	return round(number*multiplier)/multiplier
end

	//// Advanced functions ////

function SetFieldWait(field) // in mT
	// Setting new set point and waiting for magnet to reach new set point
	variable field
	variable err = 0.06 // this should really be 0.01, but I find it gets stuck in that case --Nik
					// even with 0.05 it gets stuck. I changed to it 0.06 -- Mohammad
	variable currentfield
	variable sweeprate
	variable sweeptime
	//currentfield = GetField()
	//sweeprate = GetSweepRate()
	//sweeptime = CalcSweepTime(currentfield,field,sweeprate)
	SetField(field)
	do
		sleep/s 0.1
		currentfield = GetField()
	while (abs(currentfield - field) > err)
end

function CalcSweepTime(currentfield,newfield,sweeprate)
	variable currentfield // in mT
	variable newfield // in mT
	variable sweeprate // in mT/min
	return abs(currentfield - newfield)/sweeprate*60 // in sec
end

///// Magnet communication /////

function WriteMagnet(command)	// Writes command without expecting a response
	string command
	SVAR comport=comport
	string cmd
	NVAR V_VDT

	// Insert serial communication commands
	SetSerial()
	cmd = "VDTWrite2 /O=2 /Q \""+command+"\\r\""
	execute(cmd)
	if (V_VDT == 0)
		abort "Write failed on command "+cmd
	endif
end

function/s ReadMagnet()
	string/g response
	string cmd
	NVAR V_VDT
	
	// Insert serial communication commands
	cmd = "VDTRead2 /O=2 /Q response"
	execute(cmd)
	if (V_VDT == 0)
		abort "Failed to read"
	endif
	return response
end

function WriteMagnetCheckResponse(command)	// Checks response for error
	string command
	string cmd
	string response

	WriteMagnet(command)
	response = ReadMagnet()
	if (cmpstr(response[0],"?") == 0)
		printf "Error detected, command not executed. Command was: %s", command
	endif
end

function QueryMagnet(qstring)
	string qstring
	string response
	
	WriteMagnet(qstring)
	response = ReadMagnet()
	if (cmpstr(response[0],"?") == 0)
		printf "Error detected, command not executed. Command was: %s", qstring
	endif
	return str2num(response[1,inf])
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

Window Reminder_window() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(0,0, 210,130) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 20,fstyle= 1 
	DrawText 25, 40,"Magnet Settings" // Headline
	DrawText 10, 80, "Remember to change Amp/Tesla,"
	DrawText 10, 95, "max field and max sweep rate!"
	Button ok_button,pos={40,100},size={110,20},proc=ok_button,title="OK"
end

function ok_button(action) : ButtonControl
	string action
	dowindow /k Reminder_window
end

function update_magnet(action) : ButtonControl
	string action
	wave/t magnetvalsstr=magnetvalsstr
	NVAR ampspertesla
	SVAR oldsetpoint
	SVAR oldsweeprate
	variable field,ramprate,heater,check,field_setpoint
	string state
	controlinfo /W=IPS_Window maglist
	strswitch(action)
		case "updatevals":
			// Update current field and amp values
			field = GetField()
			ramprate = GetSweepRateCurrent()
			heater = GetHeaterStatus()
			if (heater == 0)
				state = "OFF"
			elseif (heater == 1)
				state = "ON"
			else
				state = "Heater fault"
			endif
			magnetvalsstr[0][1] = num2str(field)
			magnetvalsstr[1][1] = num2str(round_num(field*ampspertesla/1000,4))
			magnetvalsstr[4][1] = num2str(round_num(ramprate/ampspertesla*1000,0))
			magnetvalsstr[5][1] = num2str(ramprate)
			magnetvalsstr[6][1] = state
			print "Current values updated"
			break
		case "setfield":
			// Update the field setpoint
			field_setpoint = round_num(str2num(magnetvalsstr[2][1]),2)
			check = SetField(field_setpoint)
			if (check == 1)
				print "Setting the magnetic field to", magnetvalsstr[2][1],"mT" 
				oldsetpoint = magnetvalsstr[2][1]
			else
				magnetvalsstr[2][1] = oldsetpoint
			endif
			break
		case "setrate":
			// Update the sweep rate
			check = SetSweepRate(str2num(magnetvalsstr[4][1]))
			if (check == 1)
				print "Setting the sweep rate to", magnetvalsstr[4][1],"mT/min"
				oldsweeprate = magnetvalsstr[4][1]
			else
				magnetvalsstr[4][1] = oldsweeprate
			endif
			break
	endswitch
end

//// Status for logging ////

function/s GetIPSStatus()
	string winfcomments=""
	string buffer
	sprintf buffer, "Magnet:\r\tField = %.3f mT\r", GetField()
	winfcomments += buffer
	sprintf buffer, "\tSweep Rate = %.1f mT/min\r", GetSweepRate()
	winfcomments += buffer	
	return winfcomments
end`