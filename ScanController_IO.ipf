#pragma rtGlobals=1		// Use modern global access method.

/// this procedure contains all of the functions that
/// scan controller needs for file I/O and custom formatted string handling
/// currently that includes -- saving IBW and HDF5 files
///                            reading/writing/parsing JSON
///                            loading ini config files

//////////////////////////////
/// SAVING EXPERIMENT DATA ///
//////////////////////////////

///// generic /////

//function /S recordedWaveArray()
//	wave /T sc_RawWaveNames, sc_CalcWaveNames
//	wave sc_RawRecord, sc_CalcRecord
//	string swave=""
//	variable i=0
//	do
//		if(strlen(sc_RawWaveNames[i])!=0 && sc_RawRecord[i]==1)
//			swave += "\""+sc_RawWaveNames[i]+"\", "
//		endif
//		i+=1
//	while(i<numpnts(sc_RawWaveNames))
//
//	i=0
//	do
//		if(strlen(sc_CalcWaveNames[i])!=0 && sc_CalcRecord[i]==1)
//			swave += "\""+sc_CalcWaveNames[i]+"\", "
//		endif
//		i+=1
//	while(i<numpnts(sc_CalcWaveNames))
//
//	return "["+swave[0,strlen(swave)-3]+"]"
//end

///// HDF5 /////

// get meta data //

//function /S saveScanComments([msg])
//	// msg can be any normal string, it will be saved as a JSON string value
//
//	string msg
//	string buffer="", jstr=""
//	jstr += getExpStatus() // record date, time, wave names, time elapsed...
//
//	if (!paramisdefault(msg) && strlen(msg)!=0)
//		jstr = addJSONkeyvalpair(jstr, "comments", TrimString(msg), addQuotes = 1)
//	endif
//
//	jstr = addJSONkeyvalpair(jstr, "logs", getEquipLogs())
//
//	//// save file ////
//	nvar filenum
//	string extension, filename
//	extension = "." + num2istr(unixtime()) + ".winf"
//	filename =  "dat" + num2istr(filenum) + extension
//	writeJSONtoFile(jstr, filename, "winfs")
//
//	return jstr
//end

//function /s json2hdf5attributes(jstr, obj_name, h5id)
//	// writes key/value pairs from jstr as attributes of "obj_name"
//	// in the hdf5 file or group identified by h5id
//	string jstr, obj_name
//	variable h5id
//
//	make /FREE /T /N=1 str_attr = ""
//	make /FREE /N=1 num_attr = 0
//
//	// loop over keys
//	string keys = getJSONkeys(jstr)
//	variable j = 0, numKeys = ItemsInList(keys, ",")
//	string currentKey = "", currentVal = ""
//	string group = ""
//	for(j=0;j<numKeys;j+=1)
//		currentKey = StringFromList(j, keys, ",")
//		if(strsearch(currentKey, ":", 0)==-1)
//			currentVal = getJSONValue(jstr, currentKey)
//			if(findJSONtype(currentVal)==0)
//				num_attr[0] = str2num(currentVal)
//				HDF5SaveData /A=currentKey num_attr, h5id, obj_name
//			else
//				str_attr[0] = currentVal
//				HDF5SaveData /A=currentKey str_attr, h5id, obj_name
//			endif
//		endif
//	endfor
//
//end

// save waves and experiment //.

function initSaveFiles([msg])
	//// create/open any files needed to save data
	//// also save any global meta-data you want
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

	// Create metadata group
	variable /G metadata_group_ID
	HDF5CreateGroup hdf5_id, "metadata", metadata_group_ID
//	json2hdf5attributes(getExpStatus(msg=msg), "metadata", hdf5_id) // add experiment metadata

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

	 // add wave status JSON string as attribute
	 nvar hdf5_id
//	 json2hdf5attributes(getWaveStatus(wn), wn, hdf5_id)
end

function closeSaveFiles()
	//// close any files that were created for this dataset

	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	string /g h5name = "dat"+filenumstr+".h5"

	// close metadata group
	nvar metadata_group_id
	HDF5CloseGroup /Z metadata_group_id
	if (V_flag != 0)
		Print "HDF5CloseGroup Failed: ", "metadata"
	endif

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

//////////////////
/// formatting ///
//////////////////

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

		// count opening brackets
		if( CmpStr(str[i], "\"" ) == 0 && escaped == 0)
			quoteCount += 1
		endif

	endfor
	return quoteCount
end

function/s removeescapedquotes(str)
	string str
	
	str = replacestring("\"",str,"")
	
	return str
end

function loadtextarrayintowave(array,destwave)
	string array,destwave
	variable i=0
	
	array = array[1,strlen(array)-2]
	
	make/o/t/n=(itemsinlist(array,",")) $destwave = stringfromlist(p,array,",")
	wave/t wref = $destwave
	for(i=0;i<(itemsinlist(array,","));i+=1)
		wref[i] = removeescapedquotes(wref[i])
	endfor
end

function loadbooleanarrayintowave(array,destwave)
	string array,destwave
	
	array = array[1,strlen(array)-2]
	
	make/o/n=(itemsinlist(array,",")) $destwave = booltonum(stringfromlist(p,array,","))
end

function loadbooleanintovariable(boolean,destvar)
	string boolean,destvar
	
	variable/g $destvar = booltonum(boolean)
end

function loadtextintostring(str,deststring)
	string str,deststring
	
	string/g $deststring = str
	svar escapestr = $deststring
	escapestr = removeescapedquotes(escapestr)
end

function loadnumintovariable(numasstr,destvar)
	string numasstr,destvar
	
	variable/g $destvar = str2num(numasstr)
end

//////////////
//// TOML ////
/////////////

// https://en.wikipedia.org/wiki/TOML

function/s getTOMLvalue(TOMLstr,key)
	// returns the value associated with key
	// returns an empty string is key is not valid
	string TOMLstr,key
	variable key_length,index,old_index,i=0, val_start, val_end
	string str
	
	key_length = itemsinlist(key,":")
	
	// search TOMLstr for key
	old_index = 0
	for(i=0;i<key_length;i+=1)
		if(i<key_length-1)
			str = "["+stringfromlist(i,key,":")+"]"
		else
			str = stringfromlist(i,key,":")
		endif
		index = strsearch(TOMLstr,str,old_index)
		if(index==-1 || index<old_index)
			return ""
		endif
		old_index=index+strlen(str)
	endfor
	val_start = index+strlen(str)+1
	val_end = strsearch(TOMLstr,num2char(13),val_start) // look for \r

	return TOMLstr[val_start,val_end-1]
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

function/s addTOMLkey(name,value,[str,indent,addquotes])
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
	endif
	
	if(addquotes)
		value = "\""+value+"\""
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

//// Read/write text files ////

function writetofile(anyStr,filename,path)
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

function/s readtxtfile(filename, path)
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