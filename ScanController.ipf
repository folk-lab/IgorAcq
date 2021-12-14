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


////////////////////////////////
///////// utility functions //// (scu_...)
////////////////////////////////

function scu_assertSeparatorType(list_string, assert_separator)
	// If the list_string does not include <assert_separator> but does include the other common separator between "," and ";" then 
	// an error is raised
	string list_string, assert_separator
	if (strsearch(list_string, assert_separator, 0) < 0)  // Does not contain desired separator (maybe only one item)
		string buffer
		strswitch (assert_separator)
			case ",":
				if (strsearch(list_string, ";", 0) >= 0)
					sprintf buffer, "ERROR[scu_assertSeparatorType]: Expected separator = %s     Found separator = ;\r", assert_separator
					abort buffer
				endif
				break
			case ";":
				if (strsearch(list_string, ",", 0) >= 0)
					sprintf buffer, "ERROR[scu_assertSeparatorType]: Expected separator = %s     Found separator = ,\r", assert_separator
					abort buffer
				endif
				break
			default:
				if (strsearch(list_string, ",", 0) >= 0 || strsearch(list_string, ";", 0) >= 0)
					sprintf buffer, "ERROR[scu_assertSeparatorType]: Expected separator = %s     Found separator = , or ;\r", assert_separator
					abort buffer
				endif
				break
		endswitch		
	endif
end


function scu_unixTime()
	// returns the current unix time in seconds
	return DateTime - date2secs(1970,1,1) - date2secs(-1,-1,-1)
end


function roundNum(number,decimalplace) 
    // to return integers, decimalplace=0
	variable number, decimalplace
	variable multiplier
	multiplier = 10^decimalplace
	return round(number*multiplier)/multiplier
end


function AppendValue(thewave, thevalue)
    // Extend wave to add a value
	wave thewave
	variable thevalue
	Redimension /N=(numpnts(thewave)+1) thewave
	thewave[numpnts(thewave)-1] = thevalue
end


function AppendString(thewave, thestring)
    // Extendt text wave to add a value
	wave/t thewave
	string thestring
	Redimension /N=(numpnts(thewave)+1) thewave
	thewave[numpnts(thewave)-1] = thestring
end


function prompt_user(promptTitle,promptStr)
    // Popup a user prompt to enter a value
	string promptTitle, promptStr

	variable x=0
	prompt x, promptStr
	doprompt promptTitle, x
	if(v_flag == 0)
		return x
	else
		return nan
	endif
end


function ask_user(question, [type])
    // Popup a confirmation window to user and return answer value
	// type = 0,1,2 for (OK), (Yes/No), (Yes/No/Cancel) returns are V_flag = 1: Yes, 2: No, 3: Cancel
	string question
	variable type
	type = paramisdefault(type) ? 1 : type
	doalert type, question
	return V_flag
end


function/S scu_getDacLabel(channels, [fastdac])
  // Returns Label name of given channel, defaults to BD# or FD#
  // Used to get x_label, y_label for init_waves 
  // Note: Only takes channels as numbers
	string channels
	variable fastdac
	
	scu_assertSeparatorType(channels, ",")

	variable i=0
	string channel, buffer, xlabelfriendly = ""
	wave/t dacvalstr
	wave/t fdacvalstr
	for(i=0;i<ItemsInList(channels, ",");i+=1)
		channel = StringFromList(i, channels, ",")

		if (fastdac == 0)
			buffer = dacvalstr[str2num(channel)][3] // Grab name from dacvalstr
			if (cmpstr(buffer, "") == 0)
				buffer = "BD"+channel
			endif
		elseif (fastdac == 1)
			buffer = fdacvalstr[str2num(channel)][3] // Grab name from fdacvalstr
			if (cmpstr(buffer, "") == 0)
				buffer = "FD"+channel
			endif
		else
			abort "\"scu_getDacLabel\": Fastdac flag must be 0 or 1"
		endif

		if (cmpstr(xlabelfriendly, "") != 0)
			buffer = ", "+buffer
		endif
		xlabelfriendly += buffer
	endfor
	return xlabelfriendly + " (mV)"
end


function/s scu_getChannelNumbers(channels, [fastdac])
	// Returns channels as numbers string whether numbers or labels passed
	// Note: Returns "," separated list, because channels is quite often user entered
	string channels
	variable fastdac
	
	scu_assertSeparatorType(channels, ",")
	
	string new_channels = "", err_msg
	variable i = 0
	string ch
	if(fastdac == 1)
		wave/t fdacvalstr
		for(i=0;i<itemsinlist(channels, ",");i++)
			ch = stringfromlist(i, channels, ",")
			ch = removeLeadingWhitespace(ch)
			ch = removeTrailingWhiteSpace(ch)
			if(numtype(str2num(ch)) != 0)
				duplicate/o/free/t/r=[][3] fdacvalstr fdacnames
				findvalue/RMD=[][3]/TEXT=ch/TXOP=5 fdacnames
				if(V_Value == -1)  // Not found
					sprintf err_msg "ERROR[SF_get_channesl]:No FastDAC channel found with name %s", ch
					abort err_msg
				else  // Replace with DAC number
					ch = fdacvalstr[V_value][0]
				endif
			endif
			new_channels = addlistitem(ch, new_channels, ",", INF)
		endfor
	else  // Babydac
		wave/t dacvalstr
		for(i=0;i<itemsinlist(channels, ",");i++)
			ch = stringfromlist(i, channels, ",")
			ch = removeLeadingWhitespace(ch)
			ch = removeTrailingWhiteSpace(ch)
			if(numtype(str2num(ch)) != 0)
				duplicate/o/free/t/r=[][3] dacvalstr dacnames
				findvalue/RMD=[][3]/TEXT=ch/TXOP=0 dacnames
				if(V_Value == -1)  // Not found
					sprintf err_msg "ERROR[SF_get_channesl]:No BabyDAC channel found with name %s", ch
					abort err_msg
				else  // Replace with DAC number
					ch = dacvalstr[V_value][0]
				endif
			endif
			new_channels = addlistitem(ch, new_channels, ",", INF)
		endfor
	endif
	new_channels = new_channels[0,strlen(new_channels)-2]  // Remove ";" at end (BREAKS LIMIT CHECKING OTHERWISE)
	return new_channels
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
			scs_checksweepstate()
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

    // For 2D scans
    variable is2d
    string channelsy 
    variable starty, finy, numptsy, rampratey 
    variable delayy  // delay after each step in y-axis (e.g. settling time after x-axis has just been ramped from fin to start quickly)

    // For specific scans
    variable direction  // Allows controlling scan from start -> fin or fin -> start (with 1 or -1)
    variable duration   // Can specify duration of scan rather than numpts or sweeprate for readVsTime
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
    string adcList 
    string startxs, finxs  // If sweeping from different start/end points for each DAC channel
    string startys, finys  // Similar for Y-axis
	 string raw_wave_names  // Names of waves to override the names raw data is stored in for FastDAC scans
	 
	 // Backend used
	 variable never_save   // Set to 1 to make sure these ScanVars are never saved (e.g. if using to get throw away values for getting an ADC reading)
endstructure


function scv_setLastScanVars(S) 
	// Save the ScanVars to global waves so that they can be loaded later
	Struct ScanVars &S
	
	if (!S.never_save)
		variable st = S.start_time
		S.start_time = st == 0 ? datetime : S.start_time  // Temporarily make a start_time so at least something is saved in case of abort	 
		
		// Writing in chunks of 5 just to make it easier to count and keep track of them
		make/o/T sc_lastScanVarsStrings = {\
			S.channelsx, S.channelsy, S.x_label, S.y_label, S.comments,\
			S.adcList, S.startxs, S.finxs, S.startys, S.finys,\
			S.raw_wave_names\
			}
		make/o/d sc_lastScanVarsVariables = {\
			S.instrIDx, S.instrIDy, S.lims_checked, S.startx, S.finx, S.numptsx,\
		 	S.rampratex, S.delayx, S.is2d, S.starty, S.finy,\
		 	S.numptsy, S.rampratey, S.delayy, S.direction, S.duration,\
		 	S.readVsTime, S.start_time, S.end_time, S.using_fastdac, S.numADCs,\
		 	S.samplingFreq, S.measureFreq, S.sweeprate, S.never_save\
		 	}
		
		S.start_time = st  // Restore to whatever it was before	
	endif
end


function scv_getLastScanVars(S)   
	// Makde ScanVars from the global waves that are created when calling scv_setLastScanVars(S)
	Struct ScanVars &S
	// Note: can't just use StructPut/Get because they only work for numeric entries, not strings...
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
	S.instrIDx = v[0]
	S.instrIDy = v[1]
	S.lims_checked = v[2]
	S.startx = v[3]
	S.finx = v[4]
	S.numptsx = v[5]
	S.rampratex = v[6]
	S.delayx = v[7]
	S.is2d = v[8]
	S.starty = v[9]
	S.finy = v[10]
	S.numptsy = v[11]
	S.rampratey = v[12]
	S.delayy = v[13]
	S.direction = v[14]
	S.duration = v[15]
	S.readVsTime = v[16]
	S.start_time = v[17]
	S.end_time = v[18]
	S.using_fastdac = v[19]
	S.numADCs = v[20]
	S.samplingFreq = v[21]
	S.measureFreq = v[22]
	S.sweeprate = v[23]
	S.never_save = v[24]
end
	
function initScanVars(S, [instrIDx, startx, finx, channelsx, numptsx, delayx, rampratex, instrIDy, starty, finy, channelsy, numptsy, rampratey, delayy, x_label, y_label, startxs, finxs, startys, finys, comments])
    // Function to make setting up general values of scan vars easier
    // PARAMETERS:
    // startx, finx, starty, finy -- Single start/fin point for all channelsx/channelsy
    // startxs, finxs, startys, finys -- For passing in multiple start/fin points for each channel as a comma separated string instead of a single start/fin for all channels
    //		Note: Just pass anything for startx/finx if using startxs/finxs, they will be overwritten
    struct ScanVars &s
    variable instrIDx, instrIDy
    variable startx, finx, numptsx, delayx, rampratex
    variable starty, finy, numptsy, delayy, rampratey
    string channelsx
    string channelsy
    string x_label, y_label
	string startxs, finxs, startys, finys
    string comments
    
	// Handle Optional Strings
	x_label = selectString(paramIsDefault(x_label), x_label, "")
	channelsx = selectString(paramisdefault(channelsx), channelsx, "")

	y_label = selectString(paramIsDefault(y_label), y_label, "")
	channelsy = selectString(paramisdefault(channelsy), channelsy, "")

	startxs = selectString(paramisdefault(startxs), startxs, "")
	finxs = selectString(paramisdefault(finxs), finxs, "")
	startys = selectString(paramisdefault(startys), startys, "")
	finys = selectString(paramisdefault(finys), finys, "")

	comments = selectString(paramisdefault(comments), comments, "")


	S.instrIDx = instrIDx
	S.instrIDy = paramIsDefault(instrIDy) ? instrIDx : instrIDy  // For a second device controlling second axis of scan

	S.lims_checked = 0// Flag that gets set to 1 after checks on software limits/ramprates etc has been carried out (particularly important for fastdac scans which has no limit checking for the sweep)

	S.channelsx = channelsx
	S.startx = startx
	S.finx = finx 
	S.numptsx = numptsx
	S.rampratex = rampratex
	S.delayx = delayx  // delay after each step for Slow scans (has no effect for Fastdac scans)

	// For 2D scans
	S.is2d = numptsy > 0 ? 0 : 1
	S.channelsy = channelsy
	S.starty = starty 
	S.finy = finy
	S.numptsy = numptsy 
	S.rampratey = rampratey
	S.delayy = delayy // delay after each step in y-axis (e.g. settling time after x-axis has just been ramped from fin to start quickly)

	// For specific scans
	S.direction = 1 // Allows controlling scan from start -> fin or fin -> start (with 1 or -1)
	S.duration = NaN // Can specify duration of scan rather than numpts or sweeprate  
	S.readVsTime = 0 // Set to 1 if doing a readVsTime

	// Other useful info
	S.start_time = NaN // Should be recorded right before measurements begin (e.g. after all checks are carried out)  
	S.end_time = NaN // Should be recorded right after measurements end (e.g. before getting sweeplogs etc)  
	S.x_label = x_label // String to show as x_label of scan (otherwise defaults to gates that are being swept)
	S.y_label = y_label  // String to show as y_label of scan (for 2D this defaults to gates that are being swept)
	S.using_fastdac = 0 // Set to 1 when using fastdac
	S.comments = comments  // Additional comments to save in HDF sweeplogs (easy place to put keyword flags for later analysis)

	// Specific to Fastdac 
	S.numADCs = NaN  // How many ADCs are being recorded  
	S.samplingFreq = NaN  // 
	S.measureFreq = NaN  // measureFreq = samplingFreq/numADCs  
	S.sweeprate = NaN  // How fast to sweep in mV/s (easier to specify than numpts for fastdac scans)  
	S.adcList  = ""  //   
	S.startxs = startxs
	S.finxs = finxs  // If sweeping from different start/end points for each DAC channel
	S.startys = startys
	S.finys = finys  // Similar for Y-axis
	S.raw_wave_names = ""  // Names of waves to override the names raw data is stored in for FastDAC scans
	
	// Backend use
	S.never_save = 0  // Set to 1 to make sure these ScanVars are never saved (e.g. if using to get throw away values for getting an ADC reading)
end


