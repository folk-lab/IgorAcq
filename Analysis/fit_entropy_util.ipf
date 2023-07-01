#pragma TextEncoding = "UTF-8"
#pragma rtGlobals = 3			// Use modern global access method and strict wave access
#pragma DefaultTab = {3,20,4}		// Set default tab width in Igor Pro 9 and later
#include <Reduce Matrix Size>


function center_demod(int filenum, int delay, int wavelen, [int average_repeats, int demodulate_on])
	average_repeats = paramisdefault(average_repeats) ? 1 : average_repeats // assuming repeats to average into 1 trace
	demodulate_on = paramisdefault(demodulate_on) ? 0 : demodulate_on // demodulate OFF is default
	string raw_wavename = "dat" + num2str(filenum) + "cscurrent_2d";
	
	wave numerical_entropy
	wave entropy_centered, numerical_entropy_centered
	
	
	///// demodulate data if necessary /////
	string demodx_wavename = "dat" + num2str(filenum) + "cscurrentx_2d";
	if (demodulate_on == 1)
		demodulate(filenum, 2, "cscurrent_2d", demod_wavename = demodx_wavename)
	endif
	wave demodx_wave = $demodx_wavename
	
	
	///// seperate out hot and cold (CREATES numerical_entropy) /////
	wave cold, hot
	sqw_analysis($raw_wavename, delay, wavelen)
		
		
	///// center and average /////
	if (average_repeats == 1)
		///// fit cold trace to centre transitions /////
		string cold_wavename = "dat" + num2str(filenum) + "cscurrent_2d" + "_cold"
		duplicate /o cold $cold_wavename
		wave cold_wave = $cold_wavename
		master_ct_clean_average(cold_wave, 1, 0, "dat", average = 0)
		string cold_params_wavename = "dat" + num2str(filenum) + "_cs_fit_params"
		wave cold_params_wave = $cold_params_wavename
		duplicate/o/r=[][3] cold_params_wave mids


		///// centre the 2d traces /////
		centering(demodx_wave, "entropy_centered", mids) // centred plot and average plot
		centering(numerical_entropy, "numerical_entropy_centered", mids) // centred plot and average plot
		
		
		///// average to a 1d trace /////
		wave entropy_centered_avg, numerical_entropy_centered_avg
		avg_wav(entropy_centered); 
		avg_wav(numerical_entropy_centered)
	
		
		///// take care of scaling and remove nans /////
		entropy_centered_avg *= 2
		wavetransform/o zapnans entropy_centered_avg
		wavetransform/o zapnans numerical_entropy_centered_avg
		
		Integrate entropy_centered_avg /D = entropy_centered_avg_int;
		Integrate numerical_entropy_centered_avg /D = numerical_entropy_centered_avg_int;
	
		
		///// scale entropy /////
		variable entropy_scaling_factor = calc_scaling(cold, hot, mids)
		entropy_centered_avg_int *= entropy_scaling_factor;
		numerical_entropy_centered_avg_int *= entropy_scaling_factor;
		
		
		///// plot entropy graph /////
		execute("graph_entropy_analysis()")
	elseif (average_repeats == 0)
		Integrate demodx_wave /D = entropy_centered_int;
		Integrate numerical_entropy /D = numerical_entropy_centered_int;
	
		display; appendimage entropy_centered_int
		ModifyImage entropy_centered_int ctab = {*, *, RedWhiteGreen, 0}
		
		display; appendimage numerical_entropy_centered_int
		ModifyImage numerical_entropy_centered_int ctab = {*, *, RedWhiteGreen, 0}
	endif

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
	wave slice, slice_new

	do
		rowslice(wav, i)
		Redimension/N=(wavelen, 4, N) slice
		DeletePoints/M=0 0,delay, slice
		reducematrixSize(slice, 0, -1, 1, 0, -1, 4, 1, "slice_new")

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


function calc_scaling(wave cold, wave hot, wave mids)
	//first we need to center cold and hot wave
	
	wave cold_centr, hot_centr
	centering(cold, "cold_centr", mids) // centred plot and average plot
	centering(hot, "hot_centr", mids) // centred plot and average plot
	
	wave cold_centr_avg, hot_centr_avg
	avg_wav(cold_centr)
	avg_wav(hot_centr)

	wave W_coef
	
	wavetransform/o zapnans cold_centr_avg
	wavetransform/o zapnans hot_centr_avg
	
	get_initial_params(cold_centr_avg)
	
	variable minx = 0
	variable maxx = dimsize(cold_centr_avg, 0) - 1
	
	fit_transition(cold_centr_avg, minx, maxx)
	duplicate/o W_coef, cold_params
	
	fit_transition(hot_centr_avg, minx, maxx)
	duplicate/o W_coef, hot_params
	    
	execute("graph_hot_cold()")
	
	
	///// calculate scaling factor /////
	variable Go = (cold_params[0] + hot_params[0])
	variable dT = ((hot_params[2] - cold_params[2]))
	variable factor = abs(1 / Go / dT)
	
	print "Go = " + num2str(Go)
	print "dT = " + num2str(dT)
	print "factor = " + num2str(factor)
	
	return factor
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


Window graph_hot_cold() : Graph
	PauseUpdate; Silent 1		// building window...
//	wave hot_centr_avg, cold_centr_avg, fit_cold_centr_avg, fit_hot_centr_avg
	Display /W=(711, 55, 1470, 497) hot_centr_avg, cold_centr_avg, fit_cold_centr_avg, fit_hot_centr_avg
	ModifyGraph lSize = 2
	ModifyGraph lStyle(fit_cold_centr_avg) = 7, lStyle(fit_hot_centr_avg) = 7
	ModifyGraph rgb(cold_centr_avg) = (0, 0, 65535), rgb(fit_cold_centr_avg) = (26214, 26214, 26214)
	ModifyGraph rgb(fit_hot_centr_avg) = (26214, 26214, 26214)
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