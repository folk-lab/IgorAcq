#pragma rtGlobals=1		// Use modern global access method.

// Save all experiment data in native IGOR formats
//
// Waves are saved as .ibw
// Experiments are saved as .pxp
// meta data is dumped into custom .winf files
// 

/////////////////////////
////  string utility ////
/////////////////////////

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

///////////////////////////////////
//// save waves and experiment ////
///////////////////////////////////

function saveSingleWave(filename)
	// wave with name 'filename' as filename.ibw
	string filename
	Save/C/P=data $filename;
end

function saveExp()
	// save current experiment as .pxp
	SaveExperiment /P=data
	getCmdHistory()
end

/////////////////////////////
//// save comments files ////
/////////////////////////////

function /S rawWaveStrs()
	wave /T sc_RawWaveNames
	wave sc_RawRecord
	string swave=""
	variable i=0
	do
		if(strlen(sc_RawWaveNames[i])!=0 && sc_RawRecord[i]==1)
			swave += sc_RawWaveNames[i]+", "
		endif
		i+=1
	while(i<numpnts(sc_RawWaveNames))
	return swave[0,strlen(swave)-3]
end

function /S calcWaveStrs()
	wave /T sc_CalcWaveNames
	wave sc_CalcRecord
	string swave=""
	variable i=0
	do
		if(strlen(sc_CalcWaveNames[i])!=0 && sc_CalcRecord[i]==1)
			swave += sc_CalcWaveNames[i]+", "
		endif
		i+=1
	while(i<numpnts(sc_CalcWaveNames))
	return swave[0,strlen(swave)-3]
end

function /s getExpStatus()
	nvar filenum, sweep_t_elapsed
	
	// create header with corresponding .ibw name and date
	string output="", buffer="" 
	
	// date/time info
	sprintf buffer, "dataset:  dat%d*.ibw \r", filenum; output+=buffer
	sprintf buffer, "filenum: %d \r", filenum; output+=buffer
	sprintf buffer, "data path:  %s \r", ReplaceString(":", getExpPath("data"), "/"); output+=buffer // path to data 
	sprintf buffer, "system info: %s \r", ReplaceString(":",igorinfo(3),"="); output+=buffer // system information
	sprintf buffer, "measurement completed:  %s %s \r", Secs2Date(DateTime, 1), Secs2Time(DateTime, 3); output+=buffer // time of file save
	sprintf buffer, "time elapsed:  %.2f s \r", sweep_t_elapsed; output+=buffer
	
	// scan control info
	sprintf buffer, "raw data waves:  %s \r", rawWaveStrs(); output+=buffer 
	sprintf buffer, "calculated data waves:  %s \r", calcWaveStrs(); output+=buffer

	return output
end

function /s getWaveStatus(datname)
	string datname
	nvar filenum
	
	// create header with corresponding .ibw name and date
	string output="", buffer="" 
	
	// date/time info
	sprintf buffer, "wave name:  dat%d%s.ibw \r", filenum, datname; output+=buffer
	sprintf buffer, "filenum: %d \r", filenum; output+=buffer
	sprintf buffer, "data path:  %sdat%d%s.ibw \r", ReplaceString(":", getExpPath("data"), "/"), filenum, datname; output+=buffer
	
	// wave info
	//check if wave is 1d or 2d
	variable dims
	if(dimsize($datname, 1)==0)
		dims =1
	elseif(dimsize($datname, 1)!=0 && dimsize($datname, 2)==0)
		dims = 2
	else
		dims = 3
	endif
	
	if (dims==1)
		// save some data
		wavestats/Q $datname
		sprintf buffer, "wave stats: length=%d, dx=%.2e, mean=%.2e, std=%.2e", dimsize($datname,0), dimdelta($datname, 0), V_avg, V_sdev
	elseif(dims==2)
		wavestats/Q $datname
		sprintf buffer, "wave stats: columns=%d, rows=%d, dx=%.2e, dy=%.2e, mean=%.2e, std=%.2e", dimsize($datname,0), dimsize($datname,1), dimdelta($datname, 0), dimdelta($datname, 1), V_avg, V_sdev
	else
		sprintf buffer, "no stats for waves with dimentionality > 2"
	endif
	output+=buffer

	return output
end

function /S saveScanComments([msg, logs])
	// msg must be a string
	// logs should be formatted like a series of commands
	// logs = "function(param1, param2); second_function(param)"
	// any params used in 
	
	string msg, logs
	variable numlogs = 12
	string buffer="", comments=""
	comments += getExpStatus() + "\r" // record date, time, wave names, time elapsed...
	
	if (!paramisdefault(msg) && strlen(msg)!=0)
		comments += "comments:  \r" + removeAllWhitespace(msg) + "\r\r" // record any comments
	endif
	
	comments += "logs: \r"
	if (!paramisdefault(logs) && strlen(logs)!=0)
		string command
		string /G sc_loggable=""
		variable N = strlen(logs)
		variable i = 0, ind
		do
			ind = strsearch(logs, ";",0)
			if(ind==0)
				// strange case where the string starts with ;
				// get rid of the ; and move on
				logs = logs[1,inf]
				N = strlen(logs)
				continue
			elseif(ind == N-1)
				// string ends with ;
				// this is the final command
				command = logs[0,N-2]
				N = 0 
			elseif(ind==-1 && strlen(logs)!=0)
				// no ; left
				// if the string is not empty, it must be a command
				command = logs
				N = 0
			else
				// there must be a ; somewhere in the middle
				command = logs[0,ind-1]
				logs = logs[ind,inf]
				N = strlen(logs)
			endif
			Execute/Q/Z "sc_loggable="+command
			if(strlen(sc_loggable)!=0)
				comments += removeAllWhitespace(sc_loggable)+"\r\r"
			else
				comments += removeAllWhitespace("command failed to log anything: "+command)+"\r\r"
			endif
			sc_loggable=""
		while(N>0)
		comments = comments[0,strlen(comments)-2]
	endif
	str2WINF("", comments)
end

function /S SaveInitialWaveComments(datname, [title, x_label, y_label, z_label, x_multiplier, y_multiplier, z_multiplier, display_thumbnail])
	variable  x_multiplier, y_multiplier, z_multiplier
	string datname, title, x_label, y_label, z_label, display_thumbnail
	string buffer="", comments=""
	
	// save waveStatus
	comments += getWaveStatus(datname) + "\r\r" // record date, time, wave names, time elapsed...
	
	// save plot commands
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
	
	// leave room for comments
	comments += "\r"+"comments:  \r"
	
	str2WINF(datname, comments)
end


// these should live in the procedures for the instrument
// that way not all of the procedures need to be loaded for this WINF thing to compile correctly

//function/S GetSRSStatus(srs)
//	variable srs
//	string winfcomments = "", buffer = "";
//	sprintf buffer "SRS %s:\r\tLock-in  Amplitude = %.3f V\r\tTime Constant = %.2fms\r\tFrequency = %.2fHz\r\tSensitivity=%.2fV\r\tPhase = %.2f\r", GetSRSAmplitude(srs), GetSRSTimeConstInSeconds(srs)*1000, GetSRSFrequency(srs),getsrssensitivity(srs, realsens=1), GetSRSPhase(srs)
//	winfcomments += buffer
//	
//	return winfcomments
//end
//
//function /S GetIPSStatus()
//	string winfcomments = "", buffer = "";
//	sprintf buffer, "IPS:\r\tMagnetic Field = %.4f mT\r\tSweep Rate = %.4f mT/min\r", GetField(),   GetSweepRate(); winfcomments += buffer
//	
//	return winfcomments
//end