#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

function ScanFastDAC(start, fin, channels, [numptsx, sweeprate, delay, ramprate, repeats, alternate, starts, fins, x_label, y_label, comments, nosave, use_awg, interlaced_channels, interlaced_setpoints,fake])
	// 1D repeat scan for FastDAC
	// Note: to alternate scan direction set alternate=1
	// Note: Ramprate is only for ramping gates between scans
	 // Performs 1D repeat scans with FastDAC, allowing for various configurations including alternate scanning, delay, and ramp rate adjustments.
    // Parameters:
    // - start, fin: Start and end points of the scan.
    // - channels: Comma-separated list of channels to scan.
    // - numptsx, sweeprate, delay, ramprate: Scan parameters.
    // - repeats: Number of scan repetitions.
    // - alternate: If set to 1, alternates scan direction.
    // - starts, fins: Start and end points for each channel, if varying.
    // - x_label, y_label: Labels for the X and Y axes.
    // - comments: Additional comments for the scan.
    // - nosave: If set to 1, does not save the scan results.
    // - use_awg: If set to 1, uses the AWG for the scan.
    // - interlaced_channels, interlaced_setpoints: For interlaced scans.
    
	
	variable start, fin, repeats, numptsx, sweeprate, delay, ramprate, alternate, nosave, use_awg,fake
	string channels, x_label, y_label, comments, starts, fins, interlaced_channels, interlaced_setpoints

	// Set defaults
	delay = ParamIsDefault(delay) ? 0.01 : delay
	y_label = selectstring(paramisdefault(y_label), y_label, "nA")
	x_label = selectstring(paramisdefault(x_label), x_label, "")
	comments = selectstring(paramisdefault(comments), comments, "")
	starts = selectstring(paramisdefault(starts), starts, "")
	fins = selectstring(paramisdefault(fins), fins, "")
	interlaced_channels = selectString(paramisdefault(interlaced_channels), interlaced_channels, "")
	interlaced_setpoints = selectString(paramisdefault(interlaced_setpoints), interlaced_setpoints, "")
	

	// Set sc_ScanVars struct
	struct ScanVars S
	initScanVarsFD(S, start, fin, channelsx=channels, numptsx=numptsx, rampratex=ramprate, starty=1, finy=repeats, delayy=delay, sweeprate=sweeprate,  \
					numptsy=repeats, startxs=starts, finxs=fins, x_label=x_label, y_label=y_label, alternate=alternate, interlaced_channels=interlaced_channels, \
					interlaced_setpoints=interlaced_setpoints, comments=comments, use_awg=use_awg)

   
	// Check software limits and ramprate limits
	
  	// If using AWG then get that now and check it
//	struct AWGVars AWG
//	if(use_AWG)	
//		fd_getGlobalAWG(AWG)
//		CheckAWG(AWG, S)  //Note: sets S.numptsx here and AWG.lims_checked = 1
//	endif
//	SetAWG(AWG, use_AWG)

// Pre-scan setup
	if (S.is2d)
		S.y_label = "Repeats"
	endif
	PreScanChecksFD(S)
	if (fake==1)
		abort
	endif
	
	// Ramp to start
	RampStartFD(S)  // Ramps to starting value

	// Let gates settle
	sc_sleep_noupdate(S.delayy)

	// Initiate Scan
	initializeScan(S, y_label = y_label)


	// Main measurement loop
	int j, d = 1
	for (j = 0; j < S.numptsy; j++)
		S.direction = d  // Will determine direction of scan in fd_Record_Values
		// Interlaced Scan Stuff
		if (S.interlaced_y_flag)
			if (use_awg)
				//*Set_AWG_state(S, AWG, mod(j, S.interlaced_num_setpoints))
			endif
			//*Ramp_interlaced_channels(S, mod(j, S.interlaced_num_setpoints))
		endif

		// Ramp to start of fast axis // this would need to ramp all the DACs being used to their starting position (do we need synchronization)
		RampStartFD(S, ignore_lims = 1, x_only = 1) // This uses ramp smart, Which does not account for synchronization. the important thing would be
		// to have all the dacs return to their respective starting positions
		sc_sleep(S.delayy)

		// Record values for 1D sweep
		//*scfd_RecordValues(S, j, AWG_List = AWG)
		scfd_RecordValues(S, j)


		if (alternate != 0) // If want to alternate scan scandirection for next row
			d = d * -1
		endif
	endfor

	// Save by default
	if (nosave == 0)
		EndScan(S = S)
		// SaveWaves(msg=comments, fastdac=1)
	endif
	doWindow/k/z SweepControl  // Attempt to close previously open window just in case
	doWindow/k/z SweepControl  // Attempt to close previously open window just in case

