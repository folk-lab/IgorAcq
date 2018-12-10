pragma rtGlobals=1		// Use modern global access method.

/// this procedure contains all of the functions that
/// scan controller needs for file I/O and custom formatted string handling

//////////////////////////////
/// SAVING EXPERIMENT DATA ///
//////////////////////////////

function initSaveFiles([msg])
	//// create/open HDF5 files

	string msg
	if(paramisdefault(msg)) // save meta data
		msg=""
	endif

	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	string /g h5name = "dat"+filenumstr+".h5"

	// Open HDF5 file
	variable /g hdf5_id
	HDF5CreateFile /P=data hdf5_id as h5name

	// save x and y arrays
	nvar sc_is2d
	HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 $"sc_xdata" , hdf5_id, "x_array"
	if(sc_is2d)
		HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 $"sc_ydata" , hdf5_id, "y_array"
	endif

	// Create config group
	svar sc_current_config
	variable /G config_group_ID
	HDF5CreateGroup hdf5_id, "config", config_group_ID
//	json2hdf5attributes(JSONfromFile("config", sc_current_config), "config", hdf5_id) // add current scancontroller config

	// Create logs group
	variable /G logs_group_ID
	HDF5CreateGroup hdf5_id, "logs", logs_group_ID
//	json2hdf5attributes(getEquipLogs(), "logs", hdf5_id) // add current scancontroller config

end

function saveSingleWave(wn)
	// wave with name 'filename' as filename.ibw
	string wn
	nvar hdf5_id

	HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 /Z $wn , hdf5_id
	if (V_flag != 0)
		Print "HDF5SaveData failed: ", wn
		return 0
	endif

end

function closeSaveFiles()
	//// close any files that were created for this dataset

	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	string /g h5name = "dat"+filenumstr+".h5"

	// close config group
	nvar config_group_id
	HDF5CloseGroup /Z config_group_id
	if (V_flag != 0)
		Print "HDF5CloseGroup Failed: ", "config"
	endif

	// close HDF5 file
	nvar hdf5_id
	HDF5CloseFile /Z hdf5_id
	if (V_flag != 0)
		Print "HDF5CloseFile failed: ", h5name
	endif

end

/////////////////////////
/// read JSON strings ///
/////////////////////////

// useful for parsing HTTP responses

function/s getJSONvalue(jstr, key)
	// returns the value of the parsed key
	// function returns can be: object, array, value
	// expected format: "parent1:parent2:parent3:key"
	string jstr, key
	variable offset, key_length
	string indices

	key_length = itemsinlist(key,":")

	JSONSimple jstr
	wave/t t_tokentext
	wave w_tokentype, w_tokensize

	if(key_length==1)
		// this is the only key with this name
		// if not, the first key will be returned
		offset = 0
		return getJSONkeyoffset(key,offset)
	else
		// the key has parents, and there could be multiple keys with this name
		// find the indices of the keys parsed
		indices = getJSONindices(key)
		if(itemsinlist(indices,",")<key_length)
			return ""
		else
			return getJSONkeyoffset(stringfromlist(key_length-1,key,":"),str2num(stringfromlist(key_length-1,indices,","))-1)
		endif
	endif
end

function/s getJSONindices(keys)
	// returns string list with indices of parsed keys
	string keys
	string indices="", key
	wave/t t_tokentext
	wave w_tokentype, w_tokensize, w_tokenparent
	variable i=0, j=0, index, k=0

	for(i=0;i<itemsinlist(keys,":");i+=1)
		key = stringfromlist(i,keys,":")
		if(i==0)
			index = 0
		else
			index = str2num(stringfromlist(i-1,indices,","))
		endif
		for(j=0;j<numpnts(t_tokentext);j+=1)
			if(cmpstr(t_tokentext[j],key)==0 && w_tokensize[j]>0)
				if(w_tokenparent[j]==index)
					if(w_tokensize[j+1]>0)
						k = j+1
					else
						k = j
					endif
					indices = addlistitem(num2str(k),indices,",",inf)
					break
				endif
			endif
		endfor
	endfor

	return indices
end

