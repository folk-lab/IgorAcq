#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3			// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#include <Reduce Matrix Size>

function dotcond_avg(wave wav, int refit,string kenner_out)
// wav is the wave containing original dotcurrent data
	// refit tells whether to do new fits to each CT line
	// kenner_out is the prefix to replace dat for this analysis
	// kenner_out  can not contain a number otherwise getfirstnu will not work

	variable refnum, ms
		//stopalltimers()
	refnum=startmstimer

	closeallGraphs()

	string datasetname =nameofwave(wav)
	string kenner=getsuffix(datasetname) //  cscurrent in the above case
	int wavenum=getfirstnum(datasetname) // XXX in the above case
	
	// these are the new wave names to be made
	string avg = kenner_out + num2str(wavenum) + "avg"
	string cond_centr=kenner_out+num2str(wavenum)+"centered"
	string cleaned=kenner_out+num2str(wavenum)+"cleaned"

	string split_pos=cleaned+"_pos"
	string split_neg=cleaned+"_neg"
	string pos_avg=split_pos+"_avg"
	string neg_avg=split_neg+"_avg"
	string fit_params_name = kenner_out+num2str(wavenum)+"fit_params"
	variable N
	N=40// how many sdevs in thetas are acceptable?



	if (refit==1)
		cond_fit_params($datasetname,kenner_out)// finds fit_params
		find_plot_gammas(fit_params_name,N) //need to do this to refind good and bad gammas
		duplicate/o/r=[][2] $fit_params_name mids
		centering($datasetname,cond_centr,mids)// only need to center after redoing fits, centred plot; returns cond_centr
		dotcleaned($cond_centr,kenner_out) // only need to clean after redoing fits; returns cond_centr
	endif


	split_wave( $cleaned,  0) //makes condxxxxcentered
	avg_wav($split_pos) // pos average
	avg_wav($split_neg) // neg average
	calc_avg_cond($pos_avg,$neg_avg,avg) // condxxxxavg
	dotfigs(wavenum,N,kenner, kenner_out)
//ctrans_avg(wavenum, 1,dotcondcentering=1)
	ms=stopmstimer(refnum)
	print ms/1e6
end


function/wave split_wave(wave wav, variable flag)
	wave kenner
	redimension/n=-1 kenner
	Duplicate/o kenner,idx
	idx = kenner[p] > flag ? p : NaN
	WaveTransform zapnans idx

	string wn=nameofwave(wav)
	string newname =wn+"_pos"
	variable	nr = dimsize(wav,0) //number of rows (sweep length)

	duplicate/o wav $newname
	wave out_wav = $newname
	Redimension/E=1/N=(-1,dimsize(idx,0)) out_wav

	variable i=0
	do
		out_wav[][i]=wav[p][idx[i]]

		i=i+1

	while(i<dimsize(idx,0))


	//now look for negative values
	Duplicate/o kenner,idx
	idx = kenner[p][q] < flag ? p : NaN
	WaveTransform zapnans idx

	string newname1 =wn+"_neg"
	duplicate/o wav $newname1
	wave out_wav1 = $newname1
	Redimension/E=1/N=(-1,dimsize(idx,0)) out_wav1

	i=0
	wave out_wav1 = $newname1
	do
		out_wav1[][i]=wav[p][idx[i]]
		i=i+1
	while(i<dimsize(idx,0))
end


//what does this mean in Igor pro: [p][q] > flag ? p : NaN
//In Igor Pro, the expression "[p][q] > flag ? p : NaN" is a conditional statement that checks if the value of the two-dimensional array element located at [p][q] is greater than the value of the variable "flag".
//If the condition is true, the statement returns the value of "p". If the condition is false, the statement returns "NaN", which stands for "Not a Number" and is used to represent undefined or unrepresentable numerical values.


//function /wave avg_wav(wave wav) // /WAVE lets your return a wave
//
//	//  averaging any wave over columns (in y direction)
//	// wave returned is avg_name
//	string wn=nameofwave(wav)
//	string avg_name=wn+"_avg";
//	int nc
//	int nr
//
////	wn="dat"+num2str(wavenum)+dataset //current 2d array
//
//	nr = dimsize($wn,0) //number of rows (sweep length)
//	nc = dimsize($wn,1) //number of columns (repeats)
//	ReduceMatrixSize(wav, 0, -1, nr, 0,-1, 1,1, avg_name)
//	redimension/n=-1 $avg_name
//end





function find_plot_gammas(string fit_params_name, variable N)

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


	//display gammas, meanwave, stdwave, stdwave2


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
	//	ModifyGraph width={Aspect,1.62},height=300
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
	string w2d
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
	//    ModifyGraph width={Aspect,1.62},height=300
	Label bottom "voltage"
	Label left dataset
	TextBox/C/N=text1/A=MT/E=2 "bad gammas of "+dataset
endif
end





