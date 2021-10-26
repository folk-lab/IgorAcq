// Structure to hold scan information (general to all scans)
structure ScanVars
    variable instrID
    
    variable lims_checked // Flag that gets set to 1 after checks on software limits/ramprates etc has been carried out

    string channelsx
    variable startx, finx, numptsx, rampratex
    variable delayx

    // For 2D scans
    variable is2d
    string channelsy 
    variable starty, finy, numptsy, rampratey 
    variable delayy

    // For scanRepeat
    variable direction

    // Other useful info
    variable start_time // Should be recorded right before measurements begin (e.g. after all checks are carried out)
    variable end_time // Should be recorded right after measurements end (e.g. before getting sweeplogs etc)
    string x_label
    string y_label
    variable using_fastdac // Set to 1 when using fastdac

    // ScanControllerInfo 
    // string activeGraphs


    // Specific to Fastdac 
    variable numADCs
    variable samplingFreq, measureFreq
    variable sweeprate
    string adcList
    string startxs, finxs
    string startys, finys
endstructure

function initFDscanVars(S, instrID, startx, finx, channelsx, [numptsx, sweeprate, rampratex, delayx, starty, finy, channelsy, numptsy, rampratey, delayy, direction, startxs, finxs, startys, finys])
    // Function to make setting up scanVars struct easier for FastDAC scans
    // PARAMETERS:
    // startx, finx, starty, finy -- Single start/fin point for all channelsx/channelsy
    // startxs, finxs, startys, finys -- For passing in multiple start/fin points for each channel as a comma separated string instead of a single start/fin for all channels
    //		Note: Just pass anything for startx/finx if using startxs/finxs, they will be overwritten
    struct ScanVars &S
    variable instrID
    variable startx, finx, numptsx, delayx, rampratex
    variable starty, finy, numptsy, delayy, rampratey
    string channelsx
    string channelsy
    string startxs, finxs, startys, finys
    variable direction, sweeprate

    // Handle Optional Parameters
    S.numptsx = paramisdefault(numptsx) ? NaN : numptsx
    S.rampratex = paramisDefault(rampratex) ? NaN : rampratex
    S.delayx = paramisDefault(delayx) ? NaN : delayx

    S.sweeprate = paramisdefault(sweeprate) ? NaN : sweeprate  // TODO: Should this be different?

	 S.numptsy = paramisdefault(numptsy) ? NaN : numptsy
    S.rampratey = paramisdefault(rampratey) ? NaN : rampratey
    S.delayy = paramisdefault(delayy) ? NaN : delayy

	// Set Variables in Struct
    S.instrID = instrID
    S.adcList = SFfd_get_adcs()
    S.using_fastdac = 1

	// For repeat scans 
    S.direction = paramisdefault(direction) ? 1 : direction
   	
   	// Sets channelsx, channelsy and is2d
    setChannels(S, channelsx, channelsy, fastdac=1)

   	// Sets starts/fins in FD string format
    setFDsetpoints(S, channelsx, startx, finx, channelsy, starty, finy, startxs, finxs, startys, finys)
	
	// Set variables with some calculation
    setNumptsSweeprate(S) 	// Checks that either numpts OR sweeprate was provided, and sets both in ScanVars accordingly
                                    // Note: Valid for same start/fin points only (uses S.startx, S.finx NOT S.startxs, S.finxs)
    setMeasureFreq(S) 		// Sets S.samplingFreq/measureFreq/numADCs	
   
end

function setNumptsSweeprate(S)
	Struct ScanVars &S
	 // If NaN then set to zero so rest of logic works
   if(numtype(S.sweeprate) == 2)
   		S.sweeprate = 0
   	endif
   
   // Chose which input to use for numpts of scan
   if (S.numptsx == 0 && S.sweeprate == 0)
      abort "ERROR[ScanFastDac]: User must provide either numpts OR sweeprate for scan [neither provided]"
   elseif (S.numptsx!=0 && S.sweeprate!=0)
      abort "ERROR[ScanFastDac]: User must provide either numpts OR sweeprate for scan [both provided]"
   elseif (S.numptsx!=0) // If numpts provided, just use that
      S.sweeprate = fd_get_sweeprate_from_numpts(S.instrID, S.startx, S.finx, S.numptsx)
   elseif (S.sweeprate!=0) // If sweeprate provided calculate numpts required
      S.numptsx = fd_get_numpts_from_sweeprate(S.instrID, S.startx, S.finx, S.sweeprate)
   endif
end

