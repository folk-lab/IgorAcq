#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#include <Waves Average>
#include <FilterDialog> menus=0
#include <Split Axis>
#include <WMBatchCurveFitIM>
#include <Decimation>
#include <Wave Arithmetic Panel>
#include <Reduce Matrix Size>




function lock_in_test(data)
	wave data
	int  xmin, xmax
	int data_length, i
	variable step_value, avg, res, voltage, period
	struct AWGVars AWG
	variable batches
	batches=25;
	variable nofcycles
	nofcycles=AWG.numCycles;
	period=AWG.waveLen/2;
	
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


function demodulate(datnum, harmonic, wave_kenner, [append2hdf, dat_kenner])
	variable datnum, harmonic
	string wave_kenner
	variable append2hdf
	string dat_kenner
	dat_kenner = selectString(paramisdefault(dat_kenner), dat_kenner, "")
	variable nofcycles, period, cols, rows
	string wn="dat" + num2str(datnum) + wave_kenner;
	wave wav=$wn
	struct AWGVars AWGLI
	fd_getoldAWG(AWGLI, datnum)
	cols=dimsize(wav,0); //print cols
	rows=dimsize(wav,1); //print rows
	nofcycles=AWGLI.numCycles;
	period=AWGLI.waveLen;
	print "AWG num cycles  = " + num2str(nofcycles)
	print "AWG wave len = " + num2str(period)
	
//	//Original Measurement Wave
	make /o/n=(cols) sine1d
	sine1d=sin(2*pi*(harmonic*p/period)) // create 1d sine wave with same frequency as AWG wave and specified harmonic

	matrixop /o sinewave=colrepeat(sine1d, rows)
	matrixop /o temp=wav * sinewave
	copyscales wav, temp
	temp=temp*pi/2;
	
	

	
	print "cols = " + num2str(cols)
	print "rows = " + num2str(rows)
	print "(cols/period/nofcycles) = " + num2str(cols/period/nofcycles)
	ReduceMatrixSize(temp, 0, -1, (cols/period/nofcycles), 0,-1, rows, 1, "demod")
	


end

function center_dSdN(int wavenum, string kenner)
//wav is input wave, for example demod
//centered is output name
wave demod
string centered=kenner+num2str(wavenum)+"centered"
string centeravg=kenner+num2str(wavenum)+"centered_avg"
string cleaned=kenner+num2str(wavenum)+"cleaned"
string cleaned_avg=kenner+num2str(wavenum)+"cleaned_avg"


//duplicate/o demod centered
wave badthetasx

string condfit_prefix="cst"; //this can become an input if needed
string condfit_params_name=condfit_prefix+num2str(wavenum)+"fit_params"
wave condfit_params = $condfit_params_name

	duplicate/o/r=[][3] condfit_params mids

	centering(demod,centered,mids)
	wave temp=$centered

	duplicate/o temp $cleaned


	// removing lines with bad thetas;

	variable i, idx
	int nc
	int nr
	nr = dimsize(badthetasx,0) //number of rows
	i=0
	if (nr>0)
		do
			idx=badthetasx[i]-i //when deleting, I need the -i because if deleting in the loop the indeces of center change continously as points are deleted
			DeletePoints/M=1 idx,1, $cleaned
			i=i+1
		while (i<nr)
	endif
//		WaveTransform zapnans $cleaned_avg
//		WaveTransform zapnans $centeravg


	avg_wav($cleaned)
	avg_wav($centered)
	display $cleaned_avg, $centeravg
	makecolorful()
//	wave center=$centeravg
//	Extract/o/indx center,newx, (numtype(center[p])==0)
//	wavestats center
//	DeletePoints 0, 43, center 

	

	
	
end




