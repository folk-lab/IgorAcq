#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Scan Controller routines for 1d and 2d scans
// Version 1.7 August 8, 2016
// Authors: Mohammad Samani, Nik Hartman & Christian Olsen

function sc_checksweepstate()
	nvar sc_abortsweep, sc_pause
	if (GetKeyState(0) & 32)
			// If the ESC button is pressed during the scan, save existing data and stop the scan.
			SaveWaves(msg="The scan was aborted during the execution.")
			abort
		endif
		
		if(sc_abortsweep)
			// If the Abort button is pressed during the scan, save existing data and stop the scan.
			SaveWaves(msg="The scan was aborted during the execution.")
			abort "Measurement aborted by user"
			dowindow /k SweepControl
		elseif(sc_pause)
			// Pause sweep if button is pressed
			do
				if(sc_abortsweep)
					SaveWaves(msg="The scan was aborted during the execution.")
					dowindow /k SweepControl
					abort "Measurement aborted by user"
				endif
			while(sc_pause)
	endif
end

function sc_sleep(delay)
	// sleep for delay seconds while 
	// checking for breaks and doing other tasks
	variable delay
	nvar sc_abortsweep, sc_pause
	
	variable i=0, start_time = datetime
	do

		if(i==0)
			doupdate // update plots on first iteration only
		endif
		
		sc_checksweepstate()
		
	while(datetime-start_time < delay)
end

function InitScanController()
	string filelist = ""
	
	GetFileFolderInfo/z/q/p=config
	
	if(v_flag==0)
		filelist = greplist(indexedfile(config,-1,".config"),"sc")
	endif
	
	if(itemsinlist(filelist)>0)
		// read content into waves
		sc_loadconfig(filelist)
	else
		// These arrays should have the same size. Their indeces correspond to each other.
		make/t/o sc_RawWaveNames = {"g1x", "g1y"} // Wave names to be created and saved
		make/o sc_RawRecord = {0,0} // Whether you want to record and save the data for this wave
		make/o sc_RawPlot = {0,0} // Whether you want to record and save the data for this wave
		make/t/o sc_RequestScripts = {"", ""}
		make/t/o sc_GetResponseScripts = {"getg1x()", "getg1y()"}
		// End of same-size waves
		
		// And these waves should be the same size too
		make/t/o sc_CalcWaveNames = {"", ""} // Calculated wave names
		make/t/o sc_CalcScripts = {"",""} // Scripts to calculate stuff
		make/o sc_CalcRecord = {0,0} // Include this calculated field or not
		make/o sc_CalcPlot = {0,0} // Include this calculated field or not
		// end of same-size waves
		
		// default colormap
		string /g sc_ColorMap = "Grays"
		
		// Print variables
		variable/g sc_PrintRaw = 1,sc_PrintCalc = 1
		
		// logging string
		string /g sc_LogStr = "GetSRSStatus(srs1);"
			
		nvar filenum
		if (numtype(filenum) == 2)
			print "Initializing FileNum to 0 since it didn't exist before.\n"
			variable /g filenum=0
		else
			printf "Current FileNum is %d\n", filenum
		endif
	endif
	// variable to keep track of abort operations
	variable /g sc_AbortSave = 0
	
	sc_rebuildwindow()
end

function sc_rebuildwindow()
	dowindow /k ScanController
	execute("ScanController()")
end

// In order to enable or disable a wave, call these two functions instead of messing with the waves sc_RawRecord and sc_CalcRecord directly
function EnableScanControllerItem(wn)
	string wn
	ChangeScanControllerItemStatus(wn, 1)
end
function DisableScanControllerItem(wn)
	string wn
	ChangeScanControllerItemStatus(wn, 0)
end

function ChangeScanControllerItemStatus(wn, ison)
	string wn
	variable ison
	string cmd
	wave sc_RawRecord, sc_CalcRecord
	wave /t sc_RawWaveNames, sc_CalcWaveNames
	variable i=0, done=0
	do
		if (stringmatch(sc_RawWaveNames[i], wn))
			sc_RawRecord[i]=ison
			cmd = "CheckBox sc_RawRecordCheckBox" + num2istr(i) + " value=" + num2istr(ison)
			execute(cmd)
			done=1
		endif
		i+=1
	while (i<numpnts( sc_RawWaveNames ) && !done)

	i=0
	do
		if (stringmatch(sc_CalcWaveNames[i], wn))
			sc_CalcRecord[i]=ison
			cmd = "CheckBox sc_CalcRecordCheckBox" + num2istr(i) + " value=" + num2istr(ison)
			execute(cmd)	
		endif
		i+=1
	while (i<numpnts( sc_CalcWaveNames ) && !done)

	if (!done) 
		print "Error: Could not find the wave name specified."
	endif
	execute("doupdate")
end

