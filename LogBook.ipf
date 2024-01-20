// LogBook
// Jeffrey J Weimer

#pragma rtGlobals=3
#pragma IgorVersion=8.00
#pragma version = 3.11

// for Project Updater
Static Constant kProjectID=2352
Static Strconstant ksShortTitle="LogBook"

#pragma IndependentModule=LogBook

// last modified 2023-05-17
// expands and solidifies use of markdown
// last modified: 2023-04-23
// bug fixes: now properly selects HERE location
// improvements: blank comments not giving extra return line
// improvements: now compatible with Project Updater
// features: now uses markdown for headers and subheaders
// features: now uses markdown tags for #date and #time stamps
// changes: in notebook, headers are bold and subheaders normal
// changes: depreciating use of Package Tools (but keeping reference to Screen Sizer)

Static StrConstant thePackageFolder="root:Packages:LogBook"
Static Constant thePackageVersion = 3.11

// ****** DEPRECIATING
// TO REMOVE IN NEXT UPDATE
//Static StrConstant thePackage="LogBook"
//Static StrConstant theProcedureFile = "LogBook.ipf"
//Static StrConstant thePackageInfo = "A control panel to document the progress of an experiment in a notebook"
//Static StrConstant thePackageAuthor = "Jeffrey J Weimer"
//Static Constant hasHelp = 1
//Static Constant removable = 1

Static StrConstant kPanelName = "LogBookPanel"
Static StrConstant kPanelTitle = "LogBook Panel"

// panel width/height constants

Static Constant lbpwidth=270
Static Constant lbpheight=340

// TEST MODE (comment out for actual use)
//#define DEBUG

// Menu

Menu "Windows", hideable
	//Submenu "Packages"
		"LogBook Panel",/Q,ShowPanel()
	//end
End

// clear and reset panel cache settings when an experiment starts
Static Function AfterFileOpenHook(refNum,file,pathName,type,creator,kind)
	Variable refNum,kind
	String file,pathName,type,creator
	
	// only do when the package folder has been created
	if (!DataFolderExists(thePackageFolder))
		return 0
	endif
	
	DFREF pdf = $thePackageFolder
	DFREF gdf = pdf:PanelGlobals
	
	NVAR/SDFR=gdf hrefnum
	SVAR/SDFR=gdf history

	// reset the history
	
	if (NVAR_exists(hrefnum))
		hrefnum = nan
		history = ""
	endif
	
	// clear the history checkbox
	DoWindow/F $kPanelName
	if (V_flag)
		Checkbox tb0_cbhistory,  win=$kPanelName, value = 0
		Checkbox tb0_cbhistory0,  win=$kPanelName, disable = 2
		Checkbox tb0_cbhistory1,  win=$kPanelName, disable = 2
	endif
	return 0
end

// Setup Globals
Static Function SetupGlobals()
 	
	DFREF cdf = GetDataFolderDFR()
	
	// first time set up here
	
	if (!DataFolderExists(thePackageFolder))		
		SetDataFolder root:
		NewDataFolder/O/S Packages
		NewDataFolder/O/S LogBook
		NewDataFolder/O/S PanelGlobals
		variable/G template=1, graphic=1, notebk=1
		variable/G frame=0, size=100, omode=1
		variable/G xsize=0, ysize=0, hrefnum=nan, odynamic=1, ndynamic=1
		string/G recentdate=""
		string/G title="Observation", graphicname="",notes="", history=""
		SetDataFolder cdf
	endif
	
	return 0
end

// Update Panel
// existing = 0 -> show new panel
// existing = 1 -> update existing panel
Static Function UpdatePanel(existing)
	variable existing
	
	DFREF pdf = $thePackageFolder
	DFREF gdf = pdf:PanelGlobals
	
	NVAR/SDFR=gdf hrefnum
	SVAR/SDFR=gdf history
	
	switch(existing)
		case 0:
			// handle case where panel was closed while capture history still active
			if (numtype(hrefnum)!=2)
				history = CaptureHistory(hrefnum,1)
				hrefnum = nan
				history = ""
			endif
			return 0
		default:
			// possibly update to newer version here
			return 0
	endswitch
end

// ****** DEPRECIATING
// TO REMOVE IN NEXT UPDATE
//// Initialize
//// called when the panel has never been set up for this experiment
//Static Function Initialize()
//	
//	string theCmd
//	sprintf theCmd, "ProcGlobal#PackageExists(\"%s\")", thePackage
//	Execute/Q/Z theCmd
//	NVAR V_exists
//	if (NVAR_exists(V_exists))
//		sprintf theCmd,"\"%s\"", thePackage
//		sprintf theCmd, "%s,folder=\"%s\"", theCmd, thePackageFolder
//		sprintf theCmd, "%s,file=\"%s\"", theCmd, theProcedureFile
//		sprintf theCmd, "%s,info=\"%s\"", theCmd, thePackageInfo
//		sprintf theCmd "%s,author=\"%s\"", theCmd, thePackageAuthor
//		sprintf theCmd, "%s,version=%f", theCmd, thePackageVersion
//		sprintf theCmd, "%s,hasHelp=%d", theCmd, hasHelp
//		sprintf theCmd, "%s,removable=%d", theCmd, removable
//		switch(V_exists)
//			case 0:
//				sprintf theCmd, "ProcGlobal#PackageSetup(%s)", theCmd
//				break
//			case 1:
//				sprintf theCmd, "ProcGlobal#PackageUpdate(%s)", theCmd
//				break
//		endswitch
//		Execute/Q/Z theCmd
//	endif
//	return 0
//end

// Show Panel
// menu entry point to panel
Function ShowPanel()

	string theCmd

	// bring panel to front if it exists
	// update if needed

	if (WinType(kPanelName)==7)
		if (UpdatePanel(1)==1)
			KillWindow $kPanelName
//			ShowPanel()
		else
			DoWindow/F $kPanelName
			return 0
		endif
	endif
	
	// create the package and panel // and initialize it via package tools
	
	SetUpGlobals()
	UpdatePanel(0)
// ****** DEPRECIATING
// TO REMOVE IN NEXT UPDATE
//	Initialize()

	// put up the panel
	
	//variable offset
	string ptitle = kPanelTitle
	
	// use screen sizer when present
//	if(Exists("ProcGlobal#ScreenSizer#Initialize")==6)
//		theCmd = "ProcGlobal#ScreenSizer#Initialize(0)"
//		Execute/Q/Z theCmd
//		sprintf theCmd, "ProcGlobal#ScreenSizer#MakePanel(70,10,%d,%d,\"%s\",other=\"/N=$kPanelName/K=1\")", lbpwidth, lbpheight, ptitle
//		Execute/Q/Z theCmd
//	else
		NewPanel/W=(20,80,20+lbpwidth,80+lbpheight)/N=$kPanelName/K=1 as ptitle
//	endif

	// edit mode or not
