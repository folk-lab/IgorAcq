#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// this was originally written to use the BabyDAC and onboard ADC
// rewritten here to use the Arduino/AnalogShield

function init_probestation(cvAmp, voltDivider, chBias, chADC, nAvg)
	// voltage_divider = 0.0625 for the box Nik built
	variable cvAmp, voltDivider, chBias, chADC, nAvg
	variable /g current_amp = cvAmp
	variable /g voltage_divider = voltDivider
	variable /g bias_channel = chBias
	variable /g adc_channel = chADC
	variable /g adc_avg = nAvg // < 100, suggest 96
	variable /g ps_inline_resistance = 2400 // roughly
	InitAnalogShield()
	
	make /o/n=(10) current=NaN
	display current
end

function single_point()
	// read single resistance value
	wave/t as_valsstr=as_valsstr
	nvar voltage_divider, current_amp, bias_channel, adc_channel, adc_avg, ps_inline_resistance
	variable output = str2num(as_valsstr[bias_channel][1])*voltage_divider
	return (-1*output)/(ReadADCsingleAS(adc_channel, adc_avg)*current_amp)-ps_inline_resistance
end

function iv_curve(startx, endx, numptsx, delayx)
	// sweep iv curve
	variable startx, endx, numptsx, delayx
	wave/t as_valsstr=as_valsstr
	wave w_coef=w_coef
	nvar voltage_divider, current_amp, bias_channel, adc_channel, adc_avg, ps_inline_resistance
	variable output = str2num(as_valsstr[bias_channel][1])*voltage_divider
	
	make /o/n=(numptsx) current=NaN
	setscale/I x startx, endx, "", current
	
	RampOutputAS(bias_channel, startx/voltage_divider, ramprate=500)
	sleep /S 0.5
	variable i=0, setpoint=startx
	do
		setpoint = startx + (i*(endx-startx)/(numptsx-1))
		RampOutputAS(bias_channel, setpoint/voltage_divider, ramprate=500)
		sleep /S delayx
		current[i] = -1*ReadADCsingleAS(adc_channel, adc_avg)*current_amp/1000
		doupdate
		i+=1
	while(i<numptsx)

	CurveFit /Q line, current
	print (1e-3/w_coef[1])-ps_inline_resistance
	
	RampOutputAS(bias_channel, 0, ramprate=500) // ramp back to zero so you can move the probes safely
	
//	string filename
//	filename =  "dat" + num2str(filenum) + "current"; duplicate current $filename; Save/C/P=data $filename;
	
end