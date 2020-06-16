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
	setLS370system(system)  // Sets channel/heater/temp lookup strings/waves
	createLS370Gobals() //Only inits values if not already existing
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
			ls_label = "LD"				//plate					//labels	  //IDs
			string/g bfchannellookup = "mc;still;magnet;4K;50K;6;5;4;2;1;6;5;4;2;1"  //TODO: Check with LD API
			string/g bfheaterlookup = "mc;still;sc_mc;2"						//sc_mc only used internally, still label refers to API //TODO: Check with LD API
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
			channel_idx = whichlistitem(plate,bfchannellookup,";")
			if(channel_idx < 0)
				printf "The requested plate (%s) doesn't exsist!", plate
				return 0.0
			else
				channel = stringfromlist(channel_idx+5,bfchannellookup,";")
			endif
			break
		default:
			abort "ls_system not implemented"
	endswitch
	
	string result
	
	// TODO: Try get from SQL first, and if recent enough then don't ask from Lakeshore!
	
	sprintf command, "get-channel-data/%d?ctrl_label=%s", channel, ls_label
	result = sendLS370(instrID,command,"get",keys="data:record:temperature_k") 
	return str2num(result)
end


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
			heater_idx = whichlistitem(heater,bfheaterlookup,";")
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

	if(cmpstr(channel, "") != 0)
		sprintf command, "get-analog-data/%s?ctrl_label=%s", channel, ls_label
	else
		sprintf command, "get-heater-data?ctrl_label=%s", ls_label
	endif
	
	return str2num(sendLS370(instrID,command,"get", keys="power_mw"))  // TODO: check this works for both MCheater and Still (analog) heater
end


function getLS370PIDtemp(instrID) // Units: mK
	// returns the setpoint of the PID loop.
	// the setpoint is set regardless of the actual state of the PID loop
	// and one can therefore always read the current setpoint (active or not)
	string instrID
	variable temp
	string payload, command
	svar ls_label
	nvar temp_set

	sprintf command, "get-temperature-control-setpoint?%s", ls_label

	string response = sendLS370(instrID,command,"get", keys="data")
	temp = str2num(response)*1000
	temp_set = temp
	return temp
end


function/s getLS370heaterrange(instrID) // Units: AU
	// range must be a number between 0 and 8
	string instrID
	variable range
	string command,payload,response
	svar ls_label

	sprintf command, "get-heater-range-amps/%s", ls_label

	response = sendLS370(instrID,command,"get", keys="data")
	return response
end


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


function getLS370controlmode(instrID, [verbose]) // Units: No units
	// returns the temperature control mode.
	// 1: PID, 3: Open loop, 4: Off
	string instrID
	variable verbose
	nvar pid_mode, pid_led, mcheater_led
	string payload, command,response
	svar ls_label

	sprintf command, "get-temperature-control-mode?%s", ls_label

	response = sendLS370(instrID,command,"get", keys="data", payload=payload)
	pid_mode = mode_str_to_mode(response)
	if (verbose)
		print "Control mode is ", response
	endif
	return pid_mode
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
			channel_idx = whichlistitem(plate,bfchannellookup,";")
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

function setLS370tempcontrolmode(instrID, mode) // Units: No units
	// sets the temperature control mode
	// avaliable options are: off (4), PID (1), Temp_zone (2), Open loop (3)
	string instrID
	variable mode

	nvar pid_mode
	svar ls_label
	string command
	
	sprintf command, "set-temperature-control-parameters/%s/%s", ls_label
	sendLS370(instrID,command,"put")

	pid_mode = mode	
end


function setLS370PIDcontrol(instrID,channel,setpoint,maxcurrent) //Units: mK, mA
	string instrID
	variable channel, setpoint, maxcurrent
	string payload, command
	svar ls_label
	nvar temp_set
	

	// check for NAN and INF
	if(sc_check_naninf(setpoint) != 0)
		abort "trying to set setpoint to NaN or Inf"
	endif

	// set-temperature-control-parameters  
	// TODO: This does not need to be called every time, should it be moved to seperate function?
	sprintf payload, "{\"channel_label\": %d, \"delay\": %d, \"use_filtered_values\":\"%s\", \"max_heater_level\": %d,  \"setpoint_units\":\"%s\", \"heater_output_display_type\":\"%s\"}", 	\
												channel, 				1, 									"true", 							8, 			 					"kelvin", 									"current"
	sprintf command, "set-temperature-control-parameters/%s", ls_label
	sendLS370(instrID,command,"put",payload=payload)
	
	// set-heater-range-amps //TODO: Check if this is how we can we set a max_current for the heating with new API?
	print "WARNING: NO MAX CURRENT SET" 
