#pragma rtGlobals=1	// Use modern global access method

// Driver for controling the Lakeshorer
// Communicates with server over http
// 
// NEEDS SOME DOCUMENTATION
//


////////////////////////////
//// Get current values ////
////////////////////////////

function getTemperature(plate, max_age)
	// plates: mc (mixing chamber), cold plate, still, 1K (1K pot), sorb
	//
   // returns temperatures in Kelvin
   
   // max_age determines how old a reading can be before I demand a new one
   // from the lakeshore server
   // max_age=0 always requests a new reading

	string plate
	variable max_age
	string payload="", headers = "Content-Type: application/json", url = "http://ls_370-370014:9898/get_channel_data"
	variable channel=-1
	
	strswitch(plate)
		case "mc":
			channel = 3
			break
		case "cold plate":
			channel = 6
			break
		case "still":
			channel = 5
			break
		case "1k":
			channel = 2
			break
		case "sorb":
			channel = 1
			break
		default:
			channel=3 // if you send in garbage, you get the mixing chamber back
			break
	endswitch
	
	sprintf payload, "{\"ch\":%d, \"max_age\":%d}", channel, max_age

	URLRequest /TIME=5.0 /DSTR=payload url=url, method=post, headers=headers
	
	if (V_flag == 0)    // No error
		if (V_responseCode != 200)  // 200 is the HTTP OK code
		    print "Temperature reading failed: "+plate
		    return 0.0
		else
		    string response = S_serverResponse // response is a JSON string
		endif
   else
        print "HTTP connection error. Temperature reading not attempted."
        return 0.0
   endif
	
	if(getJSONbool(response, "ok")==1)
		// no error
		string data = getJSONarray(response, "data")
		return getJSONnum(data, "T")
	else
		// not sure what comes back here
		print "Problem reading temperature value: "+response
		return 0.0
	endif
	
end

function getHeaterPwr(heater, max_age)
	//
	//    to do:  check units
	//

	// heaters: mc (mixing chamber, "heater")
	//          still ("analog 2")
	//          sorb ("analog 1") -- only on Kelvinox
   // returns power in mW
   
   // max_age determines how old a reading can be before I demand a new one
   // from the lakeshore server
   // max_age=0 always requests a new reading

	string heater
	variable max_age
	string url="", payload="", headers = "Content-Type: application/json"
	
	strswitch(heater)
		case "mc":
			url = "http://ls_370-370014:9898/get_heater_data"
			sprintf payload, "{\"max_age\":%d}", max_age
			break
		case "still":
			url = "http://ls_370-370014:9898/get_analog_data"
			sprintf payload, "{\"ch\":2, \"max_age\":%d}", max_age
			break
		case "sorb":
			url = "http://ls_370-370014:9898/get_analog_data"
			sprintf payload, "{\"ch\":1, \"max_age\":%d}", max_age
			break
	endswitch

	URLRequest /TIME=5.0 /DSTR=payload url=url, method=post, headers=headers
	
	if (V_flag == 0)    // No error
		if (V_responseCode != 200)  // 200 is the HTTP OK code
		    print "Heater reading failed: "+heater
		    return 0.0
		else
		    string response = S_serverResponse // response is a JSON string
		endif
   else
        print "HTTP connection error. Heater reading not attempted."
        return 0.0
   endif
	
	if(getJSONbool(response, "ok")==1)
		// no error
		string data = getJSONarray(response, "data")
		return getJSONnum(data, "power_mw")
	else
		// not sure what comes back here
		print "Problem reading heater value: "+response
		return 0.0
	endif
	
end

////////////////////////
//// heater control ////
////////////////////////

function SetStillHeater(power)
	// power in mW
	//
	// using the ANALOG command because it gives me better control over options
	// STILL is only really a help when using the front panel

	variable power
	power = power/1000.0 // convert to W
	
	variable resistance = 460 // Ohms
	variable fullscale = 10 //V
	
	variable voltageOut = sqrt(power*resistance)
	variable percentOut = voltageOut/fullscale*100.0

	string cmd=""
	// channel=2, polarity=0, mode=4(still), channel=1(sorb), source=1(Kelvin), 
	//                             high_val=100.0(100% max), low_val=0.0(0% min), percentOut
	sprintf cmd,"ANALOG 2,0,2,1,1,100.0,0.0,%g", percentOut
//	print cmd
	lakeshorePost(cmd)
	
end

