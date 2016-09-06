#pragma rtGlobals=1	// Use modern global access method

// Driver for controling the Lakeshore, via an intermidiate server
// Set the system in SetSsystem().
// Communicates with server over http.
// Adding gui for temperature control
// Procedure written by Christian Olsen 2016-04-xx

//// Initiate Lakeshore ////

function InitLakeshore()
	SetSystem("bfs") // Set the correct fridge. Blue Fors small = bfs, Blue Fors big = bfb
	CreateGlobal() // Create global variables for GUI
	UpdateCurrentValues() // Get current Lakeshore state
	SetPointTemp(GetTemp("mc")*1000) // Set temp control setpoint to current MC temp
	SetControlParameters() // Set temp control parameters. Set parameters explicitly if defualt is not desiered
	TempSequence(preset="normal") // Set temperature reading to normal mode
	// Build window
	dowindow/k LakeShore_Window
	execute("LakeShore_Window()")
end

function CreateGlobal()
	make/o heatertable = {{0,1,2,3,4,5,6,7,8},{0,0.0316,0.1,0.316,1,3.16,10,31.6,100}} // Convert heater values
	make/o/t controlloop = {"Closed Loop PID","Zone Tuning","Open Loop","Off"}
	variable/g p_value // P value (PID)
	variable/g i_value // I value (PID)
	variable/g d_value // D value (PID)
	variable/g temp_set // Temperature setpoint for PID control (in mK)
	variable/g ramp_rate // Ramp rate used in PID (in mK/min)
	variable/g led_val // control variable for "LED"
	variable/g pid_mode // control variable for Control mode
	variable/g ramp_stat // control variable for Ramp
	variable/g control_channel // control variable for PID control
	variable/g filter_channel // control variable for control channel (filter)
	variable/g units_control = 1 // control variable for K/Ohm unit (set to K)
	variable/g delay_control = 1 // 1 s (only used in Auotscan)
	variable/g cp_control = 1 // control variable for heater unit (set to current)
	variable/g heaterrange_control //control variable for MC heater range (set to Off)
	variable/g heaterres_control //control variable for total heater resistance (in Ohm)
	variable/g mcheat //control variable for MC heater output (in mA)
	variable/g stillheat //control variable for Still heater output (in mW)
	string/g temp_seq //Temperature reading sequence
	variable/g magnetheater_control //Magnet heater state
end

function SetSystem(frigde)
	string frigde
	string/g readsql, writesql, systemid
	
	strswitch(frigde)
		case "bfs":
			readsql = "4"
			writesql = "3"
			systemid = "bfs"
			break
		case "bfb":
			readsql = "NaN"
			writesql = "NaN"
			systemid = "bfb"
			abort "System is not setup. Can't be used!"
			break
		case "igh":
			readsql = "2"
			writesql = "2"
			systemid = "ighn"
			break
		default:
			abort "Not a valid system. Blue Fors LD250 = bfs, Blue Fors LD400 = bfb, IGH = ???" // FIX
	endswitch
end

function SetControlParameters([channel,filter,units,delay,cp,heaterrange_max,heaterres])
	// set channel to control channel
	variable channel,filter,units,delay,cp,heaterres,heaterrange_max
	string command, url
	nvar control_channel,filter_channel,units_control,delay_control,cp_control,heaterres_control
	
	if(ParamIsDefault(channel))
		channel = control_channel // control channel
	endif
	if(ParamIsDefault(filter))
		filter = filter_channel // Filtered channel
	endif
	if(ParamIsDefault(units))
		units = units_control // Kelvin
	endif
	if(ParamIsDefault(delay))
		delay = delay_control // seconds (only used in AutoScan mode)
	endif
	if(ParamIsDefault(cp))
		cp = cp_control // current
	endif
	if(ParamIsDefault(heaterrange_max))
		heaterrange_max = 8 // 100 mA
	endif
	if(ParamIsDefault(heaterres))
		heaterres = heaterres_control
	endif
	
	sprintf command,"CSET %d,%d,%d,%d,%d,%d,%d", channel, filter, units, delay, cp, heaterrange_max, heaterres
	url = CreateURL("createCommand",writeurl = "1", cmd = command)
	WriteLakeShore(url)
	control_channel = channel
	filter_channel = filter
	units_control = units
	delay_control = delay
	cp_control = cp
	heaterres_control = heaterres
	PopupMenu ControlChannel,mode=channel
end