function setMeasureFreq(S)
	Struct ScanVars &S
   S.samplingFreq = getfadcSpeed(S.instrID)
   S.numADCs = getNumFADC()
   S.measureFreq = S.samplingFreq/S.numADCs  //Because sampling is split between number of ADCs being read //TODO: This needs to be adapted for multiple FastDacs

end

function initBDscanVars(S, instrID, startx, finx, channelsx, [numptsx, sweeprate, delayx, rampratex, starty, finy, channelsy, numptsy, rampratey, delayy, direction])
    // Function to make setting up scanVars struct easier for FastDAC scans
    // PARAMETERS:
    // startx, finx, starty, finy -- Single start/fin point for all channelsx/channelsy
    // startxs, finxs, startys, finys -- For passing in multiple start/fin points for each channel as a comma separated string instead of a single start/fin for all channels
    //		Note: Just pass anything for startx/finx if using startxs/finxs, they will be overwritten
    struct ScanVars &s
    variable instrID
    variable startx, finx, numptsx, delayx, rampratex
    variable starty, finy, numptsy, delayy, rampratey
    string channelsx
    string channelsy
    variable direction, sweeprate

    // Handle Optional Parameters
    s.numptsx = paramisdefault(numptsx) ? NaN : numptsx
    s.rampratex = paramisDefault(rampratex) ? NaN : rampratex
    s.delayx = paramisDefault(delayx) ? NaN : delayx

    s.sweeprate = paramisdefault(sweeprate) ? NaN : sweeprate  // TODO: Should this be different?

	s.numptsy = paramisdefault(numptsy) ? NaN : numptsy
    s.rampratey = paramisdefault(rampratey) ? NaN : rampratey
    s.delayy = paramisdefault(delayy) ? NaN : delayy

	// Set Variables in Struct
    s.instrID = instrID

	// For repeat scans 
    s.direction = paramisdefault(direction) ? 1 : direction
   	
   	// Sets channelsx, channelsy and is2d
    setChannels(S, channelsx, channelsy, fastdac=0)
end

function setChannels(S, channelsx, channelsy, [fastdac])
    // Set S.channelsx and S.channelys converting channel labels to numbers where necessary
    // Note: Also sets S.is2d
    struct ScanVars &S
    string channelsx, channelsy
    variable fastdac

    s.channelsx = SF_get_channels(channelsx, fastdac=fastdac)

	if (numtype(strlen(channelsy)) != 0 || strlen(channelsy) == 0)  // No Y set at all
		s.starty = NaN
		s.finy = NaN
		s.channelsy = ""
        s.is2d = 0
	else
		s.channelsy = SF_get_channels(channelsy, fastdac=fastdac)
       s.is2d = 1
    endif
end

function setFDsetpoints(S, channelsx, startx, finx, channelsy, starty, finy, startxs, finxs, startys, finys)

    struct ScanVars &S
    variable startx, finx, starty, finy
    string channelsx, startxs, finxs, channelsy, startys, finys

	string starts, fins
    // Set X
   	if ((numtype(strlen(startxs)) != 0 || strlen(startxs) == 0) && (numtype(strlen(finxs)) != 0 || strlen(finxs) == 0))  // Then just a single start/end for channelsx
   		s.startx = startx
		s.finx = finx	
        SFfd_format_setpoints(startx, finx, S.channelsx, starts, fins)  
		s.startxs = startxs
		s.finxs = finxs
	elseif (!(numtype(strlen(startxs)) != 0 || strlen(startxs) == 0) && !(numtype(strlen(finxs)) != 0 || strlen(finxs) == 0))
		SFfd_sanitize_setpoints(startxs, finxs, S.channelsx, starts, fins)
		s.startx = str2num(StringFromList(0, starts, ","))
		s.finx = str2num(StringFromList(0, fins, ","))
		s.startxs = starts
		s.finxs = fins
	else
		abort "If either of startxs/finxs is provided, both must be provided"
	endif

    // If 2D then set Y
    if (S.is2d) 
        if ((numtype(strlen(startys)) != 0 || strlen(startys) == 0) && (numtype(strlen(finys)) != 0 || strlen(finys) == 0))  // Single start/end for Y
            s.starty = starty
            s.finy = finy	
            SFfd_format_setpoints(S.starty, S.finy, S.channelsy, starts, fins)  
            s.startys = starts
            s.finys = fins
        elseif (!(numtype(strlen(startys)) != 0 || strlen(startys) == 0) && !(numtype(strlen(finys)) != 0 || strlen(finys) == 0)) // Multiple start/end for Ys
            SFfd_sanitize_setpoints(startys, finys, S.channelsy, starts, fins)
            s.starty = str2num(StringFromList(0, starts, ","))
            s.finy = str2num(StringFromList(0, fins, ","))
            s.startys = starts
            s.finys = fins
        else
            abort "Something wrong with Y part. Note: If either of startys/finys is provided, both must be provided"
        endif
    endif
