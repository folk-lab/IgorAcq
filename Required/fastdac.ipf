﻿#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

/// new fastDAC code, implementing Ovi's API

////////////////////
//// Connection ////
////////////////////


function openFastDAC(portnum,[verbose])
	// open/test a connection to the LS37X RPi interface written by Ovi
	//      the whole thing _should_ work for LS370 and LS372
	// instrID is the name of the global variable that will be used for communication
	// http_address is exactly what it sounds like
	//	it should look something like this: http://lcmi-docs.qdev-h101.lab:xxxxx/api/v1/

	// verbose=0 will not print any information about the connection


	string portnum
	variable verbose
	string IDname="fd"


	string http_address = "http://lcmi-docs.qdev-h101.lab:"+portnum+"/api/v1/"
	http_address="http://127.0.0.1:"+portnum+"/api/v1/"



	if(paramisdefault(verbose))
		verbose=1
	elseif(verbose!=1)
		verbose=0
	endif

	string comm = ""
	sprintf comm, "instrID=%s,url=%s" IDname, http_address
	string response = ""

	openHTTPinstr(comm, verbose=verbose)  // creates global variable fd=http_address

	response = get_proxy_info()
	
	string proxies_info = getjsonvalue(response, "proxies_info")
	string fastdac_labels = get_fastdac_labels()
	
	if (verbose==1)
		print fastdac_labels
	endif
end




function init_dac_and_adc(fastdac_string)
	// creates two waves 'dac_table' and 'adc_table' which are used to create fastDAC window
//	example: init_dac_and_adc("5;3;6;8")
	string fastdac_string // expecting e.g. "17;2;34"
	
	// if dac and adc ever change these values need updating
	int num_dac = 8
	int num_adc = 4
	
	variable num_fastdac = ItemsInList(fastdac_string, ";")
	int fastdac_count = 0
	string temp_string
	
	////////////////////////////
	///// create DAC table /////
	////////////////////////////
	int dac_count = 0
	make /o /T /n=(num_fastdac * num_dac, 5) dac_table
	wave /t dac_table
	int i
	for  (i=0; i < num_fastdac * num_dac; i++)
	
		// column 0: DAC channel str
		temp_string = stringFromList(fastdac_count, fastdac_string, ";") + "." + num2str(dac_count)
		dac_table[i][0] = temp_string
		
		// column 1: output
		temp_string = num2str(gnoise(10))
		dac_table[i][1] = temp_string
		
		// column 2
		temp_string = "-10000,10000"
		dac_table[i][2] = temp_string
		
		// column 3: label
		temp_string = "gate" + num2str(i)
		dac_table[i][3] = temp_string
		
		// column 4: ramprate
		temp_string = "1000000"
		dac_table[i][4] = temp_string
		
		
		if (dac_count < num_dac - 1)
			dac_count += 1
		else
			dac_count = 0
			fastdac_count += 1
		endif
	endfor
	
	
	////////////////////////////
	///// create ADC table /////
	////////////////////////////
	int adc_count = 0
	fastdac_count = 0
	make /o /T /n=(num_fastdac * num_adc, 9) adc_table
	wave /t adc_table
	for  (i=0; i < num_fastdac * num_adc; i++)
	
		// column 0
		temp_string = stringFromList(fastdac_count, fastdac_string, ";") + "." + num2str(adc_count)
		adc_table[i][0] = temp_string
		
		// column 1: input
		temp_string = num2str(gnoise(10))
		adc_table[i][1] = temp_string
		
		// column 3
		temp_string = "wave" + num2str(i)
		adc_table[i][3] = temp_string
		
		// column 4
		temp_string = "ADC" + num2str(i)
		adc_table[i][4] = temp_string
		
		// column 7
		temp_string = num2str(1)
		adc_table[i][7] = temp_string
		
		if (adc_count < num_adc - 1)
			adc_count += 1
		else
			adc_count = 0
			fastdac_count += 1
		endif
	endfor
	
	
end



function initFastDAC([fastdac_order, portnum])
	// usage: init_dac_and_adc("1;2;4;6")
	//Edit/K=0 root:adc_table;Edit/K=0 root:dac_table
	// default is to initialise the FastDacs in ascending order. But can specify the order with the parameter fastdac_order
	// i.e. fastdac_order = "12;3;6;1;17"
	string fastdac_order, portnum
	fastdac_order = selectString(paramIsDefault(fastdac_order), fastdac_order, "")
	portnum = selectString(paramIsDefault(portnum), portnum, "XXX")

	string fastdac_labels
	if (paramIsDefault(fastdac_order) == 0)
		fastdac_labels = get_fastdac_labels(sort_fastdacs = 0, fastdac_order = fastdac_order)	// default is to return sorted fastdac channels
	else
		fastdac_labels = get_fastdac_labels(sort_fastdacs = 1)	// default is to return sorted fastdac channels
	endif
	
	init_dac_and_adc(fastdac_labels)
	wave/t adc_table, dac_table

	variable num_fastdac = get_number_of_fastdacs()

	// initise ADC and DAC channel
	make/o/t/n=(dimsize(ADC_table,0)) ADC_channel
	make/o/t/n=(dimsize(DAC_table,0)) DAC_channel
	ADC_channel=adc_table[p][0]
	DAC_channel=dac_table[p][0]

	nvar filenum
	getFDIDs()

	// create waves to hold control info
	variable oldinit = scfw_fdacCheckForOldInit(portnum = portnum)


	// create GUI window
	string cmd = ""
	getwindow/z ScanControllerFastDAC wsizeRM
	killwindow/z ScanControllerFastDAC
	killwindow/z after1
	execute("after1()")
	
	scw_colour_the_table()

	nvar sampling_time
	sampling_time=82
	setadc_speed(sampling_time)
end




function setADC_speed(int ADCspeed)
	svar fd
	wave/t ADC_channel
	nvar sampling_time
	variable new_speed
	variable i = 0
	do
		set_one_fadcSpeed(i,ADCspeed)
		i = i + 1
	while(i<dimsize(ADC_channel, 0))
	sc_sleep(0.2)
	sampling_time=get_one_fadcSpeed(3)
	print "setting all ADCs to "+num2str(sampling_time)+"(uS)"
end



function fd_getmaxADCs(S)
	struct ScanVars &S
	variable maxADCs
	wave fadcattr
	string adcList = scf_getRecordedFADCinfo("channels")
	StringToListWave(adclist)
	wave numericwave
	numericwave = floor(numericwave)
	maxADCs = get_MaxRepeats_from_wave(numericwave)
	S.numADCs = dimsize(numericwave, 0)
	return maxADCs
end



function getFDIDs()
	//ADC_channel has to exist for this to work
	//creates string wave FDIDs and sting list FDIDs_list
	wave/t ADC_channel
	ConvertTxtWvToNumWv(ADC_channel); /// creates numerical wave out of ADC_channel
	wave numconvert
	matrixop/o rounded = round(numconvert)
	FDecimate(rounded, "FDIDs", 4)
	
	killwaves /Z numconvert
	killwaves /Z rounded
end




window FastDACWindow(v_left,v_right,v_top,v_bottom) : Panel
	variable v_left,v_right,v_top,v_bottom
	PauseUpdate; Silent 1 // pause everything else, while building the window
	
	NewPanel/w=(0,0,1010,585)/n=ScanControllerFastDAC
	if(v_left+v_right+v_top+v_bottom > 0)
		MoveWindow/w=ScanControllerFastDAC v_left,v_top,V_right,v_bottom
	endif
	ModifyPanel/w=ScanControllerFastDAC framestyle=2, fixedsize=1
	SetDrawLayer userback
	SetDrawEnv fsize=25, fstyle=1
	DrawText 160, 45, "DAC"
	SetDrawEnv fsize=25, fstyle=1
	DrawText 650, 45, "ADC"
	DrawLine 385,15,385,575 
	DrawLine 395,415,1000,415 /////EDIT 385-> 415
	DrawLine 355,415,375,415
	DrawLine 10,415,220,415
	SetDrawEnv dash=1
	Drawline 395,333,1000,333 /////EDIT 295 -> 320
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
	DrawText 450, 70, "Input (mV)"
	SetDrawEnv fsize=14, fstyle=1, textrot = -60
	DrawText 550, 75, "Record"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 590, 70, "Wave Name"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 705, 70, "Calc Function"
	SetDrawEnv fsize=14, fstyle=1, textrot = -60
	DrawText 850, 75, "Notch"
	SetDrawEnv fsize=14, fstyle=1, textrot = -60
	DrawText 885, 75, "Demod"
	SetDrawEnv fsize=14, fstyle=1, textrot = -60
	DrawText 920, 75, "Harmonic"
	SetDrawEnv fsize=14, fstyle=1, textrot = -60
	DrawText 950, 75, "Resamp"
	ListBox fadclist,pos={400,75},size={600,180},fsize=14,frame=2,widths={30,70,30,95,100,30,30,20,30} //added two widths for resample and notch filter, changed listbox size, demod
	
	
	ListBox fadclist,listwave=root:fadcvalstr,selwave=root:fadcattr,mode=1
	button updatefadc,pos={400,265},size={90,20},proc=scfw_update_fadc,title="Update ADC"
	checkbox sc_plotRawBox,pos={505,265},proc=scw_CheckboxClicked,variable=sc_plotRaw,side=1,title="\Z14Plot Raw"
	checkbox sc_demodyBox,pos={585,265},proc=scw_CheckboxClicked,variable=sc_demody,side=1,title="\Z14Save Demod.y"
	checkbox sc_hotcoldBox,pos={823,302},proc=scw_CheckboxClicked,variable=sc_hotcold,side=1,title="\Z14 Hot/Cold"
	SetVariable sc_hotcolddelayBox,pos={908,300},size={70,20},value=sc_hotcolddelay,side=1,title="\Z14Delay"
	SetVariable sc_FilterfadcBox,pos={828,264},size={150,20},value=sc_ResampleFreqfadc,side=1,title="\Z14Resamp Freq ",help={"Re-samples to specified frequency, 0 Hz == no re-sampling"} /////EDIT ADDED
	SetVariable sc_demodphiBox,pos={705,264},size={100,20},value=sc_demodphi,side=1,title="\Z14Demod \$WMTEX$ \Phi $/WMTEX$"//help={"Re-samples to specified frequency, 0 Hz == no re-sampling"} /////EDIT ADDED
	SetVariable sc_nfreqBox,pos={500,300},size={150,20}, value=sc_nfreq ,side=1,title="\Z14 Notch Freqs" ,help={"seperate frequencies (Hz) with , "}
	SetVariable sc_nQsBox,pos={665,300},size={140,20}, value=sc_nQs ,side=1,title="\Z14 Notch Qs" ,help={"seperate Qs with , "}
	DrawText 807,277, "\Z14\$WMTEX$ {}^{o} $/WMTEX$" 
	DrawText 982,283, "\Z14Hz" 
	
	//popupMenu fadcSetting1,pos={420,345},proc=scfw_scfw_update_fadcSpeed,mode=1,title="\Z14FD1 speed",size={100,20},value=sc_fadcSpeed1 
	//popupMenu fadcSetting2,pos={620,345},proc=scfw_scfw_update_fadcSpeed,mode=1,title="\Z14FD2 speed",size={100,20},value=sc_fadcSpeed2 
	//popupMenu fadcSetting3,pos={820,345},proc=scfw_scfw_update_fadcSpeed,mode=1,title="\Z14FD3 speed",size={100,20},value=sc_fadcSpeed3 
	//popupMenu fadcSetting4,pos={420,375},proc=scfw_scfw_update_fadcSpeed,mode=1,title="\Z14FD4 speed",size={100,20},value=sc_fadcSpeed4 
	//popupMenu fadcSetting5,pos={620,375},proc=scfw_scfw_update_fadcSpeed,mode=1,title="\Z14FD5 speed",size={100,20},value=sc_fadcSpeed5 
	//popupMenu fadcSetting6,pos={820,375},proc=scfw_scfw_update_fadcSpeed,mode=1,title="\Z14FD6 speed",size={100,20},value=sc_fadcSpeed6 
