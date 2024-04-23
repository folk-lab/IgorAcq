#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#include <Reduce Matrix Size>
#include <Waves Average>
#include <FilterDialog> menus=0
#include <Split Axis>
#include <WMBatchCurveFitIM>
#include <Decimation>
#include <Wave Arithmetic Panel>


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
			scfw_CreateControlWaves()
			print "[FastDAC] Init to default values"
		else
			print "[Warning] \"scfw_fdacCheckForOldInit\": Bad user input - Init to default values"
			scfw_CreateControlWaves()
			response = -1
		endif
	else
		// Init to default values
		scfw_CreateControlWaves()
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


function scfw_CreateControlWaves()
//creates all waves and strings necessary for initfastDAC()
	wave fdacvalstr, dac_table
	wave fadcvalstr, adc_table
	
	variable numdacch=dimsize(dac_table,0)
	variable numadcch=dimsize(adc_table,0)
	
	variable i
	
	duplicate/o dac_table, fdacvalstr
	duplicate/o adc_table, fadcvalstr

	duplicate/o dac_table, old_fdacvalstr
	make/o/n=(numDACCh) fdacattr0 = 0
	make/o/n=(numDACCh) fdacattr1 = 2
	concatenate/o {fdacattr0,fdacattr1,fdacattr1,fdacattr1,fdacattr1}, fdacattr

	make/o/n=(numADCCh) fadcattr0 = 0
	make/o/n=(numADCCh) fadcattr1 = 2
	make/o/n=(numADCCh) fadcattr2 = 32
	concatenate/o {fadcattr0,fadcattr0,fadcattr2,fadcattr1,fadcattr1, fadcattr2, fadcattr2, fadcattr1, fadcattr2}, fadcattr /// removed 8 since resampling is now done by default


	
	// create waves for LI
	make/o/t/n=(4,2) LIvalstr
	LIvalstr[0][0] = "Amp"
	LIvalstr[1][0] = "Freq (Hz)"
	LIvalstr[2][0] = "Channels"
	LIvalstr[3][0] = "Cycles"
	LIvalstr[][1] = ""
	
	make/o/n=(4,2) LIattr = 0
	LIattr[][1] = 2
	
	make/o/t/n=(3,2) LIvalstr0
	LIvalstr0[0][0] = "Amp"
	LIvalstr0[0][1] = "Time (ms)"
	LIvalstr0[1,2][] = ""
	
	make/o/n=(3,2) LIattr0 = 0

	// create waves for AWG
	make/o/t/n=(11,2) AWGvalstr
	AWGvalstr[0][0] = "Amp"
	AWGvalstr[0][1] = "Time (ms)"
	AWGvalstr[1,10][] = ""
	make/o/n=(10,2) AWGattr = 2
	AWGattr[0][] = 0
	
	// AW0
	make/o/t/n=(11,2) AWGvalstr0
	AWGvalstr0[0][0] = "Amp"
	AWGvalstr0[0][1] = "Time (ms)"
	AWGvalstr0[1,10][] = ""
	make/o/n=(10,2) AWGattr0 = 0
	//AW1
	make/o/t/n=(11,2) AWGvalstr1
	AWGvalstr1[0][0] = "Amp"
	AWGvalstr1[0][1] = "Time (ms)"
	AWGvalstr1[1,10][] = ""
	make/o/n=(10,2) AWGattr1 = 0
	
	// create waves for AWGset
	make/o/t/n=(3,2) AWGsetvalstr
	AWGsetvalstr[0][0] = "AW0 Chs"
	AWGsetvalstr[1][0] = "AW1 Chs"
	AWGsetvalstr[2][0] = "Cycles"
	AWGsetvalstr[][1] = ""
	
	make/o/n=(3,2) AWGsetattr = 0
	AWGsetattr[][1] = 2
	
	variable /g sc_printfadc = 0
	variable /g sc_saverawfadc = 0
	variable /g sc_demodphi = 0
	variable /g sc_demody = 0
	variable /g sc_hotcold = 0
	variable /g sc_hotcolddelay = 0
	variable /g sc_plotRaw = 0
	variable /g sc_wnumawg = 0
	variable /g tabnumAW = 0
	variable /g sc_ResampleFreqfadc = 100 // Resampling frequency if using resampling
	string   /g sc_freqAW0 = ""
	string   /g sc_freqAW1 = ""
	string   /g sc_nfreq = "60,180,300"
	string   /g sc_nQs = "50,150,250"
	
	
	// instrument wave
	// make some waves needed for the scancontroller window
	variable /g sc_instrLimit = 20 // change this if necessary, seeems fine
	make /o/N=(sc_instrLimit,3) instrBoxAttr = 2
	make /t/o/N=(sc_instrLimit,3) sc_Instr

	sc_Instr[0][0] = "openFastDAC(\"xxxxx\", verbose=0)"
	//sc_Instr[1][0] = "openLS370connection(\"ls\", \"http://lksh370-xld.qdev-b111.lab:49300/api/v1/\", \"bfbig\", verbose=1)"
	//sc_Instr[2][0] = "openIPS120connection(\"ips1\",\"GPIB::25::INSTR\", 9.569, 9000, 182, verbose=0, hold = 1)"
	sc_Instr[0][2] = "getFDstatus()"
	//sc_Instr[1][2] = "getls370Status(\"ls\")"
	//sc_Instr[2][2] = "getipsstatus(ips1)"
	//sc_Instr[3][2] = "getFDstatus(\"fd2\")"
	//sc_Instr[4][2] = "getFDstatus(\"fd3\")"


	// clean up
	killwaves fdacattr0,fdacattr1
	killwaves fadcattr0,fadcattr1,fadcattr2
end

function scw_OpenInstrButton(action) : Buttoncontrol
	string action
	sc_openInstrConnections(1)
end

function scfw_update_fadc(action) : ButtonControl
	string action
	svar sc_fdackeys
	wave/t fadcvalstr
	variable i=0

	variable numADCCh
	numADCch = dimsize(fadcvalstr,0); 
	variable temp
	for(i=0;i<numADCCh;i+=1)
		temp= get_one_FADCChannel(i)
		fadcvalstr[i][1] = num2str(temp)
	endfor
	return numADCCh
end


function scfw_update_fdac(action) : ButtonControl
	string action
	svar sc_fdackeys
	wave/t fdacvalstr
	wave/t old_fdacvalstr
	variable numDACCh
	numDACCh=scfw_update_all_fdac(option=action)
	return numDACCh
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



function scfw_update_all_fdac([option])
	// Ramps or updates all FastDac outputs
	string option // {"fdacramp": ramp all fastdacs to values currently in fdacvalstr, "fdacrampzero": ramp all to zero, "updatefdac": update fdacvalstr from what the dacs are currently at}
	wave/t fdacvalstr
	wave/t old_fdacvalstr
	wave/t DAC_channel
	variable ramprate

	if (paramisdefault(option))
		option = "fdacramp"
	endif
	
	// Either ramp fastdacs or update fdacvalstr
	variable i=0,j=0,output = 0, startCh = 0, numDACCh
	numDACCh = dimsize(DAC_channel,0)
	

			try
				strswitch(option)
					case "fdacramp":
						for(j=0;j<numDACCh;j+=1)
							output = str2num(fdacvalstr[j][1])
							if(output != str2num(old_fdacvalstr[j]))
							ramprate=str2num(fdacvalstr[j][4])
								rampmultipleFDAC(num2str(j), output,ramprate=ramprate)
							endif
						endfor
						break
					case "fdacrampzero":
						for(j=0;j<numDACCh;j+=1)
						ramprate=str2num(fdacvalstr[j][4])
							rampmultipleFDAC(num2str(j), 0,ramprate=ramprate)
						endfor
					break

					case "updatefdac":
						variable value
						for(j=0;j<numDACCh;j+=1)
							value=get_one_FDACChannel(j)
							scfw_updateFdacValStr(j, value, update_oldValStr=1)
						endfor
						break
				endswitch
			catch
			
				
				// silent abort
				abortonvalue 1,10
			endtry
			
			return numDACCh
		
	
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

// set update speed for ADC (all FD_boxes must have the same speed)

////////////////////////////////
///////// utility functions //// (scu_...)
////////////////////////////////

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



Function scu_assertSeparatorType(string list_string, string assert_separator)
    // Validates that the list_string uses the assert_separator exclusively.
    // If it finds an alternative common separator ("," or ";"), it raises an error.
    // This ensures data string consistency, especially in functions that process delimited lists.

    
    // Check if the desired separator is not found in the list_string
    If (strsearch(list_string, assert_separator, 0) < 0)
        // Prepare for potential error messaging
        String buffer
        String calling_func = GetRTStackInfo(2)  // Identifies the function making the call for error context
        
        // Determine the nature of the mismatch based on the asserted separator
        StrSwitch (assert_separator)
            Case ",":
                // If the assert_separator is a comma but a semicolon is found instead
                If (strsearch(list_string, ";", 0) >= 0)
                    // Format and abort with an error message
                    SPrintF buffer, "ERROR[scu_assertSeparatorType]: In function \"%s\" Expected separator = %s     Found separator = ;\r", calling_func, assert_separator
                    Abort buffer
                EndIf
                Break
            
            Case ";":
                // If the assert_separator is a semicolon but a comma is found instead
                If (strsearch(list_string, ",", 0) >= 0)
                    // Format and abort with an error message
                    SPrintF buffer, "ERROR[scu_assertSeparatorType]: In function \"%s\" Expected separator = %s     Found separator = ,\r", calling_func, assert_separator
                    Abort buffer
                EndIf
                Break
            
            Default:
                // If any other separator is asserted but a comma or semicolon is found
                If (strsearch(list_string, ",", 0) >= 0 || strsearch(list_string, ";", 0) >= 0)
                    // Format and abort with a generic error message covering both common separators
                    SPrintF buffer, "ERROR[scu_assertSeparatorType]: In function \"%s\" Expected separator = %s     Found separator = , or ;\r", calling_func, assert_separator
                    Abort buffer
                EndIf
                Break
        EndSwitch      
    EndIf
End

Function/S scu_getChannelNumbers(string channels)
    // This function converts a string of channel identifiers (either names or numbers)
    // into a comma-separated list of channel numbers for FastDAC.
    // It ensures that the channels are properly formatted and exist within the FastDAC configuration.
    
    // Assert that the channels string uses commas as separators
    scu_assertSeparatorType(channels, ",")
    
    // Initialize variables for processing
    String new_channels = "", err_msg
    Variable i = 0
    String ch
    
    // Process for FastDAC channels

        Wave/T fdacvalstr  // Assuming fdacvalstr contains FastDAC channel info
        for(i=0;i<itemsinlist(channels, ",");i+=1)
            // Extract and trim each channel identifier from the list
            ch = stringfromlist(i, channels, ",")
            ch = removeLeadingWhitespace(ch)
            ch = removeTrailingWhiteSpace(ch)
            
            // Check if the channel identifier is not numeric and not empty
            if(numtype(str2num(ch)) != 0 && cmpstr(ch,""))
                // Search for the channel identifier in FastDAC configuration
                duplicate/o/free/t/r=[][3] fdacvalstr fdacnames
                findvalue/RMD=[][3]/TEXT=ch/TXOP=5 fdacnames
                if(V_Value == -1)  // If not found, abort with error
                    sprintf err_msg "ERROR[scu_getChannelNumbers]:No FastDAC channel found with name %s", ch
                    abort err_msg
                else  // If found, use the corresponding channel number
                    ch = fdacvalstr[V_value][0]
                endif
            endif
            // Add the processed channel to the new_channels list
            new_channels = addlistitem(ch, new_channels, ",", INF)
        endfor

    
    // Clean up: Remove the trailing comma from the new_channels string
    if(strlen(new_channels) > 0)
        new_channels = new_channels[0,strlen(new_channels)-1]
    endif
    
    return new_channels