function initScanVarsFD(S, instrID, startx, finx, [channelsx, numptsx, sweeprate, duration, rampratex, delayx, starty, finy, channelsy, numptsy, rampratey, delayy, startxs, finxs, startys, finys, x_label, y_label, comments])
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
	
	// Ensure optional strings aren't null
	channelsy = selectString(paramIsDefault(channelsy), channelsy, "")
	startys = selectString(paramIsDefault(startys), startys, "")
	finys = selectString(paramIsDefault(finys), finys, "")
	y_label = selectString(paramIsDefault(y_label), y_label, "")	

	channelsx = selectString(paramIsDefault(channelsx), channelsx, "")
	startxs = selectString(paramIsDefault(startxs), startxs, "")
	finxs = selectString(paramIsDefault(finxs), finxs, "")
	x_label = selectString(paramIsDefault(x_label), x_label, "")

	comments = selectString(paramIsDefault(comments), comments, "")

	// Standard initialization
	initScanVars(S, instrIDx=instrID, startx=startx, finx=finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
	instrIDy=instrID, starty=starty, finy=finy, channelsy=channelsy, numptsy=numptsy, rampratey=rampratey, delayy=delayy, \
	x_label=x_label, y_label=y_label, startxs=startxs, finxs=finxs, startys=startys, finys=finys, comments=comments)

	// Additional intialization for fastDAC scans
    S.adcList = scf_getRecordedADCinfo("channels")
    S.using_fastdac = 1

   	// Sets channelsx, channelsy to be lists of channel numbers instead of labels
    scv_setChannels(S, channelsx, channelsy, fastdac=1)
    
   	// Get Labels for graphs
   	S.x_label = selectString(strlen(x_label) > 0, scu_getDacLabel(S.channelsx, fastdac=1), x_label)  // Uses channels as list of numbers, and only if x_label not passed in
   	if (S.is2d)
   		S.y_label = selectString(strlen(y_label) > 0, scu_getDacLabel(S.channelsy, fastdac=1), y_label) 
   	else
   		S.y_label = y_label
   	endif  		

   	// Sets starts/fins in FD string format
    scv_setFDsetpoints(S, channelsx, startx, finx, channelsy, starty, finy, startxs, finxs, startys, finys)
	
	// Set variables with some calculation
    scv_setFreq(S) 		// Sets S.samplingFreq/measureFreq/numADCs	
    scv_setNumptsSweeprateDuration(S) 	// Checks that either numpts OR sweeprate OR duration was provided, and sets ScanVars accordingly
                                // Note: Valid for start/fin only (uses S.startx, S.finx NOT S.startxs, S.finxs)
end


function initScanVarsBD(S, instrID, startx, finx, [channelsx, numptsx, delayx, rampratex, starty, finy, channelsy, numptsy, rampratey, delayy, startxs, finxs, startys, finys, x_label, y_label, comments])
    // Function to make setting up scanVars struct easier for BabyDAC scans
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
    string x_label, y_label
    string startxs, finxs, startys, finys
    string comments
    
	// Ensure optional strings aren't null
	channelsy = selectString(paramIsDefault(channelsy), channelsy, "")
	startys = selectString(paramIsDefault(startys), startys, "")
	finys = selectString(paramIsDefault(finys), finys, "")
	y_label = selectString(paramIsDefault(y_label), y_label, "")	

	channelsx = selectString(paramIsDefault(channelsx), channelsx, "")
	startxs = selectString(paramIsDefault(startxs), startxs, "")
	finxs = selectString(paramIsDefault(finxs), finxs, "")
	x_label = selectString(paramIsDefault(x_label), x_label, "")

	comments = selectString(paramIsDefault(comments), comments, "")

	// Standard initialization
	initScanVars(S, instrIDx=instrID, startx=startx, finx=finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex, \
	instrIDy=instrID, starty=starty, finy=finy, channelsy=channelsy, numptsy=numptsy, rampratey=rampratey, delayy=delayy, \
	x_label=x_label, y_label=y_label, startxs=startxs, finxs=finxs, startys=startys, finys=finys, comments=comments)
    
	// Additional initialization for BabyDAC scans
    scv_setChannels(S, channelsx, channelsy, fastdac=0) // Sets channelsx, channelsy to lists of numbers instead of labels
    
   	// Get Labels for graphs
   	S.x_label = selectString(strlen(x_label) > 0, scu_getDacLabel(S.channelsx, fastdac=0), x_label)  // Uses channels as list of numbers, and only if x_label not passed in
   	if (S.is2d && strlen(y_label) == 0)
	   	S.y_label = selectString(strlen(y_label) > 0, scu_getDacLabel(S.channelsy, fastdac=0), y_label) 
	else
		S.y_label = y_label
	endif
end


function scv_setNumptsSweeprateDuration(S)
	// Set all of S.numptsx, S.sweeprate, S.duration based on whichever of those is provided
	Struct ScanVars &S
	 // If NaN then set to zero so rest of logic works
   if(numtype(S.sweeprate) == 2)
   		S.sweeprate = 0
   	endif
   
   S.numptsx = numtype(S.numptsx) == 0 ? S.numptsx : 0
   S.sweeprate = numtype(S.sweeprate) == 0 ? S.sweeprate : 0
   S.duration = numtype(S.duration) == 0 ? S.duration : 0      
   
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
		S.numptsx = round(S.measureFreq*S.duration)
		S.sweeprate = fd_get_sweeprate_from_numpts(S.startx, S.finx, S.numptsx, S.measureFreq)
		if (numtype(S.sweeprate) != 0)  // TODO: Is this the right check? (For a start=fin=0 scan)
			S.sweeprate = NaN
		endif
   endif
end


function scv_setFreq(S)
	// Set S.samplingFreq, S.numADCs, S.measureFreq
	Struct ScanVars &S
   S.samplingFreq = getfadcSpeed(S.instrIDx)
   S.numADCs = scf_getNumRecordedADCs()
   S.measureFreq = S.samplingFreq/S.numADCs  //Because sampling is split between number of ADCs being read //TODO: This needs to be adapted for multiple FastDacs
end


function scv_setChannels (S, channelsx, channelsy, [fastdac])
    // Set S.channelsx and S.channelys converting channel labels to numbers where necessary
    struct ScanVars &S
    string channelsx, channelsy
    variable fastdac

    s.channelsx = scu_getChannelNumbers(channelsx, fastdac=fastdac)

	if (numtype(strlen(channelsy)) != 0 || strlen(channelsy) == 0)  // No Y set at all
		s.channelsy = ""
	else
		s.channelsy = scu_getChannelNumbers(channelsy, fastdac=fastdac)
    endif
end


function scv_setFDsetpoints(S, channelsx, startx, finx, channelsy, starty, finy, startxs, finxs, startys, finys)

    struct ScanVars &S
    variable startx, finx, starty, finy
    string channelsx, startxs, finxs, channelsy, startys, finys

	string starts, fins  // Strings to modify in format_setpoints
    // Set X
   	if ((numtype(strlen(startxs)) != 0 || strlen(startxs) == 0) && (numtype(strlen(finxs)) != 0 || strlen(finxs) == 0))  // Then just a single start/end for channelsx
   		s.startx = startx
		s.finx = finx	
        scv_formatSetpointsFD(startx, finx, S.channelsx, starts, fins)  // Modifies starts, fins
		s.startxs = starts
		s.finxs = fins
	elseif (!(numtype(strlen(startxs)) != 0 || strlen(startxs) == 0) && !(numtype(strlen(finxs)) != 0 || strlen(finxs) == 0))
		scv_sanitizeSetpointsFD(startxs, finxs, S.channelsx, starts, fins)  // Modifies starts, fins
		s.startx = str2num(StringFromList(0, starts, ","))
		s.finx = str2num(StringFromList(0, fins, ","))
		s.startxs = starts
		s.finxs = fins
	else
		abort "If either of startxs/finxs is provided, both must be provided"
	endif

    // If 2D then set Y
    if (S.is2d) 
        if (strlen(startys) == 0 && strlen(finys) == 0)  // Single start/end for Y
            s.starty = starty
            s.finy = finy	
            scv_formatSetpointsFD(S.starty, S.finy, S.channelsy, starts, fins)  
            s.startys = starts
            s.finys = fins
        elseif (!(numtype(strlen(startys)) != 0 || strlen(startys) == 0) && !(numtype(strlen(finys)) != 0 || strlen(finys) == 0)) // Multiple start/end for Ys
            scv_sanitizeSetpointsFD(startys, finys, S.channelsy, starts, fins)
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


function scv_sanitizeSetpointsFD(start_list, fin_list, channels, starts, fins)
	// Makes sure starts/fins make sense for number of channels and have no bad formatting
	// Modifies the starts/fins strings passed in
	string start_list, fin_list, channels
	string &starts, &fins
	
	string buffer
	
	scu_assertSeparatorType(channels, ",")  // "," because quite often user entered
	scu_assertSeparatorType(start_list, ",")  // "," because entered by user
	scu_assertSeparatorType(fin_list, ",")	// "," because entered by user
	
	if (itemsinlist(channels, ",") != itemsinlist(start_list, ",") || itemsinlist(channels, ",") != itemsinlist(fin_list, ","))
		sprintf buffer, "ERROR[scv_sanitizeSetpointsFD]: length of start_list/fin_list/channels not equal!!! start_list:(%s), fin_list:(%s), channels:(%s)\r", start_list, fin_list, channels
		abort buffer
	endif
	
	starts = replaceString(" ", start_list, "")
	fins = replaceString(" ", fin_list, "")
end


function scv_formatSetpointsFD(start, fin, channels, starts, fins)
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
    sci_initializeWaves(S)

    // Set up graphs to display recorded data
    string activeGraphs
    activeGraphs = scg_initializeGraphs(S)
    scg_arrangeWindows(activeGraphs)

    // Open Abort window
    scg_openAbortWindow()

    // Save struct to globals
    scv_setLastScanVars(S)
end


function sci_initializeWaves(S)  // TODO: rename
    // Initializes the waves necessary for recording scan
	//  Need 1D and 2D waves for the raw data coming from the fastdac (2D for storing, not necessarily displaying)
	// 	Need 2D waves for either the raw data, or filtered data if a filter is set
	//		(If a filter is set, the raw waves should only ever be plotted 1D)
	//		(This will be after calc (i.e. don't need before and after calc wave))
    struct ScanVars &S
    variable fastdac

    variable numpts  // Numpts to initialize wave with, note: for Filtered data, this number is reduced
    string wavenames, wn
    variable raw, j
    for (raw = 0; raw<2; raw++) // (raw = 0 means calc waves)
        wavenames = sci_get1DWaveNames(raw, S.using_fastdac)
        sci_sanityCheckWavenames(wavenames)
        if (S.using_fastdac)
	        numpts = (raw) ? S.numptsx : scfd_postFilterNumpts(S.numptsx, S.measureFreq)  
	     else
	     	numpts = S.numptsx
	     endif
        for (j=0; j<itemsinlist(wavenames);j++)
            wn = stringFromList(j, wavenames)
            sci_init1DWave(wn, numpts, S.startx, S.finx)
            if (S.is2d == 1)
                sci_init2DWave(wn+"_2d", numpts, S.startx, S.finx, S.numptsy, S.starty, S.finy)
            endif
        endfor
    endfor

	// Setup Async measurements if not doing a fastdac scan (workers will look for data made here)
	if (!S.using_fastdac) 
		sc_findAsyncMeasurements()
	endif
end


function sci_init1DWave(wn, numpts, start, fin)
    // Overwrites waveName with scaled wave from start to fin with numpts
    string wn
    variable numpts, start, fin
    string cmd
    
    if (numtype(numpts) != 0 || numpts==0)
		sprintf cmd "ERROR[sci_init1DWave]: Invalid numpts for wn = %s. numpts either 0 or NaN", wn
    	abort cmd
    elseif (numtype(start) != 0 || numtype(fin) != 0)
    	sprintf cmd "ERROR[sci_init1DWave]: Invalid range passed for wn = %s. numtype(start) = %d, numtype(fin) = %d" wn, numtype(start), numtype(fin)
    elseif (start == fin)
	   	sprintf cmd "ERROR[sci_init1DWave]: Invalid range passed for wn = %s. start = %.3f, fin = %.3f", wn, start, fin
	   	abort cmd
   endif
    
    make/O/n=(numpts) $wn = NaN  
    cmd = "setscale/I x " + num2str(start) + ", " + num2str(fin) + ", " + wn; execute(cmd)
end


function sci_init2DWave(wn, numptsx, startx, finx, numptsy, starty, finy)
    // Overwrites waveName with scaled wave from start to fin with numpts
    string wn
    variable numptsx, startx, finx, numptsy, starty, finy
    string cmd
    
    if (numtype(numptsx) != 0 || numptsx == 0)
		sprintf cmd "ERROR[sci_init1DWave]: Invalid numptsx for wn = %s. numptsx either 0 or NaN", wn
    	abort cmd
    elseif (numtype(numptsy) != 0 || numptsy == 0)
		sprintf cmd "ERROR[sci_init1DWave]: Invalid numptsy for wn = %s. numptsy either 0 or NaN", wn
    	abort cmd    	
    elseif (numtype(startx) != 0 || numtype(finx) != 0 || numtype(starty) != 0 || numtype(finy) != 0)
    	sprintf cmd "ERROR[sci_init2DWave]: Invalid range passed for wn = %s. numtype(startx) = %d, numtype(finx) = %d, numtype(starty) = %d, numtype(finy) = %d" wn, numtype(startx), numtype(finx), numtype(starty), numtype(finy)
    	abort cmd
    elseif (startx == finx || starty == finy)
	   	sprintf cmd "ERROR[sci_init2DWave]: Invalid range passed for wn = %s. startx = %.3f, finx = %.3f, starty = %.3f, finy = %.3f", wn, startx, finx, starty, finy
	   	abort cmd
   endif
    
    make/O/n=(numptsx, numptsy) $wn = NaN  // TODO: can put in a cmd and execute if necessary
    cmd = "setscale/I x " + num2str(startx) + ", " + num2str(finx) + ", " + wn; execute(cmd)
	cmd = "setscale/I y " + num2str(starty) + ", " + num2str(finy) + ", " + wn; execute(cmd)
