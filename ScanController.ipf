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


// Structure to hold scan information (general to all scans)  (prefix "sv_" for private functions which are specifically for this)
structure ScanVars
    variable instrID
    
    variable lims_checked // Flag that gets set to 1 after checks on software limits/ramprates etc has been carried out

    string channelsx
    variable startx, finx, numptsx, rampratex
    variable delayx

    // For 2D scans
    variable is2d
    string channelsy 
    variable starty, finy, numptsy, rampratey 
    variable delayy

    // For scanRepeat
    variable direction

    // Other useful info
    variable start_time // Should be recorded right before measurements begin (e.g. after all checks are carried out)
    variable end_time // Should be recorded right after measurements end (e.g. before getting sweeplogs etc)
    string x_label
    string y_label
    variable using_fastdac // Set to 1 when using fastdac
    string comments

    // ScanControllerInfo 
    // string activeGraphs


    // Specific to Fastdac 
    variable numADCs
    variable samplingFreq, measureFreq
    variable sweeprate
    string adcList
    string startxs, finxs
    string startys, finys
endstructure


function initFDscanVars(S, instrID, startx, finx, channelsx, [numptsx, sweeprate, rampratex, delayx, starty, finy, channelsy, numptsy, rampratey, delayy, direction, startxs, finxs, startys, finys, x_label, y_label, comments])
    // Function to make setting up scanVars struct easier for FastDAC scans
    // PARAMETERS:
    // startx, finx, starty, finy -- Single start/fin point for all channelsx/channelsy
    // startxs, finxs, startys, finys -- For passing in multiple start/fin points for each channel as a comma separated string instead of a single start/fin for all channels
    //		Note: Just pass anything for startx/finx if using startxs/finxs, they will be overwritten
    struct ScanVars &S
    variable instrID
    variable startx, finx, numptsx, delayx, rampratex
    variable starty, finy, numptsy, delayy, rampratey
    string channelsx, channelsy
    string startxs, finxs, startys, finys
    string  x_label, y_label
    string comments
    variable direction, sweeprate
	
	channelsy = selectString(paramIsDefault(channelsy), channelsy, "")
	startys = selectString(paramIsDefault(startys), startys, "")
	finys = selectString(paramIsDefault(finys), finys, "")
	y_label = selectString((paramIsDefault(y_label) || numtype(strlen(y_label)) == 2), y_label, "")	

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
    S.comments = comments

	// For repeat scans 
    S.direction = paramisdefault(direction) ? 1 : direction
   	
   	// Sets channelsx, channelsy and is2d
    sv_setChannels(S, channelsx, channelsy, fastdac=1)
    
   	// Get Labels for graphs
   	S.x_label = selectString(strlen(x_label) > 0, GetLabel(S.channelsx, fastdac=1), x_label)  // Uses channels as list of numbers, and only if x_label not passed in
   	S.y_label = selectString(strlen(y_label) > 0, GetLabel(S.channelsy, fastdac=1), y_label)   		

   	// Sets starts/fins in FD string format
    sv_setFDsetpoints(S, channelsx, startx, finx, channelsy, starty, finy, startxs, finxs, startys, finys)
	
	// Set variables with some calculation
    sv_setNumptsSweeprate(S) 	// Checks that either numpts OR sweeprate was provided, and sets both in ScanVars accordingly
                                    // Note: Valid for same start/fin points only (uses S.startx, S.finx NOT S.startxs, S.finxs)
    sv_setMeasureFreq(S) 		// Sets S.samplingFreq/measureFreq/numADCs	
end

function sv_setNumptsSweeprate(S)
	Struct ScanVars &S
	 // If NaN then set to zero so rest of logic works
   if(numtype(S.sweeprate) == 2)
   		S.sweeprate = 0
   	endif
   
   // Chose which input to use for numpts of scan
   if (S.numptsx == 0 && S.sweeprate == 0)
      abort "ERROR[ScanFastDac]: User must provide either numpts OR sweeprate for scan [neither provided]"
   elseif (S.numptsx!=0 && S.sweeprate!=0)
      abort "ERROR[ScanFastDac]: User must provide either numpts OR sweeprate for scan [both provided]"
   elseif (S.numptsx!=0) // If numpts provided, just use that
      S.sweeprate = fd_get_sweeprate_from_numpts(S.instrID, S.startx, S.finx, S.numptsx)
   elseif (S.sweeprate!=0) // If sweeprate provided calculate numpts required
      S.numptsx = fd_get_numpts_from_sweeprate(S.instrID, S.startx, S.finx, S.sweeprate)
   endif
end

function sv_setMeasureFreq(S)
	Struct ScanVars &S
   S.samplingFreq = getfadcSpeed(S.instrID)
   S.numADCs = getNumFADC()
   S.measureFreq = S.samplingFreq/S.numADCs  //Because sampling is split between number of ADCs being read //TODO: This needs to be adapted for multiple FastDacs
end


function initBDscanVars(S, instrID, startx, finx, channelsx, [numptsx, sweeprate, delayx, rampratex, starty, finy, channelsy, numptsy, rampratey, delayy, direction, x_label, y_label])
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

	x_label = selectString((paramIsDefault(x_label) || numtype(strlen(x_label)) == 2), x_label, "")
	y_label = selectString((paramIsDefault(y_label) || numtype(strlen(y_label)) == 2), y_label, "")
	channelsy = selectString(paramisdefault(channelsy), channelsy, "")

    // Handle Optional Parameters
    s.numptsx = paramisdefault(numptsx) ? NaN : numptsx
    s.rampratex = paramisDefault(rampratex) ? NaN : rampratex
    s.delayx = paramisDefault(delayx) ? NaN : delayx

    s.sweeprate = paramisdefault(sweeprate) ? NaN : sweeprate  // TODO: Should this be different?

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
  	// Get Labels for graphs
   	S.x_label = selectString(strlen(x_label) > 0, GetLabel(S.channelsx, fastdac=0), x_label)  // Uses channels as list of numbers, and only if x_label not passed in
   	S.y_label = selectString(strlen(y_label) > 0, GetLabel(S.channelsy, fastdac=0), y_label) 
   	
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














/////////////////////////////////////////////////////////// This chunk should probably go somewhere else


function initializeScan(S)
    // Opens instrument connection, initializes waves to store data, opens and tiles graphs, opens abort window.
    struct ScanVars &S
    variable fastdac

    // Kill and reopen connections (solves some common issues)
    killVISA()
    sc_OpenInstrConnections(0)

    // Make sure waves exist to store data
    new_initializeWaves(S)
    // TODO: Might need to get the S.adcList differently because sc_fastadc is no longer created in initWaves

    // Set up graphs to display recorded data
    string activeGraphs
    activeGraphs = initializeGraphs(S)
    arrangeWindows(activeGraphs)

    // Open Abort window
    openAbortWindow()

    // Save struct to globals
    S.start_time = datetime
    saveAsLastScanVarsStruct(S)
end


function new_initializeWaves(S)
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
    make/O/n=(numpts) $wn = NaN  // TODO: can put in a cmd and execute if necessary
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
////////////// Previously there was a check to prevent last character of wave name being a number
////////////// This is not necessary for the fastdac, but maybe it needs to be reimplemented for ScanController??
////////////// 2021/10  <-- If a significant amount of time has passed, remove all of this!
//        if (!((char2num(s[strlen(s)-1]) >= 97 && char2num(s[strlen(s)-1]) <= 122) || (char2num(s[strlen(s)-1]) >= 65 && char2num(s[strlen(s)-1]) <= 90)))
//            print "The last character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
//            abort
//        endif
    endfor
