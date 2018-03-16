#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1	// Use modern global access method

///////////////////////////
//// Vector magnet driver ////
//////////////////////////

// Driver communicates over serial, remember to set the correct serial ports in three global strings called IPSz_serial, L625x_serial & L625y_serial.
// Procedure written by Christian Olsen 2017-03-15
// Main axis is powered by an IPS120 and the in-plane fields are powered by two Lakeshore 625 power supplies.

function InitVectorMagnet()
	// 3-axis magnet. 6T-1T-1T. 
	variable/g ampsperteslax=55.49, ampsperteslay=55.22, ampsperteslaz=9.950// A/T
	variable/g maxfieldx=1000, maxfieldy=1000, maxfieldz=6000 // mT
	variable/g maxrampratex=300, maxrampratey=300, maxrampratez=300 // mT/min
	
	// Setup variables and waves needed for the control window.
	// Add control window stuff here.
	make/t/o outputvalstr={{"X [mT]:","Y [mT]:","Z [mT]:"},{"0","0","0"}}
	make/o listboxattr_outputlist={{0,0,0},{0,0,0}}
	make/t/o sweepratevalstr={{"X [mT/min]:","Y [mT/min]:","Z [mT/min]:"},{"0","0","0"}}
	make/o listboxattr_sweepratelist={{0,0,0},{2,2,2}}
	make/t/o setpointvalstr={{"X [mT]:","Y [mT]:","Z [mT]:"},{"0","0","0"}}
	make/o listboxattr_setpointlist={{0,0,0},{2,2,2}}
	make/t/o sphericalvalstr={{"R [mT]:","Theta [rad]:","Phi [rad]:"},{"0","0","0"}}
	make/o listboxattr_sphericallist={{0,0,0},{0,0,0}}
	string/g oldsweepratex,oldsweepratey,oldsweepratez
	string/g oldsetpointx="0",oldsetpointy="0",oldsetpointz="0"
	
	CheckSerialPorts() // Checking that we can talk to the power supplies.
	
	SetSweepRateAll(100,100,100) // Fixing the sweeprates at 100 mT/min, so the control window is correct at startup.
	dowindow /k Vector_window
	execute("Vector_window()")
end

function CheckSerialPorts()
	svar IPSz_serial, L625x_serial, L625y_serial
	string response
	
	// Checking IPS120
	initIPS()
	WriteVector("X","ips")
	response = ReadVector("ips")
	
	// Checking L625 x-axis
	InitL625("x")
	WriteVector("*IDN?","l625x")
	response = ReadVector("l625x")
	if(strsearch(response,"LSCI",0) ==-1)
		abort("L625 error. It is highly likely that \"L625_serial\" is not set correctly.")
	endif
	
	// Checking L625 y-axis
	InitL625("y")
	WriteVector("*IDN?","l625y")
	response = ReadVector("l625y")
	if(strsearch(response,"LSCI",0) ==-1)
		abort("L625 error. It is highly likely that \"L625_serial\" is not set correctly.")
	endif
end

function initIPS()
	SetSerialPortMagnet("ips")
	VDT2 baud=9600, stopbits=2, terminalEOL=0, killio
	WriteVector("$C3","ips") // Remote and unlocked
	WriteVector("$M9","ips") // Set display to Tesla
	WriteVector("$Q4","ips") // Use extended resolutuon (0.0001 amp)
	WriteVector("$A0","ips")// Set to Hold
	SetSweepRatez(100) // Set sweeprate of main axis
end

function InitL625(axis) // axis must be "x" or "y"
	string axis
	string port
	
	port = "l625"+axis
	SetSerialPortMagnet(port)
	VDT2 baud=9600, stopbits=1, databits=7, parity=1, terminalEOL=2, killio
	WriteVector("DISP 1,0,1",port) // Set the display to show output in Tesla, show remote voltage signal & set the brigtness to 50%.
	sleep/s 0.05
	WriteVector("LOCK 2,123",port) // Locks keypad access to LIMIT, sets passcode to 123.
	sleep/s 0.05
end

