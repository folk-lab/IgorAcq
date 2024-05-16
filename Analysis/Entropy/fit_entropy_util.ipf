#pragma TextEncoding = "UTF-8"
#pragma rtGlobals = 3			// Use modern global access method and strict wave access
#pragma DefaultTab = {3,20,4}		// Set default tab width in Igor Pro 9 and later
#include <Reduce Matrix Size>


function master_entropy_clean_average(filenum, delay, wavelen, [centre_repeats, average_repeats, demodulate_on, cold_awg_first, apply_scaling, forced_theta, fit_width, divide_data, resample_before_centering, resample_measure_freq, average_every_n, zero_offset_entropy, use_notch])
	int filenum, delay, wavelen
	int centre_repeats, average_repeats, demodulate_on, cold_awg_first, apply_scaling
	variable forced_theta, fit_width, divide_data, resample_before_centering, resample_measure_freq, average_every_n, zero_offset_entropy, use_notch
	
	centre_repeats = paramisdefault(centre_repeats) ? 0 : centre_repeats // default is to not centre repeats based on cold trace
	average_repeats = paramisdefault(average_repeats) ? 1 : average_repeats // default is to average repeats
	demodulate_on = paramisdefault(demodulate_on) ? 0 : demodulate_on // default demodulate OFF
	cold_awg_first = paramisdefault(cold_awg_first) ? 1 : cold_awg_first // default is cold heating cycle first
	apply_scaling = paramisdefault(apply_scaling) ? 1 : apply_scaling // scaling ON is default
	forced_theta = paramisdefault(forced_theta) ? 0 : forced_theta // default is forcing theta OFF for calculating the scaling. 0 assumes the theta needs to be calculated
	fit_width = paramisdefault(fit_width) ? INF : fit_width // default is to fit entire transition
	divide_data = paramisdefault(divide_data) ? 1 : divide_data // default not divide the data. Use case: If input data is RAW we may need to re-scale data.
	resample_before_centering = paramisdefault(resample_before_centering) ? 0 : resample_before_centering // resample the data before centering. Useful if file size are large. Resampled data not used to calculate entropy
	resample_measure_freq = paramisdefault(resample_measure_freq) ? 0 : resample_measure_freq // Force the resampling measure freq. If set to zero, uses the input from scanvars
	average_every_n = paramisdefault(average_every_n) ? 1 : average_every_n // average every n rows in a 2d data set. Useful if you have repeats at each setpoint
	zero_offset_entropy = paramisdefault(zero_offset_entropy) ? 0 : zero_offset_entropy // offset entropy data so delta Ics starts at zero
	use_notch = paramisdefault(use_notch) ? 0 : use_notch // assume a notch filtered wave has been created with "_nf" appended to the end. Default is to not use notch filtered wave
	
	string raw_wavename 
	if (use_notch == 0)
		raw_wavename = "dat" + num2str(filenum) + "cscurrent_2d"
	else
		raw_wavename = "dat" + num2str(filenum) + "cscurrent_2d_nf"
	endif
	
	string cs_cold_cleaned_name = "dat" + num2str(filenum) + "_cs_cleaned"
	string cs_hot_cleaned_name = "dat" + num2str(filenum) + "_cs_cleaned_hot"
	string cs_cold_cleaned_avg_name = cs_cold_cleaned_name + "_avg"
	string cs_hot_cleaned_avg_name = cs_hot_cleaned_name + "_avg"
	
	wave raw_wave = $raw_wavename
	if (divide_data != 1)
		raw_wave[][] = raw_wave[p][q]/divide_data
	endif
	
	
	//	notch filter
//	notch_filters($raw_wavename, Hzs="60;180;300;420;540;900",  Qs="50;150;250;360;500;850",  notch_name=notch_wavename)

	///// DEMODULATE /////
	string demodx_wavename = "dat" + num2str(filenum) + "cscurrentx_2d";
	wave demodx_wave = $demodx_wavename
//	demodx_wave[][] = demodx_wave[p][q]/divide_data
	if (demodulate_on == 1)
		demodx_wave[][] = demodx_wave[p][q]/divide_data
		demodulate(filenum, 2, "cscurrent_2d", demod_wavename = demodx_wavename)
		wave demodx_wave = $demodx_wavename
		demodx_wave *= 2
		duplicate /o $demodx_wavename demod_entropy
	endif
