#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#include <Waves Average>
#include <FilterDialog> menus=0
#include <Split Axis>
#include <WMBatchCurveFitIM>
#include <Decimation>
#include <Wave Arithmetic Panel>



function lock_in_test(data)
	wave data
	int  xmin, xmax
	int data_length, i
	variable step_value, avg, res, voltage, period
//	struct AWGVars AWG
	variable batches
	batches=25;
	variable nofcycles
	nofcycles=10//***AWG.numCycles;
	period=10//***AWG.waveLen/2;
	
	voltage=1E-3
	data_length=numpnts(data)
	step_value=0
	print(data_length)
	wave resistance
	make/O/N=(data_length/(nofcycles*period)) resistance
	xmin=-1500
	xmax=1500
	for(i=0; i<data_length; i+=1)
		if (i/(nofcycles*period)==trunc(i/(nofcycles*period)))
			step_value+=data[i]*sin(2*pi*i/period)
			avg=step_value/(nofcycles*period)
			res=voltage/(pi*avg*1E-9)
			resistance[i/(nofcycles*period)]=1/(res/25813) 
			step_value=0
		else
			step_value+=data[i]*sin(2*pi*i/period)
		endif
	endfor
		
	display resistance
	Label left "Inverse Resistance"
	ModifyGraph lblLineSpacing(left)=1
	ModifyGraph lblLineSpacing=0
	ModifyGraph lblMargin(left)=10,notation(left)=1;DelayUpdate
	setScale/I x, xmin, xmax, resistance
	
	
end



function demodulate(datnum, harmonic, wave_kenner, [append2hdf, demod_wavename])
	///// if demod_wavename is use this name for demod wave. Otherwise default is "demod"
	variable datnum, harmonic
	string wave_kenner
	variable append2hdf
	string demod_wavename
	demod_wavename = selectString(paramisdefault(demod_wavename), demod_wavename, "demod")
	variable nofcycles, period, cols, rows
	string wn="dat" + num2str(datnum) + wave_kenner;
	wave wav=$wn
//	struct AWGVars AWGLI
//	fd_getoldAWG(AWGLI, datnum) //***

//	print AWGLI

	cols=dimsize(wav,0); print cols
	rows=dimsize(wav,1); print rows
	nofcycles=10//***AWGLI.numCycles;
	period=10//**AWGLI.waveLen;
	print "AWG num cycles  = " + num2str(nofcycles)
	print "AWG wave len = " + num2str(period)
	
//	//Original Measurement Wave
	make /o/n=(cols) sine1d
	sine1d=sin(2*pi*(harmonic*p/period)) // create 1d sine wave with same frequency as AWG wave and specified harmonic

	matrixop /o sinewave=colrepeat(sine1d, rows)
	matrixop /o temp=wav * sinewave
	copyscales wav, temp
	temp=temp*pi/2;
	
	
	
	///// display steps of demod /////
//	display
//	appendimage temp
//
//	display
//	appendimage sinewave
//
	Duplicate /o sine1d, wave0x
	wave0x = x

//	display wav vs wave0x
//	appendtoGraph sine1d
	
	print "cols = " + num2str(cols)
	print "rows = " + num2str(rows)
	print "(cols/period/nofcycles) = " + num2str(cols/period/nofcycles)
	ReduceMatrixSize(temp, 0, -1, (cols/period/nofcycles), 0,-1, rows, 1, demod_wavename)
	
	KillWindow /Z demod_window
	Display
	DoWindow/C demod_window
	Appendimage /W=demod_window $demod_wavename
	ModifyImage /W=demod_window $demod_wavename ctab = {*, *, RedWhiteGreen, 0}
	

end



