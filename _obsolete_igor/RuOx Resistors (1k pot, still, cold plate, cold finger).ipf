#pragma rtGlobals=1		// Use modern global access method.

/// HOW TO MEASURE:
// 1K pot: ????
// Still: CUSTOM connector on blue box beside breakout box -- use 9-pin breakout cable: pins 1-2~~~3-4
// Cold plate: CUSTOM connector as well - pins 5-6~~~7,8
// Mixing chamber: Pins 1,2,4,5 from the connector that goes to the temperature measurement system.
//      (advised to use extra-low excitation voltage for the mixing chamber resistor, and low noise!!)

macro initRuOxReader()
	loadwave /g/d/n=ruox "C:\\Documents and Settings\\dilfridge.QDOT13\\Desktop\\Local Measurement Data\\RuO2 sensor temperature resistance.txt"
	duplicate /o ruox0, ruoxln0 ; ruoxln0 = ln(ruox0)
	duplicate /o ruox1, ruoxln1 ; ruoxln1 = ln(ruox1)
	
	CurveFit/q/M=2/W=0 poly 3, ruoxln0[0,20]/X=ruoxln1
	duplicate /o w_coef ruoxlncoef
	printf "fit coefs: "
	print ruoxlncoef
	// note: these are 4-probe resistance values
end

// note: these are 4-probe resistance values !
// (2-probe is ~approx 2 kohm more due to contact resistance!)
function ruoxResToTemp(res)
	variable res
	
	wave ruoxln1, ruoxln0, ruoxlncoef
	
	if(ln(res) <= ruoxln1[0])
		findlevel /q ruox1, res
		return exp(ruoxln0(v_levelx))
	endif
	if(ln(res) >= ruoxln1[0])
		return exp(poly(ruoxlncoef,ln(res)))
	endif

	
	// interpolation to sub-zero values...
end