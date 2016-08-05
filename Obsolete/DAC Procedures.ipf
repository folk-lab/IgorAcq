#pragma rtGlobals=1		// Use modern global access method.

function setvolts(chan, mV)

	variable chan, mV
	variable chanfactor
	wave dacvals = dacvals
	
	if (chan==0||chan==2||chan ==4||chan==6||chan==8||chan==10||chan==12||chan==14)
	 	chanfactor=3
	else
		chanfactor =-100
	endif
	
	fDAQmx_WriteChan("Dev1", chan, (chanfactor*mV/1000), -10, 10)
	dacvals[chan]=mV
	
end

function rampvolts(chan, mV)

	variable chan, mV
	wave dacvals = dacvals
	variable initmV, finmV, sign1, chanfactor
	
	if (chan==0||chan==2||chan ==4||chan==6||chan==8||chan==10||chan==12||chan==14)
	 	chanfactor=3
	else
		chanfactor =-100
	endif
	
	initmV = dacvals[chan]
	finmV = mV
	
	mV = initmV
	sign1 = (finmV-initmV)/abs(finmV-initmV)
	do
		fDAQmx_WriteChan("Dev1", chan, (chanfactor*mV/1000), -10, 10)
		dacvals[chan]=mV
		sleep /s 0.2
		mV += 50*sign1
	while ((mV*sign1) < (finmV*sign1))
	fDAQmx_WriteChan("Dev1", chan, (chanfactor*finmV/1000), -10, 10)
	dacvals[chan]=finmV
end

function rampallzero()
	variable chan

	for(chan=0;chan<16;chan+=1)
		rampvolts(chan,0)
	endfor
end
