CREATE TABLE roq.buildings (
	ogc_fid serial4 NOT NULL,
	id varchar NOT NULL,
	buildingpart varchar NULL,
	json_attributes jsonb NULL,
	wkb_geometry public.geometry NULL,
	color varchar NULL,
	CONSTRAINT buildings_pkey PRIMARY KEY (ogc_fid)
);
CREATE INDEX buildings_st_centroid_idx ON roq.buildings USING gist (st_centroid(st_envelope(wkb_geometry)));