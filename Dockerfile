FROM python:3.11-slim-bookworm as base
ARG VERSION
LABEL org.opencontainers.image.authors="Ravi Peters <ravi.peters@3dgi.nl>"
LABEL org.opencontainers.image.vendor="3DGI"
LABEL org.opencontainers.image.title="geoflow-dim"
LABEL org.opencontainers.image.description="Custom image made for Kadaster to perform buildings reconstruction based on geoflow with rooflines extracted from true-ortho photos"
LABEL org.opencontainers.image.version=$VERSION
LABEL org.opencontainers.image.licenses="MIT"
ARG JOBS=4
SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt-get -y install \
    libgeos++-dev \
    libeigen3-dev \
    libpq-dev \
    nlohmann-json3-dev \
    libboost-filesystem-dev \
    libsqlite3-dev sqlite3\
    libgeotiff-dev \
    build-essential \
    wget \
    git \
    cmake

ARG PROJ_VERSION=9.2.1
RUN cd /tmp && \
    wget https://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz && \
    tar -zxvf proj-${PROJ_VERSION}.tar.gz  && \
    cd proj-${PROJ_VERSION} && \
    mkdir build && \
    cd build/ && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF && \
    cmake --build . --config Release --parallel $JOBS && \
    cmake --install . && \
    rm -rf /tmp/*

ARG LASTOOLS_VERSION=9ecb4e682153436b044adaeb3b4bfdf556109a0f
RUN cd /tmp && \
    git clone https://github.com/LAStools/LAStools.git lastools && \
    cd lastools && \
    git checkout ${LASTOOLS_VERSION} && \
    mkdir build && \
    cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    cmake --build . --parallel $JOBS --config Release && \
    cmake --install . && \
    rm -rf /tmp/* && \
    mkdir /tmp/geoflow-bundle

ARG CGAL_VERSION=5.5.2
RUN cd /tmp && \
    apt-get install -y libboost-system-dev libboost-thread-dev libgmp-dev libmpfr-dev zlib1g-dev && \
    wget https://github.com/CGAL/cgal/releases/download/v${CGAL_VERSION}/CGAL-${CGAL_VERSION}.tar.xz && \
    tar xf CGAL-${CGAL_VERSION}.tar.xz && \
    cd CGAL-${CGAL_VERSION} && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    cmake --build . --parallel $JOBS --config Release && \
    cmake --install . && \
    rm -rf /tmp/*

ARG GDAL_VERSION=3.8.3
RUN cd /tmp && \
    wget http://download.osgeo.org/gdal/${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz && \
    tar -zxvf gdal-${GDAL_VERSION}.tar.gz && \
    cd gdal-${GDAL_VERSION} && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DENABLE_IPO=OFF -DBUILD_TESTING=OFF && \
    cmake --build . --parallel $JOBS --config Release && \
    cmake --install . && \
    ldconfig && \
    rm -rf /tmp/*
CMD ["bash"]

# # install geoflow
FROM base as build-geoflow
COPY ./strip-docker-image-export /tmp/
RUN cd /tmp && \
    git clone https://github.com/geoflow3d/geoflow-bundle.git && cd geoflow-bundle && \
    git checkout develop && \
    git submodule update --init --recursive && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DGF_BUILD_GUI=OFF && \
    cmake --build . --parallel $JOBS --config Release && \
    cmake --install .
    # rm -rf /tmp/*
RUN mkdir /tmp/export && \
    bash /tmp/strip-docker-image-export \
    -v \
    -d /tmp/export \
    -f /usr/local/bin/geof \
    -f /usr/local/lib/geoflow-plugins/gfp_buildingreconstruction.so \
    -f /usr/local/lib/geoflow-plugins/gfp_core_io.so \
    -f /usr/local/lib/geoflow-plugins/gfp_gdal.so \
    -f /usr/local/lib/geoflow-plugins/gfp_val3dity.so \
    -f /usr/local/lib/geoflow-plugins/gfp_las.so

# install crop
FROM base as build-crop
COPY ./strip-docker-image-export /tmp/
RUN cd /tmp && \
    git clone https://github.com/patrikmalvenius/roofer.git && cd roofer && \
    git checkout develop && \
    git submodule update --init --recursive && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    cmake --build . --parallel $JOBS --config Release && \
    cmake --install .
    # rm -rf /tmp/*
RUN mkdir /tmp/export && \
    mkdir -p /tmp/export/usr/local/share && \
    bash /tmp/strip-docker-image-export \
    -v \
    -d /tmp/export \
    -f /usr/local/bin/crop

FROM base as pyenv
SHELL ["/bin/bash", "-c"]
ARG JOBS
RUN mkdir /dim_pipeline && cd /dim_pipeline && \
    python3 -m venv roofenv && \
    pip install numpy && \
    source /dim_pipeline/roofenv/bin/activate && \
    pip3 install shapely rtree wheel click fiona numpy cjdb && \ 
    pip3 install cjio &&\
    pip3 install 'cjio[export,reproject,validate,triangulate]' &&\
    pip3 install --no-cache-dir --force-reinstall 'GDAL[numpy]'

# # install opencv
RUN apt-get install -y unzip && \
    cd /tmp && \
    wget https://github.com/opencv/opencv/archive/4.8.0.zip && \
    unzip 4.8.0.zip && \
    cd opencv-4.8.0/ && \
    mkdir build && cd build/ && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/dim_pipeline/roofenv -DPYTHON3_NUMPY_INCLUDE_DIRS=/usr/local/lib/python3.11/site-packages/numpy/core/include && \
    cd /tmp/opencv-4.8.0/build && cmake --build . --parallel $JOBS --config Release && \
    cd /tmp/opencv-4.8.0/build && cmake --install .

RUN cd /tmp && \
    wget https://boostorg.jfrog.io/artifactory/main/release/1.82.0/source/boost_1_82_0.tar.gz && \
    tar -zxf boost_1_82_0.tar.gz && \
    cd /tmp/boost_1_82_0 && \
    ./bootstrap.sh --with-libraries=python,filesystem --with-python=/usr/local/bin/python --prefix=/dim_pipeline/roofenv && \
    ./b2 install

RUN cd /tmp && \
    git clone https://github.com/Ylannl/Roofline-extraction-from-orthophotos.git && \
    cd Roofline-extraction-from-orthophotos && \
    cp class_definition.py /dim_pipeline/roofenv/lib64/python3.11/site-packages/ && \
    cd kinetic_partition && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/dim_pipeline/roofenv -DBoost_DIR=/dim_pipeline/roofenv/lib/cmake/Boost-1.82.0/ && \
    cmake --build . --parallel $JOBS --config Release && \
    cp libkinetic_partition* /dim_pipeline/roofenv/lib64/python3.11/site-packages/

# install azcopy
RUN cd /tmp && \
    wget -O azcopy_v10.tar.gz https://aka.ms/downloadazcopy-v10-linux && tar -xf azcopy_v10.tar.gz --strip-components=1 && \
    mv azcopy /usr/local/bin/ && \
    rm azcopy_v10.tar.gz NOTICE.txt

RUN apt-get update && apt-get -y install

FROM python:3.11-slim-bookworm as geoflow-dim-runner
COPY --from=base /usr/local/share/gdal/ /usr/local/share/gdal
COPY --from=base /usr/local/share/proj /usr/local/share/proj
COPY --from=build-geoflow /tmp/export/usr/ /usr
COPY --from=build-geoflow /tmp/export/lib/ /lib
COPY --from=build-crop /tmp/export/usr/ /usr
COPY --from=pyenv /dim_pipeline/ /dim_pipeline
COPY --from=pyenv /usr/local/bin/azcopy /usr/local/bin/azcopy
COPY ./resources/ /dim_pipeline/resources
COPY ./run.py /dim_pipeline/python

ENV LD_LIBRARY_PATH=/usr/local/lib/;/lib/x86_64-linux-gnu/
WORKDIR /data
#ENTRYPOINT ["/dim_pipeline/roofenv/bin/python", "/dim_pipeline/run.py"]
#CMD ["--help"]
CMD ["/bin/bash"]
