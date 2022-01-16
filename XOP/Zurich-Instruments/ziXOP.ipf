#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Global constants for enums

//========================================================================

/// Enumerates all types that data in a ZIEvent may have
// ZIValueType_enum

  /// No data type, event is invalid.
  Constant ZI_VALUE_TYPE_NONE = 0
  
  /// ZIDoubleData type. Use the ZIEvent.value.doubleData pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_DOUBLE_DATA = 1

  /// ZIIntegerData type. Use the ZIEvent.value.integerData pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_INTEGER_DATA = 2

  /// ZIDemodSample type. Use the ZIEvent.value.demodSample pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_DEMOD_SAMPLE = 3

  /// ScopeWave type, used in v1 compatibility mode. use the ZIEvent.value.scopeWaveOld pointer
  /// to read the data of the event.
  Constant ZI_VALUE_TYPE_SCOPE_WAVE_OLD = 4

  /// ZIAuxInSample type. Use the ZIEvent.value.auxInSample pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_AUXIN_SAMPLE = 5

  /// ZIDIOSample type. Use the ZIEvent.value.dioSample pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_DIO_SAMPLE = 6

  /// ZIByteArray type. Use the ZIEvent.value.byteArray pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_BYTE_ARRAY = 7

  /// ZIPWAWave type. Use the ZIEvent.value.pwaWave pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_PWA_WAVE = 8

  /// TreeChange type - a list of added or removed nodes, used in v1 compatibility mode. Use the
  /// ZIEvent.value.treeChangeDataOld pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_TREE_CHANGE_OLD = 16

  /// ZIDoubleDataTS type. Use the ZIEvent.value.doubleDataTS pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_DOUBLE_DATA_TS = 32

  /// ZIIntegerDataTS type. Use the ZIEvent.value.integerDataTS pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_INTEGER_DATA_TS = 33

  /// ZIScopeWave type. Use the ZIEvent.value.scopeWave pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_SCOPE_WAVE = 35

  /// ZIScopeWaveEx type. Use the ZIEvent.value.scopeWaveEx pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_SCOPE_WAVE_EX = 36

  /// ZIByteArrayTS type. Use the ZIEvent.value.byteArrayTS pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_BYTE_ARRAY_TS = 38

  /// ZITreeChangeData type - a list of added or removed nodes. Use the ZIEvent.value.treeChangeData
  /// pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_TREE_CHANGE_DATA = 48

  /// ZIAsyncReply type. Use the ZIEvent.value.asyncReply pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_ASYNC_REPLY = 50

  /// ZISweeperWave type. Use the ZIEvent.value.sweeperWave pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_SWEEPER_WAVE = 64

  /// ZISpectrumWave type. Use the ZIEvent.value.spectrumWave pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_SPECTRUM_WAVE = 65

  /// ZIAdvisorWave type. Use the ZIEvent.value.advisorWave pointer to read the data of the event.
  Constant ZI_VALUE_TYPE_ADVISOR_WAVE = 66
  

