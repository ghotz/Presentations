SELECT
	Test,
	[Rows] = FORMAT([Rows], '#,#', 'it'),
	ElapsedSecs = FORMAT(ElapsedSecs, '#.000', 'it'),
	RowsPerSec = FORMAT([Rows] / ElapsedSecs, '#,#', 'it'),
	SchemaPersisted, DataPersisted, Compiled, DelayedDurability
FROM
	(	VALUES
		('STD',			100000, NULL, NULL, NULL, NULL, 'No'),
		('HSD',			100000, NULL, 'Yes', 'Yes', 'No', 'No'),
		('HSO',			100000, NULL, 'Yes', 'No', 'No', 'No'),
		('HSD_C',		100000, NULL, 'Yes', 'Yes', 'Yes', 'No'),
		('HSO_C',		100000, NULL, 'Yes', 'No', 'Yes', 'No'),
		('STD_DD',		100000, NULL, NULL, NULL, NULL, 'Yes'),
		('HSD_DD',		100000, NULL, 'Yes', 'Yes', 'No', 'Yes'),
		('HSD_C_DD',	100000, NULL, 'Yes', 'Yes', 'Yes', 'Yes')
	) T(Test, [Rows], ElapsedSecs, SchemaPersisted, DataPersisted, Compiled, DelayedDurability)
