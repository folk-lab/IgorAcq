//#pragma TextEncoding = "UTF-8"
//#pragma rtGlobals=3				// Use modern global access method and strict wave access
//#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
//
////  mostly written by TC 
//
function get_hdfid(datnum)
	// Opens HDF5 file from current data folder and returns sweeplogs jsonID
	// Remember to JSON_Release(jsonID) or JSONXOP_release/A to release all objects
	// Can be converted to JSON string by using JSON_dump(jsonID)
	variable datnum
	variable fileid
	HDF5OpenFile /P=data fileid as "dat"+num2str(datnum)+".h5"
	return fileid
end
//
//function fd_getGlobalAWG(S)
//	// Function to get global values for AWG_list that were stored using set_global_AWG_list()
//	// StructPut ONLY gets VARIABLES
//	struct AWGVars &S
//	// Get string parts
//	wave/T t = fd_AWGglobalStrings
//	
//
//	
//	S.AW_waves = t[0]
//	S.AW_dacs = t[1]
//
//	// Get variable parts
//	wave v = fd_AWGglobalVars
//	S.initialized = v[0]
//	S.use_AWG = v[1]  
//	S.lims_checked = 0 // Always initialized to zero so that checks have to be run before using in scan (see SetCheckAWG())
//	S.waveLen = v[3]
//	S.numADCs = v[4]
//	S.samplingFreq = v[5]
//	S.measureFreq = v[6]
//	S.numWaves = v[7]
//	S.numCycles = v[8]
//	S.numSteps = v[9]
//end
//
//function get_sweeplogs(datnum)
//	// Opens HDF5 file from current data folder and returns sweeplogs jsonID
//	// Remember to JSON_Release(jsonID) or JSONXOP_release/A to release all objects
//	// Can be converted to JSON string by using JSON_dump(jsonID)
//	variable datnum
//	variable fileid, metadataID, i, result
//	wave/t sc_sweeplogs
//	
//	HDF5OpenFile /P=data fileid as "dat"+num2str(datnum)+".h5"
//	HDF5LoadData /Q/O/Type=1/N=sc_sweeplogs /A="sweep_logs" fileid, "metadata"
//	 
//	
//	variable sweeplogsID
//	sweeplogsID = JSON_Parse(sc_sweeplogs[0])
//
//	return sweeplogsID
//end
//
//function getJSONXid(jsonID, path)
//	// Returns jsonID of json object located at "path" in jsonID passed in. e.g. get "BabyDAC" json from "Sweep_logs" json.
//	// Path should be able to be a true JSON pointer i.e. "/" separated path (e.g. "Magnets/Magx") but it is untested
//	variable jsonID
//	string path
//	variable i, tempID
//	string tempKey
//	
//	if (JSON_GetType(jsonID, path) != 0)	
//		abort "ERROR[get_json_from_json]: path does not point to JSON obect"
//	endif
//
//	if (itemsinlist(path, "/") == 1)
//		return getJSONXid_fromKey(jsonID, path)
//	else
//		tempID = jsonID
//		for(i=0;i<itemsinlist(path, "/");i++)  //Should recursively get deeper JSON objects. Untested
//			tempKey = stringfromlist(i, path, "/")
//			tempID = getJSONXid_fromKey(tempID, tempkey)
//		endfor
//		return tempID
//	endif
//end
//
//function getJSONXid_fromKey(jsonID, key)
//	// Should only be called from getJSONid to convert the inner JSON into a new JSONid pointer.
//	// User should use the more general getJSONid(jsonID, path) where path can be a single key or "/" separated path
//	variable jsonID
//	string key
//	if ((JSON_GetType(jsonID, key) != 0) || (itemsinlist(key, "/") != 1)	)
//		abort "ERROR[get_json_from_json_key]: key is not a top level JSON obect"
//	endif
//	return JSON_parse(getJSONvalue(json_dump(jsonID), key))  // workaround to get a jsonID of inner JSON
//end
//
//
//
//function/s getJSONvalue(jstr, key)
//	// returns the value of the parsed key
//	// function returns can be: object, array, value
//	// expected format: "parent1:parent2:parent3:key"
//	string jstr, key
//	variable offset, key_length
//	string indices
//	
//	key_length = itemsinlist(key,":")
//
//	JSONSimple/z jstr
//	wave/t t_tokentext
//	wave w_tokentype, w_tokensize
//
//	if(key_length==0)
//		// return whole json
//		return jstr
//	elseif(key_length==1)
//		// this is the only key with this name
//		// if not, the first key will be returned
//		offset = 0
//		return getJSONkeyoffset(key,offset)
//	else
//		// the key has parents, and there could be multiple keys with this name
//		// find the indices of the keys parsed
//		indices = getJSONindices(key)
//		if(itemsinlist(indices,",")<key_length)
//			print "[ERROR] Value of JSON key is ambiguous: "+key
//			return ""
//		else
//			return getJSONkeyoffset(stringfromlist(key_length-1,key,":"),str2num(stringfromlist(key_length-1,indices,","))-1)
//		endif
//	endif
//end
//
//function/s getJSONkeyoffset(key,offset)
//	string key
//	variable offset
//	wave/t t_tokentext
//	wave w_tokentype, w_tokensize
//	variable i=0
//
//	// find key and check that it is infact a key
//	for(i=offset;i<numpnts(t_tokentext);i+=1)
//		if(cmpstr(t_tokentext[i],key)==0 && w_tokensize[i]>0)
//			return t_tokentext[i+1]
//		endif
//	endfor
//	// if key is not found, return an empty string
//	print "[ERROR] JSON key not found: "+key
//	return t_tokentext[0] // Default to return everything
//end
//
//function/s getJSONindices(keys)
//	// returns string list with indices of parsed keys
//	string keys
//	string indices="", key
//	wave/t t_tokentext
//	wave w_tokentype, w_tokensize, w_tokenparent
//	variable i=0, j=0, index, k=0
//
//	for(i=0;i<itemsinlist(keys,":");i+=1)
//		key = stringfromlist(i,keys,":")
//		if(i==0)
//			index = 0
//		else
//			index = str2num(stringfromlist(i-1,indices,","))
//		endif
//		for(j=0;j<numpnts(t_tokentext);j+=1)
//			if(cmpstr(t_tokentext[j],key)==0 && w_tokensize[j]>0)
//				if(w_tokenparent[j]==index)
//					if(w_tokensize[j+1]>0)
//						k = j+1
//					else
//						k = j
//					endif
//					indices = addlistitem(num2str(k),indices,",",inf)
//					break
//				endif
//			endif
//		endfor
//	endfor
//
//	return indices
//end
//
//function fd_get_AWGparams_from_hdf(datnum, [fastdac_num])
//
//	variable datnum, fastdac_num
//	variable sl_id, fd_id  //JSON ids
//	nvar wavelen, numcycles
//	
//	struct AWGVars AWGLI
//	fd_getGlobalAWG(AWGLI); print AWGLI
//
//
//	fastdac_num = paramisdefault(fastdac_num) ? 1 : fastdac_num
//
//	if(fastdac_num != 1)
//		abort "WARNING: This is untested... remove this abort if you're feeling lucky!"
//	endif
//
//	sl_id = get_sweeplogs(datnum)  // Get Sweep_logs JSON;
//	fd_id = getJSONXid(sl_id, "FastDAC "+num2istr(fastdac_num)) // Get FastDAC JSON from Sweeplogs
//	
//	JSONXOP_GetValue/V fd_id, "/AWG/waveLen"
//	AWGLI.wavelen=V_value*10
//
//	JSONXOP_GetValue/V fd_id, "/AWG/numCycles"
//	AWGLI.numcycles=V_value*10;
//			
//	JSONXOP_Release /A  //Clear all stored JSON strings
//	
//end
//
//
//
function fd_getoldAWG(S,datnum,[fastdac_num, kenner])
	// Function to get old values for AWG that is stored in hdf file with filenum
	struct AWGVars &S
	variable datnum, fastdac_num
	string kenner
	kenner = selectString(paramisdefault(kenner), kenner, "")
	
	variable sl_id, fd_id  //JSON ids
	fastdac_num = paramisdefault(fastdac_num) ? 1 : fastdac_num

	if(fastdac_num != 1)
		abort "WARNING: This is untested... remove this abort if you're feeling lucky!"
	endif

	sl_id = get_sweeplogs(datnum, kenner=kenner)  // Get Sweep_logs JSON;
	fd_id = getJSONXid(sl_id, "FastDAC "+num2istr(fastdac_num)) // Get FastDAC JSON from Sweeplogs

	// Get variable parts

	//	JSONXOP_GetValue/V fd_id, "/AWG/initialized"
	//	S.initialized=V_value

	JSONXOP_GetValue/V fd_id, "/AWG/AWG_used"
	S.use_AWG=V_value

	S.lims_checked=0; //always 0

	JSONXOP_GetValue/V fd_id, "/AWG/waveLen"
	S.waveLen=V_value

	JSONXOP_GetValue/V fd_id, "/AWG/numADCs"
	S.numADCs=V_value

	JSONXOP_GetValue/V fd_id, "/AWG/samplingFreq"
	S.samplingFreq=V_value

	JSONXOP_GetValue/V fd_id, "/AWG/measureFreq"
	S.measureFreq=V_value

	JSONXOP_GetValue/V fd_id, "/AWG/numWaves"
	S.numWaves=V_value

	JSONXOP_GetValue/V fd_id, "/AWG/numCycles"
	S.numCycles=V_value


	JSONXOP_GetValue/V fd_id, "/AWG/numSteps"
	S.numSteps=V_value

	JSONXOP_GetValue/T fd_id, "/AWG/AW_Waves"
	S.AW_waves=S_value

	JSONXOP_GetValue/T fd_id, "/AWG/AW_Dacs"
	S.AW_dacs=S_value

	JSONXOP_Release /A  //Clear all stored JSON strings

