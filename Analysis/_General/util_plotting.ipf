#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

Menu "Graph"
	"Close All Graphs/9", CloseAllGraphs()
End


Function CloseAllGraphs()
	String name
	do
		name = WinName(0,1) // name of the front graph
		if (strlen(name) == 0)
			break // all done
		endif
		DoWindow/K $name // Close the graph
	while(1)
End


Function CloseAllTables()
	String name
	do
		name = WinName(0,2) // name of the front table
		if (strlen(name) == 0)
			break // all done
		endif
		DoWindow/K $name // Close the table
	while(1)
End



Function AddLegend(wav, param)
    wave wav        
    string param 
    string graphName
    
        graphName = WinName(0, 1)   // Top graph
    
    
    String list = TraceNameList(graphName, ";", 1)
    String legendText = ""
    Variable numItems = ItemsInList(list)
    Variable i
    for(i=0; i<numItems; i+=1)
        String item = StringFromList(i, list)+"--"+param+num2str(wav[i])
//        if (CmpStr(item,"wave1") == 0)
//            continue            // Skip this trace
//        endif
        String itemText
        sprintf itemText, "\\s(%s) %s", item, item
        if (i > 0)
            legendText += "\r"      // Add CR
        endif
        legendText += itemText
    endfor
    Legend/K/N=text0
    Legend/C/N=MyLegend/W=$graphName legendText
    Legend/C/N=text0/J/A=MT/E=0
End



function displayplot2D(start, endnum,whichdat,[delta,xnum, shiftx, shifty])
	variable start, endnum
	string whichdat
	variable delta, xnum, shiftx, shifty
	if(paramisdefault(delta))
		delta=1
	endif
	if(delta==0)
		abort
	endif

	if(paramisdefault(shiftx))
		shiftx=0
	endif
	if(paramisdefault(shifty))
		shifty=0
	endif
		
	variable i=0, totoffx=0, totoffy=0
	string st
	//udh5()
	Display /W=(35,53,960,830)
	i=start
	do
		st="dat"+num2str(i)+whichdat
		appendtograph $st
		wavestats /q $st
		totoffx=shiftx*mod((i-start)/delta,xnum)
		totoffy=shifty*floor((i-start)/delta/xnum)-v_avg
		ModifyGraph offset($st)={totoffx,totoffy}
		i+=delta
	while (i<=endnum)
	makecolorful()
	legend
	Legend/C/N=text0/J/A=RC/E

end


function displayplot(start, endnum,whichdat,[delta,shiftx, shifty])
	variable start, endnum
	string whichdat
	variable delta, shiftx, shifty
	if(paramisdefault(delta))
		delta=1
	endif
	if(delta==0)
		abort
	endif

	if(paramisdefault(shiftx))
		shiftx=0
	endif
	if(paramisdefault(shifty))
		shifty=0
	endif
		
	variable i=0, totoffx=0, totoffy=0
	string st
	//udh5()
	Display /W=(35,53,960,830)
	i=start
	do
		st="dat"+num2str(i)+whichdat
		appendtograph $st
		ModifyGraph offset($st)={totoffx,totoffy}
		totoffx=totoffx+shiftx
		totoffy=totoffy+shifty
		i+=delta
	while (i<=endnum)
	makecolorful()
	legend
	Legend/C/N=text0/J/A=RC/E

end


function create_colour_wave()
	// assumes 'newpath colour_data' points to path holding colour waves. 
	// colour palletes downloaded from here: https://www.kennethmoreland.com/color-advice
	// can then be used i.e. ModifyImage wave0 ctab= {*,*,colour_fast,0}
	
	string colour_names
	colour_names = "bent_CW;black_body;ext_kindlmann;fast;inferno;kindlmann;plasma;smooth_CW;viridis"
	
	int number_of_colour = itemsinList(colour_names, ";")
	string csv_name, wave_name, colour_name
	
	int i
	for (i = 0; i < number_of_colour; i++)
		
		colour_name = stringFromList(i, colour_names, ";")
		
		csv_name = colour_name + ".csv"
		wave_name = "colour_" + colour_name
		
		
		loadwave /Q/J/K=1/M/N/P=colour_data csv_name
		wave wave0
		duplicate /o/RMD=[1,][1,3] wave0 $wave_name
		
		wave colour_wave = $wave_name
		colour_wave *= 65535
	endfor

end



function makecolorful([rev, nlines])
	variable rev, nlines
	variable num=0, index=0,colorindex
	string tracename
	string list=tracenamelist("",";",1)
	colortab2wave rainbow
	wave M_colors
	variable n=dimsize(M_colors,0), group
	do
		tracename=stringfromlist(index, list)
		if(strlen(tracename)==0)
			break
		endif
		index+=1
	while(1)
	num=index-1
	if( !ParamIsDefault(nlines))
		group=index/nlines
	endif
	index=0
	do
		tracename=stringfromlist(index, list)
		if( ParamIsDefault(nlines))
			if( ParamIsDefault(rev))
				colorindex=round(n*index/num)
			else
				colorindex=round(n*(num-index)/num)
			endif
		else
			if( ParamIsDefault(rev))
				colorindex=round(n*ceil((index+1)/nlines)/group)
			else
				colorindex=round(n*(group-ceil((index+1)/nlines))/group)
			endif
		endif
		if(colorindex>99)
			colorindex=99
		endif
		ModifyGraph rgb($tracename)=(M_colors[colorindex][0],M_colors[colorindex][1],M_colors[colorindex][2])
		index+=1
	while(index<=num)

