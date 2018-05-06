#pragma rtGlobals=1		// Use modern global access method.

function FR_k238()   //sets Keitley 238 into factory reset
	NVAR device = root:k238
	execute "GPIB device "+num2istr(device)
	execute "GPIBwrite /F=\"%s\\0\" \"J0X\""
end



function LS_k238()   //sets Keitley 238 into local sensing mode
	NVAR device = root:k238
	execute "GPIB device "+num2istr(device)
	execute "GPIBwrite /F=\"%s\\0\" \"O0X\""
end


function OP_k238()   //sets Keitley 238 into operation mode
	NVAR device = root:k238
	execute "GPIB device "+num2istr(device)
	execute "GPIBwrite /F=\"%s\\0\" \"N1X\""
end




macro Init_k238()   //sets Keitley 238 into remote (in fact it initalizes the GPIB)
variable /g k238
	NI488 ibdev 0, 16, 0, 10, 1, 0, k238
end


macro FunVoltageBias_k238()   //sets Keitley 238 into voltage Bias
	NVAR device = root:k238
	execute "GPIB device "+num2istr(device)
	execute "GPIBwrite /F=\"%s\\0\" \"F0,0X\""
end


function FunCurrentBias_k238()   //sets Keitley 238 into current  Bias
	NVAR device = root:k238
	execute "Init_k238()"
	execute "GPIB device "+num2istr(device)
	execute "GPIBwrite /F=\"%s\\0\" \"F1,0X\""
end

function SetVolts_k238(V)   //sets Keitley 238 to a voltage
	variable V
	NVAR device = root:k238
	//execute "Init_k238()"
	execute "GPIB device "+num2istr(device)
	execute "GPIBwrite /F=\"%s\\0\" \"B"+num2str(V) + ",3,500X\""
end



function SetAmps_k238(A)   //sets Keitley 238 to current
	variable A
	NVAR device = root:k238
	execute "Init_k238()"
	execute "GPIB device "+num2istr(device)
	execute "GPIBwrite /F=\"%s\\0\" \"B"+num2str(A) + ",0,500X\""
end


function readK238Curr()
	variable /g k238i, di1, di2, di3
	NVAR device = root:k238
	execute "Init_k238()"
	execute "GPIB device "+num2istr(device)
	//execute "GPIBwrite /F=\"%s\\0\" \"L1,0X\""
	execute "GPIBwrite /F=\"%s\\0\" \"G4,0,0X\""
	Sleep /s 0.01
	execute "GPIBread/T=\"\\n\"  k238i, di1,di2"
	return k238i
end

function readVoltsk238()
	variable /G k238v, d1 ,d2
	NVAR device = root:k238
	//execute "Init_k238()"
	execute "GPIB device "+num2istr(device)
	execute "GPIBwrite /F=\"%s\\0\" \"G1,0,0X\""
	execute "GPIBread/T=\"\\n\" k238v, d1, d2" //d1,d2 sacrificial dummy variables
	return k238v
end

function rampK238Volts(volts,rate) //ramps k238 voltage; smallest voltage division is 10 mV
	variable volts
	variable rate	// in mV/s
	variable initvolts, finvolts, sign1, increment
	variable A
	NVAR device = root:k238
	//execute "Init_k238()"
	initvolts = readVoltsk238()
	finvolts = volts

	A = initvolts
	increment = rate/50000
	sign1 = (finvolts-initvolts)/abs(finvolts-initvolts)
	do
		SetVolts_k238(A)
	//	sleep /s 0.005
		A += increment*sign1
	//	execute "print" + num2str(A)
	while((A*sign1)<(finvolts*sign1))
	SetVolts_k238(finvolts)
end
