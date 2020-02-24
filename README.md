# Shell utils for OCI Command Line Interface and API

* `ocurl.sh` wrap the _oci-curl.sh_ script provided by Oracle, adding profile selection.
* `oci-show-regions.sh` list subscribed regions using the default configuration in your CLI profile
* `oci-show-profiles.sh` list the available profiles in your _~/.oci/config_ file

### ocurl
Add profile-based configuration and better url handling to the oci-curl [sample code](https://docs.cloud.oracle.com/en-us/iaas/Content/API/Concepts/signingrequests.htm#seven) provided in OCI documentation.
Use either the profile name provided in input, the OCI_CLI_PROFILE environment variable if it is set and not empty, or the DEFAULT profile.

#### Usage:
__ocurl [-h] | [-p PROFILE] [-f CONFIG_PATH] <host> <method> [file-to-send-as-body] <request-target> [extra-curl-args]__

examples:
```SHELL
ocurl iaas.us-ashburn-1.oraclecloud.com get "/20160918/instances?compartmentId=some-compartment-ocid"

ocurl -p MYCONFIG iaas.us-ashburn-1.oraclecloud.com get "/20160918/instances?compartmentId=some-compartment-ocid"

ocurl iaas.us-ashburn-1.oraclecloud.com post ./request.json "/20160918/vcns"
```