End




	
function initScanVars(S, [instrIDx, startx, finx, channelsx, numptsx, delayx, rampratex, instrIDy, starty, finy, channelsy, numptsy, rampratey, delayy, x_label, y_label, startxs, finxs, startys, finys, alternate, interlaced_channels, interlaced_setpoints, comments])
    // Initializes scanning parameters within a ScanVars struct for both 1D and 2D scanning operations.
    // It accommodates a range of scan configurations, including alternate and interlaced scanning modes.
    //
    // PARAMETERS:
    // S: Reference to a ScanVars struct to be initialized with scan parameters.
    // instrIDx, instrIDy: Instrument IDs for x and y scanning axes. If instrIDy is omitted, instrIDx is used for both axes.
    // startx, finx, starty, finy: Start and end points for scanning in the x and y directions.
    // channelsx, channelsy: Channel identifiers for x and y axes.
    // numptsx, numptsy: Number of points to scan in the x and y directions.
    // delayx, delayy: Delay after each step in x and y axes, applicable for slow scans.
    // rampratex, rampratey: Ramp rates for the x and y axes.
    // x_label, y_label: Labels for the x and y axes.
    // startxs, finxs, startys, finys: Comma-separated strings for multiple start/end points for each channel.
    // alternate: Controls scan direction (start->fin or fin->start).
    // interlaced_channels, interlaced_setpoints: For interlaced scanning modes.
    // comments: Comments or notes regarding the scan.
    
    struct ScanVars &S
    variable instrIDx, instrIDy
    variable startx, finx, numptsx, delayx, rampratex
    variable starty, finy, numptsy, delayy, rampratey
    variable alternate
    string channelsx
    string channelsy
    string x_label, y_label
	 string startxs, finxs, startys, finys
	 string interlaced_channels, interlaced_setpoints
    string comments
        nvar filenum

    
	// Handle Optional Strings
	x_label = selectString(paramIsDefault(x_label), x_label, "")
	channelsx = selectString(paramisdefault(channelsx), channelsx, "")

	y_label = selectString(paramIsDefault(y_label), y_label, "")
	channelsy = selectString(paramisdefault(channelsy), channelsy, "")

	startxs = selectString(paramisdefault(startxs), startxs, "")
	finxs = selectString(paramisdefault(finxs), finxs, "")
	startys = selectString(paramisdefault(startys), startys, "")
	finys = selectString(paramisdefault(finys), finys, "")
	
	interlaced_channels = selectString(paramisdefault(interlaced_channels), interlaced_channels, "")
	interlaced_setpoints = selectString(paramisdefault(interlaced_setpoints), interlaced_setpoints, "")

	comments = selectString(paramisdefault(comments), comments, "")

 // Assigning instrument IDs and checking for defaults
    S.instrIDx = instrIDx
    S.instrIDy = ParamIsDefault(instrIDy) ? instrIDx : instrIDy

	S.lims_checked = 0// Flag that gets set to 1 after checks on software limits/ramprates etc has been carried out (particularly important for fastdac scans which has no limit checking for the sweep)

	S.channelsx = channelsx
	S.startx = startx
	S.finx = finx 
	S.numptsx = numptsx
	S.rampratex = rampratex
	S.delayx = delayx  // delay after each step for Slow scans (has no effect for Fastdac scans)

	// For 2D scans
	S.is2d = numptsy > 1 ? 1 : 0
	S.channelsy = channelsy
	S.starty = starty 
	S.finy = finy
	S.numptsy = numptsy > 1 ? numptsy : 1  // All scans have at least size 1 in y-direction (1 implies a 1D scan)
	S.rampratey = rampratey
	S.delayy = delayy // delay after each step in y-axis (e.g. settling time after x-axis has just been ramped from fin to start quickly)

	// For specific scans
	S.alternate = alternate // Allows controlling scan from start -> fin or fin -> start (with 1 or -1)
	S.duration = NaN // Can specify duration of scan rather than numpts or sweeprate  
	S.readVsTime = 0 // Set to 1 if doing a readVsTime
	
	
	// For interlaced scans
	S.interlaced_channels = interlaced_channels
	S.interlaced_setpoints = interlaced_setpoints
	if (cmpstr(interlaced_channels, "") != 0  && cmpstr(interlaced_setpoints, "") != 0) // if string are NOT empty. cmpstr returns 0, if strings are equal
		S.interlaced_y_flag = 1 
		variable non_interlaced_numptsy = numptsy 
		S.interlaced_num_setpoints = ItemsInList(StringFromList(0, interlaced_setpoints, ";"), ",")
		S.numptsy = numptsy * S.interlaced_num_setpoints
		printf "NOTE: Interlace scan, numptsy will increase from %d to %d\r" ,non_interlaced_numptsy, S.numptsy

	endif
	
	

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
	S.direction = 1   // For keeping track of scan direction when using alternating scan
	S.never_save = 0  // Set to 1 to make sure these ScanVars are never saved (e.g. if using to get throw away values for getting an ADC reading)
	S.filenum = filenum
end

function get_dacListIDs(S)

	struct ScanVars &S
	string  new_channels

	// working out DACLIstIDs for x channels
	new_channels=scu_getChannelNumbers(S.channelsx) /// this returns a string with x DAC channels
	wave numericwave
	wave/t dac_channel
	variable i
	S.daclistids=S.channelsx
	StringToListWave(S.daclistids)
	string returnlist=""

	for (i = 0; i<dimsize(numericwave, 0); i=i+1)
		returnlist=returnlist+dac_channel[numericwave[i]]+","
	endfor
	S.dacListIDs=returnlist;

	// working out DACLIstIDs for y channels
	new_channels=scu_getChannelNumbers(S.channelsy) /// this returns a string with x DAC channels
	S.dacListIDs_y=S.channelsy
	returnlist=""
	if((S.is2d==1)&& (strlen(S.dacListIDs_y)>1))
		StringToListWave(S.dacListIDs_y)

		for (i = 0; i<dimsize(numericwave, 0); i=i+1)
			returnlist=returnlist+dac_channel[numericwave[i]]+","
		endfor
		S.dacListIDs_y=returnlist;
	endif



end


function/S scf_getRecordedFADCinfo(info_name, [column])
	// Return a list of strings for specified column in fadcattr based on whether "record" is ticked
	// Valid info_name ("calc_names", "raw_names", "calc_funcs", "inputs", "channels")

	//column specifies whether another column of checkboxes need to be satisfied, There is
	// notch = 5, demod = 6, resample = 8,
	string info_name
	variable column
	variable i
	wave fadcattr
	wave/t adc_channel

	string return_list = ""
	wave/t fadcvalstr
	for (i = 0; i<dimsize(fadcvalstr, 0); i++)

		if (paramIsDefault(column))

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
						//S.adcListIDs=scf_getRecordedFADCinfo("adcListIDs")
					case "adcListIDs":
						return_list = addlistItem(adc_channel[i], return_list, ";", INF)
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

		else
        
        	if (fadcattr[i][2] == 48 && fadcattr[i][column] == 48) // Checkbox checked
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
        	
        endif
        
    endfor
    return return_list
end

function scv_setChannels (S, channelsx, channelsy, [fastdac])
    // Set S.channelsx and S.channelys converting channel labels to numbers where necessary
    struct ScanVars &S
    string channelsx, channelsy
    variable fastdac

    s.channelsx = scu_getChannelNumbers(channelsx)

	if (numtype(strlen(channelsy)) != 0 || strlen(channelsy) == 0)  // No Y set at all
		s.channelsy = ""
	else
		s.channelsy = scu_getChannelNumbers(channelsy)
    endif
    
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
	//wave/t dacvalstr
	wave/t fdacvalstr
	for(i=0;i<ItemsInList(channels, ",");i+=1)
		channel = StringFromList(i, channels, ",")

	
			buffer = fdacvalstr[str2num(channel)][3] // Grab name from fdacvalstr
			if (cmpstr(buffer, "") == 0)
				buffer = "FD"+channel
			endif
	

		if (cmpstr(xlabelfriendly, "") != 0)
			buffer = ", "+buffer
		endif
		xlabelfriendly += buffer
	endfor
	if (strlen(xlabelfriendly)>0)
		xlabelfriendly = xlabelfriendly + " (mV)"
	endif
	return xlabelfriendly
end

function scv_setSetpoints(S, itemsx, startx, finx, itemsy, starty, finy, startxs, finxs, startys, finys)
	// Sets up start and end setpoints for scanning, adjusting for both 1D and 2D scans, and handles interlaced scan configurations.
	// PARAMETERS:
	// S: ScanVars structure to be modified with start and end setpoints.
	// itemsx, itemsy: Identifiers for the scanning items/channels in x and y directions.
	// startx, finx, starty, finy: Start and end points for the scan in x and y directions.
	// startxs, finxs, startys, finys: Comma-separated strings for multiple start/end points per channel.

	struct ScanVars &S
	variable startx, finx, starty, finy
	string itemsx, startxs, finxs, itemsy, startys, finys

	string starts, fins  // Strings to modify in format_setpoints
	int i

	// Initialize string keys for storing individual channel setpoints
	S.IDstartxs = ""; S.IDfinxs = ""

	// Handle x-direction setpoints
	If (Strlen(startxs) == 0 && Strlen(finxs) == 0)   // Single start/end for all itemsx
		S.startx = startx
		S.finx = finx
		scv_formatSetpoints(startx, finx, itemsx, starts, fins)  // Format single start/ends into lists

		// Assign formatted starts and ends to each channel
		For (i = 0; i < ItemsInList(S.channelsx); i += 1)
			S.IDstartxs = ReplaceStringByKey(StringFromList(i, S.channelsx), S.IDstartxs, StringBykey(StringFromList(i, S.channelsx), S.IDstartxs) + "," + StringFromList(i, starts, ","))
			S.IDfinxs = ReplaceStringByKey(StringFromList(i, S.channelsx), S.IDfinxs, StringBykey(StringFromList(i, S.channelsx), S.IDfinxs) + "," + StringFromList(i, fins, ","))
		EndFor

		S.startxs = starts
		S.finxs = fins
	ElseIf (Strlen(startxs) > 0 && Strlen(finxs) > 0)   // Multiple start/end points provided
		scv_sanitizeSetpoints(startxs, finxs, itemsx, starts, fins)  // Clean and format provided start/ends
		S.startx = Str2Num(StringFromList(0, starts, ","))
		S.finx = Str2Num(StringFromList(0, fins, ","))

		// Repeat assignment for multiple setpoints
		For (i = 0; i < ItemsInList(S.daclistIDs); i += 1)
			S.IDstartxs = ReplaceStringByKey(StringFromList(i, S.daclistIDs), S.IDstartxs, StringBykey(StringFromList(i, S.daclistIDs), S.IDstartxs) + "," + StringFromList(i, starts, ","))
			S.IDfinxs = ReplaceStringByKey(StringFromList(i, S.daclistIDs), S.IDfinxs, StringBykey(StringFromList(i, S.daclistIDs), S.IDfinxs) + "," + StringFromList(i, fins, ","))
		EndFor

		S.startxs = starts
		S.finxs = fins
	Else
		Abort "Both startxs and finxs must be provided if one is provided."
	EndIf


	// Handle y-direction setpoints for 2D scans
	if (S.is2d)
		if (strlen(startys) == 0 && strlen(finys) == 0)  // Single start/end for Y
			s.starty = starty
			s.finy = finy
			scv_formatSetpoints(starty, finy, itemsy, starts, fins)
			s.startys = starts
			s.finys = fins
		elseif (!(numtype(strlen(startys)) != 0 || strlen(startys) == 0) && !(numtype(strlen(finys)) != 0 || strlen(finys) == 0)) // Multiple start/end for Ys
			scv_sanitizeSetpoints(startys, finys, itemsy, starts, fins)
			s.starty = str2num(StringFromList(0, starts, ","))
			s.finy = str2num(StringFromList(0, fins, ","))
			s.startys = starts
			s.finys = fins
		else
			abort "Something wrong with Y part. Note: If either of startys/finys is provided, both must be provided"
		endif

		if (S.interlaced_y_flag)
			// Slightly adjust the endpoints such that the DAC steps are the same as without interlaced
			variable num_setpoints = S.interlaced_num_setpoints
			variable num_dac_steps = S.numptsy/num_setpoints
			variable spacing, original_finy, original_starty, new_finy

			// Adjust the single finy
			original_finy = S.finy
			original_starty = S.starty
			//        	spacing = (original_finy-original_starty)/(num_dac_steps-1)/num_setpoints
			//        	new_finy = original_finy + spacing*(num_setpoints-1)

			spacing = (original_finy-original_starty)/num_dac_steps
			new_finy = original_starty + spacing*(num_dac_steps)
			S.finy = new_finy

			// Adjust the finys
			string new_finys = ""

			for (i=0;i<itemsinList(S.finys, ",");i++)
				original_finy = str2num(stringfromList(i, S.finys, ","))
				original_starty = str2num(stringfromList(i, S.startys, ","))
				//	        	spacing = (original_finy-original_starty)/(num_dac_steps-1)/num_setpoints
				//	        	new_finy = original_finy + spacing*(num_setpoints-1)
				spacing = (original_finy-original_starty)/num_dac_steps
				new_finy = original_starty + spacing*(num_dac_steps)
				new_finys = AddListItem(num2str(new_finy), new_finys, ",", INF)
			endfor
			scv_sanitizeSetpoints(S.startys, new_finys, itemsy, starts, fins)
			//			new_finys = new_finys[0,strlen(new_finys)-2] // Remove the comma Igor stupidly leaves behind...
			S.finys = fins
		endif
	else
		S.startys = ""
		S.finys = ""
	endif
end

function scv_setFreq([S,A])
	// Set S.samplingFreq, S.numADCs, S.measureFreq
	// measureFreq is set now based on maxADCs (numADCs per fastDAC selected for recording)
	// for now assume all ADC are set to max speed
	
	Struct ScanVars &S
	Struct AWGvars &A
	int i; //string instrIDs
	S.samplingFreq=1/82*1e6;
	variable maxADCs=fd_getmaxADCs(S)
	S.maxADCs=maxADCs;
	S.measureFreq = S.samplingFreq/S.maxADCs
	
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

Function scv_formatSetpoints(variable start, variable fin, string items, String &starts, String &fins)
    // Formats start and end setpoints into comma-separated strings for a list of items (channels).
    // This is useful for preparing setpoints for FastDAC operations, where each channel needs a start and end value.
    // PARAMETERS:
    // start: The start setpoint to be applied to each item.
    // fin: The end setpoint to be applied to each item.
    // items: A comma-separated string of item identifiers (e.g., channel numbers).
    // &starts, &fins: References to strings where the formatted start and end setpoints will be stored.

   
    // Initialize the output strings
    starts = ""
    fins = ""
    
    // Loop through each item and append the start and end setpoints to the output strings
    Variable i
    For (i = 0; i < ItemsInList(items, ","); i += 1)
        // Append formatted start and end values to the respective strings
        starts += Num2Str(start) + ","
        fins += Num2Str(fin) + ","
    EndFor
    
    // Remove the trailing comma from the formatted strings
    If (Strlen(starts) > 0)
        starts = Starts[0, Strlen(starts) - 2]  // Adjust to remove the last comma
    EndIf
    If (Strlen(fins) > 0)
        fins = Fins[0, Strlen(fins) - 2]  // Adjust to remove the last comma
    EndIf
