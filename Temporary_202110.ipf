///// Aim for data saving/plotting 

function test_scan_2d(fdID, startx, finx, channelsx, starty, finy, channelsy, numptsy, [numpts, sweeprate, rampratex, rampratey, delayy, comments])
	variable fdID, startx, finx, starty, finy, numptsy, numpts, sweeprate, rampratex, rampratey, delayy
	string channelsx, channelsy, comments
	// TODO: Add an input to the ScanControllerFastDAC with a Lowpass filter cutoff and a tickbox

	// Set defaults
	nvar fd_ramprate  // Default to use for all fd ramps
	rampratex = paramisdefault(rampratex) ? fd_ramprate : rampratex
	rampratey = ParamIsDefault(rampratey) ? fd_ramprate : rampratey
	delayy = ParamIsDefault(delayy) ? 0.01 : delayy
	comments = selectstring(paramisdefault(comments), comments, "")

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Put info into scanVars struct (to more easily pass around later)
 	struct FD_ScanVars Fsv
	SF_init_FDscanVars(Fsv, fdID, startx, finx, channelsx, numpts, rampratex, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
	   						 starty=starty, finy=finy, channelsy=channelsy, rampratey=rampratey, startxs="", finxs="", startys="", finys="")

	// Check scan is within limits
	SFfd_pre_checks(Fsv)

   	// Set up AWG if using (TODO: For now we will ignore this)
	struct fdAWG_list AWG
	// if(use_AWG)
	// 	fdAWG_get_global_AWG_list(AWG)
	// 	SFawg_set_and_precheck(AWG, Fsv)  // Note: sets SV.numptsx here and AWG.use_AWG = 1 if pass checks
	// else  // Don't use AWG
		AWG.use_AWG = 0  	// This is the default, but just putting here explicitly
	// endif

	// Ramp to start of scan
	SFfd_ramp_start(Fsv, ignore_lims=1)  // Ignore lims because already checked

	// Let gates settle
	sc_sleep(Fsv.delayy)

	// Get Labels for graphs
	string x_label, y_label
	x_label = GetLabel(Fsv.channelsx, fastdac=1)
	y_label = GetLabel(Fsv.channelsy, fastdac=1)

	// Initialize scan (create waves to store data, and open/arrange relevant graphs)
	// TODO: Hopefully we can use a lot of the existing InitializeWaves() but this needs a major refactor
	NEW_InitializeScan()

	// Main Measurement loop
	variable setpointy, sy, fy, i, j
	string chy
	for(i=0; i<Fsv.numptsy; i++)
		// Ramp slow axis
		for(j=0; j<itemsinlist(Fsv.channelsy,","); j++) // For each y channel, move to next setpoint
			sy = str2num(stringfromList(j, Fsv.startys, ","))
			fy = str2num(stringfromList(j, Fsv.finys, ","))
			chy = stringfromList(j, Fsv.channelsy, ",")
			setpointy = sy + (i*(fy-sy)/(Fsv.numptsy-1))
			RampMultipleFDac(Fsv.instrID, chy, setpointy, ramprate=Fsv.rampratey, ignore_lims=1)
		endfor

		// Ramp to start of fast axis
		SFfd_ramp_start(Fsv, ignore_lims=1, x_only=1)
		sc_sleep(Fsv.delayy)

		// Record fast axis
		// fd_Record_Values(Fsv, PL, i, AWG_list = AWG)
		// TODO: Mostly this will follow fd_record_values() but some changes need to be made
		NEW_fd_record_values(Fsv, i)
	endfor

	// Save to HDF
	// TODO: Mostly this will follow SaveWaves() but some changes need to be made
	NEW_EndScan()
end


////////////////////////////////////////////////////////////////////
///////////////////////////// Save Waves ///////////////////////////
////////////////////////////////////////////////////////////////////

