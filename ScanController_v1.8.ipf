#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Scan Controller routines for 1d and 2d scans
// Version 1.7 August 8, 2016
// Version 1.8 XXXX X, 2017
// Authors: Mohammad Samani, Nik Hartman & Christian Olsen


// Updates in 1.8....
//     -- separate all save functions into ScanControllerNATIVE 
//     -- remove support for time averaging over any parameter. it is rarely useful and confusing to read. 
//     -- add option (which should be ON) to push 'new data' notifications to qdot-server 
//     -- fill 2D arrays point by point not line by line 
//     -- remove restriction on Request/Response scripts -- go back to using execute()
//     -- fix sc_sleep accuracy problem -- USE IT EVERYWHERE IN PLACE OF SLEEP
//     -- save command history as plain text in *.history
//     -- add Slack notifications (somefolkneverlearn.slack.com)

// FUTURE: 
//     -- start using JSON format for config files
//     -- Test a ScanControllerHDF5 package to put all sweep information in a single HDF5 file
//     -- add a new type of value to record that can/will be read during sc_sleep
//     -- Write a RecordValuesAsync function that can parallelize instrument calls by opening multiple threads


///////////////////////////////
////// utility functions //////
///////////////////////////////


function /S getJSONstr(jstr, key)
	// get value of key from json string	s
	// works for string values
	// matches anything in quotes like this.... 
	//
	// "key":"match_this"
	//
	// returns "match_this"

	string jstr, key
	string val=""
	string regex = ""
	sprintf regex, "\"(?i)%s\"\\s*:\\s*\"(.+?)\"", key
	splitstring /E=regex jstr, val
	return val
end

function /S getJSONarray(jstr, key)
	// get value of key from json string	
	// works for string values
	// matches anything in (), {}, or [] like this.... 
	//
	// "key": [1,2,3,4]
	//
	// returns "[1,2,3,4]"

	string jstr, key
	string group1
	string regex = ""
	sprintf regex, "\"(?i)%s\"\\s*:\\s*((\[|\(|{)(.+?)(\]|\)|}))", key

	splitstring /E=regex jstr, group1
	return group1
end

function getJSONbool(jstr, key)
	// get value of key from json string
	// works on boolean values
	// matches true|false
	//
	// "key":True
	//
	// returns 1
	
	string jstr, key
	string val=""
	string regex = ""
	sprintf regex, "\"(?i)%s\"\\s*:\\s*(?i)(true|false)", key
	splitstring /E=regex jstr, val

	strswitch(LowerStr(val))
		case "true":
			return 1
		case "false":
			return 0
	endswitch
	
end

function getJSONnum(jstr, key)
	// get value of key from json string
	// works on numeric values in quotes or not in quotes
	// 
	// "key":9.99 and "key":"9.99"
	//
	// both return 9.99
	
	string jstr, key
	string quote="", val=""
	string regex = ""
	sprintf regex, "\"(?i)%s\"\\s*:\\s*(\")?([-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?)(?(1)\\1|)", key
	
	splitstring /E=regex jstr, quote, val

	return str2num(val)
	
end

function unixtime()
	// returns the current unix time in seconds
	return DateTime - date2secs(1970,1,1) - date2secs(-1,-1,-1)
end

function AppendValue(thewave, thevalue)
	wave thewave
	variable thevalue
	Redimension /N=(numpnts(thewave)+1) thewave
	thewave[numpnts(thewave)-1] = thevalue
end

function AppendString(thewave, thestring)
	wave/t thewave
	string thestring
	Redimension /N=(numpnts(thewave)+1) thewave
	thewave[numpnts(thewave)-1] = thestring
end

function /S removeAllWhitespace(str)
	string str
	str = RemoveLeadingWhitespace(str)
	str = RemoveTrailingWhitespace(str)
	return str
end

Function/S RemoveLeadingWhitespace(str)
    String str
 
    if (strlen(str) == 0)
        return ""
    endif
 
    do
        String firstChar= str[0]
        if (IsWhiteSpace(firstChar))
            str= str[1,inf]
        else
            break
        endif   
    while (strlen(str) > 0)
 
    return str
End
 
Function/S RemoveTrailingWhitespace(str)
    String str
 
    if (strlen(str) == 0)
        return ""
    endif
 
    do
        String lastChar = str[strlen(str) - 1]
        if (IsWhiteSpace(lastChar))
            str = str[0, strlen(str) - 2]
        else
        	break
        endif
    while (strlen(str) > 0)
    return str
End
 
Function IsWhiteSpace(char)
    String char
 
    return GrepString(char, "\\s")
End

function list2textwave(stringlistwave,namewave)
	string stringlistwave, namewave
	variable n = ItemsInList(stringlistwave,",")
	make/o/t/n=(n) $namewave=StringFromList(p,stringlistwave, ",")
end

function list2numwave(stringlistwave,namewave)
	string stringlistwave, namewave
	variable n = ItemsInList(stringlistwave,",")
	make/o/t/n=(n) blawave=StringFromList(p,stringlistwave, ",")
	make/o/n=(n) $namewave= str2num(blawave)
end

function/S executeWinCmd(command)
	// http://www.igorexchange.com/node/938
	string command
	string IPUFpath = SpecialDirPath("Igor Pro User Files",0,1,0)	// guaranteed writeable path in IP7
	string batchFileName = "ExecuteWinCmd.bat", outputFileName = "ExecuteWinCmd.out"
	string outputLine, result = ""
	variable refNum
	 
	NewPath/O/Q IgorProUserFiles, IPUFpath
	Open/P=IgorProUserFiles refNum as batchFileName	// overwrites previous batchfile
	fprintf refNum,"cmd/c \"%s > \"%s%s\"\"\r", command, IPUFpath, outputFileName
	Close refNum
	ExecuteScriptText/B "\"" + IPUFpath + "\\" + batchFileName + "\""
	Open/P=IgorProUserFiles/R refNum as outputFileName
	
	do
		FReadLine refNum, outputLine
		if( strlen(outputLine) == 0 )
			break
		endif
		result += outputLine
	while( 1 )
	Close refNum
	return result
end

function/S executeMacCmd(command)
	// http://www.igorexchange.com/node/938
	string command

	string cmd
	sprintf cmd, "do shell script \"%s\"", command
	ExecuteScriptText cmd

	return S_value
end

function /S getHostName()
	// find the name of the computer Igor is running on
	string platform = igorinfo(2)
	string result, hostname, location
	
	strswitch(platform)
		case "Macintosh":
			result = executeMacCmd("hostname")
			splitstring /E="([a-zA-Z0-9\-]+).(.+)" result, hostname, location
			return removeallwhitespace(LowerStr(hostname))
		case "Windows":
			hostname = executeWinCmd("hostname")
			return removeallwhitespace(LowerStr(hostname))
		default:
			abort "What operating system are you running?! How?!"
	endswitch
	
end