function zap_NaNs(wave_1d, [overwrite])
	// removes any datapoints with NaNs :: only removes NaNs from the end of the wave. Assumes NaNs are only at start and end and not within wave
	// wave_1d: 2d wave to remove rows from
	// overwrite: Default is overwrite = 1. overwrite = 0 will create new wave with "_zap" appended to the end
	// percentage_cutoff_inf: Default is percentage_cutoff_inf = 0.15 :: 15%
	wave wave_1d
	int overwrite
	
	overwrite = paramisdefault(overwrite) ? 1 : overwrite
	
	// Duplicating 1d wave
	if (overwrite == 0)
		string wave_1d_name = nameofwave(wave_1d)
		string wave_1d_name_new = wave_1d_name + "_zap"
		duplicate /o wave_1d $wave_1d_name_new
		wave wave_1d_new = $wave_1d_name_new 
	endif
	
	
	create_x_wave(wave_1d)
	wave x_wave
	
	
	variable num_rows = dimsize(wave_1d, 0)
	int first_num_from_left = 0
	int first_num_from_right = num_rows
		
		
	///// find first number index on the left /////
	int i 
	for (i = 0; i < num_rows; i++)
	
		if (numtype(wave_1d[i]) == 0)
			first_num_from_left = i
			break
		endif
		
	endfor
	
	
	///// find first number index on the right /////
	for (i = num_rows - 1; i >= 0; i--)
	
		if (numtype(wave_1d[i]) == 0)
			first_num_from_right = i
			break
		endif
		
	endfor
	
	
	variable start_point = pnt2x(wave_1d, first_num_from_left) // point of first non-NaN
	variable end_point = pnt2x(wave_1d, first_num_from_right) // point of first non-NaN
	
	// delete NaNs from the left
	if (overwrite == 1)
		deletePoints /M=0 0, first_num_from_left, wave_1d
	else 
		deletePoints /M=0 0, first_num_from_left, wave_1d_new
	endif

	
	// delete NaNs from the right
	if (overwrite == 1)
		deletePoints /M=0 first_num_from_right-first_num_from_left+1, num_rows-first_num_from_right-1, wave_1d
	else
		deletePoints /M=0 first_num_from_right-first_num_from_left+1, num_rows-first_num_from_right-1, wave_1d_new
	endif

	
	// set correct scaling using start and end point
	if (overwrite == 1)
		setscale /I x, start_point, end_point, wave_1d
	else
		setscale /I x, start_point, end_point, wave_1d_new
	endif
end


function replace_nans_with_avg(wave_2d, [overwrite])
	// Replaces NaN values in a 2D wave with the average of the non-NaN values in each column
    // wave_2d: The input 2D wave
    // overwrite: Set to 1 to overwrite the input wave (Default is to create new wave with "_new" added)
	wave wave_2d
	int overwrite
	
	string wave_name = nameofwave(wave_2d)
	
	// Getting x-values from wave
	string wave_name_x = wave_name + "_x"
	duplicate /o /R=[][0] wave_2d $wave_name_x
	wave wave_2d_x = $wave_name_x
	wave_2d_x = x
	
	// Duplicating 2d wave
	string wave_name_new = wave_name + "_new"
	duplicate /o wave_2d $wave_name_new
	wave wave_new = $wave_name_new 
	
	variable num_rows = dimsize(wave_2d, 1) // IGOR column
	variable num_bad_rows = 0
	variable i
	for (i = 0; i < num_rows; i++)
		duplicate /R=[][i] /o /free wave_2d wave_slice
		wavestats /Q wave_slice
		if (V_numNans/V_npnts > 0.33) // If 25% or more of data poitns are NaNs
			DeletePoints/M=1 (i - num_bad_rows), 1, wave_new // delete row 
			num_bad_rows += 1
		else
			Interpolate2 /T=1 /I=0 /Y=wave_slice wave_2d_x,  wave_slice // linear interpolation
			wave_new[][i - num_bad_rows] = wave_slice[p]
		endif
	endfor
	
	
	killwaves wave_2d_x
	
	
	if (overwrite == 1)
		duplicate /o wave_new $wave_name
		killwaves wave_new
	endif
end