function RenameSaveWaves([msg,save_experiment,fastdac, wave_names])
	// the message will be printed in the history, and will be saved in the HDF file corresponding to this scan
	// save_experiment=1 to save the experiment file
	// Use wave_names to manually save comma separated waves in HDF file with sweeplogs etc.
	string msg, wave_names
	variable save_experiment, fastdac
	string his_str
	nvar sc_is2d, sc_PrintRaw, sc_PrintCalc, sc_scanstarttime
	svar sc_x_label, sc_y_label
	string filename, wn, logs=""
	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	wave /t sc_RawWaveNames, sc_CalcWaveNames
	wave sc_RawRecord, sc_CalcRecord
	variable filecount = 0

	variable save_type = 0

	if (!paramisdefault(msg))
		print msg
	else
		msg=""
	endif

	save_type = 0
	if(!paramisdefault(fastdac) && !paramisdefault(wave_names))
		abort "ERROR[SaveWaves]: Can only save FastDAC waves OR wave_names, not both at same time"
	elseif(fastdac == 1)
		save_type = 1  // Save Fastdac_ScanController waves
	elseif(!paramisDefault(wave_names))
		save_type = 2  // Save given wave_names ONLY
	else
		save_type = 0  // Save normal ScanController waves
	endif


	// compare to earlier call of InitializeWaves
	nvar fastdac_init
	if(fastdac > fastdac_init && save_type != 2)
		print("[ERROR] \"SaveWaves\": Trying to save fastDAC files, but they weren't initialized by \"InitializeWaves\"")
		abort
	elseif(fastdac < fastdac_init  && save_type != 2)
		print("[ERROR] \"SaveWaves\": Trying to save non-fastDAC files, but they weren't initialized by \"InitializeWaves\"")
		abort
	endif

	nvar sc_save_time
	if (paramisdefault(save_experiment))
		save_experiment = 1 // save the experiment by default
	endif


	KillDataFolder/z root:async // clean this up for next time

	if(save_type != 2)
		// save timing variables
		variable /g sweep_t_elapsed = datetime-sc_scanstarttime
		printf "Time elapsed: %.2f s \r", sweep_t_elapsed
		dowindow/k SweepControl // kill scan control window
	else
		variable /g sweep_t_elapsed = 0
	endif

	// count up the number of data files to save
	variable ii=0
	if(save_type == 0)
		// normal non-fastdac files
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
	// Save Fastdac waves
	elseif(save_type == 1)
		wave/t fadcvalstr
		wave fadcattr
		string wn_raw = ""
		nvar sc_Printfadc
		nvar sc_Saverawfadc

		ii=0
		do
			if(fadcattr[ii][2] == 48)
				filecount += 1
			endif
			ii+=1
		while(ii<dimsize(fadcattr,0))

		if(filecount > 0)
			// there is data to save!
			// save it and increment the filenumber
			printf "saving all dat%d files...\r", filenum

			// Open up HDF5 files
			// Save scan controller meta data in this function as well
			initSaveFiles(msg=msg)

			// look for waves to save
			ii=0
			string str_2d = "", savename
			do
				if(fadcattr[ii][2] == 48) //checkbox checked
					wn = fadcvalstr[ii][3]
					if(sc_is2d)
						wn += "_2d"
					endif
					filename = "dat"+filenumstr+wn

					duplicate $wn $filename

					if(sc_Printfadc)
						print filename
					endif
					saveSingleWave(wn)

					if(sc_Saverawfadc)
						str_2d = ""  // Set 2d_str blank until check if sc_is2d
						wn_raw = "ADC"+num2istr(ii)
						if(sc_is2d)
							wn_raw += "_2d"
							str_2d = "_2d"  // Need to add _2d to name if wave is 2d only.
						endif
						filename = "dat"+filenumstr+fadcvalstr[ii][3]+str_2d+"_RAW"  // More easily identify which Raw wave for which Calc wave
						savename = fadcvalstr[ii][3]+str_2d+"_RAW"


						duplicate $wn_raw $filename


						duplicate/O $wn_raw $savename  // To store in HDF with more easily identifiable name
						if(sc_Printfadc)
							print filename
						endif
						saveSingleWave(savename)
					endif
				endif
				ii+=1
			while(ii<dimsize(fadcattr,0))
			closeSaveFiles()
		endif
	elseif(save_type == 2)
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
		initSaveFiles(msg=msg, logs_only=1)
		printf "Saving waves [%s] in dat%d.h5\r", wave_names, filenum

		// Now save each wave
		for(ii=0;ii<itemsinlist(wave_names, ",");ii++)
			wn = stringfromlist(ii, wave_names, ",")
			saveSingleWave(wn)
		endfor
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
		sc_copyNewFiles(filenum, save_experiment=save_experiment)
	endif

	// add info about scan to the scan history file in /config
//	sc_saveFuncCall(getrtstackinfo(2))

	// delete waves old waves, so only the newest 500 scans are stored in volatile memory
	// turn on by setting sc_cleanup = 1