end

//////////////////////////////////////////////////////////////////////////////////////////////// End of chunk which should probably be moved

















// function sc_controlwindows(action)
// 	string action
// 	string openaboutwindows
// 	variable ii

// 	openaboutwindows = winlist("SweepControl*",";","WIN:64")
// 	if(itemsinlist(openaboutwindows)>0)
// 		for(ii=0;ii<itemsinlist(openaboutwindows);ii+=1)
// 			killwindow $stringfromlist(ii,openaboutwindows)
// 		endfor
// 	endif
// end


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
		print "[WARNING] Only saving local copies of data. See sc_checkBackup()."
		return 0
	else
		// this should also create the path if it does not exist
		string sp = S_path
		newpath /C/O/Q backup_data sp+sc_hostname+":"+getExpPath("data", full=1)
		newpath /C/O/Q backup_config sp+sc_hostname+":"+getExpPath("config", full=1)
		
		return 1
	endif
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
    for (i = 0; i<2; i++)  // Raw = 1, Calc = 0
        waveNames = get1DWaveNames(i, S.using_fastdac)
        buffer = initializeGraphsForWavenames(waveNames, S.x_label, is2d=S.is2d, y_label=S.y_label)
        if(i==1) // Raw waves
	        sc_rawGraphs1D = buffer
        endif
        graphIDs = graphIDs + buffer
    endfor
    return graphIDs
end


function/S initializeGraphsForWavenames(wavenames, x_label, [is2d, y_label, spectrum])
	// Ensures a graph is open and tiles graphs for each wave in comma separated wavenames
	// Returns list of graphIDs of active graphs
	// Spectrum = 1 to use SAnum instead of filenum in plot
	string wavenames, x_label, y_label
	variable is2d, spectrum
	
	y_label = selectString(paramisDefault(y_label), y_label, "")

	string wn, openGraphID, graphIDs = ""
	variable i
	for (i = 0; i<ItemsInList(waveNames); i++)  // Look through wavenames that are being recorded
	    wn = StringFromList(i, waveNames)
	    openGraphID = graphExistsForWavename(wn)
	    if (cmpstr(openGraphID, "")) // Graph is already open (str != "")
	        setUpGraph1D(openGraphID, x_label, spectrum=spectrum, y_label=y_label)  // TODO: Add S.y_label if it is not null or empty
	    else 
	        open1Dgraph(wn, x_label, y_label=y_label, spectrum=spectrum, y_label=y_label)
	        openGraphID = winname(0,1)
	    endif
       graphIDs = addlistItem(openGraphID, graphIDs, ";", INF)


	    if (is2d)
	        wn = wn+"_2d"
	        openGraphID = graphExistsForWavename(wn)
	        if (cmpstr(openGraphID, "")) // Graph is already open (str != "")
	            setUpGraph2D(openGraphID, wn, x_label, y_label, spectrum=spectrum)
	        else 
	            open2Dgraph(wn, x_label, y_label, spectrum=spectrum)
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
    for (i = 0; i < ItemsInList(graphTitles); i++)  
        title = StringFromList(i, graphTitles)
        if (stringMatch(wn, title))
            return stringFromList(i, graphIDs)  
        endif
    endfor
    return ""
end

function open1Dgraph(wn, x_label, [y_label, spectrum])
    // Opens 1D graph for wn
    string wn, x_label, y_label
    variable spectrum
    
    y_label = selectString(paramIsDefault(y_label), y_label, "")
    
    display $wn
    setWindow kwTopWin, graphicsTech=0
    
    setUpGraph1D(WinName(0,1), x_label, y_label=y_label, spectrum=spectrum)
end

function open2Dgraph(wn, x_label, y_label, [spectrum])
    // Opens 2D graph for wn
    string wn, x_label, y_label
    variable spectrum
    wave w = $wn
    if (dimsize(w, 1) == 0)
    	abort "Trying to open a 2D graph for a 1D wave"
    endif
    
    display
    setwindow kwTopWin, graphicsTech=0
    appendimage $wn
    setUpGraph2D(WinName(0,1), wn, x_label, y_label, spectrum=spectrum)
end

function setUpGraph1D(graphID, x_label, [y_label, spectrum])
    string graphID, x_label, y_label
    variable spectrum
    // Sets axis labels, datnum etc
    setaxis/w=$graphID /a
    Label /W=$graphID bottom, x_label
    if (!paramisDefault(y_label))
        Label /W=$graphID left, y_label
    endif

    variable num
    if (spectrum)
		nvar sanum
		num = sanum
	else
		nvar filenum
		num = filenum
	endif
    TextBox /W=$graphID/C/N=datnum/A=LT/X=1.0/Y=1.0/E=2 "Dat"+num2str(num)
end

function setUpGraph2D(graphID, wn, x_label, y_label, [spectrum])
    string graphID, wn, x_label, y_label
    variable spectrum
    svar sc_ColorMap
    // Sets axis labels, datnum etc
    Label /W=$graphID bottom, x_label
    Label /W=$graphID left, y_label

    modifyimage /W=$graphID $wn ctab={*, *, $sc_ColorMap, 0}
    colorscale /c/n=$sc_ColorMap /e/a=rc image=$wn

    variable num
    if (spectrum)
		nvar sanum
		num = sanum
	else
		nvar filenum
		num = filenum
	endif
    TextBox /W=$graphID/C/N=datnum/A=LT/X=1.0/Y=1.0/E=2 "Dat"+num2str(num)
    
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
		graphTitles += plottitle+";"
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



/////////////////////////////
//// configuration files ////
/////////////////////////////

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


function /s new_sc_createSweepLogs([S, comments])
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
    endif

    sc_instrumentLogs(jstr)  // Modifies the jstr to add Instrumt Status (from ScanController Window)
	return jstr
end

function sc_instrumentLogs(jstr)
	// instrument logs (ScanController Window)
	// all log strings should be valid JSON objects
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


// In order to enable or disable a wave
// call these two functions instead of messing with the waves sc_RawRecord and sc_CalcRecord directly
// function EnableScanControllerItem(wn)
// 	string wn
// 	ChangeScanControllerItemStatus(wn, 1)
// end

// function DisableScanControllerItem(wn)
// 	string wn
// 	ChangeScanControllerItemStatus(wn, 0)
// end

// function ChangeScanControllerItemStatus(wn, ison)
// 	string wn
// 	variable ison
// 	string cmd
// 	wave sc_RawRecord, sc_CalcRecord
// 	wave /t sc_RawWaveNames, sc_CalcWaveNames
// 	variable i=0, done=0
// 	do
// 		if (stringmatch(sc_RawWaveNames[i], wn))
// 			sc_RawRecord[i]=ison
// 			cmd = "CheckBox sc_RawRecordCheckBox" + num2istr(i) + " value=" + num2istr(ison)
// 			execute(cmd)
// 			done=1
// 		endif
// 		i+=1
// 	while (i<numpnts( sc_RawWaveNames ) && !done)

