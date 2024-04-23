#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1			// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

/// this procedure contains all of the functions that
/// scan controller needs for file I/O and custom formatted string handling


Function StringToListWave(string strList)
    // Takes a string of numbers delimited by either commas or semicolons and converts it to a numeric wave.
    
    Variable numItems, i
    String numStr, separator
    
    // Determine the separator used in the string
    If (StrSearch(strList, ";", 0) >= 0)
        separator = ";"
    ElseIf (StrSearch(strList, ",", 0) >= 0)
        separator = ","
    Else
        // If no separator is found, assume the string is invalid or empty and abort
        Print "No valid separator found or string is empty."
        return 0
    EndIf
    
    // Count the number of items in the list
    numItems = ItemsInList(strList, separator)
    
    // Make a new wave with the number of items found in the string
    Make/O/N=(numItems) numericWave
    
    // Loop through the string, convert each item to a number, and assign it to the wave
    For (i = 0; i < numItems; i += 1)
        numStr = StringFromList(i, strList, separator)  // Extract number string from list using the detected separator
        numericWave[i] = Str2Num(numStr)  // Convert to number and assign to wave
    EndFor
    
    // Optionally, give the wave a meaningful name or handle it externally
End

//////////////////////////////
/// SAVING EXPERIMENT DATA ///
//////////////////////////////

function OpenHDFFile(RawSave)	
	//open a file and return its ID based on RawSave
	// Rawsave = 0 to open normal hdf5
	// Rawsave = 1 to open _RAW hdf5
	// returns the hdf5_id
	variable RawSave
	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	string h5name


	if (RawSave == 0)
		h5name = "dat"+filenumstr+".h5"
	elseif (RawSave == 1)
		h5name = "dat"+filenumstr+"_RAW"+".h5"
	endif

	variable hdf5_id
	HDF5CreateFile /P=data hdf5_id as h5name // Open HDF5 file
	if (V_Flag !=0)
		abort "Failed to open save file. Probably need to run `filenum+=1` so that it isn't trying to create an existing file. And then run EndScan(...) again"
	endif	
	return hdf5_id
end


function CloseHDFFile(hdf5_id_list) 
	// close any files that were created for this dataset
	string hdf5_id_list	
	
	variable i
	variable hdf5_id
	for (i=0;i<itemsinlist(hdf5_id_list);i++)
		hdf5_id = str2num(stringFromList(i, hdf5_id_list))

		HDF5CloseFile /Z hdf5_id // close HDF5 file
		if (V_flag != 0)
			Print "HDF5CloseFile failed"
		endif
		
	endfor
end


function saveWavesToHDF(wavesList, hdfID, [saveNames])
	string wavesList, saveNames
	variable hdfID
	
	saveNames = selectString(paramIsDefault(saveNames), saveNames, wavesList)
	
	variable i	
	string wn, saveName
	for (i=0; i<itemsInList(wavesList); i++)
		wn = stringFromList(i, wavesList)
		saveName = stringFromList(i, saveNames)
		SaveSingleWaveToHDF(wn, hdfID, saveName=saveName)
	endfor
end


function addMetaFiles(hdf5_id_list, [S, logs_only, comments])
	// Adds config json string and sweeplogs json string to HDFs as attrs of a group named "metadata"
	// Note: comments is only used when saving logs_only (otherwise comments are saved from ScanVars.comments)
	string hdf5_id_list, comments
	Struct ScanVars &S
	variable logs_only  // 1=Don't save any sweep information to HDF
	make/Free/T/N=1 cconfig = {""}
//	cconfig = prettyJSONfmt(scw_createConfig())  	//<< 2023/01 -- I think someting about this is chopping off a lot of the info
	cconfig = scw_createConfig()  					// << This is the temporary fix -- at least the info is saved even if not perfect
	
	if (!logs_only)
		make /FREE /T /N=1 sweep_logs = prettyJSONfmt(sc_createSweepLogs(S=S))
		make /free /T /N=1 instr_logs=prettyJSONfmt(sc_instrumentLogs()) // Modifies the jstr to add Instrumt Status (from ScanController Window)
		make /FREE /T /N=1 scan_vars_json = sce_ScanVarsToJson(S, getrtstackinfo(3), save_to_file = 0)
	else
		make /FREE /T /N=1 sweep_logs = prettyJSONfmt(sc_createSweepLogs(comments = comments))
	endif
	
	// Check that prettyJSONfmt actually returned a valid JSON.
	sc_confirm_JSON(sweep_logs, name="sweep_logs")
	sc_confirm_JSON(cconfig, name="cconfig")

	// LOOP through the given hdf5_id in list
	variable i
	variable hdf5_id
	for (i=0;i<itemsinlist(hdf5_id_list);i++)
		hdf5_id = str2num(stringFromList(i, hdf5_id_list))

		
		// Create metadata
		// this just creates one big JSON string attribute for the group
		// its... fine
		variable /G meta_group_ID
		HDF5CreateGroup/z hdf5_id, "metadata", meta_group_ID
		if (V_flag != 0)
				Print "HDF5OpenGroup Failed: ", "metadata"
		endif

		
		HDF5SaveData/z /A="sweep_logs" sweep_logs, hdf5_id, "metadata"
		if (V_flag != 0)
				Print "HDF5SaveData Failed: ", "sweep_logs"
		endif
		
		HDF5SaveData/z /A="instr_logs" instr_logs, hdf5_id, "metadata"
		if (V_flag != 0)
				Print "HDF5SaveData Failed: ", "instr_logs"
		endif



		if (!logs_only)
			HDF5SaveData/z /A="ScanVars" scan_vars_json, hdf5_id, "metadata"
			if (V_flag != 0)
					Print "HDF5SaveData Failed: ", "ScanVars"
			endif
		endif
		
		HDF5SaveData/z /A="sc_config" cconfig, hdf5_id, "metadata"
		if (V_flag != 0)
				Print "HDF5SaveData Failed: ", "sc_config"
		endif
		
		HDF5CloseGroup /Z meta_group_id
		if (V_flag != 0)
			Print "HDF5CloseGroup Failed: ", "metadata"
		endif

		// may as well save this config file, since we already have it
		scw_saveConfig()	
		
	endfor
end


