#!/bin/bash
set -eu
apt install -y sudo
sudo apt update && sudo apt install -y wget python3-requests python3-snappy python3-grpc-tools
# maybe needed or not python3-grpc-tools python3-protobuf

mkdir -p prometheus_proto/gogoproto
cd prometheus_proto
wget https://raw.githubusercontent.com/prometheus/prometheus/main/prompb/remote.proto
wget https://raw.githubusercontent.com/prometheus/prometheus/main/prompb/types.proto
wget -P gogoproto https://raw.githubusercontent.com/gogo/protobuf/master/gogoproto/gogo.proto

sudo apt install -y protobuf-compiler

protoc --proto_path=. --python_out=. gogoproto/gogo.proto
protoc --proto_path=. --python_out=. types.proto
protoc --proto_path=. --python_out=. remote.proto

mv *.py ../
mv gogoproto ../
cd ..
