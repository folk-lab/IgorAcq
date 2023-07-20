#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3			// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#include <Reduce Matrix Size>

function master_ct_clean_average(wav, refit, dotcondcentering, kenner_out, [condfit_prefix, minx, maxx, average, fit_width])
	// wav is the wave containing original CT data
	// refit tells whether to do new fits to each CT line
	// dotcondcentering tells whether to use conductance data to center the CT data
	// kenner_out is the prefix to replace dat for this analysis
	// kenner_out and condfit_prefix can not contain a number otherwise getfirstnu will not work
	// fit_width: in points units rather than index. Will mask data to fit_width on either side of chosen mid point to attempt to fit. 
	wave wav
	int refit, dotcondcentering
	string kenner_out
	// optional params
	string condfit_prefix
	variable minx, maxx, fit_width
	int average


	///// start function timer
	variable refnum, ms
	refnum=startmstimer


	///// optional params /////
	//	option to limit fit to indexes [minx,maxx]
	minx = paramisdefault(minx) ? 0 : minx // averaging ON is default
	maxx = paramisdefault(maxx) ? (dimsize(wav, 0) - 1) : maxx // averaging ON is default
	average = paramisdefault(average) ? 1 : average // averaging ON is default
	fit_width = paramisdefault(fit_width) ? inf : fit_width // averaging ON is default
	
	
	///// hard coded std setting
	variable N = 3; // how many sdevs are acceptable?
	
	
	///// setting wave names /////
	string datasetname = nameofWave(wav) // typically datXXXcscurrent or similar
	string kenner = getsuffix(datasetname) //  cscurrent in the above case
	int wavenum = getfirstnum(datasetname) // XXX in the above case


	// these are the new wave names to be made
	string centered_wave_name = kenner_out + num2str(wavenum) + "_cs_centered"
	string cleaned_wave_name = kenner_out + num2str(wavenum) + "_cs_cleaned"
	string avg_wave_name = cleaned_wave_name + "_avg"
	
	string fit_params_name = kenner_out + num2str(wavenum) + "_cs_fit_params"
	wave fit_params = $fit_params_name

	wave W_coef
	wave badthetasx
	wave badgammasx
	
	string quickavg = avg_wav($datasetname) // averages datasetname and returns the name of the averaged wave

	if (refit==1)
		get_initial_params($quickavg)
		if(average==1)
			fit_transition($quickavg, minx, maxx, fit_width = fit_width); // print W_coef
		endif
		// fit each row (IGOR column) to get fit params
		get_fit_params($datasetname, fit_params_name, minx, maxx, fit_width = fit_width) 

	endif

	if (dotcondcentering==0)
		zap_bad_params($datasetname, $fit_params_name, 6, overwrite = 1, zap_bad_mids = 1, zap_bad_thetas = 1) // remove rows with any fit param = INF or NaN
		plot_thetas(wavenum, N, fit_params_name)
		if(average==1)	
			duplicate/o/r=[][3] $fit_params_name mids
			centering($datasetname, centered_wave_name, mids) // centred plot and average plot
			remove_bad_thetas($centered_wave_name, badthetasx, cleaned_wave_name)
		endif

	elseif(dotcondcentering==1)
		string condfit_params_name = condfit_prefix + num2str(wavenum) + "_dot_fit_params"
		wave condfit_params = $condfit_params_name
		
		plot_gammas(condfit_params_name, N)
		plot_badgammas($centered_wave_name)
		duplicate/o/r=[][2] condfit_params mids

		centering($datasetname, centered_wave_name, mids)
		remove_bad_thetas($centered_wave_name, badgammasx, cleaned_wave_name)
	endif

	if(average==1)
//		replace_nans_with_avg($cleaned_wave_name, overwrite=0) // remove any row with > 25% NaNs in the row
		avg_wav($cleaned_wave_name) // quick average plot
		
		wavetransform/o zapnans $avg_wave_name
		get_initial_params($avg_wave_name); //print W_coef
		
		fit_transition($avg_wave_name, minx, maxx, fit_width = fit_width)
		plot_ct_figs(wavenum, N, kenner, kenner_out, minx, maxx, fit_width = fit_width)
	endif

	ms=stopmstimer(refnum)
	print "CT: time taken = " + num2str(ms/1e6) + "s"
end



