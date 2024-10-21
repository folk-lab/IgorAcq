#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

// 2D device scans 
// Written by Ray Su 
// ruihengsu@gmail.com

function readSRSt_ZERO(srsID, fdID, channel2D, theta0, theta_min, cB_period, delay) //Units: rad
	variable srsID, fdID, theta0, theta_min, cB_period, delay // cb period expected in mV 
	string channel2D // Fastdac channel for the BBG gate
	variable response, delta_max
	
	delta_max = 2*cb_period // maxmimum change is 2 times the cB period
	response = str2num(queryInstr(srsID, "OUTP? 4\n"))
	
	variable i = 0 
	variable k = 8
	variable di, setpoint
	
	if (abs(response - theta0) > theta_min)
		do
			di = delta_max/(5*2^k)
			setpoint = i*di
			RampMultipleFDAC(fdID, channel2D, setpoint)
			sc_sleep(delay)
			response = str2num(queryInstr(srsID, "OUTP? 4\n"))	
			i = i + 1
		while (abs(response - theta0) > 3 && i < 5*2^k)
	endif 
	sc_sleep(1)
	response = str2num(queryInstr(srsID, "OUTP? 4\n"))
	return response
end


// readSRSt_ZERO_V2(srs4, fd2, "BBGx111", 0, 5, 500) Example function call 
function readSRSt_ZERO_V2(srsID, fdID, channel2D, theta0, theta_min, cB_period) //Units: rad
	variable srsID, fdID, theta0, theta_min, cB_period // cb period expected in mV 
	string channel2D // Fastdac channel for the BBG gate
	variable response, delta_max
	
	variable cumulativeSum = 0 // To store the cumulative sum of responses
	variable iterationCount = 0 // To count the number of iterations
	variable runningAverage // To store the running average
	
	Make /N=3/O waveResponseHistory
	
	delta_max = 2*cb_period // maxmimum change is 2 times the cB period
	
	variable j = 0
	do	
		sc_sleep(0.1)
		response = str2num(queryInstr(srsID, "OUTP? 4\n"))	// Measure
		waveResponseHistory[j] = response	
		j += 1
	while (j <= 2)

	variable i
	variable k
	variable di, setpoint
	
	setpoint = 0
	if (abs(mean(waveResponseHistory) - theta0) > theta_min) // if THETA IS not acceptable
		do	
			if (abs(response) > 90) 
				k = 6
				di = delta_max/(5*2^k)
				setpoint += di // Increase the set point 
				RampMultipleFDAC(fdID, channel2D, setpoint) // INCREASE V2D
				sc_sleep(0.1)
			else
				k = 9
				di = delta_max/(5*2^k)
				setpoint += di // Increase the set point 
				RampMultipleFDAC(fdID, channel2D, setpoint) // INCREASE V2D
				sc_sleep(0.1)
			endif 
			
			response = str2num(queryInstr(srsID, "OUTP? 4\n"))	// Measure
			
			i = 1
			do
				waveResponseHistory[i-1] = waveResponseHistory[i]
				i += 1
			while(i < 3)
			i = 1
			// Store the new response in the last position
			waveResponseHistory[4] = response
		
		while (abs(mean(waveResponseHistory) - theta0) > theta_min && abs(setpoint) < delta_max)
	endif 
	
	if (abs(setpoint) > delta_max && abs(mean(waveResponseHistory) - theta0) > theta_min)
		response = readSRSt_ZERO_V2(srsID, fdID, channel2D, theta0, theta_min, cB_period)
		return response 
	else
		sc_sleep(1)
		response = str2num(queryInstr(srsID, "OUTP? 4\n"))		
		return response
	endif
end

//readSRSt_ZERO_V3(srs4, fd2, "BBGx111", 10, 500, 11);

function readSRSt_ZERO_V3(srsID, fdID, channel2D, dT_max, cB_period, npts, ) //Units: rad
	variable srsID, fdID, dT_max, cB_period, npts 
	string channel2D // Fastdac channel for the BBG gate
	
	variable multipoint = 5
	Make /N=(multipoint)/O THETA_0
	
	variable j = 0
	do	
		asleep(0.3)
		THETA_0[j] = abs(str2num(queryInstr(srsID, "OUTP? 4\n"))) // get value for phase
		j += 1
	while (j <= multipoint-1)
	
	variable THETA_AVG = mean(THETA_0)
	
	if (THETA_AVG < dT_max || abs(THETA_AVG - 180) < dT_max)
		return mean(THETA_0)
	else
		print("Re-adjusting operating point")
		
		variable scale = 2
		variable i = 0
		
		double V_0 = getFDACOutput(fdID, 8)
		variable zero_crossing = 0
		double PEAK_X, PEAK_Y 
		PEAK_Y = 0
		do 
		    Make /N=(npts)/O HIST_Y // recording of SET current 
			Make /N=(npts)/O HIST_X // recording of SET POINT 
			i = 0
			double dV_window = cB_period/(2^scale)
			double dV = dV_window/(npts - 1)
			double setpoint
			do 
				setpoint = V_0 - dV_window/2 + i*dV
	//			print setpoint
				RampMultipleFDAC(fdID, channel2D, setpoint) // INCREASE V2D
				if (i == 0)
					sc_sleep(2)
				else
					sc_sleep(1)
				endif 
				HIST_Y[i] = str2num(queryInstr(srsID, "OUTP? 1\n"))
				HIST_X[i] = setpoint
				
				if (i==0 && PEAK_Y == 0)
					PEAK_Y = HIST_Y[0]
					PEAK_X = HIST_X[0]
				endif 
				
				if (abs(HIST_Y[i]) > abs(PEAK_Y))
					PEAK_Y = HIST_Y[i]
					PEAK_X = HIST_X[i]
				endif 
				print HIST_X[i] 
				print HIST_Y[i]
				i += 1
			while(i < npts)
			
			double minValue, maxValue 
			
			[minValue, maxValue] = WaveMinAndMax(HIST_Y)
			
			if (minValue*maxValue < 0)
				zero_crossing = 1
			endif
			
			scale = scale - 1
			npts = npts*2
			
		while (zero_crossing == 0 && scale >= 0)
		
		RampMultipleFDAC(fdID, channel2D, PEAK_X)
		sc_sleep(2)
		
		j = 0
		do	
			THETA_0[j] = abs(str2num(queryInstr(srsID, "OUTP? 4\n"))) // get current value for phase
			asleep(0.3)
			j += 1
		while (j <= multipoint-1)
		return mean(THETA_0)
	endif 
