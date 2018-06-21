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


// Which port is the Kelvinox on? Configure here.
Function KelvinoxSetPort()
	execute("VDTOperationsPort2 COM4")
end

Function initKelvinox()
	string cmd
	string /g junkstr
	variable/g show_setpoint=1, Kelvinox_Background=0
	variable/g level_He, level_N2, MixChRange, TempControl_Sorb, TempControl_MixCh
	variable/g temp_sorb, temp_1K, temp_mix, power_mix, power_still, power_sorb, Pres_P1, Pres_P2, Pres_G1, Pres_G2, Pres_G3
	variable/g Local_status, Pump_He3, Pump_He4, Pump_Roots
	variable/g Valve_V1, Valve_V1A, Valve_V2, Valve_V2A, Valve_V3, Valve_V4, Valve_V5, Valve_V4A, Valve_V5A, Valve_V6, Valve_V7,Valve_V8, Valve_V9, Valve_V10, Valve_V11A, Valve_V11B, Valve_V12A, Valve_V12B, Valve_V13A, Valve_V13B, Valve_V14, Valve_NV
	variable/g Valve_V6moving, Valve_NVmoving, Valve_V12Amoving
	string /g KelvinoxTimeStamp
	variable /g ILM_Active
	KelvinoxSetPort()
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
	Kelvinox_command2("R32")			//Mix chamber temp
	temp_mix=str2num(junkstr[2,7])/10
	Kelvinox_command("A1")		//fixed heater power
	if(1.1*temp<temp_mix)
		Kelvinox_command("M0")	// zero power
		power_mix=0
	elseif(0.9*temp>temp_mix)
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
		Kelvinox_command2("R32")			//Mix chamber temp
		temp_mix=str2num(junkstr[2,7])/10	
		DoUpdate
		sleep/s 1
	while(abs(temp-temp_mix)>Dtemp)		// Fast approaching setpoint
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
		Kelvinox_command2("R32")			//Mix chamber temp
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
	while(i<npoint)
end

Function KelvinoxSetMixChTempControl(temp)
	variable temp

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

Function ApproachSetPoint(temp,roots)
	variable temp,roots
	NVAR temp_mix, power_mix
	SVAR junkstr
	variable temp_old=temp_mix, temp_origin=temp_mix, Dtemp,prefactor=2
	Kelvinox_command("A1")		//fixed heater power
	do
		Kelvinox_command2("R32")			//Mix chamber temp
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
		low = 160
	endif
	if(paramisdefault(high))
		high = 210
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

Function Kelvinox_command(cmd)
	string cmd
	string cmd2
	KelvinoxSetPort()
	cmd2="VDTwrite2 /o=3 \"@5"+cmd+"\\r\""
	execute (cmd2)
	cmd2="VDTread2 /o=3 junkstr"
	execute (cmd2)
end	

Function Kelvinox_command2(cmd)
// Sometimes the reading data is not successful and the data is still left in the buffer of fridge. 
// This will mess up the program, and will even cause the fridge warming up.
// This function reads the buffer repeatly to make sure that all data is read out.
// The final command (attempted read on empty buffer) times out after 0.1s.
	string cmd
	string cmd2, result
	SVAR junkstr
	NVAR V_VDT
	KelvinoxSetPort()
	cmd2="VDTwrite2 /o=3 \"@5"+cmd+"\\r\""
	execute (cmd2)
	do
		cmd2="VDTread2 /O=0.1/Q junkstr"
		execute (cmd2)
		if(V_VDT>0)
			result=junkstr
		else
			break
		endif
	while(1)
	junkstr=result // finally, store the last non-timed-out result.
end	

/// Upon failure, returns false rather than aborting.
Function ILM_command(cmd)
	string cmd
	string cmd2
	KelvinoxSetPort()
	cmd2="VDTwrite2 /o=3 \"@6"+cmd+"\\r\""
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
end