// 	i=0
// 	do
// 		if (stringmatch(sc_CalcWaveNames[i], wn))
// 			sc_CalcRecord[i]=ison
// 			cmd = "CheckBox sc_CalcRecordCheckBox" + num2istr(i) + " value=" + num2istr(ison)
// 			execute(cmd)
// 		endif
// 		i+=1
// 	while (i<numpnts( sc_CalcWaveNames ) && !done)

// 	if (!done)
// 		print "Error: Could not find the wave name specified."
// 	endif
// 	execute("doupdate")
// end



////////////////////////////////////////////
/// Slow ScanController Recording Data /////
////////////////////////////////////////////

function New_RecordValues(S, i, j, [readvstime, fillnan])
	// In a 1d scan, i is the index of the loop. j will be ignored.
	// In a 2d scan, i is the index of the outer (slow) loop, and j is the index of the inner (fast) loop.

	// readvstime works only in 1d and rescales (grows) the wave at each index

	// fillnan=1 skips any read or calculation functions entirely and fills point [i,j] with nan
	Struct ScanVars &S
	variable i, j, readvstime, fillnan
	wave/t sc_RawWaveNames, sc_RawScripts, sc_CalcWaveNames, sc_CalcScripts
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	nvar sc_abortsweep, sc_pause, sc_scanstarttime
	variable ii = 0
	
	////// TEMPORARY FIX
	variable sc_is2d = S.is2d
	variable sc_startx = S.startx
	variable sc_finx = S.finx
	variable sc_numptsx = S.numptsx
	variable sc_starty = S.starty
	variable sc_finy = S.finy
	variable sc_numptsy = S.numptsy

	if (i==0 && j==0)
		print "WARNING[New_RecordValues]: This is just a temporary fix for RecordValues!! It needs re-writing"	
	endif
//	abort "Not reimplemented yet. Needs to use ScanVars etc similar to fastdac, and be tested"
	//TODO: DO this

	//// setup all sorts of logic so we can store values correctly ////

	variable innerindex, outerindex
	if (sc_is2d == 1 || sc_is2d == 2) //1 is normal 2D, 2 is Line2D
		// 2d
		innerindex = j
		outerindex = i
	else
		// 1d
		innerindex = i
		outerindex = i // meaningless
	endif

	// Set readvstime to 0 if it's not defined
	if(paramisdefault(readvstime))
		readvstime=0
	endif

	if(innerindex==0 && outerindex==0)
		variable/g sc_rvt = readvstime // needed for rescaling in SaveWaves()
	endif

	if(readvstime==1 && sc_is2d)
		abort "NOT IMPLEMENTED: Read vs Time is currently only supported for 1D sweeps."
	endif

	//// fill NaNs? ////

	if(paramisdefault(fillnan))
		fillnan = 0 // defaults to 0
	elseif(fillnan==1)
		fillnan = 1 // again, obvious
	else
		fillnan=0   // if something other than 1, assume default
	endif

	//// Setup and run async data collection ////
	wave sc_measAsync
	if( (sum(sc_measAsync) > 1) && (fillnan==0) && (sc_is2d != 2))
		variable tgID = sc_ManageThreads(innerindex, outerindex, readvstime) // start threads, wait, collect data
		sc_KillThreads(tgID) // Terminate threads
	endif

	//// Read sync data ( or fill NaN) ////
	variable /g sc_tmpVal
	variable dx			//For 2Dline
	wave sc_linestart, sc_xdata 	//For 2Dline  
	string script = "", cmd = ""
	ii=0
	do
		if ((sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1) && sc_measAsync[ii]==0)
			wave wref1d = $sc_RawWaveNames[ii]

			// Redimension waves if readvstime is set to 1
			if (readvstime == 1)
				redimension /n=(innerindex+1) wref1d
				setscale/I x 0,  datetime - sc_scanstarttime, wref1d
			endif

			if(fillnan == 0)
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

			if (sc_is2d == 1)
				// 2D Wave
				wave wref2d = $sc_RawWaveNames[ii] + "2d"
				wref2d[innerindex][outerindex] = wref1d[innerindex]
			elseif (sc_is2d == 2 && fillnan == 0)
				//2D line wave
				FindValue/V=0/T=(inf) wref1D 	//Finds the first non NaN and stores position in V_value (V=value, T=tolerance)
				if(innerindex == V_value)		//records the x value of the first notNaN for all line2D graphs  
					sc_linestart[outerindex] = sc_xdata[innerindex]
				endif
				wave wref2d = $sc_RawWaveNames[ii] + "2d"
				if(dimsize(wref2d, 0)-1 < innerindex-V_value) //Does 2D line wave need larger x range?
					dx = dimdelta(wref2d, 0) 																//saves delta x of original to put back in
					make/o/n=(dimsize(wref2d,0)+1, dimsize(wref2d,1)) temp2Dwave = NaN 			//Make new larger wave 	
					temp2Dwave[0,dimsize(wref2d,0)-1][0,dimsize(wref2d,1)-1] = wref2d[p][q] 	//copy over old values with NaNs everywhere else
					duplicate/O temp2Dwave wref2d															//Put back into old wave
					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + nameofwave(wref2d); execute(cmd) //Sets Y scale again
					cmd = "setscale /P x, 0, " + num2str(dx) + ", " + nameofwave(wref2d); execute(cmd) //Sets x scale again (starts at 0 but with correct delta)
					killwaves temp2Dwave																	//Clear mess
				endif	
				wref2d[innerindex-(V_value)][outerindex] = wref1d[innerindex] 	//Using V_value from FindValue a few lines up
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
			if (readvstime == 1)
				redimension /n=(innerindex+1) wref1d
				setscale/I x 0, datetime - sc_scanstarttime, wref1d
			endif

			if(fillnan == 0)
				script = TrimString(sc_CalcScripts[ii])
				// Allow the use of the keyword '[i]' in calculated fields where i is the inner loop's current index
				script = ReplaceString("[i]", script, "["+num2istr(innerindex)+"]")
				sprintf cmd, "%s = %s", "sc_tmpVal", script
				Execute/Q/Z cmd
				if(V_flag!=0)
					print "[ERROR] in RecordValues (calc): "+GetErrMessage(V_Flag,2)
				endif
			elseif(fillnan == 1)
				sc_tmpval = NaN
			endif
			wref1d[innerindex] = sc_tmpval

			if (sc_is2d == 1)
				wave wref2d = $sc_CalcWaveNames[ii] + "2d"
				wref2d[innerindex][outerindex] = wref1d[innerindex]
			elseif (sc_is2d == 2 && fillnan == 0)
				//2D line wave
				FindValue/V=0/T=(inf) wref1D 	//Finds the first non NaN and stores position in V_value (V=value, T=tolerance)
				
				if(innerindex == V_value)		//records the x value of the first notNaN for all line2D graphs  
					sc_linestart[outerindex] = sc_xdata[innerindex]
				endif
				wave wref2d = $sc_CalcWaveNames[ii] + "2d"
				if(dimsize(wref2d, 0)-1 < innerindex-V_value && v_value != -1) //Does 2D line wave need larger x range?
					dx = dimdelta(wref2d, 0)
					make/o/n=(dimsize(wref2d,0)+1, dimsize(wref2d,1)) temp2Dwave = NaN 			//Make new larger wave 	
					temp2Dwave[0,dimsize(wref2d,0)-1][0,dimsize(wref2d,1)-1] = wref2d[p][q] 	//copy over old values with NaNs everywhere else
					duplicate/O temp2Dwave wref2d															//Put back into old wave
					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + nameofwave(wref2d); execute(cmd) //Sets Y scale again
					cmd = "setscale /P x, 0, " + num2str(dx) + ", " + nameofwave(wref2d); execute(cmd) //Sets x scale again (starts at 0 but with correct delta)
					killwaves temp2Dwave																	//Clear mess
				endif
				if (v_value != -1 && V_value < innerindex) //don't fill a NaN or if V_value is actually from previous line of data (because it will try index out of range)
					wref2d[innerindex-(V_value)][outerindex] = wref1d[innerindex] 	//Using V_value from FindValue a few lines up 	
				endif
			endif
		endif
		ii+=1
	while (ii < numpnts(sc_CalcWaveNames))

	// check abort/pause status
	try
		sc_checksweepstate()
	catch
		variable err = GetRTError(1)
		
		// reset sweep control parameters if igor abort button is used
		if(v_abortcode == -1)
			sc_abortsweep = 0
			sc_pause = 0
		endif
		
		//silent abort
		abortonvalue 1,10 
	endtry