function SetSerialPortMagnet(powersupply)
	string powersupply
	string/g serialport=""
	
	if(cmpstr(powersupply,"ips")==0)
		svar IPSz_serial
		serialport = IPSz_serial
	elseif(cmpstr(powersupply,"l625x")==0)
		svar L625x_serial
		serialport = L625x_serial
	elseif(cmpstr(powersupply,"l625y")==0)
		svar L625y_serial
		serialport = L625y_serial
	endif

	VDTOperationsPort2 $serialport
end

////////////////////
//// Get functions ////
///////////////////

function GetCurrentx() // Units: A
	nvar ampsperteslax
	wave/t outputvalstr,sphericalvalstr
	wave sphericalcoordinates
	variable current,field
	
	current=QueryVector("RDGI?","l625x")
	// Update control window
	field = Round_Number(current/ampsperteslax*1000,5)
	CartisiantoSpherical(field,str2num(outputvalstr[1][1]),str2num(outputvalstr[2][1]))
	outputvalstr[0][1] = num2str(field)
	sphericalvalstr[0][1] = num2str(sphericalcoordinates[0])
	sphericalvalstr[1][1] = num2str(sphericalcoordinates[1])
	sphericalvalstr[2][1] = num2str(sphericalcoordinates[2])
	
	return current
end

function GetCurrenty() // Units: A
	nvar ampsperteslay
	wave/t outputvalstr,sphericalvalstr
	wave sphericalcoordinates
	variable current,field
	
	current=QueryVector("RDGI?","l625y")
	// Update control window
	field = Round_Number(current/ampsperteslay*1000,5)
	CartisiantoSpherical(str2num(outputvalstr[0][1]),field,str2num(outputvalstr[2][1]))
	outputvalstr[1][1] = num2str(field)
	sphericalvalstr[0][1] = num2str(sphericalcoordinates[0])
	sphericalvalstr[1][1] = num2str(sphericalcoordinates[1])
	sphericalvalstr[2][1] = num2str(sphericalcoordinates[2])
	
	return current
end

function GetCurrentz() // Units: A
	nvar ampsperteslaz
	wave/t outputvalstr,sphericalvalstr
	wave sphericalcoordinates
	variable current,field
	string current_raw
	
	current = QueryVectorIPS("R0")
	
	// Update control window
	field = Round_Number(current/ampsperteslaz*1000,5)
	CartisiantoSpherical(str2num(outputvalstr[0][1]),str2num(outputvalstr[1][1]),field)
	outputvalstr[2][1] = num2str(field)
	sphericalvalstr[0][1] = num2str(sphericalcoordinates[0])
	sphericalvalstr[1][1] = num2str(sphericalcoordinates[1])
	sphericalvalstr[2][1] = num2str(sphericalcoordinates[2])
	
	return current
end

function GetAllCurrent() // Units: A
	nvar ampsperteslax, ampsperteslay, ampsperteslaz
	make/o/n=3 currentwave
	
	currentwave[0] = GetCurrentx()
	currentwave[1] = GetCurrenty()
	currentwave[2] = GetCurrentz()
end

function GetFieldx() // Units: mT
	nvar ampsperteslax
	variable field, current
	wave/t outputvalstr
	
	current = GetCurrentx()
	field = Round_Number(current/ampsperteslax*1000,3)
	outputvalstr[0][1] = num2str(field)
	
	return field
end

function GetFieldy() // Units: mT
	nvar ampsperteslay
	variable field, current
	wave/t outputvalstr
	
	current = GetCurrenty()
	field = Round_Number(current/ampsperteslay*1000,3)
	outputvalstr[1][1] = num2str(field)
	
	return field
end

function GetFieldz() // Units: mT
	nvar ampsperteslaz
	variable current,field
	wave/t outputvalstr
	
	current = GetCurrentz()
	field = Round_Number(current/ampsperteslaz*1000,3)
	outputvalstr[2][1] = num2str(field)
	
	return field
end

function GetFieldAll() // Units: mT
	make/n=3/o fieldwave
	
	fieldwave[0] = GetFieldx()
	fieldwave[1] = GetFieldy()
	fieldwave[2] = GetFieldz()
end

