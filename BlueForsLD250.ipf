#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// pressure readings straight from the server

function GetBFPressure(sensor)
	variable sensor
	string response = ""
	string url = "http://qdot-server.phas.ubc.ca:8081/webService/logger.php?action=getCurrentValue&loggable_name="
	url = url+ "bfs_p" + num2str(sensor)+"&yes_calc=false"
	response = FetchURL(url)
	return str2num(response)
end

// bluefors status for logging

function /S GetBFStatus()
	string winfcomments=""
	string  buffer=""

	sprintf  winfcomments "BF250:\r\t"
	sprintf buffer "MC = %.3f K\r\tStill = %.3f K\r\t4K = %.3f K\r\tMagnet = %.3f K\r\t50K = %.3f K\r\t", GetTemp("mc"), GetTemp("still"), GetTemp("4k"), GetTemp("magnet"), GetTemp("50k")
	winfcomments += buffer
	sprintf buffer "P1 = %.2e mbar\r\tP2 = %.3f mbar\r\tP3 = %.3f mbar\r\tP4 = %.3f mbar\r\tP5 = %.3f mbar\r\tP6 = %.3f mbar\r\t", GetBFPressure(1), GetBFPressure(2), GetBFPressure(3), GetBFPressure(4), GetBFPressure(5), GetBFPressure(6)
	winfcomments += buffer
	return winfcomments
end