end




function RecordValues(i, j, [readvstime, fillnan])
	// In a 1d scan, i is the index of the loop. j will be ignored.
	// In a 2d scan, i is the index of the outer (slow) loop, and j is the index of the inner (fast) loop.

	// readvstime works only in 1d and rescales (grows) the wave at each index

	// fillnan=1 skips any read or calculation functions entirely and fills point [i,j] with nan

	variable i, j, readvstime, fillnan
	nvar sc_is2d, sc_startx, sc_finx, sc_numptsx, sc_starty, sc_finy, sc_numptsy
	wave/t sc_RawWaveNames, sc_RawScripts, sc_CalcWaveNames, sc_CalcScripts
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	nvar sc_abortsweep, sc_pause, sc_scanstarttime
	variable ii = 0
	
	
	
	abort "Not reimplemented yet. Needs to use ScanVars etc similar to fastdac, and be tested"
	//TODO: DO this

	//// setup all sorts of logic so we can store values correctly ////

	variable innerindex, outerindex
	if (sc_is2d == 1 || sc_is2d == 2) //1 is normal 2D, 2 is Line2D
		// 2d
		innerindex = j
		outerindex = i
	else
		// 1d
		innerindex = i
		outerindex = i // meaningless
	endif

	// Set readvstime to 0 if it's not defined
	if(paramisdefault(readvstime))
		readvstime=0
	endif

	if(innerindex==0 && outerindex==0)
		variable/g sc_rvt = readvstime // needed for rescaling in SaveWaves()
	endif

	if(readvstime==1 && sc_is2d)
		abort "NOT IMPLEMENTED: Read vs Time is currently only supported for 1D sweeps."
	endif

	//// fill NaNs? ////

	if(paramisdefault(fillnan))
		fillnan = 0 // defaults to 0
	elseif(fillnan==1)
		fillnan = 1 // again, obvious
	else
		fillnan=0   // if something other than 1, assume default
	endif

	//// Setup and run async data collection ////
	wave sc_measAsync
	if( (sum(sc_measAsync) > 1) && (fillnan==0) && (sc_is2d != 2))
		variable tgID = sc_ManageThreads(innerindex, outerindex, readvstime) // start threads, wait, collect data
		sc_KillThreads(tgID) // Terminate threads
	endif

	//// Read sync data ( or fill NaN) ////
	variable /g sc_tmpVal
	variable dx			//For 2Dline
	wave sc_linestart, sc_xdata 	//For 2Dline  
	string script = "", cmd = ""
	ii=0
	do
		if ((sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1) && sc_measAsync[ii]==0)
			wave wref1d = $sc_RawWaveNames[ii]

			// Redimension waves if readvstime is set to 1
			if (readvstime == 1)
				redimension /n=(innerindex+1) wref1d
				setscale/I x 0,  datetime - sc_scanstarttime, wref1d
			endif

			if(fillnan == 0)
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

			if (sc_is2d == 1)
				// 2D Wave
				wave wref2d = $sc_RawWaveNames[ii] + "2d"
				wref2d[innerindex][outerindex] = wref1d[innerindex]
			elseif (sc_is2d == 2 && fillnan == 0)
				//2D line wave
				FindValue/V=0/T=(inf) wref1D 	//Finds the first non NaN and stores position in V_value (V=value, T=tolerance)
				if(innerindex == V_value)		//records the x value of the first notNaN for all line2D graphs  
					sc_linestart[outerindex] = sc_xdata[innerindex]
				endif
				wave wref2d = $sc_RawWaveNames[ii] + "2d"
				if(dimsize(wref2d, 0)-1 < innerindex-V_value) //Does 2D line wave need larger x range?
					dx = dimdelta(wref2d, 0) 																//saves delta x of original to put back in
					make/o/n=(dimsize(wref2d,0)+1, dimsize(wref2d,1)) temp2Dwave = NaN 			//Make new larger wave 	
					temp2Dwave[0,dimsize(wref2d,0)-1][0,dimsize(wref2d,1)-1] = wref2d[p][q] 	//copy over old values with NaNs everywhere else
					duplicate/O temp2Dwave wref2d															//Put back into old wave
					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + nameofwave(wref2d); execute(cmd) //Sets Y scale again
					cmd = "setscale /P x, 0, " + num2str(dx) + ", " + nameofwave(wref2d); execute(cmd) //Sets x scale again (starts at 0 but with correct delta)
					killwaves temp2Dwave																	//Clear mess
				endif	
				wref2d[innerindex-(V_value)][outerindex] = wref1d[innerindex] 	//Using V_value from FindValue a few lines up
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
			if (readvstime == 1)
				redimension /n=(innerindex+1) wref1d
				setscale/I x 0, datetime - sc_scanstarttime, wref1d
			endif

			if(fillnan == 0)
				script = TrimString(sc_CalcScripts[ii])
				// Allow the use of the keyword '[i]' in calculated fields where i is the inner loop's current index
				script = ReplaceString("[i]", script, "["+num2istr(innerindex)+"]")
				sprintf cmd, "%s = %s", "sc_tmpVal", script
				Execute/Q/Z cmd
				if(V_flag!=0)
					print "[ERROR] in RecordValues (calc): "+GetErrMessage(V_Flag,2)
				endif
			elseif(fillnan == 1)
				sc_tmpval = NaN
			endif
			wref1d[innerindex] = sc_tmpval

			if (sc_is2d == 1)
				wave wref2d = $sc_CalcWaveNames[ii] + "2d"
				wref2d[innerindex][outerindex] = wref1d[innerindex]
			elseif (sc_is2d == 2 && fillnan == 0)
				//2D line wave
				FindValue/V=0/T=(inf) wref1D 	//Finds the first non NaN and stores position in V_value (V=value, T=tolerance)
				
				if(innerindex == V_value)		//records the x value of the first notNaN for all line2D graphs  
					sc_linestart[outerindex] = sc_xdata[innerindex]
				endif
				wave wref2d = $sc_CalcWaveNames[ii] + "2d"
				if(dimsize(wref2d, 0)-1 < innerindex-V_value && v_value != -1) //Does 2D line wave need larger x range?
					dx = dimdelta(wref2d, 0)
					make/o/n=(dimsize(wref2d,0)+1, dimsize(wref2d,1)) temp2Dwave = NaN 			//Make new larger wave 	
					temp2Dwave[0,dimsize(wref2d,0)-1][0,dimsize(wref2d,1)-1] = wref2d[p][q] 	//copy over old values with NaNs everywhere else
					duplicate/O temp2Dwave wref2d															//Put back into old wave
					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + nameofwave(wref2d); execute(cmd) //Sets Y scale again
					cmd = "setscale /P x, 0, " + num2str(dx) + ", " + nameofwave(wref2d); execute(cmd) //Sets x scale again (starts at 0 but with correct delta)
					killwaves temp2Dwave																	//Clear mess
				endif
				if (v_value != -1 && V_value < innerindex) //don't fill a NaN or if V_value is actually from previous line of data (because it will try index out of range)
					wref2d[innerindex-(V_value)][outerindex] = wref1d[innerindex] 	//Using V_value from FindValue a few lines up 	
				endif
			endif
		endif
		ii+=1
	while (ii < numpnts(sc_CalcWaveNames))

	// check abort/pause status
	try
		sc_checksweepstate()
	catch
		variable err = GetRTError(1)
		
		// reset sweep control parameters if igor about button is used
		if(v_abortcode == -1)
			sc_abortsweep = 0
			sc_pause = 0
		endif
		
		//silent abort
		abortonvalue 1,10 
	endtry
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