function /wave get_initial_params(sweep, [update_amp_only, update_theta_only, update_mid_only])
	// for a given sweep returns a guess of initial parameters for the fit function: Charge transiton
	wave sweep
	int update_amp_only, update_theta_only, update_mid_only
		
	update_amp_only = paramisdefault(update_amp_only) ? 0 : update_amp_only // updating amp only OFF is default
	update_theta_only = paramisdefault(update_theta_only) ? 0 : update_theta_only // updating theta only OFF is default
	update_mid_only = paramisdefault(update_mid_only) ? 0 : update_mid_only // updating mid only OFF is default
	
	// check if we want to only update wcoef rather than re-write
	variable update_wcoef_only
	if ((update_mid_only == 1) || (update_amp_only == 1) || (update_theta_only == 1))
		update_wcoef_only = 1
	else
		update_wcoef_only = 0
	endif
	
	duplicate /o sweep x_array
	x_array = x
	wave x_array

	///// guess of amp term /////
	variable amp = wavemax(sweep) - wavemin(sweep) //might be worthwile looking for a maximum/minimum with differentiation
	
	///// guess of constant term /////
	variable const = mean(sweep)
	
	///// guess of theta term /////
	variable theta = 10

	///// guess of mid term ////
	duplicate /o sweep sweepsmooth
	Smooth/S=4 201, sweepsmooth
	differentiate sweepsmooth
	variable wave_min = wavemin(sweepsmooth)
	FindLevel /Q sweepsmooth, wave_min
	variable mid = V_LevelX
	
	// set mid to mid x value if calculated mid point outside range
	if ((mid < x_array[0]) || (mid > x_array[inf]))
		wavestats /Q x_array
		mid = x_array[round(V_npnts/2)]
	endif


	///// guess of linear term /////
	variable lin = 0.001  // differentiated value of flat area?


	killwaves sweepsmooth
	
	// if we are updating any of the wcoefs
	if (update_wcoef_only == 1)
		Wave/Z w = W_coef
		
		// update amp
		if (update_amp_only == 1)
			w[0] = amp
		endif	
		
		// update theta
		if (update_theta_only == 1)
			w[2] = theta
		endif		
		
		// update mid
		if (update_mid_only == 1)
			w[3] = mid
		endif
		
		return w
	endif
	
	if (update_wcoef_only != 1)
		Make /D/N=6/O W_coef
		W_coef[0] = {amp,const,theta,mid,lin,0}
		return W_coef
	endif

//	Wave/Z w = W_coef
//	
//	Make /D/N=6/O W_coef
//	W_coef[0] = {amp,const,theta,mid,lin,0}
//	
//	killwaves sweepsmooth
//	return W_coef

end


function zap_bad_params(wave_2d, params, num_params, [overwrite, zap_bad_mids, zap_bad_thetas])
	wave wave_2d, params
	variable num_params
	int overwrite, zap_bad_mids, zap_bad_thetas
		
	variable num_cols = dimsize(wave_2d, 0)
	variable num_rows = dimsize(wave_2d, 1)

	duplicate /o /RMD=[][0] wave_2d x_array
	x_array = x
	wave x_array
	variable scan_width = (x_array[INF] - x_array[0])/2
	variable scan_mid = x_array[0] + scan_width
	variable mid_percentage_within = 0.1
	
	// Duplicating 2d wave
	string wave_2d_name = nameofwave(wave_2d)
	string wave_2d_name_new = wave_2d_name + "_new"
	duplicate /o wave_2d $wave_2d_name_new
	wave wave_2d_new = $wave_2d_name_new 
	
	// Duplicating param wave
	string params_name = nameofwave(params)
	string params_name_new = params_name + "_new"
	duplicate /o params $params_name_new
	wave params_new = $params_name_new 
	
	variable num_bad_rows = 0
	variable is_bad_mid, mid
	variable is_bad_theta, theta
	
	variable i
	for (i = 0; i < num_rows; i++)
		is_bad_mid = 0
		is_bad_theta = 0
		// Create slice of param values (exclude uncertainties)
		duplicate /o /RMD=[i][0, num_params - 1] params param_slice
		wavestats /Q param_slice
		
		// assuming theta is index 2
		if (zap_bad_mids == 1)
			theta = param_slice[2]
			if (abs(theta) > 600) // hard coded theta cutoff off of > 1000
				is_bad_mid = 1
			endif
		endif
		
		// assuming mid is index 3
		if (zap_bad_mids == 1)
			mid = param_slice[3]
			if ((mid < scan_mid - (scan_width*mid_percentage_within*2)) || (mid > scan_mid + (scan_width*mid_percentage_within*2)))
				is_bad_theta = 1
			endif
		endif
		
		// if NaN or INF in params then delete row from data and param values	
		if ((V_numNans > 0) || (V_numINFs > 0) || (is_bad_mid == 1) || (is_bad_theta == 1))
			DeletePoints/M=1 (i - num_bad_rows), 1, wave_2d_new // delete row
			DeletePoints/M=0 (i - num_bad_rows), 1, params_new  // delete row
			num_bad_rows += 1
		endif
		
	endfor
	
	// overwrite input waves 
	if (overwrite == 1)
		duplicate /o wave_2d_new $wave_2d_name
		duplicate /o params_new $params_name
		killwaves wave_2d_new, params_new
	endif
	