End



function scv_sanitizeSetpoints(start_list, fin_list, items, starts, fins)
	// Makes sure starts/fins make sense for number of items and have no bad formatting
	// Modifies the starts/fins strings passed in
	string start_list, fin_list, items
	string &starts, &fins
	
	string buffer
	
	scu_assertSeparatorType(items, ",")  // "," because quite often user entered
	scu_assertSeparatorType(start_list, ",")  // "," because entered by user
	scu_assertSeparatorType(fin_list, ",")	// "," because entered by user
	
	if (itemsinlist(items, ",") != itemsinlist(start_list, ",") || itemsinlist(items, ",") != itemsinlist(fin_list, ","))
		sprintf buffer, "ERROR[scv_sanitizeSetpoints]: length of start_list/fin_list/items not equal!!! start_list:(%s), fin_list:(%s), items:(%s)\r", start_list, fin_list, items
		abort buffer
	endif
	
	starts = replaceString(" ", start_list, "")
	fins = replaceString(" ", fin_list, "")
	
	// Make sure the starts/ends don't have commas at the end (igor likes to put them in unnecessarily when making lists)
	if (cmpstr(starts[strlen(starts)-1], ",") == 0)  // Zero if equal (I know... stupid)
		starts = starts[0, strlen(starts)-2]
	endif
	if (cmpstr(fins[strlen(fins)-1], ",") == 0)  // Zero if equal (I know... stupid)
		fins = fins[0, strlen(fins)-2]
	endif
end


Function RampStartFD(Struct ScanVars &S, [Variable ignore_lims, Variable x_only, Variable y_only])
    // Moves DAC channels to their starting points before a scan begins. 
    // It checks the direction of the scan and ramps the channels accordingly.
    // PARAMETERS:
    // S: A reference to a ScanVars structure containing scan settings.
    // ignore_lims: (Optional) If set, software limits for DAC output are ignored.
    // x_only, y_only: (Optional) Flags to specify ramping in only one direction.

 

    Variable i, setpoint

    // Ramp x-direction channels to their start if they exist and y_only is not set
    If (StrLen(S.channelsx) != 0 && y_only != 1) 
        scu_assertSeparatorType(S.channelsx, ",")  // Assert that channels are separated by commas
        For (i = 0; i < ItemsInList(S.channelsx, ","); i += 1)
            //NVAR fdID = $(StringFromList(i, S.daclistIDs))  // Dynamic variable access based on channel ID
            
            // Determine the setpoint based on scan direction
            If (S.direction == 1)
                setpoint = Str2Num(StringFromList(i, S.startxs, ","))
            ElseIf (S.direction == -1)
                setpoint = Str2Num(StringFromList(i, S.finxs, ","))
            Else
                Abort "ERROR[RampStartFD]: S.direction not set to 1 or -1."
            EndIf
            
            // Ramp the DAC channel to the determined setpoint
            rampMultipleFDAC(StringFromList(i, S.channelsx, ","), setpoint, ramprate = S.rampratex)
        EndFor
    EndIf

    // Similarly, ramp y-direction channels to their start if they exist and x_only is not set
    If (StrLen(S.channelsy) != 0 && x_only != 1) 
        scu_assertSeparatorType(S.channelsy, ",")
        For (i = 0; i < ItemsInList(S.channelsy, ","); i += 1)
            rampMultipleFDAC(StringFromList(i, S.channelsy, ","), Str2Num(StringFromList(i, S.startys, ",")), ramprate = S.rampratey)
        EndFor
    EndIf
End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////// Initializing a Scan //////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function initializeScan(S, [init_graphs, y_label])
    // Opens instrument connection, initializes waves to store data, opens and tiles graphs, opens abort window.
    // init_graphs: set to 0 if you want to handle opening graphs yourself
    struct ScanVars &S
    variable init_graphs
    string y_label
    y_label = selectString(paramIsDefault(y_label), y_label, "")
    init_graphs = paramisdefault(init_graphs) ? 1 : init_graphs
    variable fastdac

    // Make sure waves exist to store data
    sci_initializeWaves(S)

    // Set up graphs to display recorded data
    if (init_graphs)
	    string activeGraphs
	    activeGraphs = scg_initializeGraphs(S, y_label = y_label)
	    scg_arrangeWindows(activeGraphs)
	 endif

    // Open Abort window
    scg_openAbortWindow()

    // Save struct to globals
    scv_setLastScanVars(S)
end


function sci_initializeWaves(S)  // TODO: rename
   // Initializes the waves necessary for recording scan
	// Need 1D and 2D waves for the raw data coming from the fastdac (2D for storing, not necessarily displaying)
	// 	Need 2D waves for either the raw data, or filtered data if a filter is set
	// (If a filter is set, the raw waves should only ever be plotted 1D)
	//	(This will be after calc (i.e. don't need before and after calc wave))
	
    struct ScanVars &S
    struct AWGVars AWG
    fd_getGlobalAWG(AWG)
    
    variable numpts  //Numpts to initialize wave with, note: for Filtered data, this number is reduced
    string wavenames, wn, rawwavenames, rwn
    variable raw, j
    wave fadcattr
    nvar sc_demody, sc_hotcold
    
    rawwavenames = sci_get1DWaveNames(1, S.using_fastdac)
    
	for (raw = 0; raw<2; raw++)                                      // (raw = 0 means calc waves)
		wavenames = sci_get1DWaveNames(raw, S.using_fastdac)
		sci_sanityCheckWavenames(wavenames)

		for (j=0; j<itemsinlist(wavenames);j++)

			wn = stringFromList(j, wavenames)
			rwn = stringFromList(j, rawwavenames)
			string wavenum = rwn[3,strlen(rwn)]

			if (S.using_fastdac && fadcattr[str2num(wavenum)][8] == 48) // Checkbox checked
				numpts = (raw) ? S.numptsx : scfd_postFilterNumpts(S.numptsx, S.measureFreq)
			else
				numpts = S.numptsx
			endif

			sci_init1DWave(wn, numpts, S.startx, S.finx)

			if (S.is2d == 1)
				sci_init2DWave(wn+"_2d", numpts, S.startx, S.finx, S.numptsy, S.starty, S.finy)
			endif


			//initializing for hot/cold waves, not sure if i need to, if we are just saving in the end?
			        if(sc_hotcold && raw == 0)
			
			             //sci_init1DWave(wn+"hot", S.numptsx/AWG.waveLen, S.startx, S.finx) //dont need to initialize since im not plotting
			          	//sci_init1DWave(wn+"cold", S.numptsx/AWG.waveLen, S.startx, S.finx)
			
			          	if(S.is2d == 1)
			          		sci_init2DWave(wn+"hot_2d", S.numptsx/AWG.waveLen, S.startx, S.finx, S.numptsy, S.starty, S.finy)
			          		sci_init2DWave(wn+"cold_2d", S.numptsx/AWG.waveLen, S.startx, S.finx, S.numptsy, S.starty, S.finy)
			          	endif
			
			        endif

//			//initializing 1d waves for demodulation
			if (S.using_fastdac && raw == 0 && fadcattr[str2num(wavenum)][6] == 48)
				sci_init1DWave(wn+"x", S.numptsx/AWG.waveLen/AWG.numCycles, S.startx, S.finx)
				sci_init1DWave(wn+"y", S.numptsx/AWG.waveLen/AWG.numCycles, S.startx, S.finx)

				//initializing 2d waves for demodulation
				if (s.is2d == 1)
					sci_init2DWave(wn+"x_2d", S.numptsx/AWG.waveLen/AWG.numCycles, S.startx, S.finx, S.numptsy, S.starty, S.finy)

					if (sc_demody == 1)
						sci_init2DWave(wn+"y_2d", S.numptsx/AWG.waveLen/AWG.numCycles, S.startx, S.finx, S.numptsy, S.starty, S.finy)
					endif

				endif

			endif

		endfor

	endfor

	// Setup Async measurements if not doing a fastdac scan (workers will look for data made here)
//	if (!S.using_fastdac) 
//		sc_findAsyncMeasurements()
//	endif
	
end



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


function/S sci_get1DWaveNames(raw, fastdac, [for_plotting])
    // Return a list of Raw or Calc wavenames (without any checks)
    variable raw, fastdac // 1 for True, 0 for False
    variable for_plotting // Return the list of wavenames that are ticked for plotting (currently for ScanController only, has no effect for Fastdac scans)
    
    string wavenames = ""
	if (fastdac == 1)
		if (raw == 1)
			wavenames = scf_getRecordedFADCinfo("raw_names")
		else
			wavenames = scf_getRecordedFADCinfo("calc_names")
		endif
    else  // Regular ScanController
        wave sc_RawRecord, sc_RawWaveNames, sc_RawPlot
        wave sc_CalcRecord, sc_CalcWaveNames, sc_CalcPlot
        if (raw == 1)
            duplicate/free/o sc_RawRecord, recordWave
            duplicate/free/o sc_RawPlot, plotWave
            duplicate/free/o/t sc_RawWaveNames, waveNameWave
        else
            duplicate/free/o sc_CalcRecord, recordWave
            duplicate/free/o sc_CalcPlot, plotWave            
            duplicate/free/o/t sc_CalcWaveNames, waveNameWave
        endif
        variable i=0
        for (i = 0; i<numpnts(waveNameWave); i++)     
            if (recordWave[i] && (for_plotting == 0 || (for_plotting == 1 && plotWave[i])))  // If recorded and either not requesting plot list, or plotting is also ticked
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

function/S scg_initializeGraphs(S , [y_label])
    // Initialize graphs that are going to be recorded
    // Returns list of Graphs that data is being plotted in
    // Sets sc_frequentGraphs (the list of graphs that should be updated through a 1D scan, where the rest should only get updated at the end of 1D scans)
    
    // Note: For Fastdac
    //     Raw is e.g. ADC0, ADC1. Calc is e.g. wave1, wave2 (or specified names)
    //     Either the Raw 1D graphs or if not plot_raw, then the Calc 1D graphs should be updated
    
    
    // Note: For Regular Scancontroller
    //     Raw is the top half of ScanController, Calc is the middle part (with Calc scripts)
    //     All 1D graphs should be updated
    
    struct ScanVars &S
	 string y_label
	 y_label = selectstring(paramIsDefault(y_label), y_label, "")
	 
	 string/g sc_frequentGraphs = ""  // So that fd_record_values and RecordValues know which graphs to update while reading.
    string graphIDs = ""
    variable i,j
    string waveNames
    string buffer
    variable raw
    nvar sc_plotRaw 
    wave fadcattr
    
    string rawwaveNames = sci_get1DWaveNames(1, S.using_fastdac, for_plotting=1)
    for (i = 0; i<2; i++)  // i = 0, 1 for raw = 1, 0 (i.e. go through raw graphs first, then calc graphs)
      	raw = !i
      	
		// Get the wavenames (raw or calc, fast or slow) that we need to make graphs for 
      	waveNames = sci_get1DWaveNames(raw, S.using_fastdac, for_plotting=1)
      	if (cmpstr(waveNames, "") == 0) // If the strings ARE equal
      		continue
      	endif
      	
      	// Specific to Fastdac
      	if (S.using_fastdac)
	      	// If plot raw not ticked, then skip making raw graphs
	    	if(raw && sc_plotRaw == 0)
	    		continue
	    	endif
	    	
	    	if (raw)
	    		// Plot 1D ONLY for raw (even if a 2D scan), but also show noise spectrum along with the 1D raw plot
	    		buffer = scg_initializeGraphsForWavenames(waveNames, S.x_label, y_label="mV", spectrum = 1, mFreq = S.measureFreq)
	    		for (j=0; j<itemsinlist(waveNames); j++)
	    			// No *2 in this loop, because only plots 1D graphs
		    		sc_frequentGraphs = addlistItem(stringfromlist(j, buffer, ";"), sc_frequentGraphs, ";")	    		
	    		endfor
	    	else
	    		// Plot 1D (and 2D if 2D scan)
	    		buffer = scg_initializeGraphsForWavenames(waveNames, S.x_label, y_label=y_label, for_2d=S.is2d, y_label_2d = S.y_label)
	    		if (!sc_plotRaw)
	    			for (j=0; j<itemsinlist(waveNames); j++)
	    				// j*(1+S.is2d) so that only 1D graphs are collected in the sc_frequentGraphs
			    		sc_frequentGraphs = addlistItem(stringfromlist(j*(1+S.is2d), buffer, ";"), sc_frequentGraphs, ";")	    		
		    		endfor
		      	endif
	      		
	      		// Graphing specific to using demod
	      		if (S.using_fastdac)	
	      			for (j=0; j<itemsinlist(waveNames); j++)
						string rwn = StringFromList(j, rawWaveNames)
						string cwn = StringFromList(j, WaveNames)
						string ADCnum = rwn[3,INF]
				
						if (fadcattr[str2num(ADCnum)][6] == 48) // checks which demod box is checked
							buffer += scg_initializeGraphsForWavenames(cwn + "x", S.x_label, for_2d=S.is2d, y_label=y_label, append_wn = cwn + "y")
						endif
					endfor
				endif
	    	endif
	    	
      	// Specific to Regular Scancontroller
		else
	   		// Plot 1D (and 2D if 2D scan)
	   		
			buffer = scg_initializeGraphsForWavenames(waveNames, S.x_label, y_label=y_label, for_2d=S.is2d, y_label_2d = S.y_label)
	
			// Always add 1D graphs to plotting list
			for (j=0; j<itemsinlist(waveNames); j++)
				// j*(1+S.is2d) so that only 1D graphs are collected in the sc_frequentGraphs
	    		sc_frequentGraphs = addlistItem(stringfromlist(j*(1+S.is2d), buffer, ";"), sc_frequentGraphs, ";")	    		
    		endfor
		endif
	 
       graphIDs = graphIDs + buffer
    endfor

    return graphIDs
