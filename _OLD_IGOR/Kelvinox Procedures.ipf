#pragma rtGlobals=1		// Use modern global access method.

//************************************************ReadMe First*************************************************************************
// To use this procedure, run initKelvinox() first.

//******************************************* Most useful Routines *******************************************************************
//KelvinoxSetMixChTemp():	Set the temperature of mixing chamber
//KelvinoxGetStatus(): Get current status of the fridge.The information is stored in global variables (see below).


//*******************************************  Other information  **********************************************************************
//Before controlling the fridge, set the fridge to remote mode by calling KelvinoxSetLocal(Value). Vaule 1 = local, 0 = remote.
//Control pumps: KelvinoxSetPump(PumpName, Value). PumpName="He3", "He4", or "Roots". Value 1 = on, 0 = off
//Control valves: KelvinoxSetValve(ValveName, Value). ValveName="V1", "V2", "V1A"....For valves "V6" and "V12A", value means percent open (value 50=50% open). For other valves, value 1 = on, 0 = off
//Set temperature or power: Set according global variables, and then call KelvinoxSetStatus(). To turn off the sorb heater, set both power_sorb and TempControl_Sorb to 0. To turn off the mix ch heater, set MixChRange=0.
//If timeout occurs when trying to get status, press button "C" or run ButtonProc_Kelvinox("clearmem")

// Global variables:
// Temperature: temp_sorb, temp_mix, temp_1K  (sorb, mixing chamber and 1K pot, respectively).
// Power: power_sorb, power_mix, power_still.
// Mix Power Range: MixChRange
// Pressure: Pres_P1, Pres_P2, Pres_G1, Pres_G2, Pres_G3.
// Level of liquid: level_He, level_N2.
// Control status: Local_status, 1=local, 0=remote.

//// updated May 7 2009 (Mark) -- level meter updated, added timestamp. May 14: added 'Lock' feature to prevent accidents
/// updated June 6 2011 (Mark) -- added some error tolerance to KelvinoxGetStatus()


// Which port is the Kelvinox on? Configure here.
Function KelvinoxSetPort()
	execute "VDTOperationsPort2 COM4"
end

Function initKelvinox()
	string cmd
	string /g junkstr
	variable/g show_setpoint=1, Kelvinox_Background=0
	variable/g level_He=nan, level_N2=nan, MixChRange, TempControl_Sorb, TempControl_MixCh
	variable/g temp_sorb, temp_1K, temp_mix, power_mix, power_still, power_sorb, Pres_P1, Pres_P2, Pres_G1, Pres_G2, Pres_G3
	variable/g Local_status, Pump_He3, Pump_He4, Pump_Roots
	variable/g Valve_V1, Valve_V1A, Valve_V2, Valve_V2A, Valve_V3, Valve_V4, Valve_V5, Valve_V4A, Valve_V5A, Valve_V6, Valve_V7,Valve_V8, Valve_V9, Valve_V10, Valve_V11A, Valve_V11B, Valve_V12A, Valve_V12B, Valve_V13A, Valve_V13B, Valve_V14, Valve_NV
	variable/g Valve_V6moving, Valve_NVmoving, Valve_V12Amoving
	string /g KelvinoxTimeStamp
	variable /g KelvinoxDateTime
	variable /g ILM_Active
	variable /g lastNVadjust, lastNVdir
	variable /g KelvinoxDirtyBuffer = 1
	
	KelvinoxSetPort()
	execute "vdt2 baud=9600, stopbits=2, databits=8, parity=0, in=0,  out=0, echo=0, terminalEOL=0,killio"
	Kelvinox_clearbuffer()
	dowindow /k Kelvinox
	execute("Kelvinox()")
	KelvinoxLockSwitch(unlock=0)
	KelvinoxGetStatus()
end

Function TempToSetPoint(setpoint)	//judge whether curr_temp is near setpoint
	variable setpoint
	NVAR temp_mix
	SVAR junkstr
	variable diff
	
	if(setpoint<=750)
		diff=sqrt(setpoint)/2
	else
		diff=sqrt(setpoint)*2
	endif
	
	if(abs(setpoint-temp_mix)<=diff) 
		return 1
	else 
		return 0
	endif
end

/////// Warning: If you press buttons on the IGH while this command is running, you may cause
///////                it to abort early, possibly with the heater at max power.
Function KelvinoxSetMixChTemp(temp)	//temp in unit of mK
// NOTE: only work for temp<800mK and well functioning fridge.
	variable temp
	variable power, roots,Dtemp,i=0,tt=0
	NVAR temp_mix, power_mix
	SVAR junkstr
	
	KelvinoxSetLocal(0)	//set remote
	if(temp<=150)
		KelvinoxSetPump("Roots", 1)	//low temperature, turn on Roots pump
		roots=1
	else
		KelvinoxSetPump("Roots", 0)	//high temperature, turn off Roots pump
		roots=0
	endif
	Kelvinox_ClearBuffer()
	Kelvinox_command("R32")			//Mix chamber temp
	temp_mix=str2num(junkstr[2,7])/10
	Kelvinox_command("A1")		//fixed heater power
	if(1.02*temp<temp_mix)
		Kelvinox_command("M0")	// zero power
		power_mix=0
	elseif(0.98*temp>temp_mix)
		power=CalcPower(temp, roots)
		if(1.5*power<20000)
			power_mix=1.6*power
			SetMixChPower(power_mix)
		else
			power_mix=19990
			SetMixChPower(power_mix)
		endif
	endif
	Dtemp=1.1^(abs(temp-temp_mix)/50-1)*0.1*temp
	do
		KelvinoxSetLocal(0)
		Kelvinox_ClearBuffer()
		Kelvinox_command("R32")			//Mix chamber temp
		temp_mix=str2num(junkstr[2,7])/10	
		DoUpdate
		sleep/s 1
//		if (mod(i,10) ==0)
//			logger()
//		endif
		i+=1
	while(abs(temp-temp_mix)>Dtemp)		// Fast approaching setpoint
	i=0
	//Try to stablize at setpoint
	ApproachSetPoint(temp,roots)
	Dtemp=sqrt(temp)/2
	variable npoint
	if(temp<=500)
		npoint=180
	else
		npoint=480
	endif
	do
		KelvinoxSetLocal(0)				// Make sure the procedure does not lose control of the IGH
		Kelvinox_ClearBuffer()
		Kelvinox_command("R32")			//Mix chamber temp
		temp_mix=str2num(junkstr[2,7])/10
		if(abs(temp-temp_mix)>Dtemp)
			ApproachSetPoint(temp,roots)
		else
			if(TempToSetPoint(temp))
				i+=1
			else
				i=0
			endif
		endif
		DoUpdate
		sleep/s 1
//		if (mod(i,10) ==0)
//			logger()
//		endif
	while(i<npoint)
end

// sets the mixing chamber temperature control
///   Maximum possible temperature is 1900 mK (limitation of bugs in IGH's 3.02 firmware)
// also attempts to set PID values appropriately, but note:
//    APPROPRIATE PID VALUES DEPEND ON THE HEATER RANGE!
// call with temp=0 to turn off the heater.
Function KelvinoxSetMixChTempControl(temp)
	variable temp
	
	if(temp > 1900)
		temp = 1900
		print "temperature requested above 1900 mK, set to 1900 mK instead"
	endif

	kelvinoxsetlocal(0)
	if(temp <= 0)
		Kelvinox_command("A0")
		return 0
	endif

	
	Kelvinox_command("A2")	//temperature control
	Kelvinox_command("T"+num2str(temp*10))
	if(temp<=250)
		Kelvinox_command("i10")
		Kelvinox_command("p15")
	elseif(temp<=500)
		Kelvinox_command("i10")
		Kelvinox_command("p30")
	else
		Kelvinox_command("i30")
		Kelvinox_command("p100")
	endif
end

