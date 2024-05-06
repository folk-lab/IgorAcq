#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=2	// Use modern global access method and strict wave access.
#include <Resize Controls>

/// this a where all the functions that need to still be place in the proper procedure files live
macro initexperiment()
//NewPath/o fdtest "Macintosh HD:Users:labuser:temp_files:"
//NewPath/O data "Macintosh HD:Users:labuser:Dropbox:work:current_meas:temp:"
//NewPath/O data "Macintosh HD:Users:labuser:Documents:Data:Johann:2024_04_SwaggerTest:data:"
//NewPath/O fdtest "Macintosh HD:Users:labuser:Documents:Data:Johann:2024_04_SwaggerTest:temp_files:"

	create_experiment_paths()

	initscancontroller()
	
	create_variable("sc_abortsweep")
	create_variable("sc_scanstarttime")
	create_variable("sc_save_time")
	create_variable("sc_PrintRaw")
	create_variable("sc_PrintCalc")
	create_variable("sc_pause")
	create_variable("sc_instrLimit")
	create_variable("sc_cleanup")
	create_variable("sc_abortsweep")
	create_variable("sc_abortnosave")
	create_variable("sc_demody")
	create_variable("sc_hotcold")
	create_variable("sc_plotRaw")
	create_variable("filenum"); 
	create_variable("lastconfig");
	
	lastconfig = scu_unixTime()


	make/o numericwave
	//numwav2txtwav(DAC_channel);
	//numwav2txtwav(ADC_channel);
	 openFastDAC("51011", verbose = 0)

	 init_dac_and_adc("1;11")
	 initfastdac()
	 openFastDAC("51011", verbose = 0)
	 fadcattr[1][2]=48
	 
	make/o/t/n=6 sc_awg_labels
	sc_awg_labels={"DAC Channel", "Setpoints", "Samples", "Box #", "# Cycles", "Do not edit"} // this will be the sc_awg_labels for the AWG table

endmacro




function create_experiment_paths()
	// assumes the experiment has been saved so that the filepath 'home' exists
	//not tested on Windows computer
	 
	// check Mac or Windows to determine seperator
	string separator_type
	if (cmpstr(igorInfo(2), "Macintosh") == 0) // if mac
		separator_type = ":"
	elseif (cmpstr(igorInfo(2), "Windows") == 0) // if windows
		separator_type = "\\"
	endif
	 
	pathinfo home // path stored in s_path
	string master_path = ParseFilePath(1, s_path, separator_type, 1, 0)
	
	string data_path = master_path + "data" + separator_type
	string tempdata_path = master_path + "temp_data" + separator_type
	 
	NewPath/C data data_path
	NewPath/C fdtest tempdata_path

end



function numwav2txtwav(wave numwav)
make/o/t/N=(dimsize(numwav,0)) temp;
temp=num2str(numwav[p])
string wn=nameofwave(numwav)
killwaves numwav;
duplicate temp $wn
end


