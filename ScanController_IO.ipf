#pragma rtGlobals=1		// Use modern global access method.

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
		if(cmpStr(dummy, "\"" )==0 && escaped==0)
			dummy = "\\"+dummy
		endif
		newStr = newStr+dummy
	endfor
	return newStr
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
			escapedStr = escapeInnerQuotes(checkStr)
			list = removelistitem(i,list,";")
			list = addlistitem(escapedStr,list,";",i)
		endif
	endfor
	list = replacestring(";",list,",")
	return "["+list[0,strlen(list)-2]+"]"
end
