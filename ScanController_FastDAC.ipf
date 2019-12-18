#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Fast DAC (8 DAC channels + 4 ADC channels). Build in-house by Mark (Electronic work shop).
// This is the ScanController extention to the ScanController code. Running measurements with
// the Fast DAC must be "stand alone", no other instruments can read at the same time.
// The Fast DAC extention will open a seperate "Fast DAC window" that holds all the information
// nessesary to run a Fast DAC measurement. Any "normal" measurements should still be set up in 
// the standard ScanController window.
// It is the users job to add the fastdac=1 flag to initWaves(), RecordValues() and SaveWaves()!
//
// Written by Christian Olsen, 2019-11-xx

function openFastDACconnection(instrID, visa_address, [verbose])
	// instrID is the name of the global variable that will be used for communication
	// visa_address is the VISA address string, i.e. ASRL1::INSTR
	string instrID, visa_address
	variable verbose
	
	if(paramisdefault(verbose))
		verbose=1
	elseif(verbose!=1)
		verbose=0
	endif
	
	variable localRM
	variable status = viOpenDefaultRM(localRM) // open local copy of resource manager
	if(status < 0)
		VISAerrormsg("open FastDAC connection:", localRM, status)
		abort
	endif
	
	string comm = ""
	sprintf comm, "name=FastDAC,instrID=%s,visa_address=%s" instrID, visa_address
	string options = "baudrate=57600,databits=8,stopbits=1,parity=0"
	openVISAinstr(comm, options=options, localRM=localRM, verbose=verbose)
end

function setfadcSpeed(instrID,speed)
	// speed should be a number between 1-3.
	// slow=1, fast=2 and fastest=3
	variable instrID, speed
	
	// check formatting of speed
	if(speed < 0 || speed > 3)
		print "[ERROR] \"setfadcSpeeed\": Speed must be integer between 1-3"
		abort
	endif
	
	string cmd = "ADD REAL COMMAND!"
	string response = queryInstr(instrID, cmd+"\r\n", read_term="\r\n")
	
	// check respose
	// not sure what to expect!
	if(1)
		// do nothing
	else
		string err
		sprintf err, "[ERROR] \"setfadcSpeed\": Bad response! %s", response
		print err
		abort
	endif
end

function resetfdacwindow(fdacCh)
	variable fdacCh
	wave/t fdacvalstr, old_fdacvalstr
	
	fdacvalstr[fdacCh][1] = old_fdacvalstr[fdacCh]
end

function updatefdacWindow(fdacCh)
	variable fdacCh
	wave/t fdacvalstr, old_fdacvalstr
	 
	old_fdacvalstr[fdacCh] = fdacvalstr[fdacCh][1]
end

function rampOutputfdac(instrID,channel,output,[ramprate]) // Units: mV, mV/s
	// ramps a channel to the voltage specified by "output".
	// ramp is controlled locally on DAC controller.
	variable instrID, channel, output, ramprate
	wave/t fdacvalstr, old_fdacvalstr
	
	if(paramIsDefault(ramprate))
		ramprate = 500
	endif
	
	variable fdacCh = resolvefdacChannel(instrID,channel)
	// check if specified channel is real
	if(channel > 7 || channel < 0)
		print "[ERROR] \"rampOutputfdac\": Channel must be integer between 0-7"
		resetfdacwindow(fdacCh)
		abort
	endif
	
	// check that output is within hardware limit
	nvar fdac_limit
	if(abs(output) > fdac_limit)
		string err
		sprintf err, "[ERROR] \"rampOutputfdac\": Output voltage on channel %d outside hardware limit", fdacCh
		print err
		resetfdacwindow(fdacCh)
		abort
	endif
	
	// check that output is within software limit
	// overwrite output to software limit and warn user
	if(abs(output) > str2num(fdacvalstr[fdacCh][2]))
		output = sign(output)*str2num(fdacvalstr[fdacCh][2])
		string warn
		sprintf warn, "[WARNING] \"rampOutputfdac\": Output voltage must be within limit. Setting channel %d to %.3fmV", fdacCh, output
		print warn
	endif
	
	// read current dac output and compare to window
	string cmd = "ADD REAL COMMAND!"
	string response
	response = queryInstr(instrID, cmd+"\r\n", read_term="\r\n")
	
	// check response
	// not sure what to expect!
	if(1)
		// good response
		if(abs(str2num(response)-str2num(old_fdacvalstr[fdacCh][1]))<0.1)
			// no discrepancy
		else
			sprintf warn, "[WARNING] \"rampOutputfdac\": Actual output of channel %d is different than expected", fdacCh
			print warn
		endif
	else
		sprintf err, "[ERROR] \"rampOutputfdac\": Bad response! %s", response
		print err
		resetfdacwindow(fdacCh)
		abort
	endif
	
	// set ramprate
	cmd = "ADD REAL COMMAND!"
	response = queryInstr(instrID, cmd+"\r\n", read_term="\r\n")
	
	// check respose
	// not sure what to expect!
	if(1) 
		// not a good response
		sprintf err, "[ERROR] \"rampOutputfdac\": Bad response! %s", response
		print err
		resetfdacwindow(fdacCh)
		abort
	endif
	
	// ramp channel to output
	cmd = "ADD REAL COMMAND!"
	response = queryInstr(instrID, cmd+"\r\n", read_term="\r\n")
	
	// check respose
	// not sure what to expect! if good update window
	if(1)
		fdacvalstr[fdacCh][1] = num2str(output)
		updatefdacWindow(fdacCh)
	else
		sprintf err, "[ERROR] \"rampOutputfdac\": Bad response! %s", response
		print err
		resetfdacwindow(fdacCh)
		abort
	endif
