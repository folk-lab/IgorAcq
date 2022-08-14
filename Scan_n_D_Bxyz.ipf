#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

// 2D device scans 
// Written by Zhenxiang Gao, Ray Su 
// ruihengsu@gmail.com
// Mr Ray: the idea is to first set the device parameters, namely the top and bottom gate dielectric thickness first 
// using the function setDualGateDeviceParameters(top_thickness, bottom_thickness) 
// this creates several global variables that is used in to compute the matrix elements to convert from VtVb to n,D 
// running the setDualGateDeviceParameters function should reset global variables, thus modifying the matrix elements 

function setDualGateDeviceParameters(top_thickness, bottom_thickness, n0, ns) 
	// these are the estimated top and bottom gate dielectric thickness in nm
	// n_offset is independently determined instrinsic doping of the sample, in units of 10^12 cm^-2
	variable top_thickness, bottom_thickness, n0, ns
	variable/G full_filling = ns
	variable/G n_offset = n0
	variable/G epsilon_hbn = 3.4
	variable/G epsilon_0 = 8.8541878128e-12
	variable/G electron_charge = 1.602176634e-19 
	variable/G top_capacitance = epsilon_0*epsilon_hbn/(top_thickness*1e-9) // these are the capacitances per unit area 
	variable/G bottom_capacitance = epsilon_0*epsilon_hbn/(bottom_thickness*1e-9)
end

// These are the matrix elements 
function A_nt()
	nvar top_capacitance
	nvar electron_charge
	return 1e-16*top_capacitance/electron_charge/1000
end 

function A_nb()
	nvar electron_charge
	nvar bottom_capacitance
	return 1e-16*bottom_capacitance/electron_charge/1000
end 

function A_Dt()
	nvar top_capacitance
	nvar electron_charge
	nvar epsilon_0
	return -1e-9*top_capacitance/(2*epsilon_0)/1000
end 

function A_Db()
	nvar electron_charge
	nvar bottom_capacitance
	nvar epsilon_0
	return 1e-9*bottom_capacitance/(2*epsilon_0)/1000
end 


function B_tn()
	nvar top_capacitance
	nvar electron_charge
	return 1000*1e16*electron_charge/(2*top_capacitance)
end 

function B_tD()
	nvar top_capacitance
	nvar epsilon_0
	return 1000*-1e9*epsilon_0/(top_capacitance)
end 

function B_bn()
	nvar bottom_capacitance
	nvar electron_charge
	return 1000*1e16*electron_charge/(2*bottom_capacitance)
end 

function B_bD()
	nvar bottom_capacitance
	nvar epsilon_0
	return 1000*1e9*epsilon_0/(bottom_capacitance)
end 

//////////////////////////////////////////
////Convert b/w gate voltages and (n,D)///
//////////////////////////////////////////

function ConvertnuTon(nu)
	variable nu
	nvar full_filling
	return nu*full_filling/4
end


function ConvertVtVbTon(Vtop,Vbtm)  //Input Vtop and vbtm are in units of mV. e.g. '1000'->1V
	variable Vtop,Vbtm
	nvar n_offset
	return A_nt()*Vtop+A_nb()*Vbtm - n_offset
end

function ConvertVtVbToD(Vtop,Vbtm)  //Input Vtop and vbtm are in units of mV. e.g. '1000'->1V
	variable Vtop,Vbtm
	return A_Dt()*Vtop+A_Db()*Vbtm
end

function ConvertnDToVt(n,D) // Input n and D in units of 10^12/cm^2 and V/nm 
	variable n,D
	nvar n_offset
	return B_tn()*(n + n_offset)+B_tD()*D  //Returned Vtop is in unit of mV. e.g. '1000'->1V
end

function ConvertnDToVb(n,D)
	variable n,D
	nvar n_offset
	return B_bn()*(n + n_offset)+B_bD()*D  //Returned Vbtm is in unit of mV. e.g. '1000'->1V