function /S getExpPath(whichpath, [full])
	// whichpath determines which path will be returned (data, winfs, config)
	// root always gives the path to local_measurement_data
	// if full==1, the full path on the local machine is returned in native style
	// if full==0, the path relative to local_measurement_data is returned in Unix style
	string whichpath
	variable full
	
	if(paramisdefault(full))
		full=0
	endif
	
	pathinfo data // get path info
	
	if(V_flag == 0) // check if path is defined
		abort "data path is not defined!\n"
	endif
	
	// get relative path to data
	string temp1, temp2, temp3
	SplitString/E="([\w\s\-\:]+)(?i)(local[\s\_]measurement[\s\_]data)([\w\s\-\:]+)" S_path, temp1, temp2, temp3
		
	strswitch(whichpath)
		case "root":
			// returns path to local_measurement_data on local machine
			return ParseFilePath(5, temp1+temp2, "*", 0, 0)
		case "data":
			// returns path to data relative to local_measurement_data
			if(full==0)
				return "/"+ReplaceString(":", temp3[1,inf], "/")
			else
				return ParseFilePath(5, temp1+temp2+temp3, "*", 0, 0)
			endif
		case "winfs":
			if(full==0)
				return "/"+ReplaceString(":", temp3[1,inf], "/")+"winfs/"
			else
				return ParseFilePath(5, temp1+temp2+temp3+"winfs:", "*", 0, 0)
			endif
		case "config":
			if(full==0)
				return "/"+ReplaceString(":", temp3[1,inf], "/")+"config/"
			else
				return ParseFilePath(5, temp1+temp2+temp3+"config:", "*", 0, 0)
			endif
	endswitch
end

///////////////////////////////
//// start scan controller ////
///////////////////////////////

function InitScanController([srv_push])
	// srv_push = 1 to alert qdot-server of new data
	variable srv_push
	variable /g sc_srv_push
	if(paramisdefault(srv_push) || srv_push==1)
		sc_srv_push = 1
	else
		sc_srv_push = 0
	endif
	
	string filelist = ""
	string /g slack_url =  "https://hooks.slack.com/services/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" // url for slack alert

	string server = "10.5.254.1" // address for qdot-server
	variable port = 7965 // port number the server is listening on
	string /g server_url = ""
	sprintf server_url, "http://%s:%d", server, port
	
	string /g sc_hostname = getHostName() // machine name

	// Check if data path is definded
	GetFileFolderInfo/Z/Q/P=data
	if(v_flag != 0 || v_isfolder != 1)
		abort "Data path not defined!\n"
	endif
	
	newpath /C/O/Q winfs getExpPath("winfs", full=1) // create/overwrite winf path
	newpath /C/O/Q config getExpPath("config", full=1) // create/overwrite config path
	
	// look for config files
	filelist = greplist(indexedfile(config,-1,".config"),"sc")
	
	if(itemsinlist(filelist)>0)
		// read content into waves
		filelist = SortList(filelist, ";", 1+16)
		sc_loadconfig(StringFromList(0,filelist, ";"))
	else
		// These arrays should have the same size. Their indeces correspond to each other.
		make/t/o sc_RawWaveNames = {"g1x", "g1y"} // Wave names to be created and saved
		make/o sc_RawRecord = {0,0} // Whether you want to record and save the data for this wave
		make/o sc_RawPlot = {0,0} // Whether you want to record and save the data for this wave
		make/t/o sc_RequestScripts = {"", ""}
		make/t/o sc_GetResponseScripts = {"getg1x()", "getg1y()"}
		// End of same-size waves
		
		// And these waves should be the same size too
		make/t/o sc_CalcWaveNames = {"", ""} // Calculated wave names
		make/t/o sc_CalcScripts = {"",""} // Scripts to calculate stuff
		make/o sc_CalcRecord = {0,0} // Include this calculated field or not
		make/o sc_CalcPlot = {0,0} // Include this calculated field or not
		// end of same-size waves
		
		// default colormap
		string /g sc_ColorMap = "Grays"
		
		// Print variables
		variable/g sc_PrintRaw = 1,sc_PrintCalc = 1
		
		// logging string
		string /g sc_LogStr = "GetSRSStatus(srs1);"
			
		nvar filenum
		if (numtype(filenum) == 2)
			print "Initializing FileNum to 0 since it didn't exist before.\n"
			variable /g filenum=0
		else
			printf "Current FileNum is %d\n", filenum
		endif
	endif
	
	sc_rebuildwindow()
end

/////////////////////////////
//// configuration files ////
/////////////////////////////

function sc_createconfig()
	wave/t sc_RawWaveNames
	wave sc_RawRecord
	wave sc_RawPlot
	wave/t sc_RequestScripts
	wave/t sc_GetResponseScripts
	wave/t sc_CalcWaveNames
	wave/t sc_CalcScripts
	wave sc_CalcRecord
	wave sc_CalcPlot
	nvar sc_PrintRaw
	nvar sc_PrintCalc
	svar sc_LogStr
	svar sc_ColorMap
	nvar filenum
	variable refnum
	string configfile
	
	configfile = "sc" + num2istr(unixtime()) + ".config"
	
	// Try to open config file or create it otherwise
	open /z/p=config refnum as configfile
	
	wfprintf refnum, "%s,", sc_RawWaveNames
	fprintf refnum, "\r"
	wfprintf refnum, "%g,", sc_RawRecord
	fprintf refnum, "\r"
	wfprintf refnum, "%g,", sc_RawPlot
	fprintf refnum, "\r"
	wfprintf refnum, "%s,", sc_RequestScripts
	fprintf refnum, "\r"
	wfprintf refnum, "%s,", sc_GetResponseScripts
	fprintf refnum, "\r"
	wfprintf refnum, "%s,", sc_CalcWaveNames
	fprintf refnum, "\r"
	wfprintf refnum, "%s,", sc_CalcScripts
	fprintf refnum, "\r"
	wfprintf refnum, "%g,", sc_CalcRecord
	fprintf refnum, "\r"
	wfprintf refnum, "%g,", sc_CalcPlot
	fprintf refnum, "\r"
	fprintf refnum, "%g\r", sc_PrintRaw
	fprintf refnum, "%g\r", sc_PrintCalc
	fprintf refnum, "%s\r", sc_LogStr
	fprintf refnum, "%s\r", sc_ColorMap
	fprintf refnum, "%g\r", filenum
	
	close refnum
	
end

function sc_loadconfig(configfile)
	string configfile
	variable refnum
	string loadcontainer
	nvar sc_PrintRaw
	nvar sc_PrintCalc
	svar sc_LogStr
	svar sc_ColorMap
	nvar filenum
	variable i, confignum=0
	string file_string, configunix
	
	open /z/r/p=config refnum as configfile
	printf "Loading configuration from: %s\n", configfile
	
	// load raw wave configuration
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2textwave(removeending(loadcontainer,"\r"),"sc_RawWaveNames")
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2numwave(removeending(loadcontainer,"\r"),"sc_RawRecord")
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2numwave(removeending(loadcontainer,"\r"),"sc_RawPlot")
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2textwave(removeending(loadcontainer,"\r"),"sc_RequestScripts")
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2textwave(removeending(loadcontainer,"\r"),"sc_GetResponseScripts")
	
	// load calc wave configuration
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2textwave(removeending(loadcontainer,"\r"),"sc_CalcWaveNames")
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2textwave(removeending(loadcontainer,"\r"),"sc_CalcScripts")
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2numwave(removeending(loadcontainer,"\r"),"sc_CalcRecord")
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2numwave(removeending(loadcontainer,"\r"),"sc_CalcPlot")
	
	// load print checkbox settings
	freadline/t=(num2char(13)) refnum, loadcontainer
	sc_PrintRaw = str2num(removeending(loadcontainer,"\r"))
	freadline/t=(num2char(13)) refnum, loadcontainer
	sc_PrintCalc = str2num(removeending(loadcontainer,"\r"))
	
	// load log string
	freadline/t=(num2char(13)) refnum, loadcontainer
	sc_LogStr = removeending(loadcontainer,"\r")
	
	// load colormap
	freadline/t=(num2char(13)) refnum, loadcontainer
	sc_ColorMap = removeending(loadcontainer,"\r")
	
	close refnum