function resampleWave(wav, targetFreq, [measureFreq])
	// finds measure freq from scan vars and calls scfd_resampleWaves
	wave wav 
	variable targetFreq 
	variable measureFreq
	
	measureFreq = paramisdefault(measureFreq) ? 0 : measureFreq // default is to find measure freq from scanvars unless specified
	
	string wn = nameOfWave(wav)
	int wavenum = getfirstnum(wn)
	
	///** todo
//	if (measureFreq == 0)
//		struct AWGVars S
//		fd_getoldAWG(S, wavenum)
//		measureFreq = S.measureFreq
//	endif
	
	scfd_resampleWaves(wav, measureFreq, targetFreq)
	
end




function notch_filters(wave wav, [string Hzs, string Qs, string notch_name])
	// wav is the wave to be filtered.  notch_name, if specified, is the name of the wave after notch filtering.
	// If not specified the filtered wave will have the original name plus '_nf' 
	// This function is used Hzto apply the notch filter for a choice of frequencies and Q factors
	// if the length of Hzs and Qs do not match then Q is chosen as the first Q is the list
	// It is expected that wav will have an associated JSON file to convert measurement times to points, via fd_getmeasfreq below
	// EXAMPLE usage: notch_filters(dat6430cscurrent_2d, Hzs="60;180;300", Qs="50;150;250")
	
	Hzs = selectString(paramisdefault(Hzs), Hzs, "60")
	Qs = selectString(paramisdefault(Qs), Qs, "50")
	variable num_Hz = ItemsInList(Hzs, ";")
	variable num_Q = ItemsInList(Qs, ";")
	
	// Get new filtered name and make a copy of wave
	String wav_name = nameOfWave(wav)
	notch_name = selectString(paramisdefault(notch_name), notch_name, wav_name + "_nf")
	if ((cmpstr(wav_name,notch_name)))
		duplicate/o wav $notch_name
	else
		print notch_name
		abort "I was going to overwrite your wave"
	endif
	wave notch_wave = $notch_name
		
	// Creating wave variables
	variable num_rows = dimsize(wav, 0)
	variable padnum = 2^ceil(log(num_rows) / log(2)); 
	duplicate /o wav tempwav // tempwav is the one we will operate on during the FFT
	variable offset = mean(wav)
	tempwav -= offset // make tempwav have zero average to reduce end effects associated with padding
	
	//Transform
	FFT/pad=(padnum)/OUT=1/DEST=temp_fft tempwav

	wave /c temp_fft
	duplicate/c/o temp_fft fftfactor // fftfactor is the wave to multiple temp_fft by to zero our certain frequencies
//	fftfactor = 1 - exp(-(x - freq)^2 / (freq / Q)^2)
	
	// Accessing freq conversion for wav
	int wavenum = getfirstnum(wav_name)
//	variable freqfactor = 1/(fd_getmeasfreq(wavenum) * dimdelta(wav, 0)) //***// freq in wav = Hz in real seconds * freqfactor
	variable freqfactor = 1

	fftfactor=1
	variable freq, Q, i
	for (i=0;i<num_Hz;i+=1)
		freq = freqfactor * str2num(stringfromlist(i, Hzs))
		Q = ((num_Hz==num_Q) ? str2num(stringfromlist(i, Qs)): str2num(stringfromlist(0, Qs))) // this sets Q to be the ith item on the list if num_Q==num_Hz, otherwise it sets it to be the first value
		fftfactor -= exp(-(x - freq)^2 / (freq / Q)^2)
	endfor
	temp_fft *= fftfactor

	//Inverse transform
	IFFT/DEST=temp_ifft  temp_fft
	wave temp_ifft
	
	temp_ifft += offset

	redimension/N=(num_rows, -1) temp_ifft
	copyscales wav, temp_ifft
	duplicate /o temp_ifft $notch_name

	
end