end



function ScanFastDAC2D(startx, finx, channelsx, starty, finy, channelsy, numptsy, [numpts, sweeprate, bdID, fdyID, rampratex, rampratey, delayy, startxs, finxs, startys, finys, comments, nosave, use_AWG, interlaced_channels, interlaced_setpoints, y_label, fake])
	// EXAMPLE: scanfastdac2d2(0, 1000, "10, 2", 0, 500, "0,8", 4, startxs = "0, 100", startys = "0, 100", finxs = "1000,900", finys = "800,400", sweeprate = 250, interlaced_channels = "19", interlaced_setpoints = "100, 300")

	// 2D Scan for FastDAC only OR FastDAC on fast axis and BabyDAC on slow axis
	// Note: Must provide numptsx OR sweeprate in optional parameters instead
	// Note: To ramp with babyDAC on slow axis provide the BabyDAC variable in bdID
	// Note: channels should be a comma-separated string ex: "0,4,5"
	// Example :: Interlaced parameters
	// Interlaced period of 3 rows where ohmic1 and ohmic2 change on each row.
	// interlace_channels = "ohmic1, ohmic2"
	// interlace_values = "500,10,0;10,10,10"
	// ohmic1 will change between 500,10,0 each row

	variable startx, finx, starty, finy, numptsy, numpts, sweeprate, bdID, fdyID, rampratex, rampratey, delayy, nosave, use_AWG
	string channelsx, channelsy, comments, startxs, finxs, startys, finys, interlaced_channels, interlaced_setpoints, y_label
	int fake
	// Set defaults
	y_label = selectstring(paramisdefault(y_label), y_label, "nA")
	delayy = ParamIsDefault(delayy) ? 0.01 : delayy
//	rampratey = ParamIsDefault(rampratey) ? 1000 : rampratey
//	rampratex = ParamIsDefault(rampratex) ? 1000 : rampratex


	comments = selectstring(paramisdefault(comments), comments, "")
	startxs = selectstring(paramisdefault(startxs), startxs, "")
	finxs = selectstring(paramisdefault(finxs), finxs, "")
	startys = selectstring(paramisdefault(startys), startys, "")
	finys = selectstring(paramisdefault(finys), finys, "")

	interlaced_channels = selectString(paramisdefault(interlaced_channels), interlaced_channels, "")
	interlaced_setpoints = selectString(paramisdefault(interlaced_setpoints), interlaced_setpoints, "")
	variable scan2d = 1
	// Put info into scanVars struct (to more easily pass around later)
	struct ScanVars S
	initScanVarsFD(S, startx, finx, channelsx=channelsx, rampratex=rampratex, numptsx=numpts, sweeprate=sweeprate, numptsy=numptsy, delayy=delayy,\
	starty=starty, finy=finy, channelsy=channelsy, rampratey=rampratey, startxs=startxs, finxs=finxs, startys=startys, finys=finys,\
	interlaced_channels=interlaced_channels, interlaced_setpoints=interlaced_setpoints, comments=comments, x_only = 0)
	s.is2d = 1
	S.starty = starty
	S.finy = finy
	scv_setSetpoints(S, S.channelsx, S.startx, S.finx, S.channelsy, starty, finy, S.startxs, S.finxs, startys, finys)
	// Check software limits and ramprate limits and that ADCs/DACs are on same FastDAC
	PreScanChecksFD(S)
	if (fake == 1)
		abort
	endif
   	
  	//* If using AWG then get that now and check it
//	struct AWGVars AWG
//	if(use_AWG)	
//		fd_getGlobalAWG(AWG)
//		CheckAWG(AWG, S)  // Note: sets S.numptsx here and AWG.lims_checked = 1
//	endif
//	SetAWG(AWG, use_AWG)
   
	// Ramp to start without checks
	RampStartFD(S, ignore_lims = 1)
//   	
//   	// Let gates settle
	sc_sleep(S.delayy)
//
//	// Initialize waves and graphs
	initializeScan(S, y_label = y_label)
//
//	// Main measurement loop
	variable i=0, j=0
	variable setpointy, sy, fy
	string chy
	variable k = 0
	for(i=0; i<S.numptsy; i++)
