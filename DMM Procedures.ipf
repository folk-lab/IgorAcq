init#pragma rtGlobals=1		// Use modern global access method.// DMM Procedures// Michael Switkes & Randy True// 26 May 1996// Last modified by Alex Johnson 8/05// The "dmm" arguments passed to most functions should be obtained with the command:// NI488 ibfind "dev##", X// where ## is the GPIB address of the DMM and X is a global variable used to store it // eg: NI488 ibfind "dev14", dmm14	(see InitGPIB())// Set up a DMM to read DC voltages// Run once for each DMM before first usefunction InitDMM(dmm)	Variable dmm	execute "GPIB device "+num2istr(dmm)	execute "GPIBwrite/F=\"%s\" \"conf:volt:dc def, max\""	execute "GPIBwrite/F=\"%s\" \"zero:auto off\""	localdmm(dmm)End// Sets the reading speed of the DMM (integration time).// speed can be one of {-2,-1, 0, 1, 2} which correspond to// {.02,.2,1,10,100} line cycles (at 60Hz), or// integration times of {.00033, .0033, .017, .17, 1.7} secondsfunction SetSpeedDMM(dmm, speed)	Variable dmm, speed	String linecycles="1"	if (speed == -2)		linecycles = ".02"	elseif (speed == -1)		linecycles = ".2"	elseif (speed == 0)		linecycles = "1"	elseif (speed == 1)		linecycles = "10"	elseif (speed == 2)		linecycles = "100"	endif	execute "GPIB device "+num2istr(dmm)	execute "GPIBwrite/F=\"%s\" \"volt:dc:nplc "+linecycles+"\""	localdmm(dmm)End// Puts the newest DMM error in global junkstring and clears it from the bufferfunction errorDMM(dmm)	Variable dmm	string /G junkstring	execute "GPIB device "+num2istr(dmm)	execute "GPIBwrite/F=\"%s\" \"syst:err?\""	execute "GPIBread/T=\"\n\" junkstring"end// Clears the error buffer and the i/o buffersfunction cleardmm(dmm)	variable dmm	execute "GPIB device "+num2istr(dmm)	execute "GPIB deviceclear"	errordmm(dmm);errordmm(dmm);errordmm(dmm)	errordmm(dmm);errordmm(dmm);errordmm(dmm)	localdmm(dmm)end	// This reads the DMM and returns the measurement in Volts!function ReadDMM(dmm)	variable dmm	Variable/G junkvariable, nanjunk,V_flag	V_flag = 0	//setspeeddmm(dmm,0)	execute "GPIB device "+num2istr(dmm)	execute "GPIBwrite/F=\"%s\"  \"READ?\""	execute "GPIBread/Q/T=\"\n\" junkvariable" // added as a hacked solution to reading NaNs every other time	//execute "GPIBread/Q/T=\"\n\" nanjunk" // added as a hacked solution to reading NaNs every other time//	if (!V_flag)//		cleardmm(dmm)//		print "VFLAG"		//setspeeddmm(dmm,-2)//		execute "GPIB device "+num2istr(dmm)//		execute "GPIBwrite/F=\"%s\"  \"read?\""//		sleep/s 0.05//		execute "GPIBread/Q/T=\"\n\" junkvariable"//		execute "GPIBread/Q/T=\"\n\" nanjunk" // added as a hacked solution to reading NaNs every other time//	endif	return junkvariableEnd// leaves dmms in remote mode after a measurementfunction nolocal()	variable/G flagnolocal=1end// Sends one dmm back to localfunction LocalDmm(dmm)	variable dmm	variable/G flagnolocal=0	execute "GPIB device "+num2istr(dmm)	execute "GPIB gotolocal"end// fourwire: 0 for 2wire measurement (default), 1 for 4wire measurementfunction DmmReadResistance(dmm, range, [fourwire])	variable dmm, range, fourwire	Variable/G junkvariable, V_flag	setspeeddmm(dmm,-2)	execute "GPIB device "+num2istr(dmm)	if (ParamIsDefault(fourwire))		fourwire = 0	endif	if (fourwire == 1)		execute "GPIBwrite/F=\"%s\"  \"MEASure:FRESistance? "+num2str(range)+"\""	else		execute "GPIBwrite/F=\"%s\"  \"MEASure:RESistance? "+num2str(range)+"\""	endif		sleep/s 0.2	execute "GPIBread/Q/T=\"\n\" junkvariable"	if (!V_flag)		cleardmm(dmm)		setspeeddmm(dmm,-2)		execute "GPIB device "+num2istr(dmm)		execute "GPIBwrite/F=\"%s\"  \"MEASure:RESistance? "+num2str(range)+"\""		sleep/s 0.2		execute "GPIBread/Q/T=\"\n\" junkvariable"	endif		return junkvariableend