Function ApproachSetPoint(temp,roots)
	variable temp,roots
	NVAR temp_mix, power_mix
	SVAR junkstr
	variable temp_old=temp_mix, temp_origin=temp_mix, Dtemp,prefactor=2
	Kelvinox_command("A1")		//fixed heater power
	do
		Kelvinox_ClearBuffer()
		Kelvinox_command("R32")			//Mix chamber temp
		temp_mix=str2num(junkstr[2,7])/10	
		if((temp_mix-temp_old)*(temp-temp_mix)<=0)
			if((temp_mix-temp_old)*(temp_mix-temp_origin)<=0)
				prefactor*=1.05
			endif
		endif
		temp_old=temp_mix
		Dtemp=temp-temp_mix
		power_mix=CalcPower(temp+prefactor*Dtemp,roots)
		SetMixChPower(power_mix)
		DoUpdate
		sleep/s 1
	while(abs(temp-temp_mix)>1)
	Kelvinox_command("T"+num2str(temp*10))
	Kelvinox_command("A2")	//temperature control
	if(temp<=250)
		Kelvinox_command("i10")
		Kelvinox_command("p15")
	elseif(temp<=500)
		Kelvinox_command("i10")
		Kelvinox_command("p30")
	else
		Kelvinox_command("i30")
		Kelvinox_command("p100")
	endif
end

Function CleaningDump([low,high])
	variable low, high
// 
	NVAR Pres_G1, Pres_G2, temp_1K
	SVAR junkstr
	variable i,flag=0
	KelvinoxSetPort()
	KelvinoxSetLocal(0)	//set remote
	
	KelvinoxSetValve("V9", 0)
	KelvinoxSetValve("V10", 0)
	KelvinoxGetStatus()
	if(paramisdefault(low))
		low = 150
	endif
	if(paramisdefault(high))
		high = 200
	endif
	do
		do
			sleep /s 1
			doupdate
			Kelvinox_command("R14")
			Pres_G1=str2num(junkstr[3,7])/10
			Kelvinox_command("R15")
			Pres_G2=str2num(junkstr[3,7])/10
			Kelvinox_command("R2")			//1K pot temp
			temp_1K=str2num(junkstr[3,7])/1000
		while(Pres_G2 >= low)
		
		i=0
		KelvinoxSetValve("V10", 1)
		KelvinoxGetStatus()
		do
			sleep/s 0.5
			doupdate
			if(i>600)		// Wait for 5mins
				flag=1	// Dump is empty
				break
			endif
			Kelvinox_command("R14")
			Pres_G1=str2num(junkstr[3,7])/10
			Kelvinox_command("R15")
			Pres_G2=str2num(junkstr[3,7])/10
			Kelvinox_command("R2")			//1K pot temp
			temp_1K=str2num(junkstr[3,7])/1000
			i+=1
		while(Pres_G2 < high)
		KelvinoxSetValve("V10", 0)
		KelvinoxGetStatus()
	while(!flag)
	beep
end

Function CalcPower(temp, roots)
	variable temp,roots
	variable result
	if(roots==1)
		result=0.0148*temp^2+0.789*temp-32.4
	else
		result=0.00348*temp^2+2.87*temp-429
	endif
	if(result<0)
		return 0
	else
		return result
	endif
end

// Power is in microwatt units.
Function SetMixChPower(power)
	variable power
	variable exponent
	NVAR MixChRange
	if(power>0)
		exponent=floor(log(power/2))+2
		Kelvinox_command("E"+num2str(exponent))	//set exponent for mix power range
		Kelvinox_command("M"+num2str(floor(power*10^(4-exponent))))	//set power
	//elseif(power==0)
		//MixChRange=0
		//Kelvinox_command("A0")
	endif
end

// Generic kelvinox command. If communication fails (e.g. user is holding a button down on IGH),
// then timeout occurs after 10 seconds and igor aborts.
Function Kelvinox_command(cmd)
	string cmd
	string cmd2
	svar junkstr
	nvar v_vdt
	nvar KelvinoxDirtyBuffer 
	KelvinoxSetPort()
	execute "vdt2 killio"
	if(KelvinoxDirtyBuffer)
		Kelvinox_ClearBuffer()
	endif
	KelvinoxDirtyBuffer = 1 /// if we fail, buffer is dirty.
	cmd2="VDTwrite2 /o=3 /q \"@5"+cmd+"\\r\""
	execute (cmd2)
	if(v_vdt == 0)
		abort "Failed communication with IGH (write)." 
		junkstr = ""
		return 0
	endif
	cmd2="VDTread2 /o=10 /q junkstr"
	execute (cmd2)
	if(v_vdt == 0)
		abort "Failed communication with IGH (read). Were you holding down a button?" 
		junkstr = ""
		return 0
	endif
	KelvinoxDirtyBuffer = 0 /// success -- buffer is clean.
	return 1
end

/// Quiet Kelvinox command -- if there is an error, this function returns 0. Returns 1 if communication worked.
// timeout is 1 second.
Function Kelvinox_commandQ(cmd)
	string cmd
	string cmd2
	svar junkstr
	nvar v_vdt
	nvar KelvinoxDirtyBuffer 
	KelvinoxSetPort()
	if(KelvinoxDirtyBuffer)
		Kelvinox_ClearBuffer()
	endif
	KelvinoxDirtyBuffer = 1 /// if we fail, buffer is dirty.
	cmd2="VDTwrite2 /o=1 /q \"@5"+cmd+"\\r\""
	execute (cmd2)
	if(v_vdt == 0)
		junkstr = ""
		return 0
	endif
	cmd2="VDTread2 /o=1 /q junkstr"
	execute (cmd2)
	if(v_vdt == 0)
		junkstr = ""
		return 0
	endif
	KelvinoxDirtyBuffer = 0 /// success -- buffer is clean.
	return 1
end	

// Sometimes the reading data is not successful and the data is still left in the buffer of fridge. 
// This will mess up the program, and will even cause the fridge warming up.
// This function reads the buffer repeatly to make sure that all data is read out.
// The final command (attempted read on empty buffer) times out after 0.1s.
Function Kelvinox_clearbuffer()
	string cmd
	svar junkstr
	nvar KelvinoxDirtyBuffer
	nvar v_vdt
	do
		cmd="VDTread2 /O=0.1/Q junkstr"
		execute (cmd)
	while(V_VDT)
	KelvinoxDirtyBuffer = 0
end

/// Command to level meter (ILM)
/// Upon failure, returns false rather than aborting. Timeout is 1 second.
Function ILM_command(cmd)
	string cmd
	string cmd2
	nvar KelvinoxDirtyBuffer
	KelvinoxSetPort()
	if(KelvinoxDirtyBuffer)
		Kelvinox_ClearBuffer()
	endif
	KelvinoxDirtyBuffer = 1 /// if we fail, buffer is dirty.
	cmd2="VDTwrite2 /o=1 \"@6"+cmd+"\\r\""
	execute /q/z cmd2
	nvar v_vdt
	if(v_vdt == 0)
		return 0
	endif
	cmd2="VDTread2 /o=1 junkstr"
	execute /q/z cmd2
	if(v_vdt == 0)
		return 0
	endif
	return 1
	KelvinoxDirtyBuffer = 0 /// success -- buffer is clean.
end

function CanReachILM()
	return ILM_command("V")
end

Function KelvinoxGetStatus()
	SVAR junkstr
	NVAR temp_sorb, temp_1k, temp_mix, power_mix, power_still, power_sorb, Pres_P1, Pres_P2, Pres_G1, Pres_G2, Pres_G3
	NVAR Local_status, Pump_He3, Pump_He4, Pump_Roots, TempControl_Sorb, TempControl_MixCh
	NVAR Valve_V1, Valve_V1A, Valve_V2, Valve_V2A, Valve_V3, Valve_V4, Valve_V5, Valve_V4A, Valve_V5A, Valve_V6, Valve_V7,Valve_V8, Valve_V9, Valve_V10, Valve_V11A, Valve_V11B, Valve_V12A, Valve_V12B, Valve_V13A, Valve_V13B, Valve_V14, Valve_NV
	NVAR Valve_V6moving, Valve_NVmoving, Valve_V12Amoving
	variable statuscode, mixrange, sorbstatus
	
	variable oldlocal_status = local_status
	
	kelvinoxsetport()
	/// While getting data, lock out the front panel.
	if(!kelvinox_commandq("C1"))
		// Okay, we couldn't lock out the front panel. Probably someone is holding down a button
		// on the IGH so we can't communicate, or the IGH could be off.
		
		// First business: set the local status back to normal.
		if(oldlocal_status)
			kelvinox_commandq("C2")
		else
			kelvinox_commandq("C3")
		endif
		
		// Second order of business: quit.
