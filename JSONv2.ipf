#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function/s TextWaveToStrArray2(w) //change name when done!
	wave/t w	
	string list, checkStr, escapedStr
	variable i=0
	
	wfprintf list, "\"%s\",", w	// semicolon-separated list
	for(i=0;i<itemsinlist(list,";");i+=1)
		checkStr = stringfromlist(i,list,";")
		if(countQuotes(checkStr)>2)	
			escapedStr = escapeInnerQuotes(checkStr)
			list = removelistitem(i,list,";")
			list = addlistitem(escapedStr,list,";",i)
		endif
	endfor
	return "["+list[0,strlen(list)-2]+"]"
end

function/s escapeInnerQuotes(str)
	string str
	variable i, escaped
	string dummy="", newStr=""
	
	for(i=1; i<strlen(str)-1; i+=1)
	
		// check if the current character is escaped
		if(cmpStr(str[i-1], "\\") == 0)
			escaped = 1
		else
			escaped = 0
		endif
	
		// find extra quotes
		dummy = str[i]
		if(cmpStr(dummy, "\"" ) == 0 && escaped == 0)
			dummy = "\\"+dummy
		endif
		newStr = newStr+dummy
	endfor
	return newStr
end

function loadconfig(configfile) // change name when done!
	string configfile
	string JSONstr, checkStr, textkeys, numkeys, textdestinations, numdestinations
	variable i=0,escapePos=-1
	nvar sc_PrintRaw, sc_PrintCalc
	svar sc_LogStr, sc_current_config, sc_ColorMap, sc_current_config
	
	// load json string from config file
	printf "Loading configuration from: %s\n", configfile
	sc_current_config = configfile
	JSONstr = JSONfromFile("config", configfile)
	
	// read JSON sting. Results will be dumped into: t_tokentext, w_tokensize, w_tokenparent and w_tokentype
	JSONSimple JSONstr
	wave/t t_tokentext
   wave w_tokensize, w_tokenparent, w_tokentype
   
   // replace escaped hex values with the correct charaters (if needed)
	for(i=0;i<numpnts(t_tokentext);i+=1)
		t_tokentext[i] = unescapeJSONstr(t_tokentext[i])
	endfor
	
	// distribute JSON values
	// load raw wave configuration
	// keys are: wavenames:raw, record_waves:raw, plot_waves:raw, meas_async:raw, scripts:raw
	textkeys = "wavenames,scripts"
	numkeys = "record_waves,plot_waves,meas_async"
	textdestinations = "sc_RawWaveNames,sc_RawScripts"
	numdestinations = "sc_RawRecord,sc_RawPlot,sc_measAsync"
	loadtextJSONfromkeys(textkeys,textdestinations,child="raw")
	loadnumJSONfromkeys(numkeys,numdestinations,child="raw")
	
	// load calc wave configuration
	// keys are: wavenames:calc, record_waves:calc, plot_waves:calc, scripts:calc
	textkeys = "wavenames,scripts"
	numkeys = "record_waves,plot_waves"
	textdestinations = "sc_CalcWaveNames,sc_CalcScripts"
	numdestinations = "sc_CalcRecord,sc_CalcPlot"
	loadtextJSONfromkeys(textkeys,textdestinations,child="calc")
	loadnumJSONfromkeys(numkeys,numdestinations,child="calc")
	
	// load print checkbox settings
	sc_PrintRaw = str2num(stringfromlist(0,getJSONvalues(getJSONkeyindex("print_to_history",t_tokentext),1,child="raw"),","))
	sc_PrintCalc = str2num(stringfromlist(0,getJSONvalues(getJSONkeyindex("print_to_history",t_tokentext),1,child="calc"),","))
	
	// load log string
	sc_LogStr = stringfromlist(0,getJSONvalues(getJSONkeyindex("log_string",t_tokentext),0),",")
	
	// load colormap
	sc_ColorMap = stringfromlist(0,getJSONvalues(getJSONkeyindex("colormap",t_tokentext),0),",")
end

