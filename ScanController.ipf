#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Scan Controller routines for 1d and 2d scans
// Version 1.7 August 8, 2016
// Version 1.8 XXXX X, 2017
// Version 2.0 May, 2018
// Authors: Mohammad Samani, Nik Hartman & Christian Olsen

// Updates in 2.0:

//		-- All drivers now uses the VISA xop, as it is the only one supporting multiple threads.
//			VDT and GPIB xop's should not be used anymore.
//		-- "Request scripts" are removed from the scancontroller window. Its only use was
//			 trying to do async communication (badly).
//    -- Added Async checkbox in scancontroller window


///////////////////////////////
////// utility functions //////
///////////////////////////////

function unixTime()
	// returns the current unix time in seconds
	return DateTime - date2secs(1970,1,1) - date2secs(-1,-1,-1)
end

function roundNum(number,decimalplace) // to return integers, decimalplace=0
	variable number, decimalplace
	variable multiplier
	multiplier = 10^decimalplace
	return round(number*multiplier)/multiplier
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

function /S executeWinCmd(command)
	// run the shell command
	// if logFile is selected, put output there
	// otherwise, return output
	string command
	string dataPath = getExpPath("data", full=2)

	// open batch file to store command
	variable batRef
	string batchFile = "_execute_cmd.bat"
	string batchFull = datapath + batchFile
	Open/P=data batRef as batchFile	// overwrites previous batchfile

	// setup log file paths
	string logFile = "_execute_cmd.log"
	string logFull = datapath + logFile

	// write command to batch file and close
	fprintf batRef,"cmd/c \"%s > \"%s\"\"\r", command, logFull
	Close batRef

	// execute batch file with output directed to logFile
	ExecuteScriptText /Z /W=5.0 /B "\"" + batchFull + "\""

	string outputLine, result = ""
	variable logRef
	Open/P=data logRef as logFile
	do
		FReadLine logRef, outputLine
		if( strlen(outputLine) == 0 )
			break
		endif
		result += outputLine
	while( 1 )
	Close logRef

	DeleteFile /P=data /Z=1 batchFile // delete batch file
	DeleteFile /P=data /Z=1 logFile   // delete batch file
	return result

end

function/S executeMacCmd(command)
	// http://www.igorexchange.com/node/938
	string command

	string cmd
	sprintf cmd, "do shell script \"%s\"", command
	ExecuteScriptText /UNQ /Z /W=5.0 cmd

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
			return TrimString(LowerStr(hostname))
		case "Windows":
			hostname = executeWinCmd("hostname")
			return TrimString(LowerStr(hostname))
		default:
			abort "What operating system are you running?! How?!"
	endswitch

end

function /S getExpPath(whichpath, [full])
	// whichpath determines which path will be returned (data, config)
	// lmd always gives the path to local_measurement_data
	// if full==0, the path relative to local_measurement_data is returned in Unix style
	// if full==1, the path relative to local_measurement_data is returned in colon-separated igor style
	// if full==2, the full path on the local machine is returned in native style
	// if full==3, the full path is returned in colon-separated igor format

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

	string platform = igorinfo(2), separatorStr=""
	if(cmpstr(platform,"Windows")==0)
		separatorStr="*"
	else
		separatorStr="/"
	endif

	strswitch(whichpath)
		case "lmd":
			// returns path to local_measurement_data on local machine
			// always assumes you want the full path
			if(full==2)
				return ParseFilePath(5, temp1+temp2+":", separatorStr, 0, 0)
			elseif(full==3)
				return temp1+temp2+":"
			else
				return ""
			endif
		case "data":
			// returns path to data relative to local_measurement_data
			if(full==0)
				return ReplaceString(":", temp3[1,inf], "/")
			elseif(full==1)
				return temp3[1,inf]
			elseif(full==2)
				return ParseFilePath(5, temp1+temp2+temp3, separatorStr, 0, 0)
			elseif(full==3)
				return S_path
			else
				return ""
			endif
		case "config":
			if(full==0)
				return ReplaceString(":", temp3[1,inf], "/")+"config/"
			elseif(full==1)
				return temp3[1,inf]+"config:"
			elseif(full==2)
				if(cmpstr(platform,"Windows")==0)
					return ParseFilePath(5, temp1+temp2+temp3+"config:", separatorStr, 0, 0)
				else
					return ParseFilePath(5, temp1+temp2+temp3, separatorStr, 0, 0)+"config/"
				endif
			elseif(full==3)
				return S_path+"config:"
			else
				return ""
			endif
		case "backup_data":
			// returns full path to the backup-data directory
			// always assumes you want the full path
			
			pathinfo backup_data // get path info
			if(V_flag == 0) // check if path is defined
				abort "backup_data path is not defined!\n"
			endif
			
			if(full==2)
				return ParseFilePath(5, S_path, separatorStr, 0, 0)
			elseif(full==3)
				return S_path
			else // full=0 or 1
				return ""
			endif
		case "backup_config":
			// returns full path to the backup-data directory
			// always assumes you want the full path
			
			pathinfo backup_config // get path info
			if(V_flag == 0) // check if path is defined
				abort "backup_config path is not defined!\n"
			endif
			
			if(full==2)
				return ParseFilePath(5, S_path, separatorStr, 0, 0)
			elseif(full==3)
				return S_path
			else // full=0 or 1
				return ""
			endif
		case "setup":
			if(full==0)
				return ReplaceString(":", temp3[1,inf], "/")+"setup/"
			elseif(full==1)
				return temp3[1,inf]+"config:"
			elseif(full==2)
				if(cmpstr(platform,"Windows")==0)
					return ParseFilePath(5, temp1+temp2+temp3+"setup:", separatorStr, 0, 0)
				else
					return ParseFilePath(5, temp1+temp2+temp3, separatorStr, 0, 0)+"setup/"
				endif
			elseif(full==3)
				return S_path+"setup:"
			else
				return ""
			endif
	endswitch
end

threadsafe function sc_check_NaNInf(num)
	variable num

	return numtype(num)
end

///////////////////////////////
//// start scan controller ////
///////////////////////////////

function sc_openInstrConnections(print_cmd)
	// open all VISA connections to instruments
	// this is a simple as running through the list defined
	//     in the scancontroller window
	variable print_cmd
	wave /T sc_Instr

	variable i=0
	string command = ""
	for(i=0;i<DimSize(sc_Instr, 0);i+=1)
		command = TrimString(sc_Instr[i][0])
		if(strlen(command)>0)
			if(print_cmd==1)
				print ">>> "+command
			endif
			execute/Q/Z command
			if(V_flag!=0)
				print "[ERROR] in sc_openInstrConnections: "+GetErrMessage(V_Flag,2)
			endif
		endif
	endfor
end

function sc_openInstrGUIs(print_cmd)
	// open GUIs for instruments
	// this is a simple as running through the list defined
	//     in the scancontroller window
	variable print_cmd
	wave /T sc_Instr

	variable i=0
	string command = ""
	for(i=0;i<DimSize(sc_Instr, 0);i+=1)
		command = TrimString(sc_Instr[i][1])
		if(strlen(command)>0)
			if(print_cmd==1)
				print ">>> "+command
			endif
			execute/Q/Z command
			if(V_flag!=0)
				print "[ERROR] in sc_openInstrGUIs: "+GetErrMessage(V_Flag,2)
			endif
		endif
	endfor
end

function sc_checkBackup()
	// the path `server` should point to /measurement-data
	//     which has been mounted as a network drive on your measurement computer
	// if it is, backups will be created in an appropriate directory
	//      qdot-server.phas.ubc.ca/measurement-data/<hostname>/<username>/<exp>
	svar sc_hostname

	GetFileFolderInfo/Z/Q/P=server  // Check if data path is definded
	if(v_flag != 0 || v_isfolder != 1)
		print "[WARNING] Only saving local copies of data. See sc_checkBackup()."
		return 0
	else
		// this should also create the path if it does not exist
		string sp = S_path
		newpath /C/O/Q backup_data sp+sc_hostname+":"+getExpPath("data", full=1)
		newpath /C/O/Q backup_config sp+sc_hostname+":"+getExpPath("config", full=1)
		
		return 1
	endif
end

