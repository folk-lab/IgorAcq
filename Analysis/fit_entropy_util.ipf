#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3			// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#include <Reduce Matrix Size>





function /wave sqw_analysis(wave wav, int delay, int wavelen)

// this function separates hot (plus/minus) and cold(plus/minus) and returns  two waves for hot and cold //part of CT
	variable nr, nc
	nr=dimsize(wav,0)
	nc=dimsize(wav,1)
	variable i=0
	variable N
	N=nr/wavelen/4;

	Make/o/N=(nc,(N)) cold1, cold2, hot1, hot2
	wave slice, slice_new

	do
		rowslice(wav,i)
		Redimension/N=(wavelen,4,N) slice //should be the dimension of fdAW AWG.Wavelen
		DeletePoints/M=0 0,delay, slice
		reducematrixSize(slice,0,-1,1,0,-1,4,1,"slice_new") // fdAW 

		cold1[i][]=slice_new[0][0][q]
		cold2[i][]=slice_new[0][2][q]
		hot1[i][]=slice_new[0][1][q]
		hot2[i][]=slice_new[0][3][q]


		i=i+1
	while(i<nc)

	duplicate/o cold1, cold; cold=(cold1+cold2)/2
	duplicate/o hot1, hot; hot=(hot1+hot2)/2

	matrixtranspose hot
	matrixtranspose cold

	CopyScales wav, cold, hot
	
	duplicate/o hot, nument
	nument=cold-hot;

end




function center_demod(int filenum, int delay, int wavelen)
	string wname="dat"+num2str(filenum)+"cscurrent_2d";
	sqw_analysis($wname,delay,wavelen)
	wave cold, hot, cold_avg, hot_avg,W_coef
	avg_wav(cold);
	avg_wav(hot)
	display hot_avg, cold_avg
	DeletePoints 5,1, W_coef
	W_coef[0]= {-0.0546777,0.882581,11.9077,-16.7818,7.74687e-05}
	    
	FuncFit/TBOX=768 Chargetransition W_coef cold_avg /D 
	duplicate/o W_coef, cold_r
	    
	FuncFit/TBOX=768 Chargetransition W_coef hot_avg /D 
	duplicate/o W_coef, hot_r
	    
	 variable   Go= (cold_r[0]+hot_r[0]); print Go; print "Go"
	 variable   dT=(hot_r[2]-cold_r[2]); print dT; print "dT"
	 
	 dT = 2.13
	 W_coef[0]= {0.0531997,0.880123,10.688,-12.024,7.28489e-05,7.50215e-08}
	
	
	string cold_wavename = "dat" + num2str(filenum) + "cscurrent_2d" + "_cold"
	duplicate /o cold $cold_wavename
	master_ct_clean_average($cold_wavename, 1, 0, "dat", average = 0)
	string cold_wave_params = "dat" + num2str(filenum) + "_cs_fit_params"
	
	wave ct0fit_params = $cold_wave_params
	
	duplicate/o/r=[][3] ct0fit_params mids
	demodulate(filenum, 2, "cscurrent_2d")
	wave demod
	string wname1="dat"+num2str(filenum)+"cscurrentx_2d";
	wave nument
	centering(demod,"entropy",mids) // centred plot and average plot
	centering(nument,"numentropy",mids) // centred plot and average plot
	
	wave entropy, entropy_avg, numentropy, numentropy_avg
	avg_wav(entropy); 
	avg_wav(numentropy)
	entropy_avg=entropy_avg*2;
	
	wavetransform zapnans entropy_avg
	wavetransform zapnans numentropy_avg
	
	Integrate entropy_avg/D=entropy_avg_INT;
	Integrate numentropy_avg/D=numentropy_avg_INT;
	entropy_avg_int=entropy_avg_INT/abs(Go)/dT
	numentropy_avg_int=numentropy_avg_INT/abs(Go)/dT
	
	execute("intent_graph()")
end

