#!/bin/bash

terraform fmt
terraform validate

./zipfunction.sh

gitid="$(git rev-parse HEAD)"
var="-var gitid="$gitid

terraform plan $var --out plan.out
terraform apply plan.out