end


function/S sci_get1DWaveNames(raw, fastdac)
    // Return a list of Raw or Calc wavenames (without any checks)
    variable raw, fastdac  // 1 for True, 0 for False
    
    string wavenames = ""
	if (fastdac == 1)
		if (raw == 1)
			wavenames = scf_getRecordedADCinfo("raw_names")
		else
			wavenames = scf_getRecordedADCinfo("calc_names")
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


function/S sci_get2DWaveNames(raw, fastdac)
    // Return a list of Raw or Calc wavenames (without any checks)
    variable raw, fastdac  // 1 for True, 0 for False
    string waveNames1D = sci_get1DWaveNames(raw, fastdac)
    string waveNames2D = ""
    variable i
    for (i = 0; i<ItemsInList(waveNames1D); i++)
        waveNames2D = addlistItem(StringFromList(i, waveNames1D)+"_2d", waveNames2D, ";", INF)
    endfor
    return waveNames2D
end


function sci_sanityCheckWavenames(wavenames)
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
//////////////////////////// Opening and Layout out Graphs //////////////////// (scg_...)
/////////////////////////////////////////////////////////////////////////////

function/S scg_initializeGraphs(S)
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
        waveNames = sci_get1DWaveNames(raw, S.using_fastdac)
		if (S.is2d == 0 && raw == 1 && S.using_fastdac)
			ylabel = "ADC /mV"
		else
			ylabel = S.y_label
		endif
        buffer = scg_initializeGraphsForWavenames(waveNames, S.x_label, is2d=S.is2d, y_label=ylabel)
        if(raw==1) // Raw waves
	        sc_rawGraphs1D = buffer
        endif
        graphIDs = graphIDs + buffer
    endfor
    return graphIDs
end


function/S scg_initializeGraphsForWavenames(wavenames, x_label, [is2d, y_label])
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
	    openGraphID = scg_graphExistsForWavename(wn)
	    if (cmpstr(openGraphID, "")) // Graph is already open (str != "")
	        scg_setupGraph1D(openGraphID, x_label, y_label=y_label_1d)  
	    else 
	        scg_open1Dgraph(wn, x_label, y_label=y_label, y_label=y_label_1d)
	        openGraphID = winname(0,1)
	    endif
       graphIDs = addlistItem(openGraphID, graphIDs, ";", INF)


	    if (is2d)
	        wn = wn+"_2d"
	        openGraphID = scg_graphExistsForWavename(wn)
	        if (cmpstr(openGraphID, "")) // Graph is already open (str != "")
	            scg_setupGraph2D(openGraphID, wn, x_label, y_label_2d)
	        else 
	            scg_open2Dgraph(wn, x_label, y_label_2d)
	            openGraphID = winname(0,1)
	        endif
           graphIDs = addlistItem(openGraphID, graphIDs, ";", INF)
	    endif
	endfor
	return graphIDs
end


function scg_arrangeWindows(graphIDs)
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


function/S scg_graphExistsForWavename(wn)
    // Checks if a graph is open containing wn, if so returns the graphTitle otherwise returns ""
    string wn
    string graphTitles = scg_getOpenGraphTitles() 
    string graphIDs = scg_getOpenGraphIDs()
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


function scg_open1Dgraph(wn, x_label, [y_label])
    // Opens 1D graph for wn
    string wn, x_label, y_label
    
    y_label = selectString(paramIsDefault(y_label), y_label, "")
    
    display $wn
    setWindow kwTopWin, graphicsTech=0
    
    scg_setupGraph1D(WinName(0,1), x_label, y_label=y_label)
end


function scg_open2Dgraph(wn, x_label, y_label)
    // Opens 2D graph for wn
    string wn, x_label, y_label
    wave w = $wn
    if (dimsize(w, 1) == 0)
    	abort "Trying to open a 2D graph for a 1D wave"
    endif
    
    display
    setwindow kwTopWin, graphicsTech=0
    appendimage $wn
    scg_setupGraph2D(WinName(0,1), wn, x_label, y_label)
end


function scg_setupGraph1D(graphID, x_label, [y_label])
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


function scg_setupGraph2D(graphID, wn, x_label, y_label)
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


function/S scg_getOpenGraphTitles()
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

function/S scg_getOpenGraphIDs()
	// GraphID == name before the ":" in graph window names
	// e.g. "Graph1:testwave" -> "Graph1"
	// Returns a list of GraphIDs
	// Use these to specify graph with /W=<graphID>
	string graphlist = winlist("*",";","WIN:1")
	return graphlist
end


function scg_openAbortWindow()
    // Opens the window which allows for pausing/aborting/abort+saving a scan
    variable/g sc_abortsweep=0, sc_pause=0, sc_abortnosave=0 // Make sure these are initialized
    doWindow/k/z SweepControl  // Attempt to close previously open window just in case
    execute("scs_abortmeasurementwindow()")
    doWindow/F SweepControl   // Bring Sweepcontrol to the front 
end


function scg_updateRawGraphs()
  // updates activegraphs which takes about 15ms
  // ONLY update 1D graphs for speed (if this takes too long, the buffer will overflow)
  svar sc_rawGraphs1D

  variable i
  for(i=0;i<itemsinlist(sc_rawGraphs1D,";");i+=1)
    doupdate/w=$stringfromlist(i,sc_rawGraphs1D,";")
  endfor
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
///// Sweep controls   ///// scs_... (ScanControlSweep...)
////////////////////////////
window scs_abortmeasurementwindow() : Panel
	//Silent 1 // building window
	NewPanel /W=(500,700,870,750) /N=SweepControl// window size
	ModifyPanel frameStyle=2
	ModifyPanel fixedSize=1
	SetDrawLayer UserBack
	Button scs_pausesweep, pos={10,15},size={110,20},proc=scs_pausesweep,title="Pause"
	Button scs_stopsweep, pos={130,15},size={110,20},proc=scs_stopsweep,title="Abort and Save"
	Button scs_stopsweepnosave, pos={250,15},size={110,20},proc=scs_stopsweep,title="Abort"
	DoUpdate /W=SweepControl /E=1
endmacro


function scs_stopsweep(action) : Buttoncontrol
	string action
	nvar sc_abortsweep,sc_abortnosave

	strswitch(action)
		case "scs_stopsweep":
			sc_abortsweep = 1
			print "[SCAN] Scan will abort and the incomplete dataset will be saved."
			break
		case "scs_stopsweepnosave":
			sc_abortnosave = 1
			print "[SCAN] Scan will abort and dataset will not be saved."
			break
	endswitch
end


function scs_pausesweep(action) : Buttoncontrol
	string action
	nvar sc_pause, sc_abortsweep

	Button scs_pausesweep,proc=scs_resumesweep,title="Resume"
	sc_pause=1
	print "[SCAN] Scan paused by user."
end


function scs_resumesweep(action) : Buttoncontrol
	string action
	nvar sc_pause

	Button scs_pausesweep,proc=scs_pausesweep,title="Pause"
	sc_pause = 0
	print "Sweep resumed"
end


function scs_checksweepstate()
	nvar /Z sc_abortsweep, sc_pause, sc_abortnosave
	
	if(NVAR_Exists(sc_abortsweep) && sc_abortsweep==1)
		// If the Abort button is pressed during the scan, save existing data and stop the scan.
		dowindow /k SweepControl
		sc_abortsweep=0
		sc_abortnosave=0
		sc_pause=0
		EndScan(save_experiment=0, aborting=1) 				
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
				dowindow /k SweepControl
				sc_abortsweep=0
				sc_abortnosave=0
				sc_pause=0
				EndScan(save_experiment=0, aborting=1) 				
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



///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////// ASYNC handling ///////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Note: Slow ScanContoller ONLY

function sc_ManageThreads(innerIndex, outerIndex, readvstime, is2d, start_time)
	variable innerIndex, outerIndex, readvstime
	variable is2d, start_time
	svar sc_asyncFolders
	nvar sc_numAvailThreads, sc_numInstrThreads
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
																 StringFromList(i, sc_asyncFolders, ";"), is2d, \
																 readvstime, start_time)
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
			funcref sc_funcAsync func = $(StringFromList(i, queryFunc, ";"))
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


threadsafe function sc_funcAsync(instrID)  // Reference functions for all *_async functions
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
/////////////////////////  Data/Experiment Saving   //////////////////////////////////////////////////////// (sce_...) ScanControllerEnd...
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
	
	save_experiment = paramisDefault(save_experiment) ? 1 : save_experiment
	additional_wavenames = SelectString(ParamIsDefault(additional_wavenames), additional_wavenames, "")
	
	nvar filenum
	variable current_filenum = filenum  // Because filenum gets incremented in SaveToHDF (to avoid clashing filenums when Igor crashes during saving)
	if(!paramIsDefault(S))
		scv_setLastScanVars(S)  // I.e save the ScanVars including end_time and any other changed values in case saving fails (which it often does)
	endif
	
	Struct ScanVars S_ // Note: This will definitely exist for the rest of this function
	scv_getLastScanVars(S_)
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
	sce_saveFuncCall(getrtstackinfo(2))
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


function sce_saveFuncCall(funcname)
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


////////////////////////////////////////////////////////////////
///////////////// Slow ScanController ONLY ////////////////////  scw_... (ScanControlWindow...)
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
			scw_loadConfig(StringFromList(0,filelist, ";"))
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
		scw_loadConfig(configFile)
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

	scw_rebuildwindow()
end


function scw_rebuildwindow()
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
		cmd="CheckBox sc_RawRecordCheckBox" + num2istr(i) + ", proc=scw_CheckboxClicked, pos={150,40+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_RawRecord[i]) + " , title=\"\""
		execute(cmd)
		cmd="CheckBox sc_RawPlotCheckBox" + num2istr(i) + ", proc=scw_CheckboxClicked, pos={210,40+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_RawPlot[i]) + " , title=\"\""
		execute(cmd)
		cmd="CheckBox sc_AsyncCheckBox" + num2istr(i) + ", proc=scw_CheckboxClicked, pos={270,40+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_measAsync[i]) + " , title=\"\""
		execute(cmd)
		cmd="SetVariable sc_rawScriptBox" + num2istr(i) + " pos={320, 37+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={340, 0}, fsize=14, title=\" \", value=sc_rawScripts[i]"
		execute(cmd)
		i+=1
	while (i<numpnts( sc_RawWaveNames ))
	i+=1
	button addrowraw,pos={550,i*(sc_InnerBoxH + sc_InnerBoxSpacing)},size={110,20},proc=scw_addrow,title="Add Row"
	button removerowraw,pos={430,i*(sc_InnerBoxH + sc_InnerBoxSpacing)},size={110,20},proc=scw_removerow,title="Remove Row"
	checkbox sc_PrintRawBox, pos={300,i*(sc_InnerBoxH + sc_InnerBoxSpacing)}, proc=scw_CheckboxClicked, value=sc_PrintRaw,side=1,title="\Z14Print filenames"
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
		cmd="CheckBox sc_CalcRecordCheckBox" + num2istr(i) + ", proc=scw_CheckboxClicked, pos={150,95+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_CalcRecord[i]) + " , title=\"\""
		execute(cmd)
		cmd="CheckBox sc_CalcPlotCheckBox" + num2istr(i) + ", proc=scw_CheckboxClicked, pos={210,95+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_CalcPlot[i]) + " , title=\"\""
		execute(cmd)
		cmd="SetVariable sc_CalcScriptBox" + num2istr(i) + " pos={320, 92+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={340, 0}, fsize=14, title=\" \", value=sc_CalcScripts[i]"
		execute(cmd)
		i+=1
	while (i<numpnts( sc_CalcWaveNames ))
	button addrowcalc,pos={550,89+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)},size={110,20},proc=scw_addrow,title="Add Row"
	button removerowcalc,pos={430,89+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)},size={110,20},proc=scw_removerow,title="Remove Row"
	checkbox sc_PrintCalcBox, pos={300,89+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)}, proc=scw_CheckboxClicked, value=sc_PrintCalc,side=1,title="\Z14Print filenames"

	// box for instrument configuration
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 13,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+20,"Connect Instrument"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 225,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+20,"Open GUI"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 440,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+20,"Log Status"
	ListBox sc_Instr,pos={9,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+25},size={sc_InnerBoxW,(sc_InnerBoxH+sc_InnerBoxSpacing)*3},fsize=14,frame=2,listWave=root:sc_Instr,selWave=root:instrBoxAttr,mode=1, editStyle=1

	// buttons
	button connect, pos={10,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+3)*(sc_InnerBoxH+sc_InnerBoxSpacing)+30},size={120,20},proc=scw_OpenInstrButton,title="Connect Instr"
	button gui, pos={140,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+3)*(sc_InnerBoxH+sc_InnerBoxSpacing)+30},size={120,20},proc=scw_OpenGUIButton,title="Open All GUI"
	button killabout, pos={270,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+3)*(sc_InnerBoxH+sc_InnerBoxSpacing)+30},size={140,20},proc=sc_controlwindows,title="Kill Sweep Controls"
	button killgraphs, pos={420,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+3)*(sc_InnerBoxH+sc_InnerBoxSpacing)+30},size={120,20},proc=scw_killgraphs,title="Close All Graphs"
	button updatebutton, pos={550,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+3)*(sc_InnerBoxH+sc_InnerBoxSpacing)+30},size={110,20},proc=scw_updatewindow,title="Update"

