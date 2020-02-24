#!/usr/bin/env bash

R_LIST=`oci iam region list --query 'data[*].name'`

if [ -z "$OCI_CLI_REGION" ]
then      
    echo "Current CLI region: DEFAULT"
else
    echo "Current CLI region: $OCI_CLI_REGION"
fi

echo "Available regions:"
field=()
i=1
for line in $R_LIST
do
    line=${line//\[}
    line=${line//\]}
    [ -z "$line" ] && continue
    line=${line//\"}
    line=${line//,}
    echo "$i. $line"
    field+=("$line")
    ((++i))      
done
echo 
echo "To select a region run the command:"
echo "OCI_CLI_REGION=<region_name>"
echo