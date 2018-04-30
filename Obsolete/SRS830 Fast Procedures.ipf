#pragma rtGlobals=1		// Use modern global access method.

////////////////////////// Procedures for fast scanning of SRS lockins ////////////////////////////
//  These procedures use the SRS830 lockins' data buffers to perform fast scans.
//  Up to 512 samples per second may be recorded.


/// triggers a reading. the left and right displayed values will be stored in the SRS's buffer.
/// This command may be called up to 16383 times, at which point the SRS's memory will be full.
/// Time taken is ~3 milliseconds
function SRSFastTrig(srs)
	variable srs
	execute "GPIB device "+num2istr(srs)
	execute "gpibwrite \"TRIG\""
End

// read out the entire SRS buffer for a given channel
// channel is 1 or 2 -- are we reading the left or right display?
// data are stored in "SRSSlurpData" wave
// Time taken is ~1.4 millisecond per datapoint plus ~30 milliseconds setup time
function SRSFastSlurp(srs,channel)
	variable srs, channel
	Variable/G junkvariable
	variable i, chunksize=200
	
	//// first, get the number of points in the buffer.
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite  \"SPTS? \""
	execute "GPIBread/T=\"\n\" junkvariable"
	
	/// make the wave. we'll read in chunks so timeouts don't occur.
	make /d/o/n=(junkvariable) SRSSlurpData
	make /d/o/n=(chunksize) SRSSlurpChunk
	i=0 /// i = # of points read so far.
	variable readsize
	do
		readsize = min(chunksize, numpnts(srsslurpdata)-i)
		execute "gpibwrite \"TRCB ? "+num2str(channel)+", "+num2str(i)+", " + num2str(readsize) + "\""
		/// junkvariable holds the number of read points.
		execute "gpibreadbinarywave /b /f=3 /l SRSSlurpChunk"
		srsslurpdata[i,i+readsize-1] = srsslurpchunk[p-i]
		i+= readsize
	while(i < numpnts(srsslurpdata))
End

// read out the entire SRS buffer for a given channel
// channel is 1 or 2 -- are we reading the left or right display?
// data are stored in "SRSSlurpData" wave
// Time taken is ~1.4 millisecond per datapoint plus ~30 milliseconds setup time
function SRSFastSlurpL(srs,channel)
	variable srs, channel
	Variable/G junkvariable
	variable i, chunksize=100
	
	//// first, get the number of points in the buffer.
	execute "GPIB device "+num2istr(srs)
	execute "GPIBwrite  \"SPTS? \n \""
	execute "GPIBread/T=\"\n\" junkvariable"
	
	/// make the output wave.
	make /d/o/n=(junkvariable) SRSSlurpData

	// we'll read in chunks so timeouts don't occur.
	make /W/o/n=(chunksize*2) SRSSlurpChunk
	i=0 /// i = # of points read so far.
	variable readsize
	do
		readsize = min(chunksize, numpnts(srsslurpdata)-i)
		execute "gpibwrite \"TRCL ? "+num2str(channel)+", "+num2str(i)+", " + num2str(readsize) + "\n\""
		execute "gpibreadbinarywave /f=2 /w /b SRSSlurpChunk"
		srsslurpdata[i,i+readsize-1] = srsslurpchunk[2*(p-i)]*2^(srsslurpchunk[2*(p-i)+1]-124)
		i+= readsize
	while(i < numpnts(srsslurpdata))
End

// Uses SRSFastSlurpL to read out both channels X and Y. The channels are then stored in
//  a complex wave called SRSSlurpDataC -- X value in the real part, Y value in the imaginary part.
function SRSFastSlurpC(srs)
	variable srs
		
	SRSFastSlurpL(srs,1)
	wave srsslurpdata
	duplicate /o srsslurpdata SRSSlurpDataX
	SRSFastSlurpL(srs,2)
	duplicate /o srsslurpdata SRSSlurpDataY
	
	make /d/c/o/n=(numpnts(srsslurpdata)) SRSSlurpDataC
	SRSSlurpDataC = cmplx(srsslurpdatax[p], srsslurpdatay[p])
End


// Set up the SRS for a fast measurement.
// By default one data point is taken each time SRSFastTrig() is called.
function SRSFastSetup(srs)
	variable srs
	execute "GPIB device "+num2istr(srs)
	execute "NI488 ibtmo "+num2istr(srs)+", 11"  // one second timeouts
	execute "GPIBwrite  \"SRAT 14 \n\""   /// One sample acquired per trigger.
	execute "GPIBwrite  \"TSTR 1 \n\""     /// Scanning starts on a trigger (software or TTL)
	execute "GPIBwrite  \"FAST 0 \n\""     /// fast mode doesn't work, so disable it.
	execute "GPIBwrite  \"SEND 1 \n\""    /// After buffer is full, just loop it.
	execute "GPIBwrite  \"REST \n\""       /// Empty the data buffer.
	execute "GPIBwrite  \"DDEF 1, 0, 0 \n\""    // Set CH1 to X
	execute "GPIBwrite  \"DDEF 2, 0, 0 \n\""    // Set CH2 to Y