function loadtextJSONfromkeys(keys,destinations,[child])
	string keys, destinations, child
	variable i=0, usechild=1, index
	string valuelist
	wave/t t_tokentext
	wave w_tokenparent, w_tokensize, w_tokentype
	
	if(paramisdefault(child))
		usechild = 0
		child = ""
	endif
	
	if(itemsinlist(keys)!=itemsinlist(destinations))
		abort "ERROR: Config load falied! Number of keys doesn't match numbers of destination waves!"
	else
		for(i=0;i<itemsinlist(keys);i+=1)
			index = getJSONkeyindex(keys[i],t_tokentext)
			valuelist = getJSONvalues(index,usechild,child=child)
			make/o/t/n=(itemsinlist(valuelist,",")) $stringfromlist(i,destinations,",") = stringfromlist(p,valuelist,",")
		endfor
	endif
end

function loadnumJSONfromkeys(keys,destinations,[child])
	string keys, destinations, child
	variable i=0, usechild=1, index
	string valuelist
	wave/t t_tokentext
	wave w_tokenparent, w_tokensize, w_tokentype
	
	if(paramisdefault(child))
		usechild = 0
		child = ""
	endif
	
	if(itemsinlist(keys)!=itemsinlist(destinations))
		abort "ERROR: Config load falied! Number of keys doesn't match numbers of destination waves!"
	else
		for(i=0;i<itemsinlist(keys);i+=1)
			index = getJSONkeyindex(keys[i],t_tokentext)
			valuelist = getJSONvalues(index,usechild,child=child)
			make/o/n=(itemsinlist(valuelist,",")) $stringfromlist(i,destinations,",") = str2num(stringfromlist(p,valuelist,","))
		endfor
	endif
end


function/s getJSONvalues(parentindex,usechild,[child])
	variable parentindex, usechild
	string child
	wave/t t_tokentext
	wave w_tokenparent
	string valuelist=""
	variable i=0,j=0, childindex
	
	for(i=0;i<numpnts(w_tokenparent);i+=1)
		if(w_tokenparent[i] == parentindex)
			if(usechild) // look for nested key
				childindex = getJSONkeyindex(child,t_tokentext)
				for(j=i;j<numpnts(w_tokenparent);j+=1) // values are found down stream
					if(w_tokenparent[j] == childindex)
						valuelist = addlistitem(t_tokentext[i],valuelist,",",inf)
					endif
				endfor
			else
				// no nested keys
				valuelist = addlistitem(t_tokentext[i],valuelist,",",inf)
			endif
		endif
	endfor
	
	return valuelist
end

function getJSONkeyindex(key,tokenwave)
	string key
	wave/t tokenwave
	variable i=0
	string error
	
	for(i=0;i<numpnts(tokenwave);i+=1)
		if(cmpstr(key,tokenwave[i])==0)
			return i
		endif
	endfor
	
	sprintf error, "ERROR: key (%s) not found!", key
	abort error
end

function/s unescapeJSONstr(JSONstr)
	string JSONstr
	variable escapePos
	
	do
		escapePos =strsearch(JSONstr,"\\",0)
		if(escapePos > 0)
			JSONstr = replacestring(JSONstr[escapePos,escapePos+4],JSONstr,num2char(str2num(JSONstr[escapePos+1,escapePos+4])))
		endif
	while(escapePos > 0)
	
	return JSONstr
end

function/s escapeJSONstr(JSONstr)
	string JSONstr
	variable escapePos, i=0
	string checkStr, checklist = "\";," // add more if needed
	
	checkStr = JSONstr
	for(i=0;i<itemsinlist(checklist,";");i+=1)
		do
			escapePos =strsearch(checkStr,stringfromlist(i,checklist,";"),0)
		if(escapePos > 0)
			checkStr = replacestring(checkStr[escapePos],checkStr,dectoescapedhexstr(char2num(checkStr[escapePos])))
			endif
		while(escapePos > 0)
	endfor
	
	return "\""+checkStr+"\""
end

function/s dectoescapedhexstr(num)
	variable num
	string hexstring = "\0x", hextable = "0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F"
	
	return hexstring+num2str(floor(num/16))+stringfromlist(num-floor(num/16)*16,hextable,",")
end