#ifndef DEBUG
	ModifyPanel/W=$kPanelName noEdit=1, fixedSize=1
#endif

	// panel controls
	
	PutMainControls()
	PutGeneralControls()

	// panel hook function
	SetWindow $kPanelName hook(LogBook)=panelhook
	
	// reset history record	
	StartStopHistory(0)
	
	return 0
	
end

// put controls on panel
Static Function PutMainControls()
	
	DFREF pdf = $thePackageFolder
	DFREF gdf = pdf:PanelGlobals
	
	NVAR/SDFR=gdf template, graphic, frame, size, xsize, ysize, omode, notebk, odynamic,ndynamic
	SVAR/SDFR=gdf title, graphicname, notes
	
	string tstr
	
	variable toffset = 10
	
	// which notebook
		
	CheckBox tb0_cbndynamic title="!",pos={lbpwidth-25,toffset}, variable=ndynamic, fSize=10
	CheckBox tb0_cbndynamic help={"Set the notebook capture name dynamically as the most recent front-most notebook."}
			
	PopupMenu tb0_notebook,pos={10,toffset},size={165,21},bodywidth=0
	PopupMenu tb0_notebook,mode=notebk,value= #"LogBook#NList()",title="To Notebook", fSize=12, proc=setpopups
	PopupMenu tb0_notebook,help={"Choose which notebook is used to log the figure(s) + notes."}
	
	// new page setting
	
	toffset += 25
	
	PopupMenu popup_startpage,title="Paginate",pos={5,toffset},size={180,20},bodyWidth=120,value="None;Horizontal Line;New Page;",fSize=12
	PopupMenu popup_startpage,help={"Define the page break input before the notes are added to the notebook."}

	//CheckBox tb0_newpage,pos={5,toffset},size={46,20},title="Start a New Page", value=0, fSize=12, font="Arial"
	
	// title block
	
	toffset += 25

	CheckBox tb0_cbtitle,pos={5,toffset},size={46,20},title="Title", value=1, fSize=12, proc=setcheckboxes
	CheckBox tb0_cbtitle,help={"Check to include a title for the notes."}
	SetVariable tb0_title,pos={50,toffset},size={lbpwidth-95,20},value=title, title=" ", fSize=12
	SetVariable tb0_title,help={"Insert a title here."}, proc=setvariables

	// notes block
	
	toffset += 25

	NewNotebook/F=1/N=notefield/W=(6,toffset,lbpwidth-10,toffset+80)/HOST=#/OPTS=(2)
	Notebook $(kPanelName)#notefield, statusWidth=0, autoSave=0, fSize=14, fStyle=0, textRGB=(0,0,0)
	
	toffset += 80

	CheckBox tb0_notefuncs,pos={10,toffset},size={42,14},title="functions in comments",value=0, fSize=10
	CheckBox tb0_notefuncs,help={"Check this box to allow function inputs in comment field. Enter functions with % or # prefix."}
	Button tb0_clearnotes,pos={lbpwidth-100,toffset},size={20,20}, title="", picture=LogBook#Eraser, proc=setbuttons
	Button tb0_clearnotes,help={"Clear the comment field."}, disable=2
	CheckBox tb0_autoclear,pos={lbpwidth-70,toffset},size={42,14},title="auto clear",value=1, fSize=10, proc=setcheckboxes
	CheckBox tb0_autoclear,help={"Auto-clear the comment field each time Shift+Return is entered."}

	// graphic block
	
	toffset += 25

	odynamic = GraphicCheckBoxes(StringFromList(0,OList()))
			
	CheckBox tb0_cbodynamic title="!",pos={lbpwidth-25,toffset}, variable=odynamic, fSize=10, font="Arial", proc=setcheckboxes, value=0
	CheckBox tb0_cbodynamic, help={"Check this box to have the panel dynamically sense\rwhich graphic window has just been front-most."}

	PopupMenu tb0_graphic,pos={10,toffset},size={170,21},fsize=12,title="Graphic",proc=setpopups
	PopupMenu tb0_graphic,mode=1,value= #"LogBook#OList()"
	PopupMenu tb0_graphic,help={"This is a selection list of graph, tables, layout, and panel windows.\rWhen more than one is available and ALL is chosen, checkboxes will allow further selection."}

	Checkbox tb0_cbpanels, title="P", pos={125,toffset}, fSize=10, font="Arial", value=1, disable=1
	Checkbox tb0_cbpanels, help={"include all panel windows"}
	Checkbox tb0_cbtables, title="T", pos={155,toffset}, fSize=10, font="Arial", value=1, disable=1
	Checkbox tb0_cbtables, help={"include all table window"}
	Checkbox tb0_cbgraphs, title="G", pos={185,toffset}, fSize=10, font="Arial", value=1, disable=1
	Checkbox tb0_cbgraphs, help={"include all graph window"}
	Checkbox tb0_cblayouts, title="L", pos={215,toffset}, fSize=10, font="Arial", value=1, disable=1
	Checkbox tb0_cblayouts, help={"include all layout windows"}
	
	toffset += 20
	
	Slider tb0_scale,pos={20,toffset},size={150,45},limits={5,100,5},variable=size,vert= 0, proc=setsliders, disable=1
	Slider tb0_scale,help={"Define the image scale size."}

	Checkbox cb_bffs, title="Fullscale\r@ 8\"", pos={180,toffset}, fSize=10, font="Arial", value=0, disable=1
	Checkbox cb_bffs, help={"Images are scaled by presentation size. Check this to scale images by 8 inches fullscale."}
	
	toffset += 25

	ValDisplay tb0_showscale,pos={20,toffset},size={25,15}, value=#"root:Packages:LogBook:PanelGlobals:size", disable=1

	// history block
	
	toffset += 25

	CheckBox tb0_cbhistory,pos={10,toffset},size={40,20},title="History ", value=0, fSize=12, font="Arial", proc=setcheckboxes
	CheckBox tb0_cbhistory,help={"Record the history window to the notebook."}

	CheckBox tb0_cbhistory0,pos={80,toffset},size={46,20},title="... <+> ...", value=1, mode=1,fSize=12, font="Arial", disable=2, proc=setcheckboxes
	CheckBox tb0_cbhistory0,help={"Record the history in one shot. Starts at button on click and ends with a log event."}
	CheckBox tb0_cbhistory1,pos={160,toffset},size={46,20},title="<... + ...>", value=0, mode=1,fSize=12, font="Arial", disable=2, proc=setcheckboxes
	CheckBox tb0_cbhistory1,help={"Record the history continuously. Starts at button on click and ends at button off/checkbox disable click."}
	
	// data files
	
	toffset += 25
	
	CheckBox tb0_cbdbrecord,pos={10,toffset},size={46,22},title="Folder Dump", value=0, fSize=12, font="Arial", proc=setcheckboxes
	CheckBox tb0_cbdbrecord, help={"Check this to include a directory listing from the current directory."}
	PopupMenu tb0_lodf,pos={100,toffset-2},size={165,21},mode=1,value= #"LogBook#LoDF()",title="", disable=2
	PopupMenu tb0_lodf,help={"Choose which data folder to print a directory listing."}

	// save
		
	Button tb_saventbk,pos={10,lbpheight-30},size={105,20},title="Save Notebook", fSize=12, fStyle=1
	Button tb_saventbk, help={"Save the notebook as markdown."}, proc=setbuttons
	
	// send to notebook block

	PopupMenu tb0_location,pos={lbpwidth-135,lbpheight-30},size={152,25},title="@"
	PopupMenu tb0_location,mode=5,value="|<<;<;!;>;>>|;", fSize=12
	PopupMenu tb0_location,help={"Insert information at start, before current position, at current position, after current position, or at end of notebook."}
	
	Button tb_noteit,pos={lbpwidth-60,lbpheight-30},size={40,20},title="->",fColor=(16385,28398,65535)
	Button tb_noteit fSize=12,fStyle=1, proc=setbuttons
	Button tb_noteit, help={"Send the information to the notebook."}

	return 0
