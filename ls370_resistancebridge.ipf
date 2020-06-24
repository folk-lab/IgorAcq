#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method

// Driver for controling a Dilution fridge, via a LakeShore 370 controller and an intermidiate server
// running on a RPi.
// Call SetSystem() before anything else. Current supported systems are: BFsmall, IGH
// Communicates with server over http.
// Procedure written by Christian Olsen 2018-03-xx
// Modified to new API by Tim Child 2020-06-xx

// Todo:
// GetTempDB()
// GetHeaterPowerDB()
// GetPressureDB()
// QueryDB()

///////////////////////////
/// LS37X specific COMM ///
///////////////////////////

function openLS370connection(instrID, http_address, system, [verbose])
	// open/test a connection to the LS37X RPi interface written by Ovi
	//      the whole thing _should_ work for LS370 and LS372
	// instrID is the name of the global variable that will be used for communication
	// http_address is exactly what it sounds like
	// system is the name of the cryostat you are working on: bfsmall, igh, bfbig
	// verbose=0 will not print any information about the connection

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
			string/g bfchannellookup = "mc;still;magnet;4K;50K;ld_mc;ld_still;ld_magnet;ld_4K;ld_50K;6;5;4;2;1"  //TODO: Check with LD API
			string/g bfheaterlookup = "mc;still;sc_mc;ld_still_heater"						//sc_mc only used internally, still label refers to API //TODO: Check with LD API
			make/o mcheatertemp_lookup = {{31.6e-3,100e-3,316e-3,1.0,3.16,10,31.6,100},{0,10,30,95,350,1201,1800,10000}}
			break
		case "bfbig":
			ls_system = "bfbig"
			ls_label = "XLD"					//plate				//labels	  			//IDs
			string/g bfchannellookup = "mc;still;magnet;4K;50K;ch6;ch5;ch4;ch2;ch1;6;5;4;2;1"  //TODO: Check with XLD API
			string/g bfheaterlookup = "mc;still;sc_mc;2"							 		//sc_mc only used internally, still label refers to API 	//TODO: Check with XLD API
			make/o mcheatertemp_lookup = {{31.6e-3,100e-3,316e-3,1.0,3.16,10,31.6,100},{0,10,30,95,350,1201,1800,10000}} // TODO: What does this do?
			break
		default:
			abort "[ERROR] Please choose a supported LS370 system: [bfsmall, bfbig]"
	endswitch

end

///////////////////////
//// Get Functions ////
//////////////////////

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
	svar ls_system, bfchannellookup, ighchannellookup
	variable channel_idx
	string channel
	string command
	svar ls_label
	
	if(paramisdefault(max_age_s))
		max_age_s = 120
	endif

	strswitch(ls_system)
		case "bfsmall":
		case "bfbig":
			channel_idx = whichlistitem(plate,bfchannellookup,";", 0, 0)
			if(channel_idx < 0)
				printf "The requested plate (%s) doesn't exsist!\r", plate
				return 0.0
			else
				channel = stringfromlist(channel_idx+5,bfchannellookup,";")
			endif
			break
		default:
			abort "ls_system not implemented"
	endswitch
	
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
	return str2num(response)
end


// get-temperature-control-mode
function getLS370controlmode(instrID, [verbose]) // Units: No units
	// returns the temperature control mode.
	// 1: PID, 3: Open loop, 4: Off
	string instrID
	variable verbose
	nvar pid_mode, pid_led, mcheater_led
	string command,response
	svar ls_label

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



//// Get Functions - Directly from data base ////

function getLS370tempDB(instrID,plate, [max_age]) // Units: mK
	// returns the temperature of the selected "plate".
	// avaliable plates on BF systems: mc (mixing chamber), still, magnet, 4K, 50K
	// data is queried directly from the SQL database
	string instrID, plate
	variable max_age
	svar ls_system
	
	max_age = paramisdefault(max_age) ? 60 : max_age
	
	svar bfchannellookup
	string channel
	variable ch_id
	variable channel_idx
	
	strswitch(ls_system)
		case "bfsmall":
		case "bfbig":
			channel_idx = whichlistitem(plate,bfchannellookup,";", 0, 0)
			if(channel_idx < 0)
				printf "The requested plate (%s) doesn't exsist!", plate
				return -1
			else
				channel = stringfromlist(channel_idx+5,bfchannellookup,";")
				ch_id = str2num(stringfromlist(channel_idx+10,bfchannellookup,";"))  // TODO: Remove requirement for the actual ch_id and be able to use the label instead
			endif
			break
		default:
			abort "ls_system not implemented"
	endswitch
	
	nvar sqr = sql_response_code  // 0=success, 1=no_data, 2=other warning, -1=error
	variable t = datetime-max_age
	string timestamp = SQL_format_time(t)
	
	
	string command = ""
	sprintf command, "SELECT DISTINCT ON (ch_idx) ch_idx, time, t FROM qdot.lksh370.channel_data WHERE time > TIMESTAMP %s ORDER BY ch_idx, time DESC;", timestamp
	string wavenames = "sql_ls370_channels,sql_ls370_timestamp,sql_ls370_temperature"
	requestSQLData(command,wavenames=wavenames, verbose=1) // TODO: change verbose to 0
	if (sqr == 1) // no rows of data
		return -1
	else
		wave temp_wave = sql_ls370_temperature
		wave ch_wave = sql_ls370_channels
		wave t_wave = sql_ls370_timestamp
		print ch_wave
		print t
		print temp_wave
		return temp_wave(ch_id)  // return temp of channel // TODO: access this by label instead of ch_ID
	endif