Window ScanController() : Panel
	variable sc_InnerBoxW = 660, sc_InnerBoxH = 32, sc_InnerBoxSpacing = 2

	if (numpnts(sc_RawWaveNames) != numpnts(sc_RawRecord) ||  numpnts(sc_RawWaveNames) != numpnts(sc_RequestScripts) ||  numpnts(sc_RawWaveNames) != numpnts(sc_GetResponseScripts)) 
		print "sc_RawWaveNames, sc_RawRecord, sc_RequestScripts, and sc_GetResponseScripts waves should have the number of elements.\nGo to the beginning of InitScanController() to fix this.\n"
		abort
	endif

	if (numpnts(sc_CalcWaveNames) != numpnts(sc_CalcRecord) ||  numpnts(sc_CalcWaveNames) != numpnts(sc_CalcScripts)) 
		print "sc_CalcWaveNames, sc_CalcRecord, and sc_CalcScripts waves should have the number of elements.\n  Go to the beginning of InitScanController() to fix this.\n"
		abort
	endif

	PauseUpdate; Silent 1		// building window...
	dowindow /K ScanController
	NewPanel /W=(10,10,sc_InnerBoxW + 30,200+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+1)*(sc_InnerBoxH+sc_InnerBoxSpacing) ) /N=ScanController
	ModifyPanel frameStyle=2
	ModifyPanel fixedSize=1
	SetDrawLayer UserBack

	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 13,29,"Wave Name"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 130,29,"Record"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 200,29,"Plot"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 250,29,"Request Script (Optional)"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 460,29,"Get Response Script"

	string cmd = ""
	variable i=0
	do
		DrawRect 9,30+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing),5+sc_InnerBoxW,30+sc_InnerBoxH+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)
		//DrawText 13,54+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing), sc_RawWaveNames[i]
		cmd="SetVariable sc_RawWaveNameBox" + num2istr(i) + " pos={13, 37+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={110, 0}, fsize=14, title=\" \", value=sc_RawWaveNames[i]"
		execute(cmd)
		cmd="CheckBox sc_RawRecordCheckBox" + num2istr(i) + ", proc=sc_CheckBoxClicked, pos={150,40+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_RawRecord[i]) + " , title=\"\""
		execute(cmd)
		cmd="CheckBox sc_RawPlotCheckBox" + num2istr(i) + ", proc=sc_CheckBoxClicked, pos={210,40+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_RawPlot[i]) + " , title=\"\""
		execute(cmd)
		cmd="SetVariable sc_RequestScriptBox" + num2istr(i) + " pos={250, 37+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={200, 0}, fsize=14, title=\" \", value=sc_RequestScripts[i]"
		execute(cmd)
		cmd="SetVariable sc_GetResponseScriptBox" + num2istr(i) + " pos={460, 37+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={200, 0}, fsize=14, title=\" \", value=sc_GetResponseScripts[i]"
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
	DrawText 250,i*(sc_InnerBoxH + sc_InnerBoxSpacing)+50,"Calculation Script ( example: dmm[i]*12.5)"

	i=0
	do
		DrawRect 9,85+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing),5+sc_InnerBoxW,85+sc_InnerBoxH+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)
		cmd="SetVariable sc_CalcWaveNameBox" + num2istr(i) + " pos={13, 92+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={110, 0}, fsize=14, title=\" \", value=sc_CalcWaveNames[i]"
		execute(cmd)		
		cmd="CheckBox sc_CalcRecordCheckBox" + num2istr(i) + ", proc=sc_CheckBoxClicked, pos={150,95+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_CalcRecord[i]) + " , title=\"\""
		execute(cmd)
		cmd="CheckBox sc_CalcPlotCheckBox" + num2istr(i) + ", proc=sc_CheckBoxClicked, pos={210,95+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_CalcPlot[i]) + " , title=\"\""
		execute(cmd)
		cmd="SetVariable sc_CalcScriptBox" + num2istr(i) + " pos={250, 92+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={410, 0}, fsize=14, title=\" \", value=sc_CalcScripts[i]"
		execute(cmd)		
		i+=1
	while (i<numpnts( sc_CalcWaveNames ))	
	button addrowcalc,pos={550,89+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)},size={110,20},proc=sc_addrow,title="Add Row"
	button removerowcalc,pos={430,89+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)},size={110,20},proc=sc_removerow,title="Remove Row"
	checkbox sc_PrintCalcBox, pos={300,89+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)}, proc=sc_CheckBoxClicked, value=sc_PrintCalc,side=1,title="\Z14Print filenames"
	
	// box for logging functions
	variable sc_Loggable
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 13,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+25,"Logging Functions (example: getSRSstatus(srs1); getIPSstatus();)"
	DrawRect 9,120+5+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+25,5+sc_InnerBoxW,120+5+sc_InnerBoxH+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+25
	cmd="SetVariable sc_LogStr pos={13, 127+5+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+25}, size={sc_InnerBoxW-12, 0}, fsize=14, title=\" \", value=sc_LogStr"
	execute(cmd)
	
	// helpful text
	DrawText 13,170+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+1)*(sc_InnerBoxH+sc_InnerBoxSpacing),"Press Update to save changes."
	DrawText 13,190+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+1)*(sc_InnerBoxH+sc_InnerBoxSpacing),"Press ESC to abort the scan and save data, while this window is active"
	
	// Close all open graphs
	button killgraphs, pos={420,154+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+1)*(sc_InnerBoxH+sc_InnerBoxSpacing)},size={120,20},proc=sc_killgraphs,title="Close All Graphs"
	button killabout, pos={220,154+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+1)*(sc_InnerBoxH+sc_InnerBoxSpacing)},size={190,20},proc=sc_controlwindows,title="Kill Sweep Control Windows"
	
	//Update button
	button updatebutton, pos={550,154+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+1)*(sc_InnerBoxH+sc_InnerBoxSpacing)},size={110,20},proc=sc_updatewindow,title="Update"
EndMacro

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
	sc_controlwindows("") // Kill all open control windows
end

function sc_updatewindow(action) : ButtonControl
	string action
	// Write (or overwrite) a config file
	sc_createconfig()
end

function sc_addrow(action) : ButtonControl
	string action
	wave/t sc_RawWaveNames=sc_RawWaveNames
	wave sc_RawRecord=sc_RawRecord 
	wave sc_RawPlot=sc_RawPlot
	wave/t sc_RequestScripts=sc_RequestScripts
	wave/t sc_GetResponseScripts=sc_GetResponseScripts
	wave/t sc_CalcWaveNames=sc_CalcWaveNames
	wave sc_CalcRecord=sc_CalcRecord 
	wave sc_CalcPlot=sc_CalcPlot
	wave/t sc_CalcScripts=sc_CalcScripts
	
	strswitch(action)
		case "addrowraw":
			AppendString(sc_RawWaveNames, "")
			AppendValue(sc_RawRecord, 0)
			AppendValue(sc_RawPlot, 0)
			AppendString(sc_RequestScripts, "")
			AppendString(sc_GetResponseScripts, "")
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
	wave/t sc_RequestScripts=sc_RequestScripts
	wave/t sc_GetResponseScripts=sc_GetResponseScripts
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
				Redimension /N=(numpnts(sc_RequestScripts)-1) sc_RequestScripts
				Redimension /N=(numpnts(sc_GetResponseScripts)-1) sc_GetResponseScripts
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

function AppendValue(thewave, thevalue)
	wave thewave
	variable thevalue
	Redimension /N=(numpnts(thewave)+1) thewave
	thewave[numpnts(thewave)-1] = thevalue