// helpful text
	DrawText 13,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+3)*(sc_InnerBoxH+sc_InnerBoxSpacing)+70,"Press Update to save changes."

EndMacro


function scw_OpenInstrButton(action) : Buttoncontrol
	string action
	sc_openInstrConnections(1)
end


function scw_OpenGUIButton(action) : Buttoncontrol
	string action
	sc_openInstrGUIs(1)
end


function scw_killgraphs(action) : Buttoncontrol
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


function scw_updatewindow(action) : ButtonControl
	string action

	scw_saveConfig(scw_createConfig())   // write a new config file
end


function scw_addrow(action) : ButtonControl
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
	scw_rebuildwindow()
end

function scw_removerow(action) : Buttoncontrol
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
	scw_rebuildwindow()
end

// Update after checkbox clicked
function scw_CheckboxClicked(ControlName, Value)
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


function/s scw_createConfig()
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


function scw_saveConfig(configstr)
	string configstr
	svar sc_current_config

	string filename = "sc" + num2istr(scu_unixTime()) + ".json"
	writetofile(prettyJSONfmt(configstr), filename, "config")
	sc_current_config = filename
end


function scw_loadConfig(configfile)
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
	scw_rebuildwindow()
end


////////////////////////////////////////////
/// Slow ScanController Recording Data /////
////////////////////////////////////////////
function RecordValues(S, i, j, [fillnan])  
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
		abort "ERROR[RecordValues]: Not valid to readvstime in 2D"
	endif

	//// Setup and run async data collection ////
	wave sc_measAsync
	if( (sum(sc_measAsync) > 1) && (fillnan==0))
		variable tgID = sc_ManageThreads(innerindex, outerindex, S.readvstime, S.is2d, S.start_time) // start threads, wait, collect data
		sc_KillThreads(tgID) // Terminate threads
	endif

	//// Run sync data collection (or fill with NaNs) ////
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	wave/t sc_RawWaveNames, sc_RawScripts, sc_CalcWaveNames, sc_CalcScripts
	variable /g sc_tmpVal  // Used when evaluating measurement scripts from ScanController window
	string script = "", cmd = ""
	ii=0
	do // TODO: Ideally rewrite this to use sci_get1DWaveNames() but need to be careful about only updating sc_measAsync == 0 ones here...
		if ((sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1) && sc_measAsync[ii]==0)
			wave wref1d = $sc_RawWaveNames[ii]

			// Redimension waves if readvstime is set to 1
			if (S.readVsTime == 1)
				redimension /n=(innerindex+1) wref1d
				S.numptsx = innerindex+1  // So that x_array etc will be saved correctly later
				wref1d[innerindex] = NaN  // Prevents graph updating with a zero
				setscale/I x 0,  datetime - S.start_time, wref1d
				S.finx = datetime - S.start_time 	// So that x_array etc will be saved correctly later
				scv_setLastScanVars(S)
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
				wave wref2d = $sc_RawWaveNames[ii] + "_2d"
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
				wave wref2d = $sc_CalcWaveNames[ii] + "_2d"
				wref2d[innerindex][outerindex] = wref1d[innerindex]
			endif
		endif
		ii+=1
	while (ii < numpnts(sc_CalcWaveNames))

	S.end_time = datetime // Updates each loop

	// check abort/pause status
	nvar sc_abortsweep, sc_pause, sc_scanstarttime
	try
		scs_checksweepstate()
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
////////////////////////////// Pre Scan Checks /////////////////////////////////////////////////////////////// scc_... (ScanControlChecks...)
/////////////////////////////////////////////////////////////////////////////////////////////////////////////
function PreScanChecksFD(S, [x_only, y_only])
   struct ScanVars &S
   variable x_only, y_only  // Whether to only check specific axis (e.g. if other axis is a babydac or something else)
   
	scc_checkSameDeviceFD(S) 	// Checks DACs and ADCs are on same device
	scc_checkRampratesFD(S)	 	// Check ramprates of x and y
	scc_checkLimsFD(S)			// Check within software lims for x and y
	S.lims_checked = 1  		// So record_values knows that limits have been checked!
end


function PreScanChecksBD(S, [x_only, y_only])
  struct ScanVars &S
  variable x_only, y_only
//	SFbd_check_ramprates(S)	 	// Check ramprates of x and y
	scc_checkLimsBD(S, x_only=x_only, y_only=y_only)			// Check within software lims for x and y
	S.lims_checked = 1  		// So record_values knows that limits have been checked!
end


function PreScanChecksKeithley(S, [x_only, y_only])
	struct ScanVars &S
	variable x_only, y_only // Whether to only check specific axis (e.g. if other axis is a babydac or something else)
	print "WARNING[PreScanChecksKeithley]: Currently no checks performed on Keithley scans"
	S.lims_checked = 1  // So record_values knows that limits have been checked!
end


function SetCheckAWG(AWG, S)
	struct AWGVars &AWG
	struct ScanVars &S

	
	// Set numptsx in Scan s.t. it is a whole number of full cycles
	AWG.numSteps = round(S.numptsx/(AWG.waveLen*AWG.numCycles))  
	S.numptsx = (AWG.numSteps*AWG.waveLen*AWG.numCycles)
	
	// Check AWG for clashes/exceeding lims etc
	CheckAWG(AWG, S)	
	AWG.use_AWG = 1
	
	// Save numSteps in AWG_list for sweeplogs later
	fd_setGlobalAWG(AWG)
end


function RampStartFD(S, [ignore_lims, x_only, y_only])
	// move DAC channels to starting point
	struct ScanVars &S
	variable ignore_lims, x_only, y_only



	variable i, setpoint
	// If x exists ramp them to start
	if(numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0 && y_only != 1)  // If not NaN and not ""
		for(i=0;i<itemsinlist(S.channelsx,",");i+=1)
			if(S.direction == 1)
				setpoint = str2num(stringfromlist(i,S.startxs,","))
			elseif(S.direction == -1)
				setpoint = str2num(stringfromlist(i,S.finxs,","))
			else
				abort "ERROR[RampStartFD]: S.direction not set to 1 or -1"
			endif
			rampMultipleFDAC(S.instrIDx,stringfromlist(i,S.channelsx,","),setpoint,ramprate=S.rampratex, ignore_lims=ignore_lims)
		endfor
	endif  
	
	// If y exists ramp them to start
	if(numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0 && x_only != 1)  // If not NaN and not "" and not x only
		scu_assertSeparatorType(S.channelsy, ",")
		for(i=0;i<itemsinlist(S.channelsy,",");i+=1)
			rampMultipleFDAC(S.instrIDy,stringfromlist(i,S.channelsy,","),str2num(stringfromlist(i,S.startys,",")),ramprate=S.rampratey, ignore_lims=ignore_lims)
		endfor
	endif
  
end

function scc_checkRampStartFD(S)
	// Checks that DACs are at the start of the ramp. If not it will ramp there and wait the delay time, but
	// will give the user a WARNING that this should have been done already in the top level scan function
	// Note: This only works for a single fastdac sweeping at once
   struct ScanVars &S
	scu_assertSeparatorType(S.channelsx, ",")
   variable i=0, require_ramp = 0, ch, sp, diff
   for(i=0;i<itemsinlist(S.channelsx);i++)
      ch = str2num(stringfromlist(i, S.channelsx, ","))
      if(S.direction == 1)
	      sp = str2num(stringfromlist(i, S.startxs, ","))
	   elseif(S.direction == -1)
	      sp = str2num(stringfromlist(i, S.finxs, ","))
	   endif
      diff = getFDACOutput(S.instrIDx, ch)-sp
      if(abs(diff) > 0.5)  // if DAC is more than 0.5mV from start of ramp
         require_ramp = 1
      endif
   endfor

   if(require_ramp == 1)
      print "WARNING[scc_checkRampStartFD]: At least one DAC was not at start point, it has been ramped and slept for delayx, but this should be done in top level scan function!"
      RampStartFD(S, ignore_lims = 1, x_only=1)
      sc_sleep(S.delayy) // Settle time for 2D sweeps
   endif
end

function scc_checkRampratesFD(S)
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
		scu_assertSeparatorType(S.channelsx, ",")
		for(i=0;i<itemsinlist(S.channelsx,",");i+=1)
			eff_ramprate = abs(str2num(stringfromlist(i,S.startxs,","))-str2num(stringfromlist(i,S.finxs,",")))*(S.measureFreq/S.numptsx)
			channel = str2num(stringfromlist(i, S.channelsx, ","))
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
		scu_assertSeparatorType(S.channelsy, ",")
		for(i=0;i<itemsinlist(S.channelsy,",");i+=1)
			channel = str2num(stringfromlist(i, S.channelsy, ","))
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


function scc_checkLimsFD(S)
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
		abort "ERROR[scc_checkLimsFD]: Channels list contains ',,' which means something has gone wrong and limit checking WONT WORK!!"
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


function scc_checkSameDeviceFD(S, [x_only, y_only])
	// Checks all rampChs and ADCs (selected in fd_scancontroller window)
	// are on the same device. 
	struct ScanVars &s
	variable x_only, y_only // whether to check only one axis (e.g. other is babydac)
	
	variable device_dacs
	variable device_buffer
	string channels
	if (!y_only)
		channels = scf_getChannelNumsOnFD(S.channelsx, device_dacs)  // Throws error if not all channels on one FastDAC
	endif
	if (!x_only)
		channels = scf_getChannelNumsOnFD(S.channelsy, device_buffer)
		if (device_dacs > 0 && device_buffer > 0 && device_buffer != device_dacs)
			abort "ERROR[scc_checkSameDeviceFD]: X channels and Y channels are not on same device"  // TODO: Maybe this should raise an error?
		elseif (device_dacs <= 0 && device_buffer > 0)
			device_dacs = device_buffer
		endif
	endif

	channels = scf_getChannelNumsOnFD(s.AdcList, device_buffer, adc=1)  // Raises error if ADCs aren't on same device
	if (device_dacs > 0 && device_buffer != device_dacs)
		abort "ERROR[scc_checkSameDeviceFD]: ADCs are not on the same device as DACs"  // TODO: Maybe should only raise error if x channels not on same device as ADCs?
	endif	
	return device_buffer // Return adc device number
end





function scc_checkLimsBD(S, [x_only, y_only])
	// check that start and end values are within software limits
   struct ScanVars &S
   variable x_only, y_only  // Whether to only check one axis (e.g. other is a fastdac)
	
	// Make single list out of X's and Y's (checking if each exists first)
	string all_channels = "", outputs = ""
	if(!y_only && numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0)  // If not NaN and not ""
		scu_assertSeparatorType(S.channelsx, ",")
		all_channels = addlistitem(S.channelsx, all_channels, "|")
		outputs = addlistitem(num2str(S.startx), outputs, ",")
		outputs = addlistitem(num2str(S.finx), outputs, ",")
	endif

	if(!x_only && numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0)  // If not NaN and not ""
		scu_assertSeparatorType(S.channelsy, ",")
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
		for(j=0;j<itemsinlist(channels, ",");j++)			// each channel from channelsx/channelsy
			channel = str2num(stringfromlist(j, channels, ","))
			for(k=0;k<2;k++)  									// Start/Fin for each channel
				output = str2num(stringfromlist(2*i+k, outputs, ","))  // 2 per channelsx/channelsy
				// Check that the DAC board is initialized
				bd_GetBoard(channel)
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
					sprintf question, "DAC channel %s will be ramped outside software limits. Continue?", stringfromlist(i,channels,",")
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


function RampStartBD(S, [x_only, y_only, ignore_lims])
	// move DAC channels to starting point
	// x_only/y_only to only try ramping x/y to start (e.g. y_only=1 when using a babydac for y-axis of a fastdac scan)
	struct ScanVars &S
	variable x_only, y_only, ignore_lims
 
	// If x exists ramp them to start
	if(!y_only && numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0)  // If not NaN and not ""
		RampMultipleBD(S.instrIDx, S.channelsx, S.startx, ramprate=S.rampratex, ignore_lims=ignore_lims)
	endif  
	
	// If y exists ramp them to start
	if(!x_only && numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0)  // If not NaN and not ""
		RampMultipleBD(S.instrIDy, S.channelsy, S.starty, ramprate=S.rampratey, ignore_lims=ignore_lims)
	endif
end


