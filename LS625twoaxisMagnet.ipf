#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1	// Use modern global access method

// Driver communicates over serial.
// Procedure written by Christian Olsen 2017-03-15
// Updated to VISA by Christian Olsen, 2018-05-xx
// Both axes are powered by Lakeshore 625 power supplies.


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

function initLS625TwoAxis(instrIDx,instrIDz)
	// wrapper function for initLS625(instrID)
	variable instrIDx, instrIDz

	// local copies of the serial port addresses
	string/g instrDescX = getResourceAddress(instrIDx)
	string/g instrDescZ = getResourceAddress(instrIDz)

	// create string constants for use in get/set functions
	execute("L625StrConst(instrDescX,instrDescZ)")

	variable/g ampsperteslax=55.49, ampsperteslaz=9.950// A/T
	variable/g maxfieldx=1000, maxfieldz=6000 // mT
	variable/g maxrampratex=300, maxrampratez=300 // mT/min

	// Setup variables and waves needed for the control window.
	// Add control window stuff here.
	make/t/o outputvalstr={{"X [mT]:","Z [mT]:"},{"0","0"}}
	make/o listboxattr_outputlist={{0,0},{0,0}}
	make/t/o sweepratevalstr={{"X [mT/min]:","Z [mT/min]:"},{"0","0"}}
	make/o listboxattr_sweepratelist={{0,0},{2,2}}
	make/t/o setpointvalstr={{"X [mT]:","Z [mT]:"},{"0","0"}}
	make/o listboxattr_setpointlist={{0,0},{2,2}}
	string/g oldsweepratex,oldsweepratez
	string/g oldsetpointx="0",oldsetpointz="0"

	// Set sweep rates, unit: mT/s
	setLS625rate(instrIDx,100)
	setLS625rate(instrIDz,100)

	// Start GUI
	dowindow/k TwoAxis_Window
	execute("TwoAxis_Window()")
end

macro L625StrConst(instrDescX,instrDescZ)
	string instrDescX,instrDescZ
	// create string constants for use in get/set functions
	StrConstant strX=instrDescX
	StrConstant strZ=instrDescZ
endmacro

////////////////////////
//// Get functions ////
///////////////////////

function getLS625current(instrID) // Units: A
	variable instrID
	nvar ampsperteslax,ampsperteslaz
	wave/t outputvalstr
	variable current,field, ampspertesla
	svar instrDescX,instrDescZ

	string l625 = getResourceAddress(instrID)

	current = str2num(queryInstr(instrID,"RDGI?\r\n", read_term = "\r\n"))

	// Update control window
	if(cmpstr(l625,instrDescX)==0)
		outputvalstr[0][1] = num2str(Round_Number(current/ampsperteslax*1000,5))
	elseif(cmpstr(l625,instrDescZ)==0)
		outputvalstr[1][1] = num2str(Round_Number(current/ampsperteslaz*1000,5))
	else
		abort "Couldn't determine which axis to address"
	endif

	return current
end

function getL625allcurrent(instrIDx,instrIDz) // Units: A
	variable instrIDx,instrIDz
	nvar ampsperteslax,ampsperteslaz
	make/o/n=2 currentwave

	currentwave[0] = getLS625current(instrIDx)
	currentwave[1] = getLS625current(instrIDz)
end

function getLS625field(instrID) // Units: mT
	variable instrID
	nvar ampsperteslax,ampsperteslaz
	variable field, current
	wave/t outputvalstr
	svar instrDescX,instrDescZ

	string l625 = getResourceAddress(instrID)

	current = getLS625current(instrID)
	// Update control window
	if(cmpstr(l625,instrDescX)==0)
		field = Round_Number(current/ampsperteslax*1000,5)
		outputvalstr[0][1] = num2str(field)
	elseif(cmpstr(l625,instrDescZ)==0)
		field = Round_Number(current/ampsperteslaz*1000,5)
		outputvalstr[1][1] = num2str(field)
	else
		abort "Couldn't determine which axis to address"
	endif

	return field
