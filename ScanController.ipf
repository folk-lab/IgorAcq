#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Scan Controller routines for 1d and 2d scans
// Version 1.7 August 8, 2016
// Version 1.8 XXXX X, 2017
// Version 2.0 May, 2018
// Version 3.0 March, 2020
// Version 4.0 Oct, 2021 -- Tim Child, Johann Drayne
// Authors: Mohammad Samani, Nik Hartman, Christian Olsen, Tim Child, Johann Drayne

// Updates in 2.0:

//		-- All drivers now uses the VISA xop, as it is the only one supporting multiple threads.
//			VDT and GPIB xop's should not be used anymore.
//		-- "Request scripts" are removed from the scancontroller window. Its only use was
//			 trying to do async communication (badly).
//    -- Added Async checkbox in scancontroller window

// Updates in 3.0:

//		-- Support for Fastdacs added (most Fastdac functions can be found in ScanController_Fastdac)
//		-- Minor: Added Dat# to graphs

// Updates in 4.0:

// 		-- Improved support for FastDACs (mostly works with multiple fastDACs connected now, although cannot sweep multiple at the same time)
// 		-- Significant refactoring of functions related to a Scan (i.e. initWaves, saveWaves etc) including opening graphs etc. 
//			All scans functions work with a ScanVars Struct which contains information about the current scan (instead of many globals)
// 		-- NOTE: Fully updated for the Fastdac related scans, only partially updated for other scans


////////////////////////////////
///////// utility functions ////
////////////////////////////////

function assertSeparatorType(list_string, assert_separator)
	// If the list_string does not include <assert_separator> but does include the other common separator between "," and ";" then 
	// an error is raised
	string list_string, assert_separator
	if (strsearch(list_string, assert_separator, 0) < 0)  // Does not contain desired separator (maybe only one item)
		string buffer
		strswitch (assert_separator)
			case ",":
				if (strsearch(list_string, ";", 0) >= 0)
					sprintf buffer, "ERROR[assertSeparatorType]: Expected separator = %s     Found separator = ;\r", assert_separator
					abort buffer
				endif
				break
			case ";":
				if (strsearch(list_string, ",", 0) >= 0)
					sprintf buffer, "ERROR[assertSeparatorType]: Expected separator = %s     Found separator = ,\r", assert_separator
					abort buffer
				endif
				break
			default:
				if (strsearch(list_string, ",", 0) >= 0 || strsearch(list_string, ";", 0) >= 0)
					sprintf buffer, "ERROR[assertSeparatorType]: Expected separator = %s     Found separator = , or ;\r", assert_separator
					abort buffer
				endif
				break
		endswitch		
	endif
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


/////////////////////////////////////
///// Common ScanController ///////////
/////////////////////////////////////
// I.e. Applicable to both regular ScanController and ScanController_Fastdac


// Structure to hold scan information (general to all scans) 
// Note: If modifying this, also modify the saveAsLastScanVarsStruct and loadLastScanVarsStruct accordingly (and to have it save to HDF, modify sc_createSweepLogs)
structure ScanVars
    variable instrID
    
    variable lims_checked // Flag that gets set to 1 after checks on software limits/ramprates etc has been carried out (particularly important for fastdac scans which has no limit checking for the sweep)

    string channelsx
    variable startx, finx, numptsx, rampratex
    variable delayx  // delay after each step for Slow scans (has no effect for Fastdac scans)

    // For 2D scans
    variable is2d
    string channelsy 
    variable starty, finy, numptsy, rampratey 
    variable delayy  // delay after each step in y-axis (e.g. settling time after x-axis has just been ramped from fin to start quickly)

    // For scanRepeat
    variable direction  // Allows controlling scan from start -> fin or fin -> start (with 1 or -1)
    variable duration   // Can specify duration of scan rather than numpts or sweeprate

	// For ReadVsTime
	variable readVsTime // Set to 1 if doing a readVsTime

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
    variable sweeprate  // How fast to sweep in mV/s (easier to specify than numpts for fastdac scans)
    variable bdID // For using BabyDAC on Y-axis of Fastdac Scan
    string adcList 
    string startxs, finxs  // If sweeping from different start/end points for each DAC channel
    string startys, finys  // Similar for Y-axis
	string raw_wave_names  // Names of waves to store raw data in (defaults to ADC# for each ADC)
endstructure


function saveAsLastScanVarsStruct(S)  // TODO: rename to setLastScanVars
	Struct ScanVars &S
	// TODO: Make these (note: can't just use StructPut/Get because they only work for numeric entries, not strings...
	make/o/T sc_lastScanVarsStrings = {S.channelsx, S.channelsy, S.x_label, S.y_label, S.comments, S.adcList, S.startxs, S.finxs, S.startys, S.finys, S.raw_wave_names}
	make/o/d sc_lastScanVarsVariables = {S.instrID, S.lims_checked, S.startx, S.finx, S.numptsx, S.rampratex, S.delayx, S.is2d, S.starty, S.finy, S.numptsy, S.rampratey, S.delayy, S.direction, S.duration, S.readVsTime, S.start_time, S.end_time, S.using_fastdac, S.numADCs, S.samplingFreq, S.measureFreq, S.sweeprate, S.bdID}
end


function loadLastScanVarsStruct(S)   // TODO: Rename to loadLastScanVars
	Struct ScanVars &S
	// TODO: Make these (note: can't just use StructPut/Get because they only work for numeric entries, not strings...
	wave/T t = sc_lastScanVarsStrings
	wave v = sc_lastScanVarsVariables
	
	// Load String parts
	S.channelsx = t[0]
	S.channelsy = t[1]
	S.x_label = t[2]
	S.y_label = t[3]
	S.comments = t[4]
	S.adcList = t[5]
	S.startxs = t[6]
	S.finxs = t[7]
	S.startys = t[8]
	S.finys = t[9]
	S.raw_wave_names = t[10]

	// Load Variable parts
	S.instrID = v[0]
	S.lims_checked = v[1]
	S.startx = v[2]
	S.finx = v[3]
	S.numptsx = v[4]
	S.rampratex = v[5]
	S.delayx = v[6]
	S.is2d = v[7]
	S.starty = v[8]
	S.finy = v[9]
	S.numptsy = v[10]
	S.rampratey = v[11]
	S.delayy = v[12]
	S.direction = v[13]
	S.duration = v[14]
	S.readVsTime = v[15]
	S.start_time = v[16]
	S.end_time = v[17]
	S.using_fastdac = v[18]
	S.numADCs = v[19]
	S.samplingFreq = v[20]
	S.measureFreq = v[21]
	S.sweeprate = v[22]
	S.bdID = v[23]
end
	

function initFDscanVars(S, instrID, startx, finx, [channelsx, numptsx, sweeprate, duration, rampratex, delayx, starty, finy, channelsy, numptsy, rampratey, delayy, direction, startxs, finxs, startys, finys, x_label, y_label, comments])
    // Function to make setting up scanVars struct easier for FastDAC scans
    // PARAMETERS:
    // startx, finx, starty, finy -- Single start/fin point for all channelsx/channelsy
    // startxs, finxs, startys, finys -- For passing in multiple start/fin points for each channel as a comma separated string instead of a single start/fin for all channels
    //		Note: Just pass anything for startx/finx if using startxs/finxs, they will be overwritten
    struct ScanVars &S
    variable instrID
    variable startx, finx, numptsx, delayx, rampratex
    variable starty, finy, numptsy, delayy, rampratey
	variable sweeprate  // If start != fin numpts will be calculated based on sweeprate
	variable duration   // numpts will be caluculated to achieve duration
    string channelsx, channelsy
    string startxs, finxs, startys, finys
    string  x_label, y_label
    string comments
    variable direction
	
	channelsy = selectString(paramIsDefault(channelsy), channelsy, "")
	startys = selectString(paramIsDefault(startys), startys, "")
	finys = selectString(paramIsDefault(finys), finys, "")
	y_label = selectString((paramIsDefault(y_label) || numtype(strlen(y_label)) == 2), y_label, "")	

	channelsx = selectString(paramIsDefault(channelsx), channelsx, "")
	startxs = selectString(paramIsDefault(startxs), startxs, "")
	finxs = selectString(paramIsDefault(finxs), finxs, "")
	x_label = selectString((paramIsDefault(x_label) || numtype(strlen(x_label)) == 2), x_label, "")

	
    // Handle Optional Parameters
    S.numptsx = paramisdefault(numptsx) ? NaN : numptsx
    S.rampratex = paramisDefault(rampratex) ? NaN : rampratex
    S.delayx = paramisDefault(delayx) ? NaN : delayx

    S.sweeprate = paramisdefault(sweeprate) ? NaN : sweeprate  // TODO: Should this be different?

	S.numptsy = paramisdefault(numptsy) ? NaN : numptsy
    S.rampratey = paramisdefault(rampratey) ? NaN : rampratey
    S.delayy = paramisdefault(delayy) ? NaN : delayy

	// Set Variables in Struct
    S.instrID = instrID
    S.adcList = getRecordedFastdacInfo("channels")
    S.using_fastdac = 1
    S.comments = selectString(paramIsDefault(comments), comments, "")

	// For repeat scans 
    S.direction = paramisdefault(direction) ? 1 : direction
   	
   	// Sets channelsx, channelsy and is2d
    sv_setChannels(S, channelsx, channelsy, fastdac=1)
    
   	// Get Labels for graphs
   	S.x_label = selectString(strlen(x_label) > 0, GetLabel(S.channelsx, fastdac=1), x_label)  // Uses channels as list of numbers, and only if x_label not passed in
   	if (S.is2d)
   		S.y_label = selectString(strlen(y_label) > 0, GetLabel(S.channelsy, fastdac=1), y_label) 
   	else
   		S.y_label = y_label
   	endif  		

   	// Sets starts/fins in FD string format
    sv_setFDsetpoints(S, channelsx, startx, finx, channelsy, starty, finy, startxs, finxs, startys, finys)
	
	// Set variables with some calculation
    sv_setMeasureFreq(S) 		// Sets S.samplingFreq/measureFreq/numADCs	
    sv_setNumptsSweeprate(S) 	// Checks that either numpts OR sweeprate OR duration was provided, and sets ScanVars accordingly
                                // Note: Valid for start/fin only (uses S.startx, S.finx NOT S.startxs, S.finxs)

	// Set empty string just to not raise nullstring errors
	S.raw_wave_names = ""	// This should be overridden afterwards if necessary
