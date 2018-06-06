#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function sc_loadINIconfig()
    // open setup.ini and setup communication with instruments
    string INIstr
    string sectionlist="", checkstr="", dummy="", section="", instr_names=""
    variable i=0, sc_index=-1, offset=0, server_sub_index=0, index=0, gui_index=-1

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

	// find scancontroller and GUI sections first
	for(i=0;i<itemsinlist(sectionlist,",");i+=1)
		checkstr = lowerstr(ini_text[str2num(stringfromlist(i,sectionlist,","))])
		if(cmpstr(checkstr[1,strlen(checkstr)-1],"scancontroller")==0)
			sc_index = str2num(stringfromlist(i,sectionlist,","))
			sectionlist = removelistitem(sc_index,sectionlist,",")
		elseif(cmpstr(checkstr[1,strlen(checkstr)-1],"gui")==0)
			gui_index = str2num(stringfromlist(i,sectionlist,","))
			sectionlist = removelistitem(sc_index,sectionlist,",")
		endif
	endfor

	// setup scancontroller variables
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
		if(cmpstr(section,"visa-instrument"))
			instr_names += setupINIvisa(index,globalRM)
		elseif(cmpstr(section,"http-instrument"))
			instr_names += setupINIhttp(index)
		else
			printf "[WARNING]: Section (%s) not recognised and will be ignored!", ini_text[index]
		endif
	endfor

	// setup GUI windows
	if(gui_index>=0)
		setupINIgui(gui_index,instr_names)
	endif
end

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
            line=TrimString(INIstr[line_start,line_end-1])
        else // this is the last line
            line=TrimString(INIstr[line_start,strlen(INIstr)-1])
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

function setupINIgui(gui_index, instr_names)
	variable gui_index
	string instr_names
	variable sub_index
	wave/t ini_text
	wave ini_type

	sub_index = gui_index+1
	do
		if(ini_type[sub_index] == 2 && ini_type[sub_index+1] == 3 && findlistitem(ini_text[sub_index],instr_names,",",0,0))
			execute(ini_text[sub_index+1])
		endif
		sub_index+=1
	while(ini_type(sub_index)>1 || sub_index>numpnts(ini_type))
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
	while(ini_type(sub_index)>1 || sub_index>numpnts(ini_type)) // stop at next section
	if(mankeycount!=itemsinlist(mandatory_keys,","))
		print "[ERROR]: Not all mandatory keys were supplied!"
		abort
	endif
end

function/s setupINIvisa(index,globalRM)
	variable index, globalRM
	string mandatory_keys="name,instrID,visa_addresse", mandatory_values = ",,"
	string optional_keys="test_query,init_function,baudrate,stopbits,databits,parity,readterm,timeout", optional_values=",,,,,,,,"
	variable sub_index = index+1, mankeyindex=0, optkeyindex=0, mankeycount=0
	string key="", name=""
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
			if(cmpstr(key,"name")==0)
				name = key
			endif
		endif
			sub_index+=1
	while(ini_type[sub_index]>1 || sub_index>numpnts(ini_type)) // stop at next section
	if(mankeycount!=itemsinlist(mandatory_keys,","))
		print "[ERROR]: Not all mandatory keys are supplied!"
		abort
	else // all mandatory keys are provided! Open instrument communication.
		openINIvisa(globalRM,mandatory_keys,mandatory_values,optional_keys,optional_values)
	endif

	return name+","
end

function/s setupINIhttp(index)
	variable index
	string mandatory_keys="name,instrID,url", mandatory_values=",,"
	string optional_keys="test_query,init_function", optional_values=","
	variable sub_index = index+1, mankeyindex=0, optkeyindex=0, mankeycount=0
	string key="", name=""
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
			if(cmpstr(key,"name")==0)
				name = key
			endif
		endif
			sub_index+=1
	while(ini_type[sub_index]>1 || sub_index>numpnts(ini_type)) // stop at next section
	if(mankeycount!=itemsinlist(mandatory_keys,","))
		print "[ERROR]: Not all mandatory keys are supplied!"
		abort
	else // all mandatory keys are provided!
		string/g $stringfromlist(1,mandatory_values,",") = $stringfromlist(2,mandatory_values,",")
	endif
	return name+","
end

function openINIvisa(globalRM,mandatory_keys,mandatory_values,optional_keys,optional_values)
	variable globalRM
	string mandatory_keys,mandatory_values,optional_keys,optional_values
	variable optkeyindex=0
	string cmd="",response=""

	string name = stringfromlist(0,mandatory_values,",")
	string var_name = stringfromlist(1,mandatory_values,",")
	string instrDesc = stringfromlist(2,mandatory_values,",")
	openInstr(var_name,instrDesc,localRM=globalRM,verbose=1,name=name)

	nvar instrID = $var_name

    // look for serial communication constants and set them
    for(i=0;i<itemsinlist(optional_keys);i+=1)
        optkey = stringfromlist(i,optional_keys,",")
        setINIvisaparameter(instrID,optkey,stingfromlist(i,optional_values,","))
    endfor
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
		printf "\t-- No test\r"
	endif
end

function setINIvisaparameter(instrID,optkey,optvalue)
    string optkey, optvalue
    variable status=0

    strswitch(optkey)
        case "baudrate":
            status = visaSetBaudRate(instrID, str2num(optvalue))
            break
        case "stopbits":
            status = visaSetStopBits(instrID, str2num(optvalue))
             break
        case "databits":
            status = visaSetDataBits(instrID, str2num(optvalue))
            break
        case "parity":
            status = visaSetParity(instrID, str2num(optvalue))
            break
        case "readterm":
            status = visaSetReadTerm(instrID, optvalue)
            break
        case "timeout":
            status = visaSetTimeout(instrID, str2num(optvalue))
        default:
            // ignore the key!
    endswitch
    if(status<0)
        VISAerrormsg("viSetAttribute", instrID, status)
	endif
end

function randomInt()
	variable from=-1e6, to=1e6
	variable amp = to - from
	return floor(from + mod(abs(enoise(100*amp)),amp+1))
end