//		print "Status not got."
		doupdate
		return 0
	endif
	
	//read temperature and power
	Kelvinox_command("R1")			//sorb temp
	temp_sorb=str2num(junkstr[3,7])/10
	Kelvinox_command("R2")			//1K pot temp
	temp_1K=str2num(junkstr[3,7])/1000
	Kelvinox_command("R3")			//Mix chamber temp
	temp_mix=str2num(junkstr[3,7])
	if(temp_mix<3000)
		Kelvinox_command("R32")			//Mix chamber temp
		temp_mix=str2num(junkstr[2,7])/10
	endif
	Kelvinox_command("R4")			//Mix chamber power
	power_mix=str2num(junkstr[3,7])
	Kelvinox_command("R5")			//still power
	power_still=str2num(junkstr[3,7])/10
	Kelvinox_command("R6")			//sorb power
	power_sorb=str2num(junkstr[3,7])
	
	//read status of V6 & V12A
	Kelvinox_command("R7")
	Valve_V6=str2num(junkstr[3,7])/10
	Kelvinox_command("R8")
	Valve_V12A=str2num(junkstr[3,7])/10
	Kelvinox_command("R9")
	Valve_NV=str2num(junkstr[3,7])/10
	//read pressure
	Kelvinox_command("R14")
	Pres_G1=str2num(junkstr[3,7])/10
	Kelvinox_command("R15")
	Pres_G2=str2num(junkstr[3,7])/10
	Kelvinox_command("R16")
	Pres_G3=str2num(junkstr[3,7])/10
	Kelvinox_command("R20")
	Pres_P1=str2num(junkstr[1,5])
	Kelvinox_command("R21")
	Pres_P2=str2num(junkstr[1,5])

	kelvinoxsetlocal(oldlocal_status)
	////////////////// DATA FROM 'X' STATUS STRING //////////////	
		//read X string.
		Kelvinox_command("X")
		/// mix power range
		mixrange=str2num(junkstr[20])
		if(str2num(junkstr[3])==0)
			mixrange=0
		endif
		PopupMenu /z Mixch_range,win=Kelvinox,mode=mixrange+1
		Kelvinox_PopMenuProc("Mixch_range", mixrange+1,"")
		power_mix=power_mix/1000*10^(mixrange-1)
		
		/// sorb temperature control
		sorbstatus=str2num(junkstr[18])
		if(sorbstatus==2 || sorbstatus==3)
			TempControl_Sorb=1
		else
			TempControl_Sorb=0
		endif
		
		//read status of valves and pumps
		statuscode=str2num("0x"+junkstr[7,14])
		Valve_V1=(statuscode & 2^9)/2^9
		Valve_V2=(statuscode & 2^15)/2^15
		Valve_V3=(statuscode & 2^12)/2^12
		Valve_V4=(statuscode & 2^11)/2^11
		Valve_V5=(statuscode & 2^10)/2^10
		Valve_V7=(statuscode & 2^2)/2^2
		Valve_V8=(statuscode & 2^1)/2^1
		Valve_V9=(statuscode & 2^0)/2^0
		Valve_V10=(statuscode & 2^14)/2^14
		Valve_V11A=(statuscode & 2^3)/2^3
		Valve_V11B=(statuscode & 2^6)/2^6
		Valve_V12B=(statuscode & 2^7)/2^7
		Valve_V13A=(statuscode & 2^4)/2^4
		Valve_V13B=(statuscode & 2^5)/2^5
		Valve_V14=(statuscode & 2^13)/2^13
		Valve_V1A=(statuscode & 2^17)/2^17
		Valve_V2A=(statuscode & 2^16)/2^16
		Valve_V4A=(statuscode & 2^19)/2^19
		Valve_V5A=(statuscode & 2^18)/2^18
		Pump_He3=(statuscode & 2^23)/2^23
		Pump_Roots=(statuscode & 2^21)/2^21
		Pump_He4=(statuscode & 2^8)/2^8
		
		// read moving status of valves
		variable movingstatus = str2num(junkstr[16]) | str2num(junkstr[1])
		Valve_V6moving = ((movingstatus&1) != 0)
		if(valve_v6moving == 1)
			ValDisplay /z V6Status,win=Kelvinox, highColor= (65280,43520,0)
		else
			if(Valve_V6 == 99.9)
				ValDisplay /z V6Status,win=Kelvinox, highColor= (0,65280,0)
			elseif(Valve_V6 > 0)
				ValDisplay /z V6Status,win=Kelvinox, highColor= (65280,30464,21760)
			else
				ValDisplay /z V6Status,win=Kelvinox, highColor= (0,0,0)
			endif
		endif
		Valve_V12Amoving = ((movingstatus&2) != 0)
		if(valve_v12Amoving == 1)
			ValDisplay /z V12AStatus,win=Kelvinox, highColor= (65280,43520,0)
		else
			if(Valve_V12A == 99.9)
				ValDisplay /z V12AStatus,win=Kelvinox, highColor= (0,65280,0)
			elseif(Valve_V12A > 0)
				ValDisplay /z V12AStatus,win=Kelvinox, highColor= (65280,30464,21760)
			else
				ValDisplay /z V12AStatus,win=Kelvinox, highColor= (0,0,0)
			endif
		endif
		Valve_NVmoving = ((movingstatus&4) != 0)
		if(valve_NVmoving == 1)
			ValDisplay /z NVStatus,win=Kelvinox, highColor= (65280,43520,0)
		else
			if(Valve_NV == 99.9)
				ValDisplay /z NVStatus,win=Kelvinox, highColor= (0,65280,0)
			elseif(Valve_NV > 0)
				ValDisplay /z NVStatus,win=Kelvinox, highColor= (65280,30464,21760)
			else
				ValDisplay /z NVStatus,win=Kelvinox, highColor= (0,0,0)
			endif
		endif
		
		// read control status
		statuscode=str2num(junkstr[5])
		Local_status=! (statuscode & 1)

      //////////////////// End of data from 'X' string /////////////


	//// Level meter handling:
	NVAR ILM_Active
	
	if(ilm_active)
	//print ilm_active
		ILMGetLevel()
	endif
	
	SVAR KelvinoxTimeStamp
	KelvinoxTimeStamp = date() + " " + time()
	nvar KelvinoxDateTime
	KelvinoxDateTime = datetime
	
//	logger()
	
	doupdate
	
	return 0	// Tell Igor to continue calling background task.
End


/// Returns 0 if ILM level getting failed; 1 if successful.
Function ILMGetLevel()
	SVAR junkstr
	NVAR level_He, level_N2
	//SVAR ILM_Rate Mohammad: I commented this out because it was crashing the logger and the variable is not used anywhere!
	NVAR ILM_Active
	
	level_He=nan ; level_N2=nan
	if(! ILM_command("X"))
		ILM_Active = 0
//		abort "Cannot read level - ILM not turned on or not connected."
		return 0
	endif
	string status=junkstr

	if(str2num(status[1])==2)
		ILM_command("R1")
		level_He=str2num(junkstr[1,6])/10
		Valdisplay /z ilmHe win=Kelvinox, format="%.1f"
	else
		Valdisplay /z ilmHe win=Kelvinox, format="Err"
	endif

	if(str2num(status[2])==1)
		ILM_command("R2")
		level_N2=str2num(junkstr[1,6])/10
		Valdisplay /z ilmN2 win=Kelvinox, format="%.1f"
	else
		Valdisplay /z ilmN2 win=Kelvinox, format="Err"
	endif

	variable herate
	sscanf status[5,6], "%x",herate
	if(herate & 2)
		PopupMenu /z LevelRateSelector,win=Kelvinox,mode=1,disable=0
	elseif(herate & 4)
		PopupMenu /z LevelRateSelector,win=Kelvinox,mode=2,disable=0
	endif
	return 1
