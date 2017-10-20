#pragma rtGlobals=1		// Use modern global access method.

// Save all experiment data in native IGOR formats
//
// Waves are saved as .ibw
// Experiments are saved as .pxp
// meta data is dumped into custom .winf files
// 

///////////////////////////////////
//// save waves and experiment ////
///////////////////////////////////

function initSaveFiles([msg])
	//// create/open any files needed to save data 
	//// also save any global meta-data you want  	
	
	string msg
	if(paramisdefault(msg)) // save meta data
		msg=""
	endif
	
	// check winfs path
	newpath /C/O/Q winfs getExpPath("winfs", full=1) // create/overwrite winf path
	SaveScanComments(msg=msg)
	
end

function saveSingleWave(wn)
	// wave with name 'filename' as filename.ibw
	string wn
	
	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	string filename =  "dat" + filenumstr + wn
	
	Save/C/P=data $filename;
	
	svar sc_x_label, sc_y_label
	SaveInitialWaveComments(wn, x_label=sc_x_label, y_label=sc_y_label)
end

function endSaveFiles()
	//// close any files that were created for this dataset
	
end

/////////////////////////////
//// save comments files ////
/////////////////////////////

function /S recordedWaveArray()
	wave /T sc_RawWaveNames, sc_CalcWaveNames
	wave sc_RawRecord, sc_CalcRecord
	string swave=""
	variable i=0
	do
		if(strlen(sc_RawWaveNames[i])!=0 && sc_RawRecord[i]==1)
			swave += "\""+sc_RawWaveNames[i]+"\", "
		endif
		i+=1
	while(i<numpnts(sc_RawWaveNames))
	
	i=0
	do
		if(strlen(sc_CalcWaveNames[i])!=0 && sc_CalcRecord[i]==1)
			swave += "\""+sc_CalcWaveNames[i]+"\", "
		endif
		i+=1
	while(i<numpnts(sc_CalcWaveNames))
	
	return "["+swave[0,strlen(swave)-3]+"]"
end

function /S saveScanComments([msg])
	// msg can be any normal string, it will be saved as a JSON string value
	
	string msg
	string buffer="", jstr=""
	jstr += getExpStatus() // record date, time, wave names, time elapsed...
	
	if (!paramisdefault(msg) && strlen(msg)!=0)
		jstr = addJSONKeyVal(jstr, "comments", strVal=TrimString(msg), addQuotes = 1)
	endif
	
	jstr = addJSONKeyVal(jstr, "logs", strVal=getEquipLogs())
	
	//// save file ////
	nvar filenum
	string extension, filename
	extension = "." + num2istr(unixtime()) + ".winf"
	filename =  "dat" + num2istr(filenum) + extension
	writeJSONtoFile(jstr, filename, "winfs")

	return jstr
end

function /s str2WINF(datname, s)
	// string s to winf file 
	//filename = dat<filenum><datname>.<unixtime>.winf
	string datname, s
	variable refnum
	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	string extension, filename
	extension = "." + num2istr(unixtime()) + ".winf"
	filename =  "dat" + filenumstr + datname + extension
	open /A/P=winfs refnum as filename
	
	do
		if(strlen(s)<500)
			fprintf refnum, "%s", s
			break
		else
			fprintf refnum, "%s", s[0,499]
			s = s[500,inf]
		endif
	while(1)
	close refnum
	
	return filename
end

function /S SaveInitialWaveComments(datname, [title, x_label, y_label, z_label, x_multiplier, y_multiplier, z_multiplier, display_thumbnail])
	variable  x_multiplier, y_multiplier, z_multiplier
	string datname, title, x_label, y_label, z_label, display_thumbnail
	string buffer="", comments=""
	
	// save waveStatus
	string jstr = getWaveStatus(datname)
	
	comments += prettyJSONfmt(jstr) + "\r\r" // record date, time, wave names, time elapsed...
	
	// save plot commands
	// these cannot be JSON strings because of the way ..../measurements looks for them
	// i'm ignoring this in hopes that we can move to HDF5 instead of dealing with it
	string plotcmds=""
	if (paramisdefault(title))
		title = ""
	endif
	plotcmds+="$$ title = "+title+"\r"
	
	if (paramisdefault(x_label))
		x_label = ""
	endif
	plotcmds+="$$ x_label = "+x_label+"\r"
	
	if (paramisdefault(y_label))
		y_label = ""
	endif
	plotcmds+="$$ y_label = "+y_label+"\r"
	
	if (paramisdefault(z_label))
		z_label = ""
	endif
	plotcmds+="$$ z_label = "+z_label+"\r"
	
	if (paramisdefault(x_multiplier))
		x_multiplier = 1.0
	endif
	plotcmds+="$$ x_multiplier = "+num2str(x_multiplier)+"\r"
	
	if (paramisdefault(y_multiplier))
		y_multiplier = 1.0
	endif
	plotcmds+="$$ y_multiplier = "+num2str(y_multiplier)+"\r"
	
	if (paramisdefault(z_multiplier))
		z_multiplier = 1.0
	endif
	plotcmds+="$$ z_multiplier = "+num2str(z_multiplier)+"\r"
	
	if (paramisdefault(display_thumbnail))
		display_thumbnail = "False"
	endif
	plotcmds+="$$ display_thumbnail = "+display_thumbnail+"\r"
	
	comments+=plotcmds

	str2WINF(datname, comments)
end