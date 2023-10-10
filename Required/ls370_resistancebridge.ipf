#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method

// Driver for controling a Dilution fridge, via a LakeShore 370 controller and an intermidiate server
// running on a RPi.
// Call SetSystem() before anything else. Current supported systems are: BFsmall, BFbig
// Communicates with server over http.
// Procedure written by Christian Olsen 2018-03-xx
// Almost entirely rewritten for new API by Tim Child 2020-06-xx

///////////////////////////
/// LS37X specific COM ///
///////////////////////////

function openLS370connection(instrID, http_address, system, [verbose])
	// open/test a connection to the LS37X RPi interface written by Ovi
	//      the whole thing _should_ work for LS370 and LS372
	// instrID is the name of the global variable that will be used for communication
	// http_address is exactly what it sounds like
	// system is the name of the cryostat you are working on: bfsmall, igh, bfbig
	// verbose=0 will not print any information about the connection
	
	// XLD -- http://lksh370-xld.qdev-b111.lab:49300/api/v1/
	// LD -- 10.18.101.12:49301/api/v1/

	string instrID, http_address, system
	variable verbose

	if(paramisdefault(verbose))
		verbose=1
	elseif(verbose!=1)
		verbose=0
	endif

	string comm = ""
	sprintf comm, "name=LS370,instrID=%s,url=%s" instrID, http_address
	string options = ""

	openHTTPinstr(comm, options=options, verbose=verbose)  // Sets svar (instrID) = url
	setLS370system(system) // Sets channel/heater/temp lookup strings/waves
	LS370createGobals() 	//Only inits values locally if not already existing. Nothing sent to LS
end

////////////////////////////
//// Initiate Lakeshore ////
////////////////////////////

function setLS370system(system)
	// Sets channel/heater/temp lookup strings/waves
	string system

	string /g ls_system="", ls_label=""
	strswitch(system)
		case "bfsmall":
			ls_system = "bfsmall"
			ls_label = "LD"				//plate					//labels	  									//IDs
			string/g bfbd_ChannelLookUp = "mc;still;magnet;4K;50K;ld_mc;ld_still;ld_magnet;ld_4K;ld_50K;6;5;4;2;1"  
			string/g bfheaterlookup = "mc;still;sc_mc;ld_still_heater"						//sc_mc only used internally, still label refers to API 
			make/o mcheatertemp_lookup = {{31.6e-3,100e-3,316e-3,1.0,3.16,10,31.6,100},{0,10,30,95,290,1201,1800,10000}}
			break
		case "bfbig":
			ls_system = "bfbig"
			ls_label = "XLD"					//plate				//labels	  			//IDs
			string/g bfbd_ChannelLookUp = "mc;still;magnet;4K;50K;ch6;ch5;ch3;ch2;ch1;6;5;3;2;1"  
			string/g bfheaterlookup = "mc;still;sc_mc;ao2"							 		//sc_mc only used internally, still label refers to API 	
			make/o mcheatertemp_lookup = {{31.6e-3,100e-3,316e-3,1.0,3.16,10,31.6,100},{0,10,30,95,290,1201,1800,10000}} 
			break
		default:
			abort "[ERROR] Please choose a supported LS370 system: [bfsmall, bfbig]"
	endswitch

end

///////////////////////
//// Get Functions ////
//////////////////////
function/s getLS370channelLabel(plate)
	// To be used by other functions, not directly by user
	// Returns the channel label for either XLD or LD system (whichever is initialized) corresponding to
	// standard channel names ("50K,4K,magnet,still,mc")
	string plate

	svar bfbd_ChannelLookUp
	
	string channel
	variable channel_idx
	channel_idx = whichlistitem(plate,bfbd_ChannelLookUp,";", 0, 0)
	if(channel_idx < 0)
		printf "The requested plate (%s) doesn't exsist!\r", plate
		abort
	else
		channel = stringfromlist(channel_idx+5,bfbd_ChannelLookUp,";")
	endif
	return channel
end

// get-analog-data
function getLS370analogData(instrID, [channel])  //mW
	// Returns power_milliw from analog channel
	// Channel = 'still'
	string instrID, channel
	
	string api_channel, command, result
	variable channel_idx
	svar ls_label	
	svar bfheaterlookup
	
	if (paramisdefault(channel))
		channel = "still"
	endif 

	channel_idx = whichlistitem(channel,bfheaterlookup,";", 0, 0)
	if(channel_idx < 0)
		printf "The requested channel (%s) doesn't exsist!", channel
		return 0.0
	elseif (channel_idx >= 2) // Already given api_name
		api_channel = channel
	else
		api_channel = stringfromlist(channel_idx+2,bfheaterlookup,";")
	endif
	
	sprintf command, "get-analog-data/%s?ctrl_label=%s", api_channel, ls_label
	result = sendLS370(instrID,command,"get",keys="data:record:power_milliw") 
	return str2num(result)
end

// get-analog-parameters
function/s getLS370analogParameters(instrID, [channel])
	// Returns all params of analog heater (Don't think we use this info but it is in API)
	// Channel = 'still' or API_channel label
	string instrID, channel
	
	string api_channel, command, result
	variable channel_idx
	svar ls_label	
	svar bfheaterlookup
	
	if (paramisdefault(channel))
		channel = "still"
	endif 
	
	channel_idx = whichlistitem(channel,bfheaterlookup,";", 0, 0)
	if(channel_idx < 0)
		printf "The requested channel (%s) doesn't exsist!", channel
		return ""
	elseif (channel_idx >= 2) // Already given api_name
		api_channel = channel
	else
		api_channel = stringfromlist(channel_idx+2,bfheaterlookup,";")
	endif
	
	sprintf command, "get-analog-parameters/%s?ctrl_label=%s", api_channel, ls_label
	result = sendLS370(instrID,command,"get",keys="") // Return the whole JSON response for now
	return result
end

// get-channel-data
function getLS370temp(instrID, plate, [max_age_s]) // Units: K
	// returns the temperature of the selected "plate".
	// avaliable plates on BF systems: mc (mixing chamber), still, magnet, 4K, 50K
	// max_age_s determines how old a reading can be (in sec), before I demand a new one
	// from the server
	// max_age_s=0 always requests a new reading
	string instrID
	string plate
	variable max_age_s
	svar ls_system, bfbd_ChannelLookUp, ighbd_ChannelLookUp
	variable channel_idx
	string channel
	string command
	svar ls_label
	
	if(paramisdefault(max_age_s))
		max_age_s = 120
	endif

	channel = getLS370channelLabel(plate)
	
	string result
	variable temp
	// TODO: test this (Christian needs to write it first...)