//	nvar sc_cleanup
//	if(sc_cleanup == 1)
//		sc_cleanVolatileMemory()
//	endif

	// increment filenum
	if(Rawadd+Calcadd > 0 || filecount > 0  || save_type == 2)
		filenum+=1
	endif
end

////////////////////////////////////////////////////////////////////
///////////// Johanns attempt at breaking down savewaves()//////////
////////////////////////////////////////////////////////////////////
function NEWSaveWaves([msg,save_experiment,fastdac, wave_names])
	// the message will be printed in the history, and will be saved in the HDF file corresponding to this scan
	// save_experiment=1 to save the experiment file
	// Use wave_names to manually save comma separated waves in HDF file with sweeplogs etc.
	string msg, wave_names
	variable save_experiment, fastdac
	string his_str
	nvar sc_is2d, sc_PrintRaw, sc_PrintCalc, sc_scanstarttime
	svar sc_x_label, sc_y_label
	string filename, wn, logs=""
	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	wave /t sc_RawWaveNames, sc_CalcWaveNames
	wave sc_RawRecord, sc_CalcRecord
	variable filecount = 0

	variable save_type = 0

	if (!paramisdefault(msg))
		print msg
	else
		msg=""
	endif
	

	nvar sc_save_time
	if (paramisdefault(save_experiment))
		save_experiment = 1 // save the experiment by default
	endif

	// set the save type
	// 0 = Normal_ScanController, 1 = Fastdac_ScanController, 2 = wave_names
	save_type = saveType(fastdac, wave_names) 

	initializeScansCheck(fastdac, save_type) // check if waves were initialzed

	KillDataFolder/z root:async // clean this up for next time

	if(save_type != 2) // normal or fastdac
		variable /g sweep_t_elapsed = datetime-sc_scanstarttime // save timing variables
		printf "Time elapsed: %.2f s \r", sweep_t_elapsed
		dowindow/k SweepControl // kill scan control window
	else
		variable /g sweep_t_elapsed = 0
	endif


	// count up the number of data files to save


	//////////////////// non - fastdac save ////////////////////
	if(save_type == 0)
		variable Rawadd = sum(sc_RawRecord)
		variable Calcadd = sum(sc_CalcRecord)
		NonFastDacSave(msg)
	//////////////////// fastdac save //////////////////////////
	elseif(save_type == 1)
		FastDacSave(msg)
	//////////////////// wave_name save ////////////////////////
	elseif(save_type == 2)
		variable ii=0
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
		initSaveFiles(msg=msg, logs_only=1)
		printf "Saving waves [%s] in dat%d.h5\r", wave_names, filenum

		// Now save each wave
		for(ii=0;ii<itemsinlist(wave_names, ",");ii++)
			wn = stringfromlist(ii, wave_names, ",")
			saveSingleWave(wn)
		endfor
		closeSaveFiles()
	endif


	////////////////////////////////////////////////////////
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
		sc_copyNewFiles(filenum, save_experiment=save_experiment)
	endif

	// add info about scan to the scan history file in /config
	//	sc_saveFuncCall(getrtstackinfo(2))

	// delete waves old waves, so only the newest 500 scans are stored in volatile memory
	// turn on by setting sc_cleanup = 1
	//	nvar sc_cleanup
	//	if(sc_cleanup == 1)
	//		sc_cleanVolatileMemory()
	//	endif

	// increment filenum
	if(Rawadd+Calcadd > 0 || filecount > 0  || save_type == 2)
		filenum+=1
	endif
end



function saveType(fastdac, wave_names)
   string wave_names
	variable fastdac
	variable save_type = 0

//	if(!paramisdefault(fastdac) && !paramisdefault(wave_names))
//		abort "ERROR[SaveWaves]: Can only save FastDAC waves OR wave_names, not both at same time"
	if(fastdac == 1)
		save_type = 1  // Save Fastdac_ScanController waves
	elseif(numtype(strlen(wave_names)) == 0)
		save_type = 2  // Save given wave_names ONLY
	else
		save_type = 0  // Save normal ScanController waves
	endif

	return save_type
end