function demodulate2(datnum,harmonic,kenner,[append2hdf, axis])
//if axis=0: demodulation in r
//if axis=1: demodulation in x
//if axis=2: demodulation in y
	variable datnum,harmonic
	string kenner
	variable append2hdf, axis
	axis = paramisdefault(axis) ? axis : 0
	variable nofcycles, period, cols, rows
	string wn="dat"+num2str(datnum)+kenner;
	string wn_x="temp_x"
	string wn_y="temp_y"
	wave wav=$wn
	wave wav_x=$wn_x
	wave wav_y=$wn_y
	struct AWGVars AWGLI
	fd_getoldAWG(AWGLI,datnum)
	make /o demod2
	
	
	print AWGLI
	
	//Demodulate in x?
	if ((axis==0)||(axis==1))
	duplicate /o wav, wav_xx
	cols=dimsize(wav,0); print cols
	rows=dimsize(wav,1); print rows
	nofcycles=AWGLI.numCycles;
	period=AWGLI.waveLen;
	//Original Measurement Wave
	make /o/n=(cols) sine1d
	sine1d=sin(2*pi*(harmonic*p/period))
	matrixop /o sinewave=colrepeat(sine1d,rows)
	matrixop /o temp=wav_xx*sinewave
	copyscales wav_xx, temp
	temp=temp*pi/2;
	ReduceMatrixSize(temp, 0, -1, (cols/period/nofcycles), 0,-1, rows, 1,"demod_x")
	wn_x="demod_x"
	wave wav_x=$wn_x
	endif
	
	//Demodulate in y?
	if ((axis==0)||(axis==2))
	duplicate /o wav, wav_yy
	cols=dimsize(wav,0); print cols
	rows=dimsize(wav,1); print rows
	nofcycles=AWGLI.numCycles;
	period=AWGLI.waveLen;
	//Original Measurement Wave
	make /o/n=(cols) sine1d
	sine1d=cos(2*pi*(harmonic*p/period))
	matrixop /o sinewave=colrepeat(sine1d,rows)
	matrixop /o temp=wav_yy*sinewave
	copyscales wav_yy, temp
	temp=temp*pi/2;
	ReduceMatrixSize(temp, 0, -1, (cols/period/nofcycles), 0,-1, rows, 1,"demod_y")
	wn_y="demod_y"
	wave wav_y=$wn_y
	endif
	
	//Given wav_x and wav_y now refer to their respective demodulations, 
	//associate the correct set with the output based on r/x/y 
	
	//wn="demod"
	
	if (axis==0)
	demod2 =( (wav_x)^2 + (wav_y)^2 ) ^ (0.5)  //problematic line - operating on null wave?
	endif
	
	if (axis==1)
	demod2 = wav_x
	endif
	
	if (axis==1)
	demod2 = wav_y
	endif
	
	//Store demodulated wave w.r.t. correct axis
	//if (append2hdf)
	//	variable fileid
	//	fileid=get_hdfid(datnum) //opens the file
	//	HDF5SaveData/o /IGOR=-1 /TRAN=1 /WRIT=1 /Z $wn, fileid
	//	HDF5CloseFile/a fileid
	//endif

end  

function rescalex(wave wav, variable factor)
variable low=indextoScale(wav,0,0)*factor;
variable high=indextoScale(wav,inf,0)*factor;
SetScale/I x low,high,"", wav
end

function rescaley(wave wav, variable factor)
variable low=indextoScale(wav,0,1)*factor;
variable high=indextoScale(wav,inf,1)*factor;
SetScale/I y low,high,"", wav
end



function/wave resampleWave(wave wav,variable targetFreq,variable measureFreq )
	// resamples wave w from measureFreq
	// to targetFreq (which should be lower than measureFreq)
	string wn=nameOfWave(wav)
	int wavenum=getfirstnum(wn)

//	variable measureFreq
//		struct ScanVars S
//		fd_getScanVars(S,wavenum)
//	struct AWGVars S
//	fd_getoldAWG(S,wavenum)

//	measureFreq=fd_getmeasfreq(wavenum); print measurefreq
	variable N=measureFreq/targetFreq
//	wave temp_wave
//	duplicate/o wav, temp_wave


	RatioFromNumber (targetFreq / measureFreq)
	if (V_numerator > V_denominator)
		string cmd
		printf cmd "WARNING[scfd_resampleWaves]: Resampling will increase number of datapoints, not decrease! (ratio = %d/%d)\r", V_numerator, V_denominator
	endif
	resample/UP=(V_numerator)/DOWN=(V_denominator)/N=201/E=3 wav


	// TODO: Need to test N more (simple testing suggests we may need >200 in some cases!)
	// TODO: Need to decide what to do with end effect. Possibly /E=2 (set edges to 0) and then turn those zeros to NaNs?
	// TODO: Or maybe /E=3 is safest (repeat edges). The default /E=0 (bounce) is awful.
end