//	temp = getLS370tempDB(instrID, plate, max_age=max_age_s)
	if (temp > 0)
		return temp
	else		
		sprintf command, "get-channel-data/%s?ctrl_label=%s", channel, ls_label
		result = sendLS370(instrID,command,"get",keys="data:record:temperature_k") 
		return str2num(result)
	endif
end


// get-controller-info/{ctrl_label}
// get-controller-info
function/s getLS370controllerInfo(instrID, [all])
	// See API docs. We don't use this, but putting it here to match API
	string instrID
	variable all
	svar ls_label
	
	string command, result
	if (all == 0)
		sprintf command, "get-controller-info/%s", ls_label
	else
		sprintf command, "get-controllers-info"
	endif
	result = sendLS370(instrID,command,"get",keys="") // Return the whole JSON response for now
	return result
end


// get-data-loggers-schedule
function/s getLS370loggersSchedule(instrID)
	// See API docs. We don't use this, but putting it here to match API
	string instrID
	
	svar ls_label
	string command, result
	
	
	sprintf command, "get-data-loggers-schedule/%s", ls_label
	result = sendLS370(instrID,command,"get", keys="") // Return the whole JSON response for now
	return result
end


// get-heater-data
function getLS370heaterpower(instrID,heater, [max_age_s]) // Units: mW
	// returns the power of the selected heater.
	// avaliable heaters on BF systems: still (analog 2), mc
	// avaliable heaters on IGH systems: sorb (analog 1), still (analog 2), mc
	// max_age_s determines how old a reading can be (in sec), before a new is demanded
	// from the server
	// max_age_s=0 always requests a new reading
	string instrID
	string heater
	variable max_age_s
	svar ls_system, bfheaterlookup, ighheaterlookup
	variable heater_idx
	string channel = ""
	string command
	svar ls_label

	if(paramisdefault(max_age_s))
		//return GetHeaterPowerDB(heater)
		max_age_s = 120
	endif

	strswitch(ls_system)
		case "bfsmall":
		case "bfbig":
			heater_idx = whichlistitem(heater,bfheaterlookup,";", 0, 0)
			if(heater_idx < 0)
				printf "The requested heater (%s) doesn't exsist!", heater
				return -1.0
			else
				channel = stringfromlist(heater_idx+2,bfheaterlookup,";")
			endif
			break
		default:
			abort "ls_system not implemented"
	endswitch

	if(cmpstr(heater, "still") == 0)  // If looking for still, use getAnalog
		return getLS370AnalogData(instrID, channel=channel) // Get Still heat using getAnalogData
	else
		sprintf command, "get-heater-data/%s", ls_label
		return str2num(sendLS370(instrID,command,"get", keys="data:record:power_milliw")) 
	endif
end


// get-heater-range-amps
function getLS370heaterrange(instrID) //mA
	// Gets the max_current setting of MC heater (not the heater power mode which would be 0-8)
	string instrID
	variable range
	string command,payload,response
	svar ls_label

	sprintf command, "get-heater-range-amps/%s", ls_label

	response = sendLS370(instrID,command,"get", keys="data")
	return str2num(response)*1000  // Convert from A to mA
end


// get-temperature-control-mode
function getLS370controlmode(instrID, [verbose]) // Units: No units
	// returns the temperature control mode.
	// 1: PID, 3: Open loop, 4: Off
	string instrID
	variable verbose
	nvar pid_mode, pid_led, mcheater_led
	string command,response
	svar ls_label // Set when opening connection to lakeshore

	sprintf command, "get-temperature-control-mode/%s", ls_label

	response = sendLS370(instrID,command,"get", keys="data")
	pid_mode = LS370_mode_str_to_mode(response)
	if (verbose)
		print "Control mode is ", response
	endif
	return pid_mode
end


// get-temperature-control-parameters
function/s getLS370controlParameters(instrID)
	// See API docs. We don't use this, but putting it here to match API
	string instrID
	svar ls_label
	
	string command, result
	sprintf command, "get-temperature-control-parameters/%s", ls_label
	result = sendLS370(instrID,command,"get",keys="data") // Return the whole JSON response for now
	return result
end


// get-temperature-control-setpoint
function getLS370PIDtemp(instrID) // Units: mK
	// returns the setpoint of the PID loop.
	// the setpoint is set regardless of the actual state of the PID loop
	// and one can therefore always read the current setpoint (active or not)
	string instrID
	variable temp
	string payload, command
	svar ls_label
	nvar temp_set

	sprintf command, "get-temperature-control-setpoint/%s", ls_label

	string response = sendLS370(instrID,command,"get", keys="data")
	temp = str2num(response)*1000
	temp_set = temp
	return temp
end


// get-temperature-pid
function/s getLS370PIDparameters(instrID) // Units: No units
	// returns the PID parameters used.
	// the retruned values are comma seperated values.
	// P = {0.001 1000}, I = {0 10000}, D = {0 2500}

	string instrID
	nvar p_value,i_value,d_value
	string payload, pid, command
	svar ls_label

	sprintf command, "get-temperature-pid/%s", ls_label

	pid = sendLS370(instrID,command,"get", keys="data")
	p_value = str2num(getJSONvalue(pid, "P"))
	i_value = str2num(getJSONvalue(pid, "I"))
	d_value = str2num(getJSONvalue(pid, "D"))
	sprintf pid, "P=%f,I=%f,D=%f", p_value, i_value, d_value  // For backwards compatability
	return pid
end




///////////////////////
//// Set Functions ////
//////////////////////

