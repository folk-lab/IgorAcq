#pragma rtGlobals=1		// Use modern global access method.

//	Procedures to control the Oxford IPS120-10 magnet power supply
//	procedure written by Domink Zumbuhl, 1-20-01
//	this procedure is independent of the magnet that you wish to drive 
//	all its transactions are in current, not field

function IPSReadCurrent()
	return IPSRead(0)
end 

function IPSReadTargetCurrent()
	return IPSRead(5)
end

function IPSReadSweepRate()
	return IPSRead(6)	
end

//	Here is a list of commands that are supported with this magnet drive procedure:
//
//	first, the "set control" commands, as they are wisely call in the manual
//	C2	:	local and unlocked
//	C3	:	remote and unlocked
//
//	then, a set of action commands i(just like on front panel)
// 	A0	:	hold
//	A1	:	to set point
//	A2	:	to zero
//	A4	:	clamp (careful with this at near-maximum field -- the initial ramp-down rate may be too fast!)
//
//	then, target commands:
//	Inn	:	set target current (amps)
//	Snn	:	set current sweep rate

function IPSLocal()
	IPSWrite("$C2")
end

function IPSRemote()
	IPSWrite("$C3")
end

function IPSHold()
	IPSWrite("$A0")
end

function IPSToSetPoint()
	IPSWrite("$A1")
end

function IPSZero()
	IPSWrite("$A2")
end

function IPSClamp()
	IPSWrite("$A4")
end
function IPSHeaterOff()
	IPSWrite("$H0")
end
// This only turns the heater switch on if the recorded magnet current is equal to the
// present power supply output current.
function IPSHeaterOn()
	IPSWrite("$H1")
end



function IPSSetTargetCurrent(amps)
	variable amps		//	amps: current in amps, including sign (negative values ok)
	IPSWrite("$I"+num2str(amps))
end

function IPSSetSweepRate(amps)
	variable amps		//	amps: sweeprate in amps/min
	IPSWrite("$S"+num2str(amps))
end

function IPSWaitTillAtSetPoint()
	do
		sleep /S .2
	while (IPSReadTargetCurrent()!=IPSReadCurrent())
end

function IPSWrite(par)			// generic IPS write function
	string par
	NVAR IPS24 = IPS24
	string cmd


	sprintf cmd, "GPIB device %d", IPS24
	execute cmd
	sprintf cmd, "GPIBwrite \""+par+"\"" 
	execute cmd		
end

function IPSRead(par)	//generic IPS read function that lets you read Rpar
	variable par

	// interesting par's are: (also see page 33, IPS120-10 manual)
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
	
	NVAR IPS120 = IPS24
	string/G junkstring
	variable/G junkvariable
	string cmd

	sprintf cmd, "GPIB device %d", ips120
	execute cmd

	execute "gpib deviceclear" // get rid of any trash left over (neccessary!!)
	//sleep /s 0.1
	sprintf cmd, "GPIBwrite \"R"+num2str(par)+"\"" //R0: Read magnet current
	execute cmd
	//sleep /s 0.1

	// The ITC returns 9 characters in response to the R query.
	// They are R#######<cr> where # is [0123456789.+-] 
	// We want the 2nd through the 8th character of this string.

	execute "NI488 ibrd IPS24, junkstring, 9" // Read 9 chars from IPS
//	print junkstring
	junkvariable = str2num(junkstring	[1,7])   // Pick out number

	return junkvariable
end

function IPSSetField(field, [wait, delay])	// function written by Yuan Ren on Aug 28, 2008
// wait & delay are optional parameters
//wait=1 then the function keeps running until the field gets to setpoint
	variable field,wait, delay
	ipshold()
	ipsremote()
	//ipssettargetcurrent(field/0.1219)
	ipssettargetcurrent(field/0.13135) //Green Dewar's 15T Magnet
	//ipssettargetcurrent(field)
	ipstosetpoint()
	if(wait)
		if( ParamIsDefault(delay))
			delay=5
		endif
		do
			sleep /S delay
		while (IPSReadTargetCurrent()!=IPSReadCurrent())
	endif
end

function IPSSetCurrent(amp, [wait, delay])	// function written by Yuan Ren on Aug 28, 2008
// wait & delay are optional parameters
//wait=1 then the function keeps running until the field gets to setpoint
	variable amp,wait, delay
	//ipshold()
	ipsremote()
	ipssettargetcurrent(amp)
	ipstosetpoint()
	if(wait)
		if( ParamIsDefault(delay))
			delay=5
		endif
		do
			sleep /S delay
		while (IPSReadTargetCurrent()!=IPSReadCurrent())
	endif
end
