/****************************************************************/
/*					Cleanup (just in case)						*/
/****************************************************************/
IF OBJECT_ID('tempdb..#JobData') IS NOT NULL DROP TABLE #JobData;
IF OBJECT_ID('tempdb..#JobGoogleGraph') IS NOT NULL DROP TABLE #JobGoogleGraph;
GO

/****************************************************************/
/*				CREATE / DECLARE / SET part						*/
/****************************************************************/
DECLARE @StartDT DATETIME = DATEADD(DAY, -1, CONVERT(DATE, GETDATE()))
DECLARE @EndDT DATETIME = DATEADD(MILLISECOND, -2, CONVERT(DATETIME, CONVERT(DATE, GETDATE())))
DECLARE @MinRuntimeInSec INT = 10

CREATE TABLE #JobGoogleGraph
(
	ID		INT				NOT NULL	IDENTITY(1,1)
,	[HTML]	NVARCHAR(800)	NOT NULL
)

/****************************************************************/
/*						Google graph - Header					*/
/****************************************************************/
INSERT INTO #JobGoogleGraph (HTML)
VALUES
(
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
)

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
INSERT INTO #JobGoogleGraph (HTML)
SELECT
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
INSERT INTO #JobGoogleGraph (HTML)
VALUES
(
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
)

/****************************************************************/
/*				Copy to HTML (Google Chrome, UTF-8)				*/
/****************************************************************/
SELECT HTML FROM #JobGoogleGraph ORDER BY ID ASC