end

function /wave fit_transition(current_array, minx, maxx, [fit_width])
	// fits the current_array, If condition is 0 it will get initial params, If 1:
	// define a variable named W_coef_guess = {} with the correct number of arguments
	// outputs wave named "fit_" + current_array
	wave current_array
	variable minx, maxx
	// optional param
	variable fit_width
	fit_width = paramisdefault(fit_width) ? inf : fit_width // averaging ON is default
	
	// update the minx and maxx based on the mid value and fit_width 
	wave W_coef
	variable mid, startx, endx
	if (fit_width != inf)
		mid = W_coef[3]
		startx = mid - fit_width
		endx = mid + fit_width
		
		minx = x2pnt(current_array, startx)
		maxx = x2pnt(current_array, endx)
	endif
	
	FuncFit/q /TBOX=768 ct_fit_function W_coef current_array[minx,maxx][0] /D
end




function /wave get_fit_params(wavenm, fit_params_name, minx, maxx, [fit_width])
	// returns wave with the name wave "dat"+ wavenum +"_cs_fit_params" eg. dat3320fit_params
	// wavenm: The input wave
    // fit_params_name: The name of the output wave (fit params)
    // minx: The minimum x value (as an index) for fitting
    // maxx: The maximum x value (as an index) for fitting
    // fit_width: Optional parameter for fit width (default is infinity)
	wave wavenm
	string fit_params_name
	variable minx, maxx
	variable fit_width
	
	fit_width = paramisdefault(fit_width) ? inf : fit_width // averaging ON is default
	
	// Define variables
	variable i
	string w2d = nameofwave(wavenm)
	int wavenum = getfirstnum(w2d)
	int nc
	int nr
	wave W_coef
	wave W_sigma

	// Get dimensions of input wave
	nr = dimsize(wavenm, 0) //number of rows (total sweeps)
	nc = dimsize(wavenm, 1) //number of columns (data points)
	
	// Create output wave
	make /N= (nc , 12) /o $fit_params_name
	wave fit_params = $fit_params_name

	// Duplicate input wave
	duplicate/o /R=[][0] wavenm temp_wave
	wave temp_wave
	
	for (i=0; i < nc ; i+=1)
		temp_wave = wavenm[p][i]
		wave W_coef = get_initial_params(temp_wave, update_amp_only = 1, update_theta_only = 1, update_mid_only = 1)
		fit_transition(temp_wave, minx, maxx, fit_width = fit_width)
		fit_params[1 * i][,5] = W_coef[q]
		fit_params[1 * i][6,] = W_sigma[q-6]
	endfor

	return fit_params

end


