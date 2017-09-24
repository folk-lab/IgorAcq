#pragma rtGlobals=1		// Use modern global access method.

// GOAL: A pure IGOR implementation of the JSON standard
//       Try to use as many built in string functions as possible to avoid encoding trouble
//
// RULES: https://tools.ietf.org/html/rfc7159.html
//        If something here doesn't make sense, go read the rules
//
// Written by Nik Hartman (September 2017)


///////////////////////////
//// utility functions ////
///////////////////////////

function /S numToBool(val)
	variable val
	if(val==1)
		return "true"
	elseif(val==0)
		return "false"
	else
		return ""
	endif
end

function boolToNum(str)
	string str
	if(StringMatch(LowerStr(str), "true")==1)
		// use string match to ignore whitespace
		return 1
	elseif(StringMatch(LowerStr(str), "false")==1)
		return 0
	else
		return -1
	endif
end

Function/S NumericWaveToBoolArray(w)
	Wave w	// numeric wave (if text, use /T here and %s below)
	String list = "["
	
	variable i=0
	for(i=0; i<numpnts(w); i+=1)
		list += numToBool(w[i])+", "
	endfor
	
	return list[0,strlen(list)-3] + "]"
End

Function/S NumericWaveToNumArray(w)
	Wave w	// numeric wave (if text, use /T here and %s below)
	String list
	wfprintf list, "%g,", w	// semicolon-separated list
	return "["+list[0,strlen(list)-2]+"]"
End

Function/S TextWaveToStrArray(w)
	Wave w	// numeric wave (if text, use /T here and %s below)
	String list
	wfprintf list, "\"%s\",", w	// semicolon-separated list
	return "["+list[0,strlen(list)-2]+"]"
End

function /s stripCharacters(str, charlist)
	// always strip whitespace from beginning and end
	// also remove any unescaped characters from charlist
	//      charlist should be a comma separated list of characters
	// ignores anything from charlist that seems to be escaped with \
	
	string str, charlist
	
	if (strlen(str) == 0)
		// just get this out of the way real quick
		return ""
	endif
 
 	// remove leading whitespace
	do
		string firstChar= str[0]
		if (IsWhiteSpace(firstChar))
			str= str[1,inf]
		else
		   break
		endif   
	while (strlen(str) > 0)
	
	// remove trailing whitespace
	do
	    string lastChar = str[strlen(str) - 1]
	    if (IsWhiteSpace(lastChar))
	    	str = str[0, strlen(str) - 2]
	    else
	    	break
	    endif
	while (strlen(str) > 0)
	
	// remove charlist characters that are not escaped
	variable i=0, j=0, escaped = 0, nchars = ItemsInList(charlist, ",")
	do
		// check if the current character is escaped
		if(i!=0)
			if( CmpStr(str[i-1], "\\") == 0)
				escaped = 1
			else
				escaped = 0
			endif
		endif
		
		string nextChar = str[i]
		for(j=0;j<nchars+1;j+=1)
			if(CmpStr(nextChar, StringFromList(j, charlist, ","))==0 && escaped==0)
				str = str[0,i-1]+str[i+1,inf]
				i-=1
			endif
		endfor
		i+=1
	while(i<strlen(str))
	
	return str
end
	
//////////////////////////////////
//// converting JSON to waves ////
//////////////////////////////////
	
