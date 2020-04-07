#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <SQLConstants>

function sc_openSQLConnection()
	
end

function sc_fetchSQLData()
	// NOT WORKING
	string conStr = "DRIVER={psqlODBC};SERVER=localhost:3307;DATABASE=qdot;UID=qdot-reader;PWD=qdot4ever;CHARSET=UTF8;"
	string sqlquery = "SELECT time, t FROM qdot.lksh370.channel_data WHERE id=(SELECT max(id) FROM qdot.lksh370.channel_data)"
	
	SQLHighLevelOp/CSTR={constr,SQL_DRIVER_NOPROMPT}/o/e=1 sqlquery
end

function sc_closeSQLConnection()

end

function/s sc_checkSQLDriver()
	// listing available drivers:
	variable environRefNum
	string ddesc,attr
	SQLAllocHandle(SQL_HANDLE_ENV,0,environRefNum)
	SQLSetEnvAttrNum(environRefNum,SQL_ATTR_ODBC_VERSION,3)
	SQLDrivers(environRefNum,SQL_FETCH_FIRST,ddesc,256,attr,256)
	
	// check the returned drivers for POSTGRESQL driver
	string mess = ""
	sprintf mess, "Driver: %s found. Attr: %s", ddesc, attr
	print mess
end