//set-analog-output-parameters
function setLS370analogOutputParameters(instrID, [channel])
	// Set analog output parameters
	// Note: currently very limited because I don't know that we actually change any of these things. You'll have to implement it if you want it
	string instrID, channel
	
	string api_channel, command, payload
	variable channel_idx
	svar ls_label	
	svar bfheaterlookup
	
	if (paramisdefault(channel))
		channel = "still"
	endif 
	
	channel_idx = whichlistitem(channel,bfheaterlookup,";", 0, 0)
	if(channel_idx < 0)
		printf "The requested channel (%s) doesn't exsist!", channel
		return 0.0
	elseif (channel_idx >= 2) // Already given api_name
		api_channel = channel
	else
		api_channel = stringfromlist(channel_idx+2,bfheaterlookup,";")
	endif
	
	variable high_value = 0, low_value = 0, manual_value = 0
	string mode = "aom_manual"  // aom_undefined, aom_off, aom_channel, aom_manual, aom_zone, aom_still
	variable monitored_channel = 0
	string polarity = "pol_unipolar"  // pol_undefined, pol_unipolar, pol_bipolar
	string source = "aos_kelvin"  // aos_undefined, aos_kelvin, aos_ohm, aos_linear_data
	
	sprintf payload, "{\"high_value\": %f,\n  \"low_value\": %f,\n  \"manual_value\": %f,\n  \"mode\": \"%s\",\n  \"monitored_channel\": %d,\n  \"polarity\": \"%s\",\n  \"source\": \"%s\"}",\
							high_value, low_value, manual_value, mode, monitored_channel, polarity, source


	sprintf command, "set-analog-output-parameters/%s/%s",  ls_label, api_channel
	sendLS370(instrID,command,"put",payload=payload)
end


//set-analog-output-power
// SEE setLS370heaterpower()


// set-data-loggers-schedule
function setLS370loggersSchedule(instrID, schedule)
	// Sets the schedule of reading temperatures and heating powers from the Lakeshore. See LoggingSchedule.txt in Data:config folder
	string instrID, schedule
	svar ls_label
	string command, payload
 
	strswitch (schedule)
		case "default":
			payload = LS370getLoggingScheduleFromConfig("default")
			break
		case "default_nomag":
			payload = LS370getLoggingScheduleFromConfig("default_nomag")
			break
		case "mc_exclusive":
			payload = LS370getLoggingScheduleFromConfig("mc_exclusive")
			break
		case "still_exclusive":
			payload = LS370getLoggingScheduleFromConfig("still_exclusive")
			break
		case "using_magnet":
			payload = LS370getLoggingScheduleFromConfig("using_magnet")
			break
		case "fast":
			payload = LS370getLoggingScheduleFromConfig("fast")
			break
		case "slow":
			payload = LS370getLoggingScheduleFromConfig("slow")
			break
		default:
			abort "Not a valid option"
	endswitch 

	sprintf command, "set-data-loggers-schedule/%s", ls_label
	sendLS370(instrID,command,"put", payload=payload)
end


// set-heater-power-milliw
function setLS370heaterpower(instrID,heater,output) //Units: mW
	// sets the manual heater output
	// avaliable heaters on BF systems: mc,still
	// avaliable heaters on IGH: mc,still,sorb
	string instrID
	string heater
	variable output
	svar ls_system, bfheaterlookup,ighheaterlookup
	nvar mcheater_set, stillheater_set
	variable heater_idx
	string channel
	string command, payload
	svar ls_label

	// check for NAN and INF
	if(numtype(output) != 0)
		abort "trying to set power to NaN or Inf"
	endif

	strswitch(ls_system)
		case "bfsmall":
		case "bfbig":
			heater_idx = whichlistitem(heater,bfheaterlookup,";", 0, 0)
			if(heater_idx < 0)
				printf "The requested heater (%s) doesn't exsist!", heater
				return -1.0
			else
				channel = stringfromlist(heater_idx+2,bfheaterlookup,";")
			endif
			break
		default:
			abort "invalid ls_system"
	endswitch

	if(cmpstr(channel, "") != 0)
		if (cmpstr(channel, "sc_mc") !=0)  // If not interal label for MC assume Still heater
			sprintf command, "set-analog-output-power/%s/%s/%f", ls_label, channel, output
			stillheater_set = output
		else // set MC heater
			sprintf command, "set-heater-power-milliw/%s/%f", ls_label, output
			mcheater_set = output
		endif
	else
		string err
		sprintf err, "Heater %s not found in bfheaterlookup"
		abort err
	endif
	sendLS370(instrID,command,"put")
end


// set-heater-range-amps
function setLS370heaterRange(instrID, max_current_mA)
	string instrID
	variable max_current_mA
	svar ls_label
	
	string command, response
	variable true_val
	
	sprintf command, "set-heater-range-amps/%s/%f", ls_label, max_current_mA/1000
//	print command, ls_label, max_current_mA/1000
	response = sendLS370(instrID,command,"put", keys="data")
	
	// Can only be set to certain values, if tried to set to something > 10% different then warn user.
	true_val = str2num(response)*1000
	if((true_val-max_current_mA)/max_current_mA > 0.1)
		printf "WARNING[setLS370heaterRange]: Requested %.2fmA, set to closest allowable value of %.2fmA instead\r", max_current_mA, true_val
	endif	
end


// set-temperature-control-mode
function setLS370controlMode(instrID, mode) // Units: No units
	// sets the temperature control mode
	// avaliable options are: off (4), PID (1), Temp_zone (2), Open loop (3)
	string instrID
	variable mode

	nvar pid_mode
	svar ls_label
	string command
	string mode_str = LS370_mode_to_str(mode)
	sprintf command, "set-temperature-control-mode/%s/%s", ls_label, mode_str
	sendLS370(instrID,command,"put")
	pid_mode = mode	
end

// set-temperature-control-parameters
function setLS370controlParameters(instrID)
	// Set temperature control parameters excluding PID, max_current, control_mode
	string instrID
	svar ls_label
	
	string command, payload
	svar bfbd_ChannelLookUp
	
	// TODO: Is there anything here we do want to be able to change easily? Mostly looks like defaults we don't need to change
	print "[setLS370ControlParameters]: See function if you want to change any of the default values or make selectable"
	string channel = stringfromlist(5,bfbd_ChannelLookUp,";") // MC API_label
	variable delay = 1
	string heater_output_display_type = "HODT_current" // HODT_current, HODT_power
	variable max_heater_level = 8 // A limit on the power output of the heater (8 is max, but we limit with max_heater_current seperately)
	string setpoint_units = "SU_kelvin" // SU_kelvin, SU_celsius
	string use_filtered_values = "true" 
	
	sprintf payload, "{\"channel_label\": \"%s\", \"delay\": \"%d\", \"heater_output_display_type\":\"%s\", \"max_heater_level\": \"%d\", \"setpoint_units\":\"%s\", \"use_filtered_values\":%s}" \
												channel, delay, heater_output_display_type, max_heater_level, setpoint_units, use_filtered_values
	sprintf command, "set-temperature-control-parameters/%s", ls_label
	sendLS370(instrID,command,"put",payload=payload)
end


