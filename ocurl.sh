#!/usr/bin/env bash
#
# Add profile configuration to the oci-curl tool.
# Use either the profile name provided in input or OCI_CLI_PROFILE is set and not empy 
# Usage:
# ocurl [-h] | [-p PROFILE] [-f CONFIG_PATH] <host> <method> [file-to-send-as-body] <request-target> [extra-curl-args]
#
# ex:
# ocurl iaas.us-ashburn-1.oraclecloud.com get "/20160918/instances?compartmentId=some-compartment-ocid"
# ocurl -p MYCONFIG iaas.us-ashburn-1.oraclecloud.com get "/20160918/instances?compartmentId=some-compartment-ocid"
# ocurl iaas.us-ashburn-1.oraclecloud.com post ./request.json "/20160918/vcns"

CONFIG_FILE_PATH="$(eval echo ~/.oci/config)"
if [ -z "$OCI_CLI_PROFILE" ]
then
    CONFIG_PROFILE="DEFAULT"
else
    CONFIG_PROFILE=$OCI_CLI_PROFILE
fi 



#convert OCI config profiles [...] in functions
function cfg.parser () {
    fixed_file=$(cat $1 | sed 's/ = /=/g')   # fix ' = ' to be '='
    IFS=$'\n' && ini=( $fixed_file )         # convert to line-array
    ini=( ${ini[*]//;*/} )    
    ini=( ${ini[*]/#[/\}$'\n'profile.} )     # set section prefix 
    ini=( ${ini[*]/%]/ \(} )                 # convert text to function (1)
    ini=( ${ini[*]/=/=\( } )                 # convert item to array
    ini=( ${ini[*]/%/ \)} )                  # close array parenthesis
    ini=( ${ini[*]/%\( \)/\(\) \{} )         # convert text  to function 
    ini=( ${ini[*]/%\} \)/\}} )              # remove extra parenthesis
    ini[0]=''                                # remove first element
    ini[${#ini[*]} + 1]='}'   
    #echo "${ini[*]}"                        # add the last brace
    eval "$(echo "${ini[*]}")"               # eval the result
}

function set_configuration () {
    cfg.parser $CONFIG_FILE_PATH
    
    profile.DEFAULT
    TENANCY=$tenancy
    USER=$user
    FINGERPRINT=$fingerprint
    KEY_FILE=$key_file

    if [ "DEFAULT" != "$CONFIG_PROFILE" ]; then
        SECTION=$(declare -F | grep "profile.\<$CONFIG_PROFILE\>")
        if [ -z $SECTION ]; then
            echo "Profile $SECTION doesn't exit. DEFAULT is used insted."
            return
        fi
        eval "profile.$CONFIG_PROFILE"
        if [ ! -z "$tenancy" ]; then
            TENANCY=$tenancy
        fi
        if [ ! -z "$user" ]; then
            USER=$user
        fi
        if [ ! -z "$fingerprint" ]; then
            FINGERPRINT=$fingerprint
        fi
        if [ ! -z "$key_file" ]; then
            KEY_FILE=$key_file
        fi
    fi
}

function oci-curl {
    local tenancyId=$TENANCY;
	local authUserId=$USER;
	local keyFingerprint="$FINGERPRINT";
	local privateKeyPath="$KEY_FILE";

    local alg=rsa-sha256
    local sigVersion="1"
    local now="$(LC_ALL=C \date -u "+%a, %d %h %Y %H:%M:%S GMT")"
    local host=$1
    local method=$2
    local extra_args
    local keyId="$tenancyId/$authUserId/$keyFingerprint"
    local api_host
    
    #handle API url with or without https:// prefix
    if ! [[ "$host" == "https"* ]];  then
        api_host=$host
        host="https://"$host
    else
        api_host=${host#"https://"}
    fi
    #echo "Host: $host"
    echo "API Host: $api_host"
    echo "Method: $method"
    echo "---------------------------------------------------------------------------"

    case $method in

        "get" | "GET")
            local target=$3
            extra_args=("${@: 4}")
            local curl_method="GET";
            local request_method="get";
            ;;

        "delete" | "DELETE")
            local target=$3
            extra_args=("${@: 4}")
            local curl_method="DELETE";
            local request_method="delete";
            ;;

        "head" | "HEAD")
            local target=$3
            extra_args=("--head" "${@: 4}")
            local curl_method="HEAD";
            local request_method="head";
            ;;

        "post" | "POST")
            local body=$3
            local target=$4
            extra_args=("${@: 5}")
            local curl_method="POST";
            local request_method="post";
            local content_sha256="$(openssl dgst -binary -sha256 < $body | openssl enc -e -base64)";
            local content_type="application/json";
            local content_length="$(wc -c < $body | xargs)";
            ;;

        "put" | "PUT")
            local body=$3
            local target=$4
            extra_args=("${@: 5}")
            local curl_method="PUT"
            local request_method="put"
            local content_sha256="$(openssl dgst -binary -sha256 < $body | openssl enc -e -base64)";
            local content_type="application/json";
            local content_length="$(wc -c < $body | xargs)";
            ;;

        *) echo "invalid method"; return;;
    esac

    # This line will url encode all special characters in the request target except "/", "?", "=", and "&", since those characters are used 
    # in the request target to indicate path and query string structure. If you need to encode any of "/", "?", "=", or "&", such as when
    # used as part of a path value or query string key or value, you will need to do that yourself in the request target you pass in.
    local escaped_target="$(echo $( rawurlencode "$target" ))"
    
    local request_target="(request-target): $request_method $escaped_target"
    local date_header="date: $now"
    local host_header="host: $api_host"
    local content_sha256_header="x-content-sha256: $content_sha256"
    local content_type_header="content-type: $content_type"
    local content_length_header="content-length: $content_length"
    local signing_string="$request_target\n$date_header\n$host_header"
    local headers="(request-target) date host"
    local curl_header_args
    curl_header_args=(-H "$date_header")
    local body_arg
    body_arg=()

    if [ "$curl_method" = "PUT" -o "$curl_method" = "POST" ]; then
        signing_string="$signing_string\n$content_sha256_header\n$content_type_header\n$content_length_header"
        headers=$headers" x-content-sha256 content-type content-length"
        curl_header_args=("${curl_header_args[@]}" -H "$content_sha256_header" -H "$content_type_header" -H "$content_length_header")
        body_arg=(--data-binary @${body})
    fi

    local sig=$(printf '%b' "$signing_string" | \
                openssl dgst -sha256 -sign $privateKeyPath | \
                openssl enc -e -base64 | tr -d '\n')

    local prefix
   

    curl "${extra_args[@]}" "${body_arg[@]}" -X $curl_method -sS $prefix${host}${escaped_target} "${curl_header_args[@]}" \
        -H "Authorization: Signature version=\"$sigVersion\",keyId=\"$keyId\",algorithm=\"$alg\",headers=\"${headers}\",signature=\"$sig\""
}

