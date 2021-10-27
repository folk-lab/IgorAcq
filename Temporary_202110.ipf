///// Aim for data saving/plotting 




////////////////////////////////////////////////////////////////////
///////////////////////////// Save Waves ///////////////////////////
////////////////////////////////////////////////////////////////////

// function RenameSaveWaves([msg,save_experiment,fastdac, wave_names])
// 	// the message will be printed in the history, and will be saved in the HDF file corresponding to this scan
// 	// save_experiment=1 to save the experiment file
// 	// Use wave_names to manually save comma separated waves in HDF file with sweeplogs etc.
// 	string msg, wave_names
// 	variable save_experiment, fastdac
// 	string his_str
// 	nvar sc_is2d, sc_PrintRaw, sc_PrintCalc, sc_scanstarttime
// 	svar sc_x_label, sc_y_label
// 	string filename, wn, logs=""
// 	nvar filenum
// 	string filenumstr = ""
// 	sprintf filenumstr, "%d", filenum
// 	wave /t sc_RawWaveNames, sc_CalcWaveNames
// 	wave sc_RawRecord, sc_CalcRecord
// 	variable filecount = 0

// 	variable save_type = 0

// 	if (!paramisdefault(msg))
// 		print msg
// 	else
// 		msg=""
// 	endif

// 	save_type = 0
// 	if(!paramisdefault(fastdac) && !paramisdefault(wave_names))
// 		abort "ERROR[SaveWaves]: Can only save FastDAC waves OR wave_names, not both at same time"
// 	elseif(fastdac == 1)
// 		save_type = 1  // Save Fastdac_ScanController waves
// 	elseif(!paramisDefault(wave_names))
// 		save_type = 2  // Save given wave_names ONLY
// 	else
// 		save_type = 0  // Save normal ScanController waves
// 	endif


// 	// compare to earlier call of InitializeWaves
// 	nvar fastdac_init
// 	if(fastdac > fastdac_init && save_type != 2)
// 		print("[ERROR] \"SaveWaves\": Trying to save fastDAC files, but they weren't initialized by \"InitializeWaves\"")
// 		abort
// 	elseif(fastdac < fastdac_init  && save_type != 2)
// 		print("[ERROR] \"SaveWaves\": Trying to save non-fastDAC files, but they weren't initialized by \"InitializeWaves\"")
// 		abort
// 	endif

// 	nvar sc_save_time
// 	if (paramisdefault(save_experiment))
// 		save_experiment = 1 // save the experiment by default
// 	endif


// 	KillDataFolder/z root:async // clean this up for next time

// 	if(save_type != 2)
// 		// save timing variables
// 		variable /g sweep_t_elapsed = datetime-sc_scanstarttime
// 		printf "Time elapsed: %.2f s \r", sweep_t_elapsed
// 		dowindow/k SweepControl // kill scan control window
// 	else
// 		variable /g sweep_t_elapsed = 0
// 	endif

// 	// count up the number of data files to save
// 	variable ii=0
// 	if(save_type == 0)
// 		// normal non-fastdac files
// 		variable Rawadd = sum(sc_RawRecord)
// 		variable Calcadd = sum(sc_CalcRecord)

// 		if(Rawadd+Calcadd > 0)
// 			// there is data to save!
// 			// save it and increment the filenumber
// 			printf "saving all dat%d files...\r", filenum

// 			nvar sc_rvt
// 	   		if(sc_rvt==1)
// 	   			sc_update_xdata() // update xdata wave
// 			endif

// 			// Open up HDF5 files
// 		 	// Save scan controller meta data in this function as well
// 			initSaveFiles(msg=msg)
// 			if(sc_is2d == 2) //If 2D linecut then need to save starting x values for each row of data
// 				wave sc_linestart
// 				filename = "dat" + filenumstr + "linestart"
// 				duplicate sc_linestart $filename
// 				savesinglewave("sc_linestart")
// 			endif
// 			// save raw data waves
// 			ii=0
// 			do
// 				if (sc_RawRecord[ii] == 1)
// 					wn = sc_RawWaveNames[ii]
// 					if (sc_is2d)
// 						wn += "2d"
// 					endif
// 					filename =  "dat" + filenumstr + wn
// 					duplicate $wn $filename // filename is a new wavename and will become <filename.xxx>
// 					if(sc_PrintRaw == 1)
// 						print filename
// 					endif
// 					saveSingleWave(wn)
// 				endif
// 				ii+=1
// 			while (ii < numpnts(sc_RawWaveNames))