function UpdateCurrentValues()
	// Get control mode, control channel, temp setpoint, ramp values, mc heater range,
	// mc heater output, still heater output and pid parameters
	string dump0,dump1,dump2,dump6
	variable dump3,dump4,dump5,dump7
	
	dump0 = GetControlParameters() // Update control variables
	dump1 = GetRamp() // Update Ramp status
	dump2 = GetControlMode() // Update Control mode
	dump3 = GetHeaterRange() // Update current heater range
	dump4 = GetMCHeater() // Update current MC heat
	dump5 = GetStillHeater() // Update current Still heat
	dump6 = GetPIDParameters() // Update PID parameters
	dump7 = GetTempSetpoint() // Update temperature setpoint
end

//// Change temperature recording sequence ////

function TempSequence([preset,temp_50k,temp_4k,temp_magnet,temp_still,temp_mc])
	// Choose a preset, e.g. cooldown, normal, temp_control or warm_up. Or set how often they should be read in s
	string preset
	variable temp_50k,temp_4k,temp_magnet,temp_still,temp_mc
	variable set_50k,set_4k,set_magnet,set_still,set_mc
	svar temp_seq
	string url,command
	
	if(ParamIsDefault(temp_50k) && ParamIsDefault(temp_4k) && ParamIsDefault(temp_magnet) && ParamIsDefault(temp_still) && ParamIsDefault(temp_mc))
		strswitch(preset)
			case "cooldown":
				set_50k = 10
				set_4k = 10
				set_magnet = 10
				set_still = 30
				set_mc = 60
				temp_seq = "Cooldown"
				break
			case "normal":
				set_50k = 0
				set_4k = 0
				set_magnet = 0
				set_still = 0
				set_mc = 0
				temp_seq = "Normal"
				break
			case "temp_control":
				set_50k = 120
				set_4k = 120
				set_magnet = 20
				set_still = 100
				set_mc = 1
				temp_seq = "Temperature Control"
				break
			case "warm_up":
				set_50k = 10
				set_4k = 10
				set_magnet = 10 
				set_still = 30
				set_mc = 30
				temp_seq = "Warm Up"
				break
			default:
				print "Choose between: cooldown,normal,temp_control and warm_up. Setting to normal!"
				set_50k = 0
				set_4k = 0
				set_magnet = 0
				set_still = 0
				set_mc = 0
				temp_seq = "Normal"
				break
		endswitch
	elseif(ParamIsDefault(preset))
		set_50k = temp_50k
		set_4k = temp_4k
		set_magnet = temp_magnet
		set_still = temp_still
		set_mc = temp_mc
		temp_seq = "Custom"
	else
		abort "Select a preset or give all stages a reading frequency"
	endif
	sprintf command,"SCANNER %d,%d,%d,%d,%d", set_50k,set_4k,set_magnet,set_still,set_mc
	url = CreateURL("createCommand",writeurl = "1", cmd = command)
	WriteLakeShore(url)
end

//// Get logged values ////

function GetTemp(plate)
	// mc, still, 4k, magnet, 50k
	// Returns temp in K
	string plate
	string response, url, key
	svar readsql = readsql
	svar systemid = systemid
	
	sprintf key,"%s_%s_temp", systemid, plate
	url = CreateURL("getCurrentState",readurl="1")
	response = FetchURL(url)
	return ReadResponseString(response, key)
end

function GetHeatSwitch(heatswitch)
	// still, mc
	// Returns 1 for "on" and 0 for "off"
	string heatswitch
	string response, url, key
	svar readsql = readsql
	svar systemid = systemid
	
	sprintf key,"%s_%s_heatswitch", systemid, heatswitch
	url = CreateURL("getCurrentState",readurl="1")
	response = FetchURL(url)
	return ReadResponseString(response, key)
end

//// Temperature control Set functions ////

function SetControlMode(control_mode)
	// Closed Loop PID = 1, Zone Tuning = 2, Open Loop = 3, Off = 4
	variable control_mode
	string command, url
	nvar led_val, pid_mode,mcheat,ramp_stat
	
	sprintf command,"CMODE %d", control_mode
	url = CreateURL("createCommand",writeurl = "1", cmd = command)
	WriteLakeShore(url)
	PopupMenu ControlMode,mode=control_mode
	if(control_mode == 1)
		led_val = 1
		mcheat = 0
		SetVariable MCheater, disable=2
		Button Rampbutton, disable=0
	elseif(control_mode == 3)
		led_val = 0
		SetVariable MCheater, disable=0
		Button Rampbutton, disable=2
	else
		led_val = 0
		mcheat = 0
		SetVariable MCheater, disable=2
		Button Rampbutton, disable=2
		if(ramp_stat == 1)
			RampTemp("off",0)
			Button Rampbutton, title="\\Z14Start Ramp",fcolor=(0,1000,0)
		endif
	endif
	pid_mode = control_mode