// set-temperature-control-setpoint
function setLS370tempSetpoint(instrID,temp) // Units: mK
	// sets the target temperature for PID control
	string instrID
	variable temp
	string command
	svar ls_label
	nvar temp_set

	// check for NAN and INF
	if(numtype(temp) != 0)
		abort "trying to set temperarture to NaN or Inf"
	endif
	
	sprintf command, "set-temperature-control-setpoint/%s/%f", ls_label, temp/1000
	sendLS370(instrID,command,"put")
	temp_set = temp

end


// set-temperature-pid
function setLS370PIDparameters(instrID,p,i,d) // Units: No units
	// set the PID parameters for the PID control loop
	// P = {0.001 1000}, I = {0 10000}, D = {0 2500}
	string instrID
	variable p,i,d
	nvar p_value,i_value,d_value
	string command,payload,cmd
	svar ls_label

	// check for NAN and INF
	if(numtype(p) != 0 || numtype(i) != 0 || numtype(d) != 0)
		abort "trying to set PID parameters to NaN or Inf"
	endif

	if(0.001 <= p && p <= 1000 && 0 <= i && i <= 10000 && 0 <= d && d <= 2500)

		sprintf payload, "{\"P\":%f, \"I\":%f, \"D\":%f}", p, i, d
		sprintf command, "set-temperature-pid/%s", ls_label
		sendLS370(instrID,command,"put",payload=payload)	

		p_value = p
		i_value = i
		d_value = d
	else
		abort "PID parameters out of range"
	endif
	
end


// turn-heater-off
function setLS370heaterOff(instrID)
	// turns off MC heater
	string instrID
	string command, payload
	svar ls_label
	nvar pid_mode

	sprintf command, "turn-heater-off/%s", ls_label
	sendLS370(instrID,command,"post")
	pid_mode = 4
end


//////// Set functions which don't map directly to API but are useful //////////

function setLS370temp(instrID,setpoint,[maxcurrent, verbose]) //Units: mK, mA
	// Sets both setpoint and max_current if passed, else estimates using LS370_estimateheaterrange
	string instrID
	variable setpoint, maxcurrent, verbose
	string payload, command
	svar ls_label
	nvar temp_set
	
	if (paramisdefault(maxcurrent))
		maxcurrent = LS370_estimateheaterrange(setpoint)
	endif
	if (verbose)
		printf "\nSetLS370Temp Verbose Mode -------- \n\nSetting Max Current: %f\nSetting Setpoint: %f\n", maxcurrent, setpoint
	endif

	// check for NAN and INF
	if(numtype(setpoint) != 0)
		abort "trying to set setpoint to NaN or Inf"
	endif
	
	nvar pid_mode // Note: PID mode needs to be set to 1 before HeaterRange can be set
	if (pid_mode != 1)
		if (verbose)
			print "PID control mode was not 1, setting to 1 now"
		endif
		setLS370controlMode(instrID, 1)
	endif
	setLS370HeaterRange(instrID, maxcurrent)
	setLS370TempSetpoint(instrID, setpoint)

end


function setLS370exclusivereader(instrID,channel)
	// This function is just for backwards compatability and convenience, it points to setLS370loggersSchedule
	string instrID, channel
	variable interval
	string command, payload
	svar ls_label
	
	string sched_name = "", err_str

	strswitch (channel)
		case "mc":
			sched_name = "mc_exclusive"
			break
		case "still":
			sched_name = "still_exclusive"
			break
		default:
			sprintf err_str, "ERROR[setLS370exclusivereader]:Need to add logger schedule to LoggingSchedules.txt for channel %s first. Then modify this func", channel
			abort err_str
			break
	endswitch
	setLS370loggersSchedule(instrID, sched_name)	
end

function resetLS370exclusivereader(instrID)
	string instrID
	string command, payload
	svar ls_label
	setLS370loggersSchedule(instrID, "default")
end



////////////////////
//// Utillities ////
///////////////////

function WaitTillTempStable(instrID, targetTmK, times, delay, err)
	// instrID is the lakeshore controller ID
	// targetmK is the target temperature in mK
	// times is the number of readings required to call a temperature stable
	// delay is the time between readings
	// err is a percent error that is acceptable in the readings
	string instrID
	variable targetTmK, times, delay, err
	variable passCount, targetT=targetTmK/1000, currentT = 0

	// check for stable temperature
	print "Target temperature: ", targetTmK, "mK"

	variable j = 0
	for (passCount=0; passCount<times; )
		asleep(delay)
//		for (j = 0; j<10; j+=1)
//			currentT += getLS370temp(instrID, "mc")/10 // do some averaging
//			asleep(2.1)
//		endfor
		currentT = getls370temp(instrID, "mc")
		if (ABS(currentT-targetT) < err*targetT)
			passCount+=1
			print "Accepted", passCount, " @ ", currentT, "K"
		else
			print "Rejected", passCount, " @ ", currentT, "K"
			passCount = 0
		endif
		currentT = 0
	endfor
end

function/s LS370getLoggingScheduleFromConfig(sched_name)
	string sched_name
	// reads LoggingSchedules from LoggingSchedules.txt file on "config" path.
	svar ls_label
	
	variable js_id
	string file_name
	sprintf file_name "%sLoggingSchedules.txt", ls_label
	js_id = JSON_parse(readtxtfile(file_name,"setup"))
	findvalue/TEXT=sched_name JSON_getkeys(js_id, "")
	if (V_value == -1)
		string err_str
		sprintf err_str "%s not found in top level keys of LoggingSchedules.txt" sched_name
		abort 	err_str
	endif
//	return JSON_getString(js_id, sched_name)
	return JSON_dump(getJSONXid(js_id, sched_name))
end


function/s LS370_mode_to_str(mode)
	//Convert from mode variable used here to mode_str used in API
	//off (4), PID (1), Temp_zone (2), Open loop (3)
	variable mode
	string mode_str = ""

	switch (mode)
		case 1:
			mode_str = "TCM_closed_loop"
			break
		case 2:
			mode_str = "TCM_zone_tuning"
			break
		case 3:
			mode_str = "TCM_open_loop"
			break
		case 4:
			mode_str = "TCM_off"
			break
		default:
			print "[WARNING] LS370_mode_to_str: Invalid mode passed, returning TCM_off"
			mode_str = "TCM_off"
			break
	endswitch
	return mode_str
end

