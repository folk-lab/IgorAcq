#pragma rtGlobals=1		// Use modern global access method.

// GOAL: A pure IGOR implementation of the JSON standard
//       Try to use as many built in string functions as possible to avoid encoding trouble
//
// RULES: https://tools.ietf.org/html/rfc7159.html
//        If something here doesn't make sense, go read the rules
//
// Written by Nik Hartman (September 2017) -- This whole thing is sloppy a.f. 

///////////////////////////
//// utility functions ////
///////////////////////////

function findJSONtype(str)
	//
	// this checks quickly to find what type something is intended to be
	// it makes no effort to check if str is a valid version of that type
	// in fact, I take advantage of that later by sending this function big chunks of 
	// characters that only _start_ with the thing I want
	//
	// RETURN TYPES:
	// 1 -- object
	// 2 -- array
	// 3 -- number -- no float/int distinction in igor
	// 4 -- string
	// 5 -- bool
	// 6 -- null
	//
	
	string str
	str = TrimString(str) // trim leading/trailing whitespace
	str = LowerStr(str)   // I don't care if you got the cases right
	if( strlen(str)==0 )
		return -1
	endif
	
	string numRegex = "([-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?)"
	if(stringmatch(str[0], "{")==1)
		// this is an object
		return 1
	elseif(stringmatch(str[0], "[")==1)
		// this is an array
		return 2
	elseif(stringmatch(str[0], "\"")==1)
		// this is a string
		return 4
	elseif(stringmatch(str[0,3], "true")==1 || stringmatch(str[0,4], "false")==1)
		// this is a boolean
		return 5
	elseif(stringmatch(str[0,3], "null")==1)
		// this is null
		return 6
	elseif(grepstring(str, "([-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?)")==1)
		// this is a number
		return 3
	else
		print "[WARNING] Value does not fit any JSON type:", str
		return -1
	endif
end

function countBrackets(str)
	// count how many brackets are in the string
	// +1 for }
	// -1 for {
	string str
	variable bracketCount = 0, i = 0, escaped = 0
	for(i=0; i<strlen(str); i+=1)
	
		// check if the current character is escaped
		if(i!=0)
			if( StringMatch(str[i-1], "\\") == 1)
				escaped = 1
			else
				escaped = 0
			endif
		endif
	
		// count opening brackets
		if( StringMatch(str[i], "{" ) == 1 && escaped == 0)
			bracketCount -= 1
		endif
		
		// count closing brackets
		if( StringMatch(str[i], "}" ) == 1 && escaped == 0)
			bracketCount += 1
		endif
		
	endfor
	return bracketCount
end

function /S readJSONobject(jstr)
	// given a string starting with {
	// return everything upto and including the matching }
	// ignores escaped brackets "\{" and "\}"
	
	string jstr
	jstr = TrimString(jstr) // just in case this didn't already happen
	
	variable i=0, openBrackets=0, startPos=-1, endPos=-1, escaped=0
	for(i=0; i<strlen(jstr); i+=1)
	
		// check if the current character is escaped
		if(i!=0)
			if( StringMatch(jstr[i-1], "\\") == 1)
				escaped = 1
			else
				escaped = 0
			endif
		endif
	
		// count opening brackets
		if( StringMatch(jstr[i], "{" ) == 1 && escaped == 0)
			openBrackets+=1
			if(startPos==-1)
				startPos = i
			endif
		endif
		
		// count closing brackets
		if( StringMatch(jstr[i], "}" ) == 1 && escaped == 0)
			openBrackets-=1
			if(openBrackets==0)
				// found the last closing bracket
				endPos = i
				break
			endif
		endif
		
	endfor

	if(openBrackets!=0 || startPos==-1 || endPos==-1)
		print "[WARNING] This JSON string is bullshit: ", jstr
		return ""
	endif
	
	return jstr[startPos, endPos]
end

function /S readJSONarray(jstr)
	// given a string starting with [
	// return everything upto and including the matching ]
	// ignores escaped brackets "\[" and "\]"
	
	string jstr
	jstr = TrimString(jstr) // just in case this didn't already happen
	
	variable i=0, openBrackets=0, startPos=-1, endPos=-1, escaped=0
	for(i=0; i<strlen(jstr); i+=1)
	
		// check if the current character is escaped
		if(i!=0)
			if( StringMatch(jstr[i-1], "\\") == 1)
				escaped = 1
			else
				escaped = 0
			endif
		endif
	
		// count opening brackets
		if( StringMatch(jstr[i], "[" ) == 1 && escaped == 0)
			openBrackets+=1
			if(startPos==-1)
				startPos = i
			endif
		endif
		
		// count closing brackets
		if( StringMatch(jstr[i], "]" ) == 1 && escaped == 0)
			openBrackets-=1
			if(openBrackets==0)
				// found the last closing bracket
				endPos = i
				break
			endif
		endif
		
	endfor

	if(openBrackets!=0 || startPos==-1 || endPos==-1)
		print "[WARNING] This JSON string is bullshit: ", jstr
		return ""
	endif
	
	return jstr[startPos, endPos]
	string str