end


/////////////////////
//// main window ////
/////////////////////


function sc_rebuildwindow()
	dowindow /k ScanController
	execute("ScanController()")
end

// In order to enable or disable a wave
// call these two functions instead of messing with the waves sc_RawRecord and sc_CalcRecord directly
function EnableScanControllerItem(wn)
	string wn
	ChangeScanControllerItemStatus(wn, 1)
end

function DisableScanControllerItem(wn)
	string wn
	ChangeScanControllerItemStatus(wn, 0)
end

function ChangeScanControllerItemStatus(wn, ison)
	string wn
	variable ison
	string cmd
	wave sc_RawRecord, sc_CalcRecord
	wave /t sc_RawWaveNames, sc_CalcWaveNames
	variable i=0, done=0
	do
		if (stringmatch(sc_RawWaveNames[i], wn))
			sc_RawRecord[i]=ison
			cmd = "CheckBox sc_RawRecordCheckBox" + num2istr(i) + " value=" + num2istr(ison)
			execute(cmd)
			done=1
		endif
		i+=1
	while (i<numpnts( sc_RawWaveNames ) && !done)

	i=0
	do
		if (stringmatch(sc_CalcWaveNames[i], wn))
			sc_CalcRecord[i]=ison
			cmd = "CheckBox sc_CalcRecordCheckBox" + num2istr(i) + " value=" + num2istr(ison)
			execute(cmd)	
		endif
		i+=1
	while (i<numpnts( sc_CalcWaveNames ) && !done)

	if (!done) 
		print "Error: Could not find the wave name specified."
	endif
	execute("doupdate")
end

Window ScanController() : Panel
	variable sc_InnerBoxW = 660, sc_InnerBoxH = 32, sc_InnerBoxSpacing = 2

	if (numpnts(sc_RawWaveNames) != numpnts(sc_RawRecord) ||  numpnts(sc_RawWaveNames) != numpnts(sc_RequestScripts) ||  numpnts(sc_RawWaveNames) != numpnts(sc_GetResponseScripts)) 
		print "sc_RawWaveNames, sc_RawRecord, sc_RequestScripts, and sc_GetResponseScripts waves should have the number of elements.\nGo to the beginning of InitScanController() to fix this.\n"
		abort
	endif

	if (numpnts(sc_CalcWaveNames) != numpnts(sc_CalcRecord) ||  numpnts(sc_CalcWaveNames) != numpnts(sc_CalcScripts)) 
		print "sc_CalcWaveNames, sc_CalcRecord, and sc_CalcScripts waves should have the number of elements.\n  Go to the beginning of InitScanController() to fix this.\n"
		abort
	endif

	PauseUpdate; Silent 1		// building window...
	dowindow /K ScanController
	NewPanel /W=(10,10,sc_InnerBoxW + 30,200+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+1)*(sc_InnerBoxH+sc_InnerBoxSpacing) ) /N=ScanController
	ModifyPanel frameStyle=2
	ModifyPanel fixedSize=1
	SetDrawLayer UserBack

	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 13,29,"Wave Name"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 130,29,"Record"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 200,29,"Plot"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 250,29,"Request Script (Optional)"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 460,29,"Get Response Script"

	string cmd = ""
	variable i=0
	do
		DrawRect 9,30+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing),5+sc_InnerBoxW,30+sc_InnerBoxH+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)
		//DrawText 13,54+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing), sc_RawWaveNames[i]
		cmd="SetVariable sc_RawWaveNameBox" + num2istr(i) + " pos={13, 37+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={110, 0}, fsize=14, title=\" \", value=sc_RawWaveNames[i]"
		execute(cmd)
		cmd="CheckBox sc_RawRecordCheckBox" + num2istr(i) + ", proc=sc_CheckBoxClicked, pos={150,40+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_RawRecord[i]) + " , title=\"\""
		execute(cmd)
		cmd="CheckBox sc_RawPlotCheckBox" + num2istr(i) + ", proc=sc_CheckBoxClicked, pos={210,40+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_RawPlot[i]) + " , title=\"\""
		execute(cmd)
		cmd="SetVariable sc_RequestScriptBox" + num2istr(i) + " pos={250, 37+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={200, 0}, fsize=14, title=\" \", value=sc_RequestScripts[i]"
		execute(cmd)
		cmd="SetVariable sc_GetResponseScriptBox" + num2istr(i) + " pos={460, 37+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={200, 0}, fsize=14, title=\" \", value=sc_GetResponseScripts[i]"
		execute(cmd)		
		i+=1
	while (i<numpnts( sc_RawWaveNames ))
	i+=1
	button addrowraw,pos={550,i*(sc_InnerBoxH + sc_InnerBoxSpacing)},size={110,20},proc=sc_addrow,title="Add Row"
	button removerowraw,pos={430,i*(sc_InnerBoxH + sc_InnerBoxSpacing)},size={110,20},proc=sc_removerow,title="Remove Row"
	checkbox sc_PrintRawBox, pos={300,i*(sc_InnerBoxH + sc_InnerBoxSpacing)}, proc=sc_CheckBoxClicked, value=sc_PrintRaw,side=1,title="\Z14Print filenames"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 13,i*(sc_InnerBoxH + sc_InnerBoxSpacing)+50,"Wave Name"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 130,i*(sc_InnerBoxH + sc_InnerBoxSpacing)+50,"Record"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 200,i*(sc_InnerBoxH + sc_InnerBoxSpacing)+50,"Plot"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 250,i*(sc_InnerBoxH + sc_InnerBoxSpacing)+50,"Calculation Script ( example: dmm[i]*12.5)"

	i=0
	do
		DrawRect 9,85+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing),5+sc_InnerBoxW,85+sc_InnerBoxH+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)
		cmd="SetVariable sc_CalcWaveNameBox" + num2istr(i) + " pos={13, 92+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={110, 0}, fsize=14, title=\" \", value=sc_CalcWaveNames[i]"
		execute(cmd)		
		cmd="CheckBox sc_CalcRecordCheckBox" + num2istr(i) + ", proc=sc_CheckBoxClicked, pos={150,95+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_CalcRecord[i]) + " , title=\"\""
		execute(cmd)
		cmd="CheckBox sc_CalcPlotCheckBox" + num2istr(i) + ", proc=sc_CheckBoxClicked, pos={210,95+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_CalcPlot[i]) + " , title=\"\""
		execute(cmd)
		cmd="SetVariable sc_CalcScriptBox" + num2istr(i) + " pos={250, 92+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={410, 0}, fsize=14, title=\" \", value=sc_CalcScripts[i]"
		execute(cmd)		
		i+=1
	while (i<numpnts( sc_CalcWaveNames ))	
	button addrowcalc,pos={550,89+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)},size={110,20},proc=sc_addrow,title="Add Row"
	button removerowcalc,pos={430,89+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)},size={110,20},proc=sc_removerow,title="Remove Row"
	checkbox sc_PrintCalcBox, pos={300,89+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)}, proc=sc_CheckBoxClicked, value=sc_PrintCalc,side=1,title="\Z14Print filenames"
	
	// box for logging functions
	variable sc_Loggable
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 13,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+25,"Logging Functions (example: getSRSstatus(srs1); getIPSstatus();)"
	DrawRect 9,120+5+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+25,5+sc_InnerBoxW,120+5+sc_InnerBoxH+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+25
	cmd="SetVariable sc_LogStr pos={13, 127+5+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+25}, size={sc_InnerBoxW-12, 0}, fsize=14, title=\" \", value=sc_LogStr"
	execute(cmd)
	
	// helpful text
	DrawText 13,170+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+1)*(sc_InnerBoxH+sc_InnerBoxSpacing),"Press Update to save changes."
	DrawText 13,190+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+1)*(sc_InnerBoxH+sc_InnerBoxSpacing),"Press ESC to abort the scan and save data, while this window is active"
	
	// Close all open graphs
	button killgraphs, pos={420,154+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+1)*(sc_InnerBoxH+sc_InnerBoxSpacing)},size={120,20},proc=sc_killgraphs,title="Close All Graphs"
	button killabout, pos={220,154+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+1)*(sc_InnerBoxH+sc_InnerBoxSpacing)},size={190,20},proc=sc_controlwindows,title="Kill Sweep Control Windows"
	
	//Update button
	button updatebutton, pos={550,154+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+1)*(sc_InnerBoxH+sc_InnerBoxSpacing)},size={110,20},proc=sc_updatewindow,title="Update"