end

function readfadcChannel(instrID,channel) // Units: mV
	variable instrID, channel
	wave/t fadcvalstr
	
	variable fadcCh = resolvefadcChannel(instrID,channel)
	// check that channel is real
	if(channel > 3 || channel < 0)
		print "[ERROR] \"readfadcChannel\": Channel must be integer between 0-3"
		abort
	endif
	
	// query ADC
	string cmd = "ADD REAL COMMAND!"
	string response
	response = queryInstr(instrID, cmd+"\r\n", read_term="\r\n")
	
	// check response
	// not sure what to expect!
	if(1) 
		// good response, update window
		fadcvalstr[fadcCh][1] = response
		return str2num(response)
	else
		string err
		sprintf err, "[ERROR] \"readfadcChannel\": Bad response! %s", response
		print err
		abort
	endif
end

function resolvefdacChannel(instrID,channel)
	variable instrID, channel
	
	// check that channel is real
	if(channel > 7 || channel < 0)
		print "[ERROR] \"resolvefdacChannel\": Channel must be integer between 0-7"
		abort
	endif
	
	nvar num_fdacs
	string idn = queryInstr(instrID, "*IDN?\r\n", read_term="\r\n")
	switch(num_fdacs)
		case 1:
			svar fdac1_idn
			if(stringmatch(fdac1_idn,idn))
				return channel
			endif
			break
		case 2:
			svar fdac1_idn,fdac2_idn
			if(stringmatch(fdac2_idn,idn))
				return channel+8
			elseif(stringmatch(fdac1_idn,idn))
				return channel
			endif
			break
		case 3:
			svar fdac1_idn,fdac2_idn, fdac3_idn
			if(stringmatch(fdac3_idn,idn))
				return channel+16
			elseif(stringmatch(fdac2_idn,idn))
				return channel+8
			elseif(stringmatch(fdac1_idn,idn))
				return channel
			endif
			break
		case 4:
			svar fdac1_idn,fdac2_idn, fdac3_idn, fdac4_idn
			if(stringmatch(fdac4_idn,idn))
				return channel+24
			elseif(stringmatch(fdac3_idn,idn))
				return channel+16
			elseif(stringmatch(fdac2_idn,idn))
				return channel+8
			elseif(stringmatch(fdac1_idn,idn))
				return channel
			endif
			break
	endswitch
	
	// Bad instr resolve
	print "[ERROR] \"resolvefdacChannel\": Couldn't resolve instrument. VISA connection likely corrupted"
	abort	
end