function /s sc_createSweepLogs([S, comments])  // TODO: Rename
	// Creates a Json String which contains information about Scan
    // Note: Comments is ignored unless ScanVars are not provided
	Struct ScanVars &S
    string comments
	string jstr = ""
	svar sc_current_config

    if (!paramisDefault(S))
        comments = S.comments
    endif

	jstr = addJSONkeyval(jstr, "comment", comments, addQuotes=1)
	jstr = addJSONkeyval(jstr, "current_config", sc_current_config, addQuotes = 1)
	jstr = addJSONkeyval(jstr, "time_completed", Secs2Date(DateTime, 1)+" "+Secs2Time(DateTime, 3), addQuotes = 1)
		
    if (paramisDefault(S))
    	nvar filenum
   		jstr = addJSONkeyval(jstr, "filenum", num2istr(filenum))
    else
	    jstr = addJSONkeyval(jstr, "filenum", num2istr(S.filenum))

        string buffer = ""
        buffer = addJSONkeyval(buffer, "x", S.x_label, addQuotes=1)
        buffer = addJSONkeyval(buffer, "y", S.y_label, addQuotes=1)
        jstr = addJSONkeyval(jstr, "axis_labels", buffer)
        jstr = addJSONkeyval(jstr, "time_elapsed", num2numStr(S.end_time-S.start_time))
        jstr = addJSONkeyval(jstr, "read_vs_time", num2numStr(S.readVsTime))
        jstr = addJsonKeyval(jstr, "x_channels", ReplaceString(";", S.channelsx, ","))
        if (S.is2d)   
	        jstr = addJsonKeyval(jstr, "y_channels", ReplaceString(";", S.channelsy, ","))        
	     endif
        if (S.using_fastdac)
        	  nvar sc_resampleFreqFadc, sc_demodphi
        	  nvar sc_demody
        	  svar sc_nQs, sc_nfreq 
        	  
   	        jstr = addJSONkeyval(jstr, "sweeprate", num2numStr(S.sweeprate))  	        
   	        jstr = addJSONkeyval(jstr, "measureFreq", num2numStr(S.measureFreq))  
		     jstr = addJSONkeyval(jstr, "resamplingFreq", num2numstr(sc_resampleFreqFadc))
		     jstr = addJSONkeyval(jstr, "resampWaves", scf_getRecordedFADCinfo("calc_names", column = 8), addQuotes= 1)
		     jstr = addJSONkeyval(jstr, "demodPhi", num2numstr(sc_demodphi))
		     jstr = addJSONkeyval(jstr, "save_demody", num2numstr(sc_demody))
		     jstr = addJSONkeyval(jstr, "demodWaves", scf_getRecordedFADCinfo("calc_names", column = 6), addQuotes= 1)
		     jstr = addJSONkeyval(jstr, "notchQs", sc_nQs, addQuotes=1)
		     jstr = addJSONkeyval(jstr, "notchFreqs", sc_nfreq, addQuotes=1)
		     jstr = addJSONkeyval(jstr, "notchedWaves", scf_getRecordedFADCinfo("calc_names", column = 5), addQuotes= 1)
   	     endif
    endif

//    sc_instrumentLogs(jstr)  // Modifies the jstr to add Instrumt Status (from ScanController Window)
	return jstr
end


function/s sc_instrumentLogs()
	// Runs all getinstrStatus() functions, and adds results to json string (to be stored in sweeplogs)
	// Note: all log strings must be valid JSON objects 
    string jstr=""
    
	//sc_openInstrConnections(0)  // Reopen connections before asking for status in case it has been a long time (?)[Vahid: how long would be a long time??] since the beginning of the scan
	wave /t sc_Instr
	variable i=0, j=0, addQuotes=0
	string command="", val=""
	string /G sc_log_buffer=""

	for(i=0;i<DimSize(sc_Instr, 0);i+=1)
		sc_log_buffer=""
		command = TrimString(sc_Instr[i][2])
		if(strlen(command)>0 && cmpstr(command[0], "/") !=0) // Command and not commented out
			Execute/Q/Z "sc_log_buffer="+command
			if(V_flag!=0)
				print "[ERROR] in sc_createSweepLogs: "+GetErrMessage(V_Flag,2)
			endif
			if(strlen(sc_log_buffer)!=0)
			jstr=sc_log_buffer
//				// need to get first key and value from sc_log_buffer
//				JSONSimple sc_log_buffer
//				wave/t t_tokentext
//				wave w_tokentype, w_tokensize, w_tokenparent
//				for(j=1;j<numpnts(t_tokentext)-1;j+=1)
//					if ( w_tokentype[j]==3 && w_tokensize[j]>0 )
//						if( w_tokenparent[j]==0 )
//							if( w_tokentype[j+1]==3 )
//								val = "\"" + t_tokentext[j+1] + "\""
//							else
//								val = t_tokentext[j+1]
//							endif
//							jstr = addJSONkeyval(jstr, t_tokentext[j], val)
//							break
//						endif
//					endif
//				endfor
			else
				print "[WARNING] command failed to log anything: "+command+"\r"
			endif
		endif
	endfor
	return jstr
end


function/t getRawSaveNames(baseNames)
	// Returns baseName +"_RAW" for baseName in baseNames
	string baseNames
	string returnNames = ""
	variable i
	for (i=0; i<itemsInList(baseNames); i++)
		returnNames = addListItem(stringFromList(i, baseNames)+"_RAW", returnNames, ";", INF)
	endfor
	return returnNames
end


function createWavesCopyIgor(wavesList, filenum, [saveNames])
	// Duplicate each wave with prefix datXXX so that it's easily accessible in Igor
	string wavesList, saveNames
	variable filenum

	saveNames = selectString(paramIsDefault(saveNames), saveNames, wavesList)	
	
	variable i	
	string wn, saveName
	for (i=0; i<itemsInList(wavesList); i++)
		wn = stringFromList(i, wavesList)
		saveName = stringFromList(i, saveNames)
		saveName = "dat"+num2str(filenum)+saveName
		duplicate $wn $saveName
	endfor
end

function saveScanWaves(hdfid, S, filtered)
	// Save x_array and y_array in HDF 
	// Note: The x_array will have the right dimensions taking into account filtering
	variable hdfid
	Struct ScanVars &S
	variable filtered


	if(filtered)
		make/o/free/N=(scfd_postFilterNumpts(S.numptsx, S.measureFreq)) sc_xarray
	else
		make/o/free/N=(S.numptsx) sc_xarray
	endif

	string cmd
	setscale/I x S.startx, S.finx, sc_xarray
	sc_xarray = x
	// cmd = "setscale/I x " + num2str(S.startx) + ", " + num2str(S.finx) + ", \"\", " + "sc_xdata"; execute(cmd)
	// cmd = "sc_xdata" +" = x"; execute(cmd)
	HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 sc_xarray, hdfid, "x_array"

	if (S.is2d)
		make/o/free/N=(S.numptsy) sc_yarray
		
		setscale/I x S.starty, S.finy, sc_yarray
		// cmd = "setscale/I x " + num2str(S.starty) + ", " + num2str(S.finy) + ", \"\", " + "sc_ydata"; execute(cmd)
		// cmd = "sc_ydata" +" = x"; execute(cmd)
		sc_yarray = x
		HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 sc_yarray, hdfid, "y_array"
	endif

	// save x and y arrays
	if(S.is2d == 2)
		abort "Not implemented again yet, need to figure out how/where to get linestarts from"
		HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 $"sc_linestart", hdfid, "linestart"
	endif
end


