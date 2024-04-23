#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <SQLConstants>

////////////////////////////
//// SQL User functions ////
////////////////////////////

function requestSQLData(statement,[wavenames, verbose])
	// Returns data in waves. Each column in a seperate wave.
	// wavenames must be a comma seperated string with wavenames
	// for the data. If wavenames are not passed or number of waves doesn't match
	// the returned number of columns general name waves will be created to hold
	// the data.
	// Data types supported: CHAR, REAL, TIMESTAMP, INTEGER

	string statement, wavenames
	variable verbose

	if(paramisdefault(wavenames))
		wavenames = ""
	endif

	// set by InitScanController
	nvar sqldriver_avaliable
	svar sqldriver

	// check if driver avaliable
	if(!sqldriver_avaliable)
		print "[ERROR] \"sc_fetchSQLTempSet\": No SQL driver avaliable."
		abort
	endif

	// open connection to database
	struct sqlRefs s
	sc_openSQLConnection(s)

	// fetch data from datebase
	sc_fetchSQLData(s,statement,wavenames, verbose=verbose)

	// close connection to database
	sc_closeSQLConnection(s)
end

function/s requestSQLValue(statement,[key])
	// Returns a single value regardless of how many values the SQL statement returns.
	// Data types supported: CHAR, REAL, TIMESTAMP, INTEGER
	// The following statement returns last recorded 4K plate temperature:
	// "SELECT t FROM qdot.lksh370.channel_data WHERE ch_idx=2 ORDER BY time DESC LIMIT 1;"
	// Passing a key will return a key:value string

	string statement, key

	if(paramisdefault(key))
		key=""
	endif

	// set by InitScanController
	nvar sqldriver_avaliable
	svar sqldriver

	// check if driver avaliable
	if(!sqldriver_avaliable)
		print "[ERROR] \"sc_fetchSQLTempSet\": No SQL driver avaliable."
		abort
	endif

	// open connection to database
	struct sqlRefs s
	sc_openSQLConnection(s)

	// fetch data from database
	string result=""
	result = sc_fetchSQLSingle(s,statement,key=key)

	// close connection to database
	sc_closeSQLConnection(s)

	return result
end


function/s SQL_format_time(time_s)
	// Converts time since 01/01/1904 in seconds to the format that SQL uses for its TIMESTAMP
	variable time_s

	string time_str
	sprintf time_str "'%s %s'", secs2Date(time_s, -2), secs2time(time_s, 3, 2)
											//'2020-01-13 23:00:00.00'  << This is the format
	return time_str
end

///////////////////////
//// SQL Utilities ////
//////////////////////

function sc_openSQLConnection(s)
	struct sqlRefs &s

	// get database connection parameters
	svar sqldriver
	string connParams = sc_readSQLConnectionParameters()

	// allocate SQL handles
	variable envRefNum=0, connRefNum=0, error=0
	// allocate env handle
	error = SQLAllocHandle(SQL_HANDLE_ENV, 0, envRefNum)
	if(error != SQL_SUCCESS)
		print "[ERROR] \"sc_openSQLConnection\": Unable to allocate environment handle."
		abort
	endif

	// set ODBC version
	error = SQLSetEnvAttrNum(envRefNum, SQL_ATTR_ODBC_VERSION, 3)
	if(error != SQL_SUCCESS)
		SQLFreeHandle(SQL_HANDLE_ENV,envRefNum)
		print "[ERROR] \"sc_openSQLConnection\": Unable to set ODBC version."
		abort
	endif

	// allocate connection handle
	error = SQLAllocHandle(SQL_HANDLE_DBC, envRefNum, connRefNum)
	if(error != SQL_SUCCESS)
		SQLFreeHandle(SQL_HANDLE_ENV,envRefNum)
		print "[ERROR] \"sc_openSQLConnection\": Unable to allocate connection handle."
		abort
	endif

	// open connection to database
	string outConnStr = ""
	variable outConnStrLen = 0
	string connStr = ""
	sprintf connStr, "DRIVER=%s;SERVER=%s;PORT=%s;DATABASE=%s;UID=%s;PWD=%s;CHARSET=UTF8;", sqldriver, stringbykey("server",connParams,":",","), stringbykey("port",connParams,":",","), stringbykey("database",connParams,":",","), stringbykey("uid",connParams,":",","), stringbykey("pwd",connParams,":",",")
	error = SQLDriverConnect(connRefNum,connStr,outConnStr,outConnStrLen,SQL_DRIVER_NOPROMPT)
	if(error != SQL_SUCCESS)
		SQLFreeHandle(SQL_HANDLE_DBC, connRefNum)
		SQLFreeHandle(SQL_HANDLE_ENV, envRefNum)
		print "[ERROR] \"sc_openSQLConnection\": Unable to connect to database."
		abort
	endif

	// add the handles to the handle structure
	s.envRefNum = envRefNum
	s.connRefNUm = connRefNum
