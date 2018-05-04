#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1	// Use modern global access method

// Driver communicates over serial, remember to set the correct serial ports in three global strings called IPSz_serial, L625x_serial & L625y_serial.
// Procedure written by Christian Olsen 2017-03-15
// Updated to VISA by Christian Olsen, 2018-05-xx
// Main axis is powered by an IPS120 and the in-plane fields are powered by two Lakeshore 625 power supplies.

// FIX window and logging!

////////////////////////////
//// Lakeshore 625 COMM ////
////////////////////////////

function ls625CommSetup(instrID)
	variable instrID
	
	// setup communication attr
	visaSetBaudRate(instrID, 57600) // baud rate
	visaSetStopBits(instrID, 10) // 1 stop bit
	visaSetDataBits(instrID, 7) // 7 data bits
	visaSetParity(instrID, 1) // Odd parity
end

///////////////////////
/// Initiate Magnet ///
///////////////////////

function initLS625Vector(instrIDx,instrIDy,instrIDz)
	// wrapper function for initLS625(instrID)
	variable instrIDx, instrIDy, instrIDz
	
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
	
	// Setting up serial communication
	ls625CommSetup(instrIDx)
	ls625CommSetup(instrIDy)
	ls625CommSetup(instrIDz)
	
	// Set sweep rates, unit: mT/s
	setLS625rateX(instrIDx,100)
	setLS625rateY(instrIDy,100)
	setLS625rateZ(instrIDz,100)
	
	// Start GUI
	dowindow/k Vector_Window
	execute("Vector_Window()")
end

///////////////////////
//// Get functions ////
//////////////////////

function getLS625currentX(instrID) // Units: A
	variable instrID
	nvar ampsperteslax
	wave/t outputvalstr,sphericalvalstr
	wave sphericalcoordinates
	variable current,field
	
	current = str2num(queryInstr(instrID,"RDGI?","\r\n","\r\n"))
	// Update control window
	field = Round_Number(current/ampsperteslax*1000,5)
	CartisiantoSpherical(field,str2num(outputvalstr[1][1]),str2num(outputvalstr[2][1]))
	outputvalstr[0][1] = num2str(field)
	sphericalvalstr[0][1] = num2str(sphericalcoordinates[0])
	sphericalvalstr[1][1] = num2str(sphericalcoordinates[1])
	sphericalvalstr[2][1] = num2str(sphericalcoordinates[2])
	
	return current
end

function getLS625currentY(instrID) // Units: A
	variable instrID
	nvar ampsperteslay
	wave/t outputvalstr,sphericalvalstr
	wave sphericalcoordinates
	variable current,field
	
	current = str2num(queryInstr(instrID,"RDGI?","\r\n","\r\n"))
	// Update control window
	field = Round_Number(current/ampsperteslay*1000,5)
	CartisiantoSpherical(str2num(outputvalstr[0][1]),field,str2num(outputvalstr[2][1]))
	outputvalstr[1][1] = num2str(field)
	sphericalvalstr[0][1] = num2str(sphericalcoordinates[0])
	sphericalvalstr[1][1] = num2str(sphericalcoordinates[1])
	sphericalvalstr[2][1] = num2str(sphericalcoordinates[2])
	
	return current
end

function getLS625currentZ(instrID) // Units: A
	variable instrID
	nvar ampsperteslaz
	wave/t outputvalstr,sphericalvalstr
	wave sphericalcoordinates
	variable current,field
	
	current = str2num(queryInstr(instrID,"RDGI?","\r\n","\r\n"))
	// Update control window
	field = Round_Number(current/ampsperteslaz*1000,5)
	CartisiantoSpherical(str2num(outputvalstr[0][1]),str2num(outputvalstr[1][1]),field)
	outputvalstr[2][1] = num2str(field)
	sphericalvalstr[0][1] = num2str(sphericalcoordinates[0])
	sphericalvalstr[1][1] = num2str(sphericalcoordinates[1])
	sphericalvalstr[2][1] = num2str(sphericalcoordinates[2])
	
	return current
end

function getL625allcurrent(instrIDx,instrIDy,instrIDz) // Units: A
	variable instrIDx,instrIDy,instrIDz
	nvar ampsperteslax, ampsperteslay, ampsperteslaz
	make/o/n=3 currentwave
	
	currentwave[0] = getLS625currentX(instrIDx)
	currentwave[1] = getLS625currentY(instrIDy)
	currentwave[2] = getLS625currentZ(instrIDz)
end

function getLS625fieldX(instrID) // Units: mT
	variable instrID
	nvar ampsperteslax
	variable field, current
	wave/t outputvalstr
	
	current = getLS625currentX(instrID)
	field = Round_Number(current/ampsperteslax*1000,3)
	outputvalstr[0][1] = num2str(field)
	
	return field
end

function getLS625fieldY(instrID) // Units: mT
	variable instrID
	nvar ampsperteslay
	variable field, current
	wave/t outputvalstr
	
	current = getLS625currentY(instrID)
	field = Round_Number(current/ampsperteslay*1000,3)
	outputvalstr[1][1] = num2str(field)
	
	return field