function notch_filters(wave wav, [string Hzs, string Qs, string notch_name])
	// wav is the wave to be filtered.  notch_name, if specified, is the name of the wave after notch filtering.
	// If not specified the filtered wave will have the original name plus _nf
	// This function is used to apply the notch filter for a choice of frequencies and Q factors
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
	int wavenum = getfirstnum(wav_name); print wavenum
	variable freqfactor = 1/(fd_getmeasfreq(wavenum) * dimdelta(wav, 0)) // freq in wav = Hz in real seconds * freqfactor
//	variable freq = 1 / (fd_getmeasfreq(wavenum) * dimdelta(wav, 0) / Hz)

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
Redimension/N=(num_rows,-1) temp_ifft
	copyscales wav, temp_ifft
	
	duplicate /o temp_ifft $notch_name

	
end




//<<<<<<< Updated upstream
//=======
//	variable i=0
//	rowslice(spectrum,i)
//	DSPPeriodogram/R=[1,(new_numptsx)] /PARS/NODC=2/DEST=W_Periodogram slice
//	duplicate/o w_Periodogram, powerspec
//	i=1
//	do
//		rowslice(spectrum,i)
//		DSPPeriodogram/R=[1,(new_numptsx)]/PARS/NODC=2/DEST=W_Periodogram slice
//		powerspec=powerspec+W_periodogram
//		i=i+1
//	while(i<dimsize(spectrum,1))
//	
////	powerspec[0]=nan
//	powerspec[0, x2pnt(powerspec, 10)] = 0
//>>>>>>> Stashed changes





function notch_filter(wave wav, variable Hz, [variable Q, string notch_name, variable overwrite_wave])
	// wav is the wave to be notch filtered, which must have the accompanying json specifying measurement frequency
	// Hz ithe frequency to notch filter, with quality factor Q
	// notch_name is the name of the wave to be after notch filtering.  If not specified the new wave will be the name of wav plus _nf
	// if notch_name already exists it will be overwritten
	// overwrite_wave is a flag that can be set to 1 to tell the function to overwrite wav, that is, to make notch_name the same as
	// the original wave.  If notch_name is specified AND overwrite_wave is set to 1, it defaults to making the output wave notch_wave

	Q = paramisdefault(Q) ? 50 : Q // set Q factor to 50 if not specified
	overwrite_wave = paramisdefault(overwrite_wave) ? 0 : overwrite_wave	
	String wav_name = nameOfWave(wav)
	
	if (paramisdefault(notch_name))
		if (overwrite_wave==1)
			notch_name=wav_name
		else
			notch_name=wav_name+"_nf"
//			duplicate/o wav $notch_name
		endif
	endif
		

	
	
	//Creating main wave copy and wave to display transform
	int wavenum = getfirstnum(wav_name)
	variable freq = 1 / (fd_getmeasfreq(wavenum) * dimdelta(wav, 0) / Hz)
	print fd_getmeasfreq(wavenum)


	// Creating wave variables
	variable num_rows = dimsize(wav, 0)
	variable padnum = 2^ceil(log(num_rows) / log(2)); 
	duplicate /o wav tempwav
	variable avg = mean(wav)
	tempwav -= avg
	
	//Transform
	FFT/pad=(padnum)/OUT=1/DEST=temp_fft tempwav
//	FFT/OUT=1/DEST=temp_fft tempwav

	wave /c temp_fft
	
	//Create gaussian, multiply it
	duplicate/c/o temp_fft fftfactor
	fftfactor = 1 - exp(-(x - freq)^2 / (freq / Q)^2)
	temp_fft *= fftfactor

	//Inverse transform
	IFFT/DEST=temp_ifft  temp_fft;DelayUpdate
	wave temp_ifft
	
	temp_ifft += avg
Redimension/N=(num_rows,-1) temp_ifft
	copyscales wav, temp_ifft
	
	duplicate /o temp_ifft $notch_name
	
//	if (overwrite_wave == 1)
//		duplicate/o wave_copy, wav
//	endif
end


function /s avg_wav(wave wav) // /WAVE lets your return a wave

	//  averaging any wave over columns (in y direction)
	// wave returned is avg_name
	string wn=nameofwave(wav)
	string avg_name=wn+"_avg";
	int nc
	int nr
	nr = dimsize($wn,0) //number of rows (sweep length)
	nc = dimsize($wn,1) //number of columns (repeats)

	ReduceMatrixSize(wav, 0, -1, nr, 0,-1, 1,1, avg_name)
	redimension/n=-1 $avg_name
	variable new_nr = dimsize($avg_name,0) //number of rows (sweep length)
	variable s=round((nr-new_nr)/2)
	wavetransform/o/p={s,nan} shift $avg_name

	return avg_name
