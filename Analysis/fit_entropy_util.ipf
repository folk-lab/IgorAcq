#pragma TextEncoding = "UTF-8"
#pragma rtGlobals = 3			// Use modern global access method and strict wave access
#pragma DefaultTab = {3,20,4}		// Set default tab width in Igor Pro 9 and later
#include <Reduce Matrix Size>


function master_entropy_clean_average(filenum, delay, wavelen, [average_repeats, demodulate_on, apply_scaling, forced_theta, fit_width])
	int filenum, delay, wavelen
	int average_repeats, demodulate_on, apply_scaling
	variable forced_theta, fit_width
	
	average_repeats = paramisdefault(average_repeats) ? 1 : average_repeats // assuming repeats to average into 1 trace
	demodulate_on = paramisdefault(demodulate_on) ? 0 : demodulate_on // demodulate OFF is default
	apply_scaling = paramisdefault(apply_scaling) ? 1 : apply_scaling // scaling ON is default
	fit_width = paramisdefault(fit_width) ? INF : fit_width // averaging ON is default
	
	
	int forced_theta_on = paramisdefault(forced_theta) ? 0 : 1 // forcing theta OFF is default
	
	string raw_wavename = "dat" + num2str(filenum) + "cscurrent_2d";
	
	///// demodulate data if necessary /////
	string demodx_wavename = "dat" + num2str(filenum) + "cscurrentx_2d";
	if (demodulate_on == 1)
		demodulate(filenum, 2, "cscurrent_2d", demod_wavename = demodx_wavename)
	endif
	wave demodx_wave = $demodx_wavename
	
	
	///// seperate out hot and cold (CREATES numerical_entropy) /////
	sqw_analysis($raw_wavename, delay, wavelen)
	wave numerical_entropy
	wave cold, hot
	
	///// plot thetas from cold wave /////
	string cold_wavename = "dat" + num2str(filenum) + "cscurrent_2d" + "_cold"
	duplicate /o cold $cold_wavename
	wave cold_wave = $cold_wavename
	
	master_ct_clean_average(cold_wave, 1, 0, "dat", average = 0, N=INF)
	
	string cold_params_wavename = "dat" + num2str(filenum) + "_cs_fit_params"
	wave cold_params_wave = $cold_params_wavename

	duplicate/o/r=[][3] cold_params_wave cold_mids
	
		
	///// center and average /////
	if (average_repeats == 1)
		
		///// centre the 2d traces /////
		centering(demodx_wave, "entropy_centered", cold_mids) // centred plot and average plot
		centering(numerical_entropy, "numerical_entropy_centered", cold_mids) // centred plot and average plot
		wave entropy_centered, numerical_entropy_centered
		
		///// average to a 1d trace /////
		avg_wav(entropy_centered); 
		avg_wav(numerical_entropy_centered)
		wave entropy_centered_avg, numerical_entropy_centered_avg
		
		///// take care of scaling and remove nans /////
		entropy_centered_avg *= 2
		wavetransform/o zapnans entropy_centered_avg
		wavetransform/o zapnans numerical_entropy_centered_avg
		
		Integrate entropy_centered_avg /D = entropy_centered_avg_int;
		Integrate numerical_entropy_centered_avg /D = numerical_entropy_centered_avg_int;
	
		
		///// scale entropy /////
		if (apply_scaling == 1)
		
			if (forced_theta_on == 1)
				wave entropy_scaling_factor = calc_scaling(cold, hot, cold_mids, average_repeats = 1, forced_theta = forced_theta, fit_width = fit_width)
			else
				wave entropy_scaling_factor = calc_scaling(cold, hot, cold_mids, average_repeats = 1, fit_width = fit_width)
			endif
			
			entropy_centered_avg_int *= entropy_scaling_factor[0]
			numerical_entropy_centered_avg_int *= entropy_scaling_factor[0]
		endif 
		
		
		///// plot entropy graph /////
		execute("graph_entropy_analysis()")
		
	elseif (average_repeats == 0)
	
		Integrate demodx_wave /D = entropy_int;
		Integrate numerical_entropy /D = numerical_entropy_int;
		
		///// scale entropy /////
		if (apply_scaling == 1)
		
			if (forced_theta_on == 1)
				wave entropy_scaling_factor = calc_scaling(cold, hot, cold_mids, average_repeats = 0, forced_theta = forced_theta, fit_width = fit_width)
			else
				wave entropy_scaling_factor = calc_scaling(cold, hot, cold_mids, average_repeats = 0, fit_width = fit_width)
			endif
			
			variable num_rows = dimsize(entropy_int, 1)
			
			offset_2d_traces(entropy_int)
			offset_2d_traces(numerical_entropy_int)
			
			variable i
			for (i=0; i < num_rows; i++)
				entropy_int[][i] = entropy_int[p][i] * entropy_scaling_factor[i]
				numerical_entropy_int[][i] = numerical_entropy_int[p][i] * entropy_scaling_factor[i]
			endfor
			
			display; appendimage entropy_int
			ModifyImage entropy_int ctab = {*, *, RedWhiteGreen, 0}
		
			display; appendimage numerical_entropy_int
			ModifyImage numerical_entropy_int ctab = {*, *, RedWhiteGreen, 0}
		
		else
			display; appendimage entropy_int
			ModifyImage entropy_int ctab = {*, *, RedWhiteGreen, 0}
		
			display; appendimage numerical_entropy_int
			ModifyImage numerical_entropy_int ctab = {*, *, RedWhiteGreen, 0}
			
		endif 
	
		
	endif

