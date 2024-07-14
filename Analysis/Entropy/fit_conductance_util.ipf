#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3			// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#include <Reduce Matrix Size>

function master_cond_clean_average(wav, refit, kenner_out, [alternate_bias, N, no_centering, percent_width])
	// wav is the wave containing original dotcurrent data
	// refit tells whether to do new fits to each CT line
	// kenner_out is the prefix to replace dat for this analysis
	// kenner_out  can not contain a number otherwise getfirstnu will not work
	wave wav
	int refit
	string kenner_out
	int alternate_bias, N, no_centering
	variable percent_width

	alternate_bias = paramisdefault(alternate_bias) ? 0 : alternate_bias // alternate_bias OFF is default
	N = paramisdefault(N) ? 3 : N // 3 standard deviations is default
	no_centering = paramisdefault(no_centering) ? 0 : no_centering // will attempt to centre by default
	percent_width = paramisdefault(percent_width) ? 0.2 : percent_width // should be from 0 - 1. percent is misleading but more clear then 'frac_width'

	variable refnum, ms
	refnum=startmstimer

//	closeallGraphs()

	string datasetname = nameofwave(wav)
	string kenner_in = getsuffix(datasetname) //  cscurrent in the above case
	int wavenum = getfirstnum(datasetname) // XXX in the above case
	
	// these are the new wave names to be made
	string centered_wave_name = kenner_out + num2str(wavenum) + "_dot_centered"
	string cleaned_wave_name = kenner_out + num2str(wavenum) + "_dot_cleaned"
	string avg_wave_name = cleaned_wave_name + "_avg" // this name can be whatever, but keeping same standard as CT fitting. 

	string split_pos = cleaned_wave_name + "_pos"
	string split_neg = cleaned_wave_name + "_neg"
	string pos_avg = split_pos + "_avg"
	string neg_avg = split_neg + "_avg"
	string fit_params_name = kenner_out + num2str(wavenum) + "_dot_fit_params"



	if (refit==1)
		get_cond_fit_params($datasetname, kenner_out, percent_width = percent_width)// finds fit_params
		plot_gammas(fit_params_name, N) //need to do this to refind good and bad gammas
		duplicate/o/r=[][2] $fit_params_name mids
		if (no_centering == 1)
			duplicate /o $datasetname $centered_wave_name
		else
			centering($datasetname, centered_wave_name, mids)// only need to center after redoing fits, centred plot; returns centered_wave_name
		endif
		remove_bad_gammas($centered_wave_name, cleaned_wave_name) // only need to clean after redoing fits; returns centered_wave_name
	endif

	if (alternate_bias == 1)
		split_wave($cleaned_wave_name, 0) //makes XXX_dot_cleaned
	
		zap_NaN_rows($split_pos, overwrite = 1, percentage_cutoff_inf = 0.15)
		zap_NaN_rows($split_neg, overwrite = 1, percentage_cutoff_inf = 0.15)
	
		avg_wav($split_pos) // pos average
		avg_wav($split_neg) // neg average
	
		get_conductance_from_current($pos_avg, $neg_avg, avg_wave_name) // XXX_dot_cleaned_avg NO FUNCITON EXISTS FOR 'get_conductance_from_current_wc'
	else
		zap_NaN_rows($cleaned_wave_name, overwrite = 0, percentage_cutoff_inf = 0.15)
		avg_wav($cleaned_wave_name)
	endif
	
	plot_cond_figs(wavenum, N, kenner_in, kenner_out, alternate_bias = alternate_bias, percent_width = percent_width)

	ms=stopmstimer(refnum)
	print "Cond: time taken = " + num2str(ms/1e6) + "s"
end


function zap_NaN_rows(wave_2d, [overwrite, percentage_cutoff_inf])
	// removes any row from wave_2d where the number of NaNs is greater than the cutoff specified in percentage_cutoff_inf
	// wave_2d: 2d wave to remove rows from
	// overwrite: Default is overwrite = 0. overwrite = 1 will overwrite input wave and params wave.
	// percentage_cutoff_inf: Default is percentage_cutoff_inf = 0.15 :: 15%
	wave wave_2d
	int overwrite
	variable percentage_cutoff_inf
	
	percentage_cutoff_inf = paramisdefault(percentage_cutoff_inf) ? 0.15 : percentage_cutoff_inf // remove row with more than 15% NaN default


	// Duplicating 2d wave
	if (overwrite == 0)
		string wave_2d_name = nameofwave(wave_2d)
		string wave_2d_name_new = wave_2d_name + "_zap"
		duplicate /o wave_2d $wave_2d_name_new
		wave wave_2d_new = $wave_2d_name_new 
	endif
	
	
	create_x_wave(wave_2d)
	wave x_wave
	
	create_y_wave(wave_2d)
	wave y_wave
	
	variable num_rows = dimsize(wave_2d, 1)
	variable num_bad_rows = 0
	
	variable i 
	for (i = 0; i < num_rows; i++)
		duplicate /o /RMD=[][i - num_bad_rows] wave_2d data_slice
		wavestats /Q data_slice
		
		if (V_numNans / (V_npnts + V_numNans + V_numINFs) >= percentage_cutoff_inf)
		
			if (overwrite == 0)
				DeletePoints/M=1 (i - num_bad_rows), 1, wave_2d_new // delete row
			else
				DeletePoints/M=1 (i - num_bad_rows), 1, wave_2d // delete row
			endif
			
			num_bad_rows += 1
		endif
		
	endfor
