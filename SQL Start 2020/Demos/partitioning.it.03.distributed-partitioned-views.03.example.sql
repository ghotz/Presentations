------------------------------------------------------------------------
-- Copyright:   2018 Gianluca Hotz
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
--              
--              The above copyright notice and this permission notice
--              shall be included in all copies or substantial portions
--              of the Software.
--              
--              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
--              ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
--              LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
--              FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
--              EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
--              FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
--              AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--              OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
--              OTHER DEALINGS IN THE SOFTWARE.
-- Synopsis:    Lo scopo di questo script e' di dimostrare il partizionamento
--              orizzontale dei dati tramite viste partizionate distribuite e la
-- 				trasparenza di queste rispetto alle applicazioni.
--              
-- 				I database utilizzati devono essere generati tramite gli script:
--				partitioning.it.03.distributed-partitioned-views.01.setup-node1
--				partitioning.it.03.distributed-partitioned-views.02.setup-node2
-- Credits:     
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Cambiamo contesto.
------------------------------------------------------------------------
USE SalesDBDPV;
GO

------------------------------------------------------------------------
-- Per effettuare le transazioni distribuite della dimostrazione, il
-- Distributed Transaction Coordinator (MSDTC) deve essere attivo su
-- tutte le macchine che ospitano le istanze coinvolte nella
-- transazione e deve essere configurato per accettare transazioni
-- remote tramite Component Services e aprendo le relative porte sui
-- Firewall
--
-- Dobbiamo inoltre impostare questo parametro a livello di connessione
-- (vedere BOL per maggiori dettagli).
------------------------------------------------------------------------
SET XACT_ABORT ON;
GO

------------------------------------------------------------------------
-- Per quanto riguarda la trasparenza per le applicazioni, le
-- considerazioni sono simili a quelle fatte per le viste locali
-- partizionate.
--
-- Se vogliamo inserire dati attraverso la vista possiamo farlo solo
-- specificando tutti i dati.
------------------------------------------------------------------------
INSERT	dbo.Orders
		(OrderID, CustomerID, EmployeeID, ShipperID, OrderDate, Filler)
VALUES	(1000001, 'C0000003213', 384, 'I', '20061222', 'a');
GO

------------------------------------------------------------------------
-- Possiamo tranquillamente eliminare i dati dalla vista.
------------------------------------------------------------------------
DELETE	dbo.Orders
WHERE	OrderID = 1000001;
GO

------------------------------------------------------------------------
-- Verifichiamo le prestazioni attivando la visualizzazione del piano
-- di esecuzione.
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Se selezioniamo gli ordini ad una particolare data...
------------------------------------------------------------------------
SELECT	*
FROM	dbo.Orders AS O1
WHERE	O1.OrderDate = '20031004';
GO

------------------------------------------------------------------------
-- ... il piano di esecuzione prevede l'accesso solo alla tabella
-- dbo.Orders2003, ha eliminato cioe' l'accesso alle altre tabelle.
--
-- Lo stesso dicasi se proviamo a selezionare i dati specificando
-- un'altra data che si riferisce a dati in un'altra partizione.
--
-- In questo caso, pero', notiamo che si tratta di una query remota.
------------------------------------------------------------------------
SELECT	*
FROM	dbo.Orders AS O1
WHERE	O1.OrderDate = '20040112';
GO

------------------------------------------------------------------------
-- In questo caso, invece, selezioniamo dati che risiedono in piu'
-- partizioni e notiamo che l'accesso avviene effettivamente nei
-- confronti di piu' tabelle.
------------------------------------------------------------------------
SELECT	*
FROM	dbo.Orders AS O1
WHERE	O1.OrderDate BETWEEN '20031201' AND '20040131';
GO

------------------------------------------------------------------------
-- In entrambi i casi precedenti possiamo notare che il predicato e'
-- stato utilizzato direttamente nella query remota, mentre se
-- utilizziamo una funzione, all'interno del predicato, questa e'
-- valutata localmente.
------------------------------------------------------------------------
SELECT	*
FROM	dbo.Orders AS O1
WHERE	YEAR(O1.OrderDate) = 2004
  AND	MONTH(O1.OrderDate) = 7;
GO

------------------------------------------------------------------------
-- Anche in questo caso possiamo trasformare la query in modo che
-- utilizzi l'operatore between.
------------------------------------------------------------------------
SELECT	*
FROM	dbo.Orders AS O1
WHERE	O1.OrderDate BETWEEN '20040701' AND '20040731';
GO