function SetSorbHeater(power)
	// power in mW
	//
	// come back later if you want to add some PID control
	
	variable power
	power = power/1000.0 // convert to W
	
	variable resistance = 85 // Ohms
	variable fullscale = 10 //V
	
	variable voltageOut = sqrt(power*resistance)
	variable percentOut = voltageOut/fullscale*100.0

	string cmd=""
	// channel=1, polarity=0, mode=2(manual), channel=1(sorb), source=1(Kelvin), 
	//                             high_val=100.0(100% max), low_val=0.0(0% min), percentOut
	sprintf cmd,"ANALOG 1,0,2,1,1,100.0,0.0,%g", percentOut
	print cmd
	lakeshorePost(cmd)
	
end


function SetControlParameters(channel, r_heater, [filter,units,delay,cp,heaterrange_max])
	// set channel to control channel
	variable channel,r_heater
	variable filter,units,delay,cp,heaterrange_max
	string command
	nvar control_channel,filter_channel,units_control,delay_control,cp_control,heaterres_control
	
	if(ParamIsDefault(filter))
		filter = 1 // control on filtered readings
	endif
	if(ParamIsDefault(units))
		units = 1 // Kelvin
	endif
	if(ParamIsDefault(delay))
		delay = 1 // seconds (only used in AutoScan mode)
	endif
	if(ParamIsDefault(cp))
		cp = 1 // current
	endif
	if(ParamIsDefault(heaterrange_max))
		heaterrange_max = 8 // 100 mA
	endif
	
	sprintf command,"CSET %d,%d,%d,%d,%d,%d,%d", channel, filter, units, delay, cp, heaterrange_max, r_heater
	
end

function SetControlMode(control_mode)
	// control modes:
	//    Closed Loop PID = 1
	//    Zone Tuning = 2
	//    Open Loop = 3
	//    Off = 4
	variable control_mode
	string command

	switch(control_mode)
		case 1:
			print "Closed Loop PID mode set"
			break
		case 2:
			print "Zone tuning mode set"
			break
		case 3:
			print "Open Loop mode set"
			break
		case 4:
			print "PID control off"
			break
		default:
			abort "Enter a valid control mode!"
	endswitch

	sprintf command,"CMODE %d", control_mode
	lakeshorePost(command)

end

function setTemperatureTarget(temp)
	// set temp in mK
	// could also be in mOhms, depending on the setup
	
	variable temp
	temp = temp/1000.0 // convert to kelvin
	
	string command=""
	sprintf command, "SETP %g", temp
	printf "Temperature setpoint is now: %.1fmK\r", temp*1000.0

	lakeshorePost(command)
end

function SetHeaterRange(value)
	// Set range in mA
	//
	//  0 = Off, 1 = 31.6μA, 2 = 100μA, 3 = 316μA, 4 = 1.00 mA
	//  5 = 3.16 mA, 6 = 10.0 mA, 7 = 31.6 mA, 8 = 100 mA
	//

	variable value
	value = value/1000.0 // convert to amps
	
	string command = ""
	variable rng=0, rngmax=0
	
	if(value<=0)
		rng = 0
		rngmax=0
	elseif(value>0 && value<=31.6e-6)
		rng = 1
		rngmax=0.0316
	elseif(value>31.6e-6 && value<=100e-6)
		rng = 2
		rngmax=0.100
	elseif(value>100e-6 && value<=316e-6)
		rng = 3
		rngmax=0.316
	elseif(value>316e-6 && value<=1.0e-3)
		rng = 4
		rngmax=1.0
	elseif(value>1.0e-3 && value<=3.16e-3)
		rng = 5
		rngmax=3.16
	elseif(value>3.16e-3 && value<=10e-3)
		rng = 6
		rngmax=10.0
	elseif(value>10e-3 && value<=31.6e-3)
		rng = 7
		rngmax=31.6
	elseif(value>31.6 && value<=100e-3)
		rng = 8
		rngmax=100.0
	else
		abort "Heater current out of range."
	endif
	
	sprintf command, "HTRRNG %d", rng
	printf "LakeShore heater range set to: %d (%.4fmA)\r", rng, rngmax
	
	lakeshorePost(command)
	
	return rngmax // 100% output for current range, in mA

end

function setHeater(heat)
	// set heat in mA
	
	variable heat
	variable rngmax = SetHeaterRange(heat)
	
	string command=""
	variable setpoint = 0
	if(rngmax == 0)
		setpoint = 0
	else
		setpoint = 100*heat/rngmax
	endif
	sprintf command, "MOUT %g", setpoint
	printf "Heater output is now: %.1fmA\r", heat

	lakeshorePost(command)
end


