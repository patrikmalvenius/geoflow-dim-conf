--récuperer la géométrie de bâtiment entier

with arra as 	(select	object_id,				array(
							select jsonb_array_elements_text(
								jsonb_array_elements(
									(geometry -> -1 -> 'boundaries' -> -1 )
								)
							)
						) as arr from cjdb.city_object co where type = 'Building')
						
select co.object_id, ST_GeomFromText('POLYGONZ(('||replace(
	replace(
		replace(
			replace(				
		array_to_string(
					array_append(
		arr, arr[1]
						), ',') ::text, ',', ''), '][', ','), '[', ''), ']', '')||'))',2154)  as lod22 from cjdb.city_object co, arra where type = 'Building' and co.object_id = arra.object_id group by co.object_id, arra.arr 
						
						
--récuperer la géométrie de bâtiment entier, update colonne geombuilding -- par contre je crois que c'est possible que j'ai raté des parties des géometries ici :(					
update city_object set geombuilding = (with arra as 	(select	object_id,				array(
							select jsonb_array_elements_text(
								jsonb_array_elements(
									(geometry -> -1 -> 'boundaries' -> -1 )
								)
							)
						) as arr from cjdb.city_object co where type = 'Building'), geom as (
						
select  co.object_id as id, ST_GeomFromText('POLYGONZ(('||replace(
	replace(
		replace(
			replace(				
		array_to_string(
					array_append(
		arr, arr[1]
						), ',') ::text, ',', ''), '][', ','), '[', ''), ']', '')||'))',2154)  as lod22 from cjdb.city_object co, arra where type = 'Building' and co.object_id = arra.object_id group by co.object_id, arra.arr ) select lod22 from geom where geom.id = object_id  )where type = 'Building'
						
--récuperer la géométrie de partie de bâtiment

with bomb as (select object_id, 
	unnest(array(select jsonb_array_elements(geometry -> -1 -> 'boundaries' -> -1   ))	) as exploded
	from cjdb.city_object co where type = 'BuildingPart'), dynamite as(
							
select bomb.object_id, bomb.exploded[0]||jsonb_build_array(bomb.exploded[0][0]) as magic from bomb)
select object_id,   ST_GeomFromText('MULTIPOLYGONZ('||replace(replace(replace(replace(replace(array_to_string(array_agg( magic), ':'), ',',''), ']]:[[', ')),(('), '] [', ','), '[[', '(('), ']]','))')||')',2154) from dynamite  group by object_id
						
						
--récuperer la géométrie de partie de bâtiment, update colonne geombuilding					
update city_object set geombuilding = (with bomb as (select object_id, 
	unnest(array(select jsonb_array_elements(geometry -> -1 -> 'boundaries' -> -1   ))	) as exploded
	from cjdb.city_object co where type = 'BuildingPart'), dynamite as(
							
select bomb.object_id, bomb.exploded[0]||jsonb_build_array(bomb.exploded[0][0]) as magic from bomb), geom as
(select object_id,   ST_GeomFromText('MULTIPOLYGONZ('||replace(replace(replace(replace(replace(array_to_string(array_agg( magic), ':'), ',',''), ']]:[[', ')),(('), '] [', ','), '[[', '(('), ']]','))')||')',2154) as lod22 from dynamite group by object_id) select lod22 from  geom where  city_object.object_id = geom.object_id  )where type = 'BuildingPart';

-- extraction de géometrie par semantic (2=toit)

with bomb as (select object_id, 
	unnest(array(select jsonb_array_elements(geometry -> -1 -> 'boundaries' ->-1  ))) as exploded,
unnest(array(select jsonb_array_elements(geometry -> -1 -> 'semantics' -> 'values'->-1))) as sem
	from cjdb.city_object co where type = 'BuildingPart'), dynamite as(
							
select bomb.object_id, bomb.exploded[0]||jsonb_build_array(bomb.exploded[0][0]) as magic from bomb where sem = '1')
select object_id,   ST_GeomFromText('MULTIPOLYGONZ('||replace(replace(replace(replace(replace(array_to_string(array_agg( magic), ':'), ',',''), ']]:[[', ')),(('), '] [', ','), '[[', '(('), ']]','))')||')',2154) from dynamite  group by object_id

-- extraction + update de géometrie par semantic (2=toit)
update city_object set geombuilding = (with bomb as (select object_id, 
	unnest(array(select jsonb_array_elements(geometry -> -1 -> 'boundaries' ->-1  ))) as exploded,
unnest(array(select jsonb_array_elements(geometry -> -1 -> 'semantics' -> 'values'->-1))) as sem
	from cjdb.city_object co where type = 'BuildingPart'), dynamite as(
							
select bomb.object_id, bomb.exploded[0]||jsonb_build_array(bomb.exploded[0][0]) as magic from bomb where sem = '1'), geom as
(select object_id,   ST_GeomFromText('MULTIPOLYGONZ('||replace(replace(replace(replace(replace(array_to_string(array_agg( magic), ':'), ',',''), ']]:[[', ')),(('), '] [', ','), '[[', '(('), ']]','))')||')',2154)
 as lod22 from dynamite group by object_id) select lod22 from  geom where  city_object.object_id = geom.object_id  )where type = 'BuildingPart';

-- insertion de données dans table cible buildings
-- toitures
with bomb as (select object_id, 
	unnest(array(select jsonb_array_elements(geometry -> -1 -> 'boundaries' ->-1  ))) as exploded,
unnest(array(select jsonb_array_elements(geometry -> -1 -> 'semantics' -> 'values'->-1))) as sem
	from cjdb.city_object co where type = 'BuildingPart'), 
dynamite as (select bomb.object_id, bomb.exploded[0]||jsonb_build_array(bomb.exploded[0][0]) as magic from bomb where sem = '1'), 
geom as (select object_id,   ST_GeomFromText('MULTIPOLYGONZ('||replace(replace(replace(replace(replace(array_to_string(array_agg( magic), ':'), ',',''), ']]:[[', ')),(('), '] [', ','), '[[', '(('), ']]','))')||')',2154)
 as lod22 from dynamite group by object_id), 
toot as (select lod22, geom.object_id, city_object.attributes from geom, city_object where  city_object.object_id = geom.object_id)
INSERT INTO buildings(id, buildingpart, json_attributes, wkb_geometry) select toot.object_id, 'roof', toot.attributes, toot.lod22 from toot;

--sol
with bomb as (select object_id, 
	unnest(array(select jsonb_array_elements(geometry -> -1 -> 'boundaries' ->-1  ))) as exploded,
unnest(array(select jsonb_array_elements(geometry -> -1 -> 'semantics' -> 'values'->-1))) as sem
	from cjdb.city_object co where type = 'BuildingPart'), 
dynamite as (select bomb.object_id, bomb.exploded[0]||jsonb_build_array(bomb.exploded[0][0]) as magic from bomb where sem = '0'), 
geom as (select object_id,   ST_GeomFromText('MULTIPOLYGONZ('||replace(replace(replace(replace(replace(array_to_string(array_agg( magic), ':'), ',',''), ']]:[[', ')),(('), '] [', ','), '[[', '(('), ']]','))')||')',2154)
 as lod22 from dynamite group by object_id), 
toot as (select lod22, geom.object_id, city_object.attributes from geom, city_object where  city_object.object_id = geom.object_id)
INSERT INTO buildings(id, buildingpart, json_attributes, wkb_geometry) select toot.object_id, 'floor', toot.attributes, toot.lod22 from toot;

--murs
with bomb as (select object_id, 
	unnest(array(select jsonb_array_elements(geometry -> -1 -> 'boundaries' ->-1  ))) as exploded,
unnest(array(select jsonb_array_elements(geometry -> -1 -> 'semantics' -> 'values'->-1))) as sem
	from cjdb.city_object co where type = 'BuildingPart'), 
dynamite as (select bomb.object_id, bomb.exploded[0]||jsonb_build_array(bomb.exploded[0][0]) as magic from bomb where sem = '2' or sem = '3'), 
geom as (select object_id,   ST_GeomFromText('MULTIPOLYGONZ('||replace(replace(replace(replace(replace(array_to_string(array_agg( magic), ':'), ',',''), ']]:[[', ')),(('), '] [', ','), '[[', '(('), ']]','))')||')',2154)
 as lod22 from dynamite group by object_id), 
toot as (select lod22, geom.object_id, city_object.attributes from geom, city_object where  city_object.object_id = geom.object_id)
INSERT INTO buildings(id, buildingpart, json_attributes, wkb_geometry) select toot.object_id, 'wall', toot.attributes, toot.lod22 from toot;