//
//		///// LOOP FOR INTERLACE SCANS ///// 
////		//*if (S.interlaced_y_flag)
////			Ramp_interlaced_channels(S, mod(i, S.interlaced_num_setpoints))
////			Set_AWG_state(S, AWG, mod(i, S.interlaced_num_setpoints))
////			if (mod(i, S.interlaced_num_setpoints) == 0) // Ramp slow axis only for first of interlaced setpoints
////				rampToNextSetpoint(S, 0, outer_index=i, y_only=1, fastdac=!use_bd, ignore_lims=1)
////			endif
////		else
////			// Ramp slow axis
		rampToNextSetpoint(S, 0, outer_index=i, y_only=1, ignore_lims=1) //uses the same, ramp multiple fdac but this function seems to be bd specific
////
////		endif
////		
//
//		// Ramp fast axis to start
		rampToNextSetpoint(S, 0, ignore_lims=1)
//		
//		// Let gates settle
		sc_sleep(S.delayy)
//		
//		// Record fast axis
		scfd_RecordValues(S, i)//*, AWG_list=AWG)
//		
	endfor
//	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
  		dowindow /k SweepControl
	endif
	
end



function/s fd_start_sweep(S, [AWG_list])
	Struct ScanVars &S
	Struct AWGVars &AWG_List
	//	int i
	//	string cmd="//*"
	//	
	print S
	string adcList=S.adcList;
	string startxs=S.startxs;
	string finxs=S.finxs;
	int numptsx=S.numptsx;
	if (S.readVsTime) 
		sample_ADC(S.adclistIDs,  S.numptsx)
	endif
	
	if (S.readvstime==0)
		linear_ramp(S)
	endif
		
	 
//	 fake_ramp( adclist,  startxs,  finxs, numptsx)
	 
//syntax
//	INT_RAMP,{DAC channels},{ADC channels},{initial DAC voltage 1},{...},{initial DAC voltage n},{final DAC voltage 1},{...},{final dac voltage n},{# of steps}
	end
	
	
function fake_ramp(string adclist, string startxs, string finxs,int numptsx)
	wave numericwave
	variable i, le, j=0
	variable nof_ADCs
	int counter
	//print adclist[i]
	string name
	StringToListWave(adclist)
	nof_ADCs=dimsize(numericwave,0);
	le=1000;
	counter=numptsx
	do
		//le=abs(floor(gnoise(1000)));
		make/o/N=(le,nof_ADCs) tempwave
		for(i=0; i<nof_ADCs; i+=1)
			tempwave[][i]=0*sin(0.001*x*2*pi)+gnoise(1)+10
			//setdimLabel 1,i, column, tempwave
		endfor
		name="test_"+num2str(j)+".dat"
		Save/p=fdtest/J/M="\n"/O tempwave as name
		counter=counter-le
		j=j+1
	while(counter>le)
	// one last round with the remaining pnts
	le=counter
	make/o/N=(le,nof_ADCs) tempwave
	for(i=0; i<nof_ADCs; i+=1)
		tempwave[][i]=0*sin(0.001*x*2*pi)+gnoise(1)+10
		//setdimLabel 1,i, column, tempwave
	endfor
	name="test_"+num2str(j)+".dat"
	Save/p=fdtest/J/M="\n"/O tempwave as name
	
end