End

//// Acquires many points of SRS data, as fast as possible (a frequency of 512 Hz)
/// This can go for at most 32 seconds, after which the SRS buffer is full.
/// data stored in SRSSlurpData.
function SRSFastvsTime(srs,waittime)
	variable srs, waittime
	if(waittime > 32.1)
		waittime = 32.1
	endif
	SRSFastSetup(srs)
	execute "GPIBwrite \"SRAT 13 \"" /// sample rate to 512 Hz
	execute "GPIBwrite \"SEND 0 \""    /// After buffer is full, stop scanning.
	SRSFastTrig(srs)
	sleep /s waittime
	execute "GPIBwrite  \"PAUS \"" /// finished the scan.
	SRSFastSlurpL(srs,1)
	wave srsslurpdata
	setscale /p x,0,1/512,srsslurpdata
end


// takes a fast-sampling scan of SRS and computes power spectral density.
//  scan takes about 16 seconds plus ~8 seconds of download time.
// outputs:
//       srsspectrometer_real: Raw data, with a power-of-2 length.
//                 X-scale: time,    Y-scale: Volts
//       srsspectrometer_power: Power spectral density.
//			X-scale: frequency;   Y-scale: Volts^2/Hz
//       srsspectrometer_int: Integrated power; the difference taken at two different frequencies gives mean square.
//                 X-scale: frequency;   Y-scale: Volts^2
//       srsspectrometer_amplitude: Square root of power spectral density.
//                 X-scale: frequency;   Y-scale: Volts/sqrt(Hz)
//
// To compute noise rms over a given bandwidth (frequency f1 to f2):
//       print sqrt(area(srsspectrometer_power,f1,f2))
// To compute noise ***density*** over a given bandwidth (frequency f1 to f2):
//       print sqrt(area(srsspectrometer_power,f1,f2)/(f2-f1))
// Optional parameters:
//  pass gain=1000 for example, to divide out gain of 1000 from the raw data.
//  pass win=1 to add a hann window (disregards data near start and end -- better if there is some sloping).
function SRSSpectrometer(srs,[gain,win])
	variable srs, gain,win
	if(paramisdefault(gain))
		gain = 1
	endif
	
	SRSFastvsTime(srs,16.1) // scan slightly more than 16 seconds to give just over a power of 2 in datapoints.
	
	wave srsslurpdata
	// chop the data down to a power of 2 points (This will be 8192 points, if all goes well)
	redimension /n=(2^floor(ln(numpnts(srsslurpdata))/ln(2))) srsslurpdata
	
	// rescale
	duplicate /o srsslurpdata srsspectrometer_real
	srsspectrometer_real = srsslurpdata/gain
	
	// apply window if desired, and compute FFT.
	if(win == 1)
		duplicate /o srsspectrometer_real srsspectrometer_win
		srsspectrometer_win -= mean(srsspectrometer_real)
		srsspectrometer_win *= sqrt(2/3)*(1-cos(2*pi*p/dimsize(srsspectrometer_win,0)))
		FFT/Out=4/DEST=srsspectrometer_power srsspectrometer_win
	else
		FFT/Out=4/DEST=srsspectrometer_power srsspectrometer_real 
	endif
	
	// convert FFT data to a useful form.
	wave /z power = $("srsspectrometer_power")
	power *= 2*dimdelta(srsslurpdata,0)/(dimsize(srsslurpdata,0))
	power[0] = 0
	duplicate /o power srsspectrometer_amplitude
	srsspectrometer_amplitude = sqrt(power)
	integrate power /d=srsspectrometer_int
end


function SRSSpectrometerLoop(srs,[gain,win])
	variable srs, gain,win
	if(paramisdefault(gain))
		gain = 1
	endif
	SRSSpectrometer(srs,gain=gain,win=win)
	wave srsspectrometer_power
	duplicate /o srsspectrometer_power srsspectrometer_sum srsspectrometer_avg
	
	dowindow /k SRSSpectrum
	display /n=SRSSpectrum srsspectrometer_avg
	doupdate
	modifygraph log=1
	doupdate
	variable num = 1
	do
		SRSSpectrometer(srs,gain=gain,win=win)
		srsspectrometer_sum += srsspectrometer_power
		srsspectrometer_avg = srsspectrometer_sum/num
		num+=1
		doupdate
	while(1)
end