function resolvefadcChannel(instrID,channel)
	variable instrID, channel
	
	// check that channel is real
	if(channel > 3 || channel < 0)
		print "[ERROR] \"resolvefadcChannel\": Channel must be integer between 0-3"
		abort
	endif
	
	nvar num_fdacs
	string idn = queryInstr(instrID, "*IDN?\r\n", read_term="\r\n")
	switch(num_fdacs)
		case 1:
			svar fdac1_idn
			if(stringmatch(fdac1_idn,idn))
				return channel
			endif
			break
		case 2:
			svar fdac1_idn,fdac2_idn
			if(stringmatch(fdac2_idn,idn))
				return channel+4
			elseif(stringmatch(fdac1_idn,idn))
				return channel
			endif
			break
		case 3:
			svar fdac1_idn,fdac2_idn, fdac3_idn
			if(stringmatch(fdac3_idn,idn))
				return channel+8
			elseif(stringmatch(fdac2_idn,idn))
				return channel+4
			elseif(stringmatch(fdac1_idn,idn))
				return channel
			endif
			break
		case 4:
			svar fdac1_idn,fdac2_idn, fdac3_idn, fdac4_idn
			if(stringmatch(fdac4_idn,idn))
				return channel+12
			elseif(stringmatch(fdac3_idn,idn))
				return channel+8
			elseif(stringmatch(fdac2_idn,idn))
				return channel+4
			elseif(stringmatch(fdac1_idn,idn))
				return channel
			endif
			break
	endswitch
	
	// Bad instr resolve
	print "[ERROR] \"resolvefadcChannel\": Couldn't resolve instrument. VISA connection likely corrupted"
	abort	
end

function initFastDAC(instrID,[instrID2,instrID3,instrID4])
	variable instrID,instrID2,instrID3,instrID4
	
	// hardware limit (mV)
	variable/g fdac_limit = 5000
	
	variable num_fdac = 0
	if(paramisDefault(instrID2) && paramisDefault(instrID3) && paramisDefault(instrID4))
		num_fdac = 1
		//string/g fdac1_idn = queryInstr(instrID, "*IDN?\r\n", read_term="\r\n")
		//string/g fdac1_addr = getResourceAddress(instrID)
	elseif(!paramisDefault(instrID2) && paramisDefault(instrID3) && paramisDefault(instrID4))
		num_fdac = 2
		//string/g fdac1_idn = queryInstr(instrID, "*IDN?\r\n", read_term="\r\n")
		//string/g fdac1_addr = getResourceAddress(instrID)
		//string/g fdac2_idn = queryInstr(instrID2, "*IDN?\r\n", read_term="\r\n")
		//string/g fdac2_addr = getResourceAddress(instrID2)
	elseif(!paramisDefault(instrID2) && !paramisDefault(instrID3) && paramisDefault(instrID4))
		num_fdac = 3
		//string/g fdac1_idn = queryInstr(instrID, "*IDN?\r\n", read_term="\r\n")
		//string/g fdac1_addr = getResourceAddress(instrID)
		//string/g fdac2_idn = queryInstr(instrID2, "*IDN?\r\n", read_term="\r\n")
		//string/g fdac2_addr = getResourceAddress(instrID2)
		//string/g fdac3_idn = queryInstr(instrID3, "*IDN?\r\n", read_term="\r\n")
		//string/g fdac3_addr = getResourceAddress(instrID3)
	elseif(!paramisDefault(instrID2) && !paramisDefault(instrID3) && !paramisDefault(instrID4))
		num_fdac = 4
		//string/g fdac1_idn = queryInstr(instrID, "*IDN?\r\n", read_term="\r\n")
		//string/g fdac1_addr = getResourceAddress(instrID)
		//string/g fdac2_idn = queryInstr(instrID2, "*IDN?\r\n", read_term="\r\n")
		//string/g fdac2_addr = getResourceAddress(instrID2)
		//string/g fdac3_idn = queryInstr(instrID3, "*IDN?\r\n", read_term="\r\n")
		//string/g fdac3_addr = getResourceAddress(instrID3)
		//string/g fdac4_idn = queryInstr(instrID4, "*IDN?\r\n", read_term="\r\n")
		//string/g fdac4_addr = getResourceAddress(instrID4)
	else
		print "[ERROR] \"initFastDAC\": Define instrID's in order."
		abort
	endif
	
	// create waves to hold control info
	fdacCheckForOldInit(num_fdac)
	
	variable/g num_fdacs = num_fdac
	
	// create GUI window
	string cmd = ""
	killwindow/z ScanControllerFastDAC
	sprintf cmd, "FastDACWindow(%d)", num_fdac
	execute(cmd)
	fdacSetGUIinteraction(num_fdac)
end