function ItemsInArray(arraystr)
	// get item at index from arraystr
	// requires arraystr to be a proper JSON array of JSON strings
	//     ["like", "this"]
	// can contain any sort of JSON element
	
	// needed a custom function because there were too
	// many exceptions for StringFromList
	string arraystr
	
	// remove leading whitespace and opening [
	variable bracketGone = 0
	do
		string firstChar= arraystr[0]
		if (IsWhiteSpace(firstChar))
			// remove whitespace
			arraystr = arraystr[1,inf]
		elseif (CmpStr(firstChar, "[")==0 && bracketGone==0)
			// this is the opening bracket
			arraystr = arraystr[1,inf]
			bracketGone=1
		else
		   break
		endif   
	while (strlen(arraystr) > 0)
	
	// remove trailing whitespace and closing ]
	bracketGone = 0
	do
	    string lastChar = arraystr[strlen(arraystr) - 1]
	    if (IsWhiteSpace(lastChar))
	    	arraystr = arraystr[0, strlen(arraystr) - 2]
	    elseif (CmpStr(lastChar, "]")==0 && bracketGone==0)
			// this is the closing bracket
			arraystr = arraystr[0, strlen(arraystr) - 2]
			bracketGone=1
	    else
	    	break
	    endif
	while (strlen(arraystr) > 0)
	
	// look for commas that are not enclosed in curly brackets, square brackets or quotes
	variable i=0, commaCount = 0
	for(i=0;i<strlen(arraystr);i+=1)
		if(CmpStr(arraystr[i], ",")==0)

			// is it a good comma?
			if(countBrackets(arraystr[i+1, inf])!=0)
				// if this is not zero, the comma is inside a JSON object
				commaCount += 0
			elseif(countSqBrackets(arraystr[i+1, inf])!=0)
				// if this is not zero, the comma is inside a JSON array
				commaCount += 0
			elseif(mod(countQuotes(arraystr[i+1, inf]),2)!=0)
				// if this is an odd number, the comma is inside a JSON string
				commaCount += 0
			else
				// this is a good one
				commaCount +=1
			endif
						
		endif
	endfor
	
	return commaCount+1

end
	
function /S StringFromArray(index, arraystr)
	// get item at index from arraystr
	// requires arraystr to be a proper JSON array of only JSON strings
	//     ["like", "this"]
	
	// needed a custom function because there were too
	// many exceptions for StringFromList
	variable index
	string arraystr
	
	// remove leading whitespace and opening [
	variable bracketGone = 0
	do
		string firstChar= arraystr[0]
		if (IsWhiteSpace(firstChar))
			// remove whitespace
			arraystr = arraystr[1,inf]
		elseif (CmpStr(firstChar, "[")==0 && bracketGone==0)
			// this is the opening bracket
			arraystr = arraystr[1,inf]
			bracketGone=1
		else
		   break
		endif   
	while (strlen(arraystr) > 0)
	
	// remove trailing whitespace and closing ]
	bracketGone = 0
	do
	    string lastChar = arraystr[strlen(arraystr) - 1]
	    if (IsWhiteSpace(lastChar))
	    	arraystr = arraystr[0, strlen(arraystr) - 2]
	    elseif (CmpStr(lastChar, "]")==0 && bracketGone==0)
			// this is the closing bracket
			arraystr = arraystr[0, strlen(arraystr) - 2]
			bracketGone=1
	    else
	    	break
	    endif
	while (strlen(arraystr) > 0)
		
	// find the element by counting commas
	variable i=0, elementCount = 0
	
	for(i=0;i<strlen(arraystr);i+=1)
		
		if(elementCount>=index)
			break
		endif
	
		if(CmpStr(arraystr[i], ",")==0)	
				
			// is it a good comma?
			if(countBrackets(arraystr[i+1, inf])!=0)
				// if this is not zero, the comma is inside a JSON object
				elementCount += 0
			elseif(countSqBrackets(arraystr[i+1, inf])!=0)
				// if this is not zero, the comma is inside a JSON array
				elementCount += 0
			elseif(mod(countQuotes(arraystr[i+1, inf]),2)!=0)
				// if this is an odd number, the comma is inside a JSON string
				elementCount += 0
			else
				// this is a good one
				elementCount +=1
			endif
			
		endif
	endfor
	
	// arraystr[i,inf] starts with the value I want to return
	return getJSONitemFromGroup(arraystr[i,inf])
end

function ArrayToTextWave(arraystr, namewave)
	string arraystr, namewave
	
	variable n = ItemsInArray(arraystr)
	make/o/t/n=(n) $namewave=stripCharacters(StringFromArray(p,arraystr), "\"")
end