end


function initBDscanVars(S, instrID, startx, finx, [channelsx, numptsx, sweeprate, delayx, rampratex, starty, finy, channelsy, numptsy, rampratey, delayy, direction, x_label, y_label, comments])
    // Function to make setting up scanVars struct easier for FastDAC scans
    // PARAMETERS:
    // startx, finx, starty, finy -- Single start/fin point for all channelsx/channelsy
    // startxs, finxs, startys, finys -- For passing in multiple start/fin points for each channel as a comma separated string instead of a single start/fin for all channels
    //		Note: Just pass anything for startx/finx if using startxs/finxs, they will be overwritten
    struct ScanVars &s
    variable instrID
    variable startx, finx, numptsx, delayx, rampratex
    variable starty, finy, numptsy, delayy, rampratey
    string channelsx
    string channelsy
    variable direction, sweeprate
    string x_label, y_label
    string comments
    
	// Handle Optional Parameters
	x_label = selectString((paramIsDefault(x_label) || numtype(strlen(x_label)) == 2), x_label, "")
	channelsx = selectString(paramisdefault(channelsx), channelsx, "")
	
	y_label = selectString((paramIsDefault(y_label) || numtype(strlen(y_label)) == 2), y_label, "")
	channelsy = selectString(paramisdefault(channelsy), channelsy, "")
	
    S.comments = selectString(paramIsDefault(comments), comments, "")
    S.startx = startx
    S.finx = finx
    s.numptsx = paramisdefault(numptsx) ? NaN : numptsx
    s.rampratex = paramisDefault(rampratex) ? NaN : rampratex
    s.delayx = paramisDefault(delayx) ? NaN : delayx

    s.sweeprate = paramisdefault(sweeprate) ? NaN : sweeprate  // TODO: Should this be different?
	
	s.starty = starty
	S.finy = finy
	s.numptsy = paramisdefault(numptsy) ? NaN : numptsy
    s.rampratey = paramisdefault(rampratey) ? NaN : rampratey
    s.delayy = paramisdefault(delayy) ? NaN : delayy
    
	// Set Variables in Struct
    s.instrID = instrID

	// For repeat scans 
    s.direction = paramisdefault(direction) ? 1 : direction
   	
   	// Sets channelsx, channelsy and is2d
    sv_setChannels(S, channelsx, channelsy, fastdac=0)
    
   	// Get Labels for graphs
   	S.x_label = selectString(strlen(x_label) > 0, GetLabel(S.channelsx, fastdac=0), x_label)  // Uses channels as list of numbers, and only if x_label not passed in
   	if (S.is2d)
	   	S.y_label = selectString(strlen(y_label) > 0, GetLabel(S.channelsy, fastdac=0), y_label) 
	else
		S.y_label = y_label
	endif
   	
   	// Used for Fastdac
   	S.startxs = ""
   	S.finxs = ""
   	S.startys = ""
   	S.finys = ""
   	S.adcList = ""
	S.raw_wave_names = ""	
end


function sv_setNumptsSweeprate(S)
	Struct ScanVars &S
	 // If NaN then set to zero so rest of logic works
   if(numtype(S.sweeprate) == 2)
   		S.sweeprate = 0
   	endif
   
   // Chose which input to use for numpts of scan
	if (S.numptsx == 0 && S.sweeprate == 0 && S.duration == 0)
	    abort "ERROR[ScanFastDac]: User must provide either numpts OR sweeprate OR duration for scan (none provided)"
	elseif ((S.numptsx!=0 + S.sweeprate!=0 + S.duration!=0) > 1)
	    abort "ERROR[ScanFastDac]: User must provide either numpts OR sweeprate OR duration for scan (more than 1 provided)"
	elseif (S.numptsx!=0) // If numpts provided, just use that
	    S.sweeprate = fd_get_sweeprate_from_numpts(S.startx, S.finx, S.numptsx, S.measureFreq)
		S.duration = S.numptsx/S.measureFreq
	elseif (S.sweeprate!=0) // If sweeprate provided calculate numpts required
    	S.numptsx = fd_get_numpts_from_sweeprate(S.startx, S.finx, S.sweeprate, S.measureFreq)
		S.duration = S.numptsx/S.measureFreq
	elseif (S.duration!=0)  // If duration provided, calculate numpts required
		S.numptsx = S.measureFreq*S.duration
		S.sweeprate = fd_get_sweeprate_from_numpts(S.startx, S.finx, S.numptsx, S.measureFreq)
		if (numtype(S.sweeprate) != 0)  // TODO: Is this the right check? (For a start=fin=0 scan)
			S.sweeprate = NaN
		endif
   endif
end


function sv_setMeasureFreq(S)
	Struct ScanVars &S
   S.samplingFreq = getfadcSpeed(S.instrID)
   S.numADCs = getNumFADC()
   S.measureFreq = S.samplingFreq/S.numADCs  //Because sampling is split between number of ADCs being read //TODO: This needs to be adapted for multiple FastDacs
end


function sv_setChannels(S, channelsx, channelsy, [fastdac])
    // Set S.channelsx and S.channelys converting channel labels to numbers where necessary
    // Note: Also sets S.is2d
    struct ScanVars &S
    string channelsx, channelsy
    variable fastdac

    s.channelsx = SF_get_channels(channelsx, fastdac=fastdac)

	if (numtype(strlen(channelsy)) != 0 || strlen(channelsy) == 0)  // No Y set at all
		s.starty = NaN
		s.finy = NaN
		s.channelsy = ""
        s.is2d = 0
	else
		s.channelsy = SF_get_channels(channelsy, fastdac=fastdac)
       s.is2d = 1
    endif
end


function sv_setFDsetpoints(S, channelsx, startx, finx, channelsy, starty, finy, startxs, finxs, startys, finys)

    struct ScanVars &S
    variable startx, finx, starty, finy
    string channelsx, startxs, finxs, channelsy, startys, finys

	string starts, fins  // Strings to modify in format_setpoints
    // Set X
   	if ((numtype(strlen(startxs)) != 0 || strlen(startxs) == 0) && (numtype(strlen(finxs)) != 0 || strlen(finxs) == 0))  // Then just a single start/end for channelsx
   		s.startx = startx
		s.finx = finx	
        SFfd_format_setpoints(startx, finx, S.channelsx, starts, fins)  // Modifies starts, fins
		s.startxs = starts
		s.finxs = fins
	elseif (!(numtype(strlen(startxs)) != 0 || strlen(startxs) == 0) && !(numtype(strlen(finxs)) != 0 || strlen(finxs) == 0))
		SFfd_sanitize_setpoints(startxs, finxs, S.channelsx, starts, fins)  // Modifies starts, fins
		s.startx = str2num(StringFromList(0, starts, ","))
		s.finx = str2num(StringFromList(0, fins, ","))
		s.startxs = starts
		s.finxs = fins
	else
		abort "If either of startxs/finxs is provided, both must be provided"
	endif

    // If 2D then set Y
    if (S.is2d) 
        if ((numtype(strlen(startys)) != 0 || strlen(startys) == 0) && (numtype(strlen(finys)) != 0 || strlen(finys) == 0))  // Single start/end for Y
            s.starty = starty
            s.finy = finy	
            SFfd_format_setpoints(S.starty, S.finy, S.channelsy, starts, fins)  
            s.startys = starts
            s.finys = fins
        elseif (!(numtype(strlen(startys)) != 0 || strlen(startys) == 0) && !(numtype(strlen(finys)) != 0 || strlen(finys) == 0)) // Multiple start/end for Ys
            SFfd_sanitize_setpoints(startys, finys, S.channelsy, starts, fins)
            s.starty = str2num(StringFromList(0, starts, ","))
            s.finy = str2num(StringFromList(0, fins, ","))
            s.startys = starts
            s.finys = fins
        else
            abort "Something wrong with Y part. Note: If either of startys/finys is provided, both must be provided"
        endif
    else
    	S.startys = ""
    	S.finys = ""
    endif
end


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////// Initializing a Scan //////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function initializeScan(S)
    // Opens instrument connection, initializes waves to store data, opens and tiles graphs, opens abort window.
    struct ScanVars &S
    variable fastdac

    // Kill and reopen connections (solves some common issues)
    killVISA()
    sc_OpenInstrConnections(0)

    // Make sure waves exist to store data
    new_initializeWaves(S)

    // Set up graphs to display recorded data
    string activeGraphs
    activeGraphs = initializeGraphs(S)
    arrangeWindows(activeGraphs)

    // Open Abort window
    openAbortWindow()

    // Save struct to globals
    saveAsLastScanVarsStruct(S)