// 			//save calculated data waves
// 			ii=0
// 			do
// 				if (sc_CalcRecord[ii] == 1)
// 					wn = sc_CalcWaveNames[ii]
// 					if (sc_is2d)
// 						wn += "2d"
// 					endif
// 					filename =  "dat" + filenumstr + wn
// 					duplicate $wn $filename
// 					if(sc_PrintCalc == 1)
// 						print filename
// 					endif
// 					saveSingleWave(wn)
// 				endif
// 				ii+=1
// 			while (ii < numpnts(sc_CalcWaveNames))
// 			closeSaveFiles()
// 		endif
// 	// Save Fastdac waves
// 	elseif(save_type == 1)
// 		wave/t fadcvalstr
// 		wave fadcattr
// 		string wn_raw = ""
// 		nvar sc_Printfadc
// 		nvar sc_Saverawfadc

// 		ii=0
// 		do
// 			if(fadcattr[ii][2] == 48)
// 				filecount += 1
// 			endif
// 			ii+=1
// 		while(ii<dimsize(fadcattr,0))

// 		if(filecount > 0)
// 			// there is data to save!
// 			// save it and increment the filenumber
// 			printf "saving all dat%d files...\r", filenum

// 			// Open up HDF5 files
// 			// Save scan controller meta data in this function as well
// 			initSaveFiles(msg=msg)

// 			// look for waves to save
// 			ii=0
// 			string str_2d = "", savename
// 			do
// 				if(fadcattr[ii][2] == 48) //checkbox checked
// 					wn = fadcvalstr[ii][3]
// 					if(sc_is2d)
// 						wn += "_2d"
// 					endif
// 					filename = "dat"+filenumstr+wn

// 					duplicate $wn $filename

// 					if(sc_Printfadc)
// 						print filename
// 					endif
// 					saveSingleWave(wn)

// 					if(sc_Saverawfadc)
// 						str_2d = ""  // Set 2d_str blank until check if sc_is2d
// 						wn_raw = "ADC"+num2istr(ii)
// 						if(sc_is2d)
// 							wn_raw += "_2d"
// 							str_2d = "_2d"  // Need to add _2d to name if wave is 2d only.
// 						endif
// 						filename = "dat"+filenumstr+fadcvalstr[ii][3]+str_2d+"_RAW"  // More easily identify which Raw wave for which Calc wave
// 						savename = fadcvalstr[ii][3]+str_2d+"_RAW"


// 						duplicate $wn_raw $filename


// 						duplicate/O $wn_raw $savename  // To store in HDF with more easily identifiable name
// 						if(sc_Printfadc)
// 							print filename
// 						endif
// 						saveSingleWave(savename)
// 					endif
// 				endif
// 				ii+=1
// 			while(ii<dimsize(fadcattr,0))
// 			closeSaveFiles()
// 		endif
// 	elseif(save_type == 2)
// 		// Check that all waves trying to save exist
// 		for(ii=0;ii<itemsinlist(wave_names, ",");ii++)
// 			wn = stringfromlist(ii, wave_names, ",")
// 			if (!exists(wn))
// 				string err_msg
// 				sprintf err_msg, "WARNING[SaveWaves]: Wavename %s does not exist. No data saved\r", wn
// 				abort err_msg
// 			endif
// 		endfor

// 		// Only init Save file after we know that the waves exist
// 		initSaveFiles(msg=msg, logs_only=1)
// 		printf "Saving waves [%s] in dat%d.h5\r", wave_names, filenum

// 		// Now save each wave
// 		for(ii=0;ii<itemsinlist(wave_names, ",");ii++)
// 			wn = stringfromlist(ii, wave_names, ",")
// 			saveSingleWave(wn)
// 		endfor
// 		closeSaveFiles()
// 	endif