end

function ConvertVtDtoVb(Vtop,D)
	variable Vtop,D
	return (D-A_Dt()*Vtop)/A_Db()
end

function ConvertVtntoVb(Vtop,n)
	variable Vtop,n
	nvar n_offset
	return ((n + n_offset)-A_nt()*Vtop)/A_nb()
end

////////////////
//Scan n and D//
////////////////
function Scan_n(instrIDx,instrIDy,fixedD,startn,finn,numptsn,delayn,rampraten, [y_label, comments, nosave]) //Units: mV


	variable instrIDx,instrIDy,fixedD,startn,finn,numptsn,delayn,rampraten,nosave
	//variable instrIDx, startx, finx, numpts, delay, rampratebothxy, instrIDy, starty, finy, nosave
	string y_label, comments
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	//y_label = selectstring(paramisdefault(y_label), y_label, "R (Ω)")
		
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, \
				 instrIDx=instrIDx, \
				 startx=startn, \
				 finx=finn, \
				 numptsx=numptsn, \
				 delayx=delayn, \
				 rampratex=rampraten,\
				 instrIDy=instrIDy, \
				 starty=ConvertnDToVb(startn,fixedD), \
				 finy=ConvertnDToVb(finn,fixedD), \
				 numptsy=numptsn, \
				 delayy=delayn, \
				 rampratey=rampraten,\
				 y_label=y_label, \
				 comments=comments)

	// Check software limits and ramprate limits
	// PreScanChecksKeithley(S)  
	S.is2d=0
	// Ramp to start without checks because checked above
	rampK2400Voltage(S.instrIDx, ConvertnDToVt(startn,fixedD))
	rampK2400Voltage(S.instrIDy, S.starty)
	
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpointx, setpointy
	do
		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))  //the 2nd Keithley, y corresponds to i
		setpointx =ConvertnDToVt(startn,fixedD) + (j*(ConvertnDToVt(finn,fixedD)-ConvertnDToVt(startn,fixedD))/(S.numptsx-1))  //the 1st Keithley, x corresponds to j
		rampK2400Voltage(S.instrIDy, setpointy, ramprate=S.rampratey)
		rampK2400Voltage(S.instrIDx, setpointx, ramprate=S.rampratex) // change to set voltage instead 
//		setK2400Voltage(S.instrIDy, setpointy)
//		setK2400Voltage(S.instrIDx, setpointx)
		
		sc_sleep(S.delayy)
		sc_sleep(S.delayx)
		RecordValues(S, i, j)
		i+=1
		j+=1
	while (i<S.numptsy&&j<S.numptsx)

	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end


function Scan_D(instrIDx,instrIDy,fixedn,startD,finD,numptsD,delayD,ramprateD, [y_label, comments, nosave]) //Units: mV


	variable instrIDx,instrIDy,fixedn,startD,finD,numptsD,delayD,ramprateD,nosave
	//variable instrIDx, startx, finx, numpts, delay, rampratebothxy, instrIDy, starty, finy, nosave
	string y_label, comments

	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	y_label = selectstring(paramisdefault(y_label), y_label, "")
		
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, \
				 instrIDx=instrIDx, \
				 startx=startD, \
				 finx=finD, \
				 numptsx=numptsD, \
				 delayx=delayD, \
				 rampratex=ramprateD, \
				 instrIDy=instrIDy, \
				 starty=convertnDToVb(fixedn, startD), \
				 finy=convertnDToVb(fixedn, finD), \
				 numptsy=numptsD, \
				 delayy=delayD, \
				 rampratey=ramprateD, \
				 y_label=y_label, \
				 x_label = "D field", \
				 comments=comments)

	// Check software limits and ramprate limits
	// PreScanChecksKeithley(S)  
	S.is2d=0
	// Ramp to start without checks because checked above
	rampK2400Voltage(S.instrIDx, convertnDToVt(fixedn, startD))
	rampK2400Voltage(S.instrIDy, S.starty)	
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpointx, setpointy
	do
		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))  //the 2nd Keithley, y corresponds to i
		setpointx = convertnDToVt(fixedn, startD) + (j*(convertnDToVt(fixedn, finD)-convertnDToVt(fixedn, startD))/(S.numptsx-1))  //the 1st Keithley, x corresponds to j

