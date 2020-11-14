#!/bin/bash

pushd ../  # back into function source code dir

if [[ -f function.zip ]]; then
    rm function.zip 
fi

cd venv/lib/python3.8/site-packages  
                               
zip -r9 ${OLDPWD}/function.zip .  # zip the dependencies

cd $OLDPWD

# add the source code to the zip
zip -g function.zip lambda_function.py  

popd