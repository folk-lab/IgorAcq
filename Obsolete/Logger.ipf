#pragma rtGlobals=1		// Use modern global access method.

/////////////////////////////////////// Experimental conditions data logger ///////////////////////////////////
// Mark Lundeberg, 2011 May 4

// Purpose: Log the IGH's status as a function of time.
//      - keeps an Igor record.
//      - keeps a file record (in case power goes out for example).
//      - allows old file records to be viewed easily.
//      - uploads screenshots of the kelvinox panel to website.
//
// Primary Usage:
//      • loggerinit()
//         - use before any of the following commands.
//
//      • logger()
//         - call this command frequently at the end of scans.
//         - if it has already logged within the last 120s, it will do nothing.
//                        Instantly returns 0 if logging didn't happen.
//         - if it has been longer, logging will occur.
//				This takes about 0.5 seconds, and returns 1.
//                        Historical results are saved in two waves: loggerhistory and loggertime.
//                        Most recent log stored in wave LoggerStatus.
//         - uploads of the screenshots will only occur every 15 minutes, at most.
//		    		This takes an extra 0.3 seconds (total 0.8 seconds).
//         - this command will fail silently if errors are encountered, allowing your experiment to keep going.
// 
//      • display loggerhistory[*][%temp_mix] vs loggertime
//         - displays a graph of the history of the "temp_mix" column versus time.
//         - %temp_mix could be replaced by %pres_G1, or %temp_1K equally well. these labels
//            can be seen in the headings of the loggertable() output.
//
// Misc commands
//      • loggertable()
//         - displays a table with the logged data.
//      • loggerclear()
//         - clear old logs out of igor's memory
//                 -the log files will still be kept and you can reload them with loggerload()
//      • loggerloop()
//         - continuously calls logger(). use to monitor the fridge when not taking data.
//      • loggerload()
//         - load up old saved logs and merge them into the logger's history.
//         - will use dialog by default, unless you call loggerload("path\\to\\filename").
//
// History:
//   '11 Apr 21: Wrote basic version.
//   '11 Mar 3: Added control box for making graphs.

/// Commands to run immediately before logging:
macro loggerprecommands()
	if(datetime-kelvinoxdatetime > 2)
		// only run kelvinoxgetstatus if not called in the last 2 seconds.
		kelvinoxgetstatus();
		
	endif
	//variable /g level_Liquefier = nan
	//execute /q/z "level_Liquefier = readliquefierlevel()"
//	execute /q/z "adjustNV()"
//execute /q/z "AdjustNVNelson()"
end

/// initialize or reset logger. Config options located here.
function initlogger()
	// variables that hold the last time the logger was executed (to prevent too-frequent logging).
	variable /g loggerlasttime = 0
	variable /g loggeruploadlasttime = 0
	// Wait at least 120s between logs (unless forcelog = 1)
	/// 120 seconds: savefile uses ~135 characters per line meaning ~35 MB per year.
	variable /g loggerperiod = 120 // s
	// Wait at least 900s between screenshots.
	variable /g loggeruploadperiod = 900 // s
	string /g loggerlogdir = "C:\\Users\\Lab User\\Desktop\\Local Measurement Data\\Fridge\\"
	string /g loggerscreenshotscript = "\"C:\\Users\\Lab User\\Desktop\\Local Measurement Programs\\Screencap\\igorcapture.bat\""
	variable /g loggergraphtime=120
	variable /g loggergraphtimeenable=0
	variable /g loggersecondenable=0
	loggerclear()
	dowindow /k loggercontrol
	execute "LoggerControl()"
end

// clear logger history.
function loggerclear()
	make /t/o/n=38 LoggerLabels
	LoggerLabels[0]= {"valve_V1","valve_V2","valve_V3","valve_V4","valve_V5","valve_V6","valve_V7","valve_V8","valve_V9","valve_V10","valve_V11a","valve_V11b","valve_V12a","valve_V12b","valve_V13a","valve_V13b"}
	LoggerLabels[16]= {"valve_V14","valve_NV","valve_V1A","valve_V2A","valve_V4A","valve_V5A","Pump_He4","Pump_He3","Pump_Roots","Pres_G1","Pres_G2","Pres_G3","Pres_P1","Pres_P2","Level_He","level_N2","level_Liquefier"}
	LoggerLabels[33]= {"Temp_mix","temp_sorb","temp_1k","power_mix","power_still","power_sorb"}
	make /o LoggerPrecision =  {0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,1,1,1,3,3,1,1,1,1,1,3,3,1,1}
	
	make /d/o/n=(0,numpnts(LoggerLabels)) LoggerHistory
	variable i = 0
	do
		setdimlabel 1, i, $(loggerlabels[i]), loggerhistory
		i+=1
	while(i<numpnts(LoggerLabels))
	make /d/o/n=(0) LoggerTime
	setscale d, 0, 0, "dat", loggertime	