end

//function getLS370heaterpowerDB(instrID,heater) // Units: mW
//	// returns the power of the selected heater.
//	// avaliable heaters on BF systems: still (analog 2), mc
//	// avaliable heaters on IGH systems: sorb (analog 1), still (analog 2), mc
//	// data is queried directly from the SQL database
//	string instrID
//	string heater
//end

//function getLS370pressureDB(instrID,gauge) // Units: mbar
//	// returns the pressure from the selected pressure gauge
//	// avaliable gauges on BF systems: P1,P2,P3,P4,P5,P6
//	// avaliable gauges on IGH systems: P1,P2,G1,G2,G3
//	// data is queried directly from the SQL database
//	string instrID
//	string gauge
//end

///////////////////////
//// Set Functions ////
//////////////////////

//set-analog-output-parameters
function setLS370analogOutputParameters(instrID, [channel])
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
	
	// TODO: What is useful to change here, do we have a default fixed state we want for analog outputs?
	abort "[setLS370AnalogOutputParameters]:If you really want to use this function, you need to figure out what parameters you want to be able to set below!"
	variable high_value = 0, low_value = 0, manual_value = 0
	string mode = "aom_undefined"  // aom_undefined, aom_off, aom_channel, aom_manual, aom_zone, aom_still
	variable monitored_channel = 0
	string polarity = "pol_undefined"  // pol_undefined, pol_unipolar, pol_bipolar
	string source = "aos_undefined"  // aos_undefined, aos_kelvin, aos_ohm, aos_linear_data
	
	sprintf payload, "{\"high_value\": %f,\n  \"low_value\": %f,\n  \"manual_value\": %f,\n  \"mode\": \"%s\",\n  \"monitored_channel\": %d,\n  \"polarity\": \"%s\",\n  \"source\": \"%s\"}",\
							high_value, low_value, manual_value, mode, monitored_channel, polarity, source


	sprintf command, "set-analog-parameters/%s/%s",  ls_label, api_channel
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
	
	abort "Not finished for new API"  
	strswitch (schedule)
		case "default":
			payload = LS370getLoggingScheduleFromConfig("default")
			break
		case "mc_exclusive":
			payload = LS370getLoggingScheduleFromConfig("mc_exclusive")
			break
		// Add other cases here (also add config to LoggingSchedules.txt in config folder)
		default:
			abort "Not a valid option"
	endswitch 
	//TODO: Test this
	abort "Not tested this yet, don't screw up logging schedule accidentally!"
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
	if(sc_check_naninf(output) != 0)
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
	
	string command
	
	sprintf command, "set-heater-range-amps/%s/%f", ls_label, max_current_mA/1000
	sendLS370(instrID,command,"put")
end


// set-temperature-control-mode
function setLS370tempMode(instrID, mode) // Units: No units
	// sets the temperature control mode
	// avaliable options are: off (4), PID (1), Temp_zone (2), Open loop (3)
	string instrID
	variable mode

	nvar pid_mode
	svar ls_label
	string command
	
	sprintf command, "set-temperature-control-mode/%s/%s", ls_label
	sendLS370(instrID,command,"put")
	pid_mode = mode	
end

// set-temperature-control-parameters
function setLS370controlParameters(instrID)
	// Set temperature control parameters excluding PID, max_current, control_mode
	string instrID
	svar ls_label
	
	string command, payload
	svar bfchannellookup
	
	// TODO: Is there anything here we do want to be able to change easily? Mostly looks like defaults we don't need to change
	print "[setLS370ControlParameters]: See function if you want to change any of the default values or make selectable"
	string channel = stringfromlist(5,bfchannellookup,";") // MC API_label
	variable delay = 1
	string heater_output_display_type = "HODT_power" // HODT_current, HODT_power
	variable max_heater_level = 8 // A limit on the power output of the heater (8 is max, but we limit with max_heater_current seperately)
	string setpoint_units = "SU_kelvin" // SU_kelvin, SU_celsius
	string use_filtered_values = "true"
	
	sprintf payload, "{\"channel_label\": \"%s\", \"delay\": %d, \"heater_output_display_type\":\"%s\", \"max_heater_level\": %d, \"setpoint_units\":\"%s\", \"use_filtered_values\":\"%s\"\"}" \
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
	if(sc_check_naninf(temp) != 0)
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
	if(sc_check_naninf(p) != 0 || sc_check_naninf(i) != 0 || sc_check_naninf(d) != 0)
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

