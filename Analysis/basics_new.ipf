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

	print AWGLI

	cols=dimsize(wav,0); print cols
	rows=dimsize(wav,1); print rows
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
	
	
//	display
//	appendimage temp

//	display
//	appendimage sinewave

//	Duplicate /o sine1d, wave0x
//	wave0x = x
//
//	display wav vs wave0x
//	appendtoGraph sine1d
//

	
	print "cols = " + num2str(cols)
	print "rows = " + num2str(rows)
	print "(cols/period/nofcycles) = " + num2str(cols/period/nofcycles)
	ReduceMatrixSize(temp, 0, -1, (cols/period/nofcycles), 0,-1, rows, 1, "demod")
	
//	display 
////	display wav
//	appendimage temp
//	display temp
//wn="demod"
//	if (append2hdf)
//		variable fileid
//		fileid=get_hdfid(datnum) //opens the file
//		HDF5SaveData/o /IGOR=-1 /TRAN=1 /WRIT=1 /Z $wn, fileid
//		HDF5CloseFile/a fileid
//	endif

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
	axis = paramisdefault(axis) ? 0 : axis
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
	
	if (axis==2)
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


function resampleWave(wave wav,variable targetFreq )
	// resamples wave w from measureFreq
	// to targetFreq (which should be lower than measureFreq)	
	string wn=nameOfWave(wav)
	int wavenum=getfirstnum(wn)
	string temp_name="dat"+num2str(wavenum)+"x_array"
	
	variable measureFreq
//	struct ScanVars S
//	fd_getScanVars(S,wavenum)
struct AWGVars S
fd_getoldAWG(S,wavenum)

	measureFreq=S.measureFreq
	variable N=measureFreq/targetFreq

	
	RatioFromNumber (targetFreq / measureFreq)
	if (V_numerator > V_denominator)
		string cmd
		printf cmd "WARNING[scfd_resampleWaves]: Resampling will increase number of datapoints, not decrease! (ratio = %d/%d)\r", V_numerator, V_denominator
	endif
	resample/UP=(V_numerator)/DOWN=(V_denominator)/N=201/E=3 wav

	//DeletePoints/M=1 25,370, wav
	


	// TODO: Need to test N more (simple testing suggests we may need >200 in some cases!)
	// TODO: Need to decide what to do with end effect. Possibly /E=2 (set edges to 0) and then turn those zeros to NaNs? 
	// TODO: Or maybe /E=3 is safest (repeat edges). The default /E=0 (bounce) is awful.
end






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

	redimension/N=(num_rows, -1) temp_ifft

	copyscales wav, temp_ifft
		
	duplicate /o temp_ifft $notch_name
	
//	if (overwrite_wave == 1)
//		duplicate/o wave_copy, wav
//	endif
end




function notch_filters(wave wav, [string Hzs, string Qs, string notch_name])
	// wav is the wave to be filtered.  notch_name, if specified, is the name of the wave after notch filtering.
	// If not specified the filtered wave will have the original name plus '_nf' 
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
	int wavenum = getfirstnum(wav_name)
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

	redimension/N=(num_rows, -1) temp_ifft
	copyscales wav, temp_ifft
	duplicate /o temp_ifft $notch_name

	
end


function spectrum_analyzer(wave data, variable samp_freq)
	// Built in powerspectrum function
	duplicate/o data spectrum
	SetScale/P x 0,1/samp_freq,"", spectrum
	variable nr=dimsize(spectrum,0);  // number of points in x-direction
	variable le=2^(floor(log(nr)/log(2))); // max factor of 2 less than total num points
	wave slice;
	wave w_Periodogram

	variable i=0
	rowslice(spectrum,i)
		DSPPeriodogram/R=[1,(le)] /DB/NODC=1/DEST=W_Periodogram slice
	duplicate/o w_Periodogram, powerspec
	i=1
	do
		rowslice(spectrum,i)
		DSPPeriodogram/R=[1,(le)]/DB/NODC=1/DEST=W_Periodogram slice
		powerspec=powerspec+W_periodogram
		i=i+1
	while(i<dimsize(spectrum,1))
	powerspec[0]=nan
	display powerspec; // SetAxis bottom 0,500

end




///// DEPRECATED ///// 
//function remove_noise(wave wav)
//	//argument/variable Declaration
//	String wavestring=nameOfWave(wav)
//	wave wav1,wav2,wav3
//	string name=wavestring+"_nf"
//	string wn,wn1,wn2,wn3
//	int wavenum=getfirstnum(wavestring)
//
////notch_filter(wave wav, variable Hz, int wavenum)
//	notch_filter(wav,60);
//	notch_filter($name,180)
//	name=wavestring+"_nf_nf";notch_filter($name,300)
//
//
//	//assigning variables
//	wn=wavestring
//	wn1=wavestring+"_nf" // the notchfiltered wave
//	wn2=wavestring+"_nf_nf" // the notchfiltered wave
//	wn3=wavestring+"_nf_nf_nf" // the notchfiltered wave
//
//	wave wav1=$wn1; 	wave wav2=$wn2; 	wave wav3=$wn3
//	wav1=wav3;
//	killwaves wav3,wav2
//	wave slice
//	rowslice(wav,0); duplicate/o slice slice1; 
//	rowslice(wav1,0); duplicate/o slice slice2; 
//	
//	rowslice(wav,30); duplicate/o slice slice3; 
//	rowslice(wav1,30); duplicate/o slice slice4; 
//	
//	rowslice(wav,60); duplicate/o slice slice5; 
//	rowslice(wav1,60); duplicate/o slice slice6; 
//	
//	//print "run noise_check to check the result"
//
//end