End

Function ILMPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			ILM_command("C3") // put the ILM in remote control mode.
			if(popnum == 1)
				ILM_command("T1")
			else
				ILM_command("S1")
			endif
			ILMGetLevel()
			break
	endswitch

	return 0
End

Function ILMCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	NVAR ilm_active, level_he, level_n2
	
	
	if(ilm_active == 1)
		/// User wants to activate level meter. Do a level check, but if there's an error, we should uncheck the box.
		ilm_active = 0
		ILMgetlevel()
		ilm_active = 1  // getlevel succeeded, let's activate!
	endif

	if(!ilm_active)
		// ilm is inactive: disable controls
		PopupMenu LevelRateSelector win=Kelvinox, disable=2
		Valdisplay ilmHe win=Kelvinox, format="(%.1f)"
		Valdisplay ilmN2 win=Kelvinox, format="(%.1f)"
	endif

	return 0
End


Function KelvinoxSetPump(Pump, Value)	//PumpName="He3", "He4", or "Roots". Value 1 = on, 0 = off
	String Pump
	Variable Value
	string cmd
	NVAR Pump_He3, Pump_He4, Pump_Roots
	
	strswitch(Pump)
		case "He3":
			Kelvinox_command("P"+num2str(49-Value)) // Value 1 = on, 0 = off
			Pump_He3=Value
			break
		case "He4":
			Kelvinox_command("P"+num2str(19-Value)) // Value 1 = on, 0 = off
			Pump_He4=Value
			break
		case "Roots":
			Kelvinox_command("P"+num2str(45-Value)) // Value 1 = on, 0 = off
			Pump_Roots=Value
			break
	endswitch
End

Function KelvinoxSetV6(Value)		//Set V6 and wait until V6 is not moving
	variable Value
	NVAR Valve_V6
	SVAR junkstr
	variable statuscode
	
	Kelvinox_command("G"+num2str(floor(Value*10))) // Value in percent open
	Valve_V6=Value
	do
		Kelvinox_command("X")
		statuscode=str2num("0x"+junkstr[16])
		if( !(statuscode & 1))
			break
		endif
		sleep/s 0.5
	while(1)
end

Function KelvinoxSetValve(Valve, Value)
// ValveName="V1", "V2", "V1A"....For valves "NV", "V6" and "V12A", value means percent open (value 50=50% open). For other valves, value 1 = on, 0 = off
	String Valve
	Variable Value
	string cmd
	NVAR Valve_V6, Valve_V12A, Valve_NV
	
	strswitch(Valve)
		case "V6":
			Kelvinox_command("G"+num2str(round(Value*10))) // Value in percent open
			Valve_V6=Value
			ValDisplay /z V6Status,win=Kelvinox, highColor= (65280,43520,0)
			break
		case "V12A":
			Kelvinox_command("H"+num2str(round(Value*10))) // Value in percent open
			Valve_V12A=Value
			ValDisplay /z V12AStatus,win=Kelvinox, highColor= (65280,43520,0)
			break
		case "NV":
			Kelvinox_command("N"+num2str(round(Value*10))) // Value in percent open
			Valve_NV=Value
			ValDisplay /z NVStatus,win=Kelvinox, highColor= (65280,43520,0)
			break
		default:
			strswitch(Valve)
			case "V1":
				Kelvinox_command("P"+num2str(21-Value)) // Value 1 = on, 0 = off
				break
			case "V2":
				Kelvinox_command("P"+num2str(33-Value))
				break
			case "V3":
				Kelvinox_command("P"+num2str(27-Value))
				break
			case "V4":
				Kelvinox_command("P"+num2str(25-Value))
				break
			case "V5":
				Kelvinox_command("P"+num2str(23-Value))
				break
			case "V7":
				Kelvinox_command("P"+num2str(7-Value))
				break
			case "V8":
				Kelvinox_command("P"+num2str(5-Value))
				break
			case "V9":
				Kelvinox_command("P"+num2str(3-Value))
				break
			case "V10":
				Kelvinox_command("P"+num2str(31-Value))
				break
			case "V11A":
				Kelvinox_command("P"+num2str(9-Value))
				break
			case "V11B":
				Kelvinox_command("P"+num2str(15-Value))
				break
			case "V12B":
				Kelvinox_command("P"+num2str(17-Value))
				break
			case "V13A":
				Kelvinox_command("P"+num2str(11-Value))
				break
			case "V13B":
				Kelvinox_command("P"+num2str(13-Value))
				break
			case "V14":
				Kelvinox_command("P"+num2str(29-Value))
				break
			case "V1A":
				Kelvinox_command("P"+num2str(37-Value))
				break
			case "V2A":
				Kelvinox_command("P"+num2str(35-Value))
				break
			case "V4A":
				Kelvinox_command("P"+num2str(41-Value))
				break
			case "V5A":
				Kelvinox_command("P"+num2str(39-Value))
				break
			endswitch
			cmd="Valve_"+Valve+"="+num2str(Value)
			execute(cmd)
	endswitch
End

Function KelvinoxSetLocal(Value)	// Value 0 = remote, 1 = local
	Variable Value
	NVAR Local_status
	
	if (Value)
		Kelvinox_command("C2")
	else
		Kelvinox_command("C3")
	endif
	Local_status= (Value && 1)
End

Function KelvinoxSetStatus()
	NVAR MixChRange, TempControl_Sorb, TempControl_MixCh
	NVAR temp_sorb, temp_mix, power_mix, power_still, power_sorb
	
	if(power_sorb==0 && !TempControl_Sorb && power_still==0)
		Kelvinox_command("O0")
	elseif(power_sorb==0 && !TempControl_Sorb && power_still>0)
		Kelvinox_command("O1")
	elseif(temp_sorb>0 && power_still==0 && TempControl_Sorb)
		Kelvinox_command("O2")
	elseif(temp_sorb>0 && power_still>0 && TempControl_Sorb)
		Kelvinox_command("O3")
	elseif(power_sorb>0 && power_still==0 && !TempControl_Sorb)
		Kelvinox_command("O4")
	elseif(power_sorb>0 && power_still>0 && !TempControl_Sorb)
		Kelvinox_command("O5")
	endif
	
	if(power_still>0)
		Kelvinox_command("S"+num2str(power_still*10))	//set still power
	endif
	if(TempControl_Sorb && temp_sorb>0)
		Kelvinox_command("K"+num2str(temp_sorb*10))		//set sorb temp
	elseif(!TempControl_Sorb && power_sorb>0)
		Kelvinox_command("B"+num2str(power_sorb))	//set sorb power
	endif
	
	if(MixChRange==0)
		Kelvinox_command("A0")		//turn off heater
	elseif(TempControl_MixCh)		//temperature control
		Kelvinox_command("A2")
		Kelvinox_command("E"+num2str(MixChRange))		//set range of Mix power
		Kelvinox_command("T"+num2str(temp_mix*10))		//set Mix control temp
	else
		Kelvinox_command("A1")	// fixed heater power
		Kelvinox_command("E"+num2str(MixChRange))		//set range of Mix power
		Kelvinox_command("M"+num2str(power_mix*1000/10^(MixChRange-1)))		//set Mix power
	endif
	
End