Window after1() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(139,320,1149,923)
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 160,45,"DAC"
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 650,45,"ADC"
	DrawLine 385,15,385,575
	SetDrawEnv linethick= 2,arrowfat= 2
	DrawLine 395,363,1000,363
	SetDrawEnv dash= 1
	DrawLine 395,363,1000,363
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 15,70,"Ch"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 50,70,"Output"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 120,70,"Limit"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 220,70,"Label"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 287,70,"Ramprate"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 405,70,"Ch"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 450,70,"Input (mV)"
	SetDrawEnv fsize= 14,fstyle= 1,textrot= -60
	DrawText 550,75,"Record"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 597,70,"wave name"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 728,70,"Calc func"
	SetDrawEnv fsize= 14,fstyle= 1,textrot= -60
	DrawText 878,74,"Notch"
	SetDrawEnv fsize= 14,fstyle= 1,textrot= -60
	DrawText 923,74,"Demod"
	SetDrawEnv fsize= 14,fstyle= 1,textrot= -60
	DrawText 972,76,"Harmonic"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 412,389,"Connect Instrument"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 632,389,"Open GUI"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 822,389,"Log Status"
	ListBox fdaclist,pos={8.00,72.00},size={356.00,428.00},fSize=14,frame=2
	ListBox fdaclist,listWave=root:fdacvalstr,selWave=root:fdacattr,mode=1,selRow=-1
	ListBox fdaclist,widths={35,70,110,65}
	Button updatefdac,pos={24.00,528.00},size={64.00,20.00},proc=scfw_update_fdac
	Button updatefdac,title="Update"
	Button fdacramp,pos={148.00,528.00},size={64.00,20.00},proc=scfw_update_fdac
	Button fdacramp,title="Ramp"
	Button fdacrampzero,pos={264.00,528.00},size={80.00,20.00},proc=scfw_update_fdac
	Button fdacrampzero,title="Ramp all 0"
	ListBox fadclist,pos={400.00,72.00},size={600.00,180.00},fSize=14,frame=2
	ListBox fadclist,listWave=root:fadcvalstr,selWave=root:fadcattr,mode=1,selRow=1
	ListBox fadclist,widths={30,70,30,95,100,30,30,20}
	Button updatefadc,pos={396.00,268.00},size={88.00,20.00},proc=scfw_update_fadc
	Button updatefadc,title="Update ADC"
	CheckBox sc_plotRawBox,pos={499.00,268.00},size={72.00,17.00},proc=scw_CheckboxClicked
	CheckBox sc_plotRawBox,title="\\Z14Plot Raw",variable=sc_plotRaw,side=1
	CheckBox sc_demodyBox,pos={580.00,272.00},size={108.00,17.00},proc=scw_CheckboxClicked
	CheckBox sc_demodyBox,title="\\Z14Save Demod.y",variable=sc_demody,side=1
	CheckBox sc_hotcoldBox,pos={814.00,312.00},size={78.00,17.00},proc=scw_CheckboxClicked
	CheckBox sc_hotcoldBox,title="\\Z14 Hot/Cold",variable=sc_hotcold,side=1
	SetVariable sc_hotcolddelayBox,pos={908.00,311.00},size={68.00,20.00}
	SetVariable sc_hotcolddelayBox,title="\\Z14Delay",value=sc_hotcolddelay
	SetVariable sc_FilterfadcBox,pos={824.00,264.00},size={148.00,20.00}
	SetVariable sc_FilterfadcBox,title="\\Z14Resamp Freq "
	SetVariable sc_FilterfadcBox,help={"Re-samples to specified frequency, 0 Hz == no re-sampling"}
	SetVariable sc_FilterfadcBox,value=sc_ResampleFreqfadc
	SetVariable sc_demodphiBox,pos={704.00,268.00},size={100.00,20.00}
	SetVariable sc_demodphiBox,title="\\Z14Demod \\$WMTEX$ \\Phi $/WMTEX$"
	SetVariable sc_demodphiBox,value=sc_demodphi
	SetVariable sc_nfreqBox,pos={500.00,312.00},size={148.00,20.00}
	SetVariable sc_nfreqBox,title="\\Z14 Notch Freqs"
	SetVariable sc_nfreqBox,help={"seperate frequencies (Hz) with , "}
	SetVariable sc_nfreqBox,value=sc_nfreq
	SetVariable sc_nQsBox,pos={660.00,312.00},size={140.00,20.00}
	SetVariable sc_nQsBox,title="\\Z14 Notch Qs",help={"seperate Qs with , "}
	SetVariable sc_nQsBox,value=sc_nQs
	ListBox sc_InstrFdac,pos={396.00,393.00},size={600.00,128.00},fSize=14,frame=2
	ListBox sc_InstrFdac,listWave=root:sc_Instr,selWave=root:instrBoxAttr,mode=1
	ListBox sc_InstrFdac,selRow=0,editStyle=1
	Button connectfdac,pos={393.00,533.00},size={60.00,40.00},proc=scw_OpenInstrButton
	Button connectfdac,title="Connect\rInstr",labelBack=(65535,65535,65535)
	Button connectfdac,fColor=(65535,0,0)
	Button killaboutfdac,pos={680.00,536.00},size={60.00,40.00},proc=sc_controlwindows
	Button killaboutfdac,title="Kill Sweep\r Controls",fSize=10,fColor=(3,52428,1)
	Button killgraphsfdac,pos={536.00,535.00},size={60.00,40.00},proc=scw_killgraphs
	Button killgraphsfdac,title="Close All \rGraphs",fSize=12,fColor=(1,12815,52428)
	Button updatebuttonfdac,pos={464.00,536.00},size={60.00,40.00},proc=scw_updatewindow
	Button updatebuttonfdac,title="save\rconfig",fColor=(65535,16385,16385)
	TabControl tb2,pos={44.00,420.00},size={180.00,20.00},disable=1,proc=TabProc2
	TabControl tb2,fSize=13,tabLabel(0)="Set AW",tabLabel(1)="AW0",tabLabel(2)="AW1"
	TabControl tb2,value=0
	ListBox awglist,pos={68.00,452.00},size={140.00,120.00},disable=1,fSize=14
	ListBox awglist,frame=2,listWave=root:AWGvalstr,selWave=root:AWGattr,mode=1
	ListBox awglist,selRow=0,widths={40,60}
	ListBox awglist0,pos={68.00,452.00},size={140.00,120.00},disable=1,fSize=14
	ListBox awglist0,frame=2,listWave=root:AWGvalstr0,selWave=root:AWGattr0,mode=1
	ListBox awglist0,selRow=0,widths={40,60}
	ListBox awglist1,pos={68.00,452.00},size={140.00,120.00},disable=1,fSize=14
	ListBox awglist1,frame=2,listWave=root:AWGvalstr1,selWave=root:AWGattr1,mode=1
	ListBox awglist1,selRow=0,widths={40,60}
	ListBox awgsetlist,pos={220.00,476.00},size={144.00,68.00},disable=1,fSize=14
	ListBox awgsetlist,frame=2,listWave=root:AWGsetvalstr,selWave=root:AWGsetattr
	ListBox awgsetlist,mode=1,selRow=0,widths={50,40}
	TitleBox freqtextbox,pos={8.00,480.00},size={100.00,20.00},disable=1
	TitleBox freqtextbox,title="Frequency",frame=0
	TitleBox Hztextbox,pos={48.00,500.00},size={40.00,20.00},disable=1,title="Hz"
	TitleBox Hztextbox,frame=0
	Button clearAW,pos={8.00,552.00},size={52.00,20.00},disable=1,proc=scw_clearAWinputs
	Button clearAW,title="Clear"
	Button setupAW,pos={8.00,524.00},size={52.00,20.00},disable=1,proc=scw_setupsquarewave
	Button setupAW,title="Create"
	SetVariable sc_wnumawgBox,pos={8.00,496.00},size={52.00,24.00},disable=1
	SetVariable sc_wnumawgBox,title="\\Z14AW",help={"0 or 1"},value=sc_wnumawg
	SetVariable sc_freqBox0,pos={4.00,500.00},size={40.00,20.00},disable=1
	SetVariable sc_freqBox0,title="\\Z14 ",help={"Shows the frequency of AW0"}
	SetVariable sc_freqBox0,value=sc_freqAW0
	SetVariable sc_freqBox1,pos={4.00,500.00},size={40.00,20.00},disable=1
	SetVariable sc_freqBox1,title="\\Z14 ",help={"Shows the frequency of AW1"}
	SetVariable sc_freqBox1,value=sc_freqAW1
	Button setupAWGfdac,pos={260.00,552.00},size={108.00,20.00},disable=1,proc=scw_setupAWG
	Button setupAWGfdac,title="Setup AWG"
	Button show_AWG,pos={886.00,537.00},size={60.00,40.00},proc=Show_AWG_wave
	Button show_AWG,title="show\rAWG",fColor=(52428,34958,1)
	Button close_tables,pos={608.00,536.00},size={60.00,40.00},proc=Close_tables
	Button close_tables,title="Close All \rTables",fSize=12,fColor=(26205,52428,1)
	Button hide,pos={748.00,536.00},size={60.00,40.00},proc=hide_procs
	Button hide,title="Hide All\r Procs",fColor=(52428,52425,1)
	Button maxi,pos={816.00,536.00},size={60.00,40.00},proc=maximize
	Button maxi,title="large\rwindow",fColor=(26214,26214,26214)