//	duplicate /o $demodx_wavename demod_entropy
	wave demod_entropy


	///// SEPARATE HOT AND COLD (CREATES numerical_entropy, cold, cold_diff, hot, hot_diff) /////
	sqw_analysis($raw_wavename, delay, wavelen, cold_awg_first=cold_awg_first)
	wave hot, cold, cold_diff, hot_diff, numerical_entropy

	///// CENTERING /////
	if (centre_repeats == 1)
		// fit cold transitions
		if (resample_before_centering != 0)
			duplicate /o cold cold_resampled
			resampleWave(cold_resampled, resample_before_centering, measureFreq = resample_measure_freq)
			wave cold_resampled
			master_ct_clean_average(cold_resampled, 1, 0, "dat")
		else
			master_ct_clean_average(cold, 1, 0, "dat")
		endif
		wave dat0_cs_cleaned
		wave dat0_cs_cleaned_avg // if no num in wave then overwrites dat0 in experiment. 
		duplicate /o dat0_cs_cleaned $cs_cold_cleaned_name
		duplicate /o dat0_cs_cleaned_avg $cs_cold_cleaned_avg_name
		
		// centre hot transitions using cold mids
		wave dat0_cs_fit_params
		duplicate/o/r=[][3] dat0_cs_fit_params mids
		wave mids
		centering(hot, "hot_centered", mids)
		wave hot_centered
		wave badthetasx
		remove_bad_thetas(hot_centered, badthetasx, "hot_cleaned")
