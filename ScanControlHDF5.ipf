#pragma rtGlobals=1		// Use modern global access method.

// Save all experiment data in native IGOR formats
//
// Waves are saved in HDF5
// Experiments are saved as .pxp
// meta data is dumped into HDF5 as JSON formatted text
// 

// structure of h5 file
// 
// there is a root group "/"
// can create other groups "/GroupA"....
// each group can contain datasets or additional groups "/GroupA/Subgroup"
// each dataset can have attributes associated with it (like datasets themselves, but attached to a dataset)
// groups may also have attributes attached to them

///////////////////////
//// get meta data ////
///////////////////////

function /S recordedWaveArray()
	wave /T sc_RawWaveNames, sc_CalcWaveNames
	wave sc_RawRecord, sc_CalcRecord
	string swave=""
	variable i=0
	do
		if(strlen(sc_RawWaveNames[i])!=0 && sc_RawRecord[i]==1)
			swave += "\""+sc_RawWaveNames[i]+"\", "
		endif
		i+=1
	while(i<numpnts(sc_RawWaveNames))
	
	i=0
	do
		if(strlen(sc_CalcWaveNames[i])!=0 && sc_CalcRecord[i]==1)
			swave += "\""+sc_CalcWaveNames[i]+"\", "
		endif
		i+=1
	while(i<numpnts(sc_CalcWaveNames))
	
	return "["+swave[0,strlen(swave)-3]+"]"
end

function /s json2attributes(jstr, obj_name, h5id)
	// writes key/value pairs from jstr as attributes of "obj_name" 
	// in the hdf5 file or group identified by h5id
	string jstr, obj_name
	variable h5id
	
	make /FREE /T /N=1 str_attr = ""
	make /FREE /N=1 num_attr = 0
	
	// loop over keys
	string keys = getJSONkeys(jstr)
	variable j = 0, numKeys = ItemsInList(keys, ",")
	string currentKey = "", currentVal = ""
	string group = ""
	for(j=0;j<numKeys;j+=1)
		currentKey = StringFromList(j, keys, ",")
		if(strsearch(currentKey, ":", 0)==-1)
			currentVal = getJSONValue(jstr, currentKey) 
			if(findJSONtype(currentVal)==3)
				num_attr[0] = str2num(currentVal)
				HDF5SaveData /A=currentKey num_attr, h5id, obj_name
			else
				str_attr[0] = currentVal
				HDF5SaveData /A=currentKey str_attr, h5id, obj_name
			endif
		endif
	endfor
	
end

///////////////////////////////////
//// save waves and experiment ////
///////////////////////////////////

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
	json2attributes(getExpStatus(), "metadata", hdf5_id) // add experiment metadata
	
	// Create config group
	svar sc_current_config
	variable /G config_group_ID
	HDF5CreateGroup hdf5_id, "config", config_group_ID
	json2attributes(JSONfromFile("config", sc_current_config), "config", hdf5_id) // add current scancontroller config
	
	// Create logs group
	svar sc_current_config
	variable /G logs_group_ID
	HDF5CreateGroup hdf5_id, "logs", logs_group_ID
	json2attributes(getEquipLogs(), "logs", hdf5_id) // add current scancontroller config
	
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
	 json2attributes(getWaveStatus(wn), wn, hdf5_id)
end

function endSaveFiles()
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