end



function zapnan_scaling_overwrite(wave_1d, [overwrite])
	// removes any NaNs from a wave and preserves the x-scaling, assumes NaNs are only at the ends.
	// wave_1d: 2d wave to remove rows from
	// overwrite: Default is overwrite = 0. overwrite = 1 will overwrite input wave and params wave.
	// percentage_cutoff_inf: Default is percentage_cutoff_inf = 0.15 :: 15%
	wave wave_1d
	int overwrite

	// Duplicating 2d wave
	if (overwrite == 0)
		string wave_1d_name = nameofwave(wave_1d)
		string wave_1d_name_new = wave_1d_name + "_zap"
		duplicate /o wave_1d $wave_1d_name_new
		wave wave_1d_new = $wave_1d_name_new 
	endif
	
	
	create_x_wave(wave_1d)
	wave x_wave

	
	variable num_cols = dimsize(wave_1d, 0)
	variable value
	variable num_nan = 0
	
	variable i 
	for (i = 0; i < num_cols; i++)
	
		value = wave_1d[i]
		
		if (numtype(value) == 2)
			DeletePoints/M=0 (i - num_nan), 1, wave_1d_new // delete row
			DeletePoints/M=0 (i - num_nan), 1, x_wave // delete row
			num_nan += 1
		endif
	endfor
end



function/wave split_wave(wave wav, variable flag)
	// split the wave into positive and negative waves
	wave kenner
	redimension/n=-1 kenner
	string base_wave_name = nameofwave(wav)

	////////////////////////////
	///// create _pos wave /////
	////////////////////////////
	Duplicate/o kenner, idx
	idx = kenner[p] > flag ? p : NaN
	WaveTransform zapnans idx

	string pos_wave_name = base_wave_name + "_pos"
	duplicate/o wav $pos_wave_name
	wave out_wav = $pos_wave_name
	Redimension/E=1/N=(-1,dimsize(idx,0)) out_wav

	variable i=0
	do
		out_wav[][i]=wav[p][idx[i]]
		i=i+1
	while(i<dimsize(idx,0))


	////////////////////////////
	///// create _neg wave /////
	////////////////////////////
	Duplicate/o kenner,idx
	idx = kenner[p][q] < flag ? p : NaN
	WaveTransform zapnans idx

	string neg_wave_name = base_wave_name + "_neg"
	duplicate/o wav $neg_wave_name
	wave out_wav1 = $neg_wave_name
	Redimension/E=1/N=(-1,dimsize(idx,0)) out_wav1

	i=0
	do
		out_wav1[][i]=wav[p][idx[i]]
		i=i+1
	while(i<dimsize(idx,0))
	
end