//		zap_NaN_rows(hot_centered, overwrite = 1, percentage_cutoff_inf = 0.15)
		wave hot_cleaned
		duplicate /o hot_cleaned $cs_hot_cleaned_name
		
		if (resample_before_centering != 0)
			duplicate /o cold dat0_cs_cleaned
			centering(cold, "cold_centered", mids)
			wave cold_centered
			wave badthetasx
			remove_bad_thetas(cold_centered, badthetasx, "cold_cleaned")
	//		zap_NaN_rows(hot_centered, overwrite = 1, percentage_cutoff_inf = 0.15)
			wave cold_cleaned
			duplicate /o cold_cleaned $cs_cold_cleaned_name
		endif

		// create numerical entropy from centered cold and hot waves
		duplicate /o $cs_cold_cleaned_name numerical_entropy
		wave cold_cleaned = $cs_cold_cleaned_name
		numerical_entropy = cold_cleaned - hot_cleaned
		
		// centre demod entropy
		centering(demod_entropy, "demod_entropy_centered", mids)
		wave demod_entropy_centered
		zap_NaN_rows(demod_entropy_centered, overwrite = 1, percentage_cutoff_inf = 0.15)
		
		// centre cold diff and hot diff
		centering(cold_diff, "cold_diff_centered", mids)
		wave cold_diff_centered
		zap_NaN_rows(cold_diff_centered, overwrite = 1, percentage_cutoff_inf = 0.15)
		duplicate /o cold_diff_centered cold_diff
		
		centering(hot_diff, "hot_diff_centered", mids)
		wave hot_diff_centered
		zap_NaN_rows(hot_diff_centered, overwrite = 1, percentage_cutoff_inf = 0.15)
		duplicate /o hot_diff_centered hot_diff
		
		// centre plus diff and minus diff
		wave plus_diff
		centering(plus_diff, "plus_diff_centered", mids)
		wave plus_diff_centered
		zap_NaN_rows(plus_diff_centered, overwrite = 1, percentage_cutoff_inf = 0.15)
		duplicate /o plus_diff_centered plus_diff
		
		wave minus_diff
		centering(minus_diff, "minus_diff_centered", mids)
		wave minus_diff_centered
		zap_NaN_rows(minus_diff_centered, overwrite = 1, percentage_cutoff_inf = 0.15)
		duplicate /o minus_diff_centered minus_diff
	endif
	
	
	
	///// AVERAGING /////
	string cs_cleaned_cold_avg_name, cs_cleaned_hot_avg_name, cs_cleaned_name
	if ((average_repeats == 1) && (centre_repeats == 1)) // use centred wave to average
		if (resample_before_centering != 0)
			avg_wav($cs_cold_cleaned_name)
		endif
		avg_wav($cs_hot_cleaned_name)
		
		wave cold_avg = $cs_cold_cleaned_avg_name
		wave hot_avg = $cs_hot_cleaned_avg_name
		duplicate /o cold_avg numerical_entropy_avg
		wave numerical_entropy_avg
		numerical_entropy_avg = cold_avg - hot_avg
		
		if (demodulate_on == 1)
			// average demod entropy
			wave demod_entropy_centered
			avg_wav(demod_entropy_centered)
			wave demod_entropy_centered_avg
			zap_NaNs(demod_entropy_centered_avg, overwrite=1)
		endif
		
		zap_NaNs(cold_avg, overwrite=1)
		zap_NaNs(hot_avg, overwrite=1)
		zap_NaNs(numerical_entropy_avg, overwrite=1)
		
	elseif ((average_repeats == 1) && (centre_repeats == 0)) // blind average
		duplicate /o cold $cs_cold_cleaned_name
		duplicate /o hot $cs_hot_cleaned_name
		avg_wav(cold)
		avg_wav(hot)
		wave cold_avg, hot_avg
		duplicate /o cold_avg $cs_cold_cleaned_avg_name
		duplicate /o hot_avg $cs_hot_cleaned_avg_name
		
		avg_wav(numerical_entropy)
		wave numerical_entropy_avg
		
		if (demodulate_on == 1)
			// average demod entropy
			avg_wav(demod_entropy)
			wave demod_entropy_avg
		endif
	elseif ((average_repeats == 0) && (average_every_n > 1))
		average_every_n_rows(cold, average_every_n, overwrite=1)
		average_every_n_rows(hot, average_every_n, overwrite=1)
		average_every_n_rows(demod_entropy, average_every_n, overwrite=1)
		average_every_n_rows(numerical_entropy, average_every_n, overwrite=1)
	endif
	
	

	
	
	///// INTEGRATE ///// 
	duplicate /o demod_entropy demod_entropy_int
	duplicate /o numerical_entropy numerical_entropy_int // big issue with nans will really mess with the data !!!!!
	
	if (zero_offset_entropy != 0)
		offset_2d_traces(demod_entropy, use_average=0.2)
		offset_2d_traces(numerical_entropy, use_average=0.2)
	endif
	
	Integrate demod_entropy /D = demod_entropy_int
	Integrate  numerical_entropy /D = numerical_entropy_int
	offset_2d_traces(demod_entropy_int)
	offset_2d_traces(numerical_entropy_int)
	
	wave entropy_centered_avg, numerical_entropy_centered_avg
	if (average_repeats == 1)
		if (demodulate_on == 1)
			if (centre_repeats == 1)
				Integrate demod_entropy_centered_avg /D = demod_entropy_avg_int
			else
				Integrate demod_entropy_avg /D = demod_entropy_avg_int
			endif
		endif
		Integrate numerical_entropy_avg /D = numerical_entropy_avg_int
	endif
	
	
	///// APPLY SCALING /////
	// scale 1D data 
	if ((apply_scaling == 1) && (average_repeats == 1))
		if (forced_theta != 0)
			wave entropy_scaling_factor = calc_scaling2($cs_cold_cleaned_avg_name, $cs_hot_cleaned_avg_name, average_repeats = 1, forced_theta = forced_theta, fit_width = fit_width)
		else
			wave entropy_scaling_factor = calc_scaling2($cs_cold_cleaned_avg_name, $cs_hot_cleaned_avg_name, average_repeats = 1, fit_width = fit_width)
		endif
		
		demod_entropy_avg_int *= entropy_scaling_factor[0]
		numerical_entropy_avg_int *= entropy_scaling_factor[0]
	endif 
	
	// scale 2D data 
	if ((apply_scaling == 1) && (average_repeats == 0))
		if (forced_theta != 0)
			wave entropy_scaling_factor = calc_scaling2($cs_cold_cleaned_name, $cs_hot_cleaned_name, average_repeats = 1, forced_theta = forced_theta, fit_width = fit_width)
		else
			wave entropy_scaling_factor = calc_scaling2($cs_cold_cleaned_name, $cs_hot_cleaned_name, average_repeats = 1, fit_width = fit_width)
		endif
		
		int i
		for (i=0; i < dimsize(numerical_entropy_int, 1); i++)
			demod_entropy_int[][i] = demod_entropy_int[p][i] * entropy_scaling_factor[i]
			numerical_entropy_int[][i] = numerical_entropy_int[p][i] * entropy_scaling_factor[i]
		endfor
	endif 
	

	// giving entropy datasets filenum related names
	string base_entropy_numerical_name = "dat" + num2str(filenum) + "_numerical_entropy"
	string base_entropy_demod_name = "dat" + num2str(filenum) + "_demod_entropy"
	
	// create filenum specific numerical entropy waves
	string entropy_numerical_2d_name = base_entropy_numerical_name + "_2d"
	string entropy_numerical_avg_name = base_entropy_numerical_name + "_avg"
	string entropy_int_numerical_2d_name = base_entropy_numerical_name + "_int_2d"
	string entropy_int_numerical_avg_name = base_entropy_numerical_name + "_int_avg"
	
	duplicate /o numerical_entropy $entropy_numerical_2d_name
	duplicate /o numerical_entropy_int $entropy_int_numerical_2d_name
	if (average_repeats == 1)
		duplicate /o numerical_entropy_avg $entropy_numerical_avg_name
		duplicate /o numerical_entropy_avg_int $entropy_int_numerical_avg_name
	endif


	// create filenum specific demod entropy waves
	string entropy_demod_2d_name = base_entropy_demod_name + "_2d"
	string entropy_demod_avg_name = base_entropy_demod_name + "_avg"
	string entropy_int_demod_2d_name = base_entropy_demod_name + "_int_2d"
	string entropy_int_demod_avg_name = base_entropy_demod_name + "_int_avg"

	duplicate /o demod_entropy $entropy_demod_2d_name
	duplicate /o demod_entropy_int $entropy_int_demod_2d_name
	if ((average_repeats == 1) && (demodulate_on == 1))
		duplicate /o demod_entropy_avg $entropy_demod_avg_name
		duplicate /o demod_entropy_avg_int $entropy_int_demod_avg_name
	endif
	
	
	///// PLOTTING /////
	closeallgraphs()
	
	///// cold diff and hot diff /////
	plot2d_heatmap(cold_diff, x_label = "Gate (mV)", y_label = "Repeats") // difference between cold set points
	plot2d_heatmap(hot_diff, x_label = "Gate (mV)", y_label = "Repeats") // difference between hot set points
	
	avg_wav(cold_diff) // average cold diff
	avg_wav(hot_diff) // average hot diff
	wave cold_diff_avg, hot_diff_avg
	smooth 500, cold_diff_avg; smooth 500, hot_diff_avg
	display cold_diff_avg, hot_diff_avg
	ModifyGraph rgb(cold_diff_avg)=(1,16019,65535)
	legend
	
	///// plus diff and minus diff /////
	wave plus_diff, minus_diff
	plot2d_heatmap(plus_diff, x_label = "Gate (mV)", y_label = "Repeats") // difference between cold set points
	plot2d_heatmap(minus_diff, x_label = "Gate (mV)", y_label = "Repeats") // difference between hot set points
	
	avg_wav(plus_diff) // average cold diff
	avg_wav(minus_diff) // average hot diff
	wave plus_diff_avg, minus_diff_avg
	smooth 500, plus_diff_avg; smooth 500, minus_diff_avg
	display plus_diff_avg, minus_diff_avg
	ModifyGraph rgb(minus_diff_avg)=(0,0,0)
	legend
	
	
	///// cold average and hot average /////
	if (average_repeats == 1)
		plot2d_heatmap($cs_cold_cleaned_name, x_label = "Gate (mV)", y_label = "Repeats") // cold transition 
		plot2d_heatmap($cs_hot_cleaned_name, x_label = "Gate (mV)", y_label = "Repeats") // hot transition
	
		display $cs_cold_cleaned_avg_name $cs_hot_cleaned_avg_name
		ModifyGraph rgb($cs_cold_cleaned_avg_name)=(0,0,65535)
		legend
	else
		plot2d_heatmap(cold, x_label = "Gate (mV)", y_label = "Repeats") // cold transition 
		plot2d_heatmap(hot, x_label = "Gate (mV)", y_label = "Repeats") // hot transition
	endif
	
	///// entropy 2d /////
	if (demodulate_on == 1)
		plot2d_heatmap($entropy_demod_2d_name, x_label = "Gate (mV)", y_label = "Repeats") // demod entropy 
		plot2d_heatmap($entropy_int_demod_2d_name, x_label = "Gate (mV)", y_label = "Repeats") // demod entropy 
	endif
	
	plot2d_heatmap($entropy_numerical_2d_name, x_label = "Gate (mV)", y_label = "Repeats") // numerical entropy
	plot2d_heatmap($entropy_int_numerical_2d_name, x_label = "Gate (mV)", y_label = "Repeats") // numerical entropy
	
	///// entropy 1d /////
	display $entropy_numerical_avg_name 
	if (demodulate_on == 1)
		appendtograph $entropy_demod_avg_name
	endif
	
	appendtograph /r $entropy_int_numerical_avg_name 
	if (demodulate_on == 1)
		appendtograph /r $entropy_int_demod_avg_name
		ModifyGraph rgb($entropy_demod_avg_name)=(0,0,0), rgb($entropy_int_demod_avg_name)=(0,0,0)
	endif
	legend
	Label left "dN/dT"
	Label right "delta.S"

	TileWindows/O=1/C/P
	