end

function getLS625fieldZ(instrID) // Units: mT
	variable instrID
	nvar ampsperteslaz
	variable current,field
	wave/t outputvalstr
	
	current = getLS625currentZ(instrID)
	field = Round_Number(current/ampsperteslaz*1000,3)
	outputvalstr[2][1] = num2str(field)
	
	return field
end

function getL625allfield(instrIDx,instrIDy,instrIDz) // Units: mT
	variable instrIDx,instrIDy,instrIDz
	make/n=3/o fieldwave
	
	fieldwave[0] = getLS625fieldX(instrIDx)
	fieldwave[1] = getLS625fieldX(instrIDy)
	fieldwave[2] = getLS625fieldX(instrIDz)
end

function getLS625rateX(instrID) // Units: mT/min
	variable instrID
	nvar ampsperteslax
	wave/t sweepratevalstr
	variable rampratefield, currentramprate
	
	currentramprate = str2num(queryInstr(instrID,"RATE?","\r\n","\r\n")) // A/s
	rampratefield = Round_Number(currentramprate/ampsperteslax*60*1000,5)
	// Update control window
	sweepratevalstr[0][1] = num2str(rampratefield)
	
	return rampratefield
end

function getLS625rateY(instrID) // Units: mT/min
	variable instrID
	nvar ampsperteslay
	wave/t sweepratevalstr
	variable rampratefield, currentramprate
	
	currentramprate = str2num(queryInstr(instrID,"RATE?","\r\n","\r\n")) // A/s
	rampratefield = Round_Number(currentramprate/ampsperteslay*60*1000,5)
	// Update control window
	sweepratevalstr[1][1] = num2str(rampratefield)
	
	return rampratefield
end

function getLS625rateZ(instrID) // Units: mT/min
	variable instrID
	variable currentramprate, rampratefield
	wave/t sweepratevalstr
	nvar ampsperteslaz
	
	currentramprate = str2num(queryInstr(instrID,"RATE?","\r\n","\r\n")) // A/s
	rampratefield = Round_Number(currentramprate/ampsperteslaz*1000,5)
	// Update control window
	sweepratevalstr[2][1] = num2str(rampratefield)
	
	return rampratefield
end

function getLS625allrate(instrIDx,instrIDy,instrIDz)
	variable instrIDx,instrIDy,instrIDz
	make/o/n=3 sweepratewave
	
	sweepratewave[0] = getLS625rateX(instrIDx)
	sweepratewave[1] = getLS625rateY(instrIDy)
	sweepratewave[2] = getLS625rateZ(instrIDz)
end

////////////////////////
//// Set functions ////
//////////////////////

function setLS625currentX(instrID,output) // Units: A
	variable instrID,output
	string cmd
	wave/t setpointvalstr
	nvar maxfieldx, ampsperteslax
	
	if (abs(output) > maxfieldx*ampsperteslax/1000)
		print "Max current is "+num2str(maxfieldx*ampsperteslax/1000)+" A"
	else	
		cmd = "SETI "+num2str(output)
		writeInstr(instrID, cmd, "\r\n")
		setpointvalstr[0][1] = num2str(Round_Number(output/ampsperteslax*1000,5))
	endif
end

function setLS625currentY(instrID,output) // Units: A
	variable instrID, output
	string cmd
	wave/t setpointvalstr
	nvar maxfieldy, ampsperteslay
	
	if (abs(output) > maxfieldy*ampsperteslay/1000)
		print "Max current is "+num2str(maxfieldy*ampsperteslay/1000)+" A"
	else	
		cmd = "SETI "+num2str(output)
		writeInstr(instrID, cmd, "\r\n")
		setpointvalstr[1][1] = num2str(Round_Number(output/ampsperteslay*1000,5))
	endif
end

function setLS625currentZ(instrID,output) // Units: A
	variable instrID, output
	string cmd
	wave/t setpointvalstr
	nvar maxfieldz, ampsperteslaz
	
	if (abs(output) > maxfieldz*ampsperteslaz/1000)
		print "Max current is "+num2str(maxfieldz*ampsperteslaz/1000)+" A"
	else	
		cmd = "SETI "+num2str(output)
		writeInstr(instrID, cmd, "\r\n")
		setpointvalstr[2][1] = num2str(Round_Number(output/ampsperteslaz*1000,5))
	endif
end

function setLS625fieldX(instrID,output) // Units: mT
	variable instrID, output
	nvar ampsperteslax, maxfieldx
	variable round_amps
	string cmd
	
	if (abs(output) > maxfieldx)
		print "Max field is "+num2str(maxfieldx)+" mT"
		return -2
	else
		round_amps = Round_Number(output*ampsperteslax/1000,5)
		setLS625currentX(instrID,round_amps)
		return 2
	endif
end

function setLS625fieldY(instrID,output) // Units: mT
	variable instrID, output
	nvar ampsperteslay, maxfieldy
	variable round_amps
	string cmd
	
	if (abs(output) > maxfieldy)
		print "Max field is "+num2str(maxfieldy)+" mT"
		return -3
	else
		round_amps = Round_Number(output*ampsperteslay/1000,5)
		setLS625currentY(instrID,round_amps)
		return 3
	endif
