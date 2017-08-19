init#pragma rtGlobals=1		// Use modern global access method.// DMM Procedures// Nik and Elyjah 8/17//// USEFUL STUFF ///////function /s GetDMMIDN(dmm)	Variable dmm	string readval	GPIB2 device = dmm	GPIBWrite2 "*IDN?\n"	GPIBRead2 /T="\n\r" readval	return readvalendfunction SetTextDMM(dmm, disp)	// this cracks me up	variable dmm	string disp	GPIB2 device = dmm	GPIBwrite2 ":DISP:TEXT '" + disp + "'\n"endfunction ReadDMMjunk(dmm)	// for those times when your dmm gpib got messed up and there's something in the buffer, and	// your scans are always off by some buffered reading... call this procedure.	variable dmm	variable readval	variable i	do		GPIB2 device = dmm		GPIBRead2 /Q/N=1 readval		i+=1	while(v_flag)	printf "this read %d characters of junk \r", i-1Endfunction ErrorsDMM(dmm)	variable dmm	string readval	variable i=1	GPIB2 device = dmm	do		GPIBwrite2 "SYST:ERR?"		GPIBRead2 /T="\n\r" readval		print num2str(i) + ":  " + readval		if(stringmatch(readval[0,1],"+0")==1 || i>9)			break		endif		i+=1	while(1==1)end///// SETUP //////function  InitDMMdcvolts(dmm, range, linecycles)	// setup dmm to take dc voltage readings	Variable dmm, range, linecycles	// Ranges: 0.1, 1, 10, 100, 1000V 	// Linecycles: 0.02, 0.2, 1, 10, 100 (60Hz cycles)		// autozero off with 1NPLC gives 5.5 digits of resolution 	// according to the manual	// this is a pretty good default and makes the read time comparable to an srs830		GPIB2 device = dmm	GPIBwrite2 "*RSTrea\n"	sc_sleep(0.05)	GPIBwrite2 "*CLS\n"	sc_sleep(0.05)	GPIBwrite2 "conf:volt:dc " + num2str(range) + "\n"	sc_sleep(0.05)	GPIBwrite2 "zero:auto off\n"	sc_sleep(0.05)	GPIBwrite2 "volt:dc:nplc " + num2str(linecycles) + "\n"Endfunction SetSpeedDMM(dmm, speed)	Variable dmm, speed	String linecycles="1"	if (speed == -2)		linecycles = ".02"	elseif (speed == -1)		linecycles = ".2"	elseif (speed == 0)		linecycles = "1"	elseif (speed == 1)		linecycles = "10"	elseif (speed == 2)		linecycles = "100"	endif	GPIB2 device = dmm	GPIBwrite2 "volt:dc:nplc "+linecycles+"\n"Endfunction /s checkDMMconfig(dmm)	Variable dmm	string readval	GPIB2 device = dmm	GPIBWrite2 "CONF?\n"	GPIBRead2 /Q/T="\n\r" readval	return readvalend////// READ /////function ReadDMM(dmm)	Variable dmm	string readval=""	GPIB2 device = dmm	GPIBWrite2 "READ?\n"	GPIBRead2 /Q/T="\n\r" readval	return str2num(readval)end////// LOGGING //////function /S getDMMstatus(dmm)	variable dmm	nvar pad	string cmd	string winfcomments	string  buffer		sprintf  winfcomments "HP 34401A DMM GPIB%d:\r\t", returnGPIBaddress(dmm)	buffer = checkDMMconfig(dmm)	winfcomments += ReplaceString("\"", buffer, "")	return winfcommentsend