#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method

// Driver for controling a Dilution fridge, via a LakeShore 370 controller and an intermidiate server
// running on a RPi.
// Call SetSystem() before anything else. Current supported systems are: BFsmall, IGH
// Communicates with server over http.
// Procedure written by Christian Olsen 2018-03-xx

// Todo:
// GetTempDB()
// GetHeaterPowerDB()
// GetPressureDB()
// QueryDB()
// Add support for BF #2

////////////////////////////
//// Initiate Lakeshore ////
///////////////////////////

function initLS370(instrID)
	string instrID

	setLS370system() // Set the correct system!
	createLS370globals() // Create the needed global variables for the GUI
	// Build main control window
	dowindow/k Lakeshore
	execute("lakeshore_window()")
	// Update current values
	updateLS370GUI(instrID)
end

///////////////////////
//// Get Functions ////
//////////////////////

function getLS370temp(instrID,plate, [max_age]) // Units: K
	// returns the temperature of the selected "plate".
	// avaliable plates on BF systems: mc (mixing chamber), still, magnet, 4K, 50K
	// avaliable plates on IGH systems: mc (mixing chamber), cold plate, still, 1K, sorb
	// max_age determines how old a reading can be (in sec), before I demand a new one
	// from the server
	// max_age=0 always requests a new reading
	string instrID
	string plate
	variable max_age
	svar system, bfchannellookup, ighchannellookup
	variable channel_idx, channel
	string headers, command, token = "vMqyDIcB"

	if(paramisdefault(max_age))
		//return GetTempDB(plate) // Maybe it is better to set max_age = 120
		max_age = 120
	endif

	strswitch(system)
		case "bfsmall":
			channel_idx = whichlistitem(plate,bfchannellookup,";")
			if(channel_idx < 0)
				printf "The requested plate (%s) doesn't exsist!", plate
				return 0.0
			else
				channel = str2num(stringfromlist(channel_idx+5,bfchannellookup,";"))
			endif
			break
		case "igh":
			channel_idx = whichlistitem(plate,ighchannellookup,";")
			if(channel_idx < 0)
				printf "The requested plate (%s) doesn't exsist!", plate
				return 0.0
			else
				channel = str2num(stringfromlist(channel_idx+5,ighchannellookup,";"))
			endif
			break
		case "bfbig":
			break
	endswitch

	headers = "Content-Type: application/json"
	sprintf command, "get-channel-data/%d?max_age=%d&_at_=%s", channel, max_age, token
	checkLS370URL(instrID)
	return str2num(queryLS370(instrID,command,headers,"t","get"))
end

function getLS370heaterpower(instrID,heater, [max_age]) // Units: mW
	// returns the power of the selected heater.
	// avaliable heaters on BF systems: still (analog 2), mc
	// avaliable heaters on IGH systems: sorb (analog 1), still (analog 2), mc
	// max_age determines how old a reading can be (in sec), before a new is demanded
	// from the server
	// max_age=0 always requests a new reading
	string instrID
	string heater
	variable max_age
	svar system, bfheaterlookup, ighheaterlookup
	variable heater_idx, channel
	string headers, command, token = "vMqyDIcB"

	if(paramisdefault(max_age))
		//return GetHeaterPowerDB(heater)
		max_age = 120
	endif

	strswitch(system)
		case "bfsmall":
			heater_idx = whichlistitem(heater,bfheaterlookup,";")
			if(heater_idx < 0)
				printf "The requested heater (%s) doesn't exsist!", heater
				return -1.0
			else
				channel = str2num(stringfromlist(heater_idx+2,bfheaterlookup,";"))
			endif
			break
		case "igh":
			heater_idx = whichlistitem(heater,ighheaterlookup,";")
			if(heater_idx < 0)
				printf "The requested heater (%s) doesn't exsist!", heater
				return -1.0
			else
				channel = str2num(stringfromlist(heater_idx+3,ighheaterlookup,";"))
			endif
			break
		case "bfbig":
			break
	endswitch

	headers = "Content-Type: application/json"
	if(channel > 0)
		sprintf command, "get-analog-data/%d?max_age=%d&_at_=%s", channel, max_age, token
	else
		sprintf command, "get-heater-data?max_age=%d&_at_=%s", max_age, token
	endif
	checkLS370URL(instrID)
	return str2num(queryLS370(instrID,command,headers,"power_mw","get"))