EndMacro


Function FindMaxRepeats(waveName)
    Wave waveName
    Variable maxRepeats = 1  // Minimum number of repeats is 1
    Variable currentCount = 1  // Current count of consecutive repeats
    Variable i
    
    // Loop through the wave, starting from the second element
    For (i = 1; i < DimSize(waveName, 0); i += 1)
        // Check if the current value is the same as the previous one
        If (waveName[i] == waveName[i-1])
            currentCount += 1  // Increment the count for consecutive repeats
            // Update maxRepeats if the current count is greater
            maxRepeats = max(maxRepeats, currentCount)
        Else
            currentCount = 1  // Reset the count if the current value is different
        EndIf
    EndFor
    
    // Print the maximum number of consecutive repeats
    //Print "The maximum number of consecutive repeats is: ", maxRepeats
    return maxrepeats
End

Menu "Graph"
	"Close All Graphs/9", CloseAllGraphs()
End

Menu "Windows"
	"Close All Tables/8", CloseAllTables()
End

Menu "Windows"
	"Scancontoller windows /0", Dowindow/f after1;  Dowindow/f ScanController


	
End

//Function CloseAllGraphs()
//	String name
//	do
//		name = WinName(0,1) // name of the front graph
//		if (strlen(name) == 0)
//			break // all done
//		endif
//		DoWindow/K $name // Close the graph
//	while(1)
//End
//
//Function CloseAllTables()
//	String name
//	do
//		name = WinName(0,2) // name of the front table
//		if (strlen(name) == 0)
//			break // all done
//		endif
//		DoWindow/K $name // Close the table
//	while(1)
//End







