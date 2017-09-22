#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// this driver requires the VISA XOP to be installed

// this could be much better....
// if you are using this device to take a lot of data
// consider reading the manual and updating the use of the buffer 
// and how time series data is acquired

// Nik -- Jan 2016

///////////////////////////////////////////
//////   COMM TEST    ///////////
///////////////////////////////////////////

function TestADC()
	// testing if communication with DT ADC works
      // all you need to do is find the correct IP address to test it out
	variable defaultRM=0, status = 0, inst
	string ip_address = "DT8824-B8.local::inst0" // change this to the correct address!
	string resourceName 
	sprintf resourceName, "TCPIP0::%s::INSTR", ip_address

	status = viOpenDefaultRM(defaultRM)
	if (status < 0)
		abort "Resource Manager not open."
	endif
	
	viOpen(defaultRM, resourceName, 0, 0, inst)
	if (status != 0)
		viClose(defaultRM)
		abort "Problem opening instrument."
	endif
	
	// read/write/print some stuff here
	sleep /S 0.2
	VISAWrite inst, "*IDN?\r\n" 
	if (V_flag == 0)	// Problem with communication
		viClose(defaultRM)
		print V_flag
		print V_status
		abort "Write failed."
	endif
	
	string response
	VISARead /T="\r\n" inst, response
	if (V_flag == 0)	// Problem with communication
		abort "Read failed."
	endif
	
	print response
	
	viClose(inst)
	viClose(defaultRM)
End

///////////////////////////
////// SETUP ////////
//////////////////////////

function InitDT8824(channels, [gain, frequency, chunk])
	// setup Data Translation DT8824 ADC
	// this thing is going to assume you want the same settings for all channels

	string channels // comma-separated list of channels to enable (channels are 1-4 not 0-3)
				    // for example: channels = "1,3" is a valid input
	variable gain, frequency, chunk
	variable nChannels, i
	variable /g dt8824_gain, dt8824_high, dt8824_low, dt8824_frequency, dt8824_chunk
	string /g dt8824_channels, cmd
	nvar V_value
	dt8824_channels = ReplaceString(" ", channels, "" )
	nChannels = ItemsInList(dt8824_channels, ",")
	
	// checks input channels
	// especially: abort if channel number out of range, i.e. contains <=0 or >4
	if (nChannels<=0 || nChannels>=5)
		abort "Wrong number of channels. Available channels are 1 to 4. Example: InitDT8824(\"1,3,4\")."
	endif 
	make/o validChannels	= {1,2,3,4}
	cmd = ""
	for (i=0; i<nChannels; i+=1)
		sprintf cmd, "FindValue /V=%d validChannels", str2num(StringFromList(i, channels, ","))
		execute cmd
		if (V_value == -1)
			abort "Channels are 1-4, not 0-3."
		endif
	endfor
	
	
	cmd=""
	
	SetupAddrDT8824() // setup global variable for IP address
	svar dt8824_addr
	
	CheckPWstateDT8824() // enable password protected functions
	
	// enable channels
	writeDT8824(":AD:ENAB OFF, (@1:4)") // turn all channels off
	sprintf cmd, ":AD:ENAB ON, (@%s)", dt8824_channels // enable proper channels
	writeDT8824(cmd)
	
	// setup gain
	// dt8824_high and dt8824_low are in Volts
	if(paramisdefault(gain) || gain ==1 )
		dt8824_gain = 1
		dt8824_high = 10.0 
		dt8824_low = -10.0 
	elseif(gain==8)
		dt8824_gain = 8
		dt8824_high = 1.25
		dt8824_low = -1.25
	elseif(gain==16)
		dt8824_gain = 16
		dt8824_high = 0.625
		dt8824_low = -0.625
	elseif(gain==32)
		dt8824_gain = 32
		dt8824_high = 0.3125
		dt8824_low = -0.3125
	else
		abort "Enter a vaild gain (1,8,16,32)"
	endif
	sprintf cmd, ":AD:GAIN %d,(@%s)", dt8824_gain,  dt8824_channels
	writeDT8824(cmd) // write gain settings
	
	// setup sample clock
	if(paramisdefault(frequency))
		dt8824_frequency = 4800
	elseif(frequency >= 1.175 && frequency <= 4800)
		dt8824_frequency = frequency
	else
		abort "Enter a valid clock frequency (1.175-4800Hz)"
	endif
	
	// only finite sized chunks of data can be read from 
	// the buffer in a single AD:FETCH call
	// dt8824_chunk is an integer < 512 that sets this size
	if(paramisdefault(chunk))
		switch( nChannels )
		// dt8824_chunk is about 1000/nChannels.
			case 1:
				dt8824_chunk = 1000
				break
			case 2:
				dt8824_chunk = 500
				break
			case 3:
				dt8824_chunk = 330
				break
			case 4:
				dt8824_chunk = 250
				break
			default:
				// not possible, checked at start of function
				break
		endswitch
	else
		dt8824_chunk = chunk
	endif
	
	// setup some waves for readings (only works for 1 channel now)
	make /O/B/U/N=(4*dt8824_chunk*nChannels+20) dt_response_wave
	make /O/N=(dt8824_chunk, nChannels) dt_val_wave
	make /O/N=(dt8824_chunk, nChannels) dt_readings
	
	// write clock frequency setting
	writeDT8824(":AD:CLOC:SOUR INT")
	sprintf cmd, ":AD:CLOC:FREQ %.2f", dt8824_frequency
	writeDT8824(cmd)
	// this thing only has set frequencies available
	// grab it and set the global variable correctly
	dt8824_frequency = str2num(queryDT8824("AD:CLOCK:FREQ?"))

	writeDT8824(":AD:BUFF:MODE WRA") // set buffer mode to wrap
	writeDT8824(":AD:TRIG:SOUR IMM") // set trigger to immediate

