#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Scan Controller routines for 1d and 2d scans
// Version 1.7 June 14, 2016
// Author: Mohammad Samani, Nik Hartman & Christian Olsen
// Email: m@msamani.ca

function InitScanController()
	nvar filenum
	// These arrays should have the same size. Their indeces correspond to each other.
	make/t/o sc_RawWaveNames = {"g1x", "g1y","g2x", "g2y","g3x", "g3y","Tmc","T4K","T50K","Tmagnet"} // Wave names to be created and saved
	make/o sc_RawRecord = {0,0,0,0,0,0,0,0,0,0} // Whether you want to record and save the data for this wave
	make/o sc_RawPlot = {0,0,0,0,0,0,0,0,0,0} // Whether you want to record and save the data for this wave
	make/t/o sc_RequestScripts = {"", "", "", "","","","","","",""}
	make/t/o sc_GetResponseScripts = {"getg1x()", "getg1y()","getg2x()", "getg2y()","getg3x()", "getg3y()","GeTemp(\"mc\")","GetTemp(\"4k\")","GetTemp(\"50k\")","GetTemp(\"magnet\")"}
	// End of same-size waves
	
	// And these waves should be the same size too
	make/t/o sc_CalcWaveNames = {"", "", "", ""} // Calculated wave names
	make/t/o sc_CalcScripts = {"","","",""} // Scripts to calculate stuff
	//"getsrsstatus(srs1,"1"); getsrsstatus(srs2,"2"); getsrsstatus(srs3,"3");getsrsstatus(srs4,"4");
	make/o sc_CalcRecord = {0,0,0,0} // Include this calculated field or not
	make/o sc_CalcPlot = {0,0,0,0} // Include this calculated field or not
	// end of same-size waves
	
	// logging string
	string /g sc_LogStr = "GetSRSStatus(srs1);GetSRSStatus(srs2);GetSRSStatus(srs3);GetIPSStatus();GetDACStatus();"
	
	variable /g sc_AbortSave = 0

	if (numtype(filenum) == 2)
		print "Initializing FileNum to 1 since it didn't exist before."
		variable /g filenum=1
	endif

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
			cmd = "CheckBox sc_RawRecordCheckBox" + num2str(i) + " value=" + num2str(ison)
			execute(cmd)
			done=1
		endif
		i+=1
	while (i<numpnts( sc_RawWaveNames ) && !done)

	i=0
	do
		if (stringmatch(sc_CalcWaveNames[i], wn))
			sc_CalcRecord[i]=ison
			cmd = "CheckBox sc_CalcRecordCheckBox" + num2str(i) + " value=" + num2str(ison)
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
		print "sc_RawWaveNames and sc_RawRecord and sc_RequestScripts and sc_GetResponseScripts waves should have the number of elements. Go to the beginning of InitScanController() to fix this."
		abort
	endif

	if (numpnts(sc_CalcWaveNames) != numpnts(sc_CalcRecord) ||  numpnts(sc_CalcWaveNames) != numpnts(sc_CalcScripts)) 
		print "sc_RawWaveNames and sc_DeviceRecord waves should have the number of elements. Go to the beginning of InitScanController() to fix this."
		abort
	endif

	PauseUpdate; Silent 1		// building window...
	dowindow /K ScanController
	NewPanel /W=(10,10,sc_InnerBoxW + 30,130+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+1)*(sc_InnerBoxH+sc_InnerBoxSpacing) ) /N=ScanController
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
		cmd="SetVariable sc_RawWaveNameBox" + num2str(i) + " pos={13, 37+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={110, 0}, fsize=14, title=\" \", value=sc_RawWaveNames[i]"
		execute(cmd)
		cmd="CheckBox sc_RawRecordCheckBox" + num2str(i) + ", proc=sc_CheckBoxClicked, pos={150,40+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_RawRecord[i]) + " , title=\"\""
		execute(cmd)
		cmd="CheckBox sc_RawPlotCheckBox" + num2str(i) + ", proc=sc_CheckBoxClicked, pos={210,40+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_RawPlot[i]) + " , title=\"\""
		execute(cmd)
		cmd="SetVariable sc_RequestScriptBox" + num2str(i) + " pos={250, 37+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={200, 0}, fsize=14, title=\" \", value=sc_RequestScripts[i]"
		execute(cmd)
		cmd="SetVariable sc_GetResponseScriptBox" + num2str(i) + " pos={460, 37+sc_InnerBoxSpacing+i*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={200, 0}, fsize=14, title=\" \", value=sc_GetResponseScripts[i]"
		execute(cmd)		
		i+=1
	while (i<numpnts( sc_RawWaveNames ))
	i+=1
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 13,i*(sc_InnerBoxH + sc_InnerBoxSpacing)+25,"Wave Name"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 130,i*(sc_InnerBoxH + sc_InnerBoxSpacing)+25,"Record"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 200,i*(sc_InnerBoxH + sc_InnerBoxSpacing)+25,"Plot"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 250,i*(sc_InnerBoxH + sc_InnerBoxSpacing)+25,"Calculation Script ( example: dmm[i]*12.5)"

	i=0
	do
		DrawRect 9,60+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing),5+sc_InnerBoxW,60+sc_InnerBoxH+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)
		cmd="SetVariable sc_CalcWaveNameBox" + num2str(i) + " pos={13, 67+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={110, 0}, fsize=14, title=\" \", value=sc_CalcWaveNames[i]"
		execute(cmd)		
		cmd="CheckBox sc_CalcRecordCheckBox" + num2str(i) + ", proc=sc_CheckBoxClicked, pos={150,70+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_CalcRecord[i]) + " , title=\"\""
		execute(cmd)
		cmd="CheckBox sc_CalcPlotCheckBox" + num2str(i) + ", proc=sc_CheckBoxClicked, pos={210,70+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, value=" + num2str(sc_CalcPlot[i]) + " , title=\"\""
		execute(cmd)
		cmd="SetVariable sc_CalcScriptBox" + num2str(i) + " pos={250, 67+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames )+i)*(sc_InnerBoxH+sc_InnerBoxSpacing)}, size={410, 0}, fsize=14, title=\" \", value=sc_CalcScripts[i]"
		execute(cmd)		
		i+=1
	while (i<numpnts( sc_CalcWaveNames ))	
	
	// box for logging functions
	variable sc_Loggable
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 13,60+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+25,"Logging Functions (example: getSRSstatus(srs1); getIPSstatus();)"
	DrawRect 9,60+5+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+25,5+sc_InnerBoxW,60+5+sc_InnerBoxH+sc_InnerBoxSpacing+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+25
	cmd="SetVariable sc_LogStr pos={13, 67+5+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames))*(sc_InnerBoxH+sc_InnerBoxSpacing)+25}, size={sc_InnerBoxW-12, 0}, fsize=14, title=\" \", value=sc_LogStr"
	execute(cmd)
	
	//Button BtnAbortSave, mode=2, pos={sc_InnerBoxW/2 - 150,},size={300,50},fsize=16,title="Abort Current Scan & Save Data", proc=sc_AbortSaveClicked
	//SetDrawEnv fsize= 14
	
	// helpful text
	DrawText 13,120+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+1)*(sc_InnerBoxH+sc_InnerBoxSpacing),"Press TAB to save changes."
	DrawText 13,140+(numpnts( sc_RawWaveNames ) + numpnts(sc_CalcWaveNames)+1)*(sc_InnerBoxH+sc_InnerBoxSpacing),"Press ESC to abort the scan and save data, while this window is active, "