end

function /S readJSONstring(jstr)
	// given a string starting with "
	// return everything upto and including the matching "
	// ignores escaped quotes "\""
	
	string jstr
	jstr = TrimString(jstr) // just in case this didn't already happen
	
	variable i=0, startPos=-1, endPos=-1, escaped=0
	for(i=0; i<strlen(jstr); i+=1)
	
		// check if the current character is escaped
		if(i!=0)
			if( StringMatch(jstr[i-1], "\\") == 1)
				escaped = 1
			else
				escaped = 0
			endif
		endif
	
		// count quotes
		if( StringMatch(jstr[i], "\"" ) == 1 && escaped == 0)
			// found one!
			if(startPos==-1)
				// this is the first one
				startPos = i
			else
				// this is not the first one
				// i have no choice but to assume it is the end
				endPos = i
				break
			endif
		endif
		
	endfor

	if(startPos==-1 || endPos==-1)
		print "[WARNING] This JSON string is bullshit: ", jstr
		return ""
	endif
	
	return jstr[startPos, endPos]
	string str
end

function /S getJSONkeys(jstr)

	// return all the keys in the JSON string
	// do not pay attention to what level they are
	//     see getKeyLevels(jstr)
	// one nice feature is that keylist is in the same order as jstr
	
	string jstr
	
	variable i=0, j=0, escaped = 0, startkey=0
	string char = "", keylist = "", testkey = "", realkey = ""
	do
		// check if the current character is escaped
		if(i!=0)
			if( StringMatch(jstr[i-1], "\\") == 1)
				escaped = 1
			else
				escaped = 0
			endif
		endif
	
		char = jstr[i]
		if(StringMatch(jstr[i], "\"" ) == 1 && escaped == 0)
		
			startkey = i // remember where we began this journey
			testkey = readJSONstring(jstr[i,inf]) // get a string to test
			i+=strlen(testkey) // jump to the end of that quoted string
						
			// look for the next non-whitespace character
			do
				char = jstr[i]
				i+=1
			while(isWhitespace(char)==1)
			
			// now I have some non-whitespace character as char
			// check if it is what I want
			if(stringmatch(char, ":")==1)
				realkey = TrimString(jstr[startkey,i-2]) // drop the ":" and any whitespace
				keylist += realkey[1,strlen(realkey)-2]+":"
			else
				// not what you wanted, back up one and put this character back in play
			endif
			i-=1 // back up one and put that character back in play
		
		endif
		i+=1
	while(i<strlen(jstr))
	return keylist
end

function /S getJSONkeylevels(jstr, keylist)
	// take a json string and a list of keys
	// return a numerical list signifying at what level they are nested
	string jstr, keylist
	
	variable i=0
	string key = "", group = "", regex = "", keylevels = ""
	for(i=0; i<ItemsInList(keylist, ":");i+=1)
		
		key = StringFromList(i, keylist, ":")
	
		sprintf regex, "\"%s\"\\s*:([\\s\\S]*)}$", key
		splitstring /E=regex jstr, group
	
		keylevels += num2istr(countBrackets(group)+1)+":"
	endfor
	print keylist, keylevels
end

///////////////////////////////
//// JSON output functions ////
///////////////////////////////

function /S addJSONKeyVal(jstr, key, [numVal, strVal, fmt])
	// new Key:Val goes at the end of JSON object, jstr
	//
	// it is up to the user to provide format strings that make sense
	// defaults are %s and %f for strVal and numVal, respectively
	//
	
	string jstr, key, strVal, fmt
	variable numVal

	if(paramisdefault(numVal) && paramisdefault(strVal))
		print "[WARNING] A value has not been provided along with the key: ", key
	endif
	
	//// remove leading/trailing whitespace and quotes from key ////
	do
	    String firstChar= key[0]
	    if (StringMatch(firstChar, "\"") == 1 || GrepString(firstChar, "\\s") == 1)
	        key = key[1,inf]
	    else
	        break
	    endif   
	while (strlen(key) > 0)
	do
	    String lastChar = key[strlen(key) - 1]
	    if (StringMatch(lastChar, "\"") == 1 || GrepString(lastChar, "\\s") == 1)
	        key = key[0, strlen(key) - 2]
	    else
	        break
	    endif   
	while (strlen(key) > 0)

	// cleanup starting string
	if(strlen(jstr)==0)
		// no starting string provided
		// make a new one
		jstr = "{}"
	else
		// get only what is inside the starting and ending brakets
		jstr = readJSONObject(jstr) // returns '{....}'
	endif
	
	jstr = jstr[0,strlen(jstr)-2]
	
	variable err
	string output="", outputFmt = ""
	if(!paramisdefault(strVal))

		// check if it is a valid type
		err = findJSONtype(strVal)
		if(err==-1)
			return ""
		endif

		// setup format string
		if(paramisdefault(fmt))
			outputFmt = "%s, \"%s\": %s}"
		else
			outputFmt = "%s, \"%s\": " + fmt + "}"
		endif
		
		// return output
		sprintf output, outputFmt, jstr, key, strVal
		return output
	endif

	if(!paramisdefault(numVal))
	
		// setup format string
		if(paramisdefault(fmt))
			outputFmt = "%s, \"%s\": %f}"
		else
			outputFmt = "%s, \"%s\": " + fmt + "}"
		endif
		
		// return output
		sprintf output, outputFmt, jstr, key, numVal
		return output
	endif
	
