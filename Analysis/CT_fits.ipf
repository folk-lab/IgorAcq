#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3			// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#include <Reduce Matrix Size>

function ctrans_avg(wave wav, int refit,int dotcondcentering, string kenner_out,[string condfit_prefix, variable minx, variable maxx])
	// wav is the wave containing original CT data
	// refit tells whether to do new fits to each CT line
	// dotcondcentering tells whether to use conductance data to center the CT data
	// kenner_out is the prefix to replace dat for this analysis
	// kenner_out and condfit_prefix can not contain a number otherwise getfirstnu will not work

	variable refnum, ms
	//	option to limit fit to indexes [minx,maxx]

		if (paramisdefault(minx))
			minx=0
		endif

		if (paramisdefault(maxx))
			maxx=dimsize(wav,0)-1
		endif
	

	
	//		stopalltimers() // run this line if timer returns nan

	refnum=startmstimer

	//closeallGraphs()
	string datasetname=nameofWave(wav) // typically datXXXcscurrent or similar
	string kenner=getsuffix(datasetname) //  cscurrent in the above case
	int wavenum=getfirstnum(datasetname) // XXX in the above case

	// these are the new wave names to be made
	string avg = kenner_out + num2str(wavenum) + "cleaned_avg"
	string centered=kenner_out+num2str(wavenum)+"centered"
	string cleaned=kenner_out+num2str(wavenum)+"cleaned"
	string fit_params_name = kenner_out+num2str(wavenum)+"fit_params"
	wave fit_params = $fit_params_name
	

	variable N=20; // how many sdevs are acceptable?


	wave W_coef
	wave badthetasx
	wave badgammasx

	//remove_noise($datasetname);


	//resampleWave($datasetname,600);
	string quickavg=avg_wav($datasetname) // averages datasetname and returns the name of the averaged wave

	if (refit==1)
		//get_initial_params($quickavg);// print W_coef
		fit_transition($quickavg,minx,maxx);// print W_coef
		
		get_fit_params($datasetname,fit_params_name,minx,maxx) //
	endif
closeallGraphs()

	if (dotcondcentering==0)
	find_plot_thetas(wavenum,N,fit_params_name)

		duplicate/o/r=[][3] $fit_params_name mids
		centering($datasetname,centered,mids) // centred plot and average plot
		cleaning($centered,badthetasx)

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

	avg_wav($cleaned) // quick average plot
	get_initial_params($quickavg); //print W_coef
	fit_transition($avg,minx,maxx)
	prepfigs(wavenum,N,kenner,kenner_out,minx,maxx)

	ms=stopmstimer(refnum)
	print ms/1e6
end





//what does this mean in Igor pro: [p][q] > flag ? p : NaN
//In Igor Pro, the expression "[p][q] > flag ? p : NaN" is a conditional statement that checks if the value of the two-dimensional array element located at [p][q] is greater than the value of the variable "flag".
//If the condition is true, the statement returns the value of "p". If the condition is false, the statement returns "NaN", which stands for "Not a Number" and is used to represent undefined or unrepresentable numerical values.

function /wave get_initial_params(sweep)

	// for a given sweep returns a guess of initial parameters for the fit function: Charge transiton

	wave sweep
	duplicate /o sweep x_array
	x_array = x

	variable amp = wavemax(sweep) - wavemin(sweep) //might be worthwile looking for a maximum/minimum with differentiation
	//variable amp = 0.001
	variable const = mean(sweep)
	variable theta = 50

	duplicate /o sweep sweepsmooth
	Smooth/S=4 201, sweepsmooth ;DelayUpdate

	differentiate sweepsmooth
	extract/INDX sweepsmooth, extractedwave, sweepsmooth == wavemin(sweepsmooth)
	variable mid = x_array[extractedwave[0]]

	//extract/INDX sweepsmooth, extractedwave, sweepsmooth == 0 //new
	//variable amp = sweep[extractedwave[0]] - sweep[extractedwave[1]] // new


	variable lin = 0.001  // differentiated value of flat area?

	Make /D/N=6/O W_coef
	W_coef[0] = {amp,const,theta,mid,lin,0}

	killwaves extractedwave, sweepsmooth
	return W_coef

end




