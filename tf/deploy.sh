#!/bin/bash

pushd ../
git add .
git commit -m "work"
popd

./zipfunction.sh

terraform fmt
terraform validate

gitid="$(git rev-parse HEAD)"
var="-var gitid="$gitid

terraform plan $var --out plan.out
terraform apply plan.out