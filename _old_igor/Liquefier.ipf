#pragma rtGlobals=1		// Use modern global access method.


////////// Procedures for communicating with the LM500 liquid level meter,
// which is installed on the LHeP18 helium liquefaction plant.
//   -Mark, November 2011


function initliquefier([port])
	string port
	if(paramisdefault(port))
		port = "COM3"
	endif
	string /g liquefierport = port
end

/// Reads level from liquefier and returns level in requested units.
//  units = "cm", "in", or "%".  Default units are %.
function readliquefierlevel([units])
	string units
	SVAR /Z liquefierport
	string /g junkstr
	if(!SVAR_Exists(liquefierport))
		initliquefier()
		string /g liquefierport
	endif
	if(paramisdefault(units))
		units = "%"
	endif
	
	execute "vdtoperationsport2 "+liquefierport
	execute "vdt2 baud=9600, stopbits=1, databits=8, parity=0, in=0,  out=0, echo=0, terminalEOL=0,killio"
	junkstr = ""
	vdtwrite2 /O=1 /Q "UNITS "+units+";MEAS?\r"  // this command shouldn't time out since there's no flow control
	vdtread2 /O=0.1 /Q junkstr // this command should read a command echo from the liquiefier.
	if(V_VDT != 1 || !stringmatch(junkstr,"UNITS "+units+";MEAS?*"))
		return nan     // did not read any response, therefore we are not able to communicate with liquefier.
	endif
	vdtread2 /O=0.1 /Q junkstr // this command will read "<LF>XX.X %"
	if(V_VDT != 1 )
		return nan     // did not read any response, therefore we are not able to communicate with liquefier.
	endif
	variable pnum
	string percent
	sscanf junkstr, "\n%f %[%cmin]", pnum, percent
	if(stringmatch(percent,units)) // valid response received.
		return pnum
	endif
	print pnum, percent
end