#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Datafolder structure:
//root:
//		connections:
//				device_name:
//						session
//						instr
//		gNumDevices
//		devices_name
//		devices_address
//		devices_query
//		other variables/folders

//Threads:
//Give each thread duplicate conenctions folder and specific device from which to read
//Read function only accesses conenction given name

//TODO:
//-Data acquisition
//-Query functions

///////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////// Read Functions /////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////

//threadGroupID: the group the thread belongs to
//device_name: alias of which device to read from
//query: the GPIB string query for the device
Threadsafe Function ReadInstrumentAsync(threadGroupID, device_name, query)
	variable threadGroupID
	String device_name
	String query
	
	//get duplicate connections data folder passed to thread group
	//access instr for given device_name
	DFREF dfr = ThreadGroupGetDFR(0,inf)
	if( DataFolderRefStatus(dfr) == 0 )
		return -1 // Thread is being killed endif
	endif
	SetDataFolder dfr
	nvar/z instr = $(":"+device_name+":instr")
	
	//read from device
	Variable cN
	string readstr
	//TODO: query functions should also pass parameters for bit sizes
	viWrite(instr, query, 6, cN) //Why not use VISAWrite
	viRead(instr, readstr, 1024, cN) //Why not use VISARead
	//TODO: return data
	return 5
end

//threadGroupID: the group the thread belongs to
//device_name: alias of which device to read from
Threadsafe function getX(threadGroupID, device_name)
	variable threadGroupID
	String device_name
	//TODO: replace actual queries
	return ReadInstrumentAsync(threadGroupID, device_name, "*IDN?\n")
end

//threadGroupID: the group the thread belongs to
//device_name: alias of which device to read from
threadsafe function getY(threadGroupID, device_name)
	variable threadGroupID
	String device_name
	//TODO: replace actual queries
	return ReadInstrumentAsync(threadGroupID, device_name, "*IDN?\n")
end

//threadGroupID: the group the thread belongs to
//device_name: alias of which device to read from
threadsafe function getFreq(threadGroupID, device_name)
	variable threadGroupID
	String device_name
	//TODO: replace actual queries
	return ReadInstrumentAsync(threadGroupID, device_name, "*IDN?\n")
end

///////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////// Async Functions /////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////

//threadGroupID: the group the thread belongs to
//device_name: alias of which device to read from
Threadsafe function getFunc(threadGroupID, device_name)
	string device_name
	variable threadGroupID
	/// this function will be used to format all getData() functions using FUNCREF
end	

//initialize the devices
//- number of devices
//- GPIB address
//- name/alias used to identify/read from them etc.
//- query for the device
//index of device address, name and query must correlate
function initDevices()
	variable /g gNumDevices = 2
	make /O/T devices_address = {"GPIB1::1::INSTR", "GPIB1::3::INSTR", "GPIB1::4::INSTR", "GPIB1::5::INSTR", "GPIB1::25::INSTR"}
	make /O/T devices_name = {"one", "three", "four", "five", "twentyfive"}
	make /o/t devices_query = {"getX", "getY", "getX", "getY", "getY"}
	variable i=0
	do
		open_comms(devices_name[i], devices_address[i])
		i=i+1
	while(i<gNumDevices)
end

//kill golbal variables from device init
function killDevices()
	NVAR numDevices = root:gNumDevices 
	wave /T devices_name
	variable i=0
	do
		close_comms(devices_name[i])
		i=i+1
	while(i<numDevices)
	variable /g gNumDevices = 0
	killwaves /z devices_address
	killwaves /z devices_name
	killwaves /z devices_query
end

//create worker thread for a single read from a single device
//device_name: device to read
//query: query for given device defined in initDevices
ThreadSafe Function sc_ActionWorker(threadGroupID, device_name, query)
	// this is the code that will be running in the thread for a given action
	string device_name
	String query
	variable threadGroupID
		
	FUNCREF getFunc actionFunc = $query
	return actionFunc(threadGroupID, device_name)
end

//start all threads in thread group: should be one thread for each device. i.e. single async read of all devices
//gives each thread duplicate of connections data folder
Function sc_StartActionThreads()
	wave /T devices_name
	wave /T devices_query
	NVAR numDevices = root:gNumDevices 
	//create group for threads
	variable threadGroupID = ThreadGroupCreate(numDevices)
 	//create threads
	variable i=0
 	do
 		//duplicate connections folder
		//each thread gets a copy of entire device init
		//will only access the init under it's name
	 	duplicatedatafolder root:connections, root:copy
 		ThreadGroupPutDF threadGroupID, root:copy
 		ThreadStart threadGroupID, i, sc_ActionWorker(threadGroupID, devices_name[i], devices_query[i])
 		i=i+1
 	while(i<numDevices)
 	//return threadgroup
 	return threadGroupID
