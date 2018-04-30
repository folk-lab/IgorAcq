#pragma rtGlobals=1		// Use modern global access method.


function initANC([port])
	string port
	if(paramisdefault(port))
		port = "COM5"
	endif
	string /g ancport = port
	execute "vdtoperationsport2 "+ancport
	execute "vdt2 baud=38400, stopbits=1"
	ANCcommand("echo off")
end

function /s ANCcommand(cmd)
	string cmd
	svar ancport
	string /g junkstr = cmd+"\r\n"
	execute "vdtoperationsport2 "+ancport
	execute "vdtwrite2 /O=3 junkstr"
	variable firstline=1
	string savedline
	do
		execute "vdtread2 /O=10 /T=\"\n\" junkstr"
		junkstr = junkstr[0,strlen(junkstr)-2]
		if(firstline)
			savedline = junkstr
			firstline = 0
		endif
	while(!stringmatch(junkstr,"OK") && !stringmatch(junkstr,"ERROR"))
	if(stringmatch(junkstr,"ERROR"))
		print "ANC error:", savedline
	endif
	return savedline
end

function ANCstep(id,howmany)
	variable id, howmany
	if(howmany > 0)
		anccommand("stepu "+num2str(id)+" "+num2istr(howmany))
	endif
	if(howmany < 0)
		anccommand("stepd "+num2str(id)+" "+num2istr(-howmany))
	endif
end