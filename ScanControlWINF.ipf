#pragma rtGlobals=1		// Use modern global access method.

// Some useful functions for creating *.winf files that will add labels and proper scaling to 
// the plots found at https://qdot-server.phas.ubc.ca/measurements

// utility functions //

function unixtime()
	// returns the current unix time in seconds
	return DateTime - date2secs(1970,1,1) - date2secs(-1,-1,-1)
end

function /s str2WINF(datname, s)
	// string s to winf file 
	// this assumes you have a path called data for your experiment
	//filename = dat<filenum><datname>.<unixtime>.winf
	string datname, s
	variable refnum
	nvar filenum
	
	string extension, filename, datapath, winfpath
	extension = "." + num2istr(unixtime()) + ".winf"
	filename =  "dat" + num2istr(filenum) + datname + extension
	pathinfo data; datapath=S_path
	winfpath = datapath+"winfs:"
	
	//	GetFileFolderInfo /Q /Z=1 winfpath // check if directory exists
	//	if (V_flag!=0)
	//		// create folder
	//	endif

	newpath /C/O/Q winfs winfpath // easier just to add/create a path
	
	open /A refnum as winfpath+filename
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

// functions to remove white space //

function /S removeAllWhitespace(str)
	string str
	str = RemoveLeadingWhitespace(str)
	str = RemoveTrailingWhitespace(str)
	return str
end

Function/S RemoveLeadingWhitespace(str)
    String str
 
    if (strlen(str) == 0)
        return ""
    endif
 
    do
        String firstChar= str[0]
        if (IsWhiteSpace(firstChar))
            str= str[1,inf]
        else
            break
        endif   
    while (strlen(str) > 0)
 
    return str
End
 
Function/S RemoveTrailingWhitespace(str)
    String str
 
    if (strlen(str) == 0)
        return ""
    endif
 
    do
        String lastChar = str[strlen(str) - 1]
        if (IsWhiteSpace(lastChar))
            str = str[0, strlen(str) - 2]
        else
        	break
        endif
    while (strlen(str) > 0)
    return str
End
 
Function IsWhiteSpace(char)
    String char
 
    return GrepString(char, "\\s")
End

// save comments files //

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
	nvar filenum, sc_scanstarttime
	
	// create header with corresponding .ibw name and date
	string output="", buffer="" 
	
	// date/time info
	sprintf buffer, "dataset:  dat%d*.ibw \r", filenum; output+=buffer
	sprintf buffer, "filenum: %d \r", filenum; output+=buffer
	pathinfo data
	sprintf buffer, "data path:  %s \r", ReplaceString(":", S_path, "/"); output+=buffer // path to data 
	sprintf buffer, "system info: %s \r", ReplaceString(":",igorinfo(3),"="); output+=buffer // system information
	sprintf buffer, "measurement completed:  %s %s \r", Secs2Date(DateTime, 1), Secs2Time(DateTime, 3); output+=buffer // time of file save
	sprintf buffer, "time elapsed:  %.2f s \r", datetime-sc_scanstarttime; output+=buffer
	
	// scan control info
	sprintf buffer, "raw data waves:  %s \r", rawWaveStrs(); output+=buffer // path to data 
	sprintf buffer, "calculated data waves:  %s \r", calcWaveStrs(); output+=buffer // path to data

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
	pathinfo data
	sprintf buffer, "data path:  %sdat%d%s.ibw \r", ReplaceString(":", S_path, "/"), filenum,datname; output+=buffer
	
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
	// return "\r" + comments
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
	//return "\r"+comments
end

function getSlackNotice(username, [message, channel, botname, min_time])
	// this function will send a notification to Slack
	// username = your slack username
	
	// message = string to include in Slack message
	// channel = slack channel to post the message in
	//            if no channel is provided a DM will be sent to username
	// botname = slack user that will post the message, defaults to @qdotbot
	// emoji = emoji that will be used as the bots avatar, defaults to :the_horns:
	// min_time = if time elapsed for this current scan is less than min_time no notification will be sent
	//					defaults to 60 seconds
	string username, channel, message, botname
	variable min_time
	nvar filenum, sc_scanstarttime, sc_abortsweep
	svar slack_url
	string msg="", buffer="", payload=""
	
	//// check if I need a notification ////
	variable t_elapsed = datetime-sc_scanstarttime;
	if (paramisdefault(min_time))
		min_time = 60.0 // seconds
	endif
	
	if(t_elapsed < min_time)
		return 0 // no notification if min_time is not exceeded
	endif
	
	if(sc_abortsweep)
		return 0 // no notification if sweep was aborted by the user
	endif
	//// end notification checks //// 
	
	if (!paramisdefault(username))
		output += "<@"+username+">\r"
	endif
	
	if (!paramisdefault(message) && strlen(message)>0)
		output += RemoveTrailingWhitespace(message) + "\r"
	endif
		
	// date/time info
	sprintf buffer, "dat%d completed:  %s %s \r", filenum, Secs2Date(DateTime, 1), Secs2Time(DateTime, 3); output+=buffer 
	sprintf buffer, "time elapsed:  %.2f s \r", datetime-sc_scanstarttime; output+=buffer
	
	// build payload
	sprintf buffer, "{\"text\":\"%s\"", output; payload+=buffer
	if (!paramisdefault(botname))
		sprintf buffer, ", \"username\":\"%s\"", botname; payload+=buffer
	endif
	if (!paramisdefault(channel))
		sprintf buffer, ", \"channel\":\"@%s\"", channel; payload+=buffer
	endif
	
	payload += "}"
	
	URLRequest /DSTR=payload url=slack_url, method=post
	if (V_flag == 0)    // No error
        if (V_responseCode != 200)  // 200 is the HTTP OK code
            print "Slack post failed!"
            return 0
        else
            return 1
        endif
    else
        print "HTTP connection error. Slack post not attempted."
        return 0
    endif
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
