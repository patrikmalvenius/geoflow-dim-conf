docker compose run geoflow  -c /config/config.toml --keep-tmp-data --only-reconstruct -l DEBUG   
docker compose run geoflow  -c /config/config.toml --keep-tmp-data  -l DEBUG 

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