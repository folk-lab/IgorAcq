//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////// Measurement Utilities   //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


function/wave average_to_1d(w)
	wave w
	duplicate/o w tempwave

	variable numptxs = dimsize(tempwave, 0) // 1 = number of columns ,,, 0 = number of rows
	make/O/N=(numptxs) temp_average

	variable i
	for(i=0;i<numptxs;i++)
		duplicate/o/r=[i][] tempwave tempwave_1d
		temp_average[i] = mean(tempwave_1d)
	endfor

	return temp_average
end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Setting up AWG ///////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
function makeSquareWaveAWG(instrID, v0, vP, vM, v0len, vPlen, vMlen, wave_num, [ramplen])  // TODO: move this to Tim's igor procedures
   // Make square waves with form v0, +vP, v0, -vM (useful for Tim's Entropy)
   // Stores copy of wave in Igor (accessible by fd_getAWGwave(wave_num))
   // Note: Need to call, fd_setupAWG() after making new wave
   // To make simple square wave set length of unwanted setpoints to zero.
   variable instrID, v0, vP, vM, v0len, vPlen, vMlen, wave_num
   variable ramplen  // lens in seconds
   variable max_setpoints = 26


	ramplen = paramisdefault(ramplen) ? 0.003 : ramplen

	if (ramplen < 0)
		abort "ERROR[makeSquareWaveAWG]: Cannot use a negative ramplen"
	endif

    // Open connection
    sc_openinstrconnections(0)

   // put inputs into waves to make them easier to work with
   make/o/free sps = {v0, vP, v0, vM} // CHANGE refers to output
   make/o/free lens = {v0len, vPlen, v0len, vMlen}

   // Sanity check on period
   // Note: limit checks happen in AWG_RAMP
   if (sum(lens) > 1)
      string msg
      sprintf msg "Do you really want to make a square wave with period %.3gs?", sum(lens)
      variable ans = ask_user(msg, type=1)
      if (ans == 2)
         abort "User aborted"
      endif
   endif
   // Ensure that ramplen is not too long (will never reach setpoints)
   variable i=0
   for(i=0;i<numpnts(lens);i++)
    if (lens[i] < ramplen && lens[1] != 0)
      msg = "Do you really want to ramp for longer than the duration of a setpoint? You will never reach the setpoint"
      ans = ask_user(msg, type=1)
      if (ans == 2)
         abort "User aborted"
      endif
    endif
   endfor


    // Get current measureFreq to calculate require sampleLens to achieve durations in s
   variable measureFreq = getFADCmeasureFreq(instrID)
   variable numSamples = 0

   // Make wave
   variable j=0, k=0
   variable setpoints_per_ramp = floor((max_setpoints - numpnts(sps))/numpnts(sps)) // points per section in square wave by setting points per square wave
   variable ramp_step_size = min(setpoints_per_ramp, floor(measureFreq * ramplen)) // used points per section in square wave. Comparing setpoints_per_ramp to measured points
   variable ramp_setpoint_duration = 0

   if (ramp_step_size != 0)
     ramp_setpoint_duration = ramplen / ramp_step_size
   endif

   // make wave to store setpoints/sample_lengths, correctly sized
   make/o/free/n=((numpnts(sps)*ramp_step_size + numpnts(sps)), 2) awg_sqw

   //Initialize prev_setpoint to the last setpoint
   variable prev_setpoint = sps[numpnts(sps) - 1]
   variable ramp_step = 0
   for(i=0;i<numpnts(sps);i++)
      if(lens[i] != 0)  // Only add to wave if duration is non-zero
         // Ramps happen at the beginning of a setpoint and use the 'previous' wave setting to compute
         // where to ramp from. Obviously this does not work for the first wave length, is that avoidable?
         ramp_step = (sps[i] - prev_setpoint)/(ramp_step_size + 1)
         for (k = 1; k < ramp_step_size+1; k++)
          // THINK ABOUT CASE RAMPLEN 0 -> ramp_setpoint_duration = 0
          numSamples = round(ramp_setpoint_duration * measureFreq)
          awg_sqw[j][0] = {prev_setpoint + (ramp_step * k)}
          awg_sqw[j][1] = {numSamples}
          j++
         endfor
         numSamples = round((lens[i]-ramplen)*measureFreq)  // Convert to # samples
         if(numSamples == 0)  // Prevent adding zero length setpoint
            abort "ERROR[makeSquareWaveAWG]: trying to add setpoint with zero length, duration too short for sampleFreq"
         endif
         awg_sqw[j][0] = {sps[i]}
         awg_sqw[j][1] = {numSamples}
         j++ // Increment awg_sqw position for storing next setpoint/sampleLen
         prev_setpoint = sps[i]
      endif
   endfor


    // Check there is a awg_sqw to add
   if(numpnts(awg_sqw) == 0)
      abort "ERROR[makeSquareWaveAWG]: No setpoints added to awg_sqw"
   endif

    // Clear current wave and then reset with new awg_sqw
   fd_clearAWGwave(instrID, wave_num)
   fd_addAWGwave(instrID, wave_num, awg_sqw)

   // Make sure user sets up AWG_list again after this change using fd_setupAWG()
   fd_setAWGuninitialized()
