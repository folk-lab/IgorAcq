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

// Pre-scan setup
	if (S.is2d)
		S.y_label = "Repeats"
	endif
	PreScanChecksFD(S)

	
	// Ramp to start
	RampStartFD(S)  // Ramps to starting value
	// Let gates settle
	sc_sleep_noupdate(S.delayy)
	// Initiate Scan
	initializeScan(S, y_label = y_label)
	if (fake==1)
		abort
	endif
	// Main measurement loop
	int j, d = 1
	for (j = 0; j < S.numptsy; j++)
		S.direction = d  // Will determine direction of scan in fd_Record_Values
		
		// Interlaced Scan Stuff
		if (S.interlaced_y_flag)
			Ramp_interlaced_channels(S, mod(j, S.interlaced_num_setpoints))
		endif


		// Ramp to start of fast axis // this would need to ramp all the DACs being used to their starting position (do we need synchronization)
		RampStartFD(S, ignore_lims = 1, x_only = 1) // This uses ramp smart, Which does not account for synchronization. the important thing would be

		// to have all the dacs return to their respective starting positions
		sc_sleep(S.delayy)


		// Record values for 1D sweep
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
	delayy = ParamIsDefault(delayy) ? 0.01 : delayy

	y_label = selectstring(paramisdefault(y_label), y_label, "nA")
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
	interlaced_channels=interlaced_channels, interlaced_setpoints=interlaced_setpoints, comments=comments, x_only=0, use_AWG=use_AWG)
	
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
  	
	// Let gates settle
	sc_sleep(S.delayy)

	// Initialize waves and graphs
	initializeScan(S, y_label = y_label)

	// Main measurement loop
	variable setpointy, sy, fy
	string chy
	variable i = 0, j = 0, k = 0
	for(i = 0; i < S.numptsy; i++)
	
		///// LOOP FOR INTERLACE SCANS ///// 
		if (S.interlaced_y_flag)
			Ramp_interlaced_channels(S, mod(i, S.interlaced_num_setpoints))
//			Set_AWG_state(S, AWG, mod(i, S.interlaced_num_setpoints))
			if (mod(i, S.interlaced_num_setpoints) == 0) // Ramp slow axis only for first of interlaced setpoints
				rampToNextSetpoint(S, 0, outer_index = i, y_only=1, ignore_lims = 1)
			endif
		else
			// Ramp slow axis
			rampToNextSetpoint(S, 0, outer_index = i, y_only = 1, ignore_lims = 1) //uses the same, ramp multiple fdac but this function seems to be bd specific
		endif
	
		// Ramp fast axis to start
		rampToNextSetpoint(S, 0, ignore_lims=1)
	
		// Let gates settle
		sc_sleep(S.delayy)
		
		// Record fast axis
		scfd_RecordValues(S, i)//*, AWG_list=AWG)
		
	endfor
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	endif
	
end



function/s fd_start_sweep(S)
	Struct ScanVars &S
	//print S
//	string adcList=S.adcList;

	fd_reset_start_fin_from_direction(S)

	int numptsx = S.numptsx;
	if (S.readVsTime) 
		sample_ADC(S.adclistIDs,  S.numptsx, S.sampling_time)
	endif
	
	if (S.readvstime==0)
		if (S.use_awg == 1)
			awg_ramp(S)
		else
			linear_ramp(S)
		endif
	endif
	
	fd_reset_start_fin_from_direction(S)
	 
//	 fake_ramp( adclist,  startxs,  finxs, numptsx)
	 
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
	string adc_channels = S.adcList //list of ADC channels clicked
	string wavenames = scf_getRecordedFADCinfo("calc_names")  // ";" separated list of recorded calculated waves

	variable i
	for(i=0;i<numChannels;i+=1)
		wn_lin = "spectrum_fftADClin"+stringfromlist(i,wavenames, ";")
		make/o/n=(S.numptsx/2) $wn_lin = nan
		setscale/i x, 0, S.measureFreq/(2.0), $wn_lin
		lin_freq_wavenames = addListItem(wn_lin, lin_freq_wavenames, ";", INF)
		
		wn_int = "spectrum_fftADCint"+stringfromlist(i,wavenames, ";")
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





