#!/usr/bin/env bash
 
R_LIST=$(sed -n -E 's/^\[(.*)\]$/\1/p'  ~/.oci/config)


if [ -z "$OCI_CLI_PROFILE" ]
then      
    echo "Current CLI profile: DEFAULT"
else
    echo "Current CLI profile: $OCI_CLI_PROFILE"
fi

echo "Available profiles:"
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
echo "To select a profile run the commmand:"
echo "OCI_CLI_PROFILE=<profile_name>"
echo