end

function readSRSt_ZERO_V3_GRAD(srsID, fdID, channel2D, dT_max, cB_period, npts, VMAX, delay) //Units: rad
	variable srsID, fdID, dT_max, cB_period, npts, VMAX, delay
	string channel2D // Fastdac channel for the BBG gate
	variable direction = 1 // sets the direction of how channel2D of fdID will be adjusted 
	variable multipoint = 2
	Make /N=(multipoint)/O THETA_0
	
	variable j = 0
	do	
		asleep(delay)
		THETA_0[j] = abs(str2num(queryInstr(srsID, "OUTP? 4\n"))) // get value for phase
		j += 1
	while (j <= multipoint-1)
	
	variable THETA_AVG = mean(THETA_0)
	
	if (THETA_AVG < dT_max || abs(THETA_AVG - 180) < dT_max)
		return mean(THETA_0)
	else
		print("Adjusting operating point of SET")
		
		variable i = 0
		
		// get starting value of the fastdac		
		double V0 = getFDACOutput(fdID, 8)
		
		if (abs(V0 + cB_period) > VMAX) // reset the 2D gate back to 0
			RampMultipleFDAC(fdID, channel2D, 0)
			V0 = 0
			sc_sleep(delay*5)
		endif
		
		// estimate the local derivative by doing a second order finite difference approximation 
		double h = cB_period/npts // step size in finite difference
		
		double PEAK_X, PEAK_Y, PEAK_idx
		PEAK_Y = 0
		
	
	    Make /N=(npts)/O HIST_Y // recording of SET current 
		Make /N=(npts)/O HIST_X // recording of SET POINT 
		double setpoint, grad, new_grad, R0, R1
		variable peaked = 0
		
		setpoint = V0
		sc_sleep(delay)
		HIST_Y[0] = str2num(queryInstr(srsID, "OUTP? 1\n"))
		HIST_X[0] = setpoint
		
		print HIST_X[0] 
		print HIST_Y[0]
		
		PEAK_Y = HIST_Y[0]
		PEAK_X = HIST_X[0]
		PEAK_idx = 0
		
		grad = 0
		
		i = 1
		do 
			setpoint = V0 + i*h
			RampMultipleFDAC(fdID, channel2D, setpoint) // INCREASE V2D
			sc_sleep(delay)

			HIST_Y[i] = str2num(queryInstr(srsID, "OUTP? 1\n"))
			HIST_X[i] = setpoint
			
			if (abs(HIST_Y[i]) > abs(PEAK_Y))
				PEAK_Y = HIST_Y[i]
				PEAK_X = HIST_X[i]
				PEAK_idx = i
			endif 
			print HIST_X[i] 
			print HIST_Y[i]
			
			new_grad = (HIST_Y[i] - HIST_Y[i-1])/(HIST_X[i] - HIST_X[i-1])
			if (new_grad*grad < 0)
				peaked = 1
			endif 
			grad = new_grad
			i += 1
		while(i < npts && peaked == 0)
		
		
		h = max(abs(HIST_X[PEAK_idx-1] - HIST_X[PEAK_idx+1]), 0.4)/ceil(npts/2)
		peaked = 0
		Make /N=(ceil(npts/2))/O HIST_Y // recording of SET current 
		Make /N=(ceil(npts/2))/O HIST_X // recording of SET POINT 

		V0 = HIST_X[PEAK_idx-1]
		RampMultipleFDAC(fdID, channel2D, V0)
		
		sc_sleep(1)
		HIST_Y[0] = str2num(queryInstr(srsID, "OUTP? 1\n"))
		HIST_X[0] = V0
		
		print HIST_X[0] 
		print HIST_Y[0]
		
		PEAK_Y = HIST_Y[0]
		PEAK_X = HIST_X[0]
		PEAK_idx = 0
		grad = 0
		
		i = 1
		do 
			setpoint = V0 + i*h
			RampMultipleFDAC(fdID, channel2D, setpoint) // INCREASE V2D
			sc_sleep(delay)

			HIST_Y[i] = str2num(queryInstr(srsID, "OUTP? 1\n"))
			HIST_X[i] = setpoint
			
			if (abs(HIST_Y[i]) > abs(PEAK_Y))
				PEAK_Y = HIST_Y[i]
				PEAK_X = HIST_X[i]
				PEAK_idx = i
			endif 
			print HIST_X[i] 
			print HIST_Y[i]
			
			new_grad = (HIST_Y[i] - HIST_Y[i-1])/(HIST_X[i] - HIST_X[i-1])
			if (new_grad*grad < 0)
				peaked = 1
			endif 
			grad = new_grad
			i += 1
		while(i < ceil(npts/2) && peaked == 0)
		
		
		sc_sleep(delay)
		