function CanReachILM()
	return ILM_command("V")
end

Function KelvinoxGetStatus()
	SVAR junkstr
	NVAR temp_sorb, temp_1K, temp_mix, power_mix, power_still, power_sorb, Pres_P1, Pres_P2, Pres_G1, Pres_G2, Pres_G3
	NVAR Local_status, Pump_He3, Pump_He4, Pump_Roots, TempControl_Sorb, TempControl_MixCh
	NVAR Valve_V1, Valve_V1A, Valve_V2, Valve_V2A, Valve_V3, Valve_V4, Valve_V5, Valve_V4A, Valve_V5A, Valve_V6, Valve_V7,Valve_V8, Valve_V9, Valve_V10, Valve_V11A, Valve_V11B, Valve_V12A, Valve_V12B, Valve_V13A, Valve_V13B, Valve_V14, Valve_NV
	NVAR Valve_V6moving, Valve_NVmoving, Valve_V12Amoving
	variable statuscode, mixrange, sorbstatus
	
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
	
	//read Mix power range
	Kelvinox_command("X")
	mixrange=str2num(junkstr[20])
	if(str2num(junkstr[3])==0)
		mixrange=0
	endif
	PopupMenu /z Mixch_range,win=Kelvinox,mode=mixrange+1
	Kelvinox_PopMenuProc("Mixch_range", mixrange+1,"")
	power_mix=power_mix/1000*10^(mixrange-1)
	
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
	
	SVAR KelvinoxTimeStamp
	KelvinoxTimeStamp = date() + " " + time()
	NVAR ILM_Active
	if(ilm_active)
		ILMGetLevel()
	endif
	return 0	// Tell Igor to continue calling background task.
End