end

function getLS370PIDtemp(instrID) // Units: mK
	// returns the setpoint of the PID loop.
	// the setpoint is set regardless of the actual state of the PID loop
	// and one can therefore always read the current setpoint (active or not)
	string instrID
	variable temp
	string headers, payload, command, token = "vMqyDIcB"
	nvar temp_set

	headers = "Content-Type: application/json"
	payload = "{\"command\": \"SETP?\"}"
	sprintf command, "command?_at_=%s", token
	checkLS370URL(instrID)
	string test = queryLS370(instrID,command,headers,"v","post",payload=payload)
	temp = str2num(test[1,inf])*1000
	temp_set = temp

	return temp
end

function/s getLS370heaterrange(instrID) // Units: AU
	// range must be a number between 0 and 8
	string instrID
	variable range
	string command,payload,headers,response,token = "vMqyDIcB"

	sprintf payload, "{\"command\": \"HTRRNG?\"}", range
	sprintf command, "command?_at_=%s", token
	headers = "Content-Type: application/json"
	checkLS370URL(instrID)
	response = queryLS370(instrID,command,headers,"v","post",payload=payload)
	return response[1,inf]
end

function/s getLS370PIDparameters(instrID) // Units: No units
	// returns the PID parameters used.
	// the retruned values are comma seperated values.
	// P = {0.001 1000}, I = {0 10000}, D = {0 2500}
	string instrID
	nvar p_value,i_value,d_value
	string headers, payload, pid, token = "vMqyDIcB", command

	headers = "Content-Type: application/json"
	payload = "{\"command\": \"PID?\"}"
	sprintf command, "command?_at_=%s", token
	checkLS370URL(instrID)
	pid = queryLS370(instrID,command,headers,"v","post",payload=payload)
	p_value = str2num(stringfromlist(0,pid[1,inf],","))
	i_value = str2num(stringfromlist(1,pid[1,inf],","))
	d_value = str2num(stringfromlist(2,pid[1,inf],","))

	return pid
end

function getLS370controlmode(instrID) // Units: No units
	// returns the temperature control mode.
	// 1: PID, 3: Open loop, 4: Off
	string instrID
	nvar pid_mode, pid_led, mcheater_led
	string headers,payload,token = "vMqyDIcB", command,response

	headers = "Content-Type: application/json"
	payload = "{\"command\": \"CMODE?\"}"
	sprintf command, "command?_at_=%s", token
	checkLS370URL(instrID)
	response = queryLS370(instrID,command,headers,"v","post",payload=payload)
	pid_mode = str2num(response[1,inf])

	if(pid_mode == 1)
		pid_led = 1
		mcheater_led = 1
		PopupMenu mcheater, mode=1
		SetVariable mcheaterset, disable=2
	elseif(pid_mode == 3)
		pid_led = 0
		mcheater_led = 1
		PopupMenu mcheater, mode=1
		SetVariable mcheaterset, disable=0
	elseif(pid_mode == 4)
		pid_led = 0
		mcheater_led = 0
		PopupMenu mcheater, mode=2
		SetVariable mcheaterset, disable=0
	else
		print "Control mode not in supported modes, turning off heater!"
		sc_sleep(0.5)
		setLS370tempcontrolmode(instrID,4)
	endif
end

//// Get Functions - Directly from data base ////

// NOT implimented yet!

function getLS370tempDB(instrID,plate) // Units: mK
	// returns the temperature of the selected "plate".
	// avaliable plates on BF systems: mc (mixing chamber), still, magnet, 4K, 50K
	// avaliable plates on IGH systems: mc (mixing chamber), cold plate, still, 1K, sorb
	// data is queried directly from the SQL database
	string instrID
	string plate

end

function getLS370heaterpowerDB(instrID,heater) // Units: mW
	// returns the power of the selected heater.
	// avaliable heaters on BF systems: still (analog 2), mc
	// avaliable heaters on IGH systems: sorb (analog 1), still (analog 2), mc
	// data is queried directly from the SQL database
	string instrID
	string heater
end

function getLS370pressureDB(instrID,gauge) // Units: mbar
	// returns the pressure from the selected pressure gauge
	// avaliable gauges on BF systems: P1,P2,P3,P4,P5,P6
	// avaliable gauges on IGH systems: P1,P2,G1,G2,G3
	// data is queried directly from the SQL database
	string instrID
	string gauge
