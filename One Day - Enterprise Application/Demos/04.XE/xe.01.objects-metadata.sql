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
-- Credits:		Jonathan Kehayias
--              https://www.sqlskills.com/blogs/jonathan/an-xevent-a-day-31-days-of-extended-events
------------------------------------------------------------------------

--
--	Parte del codice e' basato su serie di 31 articoli di Jonathan Kehayias
--	https://www.sqlskills.com/blogs/jonathan/an-xevent-a-day-31-days-of-extended-events
--
--	La cosa fondamentale da capire è che tutti i metadati ruotano intorno
--	a poche DMV che devono essere filtrate e messe in join in maniera opportuna:
--		*	sys.dm_xe_packages
--		*	sys.dm_xe_objects
--		*	sys.dm_xe_object_columns
--		*	sys.dm_xe_map_values
--

--
--	I Package XE sono contenitori di oggetti: Events, Actions, predicates, Target, Maps e Types.
--	Sono contenuti in moduli che possono essere eseguibili o libreri (DLL)
--
 
	--	XE Packages (predicato per filtrare quelli non utilizzabili es. SecAudit)
	SELECT	XP.[name], XP.[guid], XP.[description]
	FROM	sys.dm_xe_packages AS XP
	WHERE	XP.capabilities IS NULL OR XP.capabilities & 1 = 0
	ORDER BY XP.[name];
	GO

	--	Informazioni che riguardano i moduli dei package
	SELECT	XP.[name] AS package_name, XP.[guid] AS package_guid
	,		XP.[description] AS package_description
	,		LM.[name] AS module_name
	FROM	sys.dm_xe_packages AS XP
	JOIN	sys.dm_os_loaded_modules AS LM
	  ON	XP.module_address = LM.base_address
	WHERE	XP.capabilities IS NULL OR XP.capabilities & 1 = 0
	ORDER BY package_name, module_name;
	GO

--
--	Gli Eventi XE sono dei punti di interesse da monitorare nel codice dell'engine.
--	Contengono la definizione delle informazioni da tracciare che possono essere arricchite tramite le Actions.
--
--	Numericamente in crescita, SQL Trace già deprecato in SQL Server 2012:
--	SQL Server 2008R2 SP2:		262
--	SQL Server 2012 SP1:		625 (copertura completa dei 180 eventi SQL Trace)
--	SQL Server 2014 CTP2:		775
--  SQL Server 2014 SP1-CU3:	872
--	SQL Server 2016 RTM:		1301
--	SQL Server 2016 SP1:		1324
--	SQL Server 2017 CU14:		1514
--
--	Nota: no_block in capabilities_desc significa che l'evento si trova in punto critico del
--	percorso di esecuzione del programma che non puo' essere bloccato, per questo motivo
--	l'evento non puo' essere aggiunto ad una sessione che non puo' perdere eventi (NO_EVENT_LOSS).
--

	--	XE Events
	SELECT
			XP.name AS package_name
	,		XO.name AS event_name
	,		XO.[description] AS event_description
	,		XO.capabilities_desc
	FROM	sys.dm_xe_packages AS XP
	JOIN	sys.dm_xe_objects AS XO
	  ON	XP.[guid] = XO.package_guid
	WHERE	(XP.capabilities IS NULL OR XP.capabilities & 1 = 0)
	  AND	(XO.capabilities IS NULL OR XO.capabilities & 1 = 0)
	  AND	XO.object_type = N'event';
	GO

--
--	I tipi XE definiscono i tipi dato delle varie proprieta' in Extended Events
--

	--	XE Types
	SELECT
			XP.name AS package_name
	,		XO.name AS [type_name]
	,		XO.[description] AS type_description
	FROM	sys.dm_xe_packages AS XP
	JOIN	sys.dm_xe_objects AS XO
	  ON	XP.[guid] = XO.package_guid
	WHERE	(XP.capabilities IS NULL OR XP.capabilities & 1 = 0)
	  AND	(XO.capabilities IS NULL OR XO.capabilities & 1 = 0)
	  AND	XO.object_type = 'type';
	GO

--
--	le mappe XE definiscono i valori di decodifica di alcune proprieta' in Extended Events
--

	--	XE Maps
	SELECT	XM.*
	FROM	sys.dm_xe_map_values AS XM
	WHERE	XM.name = 'wait_types'
	  AND	map_value LIKE 'PAGEIO%';
	GO