//	
//	string fdIDname; S.adcLists = ""; S.fakeRecords = ""
//	
//	// the below function takes all the adcs selected to record in the fastdac Window and returns
//		// only the adcs associated with the fdID
//		//*string adcs = scu_getDeviceChannels(fdID, S.adclist, adc_flag=1) 
//		if (cmpstr(adcs, "") == 0) // If adcs is an empty string
//			string err
//			sprintf err, "ERROR[fd_start_sweep]: ADClist = %s, Not on FD %s.\r\nRemeber, ADCs are indexed e.g. 0 - 11 for 3 fastdacs", S.adclist, fdIDname
//			abort err
//		endif
//		string cmd = ""
//	
//		if (S.readVsTime) // this is passed at either the end of the scan (EndScan()) or it is passed
//			// when update ADC is pressed on the fastDac window. The point here is an ADC channel is 
//			// read for a small number of points to minimize noise and get a good average
//			adcs = replacestring(";",adcs,"")
//			S.adcLists = replacestringbykey(fdIDname, S.adcLists, adcs)
//			sprintf cmd, "SPEC_ANA,%s,%s\r", adcs, num2istr(S.numptsx)
//		else
//			scu_assertSeparatorType(S.channelsx, ",")
//			string starts, fins, temp
//			
//			// here we decide which direction the sweeps are happening in, This is for sweeps
//			// to happen at alternating directions. Standard scans have S.direction = 1
//			if(S.direction == 1)
//				starts = stringByKey(fdIDname, S.IDstartxs)
//				fins = stringByKey(fdIDname, S.IDfinxs)
//			elseif(S.direction == -1)
//				starts = stringByKey(fdIDname, S.IDfinxs)
//				fins = stringByKey(fdIDname, S.startxs)
//			else
//				abort "ERROR[fd_start_sweep]: S.direction must be 1 or -1, not " + num2str(S.direction)
//			endif
//			
//			starts = starts[1,INF] //removing the comma at the start
//			fins = fins [1, INF]   //removing the comma at the start
//
//			
//			// the below function takes all the dacs to be ramped (passed as a parameter in any scan function)
//			// and returns only the dacs associated with the fdID
//			string dacs = scu_getDeviceChannels(fdID, S.channelsx)
//	   		dacs = replacestring(",",dacs,"")
//		 	
//		 	
//			// checking the need for a fakeramp, the voltage is held at the current value.
//			int fakeChRamp = 0; string AW_dacs; int j
//			if(!cmpstr(dacs,""))
//			
//				// find global value of channel 0 in that ID, set it to start and fin, and dac = 0
//				if(!paramisDefault(AWG_list) && AWG_List.use_AWG == 1 && AWG_List.lims_checked == 1)
//					AW_dacs = scu_getDeviceChannels(fdID, AWG_list.channels_AW0)
//					AW_dacs = addlistitem(scu_getDeviceChannels(fdID, AWG_list.channels_AW1), AW_dacs, ",", INF)
//					AW_dacs = removeSeperator(AW_dacs, ",")
//					for(j=0 ; j<8 ; j++)
//						if(whichlistItem(num2str(j),AW_dacs, ",") == -1)
//							fakeChRamp = j
//							break
//						endif
//					endfor
//				endif
//				string value = num2str(getfdacOutput(fdID,fakeChRamp, same_as_window = 0))
//				starts = value 
//				fins = value 
//				dacs = num2str(fakeChRamp)
//			endif
//	
//			
//		
//			adcs = replacestring(";",adcs,"")
//			S.adcLists = replacestringbykey(fdIDname, S.adcLists, adcs)
//			
//			///// WARNING THIS SETUP OF AWG MAY NOT WORK IN ALL CASES I JUTS WANTED TO GET A SCAN GOING ////./
//			// this is all for AWG //////////////////////////////////////////////////////////////////////////////////////////////////////////
//			if(!paramisDefault(AWG_list) && AWG_List.use_AWG == 1 && AWG_List.lims_checked == 1 && ((stringmatch(fdIDname, stringFromList(0,  AWG_list.channelIDs)) == 1) || (stringmatch(fdIDname, stringFromList(1,  AWG_list.channelIDs)) == 1)))
//				int numWaves  // this numwaves must be one or two. If two, the command to the fastDAC assumes both AW0 and AW1 are being used.
//				
//				// we first figure out all the AW dacs corresponding to the current fdID
//				if (stringmatch(fdIDname, stringFromList(0,  AWG_list.channelIDs)) == 1)
//					string AW0_dacs = replacestring(",",scu_getDeviceChannels(fdID, AWG_list.channels_AW0), "")
//				endif
//				if (stringmatch(fdIDname, stringFromList(1,  AWG_list.channelIDs)) == 1)
//					string AW1_dacs = replacestring(",",scu_getDeviceChannels(fdID, AWG_list.channels_AW1), "")
//				endif
//				// we need to run through some tests to see which one of AW0, AW1 is populated
//				// if both are unpopulated and we are using AWG then a fake squarewave will be implemented on a channel
//				
//				// if only AW1 is populated, it is remapped to AW0 because the command AWG_RAMP only knows how many waves to use. So if we say
//				// numWaves = 1, it will always assume AW0
//				if (numtype(strlen(AW1_dacs)) == 2)
//					AW1_dacs = ""
//				endif
//				if(!cmpstr(AW0_dacs,"") && !cmpstr(AW1_dacs,""))
//					for(j=0 ; j<8 ; j++)
//						if(strsearch(num2str(j),dacs,0) == -1)
//							value = num2str(getfdacOutput(fdID,j, same_as_window = 0))
//							AW_dacs = num2str(j)
//							//setup squarewave to have this output
//							setupfakesquarewave(fdID, str2num(value))
//							break
//						endif
//					endfor
//					AWG_list.numWaves  = 1
//				elseif(cmpstr(AW1_dacs,"") && !cmpstr(AW0_dacs,""))  //AW1 is populated, AW0 is not
//					AW_dacs = AW1_dacs
//					scw_setupAWG("setupAWG", instrID = fdID, mapOnetoZero = 1)
//					AWG_list.numWaves  = 1
//				elseif(cmpstr(AW0_dacs,"") && !cmpstr(AW1_dacs,"")) //AW0 is populated, AW1 is not
//					AW_dacs = AW0_dacs
//					AWG_list.numWaves  = 1
//				else															
//					AW_dacs = AW0_dacs + "," + AW1_dacs
//					AWG_list.numWaves  = 2
//				endif
//
//				sprintf cmd, "AWG_RAMP,%d,%s,%s,%s,%s,%s,%d,%d\r", AWG_list.numWaves, AW_dacs, dacs, adcs, starts, fins, AWG_list.numCycles, AWG_list.numSteps
//			else			
//				sprintf cmd, "INT_RAMP,%s,%s,%s,%s,%d\r", dacs, adcs, starts, fins, S.numptsx
//			endif
//		endif
//	
//		writeInstr(fdID,cmd)
//	endfor
end