function CheckAWG(AWG, Fsv)
	// Check that AWG and FastDAC ScanValues don't have any clashing DACs and check AWG within limits etc
	struct AWGVars &AWG
	struct ScanVars &Fsv
	
	string AWdacs  // Used for storing all DACS for 1 channel  e.g. "123" = Dacs 1,2,3
	string err_msg
	variable i=0, j=0
	
	// Assert separators are correct
	scu_assertSeparatorType(AWG.AW_DACs, ",")
	scu_assertSeparatorType(AWG.AW_waves, ",")
		
	// Check initialized
	if(AWG.initialized == 0)
		abort "ERROR[CheckAWG]: AWG_List needs to be initialized. Maybe something changed since last use!"
	endif
	
	// Check numADCs hasn't changed since setting up waves
	if(AWG.numADCs != scf_getNumRecordedADCs())
		abort "ERROR[CheckAWG]: Number of ADCs being measured has changed since setting up AWG, this will change AWG frequency. Set up AWG again to continue"
	endif
	
	// Check measureFreq hasn't change since setting up waves
	if(AWG.measureFreq != Fsv.measureFreq  || AWG.samplingFreq != Fsv.samplingFreq)
		sprintf err_msg, "ERROR[CheckAWG]: MeasureFreq has changed from %.2f/s to %.2f/s since setting up AWG. Set up AWG again to continue", AWG.measureFreq, Fsv.measureFreq
		abort err_msg
	endif
	
	// Check numSteps is an integer and not zero
	if(AWG.numSteps != trunc(AWG.numSteps) || AWG.numSteps == 0)
		abort "ERROR[CheckAWG]: numSteps must be an integer, not " + num2str(AWG.numSteps)
	endif
			
	// Check there are DACs set for each AW_wave (i.e. if using 2 AWs, need at least 1 DAC for each)
	if(itemsInList(AWG.AW_waves, ",") != (itemsinlist(AWG.AW_Dacs,",")))
		sprintf err_msg "ERROR[CheckAWG]: Number of AWs doesn't match sets of AW_Dacs. AW_Waves: %s; AW_Dacs: %s", AWG.AW_waves, AWG.AW_Dacs
		abort err_msg
	endif	
	
	// Check no overlap between DACs for sweeping, and DACs for AWG
	string channel // Single DAC channel
	string FDchannels = addlistitem(Fsv.Channelsy, Fsv.Channelsx, ",") // combine channels lists
	for(i=0;i<itemsinlist(AWG.AW_Dacs, ",");i++)
		AWdacs = stringfromlist(i, AWG.AW_Dacs, ",")
		for(j=0;j<strlen(AWdacs);j++)
			channel = AWdacs[j]
			if(findlistitem(channel, FDchannels, ",") != -1)
				abort "ERROR[CheckAWG]: Trying to use same DAC channel for FD scan and AWG at the same time"
			endif
		endfor
	endfor

	// Check that all setpoints for each AW_Dac will stay within software limits
	wave/T fdacvalstr	
	string softLimitPositive = "", softLimitNegative = "", expr = "(-?[[:digit:]]+),([[:digit:]]+)", question
	variable setpoint, answer, ch_num
	for(i=0;i<itemsinlist(AWG.AW_Dacs,",");i+=1)
		AWdacs = stringfromlist(i, AWG.AW_Dacs, ",")
		string wn = fd_getAWGwave(str2num(stringfromlist(i, AWG.AW_Waves, ",")))  // Get IGOR wave of AW#
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
						print("ERROR[CheckAWG]: User abort!")
						abort
					endif
				endif
			endfor
		endfor
	endfor		
end



	
	
	
///////////////////////////////////////////////////// ScanControllerFastdac ////////////////////////////////////////////////////////////////
	

// Fast DAC (8 DAC channels + 4 ADC channels). Build in-house by Mark (Electronic work shop).
// This is the ScanController extention to the ScanController code. Running measurements with
// the Fast DAC must be "stand alone", no other instruments can read at the same time.
// The Fast DAC extention will open a seperate "Fast DAC window" that holds all the information
// nessesary to run a Fast DAC measurement. Any "normal" measurements should still be set up in
// the standard ScanController window.
//
// This driver also provides a spectrum analyzer method. See the Spectrum Analyzer section at the bottom.
// As for everyting else, you must open a connection to a FastDAC and run "InitFastDAC" before you can use the
// spectrum analyzer method.
//
// Written by Christian Olsen and Tim Child, 2020-03-27
// Massive refactoring by Tim Child 2021-11

/////////////////////
//// Util  //////////  scf_... (ScanControllerFastdac...)
/////////////////////
function/t scf_getDacInfo(channelstr, info_name)
	// Returns info from DAC window part of ScanController_Fastdac
	// Note: Single channel only, but can be addressed as number or label
	string channelstr, info_name

	variable col_num
	strswitch(info_name)
		case "output":
			col_num = 1
			break
		case "limit":
			col_num = 2
			break
		case "label":
			col_num = 3
			break
		case "ramprate":
			col_num = 4
			break
		default:
			string buf
			sprintf buf "ERROR[scf_getDacInfo]: info_name (%s) not recognized. Use any of (output, limit, label, ramprate)" info_name
			abort buf
	endswitch

	wave/T fdacValStr	
	variable channel_num = str2num(scu_getChannelNumbers(channelstr, fastdac=1))
	if (numtype(channel_num) != 0)
		abort "ERROR[scf_getDacInfo]: Bad channelstr/channel_num"
	endif
	return fdacValStr[channel_num][col_num]
end

function scf_checkInstrIDmatchesDevice(instrID, device_num)
	// checks instrID is the correct Visa address for device number
	// e.g. if instrID is to FD1, but if when checking DevChannels device 2 was returned, this will fail
	variable instrID, device_num

	string instrAddress = getResourceAddress(instrID)
	svar sc_fdacKeys
	string deviceAddress = stringbykey("visa"+num2istr(device_num), sc_fdacKeys, ":", ",") 
	if (cmpstr(deviceAddress, instrAddress) != 0)
		string buffer
		sprintf buffer, "ERROR[scf_checkInstrIDmatchesDevice]: (instrID %d => %s) != device %d => %s", instrID, instrAddress, device_num, deviceAddress 
		abort buffer
	endif
	return 1
end


function scf_getFDnumber(instrID)
	// Returns which connected FastDAC instrID points to (e.g. 1, 2 etc)
	variable instrID

	svar sc_fdackeys
	variable numDevices = scf_getNumFDs(), i=0, numADCCh = 0, numDevice=-1
	string instrAddress = getResourceAddress(instrID), deviceAddress = ""
	for(i=0;i<numDevices;i+=1)
		deviceAddress = scf_getFDVisaAddress(i+1)
		if(cmpstr(deviceAddress,instrAddress) == 0)
			numDevice = i+1
			break
		endif
	endfor
	if (numDevice < 0)
		abort "ERROR[scf_getFDnumber]: Device not found for given instrID"
	endif
	return numDevice
end


function scf_getNumFDs()
	// Returns number of connected FastDACs
	svar sc_fdacKeys
	return str2num(stringbykey("numDevices",sc_fdackeys,":",","))
end


function/S scf_getFDVisaAddress(device_num)
	// Get visa address from device number (has to be it's own function because this returns a string)
	variable device_num
	if(device_num == 0)
		abort "ERROR[scf_getFDVisaAddress]: device_num starts from 1 not 0"
	elseif(device_num > scf_getNumFDs()+1)
		string buffer
		sprintf buffer,  "ERROR[scf_getFDInfoFromDeviceNum]: Asking for device %d, but only %d devices connected\r", device_num, scf_getNumFDs()
		abort buffer
	endif

	svar sc_fdacKeys
	return stringByKey("visa"+num2str(device_num), sc_fdacKeys, ":", ",")
end


function scf_getFDInfoFromDeviceNum(device_num, info)
	// Returns the value for selected info of numbered fastDAC device (i.e. 1, 2 etc)
	// Valid requests ('master', 'name', 'numADC', 'numDAC')
	variable device_num
	string info

	svar sc_fdacKeys

	if(device_num > scf_getNumFDs())
		string buffer
		sprintf buffer,  "ERROR[scf_getFDInfoFromDeviceNum]: Asking for device %d, but only %d devices connected\r", device_num, scf_getNumFDs()
		abort buffer
	endif

	string cmd
	strswitch (info)
		case "master":
			cmd = "master"
			break
		case "name":
			cmd = "name"
			break
		case "numADC":
			cmd = "numADCch"
			break
		case "numDAC":
			cmd = "numDACch"
			break
		default:
			abort "ERROR[scf_getFDInfoFromID]: Requested info (" + info + ") not understood"
			break
	endswitch
	return str2num(stringByKey(cmd+num2str(device_num), sc_fdacKeys, ":", ","))
end


function scf_getFDInfoFromID(instrID, info)
	// Returns the value for selected info of fastDAC pointed to by instrID
	// Basically a nice way to interact with sc_fdacKeys
	variable instrID
	string info

	variable deviceNum = scf_getFDnumber(instrID)
	return scf_getFDInfoFromDeviceNum(deviceNum, info)
end

function/S scf_getRecordedADCinfo(info_name)  // TODO: Rename if prepending something which implies fd anyway
	// Return a list of strings for specified column in fadcattr based on whether "record" is ticked
	// Valid info_name ("calc_names", "raw_names", "calc_funcs", "inputs", "channels")
    string info_name 
    variable i
    wave fadcattr

	 string return_list = ""
    wave/t fadcvalstr
    for (i = 0; i<dimsize(fadcvalstr, 0); i++)
        if (fadcattr[i][2] == 48) // Checkbox checked
			strswitch(info_name)
				case "calc_names":
                return_list = addlistItem(fadcvalstr[i][3], return_list, ";", INF)  												
					break
				case "raw_names":
                return_list = addlistItem("ADC"+num2str(i), return_list, ";", INF)  						
					break
				case "calc_funcs":
                return_list = addlistItem(fadcvalstr[i][4], return_list, ";", INF)  						
					break						
				case "inputs":
                return_list = addlistItem(fadcvalstr[i][1], return_list, ";", INF)  												
					break						
				case "channels":
                return_list = addlistItem(fadcvalstr[i][0], return_list, ";", INF)  																		
					break
				default:
					abort "bad name requested: " + info_name + ". Allowed are (calc_names, raw_names, calc_funcs, inputs, channels)"
					break
			endswitch						
        endif
    endfor
    return return_list
end


function scf_getNumRecordedADCs() 
	// Returns how many ADCs are set to be recorded
	// Note: Gets this info from ScanController_Fastdac
	string adcs = scf_getRecordedADCinfo("channels")
	variable numadc = itemsInList(adcs)
	if(numadc == 0)
		print "WARNING[scf_getNumRecordedADCs]: No ADCs set to record. Behaviour may be unpredictable"
	endif
		
	return numadc
end


function/S scf_getChannelNumsOnFD(channels, device, [adc])
	// Convert from absolute channel number to device channel number (i.e. DAC 9 is actually FastDAC2s 1 channel)
	// Returns device number in device variable
	// Note: Comma separated list
	// Note: Must be channel NUMBERS
	// Note: Error thrown if not all channels are on the same device
	string channels // DACs or ADCs to check
	variable adc  // Whether we are checking DACs or ADCs
	variable &device // Returns device number in device (starting from 1)

	svar sc_fdacKeys  // Holds info about connected FastDACs

	channels = replaceString(",", channels, ";")  // DAC channels may be passed in with "," separator instead of ";" separator
	scu_assertSeparatorType(channels, ";")

	variable numDevices = scf_getNumFDs()
	device = -1 // Init invalid (so can set when first channel is found)
	variable i=0, j=0, numCh=0, startCh=0, Ch=0
	string dev_channels=""
	for(i=0;i<itemsInList(channels);i+=1)
		ch = str2num(stringfromlist(i,channels))  // Looking for where this channel lives
		startCh = 0
		for(j=0;j<numDevices+1;j+=1)  // Cycle through connected devices
			if(!adc) // Looking at DACs
				numCh = scf_getFDInfoFromDeviceNum(j+1, "numDAC")
			else  // Looking at ADCs
				numCh = scf_getFDInfoFromDeviceNum(j+1, "numADC")
			endif

			if(startCh+numCh-1 >= Ch)
				// this is the device
				if(device <= 0)
					device = j+1  // +1 to account for device numbering starting from 1 not zero
				elseif (j+1 != device)
					abort "ERROR[scf_getChannelNumsOnFD]: Channels are distributed across multiple devices. Not implemented"
				endif
				dev_channels = addlistitem(num2istr(Ch),dev_channels,";",INF)  // Add to list of Device Channels
				break
			endif
			startCh += numCh
		endfor
	endfor

	return dev_channels
end


function scf_getChannelStartNum(instrID, [adc])
	// Returns first channel number for given instrID (i.e. if second Fastdac, first DAC is probably channel 8)
	variable instrID
	variable adc // set to 1 if checking where ADCs start instead
	
	string ch_request = selectString(adc, "numDAC", "numADC")

	variable numDevices = scf_getNumFDs()
	variable devNum = scf_getFDnumber(instrID)

	variable startCh = 0
	variable valid = 0 // Set to 1 when device is found
	variable i
	for(i=0; i<numDevices; i++)
		if (devNum == i+1) // If this is the device (i+1 because device numbering starts at 1)
			valid = 1
			break
		endif
		startCh += scf_getFDInfoFromID(i+1, ch_request)
	endfor

	if(!valid)
		abort "ERROR[scf_getChannelStartNum]: Device not found"
	endif

	return startCh
end


function scf_checkFDResponse(response,command,[isString,expectedResponse])
	// Checks response (that fastdac returns at the end of most commands) meets expected response (e.g. "RAMP_FINISHED")
	string response, command, expectedResponse
	variable isString

	if(paramisdefault(expectedResponse))
		expectedResponse = ""
	endif

	variable errorCheck = 0
	string err="",callingfunc = getrtStackInfo(2)
	// FastDAC will return "NOP" if the commands isn't understood
	if(cmpstr(response,"NOP") == 0)
		sprintf err, "[ERROR] \"%s\": Command not understood! Command: %s", callingfunc, command
		print err
	elseif(numtype(str2num(response)) != 0 && !isString)
		sprintf err, "[ERROR] \"%s\": Bad response: %s", callingfunc, response
		print err
	elseif(cmpstr(response,expectedResponse) != 0 && isString)
		sprintf err, "[ERROR] \"%s\": Bad response: %s", callingfunc, response
		print err
	else
		errorCheck = 1
	endif

	return errorCheck
