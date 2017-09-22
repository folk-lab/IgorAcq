#pragma rtGlobals=1		// Use modern global access method.

// Save all experiment data in native IGOR formats
//
// Waves are saved as .ibw
// Experiments are saved as .pxp
// meta data is dumped into custom .winf files
// 

///////////////////////////////////
//// save waves and experiment ////
///////////////////////////////////

function initSaveFiles([msg])
	//// create/open any files needed to save data 
	//// also save any global meta-data you want  
	
	string msg
	if(paramisdefault(msg)) // save meta data
		msg=""
	endif
	
	SaveScanComments(msg=msg)
	
end

function saveSingleWave(wn)
	// wave with name 'filename' as filename.ibw
	string wn
	
	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	string filename =  "dat" + filenumstr + wn
	
	Save/C/P=data $filename;
	
	svar sc_x_label, sc_y_label
	SaveInitialWaveComments(wn, x_label=sc_x_label, y_label=sc_y_label)
end

function endSaveFiles()
	//// close any files that were created for this dataset
	
end

/////////////////////////////
//// save comments files ////
/////////////////////////////

function /S recordedWaveArray()
	wave /T sc_RawWaveNames, sc_CalcWaveNames
	wave sc_RawRecord, sc_CalcRecord
	string swave=""
	variable i=0
	do
		if(strlen(sc_RawWaveNames[i])!=0 && sc_RawRecord[i]==1)
			swave += "\""+sc_RawWaveNames[i]+"\", "
		endif
		i+=1
	while(i<numpnts(sc_RawWaveNames))
	
	i=0
	do
		if(strlen(sc_CalcWaveNames[i])!=0 && sc_CalcRecord[i]==1)
			swave += "\""+sc_CalcWaveNames[i]+"\", "
		endif
		i+=1
	while(i<numpnts(sc_CalcWaveNames))
	
	return "["+swave[0,strlen(swave)-3]+"]"
end

function /s getExpStatus()
	// returns JSON object full of details about the system and this run
	nvar filenum, sweep_t_elapsed
	svar sc_current_config
		
	// create header with corresponding .ibw name and date
	string jstr = "", buffer = ""

	// information about the machine your working on
	buffer = ""
	buffer = addJSONKeyVal(buffer, "hostname", strVal=getHostName(), fmt = "\"%s\"")
	string sysinfo = igorinfo(3)
	buffer = addJSONKeyVal(buffer, "OS", strVal=StringByKey("OS", sysinfo), fmt = "\"%s\"")
	buffer = addJSONKeyVal(buffer, "IGOR_VERSION", strVal=StringByKey("IGORFILEVERSION", sysinfo), fmt = "\"%s\"")
	jstr = addJSONKeyVal(jstr, "system_info", strVal=buffer)

	// information about the current experiment
	jstr = addJSONKeyVal(jstr, "experiment", strVal=getExpPath("data")+igorinfo(1)+".pxp", fmt = "\"%s\"")
	jstr = addJSONKeyVal(jstr, "current_config", strVal=sc_current_config, fmt = "\"%s\"")
	buffer = ""
	buffer = addJSONKeyVal(buffer, "data", strVal=getExpPath("data"), fmt = "\"%s\"")
	buffer = addJSONKeyVal(buffer, "winfs", strVal=getExpPath("winfs"), fmt = "\"%s\"")
	buffer = addJSONKeyVal(buffer, "config", strVal=getExpPath("config"), fmt = "\"%s\"")
	jstr = addJSONKeyVal(jstr, "paths", strVal=buffer)
	
	// information about this specific run
	jstr = addJSONKeyVal(jstr, "filenum", numVal=filenum, fmt = "%.0f")
	jstr = addJSONKeyVal(jstr, "time_completed", strVal=Secs2Date(DateTime, 1)+" "+Secs2Time(DateTime, 3), fmt = "\"%s\"")
	jstr = addJSONKeyVal(jstr, "time_elapsed", numVal = sweep_t_elapsed, fmt = "%.3f")
	jstr = addJSONKeyVal(jstr, "saved_waves", strVal=recordedWaveArray())

	return jstr
end

function /s getWaveStatus(datname)
	string datname
	nvar filenum
	
	// create header with corresponding .ibw name and date
	string jstr="", buffer="" 
	
	// date/time info
	jstr = addJSONKeyVal(jstr, "wave_name", numVal=filenum, fmt = "%.0f")
	jstr = addJSONKeyVal(jstr, "filenum", numVal=filenum, fmt = "%.0f")
	jstr = addJSONKeyVal(jstr, "file_path", strVal=getExpPath("data")+"dat"+num2istr(filenum)+datname+".ibw", fmt = "\"%s\"")

	// wave info
	//check if wave is 1d or 2d
	variable dims
	if(dimsize($datname, 1)==0)
		dims =1
	elseif(dimsize($datname, 1)!=0 && dimsize($datname, 2)==0)
		dims = 2
	else
		dims = 3
	endif
	
	if (dims==1)
		// save some data
		wavestats/Q $datname
		buffer = ""
		buffer = addJSONKeyVal(buffer, "length", numVal=dimsize($datname,0), fmt = "%d")
		buffer = addJSONKeyVal(buffer, "dx", numVal=dimdelta($datname, 0))
		buffer = addJSONKeyVal(buffer, "mean", numVal=V_avg)
		buffer = addJSONKeyVal(buffer, "standard_dev", numVal=V_avg)
		jstr = addJSONKeyVal(jstr, "wave_stats", strVal=buffer)
	elseif(dims==2)
		wavestats/Q $datname
		buffer = ""
		buffer = addJSONKeyVal(buffer, "columns", numVal=dimsize($datname,0), fmt = "%d")
		buffer = addJSONKeyVal(buffer, "rows", numVal=dimsize($datname,1), fmt = "%d")
		buffer = addJSONKeyVal(buffer, "dx", numVal=dimdelta($datname, 0))
		buffer = addJSONKeyVal(buffer, "dy", numVal=dimdelta($datname, 1))
		buffer = addJSONKeyVal(buffer, "mean", numVal=V_avg)
		buffer = addJSONKeyVal(buffer, "standard_dev", numVal=V_avg)
		jstr = addJSONKeyVal(jstr, "wave_stats", strVal=buffer)
	else
		jstr = addJSONKeyVal(jstr, "wave_stats", strVal="Wave dimensions > 2. How did you get this far?", fmt = "\"%s\"")
	endif
	
	return jstr	