end


function new_initializeWaves(S)  // TODO: rename
    // Initializes the waves necessary for recording scan
	//  Need 1D and 2D waves for the raw data coming from the fastdac (2D for storing, not necessarily displaying)
	// 	Need 2D waves for either the raw data, or filtered data if a filter is set
	//		(If a filter is set, the raw waves should only ever be plotted 1D)
	//		(This will be after calc (i.e. don't need before and after calc wave))
    struct ScanVars &S
    variable fastdac

    variable numpts  // Numpts to initialize wave with, note: for Filtered data, this number is reduced
    string wavenames, wn
    variable i, j
    for (i = 0; i<2; i++) // 0 = Calc, 1 = Raw
        wavenames = get1DWaveNames(i, S.using_fastdac)
        sanityCheckWavenames(wavenames)
        if (S.using_fastdac)
	        numpts = (i) ? S.numptsx : postFilterNumpts(S.numptsx, S.measureFreq)  // Selects S.numptsx for i=1(Raw) and calculates numpts for i=0(Calc)
	     else
	     	numpts = S.numptsx
	     endif
        for (j=0; j<itemsinlist(wavenames);j++)
            wn = stringFromList(j, wavenames)
            init1DWave(wn, numpts, S.startx, S.finx)
            if (S.is2d == 1)
                init2DWave(wn+"_2d", numpts, S.startx, S.finx, S.numptsy, S.starty, S.finy)
            elseif (S.is2d == 2)
                abort "Need to fix how waves are initialized, i.e. need to replicate something like the commented code below instead of just init1Dwave(...)"
					// cmd = "make /o/n=(1, " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd) //Makes 1 by y wave, x is redimensioned in recordline
					// cmd = "setscale /P x, 0, " + num2str((sc_finx-sc_startx)/sc_numptsx) + "," + wn2d; execute(cmd) //sets x scale starting from 0 but with delta correct
					// cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)//Useful to see if top and bottom of scan are filled with NaNs
            endif
        endfor
    endfor

    // If a linecut scan, then initialize the Row start X value wave
    if (S.is2d == 2) 
        init1DWave("sc_linestart", numpts, S.starty, S.finy)  // Wave to store first X value for each sweep
    endif

    // TODO: This is where x_array and y_array were made, but that should just be done in the savewaves part now
end


function init1DWave(wn, numpts, start, fin)
    // Overwrites waveName with scaled wave from start to fin with numpts
    string wn
    variable numpts, start, fin
    string cmd
    make/O/n=(numpts) $wn = NaN  
    cmd = "setscale/I x " + num2str(start) + ", " + num2str(fin) + ", " + wn; execute(cmd)
end


function init2DWave(wn, numptsx, startx, finx, numptsy, starty, finy)
    // Overwrites waveName with scaled wave from start to fin with numpts
    string wn
    variable numptsx, startx, finx, numptsy, starty, finy
    string cmd
    make/O/n=(numptsx, numptsy) $wn = NaN  // TODO: can put in a cmd and execute if necessary
    cmd = "setscale/I x " + num2str(startx) + ", " + num2str(finx) + ", " + wn; execute(cmd)
	cmd = "setscale/I y " + num2str(starty) + ", " + num2str(finy) + ", " + wn; execute(cmd)
end


function/S get1DWaveNames(raw, fastdac)
    // Return a list of Raw or Calc wavenames (without any checks)
    variable raw, fastdac  // 1 for True, 0 for False
    
    string wavenames = ""
	if (fastdac == 1)
		if (raw == 1)
			wavenames = getRecordedFastdacInfo("raw_names")
		else
			wavenames = getRecordedFastdacInfo("calc_names")
		endif
    else  // Regular ScanController
        wave sc_RawRecord, sc_RawWaveNames
        wave sc_CalcRecord, sc_CalcWaveNames
        if (raw == 1)
            duplicate/free/o sc_RawRecord, recordWave
            duplicate/free/o/t sc_RawWaveNames, waveNameWave
        else
            duplicate/free/o sc_CalcRecord, recordWave
            duplicate/free/o/t sc_CalcWaveNames, waveNameWave
        endif
        variable i=0
        for (i = 0; i<numpnts(waveNameWave); i++)     
            if (recordWave[i])
                wavenames = addlistItem(waveNameWave[i], wavenames, ";", INF)
            endif
        endfor
    endif
	return wavenames
end


function/S get2DWaveNames(raw, fastdac)
    // Return a list of Raw or Calc wavenames (without any checks)
    variable raw, fastdac  // 1 for True, 0 for False
    string waveNames1D = get1DWaveNames(raw, fastdac)
    string waveNames2D = ""
    variable i
    for (i = 0; i<ItemsInList(waveNames1D); i++)
        waveNames2D = addlistItem(StringFromList(i, waveNames1D)+"_2d", waveNames2D, ";", INF)
    endfor
    return waveNames2D
end


function sanityCheckWavenames(wavenames)
    // Take comma separated list of wavenames, and check they all make sense
    string wavenames
    string s
    variable i
    for (i = 0; i<itemsinlist(wavenames); i++)
        s = stringFromList(i, wavenames)
        if (cmpstr(s, "") == 0)
            print "No wavename entered for one of the recorded waves"
            abort
        endif
        if (!((char2num(s[0]) >= 97 && char2num(s[0]) <= 122) || (char2num(s[0]) >= 65 && char2num(s[0]) <= 90)))
            print "The first character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
            abort
        endif
    endfor
end


/////////////////////////////////////////////////////////////////////////////
//////////////////////////// Opening and Layout out Graphs /////////////////////
/////////////////////////////////////////////////////////////////////////////

function/S initializeGraphs(S)
    // Initialize graphs that are going to be recorded
    // Returns list of Graphs that data is being plotted in
    struct ScanVars &S

	 string/g sc_rawGraphs1D = ""  // So that fd_record_values knows which graphs to update while reading

    string graphIDs = ""
    variable i
    string waveNames
    string buffer
	string ylabel
    variable raw
    for (i = 0; i<2; i++)  // i = 0, 1
        raw = !i
        waveNames = get1DWaveNames(raw, S.using_fastdac)
		if (S.is2d == 0 && raw == 1 && S.using_fastdac)
			ylabel = "ADC /mV"
		else
			ylabel = S.y_label
		endif
        buffer = initializeGraphsForWavenames(waveNames, S.x_label, is2d=S.is2d, y_label=ylabel)
        if(raw==1) // Raw waves
	        sc_rawGraphs1D = buffer
        endif
        graphIDs = graphIDs + buffer
    endfor
    return graphIDs
end


function/S initializeGraphsForWavenames(wavenames, x_label, [is2d, y_label])
	// Ensures a graph is open and tiles graphs for each wave in comma separated wavenames
	// Returns list of graphIDs of active graphs
	string wavenames, x_label, y_label
	variable is2d
	
	y_label = selectString(paramisDefault(y_label), y_label, "")
	string y_label_2d = y_label
	string y_label_1d = selectString(is2d, y_label, "")  // Only use the y_label for 1D graphs if the scan is 1D (otherwise gets confused with y sweep gate)


	string wn, openGraphID, graphIDs = ""
	variable i
	for (i = 0; i<ItemsInList(waveNames); i++)  // Look through wavenames that are being recorded
	    wn = StringFromList(i, waveNames)
	    openGraphID = graphExistsForWavename(wn)
	    if (cmpstr(openGraphID, "")) // Graph is already open (str != "")
	        setUpGraph1D(openGraphID, x_label, y_label=y_label_1d)  
	    else 
	        open1Dgraph(wn, x_label, y_label=y_label, y_label=y_label_1d)
	        openGraphID = winname(0,1)
	    endif
       graphIDs = addlistItem(openGraphID, graphIDs, ";", INF)


	    if (is2d)
	        wn = wn+"_2d"
	        openGraphID = graphExistsForWavename(wn)
	        if (cmpstr(openGraphID, "")) // Graph is already open (str != "")
	            setUpGraph2D(openGraphID, wn, x_label, y_label_2d)
	        else 
	            open2Dgraph(wn, x_label, y_label_2d)
	            openGraphID = winname(0,1)
	        endif
           graphIDs = addlistItem(openGraphID, graphIDs, ";", INF)
	    endif
	endfor
	return graphIDs
end


function arrangeWindows(graphIDs)
    // Tile Graphs and/or windows etc
    string graphIDs
    string cmd, windowName
    cmd = "TileWindows/O=1/A=(3,4) "  
    variable i
    for (i = 0; i<itemsInList(graphIDs); i++)
        windowName = StringFromList(i, graphIDs)
        cmd += windowName+", "
        doWindow/F $windowName // Bring window to front 
    endfor
    execute(cmd)
    doupdate
end


function/S graphExistsForWavename(wn)
    // Checks if a graph is open containing wn, if so returns the graphTitle otherwise returns ""
    string wn
    string graphTitles = getOpenGraphTitles() 
    string graphIDs = getOpenGraphIDs()
    string title
    variable i
    for (i = 0; i < ItemsInList(graphTitles, "|"); i++)  // Stupid separator to avoid clashing with all the normal separators Igor uses in title names  
        title = StringFromList(i, graphTitles, "|")
        if (stringMatch(wn, title))
            return stringFromList(i, graphIDs)  
        endif
    endfor
    return ""
