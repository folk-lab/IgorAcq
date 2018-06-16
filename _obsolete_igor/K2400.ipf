#pragma rtGlobals=1		// Use modern global access method.

function setkcurrent(A, range, compl, device)
	variable A, range, compl, device
	string cmd
	
	sprintf cmd, "GPIB device %d", device
	execute cmd
	execute "GPIBwrite/F=\":sour:func curr\""
	execute "GPIBwrite/F=\":sour:curr:mode fix\""
	sprintf cmd, "GPIBwrite/F=\"sour:curr:range %.10f\"",range 	//Set current range 
	execute cmd
	sprintf cmd, "GPIBwrite/F=\"sens:volt:prot %.10f\"",compl		//Set voltage compliance 
	execute cmd
	sprintf cmd, "GPIBwrite/F=\"sour:curr:level %.10f\"",A  //Set output level
	execute cmd
end

function rampkcurrent(device,amps) 

	variable amps, device
	variable A, initamps, finamps, sign1
		
	initamps = readcurrent(device)
	finamps = amps
	
	A = initamps
	sign1 = (finamps-initamps)/abs(finamps-initamps)
	do
		setkcurrent(A,1,1,device)
		sleep /s 0.05
		A += 0.001*sign1
	while ((A*sign1) < (finamps*sign1))
		setkcurrent(finamps,1,1,device)
//		print readcurrent(device)
end

function rampkvoltage(device, volts, rate, [range, cmpli])
// Revised by Yuan Ren on March 12, 2009
// Revised by Mark Lundeberg on April 27, 2009
	variable volts, device
	variable rate // mV per sec
	variable range, cmpli
	variable A, initvolts, finvolts, sign1, increment
	variable /G k2400v
	string cmd
	
	if( ParamIsDefault(range))
		range=abs(volts)
	endif
	if( ParamIsDefault(cmpli))
		cmpli=20e-6
	endif
	
	
	increment = rate/12500
	initvolts = readkprogVoltage(device)
	//sleep / s 0.05
	finvolts = volts
//	print initvolts

	range = max(abs(range),abs(initvolts))
	A = initvolts

	sign1 = sign(finvolts-initvolts)
	do
		setkvoltage(A,range,cmpli,device)
		sleep /s 0.05
		A += increment*sign1
	while ((A*sign1) < (finvolts*sign1))
	setkvoltage(finvolts,range,cmpli,device)
	//print finvolts
end

function setkVoltage(V, range, compl, device)   // 27 milliseconds
	variable V, range, compl, device
	variable /g k2400v
	string cmd
	
//	print v, range, compl
	sprintf cmd, "GPIB device %d", device
	execute cmd
	execute "GPIBwrite/F=\":sour:func volt\""
	execute "GPIBwrite/F=\":sour:volt:mode fix\""
	sprintf cmd, "GPIBwrite/F=\"sour:volt:range %.10f\"",range 	//Set voltage range t
	execute cmd
	sprintf cmd, "GPIBwrite/F=\"sens:curr:prot %.10f\"",compl		//Set current compliance (in Amps)
	execute cmd
	sprintf cmd, "GPIBwrite/F=\"sour:volt %.10f\"",V	//Set output level
	execute cmd
	k2400v = V
	
end


///// setkvoltagefast (~6 milliseconds)
////  use this only after rampkvoltage() or setkvoltage() which put the keithley in the right mode.
function setkVoltageFast(V, device)
	variable V, device
	variable /g k2400v
	string cmd
	
//	print v, range, compl
	sprintf cmd, "GPIB device %d", device
	execute cmd
	sprintf cmd, "GPIBwrite/F=\"sour:volt %.10f\"",V	//Set output level
	execute cmd
	k2400v = V
end

//// like setkvoltagefast, only use after rampkvoltage or setkvoltage!!
//// remember to set the proper range beforehand
function rampkvoltagefast(device, volts, rate)
	variable volts, device
	variable rate // mV per sec
	variable range, cmpli
	variable A, initvolts
	variable /G k2400v
	variable steptime = 0.01   /// seconds per timestep -- this should be at least 8ms for gpib data to flush.
	variable ramprange
	string cmd
			
	initvolts = k2400v  /// use the remembered k2400v value

	ramprange = max(abs(range),initvolts)

	// compute the number of moves necessary to reach target
	variable numpts = ceil(abs((initvolts-volts)/(rate*steptime/1000)))
	if(numpts<1)
		numpts = 1
	endif
	variable dv = (volts-initvolts)/numpts
	
	variable i=1

	variable startticks = stopmstimer(-2)
	do
		A = initvolts + i*dv
		setkvoltagefast(A,device)
		
		if(i == numpts)
			break
		endif
		
		i+=1
		do
		while((stopmstimer(-2) - startticks) < (steptime*1e6))
		startticks = stopmstimer(-2)
	while (1)