//	DrawText 545, 362, "\Z14Hz"
//	DrawText 745, 362, "\Z14Hz" 
//	DrawText 945, 362, "\Z14Hz" 
//	DrawText 545, 392, "\Z14Hz" 
//	DrawText 745, 392, "\Z14Hz" 
//	DrawText 945, 392, "\Z14Hz" 

	// identical to ScanController window
	// all function calls are to ScanController functions
	// instrument communication
	
	SetDrawEnv fsize=14, fstyle=1
	DrawText 415, 445, "Connect Instrument" 
	SetDrawEnv fsize=14, fstyle=1 
	DrawText 635, 445, "Open GUI" 
	SetDrawEnv fsize=14, fstyle=1
	DrawText 825, 445, "Log Status" 
	ListBox sc_InstrFdac,pos={400,450},size={600,100},fsize=14,frame=2,listWave=root:sc_Instr,selWave=root:instrBoxAttr,mode=1, editStyle=1

	// buttons  
	button connectfdac,pos={400,555},size={110,20},proc=scw_OpenInstrButton,title="Connect Instr" 
	button guifdac,pos={520,555},size={110,20},proc=scw_OpenGUIButton,title="Open All GUI" 
	button killaboutfdac, pos={640,555},size={120,20},proc=sc_controlwindows,title="Kill Sweep Controls" 
	button killgraphsfdac, pos={770,555},size={110,20},proc=scw_killgraphs,title="Close All Graphs" 
	button updatebuttonfdac, pos={890,555},size={110,20},proc=scw_updatewindow,title="Update" 

	// helpful text
	//DrawText 820, 595, "Press Update to save changes."
	
	
	/// Lock in stuff
	tabcontrol tb, proc=TabProc , pos={230,410},size={130,22},fsize=13, appearance = {default}
	tabControl tb,tabLabel(0) = "Lock-In" 
	tabControl tb,tabLabel(1) = "AWG"
	
	tabcontrol tb2, proc=TabProc2 , pos={44,423},size={180,22},fsize=13, appearance = {default}, disable = 1
	tabControl tb2,tabLabel(0) = "Set AW" 
	tabControl tb2,tabLabel(1) = "AW0"
	tabControl tb2,tabLabel(2) = "AW1"
	
	button setupLI,pos={10,510},size={55,40},proc=scw_setupLockIn,title="Set\rLock-In"
	
	ListBox LIlist,pos={70,455},size={140,95},fsize=14,frame=2,widths={60,40}
	ListBox LIlist,listwave=root:LIvalstr,selwave=root:LIattr,mode=1
	
	ListBox LIlist0,pos={223,479},size={147,71},fsize=14,frame=2,widths={40,60}
	ListBox LIlist0,listwave=root:LIvalstr0,selwave=root:LIattr0,mode=1
	
	titlebox AW0text,pos={223,455},size={60,20},Title = "AW0",frame=0, fsize=14
	//awgLIvalstr
	//AWGvalstr
	ListBox awglist,pos={70,455},size={140,120},fsize=14,frame=2,widths={40,60}, disable = 1
	ListBox awglist,listwave=root:awgvalstr,selwave=root:awgattr,mode=1
	
	ListBox awglist0,pos={70,455},size={140,120},fsize=14,frame=2,widths={40,60}, disable = 1
	ListBox awglist0,listwave=root:awgvalstr0,selwave=root:awgattr0,mode=1
	
	ListBox awglist1,pos={70,455},size={140,120},fsize=14,frame=2,widths={40,60}, disable = 1
	ListBox awglist1,listwave=root:awgvalstr1,selwave=root:awgattr1,mode=1
	
	ListBox awgsetlist,pos={223,479},size={147,71},fsize=14,frame=2,widths={50,40}, disable = 1
	ListBox awgsetlist,listwave=root:awgsetvalstr,selwave=root:awgsetattr,mode=1
	
	titleBox freqtextbox, pos={10,480}, size={100, 20}, title="Frequency", frame = 0, disable=1
	titleBox Hztextbox, pos={48,503}, size={40, 20}, title="Hz", frame = 0, disable=1
	
	
	///AWG
	button clearAW,pos={10,555},size={55,20},proc=scw_clearAWinputs,title="Clear", disable = 1
	button setupAW,pos={10,525},size={55,20},proc=scw_setupsquarewave,title="Create", disable = 1
	SetVariable sc_wnumawgBox,pos={10,499},size={55,25},value=sc_wnumawg,side=1,title ="\Z14AW", help={"0 or 1"}, disable = 1
	SetVariable sc_freqBox0, pos={6,500},size={40,20}, value=sc_freqAW0 ,side=0,title="\Z14 ", disable = 1, help = {"Shows the frequency of AW0"}
	SetVariable sc_freqBox1, pos={6,500},size={40,20}, value=sc_freqAW1 ,side=1,title="\Z14 ", disable = 1, help = {"Shows the frequency of AW1"}
	button setupAWGfdac,pos={260,555},size={110,20},proc=scw_setupAWG,title="Setup AWG", disable = 1	
endmacro

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





Function RampMultipleFDAC(string channels, variable setpoint, [variable ramprate, string setpoints_str])
    // This function ramps multiple FastDAC channels to given setpoint(s) at a specified ramp rate.
    // Parameters:
    // channels - A comma-separated list of channels to be ramped. Expects 
    // setpoint - A common setpoint to ramp all channels to (ignored if setpoints_str is provided).
    // ramprate - The ramp rate in mV/s for all channels. If not specified, uses each channel's configured ramp rate.
    // setpoints_str - An optional comma-separated list of setpoints, allowing individual setpoints for each channel.
    // Example Use ::
    // rampmultiplefDAC("11.3, 11.6", 0, setpoints_str ="10, -10")

	ramprate = paramisdefault(ramprate) ? 10000 : ramprate     // If ramprate is not specified or not a number, default to 1000 (this is mostly safe)



    // Convert channel identifiers to numbers, supporting both numerical IDs and named channels
    channels = scu_getChannelNumbers(channels)
    
    // Abort if the number of channels and setpoints do not match when individual setpoints are provided
    if (!paramIsDefault(setpoints_str) && (itemsInList(channels, ",") != itemsInList(setpoints_str, ","))) 
        abort "ERROR[RampMultipleFdac]: Number of channels does not match number of setpoints in setpoints_str"    
    endif
    
    // Initialize variables for the loop
    Variable i = 0, nChannels = ItemsInList(channels, ",")
    string channel
    Variable channel_ramp  // Not used, consider removing if unnecessary
    variable fastdac_index
    Wave/T fdacvalstr
    
    // Loop through each channel to apply the ramp
    for (i = 0; i < nChannels; i += 1)
        // If individual setpoints are provided, override the common setpoint with the specific value for each channel
        if (!paramIsDefault(setpoints_str)) 
            setpoint = str2num(StringFromList(i, setpoints_str, ","))
        endif
        
        // Extract the channel number from the list and ramp to the setpoint
        channel = StringFromList(i, channels, ",")
        
        fastdac_index = get_fastdac_index(channel, return_adc_index = 0)
        
        if (ramprate == 0)
     	   ramprate = str2num(fdacvalstr[fastdac_index][4])
		endif
		
        fd_rampOutputFDAC(fastdac_index, setpoint, ramprate)  // Ramp the channel to the setpoint at the specified rate
    endfor
End




Function fd_rampOutputFDAC(variable channel, variable setpoint, variable ramprate) // Units: mV, mV/s
    // This function ramps one FD DAC channel to a specified setpoint at a given ramprate.
    // It checks that both the setpoint and ramprate are within their respective limits before proceeding.

    // Access the global wave containing FDAC channel settings
    Wave/T fdacvalstr
    
    // Ensure the output is within the hardware's permissible limits
    Variable output = check_fd_limits(channel, setpoint)
    
    // Check if the requested ramprate is within the software limit
    // If not, the maximum permissible ramprate is used instead
    If (ramprate > str2num(fdacvalstr[channel][4]) || numtype(ramprate) != 0)
        printf "[WARNING] \"fd_rampOutputFDAC\": Ramprate of %.0fmV/s requested for channel %d. Using max_ramprate of %.0fmV/s instead\n", ramprate, channel, str2num(fdacvalstr[channel][4])
        ramprate = str2num(fdacvalstr[channel][4])
        
        // If after adjustment, the ramprate is still not a numeric type, abort the operation
        If (numtype(ramprate) != 0)
            Abort "ERROR[fd_rampOutputFDAC]: Bad ramprate in ScanController_Fastdac window for channel " + num2str(channel)
        EndIf
    EndIf
        
    // Ramp the DAC channel to the desired output with the validated ramprate
    set_one_FDACChannel(channel, output, ramprate)
    
    // Update the DAC value in the FastDAC panel to reflect the change
    Variable currentoutput = get_one_FDACChannel(channel)
    scfw_updateFdacValStr(channel, currentoutput, update_oldValStr=1)