function LS370_mode_str_to_mode(mode_str)
	// Convert from mode_str used in API to variable mode used here
	//off (4), PID (1), Temp_zone (2), Open loop (3)
	string mode_str
	int mode
	
	strswitch (mode_str)
		case "TCM_closed_loop":
			mode = 1
			break
		case "TCM_zone_tuning":
			mode = 2
			break
		case "TCM_open_loop":
			mode = 3
			break
		case "TCM_off":
			mode = 4
			break
		default:
			print "[WARNING] LS370_mode_str_to_mode: Invalid mode_str passed, returning -1"
			mode = -1
			break
	endswitch
	return mode
end

function LS370_estimateheaterrange(temp) // Units: mK
	// sets the heater range based on the wanted output
	// uses the range lookup table
	// avaliable ranges: 1,2,3,4,5,6,7,8 --> 0,10,30,95,501,1200,5000,10000 mK
	variable temp
	wave mcheatertemp_lookup
	make/o/n=8 heatervalues
	make/o/n=8 mintempabs
	make/o/n=8 mintemp
	variable maxcurrent

	heatervalues = mcheatertemp_lookup[p][1]
	mintempabs = abs(heatervalues-temp)
	mintemp = heatervalues-temp
	FindValue/v=(wavemin(mintempabs)) mintempabs
	if(mintemp[v_value] < 0)
		maxcurrent = mcheatertemp_lookup[v_value+1][0]
	else
		maxcurrent = mcheatertemp_lookup[v_value][0]
	endif

	return maxcurrent
end


function LS370createGobals()
	// Create the needed global variables for driver

	// TODO: Should we be calling any get* functions in here to see if anything has changed, or is that overkill?
	nvar/z temp_set 
	if (!nvar_Exists(temp_set))
		variable/g temp_set = 0
	endif
	nvar/z mcheater_set
	if (!nvar_Exists(mcheater_set))
		variable/g mcheater_set = 0
	endif
	nvar/z stillheater_set
	if (!nvar_Exists(stillheater_set))
		variable/g stillheater_set = 0
	endif
	nvar/z p_value
	if (!nvar_Exists(p_value))
		variable/g p_value = 10
	endif
	nvar/z i_value
	if (!nvar_Exists(i_value))
		variable/g i_value = 5
	endif
	nvar/z d_value
	if (!nvar_Exists(d_value))
		variable/g d_value = 0
	endif
	nvar/z pid_mode
	if (!nvar_Exists(pid_mode))
		variable/g pid_mode = 4 //1=Open_loop (manual heating), 2=Zone_tuning (we don't use), 3=Closed_loop (PID temp control), 4=Off, -1=undefined/error somewhere
	endif
end


///////////////////////
//// Communication ////
//////////////////////

function/s sendLS370(instrID,cmd,method,[payload, keys])
	// function takes: instrID,cmd,responseformat,method and payload
	// paylod is a json string to send with a POST request
	// keys is a string specifying JSON keys, if keys are provided, function returns the value as a string
	//      if no keys are provided, an empty string is returned
	string instrID, cmd, keys, method, payload
	string response
	
	payload = selectstring(paramisdefault(payload), payload, "")  // Some PUT/POST commands require no payload

//	print "SendLS370 temporarily disabled"
	string headers = "accept: application/json\rlcmi-auth-token: swagger"
	if(cmpstr(method,"get")==0)
//		printf "GET: %s%s\rHeaders: %s\r", instrID, cmd, headers  		// DEBUG
		response = getHTTP(instrID,cmd,headers)
//		printf "RESPONSE: %s\r", response									// DEBUG
	elseif(cmpstr(method,"post")==0)
//		printf "POST: %s%s\rHeaders: %s\r", instrID, cmd, headers  	// DEBUG
		response = postHTTP(instrID,cmd,payload,headers)
//		printf "RESPONSE: %s\r", response									// DEBUG
	elseif(cmpstr(method,"put")==0)
//		printf "PUT: %s%s\rHeaders: %s\r", instrID, cmd, headers  		// DEBUG
//		printf "PAYLOAD: %s\r", payload										// DEBUG
		response = putHTTP(instrID,cmd,payload,headers)
//		printf "RESPONSE: %s\r", response									// DEBUG
	else
		abort "Not a supported method"
	endif
	
	// Check "ok": true in response
	string resp_ok, err_msg
	resp_ok = getJSONvalue(response, "ok")
	if(cmpstr(resp_ok, "true") !=0)
		printf err_msg "ERROR[sendLS370]: Server responded with \"ok\": %s\r\rFull response: \r%s\r", resp_ok, response
		abort "ERROR[sendLS370]: Server responded with \"ok\": " + resp_ok
	endif
	
	// Get key requested from response
	if(!paramisdefault(keys))
		string value = getJSONvalue(response, keys)
		if(strlen(value)==0)
			print "[ERROR] LS370 returned empty string for key: "+keys
		endif
		return value
	else
		return ""
	endif
end

//////////////////
///// Status /////
//////////////////

function/s getLS370Status(instrID)
	// instrID is passed to getLS370temp if needed
	string instrID

	svar ls_system
	string channelLabel="", stillLabel="", ch_idx="", file_name = ""
	if(cmpstr(ls_system,"bfsmall") == 0)
		channelLabel = "ld_mc,ld_50K,ld_4K,ld_magnet,ld_still"
		stillLabel = "ld_still_heater"
//		ch_idx = "6,1,2,4,5"
		ch_idx = "mc,50k,4k,magnet,still"
		file_name = "LDLoggingSchedules.txt"
	elseif(cmpstr(ls_system,"bfbig") == 0)
//		channelLabel = "xld_mc, xld_50K,xld_4K,xld_magnet,xld_still"
		channelLabel = "ch6,ch1,ch2,ch3,ch5"
		stillLabel = "xld_still_heater"