end

function /s avg_wav_N(wave wav, int N) // /WAVE lets your return a wave

	//  averaging any wave over columns (in y direction)
	// wave returned is avg_name
	string wn=nameofwave(wav)
	string avg_name=wn+"_avg";
	int nc
	int nr

//	wn="dat"+num2str(wavenum)+dataset //current 2d array

	nr = dimsize($wn,0) //number of rows (sweep length)
	nc = dimsize($wn,1) //number of columns (repeats)

	ReduceMatrixSize(wav, 0, -1, N, 0,-1, 1,1, avg_name)
	redimension/n=-1 $avg_name
	variable new_nr = dimsize($avg_name,0) //number of rows (sweep length)
	variable s=round((nr-new_nr)/2)
	wavetransform/o/p={s,nan} shift $avg_name

	return avg_name
end





function stopalltimers()
variable i
i=0
do
print stopMSTimer(i)
i=i+1
while(i<9)
end

function dat2num(string datname)
	variable datnum
	
	sscanf datname,"dat%d", datnum
	return datnum
end

function udh5([file_name,range,noraw])
	// Loads HDF files back into Igor
	string file_name
	string range //Optional semicolon-separated list of start and end points. If range="startnum;endnum", only dat files between startnum and endnum inclusive will be loaded
	variable noraw //set noraw=1 if you don't want raw datasets to be loaded
	
	variable startnum, endnum, exclude
	if (!(paramisDefault(range)))
		startnum = str2num(stringfromlist(0,range))
		endnum = str2num(stringfromlist(1,range))
	endif
	if (paramisDefault(noraw))
		noraw=0
	endif


	
	file_name = selectString(paramisdefault(file_name), file_name, "")
	variable refnum=startmstimer

	string infile = wavelist("*",";","") // get wave list
	string hdflist = indexedfile(data,-1,".h5") // get list of .h5 files

	string currentHDF="", currentWav="", datasets="", currentDS
	if (!stringmatch(file_name, ""))
		hdflist = file_name + ".h5"
	endif
	
	variable numHDF = itemsinlist(hdflist), fileid=0, numWN = 0, wnExists=0
	variable i=0, j=0, numloaded=0


	for(i=0; i<numHDF; i+=1) // loop over h5 filelist

	   currentHDF = StringFromList(i,hdflist)
	   	//if (!stringmatch(currentHDF, "!*_RAW"))
	   	
	   	exclude = 0
	   	if (stringmatch(currentHDF, "*_RAW*") && noraw)
	   		exclude=1
	   	endif
	   	if (!(paramisDefault(range)))
	   		if ((dat2num(currenthdf)<startnum)||(dat2num(currenthdf)>endnum))
	   			exclude=1
	   		endif
	   	endif
	   	
	   	if (!(exclude))
		HDF5OpenFile/P=data /R fileID as currentHDF
		HDF5ListGroup /TYPE=2 /R=1 fileID, "/" // list datasets in root group
		datasets = S_HDF5ListGroup
		numWN = itemsinlist(datasets)
		currentHDF = currentHDF[0,(strlen(currentHDF)-4)]
		for(j=0; j<numWN; j+=1) // loop over datasets within h5 file
			currentDS = StringFromList(j,datasets)
			currentWav = currentHDF+currentDS
		   wnExists = FindListItem(currentWav, infile,  ";")
		   if (wnExists==-1)
		   	// load wave from hdf
		   	HDF5LoadData /Q /IGOR=-1 /N=$currentWav/TRAN=1 fileID, currentDS
		   	numloaded+=1
		   endif
		endfor
		HDF5CloseFile fileID
		endif
		//endif
	endfor
	

   print numloaded, "waves uploaded"
   
   	variable	ms=stopmstimer(refnum)
	print ms/1e6
end


function /s  loadh5(int filenum,int raw, [string kenner2])
	// Loads HDF files back into Igor
	
//	variable refnum=startmstimer

	string infile = wavelist("*",";","") // get wave list
	string kenner
	kenner = selectstring(raw,"","_RAW")