function SaveSingleWaveToHDF(wn, hdf5_id, [saveName])
	// wave with name 'g1x' as dataset named 'g1x' in hdf5
	string wn, saveName
	variable hdf5_id

	saveName = selectString(paramIsDefault(saveName), saveName, wn)

	HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 /Z $wn, hdf5_id, saveName
	if (V_flag != 0)
		Print "HDF5SaveData failed: ", wn
		return 0
	endif

end


function SaveToHDF(S, [additional_wavenames])
	// Save last measurement described by S to HDF (inluding meta data etc)
	Struct ScanVars &S
	string additional_wavenames  // Any additional waves to save in HDF (note: ; separated list)
	
	nvar filenum
	printf "saving all dat%d files...\r", filenum

	nvar/z sc_Saverawfadc  // From ScanControllerFastDAC window 
	
	// Open up HDF5 files
	variable raw_hdf5_id, calc_hdf5_id
	calc_hdf5_id = OpenHDFFile(0)
	string hdfids = num2str(calc_hdf5_id)
	if (S.using_fastdac && sc_Saverawfadc == 1)
		raw_hdf5_id = OpenHDFFile(1)
		hdfids = addlistItem(num2str(raw_hdf5_id), hdfids, ";", INF)
	endif
	S.filenum = filenum
	filenum += 1  // So next created file gets a new num (setting here so that when saving fails, it doesn't try to overwrite next save)
	
	// add Meta data to each file
	addMetaFiles(hdfids, S=S)
	
	if (S.using_fastdac)
		// Save some fastdac specific waves (sweepgates etc)
		saveFastdacInfoWaves(hdfids, S)
	endif

	// Save ScanWaves (e.g. x_array, y_array etc)
	if(S.using_fastdac)
		saveScanWaves(calc_hdf5_id, S, 1)  // Needs a different x_array size if filtered
//		going forward we never save rawdata 
//		if (Sc_saveRawFadc == 1)
//			saveScanWaves(raw_hdf5_id, S, 0)
//		endif
//	else
		//saveScanWaves(calc_hdf5_id, S, 0)
	endif
	
	// Get waveList to save
	string RawWaves, CalcWaves, rwn, cwn, ADCnum, rawWaves2, rawSaveNames
	wave fadcattr
	nvar sc_demody, sc_hotcold
	int i,j=0
	
	if(S.is2d == 0)
	
		RawWaves = sci_get1DWaveNames(1, S.using_fastdac)
		CalcWaves = sci_get1DWaveNames(0, S.using_fastdac)
		RawWaves2 = RawWaves
		
		if(S.using_fastdac)
			rawSaveNames = Calcwaves
			for(i=0; i<itemsinlist(RawWaves); i++)
				rwn = StringFromList(i, RawWaves)
				cwn = StringFromList(i-j, CalcWaves)
				ADCnum = rwn[3,INF]
				if (fadcattr[str2num(ADCnum)][6] == 48)
					CalcWaves += cwn + "x;"
					CalcWaves += cwn + "y;"
				endif
				if (sc_hotcold)
					CalcWaves += cwn + "hot;"
					CalcWaves += cwn + "cold;"
					rawWaves2  = addlistitem(stringfromList(0,calcwaves), rawWaves2) //adding notched/resamp waves to raw dat
					rawSaveNames= addlistitem(stringfromlist(0,calcwaves) + "_cl", rawSaveNames)
					calcWaves = removelistItem(0,calcWaves) // removing it from main dat
					j++	
				endif
		 	endfor
		 	if(sc_hotcold)
		 		rawWaves = rawWaves2
		 	endif
		 endif
		
	elseif (S.is2d == 1)
		RawWaves = sci_get2DWaveNames(1, S.using_fastdac)
		CalcWaves = sci_get2DWaveNames(0, S.using_fastdac)
		RawWaves2 = RawWaves
		if(S.using_fastdac)
			rawSaveNames = Calcwaves
			for(i=0; i<itemsinlist(RawWaves); i++)
				rwn = StringFromList(i, RawWaves)
				cwn = StringFromList(i-j, CalcWaves)
				ADCnum = rwn[3,strlen(rwn)-4]
				
				if (fadcattr[str2num(ADCnum)][6] == 48)
					CalcWaves += cwn[0,strlen(cwn)-4] + "x_2d;"
					if (sc_demody == 1)
						CalcWaves += cwn[0,strlen(cwn)-4] + "y_2d;"
					endif
				endif
			
				if(sc_hotcold)
					CalcWaves += cwn[0,strlen(cwn)-4] + "hot_2d;"
					CalcWaves += cwn[0,strlen(cwn)-4] + "cold_2d;"
					rawWaves2  = addlistitem(stringfromList(0,calcwaves), rawWaves2) //adding notched/resamp waves to raw dat
					rawSaveNames= addlistitem(stringfromlist(0,calcwaves) + "_cl", rawSaveNames)
					calcWaves = removelistItem(0,calcWaves) // removing it from main dat
					j++	
				endif
		 	endfor
		 
		 	if(sc_hotcold)
		 		rawWaves = rawWaves2
		 	endif
		 endif
	
	else
		abort "Not implemented"
	endif
	

	// Add additional_wavenames to CalcWaves
	if (!paramIsDefault(additional_wavenames) && strlen(additional_wavenames) > 0)
		scu_assertSeparatorType(additional_wavenames, ";")
		CalcWaves += additional_wavenames
		// TODO: Check this adds the correct ; between strings
	endif
	
	// Copy waves in Experiment
	if (!S.using_fastdac) // Duplicate all Slow ScanController waves
		createWavesCopyIgor(RawWaves, filenum-1)  // -1 because already incremented filenum after opening HDF file
	endif
	createWavesCopyIgor(CalcWaves, filenum-1)  // -1 because already incremented filenum after opening HDF file
	
	// Save to HDF	
	saveWavesToHDF(CalcWaves, calc_hdf5_id)  // Includes saving additional_wavenmaes
	if(S.using_fastdac && sc_SaveRawFadc == 1)
		SaveWavesToHDF(RawWaves, raw_hdf5_id, saveNames=rawSaveNames)
	elseif(!S.using_fastdac)
		saveWavesToHDF(RawWaves, calc_hdf5_id)	// Save all regular ScanController waves in the main hdf file (they are small anyway)
	endif
	CloseHDFFile(hdfids) // close all files
end