//		ch_idx = "1,2,3,5,6"
		ch_idx = "mc,50k,4k,magnet,still"
		file_name = "XLDLoggingSchedules.txt"
	else
		print "[ERROR] \"getLSStatus\": pass the system id as instrID: \"ld\" or \"xld\"."
	endif

	// Load database schemas from SQLConfig.txt
	string jstr = readtxtfile("SQLConfig.txt","setup")
	if(cmpstr(jstr,"")==0)
		abort "SQLConfig.txt not found!"
	endif

	string database = getJSONvalue(jstr,"database")
	string temp_schema = getJSONvalue(jstr,"temperature_schema")
	string mc_heater_schema = getJSONvalue(jstr,"mc_heater_schema")
	string still_heater_schema = getJSONvalue(jstr,"still_heater_schema")

	svar ls_label

	jstr = readtxtfile(file_name,"setup")
	if(cmpstr(jstr,"")==0)
		abort file_name + " not found!"
	endif

	//// Temperatures ////

	// Get temperature data from SQL database
	string JSONkeys = "MC K,50K Plate K,4K Plate K,Magnet K,Still K"
	string LSkeys = "mc,50K,4K,magnet,still"
	string searchStr="", statement="", timestamp="", temp="", tempBuffer="", channel_label
	variable i=0
	for(i=0;i<itemsinlist(channelLabel,",");i+=1)
		// Use the "default" schedules "max" allowed times to decide what is the oldest allowed recorded temperature
		sprintf searchStr, "default:channels:%s:max", stringfromlist(i,channelLabel,",") 
		
		//UNCOMMENT WHEN ABLE TO CONNECT TO DATABASE
		timestamp = sc_SQLtimestamp(str2num(getJSONvalue(jstr,searchStr)))	
			
//		timestamp = sc_SQLtimestamp(3600) // Temporarily allow any old measurement of temp
//		timestamp = sc_SQLtimestamp(1) // Temporarily always request new

		// Ask the database if it has a recent enough temperature		
		sprintf statement, "SELECT temperature_k FROM %s.%s WHERE channel_label='%s' AND time > TIMESTAMP '%s' ORDER BY time DESC LIMIT 1;", database, temp_schema, stringfromlist(i,channelLabel,","), timestamp
		temp = requestSQLValue(statement)

		// If the database did not have a recent enough temperature, ask for a new one from the lakeshore (this takes 10 - 20s per channel)
		if(cmpstr(temp,"") == 0)
			temp = num2str(getLS370temp(instrID,stringfromlist(i,LSkeys,",")))
		endif

		// add to meta data
		tempBuffer = addJSONkeyval(tempBuffer, stringfromlist(i,JSONkeys,","), temp)
	endfor

	tempBuffer = addJSONkeyval("","Temperature",tempBuffer)
	// end temperature part

	//// Heaters ////
	// MC heater
//	string heatBuffer=""
//	timestamp = sc_SQLtimestamp(300)
//	sprintf statement, "SELECT power_milliw FROM %s.%s WHERE time > TIMESTAMP '%s' ORDER BY time DESC LIMIT 1;", database, mc_heater_schema, timestamp
//	heatBuffer = addJSONkeyval(heatBuffer,"MC Heater mW",requestSQLValue(statement))
//
//	// Still heater
//	sprintf statement, "SELECT power_milliw FROM %s.%s WHERE channel_label='%s' AND time > TIMESTAMP '%s' ORDER BY time DESC LIMIT 1;", database, still_heater_schema, stillLabel, timestamp
//	heatBuffer = addJSONkeyval(heatBuffer,"Still Heater mW",requestSQLValue(statement))
//
//	string buffer = addJSONkeyval(tempBuffer,"Heaters",heatBuffer)
	string buffer = tempBuffer
	
	return addJSONkeyval("","Lakeshore",buffer)

//	string buffer
//	buffer = getls370status_nosql(instrID)
//	return buffer
end



function/s getls370status_nosql(instrID)
	string instrID

	make/free/t LS_keys = {"MC", "50K", "4K", "Magnet", "Still"}
	make/free/t JSON_keys = {"MC K","50K Plate K","4K Plate K","Magnet K","Still K"}

//	make/free/t LS_keys = {"MC"} //, "50K", "4K", "Magnet", "Still"}
//	make/free/t JSON_keys = {"MC K"} //,"50K Plate K","4K Plate K","Magnet K","Still K"}


	string temp="", Buffer=""
	string LS_key, JSON_key
	variable i
	for (i=0; i<numpnts(LS_keys); i++)
		LS_key = LS_keys[i]
		JSON_key = JSON_keys[i]
		temp = num2str(getls370temp(instrID, LS_key))
		Buffer = addJSONkeyval(Buffer, JSON_key, temp)
	endfor

	Buffer = addJSONkeyval("","Temperature",Buffer)
	Buffer = addJSONkeyval("","Lakeshore",Buffer)

	return Buffer
end



function/s getBFStatus(instrID)
	// instrID is not used here, just pass any string. It's kept for consistency.
	string instrID

	svar ls_system

	// Load database schemas from SQLConfig.txt
	string jstr = readtxtfile("SQLConfig.txt","setup")
	if(cmpstr(jstr,"")==0)
		abort "SQLConfig.txt not found!"
	endif

	//// Pressure ////

	string database = getJSONvalue(jstr,"database")
	string pressure_schema = getJSONvalue(jstr,"pressure_schema")
 	string channelLabel = "CH1,CH2,CH3,CH4,CH5,CH6"

	variable i=0
	string pres="", presBuffer="", timestamp="", statement=""
	for(i=0;i<itemsinlist(channelLabel,",");i+=1)
		timestamp = sc_SQLtimestamp(300)
		sprintf statement, "SELECT pressure_mbar FROM %s.%s WHERE channel_id='%s' AND time > TIMESTAMP '%s' ORDER BY time DESC LIMIT 1;", database, pressure_schema, stringfromlist(i,channelLabel,","), timestamp
		pres = requestSQLValue(statement)

		presBuffer = addJSONkeyval(presBuffer, stringfromlist(i,channelLabel,",")+" mbar", pres)
	endfor

	presBuffer = addJSONkeyval("","Pressure",presBuffer)

	//// flow ////
	string flowBuffer=""
	string flow_schema = getJSONvalue(jstr,"flow_schema")
 	sprintf statement, "SELECT flow_mmol_per_s FROM %s.%s WHERE time > TIMESTAMP '%s' ORDER BY time DESC LIMIT 1;", database, flow_schema, timestamp
	flowBuffer = addJSONkeyval(flowBuffer,"Flow mmol/s",requestSQLValue(statement))

	string buffer = addJSONkeyval(presBuffer,"Mixture Flow",flowBuffer)

	return addJSONkeyval("","BlueFors",buffer)
end