end

function getL625allfield(instrIDx,instrIDz) // Units: mT
	variable instrIDx,instrIDz
	make/n=2/o fieldwave

	fieldwave[0] = getLS625field(instrIDx)
	fieldwave[1] = getLS625field(instrIDz)
end

function getLS625rate(instrID) // Units: mT/min
	variable instrID
	nvar ampsperteslax,ampsperteslaz
	wave/t sweepratevalstr
	variable rampratefield, currentramprate
	svar instrDescX,instrDescZ

	string l625 = getResourceAddress(instrID)

	currentramprate = str2num(queryInstr(instrID,"RATE?\r\n", read_term = "\r\n")) // A/s
	// Update control window
	if(cmpstr(l625,instrDescX)==0)
		rampratefield = Round_Number(currentramprate/ampsperteslax*60*1000,5)
		sweepratevalstr[0][1] = num2str(rampratefield)
	elseif(cmpstr(l625,instrDescZ)==0)
		rampratefield = Round_Number(currentramprate/ampsperteslaz*60*1000,5)
		sweepratevalstr[1][1] = num2str(rampratefield)
	else
		abort "Couldn't determine which axis to address"
	endif

	return rampratefield
end

function getLS625allrate(instrIDx,instrIDz)
	variable instrIDx,instrIDz
	make/o/n=2 sweepratewave

	sweepratewave[0] = getLS625rate(instrIDx)
	sweepratewave[1] = getLS625rate(instrIDz)
end

////////////////////////
//// Set functions ////
//////////////////////

function setLS625current(instrID,output) // Units: A
	variable instrID,output
	string cmd
	wave/t setpointvalstr
	nvar maxfieldx,maxfieldz,ampsperteslax,ampsperteslaz
	variable maxfield,ampspertesla,i=-1
	svar instrDescX,instrDescZ

	string l625 = getResourceAddress(instrID)

	if(cmpstr(l625,instrDescX)==0)
		maxfield = maxfieldx
		ampspertesla = ampsperteslax
		i=0
	elseif(cmpstr(l625,instrDescZ)==0)
		maxfield = maxfieldz
		ampspertesla = ampsperteslaz
		i=1
	else
		abort "Couldn't determine which axis to address"
	endif

	if (abs(output) > maxfield*ampspertesla/1000)
		print "Max current is "+num2str(maxfield*ampspertesla/1000)+" A"
	else
		cmd = "SETI "+num2str(output)
		writeInstr(instrID, cmd+"\r\n")
		setpointvalstr[i][1] = num2str(Round_Number(output/ampspertesla*1000,5))
	endif
end

function setLS625field(instrID,output) // Units: mT
	variable instrID, output
	nvar maxfieldx,maxfieldz,ampsperteslax,ampsperteslaz
	variable round_amps
	string cmd
	variable maxfield,ampspertesla,i=0
	svar instrDescX,instrDescZ

	string l625 = getResourceAddress(instrID)

	if(cmpstr(l625,instrDescX)==0)
		maxfield = maxfieldx
		ampspertesla = ampsperteslax
		i=2
	elseif(cmpstr(l625,instrDescZ)==0)
		maxfield = maxfieldz
		ampspertesla = ampsperteslaz
		i=3
	else
		abort "Couldn't determine which axis to address"
	endif

	if (abs(output) > maxfield)
		print "Max field is "+num2str(maxfield)+" mT"
		return -i
	else
		round_amps = Round_Number(output*ampspertesla/1000,5)
		setLS625current(instrID,round_amps)
		return i
	endif
end

function setLS625fieldwait(instrID,output)
	variable instrID, output

	setLS625field(instrID,output)
	do
		sc_sleep(0.1)
		getLS625field(instrID)
	while(checkLS625ramp(instrID))
end