function InitScanController([configFile])

	string configFile // use this to point to a specific old config

	GetFileFolderInfo/Z/Q/P=data  // Check if data path is definded
	if(v_flag != 0 || v_isfolder != 1)
		abort "Data path not defined!\n"
	endif

	string /g sc_colormap = "VioletOrangeYellow"
	string /g slack_url =  "https://hooks.slack.com/services/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" // url for slack alert
	variable /g sc_save_time = 0 // this will record the last time an experiment file was saved

	string /g sc_hostname = getHostName() // get machine name

	// check if a path is defined to backup data
	sc_checkBackup()
	
	// check if we have the correct SQL driver
	sc_checkSQLDriver()
	
	// create/overwrite setup path. All instrument/interface configs are stored here.
	newpath /C/O/Q setup getExpPath("setup", full=3)

	// deal with config file
	string /g sc_current_config = ""
	newpath /C/O/Q config getExpPath("config", full=3) // create/overwrite config path
	if(paramisdefault(configFile))
		// look for newest config file
		string filelist = greplist(indexedfile(config,-1,".json"),"sc")
		if(itemsinlist(filelist)>0)
			// read content into waves
			filelist = SortList(filelist, ";", 1+16)
			sc_loadConfig(StringFromList(0,filelist, ";"))
		else
			// if there are no config files, use defaults
			// These arrays should have the same size. Their indeces correspond to each other.
			make/t/o sc_RawWaveNames = {"g1x", "g1y"} // Wave names to be created and saved
			make/o sc_RawRecord = {0,0} // Whether you want to record and save the data for this wave
			make/o sc_RawPlot = {0,0} // Whether you want to record and save the data for this wave
			make/t/o sc_RawScripts = {"readSRSx(srs1)", "readSRSy(srs1)"}

			// And these waves should be the same size too
			make/t/o sc_CalcWaveNames = {"", ""} // Calculated wave names
			make/t/o sc_CalcScripts = {"",""} // Scripts to calculate stuff
			make/o sc_CalcRecord = {0,0} // Include this calculated field or not
			make/o sc_CalcPlot = {0,0} // Include this calculated field or not

			make /o sc_measAsync = {0,0}

			// Print variables
			variable/g sc_PrintRaw = 1,sc_PrintCalc = 1

			// instrument wave
			variable /g sc_instrLimit = 20 // change this if necessary, seeems fine
			make /t/o/N=(sc_instrLimit,3) sc_Instr
			make /o/N=(sc_instrLimit,3) instrBoxAttr = 2

			sc_Instr[0][0] = "openIPSconnection(\"ips1\", \"ASRL::1\", verbose=1)"
			sc_Instr[0][1] = "initIPS120(ips1)"
			sc_Instr[0][2] = "GetIPSStatus(ips1)"

			nvar/z filenum
			if(!nvar_exists(filenum))
				print "Initializing FileNum to 0 since it didn't exist before.\n"
				variable /g filenum=0
			else
				printf "Current filenum is %d\n", filenum
			endif
		endif
	else
		sc_loadconfig(configFile)
	endif

	sc_rebuildwindow()

end

/////////////////////////////
//// configuration files ////
/////////////////////////////

function/s sc_createConfig()
	wave/t sc_RawWaveNames, sc_RawScripts, sc_CalcWaveNames, sc_CalcScripts, sc_Instr
	wave sc_RawRecord, sc_RawPlot, sc_measAsync, sc_CalcRecord, sc_CalcPlot
	nvar sc_PrintRaw, sc_PrintCalc, filenum
	svar sc_hostname
	variable refnum
	string configfile
	string configstr = "", tmpstr = ""

	// information about the measurement computer
	tmpstr = addJSONkeyval(tmpstr, "hostname", sc_hostname, addQuotes = 1)
	string sysinfo = igorinfo(3)
	tmpstr = addJSONkeyval(tmpstr, "OS", StringByKey("OS", sysinfo), addQuotes = 1)
	tmpstr = addJSONkeyval(tmpstr, "IGOR_VERSION", StringByKey("IGORFILEVERSION", sysinfo), addQuotes = 1)
	configstr = addJSONkeyval(configstr, "system_info", tmpstr)

	// log instrument info
	configstr = addJSONkeyval(configstr, "instruments", textWave2StrArray(sc_Instr))

	// wave names
	tmpstr = ""
	tmpstr = addJSONkeyval(tmpstr, "raw", textWave2StrArray(sc_RawWaveNames))
	tmpstr = addJSONkeyval(tmpstr, "calc", textWave2StrArray(sc_CalcWaveNames))
	configstr = addJSONkeyval(configstr, "wave_names", tmpstr)

	// record checkboxes
	tmpstr = ""
	tmpstr = addJSONkeyval(tmpstr, "raw", wave2BoolArray(sc_RawRecord))
	tmpstr = addJSONkeyval(tmpstr, "calc", wave2BoolArray(sc_CalcRecord))
	configstr = addJSONkeyval(configstr, "record_waves", tmpstr)

	// plot checkboxes
	tmpstr = ""
	tmpstr = addJSONkeyval(tmpstr, "raw",  wave2BoolArray(sc_RawPlot))
	tmpstr = addJSONkeyval(tmpstr, "calc",  wave2BoolArray(sc_CalcPlot))
	configstr = addJSONkeyval(configstr, "plot_waves", tmpstr)

	// async checkboxes
	configstr = addJSONkeyval(configstr, "meas_async", wave2BoolArray(sc_measAsync))

	// scripts
	tmpstr = ""
	tmpstr = addJSONkeyval(tmpstr, "raw", textWave2StrArray(sc_RawScripts))
	tmpstr = addJSONkeyval(tmpstr, "calc", textWave2StrArray(sc_CalcScripts))
	configstr = addJSONkeyval(configstr, "scripts", tmpstr)

	// print_to_history
	tmpstr = ""
	tmpstr = addJSONkeyval(tmpstr, "raw", num2bool(sc_PrintRaw))
	tmpstr = addJSONkeyval(tmpstr, "calc", num2bool(sc_PrintCalc))
	configstr = addJSONkeyval(configstr, "print_to_history", tmpstr)

	configstr = addJSONkeyval(configstr, "filenum", num2istr(filenum))

	return configstr

end

function sc_saveConfig(configstr)
	string configstr
	svar sc_current_config

	string filename = "sc" + num2istr(unixtime()) + ".json"
	writetofile(prettyJSONfmt(configstr), filename, "config")
	sc_current_config = filename
end

