#pragma rtGlobals=1		// Use modern global access method.

/// 2012 March 26 - removed channel coupling compensation in code

 
 // Functions and interface for BabyDAC and other instruments - By Yuan Ren
 // Please run initBabyDAC() first
 
 // Functions:
 // SetVolts(Channel, mV)
 // RampVolts(Channel, mV)
 // RampAllZero()
 
// approx. 1 millisecond
// call at most once per **2** milliseconds, or serial buffer may overfill(check me?)
// update Apr 12, 2011 limit is *exactly* 5V, not 4.999V. [-Mark]
//            also rewrote to not use string processing, just binary arithmetic
function setvolts(channel, mV)  
	variable mV, channel
	wave dacvals=root:dacvals
	wave/t dacvalstr=dacvalstr
	NVAR out_voltage=out_voltage
	variable voltage,setpoint,v1,v2,v3,v4,v5,parity, babychannel
	string binarystr,cmd
	variable BabyDACNum = 2 // This is the number that is written on the BabyDAC, or is set by the first five red jumpers inside on the DAC's board.
	variable babyNo=ceil((channel+1)/4+(BabyDACNum-1))  // If you want to use 2 BabyDACs at the same time, pick, for example, babydac 3 and 4. Set the BabyDACNum to 3, and use channels 0 to 8.
	babychannel=mod(channel, 4)
	if( numtype(mV)>0)
		print "ERROR BabyDAC setvolts called with non-real voltage"
		return 0
	endif
	if (channel<12)
	if(abs(mV)>2700.001) 
		print "The output voltage cannot be greater than +- 2700mV"
		mv = sign(mV)*2700
	endif
	endif
	if(channel<0 || channel >15)
		print "The channel # should be between 0 to 15"
		return 0
	endif

	if (channel==12)
		setpoint=round((mV+10000)/10000*1048575)
      elseif (channel == 13)
      		setpoint=round((mV + 10000)/20000*1048575)
	elseif (channel==14|| channel==15)
		setpoint=round((mV+10000)/20000*1048575)
	else
		setpoint=round((mV+5000)/10000*1048575)
	endif
	
	v1=(setpoint & 0xfc000)/0x4000 // most significant 6 bits
	v2=(setpoint & 0x3f80)/0x80 // middle 7 bits
	v3=setpoint & 0x7f // least significant 7 bits
	v4=0x40+babyNo
	v5=0x40+babychannel
	parity=v4%^v5%^v1%^v2%^v3
	make/o mywave={0xc0+babyNo,v5,v1,v2,v3,parity}

	svar babydacport
	execute "VDTOperationsPort2 "+babydacport
	
	execute "VDTWriteBinaryWave2 /O=10 mywave"

//	if (channel == 3 || channel == 11 || channel == 15)  // Channel 7 and 5 are not coupled
//		dacvals[channel-2]=dacvals[channel-2]+(mV-dacvals[channel])/40
//		dacvalstr[channel-2][1]=num2str(dacvals[channel-2])
//	endif

	out_voltage=mV
	dacvals[channel]=out_voltage
	dacvalstr[channel][1]=num2str(out_voltage)
	
	return 1
end

// updated May 8 2009 by Mark: rate control, tighter looping.
// rate is in mV per second.
function rampvolts(channel, mV, [ramprate,noupdate])
	variable channel, mV,ramprate,noupdate
	wave dacvals=root:dacvals
	wave/t dacvalstr=dacvalstr
	variable voltage, sgn, step, flag=1
	variable sleeptime; // seconds per ramp cycle (must be at least 0.002)
	voltage=dacvals[channel]
	sgn=sign(mV-voltage)
	
	if(noupdate)
		pauseupdate
		sleeptime = 0.002 // can ramp finely if there's no updating!
	else
		sleeptime = 0.01 // account for screen-update delays
	endif
	
	if(paramisdefault(ramprate))
		if(channel==6)
			ramprate = 20   // (mV/s) equivalent to old rate
