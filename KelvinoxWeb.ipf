#pragma rtGlobals=3		// Use modern global access method and strict wave access

function GetMixChTemp()
	//String url = "http://qdot-server.phas.ubc.ca:8081/webService/logger.php?action=getCurrentValue"
	//url = url + "&loggable_name=ighn_temp_mix&yes_calc=0"
	//String response = FetchURL(url)
	//return str2num(response)
	String url = "http://qdot-server.phas.ubc.ca:8081/webService/logger.php?action=getCurrentState"
	url = url + "&loggable_category_id=2"
	String response = FetchURL(url)
	//print response
	return GetCurrentStatus(response, "ighn_temp_mix")
end

function GetCurrentStatus(workingstr, loggable_name)
	string workingstr, loggable_name
	string keyname
	variable numvals, i
	numvals = ItemsInList(workingstr)
	Make/O/T/N=(numvals) textWave= StringFromList(p,workingstr)
	for (i=0; i<numvals; i+=1)
		keyname = stringfromlist(0,textwave[i],"=")
		if (stringmatch(keyname, loggable_name))
			return str2num(stringfromlist(1,textwave[i],"="))
		endif
	endfor
end

function SendIGHCommand(command)
	string command
	string response
	String url = "http://qdot-server.phas.ubc.ca:8081/webService/commandmanager.php?action=createCommand"
	url = url + "&port_id=2&cmd=" + command
	response = FetchURL(url)
	// print response
end

function GetP2()
	//String url = "http://qdot-server.phas.ubc.ca:8081/webService/logger.php?action=getCurrentValue"
	//url = url + "&loggable_name=ighn_temp_mix&yes_calc=0"
	//String response = FetchURL(url)
	//return str2num(response)
	String url = "http://qdot-server.phas.ubc.ca:8081/webService/logger.php?action=getCurrentState"
	url = url + "&loggable_category_id=2"
	String response = FetchURL(url)
	//print response
	return GetCurrentStatus(response, "ighn_pres_p2")
end

function GetNV()
	//String url = "http://qdot-server.phas.ubc.ca:8081/webService/logger.php?action=getCurrentValue"
	//url = url + "&loggable_name=ighn_temp_mix&yes_calc=0"
	//String response = FetchURL(url)
	//return str2num(response)
	String url = "http://qdot-server.phas.ubc.ca:8081/webService/logger.php?action=getCurrentState"
	url = url + "&loggable_category_id=2"
	String response = FetchURL(url)
	//print response
	return GetCurrentStatus(response, "ighn_nv")
end

function checkP2(lowerlimit)
variable lowerlimit
IGHRemoteMode()
variable currentP2, currentNV
string str
currentP2=getp2(); print currentP2
if (currentP2<lowerlimit)
currentNV=getnv()
str=num2str(currentNV*10+1)
str="N"+str
	SendIGHCommand(str)
	str=" adjusted NV to:"+str; print str
endif
return currentP2
end

function reduceP2(upperlimit)
variable upperlimit
IGHRemoteMode()
variable currentP2, currentNV
string str
currentP2=getp2(); print currentP2
if (currentP2>upperlimit)
currentNV=getnv()
str=num2str(currentNV*10-2)
str="N"+str
	SendIGHCommand(str)
	str=" adjusted NV to:"+str; print str
endif
return currentP2
end

function IGHRemoteMode()
	SendIGHCommand("C3")
end

function IGHRootsON()
	IGHRemoteMode()
	SendIGHCommand("P44")
	
end

function IGHRootsOFF()
	IGHRemoteMode()
	SendIGHCommand("P45")
end






//// all of the below are stolen from Kelvinox Procedures.ipf and adapted for KelvinoxWeb.ipf ////

// Power is in microwatt units.
Function IGHCalcPower(temp, roots)
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
Function IGHSetMixChPower(power)
	variable power
	variable exponent
	if(power>0)
		exponent=floor(log(power/2))+2
		IGHRemoteMode()
		SendIGHCommand("E"+num2str(exponent))	//set exponent for mix power range
		SendIGHCommand("M"+num2str(floor(power*10^(4-exponent))))	//set power
	endif
end