//		j = 0
//		do	
//			THETA_0[j] = abs(str2num(queryInstr(srsID, "OUTP? 4\n"))) // get current value for phase
//			asleep(delay)
//			j += 1
//		while (j <= multipoint-1)
		return abs(str2num(queryInstr(srsID, "OUTP? 4\n")))
	endif 
end

function local_grad(srsID, fdID, channel2D, h, delay)
	variable srsID, fdID, h, delay
	string channel2D
	
	double V0 = getFDACOutput(fdID, 8)
	double R0, R1 
	
	RampMultipleFDAC(fdID, channel2D, V0 - h)
	sc_sleep(delay)
	R0 = str2num(queryInstr(srsID, "OUTP? 1\n"))
	RampMultipleFDAC(fdID, channel2D, V0 + h)
	sc_sleep(delay)
	R1 = str2num(queryInstr(srsID, "OUTP? 1\n"))
	
	return (R1 - R0)/(2*h)
end

function readSRSt_ZERO_Gradient(srsID, fdID, channel2D, dT_max, cB_period, npts, VMAX, learning_rate, tol) //npts is max number of iterations 
	variable srsID, fdID, dT_max, cB_period, npts, VMAX, learning_rate, tol
	string channel2D // Fastdac channel for the BBG gate
	
	variable multipoint = 5
	Make /N=(multipoint)/O THETA_0
	
	// read a phase value by averaging over multiple measurements
	variable j = 0
	do	
		asleep(0.3)
		THETA_0[j] = abs(str2num(queryInstr(srsID, "OUTP? 4\n"))) // get value for phase
		j += 1
	while (j <= multipoint-1)
	
	variable THETA_AVG = mean(THETA_0)
	
	if (THETA_AVG < dT_max || abs(THETA_AVG - 180) < dT_max)
		return mean(THETA_0)
	else
		print("Adjusting operating point of SET")
		
		variable i = 0
		
		// get starting value of the fastdac		
		double V0 = getFDACOutput(fdID, 8)
		
		if (abs(V0 + cB_period) > VMAX) // reset the 2D gate back to 0
			RampMultipleFDAC(fdID, channel2D, 0)
			V0 = 0
			sc_sleep(1)
		endif
		
		// estimate the local derivative by doing a second order finite difference approximation 
		double h = cB_period/npts // step size in finite difference
		double new_setpoint, setpoint, grad, R0, R1
		
		variable conv = 0
		
		Make /N=(npts*2)/O HIST_Y // recording of SET current 
		Make /N=(npts*2)/O HIST_X // recording of SET POINT 
		
		setpoint = V0
		do  
//			grad = local_grad(srsID, fdID, channel2D, h, 1)
			
			
			RampMultipleFDAC(fdID, channel2D, setpoint - h)
			sc_sleep(1)
			R0 = str2num(queryInstr(srsID, "OUTP? 1\n"))
			RampMultipleFDAC(fdID, channel2D, setpoint + h)
			sc_sleep(1)
			R1 = str2num(queryInstr(srsID, "OUTP? 1\n"))
			grad = (R1 - R0)/(2*h)
			
			
			new_setpoint = setpoint + learning_rate*grad
			
			if (abs(learning_rate*grad) > tol)
				setpoint = new_setpoint 
				RampMultipleFDAC(fdID, channel2D, setpoint)
				sc_sleep(1)
			else 
				conv = 1
			endif
		while(i < npts && conv == 0) // while less than maximum iteration and not converged
		
			 

//			i = 0
//			double dV_window = cB_period/(2^scale)
//			double dV = dV_window/(npts - 1)
//			double setpoint
//			do 
//				setpoint = V_0 - dV_window/2 + i*dV
//	//			print setpoint
//				
//				if (i == 0)
//					sc_sleep(2)
//				else
//					sc_sleep(1)
//				endif 
//				HIST_Y[i] = str2num(queryInstr(srsID, "OUTP? 1\n"))
//				HIST_X[i] = setpoint
//				
//				if (i==0 && PEAK_Y == 0)
//					PEAK_Y = HIST_Y[0]
//					PEAK_X = HIST_X[0]
//				endif 
//				
//				if (abs(HIST_Y[i]) > abs(PEAK_Y))
//					PEAK_Y = HIST_Y[i]
//					PEAK_X = HIST_X[i]
//				endif 
//				print HIST_X[i] 
//				print HIST_Y[i]
//				i += 1
//			while(i < npts)
//			
//			double minValue, maxValue 
//			
//			[minValue, maxValue] = WaveMinAndMax(HIST_Y)
//			
//			if (minValue*maxValue < 0)
//				zero_crossing = 1
//			endif
//			
//			scale = scale - 1
//			npts = npts*2
//			
//		
//		RampMultipleFDAC(fdID, channel2D, PEAK_X)
//		sc_sleep(2)
//		
//		j = 0
//		do	
//			THETA_0[j] = abs(str2num(queryInstr(srsID, "OUTP? 4\n"))) // get current value for phase
//			asleep(0.3)
//			j += 1
//		while (j <= multipoint-1)
//		return mean(THETA_0)
	endif 