End

function check_fd_limits(int channel, variable output)
	// check that output is within software limit
	// overwrite output to software limit and warn user
	wave/t fdacvalstr

	string softLimitPositive = "", softLimitNegative = "", expr = "(-?[[:digit:]]+),\s*([[:digit:]]+)"
	splitstring/e=(expr) fdacvalstr[channel][2], softLimitNegative, softLimitPositive
	if(output < str2num(softLimitNegative) || output > str2num(softLimitPositive))
		switch(sign(output))
			case -1:
				output = str2num(softLimitNegative)
				break
			case 1:
				if(output != 0)
					output = str2num(softLimitPositive)
				else
					output = 0
				endif
				break
		endswitch
		string warn
		sprintf warn, "[WARNING] \"fd_rampOutputFDAC\": Output voltage must be within limit. Setting channel %d to %.3fmV\n", channel, output
		print warn
	endif

	return output
end


//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////// AWG stuff////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////



//function fd_initGlobalAWG()
//	Struct AWGVars S
//	// Set empty strings instead of null
//	S.AW_waves   = ""
//	S.AW_dacs    = ""
//	S.AW_dacs2   = ""
//	S.channels_AW0   = ""
//	S.channels_AW1   = ""
//	S.channelIDs = ""
//	S.InstrIDs   = "" 
//	
//	fd_setGlobalAWG(S)
//end


//function fd_setGlobalAWG(S)
//	// Function to store values from AWG_list to global variables/strings/waves
//	// StructPut ONLY stores VARIABLES so have to store other parts separately
//	struct AWGVars &S
//
//	// Store String parts  
//	make/o/t fd_AWGglobalStrings = {S.AW_Waves, S.AW_dacs, S.AW_dacs2, S.channels_AW0, S.channels_AW1, S.channelIDs, S.InstrIDs}
//
//	// Store variable parts
//	make/o fd_AWGglobalVars = {S.initialized, S.use_AWG, S.lims_checked, S.waveLen, S.numADCs, S.samplingFreq,\
//		S.measureFreq, S.numWaves, S.numCycles, S.numSteps, S.maxADCs}
//end







//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////// End of AWG stuff//////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
function PreScanChecksFD(S)
	struct ScanVars &S
	scc_checkRampratesFD(S)	 	// Check ramprates of x and y
	scc_checkLimsFD(S)			// Check within software lims for x and y
	S.lims_checked = 1  		// So record_values knows that limits have been checked!
end

function checkStartsFinsChannels(starts, fins, channels)
	// checks that each of starts/fins/channels has the correct separators and matching length
	string starts, fins, channels 

	scu_assertSeparatorType(starts, ",")
	scu_assertSeparatorType(fins, ",")
	scu_assertSeparatorType(channels, ",")
	if (itemsInList(channels) != itemsInList(starts) || itemsInList(channels) != itemsInList(fins))
		string buf
		sprintf buf "ERROR[checkStartsFinsChannels]: len(channels) = %d, len(starts) = %d, len(fins) = %d. They should all match\r" , itemsInList(channels), itemsInList(starts), itemsInList(fins)
		abort buf
	endif
	return 1
end

function check_if_awg_defined()
	wave sc_awg_info
	if (waveexists(sc_awg_info)==0)
		print  "sc_awg_info wave is not defined; define it by calling fdawg_create function. For example"
		print 	 "fdawg_create(\"gate4\", \"0,50,0,50\", \"51\", overwrite = 0, print_on = 1)"
		abort

	endif
end

function scc_checkRampratesFD(S)
  // check if effective ramprate is higher than software limits
  struct ScanVars &S
  wave/T fdacvalstr

	variable kill_graphs = 0
	// Check x's won't be swept to fast by calculated sweeprate for each channel in x ramp
	// Should work for different start/fin values for x
	variable eff_ramprate, answer, i, k, channo
	string question, channel

	if(numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0)  // if s.Channelsx != (null or "")
		scu_assertSeparatorType(S.channelsx, ",")
		for(i=0;i<itemsinlist(S.channelsx,",");i+=1)
			eff_ramprate = abs(str2num(stringfromlist(i,S.startxs,","))-str2num(stringfromlist(i,S.finxs,",")))*(S.measureFreq/S.numptsx/S.wavelen/S.numCycles)
			channel = (stringfromlist(i, S.channelsx, ","))
			channo=get_fastdac_index(channel)

			if(eff_ramprate > str2num(fdacvalstr[channo][4])*1.05 || s.rampratex > str2num(fdacvalstr[channo][4])*1.05)  // Allow 5% too high for convenience
				// we are going too fast
				sprintf question, "DAC channel %d will be ramped at Sweeprate: %.1f mV/s and Ramprate: %.1f mV/s, software limit is set to %s mV/s. Continue?", channel, eff_ramprate, s.rampratex, fdacvalstr[channo][4]
				//answer = ask_user(question, type=1)
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
			channel = (stringfromlist(i, S.channelsy, ","))
			channo=get_fastdac_index(channel)

			if(s.rampratey > str2num(fdacvalstr[channo][4]))
				sprintf question, "DAC channel %d will be ramped at %.1f mV/s, software limit is set to %s mV/s. Continue?", channo, S.rampratey, fdacvalstr[channo][4]
				//answer = ask_user(question, type=1)
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
		channels = addlistitem(S.channelsx, channels,",")		
		starts = addlistitem(S.startxs, starts, ",")
		fins = addlistitem(S.finxs, fins, ",")
	endif
	if(numtype(strlen(s.channelsy)) == 0 && strlen(s.channelsy) != 0)  // If not NaN and not ""
		channels = addlistitem(S.channelsy, channels, ",")
		starts = addlistitem(S.startys, starts, ",")
		fins = addlistitem(S.finys, fins, ",")
	endif
	channels=ReplaceString(",,", channels, ",")


	// Check channels were concatenated correctly (Seems unnecessary, but possibly killed my device because of this...)
	if(stringmatch(channels, "*,,*") == 1)
		abort "ERROR[scc_checkLimsFD]: Channels list contains ',,' which means something has gone wrong and limit checking WONT WORK!!"
	endif

	// Check that start/fin for each channel will stay within software limits
	string buffer
	for(i=0;i<itemsinlist(channels,",");i+=1)
		scc_checkLimsSingleFD(stringfromlist(i,channels,","), str2num(stringfromlist(i,starts,",")), str2num(stringfromlist(i,fins,",")))
	endfor		
end

function scc_checkLimsSingleFD(channel, start, fin)
	// Check the start/fin are within limits for channel of FastDAC 
	// TODO: This function can be fairly easily adapted for BabyDACs too
	string channel // Single Channel str
	variable start, fin  // Single start, fin val for sweep
	variable s_out, f_out, answer
	variable channel_num
	channel_num=get_fastdac_index(channel)
	string question
	
	s_out=check_fd_limits(channel_num,start)	
	f_out=check_fd_limits(channel_num,fin)
	
	if ((s_out!=start) || (f_out!=fin))
		// we are outside limits
		sprintf question, "DAC channel %s would be ramped outside software limits. --- Aborting!", channel
		print question
		abort
		
	endif
end



function rampToNextSetpoint(S, inner_index, [outer_index, y_only, ignore_lims])
	// Ramps channels to next setpoint -- (FastDAC only)
	// Note: only ramps x channels unless outer_index provided
	Struct ScanVars &S
	variable inner_index  // The faster sweeping axis (X)
	variable outer_index  // The slower sweeping axis (Y)
	variable y_only  	  // Set to 1 to only sweep the Y channels
	variable ignore_lims  // Whether to ignore BabyDAC and FastDAC limits (makes sense if already checked previously)
	variable k
	svar fd
	if (!y_only)
		checkStartsFinsChannels(S.startxs, S.finxs, S.channelsx)
		variable sx, fx, setpointx
		string chx, IDname
		for(k=0; k<itemsinlist(S.channelsx,","); k++)
			sx = str2num(stringfromList(k, S.startxs, ","))
			fx = str2num(stringfromList(k, S.finxs, ","))
			chx = stringfromList(k, S.channelsx, ",")
			setpointx = sx + (inner_index*(fx-sx)/(S.numptsx-1))

			RampMultipleFDAC(chx, setpointx, ramprate=S.rampratex)  //limits will be checked here again.
		endfor
	endif

	if (!paramIsDefault(outer_index))
		checkStartsFinsChannels(S.startys, S.finys, S.channelsy)
		variable sy, fy, setpointy
		string chy
		for(k=0; k<itemsinlist(S.channelsy,","); k++)
			sy = str2num(stringfromList(k, S.startys, ","))
			fy = str2num(stringfromList(k, S.finys, ","))
			chy = stringfromList(k, S.channelsy, ",")
			setpointy = sy + (outer_index*(fy-sy)/(S.numptsy-1))
			RampMultipleFDAC(chy, setpointy, ramprate=S.rampratey) //limits will be checked here again.


		endfor
	endif
end

	
	
	