Function IGHApproachSetPoint(temp,roots)
	variable temp,roots
	NVAR temp_mix, power_mix
	SVAR junkstr
	variable temp_old=temp_mix, temp_origin=temp_mix, Dtemp,prefactor=2
	IGHRemoteMode()
	SendIGHCommand("A1")		//fixed heater power
	do
		temp_mix =  GetMixChTemp()
		if((temp_mix-temp_old)*(temp-temp_mix)<=0)
			if((temp_mix-temp_old)*(temp_mix-temp_origin)<=0)
				prefactor*=1.05
			endif
		endif
		temp_old=temp_mix
		Dtemp=temp-temp_mix
		power_mix=IGHCalcPower(temp+prefactor*Dtemp,roots)
		IGHSetMixChPower(power_mix)
		sleep/s 1
	while(abs(temp-temp_mix)>1)
	
	IGHRemoteMode()
	SendIGHCommand("T"+num2str(temp*10))
	SendIGHCommand("A2")	//temperature control
	if(temp<=250)
		IGHRemoteMode()
		SendIGHCommand("i10")
		SendIGHCommand("p15")
	elseif(temp<=500)
		IGHRemoteMode()
		SendIGHCommand("i10")
		SendIGHCommand("p30")
	else
		IGHRemoteMode()
		SendIGHCommand("i30")
		SendIGHCommand("p100")
	endif
end

Function IGHTempToSetPoint(setpoint)	//judge whether curr_temp is near setpoint
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

Function KelvinoxWebSetMixChTemp(temp)	//temp in unit of mK
// NOTE: only work for temp<800mK and well functioning fridge.
	variable temp
	variable power, roots,Dtemp,i=0,tt=0
	NVAR temp_mix, power_mix
	SVAR junkstr
	
	if(temp<=300)
		IGHRootsON()	//low temperature, turn on Roots pump
		roots=1
	else
		IGHRootsOFF()	//high temperature, turn off Roots pump
		roots=0
	endif

	temp_mix =  GetMixChTemp()
	IGHRemoteMode()
	SendIGHCommand("A1")		//fixed heater power
	if(1.02*temp<temp_mix)
		SendIGHCommand("M0")	// zero power
		power_mix=0
		
	elseif(0.98*temp>temp_mix)
		power=IGHCalcPower(temp, roots)
		if(1.5*power<20000)
			power_mix=1.6*power
			IGHSetMixChPower(power_mix)
		else
			power_mix=19990
			IGHSetMixChPower(power_mix)
		endif
	endif
	
	Dtemp=1.1^(abs(temp-temp_mix)/50-1)*0.1*temp
	
	do
		temp_mix =  GetMixChTemp()
		sleep/s 1
		i+=1
	while(abs(temp-temp_mix)>Dtemp)		// Fast approaching setpoint
	
	 //// good up to here ////
	
	i=0
	//Try to stablize at setpoint

	IGHApproachSetPoint(temp,roots)
//	Dtemp=sqrt(temp)/2
//	variable npoint
//	if(temp<=500)
//		npoint=180
//	else
//		npoint=480
//		
//	endif
//	do
//		IGHRemoteMode()
//		temp_mix =  GetMixChTemp()
//		
//		if(abs(temp-temp_mix)>Dtemp)
//			IGHApproachSetPoint(temp,roots)
//		else
//			if(IGHTempToSetPoint(temp))
//				i+=1
//				
//			else
//				i=0
//			endif
//		endif		
//		sleep/s 1
//		print i
//		print npoint
//	while(i<npoint)
end

//
//for P: https://qdot-server.phas.ubc.ca:8080/webService/commandmanager.php?action=createCommand&port_id=2&cmd=R30 
//for I: https://qdot-server.phas.ubc.ca:8080/webService/commandmanager.php?action=createCommand&port_id=2&cmd=R31
//
//put the response into the command ID below
//
//https://qdot-server.phas.ubc.ca:8080/webService/commandmanager.php?action=getCommandResponse&command_id=30676&timeout=2
//
//To see what the current values are:
//
//For Tcontrol up to 200mK, P=0.00015 and I=0.0001 worked great

macro changePID()
 IGHRemoteMode()

	SendIGHCommand("p0015")  // this is in units of 0.1% of heater range full power
		SendIGHCommand("i0010") // this is in units of 0.1minute
		
		// good values for up to 200mK
			//SendIGHCommand("p0015")  // this is in units of 0.1% of heater range full power
		//SendIGHCommand("i0010") // this is in units of 0.1minute

	
endmacro