# url encode all special characters except "/", "?", "=", and "&"
function rawurlencode {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] | "/" | "?" | "=" | "&" ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done

  echo "${encoded}"
}

function print_help {
    echo "Usage:"
    echo "    ocurl [-h] | [-p PROFILE] [-f CONFIG_PATH] <host> <method> [file-to-send-as-body] <request-target> [extra-curl-args]"
    echo "    -h               Display this help message."
    echo "    -p PROFILE       Profile name to be used in config file - default: DEFAULT"
    echo "    -f CONFIG_PATH   OCI config file path - default: ~/.oci/config"
}
while getopts ":hp:f:" opt; do
  case ${opt} in
    h )
      print_help
      exit 0
      ;;
   \? )
     echo "Invalid Option: -$OPTARG" 1>&2
     exit 1
     ;;
    p )
        CONFIG_PROFILE=$OPTARG
        ;;
    f )
        CONFIG_PATH=$OPTARG
        ;;
    : )
        echo "Invalid Option: -$OPTARG requires an argument" 1>&2
        print_help
        exit 1
        ;;
    esac
done
shift $((OPTIND -1))
    

# setup the configuration according to the PROFILE
set_configuration

#echo "$TENANCY"
#echo "$USER"
#echo "$FINGERPRINT"
#echo "$KEY_FILE"


# run curl
oci-curl $@