end

function SetPointTemp(temp)
	// set temp in mK
	variable temp
	string command, url
	nvar temp_set
	
	sprintf command, "SETP %g", temp/1000
	url = CreateURL("createCommand",writeurl = "1", cmd = command)
	WriteLakeShore(url)
	temp_set = temp
end

function/s SetHeaterRange(value)
	// Set range in mA
	variable value
	string command, url
	wave heatertable = heatertable
	nvar heaterrange_control
	make/o/n=9 heatervalues, minheater

	heatervalues = heatertable[p][1]
	minheater = abs(heatervalues-value)
	FindValue/v=(wavemin(minheater)) minheater
	sprintf command, "HTRRNG %d", v_value
	url = CreateURL("createCommand",writeurl = "1", cmd = command)
	WriteLakeShore(url)
	heaterrange_control = v_value
	PopupMenu HeaterRange,mode=v_value+1
end

function SetPIDParameters(p,i,d)
	// P = {0.001 1000}, I = {0 10000}, D = {0 2500}
	variable p,i,d
	nvar p_value,i_value,d_value
	string command, url
	if(0.001 <= p && p <= 1000 && 0 <= i && i <= 10000 && 0 <= d && d <= 2500)
		sprintf 	command,"PID %s,%s,%s", num2str(p), num2str(i), num2str(d)
		url = CreateURL("createCommand",writeurl = "1", cmd = command)
		WriteLakeShore(url)
		p_value = p
		i_value = i
		d_value = d
	else
		abort "PID parameters out of range"
	endif
end

function RampTemp(onoff,rate)
	// set onoff to "on/off" and rate in mK/min (max rate = 2000 mK/min)
	variable rate
	string onoff
	string command, url
	variable toggle
	nvar ramp_rate,ramp_stat
	strswitch(onoff)
		case "on":
			ramp_stat = 1
			Button Rampbutton, title="\\Z14Stop Ramp",fcolor=(1000,0,0)
			break
		case "off":
			ramp_stat = 0
			Button Rampbutton, title="\\Z14Start Ramp",fcolor=(0,1000,0)
			break
		default:
			print "Use on or off. Turning ramp off!"
			ramp_stat = 0
			Button Rampbutton, title="\\Z14Start Ramp",fcolor=(0,1000,0)
			break
	endswitch
	
	sprintf command, "RAMP %d,%g", ramp_stat, rate/1000
	url = CreateURL("createCommand",writeurl = "1", cmd = command)
	WriteLakeShore(url)
	ramp_rate = rate
end

function StillHeater(output)
	// output in mW
	variable output
	variable heaterV,procent,fullscale
	string url,command
	nvar stillheat
	
	fullscale = 10 //V
	heaterV = sqrt((output/1000)*150) //V
	procent = heaterV*100/fullscale
	sprintf 	command,"STILL %g", procent
	url = CreateURL("createCommand",writeurl = "1", cmd = command)
	WriteLakeShore(url)
	stillheat = output
end

function MCHeater(output)
	// output in mA
	variable output
	variable fullscale,procent
	string url,command
	wave heatertable = heatertable
	nvar heaterrange_control,mcheat
	
	fullscale = heatertable[heaterrange_control][1]
	procent = output*100/fullscale
	if(output > fullscale)
		printf "Range is to low, will set heater to %g mA", fullscale
		procent = 100
		output = fullscale
	endif
	sprintf 	command,"MOUT %g", procent
	url = CreateURL("createCommand",writeurl = "1", cmd = command)
	WriteLakeShore(url)
	mcheat = output
end

//// Temperature Control Get functions ////

function/s GetControlParameters()
	string url, command, response
	nvar control_channel,filter_channel,units_control,delay_control,cp_control,heaterrange_control,heaterres_control
	variable heaterrange_max // dump max heaterrange, always override to max heaterrange!
	command = "CSET?"
	url = CreateURL("createCommand",writeurl = "1", cmd = command)
	response = QueryLakeShore(url)
	sscanf response, "%g,%g,%g,%g,%g,%g,%g", control_channel,filter_channel,units_control,delay_control,cp_control,heaterrange_max,heaterres_control
	return response
