#pragma rtGlobals=1		// Use modern global access method.
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

macro display2d(file2d)
        string file2d
   
        variable filenum, chanx, chany      
        string dacvalbox, dacvalname
        variable i=0
        

        
        filenum = str2num(file2d[3,5])
        dacvalname = "dat"+num2str(filenum)+"dacvals"
        chanx = $dacvalname[16]
        chany = $dacvalname[17]

//create graph
        
       display; appendimage $file2d
       ModifyImage $file2d ctab= {*,*,YellowHot,0}
       ModifyGraph width=300,height=300
       ModifyGraph axOffset(left)=8,axOffset(bottom)=3
       
// add axis labels

       Label bottom "DAC"+num2str(chanx)
	ModifyGraph lblMargin(bottom)=40
       Label left "DAC"+num2str(chany)
       ModifyGraph lblMargin(left)=75
       
// add colorscale
	
	ColorScale/C/N=text1/A=MC image=$file2d
	ColorScale/C/N=text1/X=-79.00/Y=0.00

//add datefile name

	TextBox/C/N=text2/A=MC file2d
	TextBox/C/N=text2/X=-75/Y=-57.00
	
// add DAC channel values
	dacvalbox = "\\Z10"
	do
		if(i == 7)
			dacvalbox +="dac"+num2str(i)+":"+num2str($dacvalname[i])+"\r"
		else
			dacvalbox +="dac"+num2str(i)+":"+num2str($dacvalname[i])+" "
		endif
		i+=1
	while (i<16)        
	TextBox/C/N=text0/A=MC dacvalbox
	TextBox/C/N=text0/X=-20/Y=-72.00

	SavePICT/O/P=SpinDiff/E=-5/B=288 as file2d+".png"
//	SaveGraphCopy /O/P=SpinDiff as file2d+".pxp"

end

macro display1d(file)
        string file
   
        variable filenum, chan
        string dacvalbox, dacvalname
        variable i=0    
     
        filenum = str2num(file[3,5])
        dacvalname = "dat"+num2str(filenum)+"dacvals"
        chan = $dacvalname[16]

//create graph
        
       display $file
       ModifyGraph width=400,height=300
       ModifyGraph axOffset(left)=0,axOffset(bottom)=3
       
// add axis labels

       Label bottom "DAC"+num2str(chan)
	ModifyGraph lblMargin(bottom)=40
       
//add datefile name

	TextBox/C/N=text2/A=MC file
	TextBox/C/N=text2/X=0/Y=50.00
	
// add DAC channel values
	dacvalbox = "\\Z10"
	do
		if(i == 7)
			dacvalbox +="dac"+num2str(i)+":"+num2str($dacvalname[i])+"\r"
		else
			dacvalbox +="dac"+num2str(i)+":"+num2str($dacvalname[i])+" "
		endif
		i+=1
	while (i<16)        
	TextBox/C/N=text0/A=MC dacvalbox
	TextBox/C/N=text0/X=0/Y=-72.00

	SavePICT/O/P=SpinDiff/E=-5/B=288 as file+".png"
//	SaveGraphCopy /O/P=SpinDiff as file2d+".pxp"

end


macro waterfall(file2d)
        string file2d
        
        silent 1;pauseupdate
        
        variable rows, cols, i,start, final
        string colname
        rows = dimsize($file2d,0)
        cols = dimsize($file2d,1)
        start=dimoffset($file2d,0)
        final=start+dimdelta($file2d,0)*(rows-1)
        display
        do
                colname = "col" + num2str(i) + "_" + file2d
                make /o/n=(rows) $colname
                setscale/I x start,final,$colname
                $colname[]=$file2d[p][i]
                appendtograph $colname
                 i += 1
        while (i<cols)
end

macro waterfallt(file2d)
        string file2d
        
        variable rows, cols, i
        string colname
        rows = dimsize($file2d,1)
        cols = dimsize($file2d,0)
        
        display
        do
                colname = "col" + num2str(i) + "_" + file2d
                make /o/n=(rows) $colname
                $colname[]=$file2d[i][p]
                appendtograph $colname
                i += 2
        while (i<cols)
end

macro average2d(file2d)
        string file2d
        
        variable rows, cols, i
        string averagename
        rows = dimsize($file2d,0)
        cols = dimsize($file2d,1)

	  averagename="averagetrace"+file2d
	  make /o/n=(rows) $averagename
	 $averagename=0
        i=0
         do
      		   $averagename+=$file2d[p][i]
                i += 1
        while (i<cols)

        $averagename/=cols
        
        display $averagename
end

macro delta_waves()
variable i=0

do 
delta[i]=(dat607g[i]-dat604g[100-i])/(dat607g[i]+dat604g[100-i])
i=i+1
while (i<=100)
end 

function makecolorful([rev, nlines])	//nlines = # of lines share the same color
	variable rev, nlines
	variable num=0, index=0,colorindex
	string tracename
	string list=tracenamelist("",";",1)
	colortab2wave rainbow  // yellowhot
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
		group=index/nlines-1
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
				colorindex=round(n*floor(index/nlines)/group)
			else
				colorindex=round(n*(group-floor((index)/nlines))/group)
			endif
		endif
		ModifyGraph rgb($tracename)=(M_colors[colorindex][0],M_colors[colorindex][1],M_colors[colorindex][2])
		index+=1
	while(index<=num)
	legend
end


macro PlotScan(filenum1)	//plot series scans
        variable filenum1
        string notestring
        variable i=0
        string myfile

        display
        do
                myfile="dat"+num2str(filenum1+i)+"g9x"
                appendtograph $myfile
                if(mod(i,2)==0)
                	modifygraph rgb($myfile)=(0,0,65280)
                endif
                i+=1
        while(i<4)
        //TextBox/C/N=text0/A=MC notestring
end

macro plotting_vsfield()
closeallgraphs()
display g1x vs  field
append/r g1y vs  field
ModifyGraph rgb(g1x)=(0,0,0)
ModifyGraph mode(g1y)=2

//display  g2x; append/r g2y
//ModifyGraph rgb(g2x)=(0,0,0)
//ModifyGraph mode(g2y)=2


display g3x vs field; append/r g3y vs  field
ModifyGraph rgb(g3x)=(0,0,0)
ModifyGraph mode(g3y)=2

display g4x vs  field; append/r g4y vs  field
ModifyGraph rgb(g4x)=(0,0,0)
ModifyGraph mode(g4y)=2

display; appendimage g1x2d

display; appendimage g3x2d

display; appendimage g4x2d

display Tmc



TileWindows/A=(2,3)/O=1/W=(30,30,1000,550)


endmacro

macro plotting()
closeallgraphs()
display g1x
append/r g1y
ModifyGraph rgb(g1x)=(0,0,0)
ModifyGraph mode(g1y)=2

display  g2x; append/r g2y
ModifyGraph rgb(g2x)=(0,0,0)
ModifyGraph mode(g2y)=2


display g3x; append/r g3y
ModifyGraph rgb(g3x)=(0,0,0)
ModifyGraph mode(g3y)=2

display g4x; append/r g4y
ModifyGraph rgb(g4x)=(0,0,0)
ModifyGraph mode(g4y)=2


display Tmc
display R1s
display R2s
display leakage





TileWindows/A=(2,4)/O=1/W=(30,30,2000,550)


endmacro