// function InitializeWaves(start, fin, numpts, [starty, finy, numptsy, x_label, y_label, linecut, fastdac]) //linecut = 0,1 for false, true
// 	variable start, fin, numpts, starty, finy, numptsy, linecut, fastdac
// 	string x_label, y_label
// 	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
// 	wave/t sc_RawWaveNames, sc_CalcWaveNames, sc_RawScripts, sc_CalcScripts
// 	variable i=0, j=0
// 	string cmd = "", wn = "", wn2d="", s, script = "", script0 = "", script1 = ""
// 	string/g sc_x_label, sc_y_label, activegraphs=""
// 	variable/g sc_is2d, sc_scanstarttime = datetime
// 	variable/g sc_startx, sc_finx, sc_numptsx, sc_starty, sc_finy, sc_numptsy
// 	variable/g sc_abortsweep=0, sc_pause=0, sc_abortnosave=0
// 	string graphlist, graphname, plottitle, graphtitle="", graphnumlist="", graphnum, cmd1="",window_string=""
// 	string cmd2=""
// 	variable index, graphopen, graphopen2d
// 	svar sc_colormap
// 	variable/g fastdac_init = 0

// 	if(paramisdefault(fastdac))
// 		fastdac = 0
// 		fastdac_init = 0
// 	elseif(fastdac == 1)
// 		fastdac_init = 1
// 	else
// 		// set fastdac = 1 if you want to use the fastdac!
// 		print("[WARNING] \"InitializeWaves\": Pass fastdac = 1! Setting it to 0.")
// 		fastdac = 0
// 		fastdac_init = 0
// 	endif

// 	if(fastdac == 0)
// 		//do some sanity checks on wave names: they should not start or end with numbers.
// 		do
// 			if (sc_RawRecord[i])
// 				s = sc_RawWaveNames[i]
// 				if (!((char2num(s[0]) >= 97 && char2num(s[0]) <= 122) || (char2num(s[0]) >= 65 && char2num(s[0]) <= 90)))
// 					print "The first character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
// 					abort
// 				endif
// 				if (!((char2num(s[strlen(s)-1]) >= 97 && char2num(s[strlen(s)-1]) <= 122) || (char2num(s[strlen(s)-1]) >= 65 && char2num(s[strlen(s)-1]) <= 90)))
// 					print "The last character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
// 					abort
// 				endif
// 			endif
// 			i+=1
// 		while (i<numpnts(sc_RawWaveNames))
// 		i=0
// 		do
// 			if (sc_CalcRecord[i])
// 				s = sc_CalcWaveNames[i]
// 				if (!((char2num(s[0]) >= 97 && char2num(s[0]) <= 122) || (char2num(s[0]) >= 65 && char2num(s[0]) <= 90)))
// 					print "The first character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
// 					abort
// 				endif
// 				if (!((char2num(s[strlen(s)-1]) >= 97 && char2num(s[strlen(s)-1]) <= 122) || (char2num(s[strlen(s)-1]) >= 65 && char2num(s[strlen(s)-1]) <= 90)))
// 					print "The last character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
// 					abort
// 				endif
// 			endif
// 			i+=1
// 		while (i<numpnts(sc_CalcWaveNames))
// 	endif
// 	i=0

// 	// Close all Resource Manager sessions
// 	// and then reopen all instruemnt connections.
// 	// VISA tents to drop the connections after being
// 	// idle for a while.
// 	killVISA()
// 	sc_OpenInstrConnections(0)

// 	// The status of the upcoming scan will be set when waves are initialized.
// 	if(!paramisdefault(starty) && !paramisdefault(finy) && !paramisdefault(numptsy))
// 		sc_is2d = 1
// 		sc_startx = start
// 		sc_finx = fin
// 		sc_numptsx = numpts
// 		sc_starty = starty
// 		sc_finy = finy
// 		sc_numptsy = numptsy
// 		if(start==fin || starty==finy)
// 			print "[WARNING]: Your start and end values are the same!"
// 		endif
// 	else
// 		sc_is2d = 0
// 		sc_startx = start
// 		sc_finx = fin
// 		sc_numptsx = numpts
// 		if(start==fin)
// 			print "[WARNING]: Your start and end values are the same!"
// 		endif
// 	endif

// 	if(linecut == 1)
// 		sc_is2d = 2
// 		make/O/n=(numptsy) sc_linestart = NaN 						//To store first xvalue of each line of data
// 		cmd = "setscale/I x " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + "sc_linestart"; execute(cmd)
// 	endif

// 	if(paramisdefault(x_label) || stringmatch(x_label,""))
// 		sc_x_label=""
// 	else
// 		sc_x_label=x_label
// 	endif

// 	if(paramisdefault(y_label) || stringmatch(y_label,""))
// 		sc_y_label=""
// 	else
// 		sc_y_label=y_label
// 	endif

// 	// create waves to hold x and y data (in case I want to save it)
// 	// this is pretty useless if using readvstime
// 	cmd = "make /o/n=(" + num2istr(sc_numptsx) + ") " + "sc_xdata" + "=NaN"; execute(cmd)
// 	cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + "sc_xdata"; execute(cmd)
// 	cmd = "sc_xdata" +" = x"; execute(cmd)
// 	if(sc_is2d != 0)
// 		cmd = "make /o/n=(" + num2istr(sc_numptsy) + ") " + "sc_ydata" + "=NaN"; execute(cmd)
// 		cmd = "setscale/I x " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", \"\", " + "sc_ydata"; execute(cmd)
// 		cmd = "sc_ydata" +" = x"; execute(cmd)
// 	endif

