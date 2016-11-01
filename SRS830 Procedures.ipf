#pragma rtGlobals=1		// Use modern global access method.

// Modified by Mark Lundeberg Nov-05-2008 - Added ReadSRSjunk
// Modified by Sergey Frolov Aug-08-2007 - Added SetSRSAmplitude, SetSRSFrequency
// Modified by Yuan Ren Jun-27-2008 - Added GetSRSSensitivity, SRSAutoSens, SRSAutoPhase, SRSSensUp, SRSSenDown, GetSRSFrequency

function InitSRS(srs)
	Variable srs
	execute "NI488 ibtmo "+num2istr(srs)+", 11"  // one second timeouts
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\" \"OUTX 1\""
	execute "GPIBwrite/F=\"%s\" \"OVRM 1\""
End

function SetSRSHarmonic(srs,harm)
	variable srs, harm
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\" \"HARM "+num2str(harm)+"\""
End

function GetSRSHarmonic(srs)
	Variable srs
	Variable/G junkvariable
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\" \"HARM? \""
	execute "GPIBread/T=\"\n\" junkvariable"
	return junkvariable
End

function SetSRSTimeConst(srs, i)	// Set time constant
// i=8, t=100ms; i=9 t=300ms
	variable srs, i
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\" \"OFLT "+num2str(i)+"\""
End

function GetSRSTimeConst(srs)
	Variable srs
	Variable/G junkvariable
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\" \"OFLT?\" "
	execute "GPIBread/T=\"\n\" junkvariable"
	return junkvariable
End

function GetSRSTimeConstInSeconds(srs)
	variable srs
	variable timecode = GetSRSTimeConst(srs)
	if (mod(timecode, 2)==0)
		return 10^(timecode/2-5)
	else
		return 3*10^((timecode-1)/2-5)
	endif
End

function GetSRSSensitivityInVolts(srs)
	variable srs
	variable senscode = GetSRSSensitivity(srs)
	if (mod(senscode, 3)==0)
		return 2*10^(senscode/3-9)
	elseif (mod(senscode, 3)==1)
		return 5*10^((senscode-1)/3-9)
	else
		return 10*10^((senscode-2)/3-9)
	endif
End

function GetSRSPhase(srs)
	Variable srs
	Variable/G junkvariable
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\" \"PHAS? \""
	execute "GPIBread/T=\"\n\" junkvariable"
	return junkvariable
End

function SetSRSAmplitude(srs,volts)
	Variable srs,volts
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\" \"SLVL "+num2str(volts)+"\""
End

       	
function GetSRSAmplitude(srs)
	Variable srs
	Variable/G junkvariable
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\" \"SLVL? \""
	execute "GPIBread/T=\"\n\" junkvariable"
	return junkvariable
End

function SetSRSPhase(srs,phase)
	Variable srs,phase
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\" \"PHAS "+num2str(phase)+"\""
End

function SetSRSFrequency(srs,hertz)
	Variable srs,hertz
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\" \"FREQ "+num2str(hertz)+"\""
End

function GetSRSFrequency(srs)
	Variable srs
	Variable/G junkvariable
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\" \"FREQ? \""
	execute "GPIBread/T=\"\n\" junkvariable"
	return junkvariable
End

// note, here you need to pass in an integer which maps to a full scale.
// see SetSRSSensitivityRange for an easier way
function SetSRSSensitivity(srs,sens)
//
	Variable srs,sens
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\" \"SENS "+num2str(sens)+"\""
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
	variable /g junkvariable
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\" \"ISRC?\" "
	execute "GPIBread/T=\"\n\" junkvariable"
	if(junkvariable >= 2)
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
	
	execute "GPIBwrite/F=\"%s\" \"SENS "+num2str(choice)+"\""
	return choice
End

