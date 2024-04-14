#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#include <Color Table Control Panel>
#include <Waves Average>

//NewPath/O data "D:local_measurement_data:Silvia:noise:"
////  path: "D:local_measurement_data:Silvia:SCdiodes:"
//initscancontroller()
//listserialports()
//listgPIBinstr()
////
////openFastDACconnection("fd","ASRL5::INSTR", numDACCh = 8, numADCCh = 4, master = 1, optical = 1)
////openSRSconnection("srs", "GPIB0::1::INSTR", verbose=1)
////openk2400connection("k2400", "GPIB0::4::INSTR", verbose=1)
////
//print getfdstatus(fd)
////getsrsstatus(srs)
////getk2400status(k2400)
////
//NewPath/O server "\\\\master.qdev-h101.lab\\measurement-data:"
////
//initfastDAC()
////click at least one ADC to record
//scanfastDAC(fd,-100,100,"0",sweeprate=100)
////filenum=4
//NewPath/O ntbkpath "C:Users:labuser:OneDrive:Documents:Silvia:"
//SaveNotebook/O/P=ntbkpath/S=5/H={"UTF-8",0,0,0,0,32} logging as "logging.html"
//
//SaveNotebook/O/P=data/S=5/H={"UTF-8",0,0,0,0,32} log180 as "log180.htm"
//SaveNotebook/O/P=data/S=7/H={"UTF-8",0,0,0,0,32} log180 as "log180.ifn"

//NewPath/O data "D:local_measurement_data:Silvia:noise:"
////  path: "D:local_measurement_data:Silvia:SCdiodes:"
//initscancontroller()
//listserialports()
//listgPIBinstr()
////
////openFastDACconnection("fd","ASRL5::INSTR", numDACCh = 8, numADCCh = 4, master = 1, optical = 1)
////openSRSconnection("srs", "GPIB0::1::INSTR", verbose=1)
////openk2400connection("k2400", "GPIB0::4::INSTR", verbose=1)
////
//print getfdstatus(fd)
////getsrsstatus(srs)
////getk2400status(k2400)
////
//NewPath/O server "\\\\master.qdev-h101.lab\\measurement-data:"
////
//initfastDAC()
////click at least one ADC to record
//scanfastDAC(fd,-100,100,"0",sweeprate=100)
////filenum=4


macro calc_res( volt_div)
variable volt_div
CurveFit/q/M=2/W=0 line, current/D
print 1e-3/W_coef[1]/1e-6/volt_div


print("in kOhms, if voltage is in mV and current in nA)")
endmacro

// FDSpectrumAnalyzer(fd, 1,numAverage=5);print sqrt(spectrum_fftADCint0(6000))*29e3*1e-9

//•setls370loggersSchedule(ls, "slow")
//•setls370loggersSchedule(ls, "fast")
//•openLS370connection("ls", "http://lksh370-xld.qdev-b111.lab:49300/api/v1/", "bfbig", verbose=1)
//  LS370 (http://lksh370-xld.qdev-b111.lab:49300/api/v1/) connected as ls
//•setls370loggersSchedule(ls, "fast")

Function AppendtoLog(str,toend)
	String str 
	int toend
	String nb="logging"							// name of the notebook to log to
						// the string to log
	Variable now
	String stamp
	if (toend==1)
	Notebook $nb selection={endOfFile, endOfFile} //only use if you want to append to end
	endif
		now = datetime
		stamp = Secs2Date(now,0) + ", " + Secs2Time(now,0) + "\r"
		Notebook $nb fsize=14,text=stamp
	
	Notebook $nb fsize=14,text= str+"\r"
	//Notebook $"logging" picture={Graph5(0,0,500,300), -5, 1}	
	Notebook $"logging" picture={$"", -5, 1}	
	Notebook $nb text= "\r\r"
	
End



Window template(datnum) : Graph
variable datnum
	PauseUpdate; Silent 1		// building window...
	Display /W=(729.75,87.5,1355.25,395)
	string name="dat"+num2str(datnum)+"dV_2d"
	AppendImage $name
	ModifyImage $name ctab= {*,*,VioletOrangeYellow,0}
	ModifyGraph mirror=0
	Label left "flux_bias (mV; 3kOhm inline)"
	Label bottom "current_bias (mV; 100KOhm inline)"
	ColorScale/C/N=VioletOrangeYellow/A=RC/E image=$name
	AppendText "dV (mV)"
	TextBox/C/N=datnum/A=LT/X=1.00/Y=1.00/E=2 name