end


function scf_addFDinfos(instrID,visa_address,numDACCh,numADCCh,[master])  
	// Puts FastDAC information into global sc_fdackeys which is a list of such entries for each connected FastDAC
	string instrID, visa_address
	variable numDACCh, numADCCh, master

	if(paramisdefault(master))
		master = 0
	elseif(master > 1)
		master = 1
	endif

	variable numDevices
		svar/z sc_fdackeys
	if(!svar_exists(sc_fdackeys))
		string/g sc_fdackeys = ""
		numDevices = 0
	else
		numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",","))
	endif

	variable i=0, deviceNum=numDevices+1
	for(i=0;i<numDevices;i+=1)
		if(cmpstr(instrID,stringbykey("name"+num2istr(i+1),sc_fdackeys,":",","))==0)
			deviceNum = i+1
			break
		endif
	endfor

	sc_fdackeys = replacenumberbykey("numDevices",sc_fdackeys,deviceNum,":",",")
	sc_fdackeys = replacestringbykey("name"+num2istr(deviceNum),sc_fdackeys,instrID,":",",")
	sc_fdackeys = replacestringbykey("visa"+num2istr(deviceNum),sc_fdackeys,visa_address,":",",")
	sc_fdackeys = replacenumberbykey("numDACCh"+num2istr(deviceNum),sc_fdackeys,numDACCh,":",",")
	sc_fdackeys = replacenumberbykey("numADCCh"+num2istr(deviceNum),sc_fdackeys,numADCCh,":",",")
	sc_fdackeys = replacenumberbykey("master"+num2istr(deviceNum),sc_fdackeys,master,":",",")
	sc_fdackeys = sortlist(sc_fdackeys,",")
end


//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////// Taking Data and processing //////////////////////////////////  scfd_... (ScanControllerFastdacData...)
//////////////////////////////////////////////////////////////////////////////////////////


function scfd_postFilterNumpts(raw_numpts, measureFreq)  // TODO: Rename to NumptsAfterFilter
    // Returns number of points that will exist after applying lowpass filter specified in ScanController_Fastdac
    variable raw_numpts, measureFreq
	
	nvar boxChecked = sc_ResampleFreqCheckFadc
	nvar targetFreq = sc_ResampleFreqFadc
	if (boxChecked)
	  	RatioFromNumber (targetFreq / measureFreq)
	  	return round(raw_numpts*(V_numerator)/(V_denominator))  // TODO: Is this actually how many points are returned?
	else
		return raw_numpts
	endif
end

function scfd_resampleWaves(w, measureFreq, targetFreq)
	// resamples wave w from measureFreq
	// to targetFreq (which should be lower than measureFreq)
	Wave w
	variable measureFreq, targetFreq
	
	RatioFromNumber (targetFreq / measureFreq)
	if (V_numerator > V_denominator)
		string cmd
		printf cmd "WARNING[scfd_resampleWaves]: Resampling will increase number of datapoints, not decrease! (ratio = %d/%d)\r", V_numerator, V_denominator
	endif
	resample/UP=(V_numerator)/DOWN=(V_denominator)/N=201 w
	// TODO: Need to test N more (simple testing suggests we may need >200 in some cases!)
	// TODO: Need to decide what to do with end effect. Possibly /E=2 (set edges to 0) and then turn those zeros to NaNs? 
	// TODO: Or maybe /E=3 is safest (repeat edges). The default /E=0 (bounce) is awful.
end

function scfd_RecordValues(S, rowNum, [AWG_list, linestart, skip_data_distribution])  // TODO: Rename to fd_record_values
	struct ScanVars &S
	variable rowNum, linestart
	variable skip_data_distribution // For recording data without doing any calculation or distribution of data
	struct AWGVars &AWG_list
	// If passed AWG_list with AWG_list.use_AWG == 1 then it will run with the Arbitrary Wave Generator on
	// Note: Only works for 1 FastDAC! Not sure what implementation will look like for multiple yet

	// Check if AWG is going to be used
	Struct AWGVars AWG  // Note: Default has AWG.use_awg = 0
	if(!paramisdefault(AWG_list))  // If AWG_list passed, then overwrite default
		AWG = AWG_list
	endif 
		 
   // Check that checks have been carried out in main scan function where they belong
	if(S.lims_checked != 1 && S.readVsTime != 1)  // No limits to check if doing a readVsTime
	 	abort "ERROR[fd_record_values]: FD_ScanVars.lims_checked != 1. Probably called before limits/ramprates/sweeprates have been checked in the main Scan Function!"
	endif

   	// Check that DACs are at start of ramp (will set if necessary but will give warning if it needs to)
	   // This is to avoid the fastdac instantly changing gates significantly when the sweep command is sent
	if (!S.readVsTime)
		scc_checkRampStartFD(S)
	endif

	// If beginning of scan, record start time
	if (rowNum == 0 && S.start_time == 0)  
		S.start_time = datetime 
	endif

	// Send command and read values
	scfd_SendCommandAndRead(S, AWG, rowNum) 
	S.end_time = datetime  
	
	// Process 1D read and distribute
	if (!skip_data_distribution)
		scfd_ProcessAndDistribute(S, rowNum) 
	endif
end

function scfd_SendCommandAndRead(S, AWG_list, rowNum)
	// Send 1D Sweep command to fastdac and record the raw data it returns ONLY
	struct ScanVars &S
	struct AWGVars &AWG_list
	variable rowNum
	string cmd_sent = ""
	variable totalByteReturn

	// Check some minimum requirements
	if (S.samplingFreq == 0 || S.numADCs == 0 || S.numptsx == 0)
		abort "ERROR[scfd_SendCommandAndRead]: Not enough info in ScanVars to run scan"
	endif
	
	cmd_sent = fd_start_sweep(S, AWG_list=AWG_list)
	
	totalByteReturn = S.numADCs*2*S.numptsx
	variable entered_panic_mode = 0
	try
   		entered_panic_mode = scfd_RecordBuffer(S, rowNum, totalByteReturn)
   	catch  // One chance to do the sweep again if it failed for some reason (likely from a buffer overflow)
		variable errCode = GetRTError(1)  // Clear the error
		if (v_AbortCode != 10)  // 10 is returned when user clicks abort button mid sweep
			printf "WARNING[scfd_SendCommandAndRead]: Error during sweep at row %d. Attempting once more without updating graphs.\r" rowNum
			fd_stopFDACsweep(S.instrIDx)   // Make sure the previous scan is stopped
			cmd_sent = fd_start_sweep(S, AWG_list=AWG_list)
			entered_panic_mode = scfd_RecordBuffer(S, rowNum, totalByteReturn, record_only=1)  // Try again to record the sweep
		else
			abortonvalue 1,10  // Continue to raise the code which specifies user clicked abort button mid sweep
		endif
	endtry	

	string endstr
	endstr = readInstr(S.instrIDx)
	endstr = sc_stripTermination(endstr,"\r\n")	
	if (S.readVsTime)
		scf_checkFDResponse(endstr,cmd_sent,isString=1,expectedResponse="READ_FINISHED")
		// No need to update DACs
	else
		scf_checkFDResponse(endstr,cmd_sent,isString=1,expectedResponse="RAMP_FINISHED")
	   // update DAC values in window (request values from FastDAC directly in case ramp failed)
		scfd_updateWindow(S, S.numADCs) 
	endif
	
	if(AWG_list.use_awg == 1)  // Reset AWs back to zero (no reason to leave at end of AW)
		rampmultiplefdac(S.instrIDx, AWG_list.AW_DACs, 0)
	endif
end


function scfd_ProcessAndDistribute(ScanVars, rowNum)
	// Get 1D wave names, duplicate each wave then resample and copy into calc wave (and do calc string)
	struct ScanVars &ScanVars
	variable rowNum
		
	// Get all raw 1D wave names in a list
	string RawWaveNames1D = sci_get1DWaveNames(1, 1)
	string CalcWaveNames1D = sci_get1DWaveNames(0, 1)
	string CalcStrings = scf_getRecordedADCinfo("calc_funcs")
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
			scfd_resampleWaves(sc_tempwave, ScanVars.measureFreq, sc_ResampleFreqfadc)
		endif
		calc_string = ReplaceString(rwn, calc_string, "sc_tempwave")
		
		execute("sc_tempwave ="+calc_string)
		execute(cwn+" = sc_tempwave")
		
		if (ScanVars.is2d)
			// Copy 1D raw into 2D
			wave raw1d = $rwn
			wave raw2d = $rwn+"_2d"
			raw2d[][rowNum] = raw1d[p]
			
			// Copy 1D calc into 2D
			cwn = cwn+"_2d"
			wave calc2d = $cwn
			calc2d[][rowNum] = sc_tempwave[p]		
		endif
	endfor	
	doupdate // Update all the graphs with their new data
end


function scfd_RecordBuffer(S, rowNum, totalByteReturn, [record_only])
	// Returns whether recording entered into panic_mode during sweep
   struct ScanVars &S
   variable rowNum, totalByteReturn
   variable record_only // If set, then graphs will not be updated until all data has been read 

   // hold incoming data chunks in string and distribute to data waves
   string buffer = ""
   variable bytes_read = 0, totaldump = 0 
   variable saveBuffer = 1000 // Allow getting up to 1000 bytes behind. (Note: Buffer size is 4096 bytes and cannot be changed in Igor)
   variable bufferDumpStart = stopMSTimer(-2)

   variable bytesSec = roundNum(2*S.samplingFreq,0)
   variable read_chunk = scfd_getReadChunkSize(S.numADCs, S.numptsx, bytesSec, totalByteReturn)
   variable panic_mode = record_only  // If Igor gets behind on reading at any point, it will go into panic mode and focus all efforts on clearing buffer.
   variable expected_bytes_in_buffer = 0 // For storing how many bytes are expected to be waiting in buffer
   do
      scfd_readChunk(S.instrIDx, read_chunk, buffer)  // puts data into buffer
      scfd_distributeData1(buffer, S, bytes_read, totalByteReturn, read_chunk, rowNum)
      scfd_checkSweepstate(S.instrIDx)

      bytes_read += read_chunk      
      expected_bytes_in_buffer = scfd_ExpectedBytesInBuffer(bufferDumpStart, bytesSec, bytes_read)      
      if(!panic_mode && expected_bytes_in_buffer < saveBuffer)  // if we aren't too far behind then update Raw 1D graphs
         scg_updateRawGraphs() 
	      expected_bytes_in_buffer = scfd_ExpectedBytesInBuffer(bufferDumpStart, bytesSec, bytes_read)  // Basically checking how long graph updates took
			if (expected_bytes_in_buffer > 4096)
         		printf "ERROR[scfd_RecordBuffer]: After updating graphs, buffer is expected to overflow... Expected buffer size = %d (max = 4096). Bytes read so far = %d\r" expected_bytes_in_buffer, bytes_read
         elseif (expected_bytes_in_buffer > 2500)
//				printf "WARNING[scfd_RecordBuffer]: Last graph update resulted in buffer becoming close to full (%d of 4096 bytes). Entering panic_mode (no more graph updates)\r", expected_bytes_in_buffer
				panic_mode = 1         
         	endif
		else
			if (expected_bytes_in_buffer > 1000)
//				printf "DEBUGGING: getting behind: Expecting %d bytes in buffer (max 4096)\r" expected_bytes_in_buffer		
				if (panic_mode == 0)
					panic_mode = 1
//					printf "WARNING[scfd_RecordBuffer]: Getting behind on reading buffer, entering panic mode (no more graph updates until end of sweep)\r"				
				endif			
			endif
		endif
   while(totalByteReturn-bytes_read > read_chunk)

   // do one last read if any data left to read
   variable bytes_left = totalByteReturn-bytes_read
   if(bytes_left > 0)
      scfd_readChunk(S.instrIDx, bytes_left, buffer)  // puts data into buffer
      scfd_distributeData1(buffer, S, bytes_read, totalByteReturn, bytes_left, rowNum)
   endif
   
   scfd_checkSweepstate(S.instrIDx)
//   variable st = stopMSTimer(-2)
   scg_updateRawGraphs() 
//   printf "scg_updateRawGraphs took %.2f ms\r", (stopMSTimer(-2) - st)/1000
   return panic_mode
end

function scfd_ExpectedBytesInBuffer(start_time, bytes_per_sec, total_bytes_read)
	// Calculates how many bytes are expected to be in the buffer right now
	variable start_time  // Time at which command was sent to Fastdac
	variable bytes_per_sec  // How many bytes is fastdac returning per second (2*sampling rate)
	variable total_bytes_read  // How many bytes have been read so far
	
	return round(bytes_per_sec*(stopmstimer(-2)-start_time)*1e-6 - total_bytes_read)
end

function scfd_getReadChunkSize(numADCs, numpts, bytesSec, totalByteReturn)
  // Returns the size of chunks that should be read at a time
  variable numADCs, numpts, bytesSec, totalByteReturn

  variable read_duration = 0.5  // Make readchunk s.t. it nominally take this time to fill
  variable chunksize = (round(bytesSec*read_duration) - mod(round(bytesSec*read_duration),numADCs*2))  

  variable read_chunk=0
  if(chunksize < 50)
    chunksize = 50 - mod(50,numADCs*2)
  endif
  if(totalByteReturn > chunksize)
    read_chunk = chunksize
  else
    read_chunk = totalByteReturn
  endif
  return read_chunk
