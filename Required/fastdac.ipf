#pragma TextEncoding = "UTF-8"
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
	//http_address="master.qdev-h101.lab:xxx"



	if(paramisdefault(verbose))
		verbose=1
	elseif(verbose!=1)
		verbose=0
	endif

	string comm = ""
	sprintf comm, "instrID=%s,url=%s" IDname, http_address
	string response = ""

	openHTTPinstr(comm, verbose=verbose)  // Sets svar (instrID) = url

	if (verbose==1)
		response=getHTTP(http_address,"idn","");
		print getjsonvalue(response,"idn")
	endif
end


```

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
		temp_string = "10000"
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
	make /o /T /n=(num_fastdac * num_adc, 8) adc_table
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



function initFastDAC()
// usage: init_dac_and_adc("1;2;4;6")
//Edit/K=0 root:adc_table;Edit/K=0 root:dac_table
wave/t adc_table, dac_table
wave/t fdacvalstr
make/o/t/n=(dimsize(ADC_table,0)) ADC_channel
make/o/t/n=(dimsize(DAC_table,0)) DAC_channel
ADC_channel=adc_table[p][0]
DAC_channel=dac_table[p][0]

nvar filenum
getFDIDs()

	// hardware limit (mV)
	variable i=0, numDevices = dimsize(ADC_channel,0)/4
	variable numDACCh=dimsize(DAC_channel,0), numADCCh=numDACch/2;
	
	// create waves to hold control info
	variable oldinit = scfw_fdacCheckForOldInit(numDACCh,numADCCh)

	// create GUI window
	string cmd = ""
	//variable winsize_l,winsize_r,winsize_t,winsize_b
	getwindow/z ScanControllerFastDAC wsizeRM
	killwindow/z ScanControllerFastDAC
	//sprintf cmd, "FastDACWindow(%f,%f,%f,%f)", v_left, v_right, v_top, v_bottom
	//execute(cmd)
	killwindow/z after1
	execute("after1()")	
	//setadc_speed()
end

function setADC_speed()
svar fd
wave/t ADC_channel
variable i=0
do 
set_one_fadcSpeed(i,82)
//print get_one_fadcSpeed(i)
i=i+1
while(i<dimsize(ADC_channel,0))
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
    // channels - A comma-separated list of channels to be ramped.
    // setpoint - A common setpoint to ramp all channels to (ignored if setpoints_str is provided).
    // ramprate - The ramp rate in mV/s for all channels. If not specified, uses each channel's configured ramp rate.
    // setpoints_str - An optional comma-separated list of setpoints, allowing individual setpoints for each channel.

 
    
    // If ramprate is not specified or not a number, default to 1000 (this is mostly safe)
    ramprate = numtype(ramprate) == 0 ? ramprate : 1000

    // Convert channel identifiers to numbers, supporting both numerical IDs and named channels
    channels = scu_getChannelNumbers(channels)
    
    // Abort if the number of channels and setpoints do not match when individual setpoints are provided
    if (!paramIsDefault(setpoints_str) && (itemsInList(channels, ",") != itemsInList(setpoints_str, ","))) 
        abort "ERROR[RampMultipleFdac]: Number of channels does not match number of setpoints in setpoints_str"    
    endif
    
    // Initialize variables for the loop
    Variable i = 0, channel, nChannels = ItemsInList(channels, ",")
    Variable channel_ramp  // Not used, consider removing if unnecessary
    
    // Loop through each channel to apply the ramp
    for (i = 0; i < nChannels; i += 1)
        // If individual setpoints are provided, override the common setpoint with the specific value for each channel
        if (!paramIsDefault(setpoints_str)) 
            setpoint = str2num(StringFromList(i, setpoints_str, ","))
        endif
        
        // Extract the channel number from the list and ramp to the setpoint
        channel = str2num(StringFromList(i, channels, ","))
        fd_rampOutputFDAC(channel, setpoint, ramprate)  // Ramp the channel to the setpoint at the specified rate
    endfor
End




Function fd_rampOutputFDAC(int channel, variable setpoint, variable ramprate) // Units: mV, mV/s
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



function fd_initGlobalAWG()
	Struct AWGVars S
	// Set empty strings instead of null
	S.AW_waves   = ""
	S.AW_dacs    = ""
	S.AW_dacs2   = ""
	S.channels_AW0   = ""
	S.channels_AW1   = ""
	S.channelIDs = ""
	S.InstrIDs   = "" 
	
	fd_setGlobalAWG(S)
end


function fd_setGlobalAWG(S)
	// Function to store values from AWG_list to global variables/strings/waves
	// StructPut ONLY stores VARIABLES so have to store other parts separately
	struct AWGVars &S

	// Store String parts  
	make/o/t fd_AWGglobalStrings = {S.AW_Waves, S.AW_dacs, S.AW_dacs2, S.channels_AW0, S.channels_AW1, S.channelIDs, S.InstrIDs}

	// Store variable parts
	make/o fd_AWGglobalVars = {S.initialized, S.use_AWG, S.lims_checked, S.waveLen, S.numADCs, S.samplingFreq,\
		S.measureFreq, S.numWaves, S.numCycles, S.numSteps, S.maxADCs}
end


function SetAWG(A, state)
	// Set use_awg state to 1 or 0
	struct AWGVars &A
	variable state
	
	if (state != 0 && state != 1)
		abort "ERROR[SetAWGuseState]: value must be 0 or 1"
	endif
	if (A.initialized == 0 || numtype(strlen(A.AW_Waves)) != 0 || numtype(strlen(A.AW_dacs)) != 0)
		fd_getGlobalAWG(A)
	endif
	A.use_awg = state
	fd_setGlobalAWG(A)
end


function fd_getGlobalAWG(S)
	// Function to get global values for AWG_list that were stored using set_global_AWG_list()
	// StructPut ONLY gets VARIABLES
	struct AWGVars &S
	// Get string parts
	wave/T t = fd_AWGglobalStrings
	
		if (!WaveExists(t))
		fd_initGlobalAWG()
		wave/T t = fd_AWGglobalStrings
	endif
	
	S.AW_waves = t[0]
	S.AW_dacs = t[1]
	S.AW_dacs2 = t[2]
	S.channels_AW0 = t[3]
	S.channels_AW1 = t[4]
	S.channelIDs = t[5]
	S.instrIDs = t[6]

	// Get variable parts
	wave v = fd_AWGglobalVars
	S.initialized = v[0]
	S.use_AWG = v[1]  
	S.lims_checked = 0 // Always initialized to zero so that checks have to be run before using in scan (see SetCheckAWG())
	S.waveLen = v[3]
	S.numADCs = v[4]
	S.samplingFreq = v[5]
	S.measureFreq = v[6]
	S.numWaves = v[7]
	S.numCycles = v[8]
	S.numSteps = v[9]
	S.maxADCs = v[10]
	
end

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

function scc_checkRampratesFD(S)
  // check if effective ramprate is higher than software limits
  struct ScanVars &S
  wave/T fdacvalstr

	variable kill_graphs = 0
	// Check x's won't be swept to fast by calculated sweeprate for each channel in x ramp
	// Should work for different start/fin values for x
	variable eff_ramprate, answer, i, k, channel
	string question

	if(numtype(strlen(s.channelsx)) == 0 && strlen(s.channelsx) != 0)  // if s.Channelsx != (null or "")
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
	channels=ReplaceString(",,", channels, ",") //* there seems to be an issue on my Mac that channels has two ,, instead of one ,. Not sure if I am doing something different or if it is the OS. for now I remove the ,, by hand
		//*print channels

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
	variable channel_num = str2num(scu_getChannelNumbers(channel))
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
	
    // Defaulting optional string parameters to empty if not provided
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


	// Standard initialization
	initScanVars(S, startx=startx, finx=finx, channelsx=channelsx, numptsx=numptsx, delayx=delayx, rampratex=rampratex,\
	starty=starty, finy=finy, channelsy=channelsy, numptsy=numptsy, rampratey=rampratey, delayy=delayy, \
	x_label=x_label, y_label=y_label, startxs=startxs, finxs=finxs, startys=startys, finys=finys, alternate=alternate,\
	interlaced_channels=interlaced_channels, interlaced_setpoints=interlaced_setpoints, comments=comments)
	
	
	// Additional intialization for fastDAC scans
	string temp
	S.sweeprate = sweeprate
	S.duration = duration
   S.adcList = scf_getRecordedFADCinfo("channels")
   S.using_fastdac = 1
   temp=scf_getRecordedFADCinfo("adcListIDs"); // this returns a ; separated string with an empty space at the end
   temp=removeending(temp) // remove the empty space
   S.adcListIDs=FormatListItems(temp) /// make coma separated array of strings
   S.adcLists=scf_getRecordedFADCinfo("raw_names")
   S.fakerecords="0"
   S.lastread=-1
  
   
   S.raw_wave_names=scf_getRecordedFADCinfo("raw_names")
   svar fd
   S.instrIDs=fd

   

//   	// Sets channelsx, channelsy to be lists of channel numbers instead of labels
   scv_setChannels(S, channelsx, channelsy, fastdac=1)  
     
   	// Get Labels for graphs
   	S.x_label = selectString(strlen(x_label) > 0, scu_getDacLabel(S.channelsx, fastdac=1), x_label)  // Uses channels as list of numbers, and only if x_label not passed in
   	if (S.is2d)
   		S.y_label = selectString(strlen(y_label) > 0, scu_getDacLabel(S.channelsy, fastdac=1), y_label) 
   	else
   		S.y_label = y_label
   	endif  		

   	// Sets starts/fins (either using starts/fins given or from single startx/finx given)
   // scv_setSetpoints(S, channelsx, startx, finx, channelsy, starty, finy, startxs, finxs, startys, finys) had to move this
	
	   	get_dacListIDs(S)

	scv_setSetpoints(S, channelsx, startx, finx, channelsy, starty, finy, startxs, finxs, startys, finys)
	
	// Set variables with some calculation
    scv_setFreq(S=S) 		// Sets S.samplingFreq/measureFreq/numADCs	
    scv_setNumptsSweeprateDuration(S) 	// Checks that either numpts OR sweeprate OR duration was provided, and sets ScanVars accordingly
                                       // Note: Valid for start/fin only (uses S.startx, S.finx NOT S.startxs, S.finxs)
                                
   ///// for 2D scans //////////////////////////////////////////////////////////////////////////////////////////////////
   if(!x_only)
   		S.channelsy = scu_getChannelNumbers(channelsy)				// converting from channel labels to numbers
		S.y_label = scu_getDacLabel(S.channelsy)						// setting the y_label
   endif
   	//get_dacListIDs(S)

scv_setLastScanVars(S)
end


function/s getFDstatus()
struct ScanVars S
scv_getLastScanVars(S)
variable numDACCh, numADCCh 

svar fd
	string  buffer = "", key = ""
	wave/t fdacvalstr	
	wave/t fadcvalstr	
	wave/t ADC_channel
	string FDID_list=TextWavetolist(ADC_channel)
	
		
	buffer = addJSONkeyval(buffer, "http_address",fd, addquotes=1)
	buffer = addJSONkeyval(buffer, "FDs_used (ADC list)",FDID_list , addquotes=1)
	buffer = addJSONkeyval(buffer, "SamplingFreq", num2str(S.samplingFreq), addquotes=0)
	buffer = addJSONkeyval(buffer, "MeasureFreq", num2str(S.measureFreq), addquotes=0)


	variable i

	// update DAC values
	numDACCh=scfw_update_fdac("updatefdac")
	for(i=0;i<numDACCh;i+=1)
		sprintf key, "DAC%d{%s}",i, fdacvalstr[i][3]
		buffer = addJSONkeyval(buffer, key, fdacvalstr[i][1],addquotes=0) // getfdacOutput is PER instrument
	endfor
	
// update ADC values
	numADCCh=scfw_update_fadc("")
	for(i=0;i<numADCCh;i+=1)
		buffer = addJSONkeyval(buffer, "ADC"+num2str(i), fadcvalstr[i][1],addquotes=0) // getfdacOutput is PER instrument
	endfor	 

//	
//	
//	// AWG info
//	buffer = addJSONkeyval(buffer, "AWG", getFDAWGstatus())  //NOTE: AW saved in getFDAWGstatus()
return buffer
end

///////////////////////
//// API functions ////
///////////////////////

/// http://lcmi-docs.qdev-h101.lab:xxx/swagger/

curl -X 'GET' \
  'http://lcmi-docs.qdev-h101.lab:xxx/api/v1/get-idn/1' \
  -H 'accept: application/json'

function set_one_fadcSpeed(int adcValue,variable speed)
	svar fd
	wave/t ADC_channel
	String cmd = "set-adc-sampling-time"
	// Convert variables to strings and construct the JSON payload dynamically
	String payload
	payload = "{\"access_token\": \"string\", \"fqpn\": \"" + ADC_channel(adcValue) + "\", \"sampling_time_us\": " + num2str(speed) + "}"
	//print payload
	String headers = "accept: application/json\nContent-Type: application/json"
	// Perform the HTTP PUT request
	String response = postHTTP(fd, cmd, payload, headers)
end

function get_one_IDN()
	svar fd
	wave/t ADC_channel
	//string	response=getHTTP(fd,"get-idn/"+ADC_channel(),"");
	string value
	//value=getjsonvalue(response,"sampling_time_us")
	//variable speed = roundNum(1.0/str2num(value)*1.0e6,0)
	//return speed
end

function get_one_fadcSpeed(int adcValue)
	svar fd
	wave/t ADC_channel
	string	response=getHTTP(fd,"get-adc-sampling-time/"+ADC_channel(adcValue),"");
	string value
	value=getjsonvalue(response,"sampling_time_us")
	variable speed = roundNum(1.0/str2num(value)*1.0e6,0)
	return speed
end

function get_one_FADCChannel(int channel) // Units: mV
	svar fd
	wave/t ADC_channel	 
	string	response=getHTTP(fd,"get-adc-voltage/"+ADC_channel(channel),"");//print response
	string adc
	adc=getjsonvalue(response,"value")
	return str2num(adc)
end

function get_one_FDACChannel(int channel) // Units: mV
	svar fd
	wave/t DAC_channel
	string	response=getHTTP(fd,"get-dac-voltage/"+DAC_channel(channel),"");
	string adc
	adc=getjsonvalue(response,"value")
	return str2num(adc)
end

function set_one_FDACChannel(int channel, variable setpoint, variable ramprate)
	wave/t DAC_channel
	svar fd
	String cmd = "ramp-dac-to-target"
	String payload
	payload = "{\"fqpn\": \"" + Dac_channel(channel) + "\", \"ramp_rate_mv_per_s\": " + num2str(ramprate) + ", \"target\": {\"unit\": \"mV\", \"value\": " + num2str(setpoint) + "}}"
	String headers = "accept: application/json\nContent-Type: application/json"
	String response = postHTTP(fd, cmd, payload, headers)
	print headers
	print response
	
end

function sample_ADC(string adclist, variable nr_samples)
	svar fd
	variable chunksize=2500
	String cmd = "run-samples-acquisition"
	String payload=""
	payload+= "{\"adc_list\": ["
	payload+=adclist
	payload+=  "], "
    payload+= "\"chunk_max_samples\": \"" + num2str(chunksize) + "\", "
    payload+= "\"adc_sampling_time_us\": \"" + num2str(82) + "\", "
    payload+= "\"chunk_file_name_template\": \"temp_{{.ChunkIndex}}.dat\", "
   	payload+=  "\"nr_samples\": \"" + num2str(nr_samples) + "\"}"

//print payload
	String headers = "accept: application/json\nContent-Type: application/json"
	String response = postHTTP(fd, cmd, payload, headers)
	//print response
end




Function linear_ramp(S)
    Struct ScanVars &S
    String adcList = S.adcListIDs 
    Variable nr_samples = S.numptsx
    Variable i
    SVar fd
    Variable chunkSize = 1200
    String cmd = "start-linear-ramps"
    String payload = "{\"adc_list\": [" + adcList + "], "
    payload += "\"chunk_max_samples\": \"" + num2str(chunkSize) + "\", "
    payload += "\"adc_sampling_time_us\":" + num2str(82) + ", "
    payload += "\"chunk_file_name_template\": \"temp_{{.ChunkIndex}}.dat\", "
    payload += "\"nr_steps\": \"" + num2str(nr_samples) + "\","
    payload += "\"dac_range_map\": {"

    for (i = 0; i < ItemsInList(S.daclistIDs,","); i += 1)
        if (i > 0)
            payload += ", "
        endif
        payload += CreatePayload(S, i)
    endfor

    payload += "}}"
    print payload

    String headers = "accept: application/json\nContent-Type: application/json"
    String response = postHTTP(fd, cmd, payload, headers)
    print response
End

Function/S CreatePayload(S, idx)
    Struct ScanVars &S
    Int idx
    String dacChannel = StringFromList(idx, S.daclistIDs, ",")
    String minValue = StringFromList(idx, S.startXs, ",")
    String maxValue = StringFromList(idx, S.finXs, ",")

    // Construct the payload for one DAC entry
    String payload = "\"" + dacChannel + "\": {"
    payload += "\"max\": {\"unit\": \"mV\", \"value\": " + maxValue + "}, "
    payload += "\"min\": {\"unit\": \"mV\", \"value\": " + minValue + "}"
    payload += "}"
    return payload
End










function fd_stopFDACsweep()
//svar fd
//	// Stops any sweeps which might be running
//	String cmd = "stop"
//	String payload
//	payload = "{\"dac\": " + num2str(channel) + ", \"setpoint_mv\": " + num2str(setpoint)+ ", \"rate_mv_s\": " + num2str(ramprate) + "}"
//	String headers = "accept: application/json\nContent-Type: application/json"
//	String response = postHTTP(fd, cmd, payload, headers)
//	print response
	print "stopped FD Ramp"

end





//function get_one_FADCChannel(int channel) // Units: mV
//variable speed=gnoise(1)
//return speed
//end

//function get_one_FDACChannel(int channel) // Units: mV
//variable speed=channel+gnoise(1)
//return speed
//end

//function set_one_FDACChannel(int channel, variable setpoint, variable ramprate)
//variable speed=gnoise(1)
//return speed
//end

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





///////////////////
//// Utilities ////
///////////////////
function fd_get_numpts_from_sweeprate(start, fin, sweeprate, measureFreq)
/// Convert sweeprate in mV/s to numptsx for fdacrecordvalues
	variable start, fin, sweeprate, measureFreq
	if (start == fin)
		abort "ERROR[fd_get_numpts_from_sweeprate]: Start == Fin so can't calculate numpts"
	endif
	variable numpts = round(abs(fin-start)*measureFreq/sweeprate)   // distance * steps per second / sweeprate
	return numpts
end

function fd_get_sweeprate_from_numpts(start, fin, numpts, measureFreq)
	// Convert numpts into sweeprate in mV/s
	variable start, fin, numpts, measureFreq
	if (numpts == 0)
		abort "ERROR[fd_get_numpts_from_sweeprate]: numpts = 0 so can't calculate sweeprate"
	endif
	variable sweeprate = round(abs(fin-start)*measureFreq/numpts)   // distance * steps per second / numpts
	return sweeprate
end

function fd_getmaxADCs(S)
	struct ScanVars &S
	variable maxADCs
	wave fadcattr
	wave numericwave
	string adcList = scf_getRecordedFADCinfo("channels")
	StringToListWave(adclist)
	numericwave=floor(numericwave/4)
	maxADCs=FindMaxRepeats(numericwave)
	S.numADCs=dimsize(numericwave,0)
	return maxADCs
end

function getFDIDs()
	//ADC_channel has to exist for this to work
	//creates string wave FDIDs and sting list FDIDs_list
	wave/t ADC_channel
	ConvertTxtWvToNumWv(ADC_channel); /// creates numerical wave out of ADC_channel
	wave numconvert
	matrixop/o rounded=round(numconvert)
	FDecimate(rounded, "FDIDs", 4)	
end


Step 1: Initialize the array
- Let `active_dacs[]` and `active_adcs[]` be arrays of size 4 (for 4 boxes), initialized to zero.
- Let `total_reads_per_box[]` be an array of size 4, initialized to zero.

Step 2: Mark active DACs and ADCs
- For each DAC in `dac_locations`, increment `active_dacs[dac_location]`.
- For each ADC in `adc_locations`, increment `active_adcs[adc_location]`.

Step 3: Calculate reads required to balance the load
- Calculate `total_active_boxes` by counting non-zero entries in `active_dacs[]` and `active_adcs[]` combined.
- For each box, calculate `max_reads` which is the maximum of any individual count in `active_adcs[]`.

Step 4: Assign ADC reads
- For each box i from 1 to 4:
  - If `active_dacs[i] > 0 OR active_adcs[i] > 0` then:
    - `needed_adcs = max(max_reads - active_adcs[i], 0)`
    - `reads_per_box[i] = active_adcs[i] + needed_adcs`

Step 5: Output the number of reads per box
- The result is stored in `reads_per_box[]`, where each entry indicates the total ADC reads (real and fake) for each box.