EndMacro

function sc_killgraphs(action) : Buttoncontrol
	string action
	string opengraphs
	variable ii
	
	opengraphs = winlist("*",";","WIN:1")
	if(itemsinlist(opengraphs)>0)
		for(ii=0;ii<itemsinlist(opengraphs);ii+=1)
			killwindow $stringfromlist(ii,opengraphs)	
		endfor
	endif
	sc_controlwindows("") // Kill all open control windows
end

function sc_updatewindow(action) : ButtonControl
	string action
	// Write (or overwrite) a config file
	sc_createconfig()
end

function sc_addrow(action) : ButtonControl
	string action
	wave/t sc_RawWaveNames=sc_RawWaveNames
	wave sc_RawRecord=sc_RawRecord 
	wave sc_RawPlot=sc_RawPlot
	wave/t sc_RequestScripts=sc_RequestScripts
	wave/t sc_GetResponseScripts=sc_GetResponseScripts
	wave/t sc_CalcWaveNames=sc_CalcWaveNames
	wave sc_CalcRecord=sc_CalcRecord 
	wave sc_CalcPlot=sc_CalcPlot
	wave/t sc_CalcScripts=sc_CalcScripts
	
	strswitch(action)
		case "addrowraw":
			AppendString(sc_RawWaveNames, "")
			AppendValue(sc_RawRecord, 0)
			AppendValue(sc_RawPlot, 0)
			AppendString(sc_RequestScripts, "")
			AppendString(sc_GetResponseScripts, "")
		break
		case "addrowcalc":
			AppendString(sc_CalcWaveNames, "")
			AppendValue(sc_CalcRecord, 0)
			AppendValue(sc_CalcPlot, 0)
			AppendString(sc_CalcScripts, "")
		break
	endswitch
	sc_rebuildwindow()
end

function sc_removerow(action) : Buttoncontrol
	string action
	wave/t sc_RawWaveNames=sc_RawWaveNames
	wave sc_RawRecord=sc_RawRecord 
	wave sc_RawPlot=sc_RawPlot
	wave/t sc_RequestScripts=sc_RequestScripts
	wave/t sc_GetResponseScripts=sc_GetResponseScripts
	wave/t sc_CalcWaveNames=sc_CalcWaveNames
	wave sc_CalcRecord=sc_CalcRecord 
	wave sc_CalcPlot=sc_CalcPlot
	wave/t sc_CalcScripts=sc_CalcScripts
	
	strswitch(action)
		case "removerowraw":
			if(numpnts(sc_RawWaveNames) > 1)
				Redimension /N=(numpnts(sc_RawWaveNames)-1) sc_RawWaveNames
				Redimension /N=(numpnts(sc_RawRecord)-1) sc_RawRecord
				Redimension /N=(numpnts(sc_RawPlot)-1) sc_RawPlot
				Redimension /N=(numpnts(sc_RequestScripts)-1) sc_RequestScripts
				Redimension /N=(numpnts(sc_GetResponseScripts)-1) sc_GetResponseScripts
			else
				abort "Can't remove the last row!"
			endif
			break
		case "removerowcalc":
			if(numpnts(sc_CalcWaveNames) > 1)
				Redimension /N=(numpnts(sc_CalcWaveNames)-1) sc_CalcWaveNames
				Redimension /N=(numpnts(sc_CalcRecord)-1) sc_CalcRecord
				Redimension /N=(numpnts(sc_CalcPlot)-1) sc_CalcPlot
				Redimension /N=(numpnts(sc_CalcScripts)-1) sc_CalcScripts
			else
				abort "Can't remove the last row!"
			endif
			break
	endswitch
	sc_rebuildwindow()
end

// Update after checkbox clicked
function sc_CheckboxClicked(ControlName, Value)
	string ControlName
	variable value
	string indexstring
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	nvar sc_PrintRaw, sc_PrintCalc
	variable index
	string expr
	if (stringmatch(ControlName,"sc_RawRecordCheckBox*"))
		expr="sc_RawRecordCheckBox([[:digit:]]+)"
		SplitString/E=(expr) controlname, indexstring
		index = str2num(indexstring)
		sc_RawRecord[index] = value
	elseif (stringmatch(ControlName,"sc_CalcRecordCheckBox*"))
		expr="sc_CalcRecordCheckBox([[:digit:]]+)"
		SplitString/E=(expr) controlname, indexstring
		index = str2num(indexstring)
		sc_CalcRecord[index] = value
	elseif (stringmatch(ControlName,"sc_RawPlotCheckBox*"))
		expr="sc_RawPlotCheckBox([[:digit:]]+)"
		SplitString/E=(expr) controlname, indexstring
		index = str2num(indexstring)
		sc_RawPlot[index] = value
	elseif (stringmatch(ControlName,"sc_CalcPlotCheckBox*"))
		expr="sc_CalcPlotCheckBox([[:digit:]]+)"
		SplitString/E=(expr) controlname, indexstring
		index = str2num(indexstring)
		sc_CalcPlot[index] = value
	elseif(stringmatch(ControlName,"sc_PrintRawBox"))
		sc_PrintRaw = value
	elseif(stringmatch(ControlName,"sc_PrintCalcBox"))
		sc_PrintCalc = value
	endif
