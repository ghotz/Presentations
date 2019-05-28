------------------------------------------------------------------------
-- Copyright:   2016 Gianluca Hotz
-- License:     MIT License
--              Permission is hereby granted, free of charge, to any
--              person obtaining a copy of this software and associated
--              documentation files (the "Software"), to deal in the
--              Software without restriction, including without
--              limitation the rights to use, copy, modify, merge,
--              publish, distribute, sublicense, and/or sell copies of
--              the Software, and to permit persons to whom the
--              Software is furnished to do so, subject to the
--              following conditions:
--              The above copyright notice and this permission notice
--              shall be included in all copies or substantial portions
--              of the Software.
--              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
--              ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
--              LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
--              FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
--              EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
--              FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
--              AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--              OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
--              OTHER DEALINGS IN THE SOFTWARE.
-- Credits:		
------------------------------------------------------------------------

------------------------------------------------------------------------
--	Creazione della sessione
--
--	Istruzioni per crearla in SSMS 2012
--		1	In Management/Extended Events/Session selezione New Session
--		2	In General dare il nome monitor_lock
--		3	In eventi cercare lock e selezionare lock_acquired
--		4	In Data Storage aggiungere un target event_counter
--		5	In advanced mettere 5 secondi come Maximum latency
------------------------------------------------------------------------
CREATE EVENT SESSION [monitor_lock] ON SERVER 
ADD EVENT sqlserver.lock_acquired 
ADD TARGET package0.event_counter	-- synchronous_event_counter per 2008R2
WITH (MAX_DISPATCH_LATENCY=5 SECONDS);
GO

------------------------------------------------------------------------
--	Far partire la sessione
--	In SSMS 2012 Start Session
------------------------------------------------------------------------
ALTER EVENT SESSION [monitor_lock] ON SERVER 
STATE = START;
GO

------------------------------------------------------------------------
--	In SSMS 2012 verificare target data per la sessione
--	Eseguire le query nel file xe.04.sample-session-locks-queries.sql
--	In SSMS 2012 verificare che il contatore sale
------------------------------------------------------------------------
SELECT	XS.name AS session_name
,		XT.target_name
,		XT.execution_count
,		XT.execution_duration_ms
,		CAST(XT.target_data AS xml) AS target_data
FROM	sys.dm_xe_sessions AS XS
JOIN	sys.dm_xe_session_targets AS XT
  ON	XS.[address] = XT.event_session_address
WHERE	XS.name = N'monitor_lock'
  AND	XT.target_name = N'event_counter';	-- N'synchronous_event_counter' per 2008R2
GO

--	In questo caso possiamo vedere subito il numero di eventi
--	nella colonna execution_count ma l'evento e' nel target_data
--	in XML e dovremmo farne il parse.
SELECT
	event_node.value('../@name[1]', 'varchar(50)') AS PackageName
,	event_node.value('@name[1]', 'varchar(50)') AS EventName
,	event_node.value('@count[1]', 'int') AS Occurence
FROM	(
		SELECT	CAST(XT.target_data AS xml) AS target_data
		FROM	sys.dm_xe_sessions AS XS
		JOIN	sys.dm_xe_session_targets AS XT
		  ON	XS.[address] = XT.event_session_address
		WHERE	XS.name = N'monitor_lock'
		  AND	XT.target_name = N'event_counter'	-- N'synchronous_event_counter' per 2008R2
		) AS ED
CROSS
APPLY	target_data.nodes('CounterTarget/Packages/Package/Event') as XQ(event_node);
GO

------------------------------------------------------------------------
--	Contare semplicemente gli eventi di lock non ci da molte
--	informazioni, vediamo come possiamo contarli almeno per tipologia
--
--	Istruzioni in SSMS 2012
--		1	Aprire le proprieta' della sessione
--		2	Andare in Data Storage e aggiungere un histogram
--			selezionando lock_acquired come Filter e mode come Field
------------------------------------------------------------------------
ALTER EVENT SESSION [monitor_lock] ON SERVER 
ADD TARGET package0.histogram	-- asynchronous_bucketizer per 2008R2
(
	SET filtering_event_name=N'sqlserver.lock_acquired'
	,	source=N'mode'
	,	source_type=(0)	-- Event
)
GO