function GetSweepRatex() // Units: mT/min
	nvar ampsperteslax
	wave/t sweepratevalstr
	variable rampratefield, currentramprate
	
	currentramprate = QueryVector("RATE?","l625x") // A/s
	rampratefield = Round_Number(currentramprate/ampsperteslax*60*1000,5)
	// Update control window
	sweepratevalstr[0][1] = num2str(rampratefield)
	
	return rampratefield
end

function GetSweepRatey() // Units: mT/min
	nvar ampsperteslay
	wave/t sweepratevalstr
	variable rampratefield, currentramprate
	
	currentramprate = QueryVector("RATE?","l625y") // A/s
	rampratefield = Round_Number(currentramprate/ampsperteslay*60*1000,5)
	// Update control window
	sweepratevalstr[1][1] = num2str(rampratefield)
	
	return rampratefield
end

function GetSweepRatez() // Units: mT/min
	variable currentramprate, rampratefield
	wave/t sweepratevalstr
	nvar ampsperteslaz
	
	currentramprate = QueryVectorIPS("R6")
	rampratefield = Round_Number(currentramprate/ampsperteslaz*1000,5)
	// Update control window
	sweepratevalstr[2][1] = num2str(rampratefield)
	
	return rampratefield
end

function GetSweeprateAll()
	make/o/n=3 sweepratewave
	
	sweepratewave[0] = GetSweepRatex()
	sweepratewave[1] = GetSweepRatey()
	sweepratewave[2] = GetSweepRatez()
end

////////////////////
//// Set functions ////
///////////////////

function SetCurrentx(output) // Units: A
	variable output
	string cmd
	wave/t setpointvalstr
	nvar maxfieldx, ampsperteslax
	
	if (abs(output) > maxfieldx*ampsperteslax/1000)
		print "Max current is "+num2str(maxfieldx*ampsperteslax/1000)+" A"
	else	
		cmd = "SETI "+num2str(output)
		WriteVector(cmd,"l625x")
		setpointvalstr[0][1] = num2str(Round_Number(output/ampsperteslax*1000,5))
	endif
end

function SetCurrenty(output) // Units: A
	variable output
	string cmd
	wave/t setpointvalstr
	nvar maxfieldy, ampsperteslay
	
	if (abs(output) > maxfieldy*ampsperteslay/1000)
		print "Max current is "+num2str(maxfieldy*ampsperteslay/1000)+" A"
	else	
		cmd = "SETI "+num2str(output)
		WriteVector(cmd,"l625y")
		setpointvalstr[1][1] = num2str(Round_Number(output/ampsperteslay*1000,5))
	endif
end

function SetCurrentz(output) // Units: A
	variable output
	string cmd
	wave/t setpointvalstr
	nvar maxfieldz,ampsperteslaz
	
	if (abs(output) > maxfieldz*ampsperteslaz/1000)
		print "Max current is "+num2str(maxfieldz*ampsperteslaz/1000)+" A"
	else	
		cmd = "$I"+num2str(output)
		WriteVector(cmd,"ips")
		WriteVector("$A1","ips")
		setpointvalstr[2][1] = num2str(Round_Number(output/ampsperteslaz*1000,5))
	endif
end

function SetFieldx(output) // Units: mT
	variable output
	nvar ampsperteslax, maxfieldx
	variable round_amps
	string cmd
	
	if (abs(output) > maxfieldx)
		print "Max field is "+num2str(maxfieldx)+" mT"
		return -2
	else
		round_amps = Round_Number(output*ampsperteslax/1000,5)
		SetCurrentx(round_amps)
		return 2
	endif
end

function SetFieldy(output) // Units: mT
	variable output
	nvar ampsperteslay, maxfieldy
	variable round_amps
	string cmd
	
	if (abs(output) > maxfieldy)
		print "Max field is "+num2str(maxfieldy)+" mT"
		return -3
	else
		round_amps = Round_Number(output*ampsperteslay/1000,5)
		SetCurrenty(round_amps)
		return 3
	endif
end