end

///////////////////////
//// Set Functions ////
//////////////////////

function setLS370tempcontrolmode(instrID,mode) // Units: No units
	// sets the temperature control mode
	// avaliable options are: off (4), PID (1) and Open loop (3)
	string instrID
	variable mode
	nvar pid_mode, pid_led, mcheater_led, mcheater_set, temp_set
	svar system, bfchannellookup, ighchannellookup
	variable channel, interval, maxcurrent

	strswitch(system)
		case "bfsmall":
			channel = whichlistitem("mc",bfchannellookup,";")
			channel = str2num(stringfromlist(channel+5,bfchannellookup,";"))
			break
		case "igh":
			channel = whichlistitem("mc",ighchannellookup,";")
			channel = str2num(stringfromlist(channel+5,ighchannellookup,";"))
			break
		case "bfbig":
			break
	endswitch

	if(mode == 1)
		pid_led = 1
		mcheater_led = 1
		PopupMenu mcheater, mode=1
		SetVariable mcheaterset, disable=2
		PopupMenu tempcontrol, mode=1
		interval = 10
		maxcurrent = estimateheaterrangeLS370(instrID,temp_set)
		setLS370PIDcontrol(instrID,channel,temp_set,maxcurrent)
		setLS370exclusivereader(instrID,channel,interval)
	elseif(mode == 3)
		pid_led = 0
		mcheater_led = 1
		PopupMenu mcheater, mode=1
		SetVariable mcheaterset, disable=0
		resetLS370exclusivereader(instrID)
		sc_sleep(0.5)
		setLS370cmode(instrID,mode)
	elseif(mode == 4)
		pid_led = 0
		mcheater_led = 0
		PopupMenu mcheater, mode=2, disable=0
		SetVariable mcheaterset, disable=0
		resetLS370exclusivereader(instrID)
		sc_sleep(0.5)
		setLS370cmode(instrID,mode)
		sc_sleep(0.5)
		turnoffLS370MCheater(instrID)
	else
		abort "Choose between: PID (1), Open loop (3) and off (4)"
	endif
	pid_mode = mode
end

function setLS370PIDcontrol(instrID,channel,setpoint,maxcurrent) //Units: mK, mA
	string instrID,channel, setpoint, maxcurrent
	string payload, command, headers, token = "vMqyDIcB"
	nvar temp_set

	sprintf payload, "{ \"channel\": %d, \"set_point\": %g, \"max_current_ma\": %g, \"max_heater_level\": %s}", channel, setpoint/1000, maxcurrent, "8"
	headers = "Content-Type: application/json"
	sprintf command, "set-temperature-control-parameters?_at_=%s", token
	checkLS370URL(instrID)
	postHTTP(instrID,command,payload,headers)
	temp_set = setpoint
end

function setLS370cmode(instrID,mode)
	//PID: 1, open loop: 3, off: 4
	string instrID
	variable mode
	string payload, command, headers, token = "vMqyDIcB"

	sprintf payload, "{\"command\": \"CMODE %d\"}", mode
	headers = "Content-Type: application/json"
	sprintf command, "command?_at_=%s", token
	checkLS370URL(instrID)
	postHTTP(instrID,command,payload,headers)
end

function setLS370exclusivereader(instrID,channel,interval) // interval units: ms
	string instrID
	variable channel,interval
	string command, payload, headers, token = "vMqyDIcB"

	sprintf command, "set-exclusive-reader?_at_=%s", token
	sprintf payload, "{\"channel_label\": \"ch.%s\", \"interval_ms\": \"%s\"}", num2str(channel), num2str(interval)
	headers = "Content-Type: application/json"

	checkLS370URL(instrID)
	postHTTP(instrID,command,payload,headers)
end

function resetLS370exclusivereader(instrID)
	string instrID
	string command, payload, headers, token = "vMqyDIcB"

	sprintf command, "reset-exclusive-reader?_at_=%s", token
	payload = "{}"
	headers = "Content-Type: application/json"

	checkLS370URL(instrID)
	postHTTP(instrID,command,payload,headers)
end


function setLS370PIDtemp(instrID,temp) // Units: mK
	// sets the temperature for PID control and heater range
	string instrID
	variable temp
	string command,payload,headers,token = "vMqyDIcB"
	variable interval=10 //ms
	nvar temp_set
	svar bfchannellookup, ighchannellookup

	sprintf payload, "{\"command\": \"SETP %g\"}", temp/1000
	headers = "Content-Type: application/json"
	sprintf command, "command?_at_=%s", token
	checkLS370URL(instrID)
	postHTTP(instrID,command,payload,headers)
	temp_set = temp