--
--	Ogni evento definisce quali proprieta' vengono raccolte e alcune di
--	queste, quelle con column_type = 'customizable', vengono raccolte solo
--	su richiesta specifica.
--
--	Prendiamo come esempio l'evento lock_acquired che viene generato
--	ogni volta che un lock viene acquisito.
-- 

	--	Proprieta' tracciate per l'evento
	SELECT
			XC.name AS column_name
	,		XC.column_type AS column_type
	,		XC.column_value AS column_value
	,		XC.[description] AS column_description
	FROM	sys.dm_xe_packages	AS XP
	JOIN	sys.dm_xe_objects	AS XO
	  ON	XP.[guid] = XO.package_guid
	JOIN	sys.dm_xe_object_columns AS XC
	  ON	XO.package_guid = XC.object_package_guid
	 AND	XO.name = XC.[object_name]
	WHERE	(XP.capabilities IS NULL OR XP.capabilities & 1 = 0)
	  AND	(XO.capabilities IS NULL OR XO.capabilities & 1 = 0)
	  AND	(XC.capabilities IS NULL OR XC.capabilities & 1 = 0)
	  AND	XO.object_type = N'event'
	  AND	XO.name = N'lock_acquired';
	GO

	--	Tipi dato delle proprieta' ritornate dagli eventi
	SELECT
			XC1.name AS column_name
	,		XC1.column_type AS column_type
	,		XC1.[description] AS column_description
	,		XC1.[type_name] AS column_data_type
	,		XO2.[description] AS column_data_type_description
	,		XO2.object_type AS column_data_type_type
	,		XC1.type_package_guid
	FROM	sys.dm_xe_packages	AS XP1
	JOIN	sys.dm_xe_objects	AS XO1
	  ON	XP1.[guid] = XO1.package_guid
	JOIN	sys.dm_xe_object_columns AS XC1
	  ON	XO1.package_guid = XC1.object_package_guid
	 AND	XO1.name = XC1.[object_name]
	JOIN	sys.dm_xe_packages AS XP2
	  ON	XC1.type_package_guid = XP2.[guid]
	JOIN	sys.dm_xe_objects AS XO2
	  ON	XP2.[guid] = XO2.package_guid
	 AND	XC1.[type_name] = XO2.name
	WHERE	(XP1.capabilities IS NULL OR XP1.capabilities & 1 = 0)
	  AND	(XO1.capabilities IS NULL OR XO1.capabilities & 1 = 0)
	  AND	(XP2.capabilities IS NULL OR XP2.capabilities & 1 = 0)
	  AND	(XO2.capabilities IS NULL OR XO2.capabilities & 1 = 0)
	  AND	(XC1.capabilities IS NULL OR XC1.capabilities & 1 = 0)
	  AND	XO1.object_type = 'event'
	  AND	XO1.name = 'lock_acquired'
	  AND	XO2.object_type IN ('type', 'map');
	GO

	--	Mappe definite per le proprieta' dell'evento SQL Server 2012/2014
	--	per 2008R2 sostituire GUID 03FDA7D0-91BA-45F8-9875-8B6DD0B8E9F2 con 655FD93F-3364-40D5-B2BA-330F7FFB6491
	SELECT	map_key, map_value FROM sys.dm_xe_map_values WHERE name = N'etw_channel' AND object_package_guid = '60AA9FBF-673B-4553-B7ED-71DCA7F5E972';
	SELECT	map_key, map_value FROM sys.dm_xe_map_values WHERE name = N'keyword_map' AND object_package_guid = '03FDA7D0-91BA-45F8-9875-8B6DD0B8E9F2';
	SELECT	map_key, map_value FROM sys.dm_xe_map_values WHERE name = N'lock_resource_type' AND object_package_guid = '03FDA7D0-91BA-45F8-9875-8B6DD0B8E9F2';
	SELECT	map_key, map_value FROM sys.dm_xe_map_values WHERE name = N'lock_mode' AND object_package_guid = '03FDA7D0-91BA-45F8-9875-8B6DD0B8E9F2';
	SELECT	map_key, map_value FROM sys.dm_xe_map_values WHERE name = N'lock_owner_type' AND object_package_guid = '03FDA7D0-91BA-45F8-9875-8B6DD0B8E9F2';
	GO

--
--	Le azioni XE sono eseguite quando viene generato un evento e in genere sono due tipi:
--		* quelle che arricchiscono le informazioni dell'evento (solitamente hanno nella descrizione "Collect")
--		* quelle che eseguono azioni interne all'engine (solitamente hanno nella descrizione "Break" o "Create")
--

	--	XE Actions
	SELECT
			XP.name AS package_name
	,		XO.name AS action_name
	,		XO.[description] AS action_description
	FROM	sys.dm_xe_packages AS XP
	JOIN	sys.dm_xe_objects AS XO
	  ON	XP.[guid] = XO.package_guid
	WHERE	(XP.capabilities IS NULL OR XP.capabilities & 1 = 0)
	  AND	(XO.capabilities IS NULL OR XO.capabilities & 1 = 0)
	  AND	XO.object_type = N'action';
	GO

	--	Esempio per decodificare i tipi dell'azione query_hash
	SELECT
			XP1.name AS action_package_name
	,		XO1.name AS action_name
	,		XO1.[description] AS action_description
	,		XO1.[type_name] AS action_data_type_name
	,		XO2.[description] AS action_data_type_description
	,		XO2.object_type AS action_data_type_type
	FROM	sys.dm_xe_packages	AS XP1
	JOIN	sys.dm_xe_objects	AS XO1
	  ON	XP1.[guid] = XO1.package_guid
	JOIN	sys.dm_xe_packages AS XP2
	  ON	XO1.type_package_guid = XP2.[guid]
	JOIN	sys.dm_xe_objects AS XO2
	  ON	XP2.[guid] = XO2.package_guid
	 AND	XO1.[type_name] = XO2.name
	WHERE	(XP1.capabilities IS NULL OR XP1.capabilities & 1 = 0)
	  AND	(XO1.capabilities IS NULL OR XO1.capabilities & 1 = 0)
	  AND	(XP2.capabilities IS NULL OR XP2.capabilities & 1 = 0)
	  AND	(XO2.capabilities IS NULL OR XO2.capabilities & 1 = 0)
	  AND	XO1.object_type = 'action'
	  AND	XO1.name = 'sql_text'
	  AND	XO2.object_type IN ('type', 'map');
	  GO

