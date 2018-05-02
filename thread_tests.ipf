#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Datafolder structure:   -- move this structure from root to some connections path
//data:
//		connections:
//              -- put session here (only need one for the whole set) --
//				device_name:
//						session -- remove this
//						instr
//		gNumDevices -- i think this only existed for testing
//		devices_name
//		devices_address
//		devices_query

//Threads:
//Give each thread duplicate conenctions folder and specific device from which to read
//Read function only accesses conenction given name

// TODO: figure out what the fuck Ro-ee wrote in here

//////////////////////
/// Read Functions ///
//////////////////////

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
		return -1 // Thread is being killed
	endif
	SetDataFolder dfr
	nvar/z instr = $(":"+device_name+":instr")

	//read from device
	Variable cN
	string readstr
	//TODO: query functions should also pass parameters for bit sizes??
	viWrite(instr, query, 6, cN)
	viRead(instr, readstr, 1024, cN)
	//TODO: return data??
	return 5
end

//threadGroupID: the group the thread belongs to
//device_name: alias of which device to read from
threadsafe function getIDN(threadGroupID, device_name)
	variable threadGroupID
	String device_name

	return ReadInstrumentAsync(threadGroupID, device_name, "*IDN?\n")
end

///////////////////////
/// async functions ///
///////////////////////

//threadGroupID: the group the thread belongs to
//device_name: alias of which device to read from
threadsafe function getFunc(threadGroupID, device_name)
	string device_name
	variable threadGroupID
	/// this function will be used to format all getData() functions using FUNCREF
end

//create worker thread for a single read from a single device
//device_name: device to read
//query: query for given device defined in initDevices
threadSafe Function sc_ActionWorker(threadGroupID, device_name, query)
	// this is the code that will be running in the thread for a given action
	string device_name
	String query
	variable threadGroupID

	FUNCREF getFunc actionFunc = $query
	return actionFunc(threadGroupID, device_name)
end

function sc_StartActionThreads()
    //start all threads in thread group:
    //    should be one thread for each device (true?)
    // gives each thread duplicate of connections data folder
	wave /T devices_name
	wave /T devices_query

	variable threadGroupID = ThreadGroupCreate(numDevices) //create group for threads

    //create each thread in loop
	variable i=0
 	for(i=0;i<numpts(devices_name);i+=1)

	 	duplicatedatafolder data:connections, data:copy //duplicate connections folder
 		ThreadGroupPutDF threadGroupID, data:copy       //each thread gets a copy of entire device init
                                                        // and will only access the init under its name
 		ThreadStart threadGroupID, i, sc_ActionWorker(threadGroupID, devices_name[i], devices_query[i]) // start thread
    endfor

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

function sc_GetDataAsync(data)
    //perform async data acquisition
    //data: wave in which to store data
	wave async_data
	nvar numdevices = data:gNumDevices // is there another way to get this number?

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
//		print result
	endfor

	if(sc_StopActionThreads(threadGroupID)==0)
		return 1 // all good!
	else
		return 0 // trouble!
	endif
end

////////////////////
/// open devices ///
////////////////////

function check_folder(data_folder)
    // move to ScanController_v2.0 -- if it is really necessary
    // check if folder exists
    // create it if it does not

	string data_folder
	if (DataFolderExists(data_folder) != 1)
		newdatafolder/O $data_folder
	endif
end

function open_comms(device_name, resourceName)
    // this should be merged with ScanController_VISA:openInstr(...)
    string device_name, resourceName

    // setup folder structure
	string data_folder = "data:connections"
	check_folder(data_folder)

	data_folder += ":" + device_name
	check_folder(data_folder)

    // check if session/instrument are open
	nvar /z session = $(data_folder + ":session")
	nvar /z instr = $(data_folder + ":instr")
	if (!nvar_exists(instr))
		variable/g $(data_folder + ":instr") = -1
	endif
	if (!nvar_exists(session))
		variable/g $(data_folder + ":session") = -1
	endif
	nvar session = $(data_folder + ":session")
	nvar instr = $(data_folder + ":instr")

	// if (session != -1 || instr != -1)
		// print device_name, ": comms already open:", session, instr
	// endif

    variable status, instr_id = session, session_id = session
    string error_message

    // open resource manager
    status = viOpenDefaultRM(session_id)
    if (status < 0)
    	viStatusDesc(instr_id, status, error_message)
    	abort "OpenDefaultRM error: " + error_message
    endif

    // open instrument
    status = viOpen(session_id, resourceName, 0, 0, instr_id)
    if (status < 0)
    	viStatusDesc(instr_id, status, error_message)
    	abort "Open error: " + error_message
    endif

    session = session_id
    instr = instr_id
    return status
end

function initDevices()

    // figure out how to generate these lists from ScanControl data
    // put it in InitalizeWaves()
	make /O/T devices_address = {"GPIB0::1::INSTR", "GPIB0::2::INSTR", "GPIB0::18::INSTR", "ASRL2::INSTR"}
	make /O/T devices_name = {"srs1", "srs2", "dmm18", "ips2"} // variable names
	make /o/t devices_query = {"getX", "getY", "getX", "getY"} // functions to call
	variable i=0

	do
		open_comms(devices_name[i], devices_address[i])
		i=i+1
	while(i<numpts(devices_address))

end

/////////////////////
/// close devices ///
/////////////////////

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


/////////////////////
/// test function ///
/////////////////////

function testAsync(numpts, delay)
    //numpts - int
    //delays - seconds
	variable numpts, delay

	//initalize read functions
	initDevices()
	wave /t devices_name
	nvar numDevices = root:gNumDevices

	//wave to store data
	Make/O/N=(numpts, numDevices) async_data

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