end

macro LOCK_in_params()
print("BBG")
print "VBBG", getsrsamplitude(srs4)
print "Freq", getsrsfrequency(srs4)
print "TC", getsrstimeConst(srs4)
print "Phase", getsrsphase(srs4)
print "Sensitivity", getsrsSensitivity(srs4)/1e3

print("Back gate")
print "VBG", getsrsamplitude(srs2)
print "Freq", getsrsfrequency(srs2)
print "TC", getsrstimeConst(srs2)
print "Phase", getsrsphase(srs2)
print "Sensitivity", getsrsSensitivity(srs2)/1e3
//
//print("BBG two Omega")
//print "TC",getsrstimeConst(srs1)
//print "Phase", getsrsphase(srs1)
//print "Sensitivity", getsrsSensitivity(srs1)/1e3
endmacro 

function initCompressibilityDirection(direction)
	variable direction //  +1 for increasing VBBG, -1 for decreasing VBBG
	variable/G CompDir = direction
endmacro 


function initPIDCompressibilityDirection(direction, fdid_PID)
	variable direction, fdid_PID //  0 for increasing VBBG, 1 for decreasing VBBG
	variable/G CompDirPID = direction
	Make /N=2/O V2D_history
	setPIDDir(fdid_PID, direction)
endmacro 


function getFADCchannel_PID(fdid, fdid_PID, channel, delta_max, delay, [len_avg])
	// Instead of just grabbing one single datapoint which is susceptible to high f noise, this averages data over len_avg and returns a single value
	variable fdid, fdid_PID, channel, delta_max, delay, len_avg
	nvar CompDirPID // 0 or 1
	wave V2D_history
	len_avg = paramisdefault(len_avg) ? 0.03 : len_avg
	
	variable numpts = ceil(getFADCspeed(fdid)*len_avg)
	if(numpts <= 0)
		numpts = 1
	endif
	
	fd_readChunk(fdid, num2str(channel), numpts)  // Creates fd_readChunk_# wave	

	wave w = $"fd_readChunk_"+num2str(channel)
	wavestats/q w
	wave/t fadcvalstr
	fadcvalstr[channel][1] = num2str(v_avg)
	
	V2D_history[0] = V2D_history[1]
	V2D_history[1] = V_avg
	//print(V2D_history[1] - V2D_history[0])
	if (abs(V2D_history[1] - V2D_history[0]) > delta_max)
		asleep(delay)
	endif
	return V_avg
end

//function find_mid_point(fdid, numpts, delay)
//variable fdid, numpts, delay 
//
//make /N=(numpts)/O ISETDC_HIST 
//
//variable i=0 
//
//
//end