//		elseif(channel==0)
//			ramprate=50
		else
			ramprate = 20    // (mV/s) ~~equivalent to old rate
		endif
	endif
	
	step = ramprate*sleeptime;
	
	//print "Ramping channel "+num2str(channel)+" to "+num2str(mv)+"mV"

	voltage+=sgn*step
	if(sgn*voltage >= sgn*mV)
		//// we started less than one step away from the target. set voltage and leave.
		setvolts(channel, mV)
		return 0
	endif
	
	variable starttime,endtime

	starttime = stopmstimer(-2)
	do
		if(!noupdate)
			doupdate
		endif
		flag=setvolts(channel, voltage)
		if(flag==0)	// something went wrong
			return 0
		endif

		endtime = starttime + 1e6*sleeptime
		do
		while(stopmstimer(-2) < endtime)
		starttime = stopmstimer(-2)

		voltage+=sgn*step
	while(sgn*voltage<sgn*mV-step)
	setvolts(channel, mV)
end

function rampallzero()
	variable i
	for (i=15;i>=0;i-=1)
		rampvolts(i,0)
	endfor
end

///////////////////////////////////////////////////////////////////

 function hex2dec(hex) 	//convert hexadecimal number to decimal number
 	string hex
 	variable decimal
 	sscanf hex, "%x" , decimal
 	return decimal
end 

function/s dec2bin(dec)	//convert decimal number to binary number
	variable dec
	string binarystr=""
	do
		binarystr=num2str(mod(dec,2))+binarystr
		dec=floor(dec/2)
	while(dec>0)
	return binarystr
end

function bin2dec(bin)	//convert binary number to decimal number
	string bin
	string hex=""
	variable i
	if(mod(strlen(bin),4)==0)
		i=4
	endif
	for(i=4-mod(strlen(bin),4);i>0;i-=1)
		bin="0"+bin
	endfor
	for(i=1;i<=strlen(bin)/4;i+=1)
		strswitch (bin[(i-1)*4,i*4-1])
			case "0000":
				hex+="0"
				break
			case "0001":
				hex+="1"
				break
			case "0010":
				hex+="2"
				break
			case "0011":
				hex+="3"
				break
			case "0100":
				hex+="4"
				break
			case "0101":
				hex+="5"
				break
			case "0110":
				hex+="6"
				break
			case "0111":
				hex+="7"
				break
			case "1000":
				hex+="8"
				break
			case "1001":
				hex+="9"
				break
			case "1010":
				hex+="a"
				break
			case "1011":
				hex+="b"
				break
			case "1100":
				hex+="c"
				break
			case "1101":
				hex+="d"
				break
			case "1110":
				hex+="e"
				break
			case "1111":
				hex+="f"
				break
		endswitch
	endfor
	return hex2dec(hex)
end

////////////////////////////////////////////////////////////////