function saveFastdacInfoWaves(hdfids, S)
	string hdfids
	Struct ScanVars &S
	
	variable i = 0

	make/o/N=(3, itemsinlist(s.channelsx, ",")) sweepgates_x = 0
	for (i=0; i<itemsinlist(s.channelsx, ","); i++)
		sweepgates_x[0][i] = str2num(stringfromList(i, s.channelsx, ","))
		sweepgates_x[1][i] = str2num(stringfromlist(i, s.startxs, ","))
		sweepgates_x[2][i] = str2num(stringfromlist(i, s.finxs, ","))
	endfor
	
	if (S.is2d)
		make/o/N=(3, itemsinlist(s.channelsy, ",")) sweepgates_y = 0
		for (i=0; i<itemsinlist(s.channelsy, ","); i++)
			sweepgates_y[0][i] = str2num(stringfromList(i, s.channelsy, ","))
			sweepgates_y[1][i] = str2num(stringfromlist(i, s.startys, ","))
			sweepgates_y[2][i] = str2num(stringfromlist(i, s.finys, ","))
		endfor
	else
		make/o sweepgates_y = {{NaN, NaN, NaN}}
	endif
	
	string wn
	variable hdfid
	for(i=0; i<itemsInList(hdfids); i++)
		hdfid = str2num(stringFromList(i, hdfids))
		HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 /Z sweepgates_x, hdfid
		if (V_flag != 0)
			Print "HDF5SaveData failed on sweepgates_x"
		endif
		HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 /Z sweepgates_y, hdfid
		if (V_flag != 0)
			Print "HDF5SaveData failed on sweepgates_y"
		endif
		
	
		// Add AWs used to HDF file if used
		struct AWGVars AWG
		fd_getGlobalAWG(AWG)
		if (AWG.use_awg)
			variable j
			for(j=0;j<AWG.numWaves;j++)
				// Get IGOR AW
				//*wn = fd_getAWGwave(str2num(stringfromlist(j, AWG.AW_waves, ",")))
				SaveSingleWaveToHDF(wn, hdfid)
			endfor
		endif
	endfor
end


function LogsOnlySave(hdfid, comments)
	// Save current state of experiment (i.e. most of sweeplogs) but without any specific data from a scan
	variable hdfid
	string comments

	abort "Not implemented again yet, need to think about what info to get from createSweepLogs etc"
	make/o/free/t/n=1 attr_message = "True"
	HDF5SaveData /A="Logs_Only" attr_message, hdfid, "/"

	string jstr = ""
//	jstr = prettyJSONfmt(new_sc_createSweepLogs(comments=comments))
	addMetaFiles(num2str(hdfid), logs_only=1, comments=comments)
	CloseHDFFile(num2str(hdfid))
end


function saveExp()
	SaveExperiment /P=data // save current experiment as .pxp
	SaveFromPXP(history=1, procedure=1) // grab some useful plain text docs from the pxp
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


function /S sc_copySingleFile(original_path, new_path, filename, [allow_overwrite])
	// custom copy file function because the Igor version seems to lead to 
	// weird corruption problems when copying from a local machine 
	// to a mounted server drive
	// this assumes that all the necessary paths already exist
	variable allow_overwrite
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
		if (allow_overwrite)
			CopyFile/O/Z=1 (op+filename) as (np+filename)
		else
			CopyFile/Z=1 (op+filename) as (np+filename)
		endif
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

	nvar/z sc_experiment_save_time
	if (!nvar_Exists(sc_experiment_save_time))
		variable/g sc_experiment_save_time = 0	
	endif
	if(!paramisdefault(save_experiment) && save_experiment == 1)
		// add experiment file
		if (datetime - sc_experiment_save_time > 60*60*24)  // Only copy the experiment to server once a day at most
		   tmpname = igorinfo(1)+".pxp"
			sc_copySingleFile("data","backup_data",tmpname, allow_overwrite=1)		
			sc_experiment_save_time = datetime
		endif		
		
		// add history file
		tmpname = igorinfo(1)+".history"
		sc_copySingleFile("data","backup_data",tmpname, allow_overwrite=1)

		// add procedure file
		tmpname = igorinfo(1)+".ipf"
		sc_copySingleFile("data","backup_data",tmpname, allow_overwrite=1)
		
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

// function saveSingleWave(wn)
// 	// wave with name 'g1x' as dataset named 'g1x' in hdf5
// 	string wn
// 	nvar hdf5_id

// 	HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 /Z $wn , hdf5_id
// 	if (V_flag != 0)
// 		Print "HDF5SaveData failed: ", wn
// 		return 0
// 	endif

// end

// function closeSaveFiles()
// 	// close any files that were created for this dataset

// 	nvar filenum
// 	string filenumstr = ""
// 	sprintf filenumstr, "%d", filenum
// 	string /g h5name = "dat"+filenumstr+".h5"

// 	// close HDF5 file
// 	nvar hdf5_id
// 	HDF5CloseFile /Z hdf5_id
// 	if (V_flag != 0)
// 		Print "HDF5CloseFile failed: ", h5name
// 	endif

// end

////////////////////////////
/// Load Experiment Data ///
////////////////////////////

function get_sweeplogs(datnum, [kenner])
	// Opens HDF5 file from current data folder and returns sweeplogs jsonID
	// Remember to JSON_Release(jsonID) or JSONXOP_release/A to release all objects
	// Can be converted to JSON string by using JSON_dump(jsonID)
	variable datnum
	string kenner
	kenner = selectString(paramisdefault(kenner), kenner, "")
	variable fileID, metadataID, i, result
	
	string HDF_filename = "dat" + num2str(datnum) + kenner + ".h5"
	
	HDF5OpenFile /R/P=data fileID as HDF_filename
	HDF5LoadData /Q/O/Type=1/N=sc_sweeplogs /A="sweep_logs" fileID, "metadata"
	HDF5CloseFile fileID
	
	wave/t sc_sweeplogs
	variable sweeplogsID
	sweeplogsID = JSON_Parse(sc_sweeplogs[0])

	return sweeplogsID
end




////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////  System Functions /////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function /S getHostName()
	// find the name of the computer Igor is running on
	// Used in saveing Config info
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

function /S executeWinCmd(command)
	// run the shell command
	// if logFile is selected, put output there
	// otherwise, return output
	// Used in getHostName()
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
	// Same purpose as executeWinCmd() for Mac environment
	// Used in getHostName()
	string command

	string cmd
	sprintf cmd, "do shell script \"%s\"", command
	ExecuteScriptText /UNQ /Z /W=5.0 cmd

	return S_value
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
	SplitString/E="([\w\s\-\:]+)(?i)(local[\s\_\-]measurement[\s\_\-]data)([\w\s\-\:]+)" S_path, temp1, temp2, temp3

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



///////////////////////
/// text read/write ///
///////////////////////

function writeToFile(anyStr,filename,path)
	// write any string to a file called "filename"
	// path must be a predefined path
	string anyStr,filename,path
	variable refnum

	open /z/p=$(path) refnum as filename
	if(V_flag!=0)
		print "[ERROR] File could not be opened in writeToFile: "+filename
		return 0
	endif

	do
		if(strlen(anyStr)<500)
			fprintf refnum, "%s", anyStr
			break
		else
			fprintf refnum, "%s", anyStr[0,499]
			anyStr = anyStr[500,inf]
		endif
	while(1)

	close refnum
	return 1
end

function/s readTXTFile(filename, path)
	// read textfile into string from filename on path
	string filename,path
	variable refnum
	string buffer="", txtstr=""

	open /r/z/p=$path refNum as filename
	if(V_flag!=0)
		print "[ERROR]: Could not read file: "+filename
		return ""
	endif

	do
		freadline refnum, buffer // returns \r no matter what was used in the file
		if(strlen(buffer)==0)
			break
		endif
		txtstr+=buffer
	while(1)
	close refnum
	return txtstr