Function Show_AWG_wave(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
	string name="AWG_info"
	DoWindow/K $name // Close the table
	
	PauseUpdate; Silent 1		// building window...
	Edit/N=AWG_info/W=(1070,58,1486,275) sc_awg_labels,sc_awg_info
	ModifyTable alignment=0,format(Point)=1,width(sc_awg_labels)=78,width(sc_awg_info)=78
				break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function Close_tables(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	String name
	switch( ba.eventCode )
		case 2: // mouse up
			do
				name = WinName(0,2) // name of the front table
				if (strlen(name) == 0)
					break // all done
				endif
				DoWindow/K $name // Close the table
			while(1)

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function hide_procs(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
hideProcedures
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End



Window AWG_info() : Table
	PauseUpdate; Silent 1		// building window...
	Edit/W=(1070,58,1486,275) sc_awg_labels,sc_awg_info
	ModifyTable alignment=0,format(Point)=1,width(sc_awg_labels)=90,width(sc_awg_info)=110
EndMacro

Function minimize(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
		killwindow/z after2
		execute("after1()")
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Window after2() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(110,53,1980,1200)
	ModifyPanel frameStyle=2
	SetDrawLayer UserBack
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 160,45,"DAC"
	SetDrawEnv fsize= 25,fstyle= 1
	DrawText 650,45,"ADC"
	SetDrawEnv linethick= 2
	DrawLine 378,16,378,1123
	SetDrawEnv linethick= 2,arrowfat= 2
	DrawLine 378,645,1780,645
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 15,70,"Ch"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 50,70,"Output"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 120,70,"Limit"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 220,70,"Label"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 287,70,"Ramprate"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 405,70,"Ch"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 548,70,"Input (mV)"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 748,66,"Record"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 951,69,"Wave Name"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 1255,67,"Calc Function"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 1513,69,"Notch"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 1614,68,"Demod"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 1719,67,"Harmonic"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 454,704,"Connect Instrument"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 999,710,"Open GUI"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 1449,708,"Log Status"
	ListBox fdaclist,pos={9.00,74.00},size={356.00,430.00},fSize=14,frame=2
	ListBox fdaclist,listWave=root:fdacvalstr,selWave=root:fdacattr,mode=1,selRow=2
	ListBox fdaclist,widths={35,70,110,65}
	Button updatefdac,pos={26.00,529.00},size={64.00,20.00},proc=scfw_update_fdac
	Button updatefdac,title="Update"
	Button fdacramp,pos={148.00,529.00},size={64.00,20.00},proc=scfw_update_fdac
	Button fdacramp,title="Ramp"
	Button fdacrampzero,pos={265.00,529.00},size={80.00,20.00},proc=scfw_update_fdac
	Button fdacrampzero,title="Ramp all 0"
	ListBox fadclist,pos={400.00,74.00},size={1400.00,457.00},fSize=14,frame=2
	ListBox fadclist,listWave=root:fadcvalstr,selWave=root:fadcattr,mode=1,selRow=2
	ListBox fadclist,widths={30,70,30,95,100,30,30,20}
	Button updatefadc,pos={402.00,553.00},size={89.00,20.00},proc=scfw_update_fadc
	Button updatefadc,title="Update ADC"
	CheckBox sc_plotRawBox,pos={559.00,557.00},size={72.00,17.00},proc=scw_CheckboxClicked
	CheckBox sc_plotRawBox,title="\\Z14Plot Raw",variable=sc_plotRaw,side=1
	CheckBox sc_demodyBox,pos={703.00,558.00},size={108.00,17.00},proc=scw_CheckboxClicked
	CheckBox sc_demodyBox,title="\\Z14Save Demod.y",variable=sc_demody,side=1
	CheckBox sc_hotcoldBox,pos={855.00,603.00},size={78.00,17.00},proc=scw_CheckboxClicked
	CheckBox sc_hotcoldBox,title="\\Z14 Hot/Cold",variable=sc_hotcold,side=1
	SetVariable sc_hotcolddelayBox,pos={1018.00,604.00},size={72.00,20.00}
	SetVariable sc_hotcolddelayBox,title="\\Z14Delay",value=sc_hotcolddelay
	SetVariable sc_FilterfadcBox,pos={1017.00,555.00},size={146.00,20.00}
	SetVariable sc_FilterfadcBox,title="\\Z14Resamp Freq "
	SetVariable sc_FilterfadcBox,help={"Re-samples to specified frequency, 0 Hz == no re-sampling"}
	SetVariable sc_FilterfadcBox,value=sc_ResampleFreqfadc
	SetVariable sc_demodphiBox,pos={861.00,558.00},size={101.00,20.00}
	SetVariable sc_demodphiBox,title="\\Z14Demod \\$WMTEX$ \\Phi $/WMTEX$"
	SetVariable sc_demodphiBox,value=sc_demodphi
	SetVariable sc_nfreqBox,pos={514.00,599.00},size={148.00,20.00}
	SetVariable sc_nfreqBox,title="\\Z14 Notch Freqs"
	SetVariable sc_nfreqBox,help={"seperate frequencies (Hz) with , "}
	SetVariable sc_nfreqBox,value=sc_nfreq
	SetVariable sc_nQsBox,pos={690.00,600.00},size={140.00,20.00}
	SetVariable sc_nQsBox,title="\\Z14 Notch Qs",help={"seperate Qs with , "}
	SetVariable sc_nQsBox,value=sc_nQs
	ListBox sc_InstrFdac,pos={393.00,714.00},size={1398.00,339.00},fSize=14,frame=2
	ListBox sc_InstrFdac,listWave=root:sc_Instr,selWave=root:instrBoxAttr,mode=1
	ListBox sc_InstrFdac,selRow=0,editStyle=1
	Button connectfdac,pos={399.00,1078.00},size={74.00,40.00},proc=scw_OpenInstrButton
	Button connectfdac,title="Connect\rInstr",labelBack=(65535,65535,65535)
	Button connectfdac,fColor=(65535,0,0)
	Button killaboutfdac,pos={776.00,1081.00},size={74.00,40.00},proc=sc_controlwindows
	Button killaboutfdac,title="Kill Sweep\r Controls",fColor=(3,52428,1)
	Button killgraphsfdac,pos={585.00,1081.00},size={74.00,40.00},proc=scw_killgraphs
	Button killgraphsfdac,title="Close All\rGraphs",fColor=(1,12815,52428)
	Button updatebuttonfdac,pos={485.00,1080.00},size={74.00,40.00},proc=scw_updatewindow
	Button updatebuttonfdac,title="save\rconfig",fColor=(65535,16385,16385)
	TabControl tb2,pos={44.00,422.00},size={180.00,21.00},disable=1,proc=TabProc2
	TabControl tb2,fSize=13,tabLabel(0)="Set AW",tabLabel(1)="AW0",tabLabel(2)="AW1"
	TabControl tb2,value=0
	ListBox awglist,pos={69.00,454.00},size={140.00,120.00},disable=1,fSize=14
	ListBox awglist,frame=2,listWave=root:AWGvalstr,selWave=root:AWGattr,mode=1
	ListBox awglist,selRow=0,widths={40,60}
	ListBox awglist0,pos={69.00,454.00},size={140.00,120.00},disable=1,fSize=14
	ListBox awglist0,frame=2,listWave=root:AWGvalstr0,selWave=root:AWGattr0,mode=1
	ListBox awglist0,selRow=0,widths={40,60}
	ListBox awglist1,pos={69.00,454.00},size={140.00,120.00},disable=1,fSize=14
	ListBox awglist1,frame=2,listWave=root:AWGvalstr1,selWave=root:AWGattr1,mode=1
	ListBox awglist1,selRow=0,widths={40,60}
	ListBox awgsetlist,pos={222.00,478.00},size={146.00,70.00},disable=1,fSize=14
	ListBox awgsetlist,frame=2,listWave=root:AWGsetvalstr,selWave=root:AWGsetattr
	ListBox awgsetlist,mode=1,selRow=0,widths={50,40}
	TitleBox freqtextbox,pos={9.00,480.00},size={100.00,20.00},disable=1
	TitleBox freqtextbox,title="Frequency",frame=0
	TitleBox Hztextbox,pos={48.00,502.00},size={40.00,20.00},disable=1,title="Hz"
	TitleBox Hztextbox,frame=0
	Button clearAW,pos={9.00,554.00},size={54.00,20.00},disable=1,proc=scw_clearAWinputs
	Button clearAW,title="Clear"
	Button setupAW,pos={9.00,524.00},size={54.00,20.00},disable=1,proc=scw_setupsquarewave
	Button setupAW,title="Create"
	SetVariable sc_wnumawgBox,pos={9.00,498.00},size={54.00,24.00},disable=1
	SetVariable sc_wnumawgBox,title="\\Z14AW",help={"0 or 1"},value=sc_wnumawg
	SetVariable sc_freqBox0,pos={5.00,500.00},size={40.00,20.00},disable=1
	SetVariable sc_freqBox0,title="\\Z14 ",help={"Shows the frequency of AW0"}
	SetVariable sc_freqBox0,value=sc_freqAW0
	SetVariable sc_freqBox1,pos={5.00,500.00},size={40.00,20.00},disable=1
	SetVariable sc_freqBox1,title="\\Z14 ",help={"Shows the frequency of AW1"}
	SetVariable sc_freqBox1,value=sc_freqAW1
	Button setupAWGfdac,pos={260.00,554.00},size={109.00,20.00},disable=1,proc=scw_setupAWG
	Button setupAWGfdac,title="Setup AWG"
	Button show_AWG,pos={1040.00,1086.00},size={74.00,40.00},proc=Show_AWG_wave
	Button show_AWG,title="show\rAWG",fColor=(52428,34958,1)
	Button close_tables,pos={677.00,1081.00},size={74.00,40.00},proc=Close_tables
	Button close_tables,title="Close All \rTables",fColor=(26205,52428,1)
	Button hide,pos={867.00,1083.00},size={74.00,40.00},proc=hide_procs
	Button hide,title="Hide All\r Procs",fColor=(52428,52425,1)
	Button mini,pos={952.00,1085.00},size={75.00,40.00},proc=minimize
	Button mini,title="small\rwindow",fColor=(21845,21845,21845)
EndMacro

Function maximize(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
		killwindow/z after1
execute("after2()")
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