// 	if(save_experiment==1 & (datetime-sc_save_time)>180.0)
// 		// save if sc_save_exp=1
// 		// and if more than 3 minutes has elapsed since previous saveExp
// 		// if the sweep was aborted sc_save_exp=0 before you get here
// 		saveExp()
// 		sc_save_time = datetime
// 	endif

// 	// check if a path is defined to backup data
// 	if(sc_checkBackup())
// 		// copy data to server mount point
// 		sc_copyNewFiles(filenum, save_experiment=save_experiment)
// 	endif

// 	// add info about scan to the scan history file in /config
// //	sc_saveFuncCall(getrtstackinfo(2))

// 	// delete waves old waves, so only the newest 500 scans are stored in volatile memory
// 	// turn on by setting sc_cleanup = 1
// //	nvar sc_cleanup
// //	if(sc_cleanup == 1)
// //		sc_cleanVolatileMemory()
// //	endif

// 	// increment filenum
// 	if(Rawadd+Calcadd > 0 || filecount > 0  || save_type == 2)
// 		filenum+=1
// 	endif
// end

////////////////////////////////////////////////////////////////////
///////////// Johanns attempt at breaking down savewaves()//////////
////////////////////////////////////////////////////////////////////

function EndScan([S, save_experiment, aborting])
	// Ends a scan:
	// Closes sweepcontrol if open
	// Save Metadata into HDF files
	// Saves Measured data into HDF files
	// Saves experiment

	Struct ScanVars &S
	variable save_experiment
	variable aborting
	
	nvar filenum

	save_experiment = paramisDefault(save_experiment) ? 1 : save_experiment
	if (aborting)
		print "ERROR[EndScan]: Abort and save not implemented yet. Expect undefined behaviour"
	endif

	if(paramIsDefault(S))
		abort "Not implemented yet"
		// Also should leave a message or something in the HDF that indicates scan was aborted! 
		loadLastScanVarsStruct(S)
	else
		saveAsLastScanVarsStruct(S)
	endif

	dowindow/k SweepControl // kill scan control window
	printf "Time elapsed: %.2f s \r", (S.end_time-S.start_time)
	HDF5CloseFile/A 0 //Make sure any previously opened HDFs are closed (may be left open if Igor crashes)
	
	if(S.using_fastdac == 0)
		KillDataFolder/z root:async // clean this up for next time
		SaveToHDF(S, 0)
	elseif(S.using_fastdac == 1)
		SaveToHDF(S, 1)
	else
		abort "Don't understant S.using_fastdac != (1 | 0)"
	endif

	nvar sc_save_time
	if(save_experiment==1 & (datetime-sc_save_time)>180.0)
		// save if sc_save_exp=1
		// and if more than 3 minutes has elapsed since previous saveExp
		saveExp()
		sc_save_time = datetime
	endif

	if(sc_checkBackup())  	// check if a path is defined to backup data
		sc_copyNewFiles(filenum, save_experiment=save_experiment)		// copy data to server mount point
	endif

	// add info about scan to the scan history file in /config
	//	sc_saveFuncCall(getrtstackinfo(2))

	filenum+=1
end

function loadLastScanVarsStruct(S)
	Struct ScanVars &S
	// TODO: Make these (note: can't just use StructPut/Get because they only work for numeric entries, not strings...
end
	
function saveAsLastScanVarsStruct(S)
	Struct ScanVars &S
	// TODO: Make these (note: can't just use StructPut/Get because they only work for numeric entries, not strings...
end

function saveType(fastdac, wave_names)
   string wave_names
	variable fastdac
	variable save_type = 0

	if(fastdac && strlen(wave_names) > 0)
		abort "ERROR[SaveWaves]: Can only save FastDAC waves OR wave_names, not both at same time"
	endif
	if(fastdac == 1)
		save_type = 1  // Save Fastdac_ScanController waves
	elseif(strlen(wave_names) > 0)
		save_type = 2  // Save given wave_names ONLY
	else
		save_type = 0  // Save normal ScanController waves
	endif

	return save_type
end




