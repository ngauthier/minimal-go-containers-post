#!/usr/bin/env bash
set -ex

CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .
docker build -t example-scratch -f Dockerfile.scratch .