function initBabyDAC()
	string cmd
	variable/g out_voltage=0, set_channel=0, lockinNum=8
	make/o dacvals={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	make/o listboxattr={{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},{2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2}}
	make/t/o dacvalstr={{"0","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15"},{"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"}}
	string /g babydacport = "COM5"
	execute "VDTOperationsPort2 "+babydacport
	cmd="VDT2 baud=57600, stopbits=1"
	execute(cmd)
	dowindow /k babydac
	execute("BabyDAC()")
end

//////////////////////////////////////////////        User Interface     ////////////////////////////////////////////////

Window BabyDAC() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(43,59,342,577)
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 49,29,"CHANNEL"
	SetDrawEnv fsize= 16,fstyle= 1
	DrawText 159,29,"VOLT (mV)"
	DrawText 274,26,"                                               "
	DrawText 274,26,"                                               "
	SetDrawEnv fillpat= 0
	DrawRect 9,455,290,507
	DrawText 28,502,"LockinSens"
	DrawText 28,477,"Lockin Address  SRS"
	DrawLine 259,112,275,112
	DrawLine 275,112,275,70
	SetDrawEnv arrow= 1
	DrawLine 275,70,260,70
	SetDrawEnv textrot= -90
	DrawText 276,110,"+2.5%"
	DrawLine 259,287,275,287
	DrawLine 275,287,275,245
	SetDrawEnv arrow= 1
	DrawLine 275,245,260,245
	SetDrawEnv textrot= -90
	DrawText 276,285,"+2.5%"
	DrawLine 259,376,275,376
	DrawLine 275,376,275,334
	SetDrawEnv arrow= 1
	DrawLine 275,334,260,334
	SetDrawEnv textrot= -90
	DrawText 276,374,"+2.5%"
	Button setvol,pos={23,422},size={65,20},proc=ButtonProc_BabyDAC,title="SET"
	ListBox list0,pos={42,35},size={218,370},proc=ListBoxProc,fSize=16,frame=2
	ListBox list0,fStyle=1,listWave=root:dacvalstr,selWave=root:listboxattr,mode= 1
	ListBox list0,selRow= 1,editStyle= 2
	Button rampvol,pos={110,422},size={65,20},proc=ButtonProc_BabyDAC,title="RAMP"
	Button rampallzero,pos={195,422},size={80,20},proc=ButtonProc_BabyDAC,title="RAMP ALL 0"
	Button lockinautosens,pos={108,485},size={50,20},proc=ButtonProc_BabyDAC,title="Auto"
	Button lockinsensup,pos={165,485},size={50,20},proc=ButtonProc_BabyDAC,title="Up"
	Button lockinsensdown,pos={225,485},size={50,20},proc=ButtonProc_BabyDAC,title="Down"
	Button lockinautophase,pos={205,460},size={70,20},proc=ButtonProc_BabyDAC,title="AutoPhase"
	SetVariable lockinaddress,pos={146,462},size={30,18},title=" "
	SetVariable lockinaddress,limits={8,9,1},value= lockinnum
EndMacro

Function ButtonProc_BabyDAC(ctrlName) : ButtonControl
	String ctrlName
	wave dacvals=root:dacvals
	wave/t dacvalstr=dacvalstr
//	NVAR channel=set_channel
	nvar LockinNum
	controlinfo /W=BabyDAC list0
	variable channel = v_value
	strswitch(ctrlname)
		case "setvol":
			print "Setting channel ", channel, "to ", dacvalstr[channel][1]
			setvolts(channel,str2num(dacvalstr[channel][1]))
			break
		case "rampvol":
			print "Ramping channel ", channel, "to ", dacvalstr[channel][1]
			rampvolts(channel,str2num(dacvalstr[channel][1]))
			break
		case "rampallzero":
			print "Ramping all channels to 0 "
			rampallzero()
			break
		case "lockinautophase":
			execute "srsautophase(srs"+num2str(lockinNum)+")"
			break
		case "lockinautosens":
			execute "srsautosens(srs"+num2str(lockinNum)+")"
			break
		case "lockinsensup":
			execute "srssensup(srs"+num2str(lockinNum)+")"
			break
		case "lockinsensdown":
			execute "srssensdown(srs"+num2str(lockinNum)+")"
			break
	endswitch
End

Function ListBoxProc(ctrlName,row,col,event) : ListBoxControl
	String ctrlName
	Variable row
	Variable col
	Variable event	//1=mouse down, 2=up, 3=dbl click, 4=cell select with mouse or keys
					//5=cell select with shift key, 6=begin edit, 7=end
	wave dacvals=root:dacvals
	wave/t dacvalstr=root:dacvalstr
	NVAR channel=root:set_channel
	NVAR out_voltage=out_voltage
//	if (event==4)		// cell selected
//		out_voltage=dacvals[row]
//		dacvalstr[row][1]=num2str(out_voltage)
//		channel=row
//		if (mod(channel,4)==3 && channel!=7)	// 7 and 5 are not connected/
//			variable voltage=dacvals[channel-2]+(5000-dacvals[channel])/40
//		elseif (channel==15)
//             endif
//	elseif (event==7)
//		if (mod(channel,4)==3 && channel!=7)	// 7 and 5 are not connected
//			dacvalstr[channel-2][1]=num2str(dacvals[channel-2]+(str2num(dacvalstr[channel][1])-out_voltage)/40)
//		endif
//		out_voltage=str2num(dacvalstr[channel][1])
//	endif
End
