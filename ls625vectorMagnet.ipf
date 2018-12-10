#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1	// Use modern global access method

// Driver communicates over serial.
// Procedure written by Christian Olsen 2017-03-15
// Updated to VISA by Christian Olsen, 2018-05-xx
// All axes are powered by Lakeshore 625 power supplies.


////////////////////////////
//// Lakeshore 625 COMM ////
////////////////////////////

function openLS625connection(instrID, visa_address, [verbose])
	// instrID is the name of the global variable that will be used for communication
	// visa_address is the VISA address string, i.e. ASRL1::INSTR
	string instrID, visa_address
	variable verbose
	
	if(paramisdefault(verbose))
		verbose=1
	elseif(verbose!=1)
		verbose=0
	endif
	
	variable localRM
	variable status = viOpenDefaultRM(localRM) // open local copy of resource manager
	if(status < 0)
		VISAerrormsg("open LS625 connection:", localRM, status)
		abort
	endif
	
	string comm = ""
	sprintf comm, "name=LS625,instrID=%s,visa_address=%s" instrID, visa_address
	string options = "baudrate=57600,databits=7,stopbits=1,parity=1"
	openVISAinstr(comm, options=options, localRM=localRM, verbose=verbose)
end

///////////////////////
/// Initiate Magnet ///
///////////////////////

function initLS625Vector(instrIDx,instrIDy,instrIDz)
	// wrapper function for initLS625(instrID)
	variable instrIDx, instrIDy, instrIDz

	// local copies of the serial port addresses
	string/g instrDescX = getResourceAddress(instrIDx)
	string/g instrDescY = getResourceAddress(instrIDy)
	string/g instrDescZ = getResourceAddress(instrIDz)

	// create string constants for use in get/set functions
	execute("L625StrConst()")

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

	// Set sweep rates, unit: mT/s
	setLS625rate(instrIDx,100)
	setLS625rate(instrIDy,100)
	setLS625rate(instrIDz,100)

	// Start GUI
	dowindow/k Vector_Window
	execute("Vector_Window()")
end

macro L625StrConst()
	svar instrDescX,instrDescY,instrDescZ

	// create string constants for use in get/set functions
	StrConstant strX=instrDescX
	StrConstant strY=instrDescX
	StrConstant strZ=instrDescX
endmacro

///////////////////////
//// Get functions ////
//////////////////////

function getLS625current(instrID) // Units: A
	variable instrID
	nvar ampsperteslax,ampsperteslay,ampsperteslaz
	wave/t outputvalstr,sphericalvalstr
	wave sphericalcoordinates
	variable current,field, ampspertesla
	svar instrDescX,instrDescY,instrDescZ

	string l625 = getResourceAddress(instrID)

	current = str2num(queryInstr(instrID,"RDGI?\r\n", read_term = "\r\n"))

	// Update control window
	strswitch(l625)
		case strX:
			outputvalstr[0][1] = num2str(Round_Number(current/ampsperteslax*1000,5))
			break
		case strY:
			outputvalstr[1][1] = num2str(Round_Number(current/ampsperteslay*1000,5))
			break
		case strZ:
			outputvalstr[2][1] = num2str(Round_Number(current/ampsperteslaz*1000,5))
			break
		default:
			abort "Couldn't determine which axis to address"
	endswitch

	CartisiantoSpherical(str2num(outputvalstr[0][1]),str2num(outputvalstr[1][1]),str2num(outputvalstr[2][1]))
	sphericalvalstr[0][1] = num2str(sphericalcoordinates[0])
	sphericalvalstr[1][1] = num2str(sphericalcoordinates[1])
	sphericalvalstr[2][1] = num2str(sphericalcoordinates[2])

	return current
end

function getL625allcurrent(instrIDx,instrIDy,instrIDz) // Units: A
	variable instrIDx,instrIDy,instrIDz
	nvar ampsperteslax, ampsperteslay, ampsperteslaz
	make/o/n=3 currentwave

	currentwave[0] = getLS625current(instrIDx)
	currentwave[1] = getLS625current(instrIDy)
	currentwave[2] = getLS625current(instrIDz)
end

function getLS625field(instrID) // Units: mT
	variable instrID
	nvar ampsperteslax,ampsperteslay,ampsperteslaz
	variable field, current
	wave/t outputvalstr
	svar instrDescX,instrDescY,instrDescZ

	string l625 = getResourceAddress(instrID)

	current = getLS625current(instrID)
	// Update control window
	strswitch(l625)
		case strX:
			field = Round_Number(current/ampsperteslax*1000,5)
			outputvalstr[0][1] = num2str(field)
			break
		case strY:
			field = Round_Number(current/ampsperteslay*1000,5)
			outputvalstr[1][1] = num2str(field)
			break
		case strZ:
			field = Round_Number(current/ampsperteslaz*1000,5)
			outputvalstr[2][1] = num2str(field)
			break
		default:
			abort "Couldn't determine which axis to address"
	endswitch

	return field
