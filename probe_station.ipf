#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function init_probestation()
	variable /g current_amp = 1e-6
	variable /g voltage_divider = 0.0625
	variable /g bias_channel = 0 
	variable /g adc_channel = 1 
	variable /g adc_board = 6
end

function single_point()
	wave/t dacvalsstr=dacvalsstr
	nvar voltage_divider, current_amp, bias_channel, adc_channel, adc_board
	variable output = str2num(dacvalsstr[bias_channel][1])*voltage_divider
	return (-1*output)/(ReadADCBD(adc_channel, adc_board)*current_amp)
end

function iv_curve(startx, endx, numptsx, delayx)
	variable startx, endx, numptsx, delayx
	wave/t dacvalsstr=dacvalsstr
	wave w_coef=w_coef
	nvar voltage_divider, current_amp, bias_channel, adc_channel, adc_board
	variable output = str2num(dacvalsstr[bias_channel][1])*voltage_divider
	
	make /o/n=(numptsx) current=NaN
	setscale/I x startx, endx, "", current
	
	rampvolts(bias_channel, startx/voltage_divider, ramprate=500)
	sleep /S 0.5
	variable i=0, setpoint=startx
	do
		setpoint = startx + (i*(endx-startx)/(numptsx-1))
		rampvolts(bias_channel, setpoint/voltage_divider, ramprate=500)
		sleep /S delayx
		current[i] = -1*ReadADCBD(adc_channel,adc_board)*current_amp
		doupdate
		i+=1
	while(i<numptsx)

	CurveFit /Q line, current
	print 1/w_coef[1]
	
//	string filename
//	filename =  "dat" + num2str(filenum) + "current"; duplicate current $filename; print filename; Save/C/P=data $filename;
	
end