------------------------------------------------------------------------
--	In SSMS 2012 verificare target data per la sessione
--	Eseguire le query nel file xe.04.sample-session-locks-queries.sql
--	In SSMS 2012 verificare che i contatori salgono
--
--	Il problema in questo caso e' che i vari slot dell'istorgramma
--	hanno solo un identificatore numerico che deve essere decodificato
--	proviamo quindi con delle query
------------------------------------------------------------------------
SELECT
	slot_node.value('(value)[1]', 'int') AS histogram_value
,	slot_node.value('@count[1]', 'int') AS histogram_count
FROM	(
		SELECT	CAST(XT.target_data AS xml) AS target_data
		FROM	sys.dm_xe_sessions AS XS
		JOIN	sys.dm_xe_session_targets AS XT
		  ON	XS.[address] = XT.event_session_address
		WHERE	XS.name = N'monitor_lock'
		  AND	XT.target_name = N'histogram'	-- N'asynchronous_bucketizer' per 2008R2
		) AS ED
CROSS
APPLY	target_data.nodes('HistogramTarget/Slot') as XQ(slot_node);	-- 'BucketizerTarget/Slot' per 2008R2
GO

--	Con la query precedente abbiamo ottenuto lo stesso risultato
--	ottenuto con SSMS, guardando nei metadati delle colonne
--	tornate dall'evento (per la colonna "mode") sappiamo che e'
--	una colonna di tipo "lock_mode" che prevede la decodifica
--	tramite le Maps di XE, proviamo quindi con la seguente query:
WITH	cte_histogram AS
(
	SELECT
		slot_node.value('(value)[1]', 'int') AS histogram_value
	,	slot_node.value('@count[1]', 'int') AS histogram_count
	FROM	(
			SELECT	CAST(XT.target_data AS xml) AS target_data
			FROM	sys.dm_xe_sessions AS XS
			JOIN	sys.dm_xe_session_targets AS XT
			  ON	XS.[address] = XT.event_session_address
			WHERE	XS.name = N'monitor_lock'
			  AND	XT.target_name = N'histogram'	-- N'asynchronous_bucketizer' per 2008R2
			) AS ED
	CROSS
	APPLY	target_data.nodes('HistogramTarget/Slot') as XQ(slot_node)	-- 'BucketizerTarget/Slot' per 2008R2
)
SELECT	XM.map_value, HI.histogram_count
FROM	cte_histogram AS HI
JOIN	sys.dm_xe_map_values AS XM
  ON	HI.histogram_value = XM.map_key
WHERE	name = N'lock_mode'
GO

------------------------------------------------------------------------
--	Proviamo a contare i lock per database invece che per tipo
--
--	Istruzioni in SSMS 2012
--		1	Aprire le proprieta' della sessione
--		2	Andare in Events e poi Configure e Event Fields
--
--	La prima cosa da notare e' che la colonna database_name esiste ma
--	non e' selezionata, si tratta di una colonna di tipo "customizable"
--	cioe' che non viene raccolta di default perché troppo onerosa.
--
--	La seconda cosa da notare e' che questa colonna non esiste in
--	SQL Server 2008R2 quindi il seguente esempio prosegue solo per
--	la versione 2012 
--
--	Istruzioni in SSMS 2012
--		1	Selezionare la colonna database_name
--		2	Andare in Data Storage
--		3	Rimuovere l'istogramma
--		4	Crearne uno nuovo istogramma con lock_acquired come Filter
--			database_name come Field 
------------------------------------------------------------------------
--	Elimina la definizione dell'evento
ALTER EVENT SESSION [monitor_lock] ON SERVER 
DROP EVENT sqlserver.lock_acquired;
GO
--	Elimina la definizione del target
ALTER EVENT SESSION [monitor_lock] ON SERVER 
DROP TARGET package0.histogram;
GO
--	Aggiunge il nuovo target histogram
ALTER EVENT SESSION [monitor_lock] ON SERVER 
ADD TARGET package0.histogram
(
	SET	filtering_event_name=N'sqlserver.lock_acquired'
	,	source=N'database_name'
	,	source_type=(0)	-- Event
);
--	Aggiunge nuovamente l'evento lock_acquired specificando di
--	raccogliere anche il database_name impostando la proprieta'
--	booleana (di tipo "customizable") collect_database_name
ALTER EVENT SESSION [monitor_lock] ON SERVER
ADD EVENT sqlserver.lock_acquired(SET collect_database_name=(1));
GO