end


function SetupEntropySquareWaves([freq, cycles,hqpc_zero, hqpc_plus, hqpc_minus, channel_ratio, balance_multiplier, hqpc_bias_multiplier, ramplen])
	variable freq, cycles,hqpc_zero, hqpc_plus, hqpc_minus, channel_ratio, balance_multiplier, hqpc_bias_multiplier, ramplen

	balance_multiplier = paramIsDefault(balance_multiplier) ? 1 : balance_multiplier
	hqpc_bias_multiplier = paramIsDefault(hqpc_bias_multiplier) ? 1 : hqpc_bias_multiplier
	freq = paramisdefault(freq) ? 12.5 : freq
	cycles = paramisdefault(cycles) ? 1 : cycles
	hqpc_plus = paramisdefault(hqpc_plus) ? 50 : hqpc_plus
	hqpc_minus = paramisdefault(hqpc_minus) ? -50 : hqpc_minus
	channel_ratio = paramisdefault(channel_ratio) ? -1.478 : channel_ratio  //Using OHC, OHV
	ramplen = paramisdefault(ramplen) ? 0 : ramplen
	hqpc_zero = paramisdefault(hqpc_zero) ? 0 : hqpc_zero
	nvar fd

	variable splus = hqpc_plus*hqpc_bias_multiplier, sminus=hqpc_minus*hqpc_bias_multiplier
	variable cplus=splus*channel_ratio * balance_multiplier, cminus=sminus*channel_ratio * balance_multiplier

	variable spt
	// Make square wave 0
	spt = 1/(4*freq)  // Convert from freq to setpoint time /s  (4 because 4 setpoints per wave)
	makeSquareWaveAWG(fd, hqpc_zero, splus, sminus, spt, spt, spt, 0, ramplen=ramplen)
	// Make square wave 1
	makeSquareWaveAWG(fd, hqpc_zero, cplus, cminus, spt, spt, spt, 1, ramplen=ramplen)

	// Setup AWG
	setupAWG(fd, AWs="0,1", DACs="OHC(10M),OHV*9950", numCycles=cycles, verbose=1)
end