function /wave fit_transition(current_array,minx,maxx)
	// fits the current_array, If condition is 0 it will get initial params, If 1:
	// define a variable named W_coef_guess = {} with the correct number of arguments


	wave current_array
	variable minx,maxx


	wave W_coef

	//duplicate /o current_array x_array
	//x_array = x
	//FuncFit/q Chargetransition W_coef current_array[][0] /D   //removed the x_array
	//	FuncFit/q CT_faster W_coef current_array[][0] /D    //removed the x_array
	
	FuncFit/q /TBOX=768 CT_faster W_coef current_array[minx,maxx][0] /D
end




function /wave get_fit_params(wave wavenm, string fit_params_name,variable minx, variable maxx)
	// returns wave with the name wave "dat"+ wavenum +"fit_params" eg. dat3320fit_params

	//If condition is 0 it will get initial params, If 1:
	// define a variable named W_coef_guess = {} with the correct number of arguments


	variable i
	string w2d=nameofwave(wavenm)
	int wavenum=getfirstnum(w2d)
	int nc
	int nr
	wave temp_wave
	wave W_coef
	wave W_sigma



	nr = dimsize(wavenm,0) //number of rows (total sweeps)
	nc = dimsize(wavenm,1) //number of columns (data points)
	make /N= (nc , 12) /o $fit_params_name
	wave fit_params = $fit_params_name
	print W_coef

	duplicate/o wavenm temp_wave
	for (i=0; i < nc ; i+=1)

		temp_wave = wavenm[p][i]
		fit_transition(temp_wave,minx,maxx)
		fit_params[1 * i][,5] = W_coef[q]
		fit_params[1 * i][6,] = W_sigma[q-6]         //I genuinely cant believe this worked
		// i dont think the q-5 does anything, should double check
	endfor

	return fit_params

end


function find_plot_thetas(int wavenum,variable N,string fit_params_name)

	//If condition is 0 it will get initial params, If 1:
	// define a variable named W_coef_guess = {} with the correct number of arguments

//	string fit_params_name =kenner_out+num2str(wavenum)+"fit_params"
	variable thetamean
	variable thetastd
	variable i
	int nr
	//variable N //how many sdevs?



	wave fit_params = $fit_params_name
	nr = dimsize(fit_params,0)

	duplicate /O/R =[0,nr][2] fit_params thetas


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


	//display thetas, meanwave, stdwave, stdwave2


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
	//	ModifyGraph width={Aspect,1.62},height=300
	ModifyGraph lstyle(meanwave)=3,rgb(meanwave)=(17476,17476,17476)
	ModifyGraph lstyle(stdwave)=3,rgb(stdwave)=(52428,1,1)
	ModifyGraph lstyle(stdwave2)=3,rgb(stdwave2)=(52428,1,1)
	ModifyGraph mode(goodthetas)=3,lsize(goodthetas)=2, rgb(goodthetas)=(2,39321,1)
	ModifyGraph mode(badthetas)=3
	Legend/C/N=text0/J/A=RT "\\s(meanwave) mean\r\\s(stdwave) 2*std\r\\s(goodthetas) good\r\\s(badthetas) outliers"
	TextBox/C/N=text1/A=MT/E=2 "\\Z14\\Z16 thetas of dat" + num2str(wavenum)



	Label bottom "repeat"
	Label left "theta values"




end


function plot_badthetas(wave wavenm)

	int i
	int nr
	wave badthetasx
	string w2d=nameofwave(wavenm)

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
	//    ModifyGraph width={Aspect,1.62},height=300
	Label bottom "voltage"
	Label left "current"
	TextBox/C/N=text1/A=MT/E=2 "\\Z14\\Z16 bad thetas of " +w2d
endif
end



function /wave cleaning(wave center, wave badthetasx)
	string w2d=nameofwave(center)
	int wavenum=getfirstnum(w2d)
	string cleaned=getprefix(w2d)+num2str(wavenum)+"cleaned"
	duplicate/o center $cleaned


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
end


