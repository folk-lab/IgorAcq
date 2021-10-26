function OLDInitializeWaves(start, fin, numpts, [starty, finy, numptsy, x_label, y_label, linecut, fastdac]) //linecut = 0,1 for false, true
	variable start, fin, numpts, starty, finy, numptsy, linecut, fastdac
	string x_label, y_label
	wave sc_RawRecord, sc_CalcRecord, sc_RawPlot, sc_CalcPlot
	wave/t sc_RawWaveNames, sc_CalcWaveNames, sc_RawScripts, sc_CalcScripts
	variable i=0, j=0
	string cmd = "", wn = "", wn2d="", s, script = "", script0 = "", script1 = ""
	string/g sc_x_label, sc_y_label, activegraphs=""
	variable/g sc_is2d, sc_scanstarttime = datetime
	variable/g sc_startx, sc_finx, sc_numptsx, sc_starty, sc_finy, sc_numptsy
	variable/g sc_abortsweep=0, sc_pause=0, sc_abortnosave=0
	string graphlist, graphname, plottitle, graphtitle="", graphnumlist="", graphnum, cmd1="",window_string=""
	string cmd2=""
	variable index, graphopen, graphopen2d
	svar sc_colormap
	variable/g fastdac_init = 0

	if(paramisdefault(fastdac))
		fastdac = 0
		fastdac_init = 0
	elseif(fastdac == 1)
		fastdac_init = 1
	else
		// set fastdac = 1 if you want to use the fastdac!
		print("[WARNING] \"InitializeWaves\": Pass fastdac = 1! Setting it to 0.")
		fastdac = 0
		fastdac_init = 0
	endif

	if(fastdac == 0)
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
	endif
	i=0

	// Close all Resource Manager sessions
	// and then reopen all instruemnt connections.
	// VISA tents to drop the connections after being
	// idle for a while.
	killVISA()
	sc_OpenInstrConnections(0)

	// The status of the upcoming scan will be set when waves are initialized.
	if(!paramisdefault(starty) && !paramisdefault(finy) && !paramisdefault(numptsy))
		sc_is2d = 1
		sc_startx = start
		sc_finx = fin
		sc_numptsx = numpts
		sc_starty = starty
		sc_finy = finy
		sc_numptsy = numptsy
		if(start==fin || starty==finy)
			print "[WARNING]: Your start and end values are the same!"
		endif
	else
		sc_is2d = 0
		sc_startx = start
		sc_finx = fin
		sc_numptsx = numpts
		if(start==fin)
			print "[WARNING]: Your start and end values are the same!"
		endif
	endif

	if(linecut == 1)
		sc_is2d = 2
		make/O/n=(numptsy) sc_linestart = NaN 						//To store first xvalue of each line of data
		cmd = "setscale/I x " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + "sc_linestart"; execute(cmd)
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

	// create waves to hold x and y data (in case I want to save it)
	// this is pretty useless if using readvstime
	cmd = "make /o/n=(" + num2istr(sc_numptsx) + ") " + "sc_xdata" + "=NaN"; execute(cmd)
	cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + "sc_xdata"; execute(cmd)
	cmd = "sc_xdata" +" = x"; execute(cmd)
	if(sc_is2d != 0)
		cmd = "make /o/n=(" + num2istr(sc_numptsy) + ") " + "sc_ydata" + "=NaN"; execute(cmd)
		cmd = "setscale/I x " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", \"\", " + "sc_ydata"; execute(cmd)
		cmd = "sc_ydata" +" = x"; execute(cmd)
	endif

	if(fastdac == 0)
		// Initialize waves for raw data
		do
			if (sc_RawRecord[i] == 1 && cmpstr(sc_RawWaveNames[i], "") || sc_RawPlot[i] == 1 && cmpstr(sc_RawWaveNames[i], ""))
				wn = sc_RawWaveNames[i]
				cmd = "make /o/n=(" + num2istr(sc_numptsx) + ") " + wn + "=NaN"
				execute(cmd)
				cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + wn
				execute(cmd)
				if(sc_is2d == 1)
					// In case this is a 2D measurement
					wn2d = wn + "2d"
					cmd = "make /o/n=(" + num2istr(sc_numptsx) + ", " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd)
					cmd = "setscale /i x, " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", " + wn2d; execute(cmd)
					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)
				elseif(sc_is2d == 2)
					// In case this is a 2D line cut measurement
					wn2d = sc_RawWaveNames[i]+"2d"
					cmd = "make /o/n=(1, " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd) //Makes 1 by y wave, x is redimensioned in recordline
					cmd = "setscale /P x, 0, " + num2str((sc_finx-sc_startx)/sc_numptsx) + "," + wn2d; execute(cmd) //sets x scale starting from 0 but with delta correct
					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)//Useful to see if top and bottom of scan are filled with NaNs
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
				if(sc_is2d == 1)
					// In case this is a 2D measurement
					wn2d = wn + "2d"
					cmd = "make /o/n=(" + num2istr(sc_numptsx) + ", " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd)
					cmd = "setscale /i x, " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", " + wn2d; execute(cmd)
					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)
				elseif(sc_is2d == 2)
					// In case this is a 2D line cut measurement
					wn2d = sc_CalcWaveNames[i]+"2d"
					cmd = "make /o/n=(1, " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd) //Same as for Raw (see above)
					cmd = "setscale /P x, 0, " + num2str((sc_finx-sc_startx)/sc_numptsx) + "," + wn2d; execute(cmd) //sets x scale starting from 0 but with delta correct
					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)
				endif
			endif
			i+=1
		while (i<numpnts(sc_CalcWaveNames))

		sc_findAsyncMeasurements()

	elseif(fastdac == 1)
		// create waves for fastdac
		wave/t fadcvalstr
		wave fadcattr
		string/g sc_fastadc = ""
		string wn_raw = "", wn_raw2d = ""
		i=0
		do
			if(fadcattr[i][2] == 48) // checkbox checked
				sc_fastadc = addlistitem(fadcvalstr[i][0], sc_fastadc, ",", inf)  //Add adc_channel to list being recorded (inf to add at end)
				wn = fadcvalstr[i][3]
				cmd = "make/o/n=(" + num2istr(sc_numptsx) + ") " + wn + "=NaN"
				execute(cmd)
				cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + wn
				execute(cmd)

				wn_raw = "ADC"+num2istr(i)
				cmd = "make/o/n=(" + num2istr(sc_numptsx) + ") " + wn_raw + "=NaN"
				execute(cmd)
				cmd = "setscale/I x " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", \"\", " + wn_raw
				execute(cmd)

				if(sc_is2d > 0)  // Should work for linecut too I think?
					// In case this is a 2D measurement
					wn2d = wn + "_2d"
					cmd = "make /o/n=(" + num2istr(sc_numptsx) + ", " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd)
					cmd = "setscale /i x, " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", " + wn2d; execute(cmd)
					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)

					wn_raw2d = wn_raw + "_2d"
					cmd = "make /o/n=(" + num2istr(sc_numptsx) + ", " + num2istr(sc_numptsy) + ") " + wn_raw2d + "=NaN"; execute(cmd)
					cmd = "setscale /i x, " + num2str(sc_startx) + ", " + num2str(sc_finx) + ", " + wn_raw2d; execute(cmd)
					cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn_raw2d; execute(cmd)
				endif
			endif
			i++
		while(i<dimsize(fadcvalstr,0))
		sc_fastadc = sc_fastadc[0,strlen(sc_fastadc)-2]  // To chop off trailing comma
	endif

	// Find all open plots
	graphlist = winlist("*",";","WIN:1")
	j=0
	for (i=0;i<itemsinlist(graphlist);i=i+1)
		index = strsearch(graphlist,";",j)
		graphname = graphlist[j,index-1]
		setaxis/w=$graphname /a
		getwindow $graphname wtitle
		splitstring /e="(.*):(.*)" s_value, graphnum, plottitle
		graphtitle+= plottitle+";"
		graphnumlist+= graphnum+";"
		j=index+1
	endfor

	nvar filenum

	if(fastdac == 0)
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
						if(sc_is2d == 0)
							Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label  // Can add something like current /nA as y_label for 1D only... if 2D sc_y_label will be for 2D plot
						endif
						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)					
					endif
					if(sc_is2d)
						if(stringmatch(wn+"2d",stringfromlist(j,graphtitle)))
							graphopen2d = 1
							activegraphs+= stringfromlist(j,graphnumlist)+";"
							Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
							Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
							TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)	
						endif
					endif
				endfor
				if(graphopen && graphopen2d) //If both open do nothing
				elseif(graphopen2d) //If only 2D is open then open 1D
					display $wn
					setwindow kwTopWin, graphicsTech=0
					Label bottom, sc_x_label
					if(sc_is2d == 0)
						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
					endif
					TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
					activegraphs+= winname(0,1)+";"
				elseif(graphopen) // If only 1D is open then open 2D
					if(sc_is2d)
						wn2d = wn + "2d"
						display
						setwindow kwTopWin, graphicsTech=0
						appendimage $wn2d
						modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
						colorscale /c/n=$sc_ColorMap /e/a=rc image=$wn2d
						Label left, sc_y_label
						Label bottom, sc_x_label
						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
						activegraphs+= winname(0,1)+";"
					endif
				else // Open Both
					wn2d = wn + "2d"
					display $wn
					setwindow kwTopWin, graphicsTech=0
					Label bottom, sc_x_label
					if(sc_is2d == 0)
						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
					endif
					TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
					activegraphs+= winname(0,1)+";"
					if(sc_is2d)
						display
						setwindow kwTopWin, graphicsTech=0
						appendimage $wn2d
						modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
						colorscale /c/n=$sc_ColorMap /e/a=rc image=$wn2d
						Label left, sc_y_label
						Label bottom, sc_x_label
						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
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
						if(sc_is2d == 0)
							Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label 
						endif
						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
					endif
					if(sc_is2d)
						if(stringmatch(wn+"2d",stringfromlist(j,graphtitle)))
							graphopen2d = 1
							activegraphs+= stringfromlist(j,graphnumlist)+";"
							Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
							Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
							TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
						endif
					endif
				endfor
				if(graphopen && graphopen2d)
				elseif(graphopen2d) // If only 2D open then open 1D
					display $wn
					setwindow kwTopWin, graphicsTech=0
					Label bottom, sc_x_label
					if(sc_is2d == 0)
						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
					endif
					TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
					activegraphs+= winname(0,1)+";"
				elseif(graphopen) // If only 1D is open then open 2D
					if(sc_is2d)
						wn2d = wn + "2d"
						display
						appendimage $wn2d
						modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
						colorscale /c/n=$sc_ColorMap /e/a=rc image=$wn2d
						Label left, sc_y_label
						setwindow kwTopWin, graphicsTech=0
						Label bottom, sc_x_label
						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
						activegraphs+= winname(0,1)+";"
					endif
				else // open both
					wn2d = wn + "2d"
					display $wn
					setwindow kwTopWin, graphicsTech=0
					Label bottom, sc_x_label
					if(sc_is2d == 0)
						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
					endif
					TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
					activegraphs+= winname(0,1)+";"
					if(sc_is2d)
						display
						setwindow kwTopWin, graphicsTech=0
						appendimage $wn2d
						modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
						colorscale /c/n=$sc_ColorMap /e/a=rc image=$wn2d
						Label left, sc_y_label
						Label bottom, sc_x_label
						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
						activegraphs+= winname(0,1)+";"
					endif
				endif
			endif
			i+= 1
		while(i<numpnts(sc_CalcWaveNames))
	
	elseif(fastdac == 1)
		// open plots for fastdac
		i=0
		do
			if(fadcattr[i][2] == 48)
				wn = fadcvalstr[i][3]
				graphopen = 0
				graphopen2d = 0
				for(j=0;j<ItemsInList(graphtitle);j=j+1)
					if(stringmatch(wn,stringfromlist(j,graphtitle)))
						graphopen = 1
						activegraphs+= stringfromlist(j,graphnumlist)+";"
						Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
						if(sc_is2d == 0)
							Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
						endif
						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
					endif
					if(sc_is2d)
						if(stringmatch(wn+"_2d",stringfromlist(j,graphtitle)))
							graphopen2d = 1
							activegraphs+= stringfromlist(j,graphnumlist)+";"
							Label /W=$stringfromlist(j,graphnumlist) bottom,  sc_x_label
							Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
							TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
						endif
					endif
				endfor
				if(graphopen && graphopen2d)
				elseif(graphopen2d)  // If only 2D open then open 1D
					display $wn
					setwindow kwTopWin, graphicsTech=0
					Label bottom, sc_x_label
					if(sc_is2d == 0)
						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
					endif
					TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
					activegraphs+= winname(0,1)+";"
				elseif(graphopen) // If only 1D is open then open 2D
					if(sc_is2d)
						wn2d = wn + "_2d"
						display
						setwindow kwTopWin, graphicsTech=0
						appendimage $wn2d
						modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
						colorscale /c/n=$sc_ColorMap /e/a=rc image=$wn2d
						Label left, sc_y_label
						Label bottom, sc_x_label
						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
						activegraphs+= winname(0,1)+";"
					endif
				else // open both
					wn2d = wn + "_2d"
					display $wn
					setwindow kwTopWin, graphicsTech=0
					Label bottom, sc_x_label
					if(sc_is2d == 0)
						Label /W=$stringfromlist(j,graphnumlist) left,  sc_y_label
					endif
					TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
					activegraphs+= winname(0,1)+";"
					if(sc_is2d)
						display
						setwindow kwTopWin, graphicsTech=0
						appendimage $wn2d
						modifyimage $wn2d ctab={*, *, $sc_ColorMap, 0}
						colorscale /c/n=$sc_ColorMap /e/a=rc image=$wn2d
						Label left, sc_y_label
						Label bottom, sc_x_label
						TextBox/W=$stringfromlist(j,graphnumlist)/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat"+num2str(filenum)
						activegraphs+= winname(0,1)+";"
					endif
				endif
			endif
			i+= 1
		while(i<dimsize(fadcvalstr,0))
	endif
	execute("abortmeasurementwindow()")

	cmd1 = "TileWindows/O=1/A=(3,4) "
	cmd2 = ""
	// Tile graphs
	for(i=0;i<itemsinlist(activegraphs);i=i+1)
		window_string = stringfromlist(i,activegraphs)
		cmd1+= window_string +","

		cmd2 = "DoWindow/F " + window_string
		execute(cmd2)
	endfor
	cmd1 += "SweepControl"
	execute(cmd1)
	doupdate