end


function open1Dgraph(wn, x_label, [y_label])
    // Opens 1D graph for wn
    string wn, x_label, y_label
    
    y_label = selectString(paramIsDefault(y_label), y_label, "")
    
    display $wn
    setWindow kwTopWin, graphicsTech=0
    
    setUpGraph1D(WinName(0,1), x_label, y_label=y_label)
end


function open2Dgraph(wn, x_label, y_label)
    // Opens 2D graph for wn
    string wn, x_label, y_label
    wave w = $wn
    if (dimsize(w, 1) == 0)
    	abort "Trying to open a 2D graph for a 1D wave"
    endif
    
    display
    setwindow kwTopWin, graphicsTech=0
    appendimage $wn
    setUpGraph2D(WinName(0,1), wn, x_label, y_label)
end


function setUpGraph1D(graphID, x_label, [y_label])
    // Sets up the axis labels, and datnum for a 1D graph
    string graphID, x_label, y_label
    
    // Handle Defaults
    y_label = selectString(paramIsDefault(y_label), y_label, "")
    
    
    // Sets axis labels, datnum etc
    setaxis/w=$graphID /a
    Label /W=$graphID bottom, x_label

    Label /W=$graphID left, y_label

	nvar filenum
	
    TextBox /W=$graphID/C/N=datnum/A=LT/X=1.0/Y=1.0/E=2 "Dat"+num2str(filenum)
end


function setUpGraph2D(graphID, wn, x_label, y_label)
    string graphID, wn, x_label, y_label
    svar sc_ColorMap
    // Sets axis labels, datnum etc
    Label /W=$graphID bottom, x_label
    Label /W=$graphID left, y_label

    modifyimage /W=$graphID $wn ctab={*, *, $sc_ColorMap, 0}
    colorscale /c/n=$sc_ColorMap /e/a=rc image=$wn

	nvar filenum
    TextBox /W=$graphID/C/N=datnum/A=LT/X=1.0/Y=1.0/E=2 "Dat"+num2str(filenum)
    
end


function/S getOpenGraphTitles()
	// GraphTitle == name after the ":" in graph window names
	// e.g. "Graph1:testwave" -> "testwave"
	// Returns a list of GraphTitles
	// Useful for checking which waves are displayed in a graph
	string graphlist = winlist("*",";","WIN:1")
    string graphTitles = "", graphName, graphNum, plottitle
	variable i, j=0, index=0
	for (i=0;i<itemsinlist(graphlist);i=i+1)
		index = strsearch(graphlist,";",j)
		graphname = graphlist[j,index-1]
		getwindow $graphname wtitle
		splitstring /e="(.*):(.*)" s_value, graphnum, plottitle
		graphTitles = AddListItem(plottitle, graphTitles, "|", INF) // Use a stupid separator so that it doesn't clash with ", ; :" that Igor uses in title strings 
//		graphTitles += plottitle+"|" 
		j=index+1
	endfor
    return graphTitles
end

function/S getOpenGraphIDs()
	// GraphID == name before the ":" in graph window names
	// e.g. "Graph1:testwave" -> "Graph1"
	// Returns a list of GraphIDs
	// Use these to specify graph with /W=<graphID>
	string graphlist = winlist("*",";","WIN:1")
	return graphlist
end


function openAbortWindow()
    // Opens the window which allows for pausing/aborting/abort+saving a scan
    variable/g sc_abortsweep=0, sc_pause=0, sc_abortnosave=0 // Make sure these are initialized
    doWindow/k/z SweepControl  // Attempt to close previously open window just in case
    execute("abortmeasurementwindow()")
    doWindow/F SweepControl   // Bring Sweepcontrol to the front 
end


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////// Common Scancontroller Functions /////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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
		print "WARNING[sc_checkBackup]: Only saving local copies of data. Set a server path with \"NewPath server\" (only to folder which contains \"local-measurement-data\")"
		return 0
	else
		// this should also create the path if it does not exist
		string sp = S_path
		newpath /C/O/Q backup_data sp+sc_hostname+":"+getExpPath("data", full=1)
		newpath /C/O/Q backup_config sp+sc_hostname+":"+getExpPath("config", full=1)
		return 1
	endif
end


////////////////////////////
///// Sweep controls   /////
////////////////////////////
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
			print "[SCAN] Scan will abort and the incomplete dataset will be saved."
			break
		case "stopsweepnosave":
			sc_abortnosave = 1
			print "[SCAN] Scan will abort and dataset will not be saved."
			break
	endswitch
end


function pausesweep(action) : Buttoncontrol
	string action
	nvar sc_pause, sc_abortsweep

	Button pausesweep,proc=resumesweep,title="Resume"
	sc_pause=1
	print "[SCAN] Scan paused by user."
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
		EndScan(save_experiment=0, aborting=1)  
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
		abort "Measurement aborted by user. Data not saved automatically. Run \"EndScan(abort=1)\" if needed"
	elseif(NVAR_Exists(sc_pause) && sc_pause==1)
		// Pause sweep if button is pressed
		do
			if(sc_abortsweep)
//				SaveWaves(msg="The scan was aborted during the execution.", save_experiment=0,fastdac=fastdac)
				EndScan(save_experiment=0, aborting=1) 
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


///////////////////////////////////////////////////////////////
///////////////// Sleeps/Delays ///////////////////////////////
///////////////////////////////////////////////////////////////
function sc_sleep(delay)
	// sleep for delay seconds
	// checks for abort window interrupts in mstimer loop (i.e. This works well within Slow Scancontroller measurements, otherwise this locks up IGOR)
	variable delay
	delay = delay*1e6 // convert to microseconds
	variable start_time = stopMStimer(-2) // start the timer immediately
	nvar sc_abortsweep, sc_pause

	doupdate // do this just once during the sleep function
	do
		try
			sc_checksweepstate()
		catch
			variable err = GetRTError(1)
			string errMessage = GetErrMessage(err)
		
			// reset sweep control parameters if igor about button is used
			if(v_abortcode == -1)
				sc_abortsweep = 0
				sc_pause = 0
			endif
			
			//silent abort
			abortonvalue 1,10
		endtry
	while(stopMStimer(-2)-start_time < delay)
end


function asleep(s)
  	// Sleep function which allows user to abort or continue if sleep is longer than 2s
	variable s
	variable t1, t2
	if (s > 2)
		t1 = datetime
		doupdate	
		sleep/S/C=6/B/Q s
		t2 = datetime-t1
		if ((s-t2)>5)
			printf "User continued, slept for %.0fs\r", t2
		endif
	else
		sc_sleep(s)
	endif
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


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////// ASYNC handling ///////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Note: Slow ScanContoller ONLY

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


////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////  Data/Experiment Saving   ////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

function EndScan([S, save_experiment, aborting, additional_wavenames])
	// Ends a scan:
	// Saves/Loads current/last ScanVars from global waves
	// Closes sweepcontrol if open
	// Save Metadata into HDF files
	// Saves Measured data into HDF files
	// Saves experiment

	Struct ScanVars &S  // Note: May not exist so can't be relied upon later
	variable save_experiment
	variable aborting
	string additional_wavenames // Any additional wavenames to be saved in the DatHDF (and copied in Igor)
	
	nvar filenum
	variable current_filenum = filenum  // Because filenum gets incremented in SaveToHDF (to avoid clashing filenums when Igor crashes during saving)
	save_experiment = paramisDefault(save_experiment) ? 1 : save_experiment
	if(!paramIsDefault(S))
		saveAsLastScanVarsStruct(S)  // I.e save the ScanVars including end_time and any other changed values in case saving fails (which it often does)
	endif
	
	Struct ScanVars S_ // Note: This will definitely exist for the rest of this function
	loadLastScanVarsStruct(S_)
	if (aborting)
		S_.end_time = datetime
		S_.comments = "aborted, " + S_.comments
	endif
	if (S_.end_time == 0) // Should have already been set, but if not, this is likely a good guess and prevents a stupid number being saved
		S_.end_time = datetime
		S_.comments = "end_time guessed, "+S_.comments
	endif

	dowindow/k SweepControl // kill scan control window
	printf "Time elapsed: %.2f s \r", (S_.end_time-S_.start_time)
	HDF5CloseFile/A 0 //Make sure any previously opened HDFs are closed (may be left open if Igor crashes)
	
	if(S_.using_fastdac == 0)
		KillDataFolder/z root:async // clean this up for next time
	endif
	SaveToHDF(S_, additional_wavenames=additional_wavenames)

	nvar sc_save_time
	if(save_experiment==1 & (datetime-sc_save_time)>180.0)
		// save if sc_save_exp=1
		// and if more than 3 minutes has elapsed since previous saveExp
		saveExp()
		sc_save_time = datetime
	endif

	if(sc_checkBackup())  	// check if a path is defined to backup data
		sc_copyNewFiles(current_filenum, save_experiment=save_experiment)		// copy data to server mount point (nvar filenum gets incremented after HDF is opened)
	endif

	// add info about scan to the scan history file in /config
	//	sc_saveFuncCall(getrtstackinfo(2))
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
	if (V_Flag !=0)
		abort "Failed to open save file. Probably need to run `filenum+=1` so that it isn't trying to create an existing file. And then run EndScan(...) again"
	endif	
	return hdf5_id
end


function initcloseSaveFiles(hdf5_id_list)  // TODO: rename
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


