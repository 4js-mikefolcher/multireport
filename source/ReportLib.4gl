IMPORT os
IMPORT util

PUBLIC TYPE t_keyvalue RECORD
	varname  STRING,
	varvalue STRING
END RECORD

PUBLIC TYPE t_fileinfo RECORD
	filename STRING,
	filesize INTEGER,
	modtime  STRING
END RECORD

PUBLIC TYPE t_formfield RECORD
	fullname STRING,
	col_name STRING,
	tab_name STRING,
	field_id STRING,
	tab_idx  STRING
END RECORD

PUBLIC TYPE t_rpt_option RECORD
	envreport CHAR(1),
	dirreport CHAR(1),
	fieldreport CHAR(1),
	consolidate CHAR(1),
	output_preview CHAR(1),
	output_type CHAR(1)
END RECORD

PUBLIC DEFINE outputPreview BOOLEAN = FALSE
PUBLIC DEFINE outputType CHAR(1) = "p"

PUBLIC CONSTANT cOutputScreen = "t"
PUBLIC CONSTANT cOutputFile = "d"

PUBLIC CONSTANT cPDFType = "p"
PUBLIC CONSTANT cXLSXType = "x"
PUBLIC CONSTANT cTXTType = "t"

PUBLIC CONSTANT cCurrentDir = "."
PUBLIC CONSTANT cReportDir = "..%1reports%1."

PRIVATE DEFINE tmpFileName STRING

PUBLIC FUNCTION getEnvVars() RETURNS DYNAMIC ARRAY OF t_keyvalue
	DEFINE r_env t_keyvalue
	DEFINE a_env DYNAMIC ARRAY OF t_keyvalue
	DEFINE channel base.Channel
	DEFINE str_output STRING
	DEFINE idx INTEGER
	DEFINE cmd STRING

	LET channel = base.Channel.create()
	CALL a_env.clear()
	IF os.Path.separator() == "/" THEN
		LET cmd = "env"
	ELSE
		LET cmd = "set"
	END IF
	CALL channel.openPipe(cmd, "r")
	WHILE (str_output := channel.readLine()) IS NOT NULL
		LET idx = str_output.getIndexOf("=", 1)
		IF idx > 1 AND idx < str_output.getLength() THEN
			LET r_env.varname = str_output.subString(1, idx - 1)
			LET r_env.varvalue = str_output.subString(idx + 1, str_output.getLength())
			CALL a_env.appendElement()
			LET a_env[a_env.getLength()] = r_env
		END IF
	END WHILE
	CALL channel.close()

	RETURN a_env

END FUNCTION #getEnvVars

PUBLIC FUNCTION (rpt_options t_rpt_option) createEnvReport() RETURNS ()
	DEFINE sorted_vars DYNAMIC ARRAY OF t_keyvalue
	DEFINE idx INTEGER

	LET sorted_vars = getEnvVars()
	CALL sorted_vars.sort("varname", FALSE)

   IF rpt_options.output_type == cTXTType THEN
      LET tmpFileName = os.Path.makeTempName(), ".txt"
      START REPORT rptEnvVars TO FILE tmpFileName
   ELSE
      START REPORT rptEnvVars TO XML HANDLER rpt_options.reportConfiguration("envreport.4rp")
   END IF

	FOR idx = 1 TO sorted_vars.getLength()
		OUTPUT TO REPORT rptEnvVars(sorted_vars[idx].varname.getCharAt(1), sorted_vars[idx].*)
	END FOR

	FINISH REPORT rptEnvVars
	CALL rpt_options.saveReport()

END FUNCTION #createReport

REPORT rptEnvVars(firstChar CHAR(1), pair t_keyvalue)
	DEFINE charCount INTEGER

	ORDER EXTERNAL BY firstChar

	FORMAT
		BEFORE GROUP OF firstChar
			LET charCount = 0

		AFTER GROUP OF firstChar
			PRINT charCount

		ON EVERY ROW
			PRINT firstChar, pair.*
			LET charCount = charCount + 1