function/s getLS370HeaterStatus(instrid, [full])
	// Get some information about what the LS is currently doing (i.e. heaters on, and what control parameters for those heaters)
	string instrid
	variable full

	string buffer
	sprintf buffer, "\nMC Heater Power: %f, Heater Range: %f, Current Setpoint: %f\n", getLS370heaterpower(instrid, "mc"), getls370heaterrange(instrid), getLs370PIDtemp(instrid)
	sprintf buffer, "%sStill Heater Power: %f\n", buffer, getLS370heaterpower(instrid, "still")
	
	// This is in getLS370controlmode(...)
	string command, response
	svar ls_label // Set when opening connection to lakeshore
	sprintf command, "get-temperature-control-mode/%s", ls_label
	response = sendLS370(instrID,command,"get", keys="data")
	sprintf buffer, "%sControl mode is %s\n", buffer, response
	///////////////////////////////////////////////
		
	if (full)
		sprintf buffer, "%s\nHeater Control Parameters: \n %s \n", buffer, getLS370controlParameters(instrid)
	
		sprintf buffer, "%s\nHeater Controller Info: \n %s \n", buffer, getLS370controllerInfo(instrid, all=1)
		
		sprintf buffer, "%s\nLS370 Analog Parameters: \n %s \n", buffer, getLS370analogParameters(instrid, channel="still")
	endif
	
	return buffer
end

////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// TESTING MACRO //////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
// This function can be used to test ALL of the get/set commands used with the LS370 as of 
// Jun 24th 2020


function test_lakeshore(ls370, [gets, sets, set_defaults, ask])
	// Testing all Lakeshore commands
	string ls370
	variable gets, sets, ask, set_defaults
	
	ask = paramisdefault(ask) ? 1 : ask
	variable ans
	
	if(gets == 1)
//		print 	"COMMAND: getLS370analogData(ls370, channel=\"still\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370analogData(ls370, channel="still")
//		endif
//		
//		print 	"COMMAND: getLS370analogParameters(ls370, channel=\"still\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370analogParameters(ls370, channel="still")
//		endif
//		
//		print 	"COMMAND: getLS370temp(ls370, \"mc\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370temp(ls370, "mc")
//		endif
//		
//		print 	"COMMAND: getLS370temp(ls370, \"still\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370temp(ls370, "still")
//		endif		
//		
//		print 	"COMMAND: getLS370temp(ls370, \"4k\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370temp(ls370, "4k")
//		endif		
//		
//		print 	"COMMAND: getLS370temp(ls370, \"magnet\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370temp(ls370, "magnet")
//		endif
//		
//		print 	"COMMAND: getLS370temp(ls370, \"50k\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370temp(ls370, "50k")
//		endif	
//		
//		print 	"COMMAND: getLS370controllerInfo(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370controllerInfo(ls370)
//		endif	
//		
//		print 	"COMMAND: getLS370controllerInfo(ls370, all=1)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370controllerInfo(ls370, all=1)
//		endif	
//		
//		print 	"COMMAND: getLS370loggersSchedule(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370loggersSchedule(ls370)
//		endif	
//		
//		print 	"COMMAND: getLS370heaterpower(ls370 ,\"mc\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370heaterpower(ls370 ,"mc")
//		endif	
//		
//		print 	"COMMAND: getLS370heaterpower(ls370 ,\"still\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370heaterpower(ls370 ,"still")
//		endif	
//		   
//		// TODO: Is return in mA or A?
//		print 	"COMMAND: getLS370heaterrange(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370heaterrange(ls370)
//		endif	
//		
//		print 	"COMMAND: getLS370controlmode(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370controlmode(ls370)
//		endif	
//		   
//		print 	"COMMAND: getLS370controlParameters(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370controlParameters(ls370)
//		endif	
//		   
//		print 	"COMMAND: getLS370PIDtemp(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370PIDtemp(ls370)
//		endif	
//		   
//		print 	"COMMAND: getLS370PIDparameters(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370PIDparameters(ls370)
//		endif	
//		   
////////		print 	"COMMAND: \r"
////////		ans = test_lakeshore_ask_continue(ask)
////////		if(ans == 1)
////////			printf "RETURN: %f\r\r", getLS370tempDB(ls370,plate, [max_age])
////////		endif			
//		
//		print 	"COMMAND: getLS370status(ls370, max_age_s=0)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370status(ls370, max_age_s=0)
//		endif	
//		
////////		print 	"COMMAND: getLS370status(ls370, max_age_s=3000)\r"
////////		ans = test_lakeshore_ask_continue(ask)
////////		if(ans == 1)
////////		   printf "RETURN: %s\r\r", getLS370status(ls370, max_age_s=3000)
////////		endif	
	endif
	
	if(sets == 1)
//		print 	"COMMAND: setLS370analogOutputParameters(ls370, channel=\"still\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370analogOutputParameters(ls370, channel="still")
//		endif
//
//		print 	"COMMAND: getLS370analogParameters(ls370, channel=\"still\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370analogParameters(ls370, channel="still")
//		endif
////////			
/////////////////////// LOGGING SCHEDULES ////////////////////////////////////////////////
//		print 	"COMMAND: setLS370loggersSchedule(ls370, \"default\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370loggersSchedule(ls370, "default")
//		endif	
//		
//		print 	"COMMAND: getLS370loggersSchedule(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370loggersSchedule(ls370)
//		endif	
//		
//		print 	"COMMAND: setLS370loggersSchedule(ls370, \"mc_exclusive\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370loggersSchedule(ls370, "mc_exclusive")
//		endif	
//		
//		print 	"COMMAND: getLS370loggersSchedule(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370loggersSchedule(ls370)
//		endif	
//			
//		print 	"COMMAND: setLS370loggersSchedule(ls370, \"still_exclusive\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370loggersSchedule(ls370, "still_exclusive")
//		endif	
//		
//		print 	"COMMAND: getLS370loggersSchedule(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370loggersSchedule(ls370)
//		endif		
//		
//		print 	"COMMAND: setLS370loggersSchedule(ls370, \"using_magnet\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370loggersSchedule(ls370, "using_magnet")
//		endif	
//		
//		print 	"COMMAND: getLS370loggersSchedule(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370loggersSchedule(ls370)
//		endif	
//		
/////////////////////// END OF LOGGING SCHEDULES //////////////////////////////////////////

/////////////////////// HEATER POWERS //////////////////////////////////////////
//		print 	"COMMAND: setLS370heaterpower(ls370,\"mc\",1)  //1mW heat\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370heaterpower(ls370,"mc",1)  //1mW heat
//		endif	
//	
//		print 	"COMMAND: getLS370heaterpower(ls370 ,\"mc\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370heaterpower(ls370 ,"mc")
//		endif	
//	
//		print 	"COMMAND: setLS370heaterpower(ls370,\"still\",1)  //1mW heat\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370heaterpower(ls370,"still",1)  //1mW heat
//		endif	
//			
//		print 	"COMMAND: getLS370heaterpower(ls370 ,\"still\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370heaterpower(ls370 ,"still")
//		endif	
/////////////////////// END OF HEATER POWERS //////////////////////////////////////////


