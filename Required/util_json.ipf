//#pragma TextEncoding = "UTF-8"
//#pragma rtGlobals=3				// Use modern global access method and strict wave access
//#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
//
//
//function get_hdfid(datnum)
//	// Opens HDF5 file from current data folder and returns sweeplogs jsonID
//	// Remember to JSON_Release(jsonID) or JSONXOP_release/A to release all objects
//	// Can be converted to JSON string by using JSON_dump(jsonID)
//	variable datnum
//	variable fileid
//	HDF5OpenFile /P=data fileid as "dat"+num2str(datnum)+".h5"
//	return fileid
//end
//
//
////
////function getJSONXid(jsonID, path)
////	// Returns jsonID of json object located at "path" in jsonID passed in. e.g. get "BabyDAC" json from "Sweep_logs" json.
////	// Path should be able to be a true JSON pointer i.e. "/" separated path (e.g. "Magnets/Magx") but it is untested
////	variable jsonID
////	string path
////	variable i, tempID
////	string tempKey
////	
////	if (JSON_GetType(jsonID, path) != 0)	
////		abort "ERROR[get_json_from_json]: path does not point to JSON obect"
////	endif
////
////	if (itemsinlist(path, "/") == 1)
////		return getJSONXid_fromKey(jsonID, path)
////	else
////		tempID = jsonID
////		for(i=0;i<itemsinlist(path, "/");i++)  //Should recursively get deeper JSON objects. Untested
////			tempKey = stringfromlist(i, path, "/")
////			tempID = getJSONXid_fromKey(tempID, tempkey)
////		endfor
////		return tempID
////	endif
////end
////
////function getJSONXid_fromKey(jsonID, key)
////	// Should only be called from getJSONid to convert the inner JSON into a new JSONid pointer.
////	// User should use the more general getJSONid(jsonID, path) where path can be a single key or "/" separated path
////	variable jsonID
////	string key
////	if ((JSON_GetType(jsonID, key) != 0) || (itemsinlist(key, "/") != 1)	)
////		abort "ERROR[get_json_from_json_key]: key is not a top level JSON obect"
////	endif
////	return JSON_parse(getJSONvalue(json_dump(jsonID), key))  // workaround to get a jsonID of inner JSON
////end
////
////
////
////function/s getJSONvalue(jstr, key)
////	// returns the value of the parsed key
////	// function returns can be: object, array, value
////	// expected format: "parent1:parent2:parent3:key"
////	string jstr, key
////	variable offset, key_length
////	string indices
////	
////	key_length = itemsinlist(key,":")
////
////	JSONSimple/z jstr
////	wave/t t_tokentext
////	wave w_tokentype, w_tokensize
////
////	if(key_length==0)
////		// return whole json
////		return jstr
////	elseif(key_length==1)
////		// this is the only key with this name
////		// if not, the first key will be returned
////		offset = 0
////		return getJSONkeyoffset(key,offset)
////	else
////		// the key has parents, and there could be multiple keys with this name
////		// find the indices of the keys parsed
////		indices = getJSONindices(key)
////		if(itemsinlist(indices,",")<key_length)
////			print "[ERROR] Value of JSON key is ambiguous: "+key
////			return ""
////		else
////			return getJSONkeyoffset(stringfromlist(key_length-1,key,":"),str2num(stringfromlist(key_length-1,indices,","))-1)
////		endif
////	endif
////end
////
////function/s getJSONkeyoffset(key,offset)
////	string key
////	variable offset
////	wave/t t_tokentext
////	wave w_tokentype, w_tokensize
////	variable i=0
////
////	// find key and check that it is infact a key
////	for(i=offset;i<numpnts(t_tokentext);i+=1)
////		if(cmpstr(t_tokentext[i],key)==0 && w_tokensize[i]>0)
////			return t_tokentext[i+1]
////		endif
////	endfor
////	// if key is not found, return an empty string
////	print "[ERROR] JSON key not found: "+key
////	return t_tokentext[0] // Default to return everything
////end
////
////function/s getJSONindices(keys)
////	// returns string list with indices of parsed keys
////	string keys
////	string indices="", key
////	wave/t t_tokentext
////	wave w_tokentype, w_tokensize, w_tokenparent
////	variable i=0, j=0, index, k=0
////
////	for(i=0;i<itemsinlist(keys,":");i+=1)
////		key = stringfromlist(i,keys,":")
////		if(i==0)
////			index = 0
////		else
////			index = str2num(stringfromlist(i-1,indices,","))
////		endif
////		for(j=0;j<numpnts(t_tokentext);j+=1)
////			if(cmpstr(t_tokentext[j],key)==0 && w_tokensize[j]>0)
////				if(w_tokenparent[j]==index)
////					if(w_tokensize[j+1]>0)
////						k = j+1
////					else
////						k = j
////					endif
////					indices = addlistitem(num2str(k),indices,",",inf)
////					break
////				endif
////			endif
////		endfor
////	endfor
////
////	return indices
////end
//
//
//function fd_getoldAWG(S,datnum,[fastdac_num, kenner])
//	// Function to get old values for AWG that is stored in hdf file with filenum
//	struct ScanVars &S //*** TODOD
//	variable datnum, fastdac_num
//	string kenner
//	kenner = selectString(paramisdefault(kenner), kenner, "")
//	
//	variable sl_id, fd_id  //JSON ids
//	fastdac_num = paramisdefault(fastdac_num) ? 1 : fastdac_num
//
//	if(fastdac_num != 1)
//		abort "WARNING: This is untested... remove this abort if you're feeling lucky!"
//	endif
//
//	sl_id = get_sweeplogs(datnum, kenner=kenner)  // Get Sweep_logs JSON;
//	fd_id = getJSONXid(sl_id, "FastDAC "+num2istr(fastdac_num)) // Get FastDAC JSON from Sweeplogs
//
//	// Get variable parts
//
//	//	JSONXOP_GetValue/V fd_id, "/AWG/initialized"
//	//	S.initialized=V_value
//
//	JSONXOP_GetValue/V fd_id, "/AWG/AWG_used"
//	S.use_AWG=V_value
//
//	S.lims_checked=0; //always 0
//
//	JSONXOP_GetValue/V fd_id, "/AWG/waveLen"
//	S.waveLen=V_value
//
//	JSONXOP_GetValue/V fd_id, "/AWG/numADCs"
//	S.numADCs=V_value
//
//	JSONXOP_GetValue/V fd_id, "/AWG/samplingFreq"
//	S.samplingFreq=V_value
//
//	JSONXOP_GetValue/V fd_id, "/AWG/measureFreq"
//	S.measureFreq=V_value
//
//	JSONXOP_GetValue/V fd_id, "/AWG/numWaves"
////	S.numWaves=V_value ***
//
//	JSONXOP_GetValue/V fd_id, "/AWG/numCycles"
//	S.numCycles=V_value
//
//
//	JSONXOP_GetValue/V fd_id, "/AWG/numSteps"
////	S.numSteps=V_value
//
//	JSONXOP_GetValue/T fd_id, "/AWG/AW_Waves"
////	S.AW_waves=S_value
//
//	JSONXOP_GetValue/T fd_id, "/AWG/AW_Dacs"
////	S.AW_dacs=S_value
//
//	JSONXOP_Release /A  //Clear all stored JSON strings
//
//end
//
//
//function fd_getScanVars(S,datnum,[fastdac_num])
//	// Function to get old values for AWG that is stored in hdf file with filenum
//	struct ScanVars &S
//	variable datnum, fastdac_num
//	variable sl_id, fd_id  //JSON ids
//	fastdac_num = paramisdefault(fastdac_num) ? 1 : fastdac_num
//
//	if(fastdac_num != 1)
//		abort "WARNING: This is untested... remove this abort if you're feeling lucky!"
//	endif
//
//	sl_id = get_sweeplogs(datnum)  // Get Sweep_logs JSON;
//	fd_id = getJSONXid(sl_id, "FastDAC "+num2istr(fastdac_num)) // Get FastDAC JSON from Sweeplogs
//
//
//	// Get variable parts
//
//
//	JSONXOP_GetValue/V fd_id, "/MeasureFreq"
//	S.MeasureFreq=V_value
//
//	
//	JSONXOP_Release /A  //Clear all stored JSON strings
//
//end
//
//function fd_getmeasfreq(datnum,[fastdac_num])
//	// Function to get old h5 values for measurement frequency
//	variable datnum, fastdac_num
//	variable sl_id, fd_id  //JSON ids
//	variable freq
//	fastdac_num = paramisdefault(fastdac_num) ? 1 : fastdac_num
//
//	if(fastdac_num != 1)
//		abort "WARNING: This is untested... remove this abort if you're feeling lucky!"
//	endif
//
//	sl_id = get_sweeplogs(datnum)  // Get Sweep_logs JSON;
//	fd_id = getJSONXid(sl_id, "FastDAC " + num2istr(fastdac_num)) // Get FastDAC JSON from Sweeplogs
//
//	// Get variable parts
//
//	//	JSONXOP_GetValue/V fd_id, "/AWG/initialized"
//	//	S.initialized=V_value
//
//	JSONXOP_GetValue/V fd_id, "MeasureFreq"
//	freq=V_value
//
//	JSONXOP_Release /A  //Clear all stored JSON strings
//	
//	return freq
//
//end
//
//
//function fd_gettemperature(datnum, [which_plate])
//	// Function to get old h5 values for Lakeshore temperatures
//	variable datnum
//	string which_plate // "MC K" :: "50K Plate K" :: "4K Plate K" :: "Magnet K" :: "Still K
//	
//	which_plate = selectString(paramisdefault(which_plate), which_plate, "MC K") // Mixing chamber temp is default
//	
//	variable sl_id, fd_id  //JSON ids
//	variable temperature
//
//	sl_id = get_sweeplogs(datnum)  // Get Sweep_logs JSON;
//	fd_id = getJSONXid(sl_id, "Lakeshore") // Get FastDAC JSON from Sweeplogs
//	fd_id = getJSONXid(fd_id, "Temperature") // Get FastDAC JSON from Sweeplogs
//
//	JSONXOP_GetValue/V fd_id, which_plate
//	temperature = V_value
//
//	JSONXOP_Release /A  //Clear all stored JSON strings
//	
//	return temperature
//
//end
//
//
//function fd_getfield(datnum)
//	// Function to get old h5 values for Lakeshore temperatures
//	// 2023-10-01: Function completely fails in the try-catch-endtry. I am not sure if I am using it wrong. 
//	// Sometimes getJSONXid(sl_id, "LS625 Magnet Supply") will return error and the function will error out. 
//	variable datnum
//	
//	variable sl_id, fd_id  //JSON ids
//	variable field
//
//	sl_id = get_sweeplogs(datnum)  // Get Sweep_logs JSON;
//	try
////		fd_id = getJSONXid(sl_id, "LS625 Magnet Supply") // Get FastDAC JSON from Sweeplogs LS625
//		fd_id = getJSONXid(sl_id, "IPS") // Get FastDAC JSON from Sweeplogs IPS20
//		
//		JSONXOP_GetValue/V fd_id, "field mT"
//		field = V_value
//	
//		JSONXOP_Release /A  //Clear all stored JSON strings
//		
//		return field
//	catch
//		print "[WARNING] No Field found in JSON, returning 0"
//		return 0
//	endtry
//
//end
//
//
//function /wave fd_getfd_keys_vals(datnum, [number_of_fastdac])
//	// Function to get DAC values from HDF file
//	variable datnum
//	int number_of_fastdac
//	
//	number_of_fastdac = paramisdefault(number_of_fastdac) ? 1 : number_of_fastdac 
//
//	variable jsonId, fd_id  
//	string fast_dac_string
//	
//	variable num_keys_in_fd
//	string keys_in_fd, key_in_fd, DAC_num_index
//
//	make /free /n=(number_of_fastdac*8) all_dac_vals
//	int index
//
//	int i, j
//	try
//		for (i = 1; i <= number_of_fastdac; i++)
//			index = (i - 1) * 8
//			fast_dac_string = "FastDAC " + num2str(i)
//			
//			jsonId = get_sweeplogs(datnum)
//			fd_id = getJSONXid(jsonId, fast_dac_string) // Get FastDAC JSON from Sweeplogs
//			
//			JSONXOP_GetKeys jsonId, fast_dac_string, DAC_keys
//			
//			keys_in_fd = textWave2StrArray(DAC_keys)
//			num_keys_in_fd = ItemsInList(keys_in_fd,  ",")
//						
//			for (j=5; j < num_keys_in_fd - 3; j++)
//				key_in_fd = StringFromList(j, keys_in_fd, ",")
//				key_in_fd = removeLiteralQuotes(key_in_fd)
//				JSONXOP_GetValue/V fd_id, key_in_fd
//				
//				// calculate index based on DAC index value
//				// keys returned by JSONXOP_GetKeys are in alphabetical order. NOT in the order placed in scanvars.
//				DAC_num_index = StringFromList(0, key_in_fd, "{")
//				DAC_num_index = DAC_num_index[3,INF]
//				
//				all_dac_vals[str2num(DAC_num_index)] = V_value
//				index += 1
//			endfor
//
//		endfor
//		
//		return all_dac_vals
//	catch
//		print "[WARNING] No FD found in JSON, returning empty wave"
//		make /free /n=1 empty_wave
//		return empty_wave
//	endtry
//
//end
//
//
//
//
//function make_scanvar_table_from_dats(dat_min_max, [ignore_field])
//	// create a table from the input string dat_min_max
//	// so far it is hard coded to add only the datnum, field and temperature
//	string dat_min_max
//	int ignore_field
//	
//	variable dat_start = str2num(StringFromList(0, dat_min_max, ";"))
//	variable dat_end = str2num(StringFromList(1, dat_min_max, ";"))  
//	
//	make /o /n=((dat_end - dat_start + 1), 3+8*3) scanvar_table 
//	variable datnum, scanvar_variable 
//		
//	variable scanvar_row = 0
//	variable i
//	for(i=dat_start; i<dat_end+1; i+=1)
//	
//			make /o /n=(3+8*3) scanvar_table_slice
//			wave scanvar_table_slice
//			
//			datnum = i
//			scanvar_table_slice[0] = datnum
//			
//			scanvar_variable = fd_gettemperature(datnum, which_plate = "MC K")
//			scanvar_table_slice[1] = scanvar_variable * 1000
//			
//			if (ignore_field == 1) // terrible workaround if fd_getfield() fails to find field. I manually ignore it. :(
//				scanvar_variable = 0
//			else
//				scanvar_variable = fd_getfield(datnum)
//			endif
//			scanvar_table_slice[2] = scanvar_variable
//			
//			///// ADDING DAC VALUES /////
////			wave dac_vals = fd_getfd_keys_vals(datnum, number_of_fastdac = 3)
////			scanvar_table_slice[3, 3+8*3] = dac_vals[p - 3]
////			
//			scanvar_table[scanvar_row][] = scanvar_table_slice[q]
//
//			scanvar_row += 1
//	endfor
//	
//end
//
//
////function fd_get_fastdacs_from_hdf(datnum, [fastdac_num])
////	//Creates/Overwrites load_fdacvalstr by duplicating the current fdacvalstr then changing the labels and outputs of any values found in the metadata of HDF at dat[datnum].h5
////	//Leaves fdacvalstr unaltered	
////	variable datnum, fastdac_num
////	variable sl_id, fd_id  //JSON ids
////	
////	fastdac_num = paramisdefault(fastdac_num) ? 1 : fastdac_num 
////	
////	if(fastdac_num != 1)
////		abort "WARNING: This is untested... remove this abort if you're feeling lucky!"
////	endif
////	
////	sl_id = get_sweeplogs(datnum)  // Get Sweep_logs JSON
////	fd_id = getJSONXid(sl_id, "FastDAC "+num2istr(fastdac_num)) // Get FastDAC JSON from Sweeplogs
////
////	wave/t keys = JSON_getkeys(fd_id, "")
////	wave/t fdacvalstr
////	duplicate/o/t fdacvalstr, load_fdacvalstr
////	
////	variable i
////	string key, label_name, str_ch
////	variable ch = 0
////	for (i=0; i<numpnts(keys); i++)  // These are in a random order. Keys must be stored as "DAC#{label}:output" in JSON
////		key = keys[i]
////		if (strsearch(key, "DAC", 0) != -1)  // Check it is actually a DAC key and not something like com_port
////			SplitString/E="DAC(\d*){" key, str_ch //Gets DAC# so that I store values in correct places
////			ch = str2num(str_ch)
////			
////			load_fdacvalstr[ch][1] = num2str(JSON_getvariable(fd_id, key))
////			SplitString/E="{(.*)}" key, label_name  //Looks for label inside {} part of e.g. BD{label}
////			label_name = replaceString("~1", label_name, "/")  // Somehow igor reads '/' as '~1' don't know why...
////			load_fdacvalstr[ch][3] = label_name
////		endif
////	endfor
////	JSONXOP_Release /A  //Clear all stored JSON strings
////end