// 	if(fastdac == 0)
// 		// Initialize waves for raw data
// 		do
// 			if (sc_RawRecord[i] == 1 && cmpstr(sc_RawWaveNames[i], "") || sc_RawPlot[i] == 1 && cmpstr(sc_RawWaveNames[i], ""))
// 				wn = sc_RawWaveNames[i]
// 				cmd = "make /o/n=(" + num2istr(sc_numptsx) + ") " + wn + "=NaN"
// 				execute(cmd)
// 				cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + wn
// 				execute(cmd)
// 				if(sc_is2d == 1)
// 					// In case this is a 2D measurement
// 					wn2d = wn + "2d"
// 					cmd = "make /o/n=(" + num2istr(sc_numptsx) + ", " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd)
// 					cmd = "setscale /i x, " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", " + wn2d; execute(cmd)
// 					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)
// 				elseif(sc_is2d == 2)
// 					// In case this is a 2D line cut measurement
// 					wn2d = sc_RawWaveNames[i]+"2d"
// 					cmd = "make /o/n=(1, " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd) //Makes 1 by y wave, x is redimensioned in recordline
// 					cmd = "setscale /P x, 0, " + num2str((sc_finx-sc_startx)/sc_numptsx) + "," + wn2d; execute(cmd) //sets x scale starting from 0 but with delta correct
// 					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)//Useful to see if top and bottom of scan are filled with NaNs
// 				endif
// 			endif
// 			i+=1
// 		while (i<numpnts(sc_RawWaveNames))

// 		// Initialize waves for calculated data
// 		i=0
// 		do
// 			if (sc_CalcRecord[i] == 1 && cmpstr(sc_CalcWaveNames[i], "") || sc_CalcPlot[i] == 1 && cmpstr(sc_CalcWaveNames[i], ""))
// 				wn = sc_CalcWaveNames[i]
// 				cmd = "make /o/n=(" + num2istr(sc_numptsx) + ") " + wn + "=NaN"
// 				execute(cmd)
// 				cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + wn
// 				execute(cmd)
// 				if(sc_is2d == 1)
// 					// In case this is a 2D measurement
// 					wn2d = wn + "2d"
// 					cmd = "make /o/n=(" + num2istr(sc_numptsx) + ", " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd)
// 					cmd = "setscale /i x, " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", " + wn2d; execute(cmd)
// 					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)
// 				elseif(sc_is2d == 2)
// 					// In case this is a 2D line cut measurement
// 					wn2d = sc_CalcWaveNames[i]+"2d"
// 					cmd = "make /o/n=(1, " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd) //Same as for Raw (see above)
// 					cmd = "setscale /P x, 0, " + num2str((sc_finx-sc_startx)/sc_numptsx) + "," + wn2d; execute(cmd) //sets x scale starting from 0 but with delta correct
// 					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)
// 				endif
// 			endif
// 			i+=1
// 		while (i<numpnts(sc_CalcWaveNames))

// 		sc_findAsyncMeasurements()

// 	elseif(fastdac == 1)
// 		// create waves for fastdac
// 		wave/t fadcvalstr
// 		wave fadcattr
// 		string/g sc_fastadc = ""
// 		string wn_raw = "", wn_raw2d = ""
// 		i=0
// 		do
// 			if(fadcattr[i][2] == 48) // checkbox checked
// 				sc_fastadc = addlistitem(fadcvalstr[i][0], sc_fastadc, ",", inf)  //Add adc_channel to list being recorded (inf to add at end)
// 				wn = fadcvalstr[i][3]
// 				cmd = "make/o/n=(" + num2istr(sc_numptsx) + ") " + wn + "=NaN"
// 				execute(cmd)
// 				cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + wn
// 				execute(cmd)

// 				wn_raw = "ADC"+num2istr(i)
// 				cmd = "make/o/n=(" + num2istr(sc_numptsx) + ") " + wn_raw + "=NaN"
// 				execute(cmd)
// 				cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + wn_raw
// 				execute(cmd)

// 				if(sc_is2d > 0)  // Should work for linecut too I think?
// 					// In case this is a 2D measurement
// 					wn2d = wn + "_2d"
// 					cmd = "make /o/n=(" + num2istr(sc_numptsx) + ", " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd)
// 					cmd = "setscale /i x, " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", " + wn2d; execute(cmd)
// 					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)

// 					wn_raw2d = wn_raw + "_2d"
// 					cmd = "make /o/n=(" + num2istr(sc_numptsx) + ", " + num2istr(sc_numptsy) + ") " + wn_raw2d + "=NaN"; execute(cmd)
// 					cmd = "setscale /i x, " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", " + wn_raw2d; execute(cmd)
// 					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn_raw2d; execute(cmd)
// 				endif
// 			endif
// 			i++
// 		while(i<dimsize(fadcvalstr,0))
// 		sc_fastadc = sc_fastadc[0,strlen(sc_fastadc)-2]  // To chop off trailing comma
// 	endif

// 	// Find all open plots
// 	graphlist = winlist("*",";","WIN:1")
// 	j=0
// 	for (i=0;i<itemsinlist(graphlist);i=i+1)
// 		index = strsearch(graphlist,";",j)
// 		graphname = graphlist[j,index-1]
// 		setaxis/w=$graphname /a
// 		getwindow $graphname wtitle
// 		splitstring /e="(.*):(.*)" s_value, graphnum, plottitle
// 		graphtitle+= plottitle+";"
// 		graphnumlist+= graphnum+";"
// 		j=index+1
// 	endfor

// 	nvar filenum

// 	if(fastdac == 0)
// 		//Initialize plots for raw data waves
// 		i=0
// 		do
// 			if (sc_RawPlot[i] == 1 && cmpstr(sc_RawWaveNames[i], ""))
// 				wn = sc_RawWaveNames[i]
// 				graphopen = 0
// 				graphopen2d = 0
// 				for(j=0;j<ItemsInList(graphtitle);j=j+1)
// 					if(stringmatch(wn,stringfromlist(j,graphtitle)))
// 						graphopen = 1
// 						activegraphs+= stringfromlist(j,graphnumlist)+";"
// 						Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label	
// 						if(sc_is2d == 0)
// 							Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label  // Can add something like current /nA as y_label for 1D only... if 2D sc_y_label will be for 2D plot
// 						endif
// 						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)					
// 					endif
// 					if(sc_is2d)
// 						if(stringmatch(wn+"2d",stringfromlist(j,graphtitle)))
// 							graphopen2d = 1
// 							activegraphs+= stringfromlist(j,graphnumlist)+";"
// 							Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
// 							Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
// 							TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)	
// 						endif
// 					endif
// 				endfor
// 				if(graphopen && graphopen2d) //If both open do nothing
// 				elseif(graphopen2d) //If only 2D is open then open 1D
// 					display $wn
// 					setwindow kwTopWin, graphicsTech=0
// 					Label bottom, sc_x_label
// 					if(sc_is2d == 0)
// 						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
// 					endif
// 					TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 					activegraphs+= winname(0,1)+";"
// 				elseif(graphopen) // If only 1D is open then open 2D
// 					if(sc_is2d)
// 						wn2d = wn + "2d"
// 						display
// 						setwindow kwTopWin, graphicsTech=0
// 						appendimage $wn2d
// 						modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
// 						colorscale /c/n=$sc_ColorMap /e/a=rc image=$wn2d
// 						Label left, sc_y_label
// 						Label bottom, sc_x_label
// 						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 						activegraphs+= winname(0,1)+";"
// 					endif
// 				else // Open Both
// 					wn2d = wn + "2d"
// 					display $wn
// 					setwindow kwTopWin, graphicsTech=0
// 					Label bottom, sc_x_label
// 					if(sc_is2d == 0)
// 						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
// 					endif
// 					TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 					activegraphs+= winname(0,1)+";"
// 					if(sc_is2d)
// 						display
// 						setwindow kwTopWin, graphicsTech=0
// 						appendimage $wn2d
// 						modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
// 						colorscale /c/n=$sc_ColorMap /e/a=rc image=$wn2d
// 						Label left, sc_y_label
// 						Label bottom, sc_x_label
// 						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 						activegraphs+= winname(0,1)+";"
// 					endif
// 				endif
// 			endif
// 		i+= 1
// 		while(i<numpnts(sc_RawWaveNames))

