------------------------------------------------------------------------
-- Script:		spatial-data.sql
-- Copyright:	2012 Davide Mauri
-- License:		MIT License
-- Credits:		
------------------------------------------------------------------------
use [tempdb]
go

if (db_id('SpatialDemo') is not null) 
begin
	alter database SpatialDemo set single_user with rollback immediate;
	drop database SpatialDemo;
end
go

create database SpatialDemo;
go

alter database SpatialDemo set recovery simple
go

-- Set SQL Server 2008/2008R2 Compatibility
alter database SpatialDemo set compatibility_level = 100
go

use SpatialDemo;
go

------------------------------------------------------------------------
-- spatial data types overview
------------------------------------------------------------------------

-- create a polygon, a point and check if point is contained in the polygon
declare @box as geometry = geometry::STGeomFromText('POLYGON ((0 0, 150 0, 150 150, 0 150, 0 0))', 0);
declare @point as geometry = geometry::STGeomFromText('POINT (100 100)', 0);
select * from ( values (@box), (@point.STBuffer(2)) ) T(c)
select DoesBoxContainsPoint = @box.STContains(@point);
go

-- define a polygon on Earth
declare @home as geography = geography::STGeomFromText('POLYGON ( (9.133184 45.535153, 9.133020 45.535012, 9.133259 45.534903, 9.133339 45.534993, 9.133262 45.535028, 9.133312 45.535090, 9.133184 45.535153) )', 4326);
select Home = @home, HomeLabel = 'Home Sweet Home!';
go

-- using geography you MUST specify points using counter-clockwise order (left-foot rule)
declare @home as geography = geography::STGeomFromText('POLYGON ( (1 30, 1 31, -1 31, -1 30, 1 30) )', 4326);
select @home.ToString(), @home;
go

-- otherwise you will get an error in SQL 2008.
declare @home as geography = geography::STGeomFromText('POLYGON ( (1 30, -1 30, -1 31, 1 31, 1 30) )', 4326)
select @home.ToString(), @home;
go


-- View SRID info
select
	*
from
	sys.spatial_reference_systems
where 
	spatial_reference_id = 4326
go


------------------------------------------------------------------------
-- spatial data instancing
------------------------------------------------------------------------

-- STGeomFromText
declare @box as geometry = geometry::STGeomFromText('POLYGON ((0 0, 150 0, 150 150, 0 150, 0 0))', 0);
select @box.STAsText(), @box;
go

-- Casting
declare @box2 as geometry = cast('POLYGON ((0 0, 150 0, 150 150, 0 150, 0 0))' as geometry);
select @box2.STAsText(), @box2;

-- STGeomFromWKB (Well-Known Binary Format)
declare @line as geometry = geometry::STGeomFromWKB(0x010200000003000000000000000000594000000000000059400000000000003440000000000080664000000000008066400000000000806640, 0);
select @line.STAsText(), @line;

-- GeomFromGML
declare @gml as xml = '<Polygon xmlns="http://www.opengis.net/gml">
  <exterior>
    <LinearRing>
      <posList>0 0 150 0 150 150 0 150 0 0</posList>
    </LinearRing>
  </exterior>
</Polygon>'
declare @box as geometry = geometry::GeomFromGml(@gml, 0)
select @box.STAsText(), @box;
go

-- Define a frame
declare @frame as geometry = geometry::STPolyFromText('POLYGON ( (0 0, 10 0, 10 10, 0 10, 0 0), (2 2, 8 2, 8 8, 2 8, 2 2) )', 0)
select @frame;
go

-- Test that is really a frame :-)
declare @frame as geometry = geometry::STPolyFromText('POLYGON ( (0 0, 10 0, 10 10, 0 10, 0 0), (2 2, 8 2, 8 8, 2 8, 2 2) )', 0)
declare @pin as geometry = geometry::STPointFromText('POINT (1 1)', 0)
declare @pout as geometry = geometry::STPointFromText('POINT (3 3)', 0)
select * from ( values ('Frame', @frame), ('In', @pin.STBuffer(0.5)), ('Out', @pout.STBuffer(0.5)) ) T(Label, Shape)
select  
	DoesFrameContainsPIn = @frame.STContains(@pin), 
	DoesFrameContainsPOut = @frame.STContains(@pout)
go



