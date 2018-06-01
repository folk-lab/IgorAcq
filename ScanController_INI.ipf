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

function/s parseINIfile(INIstr)
    string INIstr
    variable line_start=0, line_end=0, type=0, index=0
    string line="", reg="(.*)=(.*)", key="", value="", sectionlist=""

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
                index = addINIstring(line,type)
                sectionlist = addlistitem(num2istr(index),sectionlist,",")
            elseif(type==2) // key/value pair
                splitstring/E=reg line , key, value
                addINIstring(key,type)
                addINIstring(value,type+1)
            endif
        endif
        line_start=line_end+1
    while(line_end>0)
    
    return sectionlist
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
    
    return line_num
end


function sc_loadINIconfig()
    // open setup.ini and setup communication with instruments
    string INIstr
    string sectionlist="", checkstr="", dummy="", section=""
    variable i=0, sc_index=-1, offset=0, server_sub_index=0, index=0

    INIstr = INIfromfile("setup") // setup is the igor symbolic path

    sectionlist = parseINIfile(INIstr)
    wave/t ini_text
    wave ini_type
    // results will be dumped into two waves: ini_text & ini_type
    // a list of section indices is returned
    // ini_text will contain the parsed strings
    // ini_type[i]==1 if the entry is a section title
    // ini_type[i]==2 if the entry is a key
    // ini_type[i]==3 if the entry is a value
	
	// find scancontroller section first
	for(i=0;i<itemsinlist(sectionlist,",");i+=1)
		checkstr = lowerstr(ini_text[str2num(stringfromlist(i,sectionlist,","))])
		if(cmpstr(checkstr[1,strlen(checkstr)-1],"scancontroller")==0)
			sc_index = str2num(stringfromlist(i,sectionlist,","))
			sectionlist = removelistitem(sc_index,sectionlist,",")
			break
		endif
	endfor
	
	if(sc_index>=0)
		setupINIscancontroller(sc_index)
	else
		print "[ERROR]: scancontroller section not found! Add it to setup.ini"
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
	
	// loop over instrument sections
	for(i=0;i<itemsinlist(sectionlist,",");i+=1)
		index = str2num(stringfromlist(i,sectionlist,","))
		section = ini_text[index]
		section = section[1,strlen(section)-1]
		if(cmpstr(section,"serial-instrument"))
			setupINIserial(index,globalRM)
		elseif(cmpstr(section,"gpib-instrument"))
			setupINIgpib(index,globalRM)
		elseif(cmpstr(section,"http-instrument"))
			setupINIhttp(index)
		else
			printf "[WARNING]: Section (%s) not recognised and will be ignored!", ini_text[index]
		endif
	endfor
end

function setupINIscancontroller(sc_index)
	variable sc_index
	string mandatory_keys = "server_url,ftp_port,srv_push,filetype"
	string mandatory_type = "str,var,var,str", key=""
	variable sub_index, mankeyindex=0, mankeycount=0
	wave/t ini_text
	wave ini_type
	
	sub_index = sc_index+1
	do
		if(ini_type[sub_index] == 2 && ini_type[sub_index+1] == 3)
			key = ini_text[sub_index]
			mankeyindex = findlistitem(key,mandatory_keys,",",0,0)
			if(mankeyindex>=0)
				key = "sc_"+key
				if(cmpstr(stringfromlist(mankeyindex,mandatory_type,","),"str"))
					string/g $key = ini_text[sub_index+1]
				elseif(cmpstr(stringfromlist(mankeyindex,mandatory_type,","),"var"))
					variable/g $key = str2num(ini_text[sub_index+1])
				endif
				mankeycount+=1
			else
				printf "[WARNING]: The key (%s) is not supported and will be ignored!", key
			endif
		endif
		sub_index += 1
	while(ini_type(sub_index)>1) // stop at next section
	if(mankeycount!=itemsinlist(mandatory_keys,","))
		print "[ERROR]: Not all mandatory keys were supplied!"
		abort
	endif
end

function setupINIserial(index,globalRM)
	variable index, globalRM
	string mandatory_keys="name,instrID,visa_addresse", mandatory_values = ",,"
	string optional_keys="test_query,init_function", optional_values=","
	variable sub_index = index+1, mankeyindex=0, optkeyindex=0, mankeycount=0
	string key=""
	wave/t ini_text
	wave ini_type
	
	do
		if(ini_type[sub_index] == 2 && ini_type[sub_index+1] == 3)
			key = ini_text[sub_index]
			mankeyindex = findlistitem(key,mandatory_keys,",",0,0)
			optkeyindex = findlistitem(key,optional_keys,",",0,0)
			if(mankeyindex>0)
				mandatory_values = removelistitem(mankeyindex,mandatory_values,",")
				mandatory_values = addlistitem(ini_text[sub_index+1],mandatory_values,",",mankeyindex)
				mankeycount+=1
			elseif(optkeyindex>0)
				optional_values = removelistitem(optkeyindex,optional_values,",")
				optional_values = addlistitem(ini_text[sub_index+1],optional_values,",",optkeyindex)
			else
				printf "[WARNING]: The key (%s) is not supported and will be ignored!", key
			endif
		endif
			sub_index+=1
	while(ini_type[sub_index]>1) // stop at next section
	if(mankeycount!=itemsinlist(mandatory_keys,","))
		print "[ERROR]: Not all mandatory keys were supplied!"
		abort
	else // all mandatory keys were provided! Open instrument communication.
		openserialInstr(globalRM,mandatory_keys,mandatory_values,optional_keys,optional_values)
	endif
end

function setupINIgpib(index,globalRM)
	variable index, globalRM
	string mandatory_keys="name,instrID,visa_addresse", mandatory_values=""
	string optional_keys="test_query,init_function", optional_values=""
	string mandatory_type="str,str,str", optional_type="str,str"
	variable sub_index = index+1
	wave/t ini_text
	wave ini_type
	
	do
	while(ini_type[sub_index]>1) // stop at next section
end

function setupINIhttp(index)
	variable index
	string mandatory_keys="name,instrID", mandatory_values=""
	string optional_keys="test_query,init_function", optional_values=""
	string mandatory_type="str,str", optional_type="str,str"
	variable sub_index = index+1
	wave/t ini_text
	wave ini_type
	
	do
	while(ini_type[sub_index]>1) // stop at next section
end

 // move to ScanController_INSTR
function openserialInstr(globalRM,mandatory_keys,mandatory_values,optional_keys,optional_values)
	variable globalRM
	string mandatory_keys,mandatory_values,optional_keys,optional_values
	variable optkeyindex=0
	string cmd="",response=""
	
	string name = stringfromlist(0,mandatory_values,",")
	string var_name = stringfromlist(1,mandatory_values,",")
	string instrDesc = stringfromlist(2,mandatory_values,",")
	openInstr(var_name,instrDesc,localRM=globalRM,verbose=1,name=name)
	
	nvar instrID = $var_name
	// first call the init_function, then query the instrument
	optkeyindex = findlistitem("init_function",optional_keys,",",0,0)
	if(optkeyindex>0)
		execute(stringfromlist(optkeyindex,optional_keys,","))
	endif
	
	optkeyindex = findlistitem("test_query",optional_keys,",",0,0)
	if(optkeyindex>0)
		cmd = stringfromlist(optkeyindex,optional_keys,",")
		response = queryInstr(instrID, cmd+"\r\n", read_term = "\r\n") // all the term characters!
		if(cmpstr(TrimString(response), "NaN")==0)
			abort
		endif
		printf "\t-- %s responded to %s with: %s\r", name, cmd, response
	else
		print "\t-- No test\r"
	endif
end