end


function/S scg_initializeGraphsForWavenames(wavenames, x_label, [for_2d, y_label, append_wn, spectrum, mFreq, y_label_2d])
	// Ensures a graph is open and tiles graphs for each wave in comma separated wavenames
	// Returns list of graphIDs of active graphs
	// append_wavename would append a wave to every single wavename in wavenames (more useful for passing just one wavename)
	// spectrum -- Also shows a noise spectrum of the data (useful for fastdac scans)
	string wavenames, x_label, y_label, append_wn, y_label_2d
	variable for_2d , spectrum, mFreq
	
	spectrum = paramisDefault(spectrum) ? 0 : 1
	y_label = selectString(paramisDefault(y_label), y_label, "")
	append_wn = selectString(paramisDefault(append_wn), append_wn, "")
	y_label_2d = selectString(paramisDefault(y_label_2d), y_label_2d, "")
	
	string y_label_1d = y_label //selectString(for_2d, y_label, "")  // Only use the y_label for 1D graphs if the scan is 1D (otherwise gets confused with y sweep gate)

	string wn, openGraphID, graphIDs = ""
	variable i
	for (i = 0; i<ItemsInList(wavenames); i++)  // Look through wavenames that are being recorded
	    wn = selectString(cmpstr(append_wn, ""), StringFromList(i, wavenames), StringFromList(i, wavenames)+";" +append_wn)
	    
		if (spectrum)
			wn = stringfromlist(0,wn)
			string ADCnum = wn[3,INF] //would fail if this was done with calculated waves, but we dont care about it
			openGraphID = scg_graphExistsForWavename(wn + ";pwrspec" + ADCnum +";..." ) // weird naming convention on igors end.
		else
			openGraphID = scg_graphExistsForWavename(wn)
		endif

		// 1D graphs
		if (cmpstr(openGraphID, "")) // Graph is already open (str != "")
			scg_setupGraph1D(openGraphID, x_label, y_label= selectstring(cmpstr(y_label_1d, ""), wn, wn +" (" + y_label_1d + ")"))
			wn = StringFromList(i, wavenames) 
		else
			wn = StringFromList(i, wavenames)
			
	      	if (spectrum)
	      		scg_open1Dgraph(wn, x_label, y_label=selectstring(cmpstr(y_label_1d,""), wn, wn +" (" + y_label_1d + ")"))
	      		openGraphID = winname(0,1)
				string wn_powerspec = scfd_spectrum_analyzer($wn, mFreq, "pwrspec" + ADCnum)
				scg_twosubplot(openGraphID, wn_powerspec, logy = 1, labelx = "Frequency (Hz)", labely ="pwr", append_wn = wn_powerspec + "int", append_labely = "cumul. pwr")
			else 
	      		scg_open1Dgraph(wn, x_label, y_label=selectstring(cmpstr(y_label_1d, ""), wn, wn + " (" + y_label_1d + ")"), append_wn = append_wn)
	      		openGraphID = winname(0,1)			
			endif 
			
	   endif
		
		graphIDs = addlistItem(openGraphID, graphIDs, ";", INF) 	
	   openGraphID = ""
		
		// 2D graphs
		if (for_2d)
			string wn2d = wn + "_2d"
			openGraphID = scg_graphExistsForWavename(wn2d)
			if (cmpstr(openGraphID, "")) // Graph is already open (str != "")
				scg_setupGraph2D(openGraphID, wn2d, x_label, y_label_2d, heat_label = selectstring(cmpstr(y_label_1d,""), wn, wn +" ("+y_label_1d +")"))
			else 
	       	scg_open2Dgraph(wn2d, x_label, y_label_2d, heat_label = selectstring(cmpstr(y_label_1d,""), wn, wn +" ("+y_label_1d +")"))
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

function scg_twosubplot(graphID, wave2name,[logy, logx, labelx, labely, append_wn, append_labely])
//creates a subplot with an existing wave and GraphID with wave2
//wave2 will appear on top, append_Wn will be appended to wave2 position
	string graphID, wave2name, labelx, labely, append_wn, append_labely
	variable logy,logx
	wave wave2 = $wave2name
	
	labelx = selectString(paramIsDefault(labelx), labelx, "")
	labely = selectString(paramIsDefault(labely), labely, "")
	append_wn = selectString(paramIsDefault(append_wn), append_wn, "")
	append_labely = selectString(paramIsDefault(append_labely), append_labely, "")
	
	ModifyGraph /W = $graphID axisEnab(left)={0,0.40}
	AppendToGraph /W = $graphID /r=l2/B=b2 wave2 
	label b2 labelx
	label l2 labely
	
	if(!paramisDefault(logy))
		ModifyGraph log(l2)=1
	endif
	
	if(!paramisDefault(logx))
		ModifyGraph log(b2)=1
	endif
	
	ModifyGraph /W = $graphID axisEnab(l2)={0.60,1}
	ModifyGraph /W = $graphID freePos(l2)=0
	ModifyGraph /W = $graphID freePos(b2)={0,l2}
	ModifyGraph rgb($wave2name)=(39321,39321,39321)
    
    if (cmpstr(append_wn, ""))
    	appendtograph /W = $graphID /l= r1 /b=b3  $append_wn
    	legend
    	label r1 append_labely
    	ModifyGraph /W = $graphID axisEnab(r1)={0.60,1}
		ModifyGraph /W = $graphID freePos(r1)=0
		ModifyGraph /W = $graphID freePos(b3)={0,r1}
		ModifyGraph noLabel(b3)=2
		
		if(!paramisDefault(logy))
			ModifyGraph log(r1)=1
		endif
	
		if(!paramisDefault(logx))
			ModifyGraph log(b3)=1
		endif
    	
    endif
	
	Modifygraph /W = $graphID axisontop(l2)=1
	Modifygraph /W = $graphID axisontop(b2)=1
	Modifygraph /W = $graphID axisontop(r1)=1
	ModifyGraph lblPosMode(l2)=2
	ModifyGraph lblPosMode(b2)=4
	ModifyGraph lblPosMode(r1)=2
	
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


function scg_open1Dgraph(wn, x_label, [y_label, append_wn])
    // Opens 1D graph for wn
    string wn, x_label, y_label, append_wn
    
    y_label = selectString(paramIsDefault(y_label), y_label, "")
    append_wn = selectString(paramIsDefault(append_wn), append_wn, "")
    
    display $wn
    
    if (cmpstr(append_wn, ""))
    	appendtograph /r $append_wn
//    	makecolorful()
    	legend
    endif
    
    setWindow kwTopWin, graphicsTech=0
    
    scg_setupGraph1D(WinName(0,1), x_label, y_label=y_label)
end


function scg_open2Dgraph(wn, x_label, y_label, [heat_label])
    // Opens 2D graph for wn
    string wn, x_label, y_label, heat_label
    heat_label = selectstring(paramisdefault(heat_label), heat_label, "")
    wave w = $wn
    if (dimsize(w, 1) == 0)
    	abort "Trying to open a 2D graph for a 1D wave"
    endif
    
    display
    setwindow kwTopWin, graphicsTech=0
    appendimage $wn
    scg_setupGraph2D(WinName(0,1), wn, x_label, y_label, heat_label = heat_label)
end


function scg_setupGraph1D(graphID, x_label, [y_label, datnum])
    // Sets up the axis labels, and datnum for a 1D graph
    string graphID, x_label, y_label
    variable datnum
    
    // this seems like a change from back in the day when alternate bias was getting used
    // not sure why this is necessary. But I will comment it out for now.
    // As the 1d and 2d display datnums do not agree. 2024-02-12: Johann
//    datnum = paramisdefault(datnum) ? 0 : datnum // alternate_bias OFF is default

    
    // Handle Defaults
    y_label = selectString(paramIsDefault(y_label), y_label, "")
    
    
    // Sets axis labels, datnum etc
    setaxis/w=$graphID /a
    Label /W=$graphID bottom, x_label

    Label /W=$graphID left, y_label

	nvar filenum
	datnum = filenum
	
//	if (datnum == 0)
//		datnum = filenum - 1
//	endif
	
    TextBox /W=$graphID/C/N=datnum/A=LT/X=1.0/Y=1.0/E=2 "Dat"+num2str(datnum)
end


function scg_setupGraph2D(graphID, wn, x_label, y_label, [heat_label])
    string graphID, wn, x_label, y_label, heat_label
    svar sc_ColorMap
    
    heat_label = selectstring(paramisdefault(heat_label), heat_label, "")
    // Sets axis labels, datnum etc
    Label /W=$graphID bottom, x_label
    Label /W=$graphID left, y_label

    modifyimage /W=$graphID $wn ctab={*, *, $sc_ColorMap, 0}
    colorscale /W=$graphID /c/n=$sc_ColorMap /e/a=rc image=$wn, heat_label  

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


function scg_updateFrequentGraphs()
	// updates activegraphs which takes about 15ms
	// ONLY update 1D graphs for speed (if this takes too long, the buffer will overflow)
 	svar/z sc_frequentGraphs
	if (svar_Exists(sc_frequentGraphs))
		variable i
			for(i=0;i<itemsinlist(sc_frequentGraphs,";");i+=1)
			doupdate/w=$stringfromlist(i,sc_frequentGraphs,";")
		endfor
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

	// Note: This can take >100ms when 2D plots are large (e.g. 10000x2000)
//	doupdate // do this just once during the sleep function 
// Checked ScanFastDacSlow with ScanFastDacSlow2D(fd, -1, 1, "OHV*9950", 101, 0.0, -1, 1, "OHC(10M)", 3, delayy=0.1, comments="graph update test")
// and the the graphs update during sweep. 
	do
		try
			//scs_checksweepstate()
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


function sc_checkBackup()
	// the path `server` should point to /measurement-data
	//     which has been mounted as a network drive on your measurement computer
	// if it is, backups will be created in an appropriate directory
	//      qdot-server.phas.ubc.ca/measurement-data/<hostname>/<username>/<exp>
	svar sc_hostname

	GetFileFolderInfo/Z/Q/P=server  // Check if data path is definded
	if(v_flag != 0 || v_isfolder !=1)
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

//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////// Taking Data and processing //////////////////////////////////  scfd_... (ScanControllerFastdacData...)
//////////////////////////////////////////////////////////////////////////////////////////


function scfd_postFilterNumpts(raw_numpts, measureFreq)  // TODO: Rename to NumptsAfterFilter
	// Returns number of points that will exist after applying lowpass filter specified in ScanController_Fastdac
	variable raw_numpts, measureFreq
	nvar targetFreq = sc_ResampleFreqFadc
	variable ret_nofpnts
	RatioFromNumber (targetFreq / measureFreq)
	ret_nofpnts=raw_numpts
	
	if (V_numerator < V_denominator)
		ret_nofpnts=round(raw_numpts*(V_numerator)/(V_denominator))  // TODO: Is this actually how many points are returned?
	endif

	return ret_nofpnts

end

function scfd_resampleWaves2(w, measureFreq, targetFreq)
	// resamples wave w from measureFreq
	// to targetFreq (which should be lower than measureFreq)
	Wave w
	variable measureFreq, targetFreq
	struct scanvars S
	scv_getLastScanVars(S)
	wave wcopy
	duplicate /o  w wcopy
	w = x
	RatioFromNumber (targetFreq / measureFreq)
	if (V_numerator > V_denominator)
		string cmd
		printf cmd "WARNING[scfd_resampleWaves]: Resampling will increase number of datapoints, not decrease! (ratio = %d/%d)\r", V_numerator, V_denominator
	endif
	setscale x 0, ((w[dimsize(w,0) - 1] - w[0])/S.sweeprate), wcopy
	resample /rate=(targetfreq)/N=201/E=3 wcopy
	copyscales w wcopy
	duplicate /o wcopy w
	killwaves wcopy

	// TODO: Need to test N more (simple testing suggests we may need >200 in some cases!)
	// TODO: Need to decide what to do with end effect. Possibly /E=2 (set edges to 0) and then turn those zeros to NaNs? 
	// TODO: Or maybe /E=3 is safest (repeat edges). The default /E=0 (bounce) is awful.

end


function scfd_resampleWaves(w, measureFreq, targetFreq)
	// resamples wave w from measureFreq
	// to targetFreq (which should be lower than measureFreq)
	Wave w
	variable measureFreq, targetFreq
	variable numpntsx
	duplicate/o w w_before


	RatioFromNumber (targetFreq / measureFreq)
	resample /UP=(V_numerator) /DOWN=(V_denominator) /N=201 /E=0 w

//	print "Num and den are",v_numerator, v_denominator
	if (V_numerator > V_denominator)
		string cmd
		//print "Resampling would increase number of datapoints, not decrease, therefore resampling is skipped"
		duplicate/o w_before w

	endif
	// TODO: Need to test N more (simple testing suggests we may need >200 in some cases!) [Vahid: I'm not sure why only N=201 is a good choice.]
	// TODO: Need to decide what to do with end effect. Possibly /E=2 (set edges to 0) and then turn those zeros to NaNs? 
	// TODO: Or maybe /E=1 is safest, this was tested with random noise around 0 and around a finite value
	numpntsx=dimsize(w,0)
	return numpntsx