end

function writeJSONtoFile(jstr, filename, path)
	string jstr, filename, path
	string indent = "  "
	
	// write jstr to filename
	// add whitespace to make it easier to read
	// this is expected to be a valid json str
	// it will be a disaster otherwise
	
	variable refNum=0
	open /z/p=$path refNum as filename
	
	variable i=0
	string char = ""

	// get keys...
	string keylist = getJSONkeys(jstr)
	string keylevels = getJSONkeylevels(jstr, keylist)

	close refNum
	
end
	
/////////////////////////////
//// JSON read functions ////
/////////////////////////////

function /S JSONfromStr(rawstr)
	// read JSON string from filename in path
	string rawstr
	return readJSONobject(rawstr)
end

function /S JSONfromFile(path, filename)
	// read JSON string from filename in path
	string path, filename
	variable refNum
	
	open /r/z/p=$path refNum as filename
	if(V_flag!=0)
		print "[WARNING] Could not read JSON from: "+filename
		return ""
	endif

	string buffer = "", jstr = ""
	do 
		FReadLine refNum, buffer
		if(strlen(buffer)==0)
			break
		endif
		jstr+=buffer
	while(1)
	close refNum
	
	return readJSONobject(jstr)
end

function /S getJSONValue(jstr, key) 
	
	// keys can be nested:
	//		"key1;keyA" will return the value of keyA which is a key within the key1 value
	// if there are repeated keys at the same nesting level, you always get the first one
	//
	// RETURN TYPES:
	// 1 -- object -- return string
	// 2 -- array -- return string
	// 3 -- number -- return result of num2str()
	// 4 -- string -- return string, no surrounding quotes
	// 5 -- bool -- return "0" or "1"
	// 6 -- null -- return "NaN" (will convert to str2num("NaN") is not a number, close enough)
	//
	// always return strings
	//
	// example:
	//     if(getJSONValue(jstr, "data")==3)
	//		     val = J_num
	//     else
	//         abort "Bad response from URL"
	//     endif
	
	string jstr, key

	variable j = 0, numKeys = ItemsInList(key)
	string currentKey = "", regex = ""
	string group = jstr
	for(j=0;j<numKeys;j+=1)
	
		jstr = readJSONObject(group)
		currentKey = StringFromList(j, key, ";")
				
		// use regex to match key and everything after it...
		sprintf regex, "\"%s\"\\s*:([\\s\\S]*)}$", currentKey
		splitstring /E=regex jstr, group
		
		// check the validity of currentKey values/positions
		if(strlen(group)==0)
			print "[WARNING] Key not found: " + currentKey
			return ""
		elseif(countBrackets(group)!=0)
			print "[WARNING] Not a valid key (nested key problem): " + currentKey
			return ""
		endif

	endfor
	
	string strVal, numRegex = "([-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?)"
	switch(findJSONtype(group))
		case 1:
			strVal = readJSONObject(group)
			if(strlen(strVal)>0)
				return strVal
			else
				return ""
			endif
		case 2: 
			strVal = readJSONArray(group)
			if(strlen(strVal)>0)
				return strVal
			else
				return ""
			endif
		case 3:
			splitstring /E=numRegex group, strVal
			if(strlen(strVal)>0)
				return strVal
			else
				return ""
			endif
		case 4:
			strVal = readJSONString(group)
			if(strlen(strVal)>0)
				return strVal
			else
				return ""
			endif
		case 5:
			if(stringmatch(LowerStr(group[0,3]),"true")==1)
				return num2istr(1)
			elseif(stringmatch(LowerStr(group[0,4]),"false")==1)
				return num2istr(0)
			else
				return ""
			endif
		case 6:
			return "NaN" 
		case -1:
			print "[WARNING] Trying to fetch an invalid type or empty value from: " + group
			return ""
	endswitch
end