end

function AppendString(thewave, thestring)
	wave/t thewave
	string thestring
	Redimension /N=(numpnts(thewave)+1) thewave
	thewave[numpnts(thewave)-1] = thestring
end

// Update after checkbox clicked
function sc_CheckboxClicked(ControlName, Value)
	string ControlName
	variable value
	string indexstring
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	nvar sc_PrintRaw, sc_PrintCalc
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
	elseif(stringmatch(ControlName,"sc_PrintRawBox"))
		sc_PrintRaw = value
	elseif(stringmatch(ControlName,"sc_PrintCalcBox"))
		sc_PrintCalc = value
	endif
end

Function/S RemoveEndingWhitespace(str)
	// stolen from http://www.igorexchange.com/node/2957
	String str
 
	do
		String str2= RemoveEnding(str," ")
		if( CmpStr(str2, str) == 0 )
			break
		endif
		str= str2
	while( 1 )
	return str
End

function InitializeWaves(start, fin, numpts, [starty, finy, numptsy, x_label, y_label])
	variable start, fin, numpts, starty, finy, numptsy
	string x_label, y_label
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	wave /T sc_RawWaveNames, sc_CalcWaveNames, sc_RequestScripts, sc_GetResponseScripts
	variable i=0, j=0
	string cmd = "", wn = "", wn2d="", s, script = "", script0 = "", script1 = ""
	string /g sc_x_label, sc_y_label
	variable /g sc_is2d, sc_scanstarttime = datetime
	variable /g sc_startx, sc_finx, sc_numptsx, sc_starty, sc_finy, sc_numptsy
	variable/g sc_abortsweep=0, sc_pause=0
	string graphlist, graphname, plottitle, graphtitle="", graphnumlist="", graphnum, activegraphs="", cmd1="",window_string=""
	string cmd2=""
	variable index, graphopen, graphopen2d
	svar sc_ColorMap
	
	//do some sanity checks on wave names: they should not start or end with numbers.
	do
		if (sc_RawRecord[i])
			s = sc_RawWaveNames[i]
			if (!((char2num(s[0]) >= 97 && char2num(s[0]) <= 122) || (char2num(s[0]) >= 65 && char2num(s[0]) <= 90)))
				print "The first character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
				abort
			endif
			if (!((char2num(s[strlen(s)-1]) >= 97 && char2num(s[strlen(s)-1]) <= 122) || (char2num(s[strlen(s)-1]) >= 65 && char2num(s[strlen(s)-1]) <= 90)))
				print "The last character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
				abort
			endif
		endif
		i+=1
	while (i<numpnts(sc_RawWaveNames))
	i=0
	do
		if (sc_CalcRecord[i])
			s = sc_CalcWaveNames[i]
			if (!((char2num(s[0]) >= 97 && char2num(s[0]) <= 122) || (char2num(s[0]) >= 65 && char2num(s[0]) <= 90)))
				print "The first character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
				abort
			endif
			if (!((char2num(s[strlen(s)-1]) >= 97 && char2num(s[strlen(s)-1]) <= 122) || (char2num(s[strlen(s)-1]) >= 65 && char2num(s[strlen(s)-1]) <= 90)))
				print "The last character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
				abort
			endif
		endif
		i+=1
	while (i<numpnts(sc_CalcWaveNames))	
	i=0
	
	// check that request and response scripts are defined correctly
	// check request scripts first
	variable ii=0
	do
		if (sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1)
			script = RemoveEndingWhitespace(sc_RequestScripts[ii])
			if(cmpstr(script, "")!=0) // it's ok if this one is empty
				// check if there is more than one command
				script0 = RemoveEndingWhitespace(stringfromlist(0, script)) // should be something here
				script1 = RemoveEndingWhitespace(stringfromlist(1, script)) // should be nothing here
				if(cmpstr(script1, "")!=0 ||  strsearch(script0, "()", 0)==-1) // check that script1 is empty and script0 contains ()
					abort "Request scripts should be formatted as: setParam() with no arguments and only a single function call"
				else
					sc_RequestScripts[ii] = script0
				endif
			endif
		endif
		ii+=1
	while (ii < numpnts(sc_RawWaveNames))
	
	// check response scripts
	ii=0
	do
		if (sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1)
			script = RemoveEndingWhitespace(sc_GetResponseScripts[ii])
			
			// check if there is more than one command
			script0 = RemoveEndingWhitespace(stringfromlist(0, script)) // should be something here
			script1 = RemoveEndingWhitespace(stringfromlist(1, script)) // should be nothing here
			if(cmpstr(script1, "")!=0 ||  strsearch(script0, "()", 0)==-1) // check that script1 is empty and script0 contains ()
				abort "Response scripts should be formatted as: getParam() with no arguments and only a single function call"
			else
				sc_GetResponseScripts[ii] = script0
			endif
		endif
		ii+=1
	while (ii < numpnts(sc_RawWaveNames))
	
	//Check if Data exsits as a path
	GetFileFolderInfo/Z/Q/P=Data
	if(V_Flag != 0 || V_isFolder != 1)
		abort "The path Data is not defined correctly."
	endif
	
	// The status of the upcoming scan will be set when waves are initialized.
	if(!paramisdefault(starty) && !paramisdefault(finy) && !paramisdefault(numptsy))
		sc_is2d = 1
		sc_startx = start
		sc_finx = fin
		sc_numptsx = numpts
		sc_starty = starty
		sc_finy = finy
		sc_numptsy = numptsy
	else
		sc_is2d = 0
		sc_startx = start
		sc_finx = fin
		sc_numptsx = numpts	
	endif
	
	if(paramisdefault(x_label) || stringmatch(x_label,""))
		sc_x_label=""
	else
		sc_x_label=x_label
	endif
	
	if(paramisdefault(y_label) || stringmatch(y_label,""))
		sc_y_label=""
	else
		sc_y_label=y_label
	endif
	
	// Initialize waves for raw data
	do
		if (sc_RawRecord[i] == 1 && cmpstr(sc_RawWaveNames[i], "") || sc_RawPlot[i] == 1 && cmpstr(sc_RawWaveNames[i], ""))
			wn = sc_RawWaveNames[i]
			cmd = "make /o/n=(" + num2istr(sc_numptsx) + ") " + wn + "=NaN"
			execute(cmd)
			cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + wn
			execute(cmd)
			if(sc_is2d)
				// In case this is a 2D measurement
				wn2d = wn + "2d"
				cmd = "make /o/n=(" + num2istr(sc_numptsx) + ", " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd)
				cmd = "setscale /i x, " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", " + wn2d; execute(cmd)
				cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)
			endif			
		endif
		i+=1
	while (i<numpnts(sc_RawWaveNames))

	// Initialize waves for calculated data
	i=0
	do
		if (sc_CalcRecord[i] == 1 && cmpstr(sc_CalcWaveNames[i], "") || sc_CalcPlot[i] == 1 && cmpstr(sc_CalcWaveNames[i], ""))
			wn = sc_CalcWaveNames[i]
			cmd = "make /o/n=(" + num2istr(sc_numptsx) + ") " + wn + "=NaN"
			execute(cmd)
			cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + wn
			execute(cmd)		
			if(sc_is2d)
				// In case this is a 2D measurement
				wn2d = wn + "2d"
				cmd = "make /o/n=(" + num2istr(sc_numptsx) + ", " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd)
				cmd = "setscale /i x, " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", " + wn2d; execute(cmd)
				cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)
			endif			
			
		endif
		i+=1
	while (i<numpnts(sc_CalcWaveNames))
	
	// Find all open plots
	graphlist = winlist("*",";","WIN:1")
	j=0
	for (i=0;i<round(strlen(graphlist)/6);i=i+1)
		index = strsearch(graphlist,";",j)
		graphname = graphlist[j,index-1]
		setaxis/w=$graphname /a
		getwindow $graphname wtitle
		splitstring /e="(.*):(.*)" s_value, graphnum, plottitle
		graphtitle+= plottitle+";"
		graphnumlist+= graphnum+";"
		j=index+1
	endfor
	
	//Initialize plots for raw data waves
	i=0
	do
		if (sc_RawPlot[i] == 1 && cmpstr(sc_RawWaveNames[i], ""))
			wn = sc_RawWaveNames[i]
			graphopen = 0
			graphopen2d = 0
			for(j=0;j<ItemsInList(graphtitle);j=j+1)
				if(stringmatch(wn,stringfromlist(j,graphtitle)))
					graphopen = 1
					activegraphs+= stringfromlist(j,graphnumlist)+";"
					Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
				endif
				if(sc_is2d)
					if(stringmatch(wn+"2d",stringfromlist(j,graphtitle)))
						graphopen2d = 1
						activegraphs+= stringfromlist(j,graphnumlist)+";"
						Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
					endif
				endif
			endfor
			if(graphopen && graphopen2d)
			elseif(graphopen2d)
				display $wn
				Label bottom, sc_x_label
				activegraphs+= winname(0,1)+";"
			elseif(graphopen)
				if(sc_is2d)
					wn2d = wn + "2d"
					display
					appendimage $wn2d
					modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
					colorscale /c/n=$sc_ColorMap /e/a=rc
					Label left, sc_y_label
					Label bottom, sc_x_label
					activegraphs+= winname(0,1)+";"
				endif
			else
				wn2d = wn + "2d"
				display $wn
				Label bottom, sc_x_label
				activegraphs+= winname(0,1)+";"
				if(sc_is2d)
					display
					appendimage $wn2d
					modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
					colorscale /c/n=$sc_ColorMap /e/a=rc
					Label left, sc_y_label
					Label bottom, sc_x_label
					activegraphs+= winname(0,1)+";"
				endif
			endif
		endif
		i+= 1
	while(i<numpnts(sc_RawWaveNames))
	
	//Initialize plots for calculated data waves
	i=0
	do
		if (sc_CalcPlot[i] == 1 && cmpstr(sc_CalcWaveNames[i], ""))
			wn = sc_CalcWaveNames[i]
			graphopen = 0
			graphopen2d = 0
			for(j=0;j<ItemsInList(graphtitle);j=j+1)
				if(stringmatch(wn,stringfromlist(j,graphtitle)))
					graphopen = 1
					activegraphs+= stringfromlist(j,graphnumlist)+";"
					Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
				endif
				if(sc_is2d)
					if(stringmatch(wn+"2d",stringfromlist(j,graphtitle)))
						graphopen2d = 1
						activegraphs+= stringfromlist(j,graphnumlist)+";"
						Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
					endif
				endif
			endfor
			if(graphopen && graphopen2d)
			elseif(graphopen2d)
				display $wn
				Label bottom, sc_x_label
				activegraphs+= winname(0,1)+";"
			elseif(graphopen)
				if(sc_is2d)
					wn2d = wn + "2d"
					display
					appendimage $wn2d
					modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
					colorscale /c/n=$sc_ColorMap /e/a=rc
					Label left, sc_y_label
					Label bottom, sc_x_label
					activegraphs+= winname(0,1)+";"
				endif
			else
				wn2d = wn + "2d"
				display $wn
				Label bottom, sc_x_label
				activegraphs+= winname(0,1)+";"
				if(sc_is2d)
					display
					appendimage $wn2d
					modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
					colorscale /c/n=$sc_ColorMap /e/a=rc
					Label left, sc_y_label
					Label bottom, sc_x_label
					activegraphs+= winname(0,1)+";"
				endif
			endif
		endif
		i+= 1
	while(i<numpnts(sc_CalcWaveNames))
	
	execute("abortmeasurementwindow()")
	
	cmd1 = "TileWindows/O=1/A=(3,4) "
	// Tile graphs
	for(i=0;i<itemsinlist(activegraphs);i=i+1)
		window_string = stringfromlist(i,activegraphs)
		cmd1+= window_string +","
		cmd2 = "DoWindow/F " + window_string
		execute(cmd2)
	endfor
	cmd1 += "SweepControl"
	execute(cmd1)