end


function scfd_notch_filters(wave wav, variable measureFreq, [string Hzs, string Qs])
	// wav is the wave to be filtered.
	// If not specified the filtered wave will have the original name plus '_nf' 
	// This function is used to apply the notch filter for a choice of frequencies and Q factors
	// if the length of Hzs and Qs do not match then Q is chosen as the first Q is the list
	// It is expected that wav will have an associated JSON file to convert measurement times to points, via fd_getmeasfreq below
	// EXAMPLE usage: notch_filters(dat6430cscurrent_2d, Hzs="60,180,300", Qs="50,150,250")
	
	Hzs = selectString(paramisdefault(Hzs), Hzs, "60")
	Qs = selectString(paramisdefault(Qs), Qs, "50")
	variable num_Hz = ItemsInList(Hzs, ",")
	variable num_Q = ItemsInList(Qs, ",")

		
	// Creating wave variables
	variable num_rows = dimsize(wav, 0)
	variable padnum = 2^ceil(log(num_rows) / log(2)); 
	duplicate /o wav tempwav // tempwav is the one we will operate on during the FFT
	variable offset = mean(wav)
	tempwav -= offset // make tempwav have zero average to reduce end effects associated with padding
	
	//Transform
	FFT/pad=(padnum)/OUT=1/DEST=temp_fft tempwav

	wave /c temp_fft
	duplicate/c/o temp_fft fftfactor // fftfactor is the wave to multiple temp_fft by to zero our certain frequencies
   //fftfactor = 1 - exp(-(x - freq)^2 / (freq / Q)^2)
	
	// Accessing freq conversion for wav

	variable freqfactor = 1/(measureFreq * dimdelta(wav, 0)) // freq in wav = Hz in real seconds * freqfactor


	fftfactor=1
	variable freq, Q, i
	for (i=0;i<num_Hz;i+=1)
		freq = freqfactor * str2num(stringfromlist(i, Hzs, ","))
		Q = ((num_Hz==num_Q) ? str2num(stringfromlist(i, Qs, ",")): str2num(stringfromlist(0, Qs, ","))) // this sets Q to be the ith item on the list if num_Q==num_Hz, otherwise it sets it to be the first value
		fftfactor -= exp(-(x - freq)^2 / (freq / Q)^2)
	endfor
	temp_fft *= fftfactor

	//Inverse transform
	IFFT/DEST=temp_ifft  temp_fft
	wave temp_ifft
	
	temp_ifft += offset

	redimension/N=(num_rows, -1) temp_ifft
	copyscales wav, temp_ifft
	duplicate /o temp_ifft wav
end

function scfd_sqw_analysis(wave wav, int delay, int wavelen, string wave_out)

// this function separates hot (plus/minus) and cold(plus/minus) and returns  two waves for hot and cold //part of CT

	variable numpts = numpnts(wav)
	duplicate /free /o wav, wav_copy
	//variable N = numpts/(wavelen/StepsInCycle) // i believe this was not done right in silvias code
	variable N = numpts/wavelen
	
	Make/o/N=(N) cold1, cold2, hot1, hot2
	wave wav_new

	Redimension/N=(wavelen/4,4,N) wav_copy //should be the dimension of fdAW AWG.Wavelen
	DeletePoints/M=0 0,delay, wav_copy
	reducematrixSize(wav_copy,0,-1,1,0,-1,4,1,"wav_new") // fdAW 

	cold1 = wav_new[0][0][p] 
	cold2 = wav_new[0][2][p] 
	hot1 = wav_new[0][1][p]   
	hot2 = wav_new[0][3][p]   
	
	duplicate/o cold1, $(wave_out + "cold")
	duplicate/o hot1, $(wave_out + "hot") 
	
	wave coldwave = $(wave_out + "cold")
	wave hotwave = $(wave_out + "hot")
	
	coldwave=(cold1+cold2)/2
	hotwave=(hot1+hot2)/2

	//matrixtranspose hotwave
	//matrixtranspose coldwave

	CopyScales /I wav, coldwave, hotwave
	
	//duplicate/o hot, nument
	//nument=cold-hot;

end


function scfd_demodulate(wav, harmonic, nofcycles, period, wnam)//, [append2hdf])
	
	wave wav
	variable harmonic, nofcycles, period //, append2hdf
	string wnam
	
	nvar sc_demodphi
	variable cols, rows
	string wn_x=wnam + "x"
	string wn_y=wnam + "y"
	wave wav_x=$wn_x
	wave wav_y=$wn_y
	
	
	duplicate /o wav, wav_copy
	wav_copy = x
	variable last_x = wav_copy[INF]
	wav_copy = wav
	Redimension/N=(-1,2) wav_copy
	cols=dimsize(wav_copy,0)
	rows=dimsize(wav_copy,1)
	make /o/n=(cols) sine1d
	
	//demodulation in x
	sine1d=sin(2*pi*(harmonic*p/period) + sc_demodphi/180*pi)
	matrixop /o sinewave=colrepeat(sine1d,rows)
	matrixop /o temp=wav_copy*sinewave
	copyscales wav_copy, temp
	temp=temp*pi/2;
	ReduceMatrixSize(temp, 0, -1, (cols/period/nofcycles), 0,-1, rows, 1,wn_x)
	wave wav_x=$wn_x
	Redimension/N=(-1) wav_x //demod.x wave
	setscale/I x, 0, last_x, wav_x //Manually setting scale to be inclusive of last point
	
	//Demodulation in y
	sine1d=cos(2*pi*(harmonic*p/period) + sc_demodphi /180 *pi)
	matrixop /o sinewave=colrepeat(sine1d,rows)
	matrixop /o temp=wav_copy*sinewave
	copyscales wav_copy, temp
	temp=temp*pi/2;
	ReduceMatrixSize(temp, 0, -1, (cols/period/nofcycles), 0,-1, rows, 1,wn_y)
	wave wav_y=$wn_y
	Redimension/N=(-1) wav_y //demod.y wave
	setscale/I x, 0, last_x, wav_y //Manually setting scale to be inclusive of last point

end 

function /s scfd_spectrum_analyzer(wave data, variable samp_freq, string wn)
	// Built in powerspectrum function
	duplicate /o /free data spectrum
	SetScale/P x 0,1/samp_freq,"", spectrum
	variable nr=dimsize(spectrum,0);  // number of points in x-direction
	variable le=2^(floor(log(nr)/log(2))); // max factor of 2 less than total num points
	make /o /free slice
	make /o /free w_Periodogram
	make /o /free powerspec
	
	variable i=0
	duplicate /free /o/rmd=[][i,i] spectrum, slice
	redimension /n=(dimsize(slice, 0)) slice
	
	DSPPeriodogram/R=[0,(le-1)]/PARS/NODC=2/DEST=W_Periodogram slice  //there is a normalization flag
	duplicate/o w_Periodogram, powerspec
	i=1
	do
		duplicate /free /o/rmd=[][i,i] spectrum, slice
		redimension /n=(dimsize(slice, 0)) slice
		DSPPeriodogram/R=[0,(le-1)]/PARS/NODC=2/DEST=W_Periodogram slice
		powerspec = powerspec+W_periodogram
		i=i+1
	while(i<dimsize(spectrum,1))
	//powerspec[0]=nan
	//display powerspec; // SetAxis bottom 0,500
	duplicate /o powerspec, $wn
	integrate powerspec /D = $(wn + "int") // new line
	return wn
end



function scfd_RecordValues(S, rowNum, [AWG_list, linestart, skip_data_distribution, skip_raw2calc])  // TODO: Rename to fd_record_values
	// this function is predominantly used in scanfastdac functions. It is for ramping and recording a certain axis 
	struct ScanVars &S			// Contains all scan details such as instrIDs, xchannels, ychannels...
	variable rowNum, linestart
	variable skip_data_distribution, skip_raw2calc // For recording data without doing any calculation or distribution of data
	struct AWGVars &AWG_list
	
	if(paramisdefault(skip_raw2calc))  // If skip_raw2calc not passed set it to 0
		skip_raw2calc=0
	endif 

		
	// If passed AWG_list with AWG_list.lims_checked == 1 then it will run with the Arbitrary Wave Generator on
	// Note: Only works for 1 FastDAC! Not sure what implementation will look like for multiple yet

	// Check if AWG is going to be used
	Struct AWGVars AWG  // Note: Default has AWG.lims_checked = 0
	if(!paramisdefault(AWG_list))  // If AWG_list passed, then overwrite default
		AWG = AWG_list
	endif 
		 

	// If beginning of scan, record start time
	if (rowNum == 0 && (S.start_time == 0 || numtype(S.start_time) != 0))  
		S.start_time = datetime-date2secs(2024,04,22) 
	endif
	
	// Send command and read values
	//print "sending command and reading"
	scfd_SendCommandAndRead(S, AWG, rowNum, skip_raw2calc=skip_raw2calc) 
	S.end_time = datetime-date2secs(2024,04,22) // this did not work on a MAC but I am not going to change it until I confirm it also does not work on a PC
	
	// Process 1D read and distribute
	if (!skip_data_distribution)
		scfd_ProcessAndDistribute(S, AWG, rowNum) 	
	endif
end

function scfd_checkRawSave()
	nvar sc_Saverawfadc
	string notched_waves = scf_getRecordedFADCinfo("calc_names", column = 5)
	string resamp_waves = scf_getRecordedFADCinfo("calc_names",column = 8)

	if(cmpstr(notched_waves,"") || cmpstr(resamp_waves,""))
		sc_Saverawfadc = 1
	else
		sc_Saverawfadc = 0
	endif
end

Function scfd_SendCommandAndRead(S,AWG_list,rowNum, [ skip_raw2calc])
	// Sends a command for a 1D sweep to FastDAC and records the raw data returned.
	// Optionally skips processing raw data into calculated waves based on skip_raw2calc flag.
	//
	// Parameters:
	// S: Reference to the ScanVars structure containing scanning parameters.
	// AWG_list: Reference to the AWGVars structure containing AWG configuration.
	// rowNum: The row number being processed.
	// skip_raw2calc: Optional flag to skip the conversion of raw waves to calculated waves.

	Struct ScanVars &S
	Struct AWGVars &AWG_list
	Variable rowNum
	Variable skip_raw2calc  // Optional flag to skip processing of raw data
	String cmd_sent  // Command sent to FastDAC (currently not used but initialized)
	Variable numpnts_read=0  // Number of points read in the current operation

	// Default skip_raw2calc to 0 if not provided
	If (ParamIsDefault(skip_raw2calc))
		skip_raw2calc = 0
	EndIf

	// Verify that necessary parameters are set before proceeding
	If (S.samplingFreq == 0 || S.numADCs == 0 || S.numptsx == 0)
		Abort "ERROR[scfd_SendCommandAndRead]: Not enough info in ScanVars to run scan"
	EndIf

	// Start the sweep
	fd_start_sweep(S, AWG_list = AWG_list)
	S.lastread = -1  // Reset the last read index

	//need to reinitialize the raw ADC waves otherwise loadfiles will be confused. If this is not a desired way to handle this,
	//we will need to add a counter to loadfiles to keep track on how many pnts have already been read
	scfd_resetraw_waves()
	// Loop to read data until the expected number of points is reached
	Do
		////                sleep/s 0.1// Short pause to allow for data acquisition

		numpnts_read = loadfiles(S,numpnts_read)  // Load data from files
		scfd_raw2CalcQuickDistribute(0)  // 0 or 1 for if data should be displayed decimated or not during the scan
		scfd_checkSweepstate()
		doupdate

	While (numpnts_read<S.numptsx)  // Continue if not all points are read

	// Update FastDAC and ADC GUI elements
	scfw_update_all_fdac(option="updatefdac")
	scfw_update_fadc("")  // Update FADC display with no additional specification



	//	if(AWG_list.use_awg == 1)  // Reset AWs back to zero (no reason to leave at end of AW)
	//		for(i=0;i<itemsinlist(S.instrIDs);i++)
	//			fdIDname = stringfromlist(i, S.instrIDs)
	//			nvar fdID = $fdIDname
	//			string AW_dacs = scu_getDeviceChannels(fdID, AWG_list.channels_AW0)
	//			AW_dacs = addlistitem(scu_getDeviceChannels(fdID, AWG_list.channels_AW1), AW_dacs, ",", INF)
	//			AW_dacs = removeSeperator(AW_dacs, ",")
	//			AW_dacs = scu_getDeviceChannels(fdID, AW_dacs, reversal = 1)
	//			rampmultiplefdac(fdID, AW_dacs, 0)
	//		endfor
	//	endif
end

//Function TestTask(s)		// This is the function that will be called periodically
//	STRUCT WMBackgroundStruct &s
//	
//	Printf "Task %s called, ticks=%d\r", s.name, s.curRunTicks
//	loadfiles("adc1;adc3")
//	return 0	// Continue background task
//End
//
//Function StartTestTask()
//	Variable numTicks = 2 * 60		// Run every two seconds (120 ticks)
//	CtrlNamedBackground Test, period=numTicks, proc=TestTask
//	CtrlNamedBackground Test, start
//End
//
//Function StopTestTask()
//	CtrlNamedBackground Test, stop
//End