end

function InitializeWaves(start, fin, numpts, [starty, finy, numptsy, x_label, y_label])
	variable start, fin, numpts, starty, finy, numptsy
	string x_label, y_label
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	wave /T sc_RawWaveNames, sc_CalcWaveNames, sc_RequestScripts, sc_GetResponseScripts
	variable i=0, j=0
	string cmd = "", wn = "", wn2d="", s, script = "", script0 = "", script1 = ""
	string /g sc_x_label, sc_y_label
	variable /g sc_is2d, sc_scanstarttime = datetime
	variable /g sc_startx, sc_finx, sc_numptsx, sc_starty, sc_finy, sc_numptsy
	variable/g sc_abortsweep=0, sc_pause=0
	string graphlist, graphname, plottitle, graphtitle="", graphnumlist="", graphnum, activegraphs="", cmd1="",window_string=""
	string cmd2=""
	variable index, graphopen, graphopen2d
	svar sc_ColorMap
	
	//do some sanity checks on wave names: they should not start or end with numbers.
	do
		if (sc_RawRecord[i])
			s = sc_RawWaveNames[i]
			if (!((char2num(s[0]) >= 97 && char2num(s[0]) <= 122) || (char2num(s[0]) >= 65 && char2num(s[0]) <= 90)))
				print "The first character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
				abort
			endif
			if (!((char2num(s[strlen(s)-1]) >= 97 && char2num(s[strlen(s)-1]) <= 122) || (char2num(s[strlen(s)-1]) >= 65 && char2num(s[strlen(s)-1]) <= 90)))
				print "The last character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
				abort
			endif
		endif
		i+=1
	while (i<numpnts(sc_RawWaveNames))
	i=0
	do
		if (sc_CalcRecord[i])
			s = sc_CalcWaveNames[i]
			if (!((char2num(s[0]) >= 97 && char2num(s[0]) <= 122) || (char2num(s[0]) >= 65 && char2num(s[0]) <= 90)))
				print "The first character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
				abort
			endif
			if (!((char2num(s[strlen(s)-1]) >= 97 && char2num(s[strlen(s)-1]) <= 122) || (char2num(s[strlen(s)-1]) >= 65 && char2num(s[strlen(s)-1]) <= 90)))
				print "The last character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
				abort
			endif
		endif
		i+=1
	while (i<numpnts(sc_CalcWaveNames))	
	i=0
	
	// The status of the upcoming scan will be set when waves are initialized.
	if(!paramisdefault(starty) && !paramisdefault(finy) && !paramisdefault(numptsy))
		sc_is2d = 1
		sc_startx = start
		sc_finx = fin
		sc_numptsx = numpts
		sc_starty = starty
		sc_finy = finy
		sc_numptsy = numptsy
	else
		sc_is2d = 0
		sc_startx = start
		sc_finx = fin
		sc_numptsx = numpts	
	endif
	
	if(paramisdefault(x_label) || stringmatch(x_label,""))
		sc_x_label=""
	else
		sc_x_label=x_label
	endif
	
	if(paramisdefault(y_label) || stringmatch(y_label,""))
		sc_y_label=""
	else
		sc_y_label=y_label
	endif
	
	// Initialize waves for raw data
	do
		if (sc_RawRecord[i] == 1 && cmpstr(sc_RawWaveNames[i], "") || sc_RawPlot[i] == 1 && cmpstr(sc_RawWaveNames[i], ""))
			wn = sc_RawWaveNames[i]
			cmd = "make /o/n=(" + num2istr(sc_numptsx) + ") " + wn + "=NaN"
			execute(cmd)
			cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + wn
			execute(cmd)
			if(sc_is2d)
				// In case this is a 2D measurement
				wn2d = wn + "2d"
				cmd = "make /o/n=(" + num2istr(sc_numptsx) + ", " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd)
				cmd = "setscale /i x, " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", " + wn2d; execute(cmd)
				cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)
			endif			
		endif
		i+=1
	while (i<numpnts(sc_RawWaveNames))

	// Initialize waves for calculated data
	i=0
	do
		if (sc_CalcRecord[i] == 1 && cmpstr(sc_CalcWaveNames[i], "") || sc_CalcPlot[i] == 1 && cmpstr(sc_CalcWaveNames[i], ""))
			wn = sc_CalcWaveNames[i]
			cmd = "make /o/n=(" + num2istr(sc_numptsx) + ") " + wn + "=NaN"
			execute(cmd)
			cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + wn
			execute(cmd)		
			if(sc_is2d)
				// In case this is a 2D measurement
				wn2d = wn + "2d"
				cmd = "make /o/n=(" + num2istr(sc_numptsx) + ", " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd)
				cmd = "setscale /i x, " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", " + wn2d; execute(cmd)
				cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)
			endif			
			
		endif
		i+=1
	while (i<numpnts(sc_CalcWaveNames))
	
	// Find all open plots
	graphlist = winlist("*",";","WIN:1")
	j=0
	for (i=0;i<round(strlen(graphlist)/6);i=i+1)
		index = strsearch(graphlist,";",j)
		graphname = graphlist[j,index-1]
		setaxis/w=$graphname /a
		getwindow $graphname wtitle
		splitstring /e="(.*):(.*)" s_value, graphnum, plottitle
		graphtitle+= plottitle+";"
		graphnumlist+= graphnum+";"
		j=index+1
	endfor
	
	//Initialize plots for raw data waves
	i=0
	do
		if (sc_RawPlot[i] == 1 && cmpstr(sc_RawWaveNames[i], ""))
			wn = sc_RawWaveNames[i]
			graphopen = 0
			graphopen2d = 0
			for(j=0;j<ItemsInList(graphtitle);j=j+1)
				if(stringmatch(wn,stringfromlist(j,graphtitle)))
					graphopen = 1
					activegraphs+= stringfromlist(j,graphnumlist)+";"
					Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
				endif
				if(sc_is2d)
					if(stringmatch(wn+"2d",stringfromlist(j,graphtitle)))
						graphopen2d = 1
						activegraphs+= stringfromlist(j,graphnumlist)+";"
						Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
					endif
				endif
			endfor
			if(graphopen && graphopen2d)
			elseif(graphopen2d)
				display $wn
				Label bottom, sc_x_label
				activegraphs+= winname(0,1)+";"
			elseif(graphopen)
				if(sc_is2d)
					wn2d = wn + "2d"
					display
					appendimage $wn2d
					modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
					colorscale /c/n=$sc_ColorMap /e/a=rc
					Label left, sc_y_label
					Label bottom, sc_x_label
					activegraphs+= winname(0,1)+";"
				endif
			else
				wn2d = wn + "2d"
				display $wn
				Label bottom, sc_x_label
				activegraphs+= winname(0,1)+";"
				if(sc_is2d)
					display
					appendimage $wn2d
					modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
					colorscale /c/n=$sc_ColorMap /e/a=rc
					Label left, sc_y_label
					Label bottom, sc_x_label
					activegraphs+= winname(0,1)+";"
				endif
			endif
		endif
		i+= 1
	while(i<numpnts(sc_RawWaveNames))
	
	//Initialize plots for calculated data waves
	i=0
	do
		if (sc_CalcPlot[i] == 1 && cmpstr(sc_CalcWaveNames[i], ""))
			wn = sc_CalcWaveNames[i]
			graphopen = 0
			graphopen2d = 0
			for(j=0;j<ItemsInList(graphtitle);j=j+1)
				if(stringmatch(wn,stringfromlist(j,graphtitle)))
					graphopen = 1
					activegraphs+= stringfromlist(j,graphnumlist)+";"
					Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
				endif
				if(sc_is2d)
					if(stringmatch(wn+"2d",stringfromlist(j,graphtitle)))
						graphopen2d = 1
						activegraphs+= stringfromlist(j,graphnumlist)+";"
						Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
					endif
				endif
			endfor
			if(graphopen && graphopen2d)
			elseif(graphopen2d)
				display $wn
				Label bottom, sc_x_label
				activegraphs+= winname(0,1)+";"
			elseif(graphopen)
				if(sc_is2d)
					wn2d = wn + "2d"
					display
					appendimage $wn2d
					modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
					colorscale /c/n=$sc_ColorMap /e/a=rc
					Label left, sc_y_label
					Label bottom, sc_x_label
					activegraphs+= winname(0,1)+";"
				endif
			else
				wn2d = wn + "2d"
				display $wn
				Label bottom, sc_x_label
				activegraphs+= winname(0,1)+";"
				if(sc_is2d)
					display
					appendimage $wn2d
					modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
					colorscale /c/n=$sc_ColorMap /e/a=rc
					Label left, sc_y_label
					Label bottom, sc_x_label
					activegraphs+= winname(0,1)+";"
				endif
			endif
		endif
		i+= 1
	while(i<numpnts(sc_CalcWaveNames))
	
	execute("abortmeasurementwindow()")
	
	cmd1 = "TileWindows/O=1/A=(3,4) "
	// Tile graphs
	for(i=0;i<itemsinlist(activegraphs);i=i+1)
		window_string = stringfromlist(i,activegraphs)
		cmd1+= window_string +","
		cmd2 = "DoWindow/F " + window_string
		execute(cmd2)
	endfor
	cmd1 += "SweepControl"
	execute(cmd1)
