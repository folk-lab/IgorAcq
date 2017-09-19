#pragma rtGlobals=1		// Use modern global access method.

// Modified by Mark Lundeberg Nov-05-2008 - Added ReadSRSjunk
// Modified by Sergey Frolov Aug-08-2007 - Added SetSRSAmplitude, SetSRSFrequency
// Modified by Yuan Ren Jun-27-2008 - Added GetSRSSensitivity, SRSAutoSens, SRSAutoPhase, SRSSensUp, SRSSenDown, GetSRSFrequency
// Updated to NIGPIB2 by Nik -- May 16 2017

function InitSRS(srs)
	variable srs
	
	GPIB2 device = srs
	GPIBWrite2 "OUTX 1"
	GPIBWrite2 "OVRM 1"
	
	NI4882 ibtmo={srs, 1}
	
End

function SetSRSHarmonic(srs,harm)
	variable srs, harm
	
	GPIB2 device = srs
	GPIBWrite2 "HARM "+num2str(harm)
	
End

function GetSRSHarmonic(srs)
	Variable srs
	Variable readval
	GPIB2 device = srs
	GPIBWrite2 "HARM?"
	GPIBRead2/T="\n" readval
	return readval
End

function SetSRSTimeConst(srs, i)	
	// Set time constant
	// i=8, t=100ms; i=9 t=300ms
	variable srs, i
	
	GPIB2 device = srs
	GPIBWrite2 "OFLT "+num2str(i)
End

function GetSRSTimeConst(srs, [realtime])
	// use realtime=1 to return values in seconds
	Variable srs, realtime
	Variable readval
	
	GPIB2 device = srs
	GPIBWrite2 "OFLT?"
	GPIBRead2/T="\n" readval
	
	if (realtime == 0)
		return readval
	endif
	
	if (mod(readval, 2)==0)
		return 10^(readval/2-5)
	else
		return 3*10^((readval-1)/2-5)
	endif
	
End

function SetSRSPhase(srs,phase)
	Variable srs,phase
	GPIB2 device = srs
	GPIBWrite2 "PHAS "+num2str(phase)
End

function GetSRSPhase(srs)
	Variable srs
	Variable readval
	GPIB2 device = srs
	GPIBWrite2 "PHAS?"
	GPIBRead2/T="\n" readval
	return readval
End

function SetSRSAmplitude(srs,volts)
	Variable srs,volts
	
	if(volts<0.0)
		abort "are you trying to set the amplitude < 0?"
	elseif(volts<0.004)
		volts = 0.004
	endif
	
	GPIB2 device = srs
	GPIBWrite2 "SLVL "+num2str(volts)
End

       	
function GetSRSAmplitude(srs)
	Variable srs
	Variable readval
	GPIB2 device = srs
	GPIBWrite2 "SLVL?"
	GPIBRead2/T="\n" readval
	return readval
End

function SetSRSFrequency(srs,hertz)
	Variable srs,hertz
	GPIB2 device = srs
	GPIBWrite2 "FREQ "+num2str(hertz)
End

function GetSRSFrequency(srs)
	Variable srs
	Variable readval
	GPIB2 device = srs
	GPIBWrite2 "FREQ?"
	GPIBRead2/T="\n" readval
	return readval
End

// note, here you need to pass in an integer which maps to a full scale.
// see SetSRSSensitivityRange for an easier way
function SetSRSSensitivity(srs,sens)
//
	Variable srs,sens
	GPIB2 device = srs
	GPIBwrite2 "SENS " + num2str(sens)
	
End

// MBL Jan'12: like SetSRSSensitivity, but here you pass in the maximum expected lock-in signal.
//      signalmax has units of Volts, or Amps.
// This function will choose the lowest possible range that will not overload.
//  (note that the actual significands for overload on the SRS are: 1.0922, 2.184, 5.461,
//        but this function uses instead 1.05, 2.1, and 5.2 for safety margin.)
// Note that the maximum ranges are 1 volt (A or A-B) and 1 microamp (I measurement). If you request
//   larger than this, this function will set the maximum
function SetSRSSensitivityRange(srs,signalmax)
	Variable srs,signalmax
	
	signalmax = abs(signalmax)
	variable exponent = floor(log(signalmax))
	variable significand = signalmax/10^exponent
	variable choiceneg
	     // this variable will hold the SRS setting with offset such that passing signalmax=1 will
	     //   give choiceneg=0. All lesser signalmaxes will give negative values.
	if(significand <= 1.05)
		choiceneg = exponent*3
	elseif(significand <= 2.10)
		choiceneg = exponent*3 + 1
	elseif(significand <= 5.20)
		choiceneg = exponent*3 + 2
	else // between 5.2 and 10
		choiceneg = exponent*3 + 3
	endif
	
	variable choice // will hold the real sensitivity setting number: choiceneg + offset.
	
	// now, let's check if we're doing current or voltage.	
	variable readval
	GPIB2 device = srs
	GPIBWrite2 "ISRC?"
	GPIBRead2/T="\n" readval
	
	if(readval >= 2)
		// current measurements: lowest setting (0) corresponds to 2e-15, or choiceneg = -44
		choice = choiceneg + 44
	else
		// voltage measurement: lowest setting (0) corresponds to 2e-9, or choiceneg = -26
		choice = choiceneg + 26
	endif
	
	
	if(choice < 0)
		choice = 0 // user requested a ridiculously small sensitivity, so we'll just put it at the lowest possible.
	endif
	if(choice > 26)
		choice = 26 // user requested a too-high range. Overload will probably occur, too bad for them.
	endif
	
	GPIBWrite2 "SENS "+num2str(choice)
	return choice