Function loadFiles(S, numPntsRead)
	struct ScanVars &S
	variable numPntsRead    // Loads files based on a specified pattern and updates data waves.
	// Pre-conditions:
	// - 'adcNames' contains a semicolon-separated list of wave names for loading data.
	// - The folder path 'fdTest' must contain files to be loaded.
	// - 'lastRead' variable must hold the index of the last file that was loaded.

	String adcNames = S.adcLists
	String fileList = IndexedFile(fdTest, -1, ".dat") // List all .dat files in fdTest
	String currentFile, testString
	Variable lastRead = S.lastRead // Initialize with the last file index loaded from structure S
	Variable numFiles = ItemsInList(fileList)
	Variable numAdcs = ItemsInList(adcNames) // Number of ADC columns to read in
	Variable i, initPts, addPts, totPts
	Variable adc, lastfile

	do
		lastfile=1 // assumes that the most recent file has already been read in until proven otherwise

		for (i = 0; i < numFiles; i += 1)
			currentFile = StringFromList(i, fileList)
			testString = "*_" + num2str(lastRead + 1) + ".dat" // Pattern of the next file to read

			if (StringMatch(currentFile, testString))
				lastRead += 1 // Increment the index as we are processing this file
				//print currentFile
				LoadWave/Q/O/G/D/A/N=tempWave/P=fdTest currentFile // Load data into temporary waves

				for (adc = 0; adc < numAdcs; adc += 1)
					Wave oneAdc = $StringFromList(adc, adcNames) // Target wave for data
					Wave dataToAdd = $("tempWave" + num2str(adc+1)) // Source wave for data

					WaveStats/Q oneAdc
					initPts = V_npnts
					totPts = (V_npnts + V_numNans)
					WaveStats/Q dataToAdd
					addPts = V_npnts

					oneAdc[initPts, (initPts + addPts - 1)] = dataToAdd[p - initPts] // Copy data
				EndFor
				lastfile=0 // we just read in a new file so perhaps the most recent file has not been read in

				DeleteFile/P=fdTest/Z=1 currentFile // Delete the file after processing
				S.lastRead = lastRead // Update the lastRead index in the structure
				numPntsRead += DimSize($"tempWave0", 0) // Update the total number of points read
				//print numPntsRead
				break // Exit the loop after processing the matching file
			EndIf
		endfor // if we got all the way through the i<numfiles for-loop without ever finding a filename that matches teststring (the next file) then we must have read the latest one


	while(!lastfile)

	return numPntsRead
End





function scfd_ProcessAndDistribute(ScanVars, AWGVars, rowNum)
	// Get 1D wave names, duplicate each wave then resample, notch filter and copy into calc wave (and do calc string)
	struct ScanVars &ScanVars
	struct AWGVars &AWGVars
	variable rowNum
	
	variable i = 0
	string RawWaveNames1D = sci_get1DWaveNames(1, 1)
	string CalcWaveNames1D = sci_get1DWaveNames(0, 1)
	string CalcStrings = scf_getRecordedFADCinfo("calc_funcs")
	nvar sc_ResampleFreqfadc, sc_demody, sc_plotRaw, sc_hotcold, sc_hotcolddelay
	svar sc_nfreq, sc_nQs
	string rwn, cwn, calc_string, calc_str 
	wave fadcattr
	wave /T fadcvalstr
	int resamp
	string wn
	variable numpntsx

	if (itemsinList(RawWaveNames1D) != itemsinList(CalCWaveNames1D))
		abort "Different number of raw wave names compared to calc wave names"
	endif

	for (i=0; i<itemsinlist(RawWaveNames1D); i++)
		resamp=1 //assume we need to resample in the end

		rwn = StringFromList(i, RawWaveNames1D)
		cwn = StringFromList(i, CalcWaveNames1D)
		calc_string = StringFromList(i, CalcStrings)

		duplicate/o $rwn sc_tempwave

		string ADCnum = rwn[3,INF]

		if (fadcattr[str2num(ADCnum)][5] == 48) // checks which notch box is checked
			scfd_notch_filters(sc_tempwave, ScanVars.measureFreq,Hzs=sc_nfreq, Qs=sc_nQs)
		endif

		if(sc_hotcold == 1)
			scfd_sqw_analysis(sc_tempwave, sc_hotcolddelay, AWGVars.waveLen, cwn)
			resamp=0
		endif


		if (fadcattr[str2num(ADCnum)][6] == 48) // checks which demod box is checked
			scfd_demodulate(sc_tempwave, str2num(fadcvalstr[str2num(ADCnum)][7]), AWGVars.numCycles, AWGVars.waveLen, cwn)


			//calc function for demod x
			calc_str = ReplaceString(rwn, calc_string, cwn + "x")
			execute(cwn+"x ="+calc_str)

			//calc function for demod y
			calc_str = ReplaceString(rwn, calc_string, cwn + "y")
			execute(cwn+"y ="+calc_str)
			resamp=0
		endif

		// dont resample for SQW analysis or demodulation after notch filtering resample
		if (resamp==1)
			numpntsx=scfd_resampleWaves(sc_tempwave, ScanVars.measureFreq, sc_ResampleFreqfadc)
			if (rowNum==0 && (ScanVars.is2d))
			wn=cwn+"_2d"
			sci_init2DWave(wn,numpntsx, ScanVars.startx, ScanVars.finx, ScanVars.numptsy, ScanVars.starty, ScanVars.finy)
			endif
		endif


		calc_str = ReplaceString(rwn, calc_string, "sc_tempwave")
		execute("sc_tempwave ="+calc_str)

		duplicate /o sc_tempwave $cwn

		if (ScanVars.is2d)
			// Copy 1D raw into 2D
			wave raw1d = $rwn
			wave raw2d = $rwn+"_2d"
			raw2d[][rowNum] = raw1d[p]

			// Copy 1D calc into 2D
			string cwn2d = cwn+"_2d"
			wave calc2d = $cwn2d
			calc2d[][rowNum] = sc_tempwave[p]


			//Copy 1D hotcold into 2d
			if (sc_hotcold == 1)
				string cwnhot = cwn + "hot"
				string cwn2dhot = cwnhot + "_2d"
				wave cw2dhot = $cwn2dhot
				wave cwhot = $cwnhot
				cw2dhot[][rowNum] = cwhot[p]

				string cwncold = cwn + "cold"
				string cwn2dcold = cwncold + "_2d"
				wave cw2dcold = $cwn2dcold
				wave cwcold = $cwncold
				cw2dcold[][rowNum] = cwcold[p]
			endif


			// Copy 1D demod into 2D
			if (fadcattr[str2num(ADCnum)][6] == 48)
				string cwnx = cwn + "x"
				string cwn2dx = cwnx + "_2d"
				wave dmod2dx = $cwn2dx
				wave dmodx = $cwnx
				dmod2dx[][rowNum] = dmodx[p]

				if (sc_demody == 1)
					string cwny = cwn + "y"
					string cwn2dy = cwny + "_2d"
					wave dmod2dy = $cwn2dy
					wave dmody = $cwny
					dmod2dy[][rowNum] = dmody[p]
				endif

			endif

		endif

		// for powerspec //
		variable avg_over = 5 //can specify the amount of rows that should be averaged over

		if (sc_plotRaw == 1)
			if (rowNum < avg_over)
				if(rowNum == 0)
					duplicate /O/R = [][0,rowNum] $(rwn) powerspec2D
				elseif(waveExists($(rwn + "_2d")))
					duplicate /O/R = [][0,rowNum] $(rwn + "_2d") powerspec2D
				endif
			else
				duplicate /O/R = [][rowNum-avg_over,rowNum] $(rwn + "_2d") powerspec2D
			endif
			scfd_spectrum_analyzer(powerspec2D, ScanVars.measureFreq, "pwrspec" + ADCnum)
		endif
	endfor

	if (!ScanVars.prevent_2d_graph_updates)
		doupdate // Update all the graphs with their new data
	endif

end

function scfd_resetraw_waves()
	string RawWaveNames1D = sci_get1DWaveNames(1, 1)  // Get the names of 1D raw waves
	string rwn
	variable i
	for (i=0; i<itemsinlist(RawWaveNames1D); i++)
		rwn = StringFromList(i, RawWaveNames1D)  // Get the current raw wave name
		wave temp=$rwn
		temp=nan
	endfor
end







function scfd_raw2CalcQuickDistribute(int decim)
	// Function to update graphs as data comes in temporarily, only applies the calc function for the scan
	//decimate is 0 or 1 for if data should be displayed decimated or not during the scan

	variable i = 0
	string RawWaveNames1D = sci_get1DWaveNames(1, 1)  // Get the names of 1D raw waves
	string CalcWaveNames1D = sci_get1DWaveNames(0, 1)  // Get the names of 1D calc waves
	string CalcStrings = scf_getRecordedFADCinfo("calc_funcs")  // Get the calc functions
	string rwn, cwn, calc_string
	wave fadcattr
	wave /T fadcvalstr

	if (itemsinList(RawWaveNames1D) != itemsinList(CalCWaveNames1D))
		abort "Different number of raw wave names compared to calc wave names"
	endif

	for (i=0; i<itemsinlist(RawWaveNames1D); i++)
		rwn = StringFromList(i, RawWaveNames1D)  // Get the current raw wave name
		cwn = StringFromList(i, CalcWaveNames1D)  // Get the current calc wave name
		calc_string = StringFromList(i, CalcStrings)  // Get the current calc function
		duplicate/o $rwn sc_tempwave  // Duplicate the raw wave to a temporary wave

		string ADCnum = rwn[3,INF]  // Extract the ADC number from the raw wave name

		//calc_string = ReplaceString(rwn, calc_string, "sc_tempwave")  // Replace the raw wave name with the temporary wave name in the calc function
		calc_string = ReplaceString(rwn, calc_string, "sc_tempwave")  // Replace the raw wave name with the temporary wave name in the calc function
		execute("sc_tempwave = "+calc_string)  // Execute the calc function

		if (decim==1)
			FDecimateXPosStd(sc_tempwave,cwn,30,2,1)
		elseif (decim!=1)
			duplicate /o sc_tempwave $cwn  // Duplicate the temporary wave to the calc wave
		endif

	endfor
end

function scfd_checkSweepstate()
Svar fd
  	// if abort button pressed then stops FDAC sweep then aborts
	variable errCode
	nvar sc_abortsweep
	nvar sc_pause
  	try
    	scs_checksweepstate()
  	catch
		errCode = GetRTError(1)
		fd_stopFDACsweep()
		if(v_abortcode == -1)  // If user abort
				sc_abortsweep = 0
				sc_pause = 0
		endif
		abortonvalue 1,10
	endtry
end


// Update after checkbox clicked
function scw_CheckboxClicked(ControlName, Value)
	string ControlName
	variable value
	string indexstring
	wave sc_RawRecord, sc_RawPlot, sc_CalcRecord, sc_CalcPlot, sc_measAsync
	nvar sc_PrintRaw, sc_PrintCalc
	nvar/z sc_Printfadc, sc_Saverawfadc, sc_demodx, sc_demody, sc_plotRaw, sc_hotcold // FastDAC specific
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
	elseif(stringmatch(ControlName,"sc_plotRawBox")) // FastDAC window
		sc_plotRaw = value
	elseif(stringmatch(ControlName,"sc_demodyBox")) // FastDAC window
		sc_demody = value
	elseif(stringmatch(ControlName,"sc_hotcoldBox")) // FastDAC window
		sc_hotcold = value

	endif
end






	

