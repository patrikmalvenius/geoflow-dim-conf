#with original setup (if your'e happy with your run.py)
# also need to change some stuff in the dockerfile maybe 
#unsurprisingly i failed to take notes of what mayhem i was wreaking there

docker compose run geoflow  -c /config/config.toml --keep-tmp-data --only-reconstruct -l DEBUG   
docker compose run geoflow  -c /config/config.toml --keep-tmp-data  -l DEBUG 

#if you let the container servie live you can init the geoflow stuff from the containers terminal
#make sure you activate the venv first
. /dim_pipeline/roofenv/bin/activate
python /dim_pipeline/run.py -c /config/config.toml --keep-tmp-data  -l DEBUG
python /dim_pipeline/run.py -c /config/config.toml --keep-tmp-data  --only-reconstruct -l DEBUG

cjio --suppress_msg tile.city.json export jsonl tile.city.jsonl 
cjdb import -H pgdb_upd -U magic -d magic -s cjdb  -f tile.city.jsonl

docker run -v D:\docker\dockers\geoflow-dim-conf\output:/data  3dgi/tyler:0 tyler --metadata data/tile.city.json --features data/features --output data/3dtiles --3dtiles-metadata-class building --object-type Building --object-type BuildingPart

docker run  -e RUST_LOG=debug -e PROJ_DATA=/usr/local/share/proj -e TYLER_RESOURCES_DIR=/data/tyler -v D:\docker\dockers\geoflow-dim-conf\output:/data   3dgi/tyler:0 tyler  --metadata data/tile.city.json --features data/features --output data/3dtiles  --3dtiles-metadata-class building --object-type Building --object-type BuildingPart     --object-attribute identificatie:string 



"PG:dbname=magic active_schema=public user=magic port=5432 host=pgdb_upd password=magic"

FOR DOCKER RUN

docker run  \
  -v ./config:/config \
  -v ./example_data/10_268_594/bag:/data/poly \
  -v ./example_data/10_268_594/true-ortho:/data/img \
  -v ./example_data/10_268_594/laz/2020_dim:/data/laz/2020_dim \
  -v ./example_data/10_268_594/laz/ahn3:/data/laz/ahn3 \
  -v ./example_data/10_268_594/laz/ahn4:/data/laz/ahn4 \
  -v ./tmp:/tmp \
  -v ./output:/data/output \
-e PG_OUTPUT="PG:dbname=gfoutput active_schema=public user=<pg_username> port=<pg_port> host=<pg_host> password=<password>" \
  geoflow-dim  -c /config/config.toml --keep-tmp-data -l DEBUG

docker run  \
  -v ./config:/config \
  -v ./example_data/10_268_594/bag:/data/poly \
  -v ./example_data/10_268_594/true-ortho:/data/img \
  -v ./example_data/10_268_594/laz/2020_dim:/data/laz/2020_dim \
  -v ./example_data/10_268_594/laz/ahn3:/data/laz/ahn3 \
  -v ./example_data/10_268_594/laz/ahn4:/data/laz/ahn4 \
  -v ./tmp:/data/tmp \
  -v ./output:/data/output \
-e PG_OUTPUT="PG:dbname=gfoutput active_schema=public user=<pg_username> port=<pg_port> host=<pg_host> password=<password>" \
  geoflow-dim  -c /config/config.toml  --keep-tmp-data --only-reconstruct -l INFO

docker run  \
  -v ./config:/config \
  -v ./example_data/10_268_594/bag:/data/poly \
  -v ./example_data/10_268_594/true-ortho:/data/img \
  -v ./example_data/10_268_594/laz/2020_dim:/data/laz/2020_dim \
  -v ./example_data/10_268_594/laz/ahn3:/data/laz/ahn3 \
  -v ./example_data/10_268_594/laz/ahn4:/data/laz/ahn4 \
  -v ./tmp:/tmp \
  -v ./output:/data/output \
-e PG_OUTPUT="PG:dbname=osm active_schema=public user=osmuser port=5432 host=172.17.0.1 password=osmuser" \
  geoflow-dim  -c /config/config.toml --keep-tmp-data --only-reconstruct -l DEBUG