End

//complete thread group properly
Function sc_StopActionThreads(threadGroupID)
	variable threadGroupID
	
	if (threadGroupID != 0)
		// We are done - kill the threads
		Variable releaseResult = ThreadGroupRelease(threadGroupID)
		if (releaseResult != 0)
			Printf "ThreadGroupRelease failed, result=%d\r", releaseResult
		endif
		threadGroupID = 0
	endif
	
	return threadGroupID
end

//perform async data acquisition
//data: wave in which to store data
function sc_GetDataAsync(data)
	wave data
	nvar numdevices = root:gNumDevices
	
	variable threadGroupID = sc_StartActionThreads() // start threads

	// wait until threads complete
	variable waitFlag = -1, waitms = 500.0
	do
		waitFlag = ThreadGroupWait(threadGroupID, waitms)
		if(waitFlag==0)
			break
		else
			sleep /S 5.0e-3
		endif
	while(1)	
	
	// get results from threads using return value
	variable result = 0, i = 0
	for(i=0; i<numDevices; i+=1)
		result = ThreadReturnValue(threadGroupID, i)
		//TODO: Get data
//		print result
	endfor

	if(sc_StopActionThreads(threadGroupID)==0)
		return 1 // all good!
	else
		return 0 // trouble!
	endif
end

///////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////// Test Functions /////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////

//numpts - int
//delays - seconds
function testAsync(numpts, delay)
	variable numpts, delay
	
	//initalize read functions
	initDevices()
	wave /t devices_name
	nvar numDevices = root:gNumDevices
		
	//wave to store data
	Make/O/N=(numpts, numDevices) data
	
	//perform read
	variable i=0, ttotal = 0, tstart = datetime
	do
		sleep /S delay
		sc_GetDataAsync(data)
		i+=1
	while (i<numpts)
	
	//calculate time
	ttotal = datetime-tstart
	printf "each sleep(...) + getDataAsync(...) call takes ~%.1fms \n", ttotal/numpts*1000
	
	//close comms
	killDevices()
end

///////////////////////////////////////////////////////////////////////////////////////
////////////////// Initializing and Closing GPIB Connections //////////////////////////
///////////////////////////////////////////////////////////////////////////////////////

threadsafe function check_folder(data_folder)
	string data_folder
	if (DataFolderExists(data_folder) != 1)
		newdatafolder/O $data_folder
	endif
end

function open_comms(device_name, resourceName)
	string device_name, resourceName
	string data_folder = "root:connections"
	check_folder(data_folder)
	data_folder += ":" + device_name
	check_folder(data_folder)
	nvar/z session = $(data_folder + ":session")
	nvar/z instr = $(data_folder + ":instr")
	if (!nvar_exists(instr))
		variable/g $(data_folder + ":instr") = -1
	endif
	if (!nvar_exists(session))
		variable/g $(data_folder + ":session") = -1
	endif
	nvar session = $(data_folder + ":session")
	nvar instr = $(data_folder + ":instr")
	
	if (session != -1 || instr != -1)
//		print device_name, ": comms already open:", session, instr
	endif
	
	variable status, instr_id = session, session_id = session
	string error_message
	status = viOpenDefaultRM(session_id)
	if (status < 0)
		viStatusDesc(instr_id, status, error_message)
		abort "OpenDefaultRM error: " + error_message
	endif
	status = viOpen(session_id, resourceName, 0, 0, instr_id)
	if (status < 0)
		viStatusDesc(instr_id, status, error_message)
		abort "Open error: " + error_message
	endif
   session = session_id
   instr = instr_id
	return status
end

function close_comms(device_name)
	string device_name
	string data_folder = "root:connections:" + device_name
	nvar/z session = $(data_folder + ":session")
	nvar/z instr = $(data_folder + ":instr")
	if (!nvar_exists(instr))
		variable/g $(data_folder + ":instr") = -1
	endif
	if (!nvar_exists(session))
		variable/g $(data_folder + ":session") = -1
	endif
	
	// check if comms are already closed
	if (session == -1 || instr == -1)
		print device_name, ": comms already closed"
		return 0
	endif
	
	variable session_id = session, instr_id = instr, status
	string error_message
	status = viClose(session_id)
	if (status < 0)
		viStatusDesc(instr_id, status, error_message)
		abort "Close error: " + error_message
	endif
	
	session = -1; instr = -1
	return status
end