end

function/s sc_fetchSQLSingle(s,statement,[key])
	struct sqlRefs &s
	string statement, key

	variable statRefNum = 0, error = 0
	error = SQLAllocHandle(SQL_HANDLE_STMT,s.connRefNum,statRefNum)
	if(error != SQL_SUCCESS)
		sc_closeSQLConnection(s)
		print "[ERROR] \"sc_fetchSQLSingle\": Unable to allocate statement handle."
		abort
	else
		s.statRefNum = statRefNum
	endif

	// write statement to database
	error = SQLExecDirect(s.statRefNum,statement)
	if(error != SQL_SUCCESS)
		sc_closeSQLConnection(s)
		print "[ERROR] \"sc_fetchSQLSingle\": Statement is likely not formatted correctly."
		abort
	endif

	// get number of columns
	variable colCount=0, warningIssued=0
	error = SQLNumResultCols(s.statRefNum, colCount)
	if(error != SQL_SUCCESS)
		sc_closeSQLConnection(s)
		print "[ERROR] \"sc_fetchSQLSingle\": Unable to fetch colunm count."
		abort
	elseif(colCount > 1)
		print "[WARNINIG] \"sc_fetchSQLSingle\": More than a single value is being returned! The last value will be set as result."
		warningIssued = 1
	endif

	// get number of rows
	variable rowCount=0
	error = SQLRowCount(s.statRefNum,rowCount)
	if(error != SQL_SUCCESS)
		sc_closeSQLConnection(s)
		print "[ERROR] \"sc_fetchSQLSingle\": Unable to fetch row count."
		abort
	elseif(rowCount > 1 && warningIssued == 0)
		print "[WARNINIG] \"sc_fetchSQLSingle\": More than a single value is being returned! The last value will be set as result."
	endif

	variable i=0, j=0, err=0, data=0, nullIndicator=0, returnedType=0
	variable colsize=0, decDigits=0, isNullable=0
	string result="", keydata="", newKeys="", dataStr="", colName=""
	for(i=0;i<rowCount;i+=1)
		// one row at a time
		try
			error = SQLFetch(s.statRefNum)
			if(error != SQL_SUCCESS)
				abortonvalue 1,1
			endif
		catch
			// check if real error or end of rows
			err = GetRTError(1)
			if(error == SQL_NO_DATA)
				// normal behavior, exit loop
				break
			else
				sc_closeSQLConnection(s)
				print "[ERROR] \"sc_fetchSQLSingle\": Unable to fetch data."
				abort
			endif
		endtry

		for(j=0;j<colCount;j+=1)
			// loop over each column
			// check retuned type
			error = SQLDescribeCol(s.statRefNum,j+1,colName,256,returnedType,colSize,decDigits,isNullable)
			if(returnedType==SQL_INTEGER || returnedType==SQL_REAL)
				error = SQLGetDataNum(s.statRefNum,j+1,data,nullIndicator)
				if(error != SQL_SUCCESS)
					sc_closeSQLConnection(s)
					print "[ERROR] \"sc_fetchSQLSingle\": Unable to fetch data."
					abort
				elseif(nullIndicator == SQL_NULL_DATA)
					print "[WARNING] \"sc_fetchSQLSingle\": Fetched data is NULL."
					result = "nan"
				else
					sprintf result, "%.9f", data
				endif
			elseif(returnedType==SQL_CHAR || returnedType==SQL_TYPE_TIMESTAMP)
				error = SQLGetDataStr(s.statRefNum,j+1,dataStr,1024,nullIndicator)
				if(error != SQL_SUCCESS)
					sc_closeSQLConnection(s)
					print "[ERROR] \"sc_fetchSQLSingle\": Unable to fetch data."
					abort
				elseif(nullIndicator == SQL_NULL_DATA)
					print "[WARNING] \"sc_fetchSQLSingle\": Fetched data is NULL."
					result = "nan"
				else
					sprintf result, "%s", dataStr
				endif
			else
				print "[WARNING] \"sc_fetchSQLSingle\": Fetched data type not supported."
				result = "nan"
			endif
		endfor
	endfor

	if(!paramisdefault(key) && cmpstr(key,"")!=0)
		result = key+":"+result
	endif

	return result
