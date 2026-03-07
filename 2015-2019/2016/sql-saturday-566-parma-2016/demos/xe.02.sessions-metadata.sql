------------------------------------------------------------------------
--	Script:			xe.02.sessions-metadata.sql
--	Description:	Introduction to Extended Events (XE) session metadata
--	Author:			Gianluca Hotz (SolidQ)
--	Copyright:		Attribution-NonCommercial-ShareAlike 3.0
------------------------------------------------------------------------

--
--	Parte del codice e' basato su serie di 31 articoli di Jonathan Kehayias
--	http://sqlblog.com/blogs/jonathan_kehayias/archive/2010/12/01/a-xevent-a-day-31-days-of-extended-events.aspx

--
--	La definizione di tutti gli elementi delle sessioni definite si trovano in
--		sys.server_event_sessions
--		sys.server_event_session_events
--		sys.server_event_session_actions
--		sys.server_event_session_targets
--		sys.server_event_session_fields
--
	-- Informazioni sulla sessione
	SELECT	XS.*
	FROM	sys.server_event_sessions AS XS
	WHERE	XS.name = N'system_health';
	GO

	-- Informazioni sugli eventi di una sessione
	SELECT	XS.name AS session_name
	,		XE.package AS event_package
	,		XE.name AS event_name
	,		XE.predicate AS event_predicate
	FROM	sys.server_event_sessions AS XS
	JOIN	sys.server_event_session_events AS XE
	  ON	XS.event_session_id = XE.event_session_id
	WHERE	XS.name = N'system_health';
	GO

	-- Informazioni sulle azioni di una sessione
	SELECT	XS.name AS session_name
	,		XE.package AS event_package
	,		XE.name AS event_name
	,		XE.predicate AS event_predicate
	,		XA.package AS action_package
	,		XA.name AS action_name
	FROM	sys.server_event_sessions AS XS
	JOIN	sys.server_event_session_events AS XE
	  ON	XS.event_session_id = XE.event_session_id
	JOIN	sys.server_event_session_actions AS XA
	  ON	XE.event_session_id = XA.event_session_id
	 AND	XE.event_id = XA.event_id
	WHERE	XS.name = N'system_health';
	GO

	-- Informazioni sulle destinazioni di una sessione
	SELECT	XS.name AS session_name
	,		XT.package AS target_package
	,		XT.name AS target_name
	FROM	sys.server_event_sessions AS XS
	JOIN	sys.server_event_session_targets AS XT
	  ON	XS.event_session_id = XT.event_session_id
	WHERE	XS.name = N'system_health';
	GO

	-- Informazioni sulle proprieta' delle destinazioni di una sessione
	SELECT	XS.name AS session_name
	,		XT.package AS target_package
	,		XT.name AS target_name
	,		XF.name AS target_option_name
	,		XF.value AS target_option_value
	FROM	sys.server_event_sessions AS XS
	JOIN	sys.server_event_session_targets AS XT
	  ON	XS.event_session_id = XT.event_session_id
	JOIN	sys.server_event_session_fields AS XF
	  ON	XT.event_session_id = XF.event_session_id
	 AND	XT.target_id = XF.[object_id]
	WHERE	XS.name = N'system_health';
	GO

--
--	La definizione di tutti gli elementi delle sessioni in esecuzione si trovano in
--		sys.dm_xe_sessions
--		sys.dm_xe_session_targets
--		sys.dm_xe_session_events
--		sys.dm_xe_session_event_actions
--		sys.dm_xe_session_object_columns

	-- Informazioni sulla sessione in esecuzione
	SELECT	XS.*
	FROM	sys.dm_xe_sessions AS XS
	WHERE	XS.name = N'system_health';
	GO

	-- Informazioni sul target della sessione in esecuzione
	SELECT	XS.name AS session_name
	,		XT.target_name
	,		XT.execution_count
	,		XT.execution_duration_ms
	,		CAST(XT.target_data AS xml) AS target_data
	FROM	sys.dm_xe_sessions AS XS
	JOIN	sys.dm_xe_session_targets AS XT
	  ON	XS.[address] = XT.event_session_address
	WHERE	XS.name = N'system_health';
	GO

	-- Informazioni sugli eventi della sessione in esecuzione
	SELECT	XS.name AS session_name
	,		XE.event_name
	,		CAST(XE.event_predicate AS xml) AS event_predicate
	FROM	sys.dm_xe_sessions AS XS
	JOIN	sys.dm_xe_session_events AS XE
	  ON	XS.[address] = XE.event_session_address
	WHERE	XS.name = N'system_health';
	GO

	-- Informazioni sulle azioni degli eventi della sessione in esecuzione
	SELECT	XS.name AS session_name
	,		XE.event_name
	,		CAST(XE.event_predicate AS xml) AS event_predicate
	,		XA.action_name
	FROM	sys.dm_xe_sessions AS XS
	JOIN	sys.dm_xe_session_events AS XE
	  ON	XS.[address] = XE.event_session_address
	JOIN	sys.dm_xe_session_event_actions AS XA
	  ON	XE.event_session_address = XA.event_session_address
	 AND	XE.event_name = XA.event_name
	WHERE	XS.name = N'system_health';
	GO

	-- Informazioni sulle colonne del target della sessione in esecuzione
	SELECT	XS.name AS session_name
	,		XT.target_name
	,		XE.event_name
	,		XC.column_name
	,		XC.column_value
	,		XC.object_type
	,		XC.[object_name]
	FROM	sys.dm_xe_sessions AS XS
	JOIN	sys.dm_xe_session_targets AS XT
	  ON	XS.[address] = XT.event_session_address
	JOIN	sys.dm_xe_session_events AS XE
	  ON	XS.[address] = XE.event_session_address
	JOIN	sys.dm_xe_session_object_columns AS XC
	  ON	XS.[address] = XC.event_session_address
	WHERE	XS.name = N'system_health'
	  AND	(
				(XC.object_type = 'target' AND XT.target_name = XC.[object_name]) 
			OR	(XC.object_type = 'event' AND XE.event_name = XC.[object_name])
			)
	GO