//	///// plot thetas from cold wave /////
//	string cold_wavename = "dat" + num2str(filenum) + "cscurrent_2d" + "_cold"
//	duplicate /o cold $cold_wavename
//	wave cold_wave = $cold_wavename
//	
//	master_ct_clean_average(cold_wave, 1, 0, "dat", average = 0, N=INF)
	
//	string cold_params_wavename = "dat" + num2str(filenum) + "_cs_fit_params"
//	wave cold_params_wave = $cold_params_wavename
//
//	duplicate/o/r=[][3] cold_params_wave cold_mids
	
		
	///// center and average /////
//	if (average_repeats == 1)
		
		///// centre the 2d traces /////
//		centering(demodx_wave, "entropy_centered", cold_mids) // centred plot and average plot
////		centering(numerical_entropy, "numerical_entropy_centered", cold_mids) // centred plot and average plot
//		wave entropy_centered, numerical_entropy_centered
//		
//		///// average to a 1d trace /////
//		avg_wav(entropy_centered); 
//		avg_wav(numerical_entropy_centered)
//		wave entropy_centered_avg, numerical_entropy_centered_avg
//		
////		///// take care of scaling and remove nans /////
////		entropy_centered_avg *= 2
////		wavetransform/o zapnans entropy_centered_avg
////		wavetransform/o zapnans numerical_entropy_centered_avg
//		
////		Integrate entropy_centered_avg /D = entropy_centered_avg_int;
////		Integrate numerical_entropy_centered_avg /D = numerical_entropy_centered_avg_int;
////	
//		
////		///// scale entropy /////
////		if (apply_scaling == 1)
////		
////			if (forced_theta != 0)
////				wave entropy_scaling_factor = calc_scaling(cold, hot, cold_mids, average_repeats = 1, forced_theta = forced_theta, fit_width = fit_width)
////			else
////				wave entropy_scaling_factor = calc_scaling(cold, hot, cold_mids, average_repeats = 1, fit_width = fit_width)
////			endif
////			
////			entropy_centered_avg_int *= entropy_scaling_factor[0]
////			numerical_entropy_centered_avg_int *= entropy_scaling_factor[0]
////		endif 
//		
		