end
 



 // structure to hold DAC and ADC channels to be used in fdac scan.
structure FD_ScanVars
	// Place to store common ScanVariables for scans with FastDAC
	// Equivalent to BD_ScanVars for the BabyDAC
	variable instrID
	
	variable lims_checked  	// This is a flag to make sure that checks on software limits/ramprates/sweeprates have
									// been carried out before executing ramps in record_values

	variable numADCs				// number of ADCs being from (sample rate is split between them)
	variable samplingFreq		// from getFdacSpeed()
	variable measureFreq		// MeasureFreq is sampleFreq/numADCs
	variable sweeprate  		// Sweeprate and numptsx are tied together by measureFreq
									// Note: Does not work for multiple start/end points! 
	variable numptsx				// Linked to sweeprate and measureFreq

	string adcList	 
	
	string channelsx   
	variable startx, finx		// Only here to match BD format and because current use is 1 start/fin value for all DACs.
									// Should use startxs, finxs strings as soon as possible
	string startxs, finxs 		// Use this ASAP because FastDAC supports different start/fin values for each DAC
	variable rampratex
	
	string channelsy
	variable starty, finy  	// OK to use starty, finy for things like rampoutputfdac(...)
	string startys, finys		// Note: Although y channels aren't part of fastdac sweep, store as strings so that check functions work for both x and y 
	variable numptsy, delayy, rampratey	
	
	variable direction		// For storing what direction to scan in (for scanRepeat)