end

function InitializeTmpWaves(innerindex, outerindex, timeavg, timeavg_delay) 
	// initializes additional waves necessary for time averaging
	variable innerindex, outerindex, timeavg, timeavg_delay
	string x_label = "time (s)" // the x axis will always be time
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot // waves that tell me what to record and plot
	wave /T sc_RawWaveNames, sc_CalcWaveNames, sc_RequestScripts, sc_GetResponseScripts // wave names and scripts
	variable i=0, j=0
	string cmd = "", wn = "", wn2d="", s, script = "", script0 = "", script1 = ""
	variable/g sc_abortsweep=0, sc_pause=0
	string graphlist, graphname, plottitle, graphtitle="", graphnumlist="", graphnum, activegraphs="", cmd1="",window_string=""
	string cmd2=""
	variable index, graphopen
	nvar sc_is2d, sc_startx, sc_finx, sc_numptsx, sc_scandirection
	svar sc_ColorMap
	
	// Initialize waves for raw data
	variable start = 0
	variable /g sc_tmp_numpts = round(timeavg/timeavg_delay)
	
	if(sc_tmp_numpts<5)
		abort("You are time averaging over less than 5 points. You should reconsider.")
	endif
	
	do
		if (sc_RawRecord[i] == 1 && cmpstr(sc_RawWaveNames[i], "") || sc_RawPlot[i] == 1 && cmpstr(sc_RawWaveNames[i], ""))
			// make 1d waves to plot live data
			wn = "tmp_"+sc_RawWaveNames[i]
			cmd = "make /o/n=(" + num2istr(sc_tmp_numpts) + ") " + wn + "=NaN"
			execute(cmd)
			cmd = "setscale/I x " + num2str(0) + ", " + num2str(timeavg) + ", \"\", " + wn
			execute(cmd)
			if ((innerindex == 0 && sc_scandirection == 1) || (innerindex == sc_numptsx-1 && sc_scandirection == -1))
				// make 2d waves to record time series versus x values
				// only if this is the beginning of an x sweep
				wn2d = "tmp_"+sc_RawWaveNames[i]+"2d"
				cmd = "make /o/n=(" + num2istr(sc_tmp_numpts) + ", " + num2istr(sc_numptsx) + ") " + wn2d + "=NaN"; execute(cmd)
				cmd = "setscale /i x, " + num2str(0) + ", " + num2str(timeavg) + ", " + wn2d; execute(cmd)
				cmd = "setscale /i y, " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", " + wn2d; execute(cmd)
			endif
		endif
		i+=1
	while (i<numpnts(sc_RawWaveNames))
	
	if(innerindex==0 && outerindex==0)
		// Find all open plots
		graphlist = winlist("*",";","WIN:1")
		j=0
		for (i=0;i<round(strlen(graphlist)/6);i=i+1)
			index = strsearch(graphlist,";",j)
			graphname = graphlist[j,index-1]
			getwindow $graphname wtitle
			splitstring /e="(.*):(.*)" s_value, graphnum, plottitle
			graphtitle+= plottitle+";"
			graphnumlist+= graphnum+";"
			j=index+1
		endfor
		
		//Initialize plots for 1d tmp raw data waves
		i=0
		do
			if (sc_RawPlot[i] == 1 && cmpstr(sc_RawWaveNames[i], ""))
				wn = "tmp_" + sc_RawWaveNames[i]
				graphopen=0
				for(j=0;j<ItemsInList(graphtitle);j=j+1)
					if(stringmatch(wn,stringfromlist(j,graphtitle)))
						graphopen=1
						activegraphs+= stringfromlist(j,graphnumlist)+";"
						Label /W=$stringfromlist(j,graphnumlist) bottom,  x_label
					endif
				endfor
				if(graphopen==0)
					display $wn
					Label bottom, x_label
					activegraphs+= winname(0,1)+";"
				endif
			endif
			i+= 1
		while(i<numpnts(sc_RawWaveNames))
		
		cmd1 = "TileWindows/O=1/A=(3,4) "
		// Tile graphs
		for(i=0;i<itemsinlist(activegraphs);i=i+1)
			window_string = stringfromlist(i,activegraphs)
			cmd1+= window_string +","
			cmd2 = "DoWindow/F " + window_string
			execute(cmd2)
		endfor
		cmd1 += "SweepControl"
		execute(cmd1)
		
	endif