/// @brief Convert a ZIValueType_enum value to a string
/// 
/// @param	ZIValueType_enum	Value to convert
/// @return	A string representing the enum value
function /S ZIValueType_enum_to_string(ZIValueType_enum)
	variable ZIValueType_enum
	
	switch (ZIValueType_enum)
		case ZI_VALUE_TYPE_NONE:
			return "ZI_VALUE_TYPE_NONE";

		case ZI_VALUE_TYPE_DOUBLE_DATA:
			return "ZI_VALUE_TYPE_DOUBLE_DATA";

		case ZI_VALUE_TYPE_INTEGER_DATA:
			return "ZI_VALUE_TYPE_INTEGER_DATA";

		case ZI_VALUE_TYPE_DEMOD_SAMPLE:
			return "ZI_VALUE_TYPE_DEMOD_SAMPLE";

		case ZI_VALUE_TYPE_SCOPE_WAVE_OLD:
			return "ZI_VALUE_TYPE_SCOPE_WAVE_OLD";

		case ZI_VALUE_TYPE_AUXIN_SAMPLE:
			return "ZI_VALUE_TYPE_AUXIN_SAMPLE";

		case ZI_VALUE_TYPE_DIO_SAMPLE:
			return "ZI_VALUE_TYPE_DIO_SAMPLE";

		case ZI_VALUE_TYPE_BYTE_ARRAY:
			return "ZI_VALUE_TYPE_BYTE_ARRAY";

		case ZI_VALUE_TYPE_PWA_WAVE:
			return "ZI_VALUE_TYPE_PWA_WAVE";

		case ZI_VALUE_TYPE_TREE_CHANGE_OLD:
			return "ZI_VALUE_TYPE_TREE_CHANGE_DATA_OLD";

		case ZI_VALUE_TYPE_DOUBLE_DATA_TS:
			return "ZI_VALUE_TYPE_DOUBLE_DATA_TS";

		case ZI_VALUE_TYPE_INTEGER_DATA_TS:
			return "ZI_VALUE_TYPE_INTEGER_DATA_TS";

		case ZI_VALUE_TYPE_SCOPE_WAVE:
			return "ZI_VALUE_TYPE_SCOPE_WAVE";

		case ZI_VALUE_TYPE_SCOPE_WAVE_EX:
			return "ZI_VALUE_TYPE_SCOPE_WAVE_EX";

		case ZI_VALUE_TYPE_BYTE_ARRAY_TS:
			return "ZI_VALUE_TYPE_BYTE_ARRAY_TS";

 		case ZI_VALUE_TYPE_TREE_CHANGE_DATA:
			return "ZI_VALUE_TYPE_TREE_CHANGE_DATA";

		case ZI_VALUE_TYPE_ASYNC_REPLY:
			return "ZI_VALUE_TYPE_ASYNC_REPLY";

		case ZI_VALUE_TYPE_SWEEPER_WAVE:
			return "ZI_VALUE_TYPE_SWEEPER_WAVE";
			
 		case ZI_VALUE_TYPE_SPECTRUM_WAVE:
			return "ZI_VALUE_TYPE_SPECTRUM_WAVE";

		case ZI_VALUE_TYPE_ADVISOR_WAVE:
			return "ZI_VALUE_TYPE_ADVISOR_WAVE";
			
		default:
			return "Unknown ZIValueType_enum value"
		
	endSwitch
end

//========================================================================

/// Defines the actions that are performed on a tree, as returned in
/// the ZITreeChangeData::action or ZITreeChangeDataOld::action.
///
/// ZITreeAction_enum

  /// A node has been removed.
  Constant ZI_TREE_ACTION_REMOVE = 0

  /// A node has been added.
  Constant ZI_TREE_ACTION_ADD = 1

  /// A node has been changed.
  Constant ZI_TREE_ACTION_CHANGE = 2
  
/// @brief Convert a ZITreeAction_enum value to a string
/// 
/// @param	ZITreeAction_enum	Value to convert
/// @return	A string representing the enum value
function /S ZITreeAction_enum_to_string(ZITreeAction_enum)
	variable ZITreeAction_enum
	
	switch (ZITreeAction_enum)
		case ZI_TREE_ACTION_REMOVE:
			return "ZI_TREE_ACTION_REMOVE";
		
		case ZI_TREE_ACTION_ADD:
			return "ZI_TREE_ACTION_ADD";
			
		case ZI_TREE_ACTION_CHANGE:
			return "ZI_TREE_ACTION_CHANGE";
			
		default:
			return "Unknown ZITreeAction_enum value"
			
	endSwitch
end

//========================================================================

/// Defines the values of the flags used in ::ziAPIListNodes
/// ZIListNodes_enum
  /// Default, return a simple listing of the given node immediate descendants.
  Constant ZI_LIST_NODES_NONE = 0
  /// List the nodes recursively
  Constant ZI_LIST_NODES_RECURSIVE = 1
  /// Return absolute paths
  Constant ZI_LIST_NODES_ABSOLUTE = 2
  /// Return only leaf nodes, which means the nodes at the outermost level of the tree
  Constant ZI_LIST_NODES_LEAFSONLY = 4
  /// Return only nodes which are marked as setting
  Constant ZI_LIST_NODES_SETTINGSONLY = 8
  