//	string hdflist = indexedfile(data,-1,".h5") // get list of .h5 files in data path
	
	string currentHDF="dat"+num2str(filenum)+kenner+".h5", currentWav="", datasets="", currentDS, loadedwaves=""
	
	variable fileid=0, numWN = 0, wnExists=0
	variable i=0, j=0, numloaded=0
	int loadthiswave

	HDF5OpenFile/P=data /R fileID as currentHDF
	HDF5ListGroup /TYPE=2 /R=1 fileID, "/" // list datasets in root group
	datasets = S_HDF5ListGroup
	numWN = itemsinlist(datasets)
	currentHDF = currentHDF[0,(strlen(currentHDF)-4)] // separate dat#### from .h5 
	for(j=0; j<numWN; j+=1) // loop over datasets within h5 file
			currentDS = StringFromList(j,datasets)
			currentWav = currentHDF+currentDS
		   wnExists = FindListItem(currentWav, infile,  ";")
		   loadthiswave = (wnExists==-1) && (paramisdefault(kenner2) || (stringmatch(currentDS,kenner2)))
		   // print currentDS,loadthiswave
		   if (loadthiswave)
		   	// load wave from hdf
		   	HDF5LoadData /Q /IGOR=-1 /N=$currentWav/TRAN=1 fileID, currentDS
		   	loadedwaves = addlistitem(currentwav,loadedwaves)
		   	numloaded+=1
		   endif
	endfor
	HDF5CloseFile fileID
	

//    variable	ms=stopmstimer(refnum)
//	print ms/1e6
	return loadedwaves
end


//function udh5([file_name])
//	// Loads HDF files back into Igor
//	string file_name
//	file_name = selectString(paramisdefault(file_name), file_name, "")
//		variable refnum=startmstimer
//
//	string infile = wavelist("*",";","") // get wave list
//	string hdflist = indexedfile(data,-1,".h5") // get list of .h5 files
//
//	string currentHDF="", currentWav="", datasets="", currentDS
//	if (!stringmatch(file_name, ""))
//		hdflist = file_name + ".h5"
//	endif
//	
//	variable numHDF = itemsinlist(hdflist), fileid=0, numWN = 0, wnExists=0
//	variable i=0, j=0, numloaded=0
//
//
//	for(i=0; i<numHDF; i+=1) // loop over h5 filelist
//
//	   currentHDF = StringFromList(i,hdflist)
//	   	//if (!stringmatch(currentHDF, "!*_RAW"))
//
//		HDF5OpenFile/P=data /R fileID as currentHDF
//		HDF5ListGroup /TYPE=2 /R=1 fileID, "/" // list datasets in root group
//		datasets = S_HDF5ListGroup
//		numWN = itemsinlist(datasets)
//		currentHDF = currentHDF[0,(strlen(currentHDF)-4)]
//		for(j=0; j<numWN; j+=1) // loop over datasets within h5 file
//			currentDS = StringFromList(j,datasets)
//			currentWav = currentHDF+currentDS
//		   wnExists = FindListItem(currentWav, infile,  ";")
//		   if (wnExists==-1)
//		   	// load wave from hdf
//		   	HDF5LoadData /Q /IGOR=-1 /N=$currentWav/TRAN=1 fileID, currentDS
//		   	numloaded+=1
//		   endif
//		endfor
//		HDF5CloseFile fileID
//		//endif
//	endfor
//
//   print numloaded, "waves uploaded"
//   
//   	variable	ms=stopmstimer(refnum)
//	print ms/1e6
//end




function ud()
	string infile = wavelist("*",";",""); print infile
	string infolder =  indexedfile(data,-1,".ibw")
	string current, current1
	variable numstrings = itemsinlist(infolder), i, curplace, numloaded=0
	variable refnum=startmstimer

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

macro plot2d(num,dataset,disp)
variable num
string dataset
variable disp

	string wvname
			wvname="dat"+num2str(num)+dataset
if (disp==1)
	display; 
	endif
	appendimage $wvname
	wavestats/q $wvname
	//ModifyImage $wvname ctab= {0.000,*,VioletOrangeYellow,0}
	ModifyImage $wvname ctab= {*,*,VioletOrangeYellow,0}
	


	ColorScale/C/N=text0/F=0/A=RC/E width=20,image=$wvname
	
	TextBox/C/N=text1/F=0/A=MT/E wvname
