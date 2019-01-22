#pragma rtGlobals=1		// Use modern global access method.
#include <AxisSlider>
#include <CopyImageSubset>

////////////////////
//// FETCH DATA ////
////////////////////

function ud()

    string infile = wavelist("*",";","")
    string ibwlist =  indexedfile(data,-1,".ibw")
    string currentIBW
    variable numIBW = itemsinlist(ibwlist), i=0, wnExists, numloaded=0
    for(i=0; i<numIBW; i+=1)

        currentIBW = StringFromList(i,ibwlist)
        wnExists = FindListItem(currentIBW[0,(strlen(currentIBW)-5)], infile,  ";")

        if (wnExists==-1)
            LoadWave/Q/H/P=data currentIBW
            numloaded+=1
        endif

    endfor
    
    print numloaded, "waves uploaded"

end

function udh5()

	string infile = wavelist("*",";","") // get wave list
	string hdflist = indexedfile(data,-1,".h5") // get list of .h5 files
	
	string currentHDF="", currentWav="", datasets="", currentDS
	variable numHDF = itemsinlist(hdflist), fileid=0, numWN = 0, wnExists=0
	
	variable i=0, j=0, numloaded=0
	
	for(i=0; i<numHDF; i+=1) // loop over h5 filelist
	
	   currentHDF = StringFromList(i,hdflist)
		 
		HDF5OpenFile/P=data /R fileID as currentHDF
		HDF5ListGroup /TYPE=2 /R=1 fileID, "/" // list datasets in root group
		datasets = S_HDF5ListGroup
		numWN = itemsinlist(datasets)
		currentHDF = currentHDF[0,(strlen(currentHDF)-4)]
		for(j=0; j<numWN; j+=1) // loop over datasets within h5 file
			currentDS = StringFromList(j,datasets)
			currentWav = currentHDF+currentDS
		   wnExists = FindListItem(currentWav, infile,  ";")
		   if (wnExists==-1)
		   	// load wave from hdf
		   	HDF5LoadData /Q /IGOR=-1 /N=$currentWav fileID, currentDS
		   	numloaded+=1
		   endif
		endfor
		HDF5CloseFile fileID
	endfor

   print numloaded, "waves uploaded"
end

//////////////////
//// PLOTTING ////
//////////////////

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



function fits(data2d, coef)
	wave data2d, coef
	variable g0, Vw, V0, i=0
	
	make /o/n=(dimsize(data2d,1)) results

	do
		FuncFit CBpeak coef data2d[][i]
		results[i]=coef[1]
		i+=1
	while (i<dimsize(data2d,1))
	
//	FuncFit CBpeak coef 
end