//		rampK2400Voltage(S.instrIDy, setpointy, ramprate=S.rampratey)
//		rampK2400Voltage(S.instrIDx, setpointx, ramprate=S.rampratex)
		
		setK2400Voltage(S.instrIDy, setpointy)
		setK2400Voltage(S.instrIDx, setpointx)
		
		sc_sleep(S.delayy)
		sc_sleep(S.delayx)
		RecordValues(S, i, j)
		i+=1
		j+=1
	while (i<S.numptsy&&j<S.numptsx)
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end


//////////////////////
//2D "n&D map" scans//
//////////////////////

//'Set' D at D_0, D_1, D_2,..., and do an n scan at each D value
function Scan2K2400nANDd2D(keithleyIDtop,keithleyIDbtm,startn, finn, numptsn, delayn, rampraten, startD,finD,numptsD,delayD,ramprateD,[ y_label, comments, nosave]) //Units: mV
	variable keithleyIDtop,keithleyIDbtm,startn, finn, numptsn, delayn, rampraten, startD,finD,numptsD,delayD,ramprateD,nosave
	string y_label, comments
	
	//Two column vectors, Transpose(n,D) and Transpose(V_top,V_btm) can be converted to each other by a matrix A and its inverse B
	//Specifically, n=A_nt*V_top+A_nb*V_btm and D=A_Dt*V_top+A_Db*V_btm. V_top=B_tn*n+B_tD*D and V_btm=B_bn*n+B_bD*D
	//For our current device, the values of these convertion matrix elements are as below:
	variable Vtgn=B_tn()
	variable VtgD=B_tD() 
	variable Vbgn=B_bn()
	variable VbgD=B_bD()
	
	//Convert the input-from-keyboard start/finish carrier density n and fixed D to start/finish V_top/V_btm 
	//variable startTop,startBtm,FinTop,FinBtm
	variable startTop=convertnDToVt(startn, startD)
	variable startBtm=convertnDToVb(startn, startD)
	variable finTop=convertnDToVt(finn, finD)
	variable finBtm=convertnDToVb(finn, finD)
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	//y_label = selectstring(paramisdefault(y_label), y_label, "Field /mT")

	
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=keithleyIDtop, startx=startn, finx=finn, numptsx=numptsn, delayx=delayn, rampratex=rampraten, \
							instrIDy=keithleyIDbtm, starty=startD, finy=finD, numptsy=numptsD, delayy=delayD, rampratey=ramprateD, \
	 						y_label=y_label, comments=comments)
	 						
	 						
	//Security Check of using 'setK2400Voltage' instead of 'ramp'
	variable KeithleyStepThreshold=40   //Never use 'setK2400Voltage' to make a gate voltage change bigger than this!!!
	variable absDeltaVtop=abs(Vtgn*(S.finx-S.startx)/(S.numptsx-1))
	variable absDeltaVbtm=abs(Vbgn*(S.finx-S.startx)/(S.numptsx-1))
	if(absDeltaVtop>KeithleyStepThreshold||absDeltaVbtm>KeithleyStepThreshold)
		print "You will kill the device!!!"
		return -1
	endif

	// Check software limits and ramprate limits
	// PreScanChecksKeithley(S, x_only=1)  
	
	// Ramp to start without checks because checked above
	//rampK2400Voltage(S.instrIDx, startx, ramprate=S.rampratex)
	rampK2400Voltage(keithleyIDtop, startTop, ramprate=rampraten)
	rampK2400Voltage(keithleyIDbtm, startBtm, ramprate=ramprateD)

		
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpointn, setpointD,setpointTop,setpointBtm
	do
		setpointn = S.startx
		setpointD = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))
		
		setpointTop=convertnDToVt(setpointn, setpointD)
		setpointBtm=convertnDToVb(setpointn, setpointD)
		rampK2400Voltage(keithleyIDtop, setpointTop, ramprate=rampraten)
		rampK2400Voltage(keithleyIDbtm, setpointBtm, ramprate=ramprateD)
		sc_sleep(S.delayy)
		j=0
		do
			setpointn = S.startx + (j*(S.finx-S.startx)/(S.numptsx-1))
			setpointTop=convertnDToVt(setpointn, setpointD)
			setpointBtm=convertnDToVb(setpointn, setpointD)
			setK2400Voltage(keithleyIDtop, setpointTop)
			setK2400Voltage(keithleyIDbtm, setpointBtm)
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
			j+=1
		while (j<S.numptsx)
	i+=1
	while (i<S.numptsy)
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end


