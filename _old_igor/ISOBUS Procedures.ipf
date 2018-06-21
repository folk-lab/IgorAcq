	#pragma rtGlobals=1		// Use modern global access method.

//// July 9, 2012 --- unified ISOBUS communications procedures, for IGH, IPS, level meter...

//// Configure here: Enter the serial port number
function ISOBUSSetPort()
	execute "VDTOperationsPort2 COM3"
end

function initISOBUS()
	variable /g ISOBUSDirtyBuffer = 1
	variable /g v_vdt
	ISOBUSSetPort()
	execute "vdt2 baud=9600, stopbits=2, databits=8, parity=0, in=0,  out=0, echo=0, terminalEOL=0,killio"
end


// Sometimes the reading data is not successful and the data is still left in the buffer of ISOBUS.
// This will mess up the program, and will even cause the fridge warming up.
// This function reads the buffer repeatly to make sure that all data is read out.
// The final command (attempted read on empty buffer) times out after 0.1s.
Function ISOBUS_clearbuffer()
	string cmd
	svar junkstr
	//nvar KelvinoxDirtyBuffer
	nvar v_vdt
	ISOBUSSetPort()
	do
		cmd="VDTread2 /O=0.1/Q junkstr"
		execute (cmd)
	while(V_VDT)
	//KelvinoxDirtyBuffer = 0
end

/// Send <cmd> to instrument <num> and read 1 line of response. Response is stored in junkstr.
Function ISOBUS_command(num,cmd,[failreturn,readtimeout])
	variable num
	string cmd
	variable failreturn,readtimeout
	string cmd2
	svar junkstr
	nvar v_vdt
	nvar ISOBUSDirtyBuffer 
	if(paramisdefault(readtimeout))
		readtimeout = 10
	endif
	ISOBUSSetPort()
	execute "vdt2 killio"
	if(ISOBUSDirtyBuffer)
		ISOBUS_ClearBuffer()
	endif
	ISOBUSDirtyBuffer = 1 /// if we fail, buffer is dirty.
	//print "ISOBUS Number (command) is "+num2str(num)
	//cmd2="VDTwrite2 /o=3 /q \"@"+num2str(num)+cmd+"\\r\""
	cmd2="VDTwrite2 /o=3 /q \""+cmd+"\\r\""
	//cmd2="VDTwrite2 /o=3 /q \"@"+num2str(num)+cmd+"\\r\""	
	
	execute (cmd2)
	if(v_vdt == 0)
		abort "Failed communication with ISOBUS (write)." 
		junkstr = ""
		return 0
	endif
	cmd2="VDTread2 /o="+num2str(readtimeout)+" /q junkstr"
	execute (cmd2)
	if(v_vdt == 0)  ///// Failed to read
		junkstr = ""
		if(failreturn)
			return 0
		endif
		abort "Failed communication with ISOBUS (read). Were you holding down a button?" 
		return 0
	endif
	ISOBUSDirtyBuffer = 0 /// success -- buffer is clean.
	return 1   //return 1 on success
end

/// Sends <cmd> to instrument <num> with NO RESPONSE REQUESTED ($).
///    This command will not fail if the instrument is not connected.
Function ISOBUS_signal(num,cmd)
	variable num
	string cmd
	string cmd2
	svar junkstr
	nvar v_vdt
	nvar ISOBUSDirtyBuffer 
	ISOBUSSetPort()
	execute "vdt2 killio"
	if(ISOBUSDirtyBuffer)
		ISOBUS_ClearBuffer()
	endif
	ISOBUSDirtyBuffer = 1 /// if we fail, buffer is dirty.
	//print "ISOBUS(signal) Number is "+num2str(num)
	cmd2="VDTwrite2 /o=3 /q \"$@"+num2str(num)+cmd+"\\r\""
	//cmd2="VDTwrite2 /o=3 /q \"$"+cmd+"\\r\""
	//cmd2="VDTwrite2 /o=2  \"U1\\r\""
	//execute (cmd2)
	//cmd2="VDTwrite2 /o=2  \"!3\\r\""
	execute (cmd2)
	if(v_vdt == 0)
		abort "Failed communication with ISOBUS (write)." 
		junkstr = ""
		return 0
	endif
	ISOBUSDirtyBuffer = 0 /// success -- buffer is clean.
	return 1   //return 1 on success
end
