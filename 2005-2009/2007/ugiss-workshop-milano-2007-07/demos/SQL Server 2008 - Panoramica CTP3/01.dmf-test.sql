------------------------------------------------------------------------
-- Script:			01.dmf-test.sql
-- Author:			Gianluca Hotz (Solid Quality Learning)
-- Copyright:		Attribution-NonCommercial-ShareAlike 2.5
-- Version:			SQL Server 2008 CTP3
-- Tab/indent size:	4
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Cambiamo contesto
-- Nota: ricordarsi di creare il database e sottoscrivere la policy
------------------------------------------------------------------------
USE Finance
GO

------------------------------------------------------------------------
-- Proviamo a creare una tabella con un nome non conforme
------------------------------------------------------------------------
CREATE TABLE dbo.PaeseISO (
	CodiceISOPaese	char(2)
,	NomePaese		varchar(255)
,	CONSTRAINT	pkPaeseISO
	PRIMARY KEY	(CodiceISOPaese)
)
GO

------------------------------------------------------------------------
-- Proviamo ora a crearla con un nome conforme
------------------------------------------------------------------------
CREATE TABLE dbo.fintblPaeseISO (
	CodiceISOPaese	char(2)
,	NomePaese		varchar(255)
,	CONSTRAINT	pkPaeseISO
	PRIMARY KEY	(CodiceISOPaese)
)
GO