//ModifyImage $wvname minRGB=(0,65535,0),maxRGB=(4369,4369,4369)
//Label bottom xlabel
//Label left ylabel

ModifyGraph fSize=18
ModifyGraph gFont="Arial"
ModifyGraph grid=0
ModifyGraph width={Aspect,1.62},height=300
ModifyGraph width=0,height=0

	//Button logscale,proc=ButtonProc,title="log"//pos={647.00,11.00},size={50.00,20.00}
	//Button lin,proc=ButtonProc_1,title="lin"//pos={647.00,45.00},size={50.00,20.00}
	
	
	variable inc
	inc=(V_max-V_min)/30
	
//	decommentize below for peaks like CB
//	ModifyImage $wvname ctab= {inc,V_max-inc,ColdWarm,0};ModifyImage $wvname log=1

ModifyImage $wvname ctabAutoscale=3
	
end
end



function mean_nan(wavenm)
	wave wavenm
	
	variable i=0, sumwv=0, numpts=dimsize(wavenm,0), numvals=0
	do
		if (abs(wavenm[i])>0)
			sumwv += wavenm[i]
			numvals+=1
		endif
		i+=1
	while(i<numpts)
	return (sumwv/numvals)
end


function centerwave(wavenm)
	string wavenm 
	wave data
	Duplicate/o $wavenm data
	data=data/1.5

	
	variable centerpt, centerval
	wave w_coef=w_coef 



	variable l= dimsize(data, 0 )
	WaveStats/Q/R=[l/2-100,l/2+100] data
	//wavestats /q data
	centerpt = v_maxrowloc
	
	
	CurveFit/q/NTHR=0 lor  data[(centerpt-20),(centerpt+20)] 
	centerval=w_coef[2]
	SetScale/P x (dimoffset(data,0)-centerval),dimdelta(data,0),"", data
	display data
end 
	
function subtract_bg(rs, bias, current,[identifier])
variable rs, bias
variable identifier
wave current
variable aspectrat=6.8/3.2;
string wavenm=("cond"+num2str(identifier))

	if (paramisdefault(identifier))
		wavenm="cond"
	endif
    duplicate /o current  $wavenm
    wave cond=$wavenm
	duplicate /o current  temp

temp=bias/current-rs
cond=1/temp *aspectrat // cond * geometry of sample =conductivity
//display; appendimage cond



end	

macro setparams_wide()
ModifyGraph fSize=14
ModifyGraph gFont="arial"
ModifyGraph grid=0
ModifyGraph width=500,height=300
endmacro









	




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








Function save_specwave(waveno)
	variable waveno
	
	Variable index = 0
	do
		Wave/Z w = WaveRefIndexedDFR(:, index)
		if (!WaveExists(w))
			break
		endif
		
		String fileName = NameOfWave(w)
		string compare2="dat"+num2str(waveno)
		variable slen
		slen= strlen(compare2)

		if(stringmatch(fileName[0,slen-1], compare2))
		Save/C/O/P=data w as fileName
      print filename
		endif
		index += 1
	while(1)
	
	
End

function save_waves(Anfang,Ende)
	variable Anfang, Ende
	variable index=Anfang
	do
		save_specwave(index)
		index += 1
	while(index<Ende)
end











Function renamewave(oldprefix,newprefix)
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














function int_PSD(tim)
	string tim
//	wave ref
	string inwave="spectrum_2020-10-09_"+tim+"fftADC0"
	string outwave="spectrum_2020-10-09_"+tim+"_int"
	wave nw=$inwave
	//execute("graph()")
	wavestats/q nw
	if (V_min<-140)
	DeletePoints 0,1, nw
	endif
	
	appendtoGraph/l $inwave; 

	duplicate/o $inwave $outwave
	wave nw_int=$outwave
	duplicate/o nw temp
	temp= 10^(nw/10);

	Integrate temp/D=nw_int
	appendtoGraph/r nw_int; 
	makecolorful(); 
	
//	matrixop/o diff=ref-nw
//	display diff
//	SetScale/I x 0,1269,"", diff


end