end
//
//
//Structure AWGVars
//	// strings/waves/etc //
//	// Convenience
//	string AW_Waves		// Which AWs to use e.g. "2" for AW_2 only, "1,2" for fdAW_1 and fdAW_2. (only supports 1 and 2 so far)
//	
//	// Used in AWG_RAMP
//	string AW_dacs		// Dacs to use for waves
//							// Note: AW_dacs is formatted (dacs_for_wave0, dacs_for_wave1, .... e.g. '01,23' for Dacs 0,1 to output wave0, Dacs 2,3 to output wave1)
//
//	// Variables //
//	// Convenience	
//	variable initialized	// Must set to 1 in order for this to be used in fd_Record_Values (this is per setup change basis)
//	variable use_AWG 		// Is AWG going to be on during the scan
//	variable lims_checked 	// Have limits been checked before scanning
//	variable waveLen			// in samples (i.e. sum of samples at each setpoint for a single wave cycle)
//	
//	// Checking things don't change
//	variable numADCs  	// num ADCs selected to measure when setting up AWG
//	variable samplingFreq // SampleFreq when setting up AWG
//	variable measureFreq // MeasureFreq when setting up AWG
//
//	// Used in AWG_Ramp
//	variable numWaves	// Number of AWs being used
//	variable numCycles 	// # wave cycles per DAC step for a full 1D scan
//	variable numSteps  	// # DAC steps for a full 1D scan
//endstructure
//
//
//
//