end

function sc_fetchSQLData(s,statement,wavenames, [verbose])
	struct sqlRefs &s
	string statement, wavenames
	variable verbose
	variable/g sql_response_code = 0  // 0=success, 1=no_data, 2=other warning, -1=error

	verbose = paramisdefault(verbose) ? 1 : verbose

	// allocate statement handle
	variable statRefNum = 0, error = 0
	error = SQLAllocHandle(SQL_HANDLE_STMT,s.connRefNum,statRefNum)
	if(error != SQL_SUCCESS)
		sc_closeSQLConnection(s)
		print "[ERROR] \"sc_fetchSQLData\": Unable to allocate statement handle."
		abort
	else
		s.statRefNum = statRefNum
	endif

	// check the wavenames
	variable useGeneralWaves=0,i=0
	string errMess=""
	if(cmpstr(wavenames,"")==0)
		useGeneralWaves = 1
	else
		for(i=0;i<itemsinlist(wavenames,",");i+=1)
			if(checkname(stringfromlist(i,wavenames,","),1) == 0 || checkname(stringfromlist(i,wavenames,","),1) == 27)
				// 0 means all good. 27 means another wave exists, we'll overwrite it!
			else
				sc_closeSQLConnection(s)
				sprintf errMess, "[ERROR] \"sc_fetchSQLData\": Wave name %s used by string, variable or function.", stringfromlist(i,wavenames,",")
				print errMess
				abort
			endif
		endfor
	endif

	// write statement to database
	error = SQLExecDirect(s.statRefNum,statement)
	if(error != SQL_SUCCESS)
		sc_closeSQLConnection(s)
		print "[ERROR] \"sc_fetchSQLData\": Statement is likely not formatted correctly."
		abort
	endif

	// get number of columns
	variable colCount=0, warningIssued=0
	error = SQLNumResultCols(s.statRefNum, colCount)
	if(error != SQL_SUCCESS)
		sc_closeSQLConnection(s)
		print "[ERROR] \"sc_fetchSQLData\": Unable to fetch colunm count."
		abort
	elseif(itemsinlist(wavenames,",") != colCount && useGeneralWaves==0)
		sql_response_code = 2
		if (verbose)
			print "[WARNING] \"sc_fetchSQLData\": Will dump data in generic waves with names based on database column names."
		endif
		useGeneralWaves = 1
	endif

	// get column data types
	string colName="",wavedatatypes=""
	variable dataType=0, colSize=0, decDigits=0, isNullable=0
	for(i=0;i<colCount;i+=1)
		error = SQLDescribeCol(s.statRefNum,i+1,colName,256,dataType,colSize,decDigits,isNullable)
		if(error != SQL_SUCCESS)
			sc_closeSQLConnection(s)
			print "[ERROR] \"sc_fetchSQLData\": Unable to fetch colunm parameters."
			abort
		endif
		if(useGeneralWaves)
			wavenames = addlistitem(uniquename(cleanupname(colName,0),1,0),wavenames,",",inf)
		endif
		wavedatatypes = addlistitem(sc_mapSQLTypeToWaveType(dataType),wavedatatypes,",",inf)
	endfor

	// get number of rows
	variable rowCount=0
	error = SQLRowCount(s.statRefNum,rowCount)
	if(error != SQL_SUCCESS)
		sc_closeSQLConnection(s)
		print "[ERROR] \"sc_fetchSQLData\": Unable to fetch row count."
		abort
	elseif(rowCount < 1)
		sql_response_code = 1
		if (verbose)
			print "[WARNING] \"sc_fetchSQLData\": No data to fetch. Try to adjust the SQL statement."
		endif
	endif

	// make waves to hold data
	variable err=0
	for(i=0;i<colCount;i+=1)
		if(numtype(str2num(stringfromlist(i,wavedatatypes,","))) == 0)
			try
				make/o/y=(str2num(stringfromlist(i,wavedatatypes,",")))/n=(rowCount) $stringfromlist(i,wavenames,",")
				abortonrte
			catch
				err = getrterror(1)
				sc_closeSQLConnection(s)
				sprintf errMess, "[ERROR] \"sc_fetchSQLData\": Wave name %s used by string, variable or function.", stringfromlist(i,wavenames,",")
				print errMess
				abort
			endtry
		else
			sql_response_code = 2
			if (verbose)
				print "[WARNING] \"sc_fetchSQLData\": Data type not understood for data going in wave: "+stringfromlist(i,wavenames,",")
			endif
		endif
	endfor

	variable j=0, nullIndicator=0, data=0, resultNum=0
	string dataStr="", result=""
	for(i=0;i<rowCount;i+=1)
		// one row at a time
		error = SQLFetch(s.statRefNum)
		if(error == SQL_NO_DATA)
			// no data to fetch. Likely that the statement didn't return any data
			break
		elseif(error != SQL_SUCCESS)
			sc_closeSQLConnection(s)
			print "[ERROR] \"sc_fetchSQLData\": Unable to fetch data."
			abort
		endif

		for(j=0;j<colCount;j+=1)
			// loop over each column
			if(numtype(str2num(stringfromlist(j,wavedatatypes,","))) != 0)
				// data type not supported
				continue
			elseif(str2num(stringfromlist(j,wavedatatypes,",")) == 0)
				// text data type
				error = SQLGetDataStr(s.statRefNum,j+1,dataStr,1024,nullIndicator)
				if(error != SQL_SUCCESS)
					sc_closeSQLConnection(s)
					print "[ERROR] \"sc_fetchSQLData\": Unable to fetch data."
					abort
				elseif(nullIndicator == SQL_NULL_DATA)
					sql_response_code = 2
					if (verbose)
						print "[WARNING] \"sc_fetchSQLData\": Fetched data is NULL."
					endif
					result = "nan"
				else
					sprintf result, "%s", dataStr
				endif
				wave/t textwn = $stringfromlist(j,wavenames,",")
				textwn[i] = result
			else
				// numeric data type
				error = SQLGetDataNum(s.statRefNum,j+1,data,nullIndicator)
				if(error != SQL_SUCCESS)
					sc_closeSQLConnection(s)
					print "[ERROR] \"sc_fetchSQLData\": Unable to fetch data."
					abort
				elseif(nullIndicator == SQL_NULL_DATA)
					sql_response_code = 2
					if (verbose)
						print "[WARNING] \"sc_fetchSQLData\": Fetched data is NULL."
					endif
					resultNum = nan
				else
					resultNum = data
				endif
				wave numwn = $stringfromlist(j,wavenames,",")
				numwn[i] = resultNum
			endif
		endfor
	endfor

	if(useGeneralWaves)
		print "[INFO] \"sc_fetchSQLData\": Waves generated are:"
		for(i=0;i<itemsinlist(wavenames,",");i+=1)
			if(numtype(str2num(stringfromlist(i,wavedatatypes,","))) == 0)
				print "\t"+stringfromlist(i,wavenames,",")
			endif
		endfor
	endif