function sc_loadConfig(configfile)
	string configfile
	string jstr
	nvar sc_PrintRaw, sc_PrintCalc
	svar sc_current_config

	// load JSON string from config file
	printf "Loading configuration from: %s\n", configfile
	sc_current_config = configfile
	jstr = readtxtfile(configfile,"config")

	// instruments
	loadStrArray2textWave(getJSONvalue(jstr, "instruments"), "sc_Instr")

	// waves
	loadStrArray2textWave(getJSONvalue(jstr,"wave_names:raw"),"sc_RawWaveNames")
	loadStrArray2textWave(getJSONvalue(jstr,"wave_names:calc"),"sc_CalcWaveNames")

	// record checkboxes
	loadBoolArray2wave(getJSONvalue(jstr,"record_waves:raw"),"sc_RawRecord")
	loadBoolArray2wave(getJSONvalue(jstr,"record_waves:calc"),"sc_CalcRecord")

	// plot checkboxes
	loadBoolArray2wave(getJSONvalue(jstr,"plot_waves:raw"),"sc_RawPlot")
	loadBoolArray2wave(getJSONvalue(jstr,"plot_waves:calc"),"sc_CalcPlot")

	// async checkboxes
	loadBoolArray2wave(getJSONvalue(jstr,"meas_async"),"sc_measAsync")

	// print_to_history
	loadBool2var(getJSONvalue(jstr,"print_to_history:raw"),"sc_PrintRaw")
	loadBool2var(getJSONvalue(jstr,"print_to_history:calc"),"sc_PrintCalc")

	// scripts
	loadStrArray2textWave(getJSONvalue(jstr,"scripts:raw"),"sc_RawScripts")
	loadStrArray2textWave(getJSONvalue(jstr,"scripts:calc"),"sc_CalcScripts")

	//filenum
	loadNum2var(getJSONvalue(jstr,"filenum"),"sc_filenum")

	// reload ScanController window
	sc_rebuildwindow()
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

	if (numpnts(sc_RawWaveNames) != numpnts(sc_RawRecord) ||  numpnts(sc_RawWaveNames) != numpnts(sc_RawScripts))
		print "sc_RawWaveNames, sc_RawRecord, and sc_RawScripts waves should have the number of elements.\nGo to the beginning of InitScanController() to fix this.\n"
		abort
	endif

	if (numpnts(sc_CalcWaveNames) != numpnts(sc_CalcRecord) ||  numpnts(sc_CalcWaveNames) != numpnts(sc_CalcScripts))
		print "sc_CalcWaveNames, sc_CalcRecord, and sc_CalcScripts waves should have the number of elements.\n  Go to the beginning of InitScanController() to fix this.\n"
		abort
	endif

	PauseUpdate; Silent 1		// building window...
	dowindow /K ScanController
	NewPanel /W=(10,10,sc_InnerBoxW + 30,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+3)*(sc_InnerBoxH+sc_InnerBoxSpacing)+90) /N=ScanController
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
	DrawText 250,29,"Async"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 320,29,"Raw Script (ex: ReadSRSx(srs1)"

	string cmd = ""
	variable i=0
	do
		DrawRect 9,30+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing),5+sc_InnerBoxW,30+sc_InnerBoxH+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)
		cmd="SetVariable sc_RawWaveNameBox" + num2istr(i) + " pos={13, 37+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={110, 0}, fsize=14, title=\" \", value=sc_RawWaveNames[i]"
		execute(cmd)
		cmd="CheckBox sc_RawRecordCheckBox" + num2istr(i) + ", proc=sc_CheckBoxClicked, pos={150,40+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_RawRecord[i]) + " , title=\"\""
		execute(cmd)
		cmd="CheckBox sc_RawPlotCheckBox" + num2istr(i) + ", proc=sc_CheckBoxClicked, pos={210,40+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_RawPlot[i]) + " , title=\"\""
		execute(cmd)
		cmd="CheckBox sc_AsyncCheckBox" + num2istr(i) + ", proc=sc_CheckBoxClicked, pos={270,40+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_measAsync[i]) + " , title=\"\""
		execute(cmd)
		cmd="SetVariable sc_rawScriptBox" + num2istr(i) + " pos={320, 37+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={340, 0}, fsize=14, title=\" \", value=sc_rawScripts[i]"
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
	DrawText 320,i*(sc_InnerBoxH + sc_InnerBoxSpacing)+50,"Calc Script (ex: dmm[i]*1.5)"

	i=0
	do
		DrawRect 9,85+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing),5+sc_InnerBoxW,85+sc_InnerBoxH+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)
		cmd="SetVariable sc_CalcWaveNameBox" + num2istr(i) + " pos={13, 92+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={110, 0}, fsize=14, title=\" \", value=sc_CalcWaveNames[i]"
		execute(cmd)
		cmd="CheckBox sc_CalcRecordCheckBox" + num2istr(i) + ", proc=sc_CheckBoxClicked, pos={150,95+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_CalcRecord[i]) + " , title=\"\""
		execute(cmd)
		cmd="CheckBox sc_CalcPlotCheckBox" + num2istr(i) + ", proc=sc_CheckBoxClicked, pos={210,95+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_CalcPlot[i]) + " , title=\"\""
		execute(cmd)
		cmd="SetVariable sc_CalcScriptBox" + num2istr(i) + " pos={320, 92+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={340, 0}, fsize=14, title=\" \", value=sc_CalcScripts[i]"
		execute(cmd)
		i+=1
	while (i<numpnts( sc_CalcWaveNames ))
	button addrowcalc,pos={550,89+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)},size={110,20},proc=sc_addrow,title="Add Row"
	button removerowcalc,pos={430,89+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)},size={110,20},proc=sc_removerow,title="Remove Row"
	checkbox sc_PrintCalcBox, pos={300,89+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)}, proc=sc_CheckBoxClicked, value=sc_PrintCalc,side=1,title="\Z14Print filenames"

	// box for instrument configuration
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 13,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+20,"Connect Instrument"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 225,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+20,"Open GUI"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 440,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+20,"Log Status"
	ListBox sc_Instr,pos={9,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+25},size={sc_InnerBoxW,(sc_InnerBoxH+sc_InnerBoxSpacing)*3},fsize=14,frame=2,listWave=root:sc_Instr,selWave=root:instrBoxAttr,mode=1, editStyle=1

	// buttons
	button connect, pos={10,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+3)*(sc_InnerBoxH+sc_InnerBoxSpacing)+30},size={120,20},proc=sc_OpenInstrButton,title="Connect Instr"
	button gui, pos={140,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+3)*(sc_InnerBoxH+sc_InnerBoxSpacing)+30},size={120,20},proc=sc_OpenGUIButton,title="Open All GUI"
	button killabout, pos={270,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+3)*(sc_InnerBoxH+sc_InnerBoxSpacing)+30},size={140,20},proc=sc_controlwindows,title="Kill Sweep Controls"
	button killgraphs, pos={420,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+3)*(sc_InnerBoxH+sc_InnerBoxSpacing)+30},size={120,20},proc=sc_killgraphs,title="Close All Graphs"
	button updatebutton, pos={550,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+3)*(sc_InnerBoxH+sc_InnerBoxSpacing)+30},size={110,20},proc=sc_updatewindow,title="Update"

// helpful text
	DrawText 13,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+3)*(sc_InnerBoxH+sc_InnerBoxSpacing)+70,"Press Update to save changes."

EndMacro

function sc_OpenInstrButton(action) : Buttoncontrol
	string action
	sc_openInstrConnections(1)
end

function sc_OpenGUIButton(action) : Buttoncontrol
	string action
	sc_openInstrGUIs(1)
end

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

	sc_saveConfig(sc_createconfig())   // write a new config file

end

function sc_addrow(action) : ButtonControl
	string action
	wave/t sc_RawWaveNames=sc_RawWaveNames
	wave sc_RawRecord=sc_RawRecord
	wave sc_RawPlot=sc_RawPlot
	wave sc_measAsync=sc_measAsync
	wave/t sc_RawScripts=sc_RawScripts
	wave/t sc_CalcWaveNames=sc_CalcWaveNames
	wave sc_CalcRecord=sc_CalcRecord
	wave sc_CalcPlot=sc_CalcPlot
	wave/t sc_CalcScripts=sc_CalcScripts

	strswitch(action)
		case "addrowraw":
			AppendString(sc_RawWaveNames, "")
			AppendValue(sc_RawRecord, 0)
			AppendValue(sc_RawPlot, 0)
			AppendValue(sc_measAsync, 0)
			AppendString(sc_RawScripts, "")
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
	wave sc_measAsync=sc_measAsync
	wave/t sc_RawScripts=sc_RawScripts
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
				Redimension /N=(numpnts(sc_measAsync)-1) sc_measAsync
				Redimension /N=(numpnts(sc_RawScripts)-1) sc_RawScripts
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
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot, sc_measAsync
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
	elseif (stringmatch(ControlName,"sc_AsyncCheckBox*"))
		expr="sc_AsyncCheckBox([[:digit:]]+)"
		SplitString/E=(expr) controlname, indexstring
		index = str2num(indexstring)
		sc_measAsync[index] = value
	elseif(stringmatch(ControlName,"sc_PrintRawBox"))
		sc_PrintRaw = value
	elseif(stringmatch(ControlName,"sc_PrintCalcBox"))
		sc_PrintCalc = value
	endif
end

////////////////////////
/// Initialize Waves ///
////////////////////////

function sc_checkAsyncScript(str)
	// returns -1 if formatting is bad
	// could be better
	// returns position of first ( character if it is good
	string str

	variable i = 0, firstOP = 0, countOP = 0, countCP = 0
	for(i=0; i<strlen(str); i+=1)

		if( CmpStr(str[i], "(") == 0 )
			countOP+=1 // count opening parentheses
			if( firstOP==0 )
				firstOP = i // record position of first (
				continue
			endif
		endif

		if( CmpStr(str[i], ")") == 0 )
			countCP -=1 // count closing parentheses
			continue
		endif

		if( CmpStr(str[i], ",") == 0 )
			return -1 // stop on comma
		endif

	endfor

	if( (countOP==1) && (countCP==-1) )
		return firstOP
	else
		return -1
	endif