end

function/s GetRamp()
	string url, command, response
	variable rate
	nvar ramp_stat,ramp_rate
	
	command = "RAMP?"
	url = CreateURL("createCommand",writeurl = "1", cmd = command)
	response = QueryLakeShore(url)
	sscanf response, "%g,%g", ramp_stat, rate
	if(ramp_stat == 1)
		Button Rampbutton, title="\\Z14Stop Ramp",fcolor=(1000,0,0)
		return "on"
	else
		Button Rampbutton, title="\\Z14Start Ramp",fcolor=(0,1000,0)
		return "off"
	endif
	ramp_rate = rate*1000
end

function GetTempSetPoint()
	// Temp set point in mK
	string command, url, response
	variable temp
	nvar temp_set
	
	command = "SETP?"
	url = CreateURL("createCommand", writeurl = "1", cmd = command)
	response = QueryLakeShore(url)
	temp = str2num(response)
	temp_set = temp*1000
	return temp*1000
end

function GetHeaterRange()
	string command, url, response
	wave heatertable = heatertable
	variable range
	nvar heaterrange_control
	
	command = "HTRRNG?"
	url = CreateURL("createCommand", writeurl = "1", cmd = command)
	response = QueryLakeShore(url)
	range = heatertable[str2num(response)][1]
	heaterrange_control = str2num(response)
	PopupMenu HeaterRange,mode=heaterrange_control+1
	return range
end

function/s GetPIDParameters()
	string command, url, response,param
	variable pid_1, pid_2, pid_3
	nvar p_value,i_value,d_value
	
	command = "PID?"
	url = CreateURL("createCommand", writeurl = "1", cmd = command)
	response = QueryLakeShore(url)
	print response
	sscanf response, "%g,%g,%g", pid_1, pid_2, pid_3
	sprintf param, "P=%g, I=%g, D=%g", pid_1, pid_2, pid_3
	p_value =pid_1
	i_value = pid_2
	d_value = pid_3
	return param
end

function/s GetControlMode()
	string command, url, response
	wave/t controlloop = controlloop
	nvar pid_mode,led_val,mcheat,ramp_stat
	
	command = "CMODE?"
	url = CreateURL("createCommand", writeurl = "1", cmd = command)
	response = QueryLakeShore(url)
	PopupMenu ControlMode,mode=str2num(response)
	pid_mode = str2num(response)
	if(pid_mode == 1)
		led_val = 1
		mcheat = 0
		SetVariable MCheater, disable=2
		Button Rampbutton, disable=0
	elseif(pid_mode == 3)
		led_val = 0
		SetVariable MCheater, disable=0
		Button Rampbutton, disable=2
	else
		led_val = 0
		mcheat = 0
		SetVariable MCheater, disable=2
		Button Rampbutton, disable=2
		if(ramp_stat == 1)
			RampTemp("off",0)
			Button Rampbutton, title="\\Z14Start Ramp",fcolor=(0,1000,0)
		endif
	endif
	return controlloop[str2num(response)-1]
end

function GetStillHeater()
	string command,url,response
	variable power,fullscale
	nvar stillheat
	
	fullscale = 10
	command = "STILL?"
	url = CreateURL("createCommand", writeurl = "1", cmd = command)
	response = QueryLakeShore(url)
	power = (str2num(response)*fullscale/100)^2/150*1000
	stillheat = power
	return power
end

function GetMCHeater()
	string command,url,response
	variable fullscale,output
	nvar mcheat, heaterrange_control
	wave heatertable = heatertable
	
	fullscale = heatertable[heaterrange_control][1]
	command = "MOUT?"
	url = CreateURL("createCommand", writeurl = "1", cmd = command)
	response = QueryLakeShore(url)
	output = str2num(response)*fullscale/100
	mcheat = output
	return output
end

//// Magnet Heater ////

function MagnetHeater(newstate)
	string newstate
	string command, url
	nvar magnetheater_control
	
	strswitch(newstate)
		case "on":
			sprintf 	command,"MAGHEATER %s", newstate
			magnetheater_control = 1
			break
		case "off":
			sprintf 	command,"MAGHEATER %s", newstate
			magnetheater_control = 0
			break
		default:
			abort "Call with 'on' or 'off'."
			break
	endswitch
		
	url = CreateURL("createCommand",writeurl = "1", cmd = command)
	WriteLakeShore(url)
end

//// Communication ////