// This function initiates a FastDAC measurement based on duration, with options for y-axis labeling and additional comments.
// If the 'nosave' flag is not set, the measurement data will be saved automatically.
Function ReadVsTimeFastdac(duration, [y_label, comments, nosave]) // Units: seconds
	Variable duration, nosave
	String comments, y_label

	// Default parameter handling: Assign empty strings if parameters are not provided
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")

	Wave fadcattr // Wave to hold FastDAC attributes (unused in provided code, could be for future use)
	Variable i = 0 // Loop index or counter (unused in provided code, could be for future use)
	String channels = scf_getRecordedFADCinfo("channels")  // Retrieve ADC channels marked for recording

	// Abort the function if no ADC channels are selected for recording
	if (itemsinlist(channels, ",") == 0)
		abort "[ERROR] \"ReadVsTimeFastdac\": No ADC channels selected"
	endif
	
	// Turn off resampling during noise spectrum scan
	nvar sc_ResampleFreqfadc
	variable original_resample_state = sc_ResampleFreqfadc 
	sc_ResampleFreqfadc = 1e6 // in this case the resampling will be skipped

	Struct ScanVars S // Declare a structure to hold scanning variables
	initScanVarsFD(S, 0, duration, duration=duration, x_label="time /s", y_label="Current /nA", comments=comments)
	// Initialize scanning variables with specified parameters. 
	// The initScanVarsFD function is a custom function not detailed here, assumed to setup scan parameters such as duration, labels, and comments.
	print  "this error is normal since we we don't sweep any DACs"


	S.readVsTime = 1 // Flag to indicate that this scan is a read versus time operation
	initializeScan(S) // Initialize the scan with the specified parameters

	scfd_RecordValues(S, 0) // Record the values based on the setup. This function is assumed to start the measurement process.

	// Decision block to handle data saving or display based on 'nosave' flag
	if (!nosave)
		EndScan(S=S) // Save the scan data and clean up if nosave is not true
	else
		dowindow/k SweepControl // If nosave is true, keep the sweep control window open for further interaction
	endif
	
	
	// Return resampling state to whatever it was before
	sc_ResampleFreqfadc = original_resample_state
End