end

function setLS370heaterrange(instrID,range) // Units: AU
	// range must be a number between 0 and 8
	string instrID,range
	string command,payload,headers,token = "vMqyDIcB"

	sprintf payload, "{\"command\": \"HTRRNG %d\"}", range
	sprintf command, "command?_at_=%s", token
	headers = "Content-Type: application/json"
	checkLS370URL(instrID)
	postHTTP(instrID,command,payload,headers)
end

function setLS370PIDparameters(instrID,p,i,d) // Units: No units
	// set the PID parameters for the PID control loop
	// P = {0.001 1000}, I = {0 10000}, D = {0 2500}
	string instrID
	variable p,i,d
	nvar p_value,i_value,d_value
	string command,payload,headers,cmd, token = "vMqyDIcB"

	if(0.001 <= p && p <= 1000 && 0 <= i && i <= 10000 && 0 <= d && d <= 2500)
		sprintf cmd,"PID %s,%s,%s", num2str(p), num2str(i), num2str(d)
		headers = "Content-Type: application/json"
		sprintf payload, "{\"command\": \"%s\"}", cmd
		sprintf command, "command?_at_=%s", token
		checkLS370URL(instrID)
		postHTTP(instrID,command,payload,headers)
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
	svar system, bfheaterlookup,ighheaterlookup
	nvar mcheater_set, stillheater_set, sorbheater_set
	variable channel, heater_idx
	string command, payload, headers, token = "vMqyDIcB"

	strswitch(system)
		case "bfsmall":
			heater_idx = whichlistitem(heater,bfheaterlookup,";")
			if(heater_idx < 0)
				printf "The requested heater (%s) doesn't exsist!", heater
				return -1.0
			else
				channel = str2num(stringfromlist(heater_idx+2,bfheaterlookup,";"))
			endif
			break
		case "igh":
			heater_idx = whichlistitem(heater,ighheaterlookup,";")
			if(heater_idx < 0)
				printf "The requested heater (%s) doesn't exsist!", heater
				return -1.0
			else
				channel = str2num(stringfromlist(heater_idx+3,ighheaterlookup,";"))
			endif
			break
		case "bfbig":
			break
	endswitch

	headers = "Content-Type: application/json"
	if(channel > 0)
		sprintf payload, "{\"analog_channel\":%d, \"power_mw\":%d}", channel, output
		sprintf command, "set-analog-output-power?_at_=%s", token
		if(channel > 1)
			stillheater_set = output
		else
			sorbheater_set = output
		endif
	else
		sprintf payload, "{\"power_mw\":%d}", output
		sprintf command, "set-heater-power?_at_=%s", token
		mcheater_set = output
	endif
	checkLS370URL(instrID)
	postHTTP(instrID,command,payload,headers)
end

function turnoffLS370MCheater(instrID)
	// turns off MC heater.
	// this function can seem unnecessary, but is in some cases need
	// and therefore it is a good practise to always use it.
	string instrID
	string command, payload, headers, token = "vMqyDIcB"
	nvar pid_led, mcheater_led, pid_mode

	sprintf command, "turn-heater-off?_at_=%s", token
	headers = "Content-Type: application/json"
	payload = "{}"
	checkLS370URL(instrID)
	postHTTP(instrID,command,payload,headers)
	pid_led = 0
	mcheater_led = 0
	pid_mode = 4
	PopupMenu mcheater, mode=2, disable=0, win=Lakeshore
	SetVariable mcheaterset, disable=0, win=Lakeshore
	PopupMenu tempcontrol, mode=2, win=Lakeshore
end

function toggleLS370magnetheater(instrID,onoff)
	// toggles the state of the magnet heater on BF #1.
	// it sets ANALOG 1 to -50% (-5V) in the "on" state
	// and 0% (0V) in the off state.
	// ANALOG 1 controls a voltage controlled switch!
	string instrID
	string onoff
	variable output
	nvar magnetheater_led
	svar system
	string command,payload,headers,cmd,token = "vMqyDIcB"

	if(cmpstr(system,"igh") == 0)
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

	headers = "Content-Type: application/json"
	sprintf cmd, "ANALOG 1,1,2,1,1,100.0,0.0,%g", output
	sprintf payload, "{\"command\":%s}", cmd
	sprintf command, "command?_at_=%s", token
	checkLS370URL(instrID)
	postHTTP(instrID,command,payload,headers)