function SetFieldz(output) // Units: mT
	variable output
	nvar ampsperteslaz, maxfieldz
	variable round_amps
	string cmd
	
	if (abs(output) > maxfieldz)
		print "Max field is "+num2str(maxfieldz)+" mT"
		return -4
	else
		round_amps = Round_Number(output*ampsperteslaz/1000,5)
		SetCurrentz(round_amps)
		return 4
	endif
end

function SetFieldxWait(output)
	variable output
	
	SetFieldx(output)
	do
		sc_sleep(0.1)
		GetFieldAll()
	while (CheckMagnetRamp("l625x"))
end

function SetFieldyWait(output)
	variable output
	
	SetFieldy(output)
	do
		sc_sleep(0.1)
		GetFieldAll()
	while (CheckMagnetRamp("l625y"))
end

function SetFieldzWait(output)
	variable output
	
	SetFieldz(output)
	do
		sc_sleep(0.1)
		GetFieldAll()
	while (CheckMagnetRamp("ips"))
end

function SetSweepRatex(output) // Units: mT/min
	variable output
	nvar maxrampratex,ampsperteslax
	wave/t sweepratevalstr
	variable ramprate_amps
	string cmd
	
	if (output < 0 || output > maxrampratex)
		print "Max sweep rate is "+num2str(maxrampratex)+" mT/min"
		return -2
	else
		ramprate_amps = Round_Number(output*(ampsperteslax/(1000*60)),5) // A/s
		cmd = "RATE "+num2str(ramprate_amps)
		WriteVector(cmd,"l625x")
		sweepratevalstr[0][1] = num2str(output)
		return 2
	endif
end

function SetSweepRatey(output) // Units: mT/min
	variable output
	nvar maxrampratey,ampsperteslay
	wave/t sweepratevalstr
	variable ramprate_amps
	string cmd
	
	if (output < 0 || output > maxrampratey)
		print "Max sweep rate is "+num2str(maxrampratey)+" mT/min"
		return -3
	else
		ramprate_amps = Round_Number(output*(ampsperteslay/(1000*60)),5) // A/s
		cmd = "RATE "+num2str(ramprate_amps)
		WriteVector(cmd,"l625y")
		sweepratevalstr[1][1] = num2str(output)
		return 3
	endif
end

function SetSweepRatez(output) // Units: mT/min
	variable output
	nvar maxrampratez,ampsperteslaz
	wave/t sweepratevalstr
	variable ramprate_amps
	string cmd
	
	if (output < 0 || output > maxrampratez)
		print "Max sweep rate is "+num2str(maxrampratez)+" mT/min"
		return -4
	else
		ramprate_amps = Round_Number(output*(ampsperteslaz/1000),5)
		cmd = "$S"+num2str(ramprate_amps)
		WriteVector(cmd,"ips")
		sweepratevalstr[2][1] = num2str(output)
		return 4
	endif
end

function SetSweepRateAll(outputx,outputy,outputz) // Units: mT/min
	variable outputx,outputy,outputz
	variable checkx, checky, checkz
	
	checkx = SetSweepRatex(outputx)
	checky = SetSweepRatey(outputy)
	checkz = SetSweepRatez(outputz)
	return checkx+checky+checkz
end

function SetCurrentAll(outputx,outputy,outputz) // Units: A
	variable outputx,outputy,outputz
	
	SetCurrentx(outputx)
	SetCurrenty(outputy)
	SetCurrentz(outputz)
end

function SetFieldAll(outputx,outputy,outputz) // Units: mT
	variable outputx,outputy,outputz
	variable checkx,checky,checkz
	
	checkx = SetFieldx(outputx)
	checky = SetFieldy(outputy)
	checkz = SetFieldz(outputz)
	
	return checkx+checky+checkz
end

function SetFieldAllSpherical(r,theta,phi) // Units: mT,rad,rad
	variable r, theta, phi
	wave carcoordinates
	
	SphericalToCartisian(r,theta,phi)
	SetFieldAll(carcoordinates[0],carcoordinates[1],carcoordinates[2])
end