//		///// plot entropy graph /////
//		execute("graph_entropy_analysis()")
//		
//	elseif (average_repeats == 0)
//	
//		Integrate demodx_wave /D = entropy_int;
//		Integrate numerical_entropy /D = numerical_entropy_int;
//		
//		///// scale entropy /////
//		if (apply_scaling == 1)
//		
//			if (forced_theta != 0)
//				wave entropy_scaling_factor = calc_scaling(cold, hot, cold_mids, average_repeats = 0, forced_theta = forced_theta, fit_width = fit_width)
//			else
//				wave entropy_scaling_factor = calc_scaling(cold, hot, cold_mids, average_repeats = 0, fit_width = fit_width)
//			endif
//			
//			variable num_rows = dimsize(entropy_int, 1)
//			
//			offset_2d_traces(entropy_int)
//			offset_2d_traces(numerical_entropy_int)
//			
//			variable i
//			for (i=0; i < num_rows; i++)
//				entropy_int[][i] = entropy_int[p][i] * entropy_scaling_factor[i]
//				numerical_entropy_int[][i] = numerical_entropy_int[p][i] * entropy_scaling_factor[i]
//			endfor
//			
//			display; appendimage entropy_int
//			ModifyImage entropy_int ctab = {*, *, RedWhiteGreen, 0}
//		
//			display; appendimage numerical_entropy_int
//			ModifyImage numerical_entropy_int ctab = {*, *, RedWhiteGreen, 0}
//		
//		else
//			display; appendimage entropy_int
//			ModifyImage entropy_int ctab = {*, *, RedWhiteGreen, 0}
//		
//			display; appendimage numerical_entropy_int
//			ModifyImage numerical_entropy_int ctab = {*, *, RedWhiteGreen, 0}
//			
//		endif 
//	
//		
//	endif

