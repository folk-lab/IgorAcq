#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later


//////////////////////////////////////////
//Convertion b/w gate voltages and (n,D)//
//////////////////////////////////////////

function ConvertVtVbTon(Vtop,Vbtm)  //Input Vtop and vbtm are in units of mV. e.g. '1000'->1V
variable Vtop,Vbtm
variable A_nt=0.7901785714285712
variable A_nb=0.5267857142857142
variable n=(A_nt*Vtop+A_nb*Vbtm)/1000
return n
end

function ConvertVtVbToD(Vtop,Vbtm)  //Input Vtop and vbtm are in units of mV. e.g. '1000'->1V
variable Vtop,Vbtm
variable A_Dt=-0.07142857142857142
variable A_Db=0.04761904761904762
variable D=(A_Dt*Vtop+A_Db*Vbtm)/1000
return D
end

function ConvertnDToVt(n,D)
variable n,D
variable B_tn=0.6327683615819211
variable B_tD=-7.000000000000001
variable VTop=(B_tn*n+B_tD*D)*1000  //Returned Vtop is in unit of mV. e.g. '1000'->1V
return VTop
end

function ConvertnDToVb(n,D)
variable n,D
variable B_bn=0.9491525423728815
variable B_bD=10.50000000000000
variable VBtm=(B_bn*n+B_bD*D)*1000  //Returned Vbtm is in unit of mV. e.g. '1000'->1V
return Vbtm
end

function ConvertVtDtoVb(Vtop,D)
variable Vtop,D
variable A_Dt=-0.07142857142857142/1000
variable A_Db=0.04761904761904762/1000
variable Vbtm=(D-A_Dt*Vtop)/A_Db
return Vbtm
end

function ConvertVtntoVb(Vtop,n)
variable Vtop,n
variable A_nt=0.7901785714285712/1000
variable A_nb=0.5267857142857142/1000
variable Vbtm=(n-A_nt*Vtop)/A_nb
return Vbtm
end

////////////////
//Scan n and D//
////////////////
function Scan_n(instrIDx,instrIDy,fixedD,startn,finn,numptsn,delayn,rampraten, [y_label, comments, nosave]) //Units: mV


	variable instrIDx,instrIDy,fixedD,startn,finn,numptsn,delayn,rampraten,nosave
	//variable instrIDx, startx, finx, numpts, delay, rampratebothxy, instrIDy, starty, finy, nosave
	string y_label, comments
////	abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	//y_label = selectstring(paramisdefault(y_label), y_label, "R (Ω)")

	//variable Vtgn,VtgD,Vbgn,VbgD //The matrix elements to  (n,D) into (V_top,V_bottom)
		variable Vtgn=0.6327683615819211*1000
		variable VtgD=-7.000000000000001*1000 //Do not forget the "-" here
		variable Vbgn=0.9491525423728815*1000
		variable VbgD=10.50000000000000*1000
		
		
		
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=instrIDx, startx=startn, finx=finn, numptsx=numptsn, delayx=delayn, rampratex=rampraten, \
							instrIDy=instrIDy, starty=Vbgn*startn+VbgD*fixedD, finy=Vbgn*finn+VbgD*fixedD, numptsy=numptsn, delayy=delayn, rampratey=rampraten, \
	 						y_label=y_label, comments=comments)

	// Check software limits and ramprate limits
	// PreScanChecksKeithley(S)  
	S.is2d=0
	// Ramp to start without checks because checked above
	rampK2400Voltage(S.instrIDx, Vtgn*startn+VtgD*fixedD)
	rampK2400Voltage(S.instrIDy, S.starty)
	
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpointx, setpointy
	do
		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))  //the 2nd Keithley, y corresponds to i
		setpointx = Vtgn*startn+VtgD*fixedD + (j*(Vtgn*finn+VtgD*fixedD-Vtgn*startn-VtgD*fixedD)/(S.numptsx-1))  //the 1st Keithley, x corresponds to j
		rampK2400Voltage(S.instrIDy, setpointy, ramprate=S.rampratey)
		rampK2400Voltage(S.instrIDx, setpointx, ramprate=S.rampratex)
		sc_sleep(S.delayy)
		sc_sleep(S.delayx)
		RecordValues(S, i, j)
		i+=1
		j+=1
	while (i<S.numptsy&&j<S.numptsx)
