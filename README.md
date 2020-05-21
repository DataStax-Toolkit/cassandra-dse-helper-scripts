This repository contains a number of auxiliary scripts for Cassandra or DSE that simplify
their maintenance.

What is included:

* [adjust-keyspaces](adjust-keyspaces) - script that helps to adjust replication factor of Cassandra/DSE
  system (or user-provided) keyspaces based on current cluster topology;
* [copy-cluster-topology-info](copy-cluster-topology-info) - script that helps to clone an entire cluster
  topology identically to another cluster;