function SetupEntropySquareWaves_unequal([freq, cycles, hqpc_plus, hqpc_minus, ratio_plus, ratio_minus, balance_multiplier, hqpc_bias_multiplier, ramplen])
	variable freq, cycles, hqpc_plus, hqpc_minus, ratio_plus, ratio_minus, balance_multiplier, hqpc_bias_multiplier, ramplen

	balance_multiplier = paramIsDefault(balance_multiplier) ? 1 : balance_multiplier
	hqpc_bias_multiplier = paramIsDefault(hqpc_bias_multiplier) ? 1 : hqpc_bias_multiplier
	freq = paramisdefault(freq) ? 12.5 : freq
	cycles = paramisdefault(cycles) ? 1 : cycles
	hqpc_plus = paramisdefault(hqpc_plus) ? 50 : hqpc_plus
	hqpc_minus = paramisdefault(hqpc_minus) ? -50 : hqpc_minus
	ratio_plus = paramisdefault(ratio_plus) ? -1.531 : ratio_plus
	ratio_minus = paramisdefault(ratio_minus) ? -1.531 : ratio_minus
	ramplen = paramisdefault(ramplen) ? 0 : ramplen

	nvar fd

	variable splus = hqpc_plus*hqpc_bias_multiplier, sminus=hqpc_minus*hqpc_bias_multiplier
	variable cplus=splus*ratio_plus * balance_multiplier, cminus=sminus*ratio_minus * balance_multiplier

	variable spt
	// Make square wave 0
	spt = 1/(4*freq)  // Convert from freq to setpoint time /s  (4 because 4 setpoints per wave)
	makeSquareWaveAWG(fd, 0, splus, sminus, spt, spt, spt, 0, ramplen=ramplen)
	// Make square wave 1
	makeSquareWaveAWG(fd, 0, cplus, cminus, spt, spt, spt, 1, ramplen=ramplen)

	// Setup AWG
	setupAWG(fd, AWs="0,1", DACs="HO1/10M,HO2*1000", numCycles=cycles)
end






////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Charge sensor functions ///////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////

function GetTargetCSCurrent([oldcscurr, lower_lim, upper_lim, nosave])
	// A rough outline for a new correctchargesensor function. Currently relies on defaults in CorrectChargeSensor
	// To be implemented into CorrectChargeSensor after some testing
	variable oldcscurr, lower_lim, upper_lim, nosave
	nvar fd
	string channelstr = "CSQ"

	channelstr = scu_getChannelNumbers(channelstr, fastdac=1)

	lower_lim = paramisdefault(lower_lim) ? 1 : lower_lim
	upper_lim = paramisdefault(upper_lim) ? 3 : upper_lim
	nosave = paramisdefault(nosave) ? 1 : nosave

	// Begin by calling CorrectChargeSensor with default things
	if (paramisDefault(oldcscurr))
		CorrectChargeSensor(fd=fd, fdchannelstr=channelstr, fadcID=fd, fadcchannel=0, check=0, direction=1)
		oldcscurr = getFADCvalue(fd, 0, len_avg=0.3)
	else
		CorrectChargeSensor(fd=fd, fdchannelstr=channelstr, fadcID=fd, fadcchannel=0, check=0, direction=1, natarget=oldcscurr)
	endif

	// Get the current value of CSQ
	wave/T fdacvalstr
	variable oldcenter = str2num(fdacvalstr[str2num(channelstr)][1])

	// Sweep CSQ +/- 20 mV around the current setting to get the charge sensor curve
	ScanFastDAC(fd, oldcenter-20, oldcenter+20, channelstr, numptsx=10000, nosave=nosave, comments="Finding steepest part of CSQ, CSQ scan")
	wave cscurrent

	duplicate/o/free cscurrent cscurrentdiff
	cscurrentdiff = (lower_lim < cscurrent[p] && cscurrent[p] < upper_lim) ? cscurrent[p] : NaN
	wavestats/Q cscurrentdiff
	resample/DOWN=(floor((V_npnts)/50)) cscurrentdiff
	differentiate cscurrentdiff
	smooth 10, cscurrentdiff

	wavestats/Q cscurrentdiff
	variable newcenter = V_maxloc

	// If Igor gives garbage, go back to the original center and return
	if(newcenter > oldcenter + 30 || newcenter < oldcenter - 30)
		rampmultiplefdac(fd, channelstr, oldcenter)
		printf "WARNING [GetTargetCSCurrent]: Thought center of CS trace was at %.1fmV, centering at %.1fmV\n", newcenter, oldcenter
		return oldcscurr
	endif

	rampmultiplefdac(fd, channelstr, newcenter)
	variable newcscurr = getFADCvalue(fd, 0, len_avg=0.3)

	// If a strangely small or large cscurrent, ramp back to center and return
	if(newcscurr > upper_lim || newcscurr < lower_lim)
		rampmultiplefdac(fd, channelstr, oldcenter)
		printf "WARNING [GetTargetCSCurrent]: Thought natarget was at %.1fmV, using %.1fmV\n", newcscurr, oldcscurr
		return oldcscurr
	endif

	return newcscurr
