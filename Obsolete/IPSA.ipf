#pragma rtGlobals=1		// Use modern global access method.

//	Procedures to control the Oxford IPS120-10 magnet power supply
//	procedure written by Domink Zumbuhl, 1-20-01
//	this procedure is independent of the magnet that you wish to drive 
//	all its transactions are in current, not field

function ipsAReadCurrent()
	return ipsARead(0)
end 

function ipsAReadTargetCurrent()
	return ipsARead(5)
end 

function ipsAReadSweepRate()
	return ipsARead(6)	
end

//	Here is a list of commands that are supported with this magnet drive procedure:
//
//	first, the "set control" commands, as they are wisely call in the manual
//	C2	:	local and unlocked
//	C3	:	remote and unlocked
//
//	then, a set of action commands (just like on front panel)
// 	A0	:	hold
//	A1	:	to set point
//	A2	:	to zero
//	A4	:	clamp			(pretty radical, probably bad idea to try when at (high/any) field)
//
//	then, target commands:
//	Inn	:	set target current (amps)
//	Snn	:	set current sweep rate

function ipsALocal()
	ipsAWrite("C2")
end

function ipsARemote()
	ipsAWrite("C3")
end

function ipsAHold()
	ipsAWrite("A0")
end

function IPSAHeaterOff()
	IPSAWrite("$H0")
end
// This only turns the heater switch on if the recorded magnet current is equal to the
// present power supply output current.
function IPSAHeaterOn()
	IPSAWrite("$H1")
end

function ipsAToSetPoint()
	ipsAWrite("A1")
end

function ipsAZero()
	ipsAWrite("A2")
end

function ipsAClamp()
	ipsAWrite("A4")
end

function ipsASetTargetCurrent(amps)
	variable amps		//	amps: current in amps, including sign (negative values ok)
	ipsAWrite("I"+num2str(amps))
end

function gotofield(field)
	variable field
	//ipsasettargetcurrent(field*7.61324704987) // Green Dewar's 15T Magnet
	ipsasettargetcurrent(field*8.2061452674) // Blue Dewar
	// ipsAToSetPoint()
end

function ipsASetSweepRate(amps)
	variable amps		//	amps: sweetrate in amps/min
	ipsAWrite("S"+num2str(amps))
end

function ipsAWaitTillAtSetPoint()
	do
		sleep /S 0.05
	while (ipsAReadTargetCurrent()!=ipsAReadCurrent())
end

function ipsAWrite(par)			// generic ipsA write function
	string par
	string cmd
	variable/G IPSA_ISOBUS_Num
	
	//print "ISOBUS Number is "+num2str(IPSA_ISOBUS_Num)
	ISOBUS_signal(IPSA_ISOBUS_Num,par)
//	NVAR ips24 = ips24
//	sprintf cmd, "GPIB device %d", ips24
//	execute cmd
//	sprintf cmd, "GPIBwrite \""+par+"\"" 
//	execute cmd		
end

function ipsA_fine()
	ipsAWrite("Q4")
end

function ipsARead(par)	//generic ipsA read function that lets you read Rpar
	variable par

	// interesting par's are: (also see page 33, ipsA120-10 manual)
	//	0	:	output current 				Amp
	//	5	:	set point 					Amp
	//	6	: 	sweep rate					Amps/min
	//	7	:	output field					Tesla
	//	8	:	set point					Tesla
	//	9	:	sweep rate					Tesla/min
	//	1	:	measured output voltage		Volt
	//	21	:	safe current limit (neg)		Amp
	//	22	:	safe current limit (pos)		Amp
	// 	23	:	lead resistance				milli Ohm
	//	24	:	magnet inductance			Henry
	
	string/G junkstring
	variable/G junkvariable
	variable/G IPSA_ISOBUS_Num
	string cmd
	
	string /g junkstr
	ISOBUS_command(IPSA_ISOBUS_Num,"R"+num2str(par))
	return str2num(junkstr[1,7])

//	NVAR ips24 = ips24
//	sprintf cmd, "GPIB device %d", ips24
//	execute cmd
//
//	execute "gpib deviceclear" // get rid of any trash left over (neccessary!!)
//	sleep /s 0.1
//	sprintf cmd, "GPIBwrite \"R"+num2str(par)+"\"" //R0: Read magnet current
//	execute cmd
//	sleep /s 0.1
//
//	// The ITC returns 9 characters in response to the R query.
//	// They are R#######<cr> where # is [0123456789.+-] 
//	// We want the 2nd through the 8th character of this string.
//
//	execute "NI488 ibrd ips24, junkstring, 9" // Read 9 chars from ipsA
////	print junkstring
//	junkvariable = str2num(junkstring	[1,7])   // Pick out number
//
//	return junkvariable
end