function/s WriteLakeShore(url)
	string url

	return FetchURL(url)
end

function/s QueryLakeShore(url)
	string url
	string cmdid
	
	cmdid = WriteLakeShore(url)
	return ReadLakeShore(cmdid, 10)
end

function/s ReadLakeShore(cmdid, timeout)
	string cmdid
	variable timeout
	string url
	
	url = CreateURL("getCommandResponse", cmd = cmdid, timeout = num2str(timeout))
	return FetchURL(url)
end

//// Util ////

function/s CreateURL(command,[readurl,writeurl,cmd,timeout])
	string command, readurl, writeurl, cmd, timeout
	string url, readwritestr
	svar readsql, writesql
	
	
	if(ParamIsDefault(readurl) == 0 && ParamIsDefault(writeurl))
		sprintf url,"http://qdot-server.phas.ubc.ca:8081/webService/logger.php?action=%s", command
		sprintf readwritestr,"&loggable_category_id=%s", readsql
	elseif(ParamIsDefault(writeurl) == 0 && ParamIsDefault(readurl) && ParamIsDefault(cmd) == 0)
		sprintf url,"http://qdot-server.phas.ubc.ca:8081/webService/commandmanager.php?action=%s", command
		cmd = ReplaceString(" ", cmd, "%20")
		sprintf readwritestr,"&port_id=%s&cmd=%s", writesql, cmd
	elseif(ParamIsDefault(readurl) && ParamIsDefault(writeurl) && ParamIsDefault(cmd) == 0)
		sprintf url,"http://qdot-server.phas.ubc.ca:8081/webService/commandmanager.php?action=%s", command
		sprintf readwritestr,"&port_id=%s&command_id=%s&timeout=%s",readsql, cmd, timeout
	else
		abort "Can't create URL. Send readurl or writeurl + cmd"
	endif
	url = url + readwritestr
	return url
end

function ReadResponseString(responsestr,key)
	string responsestr, key
	variable numvals, i
	string keyname
	
	numvals = ItemsInList(responsestr)
	Make/O/T/N=(numvals) textWave= StringFromList(p,responsestr)
	for (i=0; i<numvals; i+=1)
		keyname = stringfromlist(0,textwave[i],"=")
		if (stringmatch(keyname, key))
			return str2num(stringfromlist(1,textwave[i],"="))
		endif
	endfor
end

function /S check_command(command)
	string command
	string url
	url = CreateURL("createCommand", writeurl = "1", cmd = command)
	return QueryLakeShore(url)
end

//// User interface ////

window LakeShore_Window() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(0,0,380,400) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 130, 45,"LakeShore"
	ValDisplay PIDLed, pos={40,20}, size={45,20}, mode=2,value=led_val, zerocolor=(65535,0,0), limits={0,1,-1}, highcolor=(65535,0,0),lowcolor=(0,65535,0),barmisc={0,0},title="\\Z14PID"
	ValDisplay HeaterLed, pos={280,17}, size={65,20}, mode=2,value=magnetheater_control, zerocolor=(65535,0,0), limits={0,1,-1}, highcolor=(65535,0,0),lowcolor=(0,65535,0),barmisc={0,0},title="\\Z10Magnet\rHeater"
	PopupMenu ControlMode, pos={20,50},size={250,50},mode=4,title="\\Z16Control Mode:",value=("Closed Loop PID;Zone Tuning;Open Loop;Off"), proc=ControlMode_control
	PopupMenu ControlChannel, pos={20,82},size={250,50},mode=6,title="\\Z16Control Channel:",value=("1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16"),proc=ControlChannel_control
	SetVariable TempSet, pos={20,110},size={300,50},value=temp_set,title="\\Z16Temperature Setpoint (mK):",limits={0,300000,0},proc=tempset_control
	SetVariable Ramp, pos={20,140},size={200,50},value=ramp_rate,title="\\Z16Ramp rate (mK/min):",limits={0,2000,0},proc=Rate_control
	Button Rampbutton, pos={250,142},size={100,20},title="\\Z14Start Ramp",fcolor=(0,1000,0),disable=2,proc=Ramp_control
	PopupMenu HeaterRange, pos={20,172},size={250,50},mode=1,title="\\Z16MC Heater Range (mA):",value=("Off;0.0316;0.1;0.316;1.00;3.16;10.0;31.6;100"),proc=MCHeaterRange_control
	SetVariable MCheater, pos={20,202}, size={200,50},title="\\Z16MC Heater (mA):",value=mcheat,limits={0,100,0},disable=2,proc=MCHeater_control
	SetVariable Stillheater, pos={20,232}, size={200,50},title="\\Z16Still Heater (mW):",value=stillheat,limits={0,1000,0},proc=StillHeater_control
	SetVariable P, pos={20,262},size={200,50},value=p_value,title="\\Z16PID parameters (P):",limits={0.001,1000,0}
	SetVariable I, pos={148,292},size={72,50},value=i_value,title="\\Z16(I):",limits={0,10000,0}
	SetVariable D, pos={141,322},size={79,50},value=d_value,title="\\Z16(D):",limits={0,2500,0}
	Button PIDUpdate, pos={20,300},size={100,20},title="\\Z14Update PID",proc=PID_control
	Button UpdateValues, pos={250,250}, size={100,70},title="\\Z14Update\rCurrent\rValues",proc=Update_control
	SetVariable Temp_read, pos={20,352}, size={250,50}, title="\\Z16Temperature Sequence:",value=temp_seq,disable=2