end

function scfd_checkSweepstate(instrID)
  	// if abort button pressed then stops FDAC sweep then aborts
  	variable instrID
	variable errCode
	nvar sc_abortsweep
	nvar sc_pause
  	try
    	scs_checksweepstate()
  	catch
		errCode = GetRTError(1)
		fd_stopFDACsweep(instrID)
//		if(v_abortcode == -1)  // If user abort
//				sc_abortsweep = 0
//				sc_pause = 0
//		endif
		abortonvalue 1,10
	endtry
end

function scfd_readChunk(instrID, read_chunk, buffer)
  variable instrID, read_chunk
  string &buffer
  buffer = readInstr(instrID, read_bytes=read_chunk, binary=1)
  // If failed, abort
  if (cmpstr(buffer, "NaN") == 0)
    fd_stopFDACsweep(instrID)
    abort
  endif
end


function scfd_distributeData1(buffer, S, bytes_read, totalByteReturn, read_chunk, rowNum)
	// Distribute data to 1D waves only (for speed)
  struct ScanVars &S
  string &buffer  // Passing by reference for speed of execution
  variable bytes_read, totalByteReturn, read_chunk, rowNum

 	variable direction = S.direction == 0 ? 1 : S.direction  // Default to forward

  variable col_num_start
  if (direction == 1)
    col_num_start = bytes_read/(2*S.numADCs)
  elseif (direction == -1)
    col_num_start = (totalByteReturn-bytes_read)/(2*S.numADCs)-1
  endif
  scfd_distributeData2(buffer,S.adcList,read_chunk,rowNum,col_num_start, direction=direction, named_waves=S.raw_wave_names)
end


function scfd_updateWindow(S, numAdcs)
	// Update the DAC and ADC values in the FastDAC window (e.g. at the end of a sweep)
  struct ScanVars &S
  variable numADCs
  // Note: This does not yet support multiple fastdacs

  scu_assertSeparatorType(S.channelsx, ",")
  scu_assertSeparatorType(S.finxs, ",")
  scu_assertSeparatorType(S.adcList, ";")

  wave/T fdacvalstr

  variable i, device_num
  string channel, device_channel
  for(i=0;i<itemsinlist(S.channelsx,",");i+=1)
    channel = stringfromlist(i,S.channelsx,",")
	device_channel = scf_getChannelNumsOnFD(channel, device_num)  // Get channel for specific fastdac (and device_num of that fastdac)
	if (cmpstr(scf_getFDVisaAddress(device_num), getResourceAddress(S.instrIDx)) != 0)
		print("ERROR[scfd_updateWindow]: channel device address doesn't match instrID address")
	else
		scfw_updateFdacValStr(str2num(channel), getFDACOutput(S.instrIDx, str2num(device_channel)), update_oldValStr=1)
	endif
  endfor

  variable channel_num
  for(i=0;i<numADCs;i+=1)
    channel_num = str2num(stringfromlist(i,S.adclist,";"))
    getfadcChannel(S.instrIDx,channel_num, len_avg=0.001)  // This updates the window when called
  endfor
end


function scfd_distributeData2(buffer,adcList,bytes,rowNum,colNumStart,[direction, named_waves])  // TODO: rename
	// Distribute data to 1D waves only (for speed)
	// Note: This distribute data can be called within the 1D sweep, updating 2D waves should only be done outside of fastdac sweeps because it can be slow
	string &buffer, adcList  //passing buffer by reference for speed of execution
	variable bytes, rowNum, colNumStart, direction
	string named_waves
	wave/t fadcvalstr

	variable i
	direction = paramisdefault(direction) ? 1 : direction
	if (!(direction == 1 || direction == -1))  // Abort if direction is not 1 or -1
		abort "ERROR[scfd_distributeData2]: Direction must be 1 or -1"
	endif

	variable numADCCh = itemsinlist(adcList)
	string waveslist = ""
	if (!paramisDefault(named_waves) && strlen(named_waves) > 0)  // Use specified wavenames instead of default ADC#
		scu_assertSeparatorType(named_waves, ";")
		if (itemsInList(named_waves) != numADCch)
			abort "ERROR[scfd_distributeData2]: wrong number of named_waves for numADCch being recorded"
		endif
		waveslist = named_waves
	else
		for(i=0;i<numADCCh;i++)
			waveslist = addListItem("ADC"+stringFromList(i, adcList), waveslist, ";", INF)
		endfor
	endif

	variable j, k, dataPoint
	string wave1d, s1, s2
	// load data into raw wave
	for(i=0;i<numADCCh;i+=1)
		wave1d = stringFromList(i, waveslist)
		wave rawwave = $wave1d
		k = 0
		for(j=0;j<bytes;j+=numADCCh*2)
		// convert to floating point
			s1 = buffer[j + (i*2)]
			s2 = buffer[j + (i*2) + 1]
			datapoint = fd_Char2Num(s1, s2)
			rawwave[colNumStart+k] = dataPoint
			k += 1*direction
		endfor
	endfor
end


////////////////////////////////////////////////////////////////////////////////////
////////////////////////// FastDAC Scancontroller window ///////////////////////////  scfw_... (ScanControllerFastdacWindow...)
////////////////////////////////////////////////////////////////////////////////////

function scfw_resetfdacwindow(fdacCh)
	variable fdacCh
	wave/t fdacvalstr, old_fdacvalstr

	fdacvalstr[fdacCh][1] = old_fdacvalstr[fdacCh]
end

function scfw_updateOldFDacStr(fdacCh)  // TODO: rename to updateOldFdacValStr
	variable fdacCh
	wave/t fdacvalstr, old_fdacvalstr

	old_fdacvalstr[fdacCh] = fdacvalstr[fdacCh][1]
end

function scfw_updateFdacValStr(channel, value, [update_oldValStr])
	// Update the global string(s) which store FastDAC values. Update the oldValStr if you know that is the current DAC output.
	variable channel, value, update_oldValStr

	// TODO: Add checks here
	// check value is valid (not NaN or inf)
	// check channel_num is valid (i.e. within total number of fastdac DAC channels)
	wave/t fdacvalstr
	fdacvalstr[channel][1] = num2str(value)
	if (update_oldValStr != 0)
		wave/t old_fdacvalstr
		old_fdacvalstr[channel] = num2str(value)
	endif
end

function initFastDAC()
	// use the key:value list "sc_fdackeys" to figure out the correct number of
	// DAC/ADC channels to use. "sc_fdackeys" is created when calling "openFastDACconnection".
	svar sc_fdackeys
	if(!svar_exists(sc_fdackeys))
		print("[ERROR] \"initFastDAC\": No devices found!")
		abort
	endif

	// hardware limit (mV)
	variable/g fdac_limit = 10000

	variable i=0, numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",","))
	variable numDACCh=0, numADCCh=0
	for(i=0;i<numDevices+1;i+=1)
		if(cmpstr(stringbykey("name"+num2istr(i+1),sc_fdackeys,":",","),"")!=0)
			numDACCh += str2num(stringbykey("numDACCh"+num2istr(i+1),sc_fdackeys,":",","))
			numADCCh += str2num(stringbykey("numADCCh"+num2istr(i+1),sc_fdackeys,":",","))
		endif
	endfor

	// create waves to hold control info
	variable oldinit = scfw_fdacCheckForOldInit(numDACCh,numADCCh)

	variable/g num_fdacs = 0
	if(oldinit == -1)
		string speeds = "372;2538;6061;12195"
		string/g sc_fadcSpeed1=speeds,sc_fadcSpeed2=speeds,sc_fadcSpeed3=speeds
		string/g sc_fadcSpeed4=speeds,sc_fadcSpeed5=speeds,sc_fadcSpeed6=speeds
	endif

	// create GUI window
	string cmd = ""
	//variable winsize_l,winsize_r,winsize_t,winsize_b
	getwindow/z ScanControllerFastDAC wsizeRM
	killwindow/z ScanControllerFastDAC
	sprintf cmd, "FastDACWindow(%f,%f,%f,%f)", v_left, v_right, v_top, v_bottom
	execute(cmd)
	scfw_SetGUIinteraction(numDevices)
end

function scfw_fdacCheckForOldInit(numDACCh,numADCCh)
	variable numDACCh, numADCCh

	variable response
	wave/z fdacvalstr
	wave/z old_fdacvalstr
	if(waveexists(fdacvalstr) && waveexists(old_fdacvalstr))
		response = scfw_fdacAskUser(numDACCh)
		if(response == 1)
			// Init at old values
			print "[FastDAC] Init to old values"
		elseif(response == -1)
			// Init to default values
			scfw_CreateControlWaves(numDACCh,numADCCh)
			print "[FastDAC] Init to default values"
		else
			print "[Warning] \"scfw_fdacCheckForOldInit\": Bad user input - Init to default values"
			scfw_CreateControlWaves(numDACCh,numADCCh)
			response = -1
		endif
	else
		// Init to default values
		scfw_CreateControlWaves(numDACCh,numADCCh)
		response = -1
	endif

	return response
end

function scfw_fdacAskUser(numDACCh)
	variable numDACCh
	wave/t fdacvalstr

	// can only init to old settings if the same
	// number of DAC channels are used
	if(dimsize(fdacvalstr,0) == numDACCh)
		make/o/t/n=(numDACCh) fdacdefaultinit = "0"
		duplicate/o/rmd=[][1] fdacvalstr ,fdacvalsinit
		concatenate/o {fdacvalsinit,fdacdefaultinit}, fdacinit
		execute("scfw_fdacInitWindow()")
		pauseforuser scfw_fdacInitWindow
		nvar fdac_answer
		return fdac_answer
	else
		return -1
	endif
end

window scfw_fdacInitWindow() : Panel
	PauseUpdate; Silent 1 // building window
	NewPanel /W=(100,100,400,630) // window size
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 20, 45,"Choose FastDAC init" // Headline
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 40,80,"Old init"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 170,80,"Default"
	ListBox initlist,pos={10,90},size={280,390},fsize=16,frame=2
	ListBox initlist,fStyle=1,listWave=root:fdacinit,mode= 0
	Button old_fdacinit,pos={40,490},size={70,20},proc=scfw_fdacAskUserUpdate,title="OLD INIT"
	Button default_fdacinit,pos={170,490},size={70,20},proc=scfw_fdacAskUserUpdate,title="DEFAULT"
endmacro

function scfw_fdacAskUserUpdate(action) : ButtonControl
	string action
	variable/g fdac_answer

	strswitch(action)
		case "old_fdacinit":
			fdac_answer = 1
			dowindow/k scfw_fdacInitWindow
			break
		case "default_fdacinit":
			fdac_answer = -1
			dowindow/k scfw_fdacInitWindow
			break
	endswitch
end

window FastDACWindow(v_left,v_right,v_top,v_bottom) : Panel
	variable v_left,v_right,v_top,v_bottom
	PauseUpdate; Silent 1 // pause everything else, while building the window
	NewPanel/w=(0,0,790,630)/n=ScanControllerFastDAC // window size ////// EDIT 570 -> 600
	if(v_left+v_right+v_top+v_bottom > 0)
		MoveWindow/w=ScanControllerFastDAC v_left,v_top,V_right,v_bottom
	endif
	ModifyPanel/w=ScanControllerFastDAC framestyle=2, fixedsize=1
	SetDrawLayer userback
	SetDrawEnv fsize=25, fstyle=1
	DrawText 160, 45, "DAC"
	SetDrawEnv fsize=25, fstyle=1
	DrawText 546, 45, "ADC"
	DrawLine 385,15,385,385 
	DrawLine 10,415,780,415 /////EDIT 385-> 415
	SetDrawEnv dash=7
	Drawline 395,320,780,320 /////EDIT 295 -> 320
	// DAC, 12 channels shown
	SetDrawEnv fsize=14, fstyle=1
	DrawText 15, 70, "Ch"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 50, 70, "Output"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 120, 70, "Limit"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 220, 70, "Label"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 287, 70, "Ramprate"
	ListBox fdaclist,pos={10,75},size={360,300},fsize=14,frame=2,widths={30,70,100,65} 
	ListBox fdaclist,listwave=root:fdacvalstr,selwave=root:fdacattr,mode=1
	Button updatefdac,pos={50,384},size={65,20},proc=scfw_update_fdac,title="Update" 
	Button fdacramp,pos={150,384},size={65,20},proc=scfw_update_fdac,title="Ramp"
	Button fdacrampzero,pos={255,384},size={80,20},proc=scfw_update_fdac,title="Ramp all 0" 
	// ADC, 8 channels shown
	SetDrawEnv fsize=14, fstyle=1
	DrawText 405, 70, "Ch"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 435, 70, "Input (mV)"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 515, 70, "Record"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 575, 70, "Wave Name"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 665, 70, "Calc Function"
	ListBox fadclist,pos={400,75},size={385,180},fsize=14,frame=2,widths={25,65,45,80,80}
	ListBox fadclist,listwave=root:fadcvalstr,selwave=root:fadcattr,mode=1
	button updatefadc,pos={400,265},size={90,20},proc=scfw_update_fadc,title="Update ADC"