//	do
//		setpointx = S.startx
//		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))
//		rampK2400Voltage(S.instrIDy, setpointy, ramprate=S.rampratey)
//		rampK2400Voltage(S.instrIDx, setpointx, ramprate=S.rampratex)
//
//		sc_sleep(S.delayy)
//		j=0
//		do
//			setpointx = S.startx + (j*(S.finx-S.startx)/(S.numptsx-1))
//			rampK2400Voltage(S.instrIDx, setpointx, ramprate=S.rampratex)
//			sc_sleep(S.delayx)
//			RecordValues(S, i, j)
//			j+=1
//		while (j<S.numptsx)
//	i+=1
//	while (i<S.numptsy)
	
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
////	abort "WARNING: This scan has not been tested with an instrument connected. Remove this abort and test the behavior of the scan before running on a device!"	
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	//y_label = selectstring(paramisdefault(y_label), y_label, "R (Ω)")

	//variable Vtgn,VtgD,Vbgn,VbgD //The matrix elements to  (n,D) into (V_top,V_bottom)
		variable Vtgn=0.6327683615819211*1000
		variable VtgD=-7.000000000000001*1000 //Do not forget the "-" here
		variable Vbgn=0.9491525423728815*1000
		variable VbgD=10.50000000000000*1000
		
		
		
	// Initialize ScanVars
	struct ScanVars S
	initScanVars(S, instrIDx=instrIDx, startx=startD, finx=finD, numptsx=numptsD, delayx=delayD, rampratex=ramprateD, \
							instrIDy=instrIDy, starty=Vbgn*fixedn+VbgD*startD, finy=Vbgn*fixedn+VbgD*finD, numptsy=numptsD, delayy=delayD, rampratey=ramprateD, \
	 						y_label=y_label, comments=comments)

	// Check software limits and ramprate limits
	// PreScanChecksKeithley(S)  
	S.is2d=0
	// Ramp to start without checks because checked above
	rampK2400Voltage(S.instrIDx, Vtgn*fixedn+VtgD*startD)
	rampK2400Voltage(S.instrIDy, S.starty)	
	// Let gates settle 
	sc_sleep(S.delayy*5)
	
	// Make waves and graphs etc
	initializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpointx, setpointy
	do
		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))  //the 2nd Keithley, y corresponds to i
		setpointx = Vtgn*fixedn+VtgD*startD + (j*(Vtgn*fixedn+VtgD*finD-Vtgn*fixedn-VtgD*startD)/(S.numptsx-1))  //the 1st Keithley, x corresponds to j

		rampK2400Voltage(S.instrIDy, setpointy, ramprate=S.rampratey)
		rampK2400Voltage(S.instrIDx, setpointx, ramprate=S.rampratex)
		sc_sleep(S.delayy)
		sc_sleep(S.delayx)
		RecordValues(S, i, j)
		i+=1
		j+=1
	while (i<S.numptsy&&j<S.numptsx)