/////////////////////// HEATER RANGES //////////////////////////////////////////
//		print 	"COMMAND: setLS370heaterRange(ls370, 5)  //5mA max\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370heaterRange(ls370, 5)  //5mA max
//		endif	
//		
//		print 	"COMMAND: getLS370heaterrange(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370heaterrange(ls370)
//		endif	
/////////////////////// END OF HEATER RANGES //////////////////////////////////////////		


/////////////////////// CONTROL MODES //////////////////////////////////////////		
//		print 	"COMMAND: setLS370controlMode(ls370, 1)  //PID\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370controlMode(ls370, 1)  //PID
//		endif	
//
//		print 	"COMMAND: getLS370controlmode(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370controlmode(ls370)
//		endif	
//		
//		print 	"COMMAND: setLS370controlMode(ls370, 3)  //PID\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370controlMode(ls370, 3)  //PID
//		endif	
//
//		print 	"COMMAND: getLS370controlmode(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370controlmode(ls370)
//		endif	
//			
//		print 	"COMMAND: setLS370controlMode(ls370, 4)  //off\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370controlMode(ls370, 4)  //off
//		endif	
//		
//		print 	"COMMAND: getLS370controlmode(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370controlmode(ls370)
//		endif	

/////////////////////// END OF CONTROL MODES //////////////////////////////////////////		
			

		print 	"COMMAND: setLS370controlParameters(ls370) //sets defaults (can be adapted later to give more control)\r"
		ans = test_lakeshore_ask_continue(ask)
		if(ans == 1)
			setLS370controlParameters(ls370) //sets defaults (can be adapted later to give more control)
		endif	
		
		print 	"COMMAND: getLS370controlParameters(ls370)\r"
		ans = test_lakeshore_ask_continue(ask)
		if(ans == 1)
		   printf "RETURN: %s\r\r", getLS370controlParameters(ls370)
		endif	

/////////////////////// PID PARAMS //////////////////////////////////////////		
//		print 	"COMMAND: setLS370tempSetpoint(ls370,100) //100mK\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370tempSetpoint(ls370,100) //100mK
//		endif	
//		
//		print 	"COMMAND: getLS370PIDtemp(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370PIDtemp(ls370)
//		endif	
//
//		print 	"COMMAND: setLS370PIDparameters(ls370,10,5,0)  // p,i,d: 10, 5, 0\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370PIDparameters(ls370,10,5,0)  // p,i,d: 10, 5, 0
//		endif	
//
//		print 	"COMMAND: getLS370PIDparameters(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370PIDparameters(ls370)
//		endif	
//

/////////////////////// END OF PID PARAMS //////////////////////////////////////////		
////////			
//		print 	"COMMAND: setLS370heaterOff(ls370)	// mc off\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370heaterOff(ls370)	// mc off
//		endif	
		


/////////////////////// PID TEMPERATURE CONTROL //////////////////////////////////////////

////////			
//		print 	"COMMAND: setLS370temp(ls370,100,maxcurrent=3.1)  //100mK max 3.1mA\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370temp(ls370,100,maxcurrent=3.1)  //100mK max 3.1mA
//		endif	
//
//		print 	"COMMAND: getLS370heaterrange(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370heaterrange(ls370)
//		endif	
//			
//		print 	"COMMAND: setLS370temp(ls370,200)  //100mK max current set automatically (should be 3.1 or 10)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370temp(ls370,200)  //100mK max current set automatically (should be 3.1 or 10)
//		endif	
//
//		print 	"COMMAND: getLS370heaterrange(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %f\r\r", getLS370heaterrange(ls370)
//		endif	
//////////		
/////////////////////// END OF PID TEMPERATURE CONTROL //////////////////////////////////////////


/////////////////////// EXCLUSIVE READERS //////////////////////////////////////////		
//		print 	"COMMAND: setLS370exclusivereader(ls370,\"mc\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370exclusivereader(ls370,"mc")
//		endif	
//
//		print 	"COMMAND: getLS370loggersSchedule(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370loggersSchedule(ls370)
//		endif	
//		
//		print 	"COMMAND: setLS370exclusivereader(ls370,\"still\")\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			setLS370exclusivereader(ls370,"still")
//		endif	
//			
//		print 	"COMMAND: getLS370loggersSchedule(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370loggersSchedule(ls370)
//		endif	
//			
//		print 	"COMMAND: resetLS370exclusivereader(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//			resetLS370exclusivereader(ls370)
//		endif	
//
//		print 	"COMMAND: getLS370loggersSchedule(ls370)\r"
//		ans = test_lakeshore_ask_continue(ask)
//		if(ans == 1)
//		   printf "RETURN: %s\r\r", getLS370loggersSchedule(ls370)
//		endif	
//		
/////////////////////// END OF EXCLUSIVE READERS //////////////////////////////////////////	
			
	endif
	
	if (set_defaults == 1)
		printf "Still heat was at %f. Setting to 0\r", 		getLS370heaterpower(ls370,"still")
		setLS370heaterpower(ls370,"still",0)
		
		printf "MC heat was at %f. Setting to 0\r", 			getLS370heaterpower(ls370,"mc")
		setLS370heaterOff(ls370)
		
		printf "PID params were: %s\rSetting PID to 10,5,0\r", getLS370PIDparameters(ls370)
		setLS370PIDparameters(ls370,10,5,0)
		
		printf "Temp control mode was %d, setting to 4 (off)\r", getLS370controlmode(ls370)
		setLS370controlMode(ls370, 4)  //off

		printf "Temp setpoint was %fmV, setting to 0mK\r",		getLS370PIDtemp(ls370)
		setLS370tempSetpoint(ls370,0) //100mK

		printf "Max heater current was %fmA, setting to 0mA\r", getLS370heaterrange(ls370)
		setLS370heaterRange(ls370, 0)  //5mA max

		printf "Logging schedule was:\r%s\r\rSetting to \"default\"\r",	getLS370loggersSchedule(ls370)
		setLS370loggersSchedule(ls370, "default")
	endif
	
end


function test_lakeshore_ask_continue(ask)
	variable ask
	
	variable ans
	if(ask ==1)
//		abort "WARNING: ask user has failed"
		ans = ask_user("Send command?", type=2)
		if (ans == 3)
			abort
		endif
		return ans
	else
		return 1
	endif
end