//function dotcentering(wave waved)
//	string w2d=nameofwave(waved)
//	int wavenum=getfirstnum(w2d)
//	string fit_params_name = "cond"+num2str(wavenum)+"fit_params"
//	string centered = "cond"+num2str(wavenum)+"centered"
//	wave fit_params = $fit_params_name
//
//	wave new2dwave=$centered
//	copyscales waved new2dwave
//	new2dwave=interp2d(waved,(x+fit_params[q][2]),(y)) // column 3 is the center fit parameter
//end


end


function /wave dotcleaned(wave center,string kenner_out)
	wave badgammasx
	string w2d=nameofwave(center)
	int wavenum=getfirstnum(w2d)
	string cleaned=kenner_out+num2str(wavenum)+"cleaned"
	duplicate/o center $cleaned


	// removing lines with bad thetas;

	variable i, idx
	int nc
	int nr
	nr = dimsize(badgammasx,0) //number of rows
	i=0
	if (nr>0)
		do
			idx=badgammasx[i]-i //when deleting, I need the -i because if deleting in the loop the indeces of center change continously as points are deleted
			DeletePoints/M=1 idx,1, $cleaned
			//idx=badgammasx[i];center[][idx]=nan
			i=i+1
		while (i<nr)
	endif


	return center



end



function/wave calc_avg_cond(wave pos, wave neg, string newname)
	duplicate/o pos, $newname
	wave temp=$newname;
	temp=(pos-neg)
	variable bias=(514.95-495.05)/9950000; // divider is 9950 and 1000 is for V instead of mV
	//bias=fd_getbiasV(wavenum)/1000; print bias
	//interlaced_channels	:	OHV*9950
	//interlaced_setpoints	:	514.950,495.050
	duplicate/o temp cond
	temp=(bias/temp)*1e9-21150;
	temp=1/temp/7.7483e-05

	//21150 Ohms of inline R
	// Go=2e2/h=7.7483e-05
end

function /wave fit_peak(wave current_array)
	//	// fits the current_array, If condition is 0 it will get initial params, If 1:
	//	// define a variable named W_coef_guess = {} with the correct number of arguments
	redimension/n=-1 current_array
	duplicate/o current_array temp
	temp=abs(current_array)
	make/o/n=4 W_coef
	wavestats/q temp
	CurveFit/q lor current_array[round(V_maxrowloc-V_npnts/20),round(V_maxrowloc+V_npnts/20)] /D
	
	
end



//function chargetransition_procedure2m(int wavenum, int condition)
//
//	chargetransition_procedure2(wavenum, condition)
//	MultiGraphLayout(WinList("*", ";", "WIN:1"), 3, 20, "AllGraphLayout")
//
//end


//from: https://www.wavemetrics.com/forum/igor-pro-wish-list/automatically-color-traces-multi-trace-graph

//Function QuickColorSpectrum2()                            // colors traces with 12 different colors
//	String Traces    = TraceNameList("",";",1)               // get all the traces from the graph
//	Variable Items   = ItemsInList(Traces)                   // count the traces
//	Make/FREE/N=(11,3) colors = {{65280,0,0}, {65280,43520,0}, {0,65280,0}, {0,52224,0}, {0,65280,65280}, {0,43520,65280}, {0,15872,65280}, {65280,16384,55552}, {36864,14592,58880}, {0,0,0},{26112,26112,26112}}
//	Variable i
//	for (i = 0; i <DimSize(colors,1); i += 1)
//		ModifyGraph rgb($StringFromList(i,Traces))=(colors[0][i],colors[1][i],colors[2][i])      // set new color offset
//	endfor
//End

