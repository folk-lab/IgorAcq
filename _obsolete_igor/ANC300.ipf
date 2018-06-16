#pragma rtGlobals=1		// Use modern global access method.


function initanc([port])
	string port
	if(paramisdefault(port))
		port = "COM5"
	endif
	//print port
	VDTOpenPort2 $port		//add those 4 lines to fix some communication issues that can appear sometimes (when restarting the ANC wihtout restarting Igor for instance)//Julien Dec28
	VDTClosePort2 $port
	ExecuteScriptText /B /Z "devcon disable *pid_a4a7"
	ExecuteScriptText /B /Z "devcon enable *pid_a4a7"
	string /g ancport = port
	
end



function setstepanc(volts)
	variable volts
	SVAR /Z ancport
	string /g junkstr
	if(!SVAR_Exists(ancport))
		initanc()
		string /g ancport
	endif
	execute "vdtoperationsport2 "+ancport
	execute "vdt2 baud=9600, stopbits=1, databits=8, parity=0, in=0,  out=0, echo=0, terminalEOL=0,killio"
	junkstr = ""
	vdtwrite2 /O=1 /Q "setv 1 " + num2str(volts)+"\r"
	//vdtread2 /O=0.1 /Q junkstr 
	//vdtread2 /O=0.1 /Q junkstr 

end



function moveancup(steps)
	variable steps
	SVAR /Z ancport
	string /g junkstr
	if(!SVAR_Exists(ancport))
		initanc()
		string /g ancport
	endif
	execute "vdtoperationsport2 "+ancport
	execute "vdt2 baud=9600, stopbits=1, databits=8, parity=0, in=0,  out=0, echo=0, terminalEOL=0,killio"
	junkstr = ""
	vdtwrite2 /O=1 /Q "stepu 1 " + num2str(steps)+"\r"
	//vdtread2 /O=0.1 /Q junkstr 
	//vdtread2 /O=0.1 /Q junkstr 

end

function moveancdown(steps)
	variable steps
	SVAR /Z ancport
	string /g junkstr
	if(!SVAR_Exists(ancport))
		initanc()
		string /g ancport
	endif
	execute "vdtoperationsport2 "+ancport
	execute "vdt2 baud=9600, stopbits=1, databits=8, parity=0, in=0,  out=0, echo=0, terminalEOL=0,killio"
	junkstr = ""
	vdtwrite2 /O=1 /Q "stepd 1 " + num2str(steps)+"\r"
	//vdtread2 /O=0.1 /Q junkstr 
	//vdtread2 /O=0.1 /Q junkstr 

end


function ancgnd()
	SVAR /Z ancport
	string /g junkstr
	if(!SVAR_Exists(ancport))
		initanc()
		string /g ancport
	endif
	execute "vdtoperationsport2 "+ancport
	execute "vdt2 baud=9600, stopbits=1, databits=8, parity=0, in=0,  out=0, echo=0, terminalEOL=0,killio"
	junkstr = ""
	vdtwrite2 /O=1 /Q "setm 1 gnd \r"
	//vdtread2 /O=0.1 /Q junkstr 
	//vdtread2 /O=0.1 /Q junkstr 

end

function ancstepmode()
	SVAR /Z ancport
	string /g junkstr
	if(!SVAR_Exists(ancport))
		initanc()
		string /g ancport
	endif
	execute "vdtoperationsport2 "+ancport
	execute "vdt2 baud=9600, stopbits=1, databits=8, parity=0, in=0,  out=0, echo=0, terminalEOL=0,killio"
	junkstr = ""
	vdtwrite2 /O=1 /Q "setm 1 stp \r"
	//vdtread2 /O=0.1 /Q junkstr 
	//vdtread2 /O=0.1 /Q junkstr 

end

function ancstepwait()
	SVAR /Z ancport
	string /g junkstr
	if(!SVAR_Exists(ancport))
		initanc()
		string /g ancport
	endif
	execute "vdtoperationsport2 "+ancport
	execute "vdt2 baud=9600, stopbits=1, databits=8, parity=0, in=0,  out=0, echo=0, terminalEOL=0,killio"
	junkstr = ""
	vdtwrite2 /O=1 /Q "stepw 1 \r"
	//vdtread2 /O=0.1 /Q junkstr 
	//vdtread2 /O=0.1 /Q junkstr 

end

function anccontup()
	SVAR /Z ancport
	string /g junkstr
	if(!SVAR_Exists(ancport))
		initanc()
		string /g ancport
	endif
	execute "vdtoperationsport2 "+ancport
	execute "vdt2 baud=9600, stopbits=1, databits=8, parity=0, in=0,  out=0, echo=0, terminalEOL=0,killio"
	junkstr = ""
	vdtwrite2 /O=1 /Q "stepu 1 c \r"