------------------------------------------------------------------------
-- spatial data methods
------------------------------------------------------------------------

-- Buffer
declare @t geometry;
set @t = geometry::STGeomFromText('LINESTRING (104 312, 104 308, 102 306, 102 302, 100 296, 102 292, 104 286, 104 282, 104 276, 104 272, 98 256, 100 252, 104 248, 104 244, 108 238, 110 236, 116 232, 118 230, 120 228, 124 226, 132 224, 136 224, 140 224, 146 224, 156 224, 158 224, 168 224, 176 228, 184 228, 190 230, 198 232, 204 232, 208 236, 216 240, 220 240, 228 244, 232 244, 240 246, 244 246, 254 240, 260 238, 268 232, 270 228, 272 220, 274 214, 272 208, 272 198, 274 188, 274 180, 280 166, 288 156, 292 152, 304 144, 318 140, 326 138, 346 136, 352 136, 360 140, 372 140, 376 142, 388 144, 390 144)', 0);
select @t union all
select @t.STBuffer(10)
go

-- STWithin
DECLARE @g geometry;
DECLARE @h geometry;
SET @g = geometry::STGeomFromText('POLYGON((0 0, 10 0, 10 10, 0 10, 0 0))', 0);
SET @h = geometry::STGeomFromText('POLYGON((1 1, 3 1, 3 3, 1 3, 1 1))', 0);
SELECT P1 = @g union all
SELECT P2 = @h
SELECT P2WithinP1 = @h.STWithin(@g);
go

-- STIntersect
DECLARE @g geometry;
DECLARE @h geometry;
SET @g = geometry::STGeomFromText('LINESTRING(0 20, 20 0, 40 20)', 0);
SET @h = geometry::STGeomFromText('LINESTRING(0 0, 20 20, 40 0)', 0);
SELECT Line1 = @g.STBuffer(1) union all
SELECT Line2 = @h.STBuffer(1)
select STIntersect = @g.STIntersects(@h);
go


-- Area
declare @t geometry;
set @t = geometry::STGeomFromText('POLYGON((0 0, 2 0, 2 3, 0 0))', 0);
select Box = @t, Area = @t.STArea()
go


-- STIntersection
DECLARE @g geometry;
DECLARE @h geometry;
SET @g = geometry::STGeomFromText('POLYGON((0 0, 0 2, 2 2, 2 0, 0 0))', 0);
SET @h = geometry::STGeomFromText('POLYGON((1 1, 3 1, 3 3, 1 3, 1 1))', 0);
SELECT P1 = @g, Label = 'P1' union all
SELECT P2 = @h, Label = 'P2' union all
SELECT I = @g.STIntersection(@h), Label = 'I'
SELECT @g.STIntersection(@h).ToString();
go

-- STUnion
DECLARE @g geometry = geometry::STGeomFromText('POLYGON((0 0, 0 2, 2 2, 2 0, 0 0))', 0);
DECLARE @h geometry = geometry::STGeomFromText('POLYGON((1 1, 3 1, 3 3, 1 3, 1 1))', 0);
SELECT * FROM ( VALUES (@g, 'G'), (@h, 'H') ) AS t ( Geom, Label );
SELECT @g.STUnion(@h)
SELECT @g.STUnion(@h).ToString();
go

-- STDistance on geograhpy
DECLARE @g geography;
DECLARE @h geography;
SET @g = geography::STGeomFromText('LINESTRING(-122.360 47.656, -122.343 47.656)', 4326);
SET @h = geography::STGeomFromText('POINT(-122.34900 47.65100)', 4326);
SELECT @g.STDistance(@h);
go

------------------------------------------------------------------------
-- Use ShapeFile uploaded data
------------------------------------------------------------------------
create table [dbo].[italy_map](
	[id] [int] identity(1,1) not null primary key,
	[regione] [nvarchar](255) not null,
	[provincia] [nvarchar](255) not null,
	[shape] [geography] not null
)
go

--truncate table [dbo].[italy_map] 
--go

-- Provincie
bulk insert [SpatialDemo].dbo.[italy_map] FROM 'C:\Users\gianl\OneDrive\Documents\Presentations\UGISS\20180420 XE Dot Net\Demos\Data\ItalyMap.raw' with (datafiletype = 'native')
go

select * from dbo.italy_map where regione = 'Lombardia'
go
