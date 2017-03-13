#pragma rtGlobals=1	// Use modern global access method

///////////////////////////
//// Vector magnet driver ////
//////////////////////////

// Driver communicates over serial, remember to set the correct serial ports in two global strings called IPS_serial & L625_serial.
// Procedure written by Christian Olsen 2017-03-15
// Main axis is powered by an IPS120 and the in-plane fields are powered by two Lakeshore 625 power supplies.

function InitVectorMagnet()
	// 3-axis magnet. 6T-1T-1T. 
	variable/g ampsperteslax, ampsperteslay, ampsperteslaz // A/T
	variable/g maxfieldx, maxfieldy, maxfieldz // mT
	variable/g maxrampratex, maxrampratey, maxrampratez // mT/min
	
	CheckSerialPorts() // Checking that we can talk to the power supplies.
	InitIPS() // Setting the IPS in the correct mode
	InitL625() // Setting the two L625's in the correct operation mode.
	
	// Setup variables ans waves needed for the control window.
	// Add control window stuff here.
end

function CheckSerialPorts()
	svar IPS_serial, L625_serial
	string cmd, response
	
	// Checking IPS120
	SetSerialPort("ips")
	// Add stuff
	
	// Checking L625
	SetSerialPort("l625")
	response = QueryVector("*IDN?","l625")
	if(strsearch(response,"LSCI",0) ==-1)
		abort("L625 error. It is highly likely that \"L625_serial\" is not set correctly.")
	endif
end

function initIPS()
	svar IPS_serial
	string cmd
	
	SetSerialPort("ips")
	VDT2 baud=9600, stopbits=2, terminalEOL=0, killio
end

function InitL625()
	svar L625_serial
	string cmd
	
	SetSerialPort("l625")
	VDT2 baud=9600, stopbits=1, databits=7, parity=1, terminalEOL=2, killio
end

function SetSerialPort(powersupply)
	string powersupply
	string cmd, serialport
	
	if(cmpstr(powersupply,"ips"))
		svar IPS_serial
		serialport = IPS_serial
	elseif(cmpstr(powersupply,"l625"))
		svar L625_serial
		serialport = L625_serial
	endif
	
	sprintf cmd, "VDTOperationsPort2 %s", serialport
	execute(cmd)
end


/////////////////////////////
//// Magnet communications ////
////////////////////////////

function/s QueryVector(cmd,powersupply)
	string cmd, powersupply
	
	SetSerialPort(powersupply)
	// Write the command and read reponse	
end