end





function/wave sqw_analysis(wave wav, int delay, int wavelen, [variable cold_awg_first])
	// this function separates hot (plus/minus) and cold(plus/minus) and returns  two waves for hot and cold //part of CT
	// CREATES wave numerical_entropy as a GLOBAL wave
	// ASSUMES [cold, hot, cold, hot] heating
	cold_awg_first = paramisdefault(cold_awg_first) ? 1 : cold_awg_first // [cold, hot, cold, hot] default

	variable nr, nc
	nr = dimsize(wav,0)
	nc = dimsize(wav,1)
	variable i = 0
	variable N
	N = nr / wavelen / 4;

	Make/o/N=(nc,(N)) cold1, cold2, hot1, hot2
	wave cold1, cold2, hot1, hot2
	do
		rowslice(wav, i)
		wave slice
		
		Redimension/N=(wavelen, 4, N) slice
		DeletePoints/M=0 0,delay, slice
		reducematrixSize(slice, 0, -1, 1, 0, -1, 4, 1, "slice_new")
		wave slice_new
		
		if (cold_awg_first == 1)
			cold1[i][] = slice_new[0][0][q]
			cold2[i][] = slice_new[0][2][q]
			hot1[i][] = slice_new[0][1][q]
			hot2[i][] = slice_new[0][3][q]
		else
			cold1[i][] = slice_new[0][1][q]
			cold2[i][] = slice_new[0][3][q]
			hot1[i][] = slice_new[0][0][q]
			hot2[i][] = slice_new[0][2][q]
		endif

		i = i + 1
	while(i < nc)

	///// cold and hot averages
	duplicate/o cold1, cold
	cold = (cold1 + cold2) / 2
	
	duplicate/o hot1, hot
	hot = (hot1 + hot2) / 2
	
	///// differences between cold
	duplicate /o cold cold_diff
	wave cold_diff
	cold_diff = cold1 - cold2
	
	duplicate /o hot hot_diff
	wave hot_diff
	hot_diff = hot1 - hot2

	///// differences between plus setpoints
	duplicate /o cold1 plus_diff
	wave plus_diff
	plus_diff = cold1 - hot1
	
	duplicate /o cold2 minus_diff
	wave minus_diff
	minus_diff = cold2 - hot2
	
	matrixtranspose cold
	matrixtranspose hot
	
	matrixtranspose cold_diff
	matrixtranspose hot_diff
	
	matrixtranspose plus_diff
	matrixtranspose minus_diff

	CopyScales wav, cold, hot, cold_diff, hot_diff, plus_diff, minus_diff
	
	duplicate/o hot, numerical_entropy
	numerical_entropy = cold - hot;

end




function/WAVE calc_scaling2(cold, hot, [average_repeats, forced_theta, fit_width])
	//first we need to center cold and hot wave
	wave cold, hot
	int average_repeats
	variable forced_theta, fit_width
	
	average_repeats = paramisdefault(average_repeats) ? 1 : average_repeats // averaging ON is default
	fit_width = paramisdefault(fit_width) ? INF : fit_width // averaging ON is default
	
	int forced_theta_on = paramisdefault(forced_theta) ? 0 : 1 // forcing theta OFF is default
	
	wave W_coef
	variable minx = 0
	variable maxx = dimsize(cold, 0) - 1
	
	variable num_rows = dimsize(cold, 1) + 1
	make /O /N=(num_rows), Gos
	make /O /N=(num_rows), dTs
	make /O /N=(num_rows), factors
	wave Gos, dTs, factors
	
	variable i, Go, dT, factor
	for (i = 0; i < num_rows; i++)
	
		duplicate /RMD=[][i] /o cold cold_single_trace
		duplicate /RMD=[][i] /o hot hot_single_trace
		
		wave cold_single_trace, hot_single_trace
		
		get_initial_params(cold_single_trace)

		
		///// fit cold and hot trace /////
		fit_transition(cold_single_trace, minx, maxx, fit_width = fit_width)
		duplicate/o W_coef, cold_params
		
		fit_transition(hot_single_trace, minx, maxx, fit_width = fit_width)
		duplicate/o W_coef, hot_params
		
		
		///// calculate scaling factor /////
		Go = (cold_params[0] + hot_params[0])
		
		if (forced_theta_on == 1)
			dT = forced_theta
		else
			dT = ((hot_params[2] - cold_params[2]))
		endif
		
		factor = abs(1 / Go / dT)
		
		Gos[i] = Go
		dTs[i] = dT
		factors[i] = factor
		
	endfor
	
	print "Go = " + num2str(Go)
	print "dT = " + num2str(dT)
	print "factor = " + num2str(factor)
	
	return factors