Function KelvinoxShowSetpoint()
	SVAR junkstr
	NVAR temp_sorb, temp_1K, temp_mix, power_mix, power_still, power_sorb, MixChRange
	
	Kelvinox_command("R0")			//sorb temp
	temp_sorb=str2num(junkstr[3,7])/10
	Kelvinox_command("R3")			//Mix chamber temp
	temp_mix=str2num(junkstr[3,7])
	if(temp_mix<3000)
		Kelvinox_command("R33")			//Mix chamber temp
		temp_mix=str2num(junkstr[2,7])/10
	endif
	Kelvinox_command("R4")			//Mix chamber power
	power_mix=str2num(junkstr[3,7])
	Kelvinox_command("R5")			//still power
	power_still=str2num(junkstr[3,7])/10
	Kelvinox_command("R6")			//sorb power
	power_sorb=str2num(junkstr[3,7])
		
	//read Mix power range
	Kelvinox_command("X")
	MixChRange=str2num(junkstr[20])
	if(str2num(junkstr[3])==0)
		MixChRange=0
	endif
	PopupMenu Mixch_range,mode=MixChRange+1
	Kelvinox_PopMenuProc("Mixch_range", MixChRange+1,"")
	power_mix=power_mix/1000*10^(MixChRange-1)
End

///// added by Mark,   Sept 4 2009:   Clearmem does not cause an error.
Function KelvinoxClearMem()
	NVAR V_VDT
	string cmd
	do  /// read until timeout occurs.
		cmd="VDTread2 /q /o=1 junkstr"
		execute (cmd)
	while(v_vdt != 0)
end

Function ButtonProc_Kelvinox(ctrlName) : ButtonControl
	String ctrlName
	string cmd, valvename
	NVAR  temp_sorb, temp_1K, temp_mix, power_mix, power_still, power_sorb
	NVAR Kelvinox_Background, show_setpoint, Valve_V6, Valve_V12A, Valve_NV, Pump_He3, Pump_He4, Pump_Roots, Local_status
	NVAR TempControl_MixCh, TempControl_Sorb
	
	KelvinoxSetLocal(0)
	strswitch(ctrlname)
		case "clearmem":
			KelvinoxClearMem()
//			cmd="VDTread2 /o=3 junkstr"
//			execute (cmd)
			break
		case "button_MixCh":
			TempControl_MixCh=!TempControl_MixCh
			return 1
		case "button_Sorb":
			TempControl_Sorb=!TempControl_Sorb
			return 1
		case "get_status":
			if(Kelvinox_Background==0)
				Button Get_status title="Stop"
				Button Get_status fColor=(65280,16384,16384)
				SetBackground KelvinoxGetStatus()
				CtrlBackground period=90,start	// run the function every 1.5 sec
			else
				KillBackground
				Button Get_status title="Get Status"
				Button Get_status fColor=(0,0,0)
			endif
			Kelvinox_Background=!Kelvinox_Background
			Button button_Sorb disable=2
			Button button_MixCh disable=2
			PopupMenu Mixch_range disable=2
			SetVariable tempR1 disable=2
			SetVariable tempR3 disable=2
			SetVariable powerR6 disable=2
			SetVariable powerR5 disable=2
			SetVariable powerR4 disable=2
			Button Set_status title="Show Setpoints"
			show_setpoint=0
			return 1
		case "get_level":
			ILMGetLevel()
			break
		case "set_status":
			if(show_setpoint)	//set status
				KelvinoxSetStatus()
				sleep/s 0.5
				ButtonProc_Kelvinox("get_status")
			else				//show set points
				if(Kelvinox_Background)
					KillBackground
					Button Get_status title="Get Status"
					Button Get_status fColor=(0,0,0)
					Kelvinox_Background=0
				endif
				Button Set_status title="Set Temp & Power "
				Button button_Sorb disable=0
				Button button_MixCh disable=0
				PopupMenu Mixch_range disable=0
				SetVariable tempR1 disable=0
				SetVariable tempR3 disable=0
				SetVariable powerR6 disable=0
				SetVariable powerR5 disable=0
				SetVariable powerR4 disable=0
				show_setpoint=1
				KelvinoxShowSetpoint()
				return 1
			endif
			break
		case "button_V12A":
			KelvinoxSetValve("V12A", Valve_V12A)
			break
		case "button_V6":
			KelvinoxSetValve("V6", Valve_V6)
			break
		case "button_NV":
			KelvinoxSetValve("NV",Valve_NV)
			break
		case "button_He3":
			KelvinoxSetPump("He3", !Pump_He3)
			break
		case "button_He4":
			KelvinoxSetPump("He4", !Pump_He4)
			break
		case "button_Roots":
			KelvinoxSetPump("Roots", !Pump_Roots)
			return 1
		case "button_Local":
			KelvinoxSetLocal(1)
			break
		case "button_Remote":
			KelvinoxSetLocal(0)
			break
		case "showsorbtemp":
			Kelvinox_command("F1")
			break
		case "showsorbpower":
			Kelvinox_command("F6")
			break
		case "show1kpottemp":
			Kelvinox_command("F2")
			break
		case "showstillpower":
			Kelvinox_command("F5")
			break
		case "showmixchpower":
			Kelvinox_command("F4")
			break
		case "showmixchtemp":
			Kelvinox_command("F3")
			break
		case "lockButton":
			KelvinoxLockSwitch()
			break
		default:	// button_V1 & button_V2 ....
			valvename=ctrlname[7,strlen(ctrlname)-1]
			cmd="KelvinoxSetValve(\""+valvename+"\", !Valve_"+valvename+")"
			execute(cmd)
	endswitch
	KelvinoxGetStatus()
End

Function Kelvinox_PopMenuProc(ctrlName, popNum,popStr): PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	NVAR MixChRange
	
	MixChRange=popNum-1
	switch(MixChRange)
	case 1:
		SetVariable /Z powerR4,win=kelvinox, limits={0,2,0.001}
		break
	case 2:
		SetVariable /Z powerR4,win=kelvinox, limits={0,20,0.01}
		break
	case 3:
		SetVariable /Z powerR4,win=kelvinox, limits={0,200,0.1}
		break
	case 4:
		SetVariable /Z powerR4,win=kelvinox, limits={0,2000,1}
		break
	case 5:
		SetVariable /Z powerR4,win=kelvinox, limits={0,20000,10}
		break
	endswitch
End

/// unlock = 1 (unlock)  or   0 (lock)         or leave out to toggle
function KelvinoxLockSwitch([unlock])
	variable unlock
	variable dis
	string /g s_recreation

	dowindow /f Kelvinox
	if(paramisdefault(unlock))
		execute "controlinfo lockbutton"
		unlock = !stringmatch(s_recreation,"*Unlocked*")
		// if displaying 'unlocked', then switch to locked, and vice-versa
	endif
	dis = 2*(!unlock)   /// 0 for enabled, 2 for disabled
	
	if(unlock)
		Button lockButton title="Unlocked",fColor=(65535,0,0)
	else
		Button lockButton title="Locked",fColor=(48896,65280,48896)
	endif
	
	Button button_V1 disable=dis
	Button button_V2 disable=dis
	Button button_V3 disable=dis
	Button button_V4 disable=dis
	Button button_V5 disable=dis
	Button button_V6 disable=dis
	Button button_V7 disable=dis
	Button button_V8 disable=dis
	Button button_V9 disable=dis
	Button button_V10 disable=dis
	Button button_V11A disable=dis
	Button button_V12A disable=dis
	Button button_V13A disable=dis
	Button button_V11B disable=dis
	Button button_V12B disable=dis
	Button button_V13B disable=dis
	Button button_V14 disable=dis

	Button button_V1A disable=dis
	Button button_V2A disable=dis
	Button button_V4A disable=dis
	Button button_V5A disable=dis
	Button button_NV disable=dis
	
	Button button_He3 disable=dis
	Button button_He4 disable=dis
	Button button_Roots disable=dis
	SetVariable Valve6 disable=dis
	SetVariable Valve12A disable=dis
	SetVariable ValveNV disable=dis
end

