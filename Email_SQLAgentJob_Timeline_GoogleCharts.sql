DECLARE @EmailRecipients VARCHAR(500) = 'e-mail@gmail.com'
DECLARE @CopyRecipients VARCHAR(255)
DECLARE @AttachmentFilename VARCHAR(255) = 'SQLAgentJobTimeline.html'
DECLARE @Email_Subject VARCHAR(255) = 'SQL Agent Job Timeline'

/****************************************************************/
/*					Cleanup (just in case)						*/
/****************************************************************/
IF OBJECT_ID('tempdb..#JobData') IS NOT NULL DROP TABLE #JobData;
IF OBJECT_ID('tempdb..##JobGoogleGraph_01') IS NOT NULL DROP TABLE ##JobGoogleGraph_01;

/****************************************************************/
/*				CREATE / DECLARE / SET part						*/
/****************************************************************/
DECLARE @StartDT DATETIME = DATEADD(DAY, -1, CONVERT(DATE, GETDATE()))
DECLARE @EndDT DATETIME = DATEADD(MILLISECOND, -2, CONVERT(DATETIME, CONVERT(DATE, GETDATE())))
DECLARE @MinRuntimeInSec INT = 10
DECLARE @HTML NVARCHAR(MAX) = ''
DECLARE @EmailProfileName VARCHAR(30) = 'Mail'
DECLARE @Email_Body VARCHAR(255) = 'Open attachment with Google Chrome.'

CREATE TABLE ##JobGoogleGraph_01 ([HTML] NVARCHAR(MAX))

/****************************************************************/
/*						Google graph - Header					*/
/****************************************************************/
SET @HTML = @HTML +
'<html>
	<head>
	<script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
	<script type="text/javascript">
		google.charts.load(''current'', {''packages'':[''timeline'']});
		google.charts.setOnLoadCallback(drawChart);
		
		function drawChart() {
		var container = document.getElementById(''timeline-tooltip'');
		var chart = new google.visualization.Timeline(container);
		var dataTable = new google.visualization.DataTable();

		dataTable.addColumn({ type: ''string'', id: ''JobName'' });
		dataTable.addColumn({ type: ''string'', id: ''Bar label'' });
		dataTable.addColumn({ type: ''string'', role: ''tooltip'' });
		dataTable.addColumn({ type: ''date'', id: ''Start'' });
		dataTable.addColumn({ type: ''date'', id: ''End'' });
		dataTable.addRows(
		[
'

/****************************************************************/
/*							Get data 							*/
/****************************************************************/
SELECT
	DS.JobName
,	'''''' AS BarLabel
,	' Start time: ' + CONVERT(VARCHAR, DS.StartDate, 8)
	+ ' End time: '+ CONVERT(VARCHAR, DS.EndDate, 8)  AS ToolTip
,	DS.StartDate
,	DS.EndDate
INTO
	#JobData
FROM
	(
		SELECT
			job.[name] AS JobName
		,	CONVERT(DATETIME, CONVERT(CHAR(8), run_date, 112) + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), run_time), 6), 5, 0, ':'), 3, 0, ':'), 120) AS StartDate
		,	DATEADD(SECOND,((run_duration / 10000) % 100 * 3600) + ((run_duration / 100) % 100 * 60) + run_duration % 100, CONVERT(DATETIME, CONVERT(CHAR(8), run_date, 112) 
			+ ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), run_time), 6), 5, 0, ':'), 3, 0, ':'), 120)) AS EndDate
		FROM
			msdb.dbo.sysjobs job
			LEFT JOIN msdb.dbo.sysjobhistory his
				ON his.job_id = job.job_id
			INNER JOIN msdb.dbo.syscategories cat
				ON job.category_id = cat.category_id
		WHERE
			CONVERT(DATETIME, CONVERT(CHAR(8), run_date, 112) + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), run_time), 6), 5, 0, ':'), 3, 0, ':'), 120)
				BETWEEN '' + CONVERT(NVARCHAR(20), @StartDT, 120) + '' AND '' + CONVERT(NVARCHAR(20), @EndDT, 120) + ''
			AND step_id = 0
			AND ((run_duration / 10000) % 100 * 3600) + ((run_duration / 100) % 100 * 60) + run_duration % 100 > @MinRuntimeInSec
	) AS DS