function setLS370temp(instrID,setpoint,[maxcurrent]) //Units: mK, mA
	// Sets both setpoint and max_current if passed, else estimates using LS370_estimateheaterrange
	string instrID
	variable setpoint, maxcurrent
	string payload, command
	svar ls_label
	nvar temp_set
	
	if (paramisdefault(maxcurrent))
		maxcurrent = LS370_estimateheaterrange(setpoint)
	endif

	// check for NAN and INF
	if(sc_check_naninf(setpoint) != 0)
		abort "trying to set setpoint to NaN or Inf"
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
	//TODO: Test this
	setLS370loggersSchedule(instrID, "default")
end


// TODO: Do we want this?
function toggleLS370magnetheater(instrID,onoff)
	// toggles the state of the magnet heater on BF #1.
	// it sets ANALOG 1 to -50% (-5V) in the "on" state
	// and 0% (0V) in the off state.
	// ANALOG 1 controls a voltage controlled switch!
	string instrID
	string onoff
	variable output
	nvar magnetheater_led
	svar ls_system
	string command,payload,cmd
	svar ls_label

	abort "Not updated to new API"
	if(cmpstr(ls_system,"bfsmall") != 0)
		abort "No heater installed on this system!"
	endif

	strswitch(onoff)
		case "on":
			output = -50.000
			magnetheater_led = 1
			break
		case "off":
			output = 0.000
			magnetheater_led = 0
			break
		default:
			// default is "off"
			print "Setting to \"off\""
			output = 0.000
			magnetheater_led = 0
			break
	endswitch
	
	sprintf cmd, "ANALOG 1,1,2,1,1,100.0,0.0,%g", output
	sprintf payload, "{\"command\":%s}", cmd
	sprintf command, "command?ctrl_label=%s", ls_label
	sendLS370(instrID,command,"post", payload=payload)
end

////////////////////
//// Utillities ////
///////////////////

function/s LS370getLoggingScheduleFromConfig(sched_name)
	string sched_name
	// reads LoggingSchedules from LoggingSchedules.txt file on "config" path.
	
	variable js_id
	js_id = JSON_parse(readtxtfile("LoggingSchedules.txt","config"))
	findvalue/TEXT=sched_name JSON_getkeys(js_id, "")
	if (V_value == -1)
		string err_str
		sprintf err_str "%s not found in top level keys of LoggingSchedules.txt" sched_name
		abort 	err_str
	endif
	return JSON_getString(js_id, sched_name)
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

//	print "SendLS370 temporarily disabled"
	string headers = "accept: application/json\rlcmi-auth-token: swagger"
	if(cmpstr(method,"get")==0)
		printf "GET: %s%s\rHeaders: %s\r", instrID, cmd, headers  		// DEBUG
		response = getHTTP(instrID,cmd,headers)
		printf "RESPONSE: %s\r", response									// DEBUG
	elseif(cmpstr(method,"post")==0 && !paramisdefault(payload))
		printf "POST: %s%s\rHeaders: %s\r", instrID, cmd, headers  	// DEBUG
		response = postHTTP(instrID,cmd,payload,headers)
		printf "RESPONSE: %s\r", response									// DEBUG
	elseif(cmpstr(method,"put")==0 && !paramisdefault(payload))
		printf "PUT: %s%s\rHeaders: %s\r", instrID, cmd, headers  		// DEBUG
		printf "PAYLOAD: %s\r", payload										// DEBUG
		response = putHTTP(instrID,cmd,payload,headers)
		printf "RESPONSE: %s\r", response									// DEBUG
	else
		abort "Not a supported method or you forgot to add a payload."
	endif

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

function/s getLS370status(instrID, [max_age_s])
	// returns JSON string with current status
	string instrID
	variable max_age_s
	if(paramisdefault(max_age_s))
		max_age_s=300
	else
		//TODO: Implement max_age_s from SQL query
		print "max_age_s doesn't work and needs to be implemented differently (4th Feb 2020)"
	endif

	svar ls_system, ighgaugelookup
	string  buffer="", gauge=""
	variable i=0

	buffer = addJSONkeyval(buffer,"MC K",num2str(getLS370temp(instrID, "mc", max_age_s=max_age_s)))
	buffer = addJSONkeyval(buffer,"Still K",num2str(getLS370temp(instrID, "still", max_age_s=max_age_s)))
	buffer = addJSONkeyval(buffer,"4K Plate K",num2str(getLS370temp(instrID, "4K", max_age_s=max_age_s)))
	buffer = addJSONkeyval(buffer,"Magnet K",num2str(getLS370temp(instrID, "magnet", max_age_s=max_age_s)))
	buffer = addJSONkeyval(buffer,"50K Plate K",num2str(getLS370temp(instrID, "50K", max_age_s=max_age_s)))
	
	// TODO: add other variables like (temp setpoint, heater power etc)

	strswitch(ls_system)
		case "bfsmall":
			return addJSONkeyval("","BF Small",buffer)
		case "bfbig":
			return addJSONkeyval("","BF big",buffer)
	endswitch
end