function initScanVarsFD(S, startx, finx, [channelsx, numptsx, sweeprate, duration, rampratex, delayx, starty, finy, channelsy, numptsy, rampratey, delayy, startxs, finxs, startys, finys, x_label, y_label, alternate,  interlaced_channels, interlaced_setpoints, comments, x_only, use_awg])
 // Initializes scan variables for FastDAC scanning operations.
    // The function allows setting up both x and y dimensions with various parameters,
    // including starting/ending points, channel identifiers, sweep rates, and more.
    // 
    // PARAMETERS:
    // S: ScanVars structure passed by reference to be initialized.
    // startx, finx: Starting and ending points for the x dimension.
    // channelsx, channelsy: Comma-separated strings of channels to be scanned in the x and y dimensions.
    // numptsx, numptsy: Number of points to be scanned in the x and y dimensions.
    // sweeprate: The sweep rate for the scan.
    // duration: The duration of the scan.
    // rampratex, rampratey: Ramp rates for the x and y dimensions.
    // delayx, delayy: Delays for the x and y dimensions.
    // startxs, finxs, startys, finys: Alternative to startx/finx for specifying multiple start/end points for each channel.
    // x_label, y_label: Labels for the x and y dimensions.
    // alternate: Flag to indicate alternate scanning.
    // interlaced_channels, interlaced_setpoints: Parameters for interlaced scanning.
    // comments: Comments or notes regarding the scan.
    // x_only: Flag to indicate if only x dimension is used.
    // use_awg: Flag to indicate if AWG is used in the scan.

    struct ScanVars &S
    variable x_only, startx, finx, numptsx, delayx, rampratex
    variable starty, finy, numptsy, delayy, rampratey
	variable sweeprate  // If start != fin numpts will be calculated based on sweeprate
	variable duration   // numpts will be caluculated to achieve duration
    variable alternate, use_awg
    string channelsx, channelsy
    string startxs, finxs, startys, finys
    string  x_label, y_label
    string interlaced_channels, interlaced_setpoints
    string comments
    nvar sc_hotcolddelay
    nvar silent_scan
	
    ///// Defaulting optional string parameters to empty if not provided /////
	channelsy = selectString(paramIsDefault(channelsy), channelsy, "")
	startys = selectString(paramIsDefault(startys), startys, "")
	finys = selectString(paramIsDefault(finys), finys, "")
	y_label = selectString(paramIsDefault(y_label), y_label, "")	

	channelsx = selectString(paramIsDefault(channelsx), channelsx, "")
	startxs = selectString(paramIsDefault(startxs), startxs, "")
	finxs = selectString(paramIsDefault(finxs), finxs, "")
	x_label = selectString(paramIsDefault(x_label), x_label, "")
	
	interlaced_channels = selectString(paramisdefault(interlaced_channels), interlaced_channels, "")
	interlaced_setpoints = selectString(paramisdefault(interlaced_setpoints), interlaced_setpoints, "")

	comments = selectString(paramIsDefault(comments), comments, "")
	x_only = paramisdefault(x_only) ? 1 : x_only
	use_awg = paramisdefault(use_awg) ? 0 : use_awg  
	
		if (use_awg == 1)
			check_if_awg_defined()
		endif


	///// Standard initialization /////
	initScanVars(S, startx=startx, finx=finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex,\
	starty=starty, finy=finy, channelsy=channelsy, numptsy=numptsy, rampratey=rampratey, delayy=delayy, \
	x_label=x_label, y_label=y_label, startxs=startxs, finxs=finxs, startys=startys, finys=finys, alternate=alternate,\
	interlaced_channels=interlaced_channels, interlaced_setpoints=interlaced_setpoints, comments=comments)
	
	
	///// Additional intialization for fastDAC scans /////
	string temp
	S.sweeprate = sweeprate
	S.duration = duration
	S.adcList = scf_getRecordedFADCinfo("channels")
	S.using_fastdac = 1
	S.adcListIDs = scf_getRecordedFADCinfo("adcListIDs");  //removed formatliststring
	S.adcLists = scf_getRecordedFADCinfo("raw_names")
	S.fakerecords = "0"
	S.lastread = -1
	S.silent_scan=silent_scan
  
	S.raw_wave_names=scf_getRecordedFADCinfo("raw_names")
	svar fd
	S.instrIDs=fd
	
	
	///// Sets channelsx, channelsy to be lists of channel numbers instead of labels /////
	scv_setChannels(S, channelsx, channelsy, fastdac=1)  
     
     
   	///// Get Labels for graphs /////
   	S.x_label = selectString(strlen(x_label) > 0, scu_getDacLabel(S.channelsx, fastdac=1), x_label)  // Uses channels as list of numbers, and only if x_label not passed in
   	if (S.is2d)
   		S.y_label = selectString(strlen(y_label) > 0, scu_getDacLabel(S.channelsy, fastdac=1), y_label) 
   	else
   		S.y_label = y_label
   	endif  		
	
	
	///// Setting daclistids for x and y /////
	S.daclistids = scu_getChannelNumbers(S.channelsx) //** Not sure if we even need daclistids in the future...
	S.dacListIDs_y = scu_getChannelNumbers(S.channelsy)


	///// Setting x and y setpoints /////
	scv_setSetpoints(S, channelsx, startx, finx, channelsy, starty, finy, startxs, finxs, startys, finys)
	
	
	    
                                
	///// Setting ramprate if zero /////
	variable fastdac_index
	wave /t fdacvalstr
	if (rampratex == 0)
		fastdac_index = get_fastdac_index(stringfromList(0, S.channelsx, ","), return_adc_index = 0)
		S.rampratex = str2num(fdacvalstr[fastdac_index][4])
	endif
	
	if (rampratey == 0)
		fastdac_index = get_fastdac_index(stringfromList(0, S.channelsy, ","), return_adc_index = 0)
		S.rampratey = str2num(fdacvalstr[fastdac_index][4])
	endif
		
	
	///// Removing delimiters /////
	// x-channel
	S.channelsx = removeTrailingDelimiter(S.channelsx)
	S.startxs = removeTrailingDelimiter(S.startxs)
	S.finxs = removeTrailingDelimiter(S.finxs)
	S.dacListIDs = removeTrailingDelimiter(S.dacListIDs)
	S.IDstartxs = removeTrailingDelimiter(S.IDstartxs)
	S.IDfinxs = removeTrailingDelimiter(S.IDfinxs)
	
	// y-channel
	S.channelsy = removeTrailingDelimiter(S.channelsy)
	S.startys = removeTrailingDelimiter(S.startys)
	S.finys = removeTrailingDelimiter(S.finys)
	S.dacListIDs_y = removeTrailingDelimiter(S.dacListIDs_y)
	
	// adc
	S.adcListIDs = removeTrailingDelimiter(S.adcListIDs)
	S.adcList = removeTrailingDelimiter(S.adcList)
	S.adcLists = removeTrailingDelimiter(S.adcLists)
	
	// wave-names
	S.raw_wave_names = removeTrailingDelimiter(S.raw_wave_names)
	
				
	///// Setting up AWG /////
	//*** Is information from the first AWG enough?
			S.wavelen = 1 
		S.numcycles = 1
		S.hotcolddelay=0
		
	S.use_awg = use_awg
	if (use_awg == 0)
		S.wavelen = 1 
		S.numcycles = 1
		S.hotcolddelay=0
	else
	
		wave /t sc_awg_info // ASSUME FIRST AWG HAS BEEN CREATED
		int num_setpoints = ItemsInList(sc_awg_info[1][0], ",")
		S.wavelen = str2num(sc_awg_info[2][0]) * num_setpoints
		S.numcycles = str2num(sc_awg_info[4][0])
		fdawg_check_awg_and_sweepgates_unique(S)
		S.hotcolddelay=sc_hotcolddelay
	endif
	
	///// Set variables with some calculation /////
    scv_setFreq(S=S) 		// Sets S.samplingFreq/measureFreq/numADCs	
    scv_setNumptsSweeprateDuration(S) 	// Checks that either numpts OR sweeprate OR duration was provided, and sets ScanVars accordingly
         
	///// Delete all files in fdTest directory /////
	remove_fd_files()
	scv_setLastScanVars(S)
//	print S
end


function getFDstatus()
	// returns jsonid of current FD status.
	struct ScanVars S
	scv_getLastScanVars(S)
	variable numDACCh, numADCCh

	svar fd
	wave/t fdacvalstr
	wave/t fadcvalstr
	wave/t ADC_channel
	wave/t DAC_channel
	string FDID_list=TextWavetolist(ADC_channel)
	string path

	variable level1, level2, jsonId
	string jsonStr
	JSONXOP_New; level1 = V_value
	JSONXOP_AddValue/T=(fd) level1, "http_address"
	JSONXOP_AddValue/V=(S.samplingFreq) level1, "samplingFreq"
	JSONXOP_AddValue/V=(S.MeasureFreq) level1, "MeasureFreq"
	JSONXOP_Addtree/T=0 level1, "DAC_channels"
	JSONXOP_Addtree/T=0 level1, "ADC_channels"


	variable i

	// update DAC values
	numDACCh=scfw_update_fdac("updatefdac")
	for(i=0;i<numDACCh;i+=1)
		path="DAC_channels/DAC"+DAC_channel[i]
		JSONXOP_AddValue/T=((fdacvalstr[i][1])) level1, path
	endfor

	// update ADC values
	numADCCh=scfw_update_fadc("")
	for(i=0;i<numADCCh;i+=1)
		path="ADC_channels/ADC"+ADC_channel[i]
		JSONXOP_AddValue/T=((fadcvalstr[i][1])) level1, path
	endfor


//		jsonxop_dump level1;
//		print "Full textual representation:\r", S_value

	return level1
end



function /t get_fastdac_labels([sort_fastdacs, fastdac_order])
	// assumes openFastDAC(portnum,[verbose]) has already been run so connections are open
	// default is to sort the fastdac_labels in ascending order
	// if sort_fastdacs == 0. Then fastdac_labels is returned instead.
	variable sort_fastdacs
	string fastdac_order
	
	sort_fastdacs = paramisdefault(sort_fastdacs) ? 1 : sort_fastdacs  // default is to sort the fastdac labels
	fastdac_order = selectString(paramIsDefault(fastdac_order), fastdac_order, "")

	string response = ""
	response = get_proxy_info()
	
	string proxies_info, fastdac_label, fastdac_labels = "", temp_parse
	
	proxies_info = getjsonvalue(response, "proxies_info")
	print proxies_info
	variable num_fastdacs = ItemsInList(proxies_info,  "label") - 1
	
	int i
	for (i = 1; i <= num_fastdacs; i++)
		temp_parse = stringFromList(i, proxies_info, "label")
		fastdac_label = stringFromList(0, stringFromList(1, temp_parse, ":"), ",")
		fastdac_label = fastdac_label[1, strlen(fastdac_label) - 2]
		fastdac_labels +=  fastdac_label + ";"
	endfor
	
	
	if (sort_fastdacs == 1)
		fastdac_labels = sort_text_wave(fastdac_labels, numeric_values = 1)
		return fastdac_labels
	else
		return fastdac_order
	endif

end


function get_number_of_fastdacs()
	// get number of FastDACS
	string fastdac_labels = get_fastdac_labels()
	variable num_fastdac = ItemsInList(fastdac_labels,  ";")

	return num_fastdac
end

