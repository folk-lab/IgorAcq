#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

//////////////////////////////////////
///////////// Structs ////////////////
//////////////////////////////////////


	/////////////////////////////////////////////////
	//////////////////  ScanVars /////////////////// (scv_...)
	////////////////////////////////////////////////

	// Structure to hold scan information (general to all scans)
	// Note: If modifying this, also modify the scv_setLastScanVars and scv_getLastScanVars accordingly (and to have it save to HDF, modify sc_createSweepLogs)
	structure ScanVars
	variable instrIDx
	variable instrIDy // If using a second device for second axis of a scan (otherwise should be same as instrIDx)

	variable lims_checked // Flag that gets set to 1 after checks on software limits/ramprates etc has been carried out (particularly important for fastdac scans which has no limit checking for the sweep)

	string channelsx
	variable startx, finx, numptsx, rampratex
	variable delayx  // delay after each step for Slow scans (has no effect for Fastdac scans)
	string startxs, finxs  // If sweeping from different start/end points for each channel or instrument

	// For 2D scans
	variable is2d  // this is checked if its a 1d scan with multiple repeats(in ScanFastDac) or if its a 2d scan (ScanFastDac2D)
	string channelsy
	variable starty, finy, numptsy, rampratey
	variable delayy  // delay after each step in y-axis (e.g. settling time after x-axis has just been ramped from fin to start quickly)
	string startys, finys  // Similar for Y-axis

	// For specific scans
	variable alternate  // Allows controlling scan from start -> fin or fin -> start (with 1 or -1)
	variable duration   // Can specify duration of scan rather than numpts or sweeprate for readVsTime
	variable readVsTime // Set to 1 if doing a readVsTime
	variable interlaced_y_flag // Whether there are different values being interlaced in the y-direction of the scan
	string interlaced_channels // Channels that the scan will interlace between
	string interlaced_setpoints // Setpoints of each channel to interlace between e.g. "0,1,2;0,10,20" will expect 2 channels (;) which interlace between 3 values each (,)
	variable interlaced_num_setpoints // Number of setpoints for each channel (calculated in InitScanVars)
	variable silent_scan // For fast x sweeps with large numptsy (e.g. 2k x 10k) the 2D graph update time becomes significant

	// Other useful info
	variable start_time // Should be recorded right before measurements begin (e.g. after all checks are carried out)
	variable end_time // Should be recorded right after measurements end (e.g. before getting sweeplogs etc)
	string x_label // String to show as x_label of scan (otherwise defaults to gates that are being swept)
	string y_label  // String to show as y_label of scan (for 2D this defaults to gates that are being swept)
	variable using_fastdac // Set to 1 when using fastdac
	string comments  // Additional comments to save in HDF sweeplogs (easy place to put keyword flags for later analysis)

	// Specific to Fastdac
	variable numADCs  // How many ADCs are being recorded
	variable samplingFreq, measureFreq  // measureFreq = samplingFreq/numADCs
	variable sampling_time
	variable sweeprate  // How fast to sweep in mV/s (easier to specify than numpts for fastdac scans)
	string adcList // Which adcs' are being recorded
	string raw_wave_names  // Names of waves to override the names raw data is stored in for FastDAC scans
	variable lastread //keeps track of which files have already been read

	// Backend use
	variable direction   // For keeping track of scan direction when using alternating scan
	variable never_save   // Set to 1 to make sure these ScanVars are never saved (e.g. if using to get throw away values for getting an ADC reading)
	variable filenum 		// Filled when getting saved

	// master/slave sync use
	variable freeMem		// keep track of Memory usage in experiment
	string instrIDs      	// should contain a string list of the devices being used (ramping across devices or recording across devices)
	string adcListIDs    	// Ids for adcList (under //specific to fastDAC comment)
	string dacListIDs    	// Ids for channelx (for now, not sure ill change this yet)
	variable maxADCs     	// should contain the number with the most ADCs being recorded // I dont use this
	string fakeRecords   	// ADC channels used for fakeRecording
	string adcLists      	// adclist by id -> attempting to use stringbykey
	string IDstartxs, IDfinxs  // If sweeping from different start/end points for each channel or instrument / This one is a stringkey with fdIDs
	string dacListIDs_y     // Ids for channely (for now, not sure ill change this yet)

	//// AWG usage
	variable use_AWG 		// Is AWG going to be on during the scan; redundant but then AWG will not have to be passed if not needed
	variable waveLen			// in samples (i.e. sum of samples at each setpoint for a single wave cycle)
	variable numCycles 	// # wave cycles per DAC step for a full 1D scan
	string AWG_DACs  // DACs to use in AWGs if we have 5 AWG waves, it would look like this: "11.1,11.0"; 1.0,1.3,1.2",....
	// so the list is a semi-coma separated string with the DACs coma-separated. ///*** maybe we will come up with a better
	//						solution for this
	
	variable hotcolddelay




	endstructure