end

/////////////
/// JSON  ///
/////////////

//// Using JSON XOP ////  

// Using JSON XOP requires working with JSON id's rather than JSON strings.
// To be used in addition to home built JSON functions which work with JSON strings
// JSON id's give access to all XOP functions (e.g. JSON_getKeys(jsonID, path))
// functions here should be ...JSONX...() to mark as a function which works with JSON XOP ID's rather than strings
// To switch between jsonID and json strings use JSON_Parse/JSON_dump 

function getJSONXid(jsonID, path)
	// Returns jsonID of json object located at "path" in jsonID passed in. e.g. get "BabyDAC" json from "Sweep_logs" json.
	// Path should be able to be a true JSON pointer i.e. "/" separated path (e.g. "Magnets/Magx") but it is untested
	variable jsonID
	string path
	variable i, tempID
	string tempKey
	
	if (JSON_GetType(jsonID, path) != 0)	
		abort "ERROR[get_json_from_json]: path does not point to JSON obect"
	endif

	if (itemsinlist(path, "/") == 1)
		return getJSONXid_fromKey(jsonID, path)
	else
		tempID = jsonID
		for(i=0;i<itemsinlist(path, "/");i++)  //Should recursively get deeper JSON objects. Untested
			tempKey = stringfromlist(i, path, "/")
			tempID = getJSONXid_fromKey(tempID, tempkey)
		endfor
		return tempID
	endif
end
	
function getJSONXid_fromKey(jsonID, key)
	// Should only be called from getJSONid to convert the inner JSON into a new JSONid pointer.
	// User should use the more general getJSONid(jsonID, path) where path can be a single key or "/" separated path
	variable jsonID
	string key
	if ((JSON_GetType(jsonID, key) != 0) || (itemsinlist(key, "/") != 1)	)
		abort "ERROR[get_json_from_json_key]: key is not a top level JSON obect"
	endif
	return JSON_parse(getJSONvalue(json_dump(jsonID), key))  // workaround to get a jsonID of inner JSON
end

function sc_confirm_JSON(jsonwave, [name])
	//Checks whether 'jsonwave' can be parsed as a JSON
	// Where 'jsonwave' is a textwave built from the homemade json functions NOT JSON_XOP
	//name is just to make it easier to identify the error
	wave/t jsonwave
	string name
	if (paramisDefault(name))
		name = ""
	endif

	JSONXOP_Parse/z jsonwave[0]
	if (v_flag != 0)
		printf "WARNING: %s JSON is not a valid JSON (saved anyway)\r", name
	endif
end			
//// END of Using JSON XOP ////


/// read ///
function/s getJSONvalue(jstr, key)
	// returns the value of the parsed key
	// function returns can be: object, array, value
	// expected format: "parent1:parent2:parent3:key"
	string jstr, key
	variable offset, key_length
	string indices
	
	key_length = itemsinlist(key,":")

	JSONSimple/z jstr
	wave/t t_tokentext
	wave w_tokentype, w_tokensize

	if(key_length==0)
		// return whole json
		return jstr
	elseif(key_length==1)
		// this is the only key with this name
		// if not, the first key will be returned
		offset = 0
		return getJSONkeyoffset(key,offset)
	else
		// the key has parents, and there could be multiple keys with this name
		// find the indices of the keys parsed
		indices = getJSONindices(key)
		if(itemsinlist(indices,",")<key_length)
			print "[ERROR] Value of JSON key is ambiguous: "+key
			return ""
		else
			return getJSONkeyoffset(stringfromlist(key_length-1,key,":"),str2num(stringfromlist(key_length-1,indices,","))-1)
		endif
	endif
end

function/s getJSONindices(keys)
	// returns string list with indices of parsed keys
	string keys
	string indices="", key
	wave/t t_tokentext
	wave w_tokentype, w_tokensize, w_tokenparent
	variable i=0, j=0, index, k=0

	for(i=0;i<itemsinlist(keys,":");i+=1)
		key = stringfromlist(i,keys,":")
		if(i==0)
			index = 0
		else
			index = str2num(stringfromlist(i-1,indices,","))
		endif
		for(j=0;j<numpnts(t_tokentext);j+=1)
			if(cmpstr(t_tokentext[j],key)==0 && w_tokensize[j]>0)
				if(w_tokenparent[j]==index)
					if(w_tokensize[j+1]>0)
						k = j+1
					else
						k = j
					endif
					indices = addlistitem(num2str(k),indices,",",inf)
					break
				endif
			endif
		endfor
	endfor

	return indices
end

function/s getJSONkeyoffset(key,offset)
	string key
	variable offset
	wave/t t_tokentext
	wave w_tokentype, w_tokensize
	variable i=0

	// find key and check that it is infact a key
	for(i=offset;i<numpnts(t_tokentext);i+=1)
		if(cmpstr(t_tokentext[i],key)==0 && w_tokensize[i]>0)
			return t_tokentext[i+1]
		endif
	endfor
	// if key is not found, return an empty string
	print "[ERROR] JSON key not found: "+key
	return t_tokentext[0] // Default to return everything
end

function /S getStrArrayShape(array)
	// works for arrays of single-quoted strings
	string array
	variable openBrack = 0, closeBrack = 0, quoted = 0, elements = 0
	variable i=0
	for(i=0; i<strlen(array); i+=1)

		// check if the current character is escaped
		if(i!=0)
			if( (CmpStr(array[i], "\"")==0) && (CmpStr(array[i-1], "\\")!=0 ))
				//this is an unescaped quote
				if(quoted==0)
					quoted = 1
				elseif(quoted==1)
					quoted=0
					elements+=1
				endif
			endif
		endif

		if( (quoted==0) && (CmpStr(array[i], "[")==0) )
			openBrack+=1
		elseif( (quoted==0) && (CmpStr(array[i], "]")==0) )
			closeBrack+=1
		endif

	endfor

	if (openBrack==closeBrack)
		if(openBrack>1)
			return num2str(elements/(openBrack-1))+","+num2str(openBrack-1)
		else
			return num2str(elements)+","
		endif
	else
		print "[ERROR] array formatting problem: "+array
		return ""
	endif

end

