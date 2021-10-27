#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


function/s strTime()
	// Returns the current time in YYYY-MM-DD;HH-MM-SS format
	string datetime_str
	string time_str
	time_str = secs2time(datetime, 3)
	sprintf time_str "%s-%s-%s", time_str[0,1], time_str[3,4], time_str[6,7]
	sprintf datetime_str "%s_%s" secs2Date(datetime, -2), time_str
	return datetime_str
end

function unixTime()
	// returns the current unix time in seconds
	return DateTime - date2secs(1970,1,1) - date2secs(-1,-1,-1)
end

function roundNum(number,decimalplace) 
    // to return integers, decimalplace=0
	variable number, decimalplace
	variable multiplier
	multiplier = 10^decimalplace
	return round(number*multiplier)/multiplier
end

function AppendValue(thewave, thevalue)
    // Extend wave to add a value
	wave thewave
	variable thevalue
	Redimension /N=(numpnts(thewave)+1) thewave
	thewave[numpnts(thewave)-1] = thevalue
end

function AppendString(thewave, thestring)
    // Extendt text wave to add a value
	wave/t thewave
	string thestring
	Redimension /N=(numpnts(thewave)+1) thewave
	thewave[numpnts(thewave)-1] = thestring
end


function prompt_user(promptTitle,promptStr)
    // Popup a user prompt to enter a value
	string promptTitle, promptStr

	variable x=0
	prompt x, promptStr
	doprompt promptTitle, x
	if(v_flag == 0)
		return x
	else
		return nan
	endif
end


function ask_user(question, [type])
    // Popup a confirmation window to user
	//type = 0,1,2 for OK, Yes/No, Yes/No/Cancel returns are V_flag = 1: Yes, 2: No, 3: Cancel
	string question
	variable type
	type = paramisdefault(type) ? 1 : type
	doalert type, question
	return V_flag
end

function/S GetLabel(channels, [fastdac])
  // Returns Label name of given channel, defaults to BD# or FD#
  // Used to get x_label, y_label for init_waves 
  // Note: Only takes channels as numbers
	string channels
	variable fastdac

	variable i=0
	string channel, buffer, xlabelfriendly = ""
	wave/t dacvalstr
	wave/t fdacvalstr
	for(i=0;i<ItemsInList(channels, ",");i+=1)
		channel = StringFromList(i, channels, ",")

		if (fastdac == 0)
			buffer = dacvalstr[str2num(channel)][3] // Grab name from dacvalstr
			if (cmpstr(buffer, "") == 0)
				buffer = "BD"+channel
			endif
		elseif (fastdac == 1)
			buffer = fdacvalstr[str2num(channel)][3] // Grab name from fdacvalstr
			if (cmpstr(buffer, "") == 0)
				buffer = "FD"+channel
			endif
		else
			abort "\"GetLabel\": Fastdac flag must be 0 or 1"
		endif

		if (cmpstr(xlabelfriendly, "") != 0)
			buffer = ", "+buffer
		endif
		xlabelfriendly += buffer
	endfor
	return xlabelfriendly + " (mV)"
end


function/s SF_get_channels(channels, [fastdac])
	// Returns channels as numbers string whether numbers or labels passed
	string channels
	variable fastdac
	
	string new_channels = "", err_msg
	variable i = 0
	string ch
	if(fastdac == 1)
		wave/t fdacvalstr
		for(i=0;i<itemsinlist(channels, ",");i++)
			ch = stringfromlist(i, channels, ",")
			ch = removeLeadingWhitespace(ch)
			ch = removeTrailingWhiteSpace(ch)
			if(numtype(str2num(ch)) != 0)
				duplicate/o/free/t/r=[][3] fdacvalstr fdacnames
				findvalue/RMD=[][3]/TEXT=ch/TXOP=5 fdacnames
				if(V_Value == -1)  // Not found
					sprintf err_msg "ERROR[SF_get_channesl]:No FastDAC channel found with name %s", ch
					abort err_msg
				else  // Replace with DAC number
					ch = fdacvalstr[V_value][0]
				endif
			endif
			new_channels = addlistitem(ch, new_channels, ",", INF)
		endfor
	else  // Babydac
		wave/t dacvalstr
		for(i=0;i<itemsinlist(channels, ",");i++)
			ch = stringfromlist(i, channels, ",")
			ch = removeLeadingWhitespace(ch)
			ch = removeTrailingWhiteSpace(ch)
			if(numtype(str2num(ch)) != 0)
				duplicate/o/free/t/r=[][3] dacvalstr dacnames
				findvalue/RMD=[][3]/TEXT=ch/TXOP=0 dacnames
				if(V_Value == -1)  // Not found
					sprintf err_msg "ERROR[SF_get_channesl]:No BabyDAC channel found with name %s", ch
					abort err_msg
				else  // Replace with DAC number
					ch = dacvalstr[V_value][0]
				endif
			endif
			new_channels = addlistitem(ch, new_channels, ",", INF)
		endfor
	endif
	new_channels = new_channels[0,strlen(new_channels)-2]  // Remove comma at end (DESTROYS LIMIT CHECKING OTHERWISE)
	return new_channels
end
	