//	sprintf command, "set-heater-range-amps/%s/%f", ls_label, maxcurrent/1000
//	sendLS370(instrID,command,"put")
		
	// set-temperature-control-setpoint
	sprintf command, "set-temperature-control-setpoint/%s/%f", ls_label, setpoint/1000
	sendLS370(instrID,command,"put")
		
	temp_set = setpoint
end


function setLS370exclusivereader(instrID,channel,[interval])
	// BF small channels: [ld_mc_heater, ld_still_heater, ld_50k, ld_4k, ld_magnet, ld_still, ld_mc]
	// interval units: s
	string instrID, channel
	variable interval
	string command, payload
	svar ls_label

	abort "Not updated to new API"  // TODO: How to make this work with setLS370LoggersSchedule??

	if(paramisdefault(interval))
		interval=5
	endif
	

end


function GetLS370LoggingScheduleFromConfig(sched_name)
	string sched_name
	// reads LoggingSchedules from LoggingSchedules.txt file on "config" path.
	
	variable js_id
	js_id = JSON_parse(readtxtfile("LoggingSchedules.txt","config"))
	findvalue/TEXT=sched_name JSON_getkeys(js_id, "")
	if (V_value == -1)
		string err_str
		sprintf err_str "%s not found in top level keys of LoggingSchedules.txt, valid keys are ^^" sched_name
		print JSON_getkeys(js_id, "")
		abort 	err_str
	endif
	return JSON_dump(get_json_from_json_path(json_id, sched_name))
end

end


function setLS370loggersSchedule(instrID, schedule)
	string instrID, schedule
	svar ls_label
	string command, payload
	
	abort "Not finished for new API"  
	strswitch (schedule)
		case "default":
			payload = GetLS370LoggingScheduleFromConfig("default")
			break
		case "mc_exclusive":
			payload = GetLS370LoggingScheduleFromConfig("mc_exclusive")
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


function resetLS370exclusivereader(instrID)
	string instrID
	string command, payload
	svar ls_label
	abort "Not tested this yet"
	// TODO: Test this
	setLS370loggersSchedule(instrID, "default")
end


function setLS370TempSetpoint(instrID,temp) // Units: mK
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
			heater_idx = whichlistitem(heater,bfheaterlookup,";")
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

function turnoffLS370MCheater(instrID)
	// turns off MC heater
	string instrID
	string command, payload
	svar ls_label
	nvar pid_mode

	sprintf command, "turn-heater-off/%s", ls_label
	sendLS370(instrID,command,"post")
	pid_mode = 4
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

function/s mode_to_str(mode)
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
			print "[WARNING] mode_to_str: Invalid mode passed, returning TCM_off"
			mode_str = "TCM_off"
			break
	endswitch
	return mode_str
end

function mode_str_to_mode(mode_str)
	// Convert from mode_str used in API to variable mode used here
	//off (4), PID (1), Temp_zone (2), Open loop (3)
	string mode_str
	variable mode
	
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
			print "[WARNING] mode_str_to_mode: Invalid mode_str passed, returning -1"
			mode = -1
			break
	endswitch
end

function estimateheaterrangeLS370(temp) // Units: mK
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


function createLS370Gobals()
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
		response = getHTTP(instrID,cmd,headers)
//		print response
	elseif(cmpstr(method,"post")==0 && !paramisdefault(payload))
		response = postHTTP(instrID,cmd,payload,headers)
//		print response
	elseif(cmpstr(method,"put")==0 && !paramisdefault(payload))
		response = putHTTP(instrID,cmd,payload,headers)
//		print response
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