end 

function anccontdown()
	SVAR /Z ancport
	string /g junkstr
	if(!SVAR_Exists(ancport))
		initanc()
		string /g ancport
	endif
	execute "vdtoperationsport2 "+ancport
	execute "vdt2 baud=9600, stopbits=1, databits=8, parity=0, in=0,  out=0, echo=0, terminalEOL=0,killio"
	junkstr = ""
	vdtwrite2 /O=1 /Q "stepd 1 c \r"

end


function rampanc(deg) //deg should be at least 0.3deg different from the current angle
variable deg
variable /G dmm23
variable /G dmm22
variable angle,uplimit, downlimit
variable dmm=dmm23
setspeeddmm(dmm23,0) // seems like a good precison, and fast enough for that
angle=readdmm(dmm)
uplimit=32
downlimit=13
ancstepmode()

if(deg<downlimit) //dont want to do that
print "Angle requested is out of range"
elseif(deg>uplimit) //same
print "Angle requested is out of range"
elseif(angle<downlimit)//check if dmm is reading angle correctly
print "Angle seems incorrect. Check dmm"
elseif(angle>uplimit)//check if dmm is reading angle correctly
print "Angle seems incorrect. Check dmm"
	
	elseif(angle>deg)

		do
			if(angle<downlimit)
				break
			elseif(angle>uplimit)
				break
			endif
		moveancup(50) 
		sleep /s 0.2
		angle=readdmm(dmm)
		while(angle>deg+.2)
	
		do
			if(angle<downlimit)
				break
			elseif(angle>uplimit)
				break
			endif
		moveancup(10) 
		sleep /S 0.2
		angle=readdmm(dmm)
		while(angle>deg+0.01)
	
		do
			if(angle<downlimit)
				break
			elseif(angle>uplimit)
				break
			endif
		moveancup(2) 
		sleep /S 0.2
		angle=readdmm(dmm)
		while(angle>deg)
	
	elseif (angle<deg)

		do
			if(angle<downlimit)
				break
			elseif(angle>uplimit)
				break
			endif
		moveancdown(50)
	       sleep /s 0.2
              angle=readdmm(dmm)
		while(angle<deg-.2)
	      	
	      	do
	      		if(angle<downlimit)
				break
			elseif(angle>uplimit)
				break
			endif
		moveancdown(10)
		sleep /S 0.2
		angle=readdmm(dmm)
		while(angle<deg-0.01)
	      
	       do
	       	if(angle<downlimit)
				break
			elseif(angle>uplimit)
				break
			endif
		moveancdown(2)
		sleep /S 0.2
		angle=readdmm(dmm)
		while(angle<deg)
	
endif

ancgnd()
end






function sweepanc(angle1, angle2,stepsize,delay)
variable angle1,angle2, stepsize,delay
variable /G dmm23
variable /G dmm22
variable angle, i
make /o/n=(0) readangle=nan,  stepnr=nan
make /o/n=(0) g1=nan, g2=nan, g3=nan

i=0;
rampancres(angle1) 
angle=readdmm(dmm23)
ancstepmode()
	if(angle>angle2)
             
		do
	      redimension /n=(i+1) readangle,stepnr,g1,g2,g3
             moveancdown(stepsize)
		sleep /S delay
		angle=readdmm(dmm23)
		//print angle
		readangle[i]=angle;
		g1[i]=getg1()
		g2[i]=getg2()
		//g3[i]=getg3()
		stepnr[i]=i*stepsize;
		i=i+1;
		doupdate
		while(angle>angle2)
	

	
	
	elseif (angle<angle2)
	
		do	
	      redimension /n=(i+1) readangle,stepnr,g1,g2,g3
             moveancup(stepsize)
		sleep /S delay
		angle=readdmm(dmm23)
		//print angle
		readangle[i]=angle;
		g1[i]=getg1()
		g2[i]=getg2()
		//g3[i]=getg3()
		stepnr[i]=i*stepsize;
		i=i+1;
		doupdate
		while(angle<angle2)
	
	endif
ancgnd()
end




function scanangle(start,fin,numpts,delay,[noupdate])  //step size needs to be at least 0.3 degrees .... as of dec 27 2011//Julien
	variable start, fin, numpts, delay,noupdate
	variable i=0
	variable deg
	NVAR srs8 = srs8
	NVAR srs9 = srs9
	NVAR k2400 = k2400
	NVAR dmm22=dmm22
	NVAR dmm23=dmm23
	
	variable da = (fin-start)/(numpts-1)
	
	make /o/n=(numpts) g1=NaN
	setscale/I x start, fin, "", g1

	g1=nan
	duplicate /o g1 gx gi g2 g3 readangle