////from:
//// https://www.wavemetrics.com/code-snippet/stacked-plots-multiple-plots-layout
//
//function MultiGraphLayout(GraphList, nCols, spacing, layoutName)
//	string GraphList        // semicolon separated list of graphs to be appended to layout
//	variable nCols      // number of graph columns
//	string layoutName   // name of the layout
//	variable spacing        // spacing between graphs in points!
//
//	// how many graphs are there and how many rows are required
//	variable nGraphs = ItemsInList(GraphList)
//	variable nRows = ceil(nGraphs / nCols)
//	variable LayoutWidth, LayoutHeight
//	variable gWidth, gHeight
//	variable maxWidth = 0, maxHeight = 0
//	variable left, top
//	variable i, j, n = 0
//
//	string ThisGraph
//
//	// detect total layout size from individual graph sizes; get maximum graph size as column/row size
//	for(i=0; i<nGraphs; i+=1)
//
//		ThisGraph = StringFromList(i, GraphList)
//		GetWindow $ThisGraph gsize
//		gWidth = (V_right - V_left)
//		gHeight = (V_bottom - V_top)
//
//		// update maximum
//		maxWidth = gWidth > maxWidth ? gWidth : maxWidth
//		maxHeight = gHeight > maxHeight ? gHeight : maxHeight
//	endfor
//
//	// calculate layout size
//	LayoutWidth = maxWidth * nCols + ((nCols + 1) * spacing)
//	LayoutHeight = maxHeight * nRows + ((nRows +1) * spacing)
//
//	// make layout; kill if it exists
//	DoWindow $layoutName
//	if(V_flag)
//		KillWindow $layoutName
//	endif
//
//	NewLayout/N=$layoutName/K=1/W=(517,55,1451,800)
//	LayoutPageAction size=(LayoutWidth, LayoutHeight), margins=(0,0,0,0)
//	ModifyLayout mag=0.75
//
//	//append graphs
//	top = spacing
//	for(i=0; i<nRows; i+=1)
//
//		// reset vertical position for each column
//		left = spacing
//
//		for (j=0; j<    nCols; j+=1)
//
//			ThisGraph = StringFromList(n, GraphList)
//			if(strlen(ThisGraph) == 0)
//				return 0
//			endif
//
//			GetWindow $ThisGraph gsize
//			gWidth = (V_right - V_left)
//			gHeight = (V_bottom - V_top)
//
//			AppendLayoutObject/F=0 /D=1 /R=(left, top, (left + gWidth), (top + gHeight)) graph $ThisGraph
//
//			// shift next starting positions to the right
//			left += maxWidth + spacing
//
//			// increase plot counter
//			n += 1
//		endfor
//
//		// shift next starting positions dwon
//		top += maxHeight + spacing
//	endfor
//
//	return 1
//end
//
//
//
//// https://www.wavemetrics.com/code-snippet/stacked-plots-multiple-plots-graph








/////// Dealing Interlacing ////////



// improvements on this function
//			let it take an argument of names for all the waves created


//     		an option or a new function all together that seperates the waves by grouping
//									i.e grouping x number of rows in a m by n matrix creating
//                                      a total of m/x waves, also takes an argument for naming?
//          it could group based on amount of splits e.g split 2D wave into 4
//          it could group based on number of rows indicated.





function /wave cond_fit_params(wave wav, string kenner_out)
	string w2d=nameofwave(wav)
	int wavenum=getfirstnum(w2d)
	string fit_params_name = kenner_out+num2str(wavenum)+"fit_params" //new array


	variable i
	string wavg
	int nc
	int nr
	wave fit_params
	wave W_coef
	wave W_sigma

	nr = dimsize(wav,0) //number of rows (total sweeps)
	nc = dimsize(wav,1) //number of columns (data points)
	make/o /N=(nr) temp_wave
	CopyScales wav, temp_wave
	//setscale/I x new_x[0] , new_x[dimsize(new_x,0) - 1], "", temp_wave

	make/o /N= (nc , 8) /o $fit_params_name
	wave fit_params = $fit_params_name


	for (i=0; i < nc ; i+=1) //nc
		temp_wave = wav[p][i]	;	redimension/n=-1 temp_wave

		fit_peak(temp_wave)
		fit_params[i][0,3] = W_coef[q]
		fit_params[i][4] = W_sigma[0]
		fit_params[i][5] = W_sigma[1]
		fit_params[i][6] = W_sigma[2]
		fit_params[i][7] = W_sigma[3]


	endfor

	return fit_params

end

function dotfigs(variable wavenum,variable N,string kenner, string kenner_out)	
	string dataset="dat"+num2str(wavenum)+kenner
	string avg = kenner_out + num2str(wavenum) + "avg"
	string cond_centr=kenner_out+num2str(wavenum)+"centered"
	string cleaned=kenner_out+num2str(wavenum)+"cleaned"

	string split_pos=cleaned+"_pos"
	string split_neg=cleaned+"_neg"
	string pos_avg=split_pos+"_avg"
	string neg_avg=split_neg+"_avg"
	string fit_params_name = kenner_out+num2str(wavenum)+"fit_params" 
	closeallgraphs()

	/////////////////// thetas  //////////////////////////////////////


	find_plot_gammas(fit_params_name,N)
	plot2d_heatmap($split_pos);	plot2d_heatmap($split_neg)
	plot2d_heatmap($dataset);	plot2d_heatmap($cond_centr);plot2d_heatmap($cleaned)
	plot_badgammas($cond_centr)
	fit_peak($avg)


	//display $pos_avg, $neg_avg;
	display $avg;
	Label left "cond (2e^2/h)";DelayUpdate
	ModifyGraph log(left)=1,loglinear(left)=1
	Label bottom "gate (V)"

	TileWindows/O=1/C/P

end


function CBpeak(A,G,Vo,V)
	variable A,G,Vo,V
	variable cond

	cond=A*G/((V-Vo)^2+(G/2)^2);
	return cond
end

Function CBpeak_fit(w,V) : FitFunc
	Wave w
	Variable V

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(V) = CBpeak(A,G,Vo,V)
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ V
	//CurveFitDialog/ Coefficients 3
	//CurveFitDialog/ w[0] = A
	//CurveFitDialog/ w[1] = G
	//CurveFitDialog/ w[2] = Vo

	return CBpeak(w[0],w[1],w[2],V)
End