Window intent_graph() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(1471,53,2142,499) entropy_avg,numentropy_avg
	AppendToGraph/R entropy_avg_INT,numentropy_avg_INT
	ModifyGraph lSize(entropy_avg)=2,lSize(numentropy_avg)=2,lSize(entropy_avg_INT)=2
	ModifyGraph lSize(numentropy_avg_INT)=2
	ModifyGraph lStyle(numentropy_avg)=7,lStyle(numentropy_avg_INT)=7
	ModifyGraph rgb(entropy_avg_INT)=(4369,4369,4369),rgb(numentropy_avg_INT)=(4369,4369,4369)
	ModifyGraph zero(right)=15
	Legend/C/N=text1/J/X=67.51/Y=8.48 "\\s(entropy_avg) entropy_avg\r\\s(numentropy_avg) numentropy_avg\r\\s(entropy_avg_INT) entropy_avg_INT"
	AppendText "\\s(numentropy_avg_INT) numentropy_avg_INT"
	SetDrawLayer UserFront
	SetDrawEnv xcoord= axrel,ycoord= right,linethick= 2,linefgc= (65535,0,26214),dash= 7
	DrawLine 0,0.693147,1,0.693147
	SetDrawEnv xcoord= prel,ycoord= right,linethick= 2,linefgc= (1,4,52428)
	DrawLine 0,1.09861,1,1.09861
EndMacro

function calc_scaling(wave cold,wave hot, wave mids)

//first we need to center cold and hot wave

centering(cold,"cold_centr",mids) // centred plot and average plot
centering(hot,"hot_centr",mids) // centred plot and average plot

wave cold_centr,hot_centr, cold_centr_avg, hot_centr_avg, W_coef
avg_wav(cold_centr);
avg_wav(hot_centr);
 execute("hot_cold()")
DeletePoints 5,1, W_coef
    W_coef[0]= {-0.0546777,0.882581,11.9077,-16.7818,7.74687e-05}
    
    FuncFit/TBOX=768 Chargetransition W_coef cold_centr_avg /D 
    duplicate/o W_coef, cold_r
    
    FuncFit/TBOX=768 Chargetransition W_coef hot_centr_avg /D 
    duplicate/o W_coef, hot_r
    
 variable   Go= (cold_r[0]+hot_r[0]); print Go
 variable   dT=((hot_r[2]-cold_r[2])); print dT
 variable factor=-1/Go/dT; print factor
 return factor
end

Window hot_cold() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(711,55,1470,497) hot_centr_avg,cold_centr_avg,fit_cold_centr_avg,fit_hot_centr_avg
	ModifyGraph lSize=2
	ModifyGraph lStyle(fit_cold_centr_avg)=7,lStyle(fit_hot_centr_avg)=7
	ModifyGraph rgb(cold_centr_avg)=(0,0,65535),rgb(fit_cold_centr_avg)=(26214,26214,26214)
	ModifyGraph rgb(fit_hot_centr_avg)=(26214,26214,26214)
	TextBox/C/N=CF_cold_centr_avg/X=6.14/Y=6.89 "Coefficient values ± one standard deviation\r\tAmp   \t= -0.049555 ± 6.43e-05\r\tConst \t= 0.88481 ± 2.42e-05"
	AppendText "\tTheta \t= 7.8717 ± 0.0313\r\tMid   \t= 0.15659 ± 0.0306\r\tLinear\t= 9.1999e-05 ± 5.6e-07"
	TextBox/C/N=CF_hot_centr_avg/X=6.46/Y=35.81 "Coefficient values ± one standard deviation\r\tAmp   \t= -0.049523 ± 7.25e-05\r\tConst \t= 0.88481 ± 2.47e-05"
	AppendText "\tTheta \t= 10.005 ± 0.038\r\tMid   \t= -1.4357 ± 0.0354\r\tLinear\t= 9.1736e-05 ± 6.13e-07"
EndMacro


Window theta_graph() : Graph
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

function center_demod2(int filenum, int delay, int wavelen)
string wname="dat"+num2str(filenum)+"cscurrent_2d";
sqw_analysis($wname,delay,wavelen)
wave W_coef, cold, hot  
W_coef[0]= {0.0531997,0.880123,10.688,-12.024,7.28489e-05,7.50215e-08}
ctrans_avg2(cold,1,0, "ct", average=0)
wave ct0fit_params
duplicate/o/r=[][3] ct0fit_params mids
string wname1="dat"+num2str(filenum)+"cscurrentx_2d";