function setLS625rate(instrID,output) // Units: mT/min
	variable instrID, output
	nvar maxrampratex,maxrampratez,ampsperteslax,ampsperteslaz
	wave/t sweepratevalstr
	variable ramprate_amps
	string cmd
	variable maxramprate,ampspertesla,i=0,j=-1
	svar instrDescX,instrDescZ

	string l625 = getResourceAddress(instrID)

	if(cmpstr(l625,instrDescX)==0)
		maxramprate = maxrampratex
		ampspertesla = ampsperteslax
		i=2
		j=0
	elseif(cmpstr(l625,instrDescZ)==0)
		maxramprate = maxrampratez
		ampspertesla = ampsperteslaz
		i=3
		j=1
	else
		abort "Couldn't determine which axis to address"
	endif

	if (output < 0 || output > maxramprate)
		print "Max sweep rate is "+num2str(maxramprate)+" mT/min"
		return -i
	else
		ramprate_amps = Round_Number(output*(ampspertesla/(1000*60)),5) // A/s
		cmd = "RATE "+num2str(ramprate_amps)
		writeInstr(instrID,cmd+"\r\n")
		sweepratevalstr[j][1] = num2str(output)
		return i
	endif
end

function setLS625allrate(instrIDx,instrIDz,outputx,outputz) // Units: mT/min
	variable instrIDx,instrIDz,outputx,outputz
	variable checkx,checkz

	checkx = setLS625rate(instrIDx,outputx)
	checkz = setLS625rate(instrIDz,outputz)
	return checkx+checkz
end

function setLS625allcurrent(instrIDx,instrIDz,outputx,outputz) // Units: A
	variable instrIDx,instrIDz,outputx,outputz

	setLS625current(instrIDx,outputx)
	setLS625current(instrIDz,outputz)
end

function setLS625allfield(instrIDx,instrIDz,outputx,outputz) // Units: mT
	variable instrIDx,instrIDz,outputx,outputz
	variable checkx,checkz

	checkx = setLS625field(instrIDx,outputx)
	checkz = setLS625field(instrIDz,outputz)

	return checkx+checkz
end

//function setLS625allfieldSpherical(instrIDx,instrIDy,instrIDz,r,theta,phi) // Units: mT,rad,rad
//	variable instrIDx,instrIDy,instrIDz,r,theta,phi
//	wave carcoordinates
//
//	SphericalToCartisian(r,theta,phi)
//	setLS625allfield(instrIDx,instrIDy,instrIDz,carcoordinates[0],carcoordinates[1],carcoordinates[2])
//end

function setLS625allfieldwait(instrIDx,instrIDz,outputx,outputz) // Units: mT
	variable instrIDx,instrIDz,outputx,outputz
	wave fieldwave

	setLS625allfield(instrIDx,instrIDz,outputx,outputz)
	do
		sc_sleep(0.1)
		getL625allfield(instrIDx,instrIDz)
	while(checkLS625ramp(instrIDx) || checkLS625ramp(instrIDz))
end

//function setLS625fieldAllsphericalWait(instrIDx,instrIDy,instrIDz,r,theta,phi) // Units: mT,rad,rad
//	variable instrIDx,instrIDy,instrIDz,r,theta,phi
//	wave carcoordinates
//
//	SphericalToCartisian(r,theta,phi)
//	setLS625allfieldwait(instrIDx,instrIDy,instrIDz,carcoordinates[0],carcoordinates[1],carcoordinates[2])
//end

///////////////////
//// Utilities ////
///////////////////