function Ramp_interlaced_channels(S, i)
	// TODO: Should this live in Scans.ipf? If so, is there a better location for it?
	struct ScanVars &S
	variable i
	
	string interlace_channel, interlaced_setpoints_for_channel
	wave/t fdacvalstr
	wave/t fdacnames

	
	variable interlace_value
	variable k
	for (k = 0; k < ItemsInList(S.interlaced_channels, ","); k++)
		interlace_channel = StringFromList(k, S.interlaced_channels, ",")  // return one of the channels in interlaced_channels
		interlaced_setpoints_for_channel = StringFromList(k, S.interlaced_setpoints, ";") // return string of values to interlace between for one of the channels in interlaced_channels
		interlace_value = str2num(StringFromList(mod(i, ItemsInList(interlaced_setpoints_for_channel, ",")), interlaced_setpoints_for_channel, ",")) // return the interlace value for specific channel, changes per 1d sweep
		
		//////////////////////// Additions to determine instrID from channel name //////////////
		// Check if channel actually exists on a FastDAC, if not skip
		if(numtype(str2num(interlace_channel)) != 0) // If possible channel is a name (not a number)
			duplicate/o/free/t/r=[][3] fdacvalstr fdacnames
			findvalue/RMD=[][3]/TEXT=interlace_channel/TXOP=5 fdacnames
			if(V_Value == -1)  // If channel not found, skip this "channel"
				continue 
			endif
		endif
		
		// Figure out which FastDAC the channel belongs to
		rampmultiplefDAC(interlace_channel, interlace_value)
	endfor

end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////"Lockin window"
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Window Lock_in_panel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(1177,75,1796,410)
	SetDrawLayer UserBack
	SetDrawEnv fsize= 16
	DrawText 226,175,"Press \"Esc\" to stop lockin"
	DrawText 410,225,"CA amplification (eg.  9 for 1e-9)"
	DrawText 291.666666666667,261,"The resistance calculation assumes a 100 divider for the \rvoltage bias (standard for Basel CA)"
	ValDisplay Lockin_var,pos={34.00,14.00},size={500.00,121.00},fSize=100
	ValDisplay Lockin_var,format="%0.2f kOhm",fStyle=1
	ValDisplay Lockin_var,limits={0,0,0},barmisc={0,1000},value=#"Lockin"
	Button start_task,pos={52.00,154.00},size={118.00,28.00},proc=ButtonProc
	Button start_task,title="start lock_in",fSize=16
	SetVariable LI_ampl,pos={39.00,204.00},size={153.00,23.00},bodyWidth=77
	SetVariable LI_ampl,title="amplitude",fSize=16,value=LI_ampl
	SetVariable LI_adc,pos={39.00,244.00},size={181.00,23.00},bodyWidth=77
	SetVariable LI_adc,title="ADC_channel",fSize=16,value=LI_adc
	SetVariable LI_dac,pos={39.00,278.00},size={146.00,23.00},bodyWidth=77
	SetVariable LI_dac,title="bias DAC",fSize=16,value=LI_dac
	SetVariable CA_amp,pos={289.00,202.00},size={111.00,23.00},bodyWidth=50
	SetVariable CA_amp,title="CA amp",help={"CA amplification (eg.  9 for 1e-9)"}
	SetVariable CA_amp,fSize=16,limits={5,9,1},value=LI_CAamp
	SetVariable update,pos={285.00,270.00},size={176.00,23.00},bodyWidth=77
	SetVariable update,title="update every",fSize=16,format="% .2f s"
	SetVariable update,limits={0,inf,0.05},value=LI_update
EndMacro

macro Lock_in()
//killvariables/z  LI_hi, LI_lo, Lockin, LI_adc, LI_ampl
variable/g  LI_hi, LI_lo, Lockin, LI_adc, LI_ampl, LI_CAamp, LI_update
string/g LI_dac


Lock_in_panel() 
endmacro

Function ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
nvar LI_update
	switch( ba.eventCode )
		case 2: // mouse up
	Variable numTicks = LI_update*60	// Run every  (1 ticks)
	CtrlNamedBackground Test, period=numTicks, proc=LI_Task1
	CtrlNamedBackground Test, start	
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

function LI_Task(s)		// This is the function that will be called periodically
	STRUCT WMBackgroundStruct &s
	variable in
	NVar LI_hi, LI_lo, Lockin, LI_adc, LI_ampl
	Svar LI_dac
	variable value,j
	wave wave0x
	

ScanFastDAC(-1, 1, "11.7",numptsx=4, nosave=1, use_awg=1)

execute("Lockin=mean(wave0x)")
	if (GetKeyState(0) & 32)
		Print "Lockin aborted by Escape"
		abort
	endif
	


	return 0	// Continue background task
End

function LI_Task1(s)		// This is the function that will be called periodically
	STRUCT WMBackgroundStruct &s
	variable in
	NVar LI_hi, LI_lo, Lockin, LI_adc, LI_ampl, LI_CAamp
	Svar LI_dac
	variable value,j
	

	RampMultipleFDAC(LI_dac, LI_ampl)
	LI_hi= get_one_FADCChannel(LI_adc)

	RampMultipleFDAC(LI_dac, -LI_ampl)
	LI_lo= get_one_FADCChannel(LI_adc)
	
	Lockin=(2*LI_ampl)/(LI_hi-LI_lo)*(10^(LI_CAamp-9))
	
	//uV/nA=kOhm
	
	Variable t0= ticks

	if (GetKeyState(0) & 32)
		Print "Lockin aborted by Escape"
		abort
	endif
	


	return 0	// Continue background task
End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
