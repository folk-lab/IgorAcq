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



Function AddLegend(wav,param)
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

	string wvname;wvname=stringfromlist(0,imagenamelist("",";"));TextBox/C/N=text1/F=0/A=MT/E wvname


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

function plot2d_heatmap(wave wav)

	//plots the repeats against the sweeps for dataset cscurrent_2d

	variable num
	string dataset
	string wvname

	wvname=nameOfWave(wav)

	wave wav = $wvname



	display; //start with empty graph
	appendimage wav //append image of data
	ModifyImage $wvname ctab= {*,*,Turbo,0} //setting color (idk why it prefers the pointer)
	ColorScale /A=RC /E width=20 //puts it on the right centre, /E places it outside

	Label bottom "gate(V)"
	Label left "repeats"

	ModifyGraph fSize=24
	ModifyGraph gFont="Gill Sans Light"
	//    ModifyGraph width={Aspect,1.62},height=300
	//	TextBox/C/N=text1/A=MT/E=2 "raw 2D plot of dat" + num2str(num)

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