function loadStrArray2textWave(array,destwave)
	// supports 1 and 2d arrays
	string array,destwave
	string dims = getStrArrayShape(array), element=""
	variable i=0, quoted=0, ii=0, jj=0, nDims = itemsinlist(dims, ",")

	if(nDims==1)
		make/o/t/n=(str2num(dims)) $destwave = ""
	else
		make/o/t/n=(str2num(stringfromlist(0,dims,",")), str2num(stringfromlist(1,dims,","))) $destwave = ""
	endif
	wave /t w=$destwave

	for(i=0; i<strlen(array); i+=1)

		// check if the current character is escaped
		if(i!=0)
			if( (CmpStr(array[i], "\"")==0) && (CmpStr(array[i-1], "\\")!=0 ))
				//this is an unescaped quote
				if(quoted==0)
					quoted = 1
				elseif(quoted==1)
					quoted=0
					// end quote, add element to wave, increment ii, reset element
					if(nDims==1)
						w[ii] = unescapeQuotes(element[1,inf])
					else
						w[ii][jj] = unescapeQuotes(element[1,inf])
					endif
					element=""
					ii+=1
				endif
			endif
		endif

		if( (quoted==0) && (CmpStr(array[i], "[")==0) )
			// open bracket
		elseif( (quoted==0) && (CmpStr(array[i], "]")==0) )
			// close bracket, increment jj, reset ii
			jj+=1
			ii=0
		elseif( (quoted==1) )
			element+=array[i]
		endif

	endfor

end

function /S getArrayShape(array)
	// works for integers, floats, and boolean (true/false or 1/0)
	string array
	variable openBrack = 0, closeBrack = 0, elements = 0, commaLast = 0, brackLast = 0
	variable i=0

	for(i=0; i<strlen(array); i+=1)

		if( CmpStr(array[i], ",")==0 )
			// comma found
			commaLast=1 // comma was the last non-whitespace character
			if( brackLast==0 )
				elements+=1 // closed an element
			endif
		elseif( CmpStr(array[i], "[")==0 )
			openBrack+=1
		elseif( CmpStr(array[i], "]")==0 )
			closeBrack+=1
			if(commaLast==0 && brackLast==0)
				elements+=1 // no trailing comma, new element
			endif
			brackLast=1
		else
			if( isWhitespace(array[i])==0 )
				commaLast=0
				brackLast=0
			endif
		endif

	endfor

	if (openBrack==closeBrack)
		if(openBrack>1)
			return num2str(elements/(openBrack-1))+","+num2str(openBrack-1)
		else
			return num2str(elements)+","
		endif
	else
		print "[ERROR] array formatting problem: "+array
		return ""
	endif

end

function loadBoolArray2wave(array,destwave)
	// works for int or float since igor doesn't make a distinction
	string array,destwave
	string dims = getArrayShape(array), element=""
	variable i=0, commaLast=0, brackLast=0, ii=0, jj=0, nDims = itemsinlist(dims, ",")

	if(nDims==1)
		make/o/n=(str2num(dims)) $destwave
	else
		make/o/n=(str2num(stringfromlist(0,dims,",")), str2num(stringfromlist(1,dims,","))) $destwave
	endif
	wave w=$destwave

	for(i=0; i<strlen(array); i+=1)
		if( CmpStr(array[i], ",")==0 )
			// comma found, write element, increment ii, clear element
			commaLast=1 // comma was the last non-whitespace character
			if( brackLast==0 )
				if(nDims==1)
					w[ii] = bool2num(element)
				else
					w[ii][jj] = bool2num(element)
				endif
				ii+=1
				element="" // clear element
			endif
		elseif( CmpStr(array[i], "[")==0 )
			// open bracket
		elseif( CmpStr(array[i], "]")==0 )
			// close bracket, write element?, incrememnt jj
			if(commaLast==0)
				// no trailing comma, write element, increment ii, clear element
				if(nDims==1)
					w[ii] = bool2num(element)
				else
					w[ii][jj] = bool2num(element)
				endif
				ii+=1
				element="" // no trailing comma, new element
			endif
			jj+=1
			brackLast=1
		else
			element+=array[i] // doesn't matter if I pick up some whitespace here
			if( isWhitespace(array[i])==0 )
				commaLast=0
				brackLast=0
			endif
		endif

	endfor

end

function loadNumArray2wave(array,destwave)
	// works for int or float since igor doesn't make a distinction
	string array,destwave
	string dims = getArrayShape(array), element=""
	variable i=0, commaLast=0, brackLast=0, ii=0, jj=0, nDims = itemsinlist(dims, ",")

	if(nDims==1)
		make/o/n=(str2num(dims)) $destwave
	else
		make/o/n=(str2num(stringfromlist(0,dims,",")), str2num(stringfromlist(1,dims,","))) $destwave
	endif
	wave w=$destwave

	for(i=0; i<strlen(array); i+=1)
		if( CmpStr(array[i], ",")==0 )
			// comma found, write element, increment ii, clear element
			commaLast=1 // comma was the last non-whitespace character
			if( brackLast==0 )
				if(nDims==1)
					w[ii] = str2num(element)
				else
					w[ii][jj] = str2num(element)
				endif
				ii+=1
				element="" // clear element
			endif
		elseif( CmpStr(array[i], "[")==0 )
			// open bracket
		elseif( CmpStr(array[i], "]")==0 )
			// close bracket, incrememnt jj
			if(commaLast==0)
				// no trailing comma, increment ii, write element
				if(nDims==1)
					w[ii] = str2num(element)
				else
					w[ii][jj] = str2num(element)
				endif
				ii+=1
				element="" // no trailing comma, new element
			endif
			jj+=1
			brackLast=1
		else
			element+=array[i] // doesn't matter if I pick up some whitespace here
			if( isWhitespace(array[i])==0 )
				commaLast=0
				brackLast=0
			endif
		endif

	endfor

end

function loadBool2var(boolean,destvar)
	string boolean,destvar

	variable/g $destvar = bool2num(boolean)
end

function loadStr2string(str,deststring)
	string str,deststring

	str = removeLiteralQuotes(str)
	string/g $deststring = unescapeQuotes(str)
end

function loadNum2var(numasstr,destvar)
	string numasstr,destvar

	variable/g $destvar = str2num(numasstr)
end

function bool2Num(str)
	string str
	str = TrimString(str)
	if(StringMatch(LowerStr(str), "true")==1)
		// use string match to ignore whitespace
		return 1
	elseif(StringMatch(LowerStr(str), "false")==1)
		return 0
	else
		return -1
	endif
end

/// write ///

function/s num2numStr(val)
	variable val
	if(numtype(val)!=0)
		return "null"
	else
		return num2str(val, "%.5f")
	endif
end

function/s num2bool(val)
	variable val
	if(val==1)
		return "true"
	elseif(val==0)
		return "false"
	else
		return ""
	endif
end

function/s wave2BoolArray(w)
	// returns an array
	// supports 1d and 2d arrays
	wave w
	string list=""

	// loop over wave
	variable ii, jj, m = dimsize(w, 1), n = dimsize(w, 0)
	if(m==0)
		m=1
	elseif(m>1)
		list+="["
	endif

	for (ii=0; ii<m; ii+=1)
		list += "["
		for(jj=0; jj<n; jj+=1)
   		list+= num2bool(w[jj][ii]) + ","
		endfor
		list = list[0,strlen(list)-2] // remove comma
		list += "],"
	endfor

	list = list[0,strlen(list)-2] // remove comma
	if(m>1)
		list+="]" // add closing bracket in 2d
	endif

	return list
end