function plot_gammas(string fit_params_name, variable N)

	int wavenum =getfirstnum(fit_params_name)
	variable gammamean
	variable gammastd
	variable i
	int nr

	wave fit_params = $fit_params_name
	nr = dimsize(fit_params,0)

	duplicate /O/R =[0,nr][3] fit_params gammas
	duplicate /O/R =[0,nr][1] fit_params amp

	gammamean = mean(gammas)
	gammastd = sqrt(variance(gammas))

	make /o/n =(nr) meanwave
	make /o/n =(nr) stdwave
	make /o/n =(nr) stdwave2
	make /o/n = 0 goodgammas
	make /o/n = 0 goodgammasx
	make /o/n = 0 badgammas
	make /o/n = 0 badgammasx

	meanwave = gammamean
	stdwave = gammamean - N * gammastd
	stdwave2 = gammamean + N * gammastd

	for (i=0; i < nr ; i+=1)

		if (abs(gammas[i] - gammamean) < (N * gammastd))

			insertPoints /v = (gammas[i]) nr, 1, goodgammas // value of gamma
			insertpoints /v = (i) nr, 1, goodgammasx        // the repeat

		else

			insertPoints /v = (gammas[i]) nr, 1, badgammas // value of gamma
			insertpoints /v = (i) nr, 1, badgammasx        // repeat

		endif

	endfor


	duplicate/o goodgammas kenner
	kenner=(amp[goodgammasx])

	display meanwave, stdwave, stdwave2
	appendtograph goodgammas vs goodgammasx
	appendtograph badgammas vs badgammasx


	ModifyGraph fSize=24
	ModifyGraph gFont="Gill Sans Light"
	ModifyGraph lstyle(meanwave)=3,rgb(meanwave)=(17476,17476,17476)
	ModifyGraph lstyle(stdwave)=3,rgb(stdwave)=(52428,1,1)
	ModifyGraph lstyle(stdwave2)=3,rgb(stdwave2)=(52428,1,1)
	ModifyGraph mode(goodgammas)=3,lsize(goodgammas)=2, rgb(goodgammas)=(2,39321,1)
	ModifyGraph mode(badgammas)=3
	Legend/C/N=text0/J/A=RT "\\s(meanwave) mean\r\\s(stdwave) 2*std\r\\s(goodgammas) good\r\\s(badgammas) outliers"
	TextBox/C/N=text1/A=MT/E=2 "\\Z14\\Z16 gammas of dat" + num2str(wavenum)

	Label bottom "repeat"
	Label left "gamma values"

end
 
 
 
function plot_badgammas(wave wav)
	int i
	int nr
	wave badgammasx
	string dataset=nameOfWave(wav)

	nr = dimsize(badgammasx,0)
	display
	
	if(nr>0)
		for(i=0; i < nr; i +=1)
			appendtograph wav[][badgammasx[i]]
		endfor
	
		makecolorful()
		ModifyGraph fSize=24
		ModifyGraph gFont="Gill Sans Light"
		Label bottom "voltage"
		Label left dataset
		TextBox/C/N=text1/A=MT/E=2 "bad gammas of "+dataset
	endif
end


function /wave remove_bad_gammas(wave center, string cleaned_wave_name)
	// takes a wave 'center' and 'cleans' it based on 'badgammasx'
	// any row with a 'badgammax' will be removed from the 2d wave center
	wave badgammasx
	duplicate/o center $cleaned_wave_name
	
	//////////////////////////////////////////
	///// removing lines with bad gammas /////
	//////////////////////////////////////////

	//////////////////////////////////////////
	///// removing lines with bad gammas /////
	//////////////////////////////////////////
	variable i, idx
	int nc
	int nr
	nr = dimsize(badgammasx,0) // number of rows
	i=0
	if (nr>0)
		do
			idx = badgammasx[i] - i // when deleting, I need the -i because if deleting in the loop the indeces of center change continously as points are deleted
			DeletePoints/M=1 idx,1, $cleaned_wave_name
			i += 1
		while (i<nr)
	endif
	
	
	/////////////////////////////////////////////////
	///// removing lines with more than X% NaNs /////
	/////////////////////////////////////////////////
//	variable nan_cutoff = 0.3 // remove line if more than 30% of points are NaNs
//	variable num_columns = round(dimsize($cleaned_wave_name, 0)/2)
//	variable delete_interlaced_flag
//	
//	for (i=0; i < num_columns; i++)
//		delete_interlaced_flag = 0
//		
//		///// check if pos bias has NaNs /////
//		duplicate /RMD=[][i*2] /o $cleaned_wave_name temp_interlace1
//		WaveStats /q temp_interlace1
//		
//		if (V_numNans/V_npnts >= nan_cutoff)
//			delete_interlaced_flag = 1
//		endif
//		
//		///// check if neg bias has NaNs /////
//		duplicate /RMD=[][i*2 + 1] /o $cleaned_wave_name temp_interlace2
//		WaveStats /q temp_interlace2
//		
//		if (V_numNans/V_npnts >= nan_cutoff)
//			delete_interlaced_flag = 1
//		endif
//		
//		
//		///// delete interlaced section if either row has NaNs /////
//		if (delete_interlaced_flag == 1)
//			DeletePoints/M=1 i*2, 1, $cleaned_wave_name
//			DeletePoints/M=1 i*2, 1, $cleaned_wave_name
//		endif
//	
//	endfor


	return center

end