ORDER BY
	DS.StartDate

/****************************************************************/
/*						Google graph - Data 					*/
/****************************************************************/
/* Data in HTML */
SELECT @HTML = @HTML +
	'			[''' + DS.JOBNAME
+	''', ' + DS.BARLABEL
+	', ''' + DS.TOOLTIP
+	''', new Date('
+	DS.SD_YEAR + ', '
+	DS.SD_MONTH + ', '
+	DS.SD_DAY + ', '
+	DS.SD_HOUR + ', '
+	DS.SD_MINUTE + ', '
+	DS.SD_SECOND
+	') , new Date('
+	DS.SD_YEAR + ', '
+	DS.ED_MONTH + ', '
+	DS.ED_DAY + ', '
+	DS.ED_HOUR + ', '
+	DS.ED_MINUTE + ', '
+	DS.ED_SECOND + ') ],'
+	CHAR(13) + CHAR(10)
FROM
	(
		SELECT
			JR.JobName AS JOBNAME
		,	JR.BarLabel AS BARLABEL
		,	JR.ToolTip AS TOOLTIP
		/* Start Datetime */
		,	CONVERT(VARCHAR(30), DATEPART(YEAR, JR.StartDate)) AS SD_YEAR
		,	CONVERT(VARCHAR(30), DATEPART(MONTH, JR.StartDate)) AS SD_MONTH
		,	CONVERT(VARCHAR(30), DATEPART(DAY, JR.StartDate)) AS SD_DAY
		,	CONVERT(VARCHAR(30), DATEPART(HOUR, JR.StartDate)) AS SD_HOUR
		,	CONVERT(VARCHAR(30), DATEPART(MINUTE, JR.StartDate)) AS SD_MINUTE
		,	CONVERT(VARCHAR(30), DATEPART(SECOND, JR.StartDate)) AS SD_SECOND
		/* End Datetime */
		,	CONVERT(VARCHAR(30), DATEPART(YEAR, JR.EndDate)) AS ED_YEAR
		,	CONVERT(VARCHAR(30), DATEPART(MONTH, JR.EndDate)) AS ED_MONTH
		,	CONVERT(VARCHAR(30), DATEPART(DAY, JR.EndDate)) AS ED_DAY
		,	CONVERT(VARCHAR(30), DATEPART(HOUR, JR.EndDate)) AS ED_HOUR
		,	CONVERT(VARCHAR(30), DATEPART(MINUTE, JR.EndDate)) AS ED_MINUTE
		,	CONVERT(VARCHAR(30), DATEPART(SECOND, JR.EndDate)) AS ED_SECOND
		FROM
			#JobData AS JR
	) AS DS

/****************************************************************/
/*						Google graph - Footer 					*/
/****************************************************************/
SET @HTML = @HTML +
'
		]);

		var options =
		{
			timeline:
			{
				groupByRowLabel: true,
				colorByRowLabel: true,
				rowLabelStyle: {fontName: ''Helvetica'', fontSize: 12 }
			},
			height: 900,
			width: 1800
		};

		chart.draw(dataTable, options);
		}
	</script>
	</head>
	<body>
		<div id="timeline-tooltip" style="height: 180px;"></div>
	</body>
</html>'

INSERT INTO ##JobGoogleGraph_01 (HTML) VALUES (@HTML)

/****************************************************************/
/*						Send e-mail 							*/
/****************************************************************/
EXECUTE msdb.dbo.sp_send_dbmail	
	@profile_name = @EmailProfileName
,	@recipients = @EmailRecipients
,	@copy_recipients = @CopyRecipients
,	@subject = @Email_Subject
,	@body = @Email_Body
,	@execute_query_database = 'master'
,	@query = 'SET NOCOUNT ON; SELECT HTML FROM ##JobGoogleGraph_01'
,	@query_attachment_filename= @AttachmentFilename
,	@attach_query_result_as_file = 1
,	@query_no_truncate = 1