function get_boxnum_dacnum(string daclist)
// after running this function three global waves are created/modified:
//boxnum: just the number of the fd box for all channels used in the scan
//unique_boxnum: which fd boxes are used in the scan?
//dacnum: what is the DAC number for the specific box in that scan?
int N=ItemsInList(daclist, ",");
	make/o/n=(N) boxnum
	make/o/n=(N) dacnum
	variable fd_num
	variable fd_ch
	variable i
	for (i = 0; i < ItemsInList(daclist, ","); i += 1)
		[fd_num, fd_ch] = get_fastdac_num_ch_string(stringfromlist(i,daclist,","))
		boxnum[i]=fd_num
		dacnum[i]=fd_ch
	endfor
	FindDuplicates/INDX=indexWave/RN=unique_boxnum boxnum
end

function [variable fd_num, variable fd_ch] get_fastdac_num_ch_variable(variable fd_num_ch)
	// get_fastdac_num_ch_variable(6.1) returns variable [6, 1]
	// USE :: 
	// variable fd_num, fd_ch
	// [fd_num, fd_ch] = get_fastdac_num_ch_variable(6.1)
	// but it can not be run from the command line, only inside functions
	fd_num = floor(fd_num_ch)
	fd_ch = (fd_num_ch - fd_num) * 10

	return [fd_num, fd_ch]
end


function [variable fd_num, variable fd_ch] get_fastdac_num_ch_string(string fd_num_ch)
	// get_fastdac_num_ch_string("6.1") returns variable [6, 1]
	// USE :: 
	// variable fd_num, fd_ch
	// [fd_num, fd_ch] = get_fastdac_num_ch_string("6.1")
	// but it can not be run from the command line, only inside functions

	fd_num = str2num(stringFromList(0, fd_num_ch, "."))
	fd_ch = str2num(stringFromList(1, fd_num_ch, "."))

	return [fd_num, fd_ch]
end


function get_fastdac_index(fd_num_ch, [return_adc_index])
	// assumes DAC_channel and ADC_channel have been created
	// checks the index based on string value of fd_num_ch
	// USE :: index = get_fastdac_index("7.3", return_adc_index=1)
	string fd_num_ch
	variable return_adc_index
	
	return_adc_index = paramisdefault(return_adc_index) ? 0 : return_adc_index  // default is to return DAC index, return_adc_index = 1 to return adc index


	variable index
	if (return_adc_index == 0)
		wave /t get_fastdac_index_wave = DAC_channel
	else
		wave /t get_fastdac_index_wave = ADC_channel
	endif
	
	int wave_len = dimsize(get_fastdac_index_wave, 0)
	
	// loop through wave
	int i = 0, count = 0
	for (i = 0; i < wave_len; i++)
		if (cmpstr(fd_num_ch, get_fastdac_index_wave[i]) == 0)
			index = i
			break
		endif
	endfor
	

	return index
end



function /t fd_get_unique_fastdac_from_dac(dac_channels)
	// returns a list of unique fastdac number from dac_channels
	// USE :: 
	// unique_fastdac_num =  fd_get_unique_gate("1,2.0',3,2.3,5.3,4.7,6.5,4.4")
	string dac_channels 
	
	string unique_fastdac_vals = ""
	variable unique_fastdac_val, unique_fastdac_numbers
	variable dac_channel, unique_true
	
	
	int num_dac_channels = itemsinlist(dac_channels, ",")
	int i, j, k
	for (i = 0; i < num_dac_channels; i++)
	
		dac_channel = str2num(stringFromList(i, dac_channels, ","))
		
		// add fastdac number if unique
		unique_fastdac_val = floor(dac_channel)
		unique_fastdac_numbers = itemsinlist(unique_fastdac_vals, ",")
		unique_true = 1
		for  (k = 0; k < unique_fastdac_numbers; k++)
			if (unique_fastdac_val == str2num(stringfromList(k, unique_fastdac_vals, ",")))
				unique_true = 0
			endif
		endfor
		
		if (unique_true == 1)
			unique_fastdac_vals += num2str(unique_fastdac_val) + ","
		endif
	
	endfor 
	
	return removetrailingDelimiter(unique_fastdac_vals)
	
	
end



function /t fd_get_ramp_dacs(S)
	// returns a list of dac numbers from channelsx, channelsx, interlaced_channels
	// USE :: 
	// ramp_dacs =  fd_get_ramp_dacs(S)
	struct ScanVars &S
	
	string ramp_dacs = ""
	
	ramp_dacs += S.channelsx + ","
	ramp_dacs += S.channelsy + ","
	
	int num_interlace_channels = itemsinlist(S.interlaced_channels, ",")
	string interlace_channel = "", interlace_channels = ""
	
	int i 
	for (i = 0; i < num_interlace_channels; i++)
		interlace_channel = stringfromList(i, S.interlaced_channels, ",")
		
		if (stringmatch(interlace_channel, "*awg*") == 0) // if no AWG in interlace channels
			interlace_channels += scu_getChannelNumbers(interlace_channel) + ","
		endif
	endfor
	
	ramp_dacs = removetrailingDelimiter(ramp_dacs) + "," // assert a trailing delimiter at the end
	ramp_dacs += removetrailingDelimiter(interlace_channels)
	
	return ramp_dacs
	
end



///////////////////////
//// API functions ////
///////////////////////


function set_one_fadcSpeed(int channo,int adcValue)
// this is done in initfastDAC()
	svar fd
	wave/t ADC_channel
	String cmd = "set-adc-sampling-time"
	// Convert variables to strings and construct the JSON payload dynamically
	String payload=""
	payload = "{\"access_token\": \"string\", \"fqpn\": \""  +ADC_channel[channo]+ "\", \"sampling_time_us\": " + num2str(adcValue) + "}"
	String headers = "accept: application/json\nContent-Type: application/json"
	// Perform the HTTP PUT request
	String response = postHTTP(fd, cmd, payload, headers)	
end

function reset_adc(int adcValue)
/// this command resets all ADC in a box
//not sure what this function actually does
	svar fd
	wave/t ADC_channel
	variable fd_num
	fd_num=floor(str2num(ADC_channel[adcValue]))
	String cmd = "reset-adcs/"
	String payload=""
	payload = num2str(fd_num)
	String headers = "accept: application/json"
	// Perform the HTTP PUT request
	String response = postHTTP(fd, cmd, payload, headers)
end

function fd_stopFDACsweep()
/// this command will stop any active sweep
	svar fd
	String cmd = "abort-active-cmd"
	String payload=""
	String headers ="accept: application/json\rContent-Type: application/json"

	// Perform the HTTP PUT request
	String response = postHTTP(fd, cmd, payload, headers)
		print "stopped FD Ramp"
end



function/s get_proxy_info()
	// assumes openFastDAC("51011", verbose=0) has been run so that 'fd' has been created
	svar fd
	string	response=getHTTP(fd,"get-proxies-info","");
	return response
	
end

function get_idn(string fd_id)
	svar fd
	string	response=getHTTP(fd,"get-idn/"+fd_id,"");
	print response
end

function get_one_fadcSpeed(int adcValue)
	svar fd
	wave/t ADC_channel
	string	response=getHTTP(fd,"get-adc-sampling-time/"+ADC_channel(adcValue),"");
//	print response
	string value
	value=getjsonvalue(response,"sampling_time_us")
	variable speed = str2num(value)
	return speed
end


function get_one_FADCChannel(channel_int, [channel_num]) // Units: mV
	// channel_int expects index of channel i.e. index 3
	// channel_num expects number of channel i.e. channel 4.3
	// if channel_num is not specified then channel_int is used.
	// otherwise channel_num is used 
	int channel_int
	variable channel_num
	
	channel_num = paramisdefault(channel_num) ? 0 : channel_num
	
	svar fd
	wave/t ADC_channel
	string	response
	if (channel_num == 0)
		response=getHTTP(fd,"get-adc-voltage/" + ADC_channel(channel_int), "")
	else
		response=getHTTP(fd,"get-adc-voltage/" + Num2StrF(channel_num, 1), "") // ensures 1 decimal place i.e. 4 -> 4.0
	endif
	string adc
	adc=getjsonvalue(response,"value")
	return str2num(adc)
end


function get_one_FDACChannel(channel_int, [channel_num]) // Units: mV
	// channel_int expects index of channel i.e. index 3
	// channel_num expects number of channel i.e. channel 4.3
	// if channel_num is not specified then channel_int is used.
	// otherwise channel_num is used 
	int channel_int
	variable channel_num
	
	channel_num = paramisdefault(channel_num) ? 0 : channel_num
	
	svar fd
	wave/t DAC_channel
	string	response
	if (channel_num == 0)
		response=getHTTP(fd,"get-dac-voltage/" + DAC_channel(channel_int), "")
	else
		response=getHTTP(fd,"get-dac-voltage/" + Num2StrF(channel_num, 1), "") // ensures 1 decimal place i.e. 4 -> 4.0
	endif
	string dac
	dac = getjsonvalue(response,"value")
	
	return str2num(dac)
end



function set_one_FDACChannel(int channel_int, variable setpoint, variable ramprate, [variable channel_num])
	// channel_int expects index of channel i.e. index 3
	// channel_num expects number of channel i.e. channel 4.3
	// if channel_num is not specified then channel_int is used.
	// otherwise channel_num is used 
	channel_num = paramisdefault(channel_num) ? 0 : channel_num
	
	wave/t DAC_channel
	svar fd
	String cmd = "ramp-dac-to-target"
	String payload
	if (channel_num == 0)
		payload = "{\"fqpn\": \"" + DAC_channel(channel_int) + "\", \"ramp_rate_mv_per_s\": " + num2str(ramprate) + ", \"target\": {\"unit\": \"mV\", \"value\": " + num2str(setpoint) + "}}"
	else
		payload = "{\"fqpn\": \"" + Num2StrF(channel_num, 1) + "\", \"ramp_rate_mv_per_s\": " + num2str(ramprate) + ", \"target\": {\"unit\": \"mV\", \"value\": " + num2str(setpoint) + "}}"
	endif
	String headers = "accept: application/json\nContent-Type: application/json"
	String response = postHTTP(fd, cmd, payload, headers)
	
end


