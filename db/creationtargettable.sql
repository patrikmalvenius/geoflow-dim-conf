CREATE TABLE cjdb4.buildings (
	ogc_fid serial4 PRIMARY KEY,
	id varchar NOT NULL,
    buildingpart varchar,
	json_attributes jsonb NULL,
	wkb_geometry public.geometry NULL

);