function/s wave2NumArray(w)
	// returns an array
	// supports 1d and 2d arrays
	wave w
	string list=""

	// loop over wave
	variable ii, jj, m = dimsize(w, 1), n = dimsize(w, 0)
	if(m==0)
		m=1
	elseif(m>1)
		list+="["
	endif

	for (ii=0; ii<m; ii+=1)
		list += "["
		for(jj=0; jj<n; jj+=1)
   		list+= num2str(w[jj][ii])+","
		endfor
		list = list[0,strlen(list)-2] // remove comma
		list += "],"
	endfor

	list = list[0,strlen(list)-2] // remove comma
	if(m>1)
		list+="]" // add closing bracket in 2d
	endif

	return list
end

function/s textWave2StrArray(w)
	// returns an array and makes sure quotes and commas are parsed correctly.
	// supports 1d and 2d arrays
	wave/t w
	string list=""

	// loop over wave
	variable ii, jj, m = dimsize(w, 1), n = dimsize(w, 0)
	if(m==0)
		m=1
	elseif(m>1)
		list+="["
	endif

	for (ii=0; ii<m; ii+=1)
		list += "["
		for(jj=0; jj<n; jj+=1)
//   		list+="\""+removeWhiteSpace(escapeQuotes(w[jj][ii]))+"\","
   		list+="\""+escapeQuotes(w[jj][ii])+"\","
		endfor
		list = list[0,strlen(list)-2] // remove comma
		list += "],"
	endfor

	list = list[0,strlen(list)-2] // remove comma
	if(m>1)
		list+="]" // add closing bracket in 2d
	endif

	return list
end


function/s get_values(string kwListStr, [int keys, string keydel, string listdel])
	// given a kwListStr, will return only the values. If keys is specified,
	// it will return the keys instead.
	// inputs: 	kwListStr 	-> key - value pair string
	// 			 	keys 			-> set to one to retrieve keys instead of values
	// 			 	keydel 		-> specify key delimiter, default is ":"
	//			 	listdel 		-> specify list delimiter, default is ";"
	// example: 	get_values("A:1,B:4", keys = 1, listdel = ",") -> "A,B"
	
	keys		= paramisDefault(keys) ? 0 : 1
	keydel		= selectString(paramIsDefault(keydel) ,  keydel, ":")
	listdel	= selectString(paramIsDefault(listdel), listdel, ";")
	
	int i, delim
	string kw, keysOrVals = ""
	for(i=0; i<itemsinlist(kwListStr, listdel); i++)
		kw = stringfromlist(i, kwlistStr, listdel)
		delim = strsearch(kw,keydel,0)
		if(!keys)
			kw 				= kw[delim+1, INF]
			keysOrVals	= addlistitem(kw, keysOrVals, listdel, INF)
		else
			kw 				= kw[0, delim-1]
			keysOrVals	= addlistitem(kw, keysOrVals, listdel, INF)
		endif	
	endfor
	
	return keysOrVals
end

function/s TextWavetolist(w)
	// returns an array and makes sure quotes and commas are parsed correctly.
	// supports 1d and 2d arrays
	wave/t w
	string list=""

	// loop over wave
	variable i , n = dimsize(w, 0)

	for (i=0; i<n; i++)
		list += w[i] + ";"

	endfor
	list = list[0,strlen(list)-2] // remove last semicolon
	return list
end

function /s numWavetolist(w)
	// returns an array and makes sure quotes and commas are parsed correctly.
	// supports 1d and 2d arrays
	wave w
	string list=""

	// loop over wave
	variable i , n = dimsize(w, 0)

	for (i=0; i<n; i++)
		list += num2str(w[i]) + ";"
	endfor
	list = list[0,strlen(list)-2] // remove last semicolon
	return list
end

Function ConvertNumWvToTxtWv(W)
Wave W
Make /T /O /N=(numpnts(W)) TxtConvert
TxtConvert[] = num2str(W[p])
End
 
Function ConvertTxtWvToNumWv(W)
Wave /T W
Make /O /N=(numpnts(W)) NumConvert
NumConvert[] = str2num(W[p])
End

function/s addJSONkeyval(JSONstr,key,value,[addquotes])
	// returns a valid JSON string with a new key,value pair added.
	// if JSONstr is empty, start a new JSON object
	string JSONstr, key, value
	variable addquotes
	
	// check value, can't be an empty string
	if(strlen(value)==0)
		value = "null"
	endif

	if(!paramisdefault(addquotes))
		if(addquotes==1)
			// escape quotes in value and wrap value in outer quotes
			value = "\""+escapeQuotes(value)+"\""
		endif
	endif
	
	if(strlen(JSONstr)!=0)
		// remove all starting brackets, whitespace or plus signs
		variable i=0
		do
			if((isWhitespace(JSONstr[i])==1) || (CmpStr(JSONstr[i],"{")==0) || (CmpStr(JSONstr[i],"+")==0))
				i+=1
			else
				break
			endif
		while(1)

		// remove single ending bracket + whitespace
		variable j=strlen(JSONstr)-1
		do
			if((isWhitespace(JSONstr[j])==1))
				j-=1
			elseif((CmpStr(JSONstr[j],"}")==0))
				j-=1
				break
			else
				print "[ERROR] Bad JSON string in addJSONkeyvalue(...): "+JSONstr
				break
			endif
		while(1)

		return "{"+JSONstr[i,j]+", \""+key+"\":"+value+"}"
	else
		return "{"+JSONstr[i,j]+"\""+key+"\":"+value+"}"
	endif

end

//function /S escapeQuotes(str)
//	string str
//
//	variable i=0, escaped=0
//	string output = ""
//	do
//
//		if(i>strlen(str)-1)
//			break
//		endif
//
//		// check if the current character is escaped
//		if(i!=0)
//			if( CmpStr(str[i-1], "\\") == 0)
//				escaped = 1
//			else
//				escaped = 0
//			endif
//		endif
//
//		// escape quotes
//		if( CmpStr(str[i], "\"" ) == 0 && escaped == 0)
//			// this is an unescaped quote
//			str = str[0,i-1] + "\\" + str[i,inf]
//		endif
//		i+=1
//
//	while(1)
//	return str
//end


//Function/S addJSONkeyval(JSONstr, key, value, [addquotes])
//    String JSONstr, key, value
//    Variable addquotes
//    
//    // Check if key is null
//    if(strlen(key) == 0)
//        printf "Error: Key is null or empty.\n"
//        return JSONstr  // Optionally, return the unmodified JSON string or handle the error differently
//    endif
//
//	// Escape quotes in key since it's always treated as a string
//	key = escapeQuotes(key)
//
//	// Check if the value is to be added as a string
//	if(!ParamIsDefault(addquotes) && addquotes == 1)
//		// Escape quotes in value and wrap value in outer quotes
//		value = "\"" + escapeQuotes(value) + "\""
//	ElseIf(strlen(value) == 0)  // If value is an empty string, treat it as null
//		value = "null"
//		// No else case needed here; if addquotes is 0 or not provided, value is treated as numeric or boolean
//
//		if(strlen(JSONstr) != 0)
//			// Existing JSON object; prepare to append
//			// Trim leading '{' and trailing '}' to prepare for appending
//			JSONstr = ReplaceString("{", JSONstr, "")
//			JSONstr = ReplaceString("}", JSONstr, "")
//			JSONstr = TrimString(JSONstr) // Trim both leading and trailing whitespace
//
//			// Append new key-value pair
//			return "{" + JSONstr + ", \"" + key + "\":" + value + "}"
//		else
//			// New JSON object
//			return "{\"" + key + "\":" + value + "}"
//		endif
//		endif
//End
//
Function/S escapeQuotes(str)
    // Helper function to escape quotes within a string
    String str
    return ReplaceString("\"", str, "\\\"")
