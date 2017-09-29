#pragma rtGlobals=1		// Use modern global access method.

// Save all experiment data in native IGOR formats
//
// Waves are saved in HDF5
// Experiments are saved as .pxp
// meta data is dumped into HDF5 as JSON formatted text
// 

// structure of h5 file
// 
// there is a root group "/"
// can create other groups "/GroupA"....
// each group can contain datasets or additional groups "/GroupA/Subgroup"
// each dataset can have attributes associated with it (like datasets themselves, but attached to a dataset)
// groups may also have attributes attached to them

///////////////////////
//// get meta data ////
///////////////////////

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
	buffer = addJSONKeyVal(buffer, "hostname", strVal=getHostName(), addQuotes = 1)
	string sysinfo = igorinfo(3)
	buffer = addJSONKeyVal(buffer, "OS", strVal=StringByKey("OS", sysinfo), addQuotes = 1)
	buffer = addJSONKeyVal(buffer, "IGOR_VERSION", strVal=StringByKey("IGORFILEVERSION", sysinfo), addQuotes = 1)
	jstr = addJSONKeyVal(jstr, "system_info", strVal=buffer)

	// information about the current experiment
	jstr = addJSONKeyVal(jstr, "experiment", strVal=getExpPath("data")+igorinfo(1)+".pxp", addQuotes = 1)
	jstr = addJSONKeyVal(jstr, "current_config", strVal=sc_current_config, addQuotes = 1)
	buffer = ""
	buffer = addJSONKeyVal(buffer, "data", strVal=getExpPath("data"), addQuotes = 1)
	buffer = addJSONKeyVal(buffer, "winfs", strVal=getExpPath("winfs"), addQuotes = 1)
	buffer = addJSONKeyVal(buffer, "config", strVal=getExpPath("config"), addQuotes = 1)
	jstr = addJSONKeyVal(jstr, "paths", strVal=buffer)
	
	// information about this specific run
	jstr = addJSONKeyVal(jstr, "filenum", numVal=filenum, fmtNum = "%.0f")
	jstr = addJSONKeyVal(jstr, "time_completed", strVal=Secs2Date(DateTime, 1)+" "+Secs2Time(DateTime, 3), addQuotes = 1)
	jstr = addJSONKeyVal(jstr, "time_elapsed", numVal = sweep_t_elapsed, fmtNum = "%.3f")
	jstr = addJSONKeyVal(jstr, "saved_waves", strVal=recordedWaveArray())

	return jstr
end

function /s getWaveStatus(datname)
	string datname
	nvar filenum
	
	// create header with corresponding .ibw name and date
	string jstr="", buffer="" 
	
	// date/time info
	jstr = addJSONKeyVal(jstr, "wave_name", strVal=datname, addQuotes = 1)
	jstr = addJSONKeyVal(jstr, "filenum", numVal=filenum, fmtNum = "%.0f")
	jstr = addJSONKeyVal(jstr, "file_path", strVal=getExpPath("data")+"dat"+num2istr(filenum)+datname+".ibw", addQuotes = 1)

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
		buffer = addJSONKeyVal(buffer, "length", numVal=dimsize($datname,0), fmtNum = "%d")
		buffer = addJSONKeyVal(buffer, "dx", numVal=dimdelta($datname, 0))
		buffer = addJSONKeyVal(buffer, "mean", numVal=V_avg)
		buffer = addJSONKeyVal(buffer, "standard_dev", numVal=V_avg)
		jstr = addJSONKeyVal(jstr, "wave_stats", strVal=buffer)
	elseif(dims==2)
		wavestats/Q $datname
		buffer = ""
		buffer = addJSONKeyVal(buffer, "columns", numVal=dimsize($datname,0), fmtNum = "%d")
		buffer = addJSONKeyVal(buffer, "rows", numVal=dimsize($datname,1), fmtNum = "%d")
		buffer = addJSONKeyVal(buffer, "dx", numVal=dimdelta($datname, 0))
		buffer = addJSONKeyVal(buffer, "dy", numVal=dimdelta($datname, 1))
		buffer = addJSONKeyVal(buffer, "mean", numVal=V_avg)
		buffer = addJSONKeyVal(buffer, "standard_dev", numVal=V_avg)
		jstr = addJSONKeyVal(jstr, "wave_stats", strVal=buffer)
	else
		jstr = addJSONKeyVal(jstr, "wave_stats", strVal="Wave dimensions > 2. How did you get this far?", addQuotes = 1)
	endif
	
	svar sc_x_label, sc_y_label
	jstr = addJSONKeyVal(jstr, "x_label", strVal=sc_x_label, addQuotes = 1)
	jstr = addJSONKeyVal(jstr, "y_label", strVal=sc_y_label, addQuotes = 1)
	
	return jstr	
end

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
	
	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	string /g h5name = "dat"+filenumstr+".h5"
	
	// Open HDF5 file
	variable /g hdf5_id
	HDF5CreateFile /P=data hdf5_id as h5name

	// Create data array group
	variable /G data_group_ID
	HDF5CreateGroup hdf5_id, "data_arrays", data_group_ID
	
	getExpStatus()
	
end

function saveSingleWave(wn)
	// wave with name 'filename' as filename.ibw
	string wn
	nvar data_group_id

	getWaveStatus(wn)

	HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 /Z $wn , data_group_id
	if (V_flag != 0)
		Print "HDF5SaveData failed: ", wn
	endif
end

function endSaveFiles()
	//// close any files that were created for this dataset
	
	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	string /g h5name = "dat"+filenumstr+".h5"
	
	// close data_array group
	nvar data_group_id
	HDF5CloseGroup /Z data_group_id
	if (V_flag != 0)
		Print "HDF5CloseGroup Failed: ", "data_arrays"
	endif

	// close HDF5 file
	nvar hdf5_id
	HDF5CloseFile /Z hdf5_id
	if (V_flag != 0)
		Print "HDF5CloseFile failed: ", h5name
	endif
	
end

// these should live in the procedures for the instrument
// that way not all of the procedures need to be loaded for this WINF thing to compile correctly

//function/S GetSRSStatus(srs)
//	variable srs
//	string winfcomments = "", buffer = "";
//	sprintf buffer "SRS %s:\r\tLock-in  Amplitude = %.3f V\r\tTime Constant = %.2fms\r\tFrequency = %.2fHz\r\tSensitivity=%.2fV\r\tPhase = %.2f\r", GetSRSAmplitude(srs), GetSRSTimeConstInSeconds(srs)*1000, GetSRSFrequency(srs),getsrssensitivity(srs, realsens=1), GetSRSPhase(srs)
//	winfcomments += buffer
//	
//	return winfcomments
//end
//
//function /S GetIPSStatus()
//	string winfcomments = "", buffer = "";
//	sprintf buffer, "IPS:\r\tMagnetic Field = %.4f mT\r\tSweep Rate = %.4f mT/min\r", GetField(),   GetSweepRate(); winfcomments += buffer
//	
//	return winfcomments
//end