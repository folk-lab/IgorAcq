#pragma rtGlobals=1		// Use modern global access method.

// Functions and interface for power supply HP6038A
// Please run initPS() first. Pay attention to initPS(), 
//     in order to set the current limit, I use the command "iset", because the command "imax" doesn't work. 
//     But in some case, this command can cause damage to the instrument.

// Functions:
// SetPSVol(Voltage),     RampPSVol(Voltage),     ReadPSVol()
// SetPSCur(Current),       ReadPSCur()

function initPS()
	variable/g PSvoltage=0, PScurrent=0
	NVAR ps7
	execute "PS6038()"
	execute "GPIB device "+num2istr(ps7)
	execute "GPIBwrite/F=\"%s\" \"iset 0.1\""// set the current limit to 0.1A
end

function SetPSVol(voltage)	// set the output voltage of the power supply
	variable voltage
	NVAR ps7
	if(voltage<0 || voltage>61.425) 
		print voltage
		print "The output voltage can only be set between 0 V to 61.425 V"
		return 0
	endif
	execute "GPIB device "+num2istr(ps7)
	execute "GPIBwrite/F=\"%s\" \"vset "+num2str(voltage)+"\""
end

function ReadPSVol()
	NVAR ps7
	Variable/G junkvariable
	variable/g trash
	execute "GPIB device "+num2istr(ps7)
	execute "GPIBwrite/F=\"%s\" \"vout?\""
	execute "GPIBread/T=\"\n\" junkvariable"
	execute "GPIBwrite/F=\"%s\" \"vout?\""
	execute "GPIBread/T=\"\n\" trash"
	return junkvariable
end 

",\r\t"

function RampPSVol(voltage) // ramp the output voltage
	variable voltage
	variable curvolt, sgn
	curvolt=ReadPSVol()
	sgn=sign(voltage-curvolt)
	for(;sgn*curvolt<sgn*voltage-0.05;curvolt+=sgn*0.05)
		SetPSVol(curvolt)
		//sleep/s 1	//  ramps at a rate of 50mV/s, the magnet needs ramping up slowly
		sleep/s 0.1
	endfor
	SetPSVol(voltage)
end

function SetPSCur(current)
	variable current
	NVAR ps7
	
	if(current<0 || current>10.2375) 
		print "The output current can only be set between 0 A to 10.2375 A"
		return 0
	endif
	execute "GPIB device "+num2istr(ps7)
	execute "GPIBwrite/F=\"%s\" \"iset "+num2str(current)+"\""
end

function RampPSCur(current) // ramp the output current
	variable current
	variable curi, sgn
	curi=ReadPSCur()
	sgn=sign(current-curi)
	for(;sgn*curi<sgn*current-0.001;curi+=sgn*0.002)
		SetPSCur(curi)
		sleep/s 0.02//0.01
	endfor
	SetPSCur(current)
end

function ReadPSCur()
	Variable/G junkvariable, trash
	NVAR ps7
	execute "GPIB device "+num2istr(ps7)
	execute "GPIBwrite/F=\"%s\" \"iout?\""
	execute "GPIBread/T=\"\n\" junkvariable"
	execute "GPIBread/T=\"\n\"  trash"
	return junkvariable
end 

//////////////////////////////////////     Interface   ////////////////////////////////////////////////////

Window PS6038() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(395,240,777,481)
	SetDrawLayer UserBack
	Button cmdSetVol,pos={46,85},size={100,30},proc=ButtonProc_HP6038,title="Set Vol"
	Button cmdSetVol,fSize=14,fStyle=1
	Button cmdRampVol,pos={47,126},size={100,30},proc=ButtonProc_HP6038,title="Ramp Vol"
	Button cmdRampVol,fSize=14,fStyle=1
	Button cmdReadVol,pos={47,170},size={100,30},proc=ButtonProc_HP6038,title="Read Vol"
	Button cmdReadVol,fSize=14,fStyle=1
	SetVariable txtVol,pos={23,49},size={150,23},title="Vol",fSize=16,fStyle=1
	SetVariable txtVol,limits={0,61.425,0.05},value= PSvoltage
	SetVariable txtCur,pos={210,50},size={150,23},title="Cur",fSize=16,fStyle=1
	SetVariable txtCur,limits={0,10.2375,0.01},value= PScurrent
	TabControl tab0,pos={18,18},size={160,200},fSize=14,fStyle=1
	TabControl tab0,tabLabel(0)="Voltage",value= 0
	TabControl tab1,pos={206,19},size={160,200},fSize=14,fStyle=1
	TabControl tab1,tabLabel(0)="Current",value= 0
	Button cmdSetCur,pos={234,86},size={100,30},proc=ButtonProc_HP6038,title="Set Cur"
	Button cmdSetCur,fSize=14,fStyle=1
	Button cmdRampCur,pos={235,127},size={100,30},proc=ButtonProc_HP6038,title="Ramp Cur"
	Button cmdRampCur,fSize=14,fStyle=1
	Button cmdReadCur,pos={234,171},size={100,30},proc=ButtonProc_HP6038,title="Read Cur"
	Button cmdReadCur,fSize=14,fStyle=1
EndMacro

Function ButtonProc_HP6038(ctrlName) : ButtonControl
	String ctrlName
	NVAR voltage=PSvoltage, current=PScurrent
	strswitch(ctrlname)
		case "cmdsetvol":
			SetPSVol(voltage)
			break
		case "cmdrampvol":
			RampPSVol(voltage)
			break
		case "cmdreadvol":
			voltage=ReadPSVol()
			break
		case "cmdsetcur":
			SetPSCur(current)
			break
		case "cmdreadcur":
			current=ReadPSCur()
			break
	endswitch
End