function fdacCheckForOldInit(num_fdac)
	variable num_fdac
	
	variable response
	wave/z fdacvalstr
	wave/z old_fdacvalstr
	if(waveexists(fdacvalstr) && waveexists(old_fdacvalstr))
		response = fdacAskUser(num_fdac)
		if(response == 1)
			// Init at old values
			print "[FastDAC] Init to old values"
		elseif(response == -1)
			// Init to default values
			fdacCreateControlWaves(num_fdac)
			print "[FastDAC] Init to default values"
		else
			print "[Warning] \"fdacCheckForOldInit\" Bad user input - Init to default values"
			fdacCreateControlWaves(num_fdac)
		endif
	else
		// Init to default values
		fdacCreateControlWaves(num_fdac)
	endif
end

function fdacAskUser(num_fdac)
	variable num_fdac
	nvar oldnum = num_fdacs
	wave/t fdacvalstr
	
	make/o/t fdacext = {"0","0","0","0","0","0","0","0"}
	// can only init to old settings if the same
	// number of FastDACs are used
	if(oldnum == num_fdac)
		switch(num_fdac)
			case 1:
				duplicate/o fdacext, fdacdefaultinit
				break
			case 2:
				concatenate/o/np=0 {fdacext,fdacext}, fdacdefaultinit
				break
			case 3:
				concatenate/o/np=0 {fdacext,fdacext,fdacext}, fdacdefaultinit
				break
			case 4:
				concatenate/o/np=0 {fdacext,fdacext,fdacext,fdacext}, fdacdefaultinit
				break
		endswitch

		duplicate/o/rmd=[][1] fdacvalstr ,fdacvalsinit
		concatenate/o {fdacdefaultinit,fdacvalsinit}, fdacinit
		execute("fdacInitWindow()")
		pauseforuser fdacInitWindow
		nvar fdac_answer
		return fdac_answer
	else
		return -1
	endif
end

window fdacInitWindow() : Panel
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
	Button old_fdacinit,pos={40,490},size={70,20},proc=fdacAskUserUpdate,title="OLD INIT"
	Button default_fdacinit,pos={170,490},size={70,20},proc=fdacAskUserUpdate,title="DEFAULT"
endmacro

function fdacAskUserUpdate(action) : ButtonControl
	string action
	variable/g fdac_answer
	
	strswitch(action)
		case "old_fdacinit":
			fdac_answer = 1
			dowindow/k fdacInitWindow
			break
		case "default_fdacinit":
			fdac_answer = -1
			dowindow/k fdacInitWindow
			break
	endswitch
end
	
end