function SetFieldAllWait(outputx,outputy,outputz) // Units: mT
	variable outputx,outputy,outputz
	variable err=0.1,delta_all
	wave fieldwave
	
	SetFieldAll(outputx,outputy,outputz)
	do
		sc_sleep(0.1)
		GetFieldAll()
	while (CheckMagnetRamp("l625x") || CheckMagnetRamp("l625y") || CheckMagnetRamp("ips"))
end

function SetFieldAllSphericalWait(r,theta,phi) // Units: mt,rad,rad
	variable r, theta, phi
	wave carcoordinates
	
	SphericalToCartisian(r,theta,phi)
	SetFieldAllWait(carcoordinates[0],carcoordinates[1],carcoordinates[2])
end

/////////////////////////////
//// Magnet communications ////
////////////////////////////

function QueryVector(cmd,powersupply)
	string cmd, powersupply
	
	WriteVector(cmd,powersupply)
	return str2num(ReadVector(powersupply))
end

function QueryVectorIPS(cmd)
	string cmd
	string response_raw
	
	WriteVector(cmd,"ips")
	response_raw = ReadVector("ips")
	return str2num(response_raw[1,Inf])
end

function WriteVector(cmd,powersupply)
	string cmd, powersupply
	nvar v_vdt
	
	SetSerialPortMagnet(powersupply)
	if(cmpstr(powersupply,"ips")==0)
		cmd = "VDTWrite2 /O=2 /Q \""+cmd+"\\r\""
	elseif(cmpstr(powersupply,"l625x")==0 || cmpstr(powersupply,"l625y")==0)
		cmd = "VDTWrite2 /O=2 /Q \""+cmd+"\\r\\n\""
	endif
	execute(cmd)
	if (v_vdt == 0)
		abort "Write failed on command "+cmd
	endif
end

function/s ReadVector(powersupply)
	string powersupply
	string response
	variable index
	
	if(cmpstr(powersupply,"ips")==0)
		VDTRead2 /O=2/T="\r" response
	elseif(cmpstr(powersupply,"l625x")==0 || cmpstr(powersupply,"l625y")==0)
		VDTRead2 /O=2/T="\r" response
		response = TrimString(response)
		//index = strsearch(response,"\n",0)
		//response = response[0,index-1]
	endif
	if (v_vdt == 0)
		abort "Failed to read"
	endif
	return response
end

///////////////////
//// Utilities ////
///////////////////

function SphericalToCartisianTest(r,theta,phi)
	variable r, theta, phi
	
	print("x= "+num2str(RoundtoZero(r*sin(theta)*cos(phi))))
	print("y= "+num2str(RoundtoZero(r*sin(theta)*sin(phi))))
	print("z= "+num2str(RoundtoZero(r*cos(theta))))
end

function SphericalToCartisian(r,theta,phi)
	variable r, theta, phi
	make/n=3/o carcoordinates //wave holding x,y,z coordinates
	
	carcoordinates[0] = RoundtoZero(r*sin(theta)*cos(phi))
	carcoordinates[1] = RoundtoZero(r*sin(theta)*sin(phi))
	carcoordinates[2] = RoundtoZero(r*cos(theta))
end

function CartisiantoSpherical(x,y,z)
	variable x,y,z
	make/o/n=3 sphericalcoordinates
	variable r
	r = sqrt(x^2+y^2+z^2)
	if(r==0)
		sphericalcoordinates[0] = r
		sphericalcoordinates[1] = 0
		sphericalcoordinates[2] = atan2(y,x)
	else
		sphericalcoordinates[0] = r
		sphericalcoordinates[1] = acos(z/r)
		sphericalcoordinates[2] = atan2(y,x)
	endif
end

function CylindricalToCartisian(r,phi,z)
	variable r, phi, z
	make/n=3/o carcoordinates //wave holding x,y,z coordinates
	
	carcoordinates[0] = r*cos(phi)
	carcoordinates[1] = r*sin(phi)
	carcoordinates[2] = z
end

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

function TestCoordinateTransform(x,y,z)
	variable x,y,z
	wave carcoordinates,sphericalcoordinates
	
	CartisiantoSpherical(x,y,z)
	SphericalToCartisian(sphericalcoordinates[0],sphericalcoordinates[1],sphericalcoordinates[2])
	print carcoordinates[0],carcoordinates[1],carcoordinates[2]
