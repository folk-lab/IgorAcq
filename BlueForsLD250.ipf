#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// get temperatures
// get these from Lakeshore driver instead
//
//function GetCurrentBFStatus(workingstr, loggable_name)
//	string workingstr, loggable_name
//	string keyname
//	variable numvals, i
//	numvals = ItemsInList(workingstr)
//	Make/O/T/N=(numvals) textWave= StringFromList(p,workingstr)
//	for (i=0; i<numvals; i+=1)
//		keyname = stringfromlist(0,textwave[i],"=")
//		if (stringmatch(keyname, loggable_name))
//			return str2num(stringfromlist(1,textwave[i],"="))
//		endif
//	endfor
//end
////
//function GetBFMixChTemp()
//
//	String url = "http://qdot-server.phas.ubc.ca:8081/webService/logger.php?action=getCurrentState"
//	url = url + "&loggable_category_id=4"
//	String response = FetchURL(url)
//	return GetCurrentBFStatus(response, "bfs_mc_temp")
//	
//end
////
//function GetBFMagnetTemp()
//
//	String url = "http://qdot-server.phas.ubc.ca:8081/webService/logger.php?action=getCurrentState"
//	url = url + "&loggable_category_id=4"
//	String response = FetchURL(url)
//	return GetCurrentBFStatus(response, "bfs_magnet_temp")
//	
//end
//
//function GetBF4KTemp()
//
//	String url = "http://qdot-server.phas.ubc.ca:8081/webService/logger.php?action=getCurrentState"
//	url = url + "&loggable_category_id=4"
//	String response = FetchURL(url)
//	return GetCurrentBFStatus(response, "bfs_4K_temp")
//	
//end

// Lakeshore commands below

function /s SendLSCommand(command)
	string command
	string response
	command = ReplaceString(" ", command, "%20")
	String url = "http://qdot-server.phas.ubc.ca:8081/webService/commandmanager.php?action=createCommand"
	url = url + "&port_id=3&cmd=" + command
	response = FetchURL(url)
	return response
end

// get Pressure values

function GetBFPressure(sensor)
	variable sensor
	string response = ""
	string url = "http://qdot-server.phas.ubc.ca:8081/webService/logger.php?action=getCurrentValue&loggable_name="
	url = url+ "bfs_p" + num2str(sensor)+"&yes_calc=false"
	response = FetchURL(url)
	return str2num(response)
end