wave demod
demodulate(filenum, 2, "cscurrent_2d")

wave nument
centering(demod,"entropy",mids) // centred plot and average plot
centering(nument,"numentropy",mids) // centred plot and average plot

wave entropy, entropy_avg, numentropy, numentropy_avg
avg_wav(entropy); 
avg_wav(numentropy)
entropy_avg=entropy_avg*2;
wavetransform/o zapnans entropy_avg
wavetransform/o zapnans numentropy_avg

Integrate entropy_avg/D=entropy_avg_INT;
Integrate numentropy_avg/D=numentropy_avg_INT;

variable factor
factor=calc_scaling( cold, hot,  mids)
entropy_avg_int=entropy_avg_INT*factor;
numentropy_avg_int=numentropy_avg_INT*factor;

execute("intent_graph()")

end


function ctrans_avg2(wave wav, int refit,int dotcondcentering, string kenner_out,[string condfit_prefix, variable minx, variable maxx, int average])
	// wav is the wave containing original CT data
	// refit tells whether to do new fits to each CT line
	// dotcondcentering tells whether to use conductance data to center the CT data
	// kenner_out is the prefix to replace dat for this analysis
	// kenner_out and condfit_prefix can not contain a number otherwise getfirstnu will not work
	variable refnum, ms
	//	option to limit fit to indexes [minx,maxx]

	if (paramisdefault(minx))
		minx=pnt2x(wav,0)
	endif

	if (paramisdefault(maxx))
		maxx=pnt2x(wav,dimsize(wav,0))

	endif

	if (paramIsDefault(average))
		average=1
	endif

	//		stopalltimers() // run this line if timer returns nan

	refnum=startmstimer

	display
	string datasetname=nameofWave(wav) // typically datXXXcscurrent or similar
	string kenner=getsuffix(datasetname) //  cscurrent in the above case
	int wavenum=getfirstnum(datasetname) // XXX in the above case

	// these are the new wave names to be made
	string avg = kenner_out + num2str(wavenum) + "cleaned_avg"
	string centered=kenner_out+num2str(wavenum)+"centered"
	string cleaned=kenner_out+num2str(wavenum)+"cleaned"
	string fit_params_name = kenner_out+num2str(wavenum)+"fit_params"
	wave fit_params = $fit_params_name


	variable N=4; // how many sdevs are acceptable?


	wave W_coef
	wave badthetasx
	wave badgammasx


	string quickavg=avg_wav($datasetname) // averages datasetname and returns the name of the averaged wave

	if (refit==1)
		if (average==1) // sometimes we do not want to average
			get_initial_params($quickavg);// print W_coef
			fit_transition($quickavg,minx,maxx);// print W_coef
		endif

		get_fit_params($datasetname,fit_params_name,minx,maxx) //
	endif

	if (dotcondcentering==0)
	find_plot_thetas(wavenum,N,fit_params_name)
	doupdate

		if (average==1) // sometimes we do not want to average
			duplicate/o/r=[][3] $fit_params_name mids
			centering($datasetname,centered,mids) // centred plot and average plot
			cleaning($centered,badthetasx)
		endif

	elseif(dotcondcentering==1)
		string condfit_params_name=condfit_prefix+num2str(wavenum)+"fit_params"
		print condfit_params_name
		wave condfit_params = $condfit_params_name
		find_plot_gammas(condfit_params_name,N)
		plot_badgammas($centered)
		duplicate/o/r=[][2] condfit_params mids

		centering($datasetname,centered,mids)
		cleaning($centered,badgammasx)
	endif

	if (average==1) // sometimes we do not want to average
		avg_wav($cleaned) // quick average plot
		get_initial_params($quickavg); //print W_coef
		fit_transition($avg,minx,maxx)
		prepfigs(wavenum,N,kenner,kenner_out,minx,maxx)
	endif
	ms=stopmstimer(refnum)
	print ms/1e6
end