end



function CorrectChargeSensor([bd, bdchannelstr, dmmid, fd, fdchannelstr, fadcID, fadcchannel, i, check, natarget, direction, zero_tol, gate_divider, cutoff_time])
//Corrects the charge sensor by ramping the CSQ in 1mV steps
//(direction changes the direction it tries to correct in)
	variable bd, dmmid, fd, fadcID, fadcchannel, i, check, natarget, direction, zero_tol, gate_divider, cutoff_time
	string fdchannelstr, bdchannelstr
	variable cdac, cfdac, current, new_current, nextdac, j
	wave/T dacvalstr
	wave/T fdacvalstr
	
	
//	rampmultipleFDAC(fd, "CSQ2*1000", 0) // ensure virtual CSQ*1000 is zero.
	
	natarget = paramisdefault(natarget) ? 1.1 : natarget // 0.22
	direction = paramisdefault(direction) ? 1 : direction
	zero_tol = paramisdefault(zero_tol) ? 0.5 : zero_tol  // How close to zero before it starts to get more averaged measurements
	gate_divider = paramisdefault(gate_divider) ? 20 : gate_divider
	cutoff_time = paramisdefault(cutoff_time) ? 30 : cutoff_time
	fadcchannel = paramisdefault(fadcchannel) ? 1 : fadcchannel

	if ((paramisdefault(bd) && paramisdefault(fd)) || !paramisdefault(bd) && !paramisdefault(fd))
		abort "Must provide either babydac OR fastdac id"
	elseif  ((paramisdefault(dmmid) && paramisdefault(fadcID)) || !paramisdefault(fadcID) && !paramisdefault(dmmid))
		abort "Must provide either dmmid OR fadcchannel"
	elseif ((!paramisdefault(bd) && paramisDefault(bdchannelstr)) || (!paramisdefault(fd) && paramisDefault(fdchannelstr)))
		abort "Must provide the channel to change for the babydac or fastdac"
	elseif (!paramisdefault(fadcid) && paramisdefault(fadcchannel))
		abort "Must provide fdadcID if using fadc to read current"
	elseif (!paramisdefault(fd) && paramisdefault(fdchannelstr))
		abort "Must provide fdchannel if using fd"
	elseif (!paramisdefault(bd) && paramisdefault(bdchannelstr))
		abort "Must provide bdchannel if using bd"
	endif

	if (!paramisdefault(fdchannelstr))
		fdchannelstr = scu_getChannelNumbers(fdchannelstr, fastdac=1)
		if(itemsInList(fdchannelstr, ",") != 1)
			abort "ERROR[CorrectChargeSensor]: Only works with 1 fdchannel"
		else
			variable fdchannel = str2num(fdchannelstr)
		endif
	elseif (!paramisdefault(bdchannelstr))
		bdchannelstr = scu_getChannelNumbers(bdchannelstr, fastdac=0)
		if(itemsInList(bdchannelstr, ",") != 1)
			abort "ERROR[CorrectChargeSensor]: Only works with 1 bdchannel"
		else
			variable bdchannel = str2num(bdchannelstr)
		endif
	endif

	sc_openinstrconnections(0)

	//get current
	if (!paramisdefault(dmmid))
		abort