end

function getL625allfield(instrIDx,instrIDy,instrIDz) // Units: mT
	variable instrIDx,instrIDy,instrIDz
	make/n=3/o fieldwave

	fieldwave[0] = getLS625field(instrIDx)
	fieldwave[1] = getLS625field(instrIDy)
	fieldwave[2] = getLS625field(instrIDz)
end

function getLS625rate(instrID) // Units: mT/min
	variable instrID
	nvar ampsperteslax,ampsperteslay,ampsperteslaz
	wave/t sweepratevalstr
	variable rampratefield, currentramprate

	string l625 = getResourceAddress(instrID)

	currentramprate = str2num(queryInstr(instrID,"RATE?\r\n", read_term = "\r\n")) // A/s
	// Update control window
	strswitch(l625)
		case strX:
			rampratefield = Round_Number(currentramprate/ampsperteslax*60*1000,5)
			sweepratevalstr[0][1] = num2str(rampratefield)
			break
		case strY:
			rampratefield = Round_Number(currentramprate/ampsperteslay*60*1000,5)
			sweepratevalstr[1][1] = num2str(rampratefield)
			break
		case strZ:
			rampratefield = Round_Number(currentramprate/ampsperteslaz*60*1000,5)
			sweepratevalstr[2][1] = num2str(rampratefield)
			break
		default:
			abort "Couldn't determine which axis to address"
	endswitch

	return rampratefield
end

function getLS625allrate(instrIDx,instrIDy,instrIDz)
	variable instrIDx,instrIDy,instrIDz
	make/o/n=3 sweepratewave

	sweepratewave[0] = getLS625rate(instrIDx)
	sweepratewave[1] = getLS625rate(instrIDy)
	sweepratewave[2] = getLS625rate(instrIDz)
end

////////////////////////
//// Set functions ////
//////////////////////

function setLS625current(instrID,output) // Units: A
	variable instrID,output
	string cmd
	wave/t setpointvalstr
	nvar maxfieldx,maxfieldy,maxfieldz,ampsperteslax,ampsperteslay,ampsperteslaz
	variable maxfield,ampspertesla,i=-1
	
	// check for NAN and INF
	if(sc_check_naninf(output) != 0)
		abort "trying to set output to NaN or Inf"
	endif
	
	string l625 = getResourceAddress(instrID)

	strswitch(l625)
		case strX:
			maxfield = maxfieldx
			ampspertesla = ampsperteslax
			i=0
			break
		case strY:
			maxfield = maxfieldy
			ampspertesla = ampsperteslay
			i=1
			break
		case strZ:
			maxfield = maxfieldz
			ampspertesla = ampsperteslaz
			i=2
			break
		default:
			abort "Couldn't determine which axis to address"
	endswitch

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
	nvar maxfieldx,maxfieldy,maxfieldz,ampsperteslax,ampsperteslay,ampsperteslaz
	variable round_amps
	string cmd
	variable maxfield,ampspertesla,i=0

	string l625 = getResourceAddress(instrID)

	strswitch(l625)
		case strX:
			maxfield = maxfieldx
			ampspertesla = ampsperteslax
			i=2
			break
		case strY:
			maxfield = maxfieldy
			ampspertesla = ampsperteslay
			i=3
			break
		case strZ:
			maxfield = maxfieldz
			ampspertesla = ampsperteslaz
			i=4
			break
		default:
			abort "Couldn't determine which axis to address"
	endswitch

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
	nvar maxrampratex,maxrampratey,maxrampratez,ampsperteslax,ampsperteslay,ampsperteslaz
	wave/t sweepratevalstr
	variable ramprate_amps
	string cmd
	variable maxramprate,ampspertesla,i=0,j=-1
	
	// check for NAN and INF
	if(sc_check_naninf(output) != 0)
		abort "trying to set ramp rate to NaN or Inf"
	endif
	
	string l625 = getResourceAddress(instrID)

	strswitch(l625)
		case strX:
			maxramprate = maxrampratex
			ampspertesla = ampsperteslax
			i=2
			j=0
			break
		case strY:
			maxramprate = maxrampratey
			ampspertesla = ampsperteslay
			i=3
			j=1
			break
		case strZ:
			maxramprate = maxrampratez
			ampspertesla = ampsperteslaz
			i=4
			j=2
			break
		default:
			abort "Couldn't determine which axis to address"
	endswitch

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