EndMacro

// When a check-box is clicked, which means its value has probably changed, all I do is update the contents of the sc_DeviceRecord wave corresonding to that check-box.
function sc_CheckboxClicked(ControlName, Value)
	string ControlName
	variable value
	string indexstring
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	variable index
	String expr
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
	endif
end



function InitializeWaves(start, fin, numpts, [starty, finy, numptsy, x_label, y_label])
	variable start, fin, numpts, starty, finy, numptsy
	string x_label, y_label
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	wave /T sc_RawWaveNames, sc_CalcWaveNames
	variable i=0, j=0
	string cmd = "", wn = "", wn2d="", s
	string /g sc_x_label, sc_y_label
	variable /g sc_is2d, sc_scanstarttime = datetime
	variable /g sc_startx, sc_finx, sc_numptsx, sc_starty, sc_finy, sc_numptsy
	string graphlist, graphname, plottitle, graphtitle="", graphnumlist="", graphnum, activegraphs="", cmd1=""
	variable index, graphopen, graphopen2d
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
	// TODO Make sure data exists as a path
	
	
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
			cmd = "make /o/n=(" + num2str(sc_numptsx) + ") " + wn + "=NaN"
			execute(cmd)
			cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + wn
			execute(cmd)
			if(sc_is2d)
				// In case this is a 2D measurement
				wn2d = wn + "2d"
				cmd = "make /o/n=(" + num2str(sc_numptsx) + ", " + num2str(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd)
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
			cmd = "make /o/n=(" + num2str(sc_numptsx) + ") " + wn + "=NaN"
			execute(cmd)
			cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + wn
			execute(cmd)		
			if(sc_is2d)
				// In case this is a 2D measurement
				wn2d = wn + "2d"
				cmd = "make /o/n=(" + num2str(sc_numptsx) + ", " + num2str(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd)
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
				endif
				if(sc_is2d)
					if(stringmatch(wn+"2d",stringfromlist(j,graphtitle)))
						graphopen2d = 1
						activegraphs+= stringfromlist(j,graphnumlist)+";"
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
					colorscale /c/n=Grays /e/a=rc
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
					colorscale /c/n=Grays /e/a=rc
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
				endif
				if(sc_is2d)
					if(stringmatch(wn+"2d",stringfromlist(j,graphtitle)))
						graphopen2d = 1
						activegraphs+= stringfromlist(j,graphnumlist)+";"
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
					colorscale /c/n=Grays /e/a=rc
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
					colorscale /c/n=Grays /e/a=rc
					Label left, sc_y_label
					Label bottom, sc_x_label
					activegraphs+= winname(0,1)+";"
				endif
			endif
		endif
		i+= 1
	while(i<numpnts(sc_CalcWaveNames))
	
	cmd1 = "TileWindows/O=1/A=(3,4) "
	// Tile graphs
	for(i=0;i<itemsinlist(activegraphs);i=i+1)
		cmd1+= stringfromlist(i,activegraphs)+","
	endfor
	execute(cmd1)