function spectrum_analyzer(wave data, variable samp_freq)
	// Built in powerspectrum function
	duplicate/o data spectrum
	SetScale/P x 0,1/samp_freq,"", spectrum
	variable numptsx = dimsize(spectrum,0);  // number of points in x-direction
	variable new_numptsx = 2^(floor(log(numptsx)/log(2))); // max factor of 2 less than total num points
	wave slice;
	wave w_Periodogram

	variable i=0
	rowslice(spectrum,i)
	DSPPeriodogram/R=[1,(new_numptsx)] /PARS/NODC=2/DEST=W_Periodogram slice
	duplicate/o w_Periodogram, powerspec
	i=1
	do
		rowslice(spectrum,i)
		DSPPeriodogram/R=[1,(new_numptsx)]/PARS/NODC=2/DEST=W_Periodogram slice
		powerspec=powerspec+W_periodogram
		i=i+1
	while(i<dimsize(spectrum,1))
	
//	powerspec[0]=nan
	powerspec[0, x2pnt(powerspec, 10)] = 0

	duplicate /o powerspec powerspec_int
	wave powerspec_int
	integrate powerspec_int
	
	display powerspec; // SetAxis bottom 0,500
	appendtoGraph /r=l2 powerspec_int
	ModifyGraph freePos(l2)={inf,bottom}
	ModifyGraph rgb(powerspec_int)=(0,0,0)
	ModifyGraph log(left)=1
	
	Label left "nA^2/Hz"
	Label l2 "integrated nA^2/Hz"
	

end




function /s avg_wav(wave wav) // /WAVE lets your return a wave
	// averaging any wave over columns (in y direction)
	// wave returned is avg_name
	string wn = nameofwave(wav)
	string avg_name = wn + "_avg";
	int nc
	int nr

	nr = dimsize($wn, 0) //number of rows (sweep length)
	nc = dimsize($wn, 1) //number of columns (repeats)
	
	ReduceMatrixSize(wav, 0, -1, nr, 0, -1, 1, 1, avg_name)
	
	redimension/n = -1 $avg_name
	
	return avg_name
end




function average_every_n_rows(wav, n, [overwrite])
	// takes a 2d wave and averages every n rows (IGOR columns)
	// creates a wave with _avg appended to the end
	// assumes the wav has a multiple of n points
	wave wav 
	int n, overwrite
	
	overwrite = paramisdefault(overwrite) ? 0 : overwrite // default not resample the data

	
	string wave_name = nameOfWave(wav)
	string wave_name_averaged = wave_name + "_avg"

	
	variable num_rows = dimsize(wav, 1) // (repeats)
	variable num_columns = dimsize(wav, 0) // (sweep length)
	
	int num_rows_post_average = round(num_rows/n)
	
	ReduceMatrixSize(wav, 0, -1, num_columns, 0,-1, num_rows_post_average, 1, wave_name_averaged)

	if (overwrite == 1)
		duplicate /o $wave_name_averaged $wave_name
	endif
end




function crop_wave(wave wav, variable x_mid, variable y_mid, variable x_width, variable y_width)
	// takes a 2d wave and creates a new cropped wave with name "_crop" appended
	// cropped mask is determined by the centre and lengths (in gate dimensions) of the x and y
	
	string wave_name = nameOfWave(wav)
	string wave_name_averaged = wave_name + "_crop"
	
	variable num_columns = dimsize(wav, 0) // (sweep length)
	variable num_rows = dimsize(wav, 1) // (repeats)
	
	int x_coord_start, x_coord_end, y_coord_start, y_coord_end
	
	// setting x coordinates (with checks for bounds)
	if (x_width == INF)
		x_coord_start = 0
		x_coord_end = num_columns - 1
	else
		x_coord_start = scaletoindex(wav, x_mid - x_width, 0)
		x_coord_end = scaletoindex(wav, x_mid + x_width, 0)
	endif

	if (x_coord_start < 0)
		x_coord_start = 0
	endif	
	if (x_coord_end > num_columns - 1)
		x_coord_end = num_columns - 1
	endif
	
	// setting y coordinates (with checks for bounds)
	if (y_width == INF)
		y_coord_start = 0
		y_coord_end = num_rows - 1
	else
		y_coord_start = scaletoindex(wav, y_mid - y_width, 1)
		y_coord_end = scaletoindex(wav, y_mid + y_width, 1)
	endif
	
	if (y_coord_start < 0)
		y_coord_start = 0
	endif
	if (y_coord_end > num_rows - 1)
		y_coord_end = num_rows - 1
	endif
	
	int num_crop_columns = (x_coord_end - x_coord_start) + 1
	int num_crop_rows = (y_coord_end - y_coord_start) + 1
	
	ReduceMatrixSize(wav, x_coord_start, x_coord_end, num_crop_columns, y_coord_start, y_coord_end, num_crop_rows, 1, wave_name_averaged)