function initializeScansCheck(fastdac, save_type)
	variable fastdac, save_type
	nvar fastdac_init

	if(fastdac > fastdac_init && save_type != 2)
		print("[ERROR] \"SaveWaves\": Trying to save fastDAC files, but they weren't initialized by \"InitializeWaves\"")
		abort
	elseif(fastdac < fastdac_init  && save_type != 2)
		print("[ERROR] \"SaveWaves\": Trying to save non-fastDAC files, but they weren't initialized by \"InitializeWaves\"")
		abort
	endif
end


// FastDac Save Function
function FastDacSave(msg)
	string msg
	wave/t fadcvalstr
	wave fadcattr
	string wn_raw = ""
	nvar sc_Printfadc
	nvar sc_Saverawfadc
	nvar sc_is2d
	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	variable filecount = 0
	variable ii=0
	string wn, filename
	variable raw_hdf5_id, calc_hdf5_id
	nvar sc_Saverawfadc

	do
		if(fadcattr[ii][2] == 48)
			filecount += 1
		endif
		ii+=1
	while(ii<dimsize(fadcattr,0))

	if(filecount > 0)
		// there is data to save!
		// save it and increment the filenumber
		printf "saving all dat%d files...\r", filenum

		// Open up HDF5 files
		// Save scan controller meta data in this function as well
		//initSaveFiles(msg=msg)
		// for the multip file case open each file and save the id variable

		calc_hdf5_id = initOpenSaveFiles(0)

		string hdfids
		hdfids = addlistItem(num2str(calc_hdf5_id), hdfids)
		if (sc_Saverawfadc == 48) //////// check variable == 48 for ticked || MIGHT JUST BE 1 TO CHECK...
			raw_hdf5_id = initOpenSaveFiles(1)
			hdfids = addlistItem(num2str(raw_hdf5_id), hdfids)
		endif
		
		// add Meta data to each file
		addMetaFiles(hdfids, msg=msg)


		// look for waves to save
		ii=0
		string str_2d = "", savename
		do
			if(fadcattr[ii][2] == 48) //checkbox checked || MIGHT JUST BE 1 TO CHECK...
				wn = fadcvalstr[ii][3]
				if(sc_is2d)
					wn += "_2d"
				endif
				filename = "dat"+filenumstr+wn

				duplicate $wn $filename

				if(sc_Printfadc)
					print filename
				endif
				
				// saveSingleWave(wn)
				initSaveSingleWave(wn, calc_hdf5_id)

				if(sc_Saverawfadc)
					str_2d = ""  // Set 2d_str blank until check if sc_is2d
					wn_raw = "ADC"+num2istr(ii)
					if(sc_is2d)
						wn_raw += "_2d"
						str_2d = "_2d"  // Need to add _2d to name if wave is 2d only.
					endif
					filename = "dat"+filenumstr+fadcvalstr[ii][3]+str_2d+"_RAW"  // More easily identify which Raw wave for which Calc wave
					savename = fadcvalstr[ii][3]+str_2d+"_RAW"


					// duplicate $wn_raw $filename


					duplicate/O $wn_raw $savename  // To store in HDF with more easily identifiable name
					if(sc_Printfadc)
						print filename
					endif
					initSaveSingleWave(savename, raw_hdf5_id)
					// saveSingleWave(savename)
				endif
			endif
			ii+=1
		while(ii<dimsize(fadcattr,0))
		initcloseSaveFiles(hdfids) // close all files
	endif
end

// Non FastDac Save Function
function NonFastDacSave(msg)
	string msg
	wave/t fadcvalstr
	wave fadcattr
	string wn_raw = ""
	nvar sc_Printfadc
	nvar sc_Saverawfadc
	nvar sc_is2d, sc_PrintCalc
	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	variable filecount = 0
	variable ii=0, sc_PrintRaw
	string wn, filename
	wave /t sc_RawWaveNames, sc_CalcWaveNames
	wave sc_RawRecord, sc_CalcRecord
	
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
		
//		wave arb_wavename
//		arb_wavename = (condition) ? case_true : case_false
//		sc_PrintRaw == 1 && print()
		
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
end


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
	
	return hdf5_id

end