end

////////////////////
//// Utillities ////
///////////////////

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

function updateLS370GUI(instrID)
	// updates all control variables for the main control window
	string instrID

	getLS370controlmode(instrID)
	sc_sleep(0.5)
	getLS370PIDtemp(instrID)
	sc_sleep(0.5)
	getLS370PIDparameters(instrID)
	sc_sleep(0.5)
	getLS370heaterpower(instrID,"mc")
	sc_sleep(0.5)
	getLS370heaterpower(instrID,"still")
	//GetHeaterPowerDB(instrID,"mc")
	//GetHeaterPowerDB(instrID,"still")
end

// FIX pressure readings

function/s getLS370status(instrID)
	// returns loggable parameters to meta-data file
	string instrID
	svar system, ighgaugelookup
	string  buffer="", gauge=""
	variable i=0

	strswitch(system)
		case "bfsmall":
			buffer = addJSONkeyvalpair(buffer,"MC K",num2str(getLS370temp(instrID,"mc")))
			buffer = addJSONkeyvalpair(buffer,"Still K",num2str(getLS370temp(instrID,"still")))
			buffer = addJSONkeyvalpair(buffer,"4K Plate K",num2str(getLS370temp(instrID,"4K")))
			buffer = addJSONkeyvalpair(buffer,"Magnet K",num2str(getLS370temp(instrID,"magnet")))
			buffer = addJSONkeyvalpair(buffer,"50K Plate K",num2str(getLS370temp(instrID,"50K")))
//			for(i=1;i<7;i+=1)
//				gauge = "P"+num2istr(i)
//				buffer = addJSONkeyvalpair(buffer,gauge,num2str(GetPressureDB(instrID,gauge)))
//			endfor
			return addJSONkeyvalpair("","BF Small",buffer)
		case "igh":
			buffer = addJSONkeyvalpair(buffer,"MC K",num2str(getLS370temp(instrID,"mc")))
			buffer = addJSONkeyvalpair(buffer,"Cold Plate K",num2str(getLS370temp(instrID,"cold plate")))
			buffer = addJSONkeyvalpair(buffer,"Still K",num2str(getLS370temp(instrID,"still")))
			buffer = addJSONkeyvalpair(buffer,"1K Pot K",num2str(getLS370temp(instrID,"1Kt")))
			buffer = addJSONkeyvalpair(buffer,"Sorb K",num2str(getLS370temp(instrID,"sorb")))
//			for(i=1;i<6;i+=1)
//				gauge = stringfromlist(i,ighgaugelookup)
//				buffer = addJSONkeyvalpair(buffer,"P"+num2istr(i),num2str(GetPressureDB(instrID,gauge)))
//			endfor
			return addJSONkeyvalpair("","IGH",buffer)
	endswitch
end

function setLS370system()
	// opens a control window and ask user to pick the correct system.
	// this is important, because it sets the correct url for the selected RPi.
	// if the wrong url is selected, you risk fucking up others experiment!!!
	string/g system

	execute("AskUserSystem()")
	PauseForUser AskUserSystem
end

function createLS370globals()
	// Create the needed global variables for driver

	// Create lookup tables
	string/g bfchannellookup = "mc;still;magnet;4K;50K;6;5;4;2;1"
	string/g ighchannellookup = "mc;cold plate;still;1K;sorb;3;6;5;2;1"
	string/g bfheaterlookup = "mc;still;0;2"
	string/g ighheaterlookup = "mc;still;sorb;0;2;1"
	string/g ighgaugelookup = "P1;P2;G1;G2;G3"
	make/o mcheatertemp_lookup = {{31.6e-3,100e-3,316e-3,1.0,3.16,10,31.6,100},{0,10,30,95,350,1201,1800,10000}} // mA,mK

	// Create variables for control window
	variable/g pid_led = 0
	variable/g mcheater_led = 0
	variable/g stillheater_led = 0
	variable/g magnetheater_led = 0
	variable/g sorbheater_led = 0
	variable/g temp_set = 0
	variable/g mcheater_set = 0
	variable/g stillheater_set = 0
	variable/g sorbheater_set = 0
	variable/g p_value = 10
	variable/g i_value = 5
	variable/g d_value = 0
	variable/g pid_mode = 4