function sample_ADC(string adclist, variable nr_samples)
	svar fd
	variable chunksize=1000
	variable level1
	String cmd = "start-samples-acquisition"
	
	stringlist2wave(adclist,"adc_list")
		wave adc_list

	JSONXOP_New; level1=V_value
	JSONXOP_AddValue/I=(82) level1, "/adc_sampling_time_us"
	JSONXOP_AddValue/T=(num2str(chunksize)) level1, "/chunk_max_samples"
	JSONXOP_AddValue/T="temp_{{.ChunkIndex}}.dat" level1, "/chunk_file_name_template"
	JSONXOP_AddValue/wave=adc_list level1, "/adc_list"
	JSONXOP_AddValue/I=(nr_samples) level1, "/nr_samples"
	jsonxop_dump/ind=2 level1 ///--->>> S_value

	String headers = "accept: application/json\nContent-Type: application/json"
	String response = postHTTP(fd, cmd, S_value, headers)
end


//function rampMultipleFDAC_parallel(channels, setpoints, ramprates)
//	string channels, setpoints, ramprates
//	
//	// calculate number of parameters
//	int num_channels = itemsInList(channels, ",")
//	int num_setpoints = itemsInList(setpoints, ",")
//	int num_ramprates = itemsInList(ramprates, ",")
//	
//	int single_setpoint
//	if (num_setpoints == 1)
//		single_setpoint = 1
//	elseif (num_channels == num_setpoints)
//		single_setpoint = 0
//	else
//		abort "Number of channels (" + num2str(num_channels) + ") and setpoints (" + num2str(num_setpoints) + ") does not match"
//	endif
//	
//	int single_ramprate
//	if (num_ramprates == 1)
//		single_ramprate = 1
//	elseif (num_channels == num_ramprates)
//		single_ramprate = 0
//	else
//		abort "Number of channels (" + num2str(num_channels) + ") and ramprates (" + num2str(num_ramprates) + ") does not match"
//	endif
//	
//	
//	
//	// start setting up the json
//	String adcList
//	Variable nr_samples = 1
//	variable chunksize=5000
//	SVar fd
//	variable level1, level2, level3
////	variable i
////	stringlist2wave(S.adcListIDs,"adc_list")
//	wave adc_list
//
//	JSONXOP_New; level1=V_value
//	JSONXOP_New; level2=V_value
//	JSONXOP_AddValue/I=(82) level1, "/adc_sampling_time_us"
//	JSONXOP_AddValue/T=(num2str(chunksize)) level1, "/chunk_max_samples"
//	JSONXOP_AddValue/T="temp_{{.ChunkIndex}}.dat" level1, "/chunk_file_name_template"
//	JSONXOP_AddValue/wave=adc_list level1, "/adc_list"
//	JSONXOP_AddValue/I=(nr_samples) level1, "/nr_steps"
//	string dacChannel, minvalue, maxvalue
//
////
////	for (i = 0; i < ItemsInList("alalalalala", ","); i += 1)
////		JSONXOP_New; level3=V_value
////		dacChannel = StringFromList(i, channels, ",")
////		minValue = StringFromList(i, S.startxs, ",")
////		maxValue = StringFromList(i, S.finxs, ",")
////		JSONXOP_AddTree/T=0 level3, "max"
////		JSONXOP_AddTree/T=0 level3, "min"
////		JSONXOP_Addvalue/V=(str2num(maxvalue)) level3, "/max/value"
////		JSONXOP_Addvalue/V=(str2num(minvalue)) level3, "/min/value"
////		JSONXOP_Addvalue/T="mV" level3, "max/unit"
////		JSONXOP_Addvalue/T="mV" level3, "min/unit"
////		JSONXOP_AddValue/JOIN=(level3) level2, dacChannel
////		JSONXOP_Release level3
////	endfor
////
////	JSONXOP_AddValue/JOIN=(level2) level1, "/dac_range_map"
////	jsonxop_dump/ind=2 level1
////	//print "Full textual representation:\r", S_value
////	string cmd="start-linear-ramps"
////	String headers = "accept: application/json\nContent-Type: application/json"
////	String response = postHTTP(fd, cmd, S_value, headers)
////	
//	
//	
//	
//	// loop through DAC channels to build json
//	string channel, setpoint, ramprate
//	int i
//	for (i = 0; i < num_channels; i++)
//	
//		channel = stringfromlist(i, channels, ",")
//		if (single_ramprate == 1)
//			ramprate = ramprates
//		else
//			ramprate = stringfromlist(i, ramprates, ",")
//		endif
//		if (single_setpoint == 1)
//			setpoint = setpoints
//		else
//			setpoint = stringfromlist(i, setpoints, ",")
//		endif
//		
//	endfor
//	
//	
//end



Function linear_ramp(S)
	Struct ScanVars &S
	String adcList
	Variable nr_samples = S.numptsx
	variable chunksize=5000
	SVar fd
	variable level1, level2, level3
	variable i
	stringlist2wave(S.adcListIDs,"adc_list")
	wave adc_list

	JSONXOP_New; level1=V_value
	JSONXOP_New; level2=V_value
	JSONXOP_AddValue/I=(S.sampling_time) level1, "/adc_sampling_time_us"
	JSONXOP_AddValue/T=(num2str(chunksize)) level1, "/chunk_max_samples"
	JSONXOP_AddValue/T="temp_{{.ChunkIndex}}.dat" level1, "/chunk_file_name_template"
	JSONXOP_AddValue/wave=adc_list level1, "/adc_list"
	JSONXOP_AddValue/I=(S.numptsx) level1, "/nr_steps"
	string dacChannel, minvalue, maxvalue


	for (i = 0; i < ItemsInList(S.daclistIDs, ","); i += 1)
		JSONXOP_New; level3=V_value
		dacChannel = StringFromList(i, S.daclistIDs, ",")
		minValue = StringFromList(i, S.startxs, ",")
		maxValue = StringFromList(i, S.finxs, ",")
		JSONXOP_AddTree/T=0 level3, "max"
		JSONXOP_AddTree/T=0 level3, "min"
		JSONXOP_Addvalue/V=(str2num(maxvalue)) level3, "/max/value"
		JSONXOP_Addvalue/V=(str2num(minvalue)) level3, "/min/value"
		JSONXOP_Addvalue/T="mV" level3, "max/unit"
		JSONXOP_Addvalue/T="mV" level3, "min/unit"
		JSONXOP_AddValue/JOIN=(level3) level2, dacChannel
		JSONXOP_Release level3
	endfor

	JSONXOP_AddValue/JOIN=(level2) level1, "/dac_range_map"
	jsonxop_dump/ind=2 level1
	//print "Full textual representation:\r", S_value
	string cmd="start-linear-ramps"
	String headers = "accept: application/json\nContent-Type: application/json"
	String response = postHTTP(fd, cmd, S_value, headers)

End


function /t fd_get_unique_fastdac_number(S)
	Struct ScanVars &S
	// returns unique fastdac numbers from channelsx
	// if AWG_on = 1 then includes dac channels from AWG also

	string dac_channels = removetrailingDelimiter(S.channelsx) // remove delimiter just in case
	
	if (S.use_AWG == 1)
		dac_channels += "," + fdawg_get_all_dac_channels()
	endif
	
	return fd_get_unique_fastdac_from_dac(dac_channels)
end


function fd_reset_start_fin_from_direction(S)
	// swaps the start and fin if direction is -1. 
	Struct ScanVars &S
	
	variable startx = S.startx;
	variable finx = S.finx;
	string startxs = S.startxs;
	string finxs = S.finxs;
	
	if (S.direction == -1)
		S.startx = finx
		S.finx = startx
		S.startxs = finxs
		S.finxs = startxs
	endif

end


Function awg_ramp(S)
	Struct ScanVars &S
	String adcList
	Variable nr_samples = S.numptsx
	variable chunksize=5000
	SVar fd
	variable level1, level2, level3,level4,level5

	jsonxop_release/a
	stringlist2wave(S.adcListIDs,"adc_list")
	wave adc_list
	JSONXOP_New; level1=V_value
	JSONXOP_New; level2=V_value
	JSONXOP_AddValue/wave=adc_list level1, "/adcs_to_acquire"
	JSONXOP_AddValue/T=(num2str(chunksize)) level1, "/chunk_max_samples"
	JSONXOP_AddValue/I=(S.sampling_time) level1, "/adc_sampling_time_us"
	JSONXOP_AddValue/T="temp_{{.ChunkIndex}}.dat" level1, "/chunk_file_name_template"

	string dacChannel, minvalue, maxvalue
	wave /t sc_awg_info
	variable number_of_awgs = dimsize(sc_awg_info, 1)
	variable awg_fastdac_num
	
	string linear_channels = S.channelsx
	
	string unique_fastdac_numbers  = fd_get_unique_fastdac_number(S)
	variable num_unique_fastdac = itemsinList(unique_fastdac_numbers, ",")
	
	int dac_index, awg_index, unique_fastdac_num
	variable fd_num, fd_ch
	
	
	int i, j
	for (i = 0; i < num_unique_fastdac; i++)
		JSONXOP_New; level3 = V_value
		JSONXOP_New; level4 = V_value
		
		unique_fastdac_num = str2num(stringfromlist(i, unique_fastdac_numbers, ","))

		
		///// loop through DAC channels that are ramping ////// 
		for (j = 0; j < itemsinlist(linear_channels, ","); j++)
			[fd_num, fd_ch] = get_fastdac_num_ch_string(stringfromList(j, linear_channels, ","))
			
			///// add values from FastDACs /////
			if (fd_num == unique_fastdac_num)

				minValue = StringFromList(j, S.startxs, ",")
				maxValue = StringFromList(j, S.finxs, ",")
				level5 = linear_ramps_json(maxValue, minValue) // Assuming this function correctly handles JSON object creation
				JSONXOP_AddValue/JOIN=(level5) level4, num2str(round(fd_ch))
				jsonxop_release level5
//				jsonxop_dump/ind=2 level4

			endif

		endfor
		
		
		JSONXOP_AddValue/I=(S.numptsx) level3, "/linear_ramp_steps"
		JSONXOP_AddValue/JOIN=(level4) level3, "linear_ramps"

		JSONXOP_AddValue/I=(S.numCycles) level3, "/patterns_per_linear_ramp_step" //**tODOD SHOULD THIS BE FROM SCANVARS?
		
		JSONXOP_Addtree/T=1 level3, "wave_patterns"
		
		
		////// loop through AWGs /////
		for (j = 0; j < number_of_awgs; j++)
			awg_fastdac_num = str2num(sc_awg_info[3][j])
			
			// add values from AWGs
			if (awg_fastdac_num == unique_fastdac_num)
				level5 = fdawg_wave_pattern(j)
				JSONXOP_AddValue/JOIN=(level5) level3, "wave_patterns"
