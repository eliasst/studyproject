--Create table buildings_pop_census 
create table buildings_pop_census as
select gid, ags, zensus_b_2, bez_krs, a.geom from erding_freising_zensusgrid_2011_srid4326 a, study_area_union b
where st_intersects(a.geom,b.geom);

--Rename column zensus_b_2 in buildings_pop_census to census_pop
alter table buildings_pop_census rename column zensus_b_2 to census_pop;

--Add column dis_pop for post comparison
alter table buildings_pop_census add column dis_pop integer;

--Create index on the census table
create index index_buildings_pop_census ON buildings_pop_census USING GIST (geom);

--Intersect census data with disaggregation data to afterwards check in exported CSV
select b.gid,sum(a.population_building_new) as dis_pop 
into buildings_pop_census_2
from buildings_pop_dis a, buildings_pop_census b
where st_intersects(b.geom,a.building_centroid)
group by b.gid;

select a.gid, b.dis_pop, a.census_pop, geom
into buildings_pop_comparison
from buildings_pop_census a, buildings_pop_census_2 b 
where a.gid = b.gid;

update buildings_pop_comparison
set census_pop=census_pop*0
where census_pop < 0;

--All 100m grids receive a point as geometrical centroid
alter table buildings_pop_census add column grid_centroid geometry;
update buildings_pop_census set grid_centroid = st_centroid(geom);

--Create tables population_census and population_dis
select grid_centroid as geom, census_pop as population, gid
into population_census
from buildings_pop_census;

update population_census
set population=population*0
where population < 0;

alter table population_census add primary key(gid);

select building_centroid as geom, population_building_new as population
into population_dis
from buildings_pop_dis;

alter table population_dis add column gid serial;

alter table population_dis add primary key(gid);

--Add column diff for QGis Analysis
alter table buildings_pop_comparison add column diff integer;

update buildings_pop_comparison 
set diff = census_pop-dis_pop;

update buildings_pop_comparison
set diff=diff * (-1) where diff < 0;

--Add column diff_minus for normal distribution
alter table buildings_pop_comparison add column diff_minus integer;

update buildings_pop_comparison 
set diff_minus = census_pop-dis_pop;