end


//
//
//function/WAVE calc_scaling(cold, hot, mids, [average_repeats, forced_theta, fit_width])
//	//first we need to center cold and hot wave
//	wave cold, hot, mids
//	int average_repeats
//	variable forced_theta, fit_width
//	
//	average_repeats = paramisdefault(average_repeats) ? 1 : average_repeats // averaging ON is default
//	fit_width = paramisdefault(fit_width) ? INF : fit_width // averaging ON is default
//	
//
//	int forced_theta_on = paramisdefault(forced_theta) ? 0 : 1 // forcing theta OFF is default
//	
//	
//	///// centering by the mids then averaging /////
//	if (average_repeats == 1)
//				
//		wave cold_centr, hot_centr
//		centering(cold, "cold_centr", mids) // centred plot and average plot
//		centering(hot, "hot_centr", mids) // centred plot and average plot
//
//		wave cold_centr_avg, hot_centr_avg
//		avg_wav(cold_centr)
//		avg_wav(hot_centr)
//		
//		wavetransform/o zapnans cold_centr_avg
//		wavetransform/o zapnans hot_centr_avg
//	endif
//	
//	wave W_coef
//	variable minx = 0
//	variable maxx = dimsize(cold, 0) - 1
//	
//	
//	variable num_rows
//	if (average_repeats == 1)
//		num_rows = 1
//		make /O /N=1, Gos
//		make /O /N=1, dTs
//		make /O /N=1, factors
//		wave Gos, dTs, factors
//		
//	else
//		num_rows = dimsize(cold, 1)
//		make /O /N=(num_rows), Gos
//		make /O /N=(num_rows), dTs
//		make /O /N=(num_rows), factors
//		wave Gos, dTs, factors
//	endif
//	
//	
//	variable i, Go, dT, factor
//	for (i = 0; i < num_rows; i++)
//	
//		if (average_repeats == 1)
//			get_initial_params(cold_centr_avg)
//			wave cold_single_trace = cold_centr_avg
//			wave hot_single_trace = hot_centr_avg
//		else
//			duplicate /RMD=[][i] /o cold cold_single_trace
//			wave cold_single_trace
//			
//			duplicate /RMD=[][i] /o hot hot_single_trace
//			wave hot_single_trace
//			
//			get_initial_params(cold_single_trace)
//		endif
//		
//		
//		///// fit cold and hot trace /////
//		fit_transition(cold_single_trace, minx, maxx, fit_width = fit_width)
//		duplicate/o W_coef, cold_params
//		
//		fit_transition(hot_single_trace, minx, maxx, fit_width = fit_width)
//		duplicate/o W_coef, hot_params
//		
//		///// calculate scaling factor /////
//		Go = (cold_params[0] + hot_params[0])
//		
//		if (forced_theta_on == 1)
//			dT = forced_theta
//		else
//			dT = ((hot_params[2] - cold_params[2]))
//		endif
//		
//		factor = abs(1 / Go / dT)
//		
//		Gos[i] = Go
//		dTs[i] = dT
//		factors[i] = factor
//		
//	endfor
//	
////	if (average_repeats == 1)
////		execute("graph_hot_cold(hot_single_trace, cold_single_trace, fit_hot_single_trace, fit_cold_single_trace)")
////	endif
////	
//	print "Go = " + num2str(Go)
//	print "dT = " + num2str(dT)
//	print "factor = " + num2str(factor)
//	
//	return factors
//end