function/wave get_conductance_from_current(wave pos, wave neg, string newname)
	// using the positive and negative bias data gievn in current
	// calculate the 2d array in units of conductance
	// CHECK: bias and inline resistance is hard coded
	duplicate/o pos, $newname
	wave temp = $newname;
	temp = (pos-neg)
	variable bias = (2 * 77 * 5)/77000000; // divider is 9950 and 1000 is for V instead of mV
	duplicate/o temp cond
	temp = (bias/temp)*1e9-21150;
	temp = 1/temp/7.7483e-05
end



function /wave fit_single_peak(current_array, [percent_width])
	wave current_array
	variable percent_width
	
	percent_width = paramisdefault(percent_width) ? 0.2 : percent_width // should be from 0 - 1. percent is misleading but more clear then 'frac_width'

	// fits the 1D current_array by taking the absolute value of the data
	// CHECK: Not ideal when the current is negative
	redimension/n=-1 current_array
	duplicate/o current_array temp
	Smooth/S=4 201, temp
	
	make /o/n=4 W_coef
	wave W_coef
	
	// K0 = DC offset
	// K1 = Amplitude
	// K2 = x offset
	// K3 = Gamma
	variable K0, K1, K2, K3, K4
	wavestats/q temp
	
	int pos_bias_check = 1 // set to 1 if positive bias
	if (abs(V_max) < abs(V_min)) // if most positive current is less in magnitude than most negative then probably biasing in other direction.
		pos_bias_check = 0
	endif
	
	// guesssing DC term
	if (pos_bias_check == 1)
		W_coef[0] = V_min
	else
		W_coef[0] = V_max
	endif
	
	
	// guesssing Amplitude
	if (pos_bias_check == 1)
		W_coef[1] = V_max - V_min
	else
		W_coef[1] = V_min - V_max
	endif
	
	
	/// guesssing x-offset
	variable mid_index
	if (pos_bias_check == 1)
		W_coef[2] = V_maxloc
		mid_index = V_maxrowloc
	else
		W_coef[2] = V_minloc
		mid_index = V_minrowloc
	endif


	/// guesssing gamma
	W_coef[3] = 0.02

	
//	variable mean_of_wave = mean(temp, pnt2x(temp, V_npnts*0.4), pnt2x(temp, V_npnts*0.6))
//	if (mean_of_wave >= 0)
//		temp -= wavemin(temp)
//	else
//		temp -= wavemax(temp)
//		temp *= -1
//		temp -= wavemin(temp)
//	endif
	
	
	// only fit to ±5% the number of points on either side of the peak
	wavestats/q current_array
	variable min_fit_index = round(x2pnt(current_array, W_coef[2]) - V_npnts*percent_width)
	if (min_fit_index < 0)
		min_fit_index = 0
	endif
	
	variable max_fit_index = round(x2pnt(current_array, W_coef[2]) + V_npnts*percent_width)
	if (max_fit_index > V_npnts)
		max_fit_index = V_npnts - 1
	endif
	
//	// NEW METHOD //
	string hold_string = "0000"; // not holding any terms fixed
	FuncFit/q /H=(hold_string) /TBOX=768 cond_fit_function W_coef temp /D
	FuncFit/q /H=(hold_string) /TBOX=768 cond_fit_function W_coef current_array[min_fit_index, max_fit_index] /D
	
	// OLD METHOD //
//	CurveFit/q /TBOX=768 lor current_array[min_fit_index, max_fit_index] /D // fit with lor (Lorentzian) :: /q = quiet :: /D = destwaveName
end




function /wave get_cond_fit_params(wav, kenner_out, [percent_width])
	wave wav
	string kenner_out
	variable percent_width
	
	percent_width = paramisdefault(percent_width) ? 0.2 : percent_width // should be from 0 - 1. percent is misleading but more clear then 'frac_width'

	string wave_name = nameofwave(wav)
	int wave_num = getfirstnum(wave_name)
	string fit_params_name = kenner_out + num2str(wave_num) + "_dot_fit_params" //new array

	variable i
	int nc
	int nr
	wave fit_params
	wave W_coef
	wave W_sigma

	nr = dimsize(wav,0) //number of rows (data points)
	nc = dimsize(wav,1) //number of columns (total sweeps)
	make/o /N=(nr) temp_wave
	CopyScales wav, temp_wave

	make/o /N= (nc , 8) /o $fit_params_name
	wave fit_params = $fit_params_name

	for (i=0; i < nc ; i+=1) //nc
		temp_wave = wav[p][i]		
		redimension/n=-1 temp_wave

		fit_single_peak(temp_wave, percent_width = percent_width)
		fit_params[i][0,3] = W_coef[q]
		fit_params[i][4] = W_sigma[0]
		fit_params[i][5] = W_sigma[1]
		fit_params[i][6] = W_sigma[2]
		fit_params[i][7] = W_sigma[3]

	endfor

	return fit_params
