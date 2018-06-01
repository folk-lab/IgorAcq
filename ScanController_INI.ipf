#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function/s INIfromfile(path)
    // read INI file into string
    // filename must be setup.ini
    // assumes general INI rules: https://en.wikipedia.org/wiki/INI_file
    string path
    variable refnum
    string buffer="", INIstr = "", filename = "setup.ini"

    open /r/z/p=$path refnum as filename
    if(v_flag!=0)
        print "[ERROR]: Could not read the setup file! It might not exist."
        return ""
    endif

    do
        freadline refnum, buffer
        if(strlen(buffer)==0)
            break
        endif
        INIstr+=buffer
    while(1)
    close refnum

    return INIstr
end

function parseINIfile(INIstr)
    string INIstr
    variable line_start=0, line_end=0, type=0
    string line="", reg="(.*)=(.*)", key="", value=""

    // make the waves that will hold the parsed data
    make/t/o/n=0 ini_text
    make/o/n=0 ini_type

    // read until "\r"
    do
        line_end = strsearch(INIstr, "\r", line_start)
        if(line_end>0)
            line=INIstr[line_start,line_end-1]
        else // this is the last line
            line=INIstr[line_start,strlen(INIstr)]
        endif
        type = getINItype(line)
        if(type!=0) // if type=0 then it's a comment or some BS, ignore it!
            if(type==1) // section
                addINIstring(line,type)
            elseif(type==2) // key/value pair
                splitstring/E=reg line , key, value
                addINIstring(key,type)
                addINIstring(value,type+1)
            endif
        endif
        line_start=line_end+1
    while(line_end>0)
end

function getINItype(INIstr)
    string INIstr
    variable type=0

    INIstr = TrimString(INIstr)

    if(cmpstr(INIstr[0],"#")==0 || cmpstr(INIstr[0],";")==0) // comment
        return 0
    elseif(cmpstr(INIstr[0],"[")==0) // section
        return 1
    elseif(strsearch(INIstr, "=",0)>0) // key/value pair
        return 2
    else // some BS
        return 0
    endif
end

function addINIstring(str,type)
    string str
    variable type
    variable line_num=0

    wave/t ini_text
    wave ini_type
    // redimension waves
    line_num = numpnts(ini_text)+1
    redimension /n=(line_num) ini_text
    redimension /n=(line_num) ini_type

    // add new valuew
    ini_text[line_num-1] = str
    ini_type[line_num-1] = type
end


function sc_loadINIconfig()
    // open setup.ini and setup communication with instruments
    string INIstr
    string sectionlist="", checkstr="", dummy=""
    variable i=0, server_index=-1, offset=0, server_sub_index=0

    INIstr = INIfromfile("setup") // setup is the igor symbolic path

    parseINIfile(INIstr)
    wave/t ini_text
    wave ini_type
    // results will be dumped into two waves: ini_text & ini_type
    // ini_text will contain the parsed strings
    // ini_type[i]==1 if the entry is a section title
    // ini_type[i]==2 if the entry is a key
    // ini_type[i]==3 if the entry is a value
    
    // find section indies
	do
		findvalue/i=1/s=(offset) ini_type
		if(v_value>0)
			sectionlist = addlistitem(num2istr(v_value),sectionlist,",")
		endif
		offset = v_value
	while(v_value>0)
	
	// find server section first
	for(i=0;i<itemsinlist(sectionlist,",");i+=1)
		checkstr = lowerstr(ini_text[str2num(stringfromlist(i,sectionlist,","))])
		if(cmpstr(checkstr[1,strlen(checkstr)-1],"server")==0)
			server_index = str2num(stringfromlist(i,sectionlist,","))
			sectionlist = removelistitem(server_index,sectionlist,",")
			break
		endif
	endfor
	
	if(server_index>=0)
		server_sub_index = server_index+1
		do
			if(ini_type[server_sub_index] == 2 && ini_type[server_sub_index+1] == 3)
				dummy = "sc"+ini_text[server_sub_index]
				try
					variable/g $dummy = str2num(ini_text[server_sub_index+1])
				catch
					string/g $dummy = ini_text[server_sub_index+1]
				 endtry
			endif
			server_sub_index += 1
		while(server_sub_index>1)
	else
		print "[ERROR]: server section not found! Add it to setup.ini"
		abort
	endif
	
	// all sections left must be instruments!
    
   // open resource manager
	nvar /z globalRM
	if(!nvar_exists(globalRM))
		// if globalRM does not exist
		// open RM and create the global variable
		openResourceManager()
		nvar globalRM
	else
		// if globalRM does exist
		// close all connection
		// reopen everything
		closeAllInstr()
		openResourceManager()
	endif
	
end