function fd_getScanVars(S,datnum,[fastdac_num])
	// Function to get old values for AWG that is stored in hdf file with filenum
	struct ScanVars &S
	variable datnum, fastdac_num
	variable sl_id, fd_id  //JSON ids
	fastdac_num = paramisdefault(fastdac_num) ? 1 : fastdac_num

	if(fastdac_num != 1)
		abort "WARNING: This is untested... remove this abort if you're feeling lucky!"
	endif

	sl_id = get_sweeplogs(datnum)  // Get Sweep_logs JSON;
	fd_id = getJSONXid(sl_id, "FastDAC "+num2istr(fastdac_num)) // Get FastDAC JSON from Sweeplogs


	// Get variable parts


	JSONXOP_GetValue/V fd_id, "/MeasureFreq"
	S.MeasureFreq=V_value

	
	JSONXOP_Release /A  //Clear all stored JSON strings

end

function fd_getmeasfreq(datnum,[fastdac_num])
	// Function to get old h5 values for measurement frequency
	variable datnum, fastdac_num
	variable sl_id, fd_id  //JSON ids
	variable freq
	fastdac_num = paramisdefault(fastdac_num) ? 1 : fastdac_num

	if(fastdac_num != 1)
		abort "WARNING: This is untested... remove this abort if you're feeling lucky!"
	endif

	sl_id = get_sweeplogs(datnum)  // Get Sweep_logs JSON;
	fd_id = getJSONXid(sl_id, "FastDAC "+num2istr(fastdac_num)) // Get FastDAC JSON from Sweeplogs

	// Get variable parts

	//	JSONXOP_GetValue/V fd_id, "/AWG/initialized"
	//	S.initialized=V_value

	JSONXOP_GetValue/V fd_id, "MeasureFreq"
	freq=V_value

	JSONXOP_Release /A  //Clear all stored JSON strings
	
	return freq