/////////////////////////////////////////////////////// Sweeplogs /////////////////////////////////////////////////////////////////////////////
function /s new_sc_createSweepLogs([S, comments])  // TODO: Rename
	// Creates a Json String which contains information about Scan
    // Note: Comments is ignored unless ScanVars are not provided
	Struct ScanVars &S
    string comments
	string jstr = ""
	nvar filenum
	svar sc_current_config

    if (!paramisDefault(S))
        comments = S.comments
    endif

	jstr = addJSONkeyval(jstr, "comment", comments, addQuotes=1)
	jstr = addJSONkeyval(jstr, "filenum", num2istr(filenum))
	jstr = addJSONkeyval(jstr, "current_config", sc_current_config, addQuotes = 1)
	jstr = addJSONkeyval(jstr, "time_completed", Secs2Date(DateTime, 1)+" "+Secs2Time(DateTime, 3), addQuotes = 1)
	
    if (!paramisDefault(S))
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
   	        jstr = addJSONkeyval(jstr, "sweeprate", num2numStr(S.sweeprate))  	        
   	        jstr = addJSONkeyval(jstr, "measureFreq", num2numStr(S.measureFreq))   	           	        
   	     endif
    endif

    sc_instrumentLogs(jstr)  // Modifies the jstr to add Instrumt Status (from ScanController Window)
	return jstr
end


function sc_instrumentLogs(jstr)
	// Runs all getinstrStatus() functions, and adds results to json string (to be stored in sweeplogs)
	// Note: all log strings must be valid JSON objects 
    string &jstr

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
end


function addMetaFiles(hdf5_id_list, [S, logs_only, comments])
	// Adds config json string and sweeplogs json string to HDFs as attrs of a group named "metadata"
	// Note: comments is only used when saving logs_only (otherwise comments are saved from ScanVars.comments)
	string hdf5_id_list, comments
	Struct ScanVars &S
	variable logs_only  // 1=Don't save any sweep information to HDF
	make/Free/T/N=1 cconfig = {""}
	cconfig = prettyJSONfmt(sc_createconfig())
	
	if (!logs_only)
		make /FREE /T /N=1 sweep_logs = prettyJSONfmt(new_sc_createSweepLogs(S=S))
	else
		make /FREE /T /N=1 sweep_logs = prettyJSONfmt(new_sc_createSweepLogs(comments = comments))
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


function initSaveSingleWave(wn, hdf5_id, [saveName])  // TODO: Rename
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
	calc_hdf5_id = initOpenSaveFiles(0)
	string hdfids = num2str(calc_hdf5_id)
	if (S.using_fastdac && sc_Saverawfadc == 1)
		raw_hdf5_id = initOpenSaveFiles(1)
		hdfids = addlistItem(num2str(raw_hdf5_id), hdfids, ";", INF)
	endif
	filenum += 1  // So next created file gets a new num (setting here so that when saving fails, it doesn't try to overwrite next save)
	
	// add Meta data to each file
	addMetaFiles(hdfids, S=S)
	
	if (S.using_fastdac)
		// Save some fastdac specific waves (sweepgates etc)
		saveFastdacInfoWaves(hdfids, S)
	endif

	// Save ScanWaves (e.g. x_array, y_array etc)
	if(S.using_fastdac)
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
		RawWaves = get1DWaveNames(1, S.using_fastdac)
		CalcWaves = get1DWaveNames(0, S.using_fastdac)
	elseif (S.is2d == 1)
		RawWaves = get2DWaveNames(1, S.using_fastdac)
		CalcWaves = get2DWaveNames(0, S.using_fastdac)
	else
		abort "Not implemented"
	endif
	if (S.using_fastdac)  // Figure out better names for the raw data for fastdac scans (before adding additional_wavenames)
		string rawSaveNames = getRawSaveNames(CalcWaves)  
	endif

	// Add additional_wavenames to CalcWaves
	if (!paramIsDefault(additional_wavenames) && strlen(additional_wavenames) > 0)
		assertSeparatorType(additional_wavenames, ";")
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
	else
		saveWavesToHDF(RawWaves, calc_hdf5_id)	// Save all regular ScanController waves in the main hdf file (they are small anyway)
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
	
	if (S.is2d && !S.bdID)  // Also Y info (if not using BabyDAC for y-axis)
		make/o/N=(3, itemsinlist(s.channelsy, ",")) sweepgates_y = 0
		for (i=0; i<itemsinlist(s.channelsy, ","); i++)
			sweepgates_y[0][i] = str2num(stringfromList(i, s.channelsy, ","))
			sweepgates_y[1][i] = str2num(stringfromlist(i, s.startys, ","))
			sweepgates_y[2][i] = str2num(stringfromlist(i, s.finys, ","))
		endfor
	else
		make/o sweepgates_y = {{NaN, NaN, NaN}}
	endif
	
	
	nvar sc_AWG_used
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
		
		if (sc_AWG_used == 1)
			// Add AWs used to HDF file
			struct fdAWG_list AWG
			fdAWG_get_global_AWG_list(AWG)
			variable j
			for(j=0;j<AWG.numWaves;j++)
				// Get IGOR AW
				wn = fdAWG_get_AWG_wave(str2num(stringfromlist(j, AWG.AW_waves, ",")))
				initsaveSingleWave(wn, hdfid)
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
	initcloseSaveFiles(num2str(hdfid))
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


function SaveNamedWaves(wave_names, comments)
	// Saves a comma separated list of wave_names to HDF under DatXXX.h5
	string wave_names, comments
	
	nvar filenum
	variable current_filenum = filenum
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
	filenum += 1  // So next created file gets a new num (setting here so that when saving fails, it doesn't try to overwrite next save)
	
	addMetaFiles(num2str(hdfid), logs_only=1, comments=comments)


//	initSaveFiles(msg=comments, logs_only=1)
	printf "Saving waves [%s] in dat%d.h5\r", wave_names, filenum-1

	// Now save each wave
	for(ii=0;ii<itemsinlist(wave_names, ",");ii++)
		wn = stringfromlist(ii, wave_names, ",")
		initSaveSingleWave(wn, hdfid)
	endfor
	initcloseSaveFiles(num2str(hdfid))
	
	if(sc_checkBackup())  	// check if a path is defined to backup data
		sc_copyNewFiles(current_filenum, save_experiment=0)		// copy data to server mount point (nvar filenum gets incremented after HDF is opened)
	endif	
	
end


function saveExp()
	SaveExperiment /P=data // save current experiment as .pxp
	SaveFromPXP(history=1, procedure=1) // grab some useful plain text docs from the pxp
end


function sc_saveFuncCall(funcname)
	// Can be used to save Function calls to a text file
	string funcname
	// TODO: Update this function to new style with ScanVars
	abort "Not implemented again yet: This should probably take ScanVars since all these globals are now stored in there... Also seems like this could be saved to HDF?"
	
	nvar sc_is2d, sc_startx, sc_starty, sc_finx, sc_starty, sc_finy, sc_numptsx, sc_numptsy
	nvar filenum
	svar sc_x_label, sc_y_label
	
	// create JSON string
	string buffer = ""
	
	buffer = addJSONkeyval(buffer,"Filenum",num2istr(filenum))
	buffer = addJSONkeyval(buffer,"Function Name",funcname,addquotes=1)
	if(sc_is2d == 0)
		buffer = addJSONkeyval(buffer,"Sweep parameter/label",sc_x_label,addquotes=1)
		buffer = addJSONkeyval(buffer,"Starting value",num2str(sc_startx))
		buffer = addJSONkeyval(buffer,"Ending value",num2str(sc_finx))
		buffer = addJSONkeyval(buffer,"Number of points",num2istr(sc_numptsx))
	else
		buffer = addJSONkeyval(buffer,"Sweep parameter/label (x)",sc_x_label,addquotes=1)
		buffer = addJSONkeyval(buffer,"Starting value (x)",num2str(sc_startx))
		buffer = addJSONkeyval(buffer,"Ending value (x)",num2str(sc_finx))
		buffer = addJSONkeyval(buffer,"Number of points (x)",num2istr(sc_numptsx))
		buffer = addJSONkeyval(buffer,"Sweep parameter/label (y)",sc_y_label,addquotes=1)
		buffer = addJSONkeyval(buffer,"Starting value (y)",num2str(sc_starty))
		buffer = addJSONkeyval(buffer,"Ending value (y)",num2str(sc_finy))
		buffer = addJSONkeyval(buffer,"Number of points (y)",num2istr(sc_numptsy))
	endif
	
	buffer = prettyJSONfmt(buffer)
	
	// open function call history file (or create it)
	variable hisfile
	open /z/a/p=config hisfile as "FunctionCallHistory.txt"
	
	if(v_flag != 0)
		print "[WARNING] \"saveFuncCall\": Could not open FunctionCallHistory.txt"
		return 0
	endif
	
	fprintf hisfile, buffer
	fprintf hisfile, "------------------------------------\r\r"
	
	close hisfile
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


////////////////////////////////////////////////////////////////
///////////////// Slow ScanController ONLY /////////////////////
////////////////////////////////////////////////////////////////
// Slow == Not FastDAC compatible