end

// logging function
function logger([forcelog])
	variable forcelog
	
	nvar loggerperiod
	nvar loggerlasttime
	if(forcelog)
		loggerlasttime = 0
	endif
	
	if(datetime - loggerlasttime < loggerperiod)
		return 0
	endif
	loggerlasttime = datetime
	
	
	////// RUN LOGGING DATA COLLECTION HERE.
	execute /z "loggerprecommands()"
	
	
	///// CAPTURE LOGGING DATA TO WAVE HERE.
	variable now = datetime
	wave /t LoggerLabels
	wave LoggerPrecision
	make /d/o/n=(numpnts(loggerlabels)) LoggerStatus
	variable i=0
	do
		execute /q/z "loggerstatus["+num2str(i)+"] = "+LoggerLabels[i]
		i+=1
	while(i < numpnts(loggerlabels))
	
	wave loggerhistory, loggertime
	variable histidx = dimsize(loggerhistory,0)
	redimension /n=(histidx+1,numpnts(loggerlabels)), loggerhistory
	redimension /n=(histidx+1), loggertime
	loggerhistory[histidx][] = loggerstatus[q]
	loggertime[histidx] = now
	
	AdjustNV(P2low =4, P2high = 5, period = 30)


	/////// LOG FILE SAVING /////
	// Attempt to open status file.
	svar loggerlogdir
	variable fref
	string fname = loggerlogdir
	fname += Secs2Date(now,-2,".")+".txt"
	do
		open /r/z fref as fname  /// attempt to open for reading to check if the file exists.
		if(v_flag)
			// Today's file doesn't exist? Then let's create it.
			open /z fref as fname
			if(v_flag)
				print "Error: Logger could not create today's log file",fname
				break
			endif
			print "========================== ", date(), " ========================="
			print "Creating log file",fname
			fprintf fref, "Time"
			i = 0
			do
				fprintf fref, "\t%s",LoggerLabels[i]
				i+=1
			while(i < numpnts(loggerlabels))
			fprintf fref, "\r\n"
		else
			/// Great, the file exists, let's reopen it as append
			close fref
			open /a/z fref as fname
			if(v_flag)
				print "Error: Logger could not open today's log file",fname
				break
			endif
		endif	
		//// Save status to file
		fprintf fref, "%.0f",now
		i = 0
		do
			fprintf fref, "\t%."+num2str(loggerprecision[i])+"f",LoggerStatus[i]
			i+=1
		while(i < numpnts(loggerstatus))
		fprintf fref, "\r\n"
		close fref
	while(0)

	/// SCREENSHOT UPLOADER
	nvar loggeruploadperiod
	nvar loggeruploadlasttime
	svar loggerscreenshotscript
	dowindow Kelvinox
	if(v_flag && (datetime-loggeruploadlasttime > loggeruploadperiod)) // kelvinox window exists & time to cap
		dowindow /f Kelvinox	// bring panel to front
		doupdate
		executescripttext /b/z loggerscreenshotscript
		sleep /s .1 // wait for snapshot to occur
		dowindow /b Kelvinox	// send panel to back.
		loggeruploadlasttime = datetime
	endif
	
	return 1
end

// display a table
function loggertable()
	wave LoggerHistory, LoggerTime
	dowindow /K LoggerTableWin
	edit /k=1/n=LoggerTableWin LoggerTime, LoggerHistory
	modifytable horizontalindex = 2
	ModifyTable format(LoggerTime)=8
	modifytable width(loggertime)=95
	modifytable width(loggerhistory)=50
end

// continually loop while attempting to log
function loggerloop()
	do
		if (logger())
			AdjustNV(P2low = 3.8, P2high = 4.5, period = 30)
			dowindow /f kelvinox
		endif
//		adjustnv()
		doupdate
		sleep /s 1
	while(1)
end

function loggerwait(secs)
	variable secs
	variable until = datetime + secs
	do
		logger()
		sleep /s 0.1
	while(datetime < until)
end