window FastDACWindow(num_fdac) : Panel
	variable num_fdac
	
	PauseUpdate; Silent 1 // pause everything else, while building the window
	NewPanel/w=(0,0,790,570)/n=ScanControllerFastDAC // window size
	ModifyPanel/w=ScanControllerFastDAC framestyle=2, fixedsize=1
	SetDrawLayer userback
	SetDrawEnv fsize=25, fstyle=1
	DrawText 130, 45, "DAC"
	SetDrawEnv fsize=25, fstyle=1
	DrawText 516, 45, "ADC"
	DrawLine 315,15,315,385
	DrawLine 10,385,780,385
	SetDrawEnv dash=7
	Drawline 325,295,780,295
	// DAC, 12 channels shown
	SetDrawEnv fsize=14, fstyle=1
	DrawText 15, 70, "Ch"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 50, 70, "Output (mV)"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 140, 70, "Limit (mV)"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 213, 70, "Label"
	ListBox fdaclist,pos={10,75},size={290,270},fsize=14,frame=2,widths={35,90,75,70}
	ListBox fdaclist,listwave=root:fdacvalstr,selwave=root:fdacattr,mode=1
	Button fdacramp,pos={50,354},size={65,20},proc=update_fdac,title="Ramp"
	Button fdacrampzero,pos={170,354},size={90,20},proc=update_fdac,title="Ramp all 0"
	// ADC, 8 channels shown
	SetDrawEnv fsize=14, fstyle=1
	DrawText 330, 70, "Ch"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 370, 70, "Input (mV)"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 480, 70, "Record"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 540, 70, "Wave Name"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 650, 70, "Calc Function"
	ListBox fadclist,pos={325,75},size={450,180},fsize=14,frame=2,widths={35,90,45,90,90}
	ListBox fadclist,listwave=root:fadcvalstr,selwave=root:fadcattr,mode=1
	button updatefadc,pos={325,265},size={90,20},proc=update_fadc,title="Update ADC"
	checkbox sc_PrintfadcBox,pos={425,265},proc=sc_CheckBoxClicked,value=sc_Printfadc,side=1,title="\Z14Print filenames "
	checkbox sc_SavefadcBox,pos={545,265},proc=sc_CheckBoxClicked,value=sc_Saverawfadc,side=1,title="\Z14Save raw data "
	popupMenu fadcSetting1,pos={335,310},proc=update_fadcSpeed,mode=1,title="\Z14ADC1 communication",size={100,20},value="Slow;Fast;Fastest"
	popupMenu fadcSetting2,pos={560,310},proc=update_fadcSpeed,mode=1,title="\Z14ADC2 communication",size={100,20},value="Slow;Fast;Fastest"
	popupMenu fadcSetting3,pos={335,350},proc=update_fadcSpeed,mode=1,title="\Z14ADC3 communication",size={100,20},value="Slow;Fast;Fastest"
	popupMenu fadcSetting4,pos={560,350},proc=update_fadcSpeed,mode=1,title="\Z14ADC4 communication",size={100,20},value="Slow;Fast;Fastest"
	
	// identical to ScanController window
	// all function calls are to ScanController functions
	// instrument communication
	SetDrawEnv fsize=14, fstyle=1
	DrawText 15, 415, "Connect Instrument"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 265, 415, "Open GUI"
	SetDrawEnv fsize=14, fstyle=1
	DrawText 515, 415, "Log Status"
	ListBox sc_InstrFdac,pos={10,420},size={770,100},fsize=14,frame=2,listWave=root:sc_Instr,selWave=root:instrBoxAttr,mode=1, editStyle=1

	// buttons
	button connectfdac,pos={10,525},size={140,20},proc=sc_OpenInstrButton,title="Connect Instr"
	button guifdac,pos={160,525},size={140,20},proc=sc_OpenGUIButton,title="Open All GUI"
	button killaboutfdac, pos={310,525},size={160,20},proc=sc_controlwindows,title="Kill Sweep Controls"
	button killgraphsfdac, pos={480,525},size={150,20},proc=sc_killgraphs,title="Close All Graphs"
	button updatebuttonfdac, pos={640,525},size={140,20},proc=sc_updatewindow,title="Update"
	
	// helpful text
	DrawText 10, 565, "Press Update to save changes."
endmacro

	// set update speed for ADCs
function update_fadcSpeed(s) : PopupMenuControl
	struct wmpopupaction &s
	
	variable instrID
	if(s.eventcode == 2)
		// a menu item has been selected
		strswitch(s.ctrlname)
			case "fadcSetting1":
				nvar fdac1_addr
				instrID = fdac1_addr
				break
			case "fadcSetting2":
				nvar fdac2_addr
				instrID = fdac2_addr
				break
			case "fadcSetting3":
				nvar fdac3_addr
				instrID = fdac3_addr
				break
			case "fadcSetting4":
				nvar fdac4_addr
				instrID = fdac4_addr
				break
		endswitch
		
		setfadcSpeed(instrID,s.popnum)
		return 0
	else
		// do nothing
		return 0
	endif
end

function update_fdac(action) : ButtonControl
	string action
	nvar num_fdac
	wave/t fdacvalstr
	wave/t old_fdacvalstr
	
	// open temporary connection to FastDACs
	// and update values if needed
	variable i=0,j=0,output
	string tempaddrstr, tempnamestr
	for(i=0;i<num_fdac;i+=1)
		sprintf tempaddrstr, "fdac%d_adrr", i+1
		svar tempaddr = $tempaddrstr
		tempnamestr = tempaddrstr[0,4]
		openFastDACconnection(tempnamestr, tempaddr, verbose=0)
		nvar tempname = $tempnamestr
		try
			strswitch(action)
				case "ramp":
					for(j=0;j<8;j+=1)
						if(str2num(fdacvalstr[8*i+j][1]) != str2num(old_fdacvalstr[8*i+j][1]))
							output = str2num(fdacvalstr[8*i+j][1])
							rampOutputfdac(tempname,j,output,ramprate=500)
						endif
					endfor
					break
				case "rampallzero":
					for(j=0;j<8;j+=1)
						rampOutputfdac(tempname,j,0,ramprate=500)
					endfor
					break
			endswitch
		catch
			// reset error code, so VISA connection can be closed!
			variable err = GetRTError(1)
			
			viClose(tempname)
			// silent abort
			abortonvalue 1,10
		endtry
		
		// close temp visa connection
		viClose(tempname)
	endfor