//	checkbox sc_PrintfadcBox,pos={500,265},proc=scw_CheckboxClicked,value=sc_Printfadc,side=1,title="\Z14Print filenames "
	checkbox sc_SavefadcBox,pos={620,265},proc=scw_CheckboxClicked,value=sc_Saverawfadc,side=1,title="\Z14Save raw data "
	checkbox sc_FilterfadcCheckBox,pos={400,290},proc=scw_CheckboxClicked,value=sc_ResampleFreqCheckfadc,side=1,title="\Z14Resample "
	SetVariable sc_FilterfadcBox,pos={500,290},size={200,20},value=sc_ResampleFreqfadc,side=1,title="\Z14Resample Frequency ",help={"Re-samples to specified frequency, 0 Hz == no re-sampling"} /////EDIT ADDED
	DrawText 705,310, "\Z14Hz" 
	popupMenu fadcSetting1,pos={420,330},proc=scfw_scfw_update_fadcSpeed,mode=1,title="\Z14ADC1 speed",size={100,20},value=sc_fadcSpeed1 
	popupMenu fadcSetting2,pos={620,330},proc=scfw_scfw_update_fadcSpeed,mode=1,title="\Z14ADC2 speed",size={100,20},value=sc_fadcSpeed2 
	popupMenu fadcSetting3,pos={420,360},proc=scfw_scfw_update_fadcSpeed,mode=1,title="\Z14ADC3 speed",size={100,20},value=sc_fadcSpeed3 
	popupMenu fadcSetting4,pos={620,360},proc=scfw_scfw_update_fadcSpeed,mode=1,title="\Z14ADC4 speed",size={100,20},value=sc_fadcSpeed4 
	popupMenu fadcSetting5,pos={420,390},proc=scfw_scfw_update_fadcSpeed,mode=1,title="\Z14ADC5 speed",size={100,20},value=sc_fadcSpeed5 
	popupMenu fadcSetting6,pos={620,390},proc=scfw_scfw_update_fadcSpeed,mode=1,title="\Z14ADC6 speed",size={100,20},value=sc_fadcSpeed6 
	DrawText 550, 347, "\Z14Hz" 
	DrawText 750, 347, "\Z14Hz" 
	DrawText 550, 377, "\Z14Hz" 
	DrawText 750, 377, "\Z14Hz" 
	DrawText 550, 407, "\Z14Hz" 
	DrawText 750, 407, "\Z14Hz" 

	// identical to ScanController window
	// all function calls are to ScanController functions
	// instrument communication
	SetDrawEnv fsize=14, fstyle=1
	DrawText 15, 445, "Connect Instrument" 
	SetDrawEnv fsize=14, fstyle=1 
	DrawText 265, 445, "Open GUI" 
	SetDrawEnv fsize=14, fstyle=1
	DrawText 515, 445, "Log Status" 
	ListBox sc_InstrFdac,pos={10,450},size={770,100},fsize=14,frame=2,listWave=root:sc_Instr,selWave=root:instrBoxAttr,mode=1, editStyle=1

	// buttons
	button connectfdac,pos={10,555},size={140,20},proc=scw_OpenInstrButton,title="Connect Instr" 
	button guifdac,pos={160,555},size={140,20},proc=scw_OpenGUIButton,title="Open All GUI" 
	button killaboutfdac, pos={310,555},size={160,20},proc=sc_controlwindows,title="Kill Sweep Controls" 
	button killgraphsfdac, pos={480,555},size={150,20},proc=scw_killgraphs,title="Close All Graphs" 
	button updatebuttonfdac, pos={640,555},size={140,20},proc=scw_updatewindow,title="Update" 

	// helpful text
	DrawText 10, 595, "Press Update to save changes." 
endmacro

	// set update speed for ADCs
function scfw_scfw_update_fadcSpeed(s) : PopupMenuControl
	struct wmpopupaction &s

	string visa_address = ""
	svar sc_fdackeys
	if(s.eventcode == 2)
		// a menu item has been selected
		strswitch(s.ctrlname)
			case "fadcSetting1":
				visa_address = stringbykey("visa1",sc_fdackeys,":",",")
				break
			case "fadcSetting2":
				visa_address = stringbykey("visa2",sc_fdackeys,":",",")
				break
			case "fadcSetting3":
				visa_address = stringbykey("visa3",sc_fdackeys,":",",")
				break
			case "fadcSetting4":
				visa_address = stringbykey("visa4",sc_fdackeys,":",",")
				break
			case "fadcSetting5":
				visa_address = stringbykey("visa5",sc_fdackeys,":",",")
				break
			case "fadcSetting6":
				visa_address = stringbykey("visa6",sc_fdackeys,":",",")
				break
		endswitch

		string tempnamestr = "fdac_window_resource"
		try
			variable viRM = openFastDACconnection(tempnamestr, visa_address, verbose=0)
			nvar tempname = $tempnamestr
			setfadcSpeed(tempname,str2num(s.popStr))
		catch
			// reset error code, so VISA connection can be closed!
			variable err = GetRTError(1)

			viClose(tempname)
			viClose(viRM)
			// reopen normal instrument connections
			sc_OpenInstrConnections(0)
			// silent abort
			abortonvalue 1,10
		endtry
			// close temp visa connection
			viClose(tempname)
			viClose(viRM)
			sc_OpenInstrConnections(0)
			return 0
	else
		// do nothing
		return 0
	endif
	// reopen normal instrument connections
	sc_OpenInstrConnections(0)
end


function scfw_update_all_fdac([option])
	// Ramps or updates all FastDac outputs
	string option // {"fdacramp": ramp all fastdacs to values currently in fdacvalstr, "fdacrampzero": ramp all to zero, "updatefdac": update fdacvalstr from what the dacs are currently at}
	svar sc_fdackeys
	wave/t fdacvalstr
	wave/t old_fdacvalstr

	if (paramisdefault(option))
		option = "fdacramp"
	endif

	// TOOD: refactor with scf_getFDInfoFromID()/scf_getChannelNumsOnFD() etc

	// open temporary connection to FastDACs
	// Either ramp fastdacs or update fdacvalstr
	variable i=0,j=0,output = 0, numDACCh = 0, startCh = 0, viRM = 0
	string visa_address = "", tempnamestr = "fdac_window_resource"
	variable numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",","))
	for(i=0;i<numDevices;i+=1)
		numDACCh = str2num(stringbykey("numDACCh"+num2istr(i+1),sc_fdackeys,":",","))
		if(numDACCh > 0)
			visa_address = stringbykey("visa"+num2istr(i+1),sc_fdackeys,":",",")
			viRM = openFastDACconnection(tempnamestr, visa_address, verbose=0)
			nvar tempname = $tempnamestr
			try
				strswitch(option)
					case "fdacramp":
						for(j=0;j<numDACCh;j+=1)
							output = str2num(fdacvalstr[startCh+j][1])
							if(output != str2num(old_fdacvalstr[startCh+j]))
								rampmultipleFDAC(tempname, num2str(startCh+j), output)
							endif
						endfor
						break
					case "fdacrampzero":
						for(j=0;j<numDACCh;j+=1)
							rampmultipleFDAC(tempname, num2str(startCh+j), 0)
						endfor
						break
					case "updatefdac":
						variable value
						for(j=0;j<numDACCh;j+=1)
							// getfdacOutput(tempname,j)
							value = getfdacOutput(tempname,j) // j only because this is PER DEVICE
							scfw_updateFdacValStr(startCh+j, value, update_oldValStr=1)
						endfor
						break
				endswitch
			catch
				// reset error code, so VISA connection can be closed!
				variable err = GetRTError(1)

				viClose(tempname)
				viClose(viRM)
				// reopen normal instrument connections
				sc_OpenInstrConnections(0)
				// silent abort
				abortonvalue 1,10
			endtry

				// close temp visa connection
				viClose(tempname)
				viClose(viRM)
		endif
		startCh =+ numDACCh
	endfor
end

function scfw_update_fdac(action) : ButtonControl
	string action
	svar sc_fdackeys
	wave/t fdacvalstr
	wave/t old_fdacvalstr
	nvar fd_ramprate

	scfw_update_all_fdac(option=action)

	// reopen normal instrument connections
	sc_OpenInstrConnections(0)
end

function scfw_update_fadc(action) : ButtonControl
	string action
	svar sc_fdackeys
	variable i=0, j=0

	// TOOD: refactor with scf_getFDInfoFromID()/scf_getChannelNumsOnFD() etc

	string visa_address = "", tempnamestr = "fdac_window_resource"
	variable numDevices = str2num(stringbykey("numDevices",sc_fdackeys,":",","))
	variable numADCCh = 0, startCh = 0, viRm = 0
	for(i=0;i<numDevices;i+=1)
		numADCch = scf_getFDInfoFromDeviceNum(i+1, "numADC")
//		numADCCh = str2num(stringbykey("numADCCh"+num2istr(i+1),sc_fdackeys,":",","))
		if(numADCCh > 0)
			visa_address = scf_getFDVisaAddress(i+1)
//			visa_address = stringbykey("visa"+num2istr(i+1),sc_fdackeys,":",",")
			viRm = openFastDACconnection(tempnamestr, visa_address, verbose=0)
			nvar tempname = $tempnamestr
			try
				for(j=0;j<numADCCh;j+=1)
					getfadcChannel(tempname,startCh+j)
				endfor
			catch
				// reset error
				variable err = GetRTError(1)

				viClose(tempname)
				viClose(viRM)
				// reopen normal instrument connections
				sc_OpenInstrConnections(0)
				// silent abort
				abortonvalue 1,10
			endtry

			// close temp visa connection
			viClose(tempname)
			viClose(viRM)
		endif
		startCh += numADCCh
	endfor
	// reopen normal instrument connections
	sc_OpenInstrConnections(0)
end


function scfw_CreateControlWaves(numDACCh,numADCCh)
	variable numDACCh,numADCCh

	// create waves for DAC part
	make/o/t/n=(numDACCh) fdacval0 = "0"				// Channel
	make/o/t/n=(numDACCh) fdacval1 = "0"				// Output /mV
	make/o/t/n=(numDACCh) fdacval2 = "-1000,1000"	// Limits /mV
	make/o/t/n=(numDACCh) fdacval3 = ""					// Labels
	make/o/t/n=(numDACCh) fdacval4 = "10000"			// Ramprate limit /mV/s
	variable i=0
	for(i=0;i<numDACCh;i+=1)
		fdacval0[i] = num2istr(i)
	endfor
	concatenate/o {fdacval0,fdacval1,fdacval2,fdacval3,fdacval4}, fdacvalstr
	duplicate/o/R=[][1] fdacvalstr, old_fdacvalstr
	make/o/n=(numDACCh) fdacattr0 = 0
	make/o/n=(numDACCh) fdacattr1 = 2
	concatenate/o {fdacattr0,fdacattr1,fdacattr1,fdacattr1,fdacattr1}, fdacattr

	//create waves for ADC part
	make/o/t/n=(numADCCh) fadcval0 = "0"	// Channel
	make/o/t/n=(numADCCh) fadcval1 = ""		// Input /mV  (initializes empty otherwise false reading)
	make/o/t/n=(numADCCh) fadcval2 = ""		// Record (1/0)
	make/o/t/n=(numADCCh) fadcval3 = ""		// Wave Name
	make/o/t/n=(numADCCh) fadcval4 = ""		// Calc (e.g. ADC0*1e-6)
	for(i=0;i<numADCCh;i+=1)
		fadcval0[i] = num2istr(i)
		fadcval3[i] = "wave"+num2istr(i)
		fadcval4[i] = "ADC"+num2istr(i)
	endfor
	concatenate/o {fadcval0,fadcval1,fadcval2,fadcval3,fadcval4}, fadcvalstr
	make/o/n=(numADCCh) fadcattr0 = 0
	make/o/n=(numADCCh) fadcattr1 = 2
	make/o/n=(numADCCh) fadcattr2 = 32
	concatenate/o {fadcattr0,fadcattr0,fadcattr2,fadcattr1,fadcattr1}, fadcattr


	variable/g sc_printfadc = 0
	variable/g sc_saverawfadc = 0
	variable/g sc_ResampleFreqCheckfadc = 0 // Whether to use resampling
	variable/g sc_ResampleFreqfadc = 100 // Resampling frequency if using resampling


	// clean up
	killwaves fdacval0,fdacval1,fdacval2,fdacval3,fdacval4
	killwaves fdacattr0,fdacattr1
	killwaves fadcval0,fadcval1,fadcval2,fadcval3,fadcval4
	killwaves fadcattr0,fadcattr1,fadcattr2
end

function scfw_SetGUIinteraction(numDevices)
	variable numDevices

	// edit interaction mode popup menus if nessesary
	switch(numDevices)
		case 1:
			popupMenu fadcSetting2, disable=2
			popupMenu fadcSetting3, disable=2
			popupMenu fadcSetting4, disable=2
			popupMenu fadcSetting5, disable=2
			popupMenu fadcSetting6, disable=2
			break
		case 2:
			popupMenu fadcSetting3, disable=2
			popupMenu fadcSetting4, disable=2
			popupMenu fadcSetting4, disable=2
			popupMenu fadcSetting5, disable=2
			popupMenu fadcSetting6, disable=2
			break
		case 3:
			popupMenu fadcSetting4, disable=2
			popupMenu fadcSetting5, disable=2
			popupMenu fadcSetting6, disable=2
			break
		case 4:
			popupMenu fadcSetting5, disable=2
			popupMenu fadcSetting6, disable=2
			break
		case 5:
			popupMenu fadcSetting6, disable=2
			break
		default:
			if(numDevices > 6)
				print("[WARNINIG] \"FastDAC GUI\": More than 6 devices are hooked up.")
				print("Call \"setfadcSpeed\" to set the speeds of the devices not displayed in the GUI.")
			endif
	endswitch
end
	