//	rampanc(start-0.1)
	do
		if(!noupdate)
			doupdate
		endif
		deg = (start+i*da)
		
		rampanc(deg)
	
		//gx[i]=kvoltage   //  = x
		//g1[i]=getg1()
		sleep /S delay
		g1[i]=getg1()
		g2[i]=getg2()
		g3[i]=getg3()
		readangle[i]=readdmm(dmm23)
		i += 1
	while (i<numpts)
	
	logger()


end 



function kRot2d(v1, v2, vstep,A1, A2, Astep, delay, Adelay) 
	variable v1, v2, vstep,A1, A2, Astep, delay, Adelay
	nvar k2400
	variable i, Angle
	NVAR dmm23
	wave g1, g2,g3
	i=0
	make /o/n=(vstep, Astep) g2d=nan, g2dt=nan, g2du=nan
	make /o/n=(Astep) Angleread

	setscale /i x, v1,v2, g2d,g2dt,g2du
	setscale /i y,A1,A2, g2d,g2dt,g2du
      setscale /i x,A1,A2, Angleread
      	
	do
		Angle = (A1 + (A2-A1)*i/(Astep-1))
		rampanc(Angle)
		doupdate 
		rampkvoltage(k2400,v1,1000);
		Sleep /S Adelay
		scankvoltage(v1, v2, vstep, delay, ramprate=1000, runup=3,noupdate=1)
		g2d[][i]=g1[p]
		g2dt[][i]=g2[p]
             g2du[][i]=g3[p]

		Angleread[i]=readdmm(dmm23)
		i += 1
	while (i<Astep)
end
		
	


function kRot2dFixBperp(v1, v2, vstep,B1, B2, Bstep,Bperp, delay, Bdelay)  //b in T, Bperp as well
	variable v1, v2, vstep,B1, B2, Bstep, Bperp, delay, Bdelay
	nvar k2400, dmm23
	variable i, Angle,Bfield
	variable ParalellAngle
	wave g1, g2, g3
	ParalellAngle=193  // in degree
	i=0
	make /o/n=(vstep, Bstep) g2d=nan, g2dt=nan, g2du=nan
	make /o/n=(Bstep) AngleRead=nan

	setscale /i x, B1,B2, AngleRead
       setscale /i x, v1,v2, g2d,g2dt,g2du
	setscale /i y,B1,B2, g2d,g2dt,g2du
	Bfield = (B1 + (B2-B1)*i/Bstep)
	
	ipsremote()
	ipshold()
	ipssettargetcurrent(Bfield*8.2016)
	ipstosetpoint()
      rampkvoltage(k2400,v1,500);
	ipswaittillatsetpoint() 

	do
		Bfield = (B1 + (B2-B1)*i/(Bstep-1))
		ipssettargetcurrent(Bfield*8.2016)
		doupdate 
		Angle=asin(Bperp/Bfield)/pi*160+ParalellAngle 
		rampanc(Angle/10)

		rampkvoltage(k2400,v1,500);
		ipswaittillatsetpoint()
		doupdate 
		
		rampkvoltage(k2400,v1,500);
		Sleep/S Bdelay
		scankvoltage(v1, v2, vstep, delay, ramprate=1000, runup=3,noupdate=1)
		g2d[][i]=g1[p]
		g2dt[][i]=g2[p]
		g2du[][i]=g3[p]
		AngleRead[i]=readdmm(dmm23)
		i += 1
	while (i<Bstep)
	
	
	
end
		
	
function rampancres(res) //res is the resistance in mOhms
variable res
variable /G dmm23
variable /G dmm22
variable angle,uplimit, downlimit
variable dmm=dmm23
setspeeddmm(dmm23,0) // seems like a good precison, and fast enough for that
angle=readdmm(dmm)
uplimit=40000e3
downlimit=0.94e7
ancstepmode()