Window Kelvinox() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(507,429,1227,931)
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 477,298,477,363
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 61,452,300,452
	SetDrawEnv linethick= 2,linefgc= (0,0,65280)
	DrawRect 121,442,186,464
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 61,374,300,374
	SetDrawEnv linethick= 2,linefgc= (0,0,65280)
	DrawRect 121,364,186,386
	SetDrawEnv fillpat= 0,fillfgc= (60928,60928,60928)
	DrawRect 4,27,373,484
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 60,56,60,452
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 299,56,299,452
	DrawLine 174,90,299,90
	DrawLine 428,68,428,68
	SetDrawEnv fsize= 18,fstyle= 1,textrgb= (0,0,65280)
	DrawText 148,25,"Helium 3"
	SetDrawEnv fsize= 16,fstyle= 1,textrgb= (0,0,65280)
	DrawText 269,51,"Pumping"
	SetDrawEnv fsize= 16,fstyle= 1,textrgb= (0,0,65280)
	DrawText 15,51,"Condenser"
	SetDrawEnv linethick= 2,linefgc= (0,0,65280)
	DrawRect 280,189,330,211
	SetDrawEnv gstart
	SetDrawEnv fsize= 16,fstyle= 1,textrgb= (0,0,65280)
	DrawText 283,210,"Pump"
	SetDrawEnv gstop
	DrawRect 451,202,451,202
	DrawRect 451,201,451,201
	DrawRect 436,194,436,194
	SetDrawEnv fstyle= 1,textrgb= (0,0,65280)
	DrawText 125,382,"ColdTrap1"
	SetDrawEnv fstyle= 1,textrgb= (0,0,65280)
	DrawText 125,460,"ColdTrap2"
	SetDrawEnv fillpat= 0
	DrawRect 384,206,610,437
	SetDrawEnv fsize= 18,fstyle= 1,textrgb= (0,0,65280)
	DrawText 469,203,"Auxiliary"
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 533,359,533,417
	SetDrawEnv gstart
	SetDrawEnv linethick= 2,linefgc= (0,0,65280)
	DrawRect 498,403,563,425
	SetDrawEnv fsize= 16,fstyle= 1,textrgb= (0,0,65280)
	DrawText 509,423,"Pump"
	SetDrawEnv gstop
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 476,359,586,359
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 464,298,489,298
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 586,231,586,351
	SetDrawEnv fsize= 16,fstyle= 1,textrgb= (0,0,65280)
	DrawText 573,228,"IVC"
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 574,230,599,230
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 287,55,312,55
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 48,55,73,55
	DrawLine 60,119,257,119
	DrawLine 101,119,101,242
	DrawLine 256,119,256,247
	DrawLine 141,119,141,241
	DrawLine 212,119,212,311
	SetDrawEnv gstart
	SetDrawEnv linethick= 2,linefgc= (0,0,65280)
	DrawRect 198,190,237,209
	SetDrawEnv fstyle= 1,textrgb= (0,0,65280)
	DrawText 201,206,"Dump"
	SetDrawEnv gstop
	DrawLine 212,311,299,311
	DrawLine 174,124,174,238
	DrawLine 174,98,174,115
	DrawLine 182,234,234,234
	DrawLine 234,234,234,311
	DrawLine 234,246,257,246
	DrawLine 102,203,124,203
	DrawLine 124,203,124,310
	DrawLine 125,309,197,309
	DrawLine 197,309,197,373
	DrawLine 142,233,142,310
	DrawLine 124,309,124,361
	DrawLine 124,397,197,397
	DrawLine 124,389,124,398
	DrawLine 197,397,197,453
	DrawLine 142,190,192,190
	DrawLine 191,190,191,214
	DrawLine 192,213,213,213
	DrawLine 256,184,300,184
	DrawLine 405,336,477,336
	DrawLine 405,230,405,337
	DrawLine 398,229,413,229
	DrawLine 537,287,537,337
	DrawLine 530,287,545,287
	DrawLine 537,336,587,336
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 449,26,"Temp"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 610,26,"Power"
	SetDrawEnv fstyle= 1
	DrawText 687,50,"mW"
	SetDrawEnv fstyle= 1
	DrawText 687,81,"mW"
	SetDrawEnv fstyle= 1
	DrawText 687,112,"uW"
	SetDrawEnv fstyle= 1
	DrawText 524,51,"K"
	SetDrawEnv fstyle= 1
	DrawText 524,81,"K"
	SetDrawEnv fstyle= 1
	DrawText 524,111,"mK"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 620,169,"Temp Control"
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 464,278,489,278
	SetDrawEnv fsize= 16,fstyle= 1,textrgb= (0,0,65280)
	DrawText 451,299,"1KPot"
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 477,231,477,276
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 464,230,489,230
	SetDrawEnv fillpat= 0
	DrawPoly 234,262,1,1,{49,336,42,347,57,347,49,336}
	DrawLine 228,262,241,262
	SetDrawEnv fillpat= 0
	DrawPoly 177,183,1,1,{40,322,40,338,50,329,40,322}
	DrawLine 186,184,186,199
	SetDrawEnv fillfgc= (60928,60928,60928)
	DrawRect 386,444,717,499
	SetDrawEnv fsize= 18,fstyle= 1,textrgb= (0,0,65280)
	DrawText 394,472,"Level Meter"
	ValDisplay Pressure_G2,pos={255,267},size={80,21},title="G2",fSize=16
	ValDisplay Pressure_G2,format="%3.1f",frame=4,fStyle=1
	ValDisplay Pressure_G2,limits={0,0,0},barmisc={0,1000},value= #"Pres_G2"
	ValDisplay Pressure_G1,pos={16,267},size={80,21},title="G1",fSize=16
	ValDisplay Pressure_G1,format="%3.1f",frame=4,fStyle=1
	ValDisplay Pressure_G1,limits={0,0,0},barmisc={0,1000},value= #"Pres_G1"
	ValDisplay Pressure_P1,pos={137,79},size={72,21},title="P1",fSize=16,frame=4
	ValDisplay Pressure_P1,fStyle=1,limits={0,1,0},barmisc={0,1000}
	ValDisplay Pressure_P1,value= #"Pres_P1"
	Button Get_status,pos={402,120},size={100,25},proc=ButtonProc_Kelvinox,title="Get Status"
	Button Get_status,fSize=16,fStyle=1
	SetVariable Valve6,pos={277,144},size={55,24},proc=SetVariableValve,title=" "
	SetVariable Valve6,fSize=16,format="%.1f",fStyle=1
	SetVariable Valve6,limits={0,99.9,0.1},value= Valve_V6
	Button button_V6,pos={286,123},size={30,20},proc=ButtonProc_Kelvinox,title="V6"
	Button button_V12A,pos={79,365},size={35,20},proc=ButtonProc_Kelvinox,title="V12A"
	SetVariable Valve12A,pos={65,386},size={49,24},proc=SetVariableValve,title=" "
	SetVariable Valve12A,fSize=16,format="%.1f",fStyle=1
	SetVariable Valve12A,limits={0,99.9,0.1},value= Valve_V12A
	Button button_V4A,pos={463,351},size={30,20},proc=ButtonProc_Kelvinox,title="V4A"
	ValDisplay Pressure_G3,pos={434,310},size={72,21},title="G3",fSize=16
	ValDisplay Pressure_G3,format="%.1f",frame=4,fStyle=1
	ValDisplay Pressure_G3,limits={0,0,0},barmisc={0,1000},value= #"Pres_G3"
	ValDisplay Pressure_P2,pos={487,375},size={72,21},title="P2",fSize=16,frame=4
	ValDisplay Pressure_P2,fStyle=1,limits={0,0,0},barmisc={0,1000}
	ValDisplay Pressure_P2,value= #"Pres_P2"
	ValDisplay V4Astatus,pos={472,337},size={10,10},frame=2
	ValDisplay V4Astatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay V4Astatus,value= #"Valve_V4A"
	ValDisplay V2status,pos={97,146},size={10,10},frame=2
	ValDisplay V2status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V2status,value= #"Valve_V2"
	Button button_V2,pos={89,161},size={30,20},proc=ButtonProc_Kelvinox,title="V2"
	ValDisplay V3status,pos={136,146},size={10,10},frame=2
	ValDisplay V3status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V3status,value= #"Valve_V3"
	Button button_V3,pos={128,161},size={30,20},proc=ButtonProc_Kelvinox,title="V3"
	Button button_V4,pos={199,161},size={30,20},proc=ButtonProc_Kelvinox,title="V4"
	ValDisplay V4status,pos={207,146},size={10,10},frame=2
	ValDisplay V4status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V4status,value= #"Valve_V4"
	ValDisplay V7status,pos={97,208},size={10,10},frame=2
	ValDisplay V7status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V7status,value= #"Valve_V7"
	Button button_V7,pos={89,223},size={30,20},proc=ButtonProc_Kelvinox,title="V7"
	Button button_V8,pos={129,223},size={30,20},proc=ButtonProc_Kelvinox,title="V8"
	ValDisplay V8status,pos={137,208},size={10,10},frame=2
	ValDisplay V8status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V8status,value= #"Valve_V8"
	ValDisplay V5status,pos={251,146},size={10,10},frame=2
	ValDisplay V5status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V5status,value= #"Valve_V5"
	Button button_V5,pos={243,161},size={30,20},proc=ButtonProc_Kelvinox,title="V5"
	ValDisplay V9status,pos={208,263},size={10,10},frame=2
	ValDisplay V9status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V9status,value= #"Valve_V9"
	Button button_V9,pos={200,278},size={30,20},proc=ButtonProc_Kelvinox,title="V9"
	ValDisplay V10status,pos={252,220},size={10,10},frame=2
	ValDisplay V10status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V10status,value= #"Valve_V10"
	Button button_V10,pos={244,235},size={30,20},proc=ButtonProc_Kelvinox,title="V10"
	ValDisplay V14status,pos={169,208},size={10,10},frame=2
	ValDisplay V14status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V14status,value= #"Valve_V14"
	Button button_V14,pos={161,223},size={30,20},proc=ButtonProc_Kelvinox,title="V14"
	ValDisplay V11status,pos={193,317},size={10,10},frame=2
	ValDisplay V11status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V11status,value= #"Valve_V11A"
	Button button_V11A,pos={181,332},size={36,20},proc=ButtonProc_Kelvinox,title="V11A"
	ValDisplay V11stat01,pos={193,402},size={10,10},frame=2
	ValDisplay V11stat01,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V11stat01,value= #"Valve_V11B"
	Button button_V11B,pos={181,417},size={36,20},proc=ButtonProc_Kelvinox,title="V11B"
	ValDisplay V13Astatus,pos={230,369},size={10,10},frame=2
	ValDisplay V13Astatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay V13Astatus,value= #"Valve_V13A"
	Button button_V13A,pos={246,363},size={36,20},proc=ButtonProc_Kelvinox,title="V13A"
	Button button_V13B,pos={246,444},size={36,20},proc=ButtonProc_Kelvinox,title="V13B"
	ValDisplay V13Bstatus,pos={230,448},size={10,10},frame=2
	ValDisplay V13Bstatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay V13Bstatus,value= #"Valve_V13B"
	Button button_V12B,pos={79,443},size={35,20},proc=ButtonProc_Kelvinox,title="V12B"
	ValDisplay V12Bstatus,pos={66,448},size={10,10},frame=2
	ValDisplay V12Bstatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay V12Bstatus,value= #"Valve_V12B"
	ValDisplay V5Astatus,pos={582,337},size={10,10},frame=2
	ValDisplay V5Astatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V5Astatus,value= #"Valve_V5A"
	Button button_V5A,pos={574,351},size={30,20},proc=ButtonProc_Kelvinox,title="V5A"
	Button button_V1A,pos={390,283},size={30,20},proc=ButtonProc_Kelvinox,title="V1A"
	ValDisplay V1Astatus,pos={400,270},size={10,10},frame=2
	ValDisplay V1Astatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay V1Astatus,value= #"Valve_V1A"
	Button button_V2A,pos={524,312},size={30,20},proc=ButtonProc_Kelvinox,title="V2A"
	ValDisplay V2Astatus,pos={532,297},size={10,10},frame=2
	ValDisplay V2Astatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V2Astatus,value= #"Valve_V2A"
	ValDisplay V1status,pos={55,72},size={10,10},frame=2
	ValDisplay V1status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay V1status,value= #"Valve_V1"
	Button button_V1,pos={46,86},size={30,20},proc=ButtonProc_Kelvinox,title="V1"
	Button button_He3,pos={638,253},size={75,25},proc=ButtonProc_Kelvinox,title="He3 Pump"
	Button button_He3,fSize=14,fStyle=0
	Button button_He4,pos={638,288},size={75,25},proc=ButtonProc_Kelvinox,title="He4 Pump"
	Button button_He4,fSize=14,fStyle=0
	Button button_Roots,pos={638,325},size={75,25},proc=ButtonProc_Kelvinox,title="Roots"
	Button button_Roots,fSize=14,fStyle=0
	ValDisplay He3_Pump_status,pos={624,261},size={10,10},frame=2
	ValDisplay He3_Pump_status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay He3_Pump_status,value= #"Pump_He3"
	ValDisplay He4_Pump_status,pos={624,296},size={10,10},frame=2
	ValDisplay He4_Pump_status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay He4_Pump_status,value= #"Pump_He4"
	ValDisplay Roots_Pump_status,pos={624,332},size={10,10},frame=2
	ValDisplay Roots_Pump_status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay Roots_Pump_status,value= #"Pump_Roots"
	Button button_Local,pos={638,375},size={75,25},proc=ButtonProc_Kelvinox,title="Local"
	Button button_Local,fSize=14,fStyle=0
	Button button_Remote,pos={638,411},size={75,25},proc=ButtonProc_Kelvinox,title="Remote"
	Button button_Remote,fSize=14,fStyle=0
	ValDisplay Remotestatus,pos={624,418},size={10,10},frame=2
	ValDisplay Remotestatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay Remotestatus,value= #"!Local_status"
	ValDisplay Localstatus,pos={624,384},size={10,10},frame=2
	ValDisplay Localstatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay Localstatus,value= #"Local_status"
	SetVariable tempR1,pos={450,34},size={70,24},disable=2,title=" ",fSize=16
	SetVariable tempR1,fStyle=1,limits={0,inf,0.1},value= temp_sorb
	SetVariable tempR2,pos={450,63},size={70,24},disable=2,title=" ",fSize=16
	SetVariable tempR2,fStyle=1,limits={0,inf,1},value= temp_1K
	SetVariable tempR3,pos={450,92},size={70,24},disable=2,title=" ",fSize=16
	SetVariable tempR3,fStyle=1,limits={0,2000,0.1},value= temp_mix
	SetVariable powerR6,pos={615,34},size={70,24},disable=2,title=" ",fSize=16
	SetVariable powerR6,fStyle=1,limits={0,1999,1},value= power_sorb
	SetVariable powerR5,pos={615,63},size={70,24},disable=2,title=" ",fSize=16
	SetVariable powerR5,fStyle=1,limits={0,1999,0.1},value= power_still
	SetVariable powerR4,pos={616,92},size={70,24},disable=2,title=" ",fSize=16
	SetVariable powerR4,fStyle=1,limits={0,20000,10},value= power_mix
	Button Set_status,pos={401,151},size={170,25},proc=ButtonProc_Kelvinox,title="Show Setpoints"
	Button Set_status,fSize=16,fStyle=1
	PopupMenu Mixch_range,pos={553,118},size={110,21},disable=2,proc=Kelvinox_PopMenuProc,title="Range:"
	PopupMenu Mixch_range,fSize=16,fStyle=1
	PopupMenu Mixch_range,mode=1,popvalue="OFF",value= #"\"OFF;2uW;20uW;200uW;2mW;20mW\""
	Button button_Sorb,pos={638,174},size={75,25},disable=2,proc=ButtonProc_Kelvinox,title="Sorb"
	Button button_Sorb,fSize=14,fStyle=0
	ValDisplay SorbTempControl,pos={624,183},size={10,10},frame=2
	ValDisplay SorbTempControl,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay SorbTempControl,value= #"tempcontrol_Sorb"
	ValDisplay MixChTempControl,pos={624,213},size={10,10},frame=2
	ValDisplay MixChTempControl,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay MixChTempControl,value= #"Tempcontrol_MixCh"
	Button button_MixCh,pos={638,206},size={75,25},disable=2,proc=ButtonProc_Kelvinox,title="Mix CH"
	Button button_MixCh,fSize=14,fStyle=0
	Button button_NV,pos={462,253},size={30,20},proc=ButtonProc_Kelvinox,title="N/V"
	SetVariable ValveNV,pos={495,252},size={50,24},proc=SetVariableValve,title=" "
	SetVariable ValveNV,fSize=16,format="%.1f",fStyle=1
	SetVariable ValveNV,limits={0,99.9,0.1},value= Valve_NV
	Button ClearMem,pos={509,119},size={23,26},proc=ButtonProc_Kelvinox,title="C"
	Button ClearMem,fSize=16,fStyle=1
	Button ShowSorbTemp,pos={379,34},size={70,25},proc=ButtonProc_Kelvinox,title="Sorb:"
	Button ShowSorbTemp,fSize=16,fStyle=1
	Button Show1KPotTemp,pos={379,62},size={70,25},proc=ButtonProc_Kelvinox,title="1K Pot:"
	Button Show1KPotTemp,fSize=16,fStyle=1
	Button ShowMixCHTemp,pos={379,91},size={70,25},proc=ButtonProc_Kelvinox,title="Mix CH:"
	Button ShowMixCHTemp,fSize=16,fStyle=1
	Button ShowSorbPower,pos={544,34},size={70,25},proc=ButtonProc_Kelvinox,title="Sorb:"
	Button ShowSorbPower,fSize=16,fStyle=1
	Button ShowStillPower,pos={544,62},size={70,25},proc=ButtonProc_Kelvinox,title="Still:"
	Button ShowStillPower,fSize=16,fStyle=1
	Button ShowMixCHPower,pos={545,91},size={70,25},proc=ButtonProc_Kelvinox,title="Mix CH:"
	Button ShowMixCHPower,fSize=16,fStyle=1
	ValDisplay ilmHe,pos={548,450},size={85,21},title="He:",fSize=16,format="%.1f"
	ValDisplay ilmHe,frame=4,fStyle=1,limits={0,0,0},barmisc={0,1000}
	ValDisplay ilmHe,value= #"level_He"
	ValDisplay ilmN2,pos={548,472},size={85,21},title="N2:",fSize=16,format="%.1f"
	ValDisplay ilmN2,frame=4,fStyle=1,limits={0,0,0},barmisc={0,1000}
	ValDisplay ilmN2,value= #"level_N2"
	CheckBox ILMActive,pos={394,473},size={125,20},proc=ILMCheckProc,title="Is turned on?"
	CheckBox ILMActive,fSize=16,fStyle=1,variable= ILM_Active
	PopupMenu LevelRateSelector,pos={635,451},size={52,21},proc=ILMPopMenuProc
	PopupMenu LevelRateSelector,mode=2,popvalue="Slow",value= #"\"Fast;Slow\""
	TitleBox TimeStamp,pos={6,486},size={139,16},fSize=14,frame=0
	TitleBox TimeStamp,variable= KelvinoxTimeStamp,anchor= LB
	Button lockButton,pos={135,30},size={100,30},proc=ButtonProc_Kelvinox,title="Unlocked"
	Button lockButton,font="Arial",fSize=18,fStyle=1,fColor=(65535,0,0)
	ValDisplay V6status,pos={294,106},size={10,10},frame=2
	ValDisplay V6status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay V6status,value= #"1"
	ValDisplay V12Astatus,pos={66,370},size={10,10},frame=2
	ValDisplay V12Astatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V12Astatus,value= #"1"
	ValDisplay NVstatus,pos={472,238},size={10,10},frame=2
	ValDisplay NVstatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay NVstatus,value= #"1"