end

function sc_closeSQLConnection(s)
	struct sqlRefs &s

	// close cursor and discard any pending results
	// ignore errors
	SQLCloseCursor(s.statRefNum)

	// close connection to database and free all handles
	SQLFreeHandle(SQL_HANDLE_STMT, s.statRefNum)
	SQLDisconnect(s.connRefNum)
	SQLFreeHandle(SQL_HANDLE_DBC, s.connRefNum)
	SQLFreeHandle(SQL_HANDLE_ENV, s.envRefNum)
end

function/s sc_readSQLConnectionParameters()
	// reads SQL setup parameters from SQLParameters.txt file on "config" path.

	string jstr = readtxtfile("SQLConfig.txt","setup")
	if(cmpstr(jstr,"")==0)
		abort
	endif
	string connParams = ""
	connParams = addlistitem("server:"+getJSONvalue(jstr,"server"),connParams,",",inf)
	connParams = addlistitem("port:"+getJSONvalue(jstr,"port"),connParams,",",inf)
	connParams = addlistitem("database:"+getJSONvalue(jstr,"database"),connParams,",",inf)
	connParams = addlistitem("uid:"+getJSONvalue(jstr,"uid"),connParams,",",inf)
	connParams = addlistitem("pwd:"+getJSONvalue(jstr,"pwd"),connParams,",",inf)

	return connParams