//		current = read34401A(dmmid)
	else
		current = getFADCvalue(fadcID, fadcchannel, len_avg=0.5)
	endif

	variable end_condition = (naTarget == 0) ? zero_tol : 0.05*naTarget   // Either 5% or just an absolute zero_tol given
	variable step_multiplier = 1
	variable avg_len = 0.001// Starting time to avg, will increase as it gets closer to ideal value
	if (abs(current-natarget) > end_condition/2)  // If more than half the end_condition out
		variable start_time = datetime
		do
			//get current dac setting
			if (!paramisdefault(bd))
				cdac = str2num(dacvalstr[bdchannel][1])

			else
				cdac = str2num(fdacvalstr[fdchannel][1])
			endif

			if (abs(current-natarget) > 15*end_condition)
				step_multiplier = 10
			elseif (abs(current-natarget) > 10*end_condition)
				step_multiplier = 3			
			else
				step_multiplier = 1
			endif

			if (current < nAtarget)  // Choose next step direction
				nextdac = cdac+step_multiplier*(0.32*direction)*gate_divider  // 0.305... is FastDAC resolution (20000/2^16)
			else
				nextdac = cdac-step_multiplier*(0.32*direction)*gate_divider
			endif

			if (check==0) //no user input
				if (-1000*gate_divider < nextdac && nextdac < 100*gate_divider) //Prevent it doing something crazy
					if (!paramisdefault(bd))
						rampmultiplebd(bd, num2str(bdchannel), nextdac)
					else
						rampmultipleFDAC(fd, num2str(fdchannel), nextdac)
					endif
				else
					abort "Failed to correct charge sensor to target current"
				endif
			else //ask for user input
				doAlert/T="About to change DAC" 1, "Scan wants to ramp DAC to " + num2str(nextdac) +"mV, is that OK?"
				if (V_flag == 1)
					if (!paramisdefault(bd))
						rampmultiplebd(bd, num2str(bdchannel), nextdac)
					else
						rampmultipleFDAC(fd, num2str(fdchannel), nextdac)
					endif
				else
					abort "Aborted"
				endif
			endif

			//get current after dac step
			if (!paramisdefault(dmmid))
				abort "Not implemented DMM again yet"
//				current = read34401A(dmmid)
			else
				current = getFADCvalue(fadcID, fadcchannel, len_avg=avg_len)
			endif

			doupdate  // Update scancontroller window


			if ((abs(current-nAtarget) < end_condition*3) && avg_len < 0.2)  // If close to end, start averaging for at least 0.2
				avg_len = 0.2
			endif
			if (abs(current-nAtarget) < end_condition*3)  // Average longer each time when close
				avg_len = avg_len*1.2
			endif
			if (avg_len > 1)  // Max average length = 1s
				avg_len = 1
			endif
//			print avg_len
			asleep(0.05)
		while (abs(current-nAtarget) > end_condition && (datetime - start_time < cutoff_time))   // Until reaching end condition

		if (!paramisDefault(i))
			print "Ramped to " + num2str(nextdac) + "mV, at line " + num2str(i)
		endif
	endif
end



////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////// Centering Functions ////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////

function FindTransitionMid(dat, [threshold]) //Finds mid by differentiating, returns minloc
	wave dat
	variable threshold
	variable MinVal, MinLoc, w, lower, upper
	threshold = paramisDefault(threshold) ? 2 : threshold 
	wavestats/Q dat //easy way to get num notNaNs
	w = V_npnts/5 //width to smooth by (relative to how many datapoints taken)
	redimension/N=-1 dat
	smooth w, dat	//Smooth dat so differentiate works better
	duplicate/o/R=[w, numpnts(dat)-w] dat dattemp
	differentiate/EP=1 dattemp /D=datdiff
	wavestats/Q datdiff
	MinVal = V_min  		//Will get overwritten by next wavestats otherwise
	MinLoc = V_minLoc 	//
	Findvalue/V=(minVal)/T=(abs(minval/100)) datdiff //find index of min peak
	lower = V_value-w*0.75 //Region to cut from datdiff
	upper = V_value+w*0.75 //same
	if(lower < 1)
		lower = 0 //make sure it doesn't exceed datdiff index range
	endif
	if(upper > numpnts(datdiff)-2)
		upper = numpnts(datdiff)-1 //same
	endif
	datdiff[lower, upper] = NaN //Remove peak
	wavestats/Q datdiff //calc V_adev without peak
	if(abs(MinVal/V_adev)>threshold)
		//print "MinVal/V_adev = " + num2str(abs(MinVal/V_adev)) + ", at " + num2str(minloc) + "mV"
		return MinLoc
	else
		print "MinVal/V_adev = " + num2str(abs(MinVal/V_adev)) + ", at " + num2str(minloc) + "mV"
		return NaN
	endif
