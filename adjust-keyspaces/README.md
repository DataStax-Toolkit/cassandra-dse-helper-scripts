# Helper for adjusting replication factor of keyspaces

The `adjust-keyspaces.sh` script helps to adjust replication factor of Cassandra/DSE
system (or user-provided) keyspaces based on current cluster topology.  It generates a
file with CQL commands that could be executed after review.

Script adjusts replication for following keyspaces:
* for Cassandra and DSE: `system_auth`, `system_distributed`, `system_traces`;
* for DSE-only: `dse_security`, `solr_admin`, `dse_perf`, `dse_leases`, `dse_analytics`,
  `HiveMetaStore`, `dse_advrep`, `dse_system`.

## Usage

Script need to be executed on one of the nodes of cluster, as it uses `cqlsh` and
`nodetool` to find cluster topology, and extract a list of keyspaces.  Script may accept a
number of command line parameters, but could work without any if there is no
authentication setup, or other system parameters changed from defaults:

* `-h` - to get usage information;
* `-n replication_factor` - specify the desired replication factor for keyspaces.  If this
  parameter is bigger than number of nodes in specific DC, then the number of nodes is
  used instead;
* `-c cqlsh_options` - all options that need to be passed to `cqlsh`, such as,
  authentication, etc.;
* `-o nodetool_options` - all options that need to be passed to `nodetool`;
* optional list of keyspaces for which adjustment should be done.  If not specified,
  hardcoded list of system keyspaces is used.

Script will generate a file with CQL commands for changing replication factors of
keyspaces, and will print instructions how to use it, something like this:

```
SearchAnalytics has 3 nodes max RF=3
Please execute command 'cqlsh -f /tmp/fix-keyspaces-7111.cql ' to adjust replication factor for keyspaces
After that, execute following commands on each node of the cluster:
nodetool  repair -pr system_auth
nodetool  repair -pr system_distributed
nodetool  repair -pr dse_security
nodetool  repair -pr dse_perf
nodetool  repair -pr dse_leases
nodetool  repair -pr dse_analytics
nodetool  repair -pr "HiveMetaStore"
nodetool  repair -pr system_traces
```

**You must perform `nodetool repair` for all keyspaces for which change was made!**


## TODOs

* add an option for automatic execution of script with generated CQL commands.