end




function initializeScan(S)
    // Opens instrument connection, initializes waves to store data, opens and tiles graphs, opens abort window.
    struct ScanVars &S
    variable fastdac

    // Kill and reopen connections (solves some common issues)
    killVISA()
    sc_OpenInstrConnections(0)

    // Make sure waves exist to store data
    new_initializeWaves(S)
    // TODO: Might need to get the S.adcList differently because sc_fastadc is no longer created in initWaves

    // Set up graphs to display recorded data
    string activeGraphs
    activeGraphs = initializeGraphs(S)
    arrangeWindows(activeGraphs)

    // Open Abort window
    openAbortWindow()

	// Make waves for storing sweepgates, starts, ends for both x and y
    // TODO: Move this into InitScan()???
	// SFfd_create_sweepgate_save_info(S)
end


function new_initializeWaves(S)
    // Initializes the waves necessary for recording scan
	//  Need 1D and 2D waves for the raw data coming from the fastdac (2D for storing, not necessarily displaying)
	// 	Need 2D waves for either the raw data, or filtered data if a filter is set
	//		(If a filter is set, the raw waves should only ever be plotted 1D)
	//		(This will be after calc (i.e. don't need before and after calc wave))
    struct ScanVars &S
    variable fastdac

    variable numpts  // Numpts to initialize wave with, note: for Filtered data, this number is reduced
    string wavenames, wn
    variable i, j
    for (i = 0; i<2; i++) // 0 = Calc, 1 = Raw
        wavenames = get1DWaveNames(i, S.using_fastdac)
        sanityCheckWavenames(wavenames)
        numpts = (i) ? S.numptsx : postFilterNumpts(S.numptsx)  // Selects S.numptsx for i=1(Raw) and calculates numpts for i=0(Calc)
        for (j=0; j<itemsinlist(wavenames);j++)
            wn = stringFromList(i, wavenames)
            init1DWave(wn, numpts, S.startx, S.finx)
            if (S.is2d == 1)
                init2DWave(wn+"_2d", numpts, S.startx, S.finx, S.numptsy, S.starty, S.finy)
            elseif (S.is2d == 2)
                abort "Need to fix how waves are initialized, i.e. need to replicate something like the commented code below instead of just init1Dwave(...)"
					// cmd = "make /o/n=(1, " + num2istr(sc_numptsy) + ") " + wn2d + "=NaN"; execute(cmd) //Makes 1 by y wave, x is redimensioned in recordline
					// cmd = "setscale /P x, 0, " + num2str((sc_finx-sc_startx)/sc_numptsx) + "," + wn2d; execute(cmd) //sets x scale starting from 0 but with delta correct
					// cmd = "setscale /i y, " + num2str(sc_starty) + ", " + num2str(sc_finy) + ", " + wn2d; execute(cmd)//Useful to see if top and bottom of scan are filled with NaNs
            endif
        endfor
    endfor

    // If a linecut scan, then initialize the Row start X value wave
    if (S.is2d == 2) 
        init1DWave("sc_linestart", numpts, S.starty, S.finy)  // Wave to store first X value for each sweep
    endif

    // TODO: This is where x_array and y_array were made, but that should just be done in the savewaves part now
end

function postFilterNumpts(raw_numpts)
    // Returns number of points that will exist after applying lowpass filter specified in ScanController_Fastdac
    variable raw_numpts

    // TODO: do this.

end

function init1DWave(waveName, numpts, start, fin)
    // Overwrites waveName with scaled wave from start to fin with numpts
    string waveName
    variable numpts, start, fin
    string cmd
    make/O/n=(numpts) $waveName = NaN  // TODO: can put in a cmd and execute if necessary
    cmd = "setscale/I x " + num2str(start) + ", " + num2str(fin) + ", " + waveName; execute(cmd)
end

function init2DWave(waveName, numptsx, startx, finx, numptsy, starty, finy)
    // Overwrites waveName with scaled wave from start to fin with numpts
    string waveName
    variable numptsx, startx, finx, numptsy, starty, finy
    string cmd
    make/O/n=(numptsx, numptsy) $waveName = NaN  // TODO: can put in a cmd and execute if necessary
    cmd = "setscale/I x " + num2str(startx) + ", " + num2str(finx) + ", " + waveName; execute(cmd)
	cmd = "setscale/I y " + num2str(starty) + ", " + num2str(finy) + ", " + waveName; execute(cmd)