end



	
	
function udh5([dat_num, dat_list, dat_min_max])
	// Loads HDF files back into Igor, if no optional paramters specified loads all dat in file path into IGOR
	// NOTE: Assumes 'data' has been specified
	string dat_num,dat_list, dat_min_max
	dat_num = selectString(paramisdefault(dat_num), dat_num, "") // e.g. "302"
	dat_list = selectString(paramisdefault(dat_list), dat_list, "") // e.g. "302,303,304,305,401"
	dat_min_max = selectString(paramisdefault(dat_min_max), dat_min_max, "") // e.g. "302,310"
	
	string infile = wavelist("*",";","") // get wave list
	string hdflist = indexedfile(data,-1,".h5") // get list of .h5 files
	string currentHDF="", currentWav="", datasets="", currentDS
	
	
	////////////////////////////////////////////////////
	///// Overwriting hdflist if dat_num specified /////
	////////////////////////////////////////////////////
	if (!stringmatch(dat_num, ""))
		hdflist = "dat" + dat_num + ".h5"
	endif
	
	/////////////////////////////////////////////////////
	///// Overwriting hdflist if dat_list specified /////
	/////////////////////////////////////////////////////
	variable i
	if (!stringmatch(dat_list, ""))
		hdflist = ""
		for(i=0; i<ItemsInList(dat_list, ","); i+=1)
			hdflist = hdflist + "dat" + StringFromList(i, dat_list, ",") + ".h5;"
		endfor
	endif
	
	////////////////////////////////////////////////////////
	///// Overwriting hdflist if dat_min_max specified /////
	////////////////////////////////////////////////////////
	variable dat_start = str2num(StringFromList(0, dat_min_max, ","))
	variable dat_end = str2num(StringFromList(1, dat_min_max, ","))
	
	if (!stringmatch(dat_min_max, ""))
		hdflist = ""
		for(i=dat_start; i<dat_end+1; i+=1)
			hdflist = hdflist + "dat" + num2str(i) + ".h5;"
		endfor
	endif
	
	print(hdflist)
	
	variable numHDF = itemsinlist(hdflist, ";"), fileid = 0, numWN = 0, wnExists = 0
	variable j = 0, numloaded = 0


	for(i = 0; i < numHDF; i += 1) // loop over h5 filelist

		currentHDF = StringFromList(i, hdflist, ";")

		HDF5OpenFile/P=data /R fileID as currentHDF
		HDF5ListGroup /TYPE=2 /R=1 fileID, "/" // list datasets in root group
		datasets = S_HDF5ListGroup
		numWN = itemsinlist(datasets)  // number of waves in .h5
		currentHDF = currentHDF[0, (strlen(currentHDF) - 4)]
		for(j = 0; j < numWN; j += 1) // loop over datasets within h5 file
	    	currentDS = StringFromList(j, datasets)
			currentWav = currentHDF + currentDS
		    wnExists = FindListItem(currentWav, infile,  ";")
		    if (wnExists == -1)
		   		// load wave from hdf
		   		HDF5LoadData /Q /IGOR=-1 /N=$currentWav/TRAN=1 fileID, currentDS
		   		numloaded+=1
		    endif
		endfor
		HDF5CloseFile fileID
	endfor
	print numloaded, "waves uploaded"