endstructure


structure BD_ScanVars
	// Place to store common ScanVariables for scans with BabyDAC
	// Equivalent to FD_ScanVars for the FastDAC
	// Use SF_set_BDscanVars() as a nice way to initialize scanVars.
   variable instrID
   variable lims_checked
   
   variable startx, finx, numptsx, delayx, rampratex
   variable starty, finy, numptsy, delayy, rampratey
   
   variable sweeprate  // Used for Fastdac Scans  // TODO: Remove this
   
   string channelsx
   string channelsy
   
   variable direction		// For storing what direction to scan in (for scanRepeat)
endstructure

function SF_init_FDscanVars(s, instrID, startx, finx, channelsx, numptsx, rampratex, [sweeprate, starty, finy, channelsy, numptsy, rampratey, delayy, direction, startxs, finxs, startys, finys])
   // Function to make setting up scanVars struct easier. 
   // Note: This is designed to store 2D variables, so if just using 1D you still have to specify x at the end of each variable
   // PARAMETERS:
   // startx, finx, starty, finy -- Single start/fin point for all channelsx/channelsy
   // startxs, finxs, startys, finys -- For passing in multiple start/fin points for each channel as a comma separated string instead of a single start/fin for all channels
   //		Note: Just pass anything for startx/finx if using startxs/finxs
   struct FD_ScanVars &s
   variable instrID
   variable startx, finx, numptsx, rampratex
   variable starty, finy, numptsy, delayy, rampratey
   string channelsx
   string channelsy
   string startxs, finxs, startys, finys
   variable direction, sweeprate

	string starts = "", fins = ""  // Used for getting string start/fin for x and y

	string channels
	channels = SF_get_channels(channelsx, fastdac=1)

	// Set Variables in Struct
   s.instrID = instrID
   s.channelsx = channels
   s.adcList = SFfd_get_adcs()
   
   s.numptsx = numptsx
   s.rampratex = rampratex
   	
   	// Gets starts/fins in FD string format
   	if ((numtype(strlen(startxs)) != 0 || strlen(startxs) == 0) && (numtype(strlen(finxs)) != 0 || strlen(finxs) == 0))  // Then just a single start/end for channelsx
   		s.startx = startx
		s.finx = finx	
	   SFfd_format_setpoints(S.startx, S.finx, S.channelsx, starts, fins)  
		s.startxs = starts
		s.finxs = fins
	elseif (!(numtype(strlen(startxs)) != 0 || strlen(startxs) == 0) && !(numtype(strlen(finxs)) != 0 || strlen(finxs) == 0))
		SFfd_sanitize_setpoints(startxs, finxs, channelsx, starts, fins)
		s.startx = str2num(StringFromList(0, starts, ","))
		s.finx = str2num(StringFromList(0, fins, ","))
		s.startxs = starts
		s.finxs = fins
	else
		abort "If either of startxs/finxs is provided, both must be provided"
	endif
	
   s.sweeprate = paramisdefault(sweeprate) ? NaN : sweeprate
	
	// For repeat scans
   s.direction = paramisdefault(direction) ? 1 : direction
	
	// Optionally set variables for 2D scan
	if (numtype(strlen(channelsy)) != 0 || strlen(channelsy) == 0)  // No Y set at all
		s.starty = NaN
		s.finy = NaN
		s.channelsy = ""
	else
		s.channelsy = SF_get_channels(channelsy, fastdac=1)
		if ((numtype(strlen(startys)) != 0 || strlen(startys) == 0) && (numtype(strlen(finys)) != 0 || strlen(finys) == 0) && !paramisdefault(starty) && !paramisdefault(finy))  // Single start/end for Y
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
	endif

	s.numptsy = paramisdefault(numptsy) ? NaN : numptsy
   s.rampratey = paramisdefault(rampratey) ? NaN : rampratey
   s.delayy = paramisdefault(delayy) ? NaN : delayy

	// Set variables with some calculation
   SFfd_set_numpts_sweeprate(S) 	// Checks that either numpts OR sweeprate was provided, and sets both in SV accordingly
   										// Note: Valid for same start/fin points only (uses S.startx, S.finx NOT S.startxs, S.finxs)
   SFfd_set_measureFreq(S) 		// Sets S.samplingFreq/measureFreq/numADCs	
   
   
	// Make waves for storing sweepgates, starts, ends for both x and y
	SFfd_create_sweepgate_save_info(S)