end

// Set General Controls
Static Function PutGeneralControls()

	string theStr
	
	sprintf theStr, "v %3.2f", thePackageVersion
	
	SetDrawEnv fsize= 9
	DrawText lbpwidth-35,12, theStr
	
// ****** DEPRECIATING
// TO REMOVE IN NEXT UPDATE
//	// only show when PackageTools is installed too
//	if (DataFolderExists("root:Packages:PackageTools"))		
//		Button tb_removeme, pos={15,lbpheight-30},size={20,20}, title="X", proc=RemoveMe
//		Button tb_help, pos={50,lbpheight-30},size={20,20}, title="?", proc=GetHelp
//	endif	
		
	return 0
end

// confirm if the graphics still exist
Static Function ValidGraphics()

	// do graphics windows still exist (may have been deleted)
	
	string mtxt
	
	mtxt = WinName(0,(1+2+4+64))
	if (cmpstr(mtxt,kPanelName) == 0)
		mtxt = WinName(1,(1+2+4+64))
	endif
	// no valid graphics windows exist?
	if (strlen(mtxt)==0)
		return 0
	else
		return (WhichListItem(mtxt,OList()) + 1)
	endif

end

// Panel Hook Function
// update automatic settings when the panel is selected
Function PanelHook(whs)
	STRUCT WMWinHookStruct &whs
	
	DFREF pdf = $thePackageFolder
	DFREF gdf = pdf:PanelGlobals

	NVAR/SDFR=gdf notebk, graphic, odynamic, ndynamic, hrefnum
	SVAR/SDFR=gdf graphicname
	
	string mtxt = ""
	variable et, rtnV = 0
	
	switch(whs.eventCode)
		case 0:	// activate
#ifdef DEBUG
				print "panel active ", ndynamic,  mtxt, odynamic, graphicname
#endif
			
			// dynamic notebook selection
			if (ndynamic)
				et = ItemsInList(NList())
				if (et==1)
					mtxt = "New Notebook"
					Button tb_saventbk, win=$kPanelName, disable=2
					notebk=1
				else
					mtxt = WinName(0,16)
					et = WhichListItem(mtxt,NList())+1
					Button tb_saventbk, win=$kPanelName, disable=0
					notebk = et
				endif
				PopupMenu tb0_notebook,  win=$kPanelName, popValue=mtxt, value=#"LogBook#NList()", mode=et				
			endif

			// dynamic graphic selection
			ControlInfo/W=$kPanelName tb0_graphic
			GraphicCheckBoxes(S_value)
			if (odynamic)
				graphic = ValidGraphics()
				if (!graphic)
					mtxt = "None"
					PopupMenu tb0_graphic, win=$kPanelName, value=#"LogBook#OList()",popValue=mtxt, mode=1
				else
					graphicname = StringFromList(0,OList(set=(1+2+4+64)))
					PopupMenu tb0_graphic, win=$kPanelName, value=#"LogBook#OList()",popValue=graphicname, mode=graphic
				endif
			endif
			rtnV = 1
			break
		
		case 17:	// kill vote
			hrefnum = nan
			Checkbox tb0_cbhistory,  win=$kPanelName, value = 0
			Checkbox tb0_cbhistory0,  win=$kPanelName, disable = 2
			Checkbox tb0_cbhistory1,  win=$kPanelName, disable = 2
			rtnV = 1
			break
	
// mac keyboard input block
#ifdef Macintosh
		case 11:	// keyboard input
			et = GetKeyState(0)
#ifdef DEBUG
			print "Mac keyboard input"
			print et, whs.keycode
#endif
			// shift key?
			if (et&4)
				switch(whs.keycode)
					case 13:	// return key too
						LogToNotebook()
						rtnV = 1
						break
				endswitch
			elseif(whs.keycode == 27) // escape key
				SetVariable tb0_title, activate
				rtnV = 1
			endif
			break
#endif

// windows keyboard input block
#ifdef Windows
		case 11:
			et = GetKeyState(0)
#ifdef DEBUG
			print "Windows keyboard input"
			print et, whs.keycode
#endif
			if ((et&4) && (et&1))
				switch(whs.keycode)
					case 187:	// = key Windows
						LogToNotebook()
						rtnV = 1
						break
				endswitch
			endif
			break
#endif
	endswitch
	
#ifdef DEBUG
	print "panel hook function ", whs.eventCode, whs.keycode
#endif			
	
	return rtnV
end