end

function update_fadc(action) : ButtonControl
	string action
	nvar num_fdac
	variable i=0, j=0
	
	string tempaddrstr, tempnamestr
	variable input
	for(i=0;i<num_fdac;i+=1)
		sprintf tempaddrstr, "fdac%d_adrr", i+1
		svar tempaddr = $tempaddrstr
		tempnamestr = tempaddrstr[0,4]
		openFastDACconnection(tempnamestr, tempaddr, verbose=0)
		nvar tempname = $tempnamestr
		try
			for(j=0;j<4;j+=1)
				input = readfadcChannel(tempname,j)
			endfor
		catch
			// reset error
			variable err = GetRTError(1)
			
			viClose(tempname)
			// silent abort
			abortonvalue 1,10
		endtry
		
		// close temp visa connection
		viClose(tempname)
	endfor
end

function fdacCreateControlWaves(num_fdac)
	variable num_fdac
	
	// extention waves used when more than two fastDACs are connected.
	make/o/t extfdacCh1 = {"16","17","18","19","20","21","22","23"}
	make/o/t extfdacCh2 = {"24","25","26","27","28","29","30","31"}
	make/o/t extfdacval = {"0","0","0","0","0","0","0","0"}
	make/o/t extfdaclimit = {"5000","5000","5000","5000","5000","5000","5000","5000"}
	make/o/t extfdaclabel = {"Label","Label","Label","Label","Label","Label","Label","Label"}
	make/o extfdacattr0 = {0,0,0,0,0,0,0,0}
	make/o extfdacattr2 = {2,2,2,2,2,2,2,2}
	
	make/o/t extfadcCh1 = {"8","9","10","11"}
	make/o/t extfadcCh2 = {"12","13","14","15"}
	make/o/t extfadcval = {"0","0","0","0"}
	make/o/t extfadcempty = {"","","",""}
	make/o/t extfadcones = {"1","1","1","1"}
	make/o extfadcattr0 = {0,0,0,0}
	make/o extfadcattr2 = {2,2,2,2}
	make/o extfadcattr32 = {32,32,32,32}
	
	// create waves for DAC part
	make/o/t tempfdac1 = {"0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15"}
	make/o/t tempfdac2 = {"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"}
	make/o/t tempfdac3 = {"5000","5000","5000","5000","5000","5000","5000","5000","5000","5000","5000","5000","5000","5000","5000","5000"}
	make/o/t tempfdac4 = {"Label","Label","Label","Label","Label","Label","Label","Label","Label","Label","Label","Label","Label","Label","Label","Label"}
	make/o tempfdacattr1 = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	make/o tempfdacattr2 = {2,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0}
	make/o tempfdacattr3 = {2,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0}
	make/o tempfdacattr4 = {2,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0}
	
	// create waves for ADC part
	make/o/t tempfadc1 = {"0","1","2","3","4","5","6","7"}
	make/o/t tempfadc2 = {"0","0","0","0","0","0","0","0"}
	make/o/t tempfadc3 = {"","","","","","","",""}
	make/o/t tempfadc4 = {"","","","","","","",""}
	make/o/t tempfadc5 = {"1","1","1","1","1","1","1","1"}
	make/o tempfadcattr1 = {0,0,0,0,0,0,0,0}
	make/o tempfadcattr2 = {0,0,0,0,0,0,0,0}
	make/o tempfadcattr3 = {32,32,32,32,0,0,0,0}
	make/o tempfadcattr4 = {2,2,2,2,0,0,0,0}
	make/o tempfadcattr5 = {2,2,2,2,0,0,0,0}
	
	switch(num_fdac)
		case 1:
			// do nothing
			
			duplicate/o tempfdac1, fdac1
			duplicate/o tempfdac2, fdac2
			duplicate/o tempfdac3, fdac3
			duplicate/o tempfdac4, fdac4
			duplicate/o tempfdacattr1, fdacattr1
			duplicate/o tempfdacattr2, fdacattr2
			duplicate/o tempfdacattr3, fdacattr3
			duplicate/o tempfdacattr4, fdacattr4
			
			duplicate/o tempfadc1, fadc1
			duplicate/o tempfadc2, fadc2
			duplicate/o tempfadc3, fadc3
			duplicate/o tempfadc4, fadc4
			duplicate/o tempfadc5, fadc5
			duplicate/o tempfadcattr1, fadcattr1
			duplicate/o tempfadcattr2, fadcattr2
			duplicate/o tempfadcattr3, fadcattr3
			duplicate/o tempfadcattr4, fadcattr4
			duplicate/o tempfadcattr5, fadcattr5
			break
		case 2:
			// extent to 2 fastDACs
			tempfdacattr2 = {2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2}
			tempfdacattr3 = {2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2}
			tempfdacattr4 = {2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2}
			
			tempfadcattr3 = {32,32,32,32,32,32,32,32}
			tempfadcattr4 = {2,2,2,2,2,2,2,2}
			tempfadcattr5 = {2,2,2,2,2,2,2,2}
			
			duplicate/o tempfdac1, fdac1
			duplicate/o tempfdac2, fdac2
			duplicate/o tempfdac3, fdac3
			duplicate/o tempfdac4, fdac4
			duplicate/o tempfdacattr1, fdacattr1
			duplicate/o tempfdacattr2, fdacattr2
			duplicate/o tempfdacattr3, fdacattr3
			duplicate/o tempfdacattr4, fdacattr4
			
			duplicate/o tempfadc1, fadc1
			duplicate/o tempfadc2, fadc2
			duplicate/o tempfadc3, fadc3
			duplicate/o tempfadc4, fadc4
			duplicate/o tempfadc5, fadc5
			duplicate/o tempfadcattr1, fadcattr1
			duplicate/o tempfadcattr2, fadcattr2
			duplicate/o tempfadcattr3, fadcattr3
			duplicate/o tempfadcattr4, fadcattr4
			duplicate/o tempfadcattr5, fadcattr5
			break
		case 3:
			// extent to 3 fastDACs
			tempfdacattr2 = {2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2}
			tempfdacattr3 = {2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2}
			tempfdacattr4 = {2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2}
			
			tempfadcattr3 = {32,32,32,32,32,32,32,32}
			tempfadcattr4 = {2,2,2,2,2,2,2,2}
			tempfadcattr5 = {2,2,2,2,2,2,2,2}
			
			concatenate/o/np=0 {tempfdac1,extfdacCh1}, fdac1
			concatenate/o/np=0 {tempfdac2,extfdacval}, fdac2
			concatenate/o/np=0 {tempfdac3,extfdaclimit}, fdac3
			concatenate/o/np=0 {tempfdac4,extfdaclabel}, fdac4
			concatenate/o/np=0 {tempfdacattr1,extfdacattr0}, fdacattr1
			concatenate/o/np=0 {tempfdacattr2,extfdacattr2}, fdacattr2
			concatenate/o/np=0 {tempfdacattr3,extfdacattr2}, fdacattr3
			concatenate/o/np=0 {tempfdacattr4,extfdacattr2}, fdacattr4
			
			concatenate/o/np=0 {tempfadc1,extfadcCh1}, fadc1
			concatenate/o/np=0 {tempfadc2,extfadcval}, fadc2
			concatenate/o/np=0 {tempfadc3,extfadcempty}, fadc3
			concatenate/o/np=0 {tempfadc4,extfadcempty}, fadc4
			concatenate/o/np=0 {tempfadc5,extfadcones}, fadc5
			concatenate/o/np=0 {tempfadcattr1,extfadcattr0}, fadcattr1
			concatenate/o/np=0 {tempfadcattr2,extfadcattr0}, fadcattr2
			concatenate/o/np=0 {tempfadcattr3,extfadcattr32}, fadcattr3
			concatenate/o/np=0 {tempfadcattr4,extfadcattr2}, fadcattr4
			concatenate/o/np=0 {tempfadcattr5,extfadcattr2}, fadcattr5
			break
		case 4:
			// extent to 4 fastDACs
			tempfdacattr2 = {2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2}
			tempfdacattr3 = {2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2}
			tempfdacattr4 = {2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2}
			
			tempfadcattr3 = {32,32,32,32,32,32,32,32}
			tempfadcattr4 = {2,2,2,2,2,2,2,2}
			tempfadcattr5 = {2,2,2,2,2,2,2,2}
			
			concatenate/o/np=0 {tempfdac1,extfdacCh1,extfdacCh2}, fdac1
			concatenate/o/np=0 {tempfdac2,extfdacval,extfdacval}, fdac2
			concatenate/o/np=0 {tempfdac3,extfdaclimit,extfdaclimit}, fdac3
			concatenate/o/np=0 {tempfdac4,extfdaclabel,extfdaclabel}, fdac4
			concatenate/o/np=0 {tempfdacattr1,extfdacattr0,extfdacattr0}, fdacattr1
			concatenate/o/np=0 {tempfdacattr2,extfdacattr2,extfdacattr2}, fdacattr2
			concatenate/o/np=0 {tempfdacattr3,extfdacattr2,extfdacattr2}, fdacattr3
			concatenate/o/np=0 {tempfdacattr4,extfdacattr2,extfdacattr2}, fdacattr4
			
			concatenate/o/np=0 {tempfadc1,extfadcCh1,extfadcCh2}, fadc1
			concatenate/o/np=0 {tempfadc2,extfadcval,extfadcval}, fadc2
			concatenate/o/np=0 {tempfadc3,extfadcempty,extfadcempty}, fadc3
			concatenate/o/np=0 {tempfadc4,extfadcempty,extfadcempty}, fadc4
			concatenate/o/np=0 {tempfadc5,extfadcones,extfadcones}, fadc5
			concatenate/o/np=0 {tempfadcattr1,extfadcattr0,extfadcattr0}, fadcattr1
			concatenate/o/np=0 {tempfadcattr2,extfadcattr0,extfadcattr0}, fadcattr2
			concatenate/o/np=0 {tempfadcattr3,extfadcattr32,extfadcattr32}, fadcattr3
			concatenate/o/np=0 {tempfadcattr4,extfadcattr2,extfadcattr2}, fadcattr4
			concatenate/o/np=0 {tempfadcattr5,extfadcattr2,extfadcattr2}, fadcattr5
			break
		default:
			// error
			print "[ERROR] \"fdacCreateControlWaves\": Driver only supports up to 4 FastDACs!"
			abort
			break
	endswitch
	concatenate/o {fdac1,fdac2,fdac3,fdac4}, fdacvalstr
	duplicate/o/rmd=[][1] fdacvalstr, old_fdacvalstr
	concatenate/o {fdacattr1,fdacattr2,fdacattr3,fdacattr4}, fdacattr
	concatenate/o {fadc1,fadc2,fadc3,fadc4,fadc5}, fadcvalstr
	concatenate/o {fadcattr1,fadcattr2,fadcattr3,fadcattr4,fadcattr5}, fadcattr
	
	variable/g sc_printfadc = 0
	variable/g sc_saverawfadc = 0
	
	// clean up
	killwaves/z tempfdac1,tempfdac2,tempfdac3,tempfdac4
	killwaves/z tempfdacattr1,tempfdacattr2,tempfdacattr3,tempfdacattr4
	killwaves/z tempfadc1,tempfadc2,tempfadc3,tempfadc4,tempfadc5
	killwaves/z tempfadcattr1,tempfadcattr2,tempfadcattr3,tempfadcattr4,tempfadcattr5
	killwaves/z fdac1,fdac2,fdac3,fdac4
	killwaves/z fdacattr1,fdacattr2,fdacattr3,fdacattr4
	killwaves/z fadc1,fadc2,fadc3,fadc4,fadc5
	killwaves/z fadcattr1,fadcattr2,fadcattr3,fadcattr4,fadcattr5
end

function fdacSetGUIinteraction(num_fdac)
	variable num_fdac
	
	// edit interaction mode popup menus if nessesary
	switch(num_fdac)
		case 1:
			popupMenu fadcSetting2, disable=2
			popupMenu fadcSetting3, disable=2
			popupMenu fadcSetting4, disable=2
			break
		case 2:
			popupMenu fadcSetting3, disable=2
			popupMenu fadcSetting4, disable=2
			break
		case 3:
			popupMenu fadcSetting4, disable=2
			break
		case 4:
			// do nothing
			break
		default:
			// error
			print "[ERROR] \"fdacSetGUIinteraction\": Driver only supports up to 4 FastDACs!"
			abort
	endswitch
end