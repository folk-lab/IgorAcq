# Introduction #

The zhInst XOP provides additional functions for Igor Pro that allow to control and acquire from devices from Zurich Instruments.

# Requirements #

- Zurich Instruments LabOne Package 21.08
- Wavemetrics Igor Pro 8

## Requirements for Building the XOP ##

- CMake 3.15.1
- Microsoft Visual Studio 2019
- Perl 5 (only when new functions should be added)

# Installation #

- Open the downloaded zip archive and extract the ziXOP-64.xop and ziXOP.ipf file to a folder of your choice, keep the explorer window open
- Open Igor Pro, navigate in the Menu to Help/Show Igor Pro User Files
- An explorer window opens with the Igor Pro User Files folder, navigate into "Igor Extensions (64-bit)"
- In the explorer window where the ziXOP-64.xop file is present, right click the ziXOP-64.xop file and choose "Copy"
- In the "Igor Extensions (64-bit)" explorer window right click and "Paste Shortcut". A shortcut to the ziXOP-64.xop should appear.
- Open a new explorer window and navigate to your installation of LabOne from Zurich Instruments, usually at "C:\Program Files\Zurich Instruments\LabOne", navigate further to "API\C\lib". Copy the "ziAPI-win64.dll" into the folder where the "ziXOP-64.xop" file is saved.
- In the explorer window showing "Igor Extensions (64-bit)" navigate one folder up and into "User Procedures"
- In the explorer window where the ziXOP.ipf file is present, right click the ziXOP.ipf file and choose "Copy"
- In the "User Procedures" explorer window right click and "Paste Shortcut". A shortcut to the ziXOP.ipf should appear.
- Close all in that process opened explorer windows and restart Igor Pro

# Description #

Function parameters preceded by a * return values through that parameter. If an error occurs when a function is called
such reference parameters are not changed and an error code is returned as regular function return value.

If no error occurred the ziXOP functions return 0, otherwise a more detailed error message can be retrieved through `ziXOPGetError`.

Data structures and constants that are used by the ziXOP functions are defined in ziXOP.ipf. It is recommended that files that call ziXOP functions include ziXOP.ipf with `#include "ziXOP"`. Each data structure has a corresponding function for initialization that must be called before using the structure in XOP function calls. For example the structure `ziXOP_DemodSample` is paired with a function `ziXOP_initDemodSample` that initializes the structure with default values.

# Function Reference #


    ziXOPInit(variable *connHandle)


- connHandle - contains a connection handle after the function call. The connection handle refers to the connection to the zi library.
- returns: ziAPI error code or 0 if no error

Initializes internal library data structures to prepare a connection to the data server.

Corresponding ziAPI function: `ziAPInit`


    ziXOPDestroy(variable connHandle)

- connHandle - connection handle (from `ziAPIInit`)
- returns: ziAPI error code or 0 if no error

Frees all allocated memory for this connection handle from the zi library.

Corresponding ziAPI function: `ziAPIDestroy`


    ziXOPConnect(variable connHandle, string hostname, variable port)

- connHandle - connection handle (from `ziAPIInit`)
- hostName - Name of the host to which should be connected, if an empty string is given then "localhost" will be used as default
- port - The number of the port to connect to. If 0, default port of the local Data Server will be used (8005). Valid port numbers are in the range of 0 - 65535 (16 bit).
- returns: ziAPI error code or 0 if no error

Connects to the data server and prepares for data exchange.

Corresponding ziAPI function: `ziAPIConnect`


    ziXOPDisconnect(variable connHandle)

- connHandle - connection handle (from `ziAPIInit`)
- returns: ziAPI error code or 0 if no error

Disconnects from the data server.

Corresponding ziAPI function: `ziAPIDisconnect`



    ziXOPListImplementations(string *implementations)

- implementations - string contains list of implementations after function call. String must not be NULL on call.
- returns: ziAPI error code or 0 if no error

Returns the list of supported implementations.

Corresponding ziAPI function: `ziAPIListImplementations`


    ziXOPConnectEx(variable connHandle, string hostname, variable port, variable apiLevel, string implementation)

- connHandle - connection handle (from `ziAPIInit`)
- hostName - Name of the host to which should be connected, if an empty string is given then "localhost" will be used as default
- port - The number of the port to connect to. If 0, default port of the local Data Server will be used (8005). Valid port numbers are in the range of 0 - 65535 (16 bit).
- apiLevel - Specifies the ziAPI compatibility level to use for this connection (1 or 4)
- implementation - Specifies implementation to use for a connection. An empty string selects the default implementation (recommended).
- returns: ziAPI error code or 0 if no error

Connects to the data server and enables extended ziAPI. With apiLevel=1 and implementation="", this function call is equivalent to plain `ziXOPConnect`. With other version and implementation values enables corresponding ziAPI extension and connection using different implementation.

Corresponding ziAPI function: `ziAPIConnectEx`


    ziXOPGetConnectionAPILevel(variable connHandle, variable *apiLevel)

- connHandle - connection handle (from `ziAPIInit`)
- apiLevel - contains ziAPI level after the function call
- returns: ziAPI error code or 0 if no error

Returns ziAPI level used.

Corresponding ziAPI function: `ziAPIGetConnectionAPILevel`


    ziXOPGetRevision(variable *revision)

- apiLevel - contains version and build number of the ziAPI after the function call
- returns: ziAPI error code or 0 if no error