EndMacro


function/wave deinterlace(wave wav, int start, string suffix,int N)
// N is 2 for conductance and N=4 for entropy (heater on and off)
	string w2d=nameofwave(wav)
	int wavenum=getfirstnum(w2d)
	string name=w2d+"_"+suffix
	
	
	variable nr, nc
	nr=dimsize(wav,0); //print nr
	nc=dimsize(wav,1);// print nc


//https://www.wavemetrics.com/forum/general/delete-points

duplicate/o wav junk   // make a fake data wave
Make/o/n=(nr,nc/N) $name
wave new2dwave=$name
CopyScales wav, new2dwave

new2dwave = junk[p][N*q+start]

// ReduceMatrixSize(wav, 0, -1, nr, 0, -1, nc/N, 0, name)
 return new2dwave
 end

function analyze(wave wav,int remov)
	variable datnum

	string name=nameofwave(wav)
	deinterlace(wav, 0,"up",2);	deinterlace(wav, 1,"dn",2)
	string name_up=name+"_up"
	string name_dn=name+"_dn"
	wave up=$name_up
	wave dn=$name_dn
	variable index=x2pnt(dn,0)
	if (remov==1)
	dn[index,inf][]=nan;
	up[0,index][]=nan;
	endif
	rescalex( up,0.001); 	rescaley(up,0.33333)
	rescalex( dn,0.001); 	rescaley(dn,0.33333)
	Display
	AppendImage up
	AppendImage dn
	ModifyImage $name_up ctab= {-11,11,RedWhiteBlue,0}
	ModifyImage $name_dn ctab= {-11,11,RedWhiteBlue,0}
	Label bottom "\\Z14 I \\B bias \\M(μA)"
	Label left "\\Z14 I \\B flux-bias \\M(μA)"
	TextBox/C/N=text0/A=LT/X=50.00/Y=0.00 name
end




function hysteresis(wave wav)

string name=nameofwave(wav)

analyze(wav,0)
	string name_up=name+"_up"
	string name_dn=name+"_dn"
	wave up=$name_up
	wave dn=$name_dn
display; linebyline(up,1)
execute("setparams_wide()")
modifygraph rgb=(0, 0, 0)
linebyline(dn,1)
	Label bottom "\\Z14 I \\B bias \\M(μA)"
	Label left "\\Z14 dV (mV)"
end


macro IC_speed_dep(sweeprate, bias,repeats)
variable numpts, bias,repeats, sweeprate

scanfastDAC(fd,-bias,bias,"0",sweeprate=300,repeats=repeats,alternate=1);
scanfastDAC(fd,-bias,bias,"0",sweeprate=400,repeats=repeats,alternate=1);
scanfastDAC(fd,-bias,bias,"0",sweeprate=500,repeats=repeats,alternate=1);
scanfastDAC(fd,-bias,bias,"0",sweeprate=750,repeats=repeats,alternate=1);
scanfastDAC(fd,-bias,bias,"0",sweeprate=1000,repeats=repeats,alternate=1);
scanfastDAC(fd,-bias,bias,"0",sweeprate=100,repeats=repeats,alternate=1);
scanfastDAC(fd,-bias,bias,"0",sweeprate=200,repeats=repeats,alternate=1);






endmacro

macro night()
variable speed=300
variable bias=1500
//WaitTillTempStable(ls370, 1800, 5, 30, 0.05)

scanfastDAC2D(fd,-bias,bias,"bias",-500,500,"flux_bias",201,sweeprate=speed,delayy=0.01,alternate=1, repeats=2);
RampMultipleFDAC(fd, "0,1", 0, ramprate=1000)
RampMultipleFDAC(fd, "1", 0, ramprate=1000)
scanfastDAC(fd,-bias,bias,"0",sweeprate=speed,alternate=1,repeats=50);
RampMultipleFDAC(fd, "0,1,2", 0, ramprate=1000)

//WaitTillTempStable(ls370, 400, 5, 30, 0.05)