end


function CenterOnTransition([gate, virtual_gates, width, single_only])
	string gate, virtual_gates
	variable width, single_only

	nvar fd=fd

	gate = selectstring(paramisdefault(gate), gate, "ACC*2")
	width = paramisdefault(width) ? 20 : width

	gate = scu_getChannelNumbers(gate, fastdac=1)

	variable initial, mid
	wave/t fdacvalstr
	initial = str2num(fdacvalstr[str2num(gate)][1])

	ScanFastDAC(fd, initial-width, initial+width, gate, sweeprate=width, nosave=1)
	mid = findtransitionmid($"cscurrent", threshold=2)

	if (single_only == 0 && numtype(mid) != 2)
		ScanFastDAC(fd, mid-width/10, mid+width/10, gate, sweeprate=width/10, nosave=1)
		mid = findtransitionmid($"cscurrent", threshold=2)
	endif

	if (abs(mid-initial) < width && numtype(mid) != 2)
		rampmultiplefdac(fd, gate, mid)
	else
		rampmultiplefdac(fd, gate, initial)
		printf "CLOSE CALL: center on transition thought mid was at %dmV\r", mid
		mid = initial
	endif
	return mid
end




//////////////////////////////////////////////////////////////////////////////////////////
////////////////////////// Miscellaneous ////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////


function loadFromHDF(datnum, [no_check])
	variable datnum, no_check

	bdLoadFromHDF(datnum, no_check = no_check)
	fdLoadFromHDF(datnum, no_check = no_check)
	sc_openinstrconnections(0)  // Connections may have been messed up by the temporary connections made when setting bd/fd DACs
end


function additionalSetupAfterLoadHDF()
	// Use this function to ramp any other gates etc after loading from HDF (i.e. when loading from HDF in a function, call this after so that it's easy to load everything from HDF and then just correct a few more gates after
	nvar fd, bd
	nvar tim_global_variable1  // 2021/12/04  -- Using these to test many slightly different gate settings in an outer loop
	nvar tim_global_variable2
	nvar tim_global_variable3

	variable v1 = tim_global_variable1
	variable v2 = tim_global_variable2
	variable v3 = tim_global_variable3

//	print v1, v2, v3

	rampmultiplefdac(fd, "SDP", str2num(scf_getDacInfo("SDP", "output")) + v1)
	rampmultipleBD(bd, "SDBD", GetBDdacValue("SDBD") + v2)
	rampmultiplefdac(fd, "CSS", str2num(scf_getDacInfo("CSS", "output")) + v3)	
	rampmultiplefdac(fd, "ACC*2", str2num(scf_getDacInfo("ACC*2", "output")) - 0.5*v1 - 0.5*v2 - 0.5*v3)  // Somewhat corrected based on other changes	

	rampmultiplebd(bd, "OCSB*1000", 8.7)
end


function saveLogsOnly([msg])
	string msg
	variable save_experiment // Default: Do not save experiment for just this

	nvar filenum

	if (paramisdefault(msg))
		msg = "SaveLogsOnly"
	endif

	variable hdfid = OpenHDFFile(0)
	LogsOnlySave(hdfid, msg)
//	initSaveFiles(msg=msg, logs_only=1) // Saves logs here, and adds Logs_Only attr to root group of HDF
	closeHDFFile(num2str(hdfid))
end



function/T get_virtual_scan_params(mid, width1, virtual_mids, ratios)
	variable mid, width1
	string virtual_mids, ratios

	abort "2021/11 -- Somehow this function got lost, will need to be remade to be used again"
end