function ArrayToNumWave(arraystr, namewave)
	// if you put nonsense in, you'll get nonsense back here
	// it best be an array of numbers and/or bools
	string arraystr, namewave

	variable n = ItemsInArray(arraystr)
	make/o/n=(n) $namewave=str2num(StringFromArray(p,arraystr))
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
			if( CmpStr(str[i-1], "\\") == 0)
				escaped = 1
			else
				escaped = 0
			endif
		endif
	
		// count opening brackets
		if( CmpStr(str[i], "{" ) == 0 && escaped == 0)
			bracketCount -= 1
		endif
		
		// count closing brackets
		if( CmpStr(str[i], "}" ) == 0 && escaped == 0)
			bracketCount += 1
		endif
		
	endfor
	return bracketCount
end

function countSqBrackets(str)
	// count how many brackets are in the string
	// +1 for ]
	// -1 for [
	string str
	variable bracketCount = 0, i = 0, escaped = 0
	for(i=0; i<strlen(str); i+=1)
	
		// check if the current character is escaped
		if(i!=0)
			if( CmpStr(str[i-1], "\\") == 0)
				escaped = 1
			else
				escaped = 0
			endif
		endif
	
		// count opening brackets
		if( CmpStr(str[i], "[" ) == 0 && escaped == 0)
			bracketCount -= 1
		endif
		
		// count closing brackets
		if( CmpStr(str[i], "]" ) == 0 && escaped == 0)
			bracketCount += 1
		endif
		
	endfor
	return bracketCount
end

function countQuotes(str)
	// count how many quotes are in the string
	// +1 for "
	// escaped quotes are ignored
	string str
	variable quoteCount = 0, i = 0, escaped = 0
	for(i=0; i<strlen(str); i+=1)
	
		// check if the current character is escaped
		if(i!=0)
			if( CmpStr(str[i-1], "\\") == 0)
				escaped = 1
			else
				escaped = 0
			endif
		endif
	
		// count opening brackets
		if( CmpStr(str[i], "\"" ) == 0 && escaped == 0)
			quoteCount += 1
		endif
		
	endfor
	return quoteCount
end


////////////////////////
//// getting values ////
////////////////////////

function findJSONtype(str)
	
	// this checks quickly to find what type something is intended to be
	// it makes no effort to check if str is a valid version of that type
	
	// in fact, I take advantage of that later by sending this function big chunks of 
	// characters that only _start_ with the thing I want
	
	// RETURN TYPES:
	// 1 -- object
	// 2 -- array
	// 3 -- number -- no float/int distinction in igor
	// 4 -- string
	// 5 -- bool
	// 6 -- null
	
	
	string str
	str = TrimString(str) // trim leading/trailing whitespace
	str = LowerStr(str)   // I don't care if you got the cases right
	if( strlen(str)==0 )
		return -1
	endif
	
	string numRegex = "([-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?)"
	if(CmpStr(str[0], "{")==0)
		// this is an object
		return 1
	elseif(CmpStr(str[0], "[")==0)
		// this is an array
		return 2
	elseif(CmpStr(str[0], "\"")==0)
		// this is a string
		return 4
	elseif(CmpStr(str[0,3], "true")==0 || CmpStr(str[0,4], "false")==0)
		// this is a boolean
		return 5
	elseif(CmpStr(str[0,3], "null")==0)
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
			if( CmpStr(jstr[i-1], "\\") == 0)
				escaped = 1
			else
				escaped = 0
			endif
		endif
	
		// count opening brackets
		if( CmpStr(jstr[i], "{" ) == 0 && escaped == 0)
			openBrackets+=1
			if(startPos==-1)
				startPos = i
			endif
		endif
		
		// count closing brackets
		if( CmpStr(jstr[i], "}" ) == 0 && escaped == 0)
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
			if( CmpStr(jstr[i-1], "\\") == 0)
				escaped = 1
			else
				escaped = 0
			endif
		endif
	
		// count opening brackets
		if( CmpStr(jstr[i], "[" ) == 0 && escaped == 0)
			openBrackets+=1
			if(startPos==-1)
				startPos = i
			endif
		endif
		
		// count closing brackets
		if( CmpStr(jstr[i], "]" ) == 0 && escaped == 0)
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
			if( CmpStr(jstr[i-1], "\\") == 0)
				escaped = 1
			else
				escaped = 0
			endif
		endif
	
		// count quotes
		if( CmpStr(jstr[i], "\"" ) == 0 && escaped == 0)
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
	// returns a comma separated list like
	// 	key1,key2,key3:key3a,key4
	
	string jstr
	
	variable i=0, j=0, escaped = 0, startkey=0
	string char = "", testkey = "", realkey = ""
	string keylist = "", keylevel = ""
	
	do
		// check if the current character is escaped
		if(i!=0)
			if( CmpStr(jstr[i-1], "\\") == 0)
				escaped = 1
			else
				escaped = 0
			endif
		endif
	
		char = jstr[i]
		if(CmpStr(jstr[i], "\"" ) == 0 && escaped == 0)
		
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
			if(CmpStr(char, ":")==0)
				realkey = TrimString(jstr[startkey,i-2]) // drop the ":" and any whitespace
				keylist += realkey[1,strlen(realkey)-2]+","
				keylevel += num2istr(countBrackets(jstr[i,inf])-1)+"," // for closing bracket
			endif
			i-=1 // back up one and put that character back in play
		
		endif
		i+=1
	while(i<strlen(jstr))
	
	// ok... now I've got to go back through this key list and 
	//   build up keys that start at level 0
	//   this allows keys to be repeated at lower levels
	//   repeated keys at level 0 are still a problem
	variable level = -1, nextlevel = -1
	string key = "", newlist = ""
	for(i=0; i<ItemsInList(keylist, ","); i+=1)
		key = StringFromList(i, keylist, ",")
		level = str2num(StringFromList(i, keylevel, ","))
		if(level!=0)
			// go back and find all keys until you are at level 0
			// so... replace key2 with key0:key1:key2
			for(j=i-1;j>-1;j-=1)
				nextlevel = str2num(StringFromList(j, keylevel, ","))
				if(nextlevel==level-1)
					// add next level to the key
					key = StringFromList(j, keylist, ",")+":"+key
					level=nextlevel
				endif
				if(level==0)
					break
				endif
			endfor
			newlist += key+","
		else
			newlist += key+","
		endif
	endfor
	return newlist[0,strlen(newlist)-2]