//////////////////////////////////
///// Building Graphs Macros /////
//////////////////////////////////
Window graph_entropy_analysis() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(1471,53,2142,499) entropy_centered_avg, numerical_entropy_centered_avg
	AppendToGraph/R entropy_centered_avg_int, numerical_entropy_centered_avg_int
	ModifyGraph lSize(entropy_centered_avg) = 2, lSize(numerical_entropy_centered_avg) = 2, lSize(entropy_centered_avg_int) = 2
	ModifyGraph lSize(numerical_entropy_centered_avg_int) = 2
	ModifyGraph lStyle(numerical_entropy_centered_avg) = 7, lStyle(numerical_entropy_centered_avg_int) = 7
	ModifyGraph rgb(entropy_centered_avg_int) = (4369,4369,4369), rgb(numerical_entropy_centered_avg_int) = (4369,4369,4369)
	ModifyGraph zero(right) = 15
	Legend/C/N=text1/J/X=67.51/Y=8.48 "\\s(entropy_centered_avg) entropy_centered_avg\r\\s(numerical_entropy_centered_avg) numerical_entropy_centered_avg\r\\s(entropy_centered_avg_int) entropy_centered_avg_int"
	AppendText "\\s(numerical_entropy_centered_avg_int) numerical_entropy_centered_avg_int"
	SetDrawLayer UserFront
	SetDrawEnv xcoord = axrel,ycoord = right,linethick = 2,linefgc = (65535,0,26214), dash= 7
	DrawLine 0,0.693147,1,0.693147
	SetDrawEnv xcoord = prel, ycoord = right, linethick = 2, linefgc = (1, 4, 52428)
	DrawLine 0, 1.09861, 1, 1.09861
	Label bottom "Gate voltage (mV)"
	Label right "Entropy"
EndMacro


Window graph_hot_cold(wave hot_wave, wave cold_wave, wave fit_hot_wave, wave fit_cold_wave) : Graph
	wave hot_wave
	wave cold_wave
	wave fit_hot_wave
	wave fit_cold_wave
	PauseUpdate; Silent 1		// building window...
//	wave hot_centr_avg, cold_centr_avg, fit_cold_centr_avg, fit_hot_centr_avg
	Display /W=(711, 55, 1470, 497) hot_wave, cold_wave, fit_hot_wave, fit_cold_wave
	ModifyGraph lSize = 2
	ModifyGraph lStyle(fit_cold_wave) = 7, lStyle(fit_hot_wave) = 7
	ModifyGraph rgb(cold_wave) = (0, 0, 65535), rgb(fit_cold_wave) = (26214, 26214, 26214)
	ModifyGraph rgb(fit_hot_wave) = (26214, 26214, 26214)
//	TextBox/C/N=CF_cold_centr_avg/X=6.14/Y=6.89 "Coefficient values ± one standard deviation\r\tAmp   \t= -0.049555 ± 6.43e-05\r\tConst \t= 0.88481 ± 2.42e-05"
//	AppendText "\tTheta \t= 7.8717 ± 0.0313\r\tMid   \t= 0.15659 ± 0.0306\r\tLinear\t= 9.1999e-05 ± 5.6e-07"
//	TextBox/C/N=CF_hot_centr_avg/X=6.46/Y=35.81 "Coefficient values ± one standard deviation\r\tAmp   \t= -0.049523 ± 7.25e-05\r\tConst \t= 0.88481 ± 2.47e-05"
//	AppendText "\tTheta \t= 10.005 ± 0.038\r\tMid   \t= -1.4357 ± 0.0354\r\tLinear\t= 9.1736e-05 ± 6.13e-07"
	Label bottom "Gate voltage (mV)"
	Label left "Current (nA)"
	Legend
EndMacro


Window graph_theta() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(35,53,710,497) meanwave,stdwave,stdwave2
	AppendToGraph goodthetas vs goodthetasx
	AppendToGraph badthetas vs badthetasx
	ModifyGraph gFont="Gill Sans Light"
	ModifyGraph mode(goodthetas)=3,mode(badthetas)=3
	ModifyGraph lSize(goodthetas)=2
	ModifyGraph lStyle(meanwave)=3,lStyle(stdwave)=3,lStyle(stdwave2)=3
	ModifyGraph rgb(meanwave)=(17476,17476,17476),rgb(stdwave)=(52428,1,1),rgb(stdwave2)=(52428,1,1)
	ModifyGraph rgb(goodthetas)=(2,39321,1)
	ModifyGraph fSize=24
	Label left "theta values"
	Label bottom "repeat"
	Legend/C/N=text0/J "\\s(meanwave) mean\r\\s(stdwave) 2*std\r\\s(goodthetas) good\r\\s(badthetas) outliers"
	TextBox/C/N=text1/A=MT/E=2 "\\Z14\\Z16 thetas of dat0"
EndMacro