function prepfigs(wavenum,N,kenner, kenner_out, minx, maxx)
	variable wavenum,N
	string kenner, kenner_out
	variable minx, maxx
	string datasetname ="dat"+num2str(wavenum)+kenner // this was the original dataset name
	string avg = kenner_out + num2str(wavenum) + "cleaned_avg" // this is the averaged wave produced by avg_wave($cleaned)
	string centered=kenner_out+num2str(wavenum)+"centered" // this is the centered 2D wave
	string cleaned=kenner_out+num2str(wavenum)+"cleaned" // this is the centered 2D wave after removing outliers ("cleaning")
	string fit_params_name = kenner_out+num2str(wavenum)+"fit_params" // this is the fit parameters 
	string quickavg = datasetname+"_avg" // this is the wave produced by avg_wave($datasetname)
	wave W_coef


	/////////////////// quick avg fig  //////////////////////////////////////

	string fit_name = "fit_"+quickavg

	display $quickavg
	fit_transition($quickavg,minx,maxx)
	Label bottom "gate V"
	Label left "csurrent"
	ModifyGraph fSize=24
	ModifyGraph gFont="Gill Sans Light"
	ModifyGraph mode($fit_name)=0,lsize($fit_name)=1,rgb($fit_name)=(65535,0,0)
	ModifyGraph mode($quickavg)=2,lsize($quickavg)=2,rgb($quickavg)=(0,0,0)
	legend
	Legend/C/N=text0/J/A=LB/X=59.50/Y=53.03


	/////////////////// thetas  //////////////////////////////////////


	//find_plot_thetas(wavenum,N,fit_params_name)
	//plot_badthetas($datasetname) // thetas vs repeat plot and bad theta sweep plot
	plot2d_heatmap($datasetname)
	plot2d_heatmap($cleaned)
	plot2d_heatmap($centered)



	/////////////////// plot avg fit  //////////////////////////////////////

	string fit = "fit_cst"+num2str(wavenum)+"cleaned_avg" //new array

	display $avg; W_coef[3]=0
	fit_transition($avg,minx,maxx)

	Label bottom "gate V"
	Label left "csurrent"
	ModifyGraph fSize=24
	ModifyGraph gFont="Gill Sans Light"
	ModifyGraph mode($fit)=0,lsize($fit)=1,rgb($fit)=(65535,0,0)
	ModifyGraph mode($avg)=2,lsize($avg)=2,rgb($avg)=(0,0,0)
	legend

	TileWindows/O=1/C/P
	Legend/C/N=text0/J/A=LB/X=59.50/Y=53.03


	//MultiGraphLayout(WinList("*", ";", "WIN:1"), 3, 20, "AllGraphLayout");


end

Function Chargetransition(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = Amp*tanh((x - Mid)/(2*theta)) + Linear*x + Const

	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 5
	//CurveFitDialog/ w[0] = Amp
	//CurveFitDialog/ w[1] = Const
	//CurveFitDialog/ w[2] = Theta
	//CurveFitDialog/ w[3] = Mid
	//CurveFitDialog/ w[4] = Linear


	return w[0]*tanh((x - w[3])/(2*w[2])) + w[4]*x + w[1]
End

Function CT_faster(w,ys,xs) : FitFunc
	Wave w, xs, ys
	ys= w[0]*tanh((xs - w[3])/(-2*w[2])) + w[4]*xs + w[1]+w(5)*xs^2
End

Function CT2(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = Amp*tanh((x - Mid)/(2*theta)) + Linear*x + Const+Quad*x^2
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 6
	//CurveFitDialog/ w[0] = Amp
	//CurveFitDialog/ w[1] = Const
	//CurveFitDialog/ w[2] = Theta
	//CurveFitDialog/ w[3] = Mid
	//CurveFitDialog/ w[4] = Linear
	//CurveFitDialog/ w[5] = Quad


	return w[0]*tanh(-(x - w[3])/(2*w[2])) + w[4]*x + w[1]+w[5]*x^2
End



function dotcond_centering(wave waved, string kenner_out)
	string w2d=nameofwave(waved)
	int wavenum=getfirstnum(w2d)
	string centered=kenner_out+num2str(wavenum)+"centered"
	string fit_params_name = "cond"+num2str(wavenum)+"fit_params"
	wave fit_params = $fit_params_name
	wave new2dwave=$centered
	copyscales waved new2dwave
	new2dwave=interp2d(waved,(x+fit_params[q][2]),(y)) // column 3 is the center fit parameter
End