end
// In a 1d scan, i is the index of the loop. j will be ignored.
// In a 2d scan, i is the index of the outer (slow) loop, and j is the index of the inner (fast) loop. 
// In a 2D scan, if scandirection=1 (scan up), the 1d wave gets saved into the matrix when j=numptsy. If scandirection=-1(scan down), the 1d matrix gets saved when j=0. Default is 1 (up)
function RecordValues(i, j, [scandirection])
	variable i, j, scandirection
	nvar sc_is2d, sc_startx, sc_finx, sc_numptsx, sc_starty, sc_finy, sc_numptsy
	variable ii = 0, jj=0
	wave /t sc_RawWaveNames, sc_RequestScripts, sc_GetResponseScripts, sc_CalcWaveNames, sc_CalcScripts
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	string script = ""
	variable innerindex, outerindex
	
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
	
	// Send requests to machines
	do
		if (sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1)
			jj=0;
			script = sc_RequestScripts[ii];
			if (cmpstr(script, ""))
				execute(script)
			endif
		endif
		ii+=1
	while (ii < numpnts(sc_RawWaveNames))

	// Read responses from machines
	ii=0
	do
		if (sc_RawRecord[ii] == 1 || sc_RawPlot[ii] == 1)
			jj=0;
			script = sc_GetResponseScripts[ii];
			do
				if (jj < ItemsInList(script)-1)
					execute(StringFromList(jj, script))
				else
					execute(sc_RawWaveNames[ii] + "[" + num2str(innerindex) + "]=" + StringFromList(jj, script))
					if (sc_is2d)
						// 2D Wave
						// If this is the last point in a row on a 2d scan, save the row in the 2d wave
						if ((innerindex == sc_numptsx-1 && scandirection == 1) || (innerindex == 0 && scandirection == -1))
							execute(sc_RawWaveNames[ii] + "2d[][" + num2str(outerindex) + "] = " + sc_RawWaveNames[ii] + "[p]")
						endif
					endif
				endif
				jj+=1
			while (jj<ItemsInList(script))
		endif
		ii+=1
	while (ii < numpnts(sc_RawWaveNames))

	// Calculate interpreted numbers and store them in calculated waves
	ii=0
	do
		if (sc_CalcRecord[ii] == 1 || sc_CalcPlot[ii] == 1)
			jj=0;
			script = sc_CalcScripts[ii];
			// Allow the use of the keyword '[i]' in calculated fields where i is the inner loop's current index
			script = ReplaceString("[i]", script, "["+num2str(innerindex)+"]")
			do
				// If multiple commands are present, assign the value returned by the last command to the corresponding wave
				if (jj < ItemsInList(script)-1)
					execute(StringFromList(jj, script))
				else
					execute(sc_CalcWaveNames[ii] + "[" + num2str(innerindex) + "]=" + StringFromList(jj, script))
					if (sc_is2d)
						// 2D Wave						
						// If this is the last point in a row on a 2d scan, save the row in the 2d wave
						if ((innerindex == sc_numptsx-1 && scandirection == 1) || (innerindex == 0 && scandirection == -1))
							execute(sc_CalcWaveNames[ii] + "2d[][" + num2str(outerindex) + "] = " + sc_CalcWaveNames[ii] + "[p]")
						endif												
					endif
				endif
				jj+=1
			while (jj<ItemsInList(script))
		endif
		ii+=1
	while (ii < numpnts(sc_CalcWaveNames))
	doupdate
	
	if (GetKeyState(0) & 32)
		// If the ESC button is pressed during the scan, save existing data and stop the scan.
		SaveWaves(msg="The scan was aborted during the execution.")
		abort
	endif
end

// the message will be printed in the history, and will be saved in the winf file corresponding to this scan
function SaveWaves([msg])
	string msg
	nvar sc_is2d
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
			print filename
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
			print filename
			Save/C/P=data $filename;
			SaveInitialWaveComments(wn, x_label=sc_x_label, y_label=sc_y_label)
		endif
		ii+=1
	while (ii < numpnts(sc_CalcWaveNames))
	
	if(Rawadd+Calcadd > 0)
		// Save WINF for this sweep
		saveScanComments(msg=msg, logs=logs)
		filenum+=1
	endif
	SaveExperiment/p=data
end