Retrieves the version and build number of ziAPI in the following format: The number is a packed representation of YY.MM.BUILD as a 32-bit unsigned integer: (YY << 24) | (MM << 16) | BUILD.

Corresponding ziAPI function: `ziAPIGetRevision`


    ziXOPListNodes(variable connHandle, string path, string *nodes, variable flags)

- connHandle - connection handle (from `ziAPIInit`)
- path - path for which all children will be returned
- nodes - contains after the function call a semicolon separated list of all children found
- flags - a combination of flags from the ZI_LIST_NODES_* constants from ziXOP.ipf specifying what children are returned
- returns: ziAPI error code or 0 if no error

This function returns a list of node names found at the specified path. The path may contain wildcards so that the returned nodes do not necessarily have to have the same parents.

Corresponding ziAPI function: `ziAPIListNodes`


    ziXOPListNodesJSON(variable connHandle, string path, string *nodes, variable flags)

- connHandle - connection handle (from `ziAPIInit`)
- path - path for which all children will be returned
- nodes - contains after the function call a list of all children found in JSON format
- flags - a combination of flags from the ZI_LIST_NODES_* constants from ziXOP.ipf specifying what children are returned
- returns: ziAPI error code or 0 if no error

This function returns a list of node names in JSON format found at the specified path. The path may contain wildcards so that the returned nodes do not necessarily have to have the same parents.

Corresponding ziAPI function: `ziAPIListNodesJSON`


    ziXOPUpdateDevices(variable connHandle)

- connHandle - connection handle (from `ziAPIInit`)
- returns: ziAPI error code or 0 if no error

Force the data server to search for newly connected devices and update the tree.

Corresponding ziAPI function: `ziAPIUpdateDevices`


    ziXOPConnectDevice(variable connHandle, string deviceSerial, string deviceInterface, string interfaceParams)

- connHandle - connection handle (from `ziAPIInit`)
- deviceSerial - the serial of the deice to connect to, e.g. "dev2100"
- deviceInterface - the interface to use for the connection, e.g. "USB|1GbE"
- interfaceParams - parameters for interface configuration (currently reserved for future use)
- returns: ziAPI error code or 0 if no error

This function connects a device with deviceSerial via the specified deviceInterface for use with the server.

Corresponding ziAPI function: `ziAPIConnectDevice`


    ziXOPDisconnectDevice(variable connHandle, string deviceSerial)

- connHandle - connection handle (from `ziAPIInit`)
- deviceSerial - the serial of the deice to connect to, e.g. "dev2100"
- returns: ziAPI error code or 0 if no error

This function disconnects a device specified by deviceSerial from the server.