function ScanFastDacSlow(start, fin, channels, numpts, delay, ramprate, [starts, fins, y_label, repeats, alternate, delayy, until_checkwave, until_stop_val, until_operator, comments, nosave, pid]) //Units: mV
	// sweep one or more FastDAC channels but in the ScanController way (not ScanControllerFastdac). I.e. ramp, measure, ramp, measure...
	// channels should be a comma-separated string ex: "0, 4, 5"
	
	
	// not tested but should likely work - master/slave updated. - can be tested
	
	variable start, fin, numpts, delay, ramprate, nosave, until_stop_val, repeats, alternate, delayy, pid
	string channels, y_label, comments, until_operator, until_checkwave
	string starts, fins // For different start/finish points for each channel (must match length of channels if used)
	if (paramIsDefault(pid))
	// Reconnect instruments
	endif 
	//check if rawdata needs to be saved
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	starts = selectstring(paramisdefault(starts), starts, "")
	fins = selectstring(paramisdefault(fins), fins, "")
	until_operator = selectstring(paramisdefault(until_operator), until_operator, "not_set")
	delayy = ParamIsDefault(delayy) ? 5*delay : delayy


	// Initialize ScanVars
	struct ScanVars S  // Note, more like a BD scan if going slow
	initScanVarsFD(S, start, fin, channelsx=channels, numptsx=numpts, delayx=delay, rampratex=ramprate, startxs = starts, finxs = fins, comments=comments, y_label=y_label,\
	 		starty=1, finy=repeats,  numptsy=repeats, alternate=alternate, delayy=delay)  
	if (s.is2d && strlen(S.y_label) == 0)
		S.y_label = "Repeats"
	endif	 		
	S.using_fastdac = 0 // Explicitly showing that this is not a normal fastDac scan
	S.duration = numpts*max(0.05, delay) // At least 50ms per point is a good estimate 
	S.sweeprate = abs((fin-start)/S.duration) // Better estimate of sweeprate (Not really valid for a slow scan)

	// Check limits (not as much to check when using FastDAC slow)
	scc_checkLimsFD(S)
	S.lims_checked = 1
	
	// set devices needed to master slave
	//set_master_slave(S)  We don't need master-slave for slow sweeps
	
	// Ramp to start without checks because checked above
	RampStartFD(S, ignore_lims=1)

	// Let gates settle 
	sc_sleep(S.delayy)

	// Make Waves and Display etc
	InitializeScan(S)

	// Main measurement loop
	variable i=0, j=0
	variable d=1
	for (j=0; j<S.numptsy; j++)
		S.direction = d  // Will determine direction of scan in fd_Record_Values

		// Ramp to start of fast axis
		RampStartFD(S, ignore_lims=1, x_only=1)
		sc_sleep(S.delayy)
		i = 0
		do
			rampToNextSetpoint(S, i, ignore_lims=1)  // Ramp x to next setpoint
			sc_sleep(S.delayx)
			if (s.is2d)
				RecordValues(S, j, i)
			else
				RecordValues(S, i, 0)
			endif
			i+=1
		while (i<S.numptsx)
		
		if (alternate!=0) // If want to alternate scan scandirection for next row
			d = d*-1
		endif
		
	endfor
	svar fd
	if (pid)
		stoppid(1)
		//clearfdacBuffer(fd2)
	endif
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		dowindow /k SweepControl
	endif
end


function ScanFastDacSlow2D(startx, finx, channelsx, numptsx, delayx, starty, finy, channelsy, numptsy, rampratex, rampratey, [delayy, startxs, finxs, startys, finys, comments, nosave])
	// sweep one or more FastDAC channels but in the ScanController way (not ScanControllerFastdac). I.e. ramp, measure, ramp, measure...
	// channels should be a comma-separated string ex: "0, 4, 5"
	// ramprates have to be defined
	
	
	// not tested but should likely work - master/slave updated. - can be tested
	variable startx, finx, starty, finy, numptsy, numptsx, rampratex, rampratey, delayx, delayy, nosave
	string channelsx, channelsy, comments, startxs, finxs, startys, finys

	//check if rawdata needs to be saved

	// Reconnect instruments
	
	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	startxs = selectstring(paramisdefault(startxs), startxs, "")
	finxs = selectstring(paramisdefault(finxs), finxs, "")
	startys = selectstring(paramisdefault(startys), startys, "")
	finys = selectstring(paramisdefault(finys), finys, "")

	// Initialize ScanVars
	struct ScanVars S  
	 	initScanVarsFD(S, startx, finx, channelsx=channelsx, rampratex=rampratex, numptsx=numptsx, delayx=delayx,\
		  numptsy=numptsy, delayy=delayy, starty=starty, finy=finy, channelsy=channelsy, rampratey=rampratey,\
		  startxs=startxs, finxs=finxs, startys=startys, finys=finys, comments=comments, x_only = 0)
	S.using_fastdac = 0   // This is not a normal fastDac scan
	S.duration = S.numptsx*max(0.05, S.delayx) // At least 50ms per point is a good estimate 
	S.sweeprate = abs((S.finx-S.startx)/S.duration) // Better estimate of sweeprate (Not really valid for a slow scan)

	// Check limits (not as much to check when using FastDAC slow)
	scc_checkLimsFD(S)
	S.lims_checked = 1
	
	//set devices to master slave
	//set_master_slave(S): we do not need master-slave for slow scans

	// Ramp to start without checks because checked above
	RampStartFD(S, ignore_lims=1)

	// Let gates settle 
	sc_sleep(S.delayy*5)

	// Make Waves and Display etc
	InitializeScan(S)

	// Main measurement loop
	variable i=0, j=0, k=0, setpointx, setpointy
	for(i=0; i<S.numptsy; i++)
		rampToNextSetpoint(S, 0, outer_index=i, ignore_lims=1)  // Ramp x to start and y to next setpoint
		sc_sleep(S.delayy)
		for(j=0; j<S.numptsx; j++)
			// Ramp X to next setpoint
			rampToNextSetpoint(S, j, ignore_lims=1)  // Ramp x to next setpoint
			sc_sleep(S.delayx)
			RecordValues(S, i, j)
		endfor
	endfor
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		dowindow /k SweepControl
	endif