end

///////////////////////////////
//// JSON output functions ////
///////////////////////////////

function /S addJSONKeyVal(jstr, key, [numVal, strVal, fmt])
	// new Key:Val goes at the end of JSON object, jstr
	
	// it is up to the user to provide format strings that make sense
	// defaults are %s and %f for strVal and numVal, respectively

	
	string jstr, key, strVal, fmt
	variable numVal

	if(paramisdefault(numVal) && paramisdefault(strVal))
		print "[WARNING] A value has not been provided along with the key: ", key
	endif
	
	//// remove leading/trailing whitespace and quotes from key ////
	do
	    String firstChar= key[0]
	    if (CmpStr(firstChar, "\"") == 0 || GrepString(firstChar, "\\s") == 1)
	        key = key[1,inf]
	    else
	        break
	    endif   
	while (strlen(key) > 0)
	do
	    String lastChar = key[strlen(key) - 1]
	    if (CmpStr(lastChar, "\"") == 0 || GrepString(lastChar, "\\s") == 1)
	        key = key[0, strlen(key) - 2]
	    else
	        break
	    endif   
	while (strlen(key) > 0)

	// cleanup starting string
	if(strlen(jstr)==0)
		// no starting string provided
		// make a new one
		jstr = "{"
	else
		// get only what is inside the starting and ending brakets
		jstr = readJSONObject(jstr) // returns '{....}'
		jstr = jstr[0,strlen(jstr)-2]+", " // returns '{....., '
	endif
	
	variable err = 0
	string output="", outputFmt = ""
	if(!paramisdefault(strVal))

		// setup format string
		if(paramisdefault(fmt))
		
			// if no format is provided
			// check if strVal is a valid type
			err = findJSONtype(strVal)
			if(err==-1)
				return ""
			endif
			
			outputFmt = "\"%s\": %s}"
		else
			// build test string
			// check if it is a valid type
			string test = ""
			sprintf test, fmt, strVal
			err = findJSONtype(test)
			if(err==-1)
				return ""
			endif
			
			outputFmt = "\"%s\": " + fmt + "}"
		endif
		
		// return output
		sprintf output, outputFmt, key, strVal
		return jstr+output
	endif

	if(!paramisdefault(numVal))
	
		// setup format string
		if(paramisdefault(fmt))
			outputFmt = "\"%s\": %f}"
		else
			outputFmt = "\"%s\": " + fmt + "}"
		endif
		
		// return output
		sprintf output, outputFmt, key, numVal
		return jstr+output
	endif
	