function readSRSt_ZERO_V4_GRAD(srsID, fdID, channel2D, dT_max, cB_period, npts, VMAX, delay) //Units: rad
	variable srsID, fdID, dT_max, cB_period, npts, VMAX, delay
	string channel2D // Fastdac channel for the BBG gate
	nvar CompDir
	 // sets the direction of how channel2D of fdID will be adjusted 
	variable multipoint = 2
	Make /N=(multipoint)/O THETA_0, THETA_0_ABS
	variable j = 0
	do	
		asleep(delay)
		THETA_0[j] = str2num(queryInstr(srsID, "OUTP? 4\n")) // get value for phase
		THETA_0_ABS[j] = abs(THETA_0[j])
		j += 1
	while (j <= multipoint-1)
	
	variable THETA_AVG = mean(THETA_0)
	variable THETA_ABS_AVG = mean(THETA_0_ABS)
	
	if (THETA_ABS_AVG < dT_max || abs(THETA_ABS_AVG - 180) < dT_max)
		return THETA_AVG
	else
		print("Adjusting operating point of SET")
		
		variable i = 0
		
		// get starting value of the fastdac		
		double V0 = getFDACOutput(fdID, 8)
		double max_window = V0 + CompDir*cB_period
		if (abs(max_window) > VMAX)
			CompDir = CompDir*-1
		endif
		
		// estimate the local derivative by doing a second order finite difference approximation 
		double h = cB_period/npts // step size in finite difference
		
		double PEAK_X, PEAK_Y, PEAK_idx
		PEAK_Y = 0
		
	
	    Make /N=(npts)/O HIST_Y // recording of SET current 
		Make /N=(npts)/O HIST_X // recording of SET POINT 
		double setpoint, grad, new_grad, R0, R1
		variable peaked = 0
		
		setpoint = V0
		sc_sleep(delay)
		HIST_Y[0] = str2num(queryInstr(srsID, "OUTP? 1\n"))
		HIST_X[0] = setpoint
		
		print HIST_X[0] 
		print HIST_Y[0]
		
		PEAK_Y = HIST_Y[0]
		PEAK_X = HIST_X[0]
		PEAK_idx = 0
		
		grad = 0
		
		i = 1
		do 
			setpoint = V0 + CompDir*i*h
			RampMultipleFDAC(fdID, channel2D, setpoint) // INCREASE V2D
			sc_sleep(delay)

			HIST_Y[i] = str2num(queryInstr(srsID, "OUTP? 1\n"))
			HIST_X[i] = setpoint
			
			if (abs(HIST_Y[i]) > abs(PEAK_Y))
				PEAK_Y = HIST_Y[i]
				PEAK_X = HIST_X[i]
				PEAK_idx = i
			endif 
			print HIST_X[i] 
			print HIST_Y[i]
			
			new_grad = (HIST_Y[i] - HIST_Y[i-1])/(HIST_X[i] - HIST_X[i-1])
			if (new_grad*grad < 0)
				peaked = 1
			endif 
			grad = new_grad
			i += 1
		while(i < npts && peaked == 0)
		
		
		h = max(abs(HIST_X[PEAK_idx-1] - HIST_X[PEAK_idx+1]), 0.4)/ceil(npts/2)
		peaked = 0
		Make /N=(ceil(npts/2))/O HIST_Y // recording of SET current 
		Make /N=(ceil(npts/2))/O HIST_X // recording of SET POINT 

		V0 = HIST_X[PEAK_idx-1]
		RampMultipleFDAC(fdID, channel2D, V0)
		
		sc_sleep(1)
		HIST_Y[0] = str2num(queryInstr(srsID, "OUTP? 1\n"))
		HIST_X[0] = V0
		
		print HIST_X[0] 
		print HIST_Y[0]
		
		PEAK_Y = HIST_Y[0]
		PEAK_X = HIST_X[0]
		PEAK_idx = 0
		grad = 0
		
		i = 1
		do 
			setpoint = V0 + CompDir*i*h
			RampMultipleFDAC(fdID, channel2D, setpoint) // INCREASE V2D
			sc_sleep(delay)

			HIST_Y[i] = str2num(queryInstr(srsID, "OUTP? 1\n"))
			HIST_X[i] = setpoint
			
			if (abs(HIST_Y[i]) > abs(PEAK_Y))
				PEAK_Y = HIST_Y[i]
				PEAK_X = HIST_X[i]
				PEAK_idx = i
			endif 
			print HIST_X[i] 
			print HIST_Y[i]
			
			new_grad = (HIST_Y[i] - HIST_Y[i-1])/(HIST_X[i] - HIST_X[i-1])
			if (new_grad*grad < 0)
				peaked = 1
			endif 
			grad = new_grad
			i += 1
		while(i < ceil(npts/2) && peaked == 0)
		
		V0 = HIST_X[PEAK_idx]
		RampMultipleFDAC(fdID, channel2D, V0)
		print "Ramp to", V0
		
		sc_sleep(delay)
		
//		j = 0
//		do	
//			THETA_0[j] = abs(str2num(queryInstr(srsID, "OUTP? 4\n"))) // get current value for phase
//			asleep(delay)
//			j += 1
//		while (j <= multipoint-1)
		return str2num(queryInstr(srsID, "OUTP? 4\n"))
	endif 
end