//'Set' n at n_0, n_1, n_2,..., and do a D scan at each n value 
function Scan2K2400dANDn2D(keithleyIDtop,keithleyIDbtm,startn, finn, numptsn, delayn, rampraten, startD,finD,numptsD,delayD,ramprateD,[ y_label, comments, nosave]) //Units: mV
	variable keithleyIDtop,keithleyIDbtm,startn, finn, numptsn, delayn, rampraten, startD,finD,numptsD,delayD,ramprateD,nosave
	string y_label, comments
	
	nvar n_offset 
	startn = startn+n_offset
	finn = finn + n_offset
	
	//Two column vectors, Transpose(n,D) and Transpose(V_top,V_btm) can be converted to each other by a matrix A and its inverse B
	//Specifically, n=A_nt*V_top+A_nb*V_btm and D=A_Dt*V_top+A_Db*V_btm. V_top=B_tn*n+B_tD*D and V_btm=B_bn*n+B_bD*D
	//For our current device, the values of these convertion matrix elements are as below:
	variable Vtgn=B_tn()
	variable VtgD=B_tD() 
	variable Vbgn=B_bn()
	variable VbgD=B_bD()
	//Convert the input-from-keyboard start/finish carrier density n and fixed D to start/finish V_top/V_btm 
	//variable startTop,startBtm,FinTop,FinBtm
	variable startTop=convertnDToVt(startn, startD)
	variable startBtm=convertnDToVb(startn, startD)
	variable finTop=convertnDToVt(finn, finD)
	variable finBtm=convertnDToVb(finn, finD)
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	//y_label = selectstring(paramisdefault(y_label), y_label, "Field /mT")

	
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=keithleyIDtop, startx=startn, finx=finn, numptsx=numptsn, delayx=delayn, rampratex=rampraten, \
							instrIDy=keithleyIDbtm, starty=startD, finy=finD, numptsy=numptsD, delayy=delayD, rampratey=ramprateD, \
	 						y_label=y_label, comments=comments)
	 						
	 						
	//Security Check of using 'setK2400Voltage' instead of 'ramp'
	variable KeithleyStepThreshold=40   //Never use 'setK2400Voltage' to make a gate voltage change bigger than this!!!
	variable absDeltaVtop=abs(Vtgn*(S.finx-S.startx)/(S.numptsx-1))
	variable absDeltaVbtm=abs(Vbgn*(S.finx-S.startx)/(S.numptsx-1))
	if(absDeltaVtop>KeithleyStepThreshold||absDeltaVbtm>KeithleyStepThreshold)
		print "You will kill the device!!!"
		return -1
	endif

	// Check software limits and ramprate limits
	// PreScanChecksKeithley(S, x_only=1)  
	
	// Ramp to start without checks because checked above
	//rampK2400Voltage(S.instrIDx, startx, ramprate=S.rampratex)
	rampK2400Voltage(keithleyIDtop, startTop, ramprate=rampraten)
	rampK2400Voltage(keithleyIDbtm, startBtm, ramprate=ramprateD)

		
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpointn, setpointD,setpointTop,setpointBtm
	do
		setpointD = S.starty
		setpointn = S.startx + (j*(S.finx-S.startx)/(S.numptsx-1))

		setpointTop=convertnDToVt(setpointn, setpointD)
		setpointBtm=convertnDToVb(setpointn, setpointD)
		rampK2400Voltage(keithleyIDtop, setpointTop, ramprate=rampraten)
		rampK2400Voltage(keithleyIDbtm, setpointBtm, ramprate=ramprateD)
		sc_sleep(S.delayy)
		i=0
		do
			setpointD = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))
			setpointTop=convertnDToVt(setpointn, setpointD)
			setpointBtm=convertnDToVb(setpointn, setpointD)
			setK2400Voltage(keithleyIDtop, setpointTop)
			setK2400Voltage(keithleyIDbtm, setpointBtm)
			sc_sleep(S.delayx)
			RecordValues(S, i,j)
			i+=1
		while (i<S.numptsy)
	j+=1
	while (j<S.numptsx)
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end