end


function offset_2d_traces(wave wav)
	// pass in a 2d wave and offset each trace so the first value is at set_y_point
	variable set_y_point = 0
	variable row_value
	
	variable num_rows = dimsize(wav, 1)
	
	variable i
	for (i=0; i < num_rows; i++)
		row_value = wav[0][i]
		wav[][i] = wav[p][i] - (row_value - set_y_point)
	endfor
end


function/wave sqw_analysis(wave wav, int delay, int wavelen)
// this function separates hot (plus/minus) and cold(plus/minus) and returns  two waves for hot and cold //part of CT
// CREATES wave numerical_entropy as a GLOBAL wave
// ASSUMES [cold, hot, cold, hot] heating
	variable nr, nc
	nr = dimsize(wav,0)
	nc = dimsize(wav,1)
	variable i = 0
	variable N
	N = nr / wavelen / 4;

	Make/o/N=(nc,(N)) cold1, cold2, hot1, hot2

	do
		rowslice(wav, i)
		wave slice
		
		Redimension/N=(wavelen, 4, N) slice
		DeletePoints/M=0 0,delay, slice
		reducematrixSize(slice, 0, -1, 1, 0, -1, 4, 1, "slice_new")
		
		wave slice_new
		cold1[i][] = slice_new[0][0][q]
		cold2[i][] = slice_new[0][2][q]
		hot1[i][] = slice_new[0][1][q]
		hot2[i][] = slice_new[0][3][q]

		i = i + 1
	while(i < nc)

	duplicate/o cold1, cold
	cold = (cold1 + cold2) / 2
	
	duplicate/o hot1, hot
	hot = (hot1 + hot2) / 2

	matrixtranspose hot
	matrixtranspose cold

	CopyScales wav, cold, hot
	
	duplicate/o hot, numerical_entropy
	numerical_entropy = cold - hot;

end


function/WAVE calc_scaling(cold, hot, mids, [average_repeats, forced_theta, fit_width])
	//first we need to center cold and hot wave
	wave cold, hot, mids
	int average_repeats
	variable forced_theta, fit_width
	
	average_repeats = paramisdefault(average_repeats) ? 1 : average_repeats // averaging ON is default
	fit_width = paramisdefault(fit_width) ? INF : fit_width // averaging ON is default
	

	int forced_theta_on = paramisdefault(forced_theta) ? 0 : 1 // forcing theta OFF is default
	
	
	///// centering by the mids then averaging /////
	if (average_repeats == 1)
				
		wave cold_centr, hot_centr
		centering(cold, "cold_centr", mids) // centred plot and average plot
		centering(hot, "hot_centr", mids) // centred plot and average plot

		wave cold_centr_avg, hot_centr_avg
		avg_wav(cold_centr)
		avg_wav(hot_centr)
		
		wavetransform/o zapnans cold_centr_avg
		wavetransform/o zapnans hot_centr_avg
	endif
	
	wave W_coef
	variable minx = 0
	variable maxx = dimsize(cold, 0) - 1
	
	
	variable num_rows
	if (average_repeats == 1)
		num_rows = 1
		make /O /N=1, Gos
		make /O /N=1, dTs
		make /O /N=1, factors
		wave Gos, dTs, factors
		
	else
		num_rows = dimsize(cold, 1)
		make /O /N=(num_rows), Gos
		make /O /N=(num_rows), dTs
		make /O /N=(num_rows), factors
		wave Gos, dTs, factors
	endif
	
	
	variable i, Go, dT, factor
	for (i = 0; i < num_rows; i++)
	
		if (average_repeats == 1)
			get_initial_params(cold_centr_avg)
			wave cold_single_trace = cold_centr_avg
			wave hot_single_trace = hot_centr_avg
		else
			duplicate /RMD=[][i] /o cold cold_single_trace
			wave cold_single_trace
			
			duplicate /RMD=[][i] /o hot hot_single_trace
			wave hot_single_trace
			
			get_initial_params(cold_single_trace)
		endif
		
		
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
	
//	if (average_repeats == 1)
//		execute("graph_hot_cold(hot_single_trace, cold_single_trace, fit_hot_single_trace, fit_cold_single_trace)")
//	endif
//	
	print "Go = " + num2str(Go)
	print "dT = " + num2str(dT)
	print "factor = " + num2str(factor)
	
	return factors
end


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