END REPORT

PUBLIC FUNCTION (rpt_options t_rpt_option) createFileReport() RETURNS ()
	DEFINE files DYNAMIC ARRAY OF t_fileinfo
	DEFINE idx INTEGER

	LET files = dirList(cCurrentDir)
	CALL files.sort("filename", FALSE)

   IF rpt_options.output_type == cTXTType THEN
      LET tmpFileName = os.Path.makeTempName(), ".txt"
      START REPORT rptFiles TO FILE tmpFileName
   ELSE
      START REPORT rptFiles TO XML HANDLER rpt_options.reportConfiguration("filereport.4rp")
   END IF

	FOR idx = 1 TO files.getLength()
		OUTPUT TO REPORT rptFiles(files[idx].*)
	END FOR

	FINISH REPORT rptFiles
	CALL rpt_options.saveReport()

END FUNCTION #createFileReport

REPORT rptFiles(fileinfo t_fileinfo)
	DEFINE fileCount INTEGER

	ORDER EXTERNAL BY fileinfo.filename

	FORMAT
		ON EVERY ROW
			PRINT fileinfo.*
			LET fileCount = fileCount + 1

		ON LAST ROW
			PRINT fileCount
			LET fileCount = 0

END REPORT #rptFiles

PUBLIC FUNCTION (rpt_options t_rpt_option) createFieldReport() RETURNS ()
	DEFINE formfields DYNAMIC ARRAY OF t_formfield
	DEFINE idx INTEGER

	LET formfields = getFields("ReportSelection.42f")
	CALL formfields.sort("field_id", FALSE)

   IF rpt_options.output_type == cTXTType THEN
      LET tmpFileName = os.Path.makeTempName(), ".txt"
      START REPORT rptFields TO FILE tmpFileName
   ELSE
      START REPORT rptFields TO XML HANDLER rpt_options.reportConfiguration("fieldreport.4rp")
   END IF

	FOR idx = 1 TO formfields.getLength()
		OUTPUT TO REPORT rptFields(formfields[idx].*)
	END FOR

	FINISH REPORT rptFields
	CALL rpt_options.saveReport()

END FUNCTION #createFieldReport

REPORT rptFields(formfield t_formfield)
	DEFINE fieldCount INTEGER

	ORDER EXTERNAL BY formfield.fullname

	FORMAT
		ON EVERY ROW
			PRINT formfield.*
			LET fieldCount = fieldCount + 1

		ON LAST ROW
			PRINT fieldCount
			LET fieldCount = 0

END REPORT

PUBLIC FUNCTION (rpt_options t_rpt_option) reportConfiguration(rpName STRING) RETURNS om.SaxDocumentHandler
	DEFINE reportFileName STRING
	# load the 4rp file
	IF NOT fgl_report_loadCurrentSettings(rpName) THEN
		RETURN NULL
	END IF

	LET reportFileName = os.Path.makeTempName(), ".pdf"

   CASE rpt_options.output_type
      WHEN cPDFType
         LET reportFileName = os.Path.makeTempName(), ".pdf"
         CALL fgl_report_selectDevice("PDF")
      WHEN cXLSXType
         LET reportFileName = os.Path.makeTempName(), ".xlsx"
         CALL fgl_report_configureXLSXDevice(NULL,NULL,NULL,NULL,NULL,NULL,TRUE)
         CALL fgl_report_selectDevice("XLSX")
      WHEN cTXTType
         LET reportFileName = os.Path.makeTempName(), ".txt"
	END CASE

	CALL fgl_report_selectPreview(FALSE)
	CALL fgl_report_setOutputFileName(reportFileName)
	LET tmpFileName = reportFileName

	RETURN fgl_report_commitCurrentSettings()

END FUNCTION