///// Loads old log files and merges into history data.
// The merge is smart:
//    -overwrites log entries in preexisting history with same time value
//    -recognizes column labels and maps them into the existing log.
function loggerload([filename])
	string filename
	if(paramisdefault(filename))
		filename = ""
	endif
	loadwave /q/o/d/j/m/n=loggerload/U={0,2,1,0} filename
	if(v_flag == 0)
		// cancelled.
		return 0
	endif
	wave loggerload0, rp_loggerload0
	/// loggerload0 contains column labels
	/// RP_loggerload0 contains the datetime values.
	setscale d, 0, 0, "dat", rp_loggerload0
	
	
	/// example table
//	dowindow /K LoggerLoadWin
//	edit /k=1/n=LoggerLoadWin rp_loggerload0, loggerload0
//	modifytable horizontalindex = 2
//	ModifyTable format(RP_loggerload0)=8
	
	/// example graph
	//display loggerload0[*][%temp_1k] vs rp_loggerload0
	
	wave LoggerHistory, LoggerTime
	concatenate /np/o {LoggerTime, RP_loggerload0}, loggerload_tmptime
	duplicate /o loggerload_tmptime loggerload_tmpidx
	loggerload_tmpidx = p
	sort loggerload_tmptime, loggerload_tmptime, loggerload_tmpidx
	variable i = 0
	variable colls = 0
	do
		if(loggerload_tmptime[i] == loggerload_tmptime[i+1])
			//print "Collision: ",i, loggerload_tmptime[i], loggerload_tmpidx[i], loggerload_tmpidx[i+1]
			// time collision. delete the value with lower index (keeps the just-loaded value)
			if(loggerload_tmpidx[i] > loggerload_tmpidx[i+1])
				deletepoints i+1,1,loggerload_tmpidx, loggerload_tmptime
			else
				deletepoints i,1,loggerload_tmpidx, loggerload_tmptime
			endif
			colls += 1
		else
			// no collision.. move on.
			i += 1
		endif
	while(i < numpnts(loggerload_tmptime) - 1)
	
	wave /t loggerlabels
	duplicate /o LoggerHistory LoggerHistoryold
	redimension /n=(numpnts(loggerload_tmpidx),dimsize(loggerhistory,1)) LoggerHistory
	variable oldlen = dimsize(LoggerHistoryold,0)
	variable idx
	i = 0
	loggerhistory = nan
	do
		idx = loggerload_tmpidx[i]
		if(idx < oldlen)
			LoggerHistory[i][] = LoggerHistoryold[idx][q]
		else
			LoggerHistory[i][] = loggerload0[idx-oldlen][%$(loggerlabels[q])]
		endif
		i+=1
	while(i < dimsize(LoggerHistory,0))
	
	duplicate /o LoggerLoad_tmptime LoggerTime
	
	print "Merged",dimsize(loggerload0,0),"records from",s_filename,", overwrote",colls,"records."
	killwaves /z loggerload_tmpidx, LoggerLoad_tmptime, LoggerHistoryold, loggerload0, rp_loggerload0
end