end

function/s checkLS370URL(instrID)
	// Generate the command URL
	string instrID
	svar system

	strswitch(system)
		case "bfsmall":
			if(cmpstr(instrID,getLS370URL(system))==0)
				// pass
			else
				printf "[ERROR]: The URL passed (%s) does not match the BF small URL!\r", instrID
				abort
			endif
			break
		case "igh":
			if(cmpstr(instrID,getLS370URL(system))==0)
				// pass
			else
				printf "[ERROR]: The URL passed (%s) does not match the IGH URL!\r", instrID
				abort
			endif
			break
		case "bfbig":
			break
		endswitch
end

function/s GenerateDBURL(instrID,data_type,data_label)
	string instrID
	string data_type,data_label
	svar system
	string query_url

	return query_url
end

///////////////////////
//// Communication ////
//////////////////////

function/s queryLS370(instrID,cmd,headers,responseformat,method,[payload])
	// function takes six strings: instrID,cmd,headers,responseformat,method and payload
	// paylod is a json string containing "key:value" pairs
	// headers is always "Content-Type: application/json" and responseformat is the "key" of the returned data.
	// the returned value is a string.
	string instrID
	string cmd,headers,responseformat,method,payload
	string response, keys

	if(cmpstr(method,"get")==0)
		response = getHTTP(instrID,cmd,headers)
	elseif(cmpstr(method,"post")==0 && !paramisdefault(payload))
		response = postHTTP(instrID,cmd,payload,headers)
	else
		abort "Not a supported method or you forgot to add a payload."
	endif

	keys = getJSONkeys(response) // if heater output is 0, we only get time back!
	if(findlistitem(responseformat,keys,",",0) == -1)
		return "0"
	else
		return getJSONvalue(response, responseformat)
	endif
end

// function/s queryLS370DB(instrID,query_url)
// 	string instrID
// 	string query_url
// 	string headers,url,response
//
// 	headers = "Content-Type: application/x-www-form-urlencoded"
// 	sprintf url, "http://qdot-server.phas.ubc.ca:8086/query? --data_urlencode \"db=test\" --data_urlencode \"%s\"", query_url
//
//
// 	URLRequest /TIME=5.0 url=url, method=get, headers=headers
//
// 	if (V_flag == 0)    // No error
// 		if (V_responseCode != 200)  // 200 is the HTTP OK code
// 		    print "Reading failed!"
// 		    return num2str(-1.0)
// 		else
// 		    response = S_serverResponse
// 		    print response
// 		endif
//    else
//         print "HTTP connection error."
//         return num2str(-1.0)
//    endif
// end

/////////////////////////
//// Control Windows ////
////////////////////////

//// Main control window ////