Function sc_controlwindows(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
	doWindow/k/z SweepControl  // Attempt to close previously open window just in case
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

function scw_updatewindow(action) : ButtonControl
	string action

	scw_saveConfig()   // write a new config file
end


function/s scw_createConfig()
	wave/t sc_RawWaveNames, sc_RawScripts, sc_CalcWaveNames, sc_CalcScripts, sc_Instr
	wave sc_RawRecord, sc_measAsync, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
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

	// no longer logging instr info, as this is now logged in the config folder many many times
	return configstr
end


function scw_saveConfig()
	nvar lastconfig
	wave sc_Instr, AWGattr,AWGattr0,AWGattr1,AWGsetattr,fadcattr,fdacattr,instrBoxAttr,LIattr,LIattr0,	AWGsetvalstr,AWGvalstr,AWGvalstr0,AWGvalstr1,fadcvalstr,fdacvalstr,LIvalstr,LIvalstr0,old_fdacvalstr 
lastconfig=scu_unixTime()
	string filename = "attr" + num2istr(lastconfig) + ".itx"
	string filename1 = "valstr" + num2istr(lastconfig) + ".itx"
	Save/T/M="\n"/p=config AWGattr,AWGattr0,AWGattr1,AWGsetattr,fadcattr,fdacattr,instrBoxAttr,LIattr,LIattr0 as filename
	Save/T/M="\n"/P=config sc_Instr,AWGsetvalstr,AWGvalstr,AWGvalstr0,AWGvalstr1,fadcvalstr,fdacvalstr,LIvalstr,LIvalstr0,old_fdacvalstr as filename1
end


function scw_loadConfig()
nvar lastconfig
	wave sc_Instr, AWGattr,AWGattr0,AWGattr1,AWGsetattr,fadcattr,fdacattr,instrBoxAttr,LIattr,LIattr0,	AWGsetvalstr,AWGvalstr,AWGvalstr0,AWGvalstr1,fadcvalstr,fdacvalstr,LIvalstr,LIvalstr0,old_fdacvalstr 
	killwaves sc_Instr AWGattr,AWGattr0,AWGattr1,AWGsetattr,fadcattr,fdacattr,instrBoxAttr,LIattr,LIattr0,	AWGsetvalstr,AWGvalstr,AWGvalstr0,AWGvalstr1,fadcvalstr,fdacvalstr,LIvalstr,LIvalstr0,old_fdacvalstr 
	string filename = "attr" + num2istr(lastconfig) + ".itx"
	string filename1 = "valstr" + num2istr(lastconfig) + ".itx"
	
	print "first we had to delete all config waves: valstr, attvals, etc"
	print "Now, load last config waves by manually dragging the following files into Igor"
	print filename1
	print filename
	
	print "then reinitialize FastDAC or scancontroller window under Menu/Panel_Macros/..."
	
	//execute("after1()")
	
end

function scw_addrow(action) : ButtonControl
	string action
	wave/t sc_RawWaveNames=sc_RawWaveNames
	wave sc_RawRecord=sc_RawRecord
	wave sc_RawPlot=sc_RawPlot
	wave sc_CalcPlot=sc_CalcPlot	
	//wave sc_measAsync=sc_measAsync
	wave/t sc_RawScripts=sc_RawScripts
	wave/t sc_CalcWaveNames=sc_CalcWaveNames
	wave sc_CalcRecord=sc_CalcRecord
	wave/t sc_CalcScripts=sc_CalcScripts

	strswitch(action)
		case "addrowraw":
			AppendString(sc_RawWaveNames, "")
			AppendValue(sc_RawRecord, 0)
			AppendValue(sc_RawPlot, 0)			
			//AppendValue(sc_measAsync, 0)
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
	wave sc_CalcPlot=sc_CalcPlot		
	wave sc_measAsync=sc_measAsync
	wave/t sc_RawScripts=sc_RawScripts
	wave/t sc_CalcWaveNames=sc_CalcWaveNames
	wave sc_CalcRecord=sc_CalcRecord
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
	
	//scfd_checkRawSave()
	save_experiment = paramisDefault(save_experiment) ? 1 : save_experiment
	additional_wavenames = SelectString(ParamIsDefault(additional_wavenames), additional_wavenames, "")
	
	if(!paramIsDefault(S))
		scv_setLastScanVars(S)  // I.e save the ScanVars including end_time and any other changed values in case saving fails (which it often does)
	endif

	Struct ScanVars S_ // Note: This will definitely exist for the rest of this function
	scv_getLastScanVars(S_)

	if (aborting)
		S_.end_time = datetime-date2secs(2024,04,22) 
		S_.comments = "aborted, " + S_.comments
	endif
	if (S_.end_time == 0 || numtype(S_.end_time) != 0) // Should have already been set, but if not, this is likely a good guess and prevents a stupid number being saved
		S_.end_time = datetime-date2secs(2024,04,22) 
		S_.comments = "end_time guessed, "+S_.comments
	endif
	
	nvar filenum
	S_.filenum = filenum

	dowindow/k SweepControl // kill scan control window
	printf "Time elapsed: %.2f s \r", (S_.end_time-S_.start_time)
	HDF5CloseFile/A 0 //Make sure any previously opened HDFs are closed (may be left open if Igor crashes)
	
	if(S_.using_fastdac == 0)
		KillDataFolder/z root:async // clean this up for next time
	endif
	SaveToHDF(S_, additional_wavenames=additional_wavenames)

	nvar sc_save_time
	if(save_experiment==1 && (datetime-date2secs(2024,04,22) -sc_save_time)>180.0)
		// save if save_exp=1 and if more than 3 minutes has elapsed since previous saveExp
		saveExp()
		sc_save_time = datetime-date2secs(2024,04,22) 
	endif

//	if(sc_checkBackup())  	// check if a path is defined to backup data
//		 sc_copyNewFiles(S_.filenum, save_experiment=save_experiment)		// copy data to server mount point (nvar filenum gets incremented after HDF is opened)
//	endif

	// add info about scan to the scan history file in /config
	sce_ScanVarsToJson(S_, getrtstackinfo(3), save_to_file=1)
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
	hdfid = OpenHDFFile(0) // Open HDF file (normal - non RAW)

	addMetaFiles(num2str(hdfid), logs_only=1, comments=comments)

	printf "Saving waves [%s] in dat%d.h5\r", wave_names, filenum

	// Now save each wave
	for(ii=0;ii<itemsinlist(wave_names, ",");ii++)
		wn = stringfromlist(ii, wave_names, ",")
		SaveSingleWaveToHDF(wn, hdfid)
	endfor
	CloseHDFFile(num2str(hdfid))
	
	if(sc_checkBackup())  	// check if a path is defined to backup data
		sc_copyNewFiles(current_filenum, save_experiment=0)		// copy data to server mount point (nvar filenum gets incremented after HDF is opened)
	endif
		
	filenum += 1 
end


function/T sce_ScanVarsToJson(S, traceback, [save_to_file])
	// Can be used to save Function calls to a text file
	Struct ScanVars &S
	
	string traceback
	variable save_to_file  // Whether to save to .txt file
	
	// create JSON string
	string buffer = ""
	
	buffer = addJSONkeyval(buffer,"Filenum",num2istr(S.filenum))
	buffer = addJSONkeyval(buffer,"Traceback",traceback,addquotes=1)  // TODO: Remove everything from EndScan onwards (will always be the same and gives no useful extra info)
	buffer = addJSONkeyval(buffer,"x_label",S.x_label,addquotes=1)
	buffer = addJSONkeyval(buffer,"y_label",S.y_label,addquotes=1)
	buffer = addJSONkeyval(buffer,"startx", num2str(S.startx))
	buffer = addJSONkeyval(buffer,"finx",num2str(S.finx))
	buffer = addJSONkeyval(buffer,"numptsx",num2istr(S.numptsx))
	buffer = addJSONkeyval(buffer,"channelsx",S.channelsx,addquotes=1)
	buffer = addJSONkeyval(buffer,"rampratex",num2str(S.rampratex))
	buffer = addJSONkeyval(buffer,"delayx",num2str(S.delayx))

	buffer = addJSONkeyval(buffer,"is2D",num2str(S.is2D))
	buffer = addJSONkeyval(buffer,"starty",num2str(S.starty))
	buffer = addJSONkeyval(buffer,"finy",num2str(S.finy))
	buffer = addJSONkeyval(buffer,"numptsy",num2istr(S.numptsy))
	buffer = addJSONkeyval(buffer,"channelsy",S.channelsy,addquotes=1)
	buffer = addJSONkeyval(buffer,"rampratey",num2str(S.rampratey))
	buffer = addJSONkeyval(buffer,"delayy",num2str(S.delayy))
	
	buffer = addJSONkeyval(buffer,"duration_per_1D_scan",num2str(S.duration))
	buffer = addJSONkeyval(buffer,"alternate",num2istr(S.alternate))	
	buffer = addJSONkeyval(buffer,"readVsTime",num2str(S.readVsTime))
	buffer = addJSONkeyval(buffer,"interlaced_y_flag",num2str(S.interlaced_y_flag))
	buffer = addJSONkeyval(buffer,"interlaced_channels",S.interlaced_channels,addquotes=1)
	buffer = addJSONkeyval(buffer,"interlaced_setpoints",S.interlaced_setpoints,addquotes=1)
	buffer = addJSONkeyval(buffer,"interlaced_num_setpoints",num2str(S.interlaced_num_setpoints))
	
	buffer = addJSONkeyval(buffer,"start_time",num2str(S.start_time, "%.2f"))
	buffer = addJSONkeyval(buffer,"end_time",num2str(S.end_time,"%.2f"))
	buffer = addJSONkeyval(buffer,"using_fastdac",num2str(S.using_fastdac))
	buffer = addJSONkeyval(buffer,"comments",S.comments,addquotes=1)

	buffer = addJSONkeyval(buffer,"numADCs",num2istr(S.numADCs))
	buffer = addJSONkeyval(buffer,"samplingFreq",num2str(S.samplingFreq))
	buffer = addJSONkeyval(buffer,"measureFreq",num2str(S.measureFreq))
	buffer = addJSONkeyval(buffer,"sweeprate",num2str(S.sweeprate))
	buffer = addJSONkeyval(buffer,"adcList",S.adcList,addquotes=1)
	buffer = addJSONkeyval(buffer,"startxs",S.startxs,addquotes=1)
	buffer = addJSONkeyval(buffer,"finxs",S.finxs,addquotes=1)
	buffer = addJSONkeyval(buffer,"startys",S.startys,addquotes=1)
	buffer = addJSONkeyval(buffer,"finys",S.finys,addquotes=1)

	buffer = addJSONkeyval(buffer,"raw_wave_names",S.raw_wave_names,addquotes=1)
	
	
	buffer = prettyJSONfmt(buffer)
	

	
	if (save_to_file)
		// open function call history file (or create it)
		variable hisfile
		open /z/a/p=config hisfile as "FunctionCallHistory.txt"
		
		if(v_flag != 0)
			print "[WARNING] \"saveFuncCall\": Could not open FunctionCallHistory.txt"
		else
			fprintf hisfile, buffer
			fprintf hisfile, "------------------------------------\r\r"
			
			close hisfile
		endif
	endif
	return buffer
end



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function ask_user(question, [type])
    // Popup a confirmation window to user and return answer value
	// type = 0,1,2 for (OK), (Yes/No), (Yes/No/Cancel) returns are V_flag = 1: Yes, 2: No, 3: Cancel
	string question
	variable type
	type = paramisdefault(type) ? 1 : type
	doalert type, question
	return V_flag
end


////////////////////////////////////////////////////////////////
///////////////// Slow ScanController ONLY ////////////////////  scw_... (ScanControlWindow...)
////////////////////////////////////////////////////////////////
// Slow == only slow FastDAC compatible

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
    variable/g sc_abortsweep=0, sc_pause=0, sc_abortnosave=0 // Make sure these are initialized

	string /g sc_hostname = getHostName() // get machine name

	// check if a path is defined to backup data
	//*sc_checkBackup()
	
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
	
			// These arrays should have the same size. Their indeces correspond to each other.
			make/t/o sc_RawWaveNames = {"g1x", "g1y","I_leak","ADC"} // Wave names to be created and saved
			make/o sc_RawRecord = {0,0,0,0} // Whether you want to record and save the data for this wave
			make/o sc_RawPlot = {0,0,0,0} // Whether you want to plot the data for this wave
			make/t/o sc_RawScripts = {"get_one_FADCChannel(channel)","readSRSx(srs)", "readSRSy(srs)","getK2400current(k2400)"}

			// And these waves should be the same size too
			make/t/o sc_CalcWaveNames = {"", ""} // Calculated wave names
			make/t/o sc_CalcScripts = {"",""} // Scripts to calculate stuff
			make/o sc_CalcRecord = {0,0} // Include this calculated field or not
			make/o sc_CalcPlot = {0,0} // Whether you want to plot the data for this wave
			make /o sc_measAsync = {0,0}

			// Print variables
			variable/g sc_PrintRaw = 1,sc_PrintCalc = 1
			
			// Clean up volatile memory
			variable/g sc_cleanup = 0

			// instrument wave
			make /t/o/N=(sc_instrLimit,3) sc_Instr
			sc_Instr=""

			sc_Instr[0][0] = "openFastDAC(\"xxx\", verbose=0)"
			//sc_Instr[1][0] = "openLS370connection(\"ls\", \"http://lksh370-xld.qdev-b111.lab:49300/api/v1/\", \"bfbig\", verbose=1)"
			//sc_Instr[2][0] = "openIPS120connection(\"ips1\",\"GPIB::25::INSTR\", 9.569, 9000, 182, verbose=0, hold = 1)"
			sc_Instr[0][2] = "getFDstatus()"
			//sc_Instr[1][2] = "getls370Status(\"ls\")"
			//sc_Instr[2][2] = "getipsstatus(ips1)"
			//sc_Instr[3][2] = "getFDstatus(\"fd2\")"
			//sc_Instr[4][2] = "getFDstatus(\"fd3\")"


			
			
//		openMultipleFDACs("13,7,4", verbose=0)
//openLS370connection("ls", "http://lksh370-xld.qdev-b111.lab:49300/api/v1/", "bfbig", verbose=0)
//openIPS120connection("ips1", "GPIB0::25::INSTR", 9.569, 9000, 182, verbose=0, hold = 1)

			nvar/z filenum
			if(!nvar_exists(filenum))
				print "Initializing FileNum to 0 since it didn't exist before.\n"
				variable /g filenum=0
			else
				printf "Current filenum is %d\n", filenum
			endif
//		endif
	else
		scw_loadConfig()
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
	getwindow/z ScanController1 wsizeRM
	dowindow /k ScanController1
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
	//SetDrawEnv fsize= 16,fstyle= 1	
	//DrawText 250,29,"Async"
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
		//cmd="CheckBox sc_AsyncCheckBox" + num2istr(i) + ", proc=scw_CheckboxClicked, pos={270,40+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_measAsync[i]) + " , title=\"\""
		//execute(cmd)
		cmd="SetVariable sc_rawScriptBox" + num2istr(i) + " pos={250, 37+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={410, 0}, fsize=14, title=\" \", value=sc_rawScripts[i]"
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


//function/S scf_get_scanned_DACinfo(info_name, [column])
//	// Return a list of strings for specified column in fadcattr based on whether "record" is ticked
//	// Valid info_name ("calc_names", "raw_names", "calc_funcs", "inputs", "channels")
//
//	//column specifies whether another column of checkboxes need to be satisfied, There is
//	// notch = 5, demod = 6, resample = 8,
//	string info_name
//	variable column
//	variable i
//	wave fdacattr
//	wave/t dac_channel
//
//	string return_list = ""
//	wave/t fadcvalstr
//	for (i = 0; i<dimsize(fadcvalstr, 0); i++)
//
//		if (paramIsDefault(column))
//
//			if (fadcattr[i][2] == 48) // Checkbox checked
//				strswitch(info_name)
//					case "calc_names":
//						return_list = addlistItem(fadcvalstr[i][3], return_list, ";", INF)
//						break
//					case "raw_names":
//						return_list = addlistItem("ADC"+num2str(i), return_list, ";", INF)
//						break
//					case "calc_funcs":
//						return_list = addlistItem(fadcvalstr[i][4], return_list, ";", INF)
//						break
//						//S.adcListIDs=scf_getRecordedFADCinfo("adcListIDs")
//					case "adcListIDs":
//						return_list = addlistItem(adc_channel[i], return_list, ";", INF)
//						break
//					case "inputs":
//						return_list = addlistItem(fadcvalstr[i][1], return_list, ";", INF)
//						break
//					case "channels":
//						return_list = addlistItem(fadcvalstr[i][0], return_list, ";", INF)
//						break
//					default:
//						abort "bad name requested: " + info_name + ". Allowed are (calc_names, raw_names, calc_funcs, inputs, channels)"
//						break
//				endswitch
//			endif
//
//		else
//        
//        	if (fadcattr[i][2] == 48 && fadcattr[i][column] == 48) // Checkbox checked
//				strswitch(info_name)
//					case "calc_names":
//                		return_list = addlistItem(fadcvalstr[i][3], return_list, ";", INF)  												
//						break
//					case "raw_names":
//                		return_list = addlistItem("ADC"+num2str(i), return_list, ";", INF)  						
//						break
//					case "calc_funcs":
//                		return_list = addlistItem(fadcvalstr[i][4], return_list, ";", INF)  						
//						break						
//					case "inputs":
//                		return_list = addlistItem(fadcvalstr[i][1], return_list, ";", INF)  												
//						break						
//					case "channels":
//                		return_list = addlistItem(fadcvalstr[i][0], return_list, ";", INF)  																		
//						break
//					default:
//						abort "bad name requested: " + info_name + ". Allowed are (calc_names, raw_names, calc_funcs, inputs, channels)"
//						break
//				endswitch			
//        	endif
//        	
//        endif
//        
//    endfor
//    return return_list
//end



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
	if (i == 0 && j == 0 && (S.start_time == 0 || numtype(S.start_time) != 0))
		S.start_time = datetime-date2secs(2024,04,22) 
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
//	wave sc_measAsync
//	if( (sum(sc_measAsync) > 1) && (fillnan==0))
//		variable tgID = sc_ManageThreads(innerindex, outerindex, S.readvstime, S.is2d, S.start_time) // start threads, wait, collect data
//		sc_KillThreads(tgID) // Terminate threads
//	endif

	//// Run sync data collection (or fill with NaNs) ////
	wave sc_RawRecord, sc_CalcRecord
	wave/t sc_RawWaveNames, sc_RawScripts, sc_CalcWaveNames, sc_CalcScripts
	variable /g sc_tmpVal  // Used when evaluating measurement scripts from ScanController window
	string script = "", cmd = ""
	ii=0
	do // TODO: Ideally rewrite this to use sci_get1DWaveNames() but need to be careful about only updating sc_measAsync == 0 ones here...
		if (sc_RawRecord[ii] == 1)
			wave wref1d = $sc_RawWaveNames[ii]

			// Redimension waves if readvstime is set to 1
			if (S.readVsTime == 1)
				redimension /n=(innerindex+1) wref1d
				S.numptsx = innerindex+1  // So that x_array etc will be saved correctly later
				wref1d[innerindex] = NaN  // Prevents graph updating with a zero
				setscale/I x 0,  datetime-date2secs(2024,04,22)  - S.start_time, wref1d
				S.finx = datetime-date2secs(2024,04,22)  - S.start_time 	// So that x_array etc will be saved correctly later
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
		if (sc_CalcRecord[ii] == 1)
			wave wref1d = $sc_CalcWaveNames[ii] // this is the 1D wave I am filling

			// Redimension waves if readvstimeis set to 1
			if (S.readvstime == 1)
				redimension /n=(innerindex+1) wref1d
				setscale/I x 0, datetime-date2secs(2024,04,22)  - S.start_time, wref1d
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

	S.end_time = datetime-date2secs(2024,04,22) // Updates each loop

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

	// If the end of a 1D sweep, then update all graphs, otherwise only update the raw 1D graphs
	if (j == S.numptsx - 1)
		doupdate
	else
		scg_updateFrequentGraphs()
	endif
end
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////// ASYNC handling ///////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Note: Slow ScanContoller ONLY

//function sc_ManageThreads(innerIndex, outerIndex, readvstime, is2d, start_time)
//	variable innerIndex, outerIndex, readvstime
//	variable is2d, start_time
//	svar sc_asyncFolders
//	nvar sc_numAvailThreads, sc_numInstrThreads
//	wave /WAVE sc_asyncRefs
//
//	variable tgID = ThreadGroupCreate(min(sc_numInstrThreads, sc_numAvailThreads)) // open threads
//
//	variable i=0, idx=0, measIndex=0, threadIndex = 0
//	string script, queryFunc, strID, threadFolder
//
//	// start new thread for each thread_* folder in data folder structure
//	for(i=0;i<sc_numInstrThreads;i+=1)
//
//		do
//			threadIndex = ThreadGroupWait(tgID, -2) // relying on this to keep track of index
//		while(threadIndex<1)
//
//		duplicatedatafolder root:async, root:asyncCopy //duplicate async folder
//		ThreadGroupPutDF tgID, root:asyncCopy // move root:asyncCopy to where threadGroup can access it
//											           // effectively kills root:asyncCopy in main thread
//
//		// start thread
//		threadstart tgID, threadIndex-1, sc_Worker(sc_asyncRefs, innerindex, outerindex, \
//																 StringFromList(i, sc_asyncFolders, ";"), is2d, \
//																 readvstime, start_time)
//	endfor
//
//	// wait for all threads to finish and get the rest of the data
//	do
//		threadIndex = ThreadGroupWait(tgID, 0)
//		sleep /s 0.001
//	while(threadIndex!=0)
//
//	return tgID
//end
//
//
//threadsafe function sc_Worker(refWave, innerindex, outerindex, folderIndex, is2d, rvt, starttime)
//	wave /WAVE refWave
//	variable innerindex, outerindex, is2d, rvt, starttime
//	string folderIndex
//
//	do
//		DFREF dfr = ThreadGroupGetDFR(0,0)	// Get free data folder from input queue
//		if (DataFolderRefStatus(dfr) == 0)
//			continue
//		else
//			break
//		endif
//	while(1)
//
//	setdatafolder dfr:$(folderIndex)
//
//	nvar /z instrID = instrID
//	svar /z queryFunc = queryFunc
//	svar /z wavIdx = wavIdx
//
//	if(nvar_exists(instrID) && svar_exists(queryFunc) && svar_exists(wavIdx))
//
//		variable i, val
//		for(i=0;i<ItemsInList(queryFunc, ";");i+=1)
//
//			// do the measurements
//			funcref sc_funcAsync func = $(StringFromList(i, queryFunc, ";"))
//			val = func(instrID)
//
//			if(numtype(val)==2)
//				// if NaN was returned, try the next function
//				continue
//			endif
//
//			wave wref1d = refWave[2*str2num(StringFromList(i, wavIdx, ";"))]
//
//			if(rvt == 1)
//				redimension /n=(innerindex+1) wref1d
//				setscale/I x 0, datetime - starttime, wref1d
//			endif
//
//			wref1d[innerindex] = val
//
//			if(is2d)
//				wave wref2d = refWave[2*str2num(StringFromList(i, wavIdx, ";"))+1]
//				wref2d[innerindex][outerindex] = val
//			endif
//
//		endfor
//
//		return i
//	else
//		// if no instrID/queryFunc/wavIdx exists, get out
//		return NaN
//	endif
//end
//
//
//threadsafe function sc_funcAsync(instrID)  // Reference functions for all *_async functions
//	variable instrID                    // instrID used as only input to async functions
//end
//
//
//function sc_KillThreads(tgID)
//	variable tgID
//	variable releaseResult
//
//	releaseResult = ThreadGroupRelease(tgID)
//	if (releaseResult == -2)
//		abort "ThreadGroupRelease failed, threads were force quit. Igor should be restarted!"
//	elseif(releaseResult == -1)
//		printf "ThreadGroupRelease failed. No fatal errors, will continue.\r"
//	endif
//
//end
//
//
//function sc_checkAsyncScript(str)
//	// returns -1 if formatting is bad
//	// could be better
//	// returns position of first ( character if it is good
//	string str
//
//	variable i = 0, firstOP = 0, countOP = 0, countCP = 0
//	for(i=0; i<strlen(str); i+=1)
//
//		if( CmpStr(str[i], "(") == 0 )
//			countOP+=1 // count opening parentheses
//			if( firstOP==0 )
//				firstOP = i // record position of first (
//				continue
//			endif
//		endif
//
//		if( CmpStr(str[i], ")") == 0 )
//			countCP -=1 // count closing parentheses
//			continue
//		endif
//
//		if( CmpStr(str[i], ",") == 0 )
//			return -1 // stop on comma
//		endif
//
//	endfor
//
//	if( (countOP==1) && (countCP==-1) )
//		return firstOP
//	else
//		return -1
//	endif
//end
//
//
//function sc_findAsyncMeasurements()
//	// go through RawScripts and look for valid async measurements
//	//    wherever the meas_async box is checked in the window
//	nvar sc_is2d
//	wave /t sc_RawScripts, sc_RawWaveNames
//	wave sc_RawRecord, sc_measAsync
//
//	// setup async folder
//	killdatafolder /z root:async // kill it if it exists
//	newdatafolder root:async // create an empty version
//
//	variable i = 0, idx = 0, measIdx=0, instrAsync=0
//	string script, strID, queryFunc, threadFolder
//	string /g sc_asyncFolders = ""
//	make /o/n=1 /WAVE sc_asyncRefs
//
//
//	for(i=0;i<numpnts(sc_RawScripts);i+=1)
//
//		if (sc_RawRecord[i] == 1)
//			// this is something that will be measured
//
//			if (sc_measAsync[i] == 1) // this is something that should be async
//
//				script = sc_RawScripts[i]
//				idx = sc_checkAsyncScript(script) // check function format
//
//				if(idx!=-1) // fucntion is good, this will be recorded asynchronously
//
//					// keep track of function names and instrIDs in folder structure
//					strID = script[idx+1,strlen(script)-2]
//					queryFunc = script[0,idx-1]
//
//					// creates root:async:instr1
//					sprintf threadFolder, "thread_%s", strID
//					if(DataFolderExists("root:async:"+threadFolder))
//						// add measurements to the thread directory for this instrument
//
//						svar qF = root:async:$(threadFolder):queryFunc
//						qF += ";"+queryFunc
//						svar wI = root:async:$(threadFolder):wavIdx
//						wI += ";" + num2str(measIdx)
//					else
//						instrAsync += 1
//
//						// create a new thread directory for this instrument
//						newdatafolder root:async:$(threadFolder)
//						nvar instrID = $strID
//						variable /g root:async:$(threadFolder):instrID = instrID   // creates variable instrID in root:thread
//																	                          // that has the same value as $strID
//						string /g root:async:$(threadFolder):wavIdx = num2str(measIdx)
//						string /g root:async:$(threadFolder):queryFunc = queryFunc // creates string variable queryFunc in root:async:thread
//																                             // that has a value queryFunc="readInstr"
//						sc_asyncFolders += threadFolder + ";"
//
//
//
//					endif
//
//					// fill wave reference(s)
//					redimension /n=(2*measIdx+2) sc_asyncRefs
//					wave w=$sc_rawWaveNames[i] // 1d wave
//					sc_asyncRefs[2*measIdx] = w
//					if(sc_is2d)
//						wave w2d=$(sc_rawWaveNames[i]+"2d") // 2d wave
//						sc_asyncRefs[2*measIdx+1] = w2d
//					endif
//					measIdx+=1
//
//				else
//					// measurement script is formatted wrong
//					sc_measAsync[i]=0
//					printf "[WARNING] Async scripts must be formatted: \"readFunc(instrID)\"\r\t%s is no good and will be read synchronously,\r", sc_RawScripts[i]
//				endif
//
//			endif
//		endif
//
//	endfor
//
//	if(instrAsync<2)
//		// no point in doing anyting async is only one instrument is capable of it
//		// will uncheck boxes automatically
//		make /o/n=(numpnts(sc_RawScripts)) sc_measAsync = 0
//	endif
//
//	// change state of check boxes based on what just happened here!
//	doupdate /W=ScanController
//	string cmd = ""
//	for(i=0;i<numpnts(sc_measAsync);i+=1)
//		sprintf cmd, "CheckBox sc_AsyncCheckBox%d,win=ScanController,value=%d", i, sc_measAsync[i]
//		execute(cmd)
//	endfor
//	doupdate /W=ScanController
//
//	if(sum(sc_measAsync)==0)
//		sc_asyncFolders = ""
//		KillDataFolder /Z root:async // don't need this
//		return 0
//	else
//		variable /g sc_numInstrThreads = ItemsInList(sc_asyncFolders, ";")
//		variable /g sc_numAvailThreads = threadProcessorCount
//		return sc_numInstrThreads
//	endif
//
//end