function plot_thetas(int wavenum, variable N, string fit_params_name)
	//If condition is 0 it will get initial params, If 1:
	// define a variable named W_coef_guess = {} with the correct number of arguments
	variable thetamean
	variable thetastd
	variable i
	int nr

	wave fit_params = $fit_params_name
	nr = dimsize(fit_params, 0)

	duplicate /O/R =[0, nr][2] fit_params thetas

	thetamean = mean(thetas)
	thetastd = sqrt(variance(thetas))

	make /o/n =(nr) meanwave
	make /o/n =(nr) stdwave
	make /o/n =(nr) stdwave2
	make /o/n = 0 goodthetas
	make /o/n = 0 goodthetasx
	make /o/n = 0 badthetas
	make /o/n = 0 badthetasx

	meanwave = thetamean
	stdwave = thetamean - N * thetastd
	stdwave2 = thetamean + N * thetastd


	for (i=0; i < nr ; i+=1)

		if (abs(thetas[i] - thetamean) < (N * thetastd))

			insertPoints /v = (thetas[i]) nr, 1, goodthetas // value of theta
			insertpoints /v = (i) nr, 1, goodthetasx        // the repeat

		else

			insertPoints /v = (thetas[i]) nr, 1, badthetas // value of theta
			insertpoints /v = (i) nr, 1, badthetasx        // repeat

		endif

	endfor

	display meanwave, stdwave, stdwave2
	appendtograph goodthetas vs goodthetasx
	appendtograph badthetas vs badthetasx

	ModifyGraph fSize=24
	ModifyGraph gFont="Gill Sans Light"
	ModifyGraph lstyle(meanwave)=3,rgb(meanwave)=(17476,17476,17476)
	ModifyGraph lstyle(stdwave)=3,rgb(stdwave)=(52428,1,1)
	ModifyGraph lstyle(stdwave2)=3,rgb(stdwave2)=(52428,1,1)
	ModifyGraph mode(goodthetas)=3,lsize(goodthetas)=2, rgb(goodthetas)=(2,39321,1)
	ModifyGraph mode(badthetas)=3
	Legend/C/N=text0/J/A=RT "\\s(meanwave) mean\r\\s(stdwave) 2*std\r\\s(goodthetas) good\r\\s(badthetas) outliers"
	TextBox/C/N=text1/A=MT/E=2 "\\Z14\\Z16 thetas of dat" + num2str(wavenum)

	Label bottom "Theta"

end



function plot_badthetas(wave wavenm)
	int i
	int nr
	wave badthetasx
	string dataset = nameofwave(wavenm)

	duplicate /o wavenm, wavenmcopy
	
	nr = dimsize(badthetasx,0)
	display
	
	if (nr>0)
		for(i=0; i < nr; i +=1)
			appendtograph wavenmcopy[][badthetasx[i]]
	
		endfor
	
		QuickColorSpectrum2()
	
		ModifyGraph fSize=24
		ModifyGraph gFont="Gill Sans Light"
		Label bottom "Gate (mV)"
		Label left "Current (nA)"
		TextBox/C/N=text1/A=MT/E=2 "\\Z14\\Z16 bad thetas of " + dataset
	endif
end



function /wave remove_bad_thetas(wave center, wave badthetasx, string cleaned_wave_name)
	// takes a wave 'center' and 'cleans' it based on 'badthetasx'
	// any row with a 'badgammax' will be removed from the 2d wave center
	string w2d = nameofwave(center)
	duplicate/o center $cleaned_wave_name

	// removing lines with bad thetas;
	variable i, idx
	int nc
	int nr
	nr = dimsize(badthetasx,0) //number of rows
	i=0
	if (nr>0)
		do
			idx=badthetasx[i]-i //when deleting, I need the -i because if deleting in the loop the indeces of center change continously as points are deleted
			DeletePoints/M=1 idx,1, $cleaned_wave_name
			i=i+1
		while (i<nr)
	endif
end


function plot_ct_figs(variable wavenum, variable N, string kenner, string kenner_out, variable minx, variable maxx, [variable fit_width])
	string datasetname ="dat" + num2str(wavenum) + kenner // this was the original dataset name
	string centered_wave_name = kenner_out + num2str(wavenum) + "_cs_centered" // this is the centered 2D wave
	string cleaned_wave_name = kenner_out + num2str(wavenum) + "_cs_cleaned" // this is the centered 2D wave after removing outliers ("cleaning")
	string avg_wave_name = cleaned_wave_name + "_avg" // this is the averaged wave produced by avg_wave($cleaned)
	
	fit_width = paramisdefault(fit_width) ? inf : fit_width // averaging ON is default
	
	string fit_params_name = kenner_out + num2str(wavenum) + "_cs_fit_params" // this is the fit parameters 
	string quickavg = datasetname + "_avg" // this is the wave produced by avg_wave($datasetname)
	wave W_coef


	/////////////////// plot quick avg fig  //////////////////////////////////////
	string quick_fit_name = "fit_" + quickavg 
	
	display $quickavg
	fit_transition($quickavg, minx, maxx, fit_width = fit_width)
	
	Label bottom "Gate (mV)"
	Label left "Current (nA)"
	ModifyGraph fSize=24
	ModifyGraph gFont="Gill Sans Light"
	ModifyGraph mode($quick_fit_name)=0,lsize($quick_fit_name)=1,rgb($quick_fit_name)=(65535,0,0)
	ModifyGraph mode($quickavg)=2,lsize($quickavg)=2,rgb($quickavg)=(0,0,0)
	legend
	Legend/C/N=text0/J/A=LB/X=59.50/Y=53.03


	/////////////////// plot thetas  //////////////////////////////////////


	//plot_thetas(wavenum,N,fit_params_name)
	//plot_badthetas($datasetname) // thetas vs repeat plot and bad theta sweep plot
	plot2d_heatmap($datasetname)
	plot2d_heatmap($cleaned_wave_name)
	plot2d_heatmap($centered_wave_name)



	/////////////////// plot avg fit  //////////////////////////////////////
	string fit_name = "fit_" + avg_wave_name
	
	display $avg_wave_name
	fit_transition($avg_wave_name, minx, maxx, fit_width = fit_width)
	
	Label bottom "Gate (mV)"
	Label left "Current (nA)"
	ModifyGraph fSize=24
	ModifyGraph gFont="Gill Sans Light"
	ModifyGraph mode($fit_name)=0, lsize($fit_name)=1, rgb($fit_name)=(65535,0,0)
	ModifyGraph mode($avg_wave_name)=2, lsize($avg_wave_name)=2, rgb($avg_wave_name)=(0,0,0)
	legend

	TileWindows/O=1/C/P
	Legend/C/N=text0/J/A=LB/X=59.50/Y=53.03