end

function CheckMagnetRamp(powersupply)
	string powersupply
	string answerips
	variable answerl625, ramping
	
	if(cmpstr(powersupply,"ips")==0)
		WriteVector("X",powersupply)
		answerips = ReadVector(powersupply)
		if(str2num(answerips[11]) == 0) //XmnAnCnHnMmnPmn
			ramping = 0
		else
			ramping = 1
		endif
	elseif(cmpstr(powersupply,"l625x")==0)
		answerl625 = QueryVector("OPST?",powersupply)
		if(answerl625 == 6)
			ramping = 0
		else
			ramping = 1
		endif
	elseif(cmpstr(powersupply,"l625y")==0)
		answerl625 = QueryVector("OPST?",powersupply)
		if(answerl625 == 6)
			ramping = 0
		else
			ramping = 1
		endif
	else
		abort "input must be: \"ips\",\"l625x\" or \"l625y\""	
	endif
	
	return ramping
end

//////////////////////
//// Control Window ////
/////////////////////

window Vector_Window() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(0,0,500,500) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1 
	DrawText 150, 45,"Vector Magnet" // Headline
	DrawText 65,80,"\Z18Current Output"
	DrawText 300,80,"\Z18Sweeprate"
	ListBox outputlist,pos={20,90},size={220,80},fsize=16,frame=2,listwave=root:outputvalstr,selwave=root:listboxattr_outputlist,mode=1
	ListBox sweepratelist,pos={250,90},size={220,80},fsize=16,frame=2,listwave=root:sweepratevalstr,selwave=root:listboxattr_sweepratelist,mode=1
	DrawText 35,200, "\Z18Spherical Coordinates"
	DrawText 320,200, "\Z18Setpoint"
	Listbox sphericallist, pos={20,210},size={220,80},fsize=16,frame=2,listwave=root:sphericalvalstr,selwave=root:listboxattr_sphericallist,mode=1
	ListBox setpointlist, pos={250,210},size={220,80},fsize=16,frame=2,listwave=root:setpointvalstr,selwave=root:listboxattr_setpointlist,mode=1
	Button changesetpoint,pos={200,300},size={110,20},proc=update_setpoint,title="Change setpoint" // adding buttons
	Button changesweeprate,pos={340,300},size={130,20},proc=update_sweeprate,title="Change sweep rate"
	Button updatevalues, pos={20,300},size={150,20},proc=update_everything,title="Update current values"
endmacro

function update_setpoint(action) : ButtonControl
	string action
	variable check
	wave/t setpointvalstr
	svar oldsetpointx,oldsetpointy,oldsetpointz
	
	check = SetFieldAll(str2num(setpointvalstr[0][1]),str2num(setpointvalstr[1][1]),str2num(setpointvalstr[2][1]))
	if (check == 9)
		oldsetpointx = setpointvalstr[0][1]
		oldsetpointy = setpointvalstr[1][1]
		oldsetpointz = setpointvalstr[2][1]
	elseif(check == 5)
		setpointvalstr[0][1] = oldsetpointx
		oldsetpointy = setpointvalstr[1][1]
		oldsetpointz = setpointvalstr[2][1]
	elseif(check==3)
		oldsetpointx = setpointvalstr[0][1]
		setpointvalstr[1][1] = oldsetpointy
		oldsetpointz = setpointvalstr[2][1]
	elseif(check==1)
		oldsetpointx = setpointvalstr[0][1]
		oldsetpointy = setpointvalstr[1][1]
		setpointvalstr[2][1] = oldsetpointz
	elseif(check==-1)
		setpointvalstr[0][1] = oldsetpointx
		setpointvalstr[1][1] = oldsetpointy
		oldsetpointz = setpointvalstr[2][1]
	elseif(check==-3)
		setpointvalstr[0][1] = oldsetpointx
		oldsetpointy = setpointvalstr[1][1]
		setpointvalstr[2][1] = oldsetpointz
	elseif(check==-5)
		oldsetpointx = setpointvalstr[0][1]
		setpointvalstr[1][1] = oldsetpointy
		setpointvalstr[2][1] = oldsetpointz
	elseif(check==-9)
		setpointvalstr[0][1] = oldsetpointx
		setpointvalstr[1][1] = oldsetpointy
		setpointvalstr[2][1] = oldsetpointz
	endif
