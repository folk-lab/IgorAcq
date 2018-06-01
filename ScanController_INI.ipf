function/s INIfromfile(path)
    // read INI file into string
    // filename must be xxxxx.ini
    // assumes general INI rules: https://en.wikipedia.org/wiki/INI_file
    string path
    variable refnum
    string buffer="", INIstr = "", filename = "setup.ini"

    open /r/z/p=$path refnum as filename
    if(v_flag!=0)
        print "[ERROR]: Could not read the setup file! It might not exist."
        return ""
    endif

    do
        freadline refnum, buffer
        if(strlen(buffer)==0)
            break
        endif
        INIstr+=buffer
    while(1)
    close refnum

    return INIstr
end

function parseINIfile(INIstr)
    string INIstr

end

function sc_loadINIconfig()
    // open setup.ini and setup communication with instruments
    string INIstr

    INIstr = INIfromfile("setup") // setup is the igor symbolic path

    // results will be dumped into two waves: ini_text & ini_type
    // ini_text will contain the parsed strings
    // ini_type[i]==1 if the entry is a section title
    // ini_type[i]==2 if the entry is a key
    // ini_type[i]==3 if the entry is a value
    parseINIfile(INIstr)
    wave/t ini_text
    wave ini_type
end