end

structure sqlRefs
	// structure that holds sql handle refs
	variable envRefNum
	variable connRefNum
	variable statRefNum
endstructure

function/s sc_mapSQLTypeToWaveType(dataType)
	variable dataType

	string type=""
	switch(dataType)
		case SQL_INTEGER:
			type = "0x20"
			break
		case SQL_REAL:
			type = "0x02"
			break
		case SQL_CHAR:
			type = "0"
			break
		case SQL_TYPE_TIMESTAMP:
			type = "0"
			break
		case SQL_VARCHAR:
			type = "0"
			break
		default:
			type = "nan"
			break
	endswitch

	return type
end

function/s sc_checkSQLDriver([printToCommandLine])
	// Locating avaliable drivers
	// function will set global parameters:
	// nvar sqldriver_avaliable
	// svar sqldriver
	// if printToCommandLine=1 the global parameters
	// won't be set. Intended for diagnostics.
	//"DRIVER=/opt/homebrew/Library/Taps/microsoft/homebrew-mssql-release/Formula/mssql-tools18.rb;"


	variable printToCommandLine

	if(paramisdefault(printToCommandLine))
		printToCommandLine = 0
	elseif(printToCommandLine != 1)
		printToCommandLine = 0
		print "[WARNING] \"sc_checkSQLDriver\": Setting printToCommandLine = 0"
	endif

	// allocate environment handle
	variable envRefNum=0, error=0, i=0
	string ddesc="", attr="", mess="", drivers=""
	SQLAllocHandle(SQL_HANDLE_ENV,0,envRefNum)
	if(error != SQL_SUCCESS)
		print "[ERROR] \"sc_checkSQLDriver\": Unable to allocate environment handle."
		abort
	endif

	// set ODBC version
	SQLSetEnvAttrNum(envRefNum,SQL_ATTR_ODBC_VERSION,3)
	if(error != SQL_SUCCESS)
		SQLFreeHandle(SQL_HANDLE_ENV,envRefNum)
		print "[ERROR] \"sc_checkSQLDriver\": Unable to set ODBC version."
		abort
	endif

	do
		if(i==0)
			error = SQLDrivers(envRefNum,SQL_FETCH_FIRST,ddesc,256,attr,256)
		else
			error = SQLDrivers(envRefNum,SQL_FETCH_NEXT,ddesc,256,attr,256)
		endif
		if(error == SQL_NO_DATA)
			// no more drivers
			break
		elseif(error != SQL_SUCCESS)
			print "[ERROR] \"sc_checkSQLDriver\": Unable to fetch drivers."
			abort
		else
			// add the driver to the collection
			drivers = addlistitem(ddesc,drivers,",")
		endif
		i+=1
	while(1)

	// if printToCommandLine=1 just print result and exit
	if(printToCommandLine)
		print "[INFO] \"sc_checkSQLDriver\": Avaliable drivers are:"
		for(i=0;i<itemsinlist(drivers,",");i+=1)
			print "\t"+stringfromlist(i,drivers,",")
		endfor
	else
		variable/g sqldriver_available = 0
		string/g sqldriver = ""
		// check if right driver is installed
		// looking for PostgreSQL ANSI(x64)
		for(i=0;i<itemsinlist(drivers,",");i+=1)
			if(cmpstr(stringfromlist(i,drivers,","),"PostgreSQL ANSI(x64)") == 0)
				// we have the drivers we are looking for!
				sqldriver_available = 1
				sqldriver = stringfromlist(i,drivers,",")
				break
			endif
		 endfor
		 if(!sqldriver_available)
		 	print "[WARNING] \"sc_checkSQLDriver\": Driver not found. SQL won't work!"
		 endif
	endif

	// free handle
	SQLFreeHandle(SQL_HANDLE_ENV,envRefNum)