// 		//Initialize plots for calculated data waves
// 		i=0
// 		do
// 			if (sc_CalcPlot[i] == 1 && cmpstr(sc_CalcWaveNames[i], ""))
// 				wn = sc_CalcWaveNames[i]
// 				graphopen = 0
// 				graphopen2d = 0
// 				for(j=0;j<ItemsInList(graphtitle);j=j+1)
// 					if(stringmatch(wn,stringfromlist(j,graphtitle)))
// 						graphopen = 1
// 						activegraphs+= stringfromlist(j,graphnumlist)+";"
// 						Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
// 						if(sc_is2d == 0)
// 							Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label 
// 						endif
// 						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 					endif
// 					if(sc_is2d)
// 						if(stringmatch(wn+"2d",stringfromlist(j,graphtitle)))
// 							graphopen2d = 1
// 							activegraphs+= stringfromlist(j,graphnumlist)+";"
// 							Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
// 							Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
// 							TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 						endif
// 					endif
// 				endfor
// 				if(graphopen && graphopen2d)
// 				elseif(graphopen2d) // If only 2D open then open 1D
// 					display $wn
// 					setwindow kwTopWin, graphicsTech=0
// 					Label bottom, sc_x_label
// 					if(sc_is2d == 0)
// 						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
// 					endif
// 					TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 					activegraphs+= winname(0,1)+";"
// 				elseif(graphopen) // If only 1D is open then open 2D
// 					if(sc_is2d)
// 						wn2d = wn + "2d"
// 						display
// 						appendimage $wn2d
// 						modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
// 						colorscale /c/n=$sc_ColorMap /e/a=rc image=$wn2d
// 						Label left, sc_y_label
// 						setwindow kwTopWin, graphicsTech=0
// 						Label bottom, sc_x_label
// 						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 						activegraphs+= winname(0,1)+";"
// 					endif
// 				else // open both
// 					wn2d = wn + "2d"
// 					display $wn
// 					setwindow kwTopWin, graphicsTech=0
// 					Label bottom, sc_x_label
// 					if(sc_is2d == 0)
// 						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
// 					endif
// 					TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 					activegraphs+= winname(0,1)+";"
// 					if(sc_is2d)
// 						display
// 						setwindow kwTopWin, graphicsTech=0
// 						appendimage $wn2d
// 						modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
// 						colorscale /c/n=$sc_ColorMap /e/a=rc image=$wn2d
// 						Label left, sc_y_label
// 						Label bottom, sc_x_label
// 						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 						activegraphs+= winname(0,1)+";"
// 					endif
// 				endif
// 			endif
// 			i+= 1
// 		while(i<numpnts(sc_CalcWaveNames))
	
// 	elseif(fastdac == 1)
// 		// open plots for fastdac
// 		i=0
// 		do
// 			if(fadcattr[i][2] == 48)
// 				wn = fadcvalstr[i][3]
// 				graphopen = 0
// 				graphopen2d = 0
// 				for(j=0;j<ItemsInList(graphtitle);j=j+1)
// 					if(stringmatch(wn,stringfromlist(j,graphtitle)))
// 						graphopen = 1
// 						activegraphs+= stringfromlist(j,graphnumlist)+";"
// 						Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
// 						if(sc_is2d == 0)
// 							Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
// 						endif
// 						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 					endif
// 					if(sc_is2d)
// 						if(stringmatch(wn+"_2d",stringfromlist(j,graphtitle)))
// 							graphopen2d = 1
// 							activegraphs+= stringfromlist(j,graphnumlist)+";"
// 							Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
// 							Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
// 							TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 						endif
// 					endif
// 				endfor
// 				if(graphopen && graphopen2d)
// 				elseif(graphopen2d)  // If only 2D open then open 1D
// 					display $wn
// 					setwindow kwTopWin, graphicsTech=0
// 					Label bottom, sc_x_label
// 					if(sc_is2d == 0)
// 						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
// 					endif
// 					TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 					activegraphs+= winname(0,1)+";"
// 				elseif(graphopen) // If only 1D is open then open 2D
// 					if(sc_is2d)
// 						wn2d = wn + "_2d"
// 						display
// 						setwindow kwTopWin, graphicsTech=0
// 						appendimage $wn2d
// 						modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
// 						colorscale /c/n=$sc_ColorMap /e/a=rc image=$wn2d
// 						Label left, sc_y_label
// 						Label bottom, sc_x_label
// 						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 						activegraphs+= winname(0,1)+";"
// 					endif
// 				else // open both
// 					wn2d = wn + "_2d"
// 					display $wn
// 					setwindow kwTopWin, graphicsTech=0
// 					Label bottom, sc_x_label
// 					if(sc_is2d == 0)
// 						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
// 					endif
// 					TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 					activegraphs+= winname(0,1)+";"
// 					if(sc_is2d)
// 						display
// 						setwindow kwTopWin, graphicsTech=0
// 						appendimage $wn2d
// 						modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
// 						colorscale /c/n=$sc_ColorMap /e/a=rc image=$wn2d
// 						Label left, sc_y_label
// 						Label bottom, sc_x_label
// 						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
// 						activegraphs+= winname(0,1)+";"
// 					endif
// 				endif
// 			endif
// 			i+= 1
// 		while(i<dimsize(fadcvalstr,0))
// 	endif
// 	execute("abortmeasurementwindow()")

// 	cmd1 = "TileWindows/O=1/A=(3,4) "
// 	cmd2 = ""
// 	// Tile graphs
// 	for(i=0;i<itemsinlist(activegraphs);i=i+1)
// 		window_string = stringfromlist(i,activegraphs)
// 		cmd1+= window_string +","

// 		cmd2 = "DoWindow/F " + window_string
// 		execute(cmd2)
// 	endfor
// 	cmd1 += "SweepControl"
// 	execute(cmd1)
// 	doupdate
// end
 

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
	// checks for keyboard interrupts in mstimer loop
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

///////////////////////
/// ASYNC handling ///
//////////////////////
// Slow ScanContoller ONLY


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

////////////////////////
////  Data/Experiment Saving   ////
////////////////////////



function EndScan([S, save_experiment, aborting])
	// Ends a scan:
	// Saves/Loads current/last ScanVars from global waves
	// Closes sweepcontrol if open
	// Save Metadata into HDF files
	// Saves Measured data into HDF files
	// Saves experiment

	Struct ScanVars &S  // Note: May not exist so can't be relied upon later
	variable save_experiment
	variable aborting
	
	nvar filenum
	variable current_filenum = filenum
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

	dowindow/k SweepControl // kill scan control window
	printf "Time elapsed: %.2f s \r", (S_.end_time-S_.start_time)
	HDF5CloseFile/A 0 //Make sure any previously opened HDFs are closed (may be left open if Igor crashes)
	
	if(S_.using_fastdac == 0)
		KillDataFolder/z root:async // clean this up for next time
		SaveToHDF(S_, 0)
	elseif(S_.using_fastdac == 1)
		SaveToHDF(S_, 1)
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
		sc_copyNewFiles(current_filenum, save_experiment=save_experiment)		// copy data to server mount point (nvar filenum gets incremented after HDF is opened)
	endif

	// add info about scan to the scan history file in /config
	//	sc_saveFuncCall(getrtstackinfo(2))