function/s getJSONkeyoffset(key,offset)
	string key
	variable offset
	wave/t t_tokentext
	wave w_tokentype, w_tokensize
	variable i=0

	// find key and check that it is infact a key
	for(i=offset;i<numpnts(t_tokentext);i+=1)
		if(cmpstr(t_tokentext[i],key)==0 && w_tokensize[i]>0)
			return t_tokentext[i+1]
		endif
	endfor
	// if key is not found, return an empty string
	return ""
end

/////////////////////////////////
/// text formatting utilities ///
/////////////////////////////////

Function IsWhiteSpace(char)
    String char

    return GrepString(char, "\\s")
End

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

function countQuotes(str)
	// count how many quotes are in the string
	// +1 for "
	// escaped quotes are ignored
	string str
	variable quoteCount = 0, i = 0, escaped = 0
	for(i=0; i<strlen(str); i+=1)

		// check if the current character is escaped
		if(i!=0)
			if( CmpStr(str[i-1], "\\") == 0)
				escaped = 1
			else
				escaped = 0
			endif
		endif

		// count quotes
		if( CmpStr(str[i], "\"" ) == 0 && escaped == 0)
			quoteCount += 1
		endif

	endfor
	return quoteCount
end

function countSqBrackets(str)
	// count how many brackets are in the string
	// +1 for ]
	// -1 for [
	string str
	variable bracketCount = 0, i = 0, escaped = 0
	for(i=0; i<strlen(str); i+=1)
	
		// check if the current character is escaped
		if(i!=0)
			if( CmpStr(str[i-1], "\\") == 0)
				escaped = 1
			else
				escaped = 0
			endif
		endif
	
		// count opening brackets
		if( CmpStr(str[i], "[" ) == 0 && escaped == 0)
			bracketCount -= 1
		endif
		
		// count closing brackets
		if( CmpStr(str[i], "]" ) == 0 && escaped == 0)
			bracketCount += 1
		endif
		
	endfor
	return bracketCount
end

function /S escapeQuotes(str)
	string str
	
	variable i=0, escaped=0
	string output = ""
	do
	
		if(i>strlen(str)-1)
			break
		endif
		
		// check if the current character is escaped
		if(i!=0)
			if( CmpStr(str[i-1], "\\") == 0)
				escaped = 1
			else
				escaped = 0
			endif
		endif
	
		// escape quotes
		if( CmpStr(str[i], "\"" ) == 0 && escaped == 0)
			// this is an unescaped quote
			str = str[0,i-1] + "\\" + str[i,inf]
		endif
		i+=1
		
	while(1==1)
	return str
end

function /S unescapeQuotes(str)
	string str
	
	variable i=0, escaped=0
	string output = ""
	do
	
		if(i>strlen(str)-1)
			break
		endif
		
		// check if the current character is escaped
		if(i!=0)
			if( CmpStr(str[i-1], "\\") == 0)
				escaped = 1
			else
				escaped = 0
			endif
		endif
	
		// escape quotes
		if( CmpStr(str[i], "\"" ) == 0 && escaped == 1)
			// this is an unescaped quote
			str = str[0,i-2] + str[i,inf]
		endif
		i+=1
		
	while(1==1)
	return str
end

function/s removeLiteralQuotes(str)
	// removes outermost quotes
	// handles single or triple quotes (TOML standards)
	// there are about ten different ways to break this
	string str
	
	variable i=0, openQuotes=0
	for(i=0;i<strlen(str);i+=1)
		if(CmpStr(str[i],"\"")==0)
			openQuotes+=1
		endif
		
		if(openQuotes>0 && CmpStr(str[i],"\"")!=0)
			break
		endif
	endfor
	
	if(openQuotes==0)
		print "[ERROR] String not surrounded by quotes. str: "+str
		return ""
	elseif(openQuotes==2)
		openQuotes=1
	elseif(openQuotes>3)
		openQuotes=3
	endif
	
	str = str[i,inf]
	variable j, closeQuotes=0
	for(j=strlen(str); j>0; j-=1)
	
		if(CmpStr(str[j],"\"")==0)
			closeQuotes+=1
		endif
		
		if(closeQuotes==openQuotes)
			break
		endif
		
	endfor

	return str[0,j-1]
end