end

function sc_findAsyncMeasurements()
	// go through RawScripts and look for valid async measurements
	//    wherever the meas_async box is checked in the window
	nvar sc_is2d
	wave /t sc_RawScripts, sc_RawWaveNames
	wave sc_RawRecord, sc_RawPlot, sc_measAsync

	// setup async folder
	killdatafolder /z root:async // kill it if it exists
	newdatafolder root:async // create an empty version

	variable i = 0, idx = 0, measIdx=0, instrAsync=0
	string script, strID, queryFunc, threadFolder
	string /g sc_asyncFolders = ""
	make /o/n=1 /WAVE sc_asyncRefs


	for(i=0;i<numpnts(sc_RawScripts);i+=1)

		if ( (sc_RawRecord[i] == 1) || (sc_RawPlot[i] == 1) )
			// this is something that will be measured

			if (sc_measAsync[i] == 1) // this is something that should be async

				script = sc_RawScripts[i]
				idx = sc_checkAsyncScript(script) // check function format

				if(idx!=-1) // fucntion is good, this will be recorded asynchronously

					// keep track of function names and instrIDs in folder structure
					strID = script[idx+1,strlen(script)-2]
					queryFunc = script[0,idx-1]

					// creates root:async:instr1
					sprintf threadFolder, "thread_%s", strID
					if(DataFolderExists("root:async:"+threadFolder))
						// add measurements to the thread directory for this instrument

						svar qF = root:async:$(threadFolder):queryFunc
						qF += ";"+queryFunc
						svar wI = root:async:$(threadFolder):wavIdx
						wI += ";" + num2str(measIdx)
					else
						instrAsync += 1

						// create a new thread directory for this instrument
						newdatafolder root:async:$(threadFolder)
						nvar instrID = $strID
						variable /g root:async:$(threadFolder):instrID = instrID   // creates variable instrID in root:thread
																	                          // that has the same value as $strID
						string /g root:async:$(threadFolder):wavIdx = num2str(measIdx)
						string /g root:async:$(threadFolder):queryFunc = queryFunc // creates string variable queryFunc in root:async:thread
																                             // that has a value queryFunc="readInstr"
						sc_asyncFolders += threadFolder + ";"



					endif

					// fill wave reference(s)
					redimension /n=(2*measIdx+2) sc_asyncRefs
					wave w=$sc_rawWaveNames[i] // 1d wave
					sc_asyncRefs[2*measIdx] = w
					if(sc_is2d)
						wave w2d=$(sc_rawWaveNames[i]+"2d") // 2d wave
						sc_asyncRefs[2*measIdx+1] = w2d
					endif
					measIdx+=1

				else
					// measurement script is formatted wrong
					sc_measAsync[i]=0
					printf "[WARNING] Async scripts must be formatted: \"readFunc(instrID)\"\r\t%s is no good and will be read synchronously,\r", sc_RawScripts[i]
				endif

			endif
		endif

	endfor

	if(instrAsync<2)
		// no point in doing anyting async is only one instrument is capable of it
		// will uncheck boxes automatically
		make /o/n=(numpnts(sc_RawScripts)) sc_measAsync = 0
	endif

	// change state of check boxes based on what just happened here!
	doupdate /W=ScanController
	string cmd = ""
	for(i=0;i<numpnts(sc_measAsync);i+=1)
		sprintf cmd, "CheckBox sc_AsyncCheckBox%d,win=ScanController,value=%d", i, sc_measAsync[i]
		execute(cmd)
	endfor
	doupdate /W=ScanController

	if(sum(sc_measAsync)==0)
		sc_asyncFolders = ""
		KillDataFolder /Z root:async // don't need this
		return 0
	else
		variable /g sc_numInstrThreads = ItemsInList(sc_asyncFolders, ";")
		variable /g sc_numAvailThreads = threadProcessorCount
		return sc_numInstrThreads
	endif

end

function InitializeWaves(start, fin, numpts, [starty, finy, numptsy, x_label, y_label, linecut]) //linecut = 0,1 for false, true
	variable start, fin, numpts, starty, finy, numptsy, linecut
	string x_label, y_label
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	wave /T sc_RawWaveNames, sc_CalcWaveNames, sc_RawScripts, sc_CalcScripts
	variable i=0, j=0
	string cmd = "", wn = "", wn2d="", s, script = "", script0 = "", script1 = ""
	string /g sc_x_label, sc_y_label
	variable /g sc_is2d, sc_scanstarttime = datetime
	variable /g sc_startx, sc_finx, sc_numptsx, sc_starty, sc_finy, sc_numptsy
	variable/g sc_abortsweep=0, sc_pause=0, sc_abortnosave=0
	string graphlist, graphname, plottitle, graphtitle="", graphnumlist="", graphnum, activegraphs="", cmd1="",window_string=""
	string cmd2=""
	variable index, graphopen, graphopen2d
	svar sc_colormap

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

	// because VISA tends to drop connections when the
	// measurement computer is left idle
	// we may want to add a function here to setup all the instruments
	sc_OpenInstrConnections(0)

	// The status of the upcoming scan will be set when waves are initialized.
	if(!paramisdefault(starty) && !paramisdefault(finy) && !paramisdefault(numptsy))
		sc_is2d = 1
		sc_startx = start
		sc_finx = fin
		sc_numptsx = numpts
		sc_starty = starty
		sc_finy = finy
		sc_numptsy = numptsy
		if(start==fin || starty==finy)
			print "[WARNING]: Your start and end values are the same!"
		endif
	else
		sc_is2d = 0
		sc_startx = start
		sc_finx = fin
		sc_numptsx = numpts
		if(start==fin)
			print "[WARNING]: Your start and end values are the same!"
		endif
	endif
	if(linecut == 1) //Tim:To make linecuts work with RecordValues
		sc_is2d = 2
		make/O/n=(numptsy) sc_linestart = NaN 						//To store first xvalue of each line of data
		cmd = "setscale/I x " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + "sc_linestart"; execute(cmd)
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

	// create waves to hold x and y data (in case I want to save it)
	// this is pretty useless if using readvstime
	cmd = "make /o/n=(" + num2istr(sc_numptsx) + ") " + "sc_xdata" + "=NaN"; execute(cmd)
	cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + "sc_xdata"; execute(cmd)
	cmd = "sc_xdata" +" = x"; execute(cmd)
	if(sc_is2d != 0)
		cmd = "make /o/n=(" + num2istr(sc_numptsy) + ") " + "sc_ydata" + "=NaN"; execute(cmd)
		cmd = "setscale/I x " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", \"\", " + "sc_ydata"; execute(cmd)
		cmd = "sc_ydata" +" = x"; execute(cmd)
	endif

	// Initialize waves for raw data
	do
		if (sc_RawRecord[i] == 1 && cmpstr(sc_RawWaveNames[i], "") || sc_RawPlot[i] == 1 && cmpstr(sc_RawWaveNames[i], ""))
			wn = sc_RawWaveNames[i]
			cmd = "make /o/n=(" + num2istr(sc_numptsx) + ") " + wn + "=NaN"
			execute(cmd)
			cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + wn
			execute(cmd)
			if(sc_is2d == 1)
				// In case this is a 2D measurement
				wn2d = wn + "2d"
				cmd = "make /o/n=(" + num2istr(sc_numptsx) + ", " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd)
				cmd = "setscale /i x, " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", " + wn2d; execute(cmd)
				cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)
			elseif(sc_is2d ==2)
				// In case this is a 2D line cut measurement
				wn2d = sc_RawWaveNames[i]+"2d"
				cmd = "make /o/n=(1, " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd) //Makes 1 by y wave, x is redimensioned in recordline
				cmd = "setscale /P x, 0, " + num2str((sc_finx-sc_startx)/sc_numptsx) + "," + wn2d; execute(cmd) //sets x scale starting from 0 but with delta correct	
				cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)//Useful to see if top and bottom of scan are filled with NaNs
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
			if(sc_is2d == 1)
				// In case this is a 2D measurement
				wn2d = wn + "2d"
				cmd = "make /o/n=(" + num2istr(sc_numptsx) + ", " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd)
				cmd = "setscale /i x, " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", " + wn2d; execute(cmd)
				cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)
			elseif(sc_is2d == 2)
				// In case this is a 2D line cut measurement
				wn2d = sc_CalcWaveNames[i]+"2d"
				cmd = "make /o/n=(1, " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd) //Same as for Raw (see above)	
				cmd = "setscale /P x, 0, " + num2str((sc_finx-sc_startx)/sc_numptsx) + "," + wn2d; execute(cmd) //sets x scale starting from 0 but with delta correct		
				cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)
			endif
		endif
		i+=1
	while (i<numpnts(sc_CalcWaveNames))

	sc_findAsyncMeasurements()

	// Find all open plots
	graphlist = winlist("*",";","WIN:1")
	j=0				
	for (i=0;i<itemsinlist(graphlist);i=i+1) 
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
				setwindow kwTopWin, enablehiresdraw=3
				Label bottom, sc_x_label
				activegraphs+= winname(0,1)+";"
			elseif(graphopen)
				if(sc_is2d)
					wn2d = wn + "2d"
					display
					setwindow kwTopWin, enablehiresdraw=3
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
				setwindow kwTopWin, enablehiresdraw=3
				Label bottom, sc_x_label
				activegraphs+= winname(0,1)+";"
				if(sc_is2d)
					display
					setwindow kwTopWin, enablehiresdraw=3
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
				setwindow kwTopWin, enablehiresdraw=3
				Label bottom, sc_x_label
				activegraphs+= winname(0,1)+";"
			elseif(graphopen)
				if(sc_is2d)
					wn2d = wn + "2d"
					display
					setwindow kwTopWin, enablehiresdraw=3
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
				setwindow kwTopWin, enablehiresdraw=3
				Label bottom, sc_x_label
				activegraphs+= winname(0,1)+";"
				if(sc_is2d)
					display
					setwindow kwTopWin, enablehiresdraw=3
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
	cmd2 = ""
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
	NewPanel /W=(500,700,870,750) /N=SweepControl// window size
	ModifyPanel frameStyle=2
	ModifyPanel fixedSize=1
	SetDrawLayer UserBack
	Button pausesweep, pos={10,15},size={110,20},proc=pausesweep,title="Pause"
	Button stopsweep, pos={130,15},size={110,20},proc=stopsweep,title="Abort and Save"
	Button stopsweepnosave, pos={250,15},size={110,20},proc=stopsweep,title="Abort"
	DoUpdate /W=SweepControl /E=1
