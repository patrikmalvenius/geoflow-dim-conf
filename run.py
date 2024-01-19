import click
import subprocess
import fiona
from fiona.transform import transform_geom
import tempfile
import class_definition as cd
import os.path
from pathlib import Path
import glob
import copy
import sys, os
import tomllib
import logging
import shutil
from concurrent.futures import ThreadPoolExecutor, as_completed

#modify it to your build path
# sys.path.append("./kinetic_partition/build")
import libkinetic_partition

CJSONL_PATH = "/data/output/features"
METADATA_NL_PATH = "/dim_pipeline/resources/metadata_nl.jsonl"
ROOFLINES_OUTPUT_TMPL = "/tmp/features/{bid}/crop/rooflines"
BUILDING_CFG_TMPL = "/tmp/features/{bid}/config.toml"

DB_OUTPUT_STRING =  os.environ.get("PG_OUTPUT").replace('"', "")

GF_FLOWCHART_LIDAR = "/dim_pipeline/resources/flowcharts/reconstruct_bag.json"
GF_FLOWCHART_DIM = "/dim_pipeline/resources/flowcharts/reconstruct_bag_ortho.json"
GF_FLOWCHART_MERGE_FEATURES = "/dim_pipeline/resources/flowcharts/createMulti.json"

BLD_ID = "identificatie"

EXE_CROP = "/usr/local/bin/crop"
EXE_GEOF = "/usr/local/bin/geof"

def read_toml_config(config_path):
    with open(config_path, "rb") as f:
        data = tomllib.load(f)
    # data[]
    return data

def run_crop(config_path, verbose=False):
    args = [EXE_CROP, "-c", config_path, "--index"]
    if verbose:
        args += ["--verbose"]
    return subprocess.run(args)



# 3 Run gf reconstruction
def run_reconstruct(building_index_file, max_workers, skip_ortholines, config_data=None, verbose=False):
    def get_buildings(building_index_file):
        buildings = list()

        with fiona.open(building_index_file, ) as building:

            buildings = [bld for bld in building]


 
        return buildings
    def run_geoflow(building, config_data, verbose):

        def format_parameters(parameters, args):
            for (key, val) in parameters.items():
                if isinstance(val, bool):
                    if val:
                        args.append(f"--{key}=true")
                    else:
                        args.append(f"--{key}=false")
                else:
                    args.append(f"--{key}={val}")

        args = [EXE_GEOF]
        bid = str(building.properties[BLD_ID])


        args.append(GF_FLOWCHART_LIDAR)
        args += ["-c", BUILDING_CFG_TMPL.format(bid=bid)]

        if verbose:
            args += ["--verbose"]
       

        format_parameters(config_data['output']['reconstruction_parameters_lidar'], args)
        #logging.info("args")
        #logging.info(args)
        
        return subprocess.run(args)
    
    buildings = get_buildings(building_index_file)

    with ThreadPoolExecutor(max_workers=max_workers) as executor:

        futures = {executor.submit(run_geoflow, building, config_data, verbose): building for building in buildings}

        for future in as_completed(futures):
            # command = futures[future]
            result = future.result()
            if result.returncode != 0:
                logging.warning("Error occurred while executing command '{}'".format(" ".join(result.args)))

# 5 merge cjdb?
def run_tile_merge(path, verbose):
    # cmd = f"(cat {METADATA_NL_PATH} ; echo ; find {CJSONL_PATH} -name '*.city.jsonl' -exec cat {{}} \;  -exec echo \;) | cjio stdin save {path}"
    args = ["geof", GF_FLOWCHART_MERGE_FEATURES] 
    args.append(f"--path_features_input_file={path}/features.txt") 
    args.append(f"--path_metadata={METADATA_NL_PATH}") 
    args.append(f"--output_file=output/tile")
    args.append(f"--output_ogr={DB_OUTPUT_STRING}")

    args += ["--verbose"]
    logging.info(" ".join(args))
    result = subprocess.run(args)
    if result.returncode != 0:
        logging.warning("Error occurred while executing command '{}'".format(" ".join(result.args)))