end


Function QuickColorSpectrum2()                            // colors traces with 12 different colors
	String Traces    = TraceNameList("",";",1)               // get all the traces from the graph
	Variable Items   = ItemsInList(Traces)                   // count the traces
	Make/FREE/N=(11,3) colors = {{65280,0,0}, {65280,43520,0}, {0,65280,0}, {0,52224,0}, {0,65280,65280}, {0,43520,65280}, {0,15872,65280}, {65280,16384,55552}, {36864,14592,58880}, {0,0,0},{26112,26112,26112}}
	Variable i
	for (i = 0; i <DimSize(colors,1); i += 1)
		ModifyGraph rgb($StringFromList(i,Traces))=(colors[0][i],colors[1][i],colors[2][i])      // set new color offset
	endfor
End



function plot2d_heatmap(wav, [x_label, y_label])
	//plots the repeats against the sweeps for dataset cscurrent_2d
	wave wav

	string x_label, y_label
	
	x_label = selectstring(paramisdefault(x_label), x_label, "Gate (mV)")
	y_label = selectstring(paramisdefault(y_label), y_label, "Gate (mV)")

	variable num
	string wave_name

	wave_name = nameOfWave(wav)
	wave wav = $wave_name

	display //start with empty graph
	appendimage wav //append image of data
	ModifyImage $wave_name ctab= {*, *, Turbo,0} //setting color (idk why it prefers the pointer)
	ColorScale /A=RC /E width=20 //puts it on the right centre, /E places it outside

	Label bottom x_label
	Label left y_label

	ModifyGraph fSize=24
	ModifyGraph gFont="Gill Sans Light"
end


function setcolorscale2d(percent)
	variable percent
	variable x1, y1, x2, y2, xs, ys, minz, maxz, i=0, j=0
	string filename
	filename=csrwave(A)
	wave mywave = $filename
	x1=pcsr(A)
	y1=qcsr(A)
	x2=pcsr(B)
	y2=qcsr(B)
	duplicate /o/r=[x1,x2][y1,y2] mywave kjhdfgazs7f833jk
	wavestats/q kjhdfgazs7f833jk
	killwaves kjhdfgazs7f833jk
	ModifyImage '' ctab= {V_min,percent*V_max,PlanetEarth,0}
	//killwaves mywave
end


Function ApplyFakeWaterfall(graphName, dx, dy, hidden)      // e.g., ApplyFakeWaterfall("Graph0", 2, 100, 1)
	//hidden= h
	//h =0: Turns hidden line off.
	//h =1: Uses painter's algorithm.
	//h =2: True hidden.
	//h =3: Hides lines with bottom removed.
	//h =4: Hides lines using a different color for the bottom. When specified, the top color is the normal color for lines and the bottom color is set using ModifyGraph negRGB=(r,g,b).

	String graphName    // Name of graph or "" for top graph
	Variable dx, dy     // Used to offset traces to create waterfall effect
	Variable hidden     // If true, apply hidden line removal
	
	String traceList = TraceNameList(graphName, ";", 1)
	Variable numberOfTraces = ItemsInLIst(traceList)
	
	Variable traceNumber
	for(traceNumber=0; traceNumber<numberOfTraces; traceNumber+=1)
		String trace = StringFromList(traceNumber, traceList)
		Variable offsetX = (numberOfTraces-traceNumber-1) * dx
		Variable offsetY = (numberOfTraces-traceNumber-1) * dy
		ModifyGraph/W=$graphName offset($trace)={offsetX,offsetY}
		ModifyGraph/W=$graphName plusRGB($trace)=(65535,65535,65535)    // Fill color is white
		if (hidden)
			ModifyGraph/W=$graphName mode($trace)=7, hbFill($trace)=1       // Fill to zero, erase mode
		else
			ModifyGraph/W=$graphName mode($trace)=0                     // Lines between points
		endif
	endfor
End