endmacro

function stopsweep(action) : Buttoncontrol
	string action
	nvar sc_abortsweep,sc_abortnosave

	strswitch(action)
		case "stopsweep":
			sc_abortsweep = 1
			break
		case "stopsweepnosave":
			sc_abortnosave = 1
			break
	endswitch
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
	nvar /Z sc_abortsweep, sc_pause, sc_abortnosave

	if(NVAR_Exists(sc_abortsweep) && sc_abortsweep==1)
		// If the Abort button is pressed during the scan, save existing data and stop the scan.
		SaveWaves(msg="The scan was aborted during the execution.", save_experiment=0)
		dowindow /k SweepControl
		sc_abortsweep=0
		sc_abortnosave=0
		sc_pause=0
		abort "Measurement aborted by user. Data saved automatically."
	elseif(NVAR_Exists(sc_abortnosave) && sc_abortnosave==1)
		// Abort measurement without saving anything!
		dowindow /k SweepControl
		sc_abortnosave = 0
		sc_abortsweep = 0
		sc_pause=0
		abort "Measurement aborted by user. Data not saved automatically. Run \"SaveWaves()\" if needed"
	elseif(NVAR_Exists(sc_pause) && sc_pause==1)
		// Pause sweep if button is pressed
		do
			if(sc_abortsweep)
				SaveWaves(msg="The scan was aborted during the execution.", save_experiment=0)
				dowindow /k SweepControl
				sc_abortsweep=0
				sc_abortnosave=0
				sc_pause=0
				abort "Measurement aborted by user"
			elseif(sc_abortnosave)
				dowindow /k SweepControl
				sc_abortsweep=0
				sc_abortnosave=0
				sc_pause=0
				abort "Measurement aborted by user. Data NOT saved!"
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

threadsafe function sc_sleep_noupdate(delay)
	// sleep for delay seconds
	variable delay
	delay = delay*1e6 // convert to microseconds
	variable start_time = stopMStimer(-2) // start the timer immediately

	do
		sleep /s 0.002
	while(stopMStimer(-2)-start_time < delay)

end