end




function ud()
	string infile = wavelist("*",";",""); print infile
	string infolder =  indexedfile(data,-1,".ibw")
	string current, current1
	variable numstrings = itemsinlist(infolder), i, curplace, numloaded=0
	
	for(i=0; i<numstrings; i+=1)
		current1 = StringFromList(i,infolder)
		current = current1[0,(strlen(current1)-5)]
		curplace = FindListItem(current, infile,  ";")
		if (curplace==-1)
			LoadWave/Q/H/P=data current
			numloaded+=1
		endif
	endfor
	print numloaded, "waves uploaded"
end




Function Setmaxi(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	nvar maxi, mini

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
		
			 maxi = sva.dval
			String sval = sva.sval
	ModifyImage ''#0 ctab= {mini,maxi,VioletOrangeYellow,0}
break
		case -1: // control being killed
			break
	endswitch

	return maxi
End


Function Setmini(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	nvar maxi, mini

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
		
			 mini = sva.dval
			String sval = sva.sval
	ModifyImage ''#0 ctab= {mini,maxi,VioletOrangeYellow,0}

break
		case -1: // control being killed
			break
	endswitch

	return mini
End





Function renamewave(oldprefix, newprefix)
   string oldprefix, newprefix
 
   string theList, theOne, theName
   variable ic, nt
 
   theList = WaveList("*",";","")
   nt = ItemsInList(theList)
   for (ic=0;ic<nt;ic+=1)
     theOne = StringFromList(ic,theList)
     theName = ReplaceString(oldprefix,theOne,newprefix)
     rename $theOne $theName
   endfor
   return 0
end



function/wave Linspace(start, fin, num, [make_global])
	// An Igor substitute for np.linspace() (obviously with many caveats and drawbacks since it is in Igor...)
	//
	// To use this in command line:
	//		make/o/n=num tempwave
	// 		tempwave = linspace(start, fin, num)[p]
	//
	// To use in a function:
	//		wave tempwave = linspace(start, fin, num)  //Can be done ONCE (each linspace overwrites itself!)
	//	or
	//		make/n=num tempwave = linspace(start, fin, num)[p]  //Can be done MANY times
	//
	// To combine linspaces:
	//		make/free/o/n=num1 w1 = linspace(start1, fin1, num1)[p]
	//		make/free/o/n=num2 w2 = linspace(start2, fin2, num2)[p]
	//		concatenate/np/o {w1, w2}, tempwave
	//
	variable start, fin, num
	int make_global
	make_global = paramisdefault(make_global) ? 0 : make_global  // default to not make global wave
	
	if (num == 1)
		if (make_global == 1)
			Make/N=1/O linspaced = {start}
		else
			Make/N=1/O/Free linspaced = {start}
		endif
	else
		if (make_global == 1)
			Make/N=2/O linspace_start_end = {start, fin}
		else
			Make/N=2/O/Free linspace_start_end = {start, fin}
		endif
		Interpolate2/T=1/N=(num)/Y=linspaced linspace_start_end
	endif
	return linspaced
end



//from:
// https://www.wavemetrics.com/code-snippet/stacked-plots-multiple-plots-layout

function MultiGraphLayout(GraphList, nCols, spacing, layoutName)
	string GraphList        // semicolon separated list of graphs to be appended to layout
	variable nCols      // number of graph columns
	string layoutName   // name of the layout
	variable spacing        // spacing between graphs in points!

	// how many graphs are there and how many rows are required
	variable nGraphs = ItemsInList(GraphList)
	variable nRows = ceil(nGraphs / nCols)
	variable LayoutWidth, LayoutHeight
	variable gWidth, gHeight
	variable maxWidth = 0, maxHeight = 0
	variable left, top
	variable i, j, n = 0

	string ThisGraph

	// detect total layout size from individual graph sizes; get maximum graph size as column/row size
	for(i=0; i<nGraphs; i+=1)

		ThisGraph = StringFromList(i, GraphList)
		GetWindow $ThisGraph gsize
		gWidth = (V_right - V_left)
		gHeight = (V_bottom - V_top)

		// update maximum
		maxWidth = gWidth > maxWidth ? gWidth : maxWidth
		maxHeight = gHeight > maxHeight ? gHeight : maxHeight
	endfor

	// calculate layout size
	LayoutWidth = maxWidth * nCols + ((nCols + 1) * spacing)
	LayoutHeight = maxHeight * nRows + ((nRows +1) * spacing)

	// make layout; kill if it exists
	DoWindow $layoutName
	if(V_flag)
		KillWindow $layoutName
	endif

	NewLayout/N=$layoutName/K=1/W=(517,55,1451,800)
	LayoutPageAction size=(LayoutWidth, LayoutHeight), margins=(0,0,0,0)
	ModifyLayout mag=0.75

	//append graphs
	top = spacing
	for(i=0; i<nRows; i+=1)

		// reset vertical position for each column
		left = spacing

		for (j=0; j<    nCols; j+=1)

			ThisGraph = StringFromList(n, GraphList)
			if(strlen(ThisGraph) == 0)
				return 0
			endif

			GetWindow $ThisGraph gsize
			gWidth = (V_right - V_left)
			gHeight = (V_bottom - V_top)

			AppendLayoutObject/F=0 /D=1 /R=(left, top, (left + gWidth), (top + gHeight)) graph $ThisGraph

			// shift next starting positions to the right
			left += maxWidth + spacing

			// increase plot counter
			n += 1
		endfor

		// shift next starting positions dwon
		top += maxHeight + spacing
	endfor

	return 1
end


function getfirstnum(numstr)
    string numstr
    
    string junk
    variable number
    sscanf numstr, "%[^0123456789]%d", junk, number
    return number
end


function /s getsuffix(numstr)
    string numstr
    
    string junk, suff
    variable number
    sscanf numstr, "%[^0123456789]%d%s", junk, number, suff
    return suff
end



function/wave rowslice(wave wav, int rownumb)
	duplicate /o/rmd=[][rownumb,rownumb] wav, slice
	redimension /n=(dimsize(slice, 0)) slice
	return slice
end



function centering(wave wave_not_centered, string centered_wave_name, wave mids)
	// shift the wave 'wave_not_centered' by the 'mids' wave
	// call the new wave 'centered_wave_name'
	duplicate/o wave_not_centered $centered_wave_name
	wave new2dwave=$centered_wave_name
	copyscales wave_not_centered new2dwave
	new2dwave=interp2d(wave_not_centered,(x+mids[q]),(y)) // mids is the shift in x
//	new2dwave = interp2d(waved, (x + mids[q] - V_avg), (y)) // mids is the shift in x
end



function create_y_wave(wave_2d)
	// create global "y_wave" given a 2d array
	wave wave_2d
	
	string wave_2d_name = nameofwave(wave_2d)
	
	duplicate /o /RMD=[0][] $wave_2d_name y_wave
	y_wave = y
	redimension /n=(dimsize(y_wave, 1)) y_wave
end


function create_x_wave(wave_2d)
	// create global "x_wave" given a 2d array
	wave wave_2d
	
	string wave_2d_name = nameofwave(wave_2d)
	
	duplicate /o /RMD=[][0] $wave_2d_name x_wave
	x_wave = x
end



Function GetFreeMemory()
    variable freeMem

#if defined(IGOR64)
    freeMem = NumberByKey("PHYSMEM", IgorInfo(0)) - NumberByKey("USEDPHYSMEM", IgorInfo(0))
#else
    freeMem = NumberByKey("FREEMEM", IgorInfo(0))
#endif

    return freeMem / 1024 / 1024 / 1024
End