////////////////
//2D B-n scans//
////////////////
function Scan_field_n_2D(keithleyIDtop,keithleyIDbtm,fixedD,startn, finn, numptsn, delayn, rampraten, magnetID, starty, finy, numptsy, delayy, [rampratey, y_label, comments, nosave]) //Units: mV


	variable keithleyIDtop,keithleyIDbtm,fixedD,startn, finn, numptsn, delayn, rampraten, magnetID, starty, finy, numptsy, delayy, rampratey, nosave
	string y_label, comments
	
	nvar n_offset 
	startn = startn+n_offset
	finn = finn + n_offset
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	//sprintf x_label,"n (cm\S-2\M)"
	y_label = selectstring(paramisdefault(y_label), y_label, "B\B⊥\M (mT)")

	//Two column vectors, Transpose(n,D) and Transpose(V_top,V_btm) can be converted to each other by a matrix A and its inverse B
	//Specifically, n=A_nt*V_top+A_nb*V_btm and D=A_Dt*V_top+A_Db*V_btm. V_top=B_tn*n+B_tD*D and V_btm=B_bn*n+B_bD*D
	//For our current device, the values of these convertion matrix elements are as below:	
	variable Vtgn=B_tn()
	variable VtgD=B_tD() 
	variable Vbgn=B_bn()
	variable VbgD=B_bD()
	
	
	//Convert the input-from-keyboard start/finish carrier density n and fixed D to start/finish V_top/V_btm 
	//variable startTop,startBtm,FinTop,FinBtm
	variable startTop=convertnDToVt(startn, fixedD)
	variable startBtm=convertnDToVb(startn, fixedD)
	variable finTop=convertnDToVt(finn, fixedD)
	variable finBtm=convertnDToVb(finn, fixedD)
	
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=keithleyIDtop, startx=startn, finx=finn, numptsx=numptsn, delayx=delayn, rampratex=rampraten, \
							instrIDy=magnetID, starty=starty, finy=finy, numptsy=numptsy, delayy=delayy, rampratey=rampratey, \
	 						y_label=y_label, comments=comments)

	// Check software limits and ramprate limits
	// PreScanChecksKeithley(S, x_only=1)  
	// PreScanChecksMagnet(S, y_only=1)
	
	//Security Check of using 'setK2400Voltage' instead of 'ramp'
	variable KeithleyStepThreshold=40   //Never use 'setK2400Voltage' to make a gate voltage change bigger than this!!!
	variable absDeltaVtop=abs(Vtgn*(S.finx-S.startx)/(S.numptsx-1))
	variable absDeltaVbtm=abs(Vbgn*(S.finx-S.startx)/(S.numptsx-1))
	if(absDeltaVtop>KeithleyStepThreshold||absDeltaVbtm>KeithleyStepThreshold)
		print "You will kill the device!!!"
		return -1
	endif

	
	// Ramp to start without checks because checked above
	//rampK2400Voltage(S.instrIDx, startx, ramprate=S.rampratex)

	rampK2400Voltage(keithleyIDtop, startTop, ramprate=S.rampratex)
	rampK2400Voltage(keithleyIDbtm, startBtm, ramprate=S.rampratex)
	
	if (!paramIsDefault(rampratey))
		setLS625rate(magnetID,rampratey)
	endif
	setlS625fieldWait(S.instrIDy, starty )
	
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpointx, setpointy,setpointTop,setpointBtm
	do
		setpointx = S.startx		
		setpointTop=convertnDToVt(setpointx, fixedD)
		setpointBtm=convertnDToVb(setpointx, fixedD)
		
		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))
		setlS625fieldWait(S.instrIDy, setpointy)
		rampK2400Voltage(keithleyIDtop, setpointTop, ramprate=S.rampratex)
		rampK2400Voltage(keithleyIDbtm, setpointBtm, ramprate=S.rampratex)
		sc_sleep(S.delayy)
		j=0
		do
			setpointx = S.startx + (j*(S.finx-S.startx)/(S.numptsx-1))
			setpointTop=convertnDToVt(setpointx, fixedD)
			setpointBtm=convertnDToVb(setpointx, fixedD)
		
			setK2400Voltage(keithleyIDtop, setpointTop)
			setK2400Voltage(keithleyIDbtm, setpointBtm)
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
			j+=1
		while (j<S.numptsx)
	i+=1
	while (i<S.numptsy)
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end

