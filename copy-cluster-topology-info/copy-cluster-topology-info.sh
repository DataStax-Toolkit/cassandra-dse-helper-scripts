#!/usr/bin/env bash

#
# File: copy-cluster-topology-info.sh
# Author: Brendan Cicchi
#
# Created: Friday, June 14 2019
#

##### Restrictions #####
# Requires Bash 4.0+ for associative arrays
# OSX does not come with Bash 4.0 (can be installed with brew)
#     Update script's /bin/bash -> /usr/local/bin/bash after installing

##### Begin Configurations #####

# Add any necessary configs to connect via nodetool
# i.e. username, password, ssl, absolute path, etc.. or pass via -n
NODETOOL="nodetool"

##### End of Configurations #####

function main()
{
    parse_arguments "$@"
    declare -A _ip_token_map
    parse_nodetool_ring_to_map
    print_ip_token_map
}

function parse_arguments()
{
    while getopts ":hf:n:" _opt; do
        case $_opt in
            h )
                _print_usage
                exit 0
                ;;
            f )
                _nodetool_ring_path="$OPTARG"
                if [ ! -f $_nodetool_ring_path ]; then
                    echo -e "\n$_nodetool_ring_path is an invalid path."
                    exit 1
                fi
                ;;
            n )
                NODETOOL="$NODETOOL $OPTARG"
                ;;
            \?)
                echo -e "\nInvalid option: -$OPTARG"
                _print_usage
                exit 1
                ;;
            :)
                echo -e "\nOption -$OPTARG requires an argument."
                _print_usage
                exit 1
                ;;
        esac
    done
}

function _print_usage()
{
    echo "Usage:"
    echo "    -h                       Display this help message."
    echo "    -f <nodetool_ring_path>  Use an already existing output file instead of running nodetool"
    echo "    -n <nodetool_options>    Options to pass to nodetool to connect to the cluster"
}

function parse_nodetool_ring_to_map()
{
    [[ ! -z $_nodetool_ring_path ]] && _input="cat $_nodetool_ring_path" || _input="$NODETOOL ring" 
    OIFS=$IFS
    IFS=
    while read -r line
    do
        if [[ $line == *"Datacenter:"* ]]; then
            dc=$(echo $line | awk '{print $2}')
            continue
        elif _is_ip $(echo $line | awk '{print $1}'); then
            ip=$(echo $line | awk '{print $1}')
            rack=$(echo $line | awk '{print $2}')
            token=$(echo $line | awk '{print $NF}')
            if [[ -v _ip_token_map[$dc,$rack,$ip] ]]; then
                _ip_token_map[$dc,$rack,$ip]+=", $token"
            else
                _ip_token_map[$dc,$rack,$ip]=$token
            fi
        fi
    done <<< $(eval $_input)
    IFS=$OIFS
}

function print_ip_token_map()
{
    for _key in "${!_ip_token_map[@]}"
    do   
        echo "Tokens originating from node $(echo $_key | cut -d ',' -f 3)"
        echo "Datacenter: $(echo $_key | cut -d ',' -f 1)"
        echo "Rack: $(echo $_key | cut -d ',' -f 2)"
        echo "initial_token: ${_ip_token_map[$_key]}"
        echo
    done
}

function _is_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

main "$@"
