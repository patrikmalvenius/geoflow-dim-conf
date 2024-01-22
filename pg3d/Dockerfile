FROM mcr.microsoft.com/dotnet/sdk:6.0

WORKDIR data/pg3bdm_app

COPY ./init.sh ./

ENV PATH="${PATH}:/root/.dotnet/tools"

RUN apt update && \
    dotnet tool install -g pg2b3dm  && \ 
    dotnet tool install -g tesselate_building && \
    dotnet tool install -g i3dm.export