end

function setLS625fieldZ(instrID,output) // Units: mT
	variable instrID, output
	nvar ampsperteslaz, maxfieldz
	variable round_amps
	string cmd
	
	if (abs(output) > maxfieldz)
		print "Max field is "+num2str(maxfieldz)+" mT"
		return -4
	else
		round_amps = Round_Number(output*ampsperteslaz/1000,5)
		setLS625currentZ(instrID,round_amps)
		return 4
	endif
end

function setLS625fieldXwait(instrID,output)
	variable instrID, output
	
	setLS625fieldX(instrID,output)
	do
		sc_sleep(0.1)
		getLS625fieldX(instrID)
	while(checkLS625ramp(instrID))
end

function setLS625fieldYwait(instrID,output)
	variable instrID, output
	
	setLS625fieldY(instrID,output)
	do
		sc_sleep(0.1)
		getLS625fieldY(instrID)
	while(checkLS625ramp(instrID))
end

function setLS625fieldZwait(instrID,output)
	variable instrID, output
	
	setLS625fieldZ(instrID,output)
	do
		sc_sleep(0.1)
		getLS625fieldZ(instrID)
	while(checkLS625ramp(instrID))
end

function setLS625rateX(instrID,output) // Units: mT/min
	variable instrID, output
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
		writeInstr(instrID,cmd,"\r\n")
		sweepratevalstr[0][1] = num2str(output)
		return 2
	endif
end

function setLS625rateY(instrID,output) // Units: mT/min
	variable instrID, output
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
		writeInstr(instrID,cmd,"\r\n")
		sweepratevalstr[1][1] = num2str(output)
		return 3
	endif
end

function setLS625rateZ(instrID,output) // Units: mT/min
	variable instrID, output
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
		writeInstr(instrID,cmd,"\r\n")
		sweepratevalstr[2][1] = num2str(output)
		return 4
	endif
end

function setLS625allrate(instrIDx,instrIDy,instrIDz,outputx,outputy,outputz) // Units: mT/min
	variable instrIDx,instrIDy,instrIDz,outputx,outputy,outputz
	variable checkx, checky, checkz
	
	checkx = setLS625rateX(instrIDx,outputx)
	checky = setLS625rateY(instrIDy,outputy)
	checkz = setLS625rateZ(instrIDz,outputz)
	return checkx+checky+checkz
end

function setLS625allcurrent(instrIDx,instrIDy,instrIDz,outputx,outputy,outputz) // Units: A
	variable instrIDx,instrIDy,instrIDz,outputx,outputy,outputz
	
	setLS625currentX(instrIDx,outputx)
	setLS625currentY(instrIDy,outputy)
	setLS625currentZ(instrIDz,outputz)
end

function setLS625allfield(instrIDx,instrIDy,instrIDz,outputx,outputy,outputz) // Units: mT
	variable instrIDx,instrIDy,instrIDz,outputx,outputy,outputz
	variable checkx,checky,checkz
	
	checkx = setLS625fieldX(instrIDx,outputx)
	checky = setLS625fieldY(instrIDy,outputy)
	checkz = setLS625fieldZ(instrIDz,outputz)
	
	return checkx+checky+checkz
end

function setLS625allfieldSpherical(instrIDx,instrIDy,instrIDz,r,theta,phi) // Units: mT,rad,rad
	variable instrIDx,instrIDy,instrIDz,r,theta,phi
	wave carcoordinates
	
	SphericalToCartisian(r,theta,phi)
	setLS625allfield(instrIDx,instrIDy,instrIDz,carcoordinates[0],carcoordinates[1],carcoordinates[2])
end

function setLS625allfieldwait(instrIDx,instrIDy,instrIDz,outputx,outputy,outputz) // Units: mT
	variable instrIDx,instrIDy,instrIDz,outputx,outputy,outputz
	wave fieldwave
	
	setLS625allfield(instrIDx,instrIDy,instrIDz,outputx,outputy,outputz)
	do
		sc_sleep(0.1)
		getL625allfield(instrIDx,instrIDy,instrIDz)
	while(checkLS625ramp(instrIDx) || checkLS625ramp(instrIDy) || checkLS625ramp(instrIDz))
end

function setLS625fieldAllsphericalWait(instrIDx,instrIDy,instrIDz,r,theta,phi) // Units: mT,rad,rad
	variable instrIDx,instrIDy,instrIDz,r,theta,phi
	wave carcoordinates
	
	SphericalToCartisian(r,theta,phi)
	setLS625allfieldwait(instrIDx,instrIDy,instrIDz,carcoordinates[0],carcoordinates[1],carcoordinates[2])
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

function checkLS625ramp(instrID)
	variable instrID
	string response
	variable ramping
	
	response = queryInstr(instrID,"OPST?","\r\n","\r\n")
	if(str2num(response) == 6)
		ramping = 0
	else
		ramping = 1
	endif
	
	return ramping
end

////////////////////////
//// Control Window ////
///////////////////////

//// FIX from here ////

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