/// @brief Convert a ZIListNodes_enum value to a string
/// 
/// @param	ZIListNodes_enum	Value to convert
/// @return	A string representing the enum value
function /S ZIListNodes_enum_to_string(ZIListNodes_enum)
	variable ZIListNodes_enum
	
	switch (ZIListNodes_enum)
		case ZI_LIST_NODES_NONE:
			return "ZI_LIST_NODES_NONE";
		
		case ZI_LIST_NODES_RECURSIVE:
			return "ZI_LIST_NODES_RECURSIVE";
			
		case ZI_LIST_NODES_ABSOLUTE:
			return "ZI_LIST_NODES_ABSOLUTE";
			
		case ZI_LIST_NODES_LEAFSONLY:
			return "ZI_LIST_NODES_LEAFSONLY";
			
		case ZI_LIST_NODES_SETTINGSONLY:
			return "ZI_LIST_NODES_SETTINGSONLY";
			
		default:
			return "Unknown ZIListNodes_enum value"
			
	endSwitch
end

//========================================================================

// Structures used in ziXOP functions

Static Strconstant ziXOP_DemodSample_SType = "ziXOP_DemodSample_1.000"
Structure ziXOP_DemodSample
	String structureType;	///< Structure type
	WAVE timeStamp;	///< The timestamp at which the sample has been measured.
	double x;			///< X part of the sample.
	double y;			///< Y part of the sample.
	double frequency;		///< Frequency at that sample.
	double phase;		///< Phase at that sample.
	uint32 dioBits;		///< the current bits of the DIO.
	uint32 trigger;		///< trigger bits
	double auxIn0;		///< value of Aux input 0.
	double auxIn1;		///< value of Aux input 1.
EndStructure

function ziXOP_initDemodSample(s)
	struct ziXOP_DemodSample &s;
	
	s.structureType = ziXOP_DemodSample_SType;
	Make/FREE/N=0/L/U wv
	WAVE s.timeStamp = wv;
end

Static Strconstant ziXOP_DIOSample_SType = "ziXOP_DIOSample_1.000"
Structure ziXOP_DIOSample
	String structureType;	///< Structure type
	WAVE timeStamp;	///< The timestamp at which the values have been measured.
	uint32 bits;			///< The digital I/O values.
EndStructure

function ziXOP_initDIOSample(s)
	struct ziXOP_DIOSample &s;
	
	s.structureType = ziXOP_DIOSample_SType;
	Make/FREE/N=0/L/U wv
	WAVE s.timeStamp = wv;
end

Static Strconstant ziXOP_AuxInSample_SType = "ziXOP_AuxInSample_1.000"
Structure ziXOP_AuxInSample
	String structureType;	///< Structure type
	WAVE timeStamp;	///< The timestamp at which the values have been measured.
	double  ch0;			///< Channel 0 voltage.
	double  ch1;			///< Channel 1 voltage.
  EndStructure
  
  function ziXOP_initAuxInSample(s)
	struct ziXOP_AuxInSample &s;
	
	s.structureType = ziXOP_AuxInSample_SType;
	Make/FREE/N=0/L/U wv
	WAVE s.timeStamp = wv;
end

Static Strconstant ziXOP_TreeChangeData_SType = "ziXOP_TreeChangeData_1.000"
Structure ziXOP_TreeChangeData
	String structureType;	///< Structure type
	WAVE timeStamp;	///< Time stamp at which the data was updated.
	uint32 action;		///<  field indicating which action occured on the tree. A value of the ZITreeAction_enum.
	String name;			///< Name of the Path that has been added, removed or changed.
EndStructure

function ziXOP_initTreeChangeData(s)
	struct ziXOP_TreeChangeData &s;
	
	s.structureType = ziXOP_TreeChangeData_SType;
	Make/FREE/N=0/L/U wv
	WAVE s.timeStamp = wv;