Window Noise_check() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(35,53,1478,1119) slice1,slice2,slice3,slice4,slice5,slice6
	ModifyGraph rgb(slice1)=(13107,13107,13107),rgb(slice2)=(65535,62414,0),rgb(slice3)=(13107,13107,13107)
	ModifyGraph rgb(slice4)=(0,65535,47661),rgb(slice5)=(13107,13107,13107),rgb(slice6)=(32767,0,65535)
	ModifyGraph offset(slice3)={400,0},offset(slice4)={400,0},offset(slice5)={-400,0}
	ModifyGraph offset(slice6)={-400,0}
	Legend/C/N=text0/J "\\s(slice1) slice1\r\\s(slice2) slice2\r\\s(slice3) slice3\r\\s(slice4) slice4\r\\s(slice5) slice5\r\\s(slice6) slice6"
EndMacro


//function scfd_postFilterNumpts(raw_numpts, measureFreq)  // TODO: Rename to NumptsAfterFilter
//    // Returns number of points that will exist after applying lowpass filter specified in ScanController_Fastdac
//    variable raw_numpts, measureFreq
//	
//	nvar boxChecked = sc_ResampleFreqCheckFadc
//	nvar targetFreq = sc_ResampleFreqFadc
//	if (boxChecked)
//	  	RatioFromNumber (targetFreq / measureFreq)
//	  	return round(raw_numpts*(V_numerator)/(V_denominator))  // TODO: Is this actually how many points are returned?
//	else
//		return raw_numpts
//	endif
//end

function /s avg_wav(wave wav) // /WAVE lets your return a wave

	//  averaging any wave over columns (in y direction)
	// wave returned is avg_name
	string wn=nameofwave(wav)
	string avg_name=wn+"_avg";
	int nc
	int nr

//	wn="dat"+num2str(wavenum)+dataset //current 2d array

	nr = dimsize($wn,0) //number of rows (sweep length)
	nc = dimsize($wn,1) //number of columns (repeats)
	ReduceMatrixSize(wav, 0, -1, nr, 0,-1, 1,1, avg_name)
	redimension/n=-1 $avg_name
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

ModifyGraph fSize=24
ModifyGraph gFont="Gill Sans Light"
ModifyGraph grid=0
ModifyGraph width={Aspect,1.62},height=300
ModifyGraph width=0,height=0

	//Button logscale,proc=ButtonProc,title="log"//pos={647.00,11.00},size={50.00,20.00}
	//Button lin,proc=ButtonProc_1,title="lin"//pos={647.00,45.00},size={50.00,20.00}
	
	
	variable inc
	inc=(V_max-V_min)/20
	Button autoscale,pos={52.00,9.00},size={103.00,21.00},proc=ButtonProc_2,title="high contrast"
	Button use_lookup,pos={49.00,35.00},size={105.00,23.00},proc=ButtonProc_5,title="use lookup"
	Button linear,pos={163.00,9.00},size={50.00,20.00},proc=ButtonProc_6,title="linear"
	
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
ModifyGraph fSize=24
ModifyGraph gFont="Gill Sans Light"
ModifyGraph width={Aspect,1},height=400
ModifyGraph grid=0
ModifyGraph width=500,height=380
ModifyGraph width=0,height=0
endmacro

macro setparams_square()

Label bottom ""
Label left ""
	ModifyGraph fSize=24
ModifyGraph gFont="Gill Sans Light"
//ModifyGraph width=283.465,height={Aspect,1.62}
ModifyGraph grid=2
ModifyGraph width={Aspect,1},height=400

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
closeallGraphs()
sc_openInstrConnections(0)
setFdacAWGSquareWave(fd, 100, -100, 0.001, 0.001, 0)
setupAWG(fd, AWs="0", DACs="0", numCycles=1, verbose=1);
ScanFastDAC(fd, 0, 1, "3", sweeprate=1,  use_awg=1,nosave=1, repeats = 1)

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
	wave new2dwave=$centered
	copyscales waved new2dwave
	//new2dwave=interp2d(waved,(x+fit_params[q][3]),(y)) // column 3 is the center fit parameter
	new2dwave=interp2d(waved,(x+mids[q]),(y)) // mids is the shift in x
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