function/s removeSqBrackets(str)
	// removes outermost brackets
	// and whitespace from a string
	string str
	
	variable i=0
	for(i=0;i<strlen(str);i+=1)
		if(CmpStr(str[i],"[")==0)
			break
		endif
	endfor
	
	if(i==strlen(str)-1)
		print "[ERROR] String not surrounded by brackets. str: "+str
		return ""
	endif
	
	str = str[i+1,inf]
	variable j
	for(j=strlen(str); j>0; j-=1)
		if(CmpStr(str[j],"]")==0)
			break
		endif
	endfor

	return str[0,j-1]	
end

Function/t removeStringListDuplicates(theListStr)
	// credit: http://www.igorexchange.com/node/1071
	String theListStr

	String retStr = ""
	variable ii
	for(ii = 0 ; ii < itemsinlist(theListStr) ; ii+=1)
		if(whichlistitem(stringfromlist(ii , theListStr), retStr) == -1)
			retStr = addlistitem(stringfromlist(ii, theListStr), retStr, ";", inf)
		endif
	endfor
	return retStr
End

function/s searchFullString(string_to_search,substring)
	string string_to_search, substring
	string index_list=""
	variable test, startpoint=0

	do
		test = strsearch(string_to_search, substring, startpoint)
		if(test != -1)
			index_list = index_list+num2istr(test)+","
			startpoint = test+1
		endif
	while(test > -1)

	return index_list
end

function LoadTextArrayToWave(array,destwave)
	string array,destwave
	variable i=0
	
	array = removeSqBrackets(array)
	
	make/o/t/n=(itemsinlist(array,",")) $destwave = stringfromlist(p,array,",")
	wave/t wref = $destwave
	string buffer = ""
	for(i=0;i<(itemsinlist(array,","));i+=1)
		wref[i] = removeLiteralQuotes(wref[i])
		wref[i] = unescapeQuotes(wref[i])
	endfor
end

function LoadBoolArrayToWave(array,destwave)
	string array,destwave

	array = removeSqBrackets(array)

	make/o/n=(itemsinlist(array,",")) $destwave = booltonum(stringfromlist(p,array,","))
end

function LoadBoolToVar(boolean,destvar)
	string boolean,destvar

	variable/g $destvar = booltonum(boolean)
end

function LoadTextToString(str,deststring)
	string str,deststring
	
	str = removeLiteralQuotes(str)
	string/g $deststring = unescapeQuotes(str) 
end

function LoadNumToVar(numasstr,destvar)
	string numasstr,destvar

	variable/g $destvar = str2num(numasstr)
end

function/s numToBool(val)
	variable val
	if(val==1)
		return "true"
	elseif(val==0)
		return "false"
	else
		return ""
	endif
end

function boolToNum(str)
	string str
	if(StringMatch(LowerStr(str), "true")==1)
		// use string match to ignore whitespace
		return 1
	elseif(StringMatch(LowerStr(str), "false")==1)
		return 0
	else
		return -1
	endif
end

function/s numericWaveToBoolArray(w)
	// returns an array
	wave w
	string list = "["
	variable i=0

	for(i=0; i<numpnts(w); i+=1)
		list += numToBool(w[i])+","
	endfor

	return list[0,strlen(list)-2] + "]"
end

function/s textWaveToStrArray(w)
	// returns an array and makes sure quotes and commas are parsed correctly.
	wave/t w
	string list, checkStr, escapedStr
	variable i=0

	wfprintf list, "\"%s\";", w
	for(i=0;i<itemsinlist(list,";");i+=1)
		checkStr = stringfromlist(i,list,";")
		if(countQuotes(checkStr)>2)
			//escapedStr = escapeJSONstr(checkStr)
			list = removelistitem(i,list,";")
			list = addlistitem(escapedStr,list,";",i)
		endif
	endfor
	list = replacestring(";",list,",")
	return "["+list[0,strlen(list)-2]+"]"
end

///////////////////////
/// text read/write ///
///////////////////////

function writeToFile(anyStr,filename,path)
	// write any string to a file called "filename"
	// path must be a predefined path
	string anyStr,filename,path
	variable refnum=0

	open /z/p=$path refnum as filename

	do
		if(strlen(anyStr)<500)
			fprintf refnum, "%s", anyStr
			break
		else
			fprintf refnum, "%s", anyStr[0,499]
			anyStr = anyStr[500,inf]
		endif
	while(1)

	close refnum