PUBLIC FUNCTION (rpt_options t_rpt_option) multiReport() RETURNS ()

   IF rpt_options.output_type == cTXTType THEN
      LET tmpFileName = os.Path.makeTempName(), ".txt"
      #START REPORT multipartReportText TO FILE tmpFileName
      START REPORT multipartReportText TO PIPE "cat >> " || tmpFileName
   ELSE
      START REPORT multipartReport TO XML HANDLER rpt_options.reportConfiguration("multipartReport.4rp")
   END IF
   IF rpt_options.output_type == cTXTType THEN
      OUTPUT TO REPORT multipartReportText(rpt_options.*)
      FINISH REPORT multipartReportText
   ELSE
      OUTPUT TO REPORT multipartReport(rpt_options.*)
      FINISH REPORT multipartReport
   END IF
	CALL rpt_options.saveReport()

END FUNCTION #multiReport

PUBLIC FUNCTION dirList(dirPath STRING) RETURNS (DYNAMIC ARRAY OF t_fileinfo)
	DEFINE myList DYNAMIC ARRAY OF t_fileinfo
	DEFINE idx INTEGER
	DEFINE handle INTEGER
	DEFINE filename STRING

	LET idx = 0
	IF dirPath == cReportDir THEN
		LET dirPath = SFMT(cReportDir, os.Path.separator())
	END IF

	LET handle = os.Path.dirOpen(dirPath)
	WHILE handle > 0
		LET filename = os.Path.dirNext(handle)
		IF filename IS NULL THEN
			EXIT WHILE
		END IF
		IF filename == "." OR filename == ".." THEN
			CONTINUE WHILE
		END IF
		LET idx = idx + 1
		LET myList[idx].filename = filename
		LET myList[idx].filesize = os.Path.size(SFMT("%1%2%3", dirPath, os.Path.separator(), filename))
		LET myList[idx].modtime = os.Path.mtime(SFMT("%1%2%3", dirPath, os.Path.separator(), filename))
	END WHILE

	CALL os.Path.dirClose(handle)

	RETURN myList

END FUNCTION #dirList

PUBLIC FUNCTION getFields(formfile STRING) RETURNS DYNAMIC ARRAY OF t_formfield
	DEFINE formfield t_formfield
	DEFINE formfields DYNAMIC ARRAY OF t_formfield
	DEFINE idx INTEGER
	DEFINE nodeList om.NodeList
	DEFINE root om.DomNode
	DEFINE xmldoc om.DomDocument
	DEFINE node om.DomNode

	LET xmldoc = om.DomDocument.createFromXmlFile(formfile)
	LET root = xmldoc.getDocumentElement()
	LET nodeList = root.selectByTagName("FormField")
	FOR idx = 1 TO nodeList.getLength()
		LET node = nodeList.item(idx)
		INITIALIZE formfield.* TO NULL
		LET formfield.fullname = node.getAttribute("name")
		LET formfield.col_name = node.getAttribute("colName")
		LET formfield.tab_name = node.getAttribute("sqlTabName")
		LET formfield.field_id = node.getAttribute("fieldId")
		LET formfield.tab_idx = node.getAttribute("tabIndex")
		LET formfields[idx] = formfield
	END FOR

	RETURN formfields

END FUNCTION #getFields