/////////////////////////////
////  read/record funcs  ////
/////////////////////////////
function RecordValues(i, j, [readvstime, fillnan])
	// In a 1d scan, i is the index of the loop. j will be ignored.
	// In a 2d scan, i is the index of the outer (slow) loop, and j is the index of the inner (fast) loop.

	// readvstime works only in 1d and rescales (grows) the wave at each index

	// fillnan=1 skips any read or calculation functions entirely and fills point [i,j] with nan

	variable i, j, readvstime, fillnan
	nvar sc_is2d, sc_startx, sc_finx, sc_numptsx, sc_starty, sc_finy, sc_numptsy
	wave/t sc_RawWaveNames, sc_RawScripts, sc_CalcWaveNames, sc_CalcScripts
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	nvar sc_abortsweep, sc_pause, sc_scanstarttime
	variable ii = 0

	//// setup all sorts of logic so we can store values correctly ////

	variable innerindex, outerindex
	if (sc_is2d == 1 || sc_is2d == 2) //1 is normal 2D, 2 is Line2D
		// 2d
		innerindex = j
		outerindex = i
	else
		// 1d
		innerindex = i
		outerindex = i // meaningless
	endif

	// Set readvstime to 0 if it's not defined
	if(paramisdefault(readvstime))
		readvstime=0
	endif

	if(innerindex==0 && outerindex==0)
		variable/g sc_rvt = readvstime // needed for rescaling in SaveWaves()
	endif

	if(readvstime==1 && sc_is2d)
		abort "NOT IMPLEMENTED: Read vs Time is currently only supported for 1D sweeps."
	endif

	//// fill NaNs? ////

	if(paramisdefault(fillnan))
		fillnan = 0 // defaults to 0
	elseif(fillnan==1)
		fillnan = 1 // again, obvious
	else
		fillnan=0   // if something other than 1
					//     assume default
	endif

	//// Setup and run async data collection ////
	wave sc_measAsync
	if( (sum(sc_measAsync) > 1) && (fillnan==0) && (sc_is2d != 2)) //Tim:TODO: Make async work for Line cut
		variable tgID = sc_ManageThreads(innerindex, outerindex, readvstime) // start threads, wait, collect data
		sc_KillThreads(tgID) // Terminate threads
	endif

	//// Read sync data ( or fill NaN) ////
	variable /g sc_tmpVal
	variable dx			//For 2Dline
	wave sc_linestart, sc_xdata 	//For 2Dline  
	string script = "", cmd = ""
	ii=0
	do
		if ((sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1) && sc_measAsync[ii]==0)
			wave wref1d = $sc_RawWaveNames[ii]

			// Redimension waves if readvstime is set to 1
			if (readvstime == 1)
				redimension /n=(innerindex+1) wref1d
				setscale/I x 0,  datetime - sc_scanstarttime, wref1d
			endif

			if(fillnan == 0)
				script = TrimString(sc_RawScripts[ii])
				sprintf cmd, "%s = %s", "sc_tmpVal", script
				Execute/Q/Z cmd
				if(V_flag!=0)
					print "[ERROR] in RecordValues (raw): "+GetErrMessage(V_Flag,2)
				endif
			else
				sc_tmpval = NaN
			endif
			wref1d[innerindex] = sc_tmpval

			if (sc_is2d == 1)
				// 2D Wave
				wave wref2d = $sc_RawWaveNames[ii] + "2d"
				wref2d[innerindex][outerindex] = wref1d[innerindex]
			elseif (sc_is2d == 2 && fillnan == 0)
				//2D line wave
				FindValue/V=0/T=(inf) wref1D 	//Finds the first non NaN and stores position in V_value (V=value, T=tolerance)
				if(innerindex == V_value)		//records the x value of the first notNaN for all line2D graphs  
					sc_linestart[outerindex] = sc_xdata[innerindex]
				endif
				wave wref2d = $sc_RawWaveNames[ii] + "2d"
				if(dimsize(wref2d, 0)-1 < innerindex-V_value) //Does 2D line wave need larger x range?
					dx = dimdelta(wref2d, 0) 																//saves delta x of original to put back in
					make/o/n=(dimsize(wref2d,0)+1, dimsize(wref2d,1)) temp2Dwave = NaN 			//Make new larger wave 	
					temp2Dwave[0,dimsize(wref2d,0)-1][0,dimsize(wref2d,1)-1] = wref2d[p][q] 	//copy over old values with NaNs everywhere else
					duplicate/O temp2Dwave wref2d															//Put back into old wave
					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + nameofwave(wref2d); execute(cmd) //Sets Y scale again
					cmd = "setscale /P x, 0, " + num2str(dx) + ", " + nameofwave(wref2d); execute(cmd) //Sets x scale again (starts at 0 but with correct delta)
					killwaves temp2Dwave																	//Clear mess
				endif	
				wref2d[innerindex-(V_value)][outerindex] = wref1d[innerindex] 	//Using V_value from FindValue a few lines up
			endif
			
		endif
		ii+=1
	while (ii < numpnts(sc_RawWaveNames))

	//// Calculate interpreted numbers and store them in calculated waves ////
	ii=0
	cmd = ""
	do
		if ( (sc_CalcRecord[ii] == 1) || (sc_CalcPlot[ii] == 1) )
			wave wref1d = $sc_CalcWaveNames[ii] // this is the 1D wave I am filling

			// Redimension waves if readvstimeis set to 1
			if (readvstime == 1)
				redimension /n=(innerindex+1) wref1d
				setscale/I x 0, datetime - sc_scanstarttime, wref1d
			endif

			if(fillnan == 0)
				script = TrimString(sc_CalcScripts[ii])
				// Allow the use of the keyword '[i]' in calculated fields where i is the inner loop's current index
				script = ReplaceString("[i]", script, "["+num2istr(innerindex)+"]")
				sprintf cmd, "%s = %s", "sc_tmpVal", script
				Execute/Q/Z cmd
				if(V_flag!=0)
					print "[ERROR] in RecordValues (calc): "+GetErrMessage(V_Flag,2)
				endif
			elseif(fillnan == 1)
				sc_tmpval = NaN
			endif
			wref1d[innerindex] = sc_tmpval

			if (sc_is2d == 1)
				wave wref2d = $sc_CalcWaveNames[ii] + "2d"
				wref2d[innerindex][outerindex] = wref1d[innerindex]
			elseif (sc_is2d == 2 && fillnan == 0)
				//2D line wave
				FindValue/V=0/T=(inf) wref1D 	//Finds the first non NaN and stores position in V_value (V=value, T=tolerance)
				
				if(innerindex == V_value)		//records the x value of the first notNaN for all line2D graphs  
					sc_linestart[outerindex] = sc_xdata[innerindex]
				endif
				wave wref2d = $sc_CalcWaveNames[ii] + "2d"
				if(dimsize(wref2d, 0)-1 < innerindex-V_value && v_value != -1) //Does 2D line wave need larger x range?
					dx = dimdelta(wref2d, 0)
					make/o/n=(dimsize(wref2d,0)+1, dimsize(wref2d,1)) temp2Dwave = NaN 			//Make new larger wave 	
					temp2Dwave[0,dimsize(wref2d,0)-1][0,dimsize(wref2d,1)-1] = wref2d[p][q] 	//copy over old values with NaNs everywhere else
					duplicate/O temp2Dwave wref2d															//Put back into old wave
					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + nameofwave(wref2d); execute(cmd) //Sets Y scale again
					cmd = "setscale /P x, 0, " + num2str(dx) + ", " + nameofwave(wref2d); execute(cmd) //Sets x scale again (starts at 0 but with correct delta)
					killwaves temp2Dwave																	//Clear mess
				endif
				if (v_value != -1 && V_value < innerindex) //don't fill a NaN or if V_value is actually from previous line of data (because it will try index out of range)
					wref2d[innerindex-(V_value)][outerindex] = wref1d[innerindex] 	//Using V_value from FindValue a few lines up 	
				endif
			endif
		endif
		ii+=1
	while (ii < numpnts(sc_CalcWaveNames))

	// check abort/pause status
	sc_checksweepstate()
end

///////////////////////
/// ASYNC handling ///
//////////////////////

function sc_ManageThreads(innerIndex, outerIndex, readvstime)
	variable innerIndex, outerIndex, readvstime
	svar sc_asyncFolders
	nvar sc_is2d, sc_scanstarttime, sc_numAvailThreads, sc_numInstrThreads
	wave /WAVE sc_asyncRefs

	variable tgID = ThreadGroupCreate(min(sc_numInstrThreads, sc_numAvailThreads)) // open threads

	variable i=0, idx=0, measIndex=0, threadIndex = 0
	string script, queryFunc, strID, threadFolder

	// start new thread for each thread_* folder in data folder structure
	for(i=0;i<sc_numInstrThreads;i+=1)

		do
			threadIndex = ThreadGroupWait(tgID, -2) // relying on this to keep track of index
		while(threadIndex<1)

		duplicatedatafolder root:async, root:asyncCopy //duplicate async folder
		ThreadGroupPutDF tgID, root:asyncCopy // move root:asyncCopy to where threadGroup can access it
											           // effectively kills root:asyncCopy in main thread

		// start thread
		threadstart tgID, threadIndex-1, sc_Worker(sc_asyncRefs, innerindex, outerindex, \
																 StringFromList(i, sc_asyncFolders, ";"), sc_is2d, \
																 readvstime, sc_scanstarttime)

	endfor

	// wait for all threads to finish and get the rest of the data
	do
		threadIndex = ThreadGroupWait(tgID, 0)
		sleep /s 0.001
	while(threadIndex!=0)

	return tgID
end

threadsafe function sc_Worker(refWave, innerindex, outerindex, folderIndex, is2d, rvt, starttime)
	wave /WAVE refWave
	variable innerindex, outerindex, is2d, rvt, starttime
	string folderIndex

	do
		DFREF dfr = ThreadGroupGetDFR(0,0)	// Get free data folder from input queue
		if (DataFolderRefStatus(dfr) == 0)
			continue
		else
			break
		endif
	while(1)

	setdatafolder dfr:$(folderIndex)

	nvar /z instrID = instrID
	svar /z queryFunc = queryFunc
	svar /z wavIdx = wavIdx

	if(nvar_exists(instrID) && svar_exists(queryFunc) && svar_exists(wavIdx))

		variable i, val
		for(i=0;i<ItemsInList(queryFunc, ";");i+=1)

			// do the measurements
			funcref funcAsync func = $(StringFromList(i, queryFunc, ";"))
			val = func(instrID)

			if(numtype(val)==2)
				// if NaN was returned, try the next function
				continue
			endif

			wave wref1d = refWave[2*str2num(StringFromList(i, wavIdx, ";"))]

			if(rvt == 1)
				redimension /n=(innerindex+1) wref1d
				setscale/I x 0, datetime - starttime, wref1d
			endif

			wref1d[innerindex] = val

			if(is2d)
				wave wref2d = refWave[2*str2num(StringFromList(i, wavIdx, ";"))+1]
				wref2d[innerindex][outerindex] = val
			endif

		endfor

		return i
	else
		// if no instrID/queryFunc/wavIdx exists, get out
		return NaN
	endif

end

threadsafe function funcAsync(instrID)  // Reference functions for all *_async functions
	variable instrID                    // instrID used as only input to async functions
end

function sc_KillThreads(tgID)
	variable tgID
	variable releaseResult

	releaseResult = ThreadGroupRelease(tgID)
	if (releaseResult == -2)
		abort "ThreadGroupRelease failed, threads were force quit. Igor should be restarted!"
	elseif(releaseResult == -1)
		printf "ThreadGroupRelease failed. No fatal errors, will continue.\r"
	endif

end

////////////////////////
////  save all data ////
////////////////////////