function InitScanController([configFile])
	// Open the Slow ScanController window (not FastDAC)
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
	// make some waves needed for the scancontroller window
	variable /g sc_instrLimit = 20 // change this if necessary, seeems fine
	make /o/N=(sc_instrLimit,3) instrBoxAttr = 2
	
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
			
			// Clean up volatile memory
			variable/g sc_cleanup = 0

			// instrument wave
			make /t/o/N=(sc_instrLimit,3) sc_Instr

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
	
	// close all VISA sessions and create wave to hold
	// all Resource Manager sessions, so that they can
	// be closed at each call InitializeWaves()
	killVISA()
	wave/z viRm
	if(waveexists(viRm))
		killwaves viRM
	endif
	make/n=0 viRM

	sc_rebuildwindow()
end


function sc_rebuildwindow()
	string cmd=""
	getwindow/z ScanController wsizeRM
	dowindow /k ScanController
	sprintf cmd, "ScanController(%f,%f,%f,%f)", v_left,v_right,v_top,v_bottom
	execute(cmd)
end


Window ScanController(v_left,v_right,v_top,v_bottom) : Panel
	variable v_left,v_right,v_top,v_bottom
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
	if(v_left+v_right+v_top+v_bottom > 0)
		MoveWindow/w=ScanController v_left,v_top,V_right,v_bottom
	endif
	ModifyPanel frameStyle=2
	ModifyPanel fixedSize=0
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
//	sc_controlwindows("") // Kill all open control windows
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
	nvar sc_PrintRaw, sc_PrintCalc, sc_resampleFreqCheckFadc
	nvar/z sc_Printfadc, sc_Saverawfadc // FastDAC specific
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
	elseif(stringmatch(ControlName,"sc_PrintfadcBox")) // FastDAC window
		sc_Printfadc = value
	elseif(stringmatch(ControlName,"sc_SavefadcBox")) // FastDAC window
		sc_Saverawfadc = value
	elseif(stringmatch(ControlName,"sc_FilterfadcCheckBox")) // FastDAC window
		sc_resampleFreqCheckFadc = value

	endif
end


function/s sc_createConfig()
	wave/t sc_RawWaveNames, sc_RawScripts, sc_CalcWaveNames, sc_CalcScripts, sc_Instr
	wave sc_RawRecord, sc_RawPlot, sc_measAsync, sc_CalcRecord, sc_CalcPlot
	nvar sc_PrintRaw, sc_PrintCalc, filenum, sc_cleanup
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

	// FastDac if it exists
	WAVE/Z fadcvalstr
	if( WaveExists(fadcvalstr) )
		variable i = 0
		wave fadcattr
		make/o/free/n=(dimsize(fadcattr, 0)) tempwave
		
		string fdinfo = ""
		duplicate/o/free/r=[][0] fadcvalstr tempstrwave
		fdinfo = addJSONkeyval(fdinfo, "ADCnums", textwave2strarray(tempstrwave))

		duplicate/o/free/r=[][1] fadcvalstr tempstrwave
		fdinfo = addJSONkeyval(fdinfo, "ADCvals", textwave2strarray(tempstrwave))
		
		tempwave = fadcattr[p][2]
		for (i=0;i<numpnts(tempwave);i++)
			tempwave[i] =	tempwave[i] == 48 ? 1 : 0
		endfor

		fdinfo = addJSONkeyval(fdinfo, "record", wave2boolarray(tempwave))
		
		duplicate/o/free/r=[][3] fadcvalstr tempstrwave
		fdinfo = addJSONkeyval(fdinfo, "calc_name", textwave2strarray(tempstrwave))
		
		duplicate/o/free/r=[][4] fadcvalstr tempstrwave
		fdinfo = addJSONkeyval(fdinfo, "calc_script", textwave2strarray(tempstrwave))


		configstr = addJSONkeyval(configstr, "FastDAC", fdinfo)
	endif

	configstr = addJSONkeyval(configstr, "filenum", num2istr(filenum))
	
	configstr = addJSONkeyval(configstr, "cleanup", num2istr(sc_cleanup))

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
	loadNum2var(getJSONvalue(jstr,"filenum"),"filenum")
	
	//cleanup
	loadNum2var(getJSONvalue(jstr,"cleanup"),"sc_cleanup")

	// reload ScanController window
	sc_rebuildwindow()
end


////////////////////////////////////////////
/// Slow ScanController Recording Data /////
////////////////////////////////////////////

function New_RecordValues(S, i, j, [fillnan])  // TODO: Rename
	// In a 1d scan, i is the index of the loop. j will be ignored.
	// In a 2d scan, i is the index of the outer (slow) loop, and j is the index of the inner (fast) loop.
	// fillnan=1 skips any read or calculation functions entirely and fills point [i,j] with nan  (i.e. if intending to record only a subset of a larger array this effectively skips the places that should not be read)
	Struct ScanVars &S
	variable i, j, fillnan
	variable ii = 0
	
	fillnan = paramisdefault(fillnan) ? 0 : fillnan

	// Set Scan start_time on first measurement if not already set
	if (i == 0 && j == 0 && S.start_time == 0)
		S.start_time = datetime
	endif

	// Figure out which way to index waves
	variable innerindex, outerindex
	if (s.is2d == 1) //1 is normal 2D
		// 2d
		innerindex = j
		outerindex = i
	else
		// 1d
		innerindex = i
	endif
	
	// readvstime works only in 1d and rescales (grows) the wave at each index
	if(S.readVsTime == 1 && S.is2d)
		abort "ERROR[New_RecordValues]: Not valid to readvstime in 2D"
	endif

	//// Setup and run async data collection ////
	wave sc_measAsync
	if( (sum(sc_measAsync) > 1) && (fillnan==0))
		variable tgID = sc_ManageThreads(innerindex, outerindex, S.readvstime) // start threads, wait, collect data
		sc_KillThreads(tgID) // Terminate threads
	endif

	//// Run sync data collection (or fill with NaNs) ////
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	wave/t sc_RawWaveNames, sc_RawScripts, sc_CalcWaveNames, sc_CalcScripts
	variable /g sc_tmpVal  // Used when evaluating measurement scripts from ScanController window
	string script = "", cmd = ""
	ii=0
	do
		if ((sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1) && sc_measAsync[ii]==0)
			wave wref1d = $sc_RawWaveNames[ii]

			// Redimension waves if readvstime is set to 1
			if (S.readVsTime == 1)
				redimension /n=(innerindex+1) wref1d
				wref1d[innerindex] = NaN  // Prevents graph updating with a zero
				setscale/I x 0,  datetime - S.start_time, wref1d
			endif

			if(!fillnan)
				script = TrimString(sc_RawScripts[ii])
				sprintf cmd, "%s = %s", "sc_tmpVal", script
				Execute/Q/Z cmd
				if(V_flag!=0)
					print "[ERROR] \"RecordValues\": Using "+script+" raises an error: "+GetErrMessage(V_Flag,2)
				endif
			else
				sc_tmpval = NaN
			endif
			wref1d[innerindex] = sc_tmpval

			if (S.is2d == 1)
				// 2D Wave
				wave wref2d = $sc_RawWaveNames[ii] + "2d"
				wref2d[innerindex][outerindex] = wref1d[innerindex]
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
			if (S.readvstime == 1)
				redimension /n=(innerindex+1) wref1d
				setscale/I x 0, datetime - S.start_time, wref1d
			endif

			if(!fillnan)
				script = TrimString(sc_CalcScripts[ii])
				// Allow the use of the keyword '[i]' in calculated fields where i is the inner loop's current index
				script = ReplaceString("[i]", script, "["+num2istr(innerindex)+"]")
				sprintf cmd, "%s = %s", "sc_tmpVal", script
				Execute/Q/Z cmd
				if(V_flag!=0)
					print "[ERROR] in RecordValues (calc): "+GetErrMessage(V_Flag,2)
				endif
			else
				sc_tmpval = NaN
			endif
			wref1d[innerindex] = sc_tmpval

			if (S.is2d == 1)
				wave wref2d = $sc_CalcWaveNames[ii] + "2d"
				wref2d[innerindex][outerindex] = wref1d[innerindex]
			endif
		endif
		ii+=1
	while (ii < numpnts(sc_CalcWaveNames))

	S.end_time = datetime // Updates each loop

	// check abort/pause status
	nvar sc_abortsweep, sc_pause, sc_scanstarttime
	try
		sc_checksweepstate()
	catch
		variable err = GetRTError(1)
		// reset sweep control parameters if igor abort button is used
		if(v_abortcode == -1)
			sc_abortsweep = 0
			sc_pause = 0
		endif
		
		//silent abort (with code 10 which can be checked if caught elsewhere)
		abortonvalue 1,10 
	endtry
end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Pre Scan Checks ///////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

function SFfd_pre_checks(S, [x_only, y_only])
   struct ScanVars &S
   variable x_only, y_only  // Whether to only check specific axis (e.g. if other axis is a babydac or something else)
   
	SFfd_check_same_device(S) 	// Checks DACs and ADCs are on same device
	SFfd_check_ramprates(S)	 	// Check ramprates of x and y
	SFfd_check_lims(S)			// Check within software lims for x and y
	S.lims_checked = 1  		// So record_values knows that limits have been checked!
end