Function ILMGetLevel()
	SVAR junkstr
	NVAR level_He, level_N2
	SVAR ILM_Rate
	NVAR ILM_Active
	
	if(! ILM_command("X"))
		ILM_Active = 0
		abort "Cannot read level - ILM not turned on or not connected."
	endif
	string status=junkstr

	if(str2num(status[1])==2)
		ILM_command("R1")
		level_He=str2num(junkstr[1,6])/10
		Valdisplay /z ilmHe win=Kelvinox, format="%.1f"
	else
		Valdisplay /z ilmHe win=Kelvinox, format="Err"
		level_He=nan
	endif

	if(str2num(status[2])==1)
		ILM_command("R2")
		level_N2=str2num(junkstr[1,6])/10
		Valdisplay /z ilmN2 win=Kelvinox, format="%.1f"
	else
		Valdisplay /z ilmN2 win=Kelvinox, format="Err"
		level_N2=nan
	endif

	variable herate
	sscanf status[5,6], "%x",herate
	if(herate & 2)
		PopupMenu /z LevelRateSelector,win=Kelvinox,mode=1,disable=0
	elseif(herate & 4)
		PopupMenu /z LevelRateSelector,win=Kelvinox,mode=2,disable=0
	endif
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
			break
		case "V12A":
			Kelvinox_command("H"+num2str(round(Value*10))) // Value in percent open
			Valve_V12A=Value
			break
		case "NV":
			Kelvinox_command("N"+num2str(round(Value*10))) // Value in percent open
			Valve_NV=Value
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
	Local_status=Value
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
	NewPanel /W=(386,136,1126,648)
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 496,300,496,365
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 80,454,319,454
	SetDrawEnv linethick= 2,linefgc= (0,0,65280)
	DrawRect 140,444,205,466
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 80,376,319,376
	SetDrawEnv linethick= 2,linefgc= (0,0,65280)
	DrawRect 140,366,205,388
	SetDrawEnv fillpat= 0,fillfgc= (60928,60928,60928)
	DrawRect 23,29,392,486
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 79,58,79,454
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 318,58,318,454
	DrawLine 193,92,318,92
	DrawLine 428,68,428,68
	SetDrawEnv fsize= 18,fstyle= 1,textrgb= (0,0,65280)
	DrawText 167,27,"Helium 3"
	SetDrawEnv fsize= 16,fstyle= 1,textrgb= (0,0,65280)
	DrawText 288,53,"Pumping"
	SetDrawEnv fsize= 16,fstyle= 1,textrgb= (0,0,65280)
	DrawText 34,53,"Condenser"
	SetDrawEnv linethick= 2,linefgc= (0,0,65280)
	DrawRect 299,191,349,213
	SetDrawEnv gstart
	SetDrawEnv fsize= 16,fstyle= 1,textrgb= (0,0,65280)
	DrawText 302,212,"Pump"
	SetDrawEnv gstop
	DrawRect 451,202,451,202
	DrawRect 451,201,451,201
	DrawRect 436,194,436,194
	SetDrawEnv fstyle= 1,textrgb= (0,0,65280)
	DrawText 144,384,"ColdTrap1"
	SetDrawEnv fstyle= 1,textrgb= (0,0,65280)
	DrawText 144,462,"ColdTrap2"
	SetDrawEnv fillpat= 0
	DrawRect 403,208,629,439
	SetDrawEnv fsize= 18,fstyle= 1,textrgb= (0,0,65280)
	DrawText 488,205,"Auxiliary"
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 552,361,552,419
	SetDrawEnv gstart
	SetDrawEnv linethick= 2,linefgc= (0,0,65280)
	DrawRect 517,405,582,427
	SetDrawEnv fsize= 16,fstyle= 1,textrgb= (0,0,65280)
	DrawText 528,425,"Pump"
	SetDrawEnv gstop
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 495,361,605,361
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 483,300,508,300
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 605,233,605,353
	SetDrawEnv fsize= 16,fstyle= 1,textrgb= (0,0,65280)
	DrawText 592,230,"IVC"
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 593,232,618,232
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 306,57,331,57
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 67,57,92,57
	DrawLine 79,121,276,121
	DrawLine 120,121,120,244
	DrawLine 275,121,275,249
	DrawLine 160,121,160,243
	DrawLine 231,121,231,313
	SetDrawEnv gstart
	SetDrawEnv linethick= 2,linefgc= (0,0,65280)
	DrawRect 217,192,256,211
	SetDrawEnv fstyle= 1,textrgb= (0,0,65280)
	DrawText 220,208,"Dump"
	SetDrawEnv gstop
	DrawLine 231,313,318,313
	DrawLine 193,126,193,240
	DrawLine 193,100,193,117
	DrawLine 201,236,253,236
	DrawLine 253,236,253,313
	DrawLine 253,248,276,248
	DrawLine 121,205,143,205
	DrawLine 143,205,143,312
	DrawLine 144,311,216,311
	DrawLine 216,311,216,375
	DrawLine 161,235,161,312
	DrawLine 143,311,143,360
	DrawLine 143,360,210,360
	DrawLine 210,360,210,373
	DrawLine 210,381,210,455
	DrawLine 161,192,211,192
	DrawLine 210,192,210,216
	DrawLine 211,215,232,215
	DrawLine 275,186,319,186
	DrawLine 424,338,496,338
	DrawLine 424,232,424,339
	DrawLine 417,231,432,231
	DrawLine 556,289,556,339
	DrawLine 549,289,564,289
	DrawLine 556,338,606,338
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 468,28,"Temp"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 629,28,"Power"
	SetDrawEnv fstyle= 1
	DrawText 706,52,"mW"
	SetDrawEnv fstyle= 1
	DrawText 706,83,"mW"
	SetDrawEnv fstyle= 1
	DrawText 706,114,"uW"
	SetDrawEnv fstyle= 1
	DrawText 543,53,"K"
	SetDrawEnv fstyle= 1
	DrawText 543,83,"K"
	SetDrawEnv fstyle= 1
	DrawText 543,113,"mK"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 639,171,"Temp Control"
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 483,280,508,280
	SetDrawEnv fsize= 16,fstyle= 1,textrgb= (0,0,65280)
	DrawText 470,301,"1KPot"
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 496,233,496,278
	SetDrawEnv linethick= 3,linefgc= (0,0,65280)
	DrawLine 483,232,508,232
	SetDrawEnv fillpat= 0
	DrawPoly 253,264,1,1,{49,336,42,347,57,347,49,336}
	DrawLine 247,264,260,264
	SetDrawEnv fillpat= 0
	DrawPoly 196,185,1,1,{40,322,40,338,50,329,40,322}
	DrawLine 205,186,205,201
	SetDrawEnv fillfgc= (60928,60928,60928)
	DrawRect 405,446,736,501
	SetDrawEnv fsize= 18,fstyle= 1,textrgb= (0,0,65280)
	DrawText 413,474,"Level Meter"
	ValDisplay Pressure_G2,pos={274,269},size={72,21},title="G2",fSize=16
	ValDisplay Pressure_G2,format="%3.1f",frame=4,fStyle=1
	ValDisplay Pressure_G2,limits={0,0,0},barmisc={0,1000},value= #"Pres_G2"
	ValDisplay Pressure_G1,pos={35,269},size={72,21},title="G1",fSize=16
	ValDisplay Pressure_G1,format="%3.1f",frame=4,fStyle=1
	ValDisplay Pressure_G1,limits={0,0,0},barmisc={0,1000},value= #"Pres_G1"
	ValDisplay Pressure_P1,pos={156,81},size={72,21},title="P1",fSize=16,frame=4
	ValDisplay Pressure_P1,fStyle=1,limits={0,1,0},barmisc={0,1000}
	ValDisplay Pressure_P1,value= #"Pres_P1"
	Button Get_status,pos={421,122},size={100,25},proc=ButtonProc_Kelvinox,title="Get Status"
	Button Get_status,fSize=16,fStyle=1
	SetVariable Valve6,pos={299,149},size={50,22},disable=2,title=" ",fSize=16
	SetVariable Valve6,format="%.1f",fStyle=1,limits={0,99.9,0.1},value= Valve_V6
	Button button_V6,pos={305,125},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="V6"
	Button button_V12A,pos={98,367},size={35,20},disable=2,proc=ButtonProc_Kelvinox,title="V12A"
	SetVariable Valve12A,pos={84,388},size={49,22},disable=2,title=" ",fSize=16
	SetVariable Valve12A,format="%.1f",fStyle=1
	SetVariable Valve12A,limits={0,99.9,0.1},value= Valve_V12A
	Button button_V4A,pos={482,353},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="V4A"
	ValDisplay Pressure_G3,pos={453,312},size={72,21},title="G3",fSize=16
	ValDisplay Pressure_G3,format="%.1f",frame=4,fStyle=1
	ValDisplay Pressure_G3,limits={0,0,0},barmisc={0,1000},value= #"Pres_G3"
	ValDisplay Pressure_P2,pos={506,377},size={72,21},title="P2",fSize=16,frame=4
	ValDisplay Pressure_P2,fStyle=1,limits={0,0,0},barmisc={0,1000}
	ValDisplay Pressure_P2,value= #"Pres_P2"
	ValDisplay V4Astatus,pos={491,339},size={10,10},frame=2
	ValDisplay V4Astatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay V4Astatus,value= #"Valve_V4A"
	ValDisplay V2status,pos={116,148},size={10,10},frame=2
	ValDisplay V2status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V2status,value= #"Valve_V2"
	Button button_V2,pos={108,163},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="V2"
	ValDisplay V3status,pos={155,148},size={10,10},frame=2
	ValDisplay V3status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V3status,value= #"Valve_V3"
	Button button_V3,pos={147,163},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="V3"
	Button button_V4,pos={218,163},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="V4"
	ValDisplay V4status,pos={226,148},size={10,10},frame=2
	ValDisplay V4status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V4status,value= #"Valve_V4"
	ValDisplay V7status,pos={116,210},size={10,10},frame=2
	ValDisplay V7status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V7status,value= #"Valve_V7"
	Button button_V7,pos={108,225},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="V7"
	Button button_V8,pos={148,225},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="V8"
	ValDisplay V8status,pos={156,210},size={10,10},frame=2
	ValDisplay V8status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V8status,value= #"Valve_V8"
	ValDisplay V5status,pos={270,148},size={10,10},frame=2
	ValDisplay V5status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V5status,value= #"Valve_V5"
	Button button_V5,pos={262,163},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="V5"
	ValDisplay V9status,pos={227,265},size={10,10},frame=2
	ValDisplay V9status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V9status,value= #"Valve_V9"
	Button button_V9,pos={219,280},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="V9"
	ValDisplay V10status,pos={271,222},size={10,10},frame=2
	ValDisplay V10status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V10status,value= #"Valve_V10"
	Button button_V10,pos={263,237},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="V10"
	ValDisplay V14status,pos={188,210},size={10,10},frame=2
	ValDisplay V14status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V14status,value= #"Valve_V14"
	Button button_V14,pos={180,225},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="V14"
	ValDisplay V11status,pos={212,319},size={10,10},frame=2
	ValDisplay V11status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V11status,value= #"Valve_V11A"
	Button button_V11A,pos={200,334},size={36,20},disable=2,proc=ButtonProc_Kelvinox,title="V11A"
	ValDisplay V11stat01,pos={139,319},size={10,10},frame=2
	ValDisplay V11stat01,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V11stat01,value= #"Valve_V11B"
	Button button_V11B,pos={127,334},size={36,20},disable=2,proc=ButtonProc_Kelvinox,title="V11B"
	ValDisplay V13Astatus,pos={249,371},size={10,10},frame=2
	ValDisplay V13Astatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay V13Astatus,value= #"Valve_V13A"
	Button button_V13A,pos={265,365},size={36,20},disable=2,proc=ButtonProc_Kelvinox,title="V13A"
	Button button_V13B,pos={265,446},size={36,20},disable=2,proc=ButtonProc_Kelvinox,title="V13B"
	ValDisplay V13Bstatus,pos={249,450},size={10,10},frame=2
	ValDisplay V13Bstatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay V13Bstatus,value= #"Valve_V13B"
	Button button_V12B,pos={98,445},size={35,20},disable=2,proc=ButtonProc_Kelvinox,title="V12B"
	ValDisplay V12Bstatus,pos={85,450},size={10,10},frame=2
	ValDisplay V12Bstatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay V12Bstatus,value= #"Valve_V12B"
	ValDisplay V5Astatus,pos={601,339},size={10,10},frame=2
	ValDisplay V5Astatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V5Astatus,value= #"Valve_V5A"
	Button button_V5A,pos={593,353},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="V5A"
	Button button_V1A,pos={409,285},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="V1A"
	ValDisplay V1Astatus,pos={419,272},size={10,10},frame=2
	ValDisplay V1Astatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay V1Astatus,value= #"Valve_V1A"
	Button button_V2A,pos={543,314},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="V2A"
	ValDisplay V2Astatus,pos={551,299},size={10,10},frame=2
	ValDisplay V2Astatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (65280,30464,21760)
	ValDisplay V2Astatus,value= #"Valve_V2A"
	ValDisplay V1status,pos={74,74},size={10,10},frame=2
	ValDisplay V1status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay V1status,value= #"Valve_V1"
	Button button_V1,pos={65,88},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="V1"
	Button button_He3,pos={657,255},size={75,25},disable=2,proc=ButtonProc_Kelvinox,title="He3 Pump"
	Button button_He3,fSize=14,fStyle=0
	Button button_He4,pos={657,290},size={75,25},disable=2,proc=ButtonProc_Kelvinox,title="He4 Pump"
	Button button_He4,fSize=14,fStyle=0
	Button button_Roots,pos={657,327},size={75,25},disable=2,proc=ButtonProc_Kelvinox,title="Roots"
	Button button_Roots,fSize=14,fStyle=0
	ValDisplay He3_Pump_status,pos={643,263},size={10,10},frame=2
	ValDisplay He3_Pump_status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay He3_Pump_status,value= #"Pump_He3"
	ValDisplay He4_Pump_status,pos={643,298},size={10,10},frame=2
	ValDisplay He4_Pump_status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay He4_Pump_status,value= #"Pump_He4"
	ValDisplay Roots_Pump_status,pos={643,334},size={10,10},frame=2
	ValDisplay Roots_Pump_status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay Roots_Pump_status,value= #"Pump_Roots"
	Button button_Local,pos={657,377},size={75,25},proc=ButtonProc_Kelvinox,title="Local"
	Button button_Local,fSize=14,fStyle=0
	Button button_Remote,pos={657,413},size={75,25},proc=ButtonProc_Kelvinox,title="Remote"
	Button button_Remote,fSize=14,fStyle=0
	ValDisplay Remotestatus,pos={643,420},size={10,10},frame=2
	ValDisplay Remotestatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay Remotestatus,value= #"!Local_status"
	ValDisplay Localstatus,pos={643,386},size={10,10},frame=2
	ValDisplay Localstatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay Localstatus,value= #"Local_status"
	SetVariable tempR1,pos={469,36},size={70,22},disable=2,title=" ",fSize=16
	SetVariable tempR1,fStyle=1,limits={0,inf,0.1},value= temp_sorb
	SetVariable tempR2,pos={469,65},size={70,22},disable=2,title=" ",fSize=16
	SetVariable tempR2,fStyle=1,limits={0,inf,1},value= temp_1K
	SetVariable tempR3,pos={469,94},size={70,22},disable=2,title=" ",fSize=16
	SetVariable tempR3,fStyle=1,limits={0,2000,0.1},value= temp_mix
	SetVariable powerR6,pos={634,36},size={70,22},disable=2,title=" ",fSize=16
	SetVariable powerR6,fStyle=1,limits={0,1999,1},value= power_sorb
	SetVariable powerR5,pos={634,65},size={70,22},disable=2,title=" ",fSize=16
	SetVariable powerR5,fStyle=1,limits={0,1999,0.1},value= power_still
	SetVariable powerR4,pos={635,94},size={70,22},disable=2,title=" ",fSize=16
	SetVariable powerR4,fStyle=1,limits={0,2000,1},value= power_mix
	Button Set_status,pos={420,153},size={170,25},proc=ButtonProc_Kelvinox,title="Show Setpoints"
	Button Set_status,fSize=16,fStyle=1
	PopupMenu Mixch_range,pos={572,120},size={118,27},disable=2,proc=Kelvinox_PopMenuProc,title="Range:"
	PopupMenu Mixch_range,fSize=16,fStyle=1
	PopupMenu Mixch_range,mode=1,popvalue="OFF",value= #"\"OFF;2uW;20uW;200uW;2mW;20mW\""
	Button button_Sorb,pos={657,176},size={75,25},disable=2,proc=ButtonProc_Kelvinox,title="Sorb"
	Button button_Sorb,fSize=14,fStyle=0
	ValDisplay SorbTempControl,pos={643,185},size={10,10},frame=2
	ValDisplay SorbTempControl,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay SorbTempControl,value= #"tempcontrol_Sorb"
	ValDisplay MixChTempControl,pos={643,215},size={10,10},frame=2
	ValDisplay MixChTempControl,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay MixChTempControl,value= #"Tempcontrol_MixCh"
	Button button_MixCh,pos={657,208},size={75,25},disable=2,proc=ButtonProc_Kelvinox,title="Mix CH"
	Button button_MixCh,fSize=14,fStyle=0
	Button button_NV,pos={481,255},size={30,20},disable=2,proc=ButtonProc_Kelvinox,title="N/V"
	SetVariable ValveNV,pos={514,254},size={50,22},disable=2,title=" ",fSize=16
	SetVariable ValveNV,format="%.1f",fStyle=1,limits={0,99.9,0.1},value= Valve_NV
	Button ClearMem,pos={528,121},size={23,26},proc=ButtonProc_Kelvinox,title="C"
	Button ClearMem,fSize=16,fStyle=1
	Button ShowSorbTemp,pos={398,36},size={70,25},proc=ButtonProc_Kelvinox,title="Sorb:"
	Button ShowSorbTemp,fSize=16,fStyle=1
	Button Show1KPotTemp,pos={398,64},size={70,25},proc=ButtonProc_Kelvinox,title="1K Pot:"
	Button Show1KPotTemp,fSize=16,fStyle=1
	Button ShowMixCHTemp,pos={398,93},size={70,25},proc=ButtonProc_Kelvinox,title="Mix CH:"
	Button ShowMixCHTemp,fSize=16,fStyle=1
	Button ShowSorbPower,pos={563,36},size={70,25},proc=ButtonProc_Kelvinox,title="Sorb:"
	Button ShowSorbPower,fSize=16,fStyle=1
	Button ShowStillPower,pos={563,64},size={70,25},proc=ButtonProc_Kelvinox,title="Still:"
	Button ShowStillPower,fSize=16,fStyle=1
	Button ShowMixCHPower,pos={564,93},size={70,25},proc=ButtonProc_Kelvinox,title="Mix CH:"
	Button ShowMixCHPower,fSize=16,fStyle=1
	ValDisplay ilmHe,pos={567,452},size={85,21},title="He:",fSize=16,format="(%.1f)"
	ValDisplay ilmHe,frame=4,fStyle=1,limits={0,0,0},barmisc={0,1000}
	ValDisplay ilmHe,value= #"level_He"
	ValDisplay ilmN2,pos={567,474},size={85,21},title="N2:",fSize=16,format="(%.1f)"
	ValDisplay ilmN2,frame=4,fStyle=1,limits={0,0,0},barmisc={0,1000}
	ValDisplay ilmN2,value= #"level_N2"
	CheckBox ILMActive,pos={413,475},size={119,19},proc=ILMCheckProc,title="Is turned on?"
	CheckBox ILMActive,fSize=16,fStyle=1,variable= ILM_Active
	PopupMenu LevelRateSelector,pos={654,453},size={57,21},disable=2,proc=ILMPopMenuProc
	PopupMenu LevelRateSelector,mode=1,popvalue="Fast",value= #"\"Fast;Slow\""
	TitleBox TimeStamp,pos={6,491},size={158,16},fSize=14,frame=0
	TitleBox TimeStamp,variable= KelvinoxTimeStamp,anchor= LB
	Button lockButton,pos={154,32},size={100,30},proc=ButtonProc_Kelvinox,title="Locked"
	Button lockButton,font="Arial",fSize=18,fStyle=1,fColor=(48896,65280,48896)
	ValDisplay V6status,pos={313,108},size={10,10},frame=2
	ValDisplay V6status,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,65280,0)
	ValDisplay V6status,value= #"1"
	ValDisplay V12Astatus,pos={85,372},size={10,10},frame=2
	ValDisplay V12Astatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,0,0)
	ValDisplay V12Astatus,value= #"1"
	ValDisplay NVstatus,pos={491,240},size={10,10},frame=2
	ValDisplay NVstatus,limits={0,1,0},barmisc={0,0},mode= 1,highColor= (0,0,0)
	ValDisplay NVstatus,value= #"1"
EndMacro