// FastDac Save Function
function SaveToHDF(S, fastdac)
	Struct ScanVars &S
	variable fastdac
	
	nvar filenum
	printf "saving all dat%d files...\r", filenum

	nvar/z sc_Saverawfadc
	
	// Open up HDF5 files
	variable raw_hdf5_id, calc_hdf5_id
	calc_hdf5_id = initOpenSaveFiles(0)
	string hdfids = num2str(calc_hdf5_id)
	if (fastdac && sc_Saverawfadc == 1)
		raw_hdf5_id = initOpenSaveFiles(1)
		hdfids = addlistItem(num2str(raw_hdf5_id), hdfids, ";", INF)
	endif
	
	// add Meta data to each file
	addMetaFiles(hdfids, S=S)
	
	if (fastdac)
		// Save some fastdac specific waves (sweepgates etc)
		saveFastdacInfoWaves(hdfids, S)
	endif

	// Save ScanWaves (e.g. x_array, y_array etc)
	if(fastdac)
		nvar sc_resampleFreqCheckFadc
		saveScanWaves(calc_hdf5_id, S, sc_resampleFreqCheckFadc)  // Needs a different x_array size if filtered
		if (Sc_saveRawFadc == 1)
			saveScanWaves(raw_hdf5_id, S, 0)
		endif
	else
		saveScanWaves(calc_hdf5_id, S, 0)
	endif
	
	// Get waveList to save
	string RawWaves, CalcWaves
	if(S.is2d == 0)
		RawWaves = get1DWaveNames(1, fastdac)
		CalcWaves = get1DWaveNames(0, fastdac)
	elseif (S.is2d == 1)
		RawWaves = get2DWaveNames(1, fastdac)
		CalcWaves = get2DWaveNames(0, fastdac)
	else
		abort "Not implemented"
	endif
	
	// Copy waves in Experiment
	createWavesCopyIgor(CalcWaves)
	
	// Save to HDF	
	saveWavesToHDF(CalcWaves, calc_hdf5_id)
	if(fastdac && sc_SaveRawFadc == 1)
		string rawSaveNames = getRawSaveNames(CalcWaves)
		SaveWavesToHDF(RawWaves, raw_hdf5_id, saveNames=rawSaveNames)
	endif
	initcloseSaveFiles(hdfids) // close all files
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
	
	if (S.is2d)  // Also Y info
		make/o/N=(3, itemsinlist(s.channelsy, ",")) sweepgates_y = 0
		for (i=0; i<itemsinlist(s.channelsy, ","); i++)
			sweepgates_y[0][i] = str2num(stringfromList(i, s.channelsy, ","))
			sweepgates_y[1][i] = str2num(stringfromlist(i, s.startys, ","))
			sweepgates_y[2][i] = str2num(stringfromlist(i, s.finys, ","))
		endfor
	else
		make/o sweepgates_y = {{NaN, NaN, NaN}}
	endif
	
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
	jstr = new_sc_createSweepLogs(comments=comments)
	// TODO: Save this jstr into HDF
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

function saveWavesToHDF(wavesList, hdfID, [saveNames])
	string wavesList, saveNames
	variable hdfID
	
	saveNames = selectString(paramIsDefault(saveNames), saveNames, wavesList)
	
	variable i	
	string wn, saveName
	for (i=0; i<itemsInList(wavesList); i++)
		wn = stringFromList(i, wavesList)
		saveName = stringFromList(i, saveNames)
		initSaveSingleWave(wn, hdfID, saveName=saveName)
	endfor
end

function createWavesCopyIgor(wavesList, [saveNames])
	// Duplicate each wave with prefix datXXX so that it's easily accessible in Igor
	string wavesList, saveNames

	saveNames = selectString(paramIsDefault(saveNames), saveNames, wavesList)	
	
	nvar filenum
	string filenumstr = num2str(filenum)
		
	variable i	
	string wn, saveName
	for (i=0; i<itemsInList(wavesList); i++)
		wn = stringFromList(i, wavesList)
		saveName = stringFromList(i, saveNames)
		saveName = "dat"+filenumstr+saveName
		duplicate $wn $saveName
	endfor
end