end

window abortmeasurementwindow() : Panel
	//Silent 1 // building window
	NewPanel /W=(500,700,750,750) /N=SweepControl// window size
	ModifyPanel frameStyle=2
	ModifyPanel fixedSize=1
	SetDrawLayer UserBack
	Button pausesweep, pos={10,15},size={110,20},proc=pausesweep,title="Pause"
	Button stopsweep, pos={130,15},size={110,20},proc=stopsweep,title="Abort"
	DoUpdate /W=SweepControl /E=1
endmacro

function stopsweep(action) : Buttoncontrol
	string action
	nvar sc_abortsweep
	
	sc_abortsweep = 1
end 

function pausesweep(action) : Buttoncontrol
	string action
	nvar sc_pause, sc_abortsweep
	
	Button pausesweep,proc=resumesweep,title="Resume"
	sc_pause=1
	print "Sweep paused by user"
end

function resumesweep(action) : Buttoncontrol
	string action
	nvar sc_pause
	
	Button pausesweep,proc=pausesweep,title="Pause"
	sc_pause = 0
	print "Sweep resumed"
end

function protofunc()
	/// this function will be used to format function calls from strings
	/// in this revision, all functions in requestscripts and responsescripts must take no arguments
	///
	/// for example:
	/// getTemp("mc")
	/// should be replaced with a function like
	/// function getMCTemp()
 	/// 	return getTemp("mc")
 	/// end
 end	
 	