function SetPIDParameters(p,i,d)
	// P = {0.001 1000}, I = {0 10000}, D = {0 2500}
	
	variable p,i,d
	string command
	
	if(0.001 <= p && p <= 1000 && 0 <= i && i <= 10000 && 0 <= d && d <= 2500)
		sprintf 	command,"PID %.2f,%.2f,%.2f", p, i, d
	else
		abort "PID parameters out of range"
	endif
	
	lakeshorePost(command)
	
end

//function SetMCHeater(output)
//	// output in mA
//	variable output
//	variable fullscale,procent
//	string url,command
//	wave heatertable = heatertable
//	nvar heaterrange_control,mcheat
//	
//	fullscale = heatertable[heaterrange_control][1]
//	procent = output*100/fullscale
//	if(output > fullscale)
//		printf "Range is to low, will set heater to %g mA", fullscale
//		procent = 100
//		output = fullscale
//	endif
//	sprintf 	command,"MOUT %g", procent
//
//	mcheat = output
//end
//
//function/s GetControlParameters()
//	string url, command, response
//	nvar control_channel,filter_channel,units_control,delay_control,cp_control,heaterrange_control,heaterres_control
//	variable heaterrange_max // dump max heaterrange, always override to max heaterrange!
//	command = "CSET?"
//
//
//	sscanf response, "%g,%g,%g,%g,%g,%g,%g", control_channel,filter_channel,units_control,delay_control,cp_control,heaterrange_max,heaterres_control
//	return response
//end
//
//function GetTempSetPoint()
//	// Temp set point in mK
//	string command, url, response
//	variable temp
//	nvar temp_set
//	
//	command = "SETP?"
//
//	temp = str2num(response)
//	temp_set = temp*1000
//	return temp*1000
//end
//
//function GetHeaterRange()
//	string command, url, response
//	wave heatertable = heatertable
//	variable range
//	nvar heaterrange_control
//	
//	command = "HTRRNG?"
//
//
//	range = heatertable[str2num(response)][1]
//	heaterrange_control = str2num(response)
//	PopupMenu HeaterRange,mode=heaterrange_control+1
//	return range
//end
//
//function/s GetPIDParameters()
//	string command, url, response,param
//	variable pid_1, pid_2, pid_3
//	nvar p_value,i_value,d_value
//	
//	command = "PID?"
//
//
//	sscanf response, "%g,%g,%g", pid_1, pid_2, pid_3
//	sprintf param, "P=%g, I=%g, D=%g", pid_1, pid_2, pid_3
//	p_value =pid_1
//	i_value = pid_2
//	d_value = pid_3
//	return param
//end

//function/s GetControlMode()
//	string command, url, response
//	wave/t controlloop = controlloop
//	nvar pid_mode,led_val,mcheat,ramp_stat
//	
//	command = "CMODE?"
//	url = CreateURL("createCommand", writeurl = "1", cmd = command)
//	response = QueryLakeShore(url)
//	PopupMenu ControlMode,mode=str2num(response)
//	pid_mode = str2num(response)
//	if(pid_mode == 1)
//		led_val = 1
//		mcheat = 0
//		SetVariable MCheater, disable=2
//		Button Rampbutton, disable=0
//	elseif(pid_mode == 3)
//		led_val = 0
//		SetVariable MCheater, disable=0
//		Button Rampbutton, disable=2
//	else
//		led_val = 0
//		mcheat = 0
//		SetVariable MCheater, disable=2
//		Button Rampbutton, disable=2
//		if(ramp_stat == 1)
//			RampTemp("off",0)
//			Button Rampbutton, title="\\Z14Start Ramp",fcolor=(0,1000,0)
//		endif
//	endif
//	return controlloop[str2num(response)-1]
//end


//// Communication ////

function /S lakeshorePost(cmd)
	// send a command and read a response (or an OK status)
	string cmd
	
	string payload="", headers = "Content-Type: application/json", cmd_url="http://ls_370-370014:9898/cmd"
	sprintf payload, "{\"cmd\": \"%s\"}", cmd 
	
	URLRequest /TIME=10.0 /DSTR=payload url=cmd_url, method=post, headers=headers
	
	if (V_flag == 0)    // No error
		if (V_responseCode != 200)  // 200 is the HTTP OK code
		    abort "send LakeShore command failed: "+cmd
		else
		    string response = S_serverResponse // response is a JSON string
		endif
   else
        abort "HTTP connection error. LakeShore command not attempted."
   endif

	if(getJSONbool(response, "ok")==1)
		// no error
		return response // return JSON string. let the next function parse it.
	else
		// not sure what comes back here
		abort "LakeShore command execution error: "+response
	endif

end