function addMetaFiles(hdf5_id_list, [msg, logs_only])
	// meta data is created and added to the files in list
	// hdf5_id_list
	string msg
	variable logs_only  // 1=Don't save any data to HDF
	string hdf5_id_list
	
	if(paramisdefault(msg)) // save meta data
		msg=""
	endif
	
	make /FREE /T /N=1 cconfig = prettyJSONfmt(sc_createconfig())
	make /FREE /T /N=1 sweep_logs = prettyJSONfmt(sc_createSweepLogs(msg=msg))
	
	// Check that prettyJSONfmt actually returned a valid JSON.
	sc_confirm_JSON(sweep_logs, name="sweep_logs")
	sc_confirm_JSON(cconfig, name="cconfig")

	// LOOP through the given hdf5_id in list
	variable i
	variable hdf5_id
	for (i=0;i<itemsinlist(hdf5_id_list);i++)
		hdf5_id = str2num(stringFromList(i, hdf5_id_list))
	

	if (logs_only != 1)
		// save x and y arrays
		nvar sc_is2d
		HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 $"sc_xdata" , hdf5_id, "x_array"
		if(sc_is2d == 1)
			HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 $"sc_ydata" , hdf5_id, "y_array"
		elseif(sc_is2d == 2)
			HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 $"sc_ydata" , hdf5_id, "y_array"
			HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 $"sc_linestart", hdf5_id, "linestart"
		endif
	else // Make attr in HDF which makes it clear this was only to store Logs
		make/o/free/t/n=1 attr_message = "True"
		HDF5SaveData /A="Logs_Only" attr_message, hdf5_id, "/"
	endif
	
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


function initSaveSingleWave(wn, hdf5_id)
	// wave with name 'g1x' as dataset named 'g1x' in hdf5
	string wn
	variable hdf5_id

	HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 /Z $wn , hdf5_id
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


function resampleWave(wave_name, freq_start, freq_end)
	// takes a wave and resamples its frequency, freq_start
	// to freq_end
	wave wave_name
	variable freq_start, freq_end
	
//	if (freq != 0)
//		RatioFromNumber/V (freq_end / freq_start)
//  		resample/UP=V_numerator/DOWN=V_denominator/N=101 wave_name
//	endif

end

////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////





function NEW_InitializeScan()
	// Most of InitializeWaves()
	// Requirements for this part:
	// Initialize waves -- 	Need 1D and 2D waves for the raw data coming from the fastdac
	// 						Need 2D waves for either the raw data, or filtered data if a filter is set
	//							(If a filter is set, the raw waves should only ever be plotted 1D)
	//							(This will be after calc (i.e. don't need before and after calc wave))
	// Initialize graphs -- 	Need 1D graphs for raw data coming in for each sweep
	//								(Only these should be updated during the sweep, then the 2D plots after a 1D sweep)
	// 							Need 2D graphs for the filtered/calc'd waves
	//								(Should get updated at the end of each sweep)
	// Open the abort sweep window
	// Does the current InitializeWaves do anything else?

end


function NEW_fd_record_values(S, rowNum, [AWG_list, linestart])
	struct FD_ScanVars &S
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

   // Check InitWaves was run with fastdac=1
   fdRV_check_init()

   // Check that checks have been carried out in main scan function where they belong
	if(S.lims_checked != 1)
	 	abort "ERROR[fd_record_values]: FD_ScanVars.lims_checked != 1. Probably called before limits/ramprates/sweeprates have been checked in the main Scan Function!"
	endif

   	// Check that DACs are at start of ramp (will set if necessary but will give warning if it needs to)
	fdRV_check_ramp_start(S)

	// Send command and read values
	fdRV_send_command_and_read(S, AWG_list, rowNum)

	// Process 1D read and distribute
	fdRV_process_and_distribute()

	// // check abort/pause status
	// fdRV_check_sweepstate(S.instrID)
	// return looptime
end

function fdRV_send_command_and_read(ScanVars, AWG_list, rowNum)
	// Send 1D Sweep command to fastdac and record the raw data it returns ONLY
	struct FD_ScanVars &ScanVars
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


function fdRV_process_and_distribute()
	variable fastdac_freq = 2000 // This needs to be filled
//	resample/down=X
	
	
end

function NEW_EndScan()

	// Close Abort window
	// Saving Requirements
	// If filtering:
	// Save RAW data in a separate HDF (something like datXXX_RAW.h5)
	//		(along with sweep logs etc)
	//		(then delete from igor experiment)
	// Save filtered/calc'd data in the normal datXXX.h5
	// 		(with same sweep logs etc)
	// 		(Make a copy in Igor like usual (e.g. datXXX_cscurrent)
	// If not filtering -- Save like normal

	// Save experiment

	// Anything else that SaveWaves() does?
end