--
--	I predicati XE sono un meccanismo di filtro tramite regole logiche applicate al payload
--	degli eventi o alle informazioni di stato globali (Source Objects)
--
--	Le regole possono essere valutate prima della generazione dell'evento, nel qual caso
--	l'evento potrebbe non essere nemmeno generato, oppure dopo.
--

	--	XE Predicates Source Objects
	SELECT
			XP.name AS package_name
	,		XO.name AS event_name
	,		XO.[description] AS event_description
	FROM	sys.dm_xe_packages AS XP
	JOIN	sys.dm_xe_objects AS XO
	  ON	XP.[guid] = XO.package_guid
	WHERE	(XP.capabilities IS NULL OR XP.capabilities & 1 = 0)
	  AND	(XO.capabilities IS NULL OR XO.capabilities & 1 = 0)
	  AND	XO.object_type = N'pred_source';
	GO

	--	XE Predicates Comparison Operators
	SELECT
			XP.name AS package_name
	,		XO.name AS event_name
	,		XO.[description] AS event_description
	FROM	sys.dm_xe_packages AS XP
	JOIN	sys.dm_xe_objects AS XO
	  ON	XP.[guid] = XO.package_guid
	WHERE	(XP.capabilities IS NULL OR XP.capabilities & 1 = 0)
	  AND	(XO.capabilities IS NULL OR XO.capabilities & 1 = 0)
	  AND	XO.object_type = N'pred_compare';
	GO

--
--	Le destinazioni XE sono dove si possono tracciare i dati raccolti quando vengono generati gli eventi.
--
--	Destinazioni SQL Server 2008R2:
--		etw_classic_sync_target		utilizzato per correlare gli eventi con Event Tracing for
--									Windows (ETW) in modalità sincrona
--		synchronous_bucketizer		conta gli eventi raggruppandoli per una proprietà o un azione
--									in modalità sincrona
--		asynchronous_bucketizer		conta gli eventi raggruppandoli per una proprietà o un azione
--									in modalità asincrona
--		asynchronous_file_target	scrive gli eventi su file in modalità asincrona
--		pair_matching				accoppia gli eventi tramite regole di correlazione
--		synchronous_event_counter	conta gli eventi di una sessione in modalità sincrona
--		ring_buffer					buffer circolare FIFO per registrare gli eventi in modalità sincrona
--
--	Destinazioni SQL Server 2012:
--		etw_classic_sync_target		utilizzato per correlare gli eventi con Event Tracing for
--									Windows (ETW) in modalità sincrona
--		histogram					conta gli eventi raggruppandoli per una proprietà o un azione
--									in modalità asincrona
--		event_file					scrive gli eventi su file in modalità asincrona
--		pair_matching				accoppia gli eventi tramite regole di correlazione
--		event_counter				conta gli eventi di una sessione in modalità sincrona
--		ring_buffer					buffer circolare FIFO per registrare gli eventi in modalità sincrona
--

	--	XE Targets
	SELECT
			XP.name AS package_name
	,		XO.name AS target_name
	,		XO.[description] AS target_description
	,		XO.capabilities_desc AS target_capabilities
	FROM	sys.dm_xe_packages AS XP
	JOIN	sys.dm_xe_objects AS XO
	  ON	XP.[guid] = XO.package_guid
	WHERE	(XP.capabilities IS NULL OR XP.capabilities & 1 = 0)
	  AND	(XO.capabilities IS NULL OR XO.capabilities & 1 = 0)
	  AND	XO.object_type = N'target';
	GO

	--	XE Targets Configurable Options
	SELECT
			XP.name AS package_name
	,		XO.name AS target_name
	,		XC.name AS option_name
	,		XC.[type_name] AS option_data_type
	,		XC.[description] AS option_description
	FROM	sys.dm_xe_packages	AS XP
	JOIN	sys.dm_xe_objects	AS XO
	  ON	XP.[guid] = XO.package_guid
	JOIN	sys.dm_xe_object_columns AS XC
	  ON	XO.package_guid = XC.object_package_guid
	 AND	XO.name = XC.[object_name]
	WHERE	(XP.capabilities IS NULL OR XP.capabilities & 1 = 0)
	  AND	(XO.capabilities IS NULL OR XO.capabilities & 1 = 0)
	  AND	(XC.capabilities IS NULL OR XC.capabilities & 1 = 0)
	  AND	XO.object_type = N'target'
	  AND	XO.name IN (N'event_file', N'asynchronous_file_target');
	GO