//				jsonxop_dump/ind=2 level3
			endif

		endfor
		
		JSONXOP_AddValue/JOIN=(level3) level2, num2str(unique_fastdac_num)
//		jsonxop_dump/ind=2 level3
		jsonxop_release level3
		
	endfor

	JSONXOP_AddValue/JOIN=(level2) level1, "/awgs"
	jsonxop_dump/ind=2 level1

	string cmd="start-awg"
	String headers = "accept: application/json\nContent-Type: application/json"
	command_save(S_value)
	
	String response = postHTTP(fd, cmd, S_value, headers)
End


function fdawg_wave_pattern(AWG_index)
	int AWG_index
	// creates AWG wave for AWG number 'AWG_index'
	// assumes sc_awg_info has been created
	wave /t sc_awg_info
	
	variable setpoint, wavelen
	variable jsonId
	
	wave/b dac_channels = fdawg_get_DAC_channels_in_AWG(AWG_index)
//	duplicate /o/b numericwave dac_channels
	matrixop /o dac_channels = int8(dac_channels)
	
	///// adding DAC channels /////
	JSONXOP_New
	jsonId = V_value
	JSONXOP_AddValue/wave=dac_channels jsonid, "output_dacs"


	///// adding setpoints /////
	string setpoints = fdawg_get_DAC_setpoints_in_AWG(AWG_index)
	variable num_setpoints_per_awg = fdawg_get_number_DAC_setpoints_in_AWG(AWG_index)
	JSONXOP_AddTree/T=1 jsonId, "/dac_set_points"
	JSONXOP_AddValue/OBJ=(num_setpoints_per_awg) jsonId, "/dac_set_points"


	int i
	for (i = 0; i < num_setpoints_per_awg; i++)
		setpoint = str2num(stringfromlist(i, setpoints, ","))
		wavelen = str2num(sc_awg_info[2][AWG_index])
		
		JSONXOP_AddTree/T=0 jsonId, "/dac_set_points/" + num2str(i) + "/voltage"
		JSONXOP_AddTree/T=0 jsonId, "/dac_set_points/" + num2str(i) + "/voltage"

		JSONXOP_AddValue/t="mV" jsonId, "/dac_set_points/" + num2str(i) + "/voltage/unit"
		JSONXOP_AddValue/v=(setpoint) jsonId, "/dac_set_points/" + num2str(i) + "/voltage/value"
		JSONXOP_AddValue/v=(wavelen) jsonId, "/dac_set_points/" + num2str(i) + "/adc_samples"

	endfor
	
	jsonxop_dump/ind=2 jsonid


	return jsonId
		
//	variable jsonId
//	wave setpoint, samples, daclist
//	variable N = dimsize(setpoint, 0)
//
//	JSONXOP_New
//	jsonId = V_value
//	JSONXOP_AddValue/wave=daclist jsonid, "output_dacs"
//
//	JSONXOP_AddTree/T=1 jsonId, "/dac_set_points"
//	JSONXOP_AddValue/OBJ=(N) jsonId, "/dac_set_points"
//
//	variable i=0
//	for (i = 0; i < N; i++)
//		JSONXOP_AddTree/T=0 jsonId, "/dac_set_points/"+num2str(i)+"/voltage"
//		JSONXOP_AddTree/T=0 jsonId, "/dac_set_points/"+num2str(i)+"/voltage"
//
//		JSONXOP_AddValue/t="mV" jsonId, "/dac_set_points/"+num2str(i)+"/voltage/unit"
//		JSONXOP_AddValue/v=(setpoint[i]) jsonId, "/dac_set_points/"+num2str(i)+"/voltage/value"
//		JSONXOP_AddValue/v=(samples[i]) jsonId, "/dac_set_points/"+num2str(i)+"/adc_samples"
//	endfor
//
//	return jsonId

End


function linear_ramps_json(string maxvalue,string minvalue)

	variable level5
	JSONXOP_New; level5=V_value
	JSONXOP_AddTree/T=0 level5, "max"
	JSONXOP_AddTree/T=0 level5, "min"
	JSONXOP_Addvalue/V=(str2num(maxvalue)) level5, "/max/value"
	JSONXOP_Addvalue/V=(str2num(minvalue)) level5, "/min/value"
	JSONXOP_Addvalue/T="mV" level5, "max/unit"
	JSONXOP_Addvalue/T="mV" level5, "min/unit"
	return level5

end


function remove_fd_files()
variable i
string currentfile
	String fileList = IndexedFile(fdTest, -1, ".dat") // List all .dat files in fdTest
	Variable numFiles = ItemsInList(fileList)
	for (i = 0; i < numFiles; i += 1)
				currentFile = StringFromList(i, fileList)

		DeleteFile/P=fdTest/Z=1 currentFile // Delete the file after processing
	endfor
end




///////////////////////
//// PID functions ////
///////////////////////

function startPID(instrID)
	// Starts the PID algorithm on DAC and ADC channels 0
	// make sure that the PID algorithm does not return any characters.
	variable instrID
	
	string cmd=""
	sprintf cmd, "START_PID"
	writeInstr(instrID, cmd+"\r")
end


function stopPID(instrID)
	// stops the PID algorithm on DAC and ADC channels 0
	variable instrID
	
	string cmd=""
	sprintf cmd, "STOP_PID"
	writeInstr(instrID, cmd+"\r")
end


function setPIDTune(instrID, kp, ki, kd)
	// sets the PID tuning parameters
	variable instrID, kp, ki, kd
	
	string cmd=""
	// specify to print 9 digits after the decimal place
	sprintf cmd, "SET_PID_TUNE,%.9f,%.9f,%.9f",kp,ki,kd

	writeInstr(instrID, cmd+"\r")
end


function setPIDSetp(instrID, setp)
	// sets the PID set point, in mV
	variable instrID, setp
	
	string cmd=""
	sprintf cmd, "SET_PID_SETP,%f",setp

   	writeInstr(instrID, cmd+"\r")
end


function setPIDLims(instrID, lower,upper) //mV, mV
	// sets the limits of the controller output, in mV 
	variable instrID, lower, upper
	
	string cmd=""
	sprintf cmd, "SET_PID_LIMS,%f,%f",lower,upper

   	writeInstr(instrID, cmd+"\r")
end


function setPIDDir(instrID, direct) // 0 is reverse, 1 is forward
	// sets the direction of PID control
	// The default direction is forward 
	// The process variable of a reverse process decreases with increasing controller output 
	// The process variable of a direct process increases with increasing controller output 
	variable instrID, direct 
	
	string cmd=""
	sprintf cmd, "SET_PID_DIR,%d",direct
   	writeInstr(instrID, cmd+"\r")
end


function setPIDSlew(instrID, [slew]) // maximum slewrate in mV per second
	// the slew rate is proportional how fast the controller output is allowed to ramp
	variable instrID, slew 
	
	if(paramisdefault(slew))
		slew = 10000000.0
	endif
		
	string cmd=""
	sprintf cmd, "SET_PID_SLEW,%.9f",slew
	print/D cmd
   	writeInstr(instrID, cmd+"\r")
end



/////////////
//// AWG ////
/////////////
function fdawg_create(dac_channels, setpoints, wavelen, [num_cycles, overwrite, print_on])
	// Adds information to global waves '' '' ''
	// If overwrite = 1 then delete global wave
	// If overwrite = 0 then append to gloabl wave
	// USE ::
	// fdawg_create("12.0,12.1", "0,1,2", "10", overwrite = 1, print_on = 1)
	// fdawg_create("7.0", "0,1,2,10,-10,100", "10", overwrite = 0, print_on = 1)
	string dac_channels, setpoints
	string wavelen
	int num_cycles, overwrite, print_on
	
	num_cycles = paramisdefault(num_cycles) ? 1 : num_cycles  // default is for a single cycle
	overwrite = paramisdefault(overwrite) ? 1 : overwrite  // default is to overwrite previous AWG waves
	print_on = paramisdefault(print_on) ? 1 : print_on  // default is to print previous sc_awg_info if it exists

	
	// print the current awg_wave incase overwrite == 0 is accidentally not set
	wave /t sc_awg_info
	if ((waveexists(sc_awg_info) == 1) && (print_on == 1))
		print sc_awg_info
	endif
	
	// row 0 = DAC channels
	// row 1 = DAC setpoints 
	// row 2 = wavelen
	// row 3 = fastdac number (boxnum)
	// row 4 = num cycles
	
	// each row is a new DAC channel in AWG (max 8 rows in AWG)
	// each column is a new AWG 
	
	
	// overwrite old sc_awg_info or create new wave
	if (overwrite == 1)
		killwaves /Z sc_awg_info
		make /o/t/n=(5,1) sc_awg_info
	else
		InsertPoints /M=1 /V=0 inf, 1, sc_awg_info
	endif
	
	wave /t sc_awg_info
	
	
	// parameters for looping through DAC channels
	int num_awg = dimsize(sc_awg_info, 1) - 1
	variable num_dac_channels = itemsInList(dac_channels, ",")
	variable num_setpoints = itemsInList(setpoints, ";")
	
	string normalised_dac_channels = ""
	variable boxnum
	int i 
	
	////////////////////////////////////////////
	///// ADDING INFO TO SC_AWG_INFO WAVE //////
	////////////////////////////////////////////
	///// input DAC channels /////
	for (i = 0; i < num_dac_channels; i++)
		normalised_dac_channels += scu_getChannelNumbers(stringfromlist(i, dac_channels, ",")) + ","
	endfor
	normalised_dac_channels = removetrailingDelimiter(normalised_dac_channels)
	sc_awg_info[0][num_awg] = normalised_dac_channels
	
	
	///// input DAC setpoints /////
	sc_awg_info[1][num_awg] = setpoints

	
	///// input wavelen /////
	sc_awg_info[2][num_awg] = wavelen

	
	///// fastdac number /////
	boxnum = floor(str2num(stringFromList(0, normalised_dac_channels, ",")))
	for (i = 0; i < num_dac_channels; i++)
		if (boxnum != floor(str2num(stringFromList(i, normalised_dac_channels, ","))))
			abort "[WARNING] AWG : Cannot create awg with gates on different fastdacs"
		endif
	endfor
	sc_awg_info[3][num_awg] = num2str(boxnum)
	
	
	///// input number of cycles /////
	sc_awg_info[4][num_awg] = num2str(num_cycles)
	
	
	/////////////////////////////////////////////////
	///// CHECKING SC_AWG_INFO WAVE FOR SAFETY //////
	/////////////////////////////////////////////////
	///// Are the gates unique?
	fdawg_check_unique_gate()
	
	///// Are the AWG lengths equal?
	fdawg_check_awg_lengths_equal()
	
	///// Maximum two AWGs per FastDAC?
	fdawg_check_maximum_numer_of_awgs()