End

///MBL Apr'10: pass realsens=1 to get the actual fullscale sensitivity (in Volts or Amps)
function GetSRSSensitivity(srs,[realsens])
	Variable srs,realsens
	variable readval
	GPIB2 device = srs
	GPIBWrite2 "SENS?"
	GPIBRead2/T="\n" readval
	
	if(realsens == 0)
		return readval
	endif
	
	/// otherwise, return the real sensitivity... first, break it down:
	variable modulo = mod(readval,3)
	variable expo = (readval-modulo)/3
	
	// now, are we measuring current or voltage?
	GPIBWrite2 "ISRC?"
	GPIBRead2/T="\n" readval
	
	if(readval >= 2)
		expo -= 15 /// current measurement
	else
		expo -= 9 /// voltage measurement
	endif
	
	if(modulo == 0)
		return 2*10^expo
	elseif(modulo == 1)
		return 5*10^expo
	elseif(modulo == 2)
		return 10*10^expo
	endif
End

function /t ReadSRSxy(srs)  // 20 milliseconds
	variable srs
	string response
	
	GPIB2 device = srs
	GPIBWrite2 "SNAP ? 1,2"
	GPIBRead2/T="\n" response
	
	return response

end

function ReadSRSx(srs)  // 20 milliseconds
	variable srs
	variable readval
	
	GPIB2 device = srs
	GPIBWrite2 "OUTP? 1"
	GPIBRead2/T="\n" readval

	return readval
End

function ReadSRSy(srs)  // 20 milliseconds
	variable srs
	variable readval
	
	GPIB2 device = srs
	GPIBWrite2 "OUTP? 2"
	GPIBRead2/T="\n" readval

	return readval
End

function ReadSRSr(srs)
	variable srs
	variable readval
	
	GPIB2 device = srs
	GPIBWrite2 "OUTP? 3"
	GPIBRead2/T="\n" readval

	return readval
End

function ReadSRSt(srs)   // t means theta
	variable srs
	variable readval
	
	GPIB2 device = srs
	GPIBWrite2 "OUTP? 4"
	GPIBRead2/T="\n" readval

	return readval
End

function SRSAutoSens(srs)
	variable srs

	GPIB2 device = srs
	GPIBWrite2 "AGAN"
end

function SRSAutoPhase(srs)
	variable srs
	
	GPIB2 device = srs
	GPIBWrite2 "APHS"
end

function setSRSSensUp(srs)
	variable srs
	variable ind=getsrssensitivity(srs)
	
	SetSRSSensitivity(srs,ind+1)
end

function setSRSSensDown(srs)
	variable srs
	variable ind=getsrssensitivity(srs)
	SetSRSSensitivity(srs,ind-1)
end

function ReadSRSjunk(srs)
	// for those times when your srs gpib got messed up and there's something in the buffer, and
	// your scans are always off by sgetome buffered reading... call this procedure.
	variable srs
	variable readval

	variable i
	do
		GPIB2 device = srs
		GPIBRead2 /Q/N=1 readval
		i+=1
	while(v_flag)
	printf "this read %d characters of junk \r", i-1
End

function/s GetSRSStatus(srs)
	variable srs
	string cmd
	string winfcomments
	string  buffer
	
	sprintf  winfcomments "Lock-in GPIB%d:\r\t", returnGPIBaddress(srs)
	sprintf buffer "Amplitude = %.3f V\r\tTime Constant = %.2f ms\r\tFrequency = %.2f Hz\r\tPhase = %.2f deg\r\tSensitivity = %.4f V\r\tHarmonic = %d\r", GetSRSAmplitude(srs), GetSRSTimeConst(srs,realtime=1)*1000, GetSRSFrequency(srs), GetSRSPhase(srs), GetSRSSensitivity(srs, realsens=1), GetSRSHarmonic(srs)

	winfcomments += buffer
	return winfcomments
end