end



Function ct_fit_function(w,ys,xs) : FitFunc
	Wave w, xs, ys
	// f(x) = Amp*tanh((x - Mid)/(2*theta)) + Linear*x + Const+Quad*x^2
	// w[0] = Amp
	// w[1] = Const
	// w[2] = Theta
	// w[3] = Mid
	// w[4] = Linear
	// w[5] = Quad

	ys= w[0] * tanh((xs - w[3])/(-2 * w[2])) + w[4]*xs + w[1] + w(5)*xs^2
End



//////////////////////
///// DEPRECATED /////
//////////////////////
/////////////////////////////////////////////////////////
///// Using fit_single_peak() in favour of the below/////
/////////////////////////////////////////////////////////
//Function Chargetransition(w,x) : FitFunc
//	Wave w
//	Variable x
//
//	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
//	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
//	//CurveFitDialog/ Equation:
//	//CurveFitDialog/ f(x) = Amp*tanh((x - Mid)/(2*theta)) + Linear*x + Const
//
//	//CurveFitDialog/ End of Equation
//	//CurveFitDialog/ Independent Variables 1
//	//CurveFitDialog/ x
//	//CurveFitDialog/ Coefficients 5
//	//CurveFitDialog/ w[0] = Amp
//	//CurveFitDialog/ w[1] = Const
//	//CurveFitDialog/ w[2] = Theta
//	//CurveFitDialog/ w[3] = Mid
//	//CurveFitDialog/ w[4] = Linear
//
//
//	return w[0]*tanh((x - w[3])/(2*w[2])) + w[4]*x + w[1]
//End


//
//Function CT2(w,x) : FitFunc
//	Wave w
//	Variable x
//
//	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
//	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
//	//CurveFitDialog/ Equation:
//	//CurveFitDialog/ f(x) = Amp*tanh((x - Mid)/(2*theta)) + Linear*x + Const+Quad*x^2
//	//CurveFitDialog/ End of Equation
//	//CurveFitDialog/ Independent Variables 1
//	//CurveFitDialog/ x
//	//CurveFitDialog/ Coefficients 6
//	//CurveFitDialog/ w[0] = Amp
//	//CurveFitDialog/ w[1] = Const
//	//CurveFitDialog/ w[2] = Theta
//	//CurveFitDialog/ w[3] = Mid
//	//CurveFitDialog/ w[4] = Linear
//	//CurveFitDialog/ w[5] = Quad
//
//
//	return w[0]*tanh(-(x - w[3])/(2*w[2])) + w[4]*x + w[1]+w[5]*x^2
//End



//function dotcond_centering(wave waved, string kenner_out)
//	string w2d = nameofwave(waved)
//	int wavenum = getfirstnum(w2d)
//	string centered = kenner_out + num2str(wavenum) + "_cs_centered"
//	string fit_params_name = kenner_out + num2str(wavenum) + "_dot_fit_params"
//	wave fit_params = $fit_params_name
//	wave new2dwave = $centered
//	copyscales waved new2dwave
//	new2dwave=interp2d(waved,(x+fit_params[q][2]),(y)) // column 3 is the center fit parameter
//End