function RecordValues(i, j, [scandirection, readvstime, timeavg, timeavg_delay, fillnan])
	// In a 1d scan, i is the index of the loop. j will be ignored.
	// In a 2d scan, i is the index of the outer (slow) loop, and j is the index of the inner (fast) loop. 

	// In a 2D scan, if scandirection=1 (scan up), the 1d wave gets saved into the matrix when j=numptsy. 
	// If scandirection=-1(scan down), the 1d matrix gets saved when j=0. Default is 1 (up)
	
	// readvstime works only in 1d and rescales (grows) the wave at each index
	
	// timeavg and timeavg_delay set the parameters to average over many read calls for each record value call
	
	// fillnan skips any read or calculation functions entirely and fills point [i,j] with nan
	
	variable i, j, scandirection, readvstime, fillnan, timeavg, timeavg_delay
	nvar sc_is2d, sc_startx, sc_finx, sc_numptsx, sc_starty, sc_finy, sc_numptsy
	variable ii = 0, jj=0
	wave /t sc_RawWaveNames, sc_RequestScripts, sc_GetResponseScripts, sc_CalcWaveNames, sc_CalcScripts
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	string script = "",cmd = "", wstr = ""
	variable innerindex, outerindex
	nvar sc_abortsweep, sc_pause,sc_scanstarttime
	
	//// setup all sorts of logic so we can store values correctly ////
	
	if (sc_is2d)
		// 2d
		innerindex = j
		outerindex = i
	else
		// 1d
		innerindex = i
		outerindex = i // meaningless
	endif
	
	// Default scan direction is up
	if (paramisdefault(scandirection))
		scandirection=1
	endif
	variable /g sc_scandirection = scandirection // create global variable for this
	
	// Set readvstime to 0 if it's not defined
	if(paramisdefault(readvstime))
		readvstime=0
	endif
	
	if (paramisdefault(timeavg))
		timeavg = -1
	endif
	
	if(paramisdefault(timeavg_delay))
		if(timeavg>0)
			abort("Set a timeavg_delay if you are going to use the timeavg feature.")
		endif
	endif
	
	if(paramisdefault(fillnan))
		fillnan=0
	endif
	
	if(readvstime!=0 && timeavg>0)
		abort("Are you time averaging during your time series data? You should reconsider.")
	endif
	
	if(readvstime ==1 && sc_is2d)
		abort "Read vs Time is only supported for 1D sweeps."
	endif
	
	//// end setup ////
	
	if(timeavg<0) // this is the normal behavior -- one read per setpoint
		
		// Send requests to machines
		if(fillnan == 0)
			do
				if (sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1)
					jj=0;
					script = sc_RequestScripts[ii];
					if (cmpstr(script, ""))
						FUNCREF protofunc fscript = $script[0,strlen(script)-3]
						fscript()
					endif
				endif
				ii+=1
			while (ii < numpnts(sc_RawWaveNames))
		endif
		
		// Read responses from machines
		ii=0
		do
			if (sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1)
				if(fillnan == 0)
					script = sc_GetResponseScripts[ii]; // assume i'm just getting one function back here like "readFunc()"
				endif
				
				// Redimension waves if readvstime is set to 1
				if (readvstime == 1)
					redimension /n=(innerindex+1) $sc_RawWaveNames[ii]
					setscale/I x 0,  datetime - sc_scanstarttime, $sc_RawWaveNames[ii]
				endif
	
				// execute response script
				wave wref1d = $sc_RawWaveNames[ii]
				if(fillnan == 0)
					FUNCREF protofunc fscript = $script[0,strlen(script)-3]
					wref1d[innerindex] = fscript()
				elseif(fillnan == 1)
					wref1d[innerindex] = nan
				endif
				
				if (sc_is2d)
					// 2D Wave
					// If this is the last point in a row on a 2d scan, save the row in the 2d wave
					if ((innerindex == sc_numptsx-1 && scandirection == 1) || (innerindex == 0 && scandirection == -1))
						wave wref2d = $sc_RawWaveNames[ii] + "2d"
						wref2d[][outerindex] = wref1d[p]
					endif
				endif
			endif
			ii+=1
		while (ii < numpnts(sc_RawWaveNames))
		
	else // here we will time average a number of reads at each setpoint
		
		// get all the data vs time
		if(fillnan == 0)
			sc_readvstime(i, j, timeavg_delay, timeavg)
		endif
		
		// get all averages into proper waves
		ii=0
		do
			if (sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1)
				
				// Redimension waves if readvstime is set to 1
				// it would be strange if this came up, but i'm not here to judge
				if (readvstime == 1)
					redimension /n=(innerindex+1) $sc_RawWaveNames[ii]
					setscale/I x 0,  datetime - sc_scanstarttime, $sc_RawWaveNames[ii]
				endif
	
				// get mean of tmp_ wave
				wave wref1d = $sc_RawWaveNames[ii]
				wave tempref = $("tmp_"+sc_RawWaveNames[ii])
				if(fillnan == 0)
					wref1d[innerindex] = mean(tempref)
				else
					wref1d[innerindex] = nan
				endif
				
				// If this is the last point in a row on a 2d scan, save the row in the 2d wave
				if (sc_is2d)
					if ((innerindex == sc_numptsx-1 && scandirection == 1) || (innerindex == 0 && scandirection == -1))
						wave wref2d = $sc_RawWaveNames[ii] + "2d"
						wref2d[][outerindex] = wref1d[p]
					endif
				endif
			endif
			ii+=1
		while (ii < numpnts(sc_RawWaveNames))
		
	endif
	
	// Calculate interpreted numbers and store them in calculated waves
	ii=0
	do
		if (sc_CalcRecord[ii] == 1 || sc_CalcPlot[ii] == 1)
			script = sc_CalcScripts[ii]; // assume i'm just getting one function back here like "readFunc()"
			
			// Redimension waves if readvstimeis set to 1
			if (readvstime == 1)
				redimension /n=(innerindex+1) $sc_CalcWaveNames[ii]
				setscale/I x 0, datetime - sc_scanstarttime, $sc_CalcWaveNames[ii]
			endif
			
			// Allow the use of the keyword '[i]' in calculated fields where i is the inner loop's current index
			script = ReplaceString("[i]", script, "["+num2istr(innerindex)+"]")
			execute(sc_CalcWaveNames[ii] + "[" + num2istr(innerindex) + "]=" + script)
			
			if (sc_is2d && fillnan == 0)				
				// if this is the last point in a row on a 2d scan, save the row in the 2d wave
				if ((innerindex == sc_numptsx-1 && scandirection == 1) || (innerindex == 0 && scandirection == -1))
					wave wref1d = $sc_CalcWaveNames[ii]
					wave wref2d = $sc_CalcWaveNames[ii] + "2d"
					wref2d[][outerindex] = wref1d[p]
				endif
			elseif(sc_is2d && fillnan != 0)
				// fill every point with NaN as you go
				wave wref2d = $sc_CalcWaveNames[ii] + "2d"
				wref2d[innerindex][outerindex] = nan							
			endif
		endif
		ii+=1
	while (ii < numpnts(sc_CalcWaveNames))
	
	// check abort/pause status
	sc_checksweepstate()
	