macro testLI()
setFdacAWGSquareWave(fd, 100, -100, 0.01, 0.01, 0)
setupAWG(fd, AWs="0", DACs="0", numCycles=1, verbose=1);
ScanFastDAC(fd, -1, 1, "3", sweeprate=0.5,  repeats=1,  use_awg=1,nosave=0)
//lock_in_main_2d(wave0_2d,1)
//demodulate(filenum,1,"wa,[append2hdf])
//display average
endmacro


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

function /s getprefix(numstr)
    string numstr
    
    string junk
    variable number
    sscanf numstr, "%[^0123456789]%d", junk, number
    return junk
end

function /s getsuffix(numstr)
    string numstr
    
    string junk, suff
    variable number
    sscanf numstr, "%[^0123456789]%d%s", junk, number, suff
    return suff
end



function/wave rowslice(wave wav,int rownumb)
duplicate /o/rmd=[][rownumb,rownumb] wav, slice
redimension/n=(dimsize(slice,0)) slice
return slice
end




function centering(wave waved,string centered, wave mids)
	duplicate/o waved $centered
//	display; appendimage waved
	wave new2dwave=$centered
	copyscales waved new2dwave
	//new2dwave=interp2d(waved,(x+fit_params[q][3]),(y)) // column 3 is the center fit parameter
	new2dwave=interp2d(waved,(x+mids[q]),(y)) // mids is the shift in x
//		display; appendimage $centered

end

function center_xscale(wave waved)
duplicate/o waved tempx
tempx=x; wavestats/q tempx
	variable shift, delta
	shift= dimoffset(waved,0)-V_avg
	delta=dimdelta(waved,0)
	SetScale/P x shift,delta,"", waved
end

//function cst_centering(wave waved,string kenner_out)
//	string w2d=nameofwave(waved)
//	int wavenum=getfirstnum(w2d)
//	string centered=kenner_out+num2str(wavenum)+"centered"
//	string fit_params_name = kenner_out+num2str(wavenum)+"fit_params"
//	wave fit_params = $fit_params_name
//	
//	//	duplicate /o /r = [][0] waved wavex;redimension/N=(nr) wavex; wavex = x
//	duplicate/o waved $centered
//	wave new2dwave=$centered
//	copyscales waved new2dwave
//	new2dwave=interp2d(waved,(x+fit_params[q][3]),(y)) // column 3 is the center fit parameter
//end

function/WAVE calculate_spectrum(time_series, [scan_duration, linear])
	// Takes time series data and returns power spectrum
	wave time_series  // Time series (in correct units -- i.e. check that it's in nA first)
	variable scan_duration // If passing a wave which does not have Time as x-axis, this will be used to rescale
	variable linear // Whether to return with linear scale (or log scale)
	
	linear = paramisDefault(linear) ? 1 : linear

	duplicate/free time_series tseries
	if (scan_duration)
		setscale/i x, 0, scan_duration, tseries
	else
		scan_duration = DimDelta(time_series, 0) * DimSize(time_series, 0)
	endif

	variable last_val = dimSize(time_series,0)-1
	if (mod(dimsize(time_series, 0), 2) != 0)  // ODD number of points, must be EVEN to do powerspec
		last_val = last_val - 1
	endif
		
	
	// Built in powerspectrum function

	if (!linear)  // Use log scale
		DSPPeriodogram/PARS/DBR=1/NODC=2/R=[0,(last_val)] tseries  
		wave w_Periodogram
		duplicate/free w_Periodogram, powerspec
		powerspec = powerspec+10*log(scan_duration)  // This is so that the powerspec is independent of scan_duration
	else  // Use linear scale
		DSPPeriodogram/PARS/NODC=2/R=[0, (last_val)] tseries
		wave w_Periodogram
		duplicate/o w_Periodogram, powerspec
		// TODO: I'm not sure this is correct, but I don't know what should be done to fix it -- TIM
		powerspec = powerspec*scan_duration  // This is supposed to be so that the powerspec is independent of scan_duration
	endif
//	powerspec[0] = NaN
	return powerspec
	
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
//function rescalex(wave wav, variable factor)
//variable low=indextoScale(wav,0,0)*factor;
//variable high=indextoScale(wav,inf,0)*factor;
//SetScale/I x low,high,"", wav
//end
//
//function rescaley(wave wav, variable factor)
//variable low=indextoScale(wav,0,1)*factor;
//variable high=indextoScale(wav,inf,1)*factor;
//SetScale/I y low,high,"", wav
//end
//