end

function SetupAddrDT8824()
	// if you cannot find the IP address of the ADC
	// try using the National Instruments NI-MAX tool
	// it is most likely installed on your machine
	string /g dt8824_addr =  "TCPIP0::DT8824-B8.local::inst0::INSTR"
end

///////////////////////////////////////////////
////// READ/WRITE/QUERY //////
///////////////////////////////////////////////

// if you need to do many of these operations in a row
// it is best to avoid closing the visa session

function writeDT8824(cmd)
	string cmd
	variable defaultRM=0, dt8824=0
	svar dt8824_addr
	
	viOpenDefaultRM(defaultRM)
	viOpen(defaultRM, dt8824_addr, 0, 0, dt8824)
	
	VISAWrite dt8824, cmd+"\r\n" 
	if (V_flag == 0)
		abort "Write failed."
	endif
	
	viClose(dt8824)
	viClose(defaultRM)

	return 1
end

function /S readDT8824()
	string cmd
	variable defaultRM=0, dt8824=0
	svar dt8824_addr
	string response
	
	viOpenDefaultRM(defaultRM)
	viOpen(defaultRM, dt8824_addr, 0, 0, dt8824)
	
	VISARead /T="\r\n" dt8824, response
	if (V_flag == 0)
		abort "Read failed."
	endif
	
	viClose(dt8824)
	viClose(defaultRM)
	
	return response
end

function /S queryDT8824(cmd)
	string cmd
	variable defaultRM=0, dt8824=0
	svar dt8824_addr
	
	viOpenDefaultRM(defaultRM)
	viOpen(defaultRM, dt8824_addr, 0, 0, dt8824)
	
	VISAWrite dt8824, cmd+"\r\n" 
	if (V_flag == 0)
		abort "Write failed."
	endif
	
	string response
	VISARead /T="\r\n" dt8824, response
	if (V_flag == 0)
		abort "Read failed."
	endif
	
	viClose(dt8824)
	viClose(defaultRM)
	
	return response
end

///////////////////////////
////// STATUS //////
//////////////////////////

function CheckPWstateDT8824()
	// most of the commands to actually talk to this thing are password protected
	// enable password protected commands
	// default password is admin
	// i see no reason to change it, or why an ADC requires this level of security
	string response
	response = queryDT8824(":SYST:PASS:CEN:STAT?")
	if(str2num(response) == 1) // commands already enabled
		// print "PASSWORD SUCCESS!"
		return 1
	else
		writeDT8824(":SYST:PASS:CEN admin")
		sleep /S 0.1
		response = queryDT8824(":SYST:PASS:CEN:STAT?")
		if(str2num(response) == 1) // commands now enabled
			// print "PASSWORD SUCCESS!"
			return 1
		else
			abort "PASSWORD ERROR"
		endif
	endif
	abort "ERROR enabling password protected commands"
end