function SFfd_ramp_start(S, [ignore_lims, x_only, y_only])
	// move DAC channels to starting point
	struct ScanVars &S
	variable ignore_lims, x_only, y_only

	variable i, setpoint
	// If x exists ramp them to start
	if(numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0 && y_only != 1)  // If not NaN and not ""
		for(i=0;i<itemsinlist(S.channelsx,";");i+=1)
			if(S.direction == 1)
				setpoint = str2num(stringfromlist(i,S.startxs,","))
			elseif(S.direction == -1)
				setpoint = str2num(stringfromlist(i,S.finxs,","))
			else
				abort "ERROR[SFfd_ramp_start]: S.direction not set to 1 or -1"
			endif
			rampOutputfdac(S.instrID,str2num(stringfromlist(i,S.channelsx,";")),setpoint,ramprate=S.rampratex, ignore_lims=ignore_lims)			
		endfor
	endif  
	
	// If y exists ramp them to start
	if(numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0 && x_only != 1)  // If not NaN and not "" and not x only
		for(i=0;i<itemsinlist(S.channelsy,";");i+=1)
			rampOutputfdac(S.instrID,str2num(stringfromlist(i,S.channelsy,";")),str2num(stringfromlist(i,S.startys,",")),ramprate=S.rampratey, ignore_lims=ignore_lims)
		endfor
	endif
  
end


function SFfd_set_measureFreq(S)
   struct ScanVars &S
   S.samplingFreq = getfadcSpeed(S.instrID)
   S.numADCs = getNumFADC()
   S.measureFreq = S.samplingFreq/S.numADCs  //Because sampling is split between number of ADCs being read //TODO: This needs to be adapted for multiple FastDacs
end

function SFfd_check_ramprates(S)
  // check if effective ramprate is higher than software limits
  struct ScanVars &S

  wave/T fdacvalstr
  svar activegraphs


	variable kill_graphs = 0
	// Check x's won't be swept to fast by calculated sweeprate for each channel in x ramp
	// Should work for different start/fin values for x
	variable eff_ramprate, answer, i, k, channel
	string question

	if(!numtype(strlen(s.channelsx)) == 0 == 0 && strlen(s.channelsx) != 0)  // if s.Channelsx != (null or "")
		for(i=0;i<itemsinlist(S.channelsx,";");i+=1)
			eff_ramprate = abs(str2num(stringfromlist(i,S.startxs,","))-str2num(stringfromlist(i,S.finxs,",")))*(S.measureFreq/S.numptsx)
			channel = str2num(stringfromlist(i, S.channelsx, ";"))
			if(eff_ramprate > str2num(fdacvalstr[channel][4])*1.05 || s.rampratex > str2num(fdacvalstr[channel][4])*1.05)  // Allow 5% too high for convenience
				// we are going too fast
				sprintf question, "DAC channel %d will be ramped at Sweeprate: %.1f mV/s and Ramprate: %.1f mV/s, software limit is set to %s mV/s. Continue?", channel, eff_ramprate, s.rampratex, fdacvalstr[channel][4]
				answer = ask_user(question, type=1)
				if(answer == 2)
					kill_graphs = 1
					break
				endif
			endif
		endfor
	endif
  
	// if Y channels exist, then check against rampratey (not sweeprate because only change on slow axis)	
	if(numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0  && kill_graphs == 0)  // if s.Channelsy != (NaN or "") and not killing graphs yet 
		for(i=0;i<itemsinlist(S.channelsy,";");i+=1)
			channel = str2num(stringfromlist(i, S.channelsy, ";"))
			if(s.rampratey > str2num(fdacvalstr[channel][4]))
				sprintf question, "DAC channel %d will be ramped at %.1f mV/s, software limit is set to %s mV/s. Continue?", channel, S.rampratey, fdacvalstr[channel][4]
				answer = ask_user(question, type=1)
				if(answer == 2)
					kill_graphs = 1
					break
				endif
			endif
		endfor
	endif

	if(kill_graphs == 1)  // If user selected do not continue, then kill graphs and abort
		print("[ERROR] \"RecordValues\": User abort!")
		dowindow/k SweepControl // kill scan control window
		for(k=0;k<itemsinlist(activegraphs,";");k+=1)
			dowindow/k $stringfromlist(k,activegraphs,";")
		endfor
		abort
	endif
  
end



function SFfd_check_lims(S)
	// check that start and end values are within software limits
	struct ScanVars &S

	wave/T fdacvalstr
	variable answer, i, k
	
	// Make single list out of X's and Y's (checking if each exists first)
	string channels = "", starts = "", fins = ""
	if(numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0)  // If not NaN and not ""
		channels = addlistitem(S.channelsx, channels, ",")
		starts = addlistitem(S.startxs, starts, ",")
		fins = addlistitem(S.finxs, fins, ",")
	endif
	if(numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0)  // If not NaN and not ""
		channels = addlistitem(S.channelsy, channels, ",")
		starts = addlistitem(S.startys, starts, ",")
		fins = addlistitem(S.finys, fins, ",")
	endif

	// Check channels were concatenated correctly (Seems unnecessary, but possibly killed my device because of this...)
	if(stringmatch(channels, "*,,*") == 1)
		abort "ERROR[SFfd_check_lims]: Channels list contains ',,' which means something has gone wrong and limit checking WONT WORK!!"
	endif

	// Check that start/fin for each channel will stay within software limits
	string softLimitPositive = "", softLimitNegative = "", expr = "(-?[[:digit:]]+)\\s*,\\s*([[:digit:]]+)", question
	variable startval = 0, finval = 0
	string buffer
	for(i=0;i<itemsinlist(channels,",");i+=1)
		splitstring/e=(expr) fdacvalstr[str2num(stringfromlist(i,channels,","))][2], softLimitNegative, softLimitPositive
 		if(!numtype(str2num(softLimitNegative)) == 0 || !numtype(str2num(softLimitPositive)) == 0)
 			sprintf buffer, "No Lower or Upper Limit found for Channel %s. Low limit = %s. High limit = %s, Limit string = %s\r", stringfromlist(i,channels,","), softLimitNegative, softLimitPositive, fdacvalstr[str2num(stringfromlist(i,channels,","))][2]
 			abort buffer
 		endif
 		
		startval = str2num(stringfromlist(i,starts,","))
		finval = str2num(stringfromlist(i,fins,","))
		if(startval < str2num(softLimitNegative) || startval > str2num(softLimitPositive) || finval < str2num(softLimitNegative) || finval > str2num(softLimitPositive))
			// we are outside limits
			sprintf question, "DAC channel %s will be ramped outside software limits. Continue?", stringfromlist(i,channels,",")
			answer = ask_user(question, type=1)
			if(answer == 2)
				print("[ERROR] \"RecordValues\": User abort!")
				dowindow/k SweepControl // kill scan control window
				abort
			endif
		endif
	endfor		
end


function SFfd_check_same_device(S, [x_only, y_only])
	// Checks all rampChs and ADCs (selected in fd_scancontroller window)
	// are on the same device. 
	struct ScanVars &s
	variable x_only, y_only // whether to check only one axis (e.g. other is babydac)
	
	variable device_dacs
	variable device_buffer
	string channels
	if (!y_only)
		channels = getDeviceChannels(S.channelsx, device_dacs)  // Throws error if not all channels on one FastDAC
	endif
	if (!x_only)
		channels = getDeviceChannels(S.channelsy, device_buffer)
		if (device_dacs > 0 && device_buffer > 0 && device_buffer != device_dacs)
			abort "ERROR[SFfd_check_same_device]: X channels and Y channels are not on same device"  // TODO: Maybe this should raise an error?
		elseif (device_dacs <= 0 && device_buffer > 0)
			device_dacs = device_buffer
		endif
	endif

	channels = getDeviceChannels(s.AdcList, device_buffer, adc=1)  // Raises error if ADCs aren't on same device
	if (device_dacs > 0 && device_buffer != device_dacs)
		abort "ERROR[SFfd_check_same_device]: ADCs are not on the same device as DACs"  // TODO: Maybe should only raise error if x channels not on same device as ADCs?
	endif	
	return device_buffer // Return adc device number
end


function SFfd_format_setpoints(start, fin, channels, starts, fins)
	// Returns strings in starts and fins in the format that fdacRecordValues takes
	// e.g. fd_format_setpoints(-10, 10, "1,2,3", s, f) will make string s = "-10,-10,-10" and string f = "10,10,10"
	variable start, fin
	string channels, &starts, &fins
	
	variable i
	starts = ""
	fins = ""
	for(i=0; i<itemsInList(channels, ","); i++)
		starts = addlistitem(num2str(start), starts, ",", INF)
		fins = addlistitem(num2str(fin), fins, ",", INF)
	endfor
	starts = starts[0,strlen(starts)-2] // Remove comma at end
	fins = fins[0,strlen(fins)-2]	 		// Remove comma at end
end


function SFbd_pre_checks(S)
  struct ScanVars &S
//	SFbd_check_ramprates(S)	 	// Check ramprates of x and y
	SFbd_check_lims(S)			// Check within software lims for x and y
	S.lims_checked = 1  		// So record_values knows that limits have been checked!
end


function SFfd_sanitize_setpoints(start_list, fin_list, channels, starts, fins)
	// Makes sure starts/fins make sense for number of channels and have no bad formatting
	// Modifies the starts/fins strings passed in
	string start_list, fin_list, channels
	string &starts, &fins
	
	string buffer
	
	assertSeparatorType(channels, ";")  // ";" because already a processed value (e.g. labels -> numbers already happened)
	assertSeparatorType(start_list, ",")  // "," because entered by user
	assertSeparatorType(fin_list, ",")	// "," because entered by user
	
	if (itemsinlist(channels, ";") != itemsinlist(start_list, ",") || itemsinlist(channels, ";") != itemsinlist(fin_list, ","))
		sprintf buffer, "length of start_list/fin_list/channels not equal!!! start_list:(%s), fin_list:(%s), channels:(%s)\r", start_list, fin_list, channels
		abort buffer
	endif
	
	starts = replaceString(" ", start_list, "")
	fins = replaceString(" ", fin_list, "")