------------------------------------------------------------------------
--	Ancora una volta possiamo vedere il risultato tramite SSMS oppure
--	tramite una query XQuery opportunamento modificata perche'
--	il tipo dato tornato non e' piu' numerico
------------------------------------------------------------------------
SELECT
	slot_node.value('(value)[1]', 'nvarchar(128)') AS histogram_value
,	slot_node.value('@count[1]', 'int') AS histogram_count
FROM	(
		SELECT	CAST(XT.target_data AS xml) AS target_data
		FROM	sys.dm_xe_sessions AS XS
		JOIN	sys.dm_xe_session_targets AS XT
		  ON	XS.[address] = XT.event_session_address
		WHERE	XS.name = N'monitor_lock'
		  AND	XT.target_name = N'histogram'	-- N'asynchronous_bucketizer' per 2008R2
		) AS ED
CROSS
APPLY	target_data.nodes('HistogramTarget/Slot') as XQ(slot_node);	-- 'BucketizerTarget/Slot' per 2008R2
GO

------------------------------------------------------------------------
--	Un problema con il target di tipo histogram e' che puo' raggruppare
--	solo per una proprieta' e ne puo' esistere uno solo per sessione.
--
--	Se volessimo raggruppare per entrambe le proprieta' (tipo lock e
--	database), potremmo registrare l'intero evento in un Ring Buffer
--	come segue.
--
--	Istruzioni in SSMS 2012
--		1	Aprire le proprieta' della sessione
--		2	Andare in Data Storage
--		3	Aggiungere un target di tipo ring_buffer specificando 10MB
--			come dimensione massima dei buffer
--
------------------------------------------------------------------------
ALTER EVENT SESSION [monitor_lock] ON SERVER 
ADD TARGET package0.ring_buffer(
	SET	max_events_limit=(100)
	,	max_memory=(5120)
);
GO