end

function/s readTXTFile(filename, path)
	// read textfile into string from filename on path
	string filename,path
	variable refnum
	string buffer="", txtstr=""

	open /r/z/p=$path refNum as filename
	if(V_flag!=0)
		print "[ERROR]: Could not read file: "+filename
		return ""
	endif

	do
		freadline refnum, buffer // returns \r no matter what was used in the file
		if(strlen(buffer)==0)
			break
		endif
		txtstr+=buffer
	while(1)
	close refnum

	return txtstr
end

////////////
/// TOML ///
////////////

// a quick attempt at writing a TOML parser
// https://en.wikipedia.org/wiki/TOML
// https://github.com/toml-lang/toml

// a good amount of the format (nested arrays, tables, single quotes) is not supported
// general philosophy is that everything written to a .toml is valid TOML
//     but our parser cannot read all valid TOML because it is complicated and we don't need it

function/s getTOMLvalue(TOMLstr,key)
	// returns the value associated with key
	// returns an empty string is key is not valid
	string TOMLstr,key
	variable key_length,index,old_index,i=0, val_start, val_end
	string str

	key_length = itemsinlist(key,":")

	// search TOMLstr for key
	// record index of first character _after_ key
	old_index = 0
	for(i=0;i<key_length;i+=1)
		str = stringfromlist(i,key,":") 
		index = strsearch(TOMLstr,str,old_index)
		
		if(index==-1 || index<old_index)
			print "[ERROR] key not found in TOML: "+key
			return ""
		endif
		old_index=index+strlen(str)
	endfor
	TOMLstr = TOMLstr[old_index,inf] // everything from the key onward
										      // look for equal sign next
	i=0
	do
		if(i>strlen(TOMLstr)-1)
			// end of string. something wasn't formatted right.
			print "[ERROR] key = value line incorrectly formatted for key: "+key
			return ""
		endif
		
		if(char2num(TOMLstr[i])==char2num("="))
			// found the equal sign. great.
			i+=1
			break
		elseif(IsWhiteSpace(TOMLstr[i]))
			// white space. keep looking.
			i+=1
		else
			// not white space. not an equal sign. bad formatting.
			print "[ERROR] key = value line incorrectly formatted for key: "+key
			return ""
		endif
	while(1==1)
	TOMLstr = TOMLstr[i,inf] // everything from the = onward
							       // look for full value next
							       
	i=0
	do
		if(i>strlen(TOMLstr)-1)
			// end of string. something wasn't formatted right.
			print "[ERROR] key = value line incorrectly formatted for key: "+key
			return ""
		endif
		
		if(char2num(TOMLstr[i])==char2num("\r"))
			// line break!
			if(countSqBrackets(TOMLstr[i,inf])!=0 || mod(countQuotes(TOMLstr[i,inf]),2)!=0)
				// there are unclosed brackets or quotes
				// this is a multi line array or string
				i+=1
				continue
			else
				break
			endif
		endif
		i+=1
	while(1==1)
	
	TOMLstr = removeTrailingWhitespace(TOMLstr[0,i])
	return removeLeadingWhitespace(TOMLstr)
end

function/s addTOMLblock(name,[str,indent])
	string name, str, indent
	string returnstr=""

	if(!paramisdefault(str))
		returnstr = str+"\n"
	endif

	if(paramisdefault(indent))
		indent = ""
	endif

	return returnstr+indent+"["+name+"]"+"\n"
end

function/s addTOMLkey(name,value,[str,indent,addQuotes])
	string name, value, str, indent
	variable addquotes
	string returnstr
	
	if(paramisdefault(str))
		str = ""
	endif
	
	if(paramisdefault(indent))
		indent = ""
	endif
	
	if(paramisdefault(addquotes))
		addquotes = 0
	elseif(addquotes==1)
		// escape quotes in value and wrap value in outer quotes
		value = "\""+escapeQuotes(value)+"\""
	endif
	
	return str+indent+name+"="+value+"\n"
end

function/s addTOMLcomment(comment,[str,indent])
	string comment, str, indent

	if(paramisdefault(str))
		str = ""
	endif

	if(paramisdefault(indent))
		indent = ""
	endif

	return str+indent+"# "+comment+"\n"
end