if(res<downlimit) //dont want to do that
print "Angle requested is out of range"
elseif(res>uplimit) //same
print "Angle requested is out of range"
elseif(angle<downlimit)//check if dmm is reading angle correctly
print "Angle seems incorrect. Check dmm"
elseif(angle>uplimit)//check if dmm is reading angle correctly
print "Angle seems incorrect. Check dmm"
	
	elseif(angle>res)

		do
			if(angle<downlimit)
				break
			elseif(angle>uplimit)
				break
			endif
		moveancdown(100) 
		sleep /s 1.5
		angle=readdmm(dmm)
		while(angle>res+100e3)
	
		do
			if(angle<downlimit)
				break
			elseif(angle>uplimit)
				break
			endif
		moveancdown(10) 
		sleep /S 1
		angle=readdmm(dmm)
		while(angle>res+10e3)
	
		do
			if(angle<downlimit)
				break
			elseif(angle>uplimit)
				break
			endif
		moveancdown(2) 
		sleep /S 1
		angle=readdmm(dmm)
		while(angle>res)
	
	elseif (angle<res)

		do
			if(angle<downlimit)
				break
			elseif(angle>uplimit)
				break
			endif
		moveancup(100)
	       sleep /s 1.5
              angle=readdmm(dmm)
		while(angle<res-200e3)
	      	
	      	do
	      		if(angle<downlimit)
				break
			elseif(angle>uplimit)
				break
			endif
		moveancup(10)
		sleep /S 1
		angle=readdmm(dmm)
		while(angle<res-40e3)
	      
	       do
	       	if(angle<downlimit)
				break
			elseif(angle>uplimit)
				break
			endif
		moveancup(2)
		sleep /S 0.5
		angle=readdmm(dmm)
		while(angle<res)
	
endif

ancgnd()
end



function kRot2dFixBperpres(v1, v2, vstep,B1, B2, Bstep,Bperp, delay, Bdelay)  //b in T, Bperp as well
	variable v1, v2, vstep,B1, B2, Bstep, Bperp, delay, Bdelay
	wave fit_normalizedb40=root:fit_normalizedb40
	wave c49_g3_norm=root:c49_g3_norm
	wave c98_g3_norm=root:c98_g3_norm
	wave c124_g3_norm=root:c124_g3_norm
	nvar k2400, dmm23
	variable i, res,Angle,Bfield
	variable ParalellAngle
	wave g1, g2, g3
	ParalellAngle=193  // in degree
	i=0
	make /o/n=(vstep, Bstep) g2d=nan, g2dt=nan, g2du=nan
	make /o/n=(Bstep,3) AngleRead=nan
	make /o /n=(Bstep) g4=nan
	
	setscale /i x, B1,B2, AngleRead
       setscale /i x, v1,v2, g2d,g2dt,g2du
	setscale /i y,B1,B2, g2d,g2dt,g2du
	Bfield = (B1 + (B2-B1)*i/Bstep)
	
	ipsremote()
	ipshold()
	ipssettargetcurrent(Bfield*8.2016)
	ipstosetpoint()
      rampkvoltage(k2400,v1,500);
	ipswaittillatsetpoint() 

	do
		Bfield = (B1 + (B2-B1)*i/(Bstep-1))
		ipssettargetcurrent(Bfield*8.2016)
		ipswaittillatsetpoint()

		doupdate 
		//Angle=asin(Bperp/Bfield)/pi*160+ParalellAngle 
		//res=1.17e7+1.265e7*2/pi*acos(Bperp/Bfield)
		//res=1.14e7+1.299e7*2/pi*acos(Bperp/Bfield)
		//res=1.147e7+0.7753e7*acos(Bperp/Bfield)+0.06409e6*Bfield
		//res=(11.669e6+7.9637e6*acos(Bperp/Bfield))*fit_normalizedb40(Bfield) // for she5 at 4.2K (april 2012)
		//res=(11.1e6+11.997e6*2/pi*acos(Bperp/Bfield))*c49_g3_norm(Bfield) //for she2 at 10K (april 26 2012)
		//res=(11.061e6+12.036e6*2/pi*acos(Bperp/Bfield))*c49_g3_norm(Bfield) // april 27, 10K
		//res=(11.11e6+12.05e6*2/pi*acos(Bperp/Bfield))*c49_g3_norm(Bfield) // april 27, 10K, second try
		//res=(10.58e6+11.46e6*2/pi*acos(Bperp/Bfield))*c98_g3_norm(Bfield) // april 30, 30K
		//res=(10.60e6+11.47e6*2/pi*acos(Bperp/Bfield))*c98_g3_norm(Bfield) // april 30, 30K, second try
		res=(9.849e6+10.657e6*2/pi*acos(Bperp/Bfield))*c124_g3_norm(Bfield) // may 1, 77K
		
		
		//print res
		AngleRead[i][0]=res
		rampancres(res)
		//print readdmm(dmm23)
		AngleRead[i][1]=readdmm(dmm23)
		rampkvoltage(k2400,v1,500);
		doupdate 
		
		//rampkvoltage(k2400,v1,500);
		Sleep/S Bdelay
		scankvoltage(v1, v2, vstep, delay, ramprate=1000, runup=3,noupdate=1)
		g2d[][i]=g1[p]
		g2dt[][i]=g2[p]
		//g2du[][i]=g3[p]
		AngleRead[i][2]=readdmm(dmm23)
		g4[i]=getg4()
		i += 1
	while (i<Bstep)
	
	
	
end