EndMacro



Function SetVariableValve(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

//	print sva.ctrlname, sva.eventcode, sva.dval
	if(sva.eventcode != 1 && sva.eventcode != 2 && sva.eventcode != 3)
		return 0
	endif
	strswitch( sva.ctrlname )
		case "Valve6":
			KelvinoxSetValve("V6", sva.dval)
			break
		case "Valve12A":
			KelvinoxSetValve("V12A", sva.dval)
			break
		case "ValveNV":
			KelvinoxSetValve("NV", sva.dval)
			break
	endswitch

	return 0
End





/// opens needle valve if needed
// call as often as you want, 
// e.g.
//   AdjustNV()   // default parameters 
//   AdjustNV(P2low = 3.5, P2high = 4.5)  // maintain P2 between 3.5 and 4.5
// period argument is optional, specifies how fast adjustments can happen.
// CALL KelvinoxGetStatus() EACH TIME BEFORE USING THIS PROCEDURE!

// ----------> CURRENTLY DISABLED BY RETURN 0 ON SECOND LINE!
function AdjustNV([P2low, P2high, period])
	variable P2low, P2high, period
	//return 0
	nvar lastNVadjust
	nvar lastNVdir // -1 for negative +1 for positive.
	variable NVbacklash = 0.1 /// size of backlash (conservative)
	
	if(paramisdefault(P2low))
		P2low = 3.9
	endif
	if(paramisdefault(P2high))
		P2high = 500
	endif
	if(paramisdefault(period))
		period = 60
	endif
	
	if(datetime - lastnvadjust < period)
		return 0 // don't make any adjustments.. it's too soon.
	endif
	lastnvadjust = datetime
	
	nvar valve_NV
	nvar pres_P2
	
	if(pres_P2 < P2low) // need to increase
		if(lastNVdir == (-1))
			KelvinoxSetValve("NV", valve_NV+nvbacklash)
		else
			KelvinoxSetValve("NV", valve_NV+0.1)
		endif
		lastnvdir = 1
	endif
	if(pres_P2 > P2high)
		if(lastNVdir == (+1))
			KelvinoxSetValve("NV", valve_NV-nvbacklash)
		else
			KelvinoxSetValve("NV", valve_NV-0.1)
		endif
		lastnvdir = -1
	endif
	
end



// Natelson Fridge adjust needle valve
// Based on temperature of 1 K pot (with funny calibration)
/// opens needle valve if needed
// call as often as you want, 
// e.g.
//   AdjustNV()   // default parameters 
//   AdjustNV(Tlow = 4.97, Thigh = 5.1)  // maintain T between 4.95 and 5.1 (This is in reality between 1.4 and 1.5)
// period argument is optional, specifies how fast adjustments can happen.
// CALL KelvinoxGetStatus() EACH TIME BEFORE USING THIS PROCEDURE!
function AdjustNVNatelson([Tlow,Thigh, period])
	variable Tlow, Thigh, period
	nvar lastNVadjust
	nvar lastNVdir // -1 for negative +1 for positive.
	variable NVbacklash = 0.1 /// size of backlash (conservative)
	
	if(paramisdefault(Tlow))
		Tlow = 4.95
	endif
	if(paramisdefault(Thigh))
		Thigh = 5.1
	endif
	if(paramisdefault(period))
		period = 60
	endif
	
	if(datetime - lastnvadjust < period)
		return 0 // don't make any adjustments.. it's too soon.
	endif
	lastnvadjust = datetime
	
	nvar valve_NV
	nvar  temp_1k
	
	if(temp_1k < Tlow) // need to increase
		if(lastNVdir == (-1))
			KelvinoxSetValve("NV", valve_NV+nvbacklash)
		else
			KelvinoxSetValve("NV", valve_NV+0.1)
		endif
		lastnvdir = 1
	endif
	if(temp_1k > Thigh)
		if(lastNVdir == (+1))
			KelvinoxSetValve("NV", valve_NV-nvbacklash)
		else
			KelvinoxSetValve("NV", valve_NV-0.1)
		endif
		lastnvdir = -1
	endif
	
end