end

Static Strconstant ziXOP_TreeChangeDataOld_SType = "ziXOP_TreeChangeDataOld_1.000"
Structure ziXOP_TreeChangeDataOld
	String structureType 	///< Structure type
	uint32 action			///< field indicating which action occured on the tree. A value of the ZITreeAction_enum (TREE_ACTION) enum.
	String name			///< Name of the Path that has been added, removed or changed
EndStructure

function ziXOP_initTreeChangeDataOld(s)
	struct ziXOP_TreeChangeData &s;
	
	s.structureType = ziXOP_TreeChangeDataOld_SType;
end

Constant ZIInput_Signal_Input_1	= 0;
Constant ZIInput_Signal_Input_2	= 1;
Constant ZIInput_Trigger_Input_1	= 2;
Constant ZIInput_Trigger_Input_2	= 3;
Constant ZIInput_Aux_Output_1	= 4;
Constant ZIInput_Aux_Output_2	= 5;
Constant ZIInput_Aux_Output_3	= 6;
Constant ZIInput_Aux_Output_4	= 7;
Constant ZIInput_Aux_Input_1		= 8;
Constant ZIInput_Aux_Input_2		= 9;

Function /S ZIInput_to_String(ZIInput)
	Variable ZIInput
	
	switch (ZIInput)
		case ZIInput_Signal_Input_1:
			return "Signal Input 1";
			
		case ZIInput_Signal_Input_2:
			return "Signal Input 2";
			
		case ZIInput_Trigger_Input_1:
			return "Trigger Input 1";
			
		case ZIInput_Trigger_Input_2:
			return "Trigger Input 2";
			
		case ZIInput_Aux_Output_1:
			return "Aux Output 1";
			
		case ZIInput_Aux_Output_2:
			return "Aux Output 2";
			
		case ZIInput_Aux_Output_3:
			return "Aux Output 3";
			
		case ZIInput_Aux_Output_4:
			return "Aux Output 4";
			
		case ZIInput_Aux_Input_1:
			return "Aux Input 1";
			
		case ZIInput_Aux_Input_2:
			return "Aux Input 2";
			
		default:
			return "Unknown Input Value";
		
	endSwitch
end

Static Strconstant ziXOP_ScopeWave_SType = "ziXOP_ScopeWave_1.000"
Structure ziXOP_ScopeWave
	/// Structure type
	String structureType
	/// Time stamp of the last sample in this data block
	WAVE timeStamp
	/// Time stamp of the trigger (may also fall between samples and in another block)
	WAVE triggerTimeStamp
	/// Time difference between samples in seconds
	double  dt
	/// Up to four channels: if channel is enabled, corresponding element is non-zero.
	uchar channelEnable[4]
	
	/// Specifies the input source for each of the scope four channels:
	///   0 = Signal Input 1,
	///   1 = Signal Input 2,
	///   2 = Trigger Input 1,
	///   3 = Trigger Input 2,
	///   4 = Aux Output 1,
	///   5 = Aux Output 2,
	///   6 = Aux Output 3,
	///   7 = Aux Output 4,
	///   8 = Aux Input 1,
	///   9 = Aux Input 2.
	/// [see ZIInput_ constants]
	uchar channelInput[4]
	
	/// Non-zero if trigger is enabled:
	///   Bit(0): rising edge trigger off = 0, on = 1.
	///   Bit(1): falling edge trigger off = 0, on = 1.
	uchar triggerEnable
	
	/// Trigger source (same values as for channel input)
	/// [see ZIInput_ constants]
	uchar triggerInput
		
	/// Bandwidth-limit flag, per channel.
	///   Bit(0): off = 0, on = 1
	///   Bit(7...1): Reserved
    	uchar channelBWLimit[4]
	
	/// Math Operation (e.g averaging)
	///   Bit (7..0): Reserved	
	uchar channelMath[4]
	
	/// Data scaling factors for up to 4 channels
	float channelScaling[4]
	
	/// Current scope shot sequence number. Identifies a scope shot.
	uint32 sequenceNumber
	
	/// Current segment number.
	uint32 segmentNumber

	/// Current block number from the beginning of a scope shot.
	/// Large scope shots are split into blocks, which need to be concatenated to obtain the complete scope shot.
	uint32 blockNumber
	
	/// Total number of samples in one channel in the current scope shot, same for all channels
	WAVE totalSamples
	
	/// Data transfer mode
	///   SingleTransfer = 0, BlockTransfer = 1, ContinuousTransfer = 3, FFTSingleTransfer = 4.
	///   Other values are reserved.
	uchar dataTransferMode
	
	/// Block marker:
	///   Bit (0): 1 = End marker for continuous or multi-block transfer
	///   Bit (7..0): Reserved
	uchar blockMarker
	
	/// Indicator Flags.
	///   Bit (0): 1 = Data loss detected (samples are 0),
	///   Bit (1): 1 = Missed trigger,
	///   Bit (2): 1 = Transfer failure (corrupted data).	
	uchar flags
	
	/// Data format of samples:
	/// Int16 = 0, Int32 = 1, Float = 2, Int16Interleaved = 4, Int32Interleaved = 5, FloatInterleaved = 6.	
	uchar sampleFormat
	
	/// Number of samples in one channel in the current block, same for all channels
	uint32 sampleCount