///MBL Apr'10: pass realsens=1 to get the actual fullscale sensitivity (in Volts or Amps)
function GetSRSSensitivity(srs,[realsens])
//
	Variable srs,realsens
	Variable/G junkvariable
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\" \"SENS?\" "
	execute "GPIBread/T=\"\n\" junkvariable"
	if(realsens == 0)
		return junkvariable
	endif
	
	/// otherwise, return the real sensitivity... first, break it down:
	variable modulo = mod(junkvariable,3)
	variable expo = (junkvariable-modulo)/3
	
	// now, are we measuring current or voltage?
	execute "GPIBwrite/F=\"%s\" \"ISRC?\" "
	execute "GPIBread/T=\"\n\" junkvariable"
	if(junkvariable >= 2)
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

function ReadSRSx(srs)  // 20 milliseconds
	variable srs
	Variable/G junkvariable,flagnolocal
	//ReadSRSjunk(srs)
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\"  \"OUTP? 1\""
	execute "GPIBread/T=\"\n\" junkvariable"
//	if(!flagnolocal)	// acj 4/02 - send the dmm to local mode unless turned off during a sweep
//		execute "GPIB gotolocal"
//	endif
	return junkvariable
End

function ReadSRSy(srs)  // 20 milliseconds
	variable srs
	Variable/G junkvariable,flagnolocal

	execute "GPIB device "+num2istr(srs)
//	execute "GPIBwrite/F=\"%s\"  \"SYNC 1\""
	execute "GPIBwrite/F=\"%s\"  \"OUTP? 2\""
	execute "GPIBread/T=\"\n\" junkvariable"
//	if(!flagnolocal)	// acj 4/02 - send the dmm to local mode unless turned off during a sweep
//		execute "GPIB gotolocal"
//	endif
	return junkvariable
End

function ReadSRSr(srs)
	variable srs
	Variable/G junkvariable,flagnolocal

	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\"  \"OUTP? 3\""
	execute "GPIBread/T=\"\n\" junkvariable"
	return junkvariable
End

function ReadSRSt(srs)   // t means theta
	variable srs
	Variable/G junkvariable,flagnolocal

	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\"  \"OUTP? 4\""
	execute "GPIBread/T=\"\n\" junkvariable"
	return junkvariable
End

function SRSAutoSens(srs)
	variable srs
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\"  \"AGAN\""
end

function SRSAutoPhase(srs)
	variable srs
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite/F=\"%s\"  \"APHS\""
end

function SRSSensUp(srs)
	variable srs
	variable ind=getsrssensitivity(srs)
	SetSRSSensitivity(srs,ind+1)
end

function SRSSensDown(srs)
	variable srs
	variable ind=getsrssensitivity(srs)
	SetSRSSensitivity(srs,ind-1)
end

function ReadSRSjunk(srs)
	// for those times when your srs gpib got messed up and there's something in the buffer, and
	// your scans are always off by some buffered reading... call this procedure.
	variable srs
	variable/g junkvariable
	variable/g v_flag
	v_flag = 1
	junkvariable = 0
	variable i
	do
		execute "GPIB device "+num2istr(srs)
		execute "GPIBread/Q/N=1 junkvariable"
		i+=1
	while(v_flag)
	printf "this read %d characters of junk \r", i-1
	return junkvariable
End

function/s GetSRSStatus(srs)
	variable srs
	nvar pad
	string cmd
	string winfcomments
	string  buffer
	
	sprintf cmd "gpib_return(%d)", srs
	execute(cmd)
	sprintf  winfcomments "Lock-in GPIB%d:\r\t", pad
	sprintf buffer "Amplitude = %.3f V\r\tTime Constant = %.2f ms\r\tFrequency = %.2f Hz\r\tPhase = %.2f deg\r\tSensitivity = %.4f V\r\tHarmonic = %d\r", GetSRSAmplitude(srs), GetSRSTimeConstInSeconds(srs)*1000, GetSRSFrequency(srs), GetSRSPhase(srs), GetSRSSensitivityInVolts(srs), GetSRSHarmonic(srs)

	winfcomments += buffer
	return winfcomments
end