Corresponding ziAPI function: `ziAPIDisconnectDevice`


    ziXOPGetValueD(variable connHandle, string path, variable *value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node holding the value
- value - contains after the function call the double value
- returns: ziAPI error code or 0 if no error

This function retrieves the numerical value of the specified node as an double-typed value. The first value found is returned if more than one value is available (a wildcard used in the path).

Corresponding ziAPI function: `ziAPIGetValueD`


    ziXOPGetValueC(variable connHandle, string path, complex *value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node holding the value
- value - contains after the function call the complex value
- returns: ziAPI error code or 0 if no error

This function retrieves the value of the specified node as an complex-typed value. A complex-typed value contains a real and imaginary part as double precision value. The first value found is returned if more than one value is available (a wildcard used in the path).

Corresponding ziAPI function: `ziAPIGetComplexData`


    ziXOPGetValueI(variable connHandle, string path, variable *value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node holding the value
- value - contains after the function call the integer value
- returns: ziAPI error code or 0 if no error

This function retrieves the numerical value of the specified node as an integer-type value. The first value found is returned if more than one value is available (a wildcard used in the path). Note that ziAPI returns internally a 64-bit signed integer that is converted to a double, thus limited to 52-bit. If larger values are expected to be read see also `ziXOPGetValueI_64`.

Corresponding ziAPI function: `ziAPIGetValueI`


    ziXOPGetValueI_64(variable connHandle, string path, WAVE value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node holding the value
- value - numeric wave that is converted by the function call to a single element signed 64-bit integer wave. It contains after the function call the integer value
- returns: ziAPI error code or 0 if no error

This function retrieves the numerical value of the specified node as an integer-type value. The first value found is returned if more than one value is available (a wildcard used in the path). ziAPI returns internally a 64-bit signed integer that is returned in the first element of a single element 64-bit signed integer wave.

Corresponding ziAPI function: `ziAPIGetValueI`


    ziXOPGetDemodSample(variable connHandle, string path, struct ziXOP_DemodSample *value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node holding the value
- value - ziXOP_DemodSample structure that contains after the function call the returned value
- returns: ziAPI error code or 0 if no error

This function retrieves the value of the specified node as an ziXOP_DemodSample struct. The value first found is returned if more than one value is available (a wildcard is used in the path). This function is only applicable to paths matching DEMODS/[0-9]+/SAMPLE. The ziXOP_DemodSample structure is provided through ziXOP.ipf. The related structure initialization function is `ziXOP_initDemodSample`.

Corresponding ziAPI function: `ziAPIGetDemodSample`


    ziXOPGetDIOSample(variable connHandle, string path, struct ziXOP_DIOSample *value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node holding the value
- value - ziXOP_DIOSample structure that contains after the function call the returned value
- returns: ziAPI error code or 0 if no error

This function retrieves the newest available DIO sample from the specified node. The value first found is returned if more than one value is available (a wildcard is used in the path). This function is only applicable to nodes ending in "/DIOS/[0-9]+/INPUT". The ziXOP_DIOSample structure is provided through ziXOP.ipf. The related structure initialization function is `ziXOP_initDIOSample`.

Corresponding ziAPI function: `ziAPIGetDIOSample`


    ziXOPGetAuxInSample(variable connHandle, string path, struct ziXOP_AuxInSample *value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node holding the value
- value - ziXOP_AuxInSample structure that contains after the function call the returned value
- returns: ziAPI error code or 0 if no error

This function retrieves the newest available AuxIn sample from the specified node. The value first found is returned if more than one value is available (a wildcard is used in the path). This function is only applicable to nodes ending in "/AUXINS/[0-9]+/SAMPLE". The ziXOP_AuxInSample structure is provided through ziXOP.ipf. The related structure initialization function is `ziXOP_initAuxInSample`.

Corresponding ziAPI function: `ziAPIGetAuxInSample`


    ziXOPGetValueB(variable connHandle, string path, WAVE value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node holding the value
- value - numerical wave that is converted by the function call to a unsigned 8-bit integer wave. Contains after the function call the returned values.
- returns: ziAPI error code or 0 if no error

This function retrieves the newest available DIO samples (bytes) from the specified node. The value first found is returned if more than one value is available (a wildcard is used in the path).

Corresponding ziAPI function: `ziAPIGetValueB`


    ziXOPGetValueB_s(variable connHandle, string path, string *value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node holding the value
- value - string that contains after the function call the returned data. Value must not be null.
- returns: ziAPI error code or 0 if no error

This function retrieves the newest available DIO samples (bytes) from the specified node. The value first found is returned if more than one value is available (a wildcard is used in the path).

Corresponding ziAPI function: `ziAPIGetValueB`


    ziXOPSetValueD(variable connHandle, string path, variable value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- value - double-type value that will be written to the node(s).
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path to value. More than one value can be set if a wildcard is used. The function sets the value asynchronously which means that after the function returns you have no security to which value it is finally set nor at what point in time it is set.

Corresponding ziAPI function: `ziAPISetValueD`


    ziXOPSetValueC(variable connHandle, string path, complex value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- value - complex-type value that will be written to the node(s).
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path to value. More than one value can be set if a wildcard is used. The function sets the value asynchronously which means that after the function returns you have no security to which value it is finally set nor at what point in time it is set.

Corresponding ziAPI function: `ziAPISetComplexData`


    ziXOPSetValueI(variable connHandle, string path, variable value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- value - integer-type value that will be written to the node(s).
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path to value. More than one value can be set if a wildcard is used. The function sets the value asynchronously which means that after the function returns you have no security to which value it is finally set nor at what point in time it is set. Note that since value is a double-type parameter of the function only integers up to 52-bit are represented with sufficient precision.

Corresponding ziAPI function: `ziAPISetValueI`


    ziXOPSetValueI_64(variable connHandle, string path, WAVE value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- value - single element signed 64-bit integer wave that value will be written to the node(s).
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path to value[0]. More than one value can be set if a wildcard is used. The function sets the value asynchronously which means that after the function returns you have no security to which value it is finally set nor at what point in time it is set. The wave value can be created with `Make/FREE/L/N=1 value`.

Corresponding ziAPI function: `ziAPISetValueI`


    ziXOPSetValueB(variable connHandle, string path, WAVE buffer)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- buffer - unsigned 8-bit integer wave that values will be written to the node(s).
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path. More than one value can be set if a wildcard is used. The function sets the value asynchronously which means that after the function returns you have no security to which value it is finally set nor at what point in time it is set.

Corresponding ziAPI function: `ziAPISetValueB`


    ziXOPSetValueB_s(variable connHandle, string path, string buffer)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- buffer - string that will be written to the node(s).
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path. More than one value can be set if a wildcard is used. The function sets the value asynchronously which means that after the function returns you have no security to which value it is finally set nor at what point in time it is set.

Corresponding ziAPI function: `ziAPISetValueB`


    ziXOPSyncSetValueD(variable connHandle, string path, variable *value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- value - double-type variable that is written to the node(s). When the function returns the variable holds the effectively written value.
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path to Value. More than one value can be set if a wildcard is used. The function sets the value synchronously. After returning you know that it is set and to which value it is set.

Corresponding ziAPI function: `ziAPISyncSetValueD`


    ziXOPSyncSetValueI(variable connHandle, string path, variable *value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- value - double-type variable that is written as integer-type to the node(s). When the function returns the variable holds the effectively written value.
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path to Value. More than one value can be set if a wildcard is used. The function sets the value synchronously. After returning you know that it is set and to which value it is set. Note that value is a double-type parameter and can only represent integers up to 52-bit with sufficient precision.

Corresponding ziAPI function: `ziAPISyncSetValueI`


    ziXOPSyncSetValueI_64(variable connHandle, string path, WAVE value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- value - single element signed 64-bit integer wave that value will be written to the node(s). When the function returns the wave holds the effectively written value.
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path to Value. More than one value can be set if a wildcard is used. The function sets the value synchronously. After returning you know that it is set and to which value it is set.

Corresponding ziAPI function: `ziAPISyncSetValueI`


    ziXOPSyncSetValueB(variable connHandle, string path, WAVE buffer)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- value - unsigned 8-bit integer wave that value will be written to the node(s). When the function returns the wave holds the effectively written value.
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path to Value. More than one value can be set if a wildcard is used. The function sets the value synchronously. After returning you know that it is set and to which value it is set.

Corresponding ziAPI function: `ziAPISyncSetValueB`


    ziXOPSyncSetValueB_s(variable connHandle, string path, string *buffer)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- buffer - string value that will be written to the node(s). When the function returns the string holds the effectively written value.
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path to Value. More than one value can be set if a wildcard is used. The function sets the value synchronously. After returning you know that it is set and to which value it is set.

Corresponding ziAPI function: `ziAPISyncSetValueB`


    ziXOPSync(variable connHandle)

- connHandle - connection handle (from `ziAPIInit`)
- returns: ziAPI error code or 0 if no error

Synchronizes the session by dropping all pending data. This function drops any data that is pending for transfer. Any data (including poll data) retrieved afterwards is guaranteed to be produced not earlier than the call to ziXOPSync. This ensures in particular that any settings made prior to the call to ziXOPSync have been propagated to the device, and the data retrieved afterwards is produced with the new settings already set to the hardware. Note, however, that this does not include any required settling time.

Corresponding ziAPI function: `ziAPISync`


    ziXOPEchoDevice(variable connHandle, string deviceSerial)

- connHandle - connection handle (from `ziAPIInit`)
- deviceSerial - the serial of the device to get the echo from, e.g., "dev2100"
- returns: ziAPI error code or 0 if no error

Sends an echo command to a device and blocks until answer is received. This is useful to flush all buffers between API and device to enforce that further code is only executed after the device executed a previous command. Per device echo is only implemented for HF2. For other device types it is a synonym to ziAPISync, and deviceSerial parameter is ignored.

Corresponding ziAPI function: `ziAPIEchoDevice`

    ziXOPVersion()

- returns: version information about the XOP as string

Returns information about the version of the XOP.


### API for fast asynchroneous operation ###

Functions in this section are non-blocking, and on return only report errors that can be identified directly on a client side (e.g. not connected). Any further results (including errors like node not found) of the command processing is returned as a special event in poll data. Tags are used to match the asynchronous replies with the sent commands.

    ziXOPAsyncSetDoubleData(variable connHandle, string path, variable value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- value - double-type value that will be written to the node(s).
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path to value. More than one value can be set if a wildcard is used. The function sets the value asynchronously which means that after the function returns you have no security to which value it is finally set nor at what point in time it is set or if it was set.

Corresponding ziAPI function: `ziAPIAsyncSetDoubleData`


    ziXOPAsyncSetIntegerData(variable connHandle, string path, variable value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- value - integer-type value that will be written to the node(s).
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path to value. More than one value can be set if a wildcard is used. The function sets the value asynchronously which means that after the function returns you have no security to which value it is finally set nor at what point in time it is set or if it was set. Note that since value is a double-type parameter of the function only integers up to 52-bit are represented with sufficient precision.

Corresponding ziAPI function: `ziAPIAsyncSetIntegerData`


    ziXOPAsyncSetIntegerData_64(variable connHandle, string path, WAVE value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- value - single element signed 64-bit integer wave that value will be written to the node(s).
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path to value. More than one value can be set if a wildcard is used. The function sets the value asynchronously which means that after the function returns you have no security to which value it is finally set nor at what point in time it is set or if it was set. The wave value can be created with `Make/FREE/L/N=1 value`.

Corresponding ziAPI function: `ziAPIAsyncSetIntegerData`


    ziXOPAsyncSetByteArray(variable connHandle, string path, WAVE value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- value - unsigned 8-bit integer wave that values will be written to the node(s).
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path to value. More than one value can be set if a wildcard is used. The function sets the value asynchronously which means that after the function returns you have no security to which value it is finally set nor at what point in time it is set or if it was set.

Corresponding ziAPI function: `ziAPIAsyncSetByteArray`


    ziXOPAsyncSetByteArray_s(variable connHandle, string path, string value)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the node(s) for which the value(s) will be set
- value - string that will be written to the node(s).
- returns: ziAPI error code or 0 if no error

This function sets the values of the nodes specified in path to value. More than one value can be set if a wildcard is used. The function sets the value asynchronously which means that after the function returns you have no security to which value it is finally set nor at what point in time it is set or if it was set.

Corresponding ziAPI function: `ziAPIAsyncSetByteArray`

### Event Functions ###


    ziXOPAllocateEventEx(variable *eventHandle)

- eventHandle - returns a handle for a allocated ZIEvent structure
- returns: ziAPI error code or 0 if no error

Allocates ZIEvent structure and returns a handle to it. See also `ziXOPDeallocateEventEx`.

Corresponding ziAPI function: `ziAPIAllocateEventEx`


    ziXOPDeallocateEventEx(variable eventHandle)

- eventHandle - handle of a previously allocated ZIEvent structure
- returns: ziAPI error code or 0 if no error

Deallocates ZIEvent structure. See also `ziXOPAllocateEventEx`.

Corresponding ziAPI function: `ziAPIDeallocateEventEx`


    ziXOPSubscribe(variable connHandle, string path)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the nodes to subscribe
- returns: ziAPI error code or 0 if no error

Subscribes the nodes given by path for `ziXOPPollDataEx`. This function subscribes to nodes so that whenever the value of the node changes the new value can be polled using `ziXOPPollDataEx`. By using wildcards or by using a path that is not a leaf node but contains sub nodes, more than one leaf can be subscribed to with one function call.

Corresponding ziAPI function: `ziAPISubscribe`


    ziXOPUnSubscribe(variable connHandle, string path)

- connHandle - connection handle (from `ziAPIInit`)
- path - path to the nodes to unsubscribe
- returns: ziAPI error code or 0 if no error

This function is the complement to `ziXOPSubscribe`. By using wildcards or by using a path that is not a leaf node but contains sub nodes, more than one node can be unsubscribed with one function call.

Corresponding ziAPI function: `ziAPIUnSubscribe`


    ziXOPPollDataEx(variable connHandle, variable eventHandle, variable timeOutMilliseconds)

- connHandle - connection handle (from `ziAPIInit`)
- eventHandle - handle of a previously allocated ZIEvent structure in which the received event will be written
- timeOutMilliseconds - Time to wait for an event in milliseconds. If -1 it will wait forever, if 0 the function returns immediately.
- returns: ziAPI error code or 0 if no error

Checks if an event is available to read. This function returns immediately if an event is pending. Otherwise it waits for an event for up to timeOutMilliseconds. All value changes that occur in nodes that have been subscribed to or in children of nodes that have been subscribed to are sent from the Data Server to the ziAPI session.

Corresponding ziAPI function: `ziAPIPollDataEx`


    ziXOPGetValuesAsPollData(variable connHandle, string path)

- connHandle - connection handle (from `ziAPIInit`)
- path - Path to the Node holding the value. Note: Wildcards and paths referring to streamimg nodes are not permitted.
- returns: ziAPI error code or 0 if no error

Triggers a value request, which will be given back on the poll event queue. Use this function to receive the value of one or more nodes as one or more events using `ziXOPPollDataEx`, even when the node is not subscribed or no value change has occurred.

Corresponding ziAPI function: `ziAPIGetValueAsPollData`


    ZIEvent_getValueType(variable eventHandle, variable *valueType)

- eventHandle - handle of a previously allocated ZIEvent structure
- valueType - after function call contains type of the value in the event
- returns: 0

Retrieves the type of the value in the ZIEvent structure. Constants for the type are defined in ziXOP.ipf as `ZI_VALUE_TYPE_*` constants. The function `ZIValueType_enum_to_string(valueType)` can be called to retrieve the string name of the type.


    ZIEvent_getCount(variable eventHandle, variable *count)

- eventHandle - handle of a previously allocated ZIEvent structure
- count - after function call contains number of values available in the event
- returns: 0

Retrieves the number of values available in the ZIEvent structure.


    ZIEvent_getPath(variable eventHandle, string *path)

- eventHandle - handle of a previously allocated ZIEvent structure
- path - after function call contains path of the node from which the event originates
- returns: 0

Retrieves the number of values available in the ZIEvent structure.


    ZIEvent_getDoubleData(variable eventHandle, variable *data, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- data - after function call contains the data as double value (`ZI_VALUE_TYPE_DOUBLE_DATA`)
- idx - index of the double. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves data as double type value from the indexed position from the event.


    ZIEvent_getDoubleDataTS(variable eventHandle, WAVE timestamp, variable *data, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- timestamp - unsigned 64-bit integer wave with a single element containing the timestamp
- data - after function call contains the data as double value (`ZI_VALUE_TYPE_DOUBLE_DATA_TS`)
- idx - index of the double. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves data as double type value with timestamp from the indexed position from the event.


    ZIEvent_getIntegerData(variable eventHandle, variable *data, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- data - after function call contains the data as integer value (`ZI_VALUE_TYPE_INTEGER_DATA`)
- idx - index of the integer. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves data as integer type value from the indexed position from the event. Note that the integer is returned as double parameter and
is only precise up to 52-bit.


    ZIEvent_getIntegerData_64(variable eventHandle, WAVE data, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- data - numerical wave that after function call is a single element signed 64-bit integer wave containing the integer value (`ZI_VALUE_TYPE_INTEGER_DATA`)
- idx - index of the integer. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves data as 64-bit integer type value from the indexed position from the event.


    ZIEvent_getIntegerDataTS(variable eventHandle, WAVE timestamp, variable *data, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- timestamp - unsigned 64-bit integer wave with a single element containing the timestamp
- data - after function call contains the data as integer value (`ZI_VALUE_TYPE_INTEGER_DATA_TS`)
- idx - index of the integer. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves data as integer type value from the indexed position from the event. Note that the integer is returned as double parameter and
is only precise up to 52-bit.


    ZIEvent_getIntegerDataTS_64(variable eventHandle, WAVE timestamp,  WAVE data, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- timestamp - unsigned 64-bit integer wave with a single element containing the timestamp
- data - numerical wave that after function call is a single element signed 64-bit integer wave containing the integer value (`ZI_VALUE_TYPE_INTEGER_DATA_TS`)
- idx - index of the integer. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves data as 64-bit integer type value and the timestamp from the indexed position from the event.


    ZIEvent_getByteArray(variable eventHandle, WAVE data, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- data - numerical wave that after function call is a unsigned 8-bit integer wave containing the values (`ZI_VALUE_TYPE_BYTE_ARRAY`)
- idx - index of the byte array. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves data as byte array from the indexed position from the event.

    ZIEvent_getByteArray_s(variable eventHandle, string *data, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- data - string that after function call contains the values (`ZI_VALUE_TYPE_BYTE_ARRAY`)
- idx - index of the byte array. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves byte array data as string from the indexed position from the event.


    ZIEvent_getByteArrayTS(variable eventHandle, WAVE timestamp, WAVE data, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- timestamp - unsigned 64-bit integer wave with a single element containing the timestamp
- data - numerical wave that after function call is a unsigned 8-bit integer wave containing the values (`ZI_VALUE_TYPE_BYTE_ARRAY_TS`)
- idx - index of the byte array. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves data as byte array from the indexed position with timestamp from the event.


    ZIEvent_getByteArrayTS_s(variable eventHandle, WAVE timestamp, string *data, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- timestamp - unsigned 64-bit integer wave with a single element containing the timestamp
- data - string that after function call contains the values (`ZI_VALUE_TYPE_BYTE_ARRAY_TS`)
- idx - index of the byte array. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves byte array data as string from the indexed position with timestamp from the event.


    ZIEvent_getTreeChangeData(variable eventHandle, struct ziXOP_TreeChangeData *data, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- data - ziXOP_TreeChangeData structure that after function call contains the values (`ZI_VALUE_TYPE_TREE_CHANGE_DATA`)
- idx - index of the tree change data. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves information about added or removed nodes from the event. The structure ziXOP_TreeChangeData is defined in ziXOP.ipf. The function `ziXOP_initTreeChangeData` initializes the structure with default values.


    ZIEvent_getTreeChangeDataOld(variable eventHandle, struct ziXOP_TreeChangeDataOld *data, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- data - ziXOP_TreeChangeDataOld structure that after function call contains the values (`ZI_VALUE_TYPE_TREE_CHANGE_DATA_OLD`)
- idx - index of the tree change data. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves information about added or removed nodes from the event. The 'old' variant is without timestamp and used in API v1 compatibility mode. The structure ziXOP_TreeChangeDataOld is defined in ziXOP.ipf. The function `ziXOP_initTreeChangeDataOld` initializes the structure with default values.


    ZIEvent_getDemodSample(variable eventHandle, struct ziXOP_DemodSample *data, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- data - ziXOP_DemodSample structure that after function call contains the values (`ZI_VALUE_TYPE_DEMOD_SAMPLE`)
- idx - index of demodulator sample data. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves a demodulator sample from the event. The structure ziXOP_DemodSample is defined in ziXOP.ipf. The function `ziXOP_initDemodSample` initializes the structure with default values.


    ZIEvent_getAuxInSample(variable eventHandle, struct ziXOP_AuxInSample *data, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- data - ziXOP_AuxInSample structure that after function call contains the values (`ZI_VALUE_TYPE_AUXIN_SAMPLE`)
- idx - index of auxiliar input sample data. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves a auxiliar input sample from the event. The structure ziXOP_AuxInSample is defined in ziXOP.ipf. The function `ziXOP_initAuxInSample` initializes the structure with default values.


    ZIEvent_getDIOSample(variable eventHandle, struct ziXOP_DioSample *data, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- data - ziXOP_DioSample structure that after function call contains the values (`ZI_VALUE_TYPE_DIO_SAMPLE`)
- idx - index of digital I/O sample data. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves a digital I/O sample from the event. The structure ziXOP_DioSample is defined in ziXOP.ipf. The function `ziXOP_initDIOSample` initializes the structure with default values.


    ZIEvent_getScopeWave(variable eventHandle, struct ziXOP_ScopeWave *waveInfo, WAVE waveData, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- waveInfo - ziXOP_ScopeWave structure that after function call contains the wave information (`ZI_VALUE_TYPE_SCOPE_WAVE`)
- waveData - a numerical wave that after function call contains a wave with the scope data. The wave type depends on the scope settings (16/32-bit integer, 32 bit floating point). The returned wave is 2-dimensional in the format `waveData[samples][channels]`.
- idx - index of scope wave data. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves a scope wave data from the event. Supported when using API level 4. The structure ziXOP_ScopeWave is defined in ziXOP.ipf. The function `ziXOP_initScopeWave` initializes the structure with default values.


    ZIEvent_getScopeWaveOld(variable eventHandle, struct ziXOP_ScopeWaveOld *waveInfo, WAVE waveData, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- waveInfo - ziXOP_ScopeWaveOld structure that after function call contains the wave information (`ZI_VALUE_TYPE_SCOPE_WAVE_OLD`)
- waveData - a numerical wave that after function call contains a 16-bit signed integer wave with the scope data.
- idx - index of scope wave data. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves a scope shot from the event. Supported when using API level 1. The structure ziXOP_ScopeWaveOld is defined in ziXOP.ipf. The function `ziXOP_initScopeWaveOld` initializes the structure with default values.


    ZIEvent_getPWAWave(variable eventHandle, struct ziXOP_pwaWave *pwaData, WAVE sampleData, variable idx)

- eventHandle - handle of a previously allocated ZIEvent structure
- pwaData - ziXOP_pwaWave structure that after function call contains the wave information (`ZI_VALUE_TYPE_PWA_WAVE`)
- sampleData - a numerical wave that after function call contains a double typed 2-dimensional wave with the PWA data. The wave has four columns with *Phase position of each bin*, *Real PWA result or X component of a demod PWA*, *Y component of the demod PWA* and *Number of events per bin*. The waves row indexes the samples.
- idx - index of scope wave data. The index must be within range, see also `ZIEvent_getCount`.
- returns: 0

Retrieves a PWA samples from the event. The structure ziXOP_pwaWave is defined in ziXOP.ipf. The function `ziXOP_initpwaWave` initializes the structure with default values.


    ZIEvent_getDoubleData_w(variable eventHandle, WAVE data)

- eventHandle - handle of a previously allocated ZIEvent structure
- data - numerical wave that after function call contains all the available data as double typed wave (`ZI_VALUE_TYPE_DOUBLE_DATA`)
- returns: 0

Retrieves all available data as double type wave from the event.

    ZIEvent_getDoubleDataTS_w(variable eventHandle, WAVE timestamp, WAVE data)

- eventHandle - handle of a previously allocated ZIEvent structure
- timestamp - unsigned 64-bit integer wave that contains the timestamps after function call
- data - numerical wave that after function call contains all the available data as double typed wave (`ZI_VALUE_TYPE_DOUBLE_DATA_TS`)- returns: 0

Retrieves all available data as double type wave and the timestamps from the event.


    ZIEvent_getIntegerData_w(variable eventHandle, WAVE data)

- eventHandle - handle of a previously allocated ZIEvent structure
- data - numerical wave that after function call contains all the available integer data in a double typed wave (`ZI_VALUE_TYPE_INTEGER_DATA`)
- returns: 0

Retrieves all available integer data as double type wave from the event. Note that the double typed wave can only store integers up to 52-bit in full precision.


    ZIEvent_getIntegerData_64_w(variable eventHandle, WAVE data)

- eventHandle - handle of a previously allocated ZIEvent structure
- data - numerical wave that after function call contains all the available integer data in a signed 64-bit integer wave (`ZI_VALUE_TYPE_INTEGER_DATA`)
- returns: 0

Retrieves all available integer data as signed 64-bit integer wave from the event.


    ZIEvent_getIntegerDataTS_w(variable eventHandle, WAVE timestamp, WAVE data)

- eventHandle - handle of a previously allocated ZIEvent structure
- timestamp - unsigned 64-bit integer wave that contains the timestamps after function call
- data - numerical wave that after function call contains all the available integer data in a double typed wave (`ZI_VALUE_TYPE_INTEGER_DATA_TS`)
- returns: 0

Retrieves all available integer data as double type wave and the timestamps from the event. Note that the double typed wave can only store integers up to 52-bit in full precision.


    ZIEvent_getIntegerDataTS_64_w(variable eventHandle, WAVE timestamp, WAVE data)

- eventHandle - handle of a previously allocated ZIEvent structure
- timestamp - unsigned 64-bit integer wave that contains the timestamps after function call
- data - numerical wave that after function call contains all the available integer data in a signed 64-bit integer wave (`ZI_VALUE_TYPE_INTEGER_DATA`)
- returns: 0

Retrieves all available integer data as signed 64-bit integer wave and the timestamps from the event.


    ZIEvent_getByteArray_w(variable eventHandle, WAVE lengths, WAVE data)

- eventHandle - handle of a previously allocated ZIEvent structure
- lengths - numerical wave that after function call contains the lengths of each byte array retrieved
- data - numerical wave that after function call is a unsigned 8-bit integer 2-dimensional wave containing the values (`ZI_VALUE_TYPE_BYTE_ARRAY`). The wave format is `data[byteArrayCount][maxLength]`, where maxLength is the maximum length of all available byte arrays. The actual used length is stored in the lengths wave.
- returns: 0

Retrieves all available byte arrays from the event.


    ZIEvent_getByteArray_ws(variable eventHandle, TEXTWAVE data)

- eventHandle - handle of a previously allocated ZIEvent structure
- data - textual wave that after function call contains the byte array values as strings (`ZI_VALUE_TYPE_BYTE_ARRAY`). The wave format is `data[byteArrayCount]`.
- returns: 0

Retrieves all available byte arrays as strings in a text wave from the event.


    ZIEvent_getByteArrayTS_w(variable eventHandle, WAVE timestamp, WAVE lengths, WAVE data)

- eventHandle - handle of a previously allocated ZIEvent structure
- timestamp - unsigned 64-bit integer wave that contains the timestamps after function call
- lengths - numerical wave that after function call contains the lengths of each byte array retrieved. The wave is of type unsigned 32-bit integer.
- data - numerical wave that after function call is a unsigned 8-bit integer 2-dimensional wave containing the values (`ZI_VALUE_TYPE_BYTE_ARRAY_TS`). The wave format is `data[byteArrayCount][maxLength]`, where maxLength is the maximum length of all available byte arrays. The actual used length is stored in the lengths wave.
- returns: 0

Retrieves all available byte arrays and the timestamps from the event.


    ZIEvent_getByteArrayTS_ws(variable eventHandle, WAVE timestamp, WAVE data)

- eventHandle - handle of a previously allocated ZIEvent structure
- timestamp - unsigned 64-bit integer wave that contains the timestamps after function call
- data - textual wave that after function call contains the byte array values as strings (`ZI_VALUE_TYPE_BYTE_ARRAY_TS`). The wave format is `data[byteArrayCount]`.
- returns: 0

Retrieves all available byte arrays as strings in a text wave and the timestamps from the event.


    ZIEvent_getTreeChangeData_w(variable eventHandle, WAVE timestamp, WAVE action, WAVE name)

- eventHandle - handle of a previously allocated ZIEvent structure
- timestamp - unsigned 64-bit integer wave that contains the timestamps after function call
- action - numerical wave that after function call contains the action codes for all occurred tree changes . The wave format is `action[treeChangeCount]` and the type is unsigned 32-bit integer. Constants for the action codes are defined in ziXOP.ipf as `ZI_TREE_ACTION_*`.
- name - textual wave that after function call contains the node names for all occurred tree changes. The wave format is `name[treeChangeCount]`.
- returns: 0

Retrieves all available tree change data (`ZI_VALUE_TYPE_TREE_CHANGE_DATA`) and the timestamps from the event.


    ZIEvent_getDemodSample_w(variable eventHandle, WAVE timestamp, WAVE lockInData, WAVE DIOData, WAVE auxData)

- eventHandle - handle of a previously allocated ZIEvent structure
- timestamp - unsigned 64-bit integer wave that contains the timestamps after function call
- lockInData - numerical wave that after function call contains the lock-in data. The wave is of type double, is 2-dimensional with four columns *X part of the sample*, *Y part of the sample*, *oscillator frequency at that sample* and *oscillator phase at that sample*. The rows index the samples.
- DIOData - numerical wave that after function call contains the digital I/O data. The wave is of type unsigned 32-bit integer, is 2-dimensional with two columns *the current bits of the DIO* and *trigger bits*. The rows index the samples.
- auxData - numerical wave that after function call contains the auxiliary data. The wave is of type double, is 2-dimensional with two columns *value of Aux input 0* and *value of Aux input 1*. The rows index the samples.
- returns: 0

Retrieves all available demod samples (`ZI_VALUE_TYPE_DEMOD_SAMPLE`) and the timestamps from the event.


    ZIEvent_getAuxInSample_w(variable eventHandle, WAVE timestamp, WAVE data)

- eventHandle - handle of a previously allocated ZIEvent structure
- timestamp - unsigned 64-bit integer wave that contains the timestamps after function call
- data - numerical wave that after function call contains the auxiliary inputs data. The wave is of type double, is 2-dimensional with two columns *Channel 0 voltage* and *Channel 1 voltage*. The rows index the samples.
- returns: 0

Retrieves all available auxiliary input samples (`ZI_VALUE_TYPE_AUXIN_SAMPLE`) and the timestamps from the event.


    ZIEvent_getDIOSample_w(variable eventHandle, WAVE timestamp, WAVE data)

- eventHandle - handle of a previously allocated ZIEvent structure
- timestamp - unsigned 64-bit integer wave that contains the timestamps after function call
- data - numerical wave that after function call contains the auxiliary inputs data. The wave is of type unsigned 32-bit integer, is 1-dimensional with the rows indexing the *Digital I/O data*.
- returns: 0

Retrieves all available digital I/O samples (`ZI_VALUE_TYPE_DIO_SAMPLE`) and the timestamps from the event.


### Error Handling ###

    ziXOPGetError(variable errResult, string *buffer, variable *base)

- errResult - ziAPI error code
- buffer - string that contains an error description for the given ziAPI error code after the function call. buffer must not be null on call.
- base - severity of the error, can be `ZI_INFO_BASE`, `ZI_WARNING_BASE` or `ZI_ERROR_BASE`.
- returns: 0 or ziAPI error code

Returns a description and the severity for a ziAPI error code.

### XOP Error Codes ###

Error codes from runtime errors from XOP functions can be converted to comparable codes with

    Function ziXOP_GetError(code)
	  variable code

	  return (code & 0xFFFF) + 10000
    End

The following codes can be returned:

    ERR_NO_ERROR =            10000

No error occurred.

    OLD_IGOR =                10001

The used Igor Pro version is too old for the XOP.

    UNHANDLED_CPP_EXCEPTION = 10002

A unhandled internal exception occurred.

    CPP_EXCEPTION =           10003

A handled internal exception occurred.

    ERR_ASSERT =              10004

An assertion was triggered.

    ERR_CONVERT =             10005

A data type conversion failed.

    ERR_INVALID_TYPE =        10006

Got an invalid type of a wave or variable as input.

    INVALID_CONNECTION_HANDLE = 10007

The connection handle given is invalid.

    COULDNT_MAKE_CONNECTION_HANDLE = 10008

An error occurred on the attempt to create a new connection handle.

    INVALID_EVENT_HANDLE = 10009

The event handle given is invalid.

    COULDNT_MAKE_EVENT_HANDLE = 10010

An error occurred on the attempt to create a new event handle.

    EVENT_TYPE_MISMATCH = 10011

The event type required for data retrieval does not match the actual present event type.

    EVENT_INVALID_INDEX = 10012

When retrieving data from an event an index that is out of range was specified.

    INVALID_64BIT_WAVE_SIZE = 10013

The 64-bit integer wave parameter has the wrong size. Usually for a single 64-bit integer value a wave with a single element is expected.

    INVALID_64BIT_WAVE_TYPE = 10014

The 64-bit integer wave parameter has the wrong type. e.g. if a signed wave is expected and an unsigned was set.

    INVALID_BUFFER_WAVE_TYPE = 10015

When setting byte array data the wave type must be unsigned 8-bit integer wave.

    UNRECOGNISED_ZISCOPEWAVE_SAMPLE_FORMAT = 10016

The sample format code returned for the scope data is unknown to the XOP.