function /S getStatusDT8824()
	// get status bits
	// see page 104 of the SCPI manual for details
	string response, binResponse
	variable numResponse
	response = queryDT8824("AD:STAT?")
	numResponse = str2num(response)
	sprintf binResponse, "%08b", numResponse
	return binResponse
end

//////////////////////////////////////
//// READ FUNCTIONS ////
//////////////////////////////////////

function DT_Readings2Voltages()
	
	wave dt_response_wave, dt_val_wave
	variable i=0, j=0, nChannels
	variable big_int
	nvar dt8824_high, dt8824_low, dt8824_chunk
	nChannels = dimsize(dt_val_wave,1)
	variable start =20, step = 4*nChannels

	for(i=start; i<numpnts(dt_response_wave);i+=step)
		for(j=0; j<nChannels;j+=1)
			dt_val_wave[(i-start)/step][j] = dt_response_wave[i+4*j]*2^24 + dt_response_wave[i+4*j+1]*2^16 + dt_response_wave[i+4*j+2]*2^8 + dt_response_wave[i+4*j+3]*2^0
		endfor
	endfor
	
	dt_val_wave *= (1/(2^32-1))*(dt8824_high-dt8824_low)
	dt_val_wave += dt8824_low
	dt_val_wave *= 1000 // this final result will be in mV
end

function getTimeSeriesDT8824(length, [update])
	// get 'length' seconds of new data
	// this relies on DT_Readings2Voltages
	// it is kind of slow
	// it might not use the buffer in the smartest way
	// it works, though
	// update = 0 --> no plot updates while measuring
	// at some point the buffer will fill up and the index will go back to index=0 and break this code
	// that will happen after 106s with 4 channels at 4800Hz (8MB of data)
	variable length, update
	variable nChannels=0, nRead=0, i=0, maxIndex = 0, delay
	variable defaultRM=0, dt8824
	string cmd = "", response = ""
	svar dt8824_channels, dt8824_addr
	nvar dt8824_frequency, dt8824_chunk
	wave dt_response_wave, dt_val_wave
	
	if(paramisdefault(update))
		update = 0 // do not update plots
	else
		update = update
	endif
	
	nChannels = dimsize(dt_val_wave,1)
	nRead = ceil(length*dt8824_frequency/dt8824_chunk) // how many chunks to read
	delay = floor(dt8824_chunk/dt8824_frequency/0.01)*0.01 // delay time rounded down to 10ms

	make /o/n=(nRead*dt8824_chunk,nChannels) dt_readings=NaN
	setscale x 0, nRead*dt8824_chunk/dt8824_frequency, dt_readings

	viOpenDefaultRM(defaultRM)
	viOpen(defaultRM, dt8824_addr, 0, 0, dt8824)
	
//	// check status //
//	string binResponse
//	variable numResponse
//	VISAWrite dt8824, "AD:STAT?"+"\r\n" 
//	VISARead /T="\r\n" dt8824, response
//	sprintf binResponse, "%08b", numResponse
//	print binResponse

	VISAWrite dt8824, ":AD:ARM"+"\r\n" // arm measurement subsystem (clears buffer)
	VISAWrite dt8824, ":AD:INIT"+"\r\n"   // trigger readings to start
	sleep /S delay

	for(i=0;i<nRead;i+=1)
		if(maxIndex<(dt8824_chunk*(i+1)))
			do
				VISAWrite dt8824, ":AD:STATus:SCAn?"+"\r\n" 
				VISARead /T="\r\n" dt8824, response
				maxIndex = str2num(StringFromList(1, response, ","))	
			while(maxIndex<(dt8824_chunk*(i+1))) // stop when the number of readings stored in buffer is greater than requested number
		endif	
		sprintf cmd, "AD:FETCh? %d, %d", dt8824_chunk*i, dt8824_chunk
		VISAWrite dt8824, cmd+"\r\n" 
		VISARead /T="\r\n" dt8824, response
		VISAReadBinaryWave dt8824, dt_response_wave // should be able to do the converstion to 32-bit integer in this line
		DT_Readings2Voltages()
		dt_readings[i*dt8824_chunk, (i+1)*dt8824_chunk-1][] = dt_val_wave[mod(p,dt8824_chunk)][q]
		if(update!=0)
			doupdate
		endif
	endfor

	VISAWrite dt8824, ":AD:ABOR"+"\r\n" // stop data acquisition
	
	viClose(dt8824)
	viClose(defaultRM)

end