function /s sc_createSweepLogs([msg])
	string msg
	string jstr = "", buffer = ""
	nvar filenum, sweep_t_elapsed
	svar sc_current_config, sc_hostname, sc_x_label, sc_y_label

	// information about this specific sweep
	if(!paramisdefault(msg))
		jstr = addJSONkeyval(jstr, "comment", msg, addQuotes=1)
	endif
	jstr = addJSONkeyval(jstr, "filenum", num2istr(filenum))
	
	buffer = addJSONkeyval(buffer, "x", sc_x_label, addQuotes=1)
	buffer = addJSONkeyval(buffer, "y", sc_y_label, addQuotes=1)
	jstr = addJSONkeyval(jstr, "axis_labels", buffer)
	
	jstr = addJSONkeyval(jstr, "current_config", sc_current_config, addQuotes = 1)
	jstr = addJSONkeyval(jstr, "time_completed", Secs2Date(DateTime, 1)+" "+Secs2Time(DateTime, 3), addQuotes = 1)
	jstr = addJSONkeyval(jstr, "time_elapsed", num2numStr(sweep_t_elapsed))

	// instrument logs
	// all log strings should be valid JSON objects
	wave /t sc_Instr
	variable i=0, j=0, addQuotes=0
	string command="", val=""
	string /G sc_log_buffer=""
	for(i=0;i<DimSize(sc_Instr, 0);i+=1)
		sc_log_buffer=""
		command = TrimString(sc_Instr[i][2])
		if(strlen(command)>0)
			Execute/Q/Z "sc_log_buffer="+command
			if(V_flag!=0)
				print "[ERROR] in sc_createSweepLogs: "+GetErrMessage(V_Flag,2)
			endif
			if(strlen(sc_log_buffer)!=0)
				// need to get first key and value from sc_log_buffer
				JSONSimple sc_log_buffer
				wave/t t_tokentext
				wave w_tokentype, w_tokensize, w_tokenparent
	
				for(j=1;j<numpnts(t_tokentext)-1;j+=1)
					if ( w_tokentype[j]==3 && w_tokensize[j]>0 )
						if( w_tokenparent[j]==0 )
							if( w_tokentype[j+1]==3 )
								val = "\"" + t_tokentext[j+1] + "\""
							else
								val = t_tokentext[j+1]
							endif
							jstr = addJSONkeyval(jstr, t_tokentext[j], val)
							break
						endif
					endif
				endfor
				
			else
				print "[WARNING] command failed to log anything: "+command+"\r"
			endif
		endif
	endfor

	return jstr
end

function saveExp()
	SaveExperiment /P=data // save current experiment as .pxp
	SaveFromPXP(history=1, procedure=1) // grab some useful plain text docs from the pxp
end

function sc_update_xdata()
    // update the sc_xdata wave
    // to match the measured waves

	wave sc_xdata, sc_RawRecord, sc_RawPlot
	wave /t sc_RawWaveNames

	// look for the first wave that has recorded values
	string wn = ""
	variable i=0
	for(i=0; i<numpnts(sc_RawWaveNames); i+=1)
	    if (sc_RawRecord[i] == 1 || sc_RawPlot[i]==1)
	        wn = sc_RawWaveNames[i]
	        break
	    endif
	endfor

	if(strlen(wn)==0)
		wave sc_xdata, sc_CalcRecord, sc_CalcPlot
		wave /t sc_CalcWaveNames

		for(i=0; i<numpnts(sc_CalcWaveNames); i+=1)
		    if (sc_CalcRecord[i] == 1 || sc_CalcPlot[i]==1)
		        wn = sc_CalcWaveNames[i]
		        break
		    endif
		endfor
	endif

	wave w = $wn  // open reference
	Redimension /N=(numpnts(w)) sc_xdata
	CopyScales w, sc_xdata  // copy scaling
	sc_xdata = x  // set wave data equal to x scaling
end

function SaveWaves([msg, save_experiment])
	// the message will be printed in the history, and will be saved in the HDF file corresponding to this scan
	// save_experiment=1 to save the experiment file
	string msg
	variable save_experiment
	nvar sc_is2d, sc_PrintRaw, sc_PrintCalc, sc_scanstarttime
	svar sc_x_label, sc_y_label
	string filename, wn, logs=""
	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	wave /t sc_RawWaveNames, sc_CalcWaveNames
	wave sc_RawRecord, sc_CalcRecord

	if (!paramisdefault(msg))
		print msg
	else
		msg=""
	endif

	nvar sc_save_time
	if (paramisdefault(save_experiment))
		save_experiment = 1 // save the experiment by default
	endif

	KillDataFolder /Z root:async // clean this up for next time

	// save timing variables
	variable /g sweep_t_elapsed = datetime-sc_scanstarttime
	printf "Time elapsed: %.2f s \r", sweep_t_elapsed

	dowindow /k SweepControl // kill scan control window

	// count up the number of data files to save
	variable ii=0
	variable Rawadd = sum(sc_RawRecord)
	variable Calcadd = sum(sc_CalcRecord)

	if(Rawadd+Calcadd > 0)
		// there is data to save!
		// save it and increment the filenumber
		printf "saving all dat%d files...\r", filenum

		nvar sc_rvt
   	if(sc_rvt==1)
   		sc_update_xdata() // update xdata wave
		endif

		// Open up HDF5 files
	 	// Save scan controller meta data in this function as well
		initSaveFiles(msg=msg)
		if(sc_is2d == 2) //If 2D linecut then need to save starting x values for each row of data
			wave sc_linestart
			filename = "dat" + filenumstr + "linestart"
			duplicate sc_linestart $filename
			savesinglewave("sc_linestart")
		endif
		// save raw data waves
		ii=0
		do
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
				saveSingleWave(wn)
			endif
			ii+=1
		while (ii < numpnts(sc_RawWaveNames))

		//save calculated data waves
		ii=0
		do
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
				saveSingleWave(wn)
			endif
			ii+=1
		while (ii < numpnts(sc_CalcWaveNames))
		closeSaveFiles()
	endif

	if(save_experiment==1 & (datetime-sc_save_time)>180.0)
		// save if sc_save_exp=1
		// and if more than 3 minutes has elapsed since previous saveExp
		// if the sweep was aborted sc_save_exp=0 before you get here
		saveExp()
		sc_save_time = datetime
	endif

	// check if a path is defined to backup data
	if(sc_checkBackup())
		// copy data to server mount point
		sc_copyNewFiles(filenum, save_experiment=save_experiment )
	endif
	
	// increment filenum
	if(Rawadd+Calcadd > 0)
		filenum+=1
	endif

end