end

function sc_controlwindows(action)
	string action
	string openaboutwindows
	variable ii
	
	openaboutwindows = winlist("SweepControl*",";","WIN:64")
	if(itemsinlist(openaboutwindows)>0)
		for(ii=0;ii<itemsinlist(openaboutwindows);ii+=1)
			killwindow $stringfromlist(ii,openaboutwindows)	
		endfor
	endif
end

/////////////////////////////
/////  sweep controls   /////
/////////////////////////////

window abortmeasurementwindow() : Panel
	//Silent 1 // building window
	NewPanel /W=(500,700,750,750) /N=SweepControl// window size
	ModifyPanel frameStyle=2
	ModifyPanel fixedSize=1
	SetDrawLayer UserBack
	Button pausesweep, pos={10,15},size={110,20},proc=pausesweep,title="Pause"
	Button stopsweep, pos={130,15},size={110,20},proc=stopsweep,title="Abort"
	DoUpdate /W=SweepControl /E=1
endmacro

function stopsweep(action) : Buttoncontrol
	string action
	nvar sc_abortsweep
	
	sc_abortsweep = 1
end 

function pausesweep(action) : Buttoncontrol
	string action
	nvar sc_pause, sc_abortsweep
	
	Button pausesweep,proc=resumesweep,title="Resume"
	sc_pause=1
	print "Sweep paused by user"
end

function resumesweep(action) : Buttoncontrol
	string action
	nvar sc_pause
	
	Button pausesweep,proc=pausesweep,title="Pause"
	sc_pause = 0
	print "Sweep resumed"
end

function sc_checksweepstate()
	nvar sc_abortsweep, sc_pause
	if (GetKeyState(0) & 32)
			// If the ESC button is pressed during the scan, save existing data and stop the scan.
			SaveWaves(msg="The scan was aborted during the execution.", save_experiment=0)
			abort
		endif
		
		if(sc_abortsweep)
			// If the Abort button is pressed during the scan, save existing data and stop the scan.
			SaveWaves(msg="The scan was aborted during the execution.", save_experiment=0)
			dowindow /k SweepControl
			sc_abortsweep=0
			abort "Measurement aborted by user"
		elseif(sc_pause)
			// Pause sweep if button is pressed
			do
				if(sc_abortsweep)
					SaveWaves(msg="The scan was aborted during the execution.", save_experiment=0)
					dowindow /k SweepControl
					sc_abortsweep=0
					abort "Measurement aborted by user"
				endif
			while(sc_pause)
	endif
end

function sc_sleep(delay)
	// sleep for delay seconds
	// checks for keyboard interrupts in mstimer loop
	variable delay
	delay = delay*1e6 // convert to microseconds
	variable start_time = stopMStimer(-2) // start the timer immediately
	
	doupdate // do this just once during the sleep function
	
	do
		sc_checksweepstate()
	while(stopMStimer(-2)-start_time < delay)
	
end

/////////////////////////////
////  read/record funcs  ////
/////////////////////////////
 	
