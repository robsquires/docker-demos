#!/bin/bash

date

#
#  private functions -----
#

#
#parse_yaml - parses a given yaml file to an (optional) prefix
#
function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}

         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

#
# remove_container - kills and removes a container
# 
function remove_container {
    local container_name=$1
    echo "--> Stopping container: $container_name"
    docker kill $container_name
    docker rm $container_name
}

#
# map_config - maps a node in the yaml config to a variable
# exits if node not found
# 
function map_config {
    node=$1
    mapTo=$2

    value=${!1}
    if [ -z "$value" ]
      then
        echo "Node '$node' not found"
        exit 1
    fi

    eval $(echo $mapTo=$value)
}


#
#  ----- end private functions 
#


#
# import the number of workers
#
pCount=$1;
: ${pCount:=1}



#
# import the dockman config
#


dockmanFile=$2;
: ${dockmanFile:='.dockman.yml'}


if [ ! -f "$dockmanFile" ]; then
    echo "! Could not find $dockmanFile"
    exit 1
fi

eval $(parse_yaml $dockmanFile) 


#
# import the container namespace
#
map_config 'namespace' 'cnt_namespace'


#
# dockman-behat config
# 
base_cnt_cmd="./bootstrap.sh"


#
# Worker container configuration
#
map_config 'worker_container__image' 'worker_cnt_image'

file=$namespace-features

docker run -t -i -rm $worker_cnt_image find features -type f -name "*.feature" > $file

#list=`cd /Users/rob/Projects/UVd/LimpidMarkets/backend.git; tree -a  -if --noreport  features/  | grep .feature$`

#ouch

while read i; do
  echo $i
  sem --gnu -j $pCount \
    docker run -t -i -e TEST_TOKEN=1 \
    -rm \
    $worker_cnt_image \
    $base_cnt_cmd "$i"
done < $file
sem --gnu --wait

date