function SaveFromPXP([history, procedure])
	// this is all based on Igor Pro Technical Note #3
	// to save history as plain text: history=1
	// to save main procedure window as .ipf, procedure=1
	// if history=0 or procedure=0, they will not be saved

	variable history, procedure

	if(paramisdefault(history))
		history=1
	endif

	if(paramisdefault(procedure))
		procedure=1
	endif

	if(procedure!=1 && history!=1)
		// why did you do this?
		return 0
	endif

	// open experiment file as read-only
	// make sure it exists and get total size
	string expFile = igorinfo(1)+".pxp"
	variable expRef
	open /r/z/p=data expRef as expFile
	if(V_flag!=0)
		print "Experiment file could not be opened to fetch command history: ", expFile
		return 0
	endif
	FStatus expRef
	variable totalBytes = V_logEOF

	// find records from PackedFileRecordHeader
	variable pos = 0
	variable foundHistory=0, startHistory=0, numHistoryBytes=0
	variable foundProcedure=0, startProcedure=0, numProcedureBytes=0
	variable recordType, version, numDataBytes
	do
		FSetPos expRef, pos                // go to next header position
		FBinRead /U/F=2 expRef, recordType // unsigned, two-byte integer
		recordType = recordType&0x7FFF     // mask to get just the type value
		FBinRead /F=2 expRef, version      // signed, two-byte integer
		FBinRead /F=3 expRef, numDataBytes // signed, four-byte integer

		FGetPos expRef // get current file position in V_filePos

		if(recordType==2)
			foundHistory=1
			startHistory=V_filePos
			numHistoryBytes=numDataBytes
		endif

		if(recordType==5)
			foundProcedure=1
			startProcedure=V_filePos
			numProcedureBytes=numDataBytes
		endif

		if(foundHistory==1 && foundProcedure==1)
			break
		endif

		pos = V_filePos + numDataBytes // set new header position if I need to keep looking
	while(pos<totalBytes)

	variable warnings=0

	string buffer=""
	variable bytes=0, t_start=0
	if(history==1 && foundHistory==1)
		// I want to save it + I can save it

		string histFile = igorinfo(1)+".history"
		variable histRef
		open /p=data histRef as histFile

		FSetPos expRef, startHistory

		buffer=""
		bytes=0
		t_start=datetime
		do
			FReadLine /N=(numHistoryBytes-bytes) expRef, buffer
			bytes+=strlen(buffer)
			fprintf histRef, "%s", buffer

			if(datetime-t_start>2.0)
				// timeout at 2 seconds
				// something went wrong
				warnings += 1
				print "WARNING: timeout while trying to write out command history"
				break
			elseif(strlen(buffer)==0)
				// this is probably fine
				break
			endif
		while(bytes<numHistoryBytes)
		close histRef

	elseif(history==1 && foundHistory==0)
		// I want to save it but I cannot save it

		print "[WARNING] No command history saved"
		warnings += 1

	endif

	if(procedure==1 && foundProcedure==1)
		// I want to save it + I can save it

		string procFile = igorinfo(1)+".ipf"
		variable procRef
		open /p=data procRef as procFile

		FSetPos expRef, startProcedure

		buffer=""
		bytes=0
		t_start=datetime
		do
			FReadLine /N=(numProcedureBytes-bytes) expRef, buffer
			bytes+=strlen(buffer)
			fprintf procRef, "%s", buffer

			if(datetime-t_start>2.0)
				// timeout at 2 seconds
				// something went wrong
				warnings += 1
				print "[WARNING] Timeout while trying to write out procedure window"
				break
			elseif(strlen(buffer)==0)
				// this is probably fine
				break
			endif

		while(bytes<numProcedureBytes)
		close procRef

	elseif(procedure==1 && foundProcedure==0)
		// I want to save it but I cannot save it
		print "WARNING: no procedure window saved"
		warnings += 1
	endif

	close expRef
end

function /S sc_copySingleFile(original_path, new_path, filename)
	// custom copy file function because the Igor version seems to lead to 
	// weird corruption problems when copying from a local machine 
	// to a mounted server drive
	// this assumes that all the necessary paths already exist
	
	string original_path, new_path, filename
	string op="", np=""
	
	if( cmpstr(igorinfo(2) ,"Macintosh")==0 )
		// using rsync if the machine is a mac
		//   should speed things up a little bit by not copying full files
		op = getExpPath(original_path, full=2)
		np = getExpPath(new_path, full=2)
		
		string cmd = ""
		sprintf cmd, "rsync -a %s %s", op+filename, np
		executeMacCmd(cmd)
	else
		// probably can use rsync here on newer windows machines
		//   do not currently have one to test
		op = getExpPath(original_path, full=3)
		np = getExpPath(new_path, full=3)
		CopyFile /Z=1 (op+filename) as (np+filename)
	endif
	
end

function sc_copyNewFiles(datnum, [save_experiment, verbose] )
	// locate newly created/appended files and move to backup directory 

	variable datnum, save_experiment, verbose  // save_experiment=1 to save pxp, history, and procedure
	variable result = 0
	string tmpname = ""	

	// try to figure out if a path that is needed is missing
	make /O/T sc_data_paths = {"data", "config", "backup_data", "backup_config"}
	variable path_missing = 0, k=0
	for(k=0;k<numpnts(sc_data_paths);k+=1)
		pathinfo $(sc_data_paths[k])
		if(V_flag==0)
			abort "[ERROR] A path is missing. Data not backed up to server."
		endif
	endfor
	
	// add experiment/history/procedure files
	// only if I saved the experiment this run
	if(!paramisdefault(save_experiment) && save_experiment == 1)
	
		// add experiment file
		tmpname = igorinfo(1)+".pxp"
		sc_copySingleFile("data","backup_data",tmpname)

		// add history file
		tmpname = igorinfo(1)+".history"
		sc_copySingleFile("data","backup_data",tmpname)

		// add procedure file
		tmpname = igorinfo(1)+".ipf"
		sc_copySingleFile("data","backup_data",tmpname)
		
	endif

	// find new data files
	string extensions = ".h5;"
	string datstr = "", idxList, matchList
	variable i, j
	for(i=0;i<ItemsInList(extensions, ";");i+=1)
		sprintf datstr, "dat%d*%s", datnum, StringFromList(i, extensions, ";") // grep string
		idxList = IndexedFile(data, -1, StringFromList(i, extensions, ";"))
		if(strlen(idxList)==0)
			continue
		endif
		matchList = ListMatch(idxList, datstr, ";")
		if(strlen(matchlist)==0)
			continue
		endif

		for(j=0;j<ItemsInList(matchList, ";");j+=1)
			tmpname = StringFromList(j,matchList, ";")
			sc_copySingleFile("data","backup_data",tmpname)
		endfor
		
	endfor

	// add the most recent scan controller config file
	string configlist="", configpath=""
	getfilefolderinfo /Q/Z/P=config // check if config folder exists before looking for files
	if(V_flag==0 && V_isFolder==1)
		configpath = getExpPath("config", full=1)
		configlist = greplist(indexedfile(config,-1,".json"),"sc")
	endif

	if(itemsinlist(configlist)>0)
		configlist = SortList(configlist, ";", 1+16)
		tmpname = StringFromList(0,configlist, ";")
		sc_copySingleFile("config", "backup_config", tmpname )
	endif

	if(!paramisdefault(verbose) && verbose == 1)
		print "Copied new files to: " + getExpPath("backup_data", full=2)
	endif
end

//////////////////////////
/// sweep notification ///
//////////////////////////
 
function/s getSlackNotice([message, min_time]) 
	// Loading slack setup parameters from external config.
	// Setup config file ("SlackConfig.txt") should be placed in the setup folder.
	// Parameters are: userid, webhook, displayname & emoji
	
	// this function will send a notification to Slack -- run it as if it were a getInstrStatus function
	// message = string to include in Slack message
	// min_time = if time elapsed for this current scan is less than min_time no notification will be sent
	//					defaults to 60 seconds
	string message
	variable min_time
	nvar filenum, sweep_t_elapsed, sc_abortsweep
	
	// load setup from file
	string jstr = readtxtfile("SlackConfig.txt","setup")
	if(cmpstr(jstr,"")==0)
		abort
	endif
	
	string sc_slack_url = getJSONvalue(jstr,"webhook")
	string displayname = getJSONvalue(jstr,"displayname")
	string userid = getJSONvalue(jstr,"userid")
	string emoji = getJSONvalue(jstr,"emoji")
	string txt="", buffer="", payload=""

	//// check if I need a notification ////
	if (paramisdefault(min_time))
		min_time = 60.0 // seconds
	endif

	if(sweep_t_elapsed < min_time)
		return "{slack_notice: false}"
	endif

	if(sc_abortsweep)
		return "{slack_notice: false}"
	endif
	
	//// end notification checks ////


	if (!paramisdefault(message) && strlen(message)>0)
		txt += RemoveTrailingWhitespace(message) + "\r"
	endif

	sprintf buffer, "dat%d completed:  %s %s \r", filenum, Secs2Date(DateTime, 1), Secs2Time(DateTime, 3); txt+=buffer
	sprintf buffer, "time elapsed:  %.2f mins \r", sweep_t_elapsed/60; txt+=buffer
	//// end build txt ////

	//// build payload ////
	sprintf buffer, "{\"text\": \"%s\"", txt; payload+=buffer //
	sprintf buffer, ", \"username\": \"%s\"", displayname; payload+=buffer
	sprintf buffer, ", \"channel\": \"@%s\"", userid; payload+=buffer
	sprintf buffer, ", \"icon_emoji\": \"%s\"", emoji; payload+=buffer //
	payload += "}"
	//// end payload ////

	URLRequest /DSTR=payload url=sc_slack_url, method=post
	if (V_flag == 0)    // No error
        if (V_responseCode != 200)  // 200 is the HTTP OK code
            print "Slack POST failed!"
            return "{slack_notice: false}"
        else
            return "{slack_notice: true}"
        endif
    else
        print "HTTP connection error. Slack post not attempted."
        return "{slack_notice: false}"
    endif
end