end




function SF_init_BDscanVars(s, instrID, [startx, finx, channelsx, numptsx, rampratex, delayx, starty, finy, channelsy, numptsy, rampratey, delayy, direction])
   // Function to make setting up scanVars struct easier. 
   // Note: This is designed to store 2D variables, so if just using 1D you still have to specify x at the end of each variable
   struct BD_ScanVars &s
   variable instrID
   variable startx, finx, numptsx, delayx, rampratex
   variable starty, finy, numptsy, delayy, rampratey
   string channelsx
   string channelsy
   variable direction

   s.instrID = instrID
    
    string channels
	
    
   // Set X's			// NOTE: All optional because may be used for just slow axis of FastDac scan for example
	s.startx = paramisdefault(startx) ? NaN : startx
	s.finx = paramisdefault(finx) ? NaN : finx
	if(!paramisdefault(channelsx))
		channels = SF_get_channels(channelsx)
		s.channelsx = channels
	else
		s.channelsx = ""
	endif

	s.numptsx = paramisdefault(numptsx) ? NaN : numptsx
	s.rampratex = paramisdefault(rampratex) ? NaN : rampratex
	s.delayx = paramisdefault(delayx) ? NaN : delayx
   
   // Set Y's
   s.starty = paramisdefault(starty) ? NaN : starty
   s.finy = paramisdefault(finy) ? NaN : finy
	if(!paramisdefault(channelsy))
		channels = SF_get_channels(channelsy)
		s.channelsy = channels
	else
		s.channelsy = ""
	endif
	
	s.numptsy = paramisdefault(numptsy) ? NaN : numptsy
   s.rampratey = paramisdefault(rampratey) ? NaN : rampratey
   s.delayy = paramisdefault(delayy) ? NaN : delayy
   s.direction = paramisdefault(direction) ? 1 : direction 
end