#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function generateHelpFile(notebookName,windowToDoc,topicName)
	string notebookName, windowToDoc, topicName

	// open notebook
	newnotebook/f=1/k=0/n=$notebookName as notebookName
	
	//// make rulers ////
	
	// Topic rulers
	notebook $notebookName newRuler=Topic, justification=0, rulerDefaults={"Geneva",12,5,(0,0,0)}, spacing={6,6,0}, margins={0,18,468}, tabs={72}
	notebook $notebookName newRuler=TopicBodyNormal, justification=0, rulerDefaults={"Geneva",10,0,(0,0,0)}, spacing={0,6,0}, margins={18,18,468}, tabs={36,72,216}
	notebook $notebookName newRuler=TopicBodyBold, justification=0, rulerDefaults={"Geneva",10,1,(0,0,0)}, spacing={0,6,0}, margins={18,18,468}, tabs={36,72,216}
	notebook $notebookName newRuler=TopicBodyBoldUnderline, justification=0, rulerDefaults={"Geneva",10,5,(0,0,0)}, spacing={0,6,0}, margins={18,18,468}, tabs={36,72,216}
	
	// Subtopic rulers
	notebook $notebookName newRuler=Subtopic, justification=0, rulerDefaults={"Geneva",10,5,(0,0,0)}, spacing={6,3,0}, margins={18,72,432}, tabs={}
	notebook $notebookName newRuler=OperationBodyNormal, justification=0, rulerDefaults={"Geneva",10,0,(0,0,0)}, spacing={0,5,0}, margins={27,27,468}, tabs={}
	notebook $notebookName newRuler=OperationBodyItalic, justification=0, rulerDefaults={"Geneva",10,2,(0,0,0)}, spacing={0,5,0}, margins={27,27,468}, tabs={}
	notebook $notebookName newRuler=OperationSectionBoldItalic, justification=0, rulerDefaults={"Geneva",9,3,(0,0,0)}, spacing={0,4,0}, margins={27,27,432}, tabs={72,216}
	notebook $notebookName newRuler=OperationSectionLink, justification=0, rulerDefaults={"Geneva",9,4,(0,0,65535)}, spacing={0,4,0}, margins={27,27,432}, tabs={72,216}
	
	// code
	notebook $notebookName newRuler=Code, justification=0, rulerDefaults={"Monaco",9,0,(0,0,0)}, spacing={0,5,0}, margins={27,27,1008}, tabs={45,63,81,99,117,216,288}
	
	//// Add text ////
	
	// create headline topic
	string headline = ""
	sprintf headline, "%s\r", topicName
	notebook $notebookName ruler=Topic
	notebook $notebookName fstyle=0, text="•\t"
	notebook $notebookName fstyle=5, text=headline
	notebook $notebookName ruler=TopicBodyNormal
	notebook $notebookName text="Ruler is \"TopicBobyNormal\".\r"
	notebook $notebookName text="Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla enim ipsum, imperdiet id pharetra non, commodo et tellus. Cras luctus efficitur ullamcorper. Proin commodo mattis dictum.\r"
	notebook $notebookName ruler=TopicBodyBold
	notebook $notebookName text="Ruler is \"TopicBobyBold\".\r"
	notebook $notebookName ruler=TopicBodyBoldUnderline
	notebook $notebookName text="Ruler is \"TopicBobyBoldUnderline\".\r"
	notebook $notebookName ruler=Code
	notebook $notebookName text="function Somefunction(...)\r"
	notebook $notebookName text="\t// some text\r"
	notebook $notebookName text="end\r"
	notebook $notebookName ruler=OperationSectionLink
	notebook $notebookName text="<https://qdev-forum.phas.ubc.ca/>\r"
	
	// create command reference
	sprintf headline, "%s Command Reference\r", topicName
	notebook $notebookName ruler=Topic
	notebook $notebookName fstyle=0, text="•"
	notebook $notebookName fstyle=5, text="\t"+headline
	
	// create subtopics for all functions
	string selectFunc = ""
	sprintf selectFunc, "KIND:2,WIN:%s", windowToDoc
	string funcList = functionlist("*",",",selectFunc)
	funcList = sortlist(funcList,",",4)
	
	// loop over all functions and create a subtopic for each
	variable i=0
	for(i=0;i<itemsinlist(funcList,",");i+=1)
		generateSubTopic(notebookName,stringfromlist(i,funcList,","))
	endfor
end

function generateSubTopic(notebookName,funcName)
	string notebookName, funcName
	
	// headline
	notebook $notebookName ruler=Subtopic
	notebook $notebookName text=funcName
	notebook $notebookName fstyle=0,text="("
	notebook $notebookName fstyle=2,text="..."
	notebook $notebookName fstyle=0,text=")\r"
	
	// function discribtion
	notebook $notebookName ruler=OperationBodyNormal
	notebook $notebookName fstyle=-1,text="Add function discribtion.\r"
	
	// parameters
	notebook $notebookName ruler=OperationSectionBoldItalic
	notebook $notebookName text="input parameters\r"
	notebook $notebookName ruler=OperationBodyItalic
	notebook $notebookName text="Add parameter info.\r"
	
	// details
	notebook $notebookName ruler=OperationSectionBoldItalic
	notebook $notebookName text="details\r"
	notebook $notebookName ruler=OperationBodyItalic
	notebook $notebookName text="Add any details.\r"
	
	// see also
	notebook $notebookName ruler=OperationSectionBoldItalic
	notebook $notebookName text="see also\r"
	notebook $notebookName ruler=OperationSectionLink
	notebook $notebookName text="Add links\r"
end