//	do
//		setpointx = S.startx
//		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))
//		rampK2400Voltage(S.instrIDy, setpointy, ramprate=S.rampratey)
//		rampK2400Voltage(S.instrIDx, setpointx, ramprate=S.rampratex)
//
//		sc_sleep(S.delayy)
//		j=0
//		do
//			setpointx = S.startx + (j*(S.finx-S.startx)/(S.numptsx-1))
//			rampK2400Voltage(S.instrIDx, setpointx, ramprate=S.rampratex)
//			sc_sleep(S.delayx)
//			RecordValues(S, i, j)
//			j+=1
//		while (j<S.numptsx)
//	i+=1
//	while (i<S.numptsy)
	
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
	variable A_nt=0.7901785714285712/1000
	variable A_nb=0.5267857142857142/1000
	variable A_Dt=-0.07142857142857142/1000
	variable A_Db=0.04761904761904762/1000
	variable B_tn=0.6327683615819211*1000
	variable B_tD=-7.000000000000001*1000
	variable B_bn=0.9491525423728815*1000
	variable B_bD=10.50000000000000*1000
	//Convert the input-from-keyboard start/finish carrier density n and fixed D to start/finish V_top/V_btm 
	//variable startTop,startBtm,FinTop,FinBtm
	variable startTop=B_tn*startn+B_tD*startD
	variable startBtm=B_bn*startn+B_bD*startD
	variable finTop=B_tn*finn+B_tD*finD
	variable finBtm=B_bn*finn+B_bD*finD
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
	variable absDeltaVtop=abs(B_tn*(S.finx-S.startx)/(S.numptsx-1))
	variable absDeltaVbtm=abs(B_bn*(S.finx-S.startx)/(S.numptsx-1))
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
		setpointTop=B_tn*setpointn+B_tD*setpointD
		setpointBtm=B_bn*setpointn+B_bD*setpointD
		rampK2400Voltage(keithleyIDtop, setpointTop, ramprate=rampraten)
		rampK2400Voltage(keithleyIDbtm, setpointBtm, ramprate=ramprateD)
		sc_sleep(S.delayy)
		j=0
		do
			setpointn = S.startx + (j*(S.finx-S.startx)/(S.numptsx-1))
			setpointTop=B_tn*setpointn+B_tD*setpointD
			setpointBtm=B_bn*setpointn+B_bD*setpointD
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
	//Two column vectors, Transpose(n,D) and Transpose(V_top,V_btm) can be converted to each other by a matrix A and its inverse B
	//Specifically, n=A_nt*V_top+A_nb*V_btm and D=A_Dt*V_top+A_Db*V_btm. V_top=B_tn*n+B_tD*D and V_btm=B_bn*n+B_bD*D
	//For our current device, the values of these convertion matrix elements are as below:
	variable A_nt=0.7901785714285712/1000
	variable A_nb=0.5267857142857142/1000
	variable A_Dt=-0.07142857142857142/1000
	variable A_Db=0.04761904761904762/1000
	variable B_tn=0.6327683615819211*1000
	variable B_tD=-7.000000000000001*1000
	variable B_bn=0.9491525423728815*1000
	variable B_bD=10.50000000000000*1000
	//Convert the input-from-keyboard start/finish carrier density n and fixed D to start/finish V_top/V_btm 
	//variable startTop,startBtm,FinTop,FinBtm
	variable startTop=B_tn*startn+B_tD*startD
	variable startBtm=B_bn*startn+B_bD*startD
	variable finTop=B_tn*finn+B_tD*finD
	variable finBtm=B_bn*finn+B_bD*finD
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
	variable absDeltaVtop=abs(B_tn*(S.finx-S.startx)/(S.numptsx-1))
	variable absDeltaVbtm=abs(B_bn*(S.finx-S.startx)/(S.numptsx-1))
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
		setpointTop=B_tn*setpointn+B_tD*setpointD
		setpointBtm=B_bn*setpointn+B_bD*setpointD
		rampK2400Voltage(keithleyIDtop, setpointTop, ramprate=rampraten)
		rampK2400Voltage(keithleyIDbtm, setpointBtm, ramprate=ramprateD)
		sc_sleep(S.delayy)
		i=0
		do
			setpointD = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))
			setpointTop=B_tn*setpointn+B_tD*setpointD
			setpointBtm=B_bn*setpointn+B_bD*setpointD
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
	
	// Reconnect instruments
	sc_openinstrconnections(0)
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "") 
	//sprintf x_label,"n (cm\S-2\M)"
	y_label = selectstring(paramisdefault(y_label), y_label, "B\B⊥\M (mT)")

	//Two column vectors, Transpose(n,D) and Transpose(V_top,V_btm) can be converted to each other by a matrix A and its inverse B
	//Specifically, n=A_nt*V_top+A_nb*V_btm and D=A_Dt*V_top+A_Db*V_btm. V_top=B_tn*n+B_tD*D and V_btm=B_bn*n+B_bD*D
	//For our current device, the values of these convertion matrix elements are as below:
	variable A_nt=0.7901785714285712/1000
	variable A_nb=0.5267857142857142/1000
	variable A_Dt=-0.07142857142857142/1000
	variable A_Db=0.04761904761904762/1000
	variable B_tn=0.6327683615819211*1000
	variable B_tD=-7.000000000000001*1000
	variable B_bn=0.9491525423728815*1000
	variable B_bD=10.50000000000000*1000
	//Convert the input-from-keyboard start/finish carrier density n and fixed D to start/finish V_top/V_btm 
	//variable startTop,startBtm,FinTop,FinBtm
	variable startTop=B_tn*startn+B_tD*fixedD
	variable startBtm=B_bn*startn+B_bD*fixedD
	variable finTop=B_tn*finn+B_tD*fixedD
	variable finBtm=B_bn*finn+B_bD*fixedD
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
	variable absDeltaVtop=abs(B_tn*(S.finx-S.startx)/(S.numptsx-1))
	variable absDeltaVbtm=abs(B_bn*(S.finx-S.startx)/(S.numptsx-1))
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
		setpointTop=B_tn*setpointx+B_tD*fixedD
		setpointBtm=B_bn*setpointx+B_bD*fixedD
		setpointy = S.starty + (i*(S.finy-S.starty)/(S.numptsy-1))
		setlS625fieldWait(S.instrIDy, setpointy)
		rampK2400Voltage(keithleyIDtop, setpointTop, ramprate=S.rampratex)
		rampK2400Voltage(keithleyIDbtm, setpointBtm, ramprate=S.rampratex)
		sc_sleep(S.delayy)
		j=0
		do
			setpointx = S.startx + (j*(S.finx-S.startx)/(S.numptsx-1))
			setpointTop=B_tn*setpointx+B_tD*fixedD
			setpointBtm=B_bn*setpointx+B_bD*fixedD
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
	//Two column vectors, Transpose(n,D) and Transpose(V_top,V_btm) can be converted to each other by a matrix A and its inverse B
	//Specifically, n=A_nt*V_top+A_nb*V_btm and D=A_Dt*V_top+A_Db*V_btm. V_top=B_tn*n+B_tD*D and V_btm=B_bn*n+B_bD*D
	//For our current device, the values of these convertion matrix elements are as below:
	variable A_nt=0.7901785714285712/1000
	variable A_nb=0.5267857142857142/1000
	variable A_Dt=-0.07142857142857142/1000
	variable A_Db=0.04761904761904762/1000
	variable B_tn=0.6327683615819211*1000
	variable B_tD=-7.000000000000001*1000
	variable B_bn=0.9491525423728815*1000
	variable B_bD=10.50000000000000*1000
	//Convert the input-from-keyboard start/finish carrier density n and fixed D to start/finish V_top/V_btm 
	//variable startTop,startBtm,FinTop,FinBtm
	variable startTop=B_tn*startn+B_tD*fixedD
	variable startBtm=B_bn*startn+B_bD*fixedD
	variable finTop=B_tn*finn+B_tD*fixedD
	variable finBtm=B_bn*finn+B_bD*fixedD
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
	variable absDeltaVtop=abs(B_tn*(S.finx-S.startx)/(S.numptsx-1))
	variable absDeltaVbtm=abs(B_bn*(S.finx-S.startx)/(S.numptsx-1))
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
		setpointTop=B_tn*setpointx+B_tD*fixedD
		setpointBtm=B_bn*setpointx+B_bD*fixedD
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
			setpointTop=B_tn*setpointx+B_tD*fixedD
			setpointBtm=B_bn*setpointx+B_bD*fixedD
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