end

function /S getJSONindent(level)
	// returning whitespace for formatting JSON strings
	variable level
	
	variable i=0
	string output = ""
	for(i=0;i<level;i+=1)
		output += "  "
	endfor
	
	return output
end

function /S prettyJSONfmt(jstr)
	string jstr
	
	// write jstr to filename
	// add whitespace to make it easier to read
	// this is expected to be a valid json str
	// it will be a disaster otherwise
	
	string outStr="", buffer=""

	outStr += "{\r"

	// get keys...
	string keylist = getJSONkeys(jstr)
	
	variable i=0, level = 0
	string key = "", printkey = "", strVal = "", group = ""
	for(i=0;i<ItemsInList(keylist,",");i+=1) // loop over keys
		
		// check if the indent level has decreased
		// if so, close out object with curly bracket
		
		key = StringFromList(i, keylist, ",")
		printkey = StringFromList(ItemsInList(key, ":")-1, key, ":")
		
		if(i!=0 && ItemsInList(key, ":")<level)
			level = ItemsInList(key, ":")
			outStr= outStr[0,strlen(outStr)-3] + "\r" + getJSONindent(level) + "},\r"
		else
			level = ItemsInList(key, ":")
		endif 
		
		strVal = getJSONValue(jstr, key)
		
		switch(findJSONtype(strVal))
			case 1:
				// don't put the value in, it will contain keys and be handled another way
				outStr += getJSONindent(level)+"\""+printkey+"\""+": {\r"
				break
			case 2: 
				outStr += getJSONindent(level)+"\""+printkey+"\""+": "+strVal+",\r"
				break
			case 3:
				outStr += getJSONindent(level)+"\""+printkey+"\""+": "+strVal+",\r"
				break
			case 4:
				outStr += getJSONindent(level)+"\""+printkey+"\""+": "+strVal+",\r"
				break
			case 5:
				outStr += getJSONindent(level)+"\""+printkey+"\""+": "+strVal+",\r"
				break
			case 6:
				strVal = "null" 
				outStr += getJSONindent(level)+"\""+printkey+"\""+": "+strVal+",\r"
				break
			case -1:
				strVal = ""
				outStr += getJSONindent(level)+"\""+printkey+"\""+": "+strVal+",\r"
				break
		endswitch
		
	endfor
	
	outStr = outStr[0,strlen(outStr)-3]+"\r" // fix trailing comma trouble
	
	// need to close out open objects
	do
		level-=1
		outStr+= getJSONindent(level)+"}\r"
	while(level>0)
	
	return outStr
		
end

function writeJSONtoFile(jstr, filename, path)

	string jstr, filename, path
	
	// write jstr to filename
	// add whitespace to make it easier to read
	// this is expected to be a valid json str
	// it will be a disaster otherwise
	
	variable refNum=0
	jstr = prettyJSONfmt(jstr)
	
	open /z/p=$path refNum as filename

	do
		if(strlen(jstr)<500)
			fprintf refnum, "%s", jstr
			break
		else
			fprintf refnum, "%s", jstr[0,499]
			jstr = jstr[500,inf]
		endif
	while(1)

	close refNum
	
end
	
///////////////////////////////
//// JSON import functions ////
///////////////////////////////

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

function /S getJSONitemFromGroup(group)
	// get the first valid JSON item from a long ass string
	string group  // call it group because the long ass string is often a regex match
	
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
			if(CmpStr(trimString(group)[0,3],"true")==0)
				return num2istr(1)
			elseif(CmpStr(trimString(group)[0,4],"false")==0)
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

	variable j = 0, numKeys = ItemsInList(key, ":")
	string currentKey = "", regex = ""
	string group = jstr
	for(j=0;j<numKeys;j+=1)
	
		jstr = readJSONObject(group)
		currentKey = StringFromList(j, key, ":")
				
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
	
	return getJSONitemFromGroup(group)

end