function SaveNamedWaves(wave_names, comments)
	// Saves a comma separated list of wave_names to HDF under DatXXX.h5
	string wave_names, comments
	
	nvar filenum

	variable ii=0
	string wn
	// Check that all waves trying to save exist
	for(ii=0;ii<itemsinlist(wave_names, ",");ii++)
		wn = stringfromlist(ii, wave_names, ",")
		if (!exists(wn))
			string err_msg
			sprintf err_msg, "WARNING[SaveWaves]: Wavename %s does not exist. No data saved\r", wn
			abort err_msg
		endif
	endfor

	// Only init Save file after we know that the waves exist
	variable hdfid
	hdfid = initOpenSaveFiles(0) // Open HDF file (normal - non RAW)
	LogsOnlySave(hdfid, comments)

//	initSaveFiles(msg=comments, logs_only=1)
	printf "Saving waves [%s] in dat%d.h5\r", wave_names, filenum

	// Now save each wave
	for(ii=0;ii<itemsinlist(wave_names, ",");ii++)
		wn = stringfromlist(ii, wave_names, ",")
		saveSingleWave(wn)
	endfor
	closeSaveFiles()
end


//// Non FastDac Save Function
//function NonFastDacSave(msg)
//	string msg
//	wave/t fadcvalstr
//	wave fadcattr
//	string wn_raw = ""
//	nvar sc_Printfadc
//	nvar sc_Saverawfadc
//	nvar sc_is2d, sc_PrintCalc
//	nvar filenum
//	string filenumstr = ""
//	sprintf filenumstr, "%d", filenum
//	variable filecount = 0
//	variable ii=0, sc_PrintRaw
//	string wn, filename
//	wave /t sc_RawWaveNames, sc_CalcWaveNames
//	wave sc_RawRecord, sc_CalcRecord
//	
//	variable Rawadd = sum(sc_RawRecord)
//	variable Calcadd = sum(sc_CalcRecord)
//
//	if(Rawadd+Calcadd > 0)
//		// there is data to save!
//		// save it and increment the filenumber
//		printf "saving all dat%d files...\r", filenum
//
//		nvar sc_rvt
//   		if(sc_rvt==1)
//   			sc_update_xdata() // update xdata wave
//		endif
//
//		// Open up HDF5 files
//	 	// Save scan controller meta data in this function as well
//		initSaveFiles(msg=msg)
//		if(sc_is2d == 2) //If 2D linecut then need to save starting x values for each row of data
//			wave sc_linestart
//			filename = "dat" + filenumstr + "linestart"
//			duplicate sc_linestart $filename
//			savesinglewave("sc_linestart")
//		endif
//		
////		wave arb_wavename
////		arb_wavename = (condition) ? case_true : case_false
////		sc_PrintRaw == 1 && print()
//		
//		// save raw data waves
//		ii=0
//		do
//			if (sc_RawRecord[ii] == 1)
//				wn = sc_RawWaveNames[ii]
//				if (sc_is2d)
//					wn += "2d"
//				endif
//				filename =  "dat" + filenumstr + wn
//				duplicate $wn $filename // filename is a new wavename and will become <filename.xxx>
//				if(sc_PrintRaw == 1)
//					print filename
//				endif
//				saveSingleWave(wn)
//			endif
//			ii+=1
//		while (ii < numpnts(sc_RawWaveNames))
//
//		//save calculated data waves
//		ii=0
//		do
//			if (sc_CalcRecord[ii] == 1)
//				wn = sc_CalcWaveNames[ii]
//				if (sc_is2d)
//					wn += "2d"
//				endif
//				filename =  "dat" + filenumstr + wn
//				duplicate $wn $filename
//				if(sc_PrintCalc == 1)
//					print filename
//				endif
//				saveSingleWave(wn)
//			endif
//			ii+=1
//		while (ii < numpnts(sc_CalcWaveNames))
//		closeSaveFiles()
//	endif
//end


function initOpenSaveFiles(RawSave)	
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