function readSRSx_ZERO(srsID, fdID, channel2D, delta_max, cB_period, npts, VMAX, delay) //Units: rad
	variable srsID, fdID, delta_max, cB_period, npts, VMAX, delay
	string channel2D // Fastdac channel for the BBG gate
	variable rescale = 1e4/(getsrsSensitivity(srsID)/1e3)
	
	nvar CompDir
	
	 // sets the direction of how channel2D of fdID will be adjusted 
	variable multipoint = 2
	Make /N=(multipoint)/O READING
	
	variable j = 0
	do	
		asleep(delay)
		READING[j] = rescale*str2num(queryInstr(srsID, "OUTP? 1\n")) // get value for x
		j += 1
	while (j <= multipoint-1)
	
	variable READING_AVG = mean(READING)
	
	if (abs(READING_AVG) < delta_max)
		return READING_AVG/rescale
	else
		print("Adjusting operating point of SET")
		
		variable i = 0
		
		// get starting value of the fastdac		
		double V0 = getFDACOutput(fdID, 8)
		double max_window = V0 + CompDir*cB_period
		if (abs(max_window) > VMAX)
			CompDir = CompDir*-1
		endif
		
		double h = cB_period/npts 
		
		double MIN_X, MIN_Y, MIN_idx
	
	    Make /N=(npts)/O HIST_Y // recording of SET current 
		Make /N=(npts)/O HIST_X // recording of SET POINT 
		double setpoint, R0, R1
		variable peaked = 0

		setpoint = V0
		sc_sleep(delay)
		HIST_Y[0] = rescale*str2num(queryInstr(srsID, "OUTP? 1\n"))
		HIST_X[0] = setpoint
		
		print HIST_X[0] 
		print HIST_Y[0]
		
		MIN_Y = HIST_Y[0]
		MIN_X = HIST_X[0]
		MIN_idx = 0
		
		i = 1
		do 
			setpoint = V0 + CompDir*i*h
			RampMultipleFDAC(fdID, channel2D, setpoint) // INCREASE V2D
			sc_sleep(delay)

			HIST_Y[i] = rescale*str2num(queryInstr(srsID, "OUTP? 1\n"))
			HIST_X[i] = setpoint
			
			if (abs(HIST_Y[i]) < abs(MIN_Y)) // if the new value is closer to zero than the previous value 
				MIN_Y = HIST_Y[i]
				MIN_X = HIST_X[i]
				MIN_idx = i
			endif 
			print "Iteration", i
			print "V2Dx111", HIST_X[i] 
			print HIST_Y[i]
			
			
			if (HIST_Y[i]*HIST_Y[i-1] < 0)
				peaked = 1
			endif 
			i += 1
		while(i < npts && peaked == 0)
		
		V0 = HIST_X[MIN_idx-1]
		RampMultipleFDAC(fdID, channel2D, V0)
		
		h = max(abs(3*h), 0.4)/ceil(npts/2)
		peaked = 0
		Make /N=(ceil(npts/2))/O HIST_Y // recording of SET current 
		Make /N=(ceil(npts/2))/O HIST_X // recording of SET POINT 

		
	
		sc_sleep(delay)
		HIST_Y[0] = rescale*str2num(queryInstr(srsID, "OUTP? 1\n"))
		HIST_X[0] = V0
		
		print HIST_X[0] 
		print HIST_Y[0]
		
		MIN_Y = HIST_Y[0]
		MIN_X = HIST_X[0]
		MIN_idx = 0
		
		i = 1
		do 
			setpoint = V0 + CompDir*i*h
			RampMultipleFDAC(fdID, channel2D, setpoint) // INCREASE V2D
			sc_sleep(delay)

			HIST_Y[i] = rescale*str2num(queryInstr(srsID, "OUTP? 1\n"))
			HIST_X[i] = setpoint
			
			if (abs(HIST_Y[i]) < abs(MIN_Y))
				MIN_Y = HIST_Y[i]
				MIN_X = HIST_X[i]
				MIN_idx = i
			endif 
			print "Fine iteration", i
			print "V2Dx111", HIST_X[i] 
			print HIST_Y[i]
			
			if (HIST_Y[i]*HIST_Y[i-1] < 0)
				peaked = 1
			endif 
			i += 1
		while(i < ceil(npts/2) && peaked == 0)
		
		V0 = HIST_X[MIN_idx]
		RampMultipleFDAC(fdID, channel2D, V0)
		print "Ramp to", V0
		
		sc_sleep(delay)
		return str2num(queryInstr(srsID, "OUTP? 1\n"))
	endif 
end


