#pragma rtGlobals=3		// Use modern global access method and strict wave access.
function testtry()
	variable i = 0
	print GetMixChTemp()
	Variable error = GetRTError(1)
	if (error != 0)
		Print "Error getting mixing chamber temperature."
	else
		print "No errors."
	endif
end