end
//
///////////////////////////////////////////////////
////////////////////  ScanVars /////////////////// (scv_...)
//////////////////////////////////////////////////
//
//// Structure to hold scan information (general to all scans) 
//// Note: If modifying this, also modify the scv_setLastScanVars and scv_getLastScanVars accordingly (and to have it save to HDF, modify sc_createSweepLogs)
//structure ScanVars
//    variable instrIDx
//    variable instrIDy // If using a second device for second axis of a scan (otherwise should be same as instrIDx)
//    
//    variable lims_checked // Flag that gets set to 1 after checks on software limits/ramprates etc has been carried out (particularly important for fastdac scans which has no limit checking for the sweep)
//
//    string channelsx
//    variable startx, finx, numptsx, rampratex
//    variable delayx  // delay after each step for Slow scans (has no effect for Fastdac scans)
//    string startxs, finxs  // If sweeping from different start/end points for each channel or instrument
//
//    // For 2D scans
//    variable is2d
//    string channelsy 
//    variable starty, finy, numptsy, rampratey 
//    variable delayy  // delay after each step in y-axis (e.g. settling time after x-axis has just been ramped from fin to start quickly)
//    string startys, finys  // Similar for Y-axis
//
//    // For specific scans
//    variable alternate  // Allows controlling scan from start -> fin or fin -> start (with 1 or -1)
//    variable duration   // Can specify duration of scan rather than numpts or sweeprate for readVsTime
//	 variable readVsTime // Set to 1 if doing a readVsTime
//	 variable interlaced_y_flag // Whether there are different values being interlaced in the y-direction of the scan
//	 string interlaced_channels // Channels that the scan will interlace between 
//	 string interlaced_setpoints // Setpoints of each channel to interlace between e.g. "0,1,2;0,10,20" will expect 2 channels (;) which interlace between 3 values each (,)
//	 variable interlaced_num_setpoints // Number of setpoints for each channel (calculated in InitScanVars)
//	 variable prevent_2d_graph_updates // For fast x sweeps with large numptsy (e.g. 2k x 10k) the 2D graph update time becomes significant
//
//    // Other useful info
//    variable start_time // Should be recorded right before measurements begin (e.g. after all checks are carried out)
//    variable end_time // Should be recorded right after measurements end (e.g. before getting sweeplogs etc)
//    string x_label // String to show as x_label of scan (otherwise defaults to gates that are being swept)
//    string y_label  // String to show as y_label of scan (for 2D this defaults to gates that are being swept)
//    variable using_fastdac // Set to 1 when using fastdac
//    string comments  // Additional comments to save in HDF sweeplogs (easy place to put keyword flags for later analysis)
//
//    // Specific to Fastdac 
//    variable numADCs  // How many ADCs are being recorded 
//    variable samplingFreq, measureFreq  // measureFreq = samplingFreq/numADCs 
//    variable sweeprate  // How fast to sweep in mV/s (easier to specify than numpts for fastdac scans)
//    string adcList // Which adcs' are being recorded
//	 string raw_wave_names  // Names of waves to override the names raw data is stored in for FastDAC scans
//	 
//	 // Backend use
//     variable direction   // For keeping track of scan direction when using alternating scan
//	 variable never_save   // Set to 1 to make sure these ScanVars are never saved (e.g. if using to get throw away values for getting an ADC reading)
//	 variable filenum 		// Filled when getting saved
//
//endstructure
//
//function fd_get_fastdacs_from_hdf(datnum, [fastdac_num])
//	//Creates/Overwrites load_fdacvalstr by duplicating the current fdacvalstr then changing the labels and outputs of any values found in the metadata of HDF at dat[datnum].h5
//	//Leaves fdacvalstr unaltered	
//	variable datnum, fastdac_num
//	variable sl_id, fd_id  //JSON ids
//	
//	fastdac_num = paramisdefault(fastdac_num) ? 1 : fastdac_num 
//	
//	if(fastdac_num != 1)
//		abort "WARNING: This is untested... remove this abort if you're feeling lucky!"
//	endif
//	
//	sl_id = get_sweeplogs(datnum)  // Get Sweep_logs JSON
//	fd_id = getJSONXid(sl_id, "FastDAC "+num2istr(fastdac_num)) // Get FastDAC JSON from Sweeplogs
//
//	wave/t keys = JSON_getkeys(fd_id, "")
//	wave/t fdacvalstr
//	duplicate/o/t fdacvalstr, load_fdacvalstr
//	
//	variable i
//	string key, label_name, str_ch
//	variable ch = 0
//	for (i=0; i<numpnts(keys); i++)  // These are in a random order. Keys must be stored as "DAC#{label}:output" in JSON
//		key = keys[i]
//		if (strsearch(key, "DAC", 0) != -1)  // Check it is actually a DAC key and not something like com_port
//			SplitString/E="DAC(\d*){" key, str_ch //Gets DAC# so that I store values in correct places
//			ch = str2num(str_ch)
//			
//			load_fdacvalstr[ch][1] = num2str(JSON_getvariable(fd_id, key))
//			SplitString/E="{(.*)}" key, label_name  //Looks for label inside {} part of e.g. BD{label}
//			label_name = replaceString("~1", label_name, "/")  // Somehow igor reads '/' as '~1' don't know why...
//			load_fdacvalstr[ch][3] = label_name
//		endif
//	endfor
//	JSONXOP_Release /A  //Clear all stored JSON strings
//end