end

function/t get1DWaveNames(raw, fastdac)
    // Return a comma separated list of Raw or Calc wavenames (without any checks)
    variable raw, fastdac  // 1 for True, 0 for False
    string wavenames
    variable i
    wave fadcattr
    if (fastdac == 1) 
        wave/t fadcvalstr
        for (i = 0; i<dimsize(fadcvalstr, 0); i++)
            if (fadcattr[i][2] == 48) // Checkbox checked
                if (raw == 1)
                    wavenames = addlistItem("ADC"+num2str(i), wavenames)  
                else 
                    wavenames = addlistItem(fadcvalstr[i][3], wavenames)  
                endif
            endif
        endfor
    else  // Regular ScanController
        wave sc_RawRecord, sc_RawWaveNames
        wave sc_CalcRecord, sc_CalcWaveNames
        if (raw == 1)
            // wave recordWave = sc_RawRecord
            // wave waveNameWave = sc_RawWaveNames
            duplicate/free/o sc_RawRecord, recordWave
            duplicate/free/o/t sc_RawWaveNames, waveNameWave
        else
            // wave recordWave = sc_CalcRecord
            // wave waveNameWave = sc_CalcWaveNames
            duplicate/free/o sc_CalcRecord, recordWave
            duplicate/free/o/t sc_CalcWaveNames, waveNameWave
        endif
        for (i = 0; i<numpnts(waveNameWave); i++)     
            if (recordWave[i])
                wavenames = addlistItem(waveNameWave[i], wavenames)
            endif
        endfor
    endif
    return wavenames
end

function/t get2DWaveNames(raw, fastdac)
    // Return a comma separated list of Raw or Calc wavenames (without any checks)
    variable raw, fastdac  // 1 for True, 0 for False
    string waveNames1D = get1DWaveNames(raw, fastdac)
    string waveNames2D
    variable i
    for (i = 0; i<ItemsInList(waveNames1D); i++)
        waveNames2D = addlistItem(StringFromList(i, waveNames1D)+"_2d", waveNames2D)
    endfor
    return waveNames2D
end

function sanityCheckWavenames(wavenames)
    // Take comma separated list of wavenames, and check they all make sense
    string wavenames
    string s
    variable i
    for (i = 0; i<itemsinlist(wavenames); i++)
        s = stringFromList(i, wavenames)
        if (cmpstr(s, "") == 0)
            print "No wavename entered for one of the recorded waves"
            abort
        endif
        if (!((char2num(s[0]) >= 97 && char2num(s[0]) <= 122) || (char2num(s[0]) >= 65 && char2num(s[0]) <= 90)))
            print "The first character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
            abort
        endif
        if (!((char2num(s[strlen(s)-1]) >= 97 && char2num(s[strlen(s)-1]) <= 122) || (char2num(s[strlen(s)-1]) >= 65 && char2num(s[strlen(s)-1]) <= 90)))
            print "The last character of a wave name should be an alphabet a-z A-Z. The problematic wave name is " + s;
            abort
        endif
    endfor
end

function/t initializeGraphs(S)
    // Initialize graphs that are going to be recorded
    struct ScanVars &S
    string graphNames = getOpenGraphNames()
    string graphTitles = getOpenGraphTitles()    
    string graphNums = getOpenGraphNums()

    variable i, j, k
    string graphName
    for (i = 0; i<ItemsInList(graphNames); i++)
        graphName = stringFromList(i, graphNames)
        // TODO: Why do this?
		setaxis/w=$graphname /a
    endfor

    string waveNames, wn, title
    string openGraphName
    for (i = 0; i<2; i++)  // Raw = 0, Raw = 1
        waveNames = get1DWaveNames(i, S.using_fastdac)
        for (j = 0; j<ItemsInList(waveNames); j++)  // Look through wavenames that are being recorded
            wn = StringFromList(j, waveNames)
            openGraphName = graphExistsForWavename(wn)
            if (cmpstr(openGraphName, "")) // Graph is already open (str != "")
                setUpGraph1D(openGraphName, S.x_label)  // TODO: Add S.y_label if it is not null or empty
            else 
                open1Dgraph(wn, S.x_label)
                graphNames = addlistItem(winname(0,1), graphNames)
            endif
            if (S.is2d)
                wn = wn+"_2d"
                openGraphName = graphExistsForWavename(wn)
                if (cmpstr(openGraphName, "")) // Graph is already open (str != "")
                    setUpGraph2D(openGraphName, S.x_label, S.y_label)
                else 
                    open2Dgraph(wn, S.x_label, S.y_label)
                    graphNames = addlistItem(winname(0,1), graphNames)
                endif
            endif
        endfor
    endfor
    return graphNames
