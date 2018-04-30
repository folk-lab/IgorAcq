#pragma rtGlobals=1		// Use modern global access method.

// Find the manual for using this device at
// http://centrum.feld.cvut.cz/?download=_/download%2Fpristroje/eg-g-5210-en.pdf

//Edited by Mohammad Nov 10, 2013

//This reads EG&G5210 and returns the measurement in Volts or Amps depending on the 
function ReadEggX()  //takes 300 ms!! are you kidding me?
	nvar egg
	//NVAR deviceId = root:egg5210
	//Refer to page 6-21 of the manual for justification of obtaining the absolute voltage amplitude
	Variable /g eggO, eggSC, eggX
	Variable senRange

	//execute "GPIB device "+num2istr(deviceId)
	execute "GPIB device "+num2istr(egg)
	execute "GPIBwrite /F=\"%s\\0\" \"N\""
	execute "GPIBread /T=\"\\0\" eggO"

	//execute "GPIB device "+num2istr(deviceId)
	execute "GPIB device "+num2istr(egg)
	execute "GPIBwrite /F=\"%s\\0\" \"X\""
	execute "GPIBread /T=\"\\0\" eggX"

	//execute "GPIB device "+num2istr(deviceId)
	execute "GPIB device "+num2istr(egg)
	execute "GPIBwrite /F=\"%s\\0\" \"SEN\""
	execute "GPIBread /T=\"\\0\" eggSC"

	senRange = (1+(2*mod(eggSC,2)))*10^( floor(eggSC/2) - 7 )
	//senRange=0.0003
	//return senRange
	//print senrange
	//return eggX*senRange * 10^(-4)
	
	
	if (!(eggO & 2) && !(eggO & 4) )
		return eggX*senRange * 10^(-4)
	elseif (eggO & 2)
		return eggX*senRange * 10^(-12)
	elseif (eggO & 4)
		return eggX*senRange * 10^(-10)
	endif
end

function ReadEggY()
	NVAR deviceId = root:egg5210
	//Refer to page 6-21 of the manual for justification of obtaining the absolute voltage amplitude
	Variable /g eggO, eggSC, eggX
	Variable senRange

	execute "GPIB device "+num2istr(deviceId)
	execute "GPIBwrite /F=\"%s\\0\" \"N\""
	execute "GPIBread /T=\"\\0\" eggO"

	execute "GPIB device "+num2istr(deviceId)
	execute "GPIBwrite /F=\"%s\\0\" \"Y\""
	execute "GPIBread /T=\"\\0\" eggX"

	execute "GPIB device "+num2istr(deviceId)
	execute "GPIBwrite /F=\"%s\\0\" \"SEN\""
	execute "GPIBread /T=\"\\0\" eggSC"

	senRange = (1+(2*mod(eggSC,2)))*10^( floor(eggSC/2) - 7 )

	if (!(eggO & 2) && !(eggO & 4) )
		return eggX*senRange * 10^(-4)
	elseif (eggO & 2)
		return eggX*senRange * 10^(-13)
	elseif (eggO & 4)
		return eggX*senRange * 10^(-15)
	endif
end


// Sets the sensitivity of EG&G 5210
// Expected values are
// 100E-9, 300E-9, 1E-6, 3E-6, 10E-6, 30E-6, 100E-6, 300E-6, 1E-6, 3E-6, 10E-6, 30E-6, 100E-6, 300E-6, 
function setEggSensitivity(v)
	variable v
	NVAR egg5210 = root:egg5210
	variable n
	n = round(2*log(v) + 14)
	if (n > -1 && n < 16)
		execute "GPIB device "+num2istr(egg5210)
		execute "GPIBwrite/F=\"%s\\0\" \"SEN " + num2istr(n) + "\""	
	else
		print "ERROR: the sensitivity value is not in the range of acceptable values. The value should be in Volts."
	endif
end

//If you want the function to run faster, you can send the sensitivity to the function (in Volts).
//Then the function doesn't need to read the sensitivity range from the device.
//It will assume your value
// 3e0, 1e0, 300e-3, etc
function ReadEggXfast(sen)  //this takes ~66ms, an improvement over 300ms
	variable sen
	nvar egg
	//NVAR deviceId = root:egg5210
	//Refer to page 6-21 of the manual for justification of obtaining the absolute voltage amplitude
	Variable /g eggO, eggSC, eggX

	//execute "GPIB device "+num2istr(deviceId)
	execute "GPIB device "+num2istr(egg)
	execute "GPIBwrite /F=\"%s\\0\" \"X\""
	execute "GPIBread /T=\"\\0\" eggX"
	return eggX*sen*1e-4
end


//Amplitude in volts
function setEggAmplitude(v)
	variable v
	nvar egg
	if (v<=2 && v>=0)
		v=v*1000 //egg wants milivolts
	else
		print "You can't set a value higher than 2 volts or less than 0 volts to EG&G5210"
		return 0
	endif
	execute "GPIB device "+num2istr(egg)
	execute "GPIBwrite/F=\"%s\\0\" \"OA " + num2istr(v) + "\""
end