end

function timestamp2secs(timestamp)
	// converts timestamp to secs
	// timestamp: YYYY:MM:DD HH:MM:SS.+S
	string timestamp

	string year, month, day, hours, minutes, seconds, fraction
	string expr="([[:digit:]]{4})-([[:digit:]]{2})-([[:digit:]]{2}) ([[:digit:]]{2}):([[:digit:]]{2}):([[:digit:]]{2}).([[:digit:]]+)"
	splitstring/e=(expr) timestamp, year, month, day, hours, minutes, seconds, fraction

	if(v_flag == 0)
		// wrong input format
		print "[ERROR] \"time2secs\": Wrong input format! Timestamp must be YYYY:MM:DD HH:MM:SS.+S"
		abort
	endif

	sprintf fraction, "0.%s", fraction
	variable fracSecs = str2num(fraction)

	return date2secs(str2num(year),str2num(month),str2num(day)) + 3600*str2num(hours) + 60*str2num(minutes) + str2num(seconds) + fracSecs
end

function/s sc_SQLDatabaseTime()
	string statement = "SELECT NOW();"
	string result = requestSQLValue(statement)

	return result
end

function/s sc_SQLtimestamp(secs)
	// constructs a valid sql timestamp "secs" into the past,
	// based on the current database time.
	variable secs

	// get current database time
	string databaseTime = sc_SQLDatabaseTime()

	// convert to seconds and substract secs
	variable newTimeSecs = timestamp2secs(databaseTime) - secs

	// construct new timestamp
	string newTimestamp
	string newDate = secs2date(newTimeSecs,-2,"-")
	string newTime = secs2time(newTimeSecs,3,6)

	sprintf newTimestamp, "%s %s", newDate, newTime

	return newTimestamp
end

function sc_SQLinformation_schema()
	// retrun an overveiw of the database
	// add WHERE table_name = 'table_name' to get info on specific table
	string statement = "SELECT * FROM information_schema.columns WHERE table_name = 'channel_data'"

	svar sqldriver
	string connParams = sc_readSQLConnectionParameters()
	string connStr = ""
	sprintf connStr, "DRIVER=%s;SERVER=%s;PORT=%s;DATABASE=%s;UID=%s;PWD=%s;CHARSET=UTF8;", sqldriver, stringbykey("server",connParams,":",","), stringbykey("port",connParams,":",","), stringbykey("database",connParams,":",","), stringbykey("uid",connParams,":",","), stringbykey("pwd",connParams,":",",")
	SQLHighLevelOp/CSTR={connStr,SQL_DRIVER_NOPROMPT}/o/e=1 statement
