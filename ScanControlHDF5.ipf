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

	// Create data array group
	variable /G data_group_ID
	HDF5CreateGroup hdf5_id, "data_arrays", data_group_ID
	
end

function saveSingleWave(wn)
	// wave with name 'filename' as filename.ibw
	string wn
	nvar data_group_id

	HDF5SaveData /IGOR=-1 /TRAN=1 /WRIT=1 /Z $wn , data_group_id
	if (V_flag != 0)
		Print "HDF5SaveData failed: ", wn
	endif
end

function endSaveFiles()
	//// close any files that were created for this dataset
	
	nvar filenum
	string filenumstr = ""
	sprintf filenumstr, "%d", filenum
	string /g h5name = "dat"+filenumstr+".h5"
	
	// close data_array group
	nvar data_group_id
	HDF5CloseGroup /Z data_group_id
	if (V_flag != 0)
		Print "HDF5CloseGroup Failed: ", "data_arrays"
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