#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <SQLConstants>
#include <SQLUtils>

////////////////////////////
//// SQL User functions ////
///////////////////////////

function requestSQLData(statement,[wavenames])
	// Returns data in waves. Each column in a seperate wave.
	// wavenames must be a comma seperated string with wavenames
	// for the data. If wavenames are not passed or number of waves doesn't match
	// the returned number of columns general name waves will be created to hold
	// the data.
	// Data types supported: CHAR, REAL, TIMESTAMP, INTEGER
	
	string statement, wavenames
	
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
	sc_fetchSQLData(s,statement,wavenames)
	
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
	error = SQLSetEnvAttrNum (envRefNum, SQL_ATTR_ODBC_VERSION, 3)
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
		print "[ERROR] \"sc_openSQLConnection\": Unable to connected to database."
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
	elseif(colCount != 1)
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
	elseif(rowCount != 1 && warningIssued == 0)
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
					sprintf result, "%f", data
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

function sc_fetchSQLData(s,statement,wavenames)
	struct sqlRefs &s
	string statement, wavenames
	
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
				// 0 means all good. 27 means another wave excists, we'll overwrite it!
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
		print "[WARNING] \"sc_fetchSQLData\": Will dump data in generic waves with names based on database column names."
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
		print "[WARNING] \"sc_fetchSQLData\": No data to fetch. Try to adjust the SQL statement."
		return 0
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
			print "[WARNING] \"sc_fetchSQLData\": Data type not understood for data going in wave: "+stringfromlist(i,wavenames,",")
		endif
	endfor
	
	variable j=0, nullIndicator=0, data=0, resultNum=0
	string dataStr="", result=""
	for(i=0;i<rowCount;i+=1)
		// one row at a time
		error = SQLFetch(s.statRefNum)
		if(error != SQL_SUCCESS)
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
					print "[WARNING] \"sc_fetchSQLData\": Fetched data is NULL."
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
					print "[WARNING] \"sc_fetchSQLData\": Fetched data is NULL."
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
	
	string jstr = readtxtfile("SQLParameters.txt","config")
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
		default:
			type = "nan"
			break
	endswitch
	
	return type
end

function/s sc_checkSQLDriver()
	// listing available drivers:
	variable environRefNum,err,i=0
	string ddesc,attr,mess
	SQLAllocHandle(SQL_HANDLE_ENV,0,environRefNum)
	SQLSetEnvAttrNum(environRefNum,SQL_ATTR_ODBC_VERSION,3)
	do
		if(i==0)
			err = SQLDrivers(environRefNum,SQL_FETCH_FIRST,ddesc,256,attr,256)
		else
			err = SQLDrivers(environRefNum,SQL_FETCH_NEXT,ddesc,256,attr,256)
		endif
		if(err==0)
			sprintf mess, "Driver: %s. Attr: %s", ddesc, attr
			print mess
		endif
		i+=1
	while(err==0)
end

////////////////////////
//// Test functions ////
///////////////////////

function sc_fetchSQLDataTest()
	string constr = "" //add real constr
	//string sqlquery = "SELECT DISTINCT ON (ch_idx) ch_idx, time, t FROM qdot.lksh370.channel_data ORDER BY ch_idx, time DESC;"
	string sqlquery = "SELECT t FROM qdot.lksh370.channel_data WHERE ch_idx=2 ORDER BY time DESC LIMIT 1;"
	//string sqlquery = "SELECT t, time FROM qdot.lksh370.channel_data WHERE ch_idx=2 AND time > TIMESTAMP '2020-01-13 00:00:00.00'"
	//string sqlquery = "SELECT * FROM INFORMATION_SCHEMA.COLUMNS"
	//print sqlquery
	SQLHighLevelOp/CSTR={constr,SQL_DRIVER_NOPROMPT}/o/e=1 sqlquery
end