endmacro

function ControlMode_control(action,popnum,popstr) : PopupMenuControl
	string action
	variable popnum
	string popstr
	nvar pid_mode,ramp_stat,led_val,mcheat
	
	if(popnum == 1)
		led_val = 1
		mcheat = 0
		SetVariable MCheater, disable=2
		Button Rampbutton, disable=0
	elseif(popnum == 3)
		led_val = 0
		SetVariable MCheater, disable=0
		Button Rampbutton, disable=2
	else
		led_val = 0
		mcheat = 0
		SetVariable MCheater, disable=2
		Button Rampbutton, disable=2
		if(ramp_stat == 1)
			RampTemp("off",0)
			Button Rampbutton, title="\\Z14Start Ramp",fcolor=(0,1000,0)
		endif
	endif
	SetControlMode(popnum)
	pid_mode = popnum
end

function ControlChannel_control(action,popnum,popstr) : PopupMenuControl
	string action
	variable popnum
	string popstr
	
	SetControlParameters(channel = popnum)
end

function PID_control(action) : ButtonControl
	string action
	nvar p_value,i_value,d_value
	
	SetPIDParameters(p_value,i_value,d_value)
end

function tempset_control(action,varnum,varstr,varname) : SetVariableControl
	string action
	variable varnum
	string varstr, varname

	SetPointTemp(varnum)
end

function Rate_control(action,varnum,varstr,varname) : SetVariableControl
	string action
	variable varnum
	string varstr, varname
	nvar ramp_rate
	
	ramp_rate = varnum
end

function Ramp_control(action) : ButtonControl
	string action
	nvar ramp_rate, ramp_stat
	
	if(ramp_stat == 1)
		RampTemp("off",ramp_rate)
		Button Rampbutton, title="\\Z14Start Ramp",fcolor=(0,1000,0)
	elseif(ramp_stat == 0)
		if(ramp_rate == 0)
			print "Ramp rate is 0. Setting it to 10 mK/min"
			ramp_rate = 10
		endif
		RampTemp("on",ramp_rate)
		Button Rampbutton, title="\\Z14Stop Ramp",fcolor=(1000,0,0)
	endif
end

function MCHeaterRange_control(action,popnum,popstr) : PopupMenuControl
	string action
	variable popnum
	string popstr
	
	if(stringmatch(popstr,"Off"))
		popstr = "0"
	endif
	SetHeaterRange(str2num(popstr))
end

function MCHeater_control(action,varnum,varstr,varname) : SetVariableControl
	string action
	variable varnum
	string varstr, varname
	nvar pid_mode
	
	MCHeater(varnum)
end

function StillHeater_control(action,varnum,varstr,varname) : SetVariableControl
	string action
	variable varnum
	string varstr, varname
	
	StillHeater(varnum)
end

function Update_control(action) : ButtonControl
	string action
	
	UpdateCurrentValues()
end

//// xxx ////

function HeatUpMagnetToRoomTemperature()
	variable magnet_temperature = GetTemp("magnet"), heater_is_on
	do
		if (magnet_temperature > 295 && heater_is_on == 1)
			magnetheater("off")
			heater_is_on=0
		elseif (magnet_temperature < 273 && heater_is_on == 0)
			magnetheater("on")
			heater_is_on=1
		endif
		sleep /s 15
		magnet_temperature = GetTemp("magnet")
	while (GetTemp("still")<280)
	magnetheater("off")
end