end

function update_sweeprate(action) : ButtonControl
	string action
	variable check
	wave/t sweepratevalstr
	svar oldsweepratex,oldsweepratey,oldsweepratez
	
	check = SetSweepRateAll(str2num(sweepratevalstr[0][1]),str2num(sweepratevalstr[1][1]),str2num(sweepratevalstr[2][1]))
	if (check == 9)
		oldsweepratex = sweepratevalstr[0][1]
		oldsweepratey = sweepratevalstr[1][1]
		oldsweepratez = sweepratevalstr[2][1]
	elseif(check == 5)
		sweepratevalstr[0][1] = oldsweepratex
		oldsweepratey = sweepratevalstr[1][1]
		oldsweepratez = sweepratevalstr[2][1]
	elseif(check==3)
		oldsweepratex = sweepratevalstr[0][1]
		sweepratevalstr[1][1] = oldsweepratey
		oldsweepratez = sweepratevalstr[2][1]
	elseif(check==1)
		oldsweepratex = sweepratevalstr[0][1]
		oldsweepratey = sweepratevalstr[1][1]
		sweepratevalstr[2][1] = oldsweepratez
	elseif(check==-1)
		sweepratevalstr[0][1] = oldsweepratex
		sweepratevalstr[1][1] = oldsweepratey
		oldsweepratez = sweepratevalstr[2][1]
	elseif(check==-3)
		sweepratevalstr[0][1] = oldsweepratex
		oldsweepratey = sweepratevalstr[1][1]
		sweepratevalstr[2][1] = oldsweepratez
	elseif(check==-5)
		oldsweepratex = sweepratevalstr[0][1]
		sweepratevalstr[1][1] = oldsweepratey
		sweepratevalstr[2][1] = oldsweepratez
	elseif(check==-9)
		sweepratevalstr[0][1] = oldsweepratex
		sweepratevalstr[1][1] = oldsweepratey
		sweepratevalstr[2][1] = oldsweepratez
	endif
end

function update_everything(action) : ButtonControl
	string action
	wave fieldwave
	
	GetFieldAll()
	GetSweeprateAll()
	CartisiantoSpherical(fieldwave[0],fieldwave[1],fieldwave[2])
	update_output()
end

function update_output()
	wave fieldwave,sweepratewave,sphericalcoordinates
	wave/t outputvalstr,sweepratevalstr,sphericalvalstr
	variable i=0
	
	for(i=0;i<3;i+=1)
		outputvalstr[i][1] = num2str(fieldwave[i])
		sphericalvalstr[i][1] = num2str(sphericalcoordinates[i])
		sweepratevalstr[i][1] = num2str(sweepratewave[i])
	endfor
end

//////////////////
//// Logging ////
////////////////

function/s GetVectorStatus()

	string buffer = "", subbuffer = ""
	
	subbuffer = ""
	subbuffer = addJSONKeyVal(subbuffer, "x", numVal=GetFieldx(), fmtNum="%.3f")
	subbuffer = addJSONKeyVal(subbuffer, "y", numVal=GetFieldy(), fmtNum="%.3f")
	subbuffer = addJSONKeyVal(subbuffer, "z", numVal=GetFieldz(), fmtNum="%.3f")
	buffer = addJSONKeyVal(buffer, "field mT", strVal=subbuffer)

	subbuffer = ""
	subbuffer = addJSONKeyVal(subbuffer, "x", numVal=GetSweepRatex(), fmtNum="%.1f")
	subbuffer = addJSONKeyVal(subbuffer, "y", numVal=GetSweepRatey(), fmtNum="%.1f")
	subbuffer = addJSONKeyVal(subbuffer, "z", numVal=GetSweepRatez(), fmtNum="%.1f")
	buffer = addJSONKeyVal(buffer, "rate mT/min", strVal=subbuffer)
	
	return addJSONKeyVal("", "Vector Magnet", strVal=buffer)
end