end

function RecordTmpValues(index, innerindex, outerindex)
	// only for use with sc_readvstime()
	variable index, innerindex, outerindex
	variable ii = 0
	wave /t sc_RawWaveNames, sc_RequestScripts, sc_GetResponseScripts, sc_CalcWaveNames, sc_CalcScripts
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	string script = "",cmd = "", wstr = "", tmp_wavename = ""
	// variable innerindex = i, outerindex = j
	nvar sc_abortsweep, sc_pause, tmp_scanstarttime
	nvar sc_tmp_numpts
	
	// Send requests to machines
	do
		if (sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1)
			script = sc_RequestScripts[ii];
			if (cmpstr(script, ""))
				FUNCREF protofunc fscript = $script[0,strlen(script)-3]
				fscript()
			endif
		endif
		ii+=1
	while (ii < numpnts(sc_RawWaveNames))
	
	// Read responses from machines
	ii=0
	do
		if (sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1)
		
			tmp_wavename = "tmp_"+sc_RawWaveNames[ii]
			script = sc_GetResponseScripts[ii]; // assume i'm just getting one function back here like "readFunc()"

			// execute response script
			wave wref1d = $tmp_wavename
			FUNCREF protofunc fscript = $script[0,strlen(script)-3]
			wref1d[index] = fscript()

			// fill 2d wave if necessary
			if (index == sc_tmp_numpts-1)
				wave wref2d = $(tmp_wavename+"2d")
				wref2d[][innerindex] = wref1d[p]
			endif

		endif
		ii+=1
	while (ii < numpnts(sc_RawWaveNames))
	
	// check abort/pause status
	sc_checksweepstate()
	
end

function SaveWaves([msg, save_experiment])
	// the message will be printed in the history, and will be saved in the winf file corresponding to this scan
	string msg
	variable save_experiment
	nvar sc_is2d, sc_PrintRaw, sc_PrintCalc
	nvar sc_scanstarttime
	svar sc_x_label, sc_y_label, sc_LogStr
	string filename, wn, logs=""
	nvar filenum
	wave /t sc_RawWaveNames, sc_CalcWaveNames
	wave sc_RawRecord, sc_CalcRecord
	variable ii=0, Rawadd =0, Calcadd = 0

	if (!paramisdefault(msg))
		print msg
	else
		msg=""
	endif
	
	if (paramisdefault(save_experiment))
		save_experiment = 1 // save the experiment by default
	else
		save_experiment = 0 // do not save the experiment 
	endif
	
	if (strlen(sc_LogStr)!=0)
		logs = sc_LogStr
	endif

	// Raw Data
	do
		Rawadd += sc_RawRecord[ii]
		if (sc_RawRecord[ii] == 1)
			wn = sc_RawWaveNames[ii]
			if (sc_is2d)
				wn += "2d"
			endif
			filename =  "dat" + num2str(filenum) + wn
			duplicate $wn $filename
			if(sc_PrintRaw == 1)
				print filename
			endif
			Save/C/P=data $filename;
			SaveInitialWaveComments(wn, x_label=sc_x_label, y_label=sc_y_label)
			//Save/C/P=backup $filename;

		endif
		ii+=1
	while (ii < numpnts(sc_RawWaveNames))
	// Calculated Data
	ii=0
	do
		Calcadd += sc_CalcRecord[ii]
		if (sc_CalcRecord[ii] == 1)
			wn = sc_CalcWaveNames[ii]
			if (sc_is2d)
				wn += "2d"
			endif
			filename =  "dat" + num2str(filenum) + wn
			duplicate $wn $filename
			if(sc_PrintCalc == 1)
				print filename
			endif
			Save/C/P=data $filename;
			SaveInitialWaveComments(wn, x_label=sc_x_label, y_label=sc_y_label)
		endif
		ii+=1
	while (ii < numpnts(sc_CalcWaveNames))
	
	if(sc_PrintRaw == 0 && sc_PrintCalc == 0 && Rawadd+Calcadd > 0)
		print "dat"+ num2str(filenum)
	endif
	
	if(Rawadd+Calcadd > 0)
		// Save WINF for this sweep
		saveScanComments(msg=msg, logs=logs)
		filenum+=1
	endif
	
	printf "Time elapsed: %.2f s \r", datetime-sc_scanstarttime
	dowindow /k SweepControl
	
	if(save_experiment == 1)
		SaveExperiment/p=data
	endif
end

function SaveTmpWaves()
	// for use with sc_readvstime() only
	nvar sc_PrintRaw, sc_PrintCalc
	nvar tmp_scanstarttime
	svar sc_x_label
	string filename="", wn2d="", logs=""
	nvar filenum
	wave /t sc_RawWaveNames, sc_CalcWaveNames
	wave sc_RawRecord, sc_CalcRecord
	variable ii=0, Rawadd =0, Calcadd = 0

	// Raw Data
	do
		Rawadd += sc_RawRecord[ii]
		if (sc_RawRecord[ii] == 1)
			wn2d = "tmp_"+sc_RawWaveNames[ii]+"2d"
			filename =  "dat" + num2str(filenum) + "_" + wn2d
			duplicate $wn2d $filename
			if(sc_PrintRaw == 1)
				print filename
			endif
			Save/C/P=data $filename;
			SaveInitialWaveComments("_"+wn2d, x_label="time (s)", y_label = sc_x_label)
		endif
		ii+=1
	while (ii < numpnts(sc_RawWaveNames))
	
	if(Rawadd+Calcadd > 0)
		// Save WINF for this sweep
		saveScanComments(msg="This is a temporary wave saved for time averaging purposes.", logs="")
		filenum+=1
	endif

end