end



function plot_cond_figs(wavenum, N, kenner_in, kenner_out, [alternate_bias, percent_width])	
	variable wavenum, N
	string kenner_in, kenner_out
	int alternate_bias
	variable percent_width
	
	alternate_bias = paramisdefault(alternate_bias) ? 0 : alternate_bias // alternate_bias OFF is default
	percent_width = paramisdefault(percent_width) ? 0.2 : percent_width // should be from 0 - 1. percent is misleading but more clear then 'frac_width'
	
	string dataset = "dat" + num2str(wavenum) + kenner_in
	string centered_wave_name = kenner_out + num2str(wavenum) + "_dot_centered"
	string cleaned_wave_name = kenner_out + num2str(wavenum) + "_dot_cleaned"
	string avg_wave_name = cleaned_wave_name + "_avg"

	string split_pos = cleaned_wave_name + "_pos"
	string split_neg = cleaned_wave_name + "_neg"
	string pos_avg = split_pos + "_avg"
	string neg_avg = split_neg + "_avg"
	string fit_params_name = kenner_out + num2str(wavenum) + "_dot_fit_params" 


	/////////////////// 2D + bad gammas  //////////////////////////////////////
	plot2d_heatmap($dataset); // raw data
	
	if (alternate_bias == 1)
		plot2d_heatmap($split_pos) // positive bias
		plot2d_heatmap($split_neg) // negative bias
	endif
	
	plot2d_heatmap($centered_wave_name) // plot centered traces
	
	plot_gammas(fit_params_name,N)	// plot gamma values (FWHM)
	plot_badgammas($centered_wave_name) // plot traces with 'bad gammas'
	 
	plot2d_heatmap($cleaned_wave_name) // plot 2d with removed 'bad gamma' traces
	
	
	/////////////////// plot avg fit  //////////////////////////////////////
	display $avg_wave_name;

	string fit_name = "fit_" + avg_wave_name
	fit_single_peak($avg_wave_name, percent_width = percent_width) // getting fit parameters of final averaged trace
	
	Label bottom "gate (V)"
	Label left "cond (2e^2/h)"; // DelayUpdate
	ModifyGraph fSize=24
	ModifyGraph gFont="Gill Sans Light"
	ModifyGraph mode($fit_name)=0, lsize($fit_name)=1, rgb($fit_name)=(65535,0,0)
	ModifyGraph mode($avg_wave_name)=2, lsize($avg_wave_name)=2, rgb($avg_wave_name)=(0,0,0)
	legend
	Legend/C/N=text0/J/A=LB/X=59.50/Y=53.03

//	ModifyGraph log(left)=1,loglinear(left)=1 // log the y-axis

	TileWindows/O=1/C/P

end




Function cond_fit_function(w, ys, xs) : FitFunc
	Wave w, xs, ys
	// f(x) = Amp*tanh((x - Mid)/(2*theta)) + Linear*x + Const+Quad*x^2

	// f(x) = Amp*(1/pi * 0.5gamma / ((x - mid)^2 + (0.5gamma)^2)) + DC offset
	// K0 = DC offset
	// K1 = Amplitude
	// K2 = x offset
	// K3 = Gamma
	ys = w[1]*(1/pi)*(0.5*w[3] / ((xs - w[2])^2 + (0.5*w[3])^2)) + w[0]	
	
End
	
//////////////////////
///// DEPRECATED /////
//////////////////////
/////////////////////////////////////////////////////////
///// Using fit_single_peak() in favour of the below/////
/////////////////////////////////////////////////////////
//function fit_function_lorentzian(A, G, Vo, V)
//	variable A,G,Vo,V
//	variable cond
//
//	cond=A*G/((V-Vo)^2+(G/2)^2);
//	return cond
//end
//
//
//
//Function CBpeak_fit(w, V) : FitFunc
//	Wave w
//	Variable V
//	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
//	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
//	//CurveFitDialog/ Equation:
//	//CurveFitDialog/ f(V) = CBpeak(A,G,Vo,V)
//	//CurveFitDialog/ End of Equation
//	//CurveFitDialog/ Independent Variables 1
//	//CurveFitDialog/ V
//	//CurveFitDialog/ Coefficients 3
//	//CurveFitDialog/ w[0] = A
//	//CurveFitDialog/ w[1] = G
//	//CurveFitDialog/ w[2] = Vo
//
//	return fit_function_lorentzian(w[0],w[1],w[2],V)
//End
