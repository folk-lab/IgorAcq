#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

//////////////////
/// HTTP INSTR ///
//////////////////


function openHTTPinstr(mandatory, [options, verbose])
	string mandatory // mandatory: "name= ,instrID= ,url = "
	string options   // options: "test_ping= "
	variable verbose

	if(paramisdefault(options))
		options=""
	endif
	
	if(paramisdefault(verbose))
		verbose=1
	elseif(verbose!=1)
		verbose=0
	endif
	
	// create global variable
	string name = StringByKey("name", mandatory, "=", ",")
	string url = StringByKey("url", mandatory, "=", ",")
	string var_name = StringByKey("instrID", mandatory, "=", ",")

	string /g $var_name = url
	if(verbose==1)
		printf "%s (%s) connected as %s\r", name, url, var_name
	endif

	if(strlen(options)>0)
	
		// run test query
		string cmd
		cmd = StringByKey("test_ping",options,"=", ",")
		if(strlen(cmd)>0)
			
			// do something here with that command
			string response = ""
			
			if(verbose)
				printf "\t-- %s responded with: %s\r", name, response
			endif
		else
			if(verbose)
				printf "\t-- No test\r"
			endif
		endif

	endif

end


function/s postHTTP(instrID,cmd,payload,headers)
	string instrID, cmd, payload, headers
	string response=""

//	print instrID+cmd, payload
	URLRequest /TIME=15.0 /DSTR=payload url=instrID+cmd, method=post, headers=headers

	if (V_flag == 0)    // No error
		response = S_serverResponse // response is a JSON string
		if (V_responseCode != 200)  // 200 is the HTTP OK code
			print "[ERROR] HTTP response code " + num2str(V_responseCode)
			if(strlen(response)>0)
		   	printf "[MESSAGE] %s\r", getJSONvalue(response, "error")
		   endif
		   return ""
		else
			return response
		endif
   else
        abort "HTTP connection error."
   endif
end


function/s putHTTP(instrID,cmd,payload,headers)
	string instrID, cmd, payload, headers
	string response=""

//	print "url=",instrID+cmd
//	print "payload=", payload
//	print headers
	
	URLRequest /TIME=15.0 /DSTR=payload url=instrID+cmd, method=put, headers=headers

	if (V_flag == 0)    // No error
		response = S_serverResponse // response is a JSON string
		print V_responseCode
		print V_flag
		if (V_responseCode != 200)  // 200 is the HTTP OK code
			print "[ERROR] HTTP response code " + num2str(V_responseCode)
			if(strlen(response)>0)
		   	printf "[MESSAGE] %s\r", getJSONvalue(response, "error")
		   endif
		   return ""
		else
			return response
		endif
   else
        abort "HTTP connection error."
   endif
end


function/s getHTTP(instrID,cmd,headers)
	string instrID, cmd, headers
	string response, error

//	print instrID+cmd
	URLRequest /TIME=25.0 url=instrID+cmd, method=get, headers=headers

	if (V_flag == 0)    // No error
		response = S_serverResponse // response is a JSON string
		if (V_responseCode != 200)  // 200 is the HTTP OK code
			print "[ERROR] HTTP response code " + num2str(V_responseCode)
		   return ""
		else
			return response
		endif
   else
    	print "HTTP connection error."
		return ""
   endif
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////Json functions//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/////////////
/// JSON  ///
/////////////