end



function fdawg_check_unique_gate()
	// assumes the wave 'sc_awg_info' has been created
	// will abort if with warning message if there are duplicate gates.
	wave /t sc_awg_info
	
	// gate values in 'sc_awg_info[X][X][0]'
	
	///// create DAC list first /////
	string dac_channels = fdawg_get_all_dac_channels()
	
	int num_dac_channels = itemsinlist(dac_channels, ",")
	
	variable dac_channel
	int i, j
	for (i = 0; i < num_dac_channels - 1; i++)
	
		dac_channel = str2num(stringFromList(i, dac_channels, ","))
		
		for (j = i + 1; j < num_dac_channels; j++)
		
			if (dac_channel == str2num(stringFromList(j, dac_channels, ",")))
				abort "[WARNING] AWG : Same gate on more than one AWG"
			endif
			
		endfor 
	
	endfor 
	
end



function fdawg_check_awg_lengths_equal()
	// assumes the wave 'sc_awg_info' has been created
	// will abort if with warning message if there are duplicate gates.
	wave /t sc_awg_info
		
	///// create AWG lengths list first /////
	string awg_lengths = fdawg_get_AWG_lengths()
	
	int num_awgs = dimsize(sc_awg_info, 1)
		
	variable awg_length
	int i, j
	for (i = 0; i < num_awgs - 1; i++)
	
		awg_length = str2num(stringFromList(i, awg_lengths, ","))
		
		for (j = i + 1; j < num_awgs; j++)
		
			if (awg_length != str2num(stringFromList(j, awg_lengths, ",")))
				abort "[WARNING] AWG : AWG lengths are NOT equal i.e. (num_setpoints * wavelen * num_cycles)"
			endif
			
		endfor 
		
	endfor 

end


function fdawg_check_maximum_numer_of_awgs()
	// check that only two AWGs are created per fastdac
	// assumes the wave 'sc_awg_info' has been created
	// will abort if with warning message if there are duplicate gates.
	wave /t sc_awg_info
	string abort_message = ""
	
	int MAX_AWG_PER_FASTDAC = 2
	
	int num_awgs = dimsize(sc_awg_info, 1)
	int awg_count, boxnum1, boxnum2
	
	variable awg_length
	int i, j
	for (i = 0; i < num_awgs; i++)
		awg_count = 0
	
		boxnum1 = str2num(sc_awg_info[3][i])
		
		for (j = 0; j < num_awgs; j++)
		
			boxnum2 = str2num(sc_awg_info[3][j])
		
			if (boxnum1 == boxnum2)
				awg_count += 1
			endif
			
			if (awg_count > MAX_AWG_PER_FASTDAC)
				abort_message = "[WARNING] " + num2str(awg_count) + " AWGs set on FastDAC " + num2str(boxnum1) + " : the Arduino will explode..."
				abort abort_message 
			endif
		
			
		endfor 
		
	endfor
	
end



function fdawg_check_awg_and_sweepgates_unique(S)
	// added in initscanvars to ensure the AWG DACs and Ramping DACs are unique
	// assumes the wave 'sc_awg_info' has been created
	// will abort if with warning message if there are duplicate gates.
	struct ScanVars &S
	wave /t sc_awg_info
	string abort_message
		
	///// create AWG lengths list first /////
	string sweep_dac_channels = fd_get_ramp_dacs(S)
	string awg_dac_channels = fdawg_get_all_dac_channels()
	
	string dac_channels = sweep_dac_channels + "," + awg_dac_channels
	int num_dacs = itemsinlist(dac_channels, ",")
		
	variable dac_channel
	int i, j
	for (i = 0; i < num_dacs - 1; i++)
	
		dac_channel = str2num(stringFromList(i, dac_channels, ","))
		
		for (j = i + 1; j < num_dacs; j++)
		
			if (dac_channel == str2num(stringFromList(j, dac_channels, ",")))
				abort_message = "[WARNING] Channel " + num2str(dac_channel) + " on both AWG and Sweepgates. Unpredicatable Behaviour"
				abort abort_message
			endif
			
		endfor 
		
	endfor 

end



function /t fdawg_get_all_dac_channels()
	// assumes the wave 'sc_awg_info' has been created
	// returns a list of all the dac channels using in sc_awg_info across all AWGs
	
	wave /t sc_awg_info	
	
	///// create DAC list first /////
	string dac_channels = "", dac_channel = ""
	variable num_awg = dimsize(sc_awg_info, 1)
	
	int i, j
	for (i = 0; i < num_awg; i++)
		dac_channel = sc_awg_info[0][i]
			
		if (strlen(dac_channel) > 0)
			dac_channels += dac_channel + ","
		endif
			
	endfor
	
	return removetrailingDelimiter(dac_channels)
end



function /t fdawg_get_AWG_lengths()
	// assumes the wave 'sc_awg_info' has been created
	// returns a comma separated list aWG lengths using formula
	// awg_num_setpoints * awg_wavelen * awg_num_cycles
	// USE ::
	// string awg_lengths = fdawg_get_AWG_lengths()
	
	wave /t sc_awg_info	
	
	///// create DAC list first /////
	string awg_lengths = ""
	variable awg_length = 0
	variable num_awg = dimsize(sc_awg_info, 1)
	
	variable awg_num_setpoints, awg_wavelen, awg_num_cycles
	
	int i, j
	for (i = 0; i < num_awg; i++)
	
		awg_num_setpoints = itemsinlist(sc_awg_info[1][i], ",")
		awg_wavelen = str2num(sc_awg_info[2][i])
		awg_num_cycles = str2num(sc_awg_info[4][i])
		
		awg_length = awg_num_setpoints * awg_wavelen * awg_num_cycles
		awg_lengths += num2str(awg_length) + ","
			
	endfor
	
	return removetrailingDelimiter(awg_lengths)
end



function fdawg_get_number_DACs_in_AWG(AWG_index)
	// return the number of DAC channels in the AWG wave specified by AWG_index
	// assumes sc_awg_info has been created
	// USE ::
	// print fdawg_get_number_DACs_in_AWG(0)
	int AWG_index
	
	wave /t sc_awg_info
	int num_dacs = 0 
	string dac_val = ""
	
	dac_val = sc_awg_info[0][AWG_index]
	num_dacs = itemsinlist(dac_val, ",")
	
	return num_dacs

end



function /wave fdawg_get_DAC_channels_in_AWG(AWG_index)
	// return the number of DAC channels in the AWG wave specified by AWG_index
	// assumes sc_awg_info has been created
	// USE ::
	// print fdawg_get_number_DACs_in_AWG(0)
	int AWG_index
	
	wave /t sc_awg_info
	int num_dacs = 0 
	string dac_val = ""
	
	///// create num wave of dac channels
	dac_val = sc_awg_info[0][AWG_index]
	killwaves /z numericWave
	StringToListWave(dac_val + ",")
	wave numericWave


	///// now only pick the DAC number, not the fastdac number
	variable num_dacs_in_awg = fdawg_get_number_DACs_in_AWG(AWG_index)
	variable fd_num, fd_ch
	
	int i
	for (i = 0; i < num_dacs_in_awg; i++)
	
		[fd_num, fd_ch] = get_fastdac_num_ch_variable(numericWave[i])
		numericWave[i] = round(fd_ch)
		
	endfor
	
	return numericWave

end




function /s fdawg_get_DAC_setpoints_in_AWG(AWG_index)
	// return the DAC setpoints as a string
	// assumes sc_awg_info has been created
	// USE ::
	// print fdawg_get_number_DACs_in_AWG(0)
	int AWG_index

	wave /t sc_awg_info
	
	string dac_setpoints = sc_awg_info[1][AWG_index]
	
	return dac_setpoints

end



function fdawg_get_number_DAC_setpoints_in_AWG(AWG_index)
	// return the number of DAC setpoints
	// assumes sc_awg_info has been created
	// USE ::
	// print fdawg_get_number_DAC_setpoints_in_AWG(0)
	int AWG_index

	string dac_setpoints = fdawg_get_DAC_setpoints_in_AWG(AWG_index)
	
	variable num_setpoints = itemsinlist(dac_setpoints, ",")
	
	return num_setpoints

end



function fdawg_ramp_DACs_to_zero()
	// ramps all the AWG dac channels to zero
	// assumes sc_awg_info has been created
	// USE ::
	// print fdawg_ramp_DACs_to_zero()
	
	string dac_channels = fdawg_get_all_dac_channels()
	rampmultiplefdac(dac_channels, 0)
	
end


///////////////////
//// Utilities ////
///////////////////
function fd_get_numpts_from_sweeprate(start, fin, sweeprate, measureFreq,wavelen,numCycles)
/// Convert sweeprate in mV/s to numptsx for fdacrecordvalues
	variable start, fin, sweeprate, measureFreq,wavelen,numCycles
	if (start == fin)
		abort "ERROR[fd_get_numpts_from_sweeprate]: Start == Fin so can't calculate numpts"
	endif
	variable numpts = round(abs(fin-start)*measureFreq/sweeprate/wavelen/numcycles)   // distance * steps per second / sweeprate
	return numpts
end


function fd_get_sweeprate_from_numpts(start, fin, numpts, measureFreq,wavelen,numCycles)
	// Convert numpts into sweeprate in mV/s
	variable start, fin, numpts, measureFreq,wavelen,numCycles
	if (numpts == 0)
		abort "ERROR[fd_get_numpts_from_sweeprate]: numpts = 0 so can't calculate sweeprate"
	endif
	variable sweeprate = round(abs(fin-start)*measureFreq/numpts/wavelen/numCycles)   // distance * steps per second / numpts
	return sweeprate
end



Function update_ADC_sampling_time(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval; print dval
			String sval = sva.sval
			setadc_speed(dval)

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