end

function loadLastScanVarsStruct(S)
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
	S.start_time = v[14]
	S.end_time = v[15]
	S.using_fastdac = v[16]
	S.numADCs = v[17]
	S.samplingFreq = v[18]
	S.measureFreq = v[19]
	S.sweeprate = v[20]

end
	
function saveAsLastScanVarsStruct(S)
	Struct ScanVars &S
	// TODO: Make these (note: can't just use StructPut/Get because they only work for numeric entries, not strings...
	make/o/T sc_lastScanVarsStrings = {S.channelsx, S.channelsy, S.x_label, S.y_label, S.comments, S.adcList, S.startxs, S.finxs, S.startys, S.finys}
	make/o sc_lastScanVarsVariables = {S.instrID, S.lims_checked, S.startx, S.finx, S.numptsx, S.rampratex, S.delayx, S.is2d, S.starty, S.finy, S.numptsy, S.rampratey, S.delayy, S.direction, S.start_time, S.end_time, S.using_fastdac, S.numADCs, S.samplingFreq, S.measureFreq, S.sweeprate}
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

function addMetaFiles(hdf5_id_list, [S, logs_only, comments])
	// meta data is created and added to the files in list
	string hdf5_id_list, comments
	Struct ScanVars &S
	variable logs_only  // 1=Don't save any data to HDF
	
	make /FREE /T /N=1 cconfig = prettyJSONfmt(sc_createconfig())
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
	filenum += 1  // So next created file gets a new num (setting here so that when saving fails, it doesn't try to overwrite next save)
	
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
	addMetaFiles(num2str(hdfid), logs_only=1, comments=comments)


//	initSaveFiles(msg=comments, logs_only=1)
	printf "Saving waves [%s] in dat%d.h5\r", wave_names, filenum

	// Now save each wave
	for(ii=0;ii<itemsinlist(wave_names, ",");ii++)
		wn = stringfromlist(ii, wave_names, ",")
		initSaveSingleWave(wn, hdfid)
	endfor
	initcloseSaveFiles(num2str(hdfid))
end


// function /s sc_createSweepLogs([msg])
// 	// Returns a Json string of 
// 	string msg
// 	string jstr = "", buffer = ""
// 	nvar filenum, sweep_t_elapsed
// 	svar sc_current_config, sc_hostname, sc_x_label, sc_y_label

// 	// information about this specific sweep
// 	if(numtype(strlen(msg)) == 2) // if null (default or set as null)
// 		msg = ""	
// 	endif
// 	jstr = addJSONkeyval(jstr, "comment", msg, addQuotes=1)
// 	jstr = addJSONkeyval(jstr, "filenum", num2istr(filenum))
	
// 	buffer = addJSONkeyval(buffer, "x", sc_x_label, addQuotes=1)
// 	buffer = addJSONkeyval(buffer, "y", sc_y_label, addQuotes=1)
// 	jstr = addJSONkeyval(jstr, "axis_labels", buffer)
	
// 	jstr = addJSONkeyval(jstr, "current_config", sc_current_config, addQuotes = 1)
// 	jstr = addJSONkeyval(jstr, "time_completed", Secs2Date(DateTime, 1)+" "+Secs2Time(DateTime, 3), addQuotes = 1)
// 	jstr = addJSONkeyval(jstr, "time_elapsed", num2numStr(sweep_t_elapsed))

// 	// instrument logs
// 	// all log strings should be valid JSON objects
// 	wave /t sc_Instr
// 	variable i=0, j=0, addQuotes=0
// 	string command="", val=""
// 	string /G sc_log_buffer=""
// 	for(i=0;i<DimSize(sc_Instr, 0);i+=1)
// 		sc_log_buffer=""
// 		command = TrimString(sc_Instr[i][2])
// 		if(strlen(command)>0)
// 			Execute/Q/Z "sc_log_buffer="+command
// 			if(V_flag!=0)
// 				print "[ERROR] in sc_createSweepLogs: "+GetErrMessage(V_Flag,2)
// 			endif
// 			if(strlen(sc_log_buffer)!=0)
// 				// need to get first key and value from sc_log_buffer
// 				JSONSimple sc_log_buffer
// 				wave/t t_tokentext
// 				wave w_tokentype, w_tokensize, w_tokenparent
	
// 				for(j=1;j<numpnts(t_tokentext)-1;j+=1)
// 					if ( w_tokentype[j]==3 && w_tokensize[j]>0 )
// 						if( w_tokenparent[j]==0 )
// 							if( w_tokentype[j+1]==3 )
// 								val = "\"" + t_tokentext[j+1] + "\""
// 							else
// 								val = t_tokentext[j+1]
// 							endif
// 							jstr = addJSONkeyval(jstr, t_tokentext[j], val)
// 							break
// 						endif
// 					endif
// 				endfor
				
// 			else
// 				print "[WARNING] command failed to log anything: "+command+"\r"
// 			endif
// 		endif
// 	endfor

// 	return jstr
// end

function saveExp()
	SaveExperiment /P=data // save current experiment as .pxp
	SaveFromPXP(history=1, procedure=1) // grab some useful plain text docs from the pxp
end

// function sc_update_xdata()
//     // update the sc_xdata wave
//     // to match the measured waves

// 	wave sc_xdata, sc_RawRecord, sc_RawPlot
// 	wave /t sc_RawWaveNames

// 	// look for the first wave that has recorded values
// 	string wn = ""
// 	variable i=0
// 	for(i=0; i<numpnts(sc_RawWaveNames); i+=1)
// 	    if (sc_RawRecord[i] == 1 || sc_RawPlot[i]==1)
// 	        wn = sc_RawWaveNames[i]
// 	        break
// 	    endif
// 	endfor

// 	if(strlen(wn)==0)
// 		wave sc_xdata, sc_CalcRecord, sc_CalcPlot
// 		wave /t sc_CalcWaveNames

// 		for(i=0; i<numpnts(sc_CalcWaveNames); i+=1)
// 		    if (sc_CalcRecord[i] == 1 || sc_CalcPlot[i]==1)
// 		        wn = sc_CalcWaveNames[i]
// 		        break
// 		    endif
// 		endfor
// 	endif

// 	wave w = $wn  // open reference
// 	Redimension /N=(numpnts(w)) sc_xdata
// 	CopyScales w, sc_xdata  // copy scaling
// 	sc_xdata = x  // set wave data equal to x scaling
// end

// function SaveWaves([msg,save_experiment,fastdac, wave_names])
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

// function sc_cleanVolatileMemory()
// 	// delete old waves, so only the newest 500 scans are stored in volatile memory
// 	nvar filenum
	
// 	variable cleandat = 0, i=0
// 	string deletelist="",waves=""
// 	if(filenum > 500)
// 		cleandat = filenum-500
// 		sprintf waves, "dat%d*", cleandat 
// 		deletelist = wavelist(waves,",","")
// 		for(i=0;i<itemsinlist(deletelist,",");i+=1)
// 			killwaves/z $stringfromlist(i,deletelist,",")
// 		endfor
// 	endif
// end

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
