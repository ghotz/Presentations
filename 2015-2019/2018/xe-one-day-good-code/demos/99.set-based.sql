-----------------------------------------------------------------------
-- Script:		set-based.sql
-- Copyright:	2010 Davide Mauri
-- License:		
-- Credits:	
------------------------------------------------------------------------

------------------------------------------------------------------------
-- setup oggetti
------------------------------------------------------------------------
use [tempdb]
go

if (object_id('dbo.Posti') is not null) drop table dbo.Posti;
go

create table dbo.posti
(
	id_posto int identity not null constraint pk_posti primary key,
	fila char(1) not null,
	posto smallint not null,
	occupato bit not null
)
go

if (object_id('dbo.fn_Nums') is not null)
	drop function dbo.fn_Nums
go

create function dbo.fn_Nums(@m as bigint) returns table
as
return
	with
	t0 as (select n = 1 union all select n = 1),
	t1 as (select n = 1 from t0 as a, t0 as b),
	t2 as (select n = 1 from t1 as a, t1 as b),
	t3 as (select n = 1 from t2 as a, t2 as b),
	t4 as (select n = 1 from t3 as a, t3 as b),
	t5 as (select n = 1 from t4 as a, t4 as b),
	result as (select row_number() over (order by n) as n from t5)
	select n from result where n <= @m
go

-- mettiamo l'indice giusto
alter table dbo.posti drop constraint pk_posti
go

create clustered index ixc__posti on dbo.posti (fila, posto)
go

alter table dbo.posti add constraint pk_posti primary key nonclustered (id_posto)
go



------------------------------------------------------------------------
-- setup stored procedures
------------------------------------------------------------------------

if (object_id('dbo.stp_riempi_tabella_posti') is not null) drop procedure dbo.stp_riempi_tabella_posti;
go

create procedure dbo.stp_riempi_tabella_posti
@num_posti_per_fila int = 30
as
set nocount on

	truncate table dbo.[Posti];

	-- Riempiamo i posti
	with cte_file as 
	(
	select
		fila = char(n+64)
	from
		dbo.fn_Nums(12) as fila
	),
	cte_posti as
	(	
	select
		posto = n
	from
		dbo.fn_Nums(@num_posti_per_fila) as posto
	)
	insert into
		dbo.[Posti]
	select
		fila, posto, occupato = 0
	from
		[cte_file]
	cross join
		[cte_posti];
		
	update 
		dbo.posti 
	set
		[occupato] = 1
	where
		fila = 'E'
	and
		((posto between 10 and 15) or (posto between 18 and 22) or (posto between 26 and 30) or posto in (2,3));
		
	update 
		dbo.posti 
	set
		[occupato] = 1
	where
		fila = 'F'
	and
		((posto between 3 and 8) or (posto between 11 and 18) or (posto between 20 and 22) or posto in (28,30));
go
 


-- Stored procedure con soluzione set-based
if (object_id('dbo.stp_posti_soluzione_set_based') is not null) drop procedure dbo.stp_posti_soluzione_set_based;
go

create procedure dbo.stp_posti_soluzione_set_based
as
	set nocount on;

	with cte as 
	(
	select
		fila,
		posto,
		numero_riga = row_number() over(partition by fila order by posto),
		raggruppamento = posto - row_number() over(partition by fila order by posto)
	from
		[Posti] as p 
	where 
		occupato = 0
	)
	select
		fila, 
		raggruppamento, 
		da = min(posto),
		a = max(posto),
		totale_posti_vicini = max(posto) - min(posto) + 1
	from
		cte c1
	group by
		fila, raggruppamento
	order by 
		fila
go
	


-- Stored procedure con soluzione con cursore
if (object_id('dbo.stp_posti_soluzione_cursore') is not null) drop procedure dbo.stp_posti_soluzione_cursore;
go

create procedure dbo.stp_posti_soluzione_cursore
as
	set nocount on

	declare @fila char(1)
	declare @fila_prev char(1)
	declare @posto smallint
	declare @posto_prev smallint
	declare @posto_da smallint
	declare @counter smallint

	declare c cursor fast_forward for
	select fila, posto from dbo.posti where occupato = 0 order by fila, posto

	create table #result
	(
		fila char(1),
		da smallint,
		a smallint,
		totale_posti_vicini smallint
	)

	set @counter = 0

	open c
	fetch next from c into @fila, @posto

	set @posto_da = @posto

	while (@@fetch_status = 0)
	begin
		if (@posto_prev is not null)
		begin
		
			if (@posto - @posto_prev = 1) 
			begin 			
				set @counter = @counter + 1
			end else begin
				insert into #result values (@fila, @posto_da, @posto_prev, @counter + 1)
				set @posto_da = @posto
				set @counter = 0
			end
		end

		set @fila_prev = @fila
		set @posto_prev = @posto

		fetch next from c into @fila, @posto
		
		if (@fila_prev <> @fila) begin	
			insert into #result values (@fila_prev, @posto_da, @posto_prev, @counter + 1)
			set @counter = 0		
			set @posto_da = @posto
			set @posto_prev = null
		end
	end

	if (@counter > 0) begin
		insert into #result values (@fila, @posto_da, @posto_prev, @counter + 1)
	end

	close c
	deallocate c

	select * from #result

	drop table #result
go


------------------------------------------------------------------------
-- Performance Benchmark
------------------------------------------------------------------------

-- Attivazione info di benchmark
set nocount on
set statistics io on

--MEMO: Utilizzare il profiler per vedere la somma degli I/O fatti

-- Test con 30 posti per riga
exec dbo.stp_riempi_tabella_posti 30;
exec dbo.stp_posti_soluzione_set_based;
exec dbo.stp_posti_soluzione_cursore;

-- Test con 300 posti per riga
exec dbo.stp_riempi_tabella_posti 300;
exec dbo.stp_posti_soluzione_set_based;
exec dbo.stp_posti_soluzione_cursore;

-- Test con 3000 posti per riga
exec dbo.stp_riempi_tabella_posti 3000;
exec dbo.stp_posti_soluzione_set_based;
exec dbo.stp_posti_soluzione_cursore;