window lakeshore_window() : Panel
	PauseUpdate; Silent 1 // building window
	if(cmpstr(system,"bfsmall") == 0 || cmpstr(system,"bfbig") == 0)
		NewPanel /W=(0,0,380,325) /N=Lakeshore
	else
		NewPanel /W=(0,0,380,350) /N=Lakeshore
	endif
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 80, 45,"Lakeshore (LS370)" // headline

	// PID settings
	PopupMenu tempcontrol, pos={20,50},size={250,50},mode=2,title="\\Z16Temperature Control:",value=("On;Off"), proc=tempcontrol_control
	ValDisplay pidled, pos={310,50}, size={53,25}, mode=2,value=pid_led, zerocolor=(65535,0,0), limits={0,1,-1}, highcolor=(65535,0,0),lowcolor=(0,65535,0),barmisc={0,0},title="\\Z14PID"
	SetVariable tempset, pos={20,80},size={300,50},value=temp_set,title="\\Z16Temperature Setpoint (mK):",limits={0,300000,0},proc=tempset_control
	SetVariable P, pos={20,110},size={70,50},value=p_value,title="\\Z16P:",limits={0.001,1000,0}
	SetVariable I, pos={100,110},size={67,50},value=i_value,title="\\Z16I:",limits={0,10000,0}
	SetVariable D, pos={177,110},size={70,50},value=d_value,title="\\Z16D:",limits={0,2500,0}
	Button PIDUpdate, pos={257,110},size={100,20},title="\\Z14Update PID",proc=pid_control
	DrawLine 10,140,370,140

	// MC heater settings
	PopupMenu mcheater, pos={20,150},size={250,50},mode=2,title="\\Z16MC Heater:",value=("On;Off"), proc=mcheater_control
	ValDisplay mcheaterled, pos={300,150}, size={65,20}, mode=2,value=mcheater_led, zerocolor=(65535,0,0), limits={0,1,-1}, highcolor=(65535,0,0),lowcolor=(0,65535,0),barmisc={0,0},title="\\Z10MC\rHeater"
	SetVariable mcheaterset, pos={20,180},size={250,50},value=mcheater_set,title="\\Z16Heater Setpoint (mW):",limits={0,1000,0},proc=mcheaterset_control
	DrawLine 10,210,370,210
	// Still heater settings
	PopupMenu stillheater, pos={20,220},size={250,50},mode=2,title="\\Z16Still Heater:",value=("On;Off"), proc=stillheater_control
	ValDisplay stillheaterled, pos={300,220}, size={65,20}, mode=2,value=stillheater_led, zerocolor=(65535,0,0), limits={0,1,-1}, highcolor=(65535,0,0),lowcolor=(0,65535,0),barmisc={0,0},title="\\Z10Still\rHeater"
	SetVariable stillheaterset, pos={20,250},size={250,50},value=stillheater_set,title="\\Z16Heater Setpoint (mW):",limits={0,1000,0},proc=stillheaterset_control
	DrawLine 10,280,370,280
	if(cmpstr(system,"bfsmall") == 0 || cmpstr(system,"bfbig") == 0)
			// Magnet heater settings
			PopupMenu magnetheater, pos={20,290},size={250,50},mode=2,title="\\Z16Magnet Heater:",value=("On;Off"), proc=magnetheater_control
			ValDisplay magnetheaterled, pos={297,290}, size={68,20}, mode=2,value=magnetheater_led, zerocolor=(65535,0,0), limits={0,1,-1}, highcolor=(65535,0,0),lowcolor=(0,65535,0),barmisc={0,0},title="\\Z10Magnet\rHeater"
	else
		if(cmpstr(system,"igh") == 0)
			// Sorb heater settings
			PopupMenu sorbheater, pos={20,290},size={250,50},mode=2,title="\\Z16Sorb Heater:",value=("On;Off"), proc=sorbheater_control
			ValDisplay sorbheaterled, pos={300,290}, size={65,20}, mode=2,value=sorbheater_led, zerocolor=(65535,0,0), limits={0,1,-1}, highcolor=(65535,0,0),lowcolor=(0,65535,0),barmisc={0,0},title="\\Z10Sorb\rHeater"
			SetVariable sorbheaterset, pos={20,320},size={250,50},value=sorbheater_set,title="\\Z16Heater Setpoint (mW):",limits={0,1000,0},proc=sorbheaterset_control
		else
			abort "System not selected!"
		endif
	endif
endmacro

function tempcontrol_control(action,popnum,popstr) : PopupMenuControl
	string action
	variable popnum
	string popstr
	variable mode
	nvar pid_led, mcheater_led, pid_mode

	string instrID = getLS370URL()

	strswitch(popstr)
		case "On":
			pid_led = 1
			mcheater_led = 1
			PopupMenu mcheater, mode=1, disable=2
			SetVariable mcheaterset, disable=2
			mode = 1
			break
		case "Off":
			pid_led = 0
			mcheater_led = 0
			PopupMenu mcheater, mode=2, disable=0
			SetVariable mcheaterset, disable=0
			mode = 4
			break
	endswitch
	setLS370tempcontrolmode(instrID,mode)
	pid_mode = mode
end

function tempset_control(action,varnum,varstr,varname) : SetVariableControl
	string action
	variable varnum
	string varstr, varname

	string instrID = getLS370URL()

	setLS370PIDtemp(instrID,varnum) // mK
end

function pid_control(action) : ButtonControl
	string action
	nvar p_value,i_value,d_value

	string instrID = getLS370URL()

	setLS370PIDparameters(instrID,p_value,i_value,d_value)
end