end

function /S saveScanComments([msg])
	// msg can be any normal string, it will be saved as a JSON string value
	
	string msg
	string buffer="", jstr=""
	jstr += getExpStatus() // record date, time, wave names, time elapsed...
	
	if (!paramisdefault(msg) && strlen(msg)!=0)
		jstr = addJSONKeyVal(jstr, "comments", strVal=TrimString(msg), fmt = "\"%s\"")
	endif
	
	//// this should be replaced ////
	//// all log strings should be valid JSON objects ////
	buffer = ""	
	svar sc_LogStr
	if (strlen(sc_LogStr)>0)
		string command
		string /G sc_log_buffer=""
		variable i = 0
		for(i=0;i<ItemsInList(sc_logStr, ";");i+=1)
			command = StringFromList(i, sc_logStr, ";")
			Execute/Q/Z "sc_log_buffer="+command
			if(strlen(sc_log_buffer)!=0)
				buffer += TrimString(sc_log_buffer)+"\r\r"
			else
				buffer += TrimString("command failed to log anything: "+command)+"\r\r"
			endif
		endfor
		buffer = buffer[0,strlen(buffer)-2]
	endif	
	jstr = addJSONKeyVal(jstr, "logs", strVal=buffer, fmt = "\"%s\"")
	
	//// save file ////
	nvar filenum
	string extension, filename
	extension = "." + num2istr(unixtime()) + ".winf"
	filename =  "dat" + num2istr(filenum) + extension
	writeJSONtoFile(jstr, filename, "winfs")

end







function /s str2WINF(datname, s)
	// string s to winf file 
	//filename = dat<filenum><datname>.<unixtime>.winf
	string datname, s
	variable refnum
	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	string extension, filename
	extension = "." + num2istr(unixtime()) + ".winf"
	filename =  "dat" + filenumstr + datname + extension
	open /A/P=winfs refnum as filename
	
	do
		if(strlen(s)<500)
			fprintf refnum, "%s", s
			break
		else
			fprintf refnum, "%s", s[0,499]
			s = s[500,inf]
		endif
	while(1)
	close refnum
	
	return filename
end

function /S SaveInitialWaveComments(datname, [title, x_label, y_label, z_label, x_multiplier, y_multiplier, z_multiplier, display_thumbnail])
	// this has not been converted to JSON, because our measurement website relies on it, for now
	variable  x_multiplier, y_multiplier, z_multiplier
	string datname, title, x_label, y_label, z_label, display_thumbnail
	string buffer="", comments=""
	
	// save waveStatus
	string jstr = getWaveStatus(datname)
	
	comments += prettyJSONfmt(jstr) + "\r\r" // record date, time, wave names, time elapsed...
	
	// save plot commands
	string plotcmds=""
	if (paramisdefault(title))
		title = ""
	endif
	plotcmds+="$$ title = "+title+"\r"
	
	if (paramisdefault(x_label))
		x_label = ""
	endif
	plotcmds+="$$ x_label = "+x_label+"\r"
	
	if (paramisdefault(y_label))
		y_label = ""
	endif
	plotcmds+="$$ y_label = "+y_label+"\r"
	
	if (paramisdefault(z_label))
		z_label = ""
	endif
	plotcmds+="$$ z_label = "+z_label+"\r"
	
	if (paramisdefault(x_multiplier))
		x_multiplier = 1.0
	endif
	plotcmds+="$$ x_multiplier = "+num2str(x_multiplier)+"\r"
	
	if (paramisdefault(y_multiplier))
		y_multiplier = 1.0
	endif
	plotcmds+="$$ y_multiplier = "+num2str(y_multiplier)+"\r"
	
	if (paramisdefault(z_multiplier))
		z_multiplier = 1.0
	endif
	plotcmds+="$$ z_multiplier = "+num2str(z_multiplier)+"\r"
	
	if (paramisdefault(display_thumbnail))
		display_thumbnail = "False"
	endif
	plotcmds+="$$ display_thumbnail = "+display_thumbnail+"\r"
	
	comments+=plotcmds
	
	// leave room for comments
	comments += "\r"+"comments:  \r"

	print comments	
//	str2WINF(datname, comments)
end