function readSRSx_ZERO_two_omega(srsID, srsID_two_omega, fdID, channel2D, dT_max, cB_period, npts, VMAX, delay) //Units: rad
	variable srsID, srsID_two_omega, fdID, dT_max, cB_period, npts, VMAX, delay
	string channel2D // Fastdac channel for the BBG gate
	
	
	variable rescale = 1e4/(getsrsSensitivity(srsID_two_omega)/1e3)
	
	nvar CompDir
	
	 // sets the direction of how channel2D of fdID will be adjusted 
	variable multipoint = 2
	Make /N=(multipoint)/O READING
	
	variable j = 0
	do	
		asleep(delay)
		READING[j] = rescale*str2num(queryInstr(srsID_two_omega, "OUTP? 1\n")) // get value for x
		j += 1
	while (j <= multipoint-1)
	
	variable READING_AVG = mean(READING)
	
	if (abs(READING_AVG) < dT_max)
		return READING_AVG/rescale
	else
		print("Adjusting operating point of SET")
		
		variable i = 0
		
		// get starting value of the fastdac		
		double V0 = getFDACOutput(fdID, 8)
		double max_window = V0 + CompDir*cB_period
		if (abs(max_window) > VMAX)
			CompDir = CompDir*-1
		endif
		
		// estimate the local derivative by doing a second order finite difference approximation 
		double h = cB_period/npts // step size in finite difference
		
		double PEAK_X, PEAK_Y, PEAK_idx		
	
	    Make /N=(npts)/O HIST_Y // recording of SET current 
		Make /N=(npts)/O HIST_X // recording of SET POINT 
		double setpoint, grad, new_grad, R0, R1
		variable peaked = 0
		
		setpoint = V0
		sc_sleep(delay)
		HIST_Y[0] = str2num(queryInstr(srsID, "OUTP? 1\n"))
		HIST_X[0] = setpoint
		
		print "Coarse iteration", 0
		print "V2Dx111", HIST_X[0] 
		print HIST_Y[0]
		
		PEAK_Y = HIST_Y[0]
		PEAK_X = HIST_X[0]
		PEAK_idx = 0
		
		grad = 0
		
		i = 1
		do 
			setpoint = V0 + CompDir*i*h
			RampMultipleFDAC(fdID, channel2D, setpoint) // INCREASE V2D
			sc_sleep(delay)

			HIST_Y[i] = str2num(queryInstr(srsID, "OUTP? 1\n"))
			HIST_X[i] = setpoint
			
			if (abs(HIST_Y[i]) > abs(PEAK_Y))
				PEAK_Y = HIST_Y[i]
				PEAK_X = HIST_X[i]
				PEAK_idx = i
			endif 
			print "Coarse iteration", i
			print "V2Dx111", HIST_X[i] 
			print HIST_Y[i]
			
			new_grad = (HIST_Y[i] - HIST_Y[i-1])/(HIST_X[i] - HIST_X[i-1])
			if (new_grad*grad < 0)
				peaked = 1
			endif 
			grad = new_grad
			i += 1
		while(i < npts && peaked == 0)
		
		
		h = max(abs(HIST_X[PEAK_idx-1] - HIST_X[PEAK_idx+1]), 0.4)/ceil(npts/2)
		peaked = 0
		Make /N=(ceil(npts/2))/O HIST_Y2 // recording of SET current 
		Make /N=(ceil(npts/2))/O HIST_X2 // recording of SET POINT 

		V0 = HIST_X[PEAK_idx-1]
		RampMultipleFDAC(fdID, channel2D, V0)
		
		sc_sleep(1)
		HIST_Y2[0] = str2num(queryInstr(srsID, "OUTP? 1\n"))
		HIST_X2[0] = V0
		
		print "Fine iteration", 0
		print "V2Dx111", HIST_X2[0] 
		print HIST_Y2[0]
		
		double PEAK_X2, PEAK_Y2, PEAK_idx2
		
		PEAK_Y2 = HIST_Y2[0]
		PEAK_X2 = HIST_X2[0]
		PEAK_idx2 = 0
		grad = 0
		
		i = 1
		do 
			setpoint = V0 + CompDir*i*h
			RampMultipleFDAC(fdID, channel2D, setpoint) // INCREASE V2D
			sc_sleep(delay)

			HIST_Y2[i] = str2num(queryInstr(srsID, "OUTP? 1\n"))
			HIST_X2[i] = setpoint
			
			if (abs(HIST_Y2[i]) > abs(PEAK_Y2))
				PEAK_Y2 = HIST_Y2[i]
				PEAK_X2 = HIST_X2[i]
				PEAK_idx2 = i
			endif 
			print "Fine iteration", i
			print "V2Dx111", HIST_X2[i] 
			print HIST_Y2[i]
			
			new_grad = (HIST_Y2[i] - HIST_Y2[i-1])/(HIST_X2[i] - HIST_X2[i-1])
			if (new_grad*grad < 0)
				peaked = 1
			endif 
			grad = new_grad
			i += 1
		while(i < ceil(npts/2) && peaked == 0)
		
		if (abs(HIST_Y[PEAK_idx]) > abs(HIST_Y2[PEAK_idx2]))
			V0 = HIST_X[PEAK_idx]
			RampMultipleFDAC(fdID, channel2D, V0)
			print "Ramp to", V0
		else
			V0 = HIST_X2[PEAK_idx2]
			RampMultipleFDAC(fdID, channel2D, V0)
			print "Ramp to", V0
		
		endif
		sc_sleep(delay*2)
		
		return str2num(queryInstr(srsID_two_omega, "OUTP? 1\n"))
	endif 
end

function readSRSx_HIGHSENSE(srsID) //Units: rad
	variable srsID
	setsrssensitivity(srsID, 500)
	return 0
end

function Cal_V2(V1, R1, R2, Delta)
	variable V1, R1, R2, Delta 
	return R2*(V1/R1 - Delta) 
end

function Cal_Delta(V1, V2, R1, R2)
	variable V1, V2, R1, R2 
	return V1/R1 - V2/R2
end

function Cal_shift(iset_dc, A, freq, D0)
	variable iset_dc, A, freq, D0
	variable diff = iset_dc-D0
	if (abs(diff) > A)
		diff = A
	endif
	
	double xi = asin((diff)/A)/freq
	
    double d1, d2, d3
    d1 = 0 - xi
    d2 = pi/freq - xi
    d3 = -1*pi/freq - xi
    
    print d1, d2, d3
    
	return d1
end

function rampfastdacdelta(instrID, instrID2, R1, R2, Delta, channels, channels2, setpoint)
variable instrID, instrID2, Delta, R1, R2, setpoint
string channels, channels2

RampMultipleFDAC(instrID, channels, setpoint);
RampMultipleFDAC(instrID2, channels2, Cal_V2(setpoint, R1, R2, Delta));
end

