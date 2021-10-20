///// Aim for data saving/plotting 

function test_scan_2d(fdID, startx, finx, channelsx, starty, finy, channelsy, numptsy, [numpts, sweeprate, rampratex, rampratey, delayy, comments])
	variable fdID, startx, finx, starty, finy, numptys, numpts, sweeprate, rampratex, rampratey, delayy
	string channelsx, channelsy, comments

	// Reconnect instruments
	sc_openinstrconnections(0)

	// Set defaults
	nvar fd_ramprate  // Default to use for all fd ramps
	rampratex = paramisdefault(rampratex) ? fd_ramprate : rampratex
	rampratey = ParamIsDefault(rampratey) ? fd_ramprate : rampratey
	delayy = ParamIsDefault(delayy) ? 0.01 : delayy
	comments = selectstring(paramisdefault(comments), comments, "")
	
	// Put info into scanVars struct (to more easily pass around later)
 	struct FD_ScanVars Fsv
	SF_init_FDscanVars(Fsv, fdID, startx, finx, channelsx, numpts, rampratex, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy, \
	   						 starty=starty, finy=finy, channelsy=channelsy, rampratey=rampratey, startxs=startxs, finxs=finxs, startys=startys, finys=finys)

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
	variable setpointy, sy, fy
	string chy
	for(i=0; i<Fsv.numptsy; i++)
		// Ramp slow axis
		for(j=0; j<itemsinlist(Fsv.channelsy,","); j++) // For each y channel, move to next setpoint
			sy = str2num(stringfromList(j, Fsv.startys, ","))
			fy = str2num(stringfromList(j, Fsv.finys, ","))
			chy = stringfromList(j, Fsv.channelsy, ",")
			setpointy = sy + (i*(fy-sy)/(Fsv.numptsy-1))	
			RampMultipleFDac(Fsv.instrID, chy, setpointy, ramprate=Fsv.rampratey, ignore_lims=1)
		endif

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

function NEW_InitializeScan()
	// Requirements for this part: 
	// Initialize waves -- 	Need 1D waves for the 1D raw data coming from the fastdac
	// 						Need 2D waves for either the raw data, or filtered data if a filter is set
	//							(If a filter is set, the raw waves should only ever be plotted 1D)
	//							(This will be after calc (i.e. don't need before and after calc wave))
	// Initialize graphs -- 	Need 1D graphs for raw data coming in for each sweep
	//								(Only these should be updated during the sweep, then the 2D plots after a 1D sweep)							
	// 							Need 2D graphs for the filtered/calc'd waves
	//								(Should get updated at the end of each sweep)
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
		(rowNum == 0) ? print "fd_Record_Values: Using AWG" 
		// if(rowNum == 0)
		// 	print "fd_Record_Values: Using AWG"
		// endif
	endif
	
	// Check if this is a linecut scan and update centers if it is
	if(!paramIsDefault(linestart))
		wave sc_linestart
		sc_linestart[rowNum] = linestart
	endif

   // Check InitWaves was run with fastdac=1
   fdRV_check_init()

   // Check that checks have been carried out in main scan function where they belong
   (S.lims_checked != 1) ? abort "ERROR[fd_record_values]: FD_ScanVars.lims_checked != 1. Probably called before limits/ramprates/sweeprates have been checked in the main Scan Function!" 
	// if(S.lims_checked != 1)
	// 	abort "ERROR[fd_record_values]: FD_ScanVars.lims_checked != 1. Probably called before limits/ramprates/sweeprates have been checked in the main Scan Function!"
	// endif

   	// Check that DACs are at start of ramp (will set if necessary but will give warning if it needs to)
	fdRV_check_ramp_start(S)

	// Send command and read values
	fdRV_send_command_and_read()

	// Process 1D read and distribute
	fdRV_process_and_distribute()

	// // check abort/pause status
	// fdRV_check_sweepstate(S.instrID)
	// return looptime
end

function fdRV_send_command_and_read()
	string cmd_sent = ""
	variable totalByteReturn
	if(sc_AWG_used)  	// Do AWG_RAMP
	   cmd_sent = fd_start_AWG_RAMP(S, AWG_list)
	else				// DO normal INT_RAMP
		cmd_sent = fd_start_INT_RAMP(S)
	endif
	totalByteReturn = S.numADCs*2*S.numptsx
	sc_sleep(0.1) 	// Trying to get 0.2s of data per loop, will timeout on first loop without a bit of a wait first
	variable looptime = 0
   looptime = fdRV_record_buffer(S, rowNum, totalByteReturn)

   // update window
	string endstr
	endstr = readInstr(S.instrID)
	endstr = sc_stripTermination(endstr,"\r\n")
	if(fdacCheckResponse(endstr,cmd_sent,isString=1,expectedResponse="RAMP_FINISHED"))
		fdRV_update_window(S, S.numADCs)
		if(sc_AWG_used)  // Reset AWs back to zero (I don't see any reason the user would want them left at the final position of the AW)
			rampmultiplefdac(S.instrID, AWG_list.AW_DACs, 0)
		endif
	endif

	// fdRV_check_sweepstate(S.instrID)
end


function NEW_EndScan()

	// Close Abort window

	// Saving Requirements 
	// If filtering:
	// Save RAW data in a separate HDF (something like datXXX_RAW.h5) 
	//		(along with sweep logs etc)
	// Save filtered/calc'd data in the normal datXXX.h5 
	// 		(with same sweep logs etc)
	// If not filtering -- Save like normal

	// Save experiment

	// Anything else that SaveWaves() does?
end