#pragma rtGlobals=1		// Use modern global access method.

// GOAL: a pure IGOR implementation of the JSON standard
// https://tools.ietf.org/html/rfc7159.html
//
// NOTES:
//     
//   JSON can represent four primitive types (strings, numbers, booleans,
//   and null) and two structured types (objects and arrays).
//
//   A string is a sequence of zero or more Unicode characters [UNICODE].
//   Note that this citation references the latest version of Unicode
//   rather than a specific release.  It is not expected that future
//   changes in the UNICODE specification will impact the syntax of JSON.
//
//   An object is an unordered collection of zero or more name/value
//   pairs, where a name is a string and a value is a string, number,
//   boolean, null, object, or array.
//
//   An array is an ordered sequence of zero or more values.
//
//   structural characters:
//      begin-array     = ws %x5B ws  ; [ left square bracket
//      begin-object    = ws %x7B ws  ; { left curly bracket
//      end-array       = ws %x5D ws  ; ] right square bracket
//      end-object      = ws %x7D ws  ; } right curly bracket
//      name-separator  = ws %x3A ws  ; : colon
//      value-separator = ws %x2C ws  ; , comma
//
//   whitespace is allowed before or after structural characters:
//   Insignificant whitespace is allowed before or after any of the six
//   structural characters.
//
//      ws = *(
//              %x20 /              ; Space
//              %x09 /              ; Horizontal tab
//              %x0A /              ; Line feed or New line
//              %x0D )              ; Carriage return
//
//   A JSON value MUST be an object, array, number, or string, or one of
//   the following three literal names:
//
//      false null true
//
//   The literal names MUST be lowercase.












// I think the way to do this is to pick a starting place (beginning { or keyword)
// then, start parsing things according to what characters follow the name-separator





/////////// attempt 1 ///////////////

function /S getJSONstr(jstr, key)
	// get value of key from json string	s
	// works for string values
	// matches anything in quotes like this.... 
	//
	// "key":"match_this"
	//
	// returns "match_this"

	string jstr, key
	string val=""
	string regex = ""
	sprintf regex, "\"(?i)%s\"\\s*:\\s*\"(.+?)\"", key
	splitstring /E=regex jstr, val
	return val
end

function /S getJSONarray(jstr, key)
	// get value of key from json string	
	// works for string values
	// matches anything in (), {}, or [] like this.... 
	//
	// "key": [1,2,3,4]
	//
	// returns "[1,2,3,4]"

	string jstr, key
	string group1
	string regex = ""
	sprintf regex, "\"(?i)%s\"\\s*:\\s*((\[|\(|{)(.+?)(\]|\)|}))", key

	splitstring /E=regex jstr, group1
	return group1
end

function getJSONbool(jstr, key)
	// get value of key from json string
	// works on boolean values
	// matches true|false
	//
	// "key":True
	//
	// returns 1
	
	string jstr, key
	string val=""
	string regex = ""
	sprintf regex, "\"(?i)%s\"\\s*:\\s*(?i)(true|false)", key
	splitstring /E=regex jstr, val

	strswitch(LowerStr(val))
		case "true":
			return 1
		case "false":
			return 0
	endswitch
	
end

function getJSONnum(jstr, key)
	// get value of key from json string
	// works on numeric values in quotes or not in quotes
	// 
	// "key":9.99 and "key":"9.99"
	//
	// both return 9.99
	
	string jstr, key
	string quote="", val=""
	string regex = ""
	sprintf regex, "\"(?i)%s\"\\s*:\\s*(\")?([-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?)(?(1)\\1|)", key
	
	splitstring /E=regex jstr, quote, val

	return str2num(val)
	
end