end


function K2400ON(device)
	variable device
	string cmd
	
	sprintf cmd, "GPIB device %d", device
	execute cmd
	sprintf cmd, "GPIBwrite/F=\":outp on\"" //turn the output on
	execute cmd
end

function K2400OFF(device)
	variable device
	string cmd
	
	sprintf cmd, "GPIB device %d", device
	execute cmd
	sprintf cmd, "GPIBwrite/F=\":outp off\"" //turn the output of
	execute cmd
end

function readCurrent(device)
	variable device
	variable/G k2400V,k2400I,k2400garbage
	string cmd
	
	sprintf cmd, "GPIB device %d", device; execute cmd
	execute "GPIBwrite/F=\"sens:func \\\"CURR\\\"\""		//configure to measure current
	execute "GPIBwrite/F=\"form:elem volt, curr\""
	execute "GPIBwrite/F=\":read?\""
	execute "GPIBread k2400v, k2400I, k2400garbage"
	return k2400I
end


function readVoltage(device)
	variable device
	variable/G k2400V,k2400I,k2400garbage
	string cmd
	
	sprintf cmd, "GPIB device %d", device; execute cmd
	//execute "GPIBwrite/F=\":syst:rsen 0\""	//Use 2-wire sense
	execute "GPIBwrite/F=\":syst:rsen 1\""	//Use 4-wire sense
	execute "GPIBwrite/F=\":outp on\"" //turn the output on
	execute "GPIBwrite/F=\"sens:func \\\"VOLT\\\"\""	//configure to measure Voltage
	execute "GPIBwrite/F=\"form:elem volt, curr\""
	execute "GPIBwrite/F=\":read?\""
	sleep /S 0.3
	execute "GPIBread k2400v, k2400I, k2400garbage"
	return k2400v
end

function readResistance(device)
	variable device
	variable/G k2400V,k2400I,k2400garbage
	string cmd
	
	sprintf cmd, "GPIB device %d", device; execute cmd
	execute "GPIBwrite/F=\":syst:rsen 0\""	//Use 2-wire sense
	execute "GPIBwrite/F=\":outp on\"" //turn the output on
	execute "GPIBwrite/F=\"sens:func \\\"RES\\\"\""	//configure to measure resistance
	execute "GPIBwrite/F=\"form:elem res, curr\""
	execute "GPIBwrite/F=\":read?\""
	execute "GPIBread k2400v, k2400I, k2400garbage"
	return k2400I
end

function readkprogVoltage(device)
	variable device
	variable/G k2400V,k2400I,k2400garbage
	string cmd
	
	sprintf cmd, "GPIB device %d", device; execute cmd
	execute "gpib board 0 ; gpib killio"
	execute "GPIBwrite/F=\":sour:func VOLT\""	//configure to measure Voltage
	execute "GPIBwrite/F=\":sour:volt?\""
	execute "GPIBread k2400v, k2400garbage"
	return k2400v
end




function rampkvoltagerange(device, volts, rate, range)

	variable volts, device
	variable rate, range // mV per sec
	variable A, initvolts, finvolts, sign1, increment
	NVAR k2400V
	
	increment = rate/12500
	readcurrent(device)	// read the current, set the device in current sense mode.
	initvolts = k2400V		// initial voltage is the programmed voltage (fetched in readcurrent())
	finvolts = volts
	
	A = initvolts
	sign1 = (finvolts-initvolts)/abs(finvolts-initvolts)
	do
		setkvoltage(A,range,0.001,device)
		sleep /s 0.05
		A += increment*sign1
	while ((A*sign1) < (finvolts*sign1))
	setkvoltage(finvolts,range,0.001,device)
//	print readvoltage(device)
end


//function Getvgate(device)
//	variable device
//	string str
//	string winfcomments ="Keitheley ", buffer=""
	
//	sprintf buffer "Vgate=%.3f V ",readVoltage(device)

//	winfcomments += buffer
	
//	return winfcomments
//end


//function GetSRSAmplitude(srs)
//	Variable srs
//	Variable/G junkvariable
//	execute "GPIB device "+num2istr(srs)
//	execute "GPIBwrite/F=\"%s\" \"SLVL? \""
//	execute "GPIBread/T=\"\n\" junkvariable"
//	return junkvariable
//End