@click.group(invoke_without_command=True)
@click.pass_context
@click.option('-c', '--config', type=click.Path(exists=True), help='Main configuration file')
@click.option('-l', '--loglevel', type=click.Choice(['INFO', 'WARNING', 'DEBUG'], case_sensitive=False), help='Print debug information')
@click.option('-j', '--jobs', default=None, type=int, help='Number of parallel jobs to use. Default is all cores.')
@click.option('--keep-tmp-data', is_flag=True, default=False, help='Do not remove temporary files (could be helpful for debugging)')
@click.option('--only-reconstruct', is_flag=True, default=False, help='Only perform the building reconstruction and tile generation steps (needs tmp data from previous run)')
def cli(ctx, config, loglevel, jobs, keep_tmp_data, only_reconstruct):
    loglvl = logging.WARNING
    if loglevel == 'INFO':
        loglvl = logging.INFO
    elif loglevel == 'WARNING':
        loglvl = logging.WARNING
    elif loglevel == 'DEBUG':
        loglvl = logging.DEBUG
    logging.basicConfig(format='%(asctime)s [%(levelname)s]: %(message)s', level=loglvl)
    if ctx.invoked_subcommand: return

    config_data = read_toml_config(config)
    indexfile = config_data['output']['index_file']
    path = config_data['output']['path']
    building_index_path = indexfile.format(path=path)

    skip_ortholines = True


    logging.info(f"Config read from {config}")

    
    if not only_reconstruct:
        logging.info("Pointcloud selection and cropping...")
        run_crop(config, loglvl <= logging.DEBUG)
        


    logging.info("Building reconstruction...")
    run_reconstruct(building_index_path, jobs, skip_ortholines, config_data, loglvl <= logging.DEBUG)

    logging.info("Generating CityJSON file...")
    run_tile_merge(path, loglvl <= logging.DEBUG)

    if  os.environ.get("AZBLOB_GFOUTPUT_SAS_KEY") and \
        os.environ.get("AZBLOB_GFOUTPUT_CONTAINER") and \
        os.environ.get("AZBLOB_GFOUTPUT_ENDPOINT"):
        azb = azcopyResource(
            sas_key=os.environ.get("AZBLOB_GFOUTPUT_SAS_KEY"),
            container=os.environ.get("AZBLOB_GFOUTPUT_CONTAINER"),
            endpoint=os.environ.get("AZBLOB_GFOUTPUT_ENDPOINT")
        )
        logging.info("Uploading outputs to Azure BLOB storage...")
        p = Path(path)
        remote_path = Path("")
        if os.environ.get("AZBLOB_GFOUTPUT_PATH"):
            remote_path = Path(str(os.environ.get("AZBLOB_GFOUTPUT_PATH")).replace('"', ""))
        azb.upload(
            src=p,
            az_path=remote_path
        )
        azb.upload(
            src=METADATA_NL_PATH,
            az_path=remote_path / p.relative_to("/data/output") / "features_metadata.city.json"
        )

    if not keep_tmp_data:
        logging.info("Cleaning up temporary files...")
        for item in os.listdir("/data/tmp"):
            item_path = os.path.join("/data/tmp", item)
            if os.path.isfile(item_path) or os.path.islink(item_path):
                os.unlink(item_path)
            elif os.path.isdir(item_path):
                shutil.rmtree(item_path)

@cli.command(help="Run a command (for debugging)")
@click.argument("commandline")
# @click.option("--commandline")
def cmd(commandline):
    args = commandline.split()
    logging.info(f"Running: {commandline}")
    result = subprocess.run(args)
    if result.returncode != 0:
        logging.warning("Error occurred while executing command '{}'".format(" ".join(result.args)))

if __name__ == '__main__':
    cli()