function addMetaFiles(hdf5_id_list, [S, logs_only])
	// meta data is created and added to the files in list
	string hdf5_id_list
	Struct ScanVars &S
	variable logs_only  // 1=Don't save any data to HDF
	
	make /FREE /T /N=1 cconfig = prettyJSONfmt(sc_createconfig())
	make /FREE /T /N=1 sweep_logs = prettyJSONfmt(new_sc_createSweepLogs(S=S))
	
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
		
		HDF5SaveData/z /A="sc_config" cconfig, hdf5_id, "metadata"
		if (V_flag != 0)
				Print "HDF5SaveData Failed: ", "sc_config"
		endif

		HDF5CloseGroup /Z meta_group_id
		if (V_flag != 0)
			Print "HDF5CloseGroup Failed: ", "metadata"
		endif

		// may as well save this config file, since we already have it
		sc_saveConfig(cconfig[0])
		
	endfor
end


function saveScanWaves(hdfid, S, filtered)
	// Save x_array and y_array in HDF 
	// Note: The x_array will have the right dimensions taking into account filtering
	variable hdfid
	Struct ScanVars &S
	variable filtered


	if(filtered)
		make/o/free/N=(postFilterNumpts(S.numptsx, S.measureFreq)) sc_xarray
	else
		make/o/free/N=(S.numptsx) sc_xarray
	endif

	string cmd
	setscale/I x S.startx, S.finx, sc_xarray
	// cmd = "setscale/I x " + num2str(S.startx) + ", " + num2str(S.finx) + ", \"\", " + "sc_xdata"; execute(cmd)
	// cmd = "sc_xdata" +" = x"; execute(cmd)
	HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 sc_xarray, hdfid, "x_array"

	if (S.is2d)
		make/o/free/N=(S.numptsy) sc_yarray
		
		setscale/I x S.starty, S.finy, sc_yarray
		// cmd = "setscale/I x " + num2str(S.starty) + ", " + num2str(S.finy) + ", \"\", " + "sc_ydata"; execute(cmd)
		// cmd = "sc_ydata" +" = x"; execute(cmd)
		HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 sc_yarray, hdfid, "y_array"
	endif

	// save x and y arrays
	if(S.is2d == 2)
		abort "Not implemented again yet, need to figure out how/where to get linestarts from"
		HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 $"sc_linestart", hdfid, "linestart"
	endif
end


function initSaveSingleWave(wn, hdf5_id, [saveName])
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


///////////// Commented out h5name warning ////////////
///////////// remember to add back in ///////////////////
function initcloseSaveFiles(hdf5_id_list)
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


function resampleWaves(w, measureFreq, targetFreq)
	// takes a list of wave names and resamples each, from measureFreq
	// to targetFreq (which should be lower than measureFreq)
	Wave w
	variable measureFreq, targetFreq
	
	RatioFromNumber (targetFreq / measureFreq)
	resample/UP=(V_numerator)/DOWN=(V_denominator)/N=101 w
  		// TODO: Need to test N more (simple testing suggests we may need >200 in some cases!)
  		// TODO: Need to decide what to do with end effect. Possibly /E=2 (set edges to 0) and then turn those zeros to NaNs? 
  		// TODO: Or maybe /E=3 is safest (repeat edges). The default /E=0 (bounce) is awful.


end

////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////



function NEW_fd_record_values(S, rowNum, [AWG_list, linestart])
	struct ScanVars &S
	variable rowNum, linestart
	struct fdAWG_list &AWG_list
	// If passed AWG_list with AWG_list.use_AWG == 1 then it will run with the Arbitrary Wave Generator on
	// Note: Only works for 1 FastDAC! Not sure what implementation will look like for multiple yet

	// Check if AWG_list passed with use_AWG = 1
	variable/g sc_AWG_used = 0  // Global so that this can be used in SaveWaves() to save AWG info if used
	if(!paramisdefault(AWG_list) && AWG_list.use_AWG == 1)  // TODO: Does this work?
		sc_AWG_used = 1
		if(rowNum == 0)
			print "fd_Record_Values: Using AWG"
		endif
	endif

	// Check if this is a linecut scan and update centers if it is
	if(!paramIsDefault(linestart))
		wave sc_linestart
		sc_linestart[rowNum] = linestart
	endif

	if (rowNum == 0 && S.start_time == 0)
		S.start_time = datetime
	endif


   // Check that checks have been carried out in main scan function where they belong
	if(S.lims_checked != 1)
	 	abort "ERROR[fd_record_values]: FD_ScanVars.lims_checked != 1. Probably called before limits/ramprates/sweeprates have been checked in the main Scan Function!"
	endif

   	// Check that DACs are at start of ramp (will set if necessary but will give warning if it needs to)
	fdRV_check_ramp_start(S)

	// Send command and read values
	fdRV_send_command_and_read(S, AWG_list, rowNum) 
	S.end_time = datetime  
	
	// Process 1D read and distribute
	fdRV_process_and_distribute(S, AWG_list, rowNum) 
	
	// // check abort/pause status
	// fdRV_check_sweepstate(S.instrID)
	// return looptime