Function scv_getLastScanVars(S)
	// This function populates a ScanVars structure with settings from global storage.
	Struct ScanVars &S
	Wave/T sc_lastScanVarsStrings
	Wave sc_lastScanVarsVariables


	// Retrieve global string settings
	if(WaveExists(sc_lastScanVarsStrings))
		// Assuming S is a reference to a ScanVars structure and sc_lastScanVarsStrings exists and is populated
		S.channelsx = sc_lastScanVarsStrings[0]
		S.startxs = sc_lastScanVarsStrings[1]
		S.finxs = sc_lastScanVarsStrings[2]
		S.channelsy = sc_lastScanVarsStrings[3]
		S.startys = sc_lastScanVarsStrings[4]
		S.finys = sc_lastScanVarsStrings[5]
		S.interlaced_channels = sc_lastScanVarsStrings[6]
		S.interlaced_setpoints = sc_lastScanVarsStrings[7]
		S.x_label = sc_lastScanVarsStrings[8]
		S.y_label = sc_lastScanVarsStrings[9]
		S.adcList = sc_lastScanVarsStrings[10]
		S.raw_wave_names = sc_lastScanVarsStrings[11]
		S.instrIDs = sc_lastScanVarsStrings[12]
		S.adcListIDs = sc_lastScanVarsStrings[13]
		S.dacListIDs = sc_lastScanVarsStrings[14]
		S.fakeRecords = sc_lastScanVarsStrings[15]
		S.adcLists = sc_lastScanVarsStrings[16]
		S.IDstartxs = sc_lastScanVarsStrings[17]
		S.IDfinxs = sc_lastScanVarsStrings[18]
		S.dacListIDs_y = sc_lastScanVarsStrings[19]
		S.comments = sc_lastScanVarsStrings[20]
		S.AWG_DACs=sc_lastScanVarsStrings[21]

		// Ensure this list matches the actual global storage structure and contents
	Else
		Print "Global string variables for ScanVars not found."
	EndIf

	// Retrieve global numeric settings
	if(WaveExists(sc_lastScanVarsVariables))
		// Assuming sc_lastScanVarsVariables wave has been filled with the correct ordering of numeric values
		S.instrIDx = sc_lastScanVarsVariables[0]
		S.instrIDy = sc_lastScanVarsVariables[1]
		S.lims_checked = sc_lastScanVarsVariables[2]
		S.startx = sc_lastScanVarsVariables[3]
		S.finx = sc_lastScanVarsVariables[4]
		S.numptsx = sc_lastScanVarsVariables[5]
		S.rampratex = sc_lastScanVarsVariables[6]
		S.delayx = sc_lastScanVarsVariables[7]
		S.is2d = sc_lastScanVarsVariables[8]
		S.starty = sc_lastScanVarsVariables[9]
		S.finy = sc_lastScanVarsVariables[10]
		S.numptsy = sc_lastScanVarsVariables[11]
		S.rampratey = sc_lastScanVarsVariables[12]
		S.delayy = sc_lastScanVarsVariables[13]
		S.alternate = sc_lastScanVarsVariables[14]
		S.duration = sc_lastScanVarsVariables[15]
		S.readVsTime = sc_lastScanVarsVariables[16]
		S.interlaced_y_flag = sc_lastScanVarsVariables[17]
		S.interlaced_num_setpoints = sc_lastScanVarsVariables[18]
		S.silent_scan = sc_lastScanVarsVariables[19]
		S.start_time = sc_lastScanVarsVariables[20]
		S.end_time = sc_lastScanVarsVariables[21]
		S.using_fastdac = sc_lastScanVarsVariables[22]
		S.numADCs = sc_lastScanVarsVariables[23]
		S.samplingFreq = sc_lastScanVarsVariables[24]
		S.measureFreq = sc_lastScanVarsVariables[25]
		S.sweeprate = sc_lastScanVarsVariables[26]
		S.lastread = sc_lastScanVarsVariables[27]
		S.direction = sc_lastScanVarsVariables[28]
		S.never_save = sc_lastScanVarsVariables[29]
		S.filenum = sc_lastScanVarsVariables[30]
		S.freeMem = sc_lastScanVarsVariables[31]
		S.maxADCs = sc_lastScanVarsVariables[32]
		S.use_AWG= 	sc_lastScanVarsVariables[33]	// Is AWG going to be on during the scan
		S.wavelen=sc_lastScanVarsVariables[34]
		S.numCycles=sc_lastScanVarsVariables[35]
		S.hotcolddelay=sc_lastScanVarsVariables[36]
		S.sampling_time=sc_lastScanVarsVariables[37]



		// Ensure this list matches the actual global storage structure and contents
	Else
		Print "Global numeric variables for ScanVars not found."
	EndIf
	
	//print S