REPORT multipartReport(rpt_options t_rpt_option)
	DEFINE sorted_vars DYNAMIC ARRAY OF t_keyvalue
	DEFINE files DYNAMIC ARRAY OF t_fileinfo
	DEFINE formfields DYNAMIC ARRAY OF t_formfield
	DEFINE empty_vars t_keyvalue
	DEFINE empty_files t_fileinfo
	DEFINE empty_fields t_formfield
	DEFINE idx INTEGER

	FORMAT
		ON EVERY ROW

			PRINT rpt_options.*

			START REPORT rptEnvVars
			IF rpt_options.envreport == "Y" THEN

				LET sorted_vars = getEnvVars()
				CALL sorted_vars.sort("varname", FALSE)
				FOR idx = 1 TO sorted_vars.getLength()
					OUTPUT TO REPORT rptEnvVars(sorted_vars[idx].varname.getCharAt(1), sorted_vars[idx].*)
				END FOR
			ELSE
				OUTPUT TO REPORT rptEnvVars("", empty_vars.*)
			END IF
			FINISH REPORT rptEnvVars

			START REPORT rptFiles
			IF rpt_options.dirreport == "Y" THEN
				LET files = dirList(cCurrentDir)
				CALL files.sort("filename", FALSE)
				FOR idx = 1 TO files.getLength()
					OUTPUT TO REPORT rptFiles(files[idx].*)
				END FOR
			ELSE
				OUTPUT TO REPORT rptFiles(empty_files.*)
			END IF
			FINISH REPORT rptFiles

			START REPORT rptFields
			IF rpt_options.fieldreport == "Y" THEN
				LET formfields = getFields("ReportSelection.42f")
				CALL formfields.sort("field_id", FALSE)
				FOR idx = 1 TO formfields.getLength()
					OUTPUT TO REPORT rptFields(formfields[idx].*)
				END FOR
			ELSE
				OUTPUT TO REPORT rptFields(empty_fields.*)
			END IF
			FINISH REPORT rptFields

END REPORT

REPORT multipartReportText(rpt_options t_rpt_option)
	DEFINE sorted_vars DYNAMIC ARRAY OF t_keyvalue
	DEFINE files DYNAMIC ARRAY OF t_fileinfo
	DEFINE formfields DYNAMIC ARRAY OF t_formfield
	DEFINE empty_vars t_keyvalue
	DEFINE empty_files t_fileinfo
	DEFINE empty_fields t_formfield
	DEFINE idx INTEGER

	FORMAT
		ON EVERY ROW

			PRINT rpt_options.*

			START REPORT rptEnvVars TO PIPE "cat >> " || tmpFileName
			IF rpt_options.envreport == "Y" THEN

				LET sorted_vars = getEnvVars()
				CALL sorted_vars.sort("varname", FALSE)
				FOR idx = 1 TO sorted_vars.getLength()
					OUTPUT TO REPORT rptEnvVars(sorted_vars[idx].varname.getCharAt(1), sorted_vars[idx].*)
				END FOR
			ELSE
				OUTPUT TO REPORT rptEnvVars("", empty_vars.*)
			END IF
			FINISH REPORT rptEnvVars

			START REPORT rptFiles TO PIPE "cat >> " || tmpFileName
			IF rpt_options.dirreport == "Y" THEN
				LET files = dirList(cCurrentDir)
				CALL files.sort("filename", FALSE)
				FOR idx = 1 TO files.getLength()
					OUTPUT TO REPORT rptFiles(files[idx].*)
				END FOR
			ELSE
				OUTPUT TO REPORT rptFiles(empty_files.*)
			END IF
			FINISH REPORT rptFiles

			START REPORT rptFields TO PIPE "cat >> " || tmpFileName
			IF rpt_options.fieldreport == "Y" THEN
				LET formfields = getFields("ReportSelection.42f")
				CALL formfields.sort("field_id", FALSE)
				FOR idx = 1 TO formfields.getLength()
					OUTPUT TO REPORT rptFields(formfields[idx].*)
				END FOR
			ELSE
				OUTPUT TO REPORT rptFields(empty_fields.*)
			END IF
			FINISH REPORT rptFields

END REPORT

PRIVATE FUNCTION (rpt_options t_rpt_option) saveReport() RETURNS ()
	DEFINE saveFilename STRING
	DEFINE result BOOLEAN

	LET saveFilename = SFMT("..%1reports%1%2", os.Path.separator(), os.Path.baseName(tmpFilename))

	LET result = os.Path.copy(tmpFilename, saveFilename)

	IF result THEN
		DISPLAY SFMT("File %1 saved!", saveFilename)
		IF rpt_options.output_preview == cOutputScreen THEN
			CALL FGL_PUTFILE(saveFilename, os.Path.baseName(saveFilename))
		END IF
	ELSE
		DISPLAY SFMT("File %1 NOT saved!", saveFilename)
	END IF

END FUNCTION #saveReport