function/wave Linspace(start, fin, num)
	// An Igor substitute for np.linspace() (obviously with many caveats and drawbacks since it is in Igor...)
	//
	// To use this in command line:
	//		make/o/n=num tempwave
	// 		tempwave = linspace(start, fin, num)[p]
	//
	// To use in a function:
	//		wave tempwave = linspace(start, fin, num)  //Can be done ONCE (each linspace overwrites itself!)
	//	or
	//		make/n=num tempwave = linspace(start, fin, num)[p]  //Can be done MANY times
	//
	// To combine linspaces:
	//		make/free/o/n=num1 w1 = linspace(start1, fin1, num1)[p]
	//		make/free/o/n=num2 w2 = linspace(start2, fin2, num2)[p]
	//		concatenate/np/o {w1, w2}, tempwave
	//
	variable start, fin, num
	Make/N=2/O/Free linspace_start_end = {start, fin}
	Interpolate2/T=1/N=(num)/Y=linspaced linspace_start_end
	return linspaced
end


function calculate_virtual_starts_fins_using_ratio(sweep_mid, sweep_width, sweep_gate, virtual_gates, virtual_mids, virtual_ratios, channels, starts, fins)
	// Given the sweepgate mid/width, and the virtual gate mids/ratios, returns the full channels, starts, fins for a virtual sweep
	// Note: channels, starts, fins will be modified to have the return values (can't return more than 1 string in Igor)
	string sweep_gate, virtual_gates, virtual_mids, virtual_ratios
	string &channels, &starts, &fins // The & allows for modifying the string that was passed in
	variable sweep_mid, sweep_width
	
	if ((itemsinList(virtual_gates, ",") != itemsinList(virtual_mids, ",")) || (itemsinList(virtual_gates, ",") != itemsinList(virtual_ratios, ",")))
		abort "ERROR[calculate_virtual_starts_fins_using_ratio]: Virtual_gates, Virtual_mids, and virtual_ratios must all have the same number of items"
	endif
	
	
	starts = num2str(sweep_mid - sweep_width)
	fins = num2str(sweep_mid + sweep_width)
	channels = addlistitem(sweep_gate, virtual_gates, ",", 0)
	
	variable temp_mid, temp_ratio, temp_start, temp_fin
	variable k
	for (k=0; k<ItemsInList(virtual_gates, ","); k++)
			temp_mid = str2num(StringFromList(k, virtual_mids, ","))
			temp_ratio = str2num(StringFromList(k, virtual_ratios, ","))
			
			temp_start = temp_mid - temp_ratio*sweep_width
			temp_fin = temp_mid + temp_ratio*sweep_width
			
			starts = addlistitem(num2str(temp_start), starts, ",", inf)
			fins = addlistitem(num2str(temp_fin), fins, ",", inf)
	 endfor
	 
end



function/s wave2str(w)
	wave w
	string w2str = wave2NumArray(w)
	
	return w2str[1,strlen(w2str)-2]
end


function make_virtual_entropy_corners(x_start, y_start, x_len, y_len, y_over_x, [datnum])
	variable x_start, y_start, x_len, y_len, y_over_x, datnum
	
	
	string xs, ys
	
	///// calculate xs /////
	variable x0, x1, x2, x3
	x0 = x_start
	x1 = x_start + x_len
	x2 = x0
	x3 = x1
	xs = num2str(x0) + "," + num2str(x1) + ","	 + num2str(x2) + "," + num2str(x3) + ";"
	print xs
	
	
	///// calculate ys /////
	variable y0, y1, y2, y3
	y0 = y_start
	variable c = y0 - y_over_x*x0
	y1 = y_over_x*x1 + c
	
	y2 = y_start + y_len
	y3 = y1 + y_len
	ys = num2str(y0) + "," + num2str(y1) + ","	 + num2str(y2) + "," + num2str(y3) + ";"
	print ys
	
	if (ParamIsDefault(datnum) == 0)
		displaymultiple({datnum}, "cscurrent_2d", diff=1)
		make /o/n=4 tempfullx = {x0, x1, x2, x3}
		make /o/n=4 tempfully = {y0, y1, y2, y3}
		AppendToGraph tempfully vs tempfullx
		ModifyGraph mode(tempfully)=4, mrkThick(tempfully)=3, rgb(tempfully)=(0,65535,65535)
		
	endif
	
	
end