Function LoggerCheckSecond(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			if(checked)
				ListBox list1 disable=0
				Button button1 disable=0
			else
				ListBox list1 disable=1
				Button button1 disable=1
			endif
			break
	endswitch

	return 0
End

Function LoggerButtonVsTime(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	wave loggerhistory, loggertime
	wave /t loggerlabels
	nvar loggergraphtime, loggergraphtimeenable
	nvar loggersecondenable
	
	string cmd, title, winn

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			winn = uniquename("LoggerGraph", 6, 0)
			title = winn+": "
			Controlinfo /w=loggercontrol List0
			cmd = "display /k=1 /n="+winn+" loggerhistory[*][%"+loggerlabels[v_value]+"] vs loggertime"
			title += loggerlabels[v_value]
			execute cmd
			doupdate
			ModifyGraph rgb=(0,0,0)
			Label left "\\s(LoggerHistory)"+loggerlabels[v_value]
			Controlinfo /w=loggercontrol List1
			SetAxis/A=2 left
			if(loggersecondenable && V_Value >= 0)
				cmd = "append /r loggerhistory[*][%"+loggerlabels[v_value]+"] vs loggertime"
				execute cmd
				Label right "\\s(LoggerHistory#1)"+loggerlabels[v_value]
				title += " and "+loggerlabels[v_value]
				SetAxis/A=2 right
			endif
			ModifyGraph mode=3,msize=1
			if(loggergraphtimeenable)
				SetAxis bottom datetime-loggergraphtime*60,*
			endif
			Label bottom " "
			ModifyGraph margin(bottom)=25
			ModifyGraph fSize=7
			ModifyGraph btLen=3,btThick=0.5,stLen=1;ModifyGraph stThick=0.5
			ModifyGraph dateInfo(bottom)={0,1,-1}
			ModifyGraph dateFormat(bottom)={Default,2,1,1,1,"DayOfWeek Year.Month.DayOfMonth",-1}
			ModifyGraph minor=1
			ModifyGraph grid=2, gridStyle=3, gridRGB=(50000,50000,50000)
			ModifyGraph nticks=10
			dowindow /t $(winn), title
			break
	endswitch

	return 0
End

Function LoggerButtonVs12(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	wave loggerhistory, loggertime
	wave /t loggerlabels
	nvar loggergraphtime, loggergraphtimeenable
	nvar loggersecondenable
	
	string cmd, title, winn, range

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			winn = uniquename("LoggerGraph", 6, 0)
			title = winn+": "
			Controlinfo /w=loggercontrol List0
			variable v0 = v_value
			Controlinfo /w=loggercontrol List1
			variable v1 = v_value
			title += loggerlabels[v0] + " vs " + loggerlabels[v1]
			if(loggergraphtimeenable)
				findlevel /q/p loggertime, datetime-loggergraphtime*60
				if(numtype(v_levelx))
					range = "*"
				else
					range = num2str(ceil(v_levelx))+","
				endif
			else
				range = "*"
			endif
			cmd = "display /k=1 /n="+winn+" loggerhistory["+range+"][%"+loggerlabels[v0]+"]"
			cmd += " vs loggerhistory["+range+"][%"+loggerlabels[v1]+"]"
			execute cmd
			ModifyGraph rgb=(0,0,0)
			Label left loggerlabels[v0]
			Label bottom loggerlabels[v1]
			ModifyGraph mode=4,msize=1
			ModifyGraph fSize=7
			ModifyGraph btLen=3,btThick=0.5,stLen=1;ModifyGraph stThick=0.5
			dowindow /t $(winn), title
			execute "ModifyGraph zColor(LoggerHistory)={LoggerTime["+range+"],*,*,Rainbow,0}"
			break
	endswitch

	return 0
End

Function LoggerCheckStarting(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			if(checked)
				SetVariable setvar0 disable=0
			else
				SetVariable setvar0 disable=2
			endif
			break
	endswitch

	return 0
End

Window LoggerControl() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(1062,37,1256,422)
	SetDrawLayer UserBack
	DrawRect 2,44,191,382
	DrawText 101,377,"minutes ago"
	ListBox list0,pos={8,84},size={89,215},frame=2,listWave=root:LoggerLabels
	ListBox list0,row= 23,mode= 2,selRow= 34
	ListBox list1,pos={98,84},size={89,215},disable=1,frame=2
	ListBox list1,listWave=root:LoggerLabels,row= 21,mode= 2,selRow= 30
	CheckBox check0,pos={102,64},size={79,19},proc=LoggerCheckSecond,title="2\\Snd\\M variable"
	CheckBox check0,variable= loggersecondenable
	TitleBox title0,pos={20,65},size={59,19},title="1\\Sst\\M variable",frame=0
	Button button0,pos={23,301},size={50,36},proc=LoggerButtonVsTime,title="Display\rvs time"
	Button button1,pos={111,300},size={54,36},disable=1,proc=LoggerButtonVs12,title="Display\rV2 vs V1"
	SetVariable setvar0,pos={49,361},size={50,18},disable=2,title=" "
	SetVariable setvar0,value= loggergraphtime
	CheckBox check1,pos={13,344},size={97,15},proc=LoggerCheckStarting,title="Starting from..."
	CheckBox check1,variable= loggergraphtimeenable
	Button button2,pos={59,2},size={50,20},proc=LoggerButtonClear,title="Clear"
	Button button3,pos={9,2},size={50,20},proc=LoggerButtonLoad,title="Load..."
	Button button4,pos={121,20},size={70,20},proc=LoggerButtonLoop,title="Loop log"
	Button button5,pos={121,1},size={70,20},proc=LoggerButtonSingle,title="Single log"
	TitleBox title1,pos={10,39},size={93,24},title="Make graphs"
	TitleBox title1,labelBack=(65535,65535,65535),fSize=14,frame=2,fStyle=3
EndMacro

Function LoggerButtonClear(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			loggerclear()
			// click code here
			break
	endswitch

	return 0
End

Function LoggerButtonLoad(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			loggerload()
			// click code here
			break
	endswitch

	return 0
End

Function LoggerButtonLoop(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			loggerloop()
			// click code here
			break
	endswitch

	return 0
End

Function LoggerButtonSingle(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			logger(forcelog=1)
			// click code here
			break
	endswitch

	return 0
End
