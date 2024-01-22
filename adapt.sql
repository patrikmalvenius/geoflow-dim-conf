ALTER TABLE lod22_3d ADD COLUMN geom_triangle geometry;
ALTER TABLE lod22_3d ADD COLUMN style json;
ALTER TABLE lod22_3d ADD COLUMN shaders json;
--update lod22_3d set geom_triangle = ST_Tesselate(wkb_geometry);
update lod22_3d set geom_triangle = st_transform(wkb_geometry, 4326);
UPDATE lod22_3d  SET style = ('{ "walls": "#EEC900", "roof":"#FF0000", "floor":"#008000"}');
update lod22_3d set shaders = '{
  "PbrMetallicRoughness": {
    "MetallicRoughness": [
      "#000000",
      "#000000",
      "#000000",
      "#000000",
      "#000000",
      "#000000",
      "#000000",
      "#000000",
      "#000000",
      "#000000",
      "#000000",
      "#000000"
    ],
    "BaseColors": [
      "#008000",
      "#008000",
      "#FF0000",
      "#FF0000",
      "#EEC900",
      "#EEC900",
      "#EEC900",
      "#EEC900",
      "#EEC900",
      "#EEC900",
      "#EEC900",
      "#EEC900"
    ]
  }
}';


CREATE INDEX ON lod22_3d USING gist(st_centroid(st_envelope(geom_triangle)));