function Scan2FastDacSlow(instrID, instrID2, start, fin, R1, R2, Delta, channels, channels2, numpts, delay, ramprate, iset_dc, A, freq, D0, [y_label, comments, nosave]) //Units: mV
	// Scans two channels from two different fastdacs
	// instrID is the main fast dac, which is swept from start to fin 
	// instrID2 is the secondary fastdac
	// R1 and R2 are voltage divider ratios
	// Delta is the voltage difference that is maintained between channels of instrID and instrID2 
	// channels should be a comma-sepa, rated string ex: "0, 4, 5"
	variable instrID, instrID2, start, fin, , R1, R2, Delta, numpts, delay, ramprate, nosave, iset_dc, A, freq, D0
	string y_label, channels, channels2, comments
	
	// Reconnect instruments
	sc_openinstrconnections(0)

	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	

	// Initialize ScanVars
	struct ScanVars S  // Note, more like a BD scan if going slow
	initScanVars(S, \
				 instrIDx=instrID, \
				 startx=start, \
				 finx=fin, \
				 numptsx=numpts, \
				 delayx=delay, \
				 rampratex=ramprate,\
				 instrIDy=instrID2, \
				 starty= Cal_V2(start, R1, R2, Delta), \
				 finy= Cal_V2(fin, R1, R2, Delta), \
				 numptsy=numpts, \
				 delayy=delay, \
				 rampratey=ramprate,\
				 y_label=y_label, \
				 comments=comments)
	 
	S.is2d=0
		
	RampMultipleFDAC(instrID, channels, start);
	RampMultipleFDAC(instrID2, channels2, Cal_V2(start, R1, R2, Delta));


	// Let gates settle 
	sc_sleep(10)

	// Make Waves and Display etc
	InitializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpoint, setpoint2, shift
	do
		setpoint = start + (i*(fin-start)/(S.numptsx-1))  //the 2nd Keithley, y corresponds to i
		setpoint2 = Cal_V2(setpoint, R1, R2, Delta)  //the 1st Keithley, x corresponds to j
		

		RampMultipleFDAC(instrID, channels, setpoint);
		RampMultipleFDAC(instrID2, channels2, setpoint2);
		sc_sleep(S.delayx)
		
//		iset_dc = getFADCchannel(instrID, 0)
//		shift = Cal_shift(iset_dc, A, freq, D0)
//		start = start - shift
//		fin = fin - shift
//		setpoint = start + (i*(fin-start)/(S.numptsx-1))  //the 2nd Keithley, y corresponds to i
//		setpoint2 = Cal_V2(setpoint, R1, R2, Delta)  //the 1st Keithley, x corresponds to j
		
		RecordValues(S, i, j)
		i+=1
		j+=1
		
	while (i<S.numptsy&&j<S.numptsx)
	
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		dowindow /k SweepControl
	endif
end



function ScanFastDacSlow_Feedback(instrID, instrID2, start, fin, R1, R2, channels, channels2, numpts, delay, ramprate, A, freq, D0, [y_label, comments, nosave]) //Units: mV
	// Scans two channels from two different fastdacs
	// instrID is the main fast dac, which is swept from start to fin 
	// instrID2 is the secondary fastdac
	// R1 and R2 are voltage divider ratios
	// Delta is the voltage difference that is maintained between channels of instrID and instrID2 
	// channels should be a comma-sepa, rated string ex: "0, 4, 5"
	variable instrID, instrID2, start, fin, , R1, R2, numpts, delay, ramprate, nosave, A, freq, D0
	string y_label, channels, channels2, comments
	
	// Reconnect instruments
	sc_openinstrconnections(0)

	// Set defaults
	comments = selectstring(paramisdefault(comments), comments, "")
	y_label = selectstring(paramisdefault(y_label), y_label, "")
	

	// Initialize ScanVars
	struct ScanVars S  // Note, more like a BD scan if going slow
	initScanVars(S, \
				 instrIDx=instrID, \
				 startx=start, \
				 finx=fin, \
				 numptsx=numpts, \
				 delayx=delay, \
				 rampratex=ramprate,\
				 instrIDy=instrID2, \
				 numptsy=numpts, \
				 delayy=delay, \
				 rampratey=ramprate,\
				 y_label=y_label, \
				 comments=comments)
	 
	S.is2d=0
		
	RampMultipleFDAC(instrID, channels, start);
//	RampMultipleFDAC(instrID2, channels2, Cal_V2(start, R1, R2, Delta));


	// Let gates settle 
	sc_sleep(3)

	// Make Waves and Display etc
	InitializeScan(S)

	// Main measurement loop
	variable i=0, j=0, setpoint, setpoint2, shift, Delta, iset_dc
	variable VBGxR1, V2DxR2
	do
		setpoint = start + (i*(fin-start)/(S.numptsx-1))  //the 2nd Keithley, y corresponds to i
		RampMultipleFDAC(instrID, channels, setpoint);
		
		sc_sleep(S.delayx)
		
		iset_dc = getFADCchannel(instrID, 0) // measure the DC current 
		shift = Cal_shift(iset_dc, A, freq, D0) // calculate the expected shift 
		
		VBGxR1 = getfDACOutput(instrID, 1);
		V2DxR2 = getfDACOutput(instrID2, 8);
		
		Delta = Cal_delta(VBGxR1, V2DxR2, R1, R2)
		start = start + shift
		fin = fin + shift
		setpoint = start + (i*(fin-start)/(S.numptsx-1))
		setpoint2 = Cal_V2(setpoint, R1, R2, Delta)  //the 1st Keithley, x corresponds to j
		RampMultipleFDAC(instrID, channels, setpoint);
		RampMultipleFDAC(instrID2, channels2, setpoint2);
		
		sc_sleep(S.delayx)
		RecordValues(S, i, j)
		i+=1
		j+=1
		
	while (i<S.numptsy&&j<S.numptsx)
	
	
	// Save by default
	if (nosave == 0)
		EndScan(S=S)
	else
		dowindow /k SweepControl
	endif
end