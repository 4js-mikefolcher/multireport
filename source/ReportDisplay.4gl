IMPORT FGL ReportLib

MAIN
	DEFINE rpt_options ReportLib.t_rpt_option
	DEFINE rpt_output CHAR(1)

	OPEN WINDOW reportWindow WITH FORM "ReportSelection"

	LET rpt_options.envreport = "Y"
	LET rpt_options.dirreport = "Y"
	LET rpt_options.fieldreport = "Y"
	LET rpt_options.consolidate = "Y"
	LET rpt_output = "t" #PDF

	INPUT rpt_options.*, rpt_output WITHOUT DEFAULTS FROM s_rpt_options.*
		ON ACTION CANCEL
			EXIT INPUT
		AFTER INPUT
			LET ReportLib.outputPreview = (rpt_output == "t")
			IF rpt_options.consolidate == "Y" THEN
				CALL ReportLib.multiReport(rpt_options.*)
			ELSE
				IF rpt_options.envreport == "Y" THEN
					CALL ReportLib.createEnvReport()
				END IF
				IF rpt_options.dirreport== "Y" THEN
					CALL ReportLib.createFileReport()
				END IF
				IF rpt_options.fieldreport== "Y" THEN
					CALL ReportLib.createFieldReport()
				END IF
			END IF
			MESSAGE "Generating reports..."
			CONTINUE INPUT
	END INPUT

	CLOSE WINDOW reportWindow

END MAIN