//function SphericalToCartisianTest(r,theta,phi)
//	variable r, theta, phi
//
//	print("x= "+num2str(RoundtoZero(r*sin(theta)*cos(phi))))
//	print("y= "+num2str(RoundtoZero(r*sin(theta)*sin(phi))))
//	print("z= "+num2str(RoundtoZero(r*cos(theta))))
//end
//
//function SphericalToCartisian(r,theta,phi)
//	variable r, theta, phi
//	make/n=3/o carcoordinates //wave holding x,y,z coordinates
//
//	carcoordinates[0] = RoundtoZero(r*sin(theta)*cos(phi))
//	carcoordinates[1] = RoundtoZero(r*sin(theta)*sin(phi))
//	carcoordinates[2] = RoundtoZero(r*cos(theta))
//end
//
//function CartisiantoSpherical(x,y,z)
//	variable x,y,z
//	make/o/n=3 sphericalcoordinates
//	variable r
//	r = sqrt(x^2+y^2+z^2)
//	if(r==0)
//		sphericalcoordinates[0] = r
//		sphericalcoordinates[1] = 0
//		sphericalcoordinates[2] = atan2(y,x)
//	else
//		sphericalcoordinates[0] = r
//		sphericalcoordinates[1] = acos(z/r)
//		sphericalcoordinates[2] = atan2(y,x)
//	endif
//end
//
//function CylindricalToCartisian(r,phi,z)
//	variable r, phi, z
//	make/n=3/o carcoordinates //wave holding x,y,z coordinates
//
//	carcoordinates[0] = r*cos(phi)
//	carcoordinates[1] = r*sin(phi)
//	carcoordinates[2] = z
//end

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

//function TestCoordinateTransform(x,y,z)
//	variable x,y,z
//	wave carcoordinates,sphericalcoordinates
//
//	CartisiantoSpherical(x,y,z)
//	SphericalToCartisian(sphericalcoordinates[0],sphericalcoordinates[1],sphericalcoordinates[2])
//	print carcoordinates[0],carcoordinates[1],carcoordinates[2]
//end

function checkLS625ramp(instrID)
	variable instrID
	string response
	variable ramping

	response = queryInstr(instrID,"OPST?\r\n",read_term = "\r\n")
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

window TwoAxis_Window() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(0,0,500,300) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 150, 45,"Two Axis Magnet" // Headline
	DrawText 65,80,"\Z18Current Output"
	DrawText 300,80,"\Z18Sweeprate"
	ListBox outputlist,pos={20,90},size={220,80},fsize=16,frame=2,listwave=root:outputvalstr,selwave=root:listboxattr_outputlist,mode=1
	ListBox sweepratelist,pos={250,90},size={220,80},fsize=16,frame=2,listwave=root:sweepratevalstr,selwave=root:listboxattr_sweepratelist,mode=1
	//DrawText 35,200, "\Z18Spherical Coordinates"
	DrawText 320,200, "\Z18Setpoint"
	//Listbox sphericallist, pos={20,210},size={220,80},fsize=16,frame=2,listwave=root:sphericalvalstr,selwave=root:listboxattr_sphericallist,mode=1
	ListBox setpointlist, pos={250,210},size={220,80},fsize=16,frame=2,listwave=root:setpointvalstr,selwave=root:listboxattr_setpointlist,mode=1
	Button changesetpoint,pos={200,300},size={110,20},proc=update_setpoint,title="Change setpoint" // adding buttons
	Button changesweeprate,pos={340,300},size={130,20},proc=update_sweeprate,title="Change sweep rate"
	Button updatevalues, pos={20,300},size={150,20},proc=update_everything,title="Update current values"
endmacro

function update_setpoint(action) : ButtonControl
	string action
	variable check
	wave/t setpointvalstr
	svar oldsetpointx,oldsetpointz,instrDescX,instrDescZ
	variable localInstrIDx,localInstrIDz

	// open local instr connections
	localInstrIDx = openTempcommLS625(instrDescX)
	localInstrIDz = openTempcommLS625(instrDescZ)

	check = setLS625allfield(localInstrIDx,localInstrIDz,str2num(setpointvalstr[0][1]),str2num(setpointvalstr[1][1]))
	if(check == 5) // all good
		oldsetpointx = setpointvalstr[0][1]
		oldsetpointz = setpointvalstr[1][1]
	elseif(check==1) // x bad
		setpointvalstr[0][1] = oldsetpointx
		oldsetpointz = setpointvalstr[1][1]
	elseif(check==-1) // z bad
		oldsetpointx = setpointvalstr[0][1]
		setpointvalstr[1][1] = oldsetpointz
	elseif(check==-5) // all bad
		setpointvalstr[0][1] = oldsetpointx
		setpointvalstr[1][1] = oldsetpointz
	endif

	viClose(localInstrIDx)
	viClose(localInstrIDz)