function plot_waterfall(w, x_label, y_label, [y_spacing, offset, datnum, subtract_line, current_min_max, diff, diff_smooth, plot_every_n])
	wave w
	string x_label, y_label, current_min_max
	variable y_spacing, offset, datnum, subtract_line, diff, diff_smooth, plot_every_n
	
	datnum = paramisdefault(datnum) ? 0 : datnum // alternate_bias OFF is default
	subtract_line = paramisdefault(subtract_line) ? 0 : subtract_line // subtract_line OFF is default
	current_min_max = selectstring(paramisdefault(current_min_max), current_min_max, "0;0")
	diff = paramisdefault(diff) ? 0 : diff // diff OFF is default
	diff_smooth = paramisdefault(diff_smooth) ? 0 : diff_smooth // diff OFF is default
	plot_every_n = paramisdefault(plot_every_n) ? 1 : plot_every_n // plot every trace is default


	variable offset_val
	string legend_text = ""
	string legend_check = ""
	
	variable current_min = str2num(stringFromList(0, current_min_max))
	variable current_max = str2num(stringFromList(1, current_min_max))
	variable y1, y2, x1, x2, m, c
	
	display
	setWindow kwTopWin, graphicsTech=0		
	duplicate/o w tempwave
	duplicate /o /RMD=[][1] tempwave slice
	wave slice
	create_x_wave(tempwave)
	wave x_wave
	
	int num_rows = dimsize(tempwave, 0)
	
	variable i, count
	for (i=0; i<dimsize(w, 1); i++)
		slice[] = tempwave[p][i]
		
		if (subtract_line != 0)
			if (current_min == current_max)
				y1 = tempwave[0][i]
				y2 = tempwave[inf][i]
				x1 = x_wave[0]
				x2 = x_wave[inf]
			else
				y1 = current_min
				y2 = current_max
				findlevel /q slice, y1; x1 = x2pnt(slice, V_LevelX)
				findlevel /q slice, y2; x2 = x2pnt(slice, V_LevelX)
			endif
			
			m = (y2-y1)/(x2-x1)
			c = y2 - m*x2
			
			tempwave[][i] -= (m*x_wave[p] + c)
		endif
		
		offset_val = tempwave[round(num_rows/2)][i]
		if (offset != 0)
			tempwave[][i] -= offset_val
		endif
		
		if (diff == 0)
			tempwave[][i] = tempwave[p][i] + y_spacing*i
		else
			differentiate slice
			if (diff_smooth != 0)
				smooth diff_smooth, slice
			endif
			tempwave[][i] = slice[p] + y_spacing*i
		endif
		
		
		if (mod(i, plot_every_n) == 0)
			if (i==0)
				legend_check = ""
			else
				legend_check = "#" + num2str(count)
			endif
			legend_text =  legend_text + "\s(tempwave" + legend_check + ") Current = " +  num2str(offset_val) + " nA\r"
			AppendToGraph tempwave[][i]
			count += 1
		endif
		
	endfor
	scg_setupGraph1D(WinName(0,1), x_label, y_label=y_label, datnum=datnum)
	
	legend/C/N=text0/J/B=1 legend_text
	makecolorful()
end