function setLS625allrate(instrIDx,instrIDy,instrIDz,outputx,outputy,outputz) // Units: mT/min
	variable instrIDx,instrIDy,instrIDz,outputx,outputy,outputz
	variable checkx, checky, checkz

	checkx = setLS625rate(instrIDx,outputx)
	checky = setLS625rate(instrIDy,outputy)
	checkz = setLS625rate(instrIDz,outputz)
	return checkx+checky+checkz
end

function setLS625allcurrent(instrIDx,instrIDy,instrIDz,outputx,outputy,outputz) // Units: A
	variable instrIDx,instrIDy,instrIDz,outputx,outputy,outputz

	setLS625current(instrIDx,outputx)
	setLS625current(instrIDy,outputy)
	setLS625current(instrIDz,outputz)
end

function setLS625allfield(instrIDx,instrIDy,instrIDz,outputx,outputy,outputz) // Units: mT
	variable instrIDx,instrIDy,instrIDz,outputx,outputy,outputz
	variable checkx,checky,checkz

	checkx = setLS625field(instrIDx,outputx)
	checky = setLS625field(instrIDy,outputy)
	checkz = setLS625field(instrIDz,outputz)

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
	svar oldsetpointx,oldsetpointy,oldsetpointz,instrDescX,instrDescY,instrDescZ

	// open local instr connections
	openLS625connection("tempIDx", instrDescX, verbose=0)
	openLS625connection("tempIDy", instrDescY, verbose=0)
	openLS625connection("tempIDz", instrDescZ, verbose=0)
	nvar tempIDx, tempIDy, tempIDz

	check = setLS625allfield(tempIDx,tempIDy,tempIDz,str2num(setpointvalstr[0][1]),str2num(setpointvalstr[1][1]),str2num(setpointvalstr[2][1]))
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

	viClose(tempIDx)
	viClose(tempIDy)
	viClose(tempIDz)
end

function update_sweeprate(action) : ButtonControl
	string action
	variable check
	wave/t sweepratevalstr
	svar oldsweepratex,oldsweepratey,oldsweepratez,instrDescX,instrDescY,instrDescZ

	// open local instr connections
	openLS625connection("tempIDx", instrDescX, verbose=0)
	openLS625connection("tempIDy", instrDescY, verbose=0)
	openLS625connection("tempIDz", instrDescZ, verbose=0)
	nvar tempIDx, tempIDy, tempIDz

	check = setLS625allrate(tempIDx,tempIDy,tempIDz,str2num(sweepratevalstr[0][1]),str2num(sweepratevalstr[1][1]),str2num(sweepratevalstr[2][1]))
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

	viClose(tempIDx)
	viClose(tempIDy)
	viClose(tempIDz)
end

function update_everything(action) : ButtonControl
	string action
	wave fieldwave
	svar instrDescX,instrDescY,instrDescZ

	// open local instr connections
	openLS625connection("tempIDx", instrDescX, verbose=0)
	openLS625connection("tempIDy", instrDescY, verbose=0)
	openLS625connection("tempIDz", instrDescZ, verbose=0)
	nvar tempIDx, tempIDy, tempIDz

	getL625allfield(tempIDx,tempIDy,tempIDz)
	getLS625allrate(tempIDx,tempIDy,tempIDz)
	CartisiantoSpherical(fieldwave[0],fieldwave[1],fieldwave[2])
	update_output()

	viClose(tempIDx)
	viClose(tempIDy)
	viClose(tempIDz)
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

function/s GetVectorStatus(instrIDx,instrIDy,instrIDz)
	variable instrIDx,instrIDy,instrIDz
//	string buffer = "", subbuffer = ""
//
//	subbuffer = ""
//	subbuffer = addJSONkeyvalpair(subbuffer, "x", num2str(getLS625field(instrIDx)))
//	subbuffer = addJSONkeyvalpair(subbuffer, "y", num2str(getLS625field(instrIDy)))
//	subbuffer = addJSONkeyvalpair(subbuffer, "z", num2str(getLS625field(instrIDz)))
//	buffer = addJSONkeyvalpair(buffer, "field mT", subbuffer)
//
//	subbuffer = ""
//	subbuffer = addJSONkeyvalpair(subbuffer, "x", num2str(getLS625rate(instrIDx)))
//	subbuffer = addJSONkeyvalpair(subbuffer, "y", num2str(getLS625rate(instrIDy)))
//	subbuffer = addJSONkeyvalpair(subbuffer, "z", num2str(getLS625rate(instrIDz)))
//	buffer = addJSONkeyvalpair(buffer, "rate mT/min", subbuffer)
//
//	return addJSONkeyvalpair("", "Vector Magnet", buffer)
end