EndStructure

function ziXOP_initScopeWave(s)
	struct ziXOP_ScopeWave &s;
	
	s.structureType = ziXOP_ScopeWave_SType;
	
	Make/FREE/N=0/L/U wv
	WAVE s.timeStamp = wv;
	Make/FREE/N=0/L/U wv
	WAVE s.triggerTimeStamp = wv;
	Make/FREE/N=0/L/U wv
	WAVE s.totalSamples = wv;
end

Static Strconstant ziXOP_ScopeWaveOld_SType = "ziXOP_ScopeWaveOld_1.000"
Structure ziXOP_ScopeWaveOld
	String structureType; 		///< Structure type
	double dt;				///< Time difference between samples
	uint32 ScopeChannel;		///< Scope channel of the represented data
	uint32 TriggerChannel;		///< Trigger channel of the represented data
	uint32 BWLimit;			///< Bandwidth-limit flag
	uint32 Count;				///< Count of samples
EndStructure

function ziXOP_initScopeWaveOld(s)
	struct ziXOP_ScopeWaveOld &s;
	
	s.structureType = ziXOP_ScopeWaveOld_SType;
end


Static Strconstant ziXOP_pwaWave_StructureType = "ziXOP_pwaWave_1.000"
Structure ziXOP_pwaWave
	String structureType; 	///< Structure type

	WAVE timeStamp;	///< Time stamp at which the data was updated
	WAVE sampleCount;	///< Total sample count considered for PWA

	uint32 inputSelect;		///< Input selection used for the PWA
	uint32 oscSelect;			///< Oscillator used for the PWA
	uint32 harmonic;			///< Harmonic setting
	uint32 binCount;			///< Bin count of the PWA

	double frequency;			///< Frequency during PWA accumulation

	uchar pwaType;			///< Type of the PWA
	uchar mode;				///< PWA Mode [0: zoom PWA, 1: harmonic PWA]
	
	/// Overflow indicators.
	/// overflow[0]: Data accumulator overflow,
	/// overflow[1]: Counter at limit,
	/// overflow[6..2]: Reserved,
	/// overflow[7]: Invalid (missing frames).	
	uchar overflow;
	uchar commensurable;	///< Commensurability of the data
EndStructure

function ziXOP_initpwaWave(s)
	struct ziXOP_pwaWave &s;
	
	s.structureType = ziXOP_pwaWave_StructureType;
	
	Make/FREE/N=0/L/U wv
	WAVE s.timeStamp = wv;
	Make/FREE/N=0/L/U wv
	WAVE s.sampleCount = wv;
end

//========================================================================
