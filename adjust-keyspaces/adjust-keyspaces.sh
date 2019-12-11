#!/bin/bash
#
# File: adjust-keyspaces.sh
#
# Created: Friday, May  3 2019
#

rep_factor=3
fix_system=1
keyspaces=("system_auth" "system_distributed"  "dse_security" "solr_admin" "dse_perf" "dse_leases" "dse_analytics" "dsefs" '"HiveMetaStore"' "cfs" "cfs_archive" "system_traces" "dse_advrep" "dse_system")
cqlsh_options=""
nodetool_options=""

function usage() {
    echo "Usage: $0 [-n replication_factor] [-c cqlsh_options_as_a_string] [-o nodetool_options_as_a_string] [keyspace1 keyspace2 ...]"
    echo "Defaults:"
    echo "   replication_factor = $rep_factor"
    echo "   keyspace1.. = name(s) of keyspace(s) to fix replication factor."
    echo "                 fix all system keyspaces if not specified"
}

while getopts ":hc:o:n:" opt; do
    case $opt in
        n) rep_factor=$OPTARG
           ;;
        c) cqlsh_options=$OPTARG
           ;;
        o) nodetool_options=$OPTARG
           ;;
        h) usage
           exit 0
           ;;
    esac
done
shift "$(($OPTIND -1))"

if [ $# -ne 0 ] ; then
    keyspaces=()
    fix_system=0
    for ks in "$@" ; do
        keyspaces+=($ks)
    done
fi    

my_pid=$$

NODETOOL_FILE=/tmp/nodetool-out-${my_pid}.txt
SCHEMA_FILE=/tmp/cqlsh-schema-${my_pid}.txt
TMP_FILE=/tmp/tmp-${my_pid}.txt

# File with commands to execute
CQL_FILE=/tmp/fix-keyspaces-${my_pid}.cql
rm -f $CQL_FILE
touch $CQL_FILE

nodetool $nodetool_options status > $NODETOOL_FILE
RES=$?
if [ $RES -ne 0 ] ; then
    echo "Can't execute 'dsetool status'! Exit code: $?"
    exit 1
fi
    
if cat $NODETOOL_FILE|grep -e '^[UD][NJLM] '|grep -v -e '^UN ' > /dev/null 2>&1 ; then
    echo "Cluster has nodes with non-UN status, can't adjust replication factor!"
    exit 1
fi

cqlsh $cqlsh_options -e 'DESCRIBE FULL SCHEMA;' > $SCHEMA_FILE
RES=$?
if [ $RES -ne 0 ] ; then
    echo "Can't get schema via cqlsh! Exit code: $?"
    exit 1
fi

declare -A all_ks
for i in `cat $SCHEMA_FILE|grep 'CREATE KEYSPACE'|grep -e 'SimpleStrategy\|NetworkTopologyStrategy'|sed -e 's|^CREATE KEYSPACE \([^ ]*\).*$|\1|'`; do
    all_ks[$i]=1
done
#echo "All keyspaces=${!all_ks[@]}"

declare -A all_dcs

curr_dc=''
cnt=0
while read -d $'\n' line ; do
#    echo "$line"
    if echo "$line"|grep -e '^Datacenter: '  > /dev/null 2>&1 ; then
        new_dc=`echo "$line"|sed -e 's|^Datacenter: \([^ ]*\).*$|\1|'`
#        echo "new_dc=$new_dc"
        if [ -z "$new_dc" ] ; then
            echo "Can't extract DC from line '$line'"
            exit 1
        fi
        if [ -z "$curr_dc" ] ; then
            curr_dc=$new_dc
        else
            max_rf=$rep_factor
            if [ $rep_factor -gt $cnt ]; then
                max_rf=$cnt
            fi
            echo "$curr_dc has $cnt nodes max RF=$max_rf"
            all_dcs[$curr_dc]=$max_rf
            curr_dc=$new_dc
            cnt=0
        fi
    fi
    if echo "$line"|grep -e '^[UD][NJLM] ' > /dev/null 2>&1 ; then
        ((cnt++))
    fi
done < $NODETOOL_FILE
# push the last DC as well
max_rf=$rep_factor
if [ $rep_factor -gt $cnt ]; then
    max_rf=$cnt
fi
echo "$curr_dc has $cnt nodes max RF=$max_rf"
all_dcs[$curr_dc]=$max_rf

#echo "All DCs=${!all_dcs[@]}"
if [ ${#all_dcs[@]} -eq 0 ]; then
    echo "Can't identify data centers!"
    exit 1
fi

to_repair=()
for i in "${keyspaces[@]}"; do
#    echo "Processing $i"
    if [ -z "${all_ks[$i]}" ]; then
        if [ $fix_system = "0" ]; then 
            echo "$i not in the list of existing keyspaces!"
        fi
        continue
    fi
    echo -n "ALTER KEYSPACE $i WITH replication = {'class': 'NetworkTopologyStrategy'" >> $CQL_FILE
    for key in "${!all_dcs[@]}"; do
        echo -n ", '$key': ${all_dcs[$key]}" >> $CQL_FILE
    done
    echo "};" >> $CQL_FILE
    to_repair+=($i)
done

ret_code=0
if [ ${#to_repair[@]} -eq 0 ]; then
    rm -f $CQL_FILE
    echo "No keyspaces processed!"
    ret_code=1
else
#    cat $CQL_FILE
    echo "Please execute command 'cqlsh -f $CQL_FILE $cqlsh_options' to adjust replication factor for keyspaces"
    echo "After that, execute following commands on each node of the cluster:"
    for i in "${to_repair[@]}" ; do
        echo "nodetool $nodetool_options repair -pr $i"
    done
fi

# remove already processed files
rm -f $SCHEMA_FILE $NODETOOL_FILE

exit $ret_code
