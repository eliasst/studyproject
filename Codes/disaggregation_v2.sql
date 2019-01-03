

--Create table buildings_pop_dis
create table buildings_pop_dis as
select osm_id, tags, area, area_administrative_boundary, sum_buildings_area, sum_population, geom from buildings_residential;

--Create separate table with building levels
select x.tags -> 'building:levels' as building_levels, x.tags -> 'roof:levels' as roof_levels, x.osm_id as osm_id
into buildings_levels
from planet_osm_polygon x, buildings_residential b
where x.osm_id = b.osm_id;

--Add column 'levels' to buildings_pop_dis
alter table buildings_pop_dis add column building_levels integer;
update buildings_pop_dis
set building_levels = buildings_levels.building_levels::integer
from buildings_levels
where buildings_levels.osm_id=buildings_pop_dis.osm_id;

--Drop table buildings_levels
drop table buildings_levels;

--Drop rows where building are is over 500 sqm in municipalities except Freising, Neufahrn and Hallbergmoos
alter table buildings_pop_dis add column gid serial;
alter table buildings_pop_dis add column municipality varchar(60);

with x as (
	select distinct a.gid, b.bez_gem
	from buildings_pop_dis a, study_area b
	where st_intersects(a.geom,b.geom))
update buildings_pop_dis  
set municipality = x.bez_gem
from x
where buildings_pop_dis.gid = x.gid;

delete from buildings_pop_dis 
where area > 500
and municipality in ('Kirchdorf a.d.Amper','Kranzberg','Langenbach','Marzling','Berglern','Eitting','Paunzhausen','Wolfersdorf','Zolling','Allershausen',
'Attenkirchen','Fahrenzhausen','Langenpreising','Haag a.d.Amper','Oberding','Hohenkammern');

--2 building levels and 1 roof level are applied to all buildings which have an area between 55 and 150 sqm
update buildings_levels
set building_levels = 2, roof_levels = 1
where building_levels is null
and area between 55 and 150;

--Delete ground floor level, when POIs are indicated
with x as (
    select distinct b.gid
    from buildings_pop_dis b, pois p 
    where st_intersects(b.geom,p.geom)
)
update buildings_pop_dis 
set building_levels = building_levels - 1
from x
where buildings_pop_dis.gid = x.gid;

--Calculate new area 'area_levels' for buildings with more than one level indicated
alter table buildings_pop_dis add column area_levels float;
update buildings_pop_dis set area_levels=(area*building_levels::integer)
where building_levels is not null;

--Get building area in new column area_levels when it is 'Null'
update buildings_pop_dis
set area_levels = case
when area_levels is null then area
else area_levels
end;

--Create index on buildings_pop_dis
create index index_buildings_pop_dis ON buildings_pop_dis USING GIST (geom);

--All buildings receive a point as gemetrical centroid
alter table buildings_pop_dis add column building_centroid geometry;
update buildings_pop_dis set building_centroid = st_centroid(geom);

--Alter table buildings_pop_dis for new population calculation
alter table buildings_pop_dis add column population_building_new integer;
with x as (
    select m.gid,sum(b.area_levels) as sum_buildings_area_levels from buildings_pop_dis b, study_area m
    where st_intersects(b.geom,m.geom) group by m.gid
    )
update buildings_pop_dis
set population_building_new = round(m.sum_pop*(buildings_pop_dis.area_levels/x.sum_buildings_area_levels))
from study_area m,x
where st_intersects(buildings_pop_dis.geom,m.geom)
and x.gid=m.gid;