// checkboxes
Function SetCheckBoxes(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	
	switch( cba.eventCode )
		case 2: // mouse up
		case 99: // change in template
			strswitch(cba.ctrlName)
				case "tb0_cbtitle":
					SetVariable tb0_title, win=$kPanelName, disable=!cba.checked
					break
				case "tb0_autoclear":
					Button tb0_clearnotes, win=$kPanelName, disable=(2*cba.checked)
					break
				case "tb0_cbhistory":
					CheckBox tb0_cbhistory0, win=$kPanelName, disable=!cba.checked*2
					CheckBox tb0_cbhistory1, win=$kPanelName, disable=!cba.checked*2
					StartStopHistory(cba.checked)
					break
				case "tb0_cbhistory0":		// incremental
					CheckBox tb0_cbhistory1, value=!cba.checked
					StartStopHistory(2)
					break
				case "tb0_cbhistory1":		// accumulated
					CheckBox tb0_cbhistory0, win=$kPanelName, value=!cba.checked
					break
				case "tb0_cbdbrecord":		// folder dump
					PopupMenu tb0_lodf, win=$kPanelName, disable=((!cba.checked)*2)
					break
			endswitch
			break
	endswitch

	return 0
End

// popups
Function SetPopUps(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
		
	switch( pa.eventCode )
		case 2:
			strswitch( pa.ctrlName )
				// graphic selection
				case "tb0_graphic":
					GraphicCheckBoxes(pa.popStr)
					break
			endswitch
	endswitch
	return 0
end

// cycle through the list of possible graphics to show or not show the checkboxes
Function GraphicCheckBoxes(state)
	string state
	
	DFREF pdf = $thePackageFolder
	DFREF gdf = pdf:PanelGlobals

	NVAR/SDFR=gdf odynamic
	
	variable rtn = 1, nw
	
	ControlInfo/W=$kPanelName tb0_graphic
	nw = v_value > 1 ? 0 : 1
	Slider tb0_scale, win=$kPanelName, disable = nw
	ValDisplay tb0_showscale, win=$kPanelName, disable = nw
	Checkbox cb_bffs, win=$kPanelName, disable = nw
	strswitch(state)
		case "All":
			// only show checkboxes for windows that are present
			nw = ItemsinList(OList(set=1)) == 0 ? 1 : 0 // graphs
			CheckBox tb0_cbgraphs, win=$kPanelName, disable=(nw)
			nw = ItemsinList(OList(set=2)) == 0 ? 1 : 0 // tables
			CheckBox tb0_cbtables, win=$kPanelName, disable=(nw)
			nw = ItemsinList(OList(set=4)) == 0 ? 1 : 0 // layouts
			CheckBox tb0_cblayouts, win=$kPanelName, disable=(nw)
			nw = ItemsinList(OList(set=64)) == 0 ? 1 : 0 // panels
			CheckBox tb0_cbpanels, win=$kPanelName, disable=(nw)
			CheckBox tb0_cbodynamic, win=$kPanelName, disable=2
			odynamic = 0
			rtn = 0
			break
		default:
			CheckBox tb0_cbgraphs, win=$kPanelName, disable = 1
			CheckBox tb0_cbtables, win=$kPanelName, disable = 1
			CheckBox tb0_cblayouts, win=$kPanelName, disable = 1
			CheckBox tb0_cbpanels, win=$kPanelName, disable = 1
			strswitch(state)
				case "None":
					CheckBox tb0_cbodynamic, win=$kPanelName, disable = 1
					break
				default:
					CheckBox tb0_cbodynamic, win=$kPanelName, disable = 0
					break
			endswitch
			ControlInfo/W=$kPanelName tb0_cbodynamic
			odynamic = v_value
			break					
	endswitch
	return rtn
end

// sliders
Function SetSliders(sa) : SliderControl
	STRUCT WMSliderAction &sa
	
	DFREF pdf = $thePackageFolder
	DFREF gdf = pdf:PanelGlobals
	
	NVAR/SDFR=gdf size

	switch( sa.eventCode )
		case -1: // control being killed
			break
		default:
			strswitch(sa.ctrlName)
				case "tb0_scale":
					size = sa.curval
					break
			endswitch
			break
	endswitch

	return 0
End

// variables
Function SetVariables(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	DFREF pdf = $thePackageFolder
	DFREF gdf = pdf:PanelGlobals
	
	NVAR/SDFR=gdf xsize, ysize
	
	variable getout = 0

	switch( sva.eventCode )
		case 1: // mouse up
		//case 2: // Enter key
		case 3: // Live update
			strswitch(sva.ctrlName)

				// title - tab or return moves to and activates note field
				
				case "tb0_title":
#ifdef DEBUG
					print "Mac keyboard input at set variable"
#endif
					break

			endswitch
			break
		case 8:
			getout = 1
			break
	endswitch

	if (getout==1)
		SetActiveSubwindow #notefield
#ifdef DEBUG
		print "activating subwindw "
		print sva.eventCode
	else
		print "test not activating "
		print sva.eventCode
#endif
	endif
#ifdef DEBUG
	print "set variable function ", sva.eventCode
#endif			
	return 0
End

// buttons

// Send to Notebook
Function SetButtons(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2:
			strswitch(ba.CtrlName)
				case "tb0_clearnotes":
					Notebook $(kPanelName)#notefield selection={startOfFile,endofFile}
					Notebook $(kPanelName)#notefield text=""
					break
				case "tb_noteit":
					LogToNotebook()
					break
				case "tb_saventbk":
					ControlInfo/W=$kPanelName tb0_notebook
					Save_NtbktoMD(s_value)
					break
			endswitch
			break
	endswitch
	return 0
end

// onoff for history
// 0 - stop history
// 1 - start history
// 2 - restart history
Function StartStopHistory(onoff)
	variable onoff
	
	DFREF pdf = $thePackageFolder
	DFREF gdf = pdf:PanelGlobals
	
	NVAR/SDFR=gdf hrefnum
	SVAR/SDFR=gdf history

	switch( onoff )
		case 0:		// turn it off
			if (numtype(hrefnum)!=2)
				try
					history = CaptureHistory(hrefnum,1)
				catch
				endtry
				history = ""
				hrefnum = nan
			endif
			break
		default:		// turn it on
			if (numtype(hrefnum)==2)	//  --> not yet on
				history = ""
				hrefnum = CaptureHistoryStart()
			else
				if (onoff == 2)				// --> restart it
					try
						history = CaptureHistory(hrefnum,1)
					catch
					endtry
					history = ""
					hrefnum = CaptureHistoryStart()
				endif
			endif
			break
	endswitch

	return 0	
end

// graphic List
Function/S OList([set])
	variable set

	string theStr, rtStr = "None;", theList = "", theWin
	
	if (!ParamIsDefault(set))
		sprintf theWin "WIN:%d", set
		theStr = WinList("*",";",theWin)
		theStr = RemoveFromList(kPanelName,theStr)
		theStr = RemoveFromList("WNInput",theStr)
		return theStr
	endif
	
	// panels

	theWin = "WIN:64"
	theStr = RemoveFromList(kPanelName,WinList("*",";",theWin))
	theStr = RemoveFromList("WNInput",theStr)
	if (strlen(theStr)!=0)
		theList += theStr
	endif
	
	// tables

	theWin = "WIN:2"
	theStr = WinList("*",";",theWin)
	if (strlen(theStr)!=0)
		theList += theStr
	endif

	// graphs
		
	theWin = "WIN:1"
	theStr = WinList("*",";",theWin)
	if (strlen(theStr)!=0)
		theList += theStr
	endif
	
	// layouts
	
	theWin = "WIN:4"
	theStr = WinList("*",";",theWin)
	if (strlen(theStr)!=0)
		theList += theStr
	endif
	
	set = ItemsInList(theList)
	if (set==0)
		return rtStr
	else
		if (set==1)
			return ("None;" + theList)
		else
			return ("None;All;" + theList)
		endif
	endif
end

// Notebook List
Function/S NList()
	return ("New;" + WinList("*",";","WIN:16"))
end

// To Notebook from Tab0
Static Function LogToNotebook()		

	DFREF pdf = $thePackageFolder
	DFREF gdf = pdf:PanelGlobals

	NVAR/SDFR=gdf template, graphic, notebk, hrefnum
	SVAR/SDFR=gdf title, graphicname, notes, history, recentdate

	STRUCT WMButtonAction ba

	string theHeader = "", theDTStr="", thegraphic="", theNotebook="", tstr, estr, pURL
	variable itsFormat=1, at, newntbk, cObj, cHist, grtype, newpage, bffs
	variable sParagraph, sPosition
	
	// get notebook and its format
	
	ControlInfo/W=$kPanelName tb0_notebook
	notebk = V_value

	if (notebk == 1)
		// create a new notebook
		tstr = "Log Notebook"
		prompt tstr, "Give a title for the new notebook:"
		doprompt "Create New Notebook", tstr
		if (v_flag)
			return -1
		endif
		theNotebook = UniqueName(cleanupname(tstr,0),10,0)		
		NewNotebook/F=1/N=$theNotebook
		newntbk = 1
	else
		// use an existing notebook
		ControlInfo/W=$kPanelName tb0_notebook
		theNotebook = S_value
		// store current selection point
		GetSelection notebook, $theNotebook, 1
		sParagraph = V_startParagraph; sPosition = V_startPos
		Notebook $theNotebook selection={startOfFile,endOfFile}
		Notebook $theNotebook getData=2
		if (strlen(S_value)==0)
			newntbk = 1
		else
			newntbk = 0
		endif		
		Notebook $theNotebook selection={(sParagraph,sPosition),(sParagraph,sPosition)}
	endif
	
	// create rulers
	CreateNtbkRulers(theNotebook)
	
	// if a new (or blank) notebook, put starting information
	if (newntbk)
	
		Notebook $theNotebook ruler=Heading
		tstr = "# Start of Notebook\r"
		Notebook $theNotebook text = tstr
		
		Notebook $theNotebook ruler=Normal
		tstr = "#date " + date() + "\r"
		Notebook $theNotebook text = tstr
		
		Notebook $theNotebook ruler=Heading
		tstr = "## Experiment Information\r"
		Notebook $theNotebook text = tstr
		
		estr = IgorInfo(1)
		PathInfo home
		tstr = ReplaceString(":",s_path,"/")
		tstr = RemoveListItem(0,tstr,"/")
		sprintf pURL "[%s](<file:///%s%s.pxp>)", estr, tstr, estr
		Notebook $theNotebook ruler=Normal
		tstr = "Project Name: " + IgorInfo(1)
#if(IgorVersion()>=9)
		GetFileFolderInfo/Q/Z/P=home igorinfo(12)
		if(!V_flag)
			tstr += "\rCreation Date: " +  Secs2Date(V_creationDate,-2) +"|" + Secs2Time(V_creationDate,3)
			tstr += "\rModification Date: " + Secs2Date(V_modificationDate,-2) +"|" + Secs2Time(V_modificationDate,3)
		endif
#endif
		tstr += "\rExperiment File: " + pURL + "\r"
		Notebook $theNotebook text = tstr

		Notebook $theNotebook ruler=Heading
		tstr = "## User Information\r"
		Notebook $theNotebook text = tstr
		
		Notebook $theNotebook ruler=Normal
		tstr = "#author User Name: " + IgorInfo(7)
		tstr += "\rPlatform: " + IgorInfo(2)
		tstr += "\rIgor Version Information: " + IgorInfo(3)
		tstr += "\rIgorPro SN: " + IgorInfo(5) + "\r"
		Notebook $theNotebook text = tstr

		Notebook $theNotebook ruler=Heading
		tstr = "# Experiment Notes\r"
		Notebook $theNotebook text = tstr

	endif
	
	SplitString/E=("/F=./") WinRecreation(theNotebook,0)
	itsFormat = str2num(S_value[3])
		
	// move to where the stuff is to go
	ControlInfo/W=$kPanelName tb0_location
	at = V_value-1
	DoWindow/F theNotebook
	switch(at)
		case 0: // start
			Notebook $theNotebook selection={startOfFile,startOfFile}
			break
		case 1: // previous paragraph
			Notebook $theNotebook selection={startOfPrevParagraph,startOfPrevParagraph}
			break		
		case 2: // here
			break
		case 3: // next paragraph
			Notebook $theNotebook selection={startOfNextParagraph,startOfNextParagraph}
			break
		case 4: // end
			Notebook $theNotebook selection={endOfFile,endOfFile}
			break
	endswitch
	
	// new page
	ControlInfo/W=$kPanelName popup_startpage
	switch(v_value)
		case 1:		// nothing
			break
		case 2:		// new line
			Notebook $theNotebook text = "---\r"
			break
		case 3:		// new page
			Notebook $theNotebook, specialChar={1,1,""}
			break
	endswitch
	
	// title
	ControlInfo/W=$kPanelName tb0_cbtitle
	if (V_value)
		theHeader = "## " + title + "\r"
	else
		theHeader = "## Notes\r"
	endif
	Notebook $theNotebook ruler=Heading
	Notebook $theNotebook text=theHeader
	
	// date and time
	theDTStr = date()
	if (cmpstr(theDTStr,recentdate)!=0)
		recentdate = theDTStr
		theDTStr = "#date " + theDTStr + "\r"
	else
		theDTStr = ""
	endif
	theDTStr += "#time " + time() + "\r"
	Notebook $theNotebook ruler=Normal
	Notebook $theNotebook text = theDTStr
	
	// comments
	
	Notebook $theNotebook ruler=Subheading
	Notebook $theNotebook text="### Comments\r"
	Notebook $(kPanelName)#notefield getData=2
	if (strlen(S_value)!=0)
		notes = S_value
		// do comments have functions?	
		ControlInfo/W=$kPanelName tb0_notefuncs
		if (v_value)
			tstr = ParseForExecution(notes,all=1)
			if (strlen(tstr)!=0)
				notes += "\r" + tstr
			endif
		endif
		notes += "\r"
		Notebook $theNotebook ruler=Normal
		Notebook $theNotebook text=notes	
	endif
	ControlInfo/W=$kPanelName tb0_autoclear
	if (V_value)
		ba.ctrlName="tb0_clearnotes"
		ba.eventCode=2
		SetButtons(ba)
	endif			
	
	// graphics
	ControlInfo/W=$kPanelName cb_bffs
	bffs = v_value
	ControlInfo/W=$kPanelName tb0_graphic
	thegraphic = ""
	cObj = 0
	strswitch(S_Value)
		case "None":
			break
		case "All":
			// panels
			ControlInfo/W=$kPanelName tb0_cbpanels
			if (V_value==1)
				thegraphic += OList(set=64)
				cObj = 1
			endif
			// tables
			ControlInfo/W=$kPanelName tb0_cbtables
			if (V_value==1)
				thegraphic += OList(set=2)
				cObj = 1
			endif
			// graphs
			ControlInfo/W=$kPanelName tb0_cbgraphs
			if (V_value==1)
				thegraphic += OList(set=1)
				cObj = 1
			endif
			// layouts
			ControlInfo/W=$kPanelName tb0_cblayouts
			if (V_value==1)
				thegraphic += OList(set=4)
				cObj = 1
			endif
			break
		default:
			thegraphic = S_value
			cObj = 1
			break
	endswitch
	
	switch(cObj)
		case 0:	// no graphic
			break				
		case 1: // graphics
			Notebook $theNotebook ruler=Subheading
			Notebook $theNotebook text="### Figures\r"
			Notebook $theNotebook ruler=Normal
			PutgraphicinNtbk(thegraphic,theNotebook,bffs)
			break
	endswitch
	
	// history
	ControlInfo/W=$kPanelName tb0_cbhistory
	if (V_value)
		// history is being captured
		ControlInfo/W=$kPanelName tb0_cbhistory0
		if (V_value==1)		// incremental history
			history = "### Incremental History\r"
			Notebook $theNotebook ruler=Subheading
			Notebook $theNotebook text = history
			history = CaptureHistory(hrefnum,0) + "\r"
			Notebook $theNotebook ruler=Normal
			Notebook $theNotebook text = history
			StartStopHistory(0)
			Checkbox/Z tb0_cbhistory, win=$kPanelName, value=0
			Checkbox/Z tb0_cbhistory0, win=$kPanelName, disable=2
			Checkbox/Z tb0_cbhistory1, win=$kPanelName, disable=2
		else					// ongoing history
			history = "### Accumulated History\r"
			Notebook $theNotebook ruler=Subheading
			Notebook $theNotebook text = history
			history = CaptureHistory(hrefnum,0)	 + "\r"
			Notebook $theNotebook ruler=Normal
			Notebook $theNotebook text = history
		endif
	else
		StartStopHistory(0)
	endif	
	
	// data directory dump	
	ControlInfo/W=$kPanelName tb0_cbdbrecord
	if (v_value)
		ControlInfo/W=$kPanelName tb0_lodf
		if (cmpstr(s_value,"root")!=0)
			DFREF dfr = $("root:" + s_value)
		else
			DFREF dfr = $("root:")
		endif
		history = "### Data Directory Dump\r"
		Notebook $theNotebook ruler=Subheading
		Notebook $theNotebook text = history
		history = "Data Folder => " + GetDataFolder(1,dfr) + "\r"
		history += DataFolderDir(-1,dfr) + "\r"
		Notebook $theNotebook ruler=Normal
		Notebook $theNotebook text = history
	endif
	
	return 0
end

Function CreateNtbkRulers(theNtbk)
	string theNtbk
	
	Notebook $theNtbk newRuler=Heading, spacing={12,6,0}, rulerDefaults={"",14,1,(0,0,0)}
	Notebook $theNtbk newRuler=Subheading, spacing={6,6,0}, rulerDefaults={"",12,0,(0,0,0)}
	Notebook $theNtbk Ruler=Normal, spacing={0,0,0}, rulerDefaults={"",12,0,(0,0,0)}
	
	return 0
end

// list of data folders
Function/S LoDF()

	string lof="", objn
	variable ic=0
	do
		objn = GetIndexedObjName("root:",4,ic)
		if (strlen(objn)==0)
			break
		endif
		lof += objn + ";"
		ic+=1
	while(1)
	lof = "root;" + RemoveFromList("Packages",lof,";")
	return lof
end

// put graphics in the notebook
// thegraphic --> window
// theNtbk --> the notebook
// bffs --> scale by fixed full size
Static Function PutGraphicinNtbk(thegraphic,theNtbk,bffs)
	string thegraphic, theNtbk
	variable bffs

	DFREF pdf = $thePackageFolder
	DFREF gdf = pdf:PanelGlobals
		
	NVAR/SDFR=gdf frame, size, omode, xsize, ysize
	
	variable lmode, ic, ng, hwidth, gwidth, fs, fig
	string tStr, theList, gname, gtitle
	
	// translate modes and size
	// put as png
	lmode = -5
	hwidth = 8*72
	
	// put the graphic

	theList = thegraphic
	ng = ItemsInList(theList)
	
	for (ic=0;ic<ng;ic+=1)
		fig = 1
		thegraphic = StringFromList(ic,theList)
		
		switch(WinType(thegraphic))
			case 7:  // panel
				GetWindow/Z $thegraphic, wtitle
				gtitle = thegraphic + " - " +  s_value
				gname = "#### Panel: " + gtitle  + "\r"
				SavePICT/SNAP=1/O/WIN=$thegraphic/P=_PictGallery_/E=-5 as thegraphic
				GetWindow/Z $thegraphic wsize
				gwidth = V_right - V_left
			case 0:	// none (PICT)
				if (WhichListItem(thegraphic,PictList("*",";",""))==-1)
					gname = "NO PICTURE graphic TO INSERT\r"
					fig = 0
					break
				endif
				break
			case 1:	// graph
				GetWindow/Z $thegraphic, wtitle
				gtitle = thegraphic + " - " +  s_value
				GetWindow/Z $thegraphic wsize
				gwidth = V_right - V_left
				gname = "#### Graph: " + gtitle + "\r"
				break
			case 2:	// table
				GetWindow/Z $thegraphic, wtitle
				gtitle = thegraphic + " - " + s_value
				GetWindow/Z $thegraphic wsize
				gwidth = V_right - V_left
				gname = "#### Table: " + gtitle + "\r"
				break
			case 3:	// layout
				GetWindow/Z $thegraphic, wtitle
				gtitle = thegraphic + " - " + s_value
				GetWindow/Z $thegraphic wsize
				gwidth = V_right - V_left
				gname = "#### Layout: " + gtitle + "\r"
				break					
		endswitch
		
		if (fig==1)
			if (bffs==0)
				Notebook $theNtbk, text=gname
				Notebook $theNtbk, frame=frame, scaling={size,size}, picture={$thegraphic(0,0,xsize,ysize),lmode,1}
			else
				fs = round((hwidth/gwidth)*size)
#ifdef DEBUG
				print thegraphic, hwidth, gwidth, fs
#endif
				Notebook $theNtbk, text=gname
				Notebook $theNtbk, frame=frame, scaling={fs,fs}, picture={$thegraphic,lmode,1}
			endif
			put_URLinNtbk(ic, thegraphic, theNtbk)
			put_windowNotesinNtbk(thegraphic, theNtbk)
			Notebook $theNtbk, text="\r\r"
		endif
	endfor

	return 0
End

// put URL for graphic in notebook
Static Function put_URLinNtbk(variable theOne, string thegraphic, string theNtbk)

	string mdURL
	
	sprintf mdURL "\r![local file: %s.png](<./%sMedia/Picture%d.png>)\r", theGraphic, theNtbk, theOne
	Notebook $theNtbk, text=mdURL
	return 0
end

// add window notes if they exist
Static Function put_WindowNotesinNtbk(string thegraphic, string theNtbk)

	GetWindow $thegraphic, note
	if (strlen(S_value) != 0)
		sprintf S_value "\r#caption %s\r", S_value
		Notebook $theNtbk, text=S_value
	endif
	return 0
end

// Parse for Execution
// returns string from execution
// [all]: 1 (default) returns command and string, 0 returns only executation string

Static Function/S ParseForExecution(vStr,[all])
	string vStr
	variable all
	
	all = ParamIsDefault(all) ? 1 : all
	
	string theReturnStr="", theCmd="", enStr, theSCmd
	variable st=0, en=0, doff
	
	string/G rtnStr = ""

	en = strsearch(vStr,"%",st)
	if (en >= 0)	
		do
			if (cmpstr(vStr[en-1],"\\")!=0)
				theReturnStr += vStr[st,en-1]
				st = en+1
				en = strsearch(vStr,")",st)
				if (en > st)
					theCmd = vStr[st,en]
					sprintf theCmd, "rtnStr = %s", theCmd
					Execute/Q/Z theCmd
					if (V_flag)
						sprintf theCmd, "rtnStr = ProcGlobal#%s", vStr[st,en]
						Execute/Q/Z theCmd
						if (V_flag)
							sprintf theCmd, "ERROR %d: %s", V_flag, vStr[st,en]
							rtnStr = theCmd
						endif
					endif
					theReturnStr += rtnStr
					st = en + 1
				else
					theReturnStr += "MISSING ): "
				endif
			else
				theReturnStr += vStr[st,en-2] + "%"
				st = en + 1
			endif	
			en = strsearch(vStr,"%",st)
		while (en >= 0)
		theReturnStr += vStr[st,strlen(vStr)-1]
	else
		theReturnStr = vStr
	endif
	
	killstrings/Z rtnStr

	vStr = theReturnStr
	theReturnStr = ""
	st = 0
	en = strsearch(vStr,"#",st)
	if (en >= 0)	
		do
			if (cmpstr(vStr[en-1],"\\")!=0)
				if (cmpstr(vStr[en+1],"{")==0)
					enStr = "}"
					st = en + 2
					doff = 1
				else
					enStr = ")"
					st = en + 1
					doff = 0
				endif
				en = strsearch(vStr,enStr,st)
				if (en > st)
					theCmd = vStr[st,en-doff]
					Execute/Q/Z theCmd
					if (V_flag)
						switch(doff)
							case 0:
								Execute/Q/Z theCmd
								if (V_flag)
									sprintf theCmd, "ProcGlobal#%s",  vStr[st,en-doff]
									Execute/Q/Z theCmd
									if (V_flag)
										sprintf theCmd, "\rEXECUTION ERROR %d: #%s\r", V_flag, vStr[st,en-doff]
										theReturnStr += theCmd
									endif
								endif
								break
							case 1:
								sprintf theCmd, "\rEXECUTION ERROR %d: #%s\r", V_flag, vStr[st,en-doff]
								theReturnStr += theCmd
								break
						endswitch
					endif
					st = en + 1
				else
					sprintf theReturnStr, "%s\rERROR MISSING %s: %s", theReturnStr, enStr, vStr[st-1-doff,st+5]
				endif
			else
				theReturnStr += vStr[st,en-2] + "#"
				st = en + 1
			endif	
			en = strsearch(vStr,"#",st)
		while (en >= 0)
		theReturnStr += vStr[st,strlen(vStr)-1]
	else
		theReturnStr = vStr
	endif
	
	return theReturnStr
end

// ****** DEPRECIATING
// TO REMOVE IN NEXT UPDATE
//// Get Help
//Function GetHelp(ba) : ButtonControl
//	STRUCT WMButtonAction &ba
//	
//	string theCmd
//	
//	sprintf theCmd "ProcGlobal#PackageHelp(\"%s\")", thePackage
//
//	switch( ba.eventCode )
//		case 2: // mouse up
//			Execute/P/Q/Z theCmd
//			break
//	endswitch
//
//	return 0
//End

// ****** DEPRECIATING
// TO REMOVE IN NEXT UPDATE
//// Remove Me
//Function RemoveMe(ba) : ButtonControl
//	STRUCT WMButtonAction &ba
//	
//	string theCmd 
//	sprintf theCmd "ProcGlobal#PackageRemove(\"%s\")", thePackage
//
//	switch( ba.eventCode )
//		case 2: // mouse up
//			DoWindow/K $kPanelName
//			Execute/P/Q/Z theCmd
//			break
//	endswitch
//
//	return 0
//End

Function/S Graphic(item)
	variable item

	DFREF pdf = $thePackageFolder
	DFREF gdf = pdf:PanelGlobals
		
	SVAR/SDFR=gdf graphicname
	
	string rStr = "* Graphics Information: "
	
	switch(item)
		case -1:
			rStr += "-1: list; 0: graphic name; 1: graph traces;"
			break
		case 0:
			rStr += graphicname
			break
		case 1:	
			if (WinType(graphicname)==1)
				rStr += ReplaceString(";",TraceNameList(graphicname,";",1),"; ")
			else
				rStr += graphicname
			endif
			break
		default:
			rStr += graphicname
			break	
	endswitch
	
	return rStr

end

// save the notebook as markdown
Static Function Save_NtbktoMD(string theNtbk)

	string htmfilename, mdfilename //, tfoldername, nfoldername
	htmfilename = theNtbk + ".htm"
	mdfilename = theNtbk + ".md"
	//foldername = theNtbk + "Media"
	
	NewPath/O/Q/M="Choose location for markdown notebook" ntbkpath
	if (v_flag != 0)
		return 0
	endif
	
	SaveNotebook/O/P=ntbkpath/S=5/H={"UTF-8",0,0,0,0,32} $theNtbk as htmfilename
	SaveNotebook/O/P=ntbkpath/S=6 $theNtbk as mdfilename
	//DeleteFile/P=ntbkpath htmfilename
	//MoveFolder/O/P=ntbkpath/Z tfoldername as nfoldername
	
	return 0
end

// PICTURES


// PNG: width= 65, height= 22
Picture Eraser
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!!]!!!!5#R18/!7:mT.0'>J"EQn$<!Wa8#^cngL]@DT$#iF<ErZ1Lf)P
	d[f)\2dRs4o5!#]lI=EIJ[Aor6*Eb,5pGBYZRDJO<'@;od1DfTK[mQ;Bf!!sc>6pXdSKrp`sD]Mmo`
	ddk@F(W_BnZdLO43iO*D*nUuco/RmEc:.f"<dmT]MSeE49,F3PTg-&$P-85%fdd&#'fB*V,ltf;l(X
	/De\4,Nfteblm,>BO6<#hB4fKH4<3PD99O>KdQEJ#Xf_%rhcaga28VB:q#@Lh!#pG<TU%@;(//U[V)
	_,9j.+$=MLmMNPXI$a9.;)n(ha"!JL4e)=)e"#0m:ht1"B`YGC["BV*kToctifg$0^=T@F=Uh3$>Pf
	3&++PUeJ`V2RenP79@U/>1,%qFmaPCK#Ah/499[K"eW2gM<QAcb6%#M4t5TC:\]q.LgU2XI8o'2gZG
	!XH?YXjHI"pal5\L6X7kun#)mOY'#VZ,PiHDGS@Quj9lhdQc13KZJY'[MG6b!K;YZi`cB2BHeYUigi
	J8l]EY*)VD#<RF*kT&,@(gcUNVFnNm@7\Da:-D-E#`@.c8f]Y0j2Z1rd^VY>J^0drKk`P!VZ\EQO#\
	9":e+sdqE;d>YH$'82tW:iUk)ImF2\nP'WI(h*C0^%$f(p^@6M!oNq9V49W;%9QQ2X[aoJ,,iY6,O-
	3Zh[odE#C!,.\,!Yu$+R<*OnD-q"bS]1t2T<sIB*cB^"X)-49V*E8c[.%:W:tJ]$fYD6"dbI]<`kR7
	DRPqCcsV76`Mp1(B.l<?VPB\J6Q0cYkUoG1m6Ka`$"og5_?qaRjh2G4e/7$`]u\J8-7BY1pjb('@h$
	io3-b?Fp"HO7mB918>0#^_6i?Oo-`O6##bFNHMVMB/Q4[Jk@J`3FEm^NB2_Sm8_\tl\2e\ePAG4LuN
	JSuo`^?4N"W(Q8Vp7Eh#X&H@M5LJC?9aXU[7h&PiZEY58T!QYcl0!U;qE^K@@HTXaa*Za96b:AIZF@
	*.DA_b`gAd1r\[n?>O'6G_td?Qm#g+Ol1%9H?!trd1IF2Be!ueuET0?k&'ke\[HTInUt7ulFVC_c;3
	23.GmnflFHo!OXgeC=`qCJ3kVL!6]<rPeAs`ZBH]7K8#N'&J+rYo_00]BV4J*o+4)6jbk=nF<H^;BL
	2p1ktT:Y*W+8h8[hE,teZ5L[Vn>AK5bdo[4(.DL7!R?g?L,>Ku0g8>pHAq"M.%Hd&X.<1N,qAmFj[-
	mbZ%cWRAlZO_:iAm+dDOH(RXqis1:h*OUX)(rDf6*LqlERXjOOj5A%:u&?7]I#pB^($i*/T/ZZ'[ZI
	L\U8>P`\mn?jV44?UqWWIU%*^;K`^h<;nfF3E9;$f/":b&c!#9OiI?R?8"nNf9'lSNsRqHm&eqL@<i
	0O\kEXP^9oCYrnhc4!ZA%-n/8uT;ECDp?c@7kAR<NC'7GpCQ7duZjaJ;r&[Tb[i<#'4#a>`>3%p:ON
	R0b'E<BB"2EVWGH$7Y&h*rU.?m^iPOmB&LR@@YDh%A"9:`ma-UURjcoaP7bigdU,=cF<3f0Dq6"DFe
	jsZ^m?(4`RZb3.QWgB[Y'Ie`"8mR!jof6cGiT._d*-gHLQ5,>A\T:eENKtJu$u[4M`,la.oo01mS\^
	3uNmF?Xh'[AB.sAu880JQTUk<k$&(CII_gML)5K&D+U&,RIN?N-sM9epNF8Q0cYq]cGe%(0W5"8^2"
	^+YepN0=Om%q=tMdirAern3r>Q?aT4NG&qG#0\*d8DVqm,7@enQ-doHU%?-8@q^E7J?(tl"-#7,L6e
	D3eVY:`aGq1prEa(mb#H0S+!3(Le-!Z4O9?@Cb8eQd$gN%3B^(La(4S%guN"VTp=fZ9%'_=TW\U(er
	;9d89Hd0YmBcKQX1h,;bYo]K^G^u[@A'OiS5IJY[R.:,g?f_A'FTPqZHfX6Yi*G@Zj3>0c@i2)Q+s-
	IC9:]Fmq7E1D.lDP:XnCX>:D1,Yi-V?Qf)k18RN][&bJbJuB6B<6Ej6)-?<IU/SCbp04P#r;M/hcs"
	^`0hF1@c4Pr[9^m@m^d'RJROF&-2Og'oZ*$[nPBYkYBkW$JXcG6gB[DPZBXQNaAM!l8=6UbG,)RT(3
	2Y5@/ZC@Q<"^4+'UC>gYLfJOQb6KJ.0Rlk*j]9GX&:+E<,b,(PZjO7K!fUIB.+;`e%bQQ`o8=b'Hrq
	PDkniTD-Ns`iJXFj+A61UqP@*U@;sCWN1V!NVI0:Re$BKY/LqLjs(PBi&N+/T`_`d<WRpGM$ABcFQW
	+;F#RG3'_SJON_%jKAFjaGPNG=_J[7XK%,0D4E+MdSr[+7dEY1X']WjQ10[qoL4oJecoq/aR8R$5_9
	6kA(5OZlVuSqkYdrC)]]hOASHE`aU"s'C`"nf"-KqIpEY8X`1\i3R=W3psTF/lo/^I8.!I63sse&QC
	4ol[9HP#Ohp%E:r>R4h]KZ?-%$m0*ot>O&?<.,RABq_U_nj`?N,#pMoief6D8t:55sh[s%.B2Jq0dR
	PejdK&FXS=t.G]Pq/edReN"(YO6_.p<#ZNV%R<!a,V/b$j/!@.]ZXS6qF^FJl4YF.BQmL=EKg3%?n5
	_8tjC=6p&@d$EmFGpH4+OR*:Y'#!]RV%k!'MFG?iAO4Kcrck,;(F"g11Fk?41X&i+M(*PPoNfF_T!S
	)4U<GR>N;D5nrBNd0*S+/k`#d*SZ:"3j<AS1@ZRUPcOBhG`QD#(s(LrK+^kCNN#F1inpFjaq7:L+Zo
	l"QTm0hFGMZOX?/qZXX*8>0._gf:2OX%K?jFIlM;QiqR7LOk*%9hQg-3-4:3;G2D>M(U_76^ejN9pq
	kP$9[tV9h9.U%nl;ri`!>6DT#50Nfm/^d*=_+XTL(o9\>!$'QKm:V,U^070Hiq:tej%0EfuZ4PqM;P
	t@.7!t]E<JF\do!<VT&iLFsA(IDAogFJalpbKRWgGY3OkO;2APK\/ZCV`W$/I(uJ'#t=/npGi:SVJk
	HZ8ckEg&Z8Y9h/?q<6\_J`FH#M0$hY!+\Pa-dNWP+jB55QhB=9]_Xm:)+iR>M=O8JBb@QIqFarpd3c
	ZcZZ-9t?8AHiMl$ieO(3j.GM><#/!!!!j78?7R6=>B
	ASCII85End
End