function RecordValues(i, j, [scandirection, readvstime, fillnan])
	// In a 1d scan, i is the index of the loop. j will be ignored.
	// In a 2d scan, i is the index of the outer (slow) loop, and j is the index of the inner (fast) loop. 

	// In a 2D scan, if scandirection=1 (scan up), the 1d wave gets saved into the matrix when j=numptsy. 
	// If scandirection=-1(scan down), the 1d matrix gets saved when j=0. Default is 1 (up)
	
	// readvstime works only in 1d and rescales (grows) the wave at each index
		
	// fillnan skips any read or calculation functions entirely and fills point [i,j] with nan
	
	variable i, j, scandirection, readvstime, fillnan
	nvar sc_is2d, sc_startx, sc_finx, sc_numptsx, sc_starty, sc_finy, sc_numptsy
	variable ii = 0, jj=0
	wave /t sc_RawWaveNames, sc_RequestScripts, sc_GetResponseScripts, sc_CalcWaveNames, sc_CalcScripts
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	string script = "",cmd = "", wstr = ""
	variable innerindex, outerindex
	nvar sc_abortsweep, sc_pause,sc_scanstarttime
	variable /g sc_tmpVal
	
	//// setup all sorts of logic so we can store values correctly ////
	
	if (sc_is2d)
		// 2d
		innerindex = j
		outerindex = i
	else
		// 1d
		innerindex = i
		outerindex = i // meaningless
	endif
	
	// Default scan direction is up
	if (paramisdefault(scandirection))
		scandirection=1
	endif
	variable /g sc_scandirection = scandirection // create global variable for this
	
	// Set readvstime to 0 if it's not defined
	if(paramisdefault(readvstime))
		readvstime=0
	endif
	
	if(paramisdefault(fillnan))
		fillnan=0
	endif
	
	if(readvstime==1 && sc_is2d)
		abort "NOT IMPLEMENTED: Read vs Time is currently only supported for 1D sweeps."
	endif
	
	//// Send requests to machines ////
	if(fillnan == 0)
		do
			if (sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1)
				jj=0;
				script = sc_RequestScripts[ii];
				if (cmpstr(script, ""))
					execute(script)
				endif
			endif
			ii+=1
		while (ii < numpnts(sc_RawWaveNames))
	endif
	
	//// Read responses from machines ////
	ii=0
	cmd = ""
	do
		if (sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1)
			wave wref1d = $sc_RawWaveNames[ii]
			
			// Redimension waves if readvstime is set to 1
			if (readvstime == 1)
				redimension /n=(innerindex+1) $sc_RawWaveNames[ii]
				setscale/I x 0,  datetime - sc_scanstarttime, $sc_RawWaveNames[ii]
			endif
			
			if(fillnan == 0)
				script = sc_GetResponseScripts[ii] // assume script will execute and return a 'variable'
												           // let it fail hard otherwise
				sprintf cmd, "%s = %s", "sc_tmpVal", script
				execute(cmd)
			elseif(fillnan == 1)
				sc_tmpval = nan
			endif
			wref1d[innerindex] = sc_tmpval
			
			if (sc_is2d)
				// 2D Wave
				wave wref2d = $sc_RawWaveNames[ii] + "2d"
				wref2d[innerindex][outerindex] = sc_tmpval
			endif
		endif
		ii+=1
	while (ii < numpnts(sc_RawWaveNames))
	
	//// Calculate interpreted numbers and store them in calculated waves ////
	ii=0
	cmd = ""
	do
		if (sc_CalcRecord[ii] == 1 || sc_CalcPlot[ii] == 1)
			wave wref1d = $sc_CalcWaveNames[ii] // this is the 1D wave I am filling
												  
			// Redimension waves if readvstimeis set to 1
			if (readvstime == 1)
				redimension /n=(innerindex+1) wref1d
				setscale/I x 0, datetime - sc_scanstarttime, $sc_CalcWaveNames[ii]
			endif
			
			if(fillnan == 0)
				script = sc_CalcScripts[ii]; // assume script will execute and return a 'variable'
												     // let it fail hard otherwise
												     
				// Allow the use of the keyword '[i]' in calculated fields where i is the inner loop's current index
				script = ReplaceString("[i]", script, "["+num2istr(innerindex)+"]")
				sprintf cmd, "%s = %s", "sc_tmpVal", script
				execute(cmd)
			elseif(fillnan == 1)
				sc_tmpval = nan
			endif
			wref1d[innerindex] = sc_tmpval
			
			if (sc_is2d)				
				wave wref2d = $sc_CalcWaveNames[ii] + "2d"
				wref2d[innerindex][outerindex] = wref1d[innerindex]
			endif
		endif
		ii+=1
	while (ii < numpnts(sc_CalcWaveNames))
	
	// check abort/pause status
	sc_checksweepstate()
	
end

////////////////////////
////  save all data ////
////////////////////////

function SaveWaves([msg, save_experiment])
	// the message will be printed in the history, and will be saved in the winf file corresponding to this scan
	// save_experiment=1 to save the experiment file
	// srv_push=1 to alert qdot-server of new data
	string msg
	variable save_experiment
	nvar sc_is2d, sc_PrintRaw, sc_PrintCalc, sc_scanstarttime, sc_srv_push
	svar sc_x_label, sc_y_label, sc_LogStr
	string filename, wn, logs=""
	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	wave /t sc_RawWaveNames, sc_CalcWaveNames
	wave sc_RawRecord, sc_CalcRecord
	variable ii=0, Rawadd =0, Calcadd = 0

	if (!paramisdefault(msg))
		print msg
	else
		msg=""
	endif
	
	if (paramisdefault(save_experiment))
		save_experiment = 1 // save the experiment by default
	endif
	
	variable /g sc_save_exp = save_experiment
	
	if (strlen(sc_LogStr)!=0)
		logs = sc_LogStr
	endif

	// Raw Data
	do
		Rawadd += sc_RawRecord[ii]
		if (sc_RawRecord[ii] == 1)
			wn = sc_RawWaveNames[ii]
			if (sc_is2d)
				wn += "2d"
			endif
			filename =  "dat" + filenumstr + wn
			duplicate $wn $filename // filename is a new wavename and will become <filename.xxx>
			if(sc_PrintRaw == 1)
				print filename
			endif
			saveSingleWave(filename)
			SaveInitialWaveComments(wn, x_label=sc_x_label, y_label=sc_y_label)
		endif
		ii+=1
	while (ii < numpnts(sc_RawWaveNames))
	
	// Calculated Data
	ii=0
	do
		Calcadd += sc_CalcRecord[ii]
		if (sc_CalcRecord[ii] == 1)
			wn = sc_CalcWaveNames[ii]
			if (sc_is2d)
				wn += "2d"
			endif
			filename =  "dat" + filenumstr + wn
			duplicate $wn $filename
			if(sc_PrintCalc == 1)
				print filename
			endif
			saveSingleWave(filename)
			SaveInitialWaveComments(wn, x_label=sc_x_label, y_label=sc_y_label)
		endif
		ii+=1
	while (ii < numpnts(sc_CalcWaveNames))
	
	variable /g sweep_t_elapsed = datetime-sc_scanstarttime
	printf "Time elapsed: %.2f s \r", sweep_t_elapsed
	
	dowindow /k SweepControl
	
	if(Rawadd+Calcadd > 0)
		printf "saving all dat%d files...\r", filenum
		
		saveScanComments(msg=msg, logs=logs)
		
		if(sc_save_exp == 1 & sweep_t_elapsed>10.0)
			saveExp()
		endif
		
		if(sc_srv_push==1)
			sc_findNewFiles(filenum)
			sc_NotifyServer()
		endif
		
		filenum+=1
	endif
	
end

////////////////////////////
////  write out history ////
////////////////////////////

function getCmdHistory()
	// this is all based on 
	
	string expFile = igorinfo(1)+".pxp"
	variable expRef
	open /r/z/p=data expRef as expFile // open experiment file as read-only
	if(V_flag!=0)
		print "Experiment file could not be opened to fetch command history: ", expFile
		return 0
	endif
	FStatus expRef
	variable totalBytes = V_logEOF
	
	string histFile = igorinfo(1)+".history"
	variable histRef
	open /p=data histRef as histFile

	variable pos = 0, foundHistory=0
	variable recordType, version, numDataBytes
	do
		FSetPos expRef, pos                // go to next header position
		FBinRead /U/F=2 expRef, recordType // unsigned, two-byte integer
		recordType = recordType&0x7FFF     // mask to get just the type value
		FBinRead /F=2 expRef, version      // signed, two-byte integer
		FBinRead /F=3 expRef, numDataBytes // signed, four-byte integer
		
		if(recordType==2)
			foundHistory=1
			break
		endif
		
		FGetPos expRef
		pos = V_filePos + numDataBytes
	while(pos<totalBytes)

	if(foundHistory==0)
		print "WARNING: no command history saved"
		return 0
	endif

	string buffer=""
	variable bytes=0
	do
		FReadLine /N=(numDataBytes-bytes) expRef, buffer
		bytes+=strlen(buffer)
		fprintf histRef, "%s", buffer
	while(bytes<numDataBytes)
	
	close expRef
	close histRef
	
	if(bytes!=numDataBytes)
		 print "WARNING: Parts of history not written to file"
		 return 0
	else	
		return 1
	endif
