------------------------------------------------------------------------
--	Description:	Verify that connectivity is using Kerberos
------------------------------------------------------------------------
--	Copyright (c) 2015 Gianluca Hotz
--	Permission is hereby granted, free of charge, to any person
--	obtaining a copy of this software and associated documentation files
--	(the "Software"), to deal in the Software without restriction,
--	including without limitation the rights to use, copy, modify, merge,
--	publish, distribute, sublicense, and/or sell copies of the Software,
--	and to permit persons to whom the Software is furnished to do so,
--	subject to the following conditions:
--	The above copyright notice and this permission notice shall be
--	included in all copies or substantial portions of the Software.
--	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
--	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
--	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
--	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
--	BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
--	ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
--	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--	SOFTWARE.
------------------------------------------------------------------------
SELECT	session_id, net_transport, protocol_type, auth_scheme
FROM	sys.dm_exec_connections
WHERE	session_id = @@spid;
GO

--	If authentication scheme is NTLM, Kerberos is not working
--	There are may articles describing all pre-requisites to make
--	Kerberos authentication work.
--
--	One quick check is to see if SQL Server instance's SPN (Service
--	Principal Name) has been setup correctly, this can be done
--	automatically by SQL Server when the instance starts if the user
--	assigned to the service has the appropriate permissions.

--	Verify SPN configuration in ERRORLOG
EXEC master.sys.xp_readerrorlog 0, 1, N'SPN';
GO

--	Reference article to grant permissions:
--	https://support.microsoft.com/en-us/kb/319723

--	If the user can't be granted to proper permission, the SPN stil needs
--	to be created manually using SETSPN.EXE command-line tool following
--	the guidelines in Books Online:
--	https://msdn.microsoft.com/en-us/library/ms191153.aspx

--	Microsoft published also a tool called "Microsoft Kerberos
--	Configuration Manager for SQL Server" that is able to troubleshoot
--	most misconfiguration scenarios not only for the SQL Server engine
--	but also for Analysis Services and Reporting Services.
-- 
--	The tool can be downloaded at the following link:
--	http://www.microsoft.com/en-us/download/details.aspx?id=39046&751be11f-ede8-5a0c-058c-2ee190a24fa6=True