End


function/s getIndent(level)
	// returning whitespace for formatting strings
	// level = # of tabs, 1 tab = 4 spaces
	variable level

	variable i=0
	string output = ""
	for(i=0;i<level;i+=1)
		output += "    "
	endfor

	return output
end

function /s prettyJSONfmt(jstr)
	// this could be much prettier
	string jstr
	string output="", key="", val=""
	
	// Force Igor to clear out this before calling JSONSimple because JSONSimple does sort of work, but throws an error which prevents it from clearing out whatever was left in from the last call
	make/o/T t_tokentext = {""}  

	JSONSimple/z jstr
	wave w_tokentype, w_tokensize, w_tokenparent
	variable i=0, indent=1
	
	// Because JSONSimple is awful, it leaves a random number of empty cells at the end sometimes. So remove them
	FindValue /TEXT="" t_tokentext
	Redimension/N=(V_row) t_tokentext


	output+="{\n"
	for(i=1;i<numpnts(t_tokentext)-1;i+=1)

		// print only at single indent level
		if ( w_tokentype[i]==3 && w_tokensize[i]>0 )
			if( w_tokenparent[i]==0 )
				indent = 1
				if( w_tokentype[i+1]==3 )
					val = "\"" + t_tokentext[i+1] + "\""
				else
					val = t_tokentext[i+1]
				endif
				key = "\"" + t_tokentext[i] + "\""
				output+=(getIndent(indent)+key+": "+val+",\n")
			endif
		endif
	endfor

	return output[0,strlen(output)-3]+"\n}\n"
end

/////////////////////////////////
/// text formatting utilities ///
/////////////////////////////////

Function isWhiteSpace(char)
    String char

    return GrepString(char, "\\s")
End

Function/S removeLeadingWhitespace(str)
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


function/S removeSeperator(str, sep)
	string str, sep
	if (strlen(str) == 0)
        return ""
   endif
    
   do
   		String lastChar = str[strlen(str) - 1]
       if (!cmpstr(lastChar, sep))
       	str = str[0, strlen(str) - 2]
       else
        	break
       endif
   while (strlen(str) > 0)
   
   do
   		String firstChar= str[0]
      	if (!cmpstr(firstChar, sep))
       	str= str[1,inf]
      	else
         	break
      	endif
   while (strlen(str) > 0)
   
   return str

end 

Function/S FormatListItems(listString)
    String listString
    Variable i, numItems
    String result, currentItem


    // Split and process each item
    numItems = ItemsInList(listString, ";")
    result = ""  // Initialize the result string

    for(i = 0; i < numItems; i += 1)
        currentItem = StringFromList(i, listString)
        //print currentItem
        if(strlen(currentItem) > 0)
            if(strlen(result) > 0)
                result += ","  // Add comma before adding the next item
            endif
            result += "\"" + TrimString(currentItem) + "\""  // Add quotes and handle any space trimming
        endif
    endfor

    return result
End


//Function/S TrimString(str)
//    String str
//    // Trim leading and trailing white spaces
//    return RemoveEnding(str, " ")
//End



function/S removeTrailingWhitespace(str)
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

function/s removeWhiteSpace(str)
	// Remove leading or trailing whitespace
	string str
	str = removeLeadingWhitespace(str)
	str = removeTrailingWhitespace(str)
	return str
end

function countQuotes(str)
	// count how many quotes are in the string
	// +1 for "
	// escaped quotes are ignored
	string str
	variable quoteCount = 0, i = 0, escaped = 0
	for(i=0; i<strlen(str); i+=1)

		// check if the current character is escaped
		if(i!=0)
			if( CmpStr(str[i-1], "\\") == 0)
				escaped = 1
			else
				escaped = 0
			endif
		endif

		// count quotes
		if( CmpStr(str[i], "\"" ) == 0 && escaped == 0)
			quoteCount += 1
		endif

	endfor
	return quoteCount
end

function /S unescapeQuotes(str)
	string str

	variable i=0, escaped=0
	string output = ""
	do

		if(i>strlen(str)-1)
			break
		endif

		// check if the current character is escaped
		if(i!=0)
			if( CmpStr(str[i-1], "\\") == 0)
				escaped = 1
			else
				escaped = 0
			endif
		endif

		// escape quotes
		if( CmpStr(str[i], "\"" ) == 0 && escaped == 1)
			// this is an unescaped quote
			str = str[0,i-2] + str[i,inf]
		endif
		i+=1

	while(1==1)
	return str
end

function/s removeLiteralQuotes(str)
	// removes single outermost quotes
	// double quotes only
	string str

	variable i=0, openQuotes=0
	for(i=0;i<strlen(str);i+=1)
		if(CmpStr(str[i],"\"")==0)
			openQuotes+=1
		endif

		if(openQuotes>0 && CmpStr(str[i],"\"")!=0)
			break
		endif
	endfor

	if(openQuotes==0)
		print "[ERROR] String not surrounded by quotes. str: "+str
		return ""
	elseif(openQuotes==2)
		openQuotes=1
	elseif(openQuotes>3)
		openQuotes=3
	endif

	str = str[i,inf]
	variable j, closeQuotes=0
	for(j=strlen(str); j>0; j-=1)

		if(CmpStr(str[j],"\"")==0)
			closeQuotes+=1
		endif

		if(closeQuotes==openQuotes)
			break
		endif

	endfor

	return str[0,j-1]
end

function/t removeStringListDuplicates(theListStr)
	// credit: http://www.igorexchange.com/node/1071
	String theListStr

	String retStr = ""
	variable ii
	for(ii = 0 ; ii < itemsinlist(theListStr) ; ii+=1)
		if(whichlistitem(stringfromlist(ii , theListStr), retStr) == -1)
			retStr = addlistitem(stringfromlist(ii, theListStr), retStr, ";", inf)
		endif
	endfor
	return retStr
End

function/s searchFullString(string_to_search,substring)
	string string_to_search, substring
	string index_list=""
	variable test, startpoint=0

	do
		test = strsearch(string_to_search, substring, startpoint)
		if(test != -1)
			index_list = index_list+num2istr(test)+","
			startpoint = test+1
		endif
	while(test > -1)

	return index_list
end