end

////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////// Spectrum Analyzer //////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////
function FDSpectrumAnalyzer(scanlength,[numAverage, raw_graphs, calc_graphs, comments,nosave])
	// NOTE: Make sure the Calc function is set up in Scancontroller_Fastdac such that the result is in nA (not A)
	// scanlength is in sec
	// raw_graphs: whether to show the raw ADC readings
	// calc_graphs: Whether to show the readings after converting to nA (assuming Calc function is set up correctly)
	variable scanlength, numAverage, raw_graphs, calc_graphs, nosave
	string comments
	
	comments = selectString(paramisdefault(comments), comments, "")	
	numAverage = paramisDefault(numAverage) ? 1 : numAverage
	raw_graphs = paramisdefault(raw_graphs) ? 0 : raw_graphs
	calc_graphs = paramisdefault(calc_graphs) ? 1 : calc_graphs	
	
	
	// Turn off resampling during noise spectrum scan
	nvar sc_ResampleFreqfadc
	variable original_resample_state = sc_ResampleFreqfadc 
	sc_ResampleFreqfadc = 1e6 // in this case the resampling will be skipped

	// Initialize ScanVars
	Struct ScanVars S
	initScanVarsFD(S, 0, scanlength, duration=scanlength, starty=1, finy=numAverage, numptsy=numAverage, x_label="Time /s", y_label="Current /nA", comments="spectrum,"+comments)
	S.readVsTime = 1

	// Check limits (not as much to check when using FastDAC slow)
	scc_checkLimsFD(S)
	S.lims_checked = 1
	
	// Ramp to start without checks because checked above
	RampStartFD(S, ignore_lims=1)

	// Let gates settle 
	sc_sleep(S.delayy)

	// Initialize graphs and waves
	initializeScan(S, init_graphs=0)  // Going to open graphs below

	// Initialize Spectrum waves
	string wn, wn_lin, wn_int
	string lin_freq_wavenames = ""
	string int_freq_wavenames = ""	
	variable numChannels =S.numADCs// scf_getNumRecordedADCs()
	string adc_channels = S.adclist //list of ADC channels clicked
	variable i
	for(i=0;i<numChannels;i+=1)
		wn_lin = "spectrum_fftADClin"+stringfromlist(i,adc_channels, ";")
		make/o/n=(S.numptsx/2) $wn_lin = nan
		setscale/i x, 0, S.measureFreq/(2.0), $wn_lin
		lin_freq_wavenames = addListItem(wn_lin, lin_freq_wavenames, ";", INF)
		
		wn_int = "spectrum_fftADCint"+stringfromlist(i,adc_channels, ";")
		make/o/n=(S.numptsx/2) $wn_int = nan
		setscale/i x, 0, S.measureFreq/(2.0), $wn_int
		int_freq_wavenames = addListItem(wn_int, int_freq_wavenames, ";", INF)		
	endfor

	// Initialize all graphs
	string all_graphIDs = ""
	if (raw_graphs)
		all_graphIDs += scg_initializeGraphsForWavenames(sci_get1DWaveNames(1,1), "Time /s", for_2d=0, y_label="ADC /mV")  // RAW ADC readings
		if (S.is2d)
			all_graphIDs += scg_initializeGraphsForWavenames(sci_get1DWaveNames(1,1), "Time /s", for_2d=1, only_2d=1, y_label="Repeats")  // RAW ADC readings
		endif
	endif
	if (calc_graphs)
		all_graphIDs += scg_initializeGraphsForWavenames(sci_get1DWaveNames(0,1), "Time /s", for_2d=0, y_label="Current /nA")    // Calculated data (should be in nA)
		if (S.is2d)
			all_graphIDs += scg_initializeGraphsForWavenames(sci_get1DWaveNames(1,1), "Time /s", for_2d=1, only_2d=1, y_label="Repeats")  // RAW ADC readings
		endif
	endif
	
	string graphIDs
	graphIDs = scg_initializeGraphsForWavenames(lin_freq_wavenames, "Frequency /Hz", for_2d=0, y_label="nA^2/Hz")
	string gid
	for (i=0;i<itemsInList(graphIDs);i++)
		gid = StringFromList(i, graphIDs)
		modifyGraph/W=$gid log(left)=1
	endfor
	all_graphIDs = all_graphIDs+graphIDs
	all_graphIDs += scg_initializeGraphsForWavenames(int_freq_wavenames, "Frequency /Hz", for_2d=0, y_label="nA^2")
	scg_arrangeWindows(all_graphIDs)

	// Record data
	string wavenames = scf_getRecordedFADCinfo("calc_names")  // ";" separated list of recorded calculated waves
	variable j
	for (i=0; i<numAverage; i++)
		scfd_RecordValues(S, i)		

		for (j=0;j<itemsInList(wavenames);j++)
			// Calculate spectrums from calc wave
			wave w = $stringFromList(j, wavenames)
			wave fftwlin = fd_calculate_spectrum(w, linear=1)  // Linear spectrum

			// Add to averaged waves
			wave fftwavelin = $stringFromList(j, lin_freq_wavenames)
			if(i==0) // If first pass, initialize waves
				fftwavelin = fftwlin
			else  // Else add and average
				fftwavelin = fftwavelin*i + fftwlin
				fftwavelin = fftwavelin/(i+1)
			endif
			wave fftwaveint = $stringFromList(j, int_freq_wavenames)
			integrate fftwavelin /D=fftwaveint
			
			
			
		endfor
		doupdate
	endfor
	if (!nosave)
		EndScan(S=S, additional_wavenames=lin_freq_wavenames+int_freq_wavenames) 		
	endif

	// Return resampling state to whatever it was before
	sc_ResampleFreqfadc = original_resample_state