end

function fdRV_send_command_and_read(ScanVars, AWG_list, rowNum)
	// Send 1D Sweep command to fastdac and record the raw data it returns ONLY
	struct ScanVars &ScanVars
	struct fdAWG_list &AWG_list
	variable rowNum
	string cmd_sent = ""
	variable totalByteReturn
	nvar sc_AWG_used
	if(sc_AWG_used)  	// Do AWG_RAMP
	   cmd_sent = fd_start_AWG_RAMP(ScanVars, AWG_list)
	else				// DO normal INT_RAMP  
		cmd_sent = fd_start_INT_RAMP(ScanVars)
	endif
	
	totalByteReturn = ScanVars.numADCs*2*ScanVars.numptsx
	sc_sleep(0.1) 	// Trying to get 0.2s of data per loop, will timeout on first loop without a bit of a wait first
	variable looptime = 0
   looptime = fdRV_record_buffer(ScanVars, rowNum, totalByteReturn)
	
   // update window
	string endstr
	endstr = readInstr(ScanVars.instrID)
	endstr = sc_stripTermination(endstr,"\r\n")
	if(fdacCheckResponse(endstr,cmd_sent,isString=1,expectedResponse="RAMP_FINISHED"))
		fdRV_update_window(ScanVars, ScanVars.numADCs)  /// TODO: Check this isn't slow
		if(sc_AWG_used)  // Reset AWs back to zero (I don't see any reason the user would want them left at the final position of the AW)
			rampmultiplefdac(ScanVars.instrID, AWG_list.AW_DACs, 0)
		endif
	endif

	// fdRV_check_sweepstate(S.instrID)
end


function fdRV_process_and_distribute(ScanVars, AWG_list, rowNum)
	// Get 1D wave names, duplicate each wave then resample and copy into calc wave (and do calc string)
	struct ScanVars &ScanVars
	struct fdAWG_list &AWG_list
	variable rowNum
		
	// Get all raw 1D wave names in a list
	string RawWaveNames1D = get1DWaveNames(1, 1)
	string CalcWaveNames1D = get1DwaveNames(0, 1)
	string CalcStrings = getRecordedFastdacInfo("calc_funcs")
	if (itemsinList(RawWaveNames1D) != itemsinList(CalCWaveNames1D))
		abort "Different number of raw wave names compared to calc wave names"
	endif

	nvar sc_ResampleFreqCheckfadc
	nvar sc_ResampleFreqfadc
	
	variable i = 0
	string rwn, cwn
	string calc_string
	for (i=0; i<itemsinlist(RawWaveNames1D); i++)
		rwn = StringFromList(i, RawWaveNames1D)
		cwn = StringFromList(i, CalcWaveNames1D)		
		calc_string = StringFromList(i, CalcStrings)
		duplicate/o $rwn sc_tempwave
	
		if (sc_ResampleFreqCheckfadc != 0)
			resampleWaves(sc_tempwave, ScanVars.measureFreq, sc_ResampleFreqfadc)
		endif
		calc_string = ReplaceString(rwn, calc_string, "sc_tempwave")
		
		execute("sc_tempwave ="+calc_string)
		execute(cwn+" = sc_tempwave")
		
		if (ScanVars.is2d)
			cwn = cwn+"_2d"
			wave w = $cwn
			w[][rowNum] = sc_tempwave[p]		
		endif
	endfor	
	doupdate // Update all the graphs with their new data
end