end

////////////////////////
////  notifications ////
////////////////////////

function sc_findNewFiles(datnum)
	// path -- loction of new file: "data", "winfs", "config"
	// filename -- name of new file
	variable datnum
	variable refnum
	nvar sc_save_exp
	string winfpath = getExpPath("winfs", full=0)
	string configpath = getExpPath("config", full=0)
	string datapath = getExpPath("data", full=0)
	
	//// create/open qdot-server.notify ////
	
	getfilefolderinfo /Q/Z/P=data "qdot-server.notify"
	if(V_isFile==0) // if the file does not exist, create it with hostname/n at the top
		open /A/P=data refnum as "qdot-server.notify"
		fprintf refnum, "%s\n", getHostName()
	else // if the file does exist, open it for appending
		open /A/P=data refnum as "qdot-server.notify"
	endif
	
	string tmpname = ""
	// add the most recent config file
	string configlist = greplist(indexedfile(config,-1,".config"),"sc")
	
	if(itemsinlist(configlist)>0)
		// read content into waves
		configlist = SortList(configlist, ";", 1+16)
		tmpname = configpath+StringFromList(0,configlist, ";")
		grep /Q /E=tmpname /p=data "qdot-server.notify"
		if(V_value==0)
			fprintf refnum, "%s\n", tmpname
		endif
	endif
	
	// add experiment file?
	if(sc_save_exp == 1)
		tmpname = datapath+igorinfo(1)+".pxp"
		grep /Q /E=tmpname /p=data "qdot-server.notify"
		if(V_value==0)
			fprintf refnum, "%s\n", tmpname
		endif
	endif
	
	// add history file?
	if(sc_save_exp == 1)
		tmpname = datapath+igorinfo(1)+".history"
		grep /Q /E=tmpname /p=data "qdot-server.notify"
		if(V_value==0)
			fprintf refnum, "%s\n", tmpname
		endif
	endif
	
	// find new data files
	string datstr = "dat"+num2str(datnum)+"*"
	string datlist = IndexedFile(data, -1, ".ibw")
	datlist = ListMatch(datlist, datstr, ";")
	variable i=0
	for(i = 0 ; i < itemsinlist(datlist, ";") ; i+=1)
		tmpname = datapath+StringFromList(i,datlist, ";")
		fprintf refnum, "%s\n", tmpname
	endfor
	
	// find new winf files
	string winflist = IndexedFile(winfs, -1, ".winf")
	winflist = ListMatch(winflist, datstr, ";")
	for(i = 0 ; i < itemsinlist(winflist, ";") ; i+=1)
		tmpname = winfpath+StringFromList(i,winflist, ";")
		fprintf refnum, "%s\n", tmpname
	endfor
	
	close refnum // close qdot-server.notify
end

function sc_NotifyServer()
	svar server_url
	
	variable refnum
	open /A/P=data refnum as "qdot-server.notify"
	
	if(refnum==0)
		// if there is not qdot-server.notify file
		// I don't need to do anything
		print "No new files available."
		return 0
	else
		fprintf refnum, "\n"
		close refnum
	endif

	URLRequest /TIME=5.0 /P=data /DFIL="qdot-server.notify" url=server_url, method=post
	if (V_flag == 0)    // No error
        if (V_responseCode != 200)  // 200 is the HTTP OK code
            print "New file notification failed!"
            return 0
        else
            sc_DeleteNotificationFile()
            return 1
        endif
    else
        print "HTTP connection error. New file notification not attempted."
        return 0
    endif

end

function sc_DeleteNotificationFile()
	// delete qdot-server.notify
	deletefile /Z/P=data "qdot-server.notify"
	if(V_flag!=0)
		print "Failed to delete 'qdot-server.notify'"
	endif
end

function getSlackNotice(username, [message, channel, botname, emoji, min_time])
	// this function will send a notification to Slack
	// username = your slack username
	
	// message = string to include in Slack message
	// channel = slack channel to post the message in
	//            if no channel is provided a DM will be sent to username
	// botname = slack user that will post the message, defaults to @qdotbot
	// emoji = emoji that will be used as the bots avatar, defaults to :the_horns:
	// min_time = if time elapsed for this current scan is less than min_time no notification will be sent
	//					defaults to 60 seconds
	string username, channel, message, botname, emoji
	variable min_time
	nvar filenum, sweep_t_elapsed, sc_abortsweep
	svar slack_url
	string txt="", buffer="", payload=""
	
	//// check if I need a notification ////
	if (paramisdefault(min_time))
		min_time = 60.0 // seconds
	endif

	if(sweep_t_elapsed < min_time)
		return 0 // no notification if min_time is not exceeded
	endif
	
	if(sc_abortsweep)
		return 0 // no notification if sweep was aborted by the user
	endif
	//// end notification checks //// 
	
	
	//// build notification text ////
	if (!paramisdefault(channel)) 
		// message will be sent to public channel
		// user who sent it will be mentioned at the beginning of the message
		txt += "<@"+username+">\r" 
	endif
	
	if (!paramisdefault(message) && strlen(message)>0)
		txt += RemoveTrailingWhitespace(message) + "\r"
	endif
		
	sprintf buffer, "dat%d completed:  %s %s \r", filenum, Secs2Date(DateTime, 1), Secs2Time(DateTime, 3); txt+=buffer 
	sprintf buffer, "time elapsed:  %.2f s \r", sweep_t_elapsed; txt+=buffer
	//// end build txt ////
	
	
	//// build payload ////
	sprintf buffer, "{\"text\": \"%s\"", txt; payload+=buffer // 
	
	if (paramisdefault(botname))
		botname = "qdotbot"
	endif	
	sprintf buffer, ", \"username\": \"%s\"", botname; payload+=buffer
	
	if (paramisdefault(channel))
		sprintf buffer, ", \"channel\": \"@%s\"", username; payload+=buffer
	else
		sprintf buffer, ", \"channel\": \"#%s\"", channel; payload+=buffer
	endif
	
	if (paramisdefault(emoji))
		emoji = ":the_horns:"
	endif	
	sprintf buffer, ", \"icon_emoji\": \"%s\"", emoji; payload+=buffer // 
	
	payload += "}"
	//// end payload ////
	
	URLRequest /DSTR=payload url=slack_url, method=post
	if (V_flag == 0)    // No error
        if (V_responseCode != 200)  // 200 is the HTTP OK code
            print "Slack post failed!"
            return 0
        else
            return 1
        endif
    else
        print "HTTP connection error. Slack post not attempted."
        return 0
    endif
end

////////////////////////
//// test functions ////
////////////////////////

function sc_testreadtime(numpts, delay) //Units: s
	variable numpts, delay

	InitializeWaves(0, numpts, numpts, x_label="index")
	variable i=0, ttotal = 0, tstart = datetime
	do
		sc_sleep(delay)
		RecordValues(i, 0, fillnan=0) 
		i+=1
	while (i<numpts)
	ttotal = datetime-tstart
	printf "each sc_sleep(...) + RecordValues(...) call takes ~%.1fms \n", ttotal/numpts*1000
	
	sc_controlwindows("") // kill sweep control windows
end