end

function arrangeWindows(winNames)
    // Tile Graphs and/or windows etc
    string winNames
    string cmd, windowName
    cmd = "TileWindows/O=1/A=(3,4) "  
    variable i
    for (i = 0; i<itemsInList(winNames); i++)
        windowName = StringFromList(i, winNames)
        cmd += windowName+", "
        doWindow/F windowName // Bring window to front 
    endfor
    execute(cmd)
    doupdate
end


function/t graphExistsForWavename(wn)
    // Checks if a graph is open containing wn, if so returns the graphTitle otherwise returns ""
    string wn
    string graphTitles = getOpenGraphTitles()
    string title
    variable k
    for (k = 0; k < ItemsInList(graphTitles); k++)  
        title = StringFromList(k, graphTitles)
        if (stringMatch(wn, title))
            return title  // TODO: Maybe this should return graphNum instead? 
        endif
    endfor
    return ""
end

function open1Dgraph(wn, x_label)
    // Opens 1D graph for wn
    string wn, x_label
    display $wn
    setWindow kwTopWin, graphicsTech=0
    
    setUpGraph1D(WinName(0,1), x_label)
end

function open2Dgraph(wn, x_label, y_label)
    // Opens 2D graph for wn (where wn is just the 1D name)
    string wn, x_label, y_label
    string wn2d = wn+"_2d"
    display
    setwindow kwTopWin, graphicsTech=0
    appendimage $wn2d
    setUpGraph2D(WinName(0,1), x_label, y_label)
end

function setUpGraph1D(graphNumStr, x_label, [y_label])
    string graphNumStr, x_label, y_label
    // Sets axis labels, datnum etc
    Label /W=$graphNumStr bottom, x_label
    if (!paramisDefault(y_label))
        Label /W=$graphNumStr left, y_label
    endif

    nvar filenum
    TextBox /W=$graphNumStr/C/N=datnum/A=LT/X=1.0/Y=1.0/E=2 "Dat"+num2str(filenum)
end

function setUpGraph2D(graphNumStr, x_label, y_label)
    string graphNumStr, x_label, y_label
    svar sc_ColorMap
    // Sets axis labels, datnum etc
    Label /W=$graphNumStr bottom, x_label
    Label /W=$graphNumStr left, y_label

    modifyimage $graphNumStr ctab={*, *, $sc_ColorMap, 0}
    colorscale /c/n=$sc_ColorMap /e/a=rc image=$graphNumStr

    nvar filenum
    TextBox /W=$graphNumStr/C/N=datnum/A=LT/X=1.0/Y=1.0/E=2 "Dat"+num2str(filenum)
end

function/t getOpenGraphNames()
	string graphlist = winlist("*",";","WIN:1")
    string graphNames, graphName
	variable i, j=0, index=0
	for (i=0;i<itemsinlist(graphlist);i=i+1)
		index = strsearch(graphlist,";",j)
		graphname = graphlist[j,index-1]
        graphnames += graphname+";"
		j=index+1
	endfor
    return graphNames
end

function/t getOpenGraphTitles()
	string graphlist = winlist("*",";","WIN:1")
    string graphTitles, graphName, plottitle
	variable i, j=0, index=0
	for (i=0;i<itemsinlist(graphlist);i=i+1)
		index = strsearch(graphlist,";",j)
		graphname = graphlist[j,index-1]
		getwindow $graphname wtitle
		splitstring /e="(.*):(.*)" s_value, graphnum, plottitle
		graphtitles+= plottitle+";"
		j=index+1
	endfor
    return graphTitles
end

function/t getOpenGraphNums()
	string graphlist = winlist("*",";","WIN:1")
    string graphNums, graphName, graphNum
    string wtitle
	variable i, j=0, index=0
	for (i=0;i<itemsinlist(graphlist);i=i+1)
		index = strsearch(graphlist,";",j)
		graphname = graphlist[j,index-1]
		getwindow $graphname wtitle
		splitstring /e="(.*):(.*)" s_value, graphnum, plottitle
		graphNums+= graphnum+";"
		j=index+1
	endfor
    return graphNums
end

function openAbortWindow()
    doWindow/k/z SweepControl  // Attempt to close previously open window just in case
    doWindow SweepControl   // Open window
end