function Scan_VECfield_n_2D(keithleyIDtop,keithleyIDbtm,fixedD,startn, finn, numptsn, delayn, rampraten, magnetIDX,magnetIDY,magnetIDZ, BTranslateX, BTranslateY, BTranslateZ, thetafromY, alphafromX, startB, finB, numptsB, delayB, [ramprateB, y_label, comments, nosave]) //Units: mV
	//‘thetafromY' is the polar angle deviated from y-direction. Perpendicular: thetafromY=0deg In-Plane: thetafromY=90deg
	//'alphafromX' is the azimuth angle deviated from x-direction. When thetafromY=90deg, B_x: alphafromX=0 B_z:alphafromX=90deg
	//The 'magnitude' of \vec(B) can be negative---(-B0,theta,alpha)<==>(B0,pi-theta,alpha+pi) in para space  
	variable keithleyIDtop,keithleyIDbtm,fixedD,startn, finn, numptsn, delayn, rampraten, magnetIDX,magnetIDY,magnetIDZ, BTranslateX, BTranslateY, BTranslateZ, thetafromY, alphafromX, startB, finB, numptsB, delayB,ramprateB,nosave
	string y_label, comments
	
	nvar n_offset 
	startn = startn+n_offset
	finn = finn + n_offset
	
	//Two column vectors, Transpose(n,D) and Transpose(V_top,V_btm) can be converted to each other by a matrix A and its inverse B
	//Specifically, n=A_nt*V_top+A_nb*V_btm and D=A_Dt*V_top+A_Db*V_btm. V_top=B_tn*n+B_tD*D and V_btm=B_bn*n+B_bD*D
	//For our current device, the values of these convertion matrix elements are as below:	
	variable Vtgn=B_tn()
	variable VtgD=B_tD() 
	variable Vbgn=B_bn()
	variable VbgD=B_bD()

	//Convert the input-from-keyboard start/finish carrier density n and fixed D to start/finish V_top/V_btm 
	//variable startTop,startBtm,FinTop,FinBtm
	variable startTop=convertnDToVt(startn, fixedD)
	variable startBtm=convertnDToVb(startn, fixedD)
	variable finTop=convertnDToVt(finn, fixedD)
	variable finBtm=convertnDToVb(finn, fixedD)
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	//y_label = selectstring(paramisdefault(y_label), y_label, "Field /mT")

	
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=keithleyIDtop, startx=startn, finx=finn, numptsx=numptsn, delayx=delayn, rampratex=rampraten, \
							instrIDy=magnetIDY, starty=startB, finy=finB, numptsy=numptsB, delayy=delayB, rampratey=ramprateB, \
	 						y_label=y_label, comments=comments)

	// Check software limits and ramprate limits
	// PreScanChecksKeithley(S, x_only=1)  
	// PreScanChecksMagnet(S, y_only=1)
	
	//Security Check of using 'setK2400Voltage' instead of 'ramp'
	variable KeithleyStepThreshold=40   //Never use 'setK2400Voltage' to make a gate voltage change bigger than this!!!
	variable absDeltaVtop=abs(Vtgn*(S.finx-S.startx)/(S.numptsx-1))
	variable absDeltaVbtm=abs(Vbgn*(S.finx-S.startx)/(S.numptsx-1))
	if(absDeltaVtop>KeithleyStepThreshold||absDeltaVbtm>KeithleyStepThreshold)
		print "You will kill the device!!!"
		return -1
	endif



	// Ramp to start without checks because checked above
	//rampK2400Voltage(S.instrIDx, startx, ramprate=S.rampratex)
	rampK2400Voltage(keithleyIDtop, startTop, ramprate=S.rampratex)
	rampK2400Voltage(keithleyIDbtm, startBtm, ramprate=S.rampratex)

	if (!paramIsDefault(ramprateB))  //If inputting a non-default ramprateB, then set all magnets' rate to it. 
		setLS625rate(magnetIDX,ramprateB)
		setLS625rate(magnetIDY,ramprateB)
		setLS625rate(magnetIDZ,ramprateB)
	endif
	setlS625fieldWait(magnetIDX, BTranslateX+startB*sin(thetafromY*pi/180)*cos(alphafromX*pi/180))   //BTranslateX/Y/Z are the results of calibrations.
	setlS625fieldWait(magnetIDY, BTranslateY+startB*cos(thetafromY*pi/180))
	setlS625fieldWait(magnetIDZ, BTranslateZ+startB*sin(thetafromY*pi/180)*sin(alphafromX*pi/180))
	
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpointx, setpointB,setpointTop,setpointBtm
	do
		setpointx = S.startx
		setpointTop=convertnDToVt(setpointx, fixedD)
		setpointBtm=convertnDToVb(setpointx, fixedD)
		setpointB = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))
		setlS625fieldWait(magnetIDX, BTranslateX+setpointB*sin(thetafromY*pi/180)*cos(alphafromX*pi/180))
		setlS625fieldWait(magnetIDY, BTranslateY+setpointB*cos(thetafromY*pi/180))
		setlS625fieldWait(magnetIDZ, BTranslateZ+setpointB*sin(thetafromY*pi/180)*sin(alphafromX*pi/180))
		rampK2400Voltage(keithleyIDtop, setpointTop, ramprate=S.rampratex)
		rampK2400Voltage(keithleyIDbtm, setpointBtm, ramprate=S.rampratex)
		sc_sleep(S.delayy)
		j=0
		do
			setpointx = S.startx + (j*(S.finx-S.startx)/(S.numptsx-1))
			setpointTop=convertnDToVt(setpointx, fixedD)
			setpointBtm=convertnDToVb(setpointx, fixedD)
			setK2400Voltage(keithleyIDtop, setpointTop)
			setK2400Voltage(keithleyIDbtm, setpointBtm)
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
			j+=1
		while (j<S.numptsx)
	i+=1
	while (i<S.numptsy)
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		 dowindow /k SweepControl
	endif
end