function mcheater_control(action,popnum,popstr) : PopupMenuControl
	string action
	variable popnum
	string popstr
	nvar mcheater_led, mcheater_set

	string instrID = getLS370URL()

	strswitch(popstr)
		case "On":
			mcheater_led = 1
			setLS370tempcontrolmode(instrID,3) // set to "open loop"
			sc_sleep(0.5)
			setLS370heaterpower(instrID,"mc",mcheater_set) //mW
			break
		case "Off":
			mcheater_led = 0
			turnoffLS370MCheater(instrID)
			break
	endswitch
end

function mcheaterset_control(action,varnum,varstr,varname) : SetVariableControl
	string action
	variable varnum
	string varstr, varname
	nvar mcheater_led, pid_mode

	string instrID = getLS370URL()

	setLS370heaterpower(instrID,"mc",varnum)
	if(varnum > 0)
		mcheater_led = 1
		pid_mode = 3
		PopupMenu mcheater, mode=1
	else
		mcheater_led = 0
		pid_mode = 4
		PopupMenu mcheater, mode=0
	endif
end

function stillheater_control(action,popnum,popstr) : PopupMenuControl
	string action
	variable popnum
	string popstr
	nvar stillheater_led, stillheater_set

	string instrID = getLS370URL()

	strswitch(popstr)
		case "On":
			stillheater_led = 1
			setLS370heaterpower(instrID,"still",stillheater_set) //mW
			break
		case "Off":
			stillheater_led = 0
			setLS370heaterpower(instrID,"still",0) //mW
			break
	endswitch
end

function stillheaterset_control(action,varnum,varstr,varname) : SetVariableControl
	string action
	variable varnum
	string varstr, varname
	nvar stillheater_led

	string instrID = getLS370URL()

	setLS370heaterpower(instrID,"still",varnum) //mW
	if(varnum > 0)
		stillheater_led = 1
		PopupMenu stillheater, mode=1
	else
		stillheater_led = 0
		PopupMenu stillheater, mode=0
	endif
end

function magnetheater_control(action,popnum,popstr) : PopupMenuControl
	string action
	variable popnum
	string popstr
	nvar magnetheater_led

	string instrID = getLS370URL()

	strswitch(popstr)
		case "On":
			magnetheater_led = 1
			toggleLS370magnetheater(instrID,"on")
			break
		case "Off":
			magnetheater_led = 0
			toggleLS370magnetheater(instrID,"off")
			break
	endswitch
end

function sorbheater_control(action,popnum,popstr) : PopupMenuControl
	string action
	variable popnum
	string popstr
	nvar sorbheater_led, sorbheater_set

	string instrID = getLS370URL()

	strswitch(popstr)
		case "On":
			sorbheater_led = 1
			setLS370heaterpower(instrID,"sorb",sorbheater_set) //mW
			break
		case "Off":
			sorbheater_led = 0
			setLS370heaterpower(instrID,"sorb",0) //mW
			break
	endswitch
end

function sorbheaterset_control(action,varnum,varstr,varname) : SetVariableControl
	string action
	variable varnum
	string varstr, varname
	nvar sorbheater_led

	string instrID = getLS370URL()

	setLS370heaterpower(instrID,"sorb",varnum) //mW
	if(varnum > 0)
		sorbheater_led = 1
		PopupMenu sorbheater, mode=1
	else
		sorbheater_led = 0
		PopupMenu sorbheater, mode=0
	endif
end

function/s getLS370URL()
	svar system

	strswitch(system)
		case "bfsmall":
			return "http://bfsmall-wifi:7777/api/v1/"
			break
		case "igh":
			return "http://qdash.qdot.lab:7777/api/v1/"
			break
		case "bfbig":
			return ""
			break
	endswitch
end

//// System set control wondow ////

window AskUserSystem() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(100,100,400,200) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 40, 40,"Initialize Lakeshore" // Headline
	PopupMenu SelectSystem, pos={60,60},size={250,50},mode=4,title="\\Z16Select System:",value=("Blue Fors #1;IGH;Blue Fors #2"), proc=selectsystem_control
endmacro

function selectsystem_control(action,popnum,popstr) : PopupMenuControl
	string action
	variable popnum
	string popstr
	svar system

	strswitch(popstr)
		case "Blue Fors #1":
			system = "bfsmall"
			dowindow/k AskUserSystem
			break
		case "IGH":
			system = "igh"
			dowindow/k AskUserSystem
			break
		case "Blue Fors #2":
			system = "bfbig"
			print "No support for BF#2 yet!"
			dowindow/k AskUserSystem
			execute("AskUserSystem()")
			break
	endswitch
end
