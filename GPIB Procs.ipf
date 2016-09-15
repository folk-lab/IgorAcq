#pragma rtGlobals=1		// Use modern global access method.

macro initGPIB()
	variable /g dmm22
//	NI488 ibfind "dev22", dmm22
	NI488 ibdev 0, 22, 0,10, 1,0,dmm22
//	
//	variable /g dmm18
//	NI488 ibdev 0, 18, 0,10, 1,0,dmm18
////	

//	variable /g srs1
//	//NI488 ibfind "dev8", srs1
//	NI488 ibdev 0, 1, 0,10, 1,0, srs1
////	
	variable /g srs2
	//NI488 ibfind "dev8", srs8
	NI488 ibdev 0, 2, 0,10, 1,0,srs2
//	
	variable /g srs3
	//NI488 ibfind "dev8", srs8
	NI488 ibdev 0, 3, 0,10, 1,0,srs3
	
//	variable /g srs4
////	//NI488 ibfind "dev8", srs8
//	NI488 ibdev 0, 4, 0,10, 1,0,srs4

	variable /g srs5
////	//NI488 ibfind "dev8", srs8
	NI488 ibdev 0, 5, 0,10, 1,0,srs5
	
	variable /g srs6
////	//NI488 ibfind "dev8", srs8
	NI488 ibdev 0, 6, 0,10, 1,0,srs6
//
//	variable /g srs9
//	//NI488 ibfind "dev9", srs9
//	NI488 ibdev 0, 9, 0,10, 1,0,srs9
//
//	variable /g dmm23
//	//NI488 ibfind "dev23", dmm23
//	NI488 ibdev 0, 23, 0,10, 1,0,dmm23
//	
//	variable /g dmm3
//	//NI488 ibfind "dev3", dmm3
//	//NI488 ibdev 0, 3, 0,10, 1,0,dmm3
//	
	variable /g k2400
	//NI488 ibfind "dev14", k2400
	NI488 ibdev 0, 14, 0,10, 1,0,k2400	
//
//	variable /g k2300
//	//NI488 ibfind "dev24", k2300
//	NI488 ibdev 0, 24, 0,10, 1,0,k2300
//
//	//variable /g ips25
//	//NI488 ibfind "dev25", ips25
//	//NI488 ibdev 0, 25, 0,10, 1,0,ips25
//	
//	//variable /g ips24
//	//NI488 ibfind "DEV5", ips24
//	//NI488 ibdev 1, 24, 0,10, 1,0,ips24
//	
//	variable /g hp3561
//	//NI488 ibdev 0, 11, 0,10, 1,0,hp3561
//
//	variable /g hp3478a
//	NI488 ibdev 0, 18, 0,10, 1,0,hp3478a

	//variable /g hp34401a
	//NI488 ibdev 0, 22, 0,10, 1,0,hp34401a
//
//	
//	variable /g ps7
//	NI488 ibdev 0, 7, 0,10, 1,0,ps7
//
//	variable /g ppm100
//	NI488 ibdev 0, 6, 0,10, 1,0,ppm100
//	
//	variable /g egg
//	NI488 ibdev 0, 12, 0, 10, 1, 0, egg
end

macro gpib_return(srs)
	variable srs
	variable/g pad
	
	NI488 ibask srs, 1, pad
end

macro gpibprobe(devnum)
	variable devnum
	
	string devstr = "dev"+num2str(devnum)
//	print devstr
	variable /g gpibprobenum
	NI488 ibfind devstr, gpibprobenum
	gpib device gpibprobenum
	gpibwrite "*IDN?"
	string manu,model,serial,version
	gpibread manu,model,serial,version
	print manu + "  " + model + "  " + serial + "  " + version
end

macro gpibreset()
	gpib board 0
	gpib killio
	initgpib()
end

function FindListeners(address)		// Test whether the device is online
	variable address
	string cmd
	NVAR V_ibcnt
	Make/O gAddressList = {address, -1}		// -1 is NOADDR - marks end of list.
	Make/O/N=0 gResultList
	cmd="NI488 FindLstn 0, gAddressList, gResultList, 5"
	execute cmd
	if(V_ibcnt)
		return 1
	else
		return 0
	endif
End