//scanfastDAC2D(fd,-bias,bias,"bias",-500,500,"flux_bias",201,sweeprate=speed,delayy=0.01,alternate=1, repeats=2);
//RampMultipleFDAC(fd, "0,1", 0, ramprate=1000)
//RampMultipleFDAC(fd, "1", 0, ramprate=1000)
//scanfastDAC(fd,-bias,bias,"0",sweeprate=speed,alternate=1,repeats=50);
//RampMultipleFDAC(fd, "0,1,2", 0, ramprate=1000)
//
//WaitTillTempStable(ls370, 275, 5, 30, 0.05)
//
//scanfastDAC2D(fd,-bias,bias,"bias",-500,500,"flux_bias",201,sweeprate=speed,delayy=0.01,alternate=1, repeats=2);
//RampMultipleFDAC(fd, "0,1", 0, ramprate=1000)
//RampMultipleFDAC(fd, "1", 0, ramprate=1000)
//scanfastDAC(fd,-bias,bias,"0",sweeprate=speed,alternate=1,repeats=50);
//RampMultipleFDAC(fd, "0,1,2", 0, ramprate=1000)
//
//WaitTillTempStable(ls370, 90, 5, 30, 0.05)
//
//scanfastDAC2D(fd,-bias,bias,"bias",-500,500,"flux_bias",201,sweeprate=speed,delayy=0.01,alternate=1, repeats=2);
//RampMultipleFDAC(fd, "0,1", 0, ramprate=1000)
//RampMultipleFDAC(fd, "1", 0, ramprate=1000)
//scanfastDAC(fd,-bias,bias,"0",sweeprate=speed,alternate=1,repeats=50);
//RampMultipleFDAC(fd, "0,1,2", 0, ramprate=1000)
//
//WaitTillTempStable(ls370, 50, 5, 30, 0.05)
//
//scanfastDAC2D(fd,-bias,bias,"bias",-500,500,"flux_bias",201,sweeprate=speed,delayy=0.01,alternate=1, repeats=2);
//RampMultipleFDAC(fd, "0,1", 0, ramprate=1000)
//RampMultipleFDAC(fd, "1", 0, ramprate=1000)
//scanfastDAC(fd,-bias,bias,"0",sweeprate=speed,alternate=1,repeats=50);
//RampMultipleFDAC(fd, "0,1,2", 0, ramprate=1000)







//
//scanfastDAC2D(fd,-bias,bias,"bias",-500,500,"flux_bias",201,sweeprate=speed,delayy=0.01,alternate=1, repeats=2);
//RampMultipleFDAC(fd, "0,1", 0, ramprate=1000)
//RampMultipleFDAC(fd, "1", 0, ramprate=1000)
//scanfastDAC(fd,-bias,bias,"0",sweeprate=speed,alternate=1,repeats=50);
//RampMultipleFDAC(fd, "0,1,2", 0, ramprate=1000)

endmacro

macro doubleflux(sweeprate,bias,flux_start,flux_end,delta)
variable sweeprate,bias,flux_start, flux_end, delta
variable new_flux
new_flux=flux_start
do
RampMultipleFDAC(fd, "1", new_flux, ramprate=1000)
scanfastDAC2D(fd,-bias,bias,"0",800,-800,"flux_bias_closer",161,sweeprate=sweeprate,delayy=0.001,alternate=1,repeats=100);
new_flux=new_flux+delta; print new_flux

while(new_flux<=flux_end)
RampMultipleFDAC(fd, "0,1,2", 0, ramprate=1000)
endmacro

function displayVvsSC(start, endnum,whichdat[delta,shiftx, shifty])
	variable start, endnum
	string whichdat
	variable delta, shiftx, shifty
	
		string prefix="dat"

	if(paramisdefault(delta))
		delta=1
	endif
	if(delta==0)
		abort
	endif

	if(paramisdefault(shiftx))
		shiftx=0
	endif
	if(paramisdefault(shifty))
		shifty=0
	endif
		
	variable i=0, totoffx=0, totoffy=0
	string st, st1
	//udh5()
	Display /W=(0,0,500,300)
	i=start
	do
		st=prefix+num2str(i)+whichdat
		st1=prefix+num2str(i)+"current"

		appendtograph $st vs $st1
		ModifyGraph offset($st)={totoffx,totoffy}
		totoffx=totoffx+shiftx
		totoffy=totoffy+shifty
		i+=delta
	while (i<=endnum)
	makecolorful()
	legend
	Legend/C/N=text0/J/A=RC/E=0
	Label bottom "I\\Bbias \\M(uA)"
	Label left whichdat


end

//macro warmup()
//Ic_speed_dep(500);night();
//Ic_speed_dep(500);night();
//Ic_speed_dep(500);night();
//Ic_speed_dep(500);night();
//Ic_speed_dep(500);night();
//endmacro