end

function update_sweeprate(action) : ButtonControl
	string action
	variable check
	wave/t sweepratevalstr
	svar oldsweepratex,oldsweepratez,instrDescX,instrDescZ
	variable localInstrIDx,localInstrIDz

	// open local instr connections
	localInstrIDx = openTempcommLS625(instrDescX)
	localInstrIDz = openTempcommLS625(instrDescZ)

	check = setLS625allrate(localInstrIDx,localInstrIDz,str2num(sweepratevalstr[0][1]),str2num(sweepratevalstr[1][1]))
	if(check == 5) // all good
		oldsweepratex = sweepratevalstr[0][1]
		oldsweepratez = sweepratevalstr[1][1]
	elseif(check==1) // x bad
		sweepratevalstr[0][1] = oldsweepratex
		oldsweepratez = sweepratevalstr[1][1]
	elseif(check==-1) // z bad
		oldsweepratex = sweepratevalstr[0][1]
		sweepratevalstr[1][1] = oldsweepratez
	elseif(check==-5) // all bad
		sweepratevalstr[0][1] = oldsweepratex
		sweepratevalstr[1][1] = oldsweepratez
	endif

	viClose(localInstrIDx)
	viClose(localInstrIDz)
end

function update_everything(action) : ButtonControl
	string action
	wave fieldwave
	variable localInstrIDx,localInstrIDz
	svar instrDescX,instrDescZ

	// open local instr connections
	localInstrIDx = openTempcommLS625(instrDescX)
	localInstrIDz = openTempcommLS625(instrDescZ)

	getL625allfield(localInstrIDx,localInstrIDz)
	getLS625allrate(localInstrIDx,localInstrIDz)
	update_output()

	viClose(localInstrIDx)
	viClose(localInstrIDz)
end

function update_output()
	wave fieldwave,sweepratewave
	wave/t outputvalstr,sweepratevalstr
	variable i=0

	for(i=0;i<2;i+=1)
		outputvalstr[i][1] = num2str(fieldwave[i])
		sweepratevalstr[i][1] = num2str(sweepratewave[i])
	endfor
end

function openTempcommLS625(instrDesc)
	string instrDesc
	variable status, localRM
	string var_name="localhandle"

	status = viOpenDefaultRM(localRM) // open local copy of resource manager
    if(status < 0)
        VISAerrormsg("open LS625 connection:", localRM, status)
        abort
    endif
    openInstr(var_name, instrDesc, localRM=localRM, verbose=0)
    nvar localhandle = $var_name
    return localhandle
end

//////////////////
//// Logging ////
////////////////

function/s GetTwoAxisStatus(instrIDx,instrIDz)
	variable instrIDx,instrIDz
	string buffer = "", subbuffer = ""

	subbuffer = ""
	subbuffer = addJSONKeyVal(subbuffer, "x", numVal=getLS625field(instrIDx), fmtNum="%.3f")
	subbuffer = addJSONKeyVal(subbuffer, "z", numVal=getLS625field(instrIDz), fmtNum="%.3f")
	buffer = addJSONKeyVal(buffer, "field mT", strVal=subbuffer)

	subbuffer = ""
	subbuffer = addJSONKeyVal(subbuffer, "x", numVal=getLS625rate(instrIDx), fmtNum="%.1f")
	subbuffer = addJSONKeyVal(subbuffer, "z", numVal=getLS625rate(instrIDz), fmtNum="%.1f")
	buffer = addJSONKeyVal(buffer, "rate mT/min", strVal=subbuffer)

	return addJSONKeyVal("", "Two Axis Magnet", strVal=buffer)
end