end


function SFbd_check_lims(S, [x_only, y_only])
	// check that start and end values are within software limits
   struct ScanVars &S
   variable x_only, y_only  // Whether to only check one axis (e.g. other is a fastdac)
	
	// Make single list out of X's and Y's (checking if each exists first)
	string all_channels = "", outputs = ""
	if(!y_only && numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0)  // If not NaN and not ""
		all_channels = addlistitem(S.channelsx, all_channels, "|")
		outputs = addlistitem(num2str(S.startx), outputs, ",")
		outputs = addlistitem(num2str(S.finx), outputs, ",")
	endif

	if(!x_only && numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0)  // If not NaN and not ""
		all_channels = addlistitem(S.channelsy, all_channels, "|")
		outputs = addlistitem(num2str(S.starty), outputs, ",")
		outputs = addlistitem(num2str(S.finy), outputs, ",")
	endif
	

	wave/T dacvalstr
	wave bd_range_span, bd_range_high, bd_range_low

	variable board_index, sw_limit
	variable answer, i, j, k, channel, output, kill_graphs = 0
	string channels, abort_msg = "", question
	for(i=0;i<itemsinlist(all_channels, "|");i++)  		// channelsx then channelsy if it exists
		channels = stringfromlist(i, all_channels, "|")
		for(j=0;j<itemsinlist(channels, ";");j++)			// each channel from channelsx/channelsy
			channel = str2num(stringfromlist(j, channels, ";"))
			for(k=0;k<2;k++)  									// Start/Fin for each channel
				output = str2num(stringfromlist(2*i+k, outputs, ","))  // 2 per channelsx/channelsy
				// Check that the DAC board is initialized
				bdGetBoard(channel)
				board_index = floor(channel/4)
			
				// check for NAN and INF
				if(numtype(output) != 0)
					abort "trying to set voltage to NaN or Inf"
				endif
			
				// Check that the voltage is valid
				if(output > bd_range_high[board_index] || output < bd_range_low[board_index])
					sprintf abort_msg, "voltage out of DAC range, %.3fmV", output
					kill_graphs = 1
					break
				endif
			
				// check that the voltage is within software limits
				// if outside, ask user if want to continue anyway
				sw_limit = str2num(dacvalstr[channel][2])
				if(abs(output) > sw_limit)
					sprintf question, "DAC channel %s will be ramped outside software limits. Continue?", stringfromlist(i,channels,";")
					answer = ask_user(question, type=1)
					if(answer == 2)
						sprintf abort_msg "User aborted"
						kill_graphs = 1
						break
					endif
				endif
				if(kill_graphs == 1)  // Don't bother checking the rest
					break
				endif
			endfor
			if(kill_graphs == 1)  // Don't bother checking the rest
				break
			endif
		endfor
		if(kill_graphs == 1)  // Don't bother checking the rest
			break
		endif
	endfor

	if(kill_graphs == 1)
		dowindow/k SweepControl // kill scan control window
		svar activegraphs  // TODO: I don't think this is updated any more, maybe graphs can't be easily killed?
		for(k=0;k<itemsinlist(activegraphs,";");k+=1)
			dowindow/k $stringfromlist(k,activegraphs,";")
		endfor		
		abort abort_msg
	endif
end


function SFbd_ramp_start(S, [x_only, y_only, ignore_lims])
	// move DAC channels to starting point
	// x_only/y_only to only try ramping x/y to start (e.g. y_only=1 when using a babydac for y-axis of a fastdac scan)
	struct ScanVars &S
	variable x_only, y_only, ignore_lims

	variable instrID = (S.bdID) ? S.bdID : S.instrID  // Use S.bdID if it is present  
	// If x exists ramp them to start
	if(!y_only && numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0)  // If not NaN and not ""
		RampMultipleBD(instrID, S.channelsx, S.startx, ramprate=S.rampratex, ignore_lims=ignore_lims)
	endif  
	
	// If y exists ramp them to start
	if(!x_only && numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0)  // If not NaN and not ""
		RampMultipleBD(instrID, S.channelsy, S.starty, ramprate=S.rampratey, ignore_lims=ignore_lims)
	endif
end


function SFawg_check_AWG_list(AWG, Fsv)
	// Check that AWG and FastDAC ScanValues don't have any clashing DACs and check AWG within limits etc
	struct fdAWG_List &AWG
	struct ScanVars &Fsv
	
	string AWdacs  // Used for storing all DACS for 1 channel  e.g. "123" = Dacs 1,2,3
	string err_msg
	variable i=0, j=0
	
	// Assert separators are correct
	assertSeparatorType(AWG.AW_DACs, ",")
	assertSeparatorType(AWG.AW_waves, ",")
		
	// Check initialized
	if(AWG.initialized == 0)
		abort "ERROR[SFawg_check_AWG_list]: AWG_List needs to be initialized. Maybe something changed since last use!"
	endif
	
	// Check numADCs hasn't changed since setting up waves
	if(AWG.numADCs != getNumFADC())
		abort "ERROR[SFawg_check_AWG_list]: Number of ADCs being measured has changed since setting up AWG, this will change AWG frequency. Set up AWG again to continue"
	endif
	
	// Check measureFreq hasn't change since setting up waves
	if(AWG.measureFreq != Fsv.measureFreq  || AWG.samplingFreq != Fsv.samplingFreq)
		sprintf err_msg, "ERROR[SFawg_check_AWG_list]: MeasureFreq has changed from %.2f/s to %.2f/s since setting up AWG. Set up AWG again to continue", AWG.measureFreq, Fsv.measureFreq
		abort err_msg
	endif
	
	// Check numSteps is an integer and not zero
	if(AWG.numSteps != trunc(AWG.numSteps) || AWG.numSteps == 0)
		abort "ERROR[SFawg_check_AWG_list]: numSteps must be an integer, not " + num2str(AWG.numSteps)
	endif
			
	// Check there are DACs set for each AW_wave (i.e. if using 2 AWs, need at least 1 DAC for each)
	if(itemsInList(AWG.AW_waves, ",") != (itemsinlist(AWG.AW_Dacs,",")))
		sprintf err_msg "ERROR[SFawg_check_AWG_list]: Number of AWs doesn't match sets of AW_Dacs. AW_Waves: %s; AW_Dacs: %s", AWG.AW_waves, AWG.AW_Dacs
		abort err_msg
	endif	
	
	// Check no overlap between DACs for sweeping, and DACs for AWG
	string channel // Single DAC channel
	string FDchannels = addlistitem(Fsv.Channelsy, Fsv.Channelsx, ";") // combine channels lists
	for(i=0;i<itemsinlist(AWG.AW_Dacs, ",");i++)
		AWdacs = stringfromlist(i, AWG.AW_Dacs, ",")
		for(j=0;j<strlen(AWdacs);j++)
			channel = AWdacs[j]
			if(findlistitem(channel, FDchannels, ";") != -1)
				abort "ERROR[SFawg_check_AWG_list]: Trying to use same DAC channel for FD scan and AWG at the same time"
			endif
		endfor
	endfor

	// Check that all setpoints for each AW_Dac will stay within software limits
	wave/T fdacvalstr	
	string softLimitPositive = "", softLimitNegative = "", expr = "(-?[[:digit:]]+),([[:digit:]]+)", question
	variable setpoint, answer, ch_num
	for(i=0;i<itemsinlist(AWG.AW_Dacs,",");i+=1)
		AWdacs = stringfromlist(i, AWG.AW_Dacs, ",")
		string wn = fdAWG_get_AWG_wave(str2num(stringfromlist(i, AWG.AW_Waves, ",")))  // Get IGOR wave of AW#
		wave w = $wn
		duplicate/o/r=[0][] w setpoints  							// Just get setpoints part
		for(j=0;j<strlen(AWdacs);j++)  // Check for each DAC that will be outputting this wave
			ch_num = str2num(AWdacs[j])
			splitstring/e=(expr) fdacvalstr[ch_num][2], softLimitNegative, softLimitPositive
			for(j=0;j<numpnts(setpoints);j++)	// Check against each setpoint in AW
				if(setpoint < str2num(softLimitNegative) || setpoint > str2num(softLimitPositive))
					// we are outside limits
					sprintf question, "DAC channel %s will be ramped outside software limits. Continue?", AWdacs[j]
					answer = ask_user(question, type=1)
					if(answer == 2)
						print("ERROR[SFawg_check_AWG_list]: User abort!")
						abort
					endif
				endif
			endfor
		endfor
	endfor		
end


function SFawg_set_and_precheck(AWG, S)
	struct fdAWG_List &AWG
	struct ScanVars &S

	
	// Set numptsx in Scan s.t. it is a whole number of full cycles
	AWG.numSteps = round(S.numptsx/(AWG.waveLen*AWG.numCycles))  
	S.numptsx = (AWG.numSteps*AWG.waveLen*AWG.numCycles)
	
	// Check AWG for clashes/exceeding lims etc
	SFawg_check_AWG_list(AWG, S)	
	AWG.use_AWG = 1
	
	// Save numSteps in AWG_list for sweeplogs later
	fdAWG_set_global_AWG_list(AWG)
end
	