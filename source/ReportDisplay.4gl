IMPORT os
IMPORT FGL ReportLib

MAIN
	DEFINE rpt_options ReportLib.t_rpt_option
	DEFINE rpt_files DYNAMIC ARRAY OF ReportLib.t_fileinfo
	DEFINE filepath STRING

	OPEN WINDOW reportWindow WITH FORM "ReportSelection"

	LET rpt_options.envreport = "Y"
	LET rpt_options.dirreport = "Y"
	LET rpt_options.fieldreport = "Y"
	LET rpt_options.consolidate = "Y"
	LET rpt_options.output_preview = ReportLib.cOutputScreen
	LET rpt_options.output_type = ReportLib.cPDFType

	LET rpt_files = ReportLib.dirList(ReportLib.cReportDir)
	CALL rpt_files.sort("modtime", TRUE)

	DIALOG ATTRIBUTES(UNBUFFERED)

		INPUT rpt_options.* FROM s_rpt_options.*
		 ATTRIBUTES(WITHOUT DEFAULTS=TRUE)

			ON ACTION generate_report ATTRIBUTES(TEXT="Run Report")
				IF rpt_options.consolidate == "Y" THEN
					CALL rpt_options.multiReport()
				ELSE
					IF rpt_options.envreport == "Y" THEN
						CALL rpt_options.createEnvReport()
					END IF
					IF rpt_options.dirreport== "Y" THEN
						CALL rpt_options.createFileReport()
					END IF
					IF rpt_options.fieldreport== "Y" THEN
						CALL rpt_options.createFieldReport()
					END IF
				END IF
				LET rpt_files = ReportLib.dirList(ReportLib.cReportDir)
				CALL rpt_files.sort("modtime", TRUE)
				CONTINUE DIALOG
		END INPUT

		DISPLAY ARRAY rpt_files TO s_file_info.*
			ATTRIBUTES(DOUBLECLICK=view_file)

			ON ACTION view_file
				LET filepath = SFMT("..%1reports%1%2", os.Path.separator(), rpt_files[arr_curr()].filename)
				CALL FGL_PUTFILE(filepath, os.Path.baseName(filepath))

		END DISPLAY

		ON ACTION CANCEL
			EXIT DIALOG

	END DIALOG

	CLOSE WINDOW reportWindow

END MAIN