------------------------------------------------------------------------
--	Qui ne il View Target Data, ne il Watch Live Data di SSMS sono
--	molto di aiuto... cominciamo leggendo alcune proprieta' del
--	Ring Buffer utilizzando una variabile xml perche' piu'
--	performante (http://dba.stackexchange.com/a/30947)
------------------------------------------------------------------------
DECLARE	@ring_buffer	xml;
SELECT	@ring_buffer = 	CAST(XT.target_data AS xml)
FROM	sys.dm_xe_sessions AS XS
JOIN	sys.dm_xe_session_targets AS XT
  ON	XS.[address] = XT.event_session_address
WHERE	XS.name = N'monitor_lock'
	AND	XT.target_name = N'ring_buffer';

--	Dati relativi al Ring Buffer
SELECT
	@ring_buffer.value('(RingBufferTarget/@truncated)[1]', 'int') AS rb_truncated
,	@ring_buffer.value('(RingBufferTarget/@processingTime)[1]', 'int') AS rb_processingTime
,	@ring_buffer.value('(RingBufferTarget/@totalEventsProcessed)[1]', 'int') AS rb_totalEventsProcessed
,	@ring_buffer.value('(RingBufferTarget/@eventCount)[1]', 'int') AS rb_eventCount
,	@ring_buffer.value('(RingBufferTarget/@droppedCount)[1]', 'int') AS rb_droppedCount
,	@ring_buffer.value('(RingBufferTarget/@memoryUsed)[1]', 'int') AS rb_memoryUsed

--	Emissione singoli eventi
SELECT	event_node.query('.') AS event_data
FROM	@ring_buffer.nodes('RingBufferTarget/event') AS XQ(event_node);

--	con filtro per evento
--	SELECT	event_node.query('.') AS event_data
--	FROM	@ring_buffer.nodes('RingBufferTarget/event[@name=''lock_acquired'']') AS XQ(event_node);
GO

------------------------------------------------------------------------
--	Oppure possiamo estrarre direttamente le informazioni e fare
--	l'aggregazione
------------------------------------------------------------------------
DECLARE	@ring_buffer	xml;
SELECT	@ring_buffer = 	CAST(XT.target_data AS xml)
FROM	sys.dm_xe_sessions AS XS
JOIN	sys.dm_xe_session_targets AS XT
  ON	XS.[address] = XT.event_session_address
WHERE	XS.name = N'monitor_lock'
  AND	XT.target_name = N'ring_buffer';

WITH cte_locks AS
(
	SELECT
		XQ.event_node.value('(@name)[1]', 'varchar(50)') AS event_name
	,	XQ.event_node.value('(@package)[1]', 'varchar(50)') AS package_name
	,	DATEADD(hh , DATEDIFF(hh, GETUTCDATE(), CURRENT_TIMESTAMP)
	,	XQ.event_node.value('(@timestamp)[1]', 'datetime2')) AS [timestamp]
	,	XQ.event_node.value('(data[@name="resource_type"]/text)[1]', 'nvarchar(60)') as resource_type
	,	XQ.event_node.value('(data[@name="mode"]/text)[1]', 'nvarchar(60)') as mode
	,	XQ.event_node.value('(data[@name="database_name"]/value)[1]', 'nvarchar(128)') as database_name
	FROM	@ring_buffer.nodes('RingBufferTarget/event[@name=''lock_acquired'']') AS XQ(event_node)
)
SELECT	database_name, resource_type, mode AS request_mode, COUNT(*) AS lock_count
FROM	cte_locks
GROUP BY
		database_name, resource_type, mode;
GO
------------------------------------------------------------------------
--	Un altro problema puo' essere il numero di eventi che vengono
--	tracciati: potrebbero non starci nel Ring Buffer oppure potrebbero
--	essere troppi per essere analizzati in maniera performante con le
--	query su XML.
--
--	Una soluzione potrebbe essere quella di tracciare gli eventi in modo
--	piu' mirato, ad esempio con un predicato che filtri solo gli eventi
--	di alcuni database.
--
--	Istruzioni in SSMS 2012
--		1	Aprire le proprieta' della sessione
--		2	Andare in Events e poi Configure e Filter (predicate)
--		3	Impostare due predicati in OR per database_name = 
--			AdventureWorks2012 e AdventureWorksLT2012
------------------------------------------------------------------------
--	Elimina la definizione dell'evento
ALTER EVENT SESSION [monitor_lock] ON SERVER 
DROP EVENT sqlserver.lock_acquired;
GO
--	Aggiunge nuovamente l'evento specificando il predicato
ALTER EVENT SESSION [monitor_lock] ON SERVER 
ADD EVENT sqlserver.lock_acquired
(
	SET collect_database_name=(1)
    WHERE
	(
			([database_name]=N'AdventureWorks2012')
		OR	([database_name]=N'AdventureWorksLT2012')
	)
);
GO

------------------------------------------------------------------------
--	A questo punto gli eventi registrati sono solo quelli per quei
--	due database specificati nel predicato
------------------------------------------------------------------------
DECLARE	@ring_buffer	xml;
SELECT	@ring_buffer = 	CAST(XT.target_data AS xml)
FROM	sys.dm_xe_sessions AS XS
JOIN	sys.dm_xe_session_targets AS XT
  ON	XS.[address] = XT.event_session_address
WHERE	XS.name = N'monitor_lock'
  AND	XT.target_name = N'ring_buffer';

WITH cte_locks AS
(
	SELECT
		XQ.event_node.value('(@name)[1]', 'varchar(50)') AS event_name
	,	XQ.event_node.value('(@package)[1]', 'varchar(50)') AS package_name
	,	DATEADD(hh , DATEDIFF(hh, GETUTCDATE(), CURRENT_TIMESTAMP)
		, XQ.event_node.value('(@timestamp)[1]', 'datetime2')) AS [timestamp]
	,	XQ.event_node.value('(data[@name="resource_type"]/text)[1]', 'nvarchar(60)') as resource_type
	,	XQ.event_node.value('(data[@name="mode"]/text)[1]', 'nvarchar(60)') as mode
	,	XQ.event_node.value('(data[@name="database_name"]/value)[1]', 'nvarchar(128)') as database_name
	FROM	@ring_buffer.nodes('RingBufferTarget/event[@name=''lock_acquired'']') AS XQ(event_node)
)
SELECT	database_name, resource_type, mode AS request_mode, COUNT(*) AS lock_count
FROM	cte_locks
GROUP BY
		database_name, resource_type, mode;
GO

------------------------------------------------------------------------
--	Dato che i Ring Buffer sono in memoria, il loro contenuto non
--	viene mantenuto se l'istanza viene fatta ripartire, in alcuni
--	casi e' necessario scrivere gli eventi in modo persistente.
--
--	Istruzioni in SSMS 2012
--		1	Aprire le proprieta' della sessione
--		2	Andare in Data Storage
--		3	Aggiungere un target di tipo event_file
------------------------------------------------------------------------
ALTER EVENT SESSION [monitor_lock] ON SERVER 
ADD TARGET package0.event_file
(
	SET filename=N'C:\Temp\xevents\monitor_lock.xel'
);
GO

------------------------------------------------------------------------
--	In maniera analoga lla precedente possiamo estrarre i vari elementi
--	dagli eventi tracciati nel file
------------------------------------------------------------------------
WITH cte_locks AS
(
	SELECT
		XQ.event_node.value('(@name)[1]', 'varchar(50)') AS event_name
	,	XQ.event_node.value('(@package)[1]', 'varchar(50)') AS package_name
	,	DATEADD(hh , DATEDIFF(hh, GETUTCDATE(), CURRENT_TIMESTAMP)
		, XQ.event_node.value('(@timestamp)[1]', 'datetime2')) AS [timestamp]
	,	XQ.event_node.value('(data[@name="resource_type"]/text)[1]', 'nvarchar(60)') as resource_type
	,	XQ.event_node.value('(data[@name="mode"]/text)[1]', 'nvarchar(60)') as mode
	,	XQ.event_node.value('(data[@name="database_name"]/value)[1]', 'nvarchar(128)') as database_name
	FROM	(
			SELECT	CAST(event_data AS xml) AS event_data
			FROM	sys.fn_xe_file_target_read_file('C:\Temp\xevents\monitor_lock*.xel', NULL, NULL, NULL)
			) AS ED
	CROSS
	APPLY	event_data.nodes('event') as XQ(event_node)
)
SELECT	database_name, resource_type, mode AS request_mode, COUNT(*) AS lock_count
FROM	cte_locks
GROUP BY
		database_name, resource_type, mode
ORDER BY 
	database_name, resource_type, mode;
GO

------------------------------------------------------------------------
--	L'opzione Causality Tracking permette di correlare le attività
--	tramite due ulteriori colonne:
--		attach_activity_id.guid
--		attach_activity_id.seq
--	
--	Istruzioni in SSMS 2012
--		1	Fermare la sessione
--		2	Aprire le proprieta' della sessione
--		3	Impostare l'opzione Causality Tracking
--		4	Fare ripartire la sessione
------------------------------------------------------------------------
--	Fermare la sessione
ALTER EVENT SESSION [monitor_lock] ON SERVER
STATE=STOP;
GO
--	Modificare l'impostazione
ALTER EVENT SESSION [monitor_lock] ON SERVER 
WITH	(TRACK_CAUSALITY=ON);
GO
--	Fare ripartire la sessione
ALTER EVENT SESSION [monitor_lock] ON SERVER
STATE=START;
GO

------------------------------------------------------------------------
--	Funzionalita' da vedere in SSMS 2012
--		1	Raggruppamento/Aggregazione eventi
--		2	Export in CSV/XEL/Tabella
--		3	Merge dei file XEL
------------------------------------------------------------------------
SELECT * FROM tempdb.dbo.xe_locks;
GO
------------------------------------------------------------------------
--	Per fermare una sessione
------------------------------------------------------------------------
ALTER EVENT SESSION [monitor_lock] ON SERVER
STATE=STOP;
GO

------------------------------------------------------------------------
--	Per eliminare una sessione
------------------------------------------------------------------------
DROP EVENT SESSION [monitor_lock] ON SERVER;
GO