function DisplayDiff(w, [x_label, y_label, filenum, numpts])
	wave w
	string x_label, y_label
	variable filenum, numpts
	
	x_label = selectstring(paramisdefault(x_label), x_label, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	numpts = paramisdefault(numpts) ? 150 : numpts	
	
	string window_name = ""
	sprintf window_name, "%s__differentiated", nameofwave(w)
	string wn = ""
	sprintf wn, "%s__diffx", nameofwave(w)	

	wave tempwave = Diffwave(w, numpts=numpts)

	dowindow/k $window_name
	display/N=$window_name
	appendimage tempwave
	ModifyImage tempwave ctab= {*,*,VioletOrangeYellow,0}
	TextBox/W=$window_name/C/N=textid/A=LT/X=1.00/Y=1.00/E=2 window_name	
	Label left, y_label
	Label bottom, x_label
	if (filenum > 0)
		string text
		sprintf text "Dat%d", filenum
		TextBox/W=$window_name/C/N=datnum/A=LT text
	endif
end


function/wave DiffWave(w, [numpts])
	wave w
	variable numpts
	
	numpts = paramisdefault(numpts) ? 150 : numpts
	
	duplicate/o w, tempwave
	resample/DIM=0 /down=(ceil(dimsize(w,0)/numpts)) tempwave
	differentiate/DIM=0 tempwave	
	return tempwave
end


function DisplayMultiple(datnums, name_of_wave, [diff, x_label, y_label])
// Plots data from each dat on same axes... Will differentiate first if diff = 1
	wave datnums
	string name_of_wave, x_label, y_label
	variable diff

	if (paramisDefault(x_label))
		struct ScanVars S
		try
			scv_getLastScanVars(S)
			x_label = S.x_label
		catch
			x_label = ""
		endtry
	endif
	if (paramisDefault(y_label))
		struct ScanVars S2
		try
			scv_getLastScanVars(S2)   
			y_label = S2.y_label
		catch
			y_label = ""
		endtry
	endif

//	x_label = selectstring(paramisdefault(x_label), x_label, "")
//	y_label = selectstring(paramisdefault(y_label), y_label, "")

	string window_name
	sprintf window_name, "Dats%dto%d", datnums[0], datnums[numpnts(datnums)-1]
	dowindow/k $window_name
	display/N=$window_name
	TextBox/W=$window_name/C/N=textid/A=LT/X=1.00/Y=1.00/E=2 window_name	
	
	
	variable i = 0, datnum
	string wn
	string tempwn
	for(i=0; i < numpnts(datnums); i++)
		datnum = datnums[i]
//		sprintf wn, "dat%d%s", datnum, name_of_wave
//		sprintf tempwn, "tempwave_%s", wn
		wn = "dat" + num2str(datnum) + name_of_wave
		tempwn = "tempwave_" + wn
		duplicate/o $wn, $tempwn
		if (diff == 1)
			wave tempwave = diffwave($tempwn)
			duplicate /o tempwave $tempwn
			wave tempwave = $tempwn

		else 
			wave tempwave = $tempwn
		endif
		appendimage/W=$window_name tempwave
		ModifyImage/W=$window_name $tempwn ctab= {*,*,VioletOrangeYellow,0}
	endfor
	Label left, y_label
	Label bottom, x_label

end


function DisplayWave(w, [x_label, y_label])
	wave w
	string x_label, y_label
	
	x_label = selectstring(paramisdefault(x_label), x_label, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	
	string name, wn = nameofwave(w)
	sprintf name "%s_", wn
	
	svar sc_colormap
	dowindow/k $name
	display/N=$name
	setwindow kwTopWin, graphicsTech=0
	appendimage $wn
	modifyimage $wn ctab={*, *, $sc_ColorMap, 0}
//	colorscale /c/n=$sc_ColorMap /e/a=rc
	ColorScale/C/N=colorbar/A=RC/E image=$wn
	Label left, y_label
	Label bottom, x_label
	TextBox/W=$name/C/N=textid/A=LT/X=1.00/Y=1.00/E=2 name
	
end


function Display2DWaterfall(w, [offset, x_label, y_label, plot_every_n, y_min, y_max, plot_contour])
	wave w
	variable offset
	string x_label, y_label
	int plot_every_n, y_min, y_max, plot_contour
	
	variable num_repeats = DimSize(w, 1)
	int apply_offset = paramisdefault(offset) ? 0 : 1 // forcing theta OFF is default
	plot_every_n = paramisdefault(plot_every_n) ? 1 : plot_every_n // plotting every trace is default
	y_min = paramisdefault(y_min) ? 0 : y_min // y_min index 0 is default
	y_max = paramisdefault(y_max) ? dimsize(w, 1) : y_max // y_max index 0 is default
	plot_contour = paramisdefault(plot_contour) ? 0 : plot_contour // plotting contour OFF is default
	
	
	x_label = selectstring(paramisdefault(x_label), x_label, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	
	string name, wn = nameofwave(w)
	sprintf name "%s_", wn
	
	dowindow/k $name
	display/N=$name
	TextBox/W=$name/C/N=textid/A=LT/X=1.00/Y=1.00/E=2 name
	

	variable offset_to_apply
	duplicate  /o w wave_2d
	wave wave_2d
	
	duplicate  /o w wave_2d_contour
	wave wave_2d_contour
	
	
	variable i
	for(i = 0; i < num_repeats; i++)

		if (apply_offset == 1)
			offset_to_apply = i * offset
		else
			offset_to_apply = 0
		endif
		
		wave_2d[][i] = wave_2d[p][i] + offset_to_apply
		
		
		if ((mod(i, plot_every_n) == 0) && (i >= y_min) && (i < y_max))
   		AppendToGraph/W=$name wave_2d[][i]
   	endif
   	
	endfor
	
	makecolorful()
	
	string wavename_2d_contour = ""
	///// adding contour lines /////
	variable count = 0
	for(i = 0; i < num_repeats; i++)

		if (apply_offset == 1)
			offset_to_apply = i * offset
		else
			offset_to_apply = 0
		endif
		
   	
   	if ((mod(i, plot_every_n) == 0) && (i >= y_min) && (i < y_max) && (plot_contour == 1))
   	
//   		wave_2d_contour[][i] = wave_2d_contour[p][i]*0  + wave_2d_contour[0][i] + offset_to_apply
   		wave_2d_contour[][i] = wave_2d[0][i]
   		AppendToGraph/W=$name wave_2d_contour[][i]
   		
   		wavename_2d_contour = "wave_2d_contour#" + num2str(count)
   		
   		ModifyGraph rgb($wavename_2d_contour) = (30583,30583,30583), lstyle($wavename_2d_contour)=3, lsize($wavename_2d_contour)=0.1
   		
   		count += 1
   	endif
   	
	endfor
	
	
	

	Label /W=$name left y_label
	Label /W=$name bottom x_label
	

	
end


function Display3VarScans(wavenamestr, [v1, v2, v3, uselabels, usecolorbar, diffchargesense, switchrowscols, scanset, showentropy])
// This function is for displaying plots from 3D/4D/5D scans (i.e. series of 2D scans where other parameters are changed between each scan)
//v1, v2, v3 are looking for indexes e.g. "3" or range of indexs e.g. "2, 5" of the other parameters to display
//v1gmax, v2gmax, v3gmax below are the number of different values used for each parameter. These need to be hard coded
//datstart below needs to be hardcoded as the first dat of the sweep array
//uselabels also requires some hard coded variables to be set up below
//Usecolorbar = 0 does not show colorscale, = 1 shows it
//diffchargesense differentiates charge sensor data in the y direction (may want to change direction of differentiation later)

// TODO:Currently works for 5D, will need some adjusting to work for 3D, 4D.
	string wavenamestr //Takes comma separated wave names e.g. "g1x2d, v5dc"
	string v1, v2, v3 // Charge Sensor Right, Chare Sensor total, Small Dot Plunger
	variable uselabels, usecolorbar, diffchargesense, switchrowscols, scanset, showentropy //set to 1 to use //TODO: make rows cols be right all the time


	variable datstart, v1start, v2start, v3start, v1step, v2step, v3step
	variable/g v1gmax, v2gmax, v3gmax

	if (paramisdefault(scanset))
		print "Using Default parameters"
		//	////////////////// SET THESE //////////////////////////////////////////////////
		//	datstart = 328
		//	v1gmax = 7; v2gmax = 5; v3gmax = 6 //Have to make global to use NumVarOrDefault...
		//	v1start = -200; v2start = -550; v3start = -200
		//	v1step = -50; v2step = -50; v3step = -100
		//	make/o/t varlabels = {"CSR", "CStotal", "SDP"}
		//	make/o/t axislabels = {"SDL", "SDR"} //y, x
		//	///////////////////////////////////////////////////////////////////////////////

		//	///////////////////////////////////////////////////////////////////////////////

	else
		switch (scanset)
			case 1:
				// Right side of NikV2 15th feb 2020
				datstart = 88
				v1gmax = 5; v2gmax = 5; v3gmax = 2 //Have to make global to use NumVarOrDefault...
				v1start = -100; v2start = -0; v3start = -300
				v1step = -100; v2step = -100; v3step = -500
				make/o/t varlabels = {"RCB", "RP", "RCSQ"}
				make/o/t axislabels = {"RCSS", "RCT"} //y, x
				break
			case 2:
				datstart = 139
				v1gmax = 8; v2gmax = 4; v3gmax = 1 //Have to make global to use NumVarOrDefault...
				v1start = 0; v2start = -100; v3start = 0
				v1step = -25; v2step = -50; v3step = 0
				make/o/t varlabels = {"LP", "LCSS", ""}
				make/o/t axislabels = {"LCT", "LCB"} //y, x
				break
			case 3:
				datstart = 337
				v1gmax = 2; v2gmax = 6; v3gmax = 4 //Have to make global to use NumVarOrDefault...
				v1start = 10; v2start = -200; v3start = -450
				v1step = 90; v2step = -20; v3step = -50
				make/o/t varlabels = {"Bias", "Nose", "Plunger"}
				make/o/t axislabels = {"CSS", "RC1"} //y, x
				break				
		endswitch
	endif


	usecolorbar = paramisdefault(usecolorbar) ? 1 : usecolorbar
	diffchargesense = paramisdefault(diffchargesense) ? 1 : diffchargesense
	make/o/t varnames = {"v1g", "v2g", "v3g"}
	make/o/t varrangenames = {"v1range", "v2range", "v3range"}
	make/o/t varlistvals = {"v1vals", "v2vals", "v3vals"}

	variable check=0, i=0, j=0, k=0

	if (paramisdefault(v1))
		v1=""
		check+=1
	endif
	if (paramisdefault(v2))
		v2=""
		check+=1
	endif
	if (paramisdefault(v3))
		v3=""
		check+=1
	endif
	string/g v1g = v1, v2g = v2, v3g = v3 //Have to make global to use StrVarOrDefault because cant use $ inside function becuse Igor is stupid
	if (check == 3)
		abort "Select one or more values to see graphs"
	endif
	check = 0

	variable fixedvarval, n

	string v, str

	do
		v = StrVarOrDefault(varnames[i], "") // Makes v = one of the input string variables  equivalent to v = $varnames[i]
		if (itemsinlist(v, ",") == 1)
			fixedvarval = i
			check += 1
		endif
		i+=1
	while (i<3)
	if (check == 0)
		abort "Must specify value of one variable at least"
	endif


	i=0; j=0
	do
		str = varrangenames[i];	make/o/n=2 $str = NaN; wave vrname = $str    // Igor's stupid way of making a wave with a name from a text wave
		str = varlistvals[i]; make/o $str = NaN; wave vlname = $str

		v = StrVarOrDefault(varnames[i], "")
		vrname = str2num(StringFromList(p, v, ","))
		wavestats/q vrname
		n = numvarOrDefault(varnames[i]+"max", -1)-1 //-1 at end because counting starts at 0. Should never have to default to -1
		if (V_npnts == 0)
			vrname = {0, n} //effectively default to max range
		elseif (V_npnts == 1)
			vrname[1] = vrname[0] //Just same value twice so that calc vals works
		endif
		do  //fills val wave with all values wanted
			vlname[j] = vrname[0] + j
			j+=1
		while (j < vrname[1]-vrname[0]+1)
		redimension/n=(vrname[1]-vrname[0]+1) vlname
		if (vrname[1] > n)
			printf "Max range for %s is %d, automatically set to max\n", varlabels[i], n
			vrname[1] = n
		endif
		j=0
		i+=1
	while (i<numpnts(varnames))


	make/o datlist = NaN
	make/o varvals = NaN
	make/o varindexs = NaN
	variable c=0 //for counting what place in datlist
	i=0; j=0; k=0
	do  // Makes list of datnums to display
		do
			do
				str = varlistvals[0]; wave w0 = $str //v1vals = fast
				str = varlistvals[1]; wave w1 = $str //v2vals = medium
				str = varlistvals[2]; wave w2 = $str //v3vals = slow

				datlist[c] = datstart+w0[k]+w1[j]*v1gmax+w2[i]*v2gmax*v1gmax
				if (uselabels!=0)
					varindexs[c] = {{w0[k]}, {w1[j]}, {w2[i]}}
					varvals[c] = {{v1start+w0[k]*v1step}, {v2start+w1[j]*v2step}, {v3start+w2[i]*v3step}}
				endif
				c+=1
				k+=1
			while (k < numpnts(w0))
			k=0
			j+=1
		while (j < numpnts(w1))
		j=0
		i+=1
	while (i < numpnts(w2))
	redimension/n=(numpnts(w0)*numpnts(w1)*numpnts(w2), -1) datlist, varvals, varindexs //just removes NaNs at end of waves
	string rowcolvars = "012"
	rowcolvars = replacestring(num2str(fixedvarval), rowcolvars, "")
	str = varlistvals[str2num(rowcolvars[0])]; wave w0 = $str
	str = varlistvals[str2num(rowcolvars[1])]; wave w1 = $str
	//// TODO: make this unnecessary
	variable rows = numpnts(w0), cols = numpnts(w1)
	if (switchrowscols == 1)
		variable temp
		temp = rows
		rows = cols
		cols = temp
	endif
	//
	tilegraphs(datlist, wavenamestr, rows = rows, cols = cols, axislabels=axislabels, varlabels=varlabels, varvals=varvals, varindexs=varindexs, uselabels=uselabels, usecolorbar=usecolorbar, diffchargesense=diffchargesense, showentropy=showentropy)
end




function tilegraphs(dats, wavenamesstr, [rows, cols, axislabels, varlabels, varvals, varindexs, uselabels, usecolorbar, diffchargesense, showentropy]) // Need all of varlabels, varvals, varindexs to use them
	// Takes list of dats and tiles 4x4 by default or if specified
	// Designed to work with display3VarScans although it should work with other things. Might help to look at display3varscans to understand this though.
	wave dats
	string wavenamesstr //Can be one or multiple wavenames separated by "," e.g. "g1x2d, v5dc"
	variable rows, cols
	wave/t axislabels, varlabels
	wave varvals, varindexs
	variable uselabels, usecolorbar, diffchargesense, showentropy
	svar sc_colormap

	abort "Can this use the ScanController Graphs stuff now?"

	rows = paramisdefault(rows) ? 4 : rows
	cols = paramisdefault(cols) ? 4 : cols

	make/o/t/n=(itemsinlist(wavenamesstr, ",")) wavenames
	variable i=0, j=0
	make/o/t/n=(itemsinlist(wavenamesstr, ",")) wavenames
	do
		wavenames[i] = removeleadingwhitespace(stringfromlist(i, wavenamesstr, ","))
		i+=1
	while (i<(itemsinlist(wavenamesstr, ",")))
	string wn = "", activegraphs = "", wintext
	i=0;j=0
	do
		do
			sprintf wn, "dat%d%s", dats[i], wavenames[j]
			if (cmpstr(wn[-2,-1], "2d", 0))	// case insensitive
				if (diffchargesense!=0 && (stringmatch(wn, "*Ch0*") == 1 || stringmatch(wn, "*sense*")))
					duplicate/o $wn $wn+"diff"
					wn = wn+"diff"
					differentiate/dim=1 $wn
				endif
				display
				setwindow kwTopWin, enablehiresdraw=3
				appendimage $wn
				modifyimage $wn ctab={*, *, $sc_ColorMap, 0}//, margin(left)=40,margin(bottom)=25,gfSize=10, margin(right)=3,margin(top)=3
				//modifyimage $wn gfMult=75
				modifygraph gfMult=75, margin(left)=35,margin(bottom)=25, margin(right)=3,margin(top)=3
				if (usecolorbar != 0)
					colorscale /c/n=$sc_ColorMap /e/a=rc
				endif
				Label left, axislabels[0]
				Label bottom, axislabels[1]
				TextBox/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat="+num2str(dats[i])

				//TextBox/C/N=vars/A=rb/X=0.00/Y=0.00/E=2 "v1=4, v2=5, v3=6"
				if (uselabels!=0)
					sprintf wintext, "v1=%d, v2=%d, v3=%d, %s=%.3GmV, %s=%.3GmV, %s=%.3GmV: %s", varindexs[i][0], varindexs[i][1], varindexs[i][2], varlabels[0], varvals[i][0], varlabels[1], varvals[i][1], varlabels[2], varvals[i][2], wn
					DoWindow/T kwTopWin, wintext
				endif
			else
				display $wn
				setwindow kwTopWin, enablehiresdraw=3
				TextBox/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 "Dat="+num2str(dats[i])

			endif
			activegraphs+= winname(0,1)+";"
			j+=1
		while (j < numpnts(wavenames))
		j=0
		i+=1
	while (i< numpnts(dats))
	string cmd1, cmd2
	variable maxw=33*cols, maxh=33*rows
	maxw = maxw > 100 ? 100 : maxw
	maxh = maxh > 100 ? 100 : maxh
	sprintf cmd1, "TileWindows/O=1/A=(%d,%d)/r/w=(0,0,%d, %d) ", rows, cols*itemsinlist(wavenamesstr, ","), maxw, maxh
	cmd2 = ""
	string window_string
	for(i=0;i<itemsinlist(activegraphs);i=i+1)
		window_string = stringfromlist(i,activegraphs)
		cmd1+= window_string +","

		cmd2 = "DoWindow/F " + window_string
		execute(cmd2)
	endfor
	execute(cmd1)
end



function plot_differential_conductance(current_wave, [smoothing_factor, x_label, y_label])
	wave current_wave
	variable smoothing_factor
	string x_label, y_label
	
	x_label = selectstring(paramisdefault(x_label), x_label, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	smoothing_factor = paramisDefault(smoothing_factor) ? 1 : smoothing_factor

	string graph_name = "dIdVGraph"
	svar sc_colormap
	
	string wn = nameofwave(current_wave) + "_dIdV"
	duplicate/o current_wave $wn
	wave w = $wn
	variable smooth_num = round(smoothing_factor*DimSize(w, 0)/20)
	smooth/dim=0/E=3 smooth_num, w
	differentiate w
	w[,smooth_num] = NaN
	w[dimsize(w, 0)-smooth_num,] = NaN

	
	// Display the data
	KillWindow/z $graph_name
	display/k=1 /N=$graph_name

	setwindow kwTopWin, graphicsTech=0
	appendimage $wn
	modifyimage $wn ctab={*, *, $sc_ColorMap, 0}
	ColorScale/C/N=colorbar/A=RC/E image=$wn
	Label left, y_label
	Label bottom, x_label
	TextBox/W=$graph_name/C/N=textid/A=LT/X=1.00/Y=1.00/E=2 wn
//	setaxis bottom, $wn[x][smooth_num], *
	
end



function interpolate_polyline(poly_y, poly_x, [num_points_to_interp])
	// interpolate poly_y and poly_x to form evernly space poly_y_interp and poly_x_interp
	// use graphWaveDraw to create rough set of points which creates the waves w_ypoly1 and w_xpoly1 e.g. interpolate_polyline(w_ypoly1, w_xpoly1)
	wave poly_x, poly_y
	int num_points_to_interp
	num_points_to_interp = paramisdefault(num_points_to_interp) ? 1000 : num_points_to_interp
	
	variable num_vals = dimsize(poly_x, 0)
	wave linspaced = linspace(poly_x[0], poly_x[num_vals - 1], num_points_to_interp, make_global = 0)
	duplicate /o linspaced poly_x_interp
	
	Interpolate2 /T=1 /I=3 /Y=poly_y_interp/X=poly_x_interp poly_x, poly_y //linear interpolation
	
end


function/WAVE  get_z_from_xy(wave_2d, y_wave, x_wave)
	// return 1d wave where the y values are picked by the z value at each coordinate from y_wave and x_wave
	wave wave_2d, y_wave, x_wave
	
	duplicate /o y_wave z_wave
	wave z_wave
	
	variable num_vals = dimsize(y_wave, 0)
	variable x_val, y_val, x_coord, y_coord
	
	variable i
	for (i = 0; i < num_vals; i++)
		x_val = x_wave[i]
		y_val = y_wave[i]
		
		x_coord = scaletoindex(wave_2d, x_val, 0)
		y_coord = scaletoindex(wave_2d, y_val, 1)
		z_wave[i] = wave_2d[x_coord][y_coord]
		
	endfor
	
	SetScale/I x x_wave[0], x_wave[inf], "", z_wave
	
	return z_wave
end



function get_multiple_line_paths(wave_2d, y_wave, x_wave, [width_y, width_x, num_traces])
	wave wave_2d, y_wave, x_wave
	variable width_y, width_x
	int num_traces
	
	width_y = paramisdefault(width_y) ? 10 : width_y
	width_x = paramisdefault(width_y) ? 0 : width_x
	num_traces = paramisdefault(width_y) ? 10 : num_traces
	
	///// create empty 2d wave to store multiple rows of the line paths
	variable num_vals = dimsize(y_wave, 0)
	make /o/n=(num_vals, num_traces) line_path_2d_z
	make /o/n=(num_vals, num_traces) line_path_2d_y
	make /o/n=(num_vals, num_traces) line_path_2d_x
	
	
	///// calculate delta y to pull off each of the line paths
	variable delta_y = (width_y*2) / num_traces
	duplicate /o y_wave y_wave_offset
	y_wave_offset[] = y_wave[p] - width_y
	wave y_wave_offset
	
	///// calculate delta c to pull off each of the line paths
	variable delta_x = (width_x*2) / num_traces
	duplicate /o x_wave x_wave_offset
	x_wave_offset[] = x_wave[p] - width_x
	wave x_wave_offset
	
	
	variable i, offset
	for (i = 0; i < num_traces; i++)
	
		///// calculate the new y_wave_offset and x_wave_offset
		y_wave_offset[] = y_wave_offset[p] + delta_y
		x_wave_offset[] = x_wave_offset[p] + delta_x
		
		wave z_wave = get_z_from_xy(wave_2d, y_wave_offset, x_wave_offset)
		
		line_path_2d_z[][i] = z_wave[p]
		line_path_2d_y[][i] = y_wave_offset[p]
		line_path_2d_x[][i] = x_wave_offset[p]
	
	endfor
end


function plot_multiple_line_paths(wave_2d, y_wave, x_wave, [width_y, width_x, offset, num_traces, plot_contour, make_markers])
	wave wave_2d, y_wave, x_wave
	variable width_y, width_x, offset
	int num_traces, plot_contour, make_markers
	
	width_y = paramisdefault(width_y) ? 10 : width_y
	width_x = paramisdefault(width_y) ? 0 : width_x
	offset = paramisdefault(offset) ? 0.001 : offset
	num_traces = paramisdefault(width_y) ? 10 : num_traces
	plot_contour = paramisdefault(plot_contour) ? 1 : plot_contour
	make_markers = paramisdefault(make_markers) ? 0 : make_markers
	
	get_multiple_line_paths(wave_2d, y_wave, x_wave, width_y = width_y, width_x = width_x, num_traces = num_traces)
	
	wave line_path_2d_z, line_path_2d_y, line_path_2d_x
	
	///// display original 2d image with each trace
	string window_name = "line_path_traces"
	dowindow/k $window_name
	display/N=$window_name
	appendimage /W=$window_name wave_2d
	variable num_columns = dimsize(line_path_2d_y, 1)
	variable i
	for (i = 0; i < num_columns; i++)
		appendtograph /W=$window_name line_path_2d_y[][i] vs line_path_2d_x[][i]
		if (make_markers == 1)
			ModifyGraph mode=3, marker=13, mrkThick=2, rgb=(65535,0,52428)
		endif
	endfor
	
	Display2DWaterfall(line_path_2d_z, offset = offset, plot_every_n = 1, plot_contour = plot_contour)
end



function get_multiple_line_paths_int(wave_2d, y_wave, x_wave, [width_y, width_x, num_traces])
	wave wave_2d, y_wave, x_wave
	variable width_y, width_x
	int num_traces
	
	width_y = paramisdefault(width_y) ? 10 : width_y
	width_x = paramisdefault(width_y) ? 0 : width_x
	num_traces = paramisdefault(width_y) ? 10 : num_traces
	
	string wave_name = nameofwave(wave_2d)
	
	get_multiple_line_paths(wave_2d, y_wave, x_wave, width_y = width_y, width_x = width_x, num_traces = num_traces)
	
	wave line_path_2d_z, line_path_2d_y, line_path_2d_x
	
	///// display original 2d image with each trace
	string window_name = "line_path_traces"
	dowindow/k $window_name
	display/N=$window_name
	appendimage /W=$window_name wave_2d
	ModifyImage /W=$window_name $wave_name ctab= {-0.005, 0.005, RedWhiteGreen, 0}
	variable num_columns = dimsize(line_path_2d_y, 1)
	variable i
	for (i = 0; i < num_columns; i++)
		appendtograph /W=$window_name line_path_2d_y[][i] vs line_path_2d_x[][i]
	endfor
	
	///// integrate line paths and remove y offset
	Integrate line_path_2d_z /D = line_path_2d_z_int
	
	//***offset_2d_traces(line_path_2d_z_int) this will not compile
	
	// display integrated line traces
	
	window_name = "line_path_traces_z_int"
	dowindow/k $window_name
	display/N=$window_name
	appendimage /W=$window_name line_path_2d_z_int
	ModifyImage /W=$window_name line_path_2d_z_int ctab= {*,*,RedWhiteGreen,0}	
end