End



Function scv_setLastScanVars(S)
	// Stores the current ScanVars structure settings into global waves.

	Struct ScanVars &S

	// Ensure global waves for storing string and numeric values exist
	Make/o/T/N=(22) sc_lastScanVarsStrings // Adjust size for the number of string fields
	Make/o/D/N=(38) sc_lastScanVarsVariables // Adjust size for the number of numeric fields

	// Storing string fields to sc_lastScanVarsStrings wave
	sc_lastScanVarsStrings[0] = S.channelsx  //FD xchannel numbers
	sc_lastScanVarsStrings[1] = S.startxs	
	sc_lastScanVarsStrings[2] = S.finxs
	sc_lastScanVarsStrings[3] = S.channelsy   //FD ychannel numbers
	sc_lastScanVarsStrings[4] = S.startys
	sc_lastScanVarsStrings[5] = S.finys
	sc_lastScanVarsStrings[6] = S.interlaced_channels
	sc_lastScanVarsStrings[7] = S.interlaced_setpoints
	sc_lastScanVarsStrings[8] = S.x_label   //x gate labels
	sc_lastScanVarsStrings[9] = S.y_label   // y gate labels
	sc_lastScanVarsStrings[10] = S.adcList
	sc_lastScanVarsStrings[11] = S.raw_wave_names
	sc_lastScanVarsStrings[12] = S.instrIDs
	sc_lastScanVarsStrings[13] = S.adcListIDs
	sc_lastScanVarsStrings[14] = S.dacListIDs  // get this from S.channelsx
	sc_lastScanVarsStrings[15] = S.fakeRecords
	sc_lastScanVarsStrings[16] = S.adcLists
	sc_lastScanVarsStrings[17] = S.IDstartxs
	sc_lastScanVarsStrings[18] = S.IDfinxs
	sc_lastScanVarsStrings[19] = S.dacListIDs_y   // get this from S.channelsy
	sc_lastScanVarsStrings[20] = S.comments


	// Storing numeric fields to sc_lastScanVarsVariables wave
	sc_lastScanVarsVariables[0] = S.instrIDx
	sc_lastScanVarsVariables[1] = S.instrIDy
	sc_lastScanVarsVariables[2] = S.lims_checked
	sc_lastScanVarsVariables[3] = S.startx
	sc_lastScanVarsVariables[4] = S.finx
	sc_lastScanVarsVariables[5] = S.numptsx
	sc_lastScanVarsVariables[6] = S.rampratex
	sc_lastScanVarsVariables[7] = S.delayx
	sc_lastScanVarsVariables[8] = S.is2d
	sc_lastScanVarsVariables[9] = S.starty
	sc_lastScanVarsVariables[10] = S.finy
	sc_lastScanVarsVariables[11] = S.numptsy
	sc_lastScanVarsVariables[12] = S.rampratey
	sc_lastScanVarsVariables[13] = S.delayy
	sc_lastScanVarsVariables[14] = S.alternate
	sc_lastScanVarsVariables[15] = S.duration
	sc_lastScanVarsVariables[16] = S.readVsTime
	sc_lastScanVarsVariables[17] = S.interlaced_y_flag
	sc_lastScanVarsVariables[18] = S.interlaced_num_setpoints
	sc_lastScanVarsVariables[19] = S.silent_scan
	sc_lastScanVarsVariables[20] = S.start_time
	sc_lastScanVarsVariables[21] = S.end_time
	sc_lastScanVarsVariables[22] = S.using_fastdac
	sc_lastScanVarsVariables[23] = S.numADCs
	sc_lastScanVarsVariables[24] = S.samplingFreq
	sc_lastScanVarsVariables[25] = S.measureFreq
	sc_lastScanVarsVariables[26] = S.sweeprate
	sc_lastScanVarsVariables[27] = S.lastread
	sc_lastScanVarsVariables[28] = S.direction
	sc_lastScanVarsVariables[29] = S.never_save
	sc_lastScanVarsVariables[30] = S.filenum
	sc_lastScanVarsVariables[31] = S.freeMem
	sc_lastScanVarsVariables[32] = S.maxADCs
	sc_lastScanVarsVariables[33] = S.use_AWG
	sc_lastScanVarsVariables[34]=S.wavelen
	sc_lastScanVarsVariables[35]=S.numCycles
	sc_lastScanVarsVariables[36]=S.hotcolddelay
	sc_lastScanVarsVariables[37]=S.sampling_time


End


End

