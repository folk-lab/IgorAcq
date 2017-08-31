#pragma rtGlobals=3		// Use modern global access method and strict wave access.


// these tests do exactly what I wanted
// Async is a considerable speed improvement over Sync
// the problem is that none of the existing instrument communication XOPs are threadsafe
// Options:
//     



//// All the getFuncs (and any functions/XOPs they call) must be threadSafe ////

ThreadSafe function getFunc()
	/// this function will be used to format all getData() functions using FUNCREF
end	

ThreadSafe function gett1x()
	sleep /s 0.05
	return enoise(1, 2)
end
	
ThreadSafe function gett2x()

	sleep /s 0.1
	return 5*sin(enoise(pi, 2))+10
end

ThreadSafe function gett3x()

	sleep /s 0.05
	return enoise(3, 2)^2-10
end

//// a real cheap version of ScanController ////

function initActions()
	variable /g gNumActions = 3
	make /O/T sc_actions = {"gett1x", "gett2x", "gett3x"}
end

//// Worker function for threads ////

ThreadSafe Function sc_ActionWorker(func)
	// this is the code that will be running in the thread for a given action
	string func
	
	FUNCREF getFunc actionFunc = $func
	
	variable result = actionFunc()
	return result
end

//// Start/Stop threads ////

Function sc_StartActionThreads()
	wave /T sc_actions
	
	// Create thread group and start worker threads
	variable threadGroupID = ThreadGroupCreate(numpnts(sc_actions))
	Variable i
	for(i=0; i<numpnts(sc_actions); i+=1)
		ThreadStart threadGroupID, i, sc_ActionWorker(sc_actions[i])
	endfor
	return threadGroupID
End

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

//// do data acquisition ////

function sc_GetDataAsync()
	wave /T sc_actions
	
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
	
	// get results from threads
	variable result = 0, i = 0
	for(i=0; i<numpnts(sc_actions); i+=1)
		result = ThreadReturnValue(threadGroupID, i)
	endfor

	if(sc_StopActionThreads(threadGroupID)==0)
		return 1 // all good!
	else
		return 0 // trouble!
	endif
end

function sc_GetDataSync()
	wave /T sc_actions
	
	// get values
	variable result = 0, i = 0
	for(i=0; i<numpnts(sc_actions); i+=1)
		FUNCREF getFunc actionFunc = $sc_actions[i]
		result = actionFunc()
	endfor

end

//// Test functions /////

function testAsync(numpts, delay) //Units: s
	variable numpts, delay

	initActions()
	variable i=0, ttotal = 0, tstart = datetime
	do
		sleep /S delay
		sc_GetDataAsync()
		i+=1
	while (i<numpts)
	ttotal = datetime-tstart
	printf "each sleep(...) + getDataAsync(...) call takes ~%.1fms \n", ttotal/numpts*1000
	
end

function testSync(numpts, delay) //Units: s
	variable numpts, delay

	initActions()
	variable i=0, ttotal = 0, tstart = datetime
	do
		sleep /S delay
		sc_GetDataSync()
		i+=1
	while (i<numpts)
	ttotal = datetime-tstart
	printf "each sleep(...) + getDataSync(...) call takes ~%.1fms \n", ttotal/numpts*1000
	
end