end

////////////////////////
//// Test functions ////
///////////////////////

function sc_fetchSQLDataTest()

	svar sqldriver
	string database = "bf"
	string connParams = sc_readSQLConnectionParameters()
	string connStr = ""
	sprintf connStr, "DRIVER=%s;SERVER=%s;PORT=%s;DATABASE=%s;UID=%s;PWD=%s;CHARSET=UTF8;", sqldriver, stringbykey("server",connParams,":",","), stringbykey("port",connParams,":",","), stringbykey("database",connParams,":",","), stringbykey("uid",connParams,":",","), stringbykey("pwd",connParams,":",",")

	string sqlquery = "SELECT DISTINCT ON (channel_id) channel_id, time FROM bluefors.ld.pressure ORDER BY channel_id, time DESC;"
	//string sqlquery = "SELECT ch_idx, time, t FROM qdot.lksh370.channel_data WHERE ch_idx=1 ORDER BY time DESC LIMIT 1;"
	//string sqlquery = "SELECT t, time FROM qdot.lksh370.channel_data WHERE ch_idx=2 AND time > TIMESTAMP '2020-01-13 00:00:00.00'"
	//string sqlquery = "SELECT * FROM INFORMATION_SCHEMA.COLUMNS"
	//string sqlquery = "SELECT ch_idx, time, t FROM (SELECT ch_idx, time, t, ROW_NUMBER() OVER (PARTITION BY ch_idx ORDER BY time DESC) rn FROM qdot.lksh370.channel_data) tmp WHERE rn = 1;"
	//print sqlquery
	SQLHighLevelOp/CSTR={connStr,SQL_DRIVER_NOPROMPT}/o/e=1 sqlquery
end

function timeSQLStatements()
	// statement1 = 0.03s
	// statement2 = 0.13s (full loop)
	// statement3 = 0.16s (full loop)

	string wavenames1 = "channels,timestamp,temperature"
	string statement1 = "SELECT DISTINCT ON (ch_idx) ch_idx, time, t FROM qdot.lksh370.channel_data WHERE time > TIMESTAMP '2020-01-13 23:00:00.00' ORDER BY ch_idx, time DESC;"

	string database = "ls"
	variable starttime1 = stopmstimer(-2)
	requestSQLData(statement1,wavenames=wavenames1)
	variable totaltime1 = (stopmstimer(-2)-starttime1)*1e-6

	string wavenames2 = "channels,timestamp,temperature"
	string statement2 = ""
	string ch = "1,2,4,5,6"

	variable i=0
	variable starttime2 = stopmstimer(-2)
	for(i=0;i<itemsinlist(ch,",");i+=1)
		sprintf statement2, "SELECT ch_idx, time, t FROM qdot.lksh370.channel_data WHERE ch_idx=%s ORDER BY time DESC LIMIT 1;", stringfromlist(i,ch,",")
		requestSQLData(statement2,wavenames=wavenames2)
	endfor
	variable totaltime2 = (stopmstimer(-2)-starttime2)*1e-6

	string statement3=""
	variable starttime3 = stopmstimer(-2)
	for(i=0;i<itemsinlist(ch,",");i+=1)
		sprintf statement3, "SELECT t FROM qdot.lksh370.channel_data WHERE ch_idx=%s AND time > TIMESTAMP '2020-01-13 23:00:00.00' ORDER BY time DESC LIMIT 1;", stringfromlist(i,ch,",")
		requestSQLValue(statement3)
	endfor
	variable totaltime3 = (stopmstimer(-2)-starttime3)*1e-6

	string mess
	sprintf mess, "Statement #1: %f s, statement #2: %f s, statement #3: %f s", totaltime1, totaltime2, totaltime3
	print mess
end