function sc_readvstime(i, j, delay, timeout)
	variable i, j, delay, timeout
	nvar sc_is2d, sc_numptsx, sc_scandirection
	
	InitializeTmpWaves(i, j, timeout, delay) 
	nvar sc_tmp_numpts
	variable ii=0
	do
		sc_sleep(delay)
		RecordTmpValues(ii, i, j) 
		ii+=1
	while (ii<sc_tmp_numpts)
	if ((i == sc_numptsx-1 && sc_scandirection == 1) || (i == 0 && sc_scandirection == -1))
		SaveTmpWaves() // save tmp_[.....]2d at the end of each x sweep
	endif
end

function sc_createconfig()
	wave/t sc_RawWaveNames
	wave sc_RawRecord
	wave sc_RawPlot
	wave/t sc_RequestScripts
	wave/t sc_GetResponseScripts
	wave/t sc_CalcWaveNames
	wave/t sc_CalcScripts
	wave sc_CalcRecord
	wave sc_CalcPlot
	nvar sc_PrintRaw
	nvar sc_PrintCalc
	svar sc_LogStr
	svar sc_ColorMap
	nvar filenum
	variable refnum
	string configfile, datapath, configpath
	
	// Check if data path is definded
	GetFileFolderInfo/Z/Q/P=data
	
	if(v_flag != 0 || v_isfolder != 1)
		print "Data path no defined. No config file created!\n"
		return 0
	else
		pathinfo data; datapath=S_path
		configpath = datapath+"config:"
		newpath /C/O/Q config configpath // easier just to add/create a path than to check
	endif
	
	configfile = "sc" + num2istr(unixtime()) + ".config"
	
	// Try to open config file or create it otherwise
	open /z/p=config refnum as configfile
	
	wfprintf refnum, "%s,", sc_RawWaveNames
	fprintf refnum, "\r"
	wfprintf refnum, "%g,", sc_RawRecord
	fprintf refnum, "\r"
	wfprintf refnum, "%g,", sc_RawPlot
	fprintf refnum, "\r"
	wfprintf refnum, "%s,", sc_RequestScripts
	fprintf refnum, "\r"
	wfprintf refnum, "%s,", sc_GetResponseScripts
	fprintf refnum, "\r"
	wfprintf refnum, "%s,", sc_CalcWaveNames
	fprintf refnum, "\r"
	wfprintf refnum, "%s,", sc_CalcScripts
	fprintf refnum, "\r"
	wfprintf refnum, "%g,", sc_CalcRecord
	fprintf refnum, "\r"
	wfprintf refnum, "%g,", sc_CalcPlot
	fprintf refnum, "\r"
	fprintf refnum, "%g\r", sc_PrintRaw
	fprintf refnum, "%g\r", sc_PrintCalc
	fprintf refnum, "%s\r", sc_LogStr
	fprintf refnum, "%s\r", sc_ColorMap
	fprintf refnum, "%g\r", filenum
	
	close refnum
end

function sc_loadconfig(filelist)
	string filelist
	variable refnum
	string loadcontainer
	nvar sc_PrintRaw
	nvar sc_PrintCalc
	svar sc_LogStr
	svar sc_ColorMap
	nvar filenum
	variable i, confignum=0
	string file_string, configunix
	
	make/o/d/n=(itemsinlist(filelist)) configmax=0
	
	for(i=0;i<itemsinlist(filelist);i=i+1)
		file_string = stringfromlist(i,filelist)
		splitstring/e=("sc([[:digit:]]+).config") file_string, configunix
		confignum = str2num(configunix)
		configmax[i] = confignum
	endfor
	confignum = wavemax(configmax)
	
	open /z/r/p=config refnum as "sc"+num2istr(confignum)+".config"
	printf "Loading configuration from: %s\n", "sc"+num2istr(confignum)+".config"
	
	// load raw wave configuration
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2textwave(removeending(loadcontainer,"\r"),"sc_RawWaveNames")
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2numwave(removeending(loadcontainer,"\r"),"sc_RawRecord")
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2numwave(removeending(loadcontainer,"\r"),"sc_RawPlot")
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2textwave(removeending(loadcontainer,"\r"),"sc_RequestScripts")
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2textwave(removeending(loadcontainer,"\r"),"sc_GetResponseScripts")
	
	// load calc wave configuration
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2textwave(removeending(loadcontainer,"\r"),"sc_CalcWaveNames")
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2textwave(removeending(loadcontainer,"\r"),"sc_CalcScripts")
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2numwave(removeending(loadcontainer,"\r"),"sc_CalcRecord")
	freadline/t=(num2char(13)) refnum, loadcontainer
	list2numwave(removeending(loadcontainer,"\r"),"sc_CalcPlot")
	
	// load print checkbox settings
	freadline/t=(num2char(13)) refnum, loadcontainer
	sc_PrintRaw = str2num(removeending(loadcontainer,"\r"))
	freadline/t=(num2char(13)) refnum, loadcontainer
	sc_PrintCalc = str2num(removeending(loadcontainer,"\r"))
	
	// load log string
	freadline/t=(num2char(13)) refnum, loadcontainer
	sc_LogStr = removeending(loadcontainer,"\r")
	
	// load colormap
	freadline/t=(num2char(13)) refnum, loadcontainer
	sc_ColorMap = removeending(loadcontainer,"\r")
	
	close refnum
end

function list2textwave(stringlistwave,namewave)
	string stringlistwave, namewave
	variable n = ItemsInList(stringlistwave,",")
	make/o/t/n=(n) $namewave=StringFromList(p,stringlistwave, ",")
end

function list2numwave(stringlistwave,namewave)
	string stringlistwave, namewave
	variable n = ItemsInList(stringlistwave,",")
	make/o/t/n=(n) blawave=StringFromList(p,stringlistwave, ",")
	make/o/n=(n) $namewave= str2num(blawave)
end

function sc_controlwindows(action)
	string action
	string openaboutwindows
	variable ii
	
	openaboutwindows = winlist("SweepControl*",";","WIN:64")
	if(itemsinlist(openaboutwindows)>0)
		for(ii=0;ii<itemsinlist(openaboutwindows);ii+=1)
			killwindow $stringfromlist(ii,openaboutwindows)	
		endfor
	endif
end