end


function/WAVE fd_calculate_spectrum(time_series, [scan_duration, linear])
	// Takes time series data and returns power spectrum
	wave time_series  // Time series (in correct units -- i.e. check that it's in nA first)
	variable scan_duration // If passing a wave which does not have Time as x-axis, this will be used to rescale
	variable linear // Whether to return with linear scale (or log scale)
	
	linear = paramisDefault(linear) ? 1 : linear

	duplicate/free time_series tseries
	if (scan_duration)
		setscale/i x, 0, scan_duration, tseries
	else
		scan_duration = DimDelta(time_series, 0) * DimSize(time_series, 0)
	endif

	variable last_val = dimSize(time_series,0)-1
	if (mod(dimsize(time_series, 0), 2) != 0)  // ODD number of points, must be EVEN to do powerspec
		last_val = last_val - 1
	endif
		
	
	// Built in powerspectrum function

	if (!linear)  // Use log scale
		DSPPeriodogram/PARS/DBR=1/NODC=2/R=[0,(last_val)] tseries  
		wave w_Periodogram
		duplicate/free w_Periodogram, powerspec
		powerspec = powerspec+10*log(scan_duration)  // This is so that the powerspec is independent of scan_duration
	else  // Use linear scale
		DSPPeriodogram/PARS/NODC=2/R=[0, (last_val)] tseries
		wave w_Periodogram
		duplicate/free w_Periodogram, powerspec
		// TODO: I'm not sure this is correct, but I don't know what should be done to fix it -- TIM
		powerspec = powerspec*scan_duration  // This is supposed to be so that the powerspec is independent of scan_duration
	endif
//	powerspec[0] = NaN
	return powerspec
end
//
//function plotPowerSpectrum(w, [scan_duration, linear, powerspec_name])
//	wave w
//	variable scan_duration, linear
//	string powerspec_name // Wavename to save powerspectrum in (useful if you want to display more than one at a time)
//	
//	linear = paramisDefault(linear) ? 1 : linear
//	wave powerspec = fd_calculate_spectrum(w, scan_duration=scan_duration, linear=linear)
//	
//	if(!paramIsDefault(powerspec_name))
//		duplicate/o powerspec $powerspec_name
//		wave tempwave = $powerspec_name
//	else
//		duplicate/o powerspec tempwave
//	endif
//
//	string y_label = selectString(linear, "Spectrum [dBnA/sqrt(Hz)]", "Spectrum [nA/sqrt(Hz)]")
//	scg_initializeGraphsForWavenames(NameOfWave(tempwave), "Frequency /Hz", for_2d=0, y_label=y_label)
//	 doWindow/F $winName(0,1)
//end
//


