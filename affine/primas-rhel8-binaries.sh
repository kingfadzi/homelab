#!/usr/bin/env bash

# yarn workspace @affine/server prisma --version
# prisma                  : 5.16.2
# @prisma/client          : 5.16.2
# Computed binaryTarget   : rhel-openssl-1.1.x
# Operating System        : linux
# Architecture            : x64
# Node.js                 : v18.20.2
# Query Engine (Node-API) : libquery-engine 34ace0eb2704183d2c05b60b52fba5c43c13f303 (at node_modules/@prisma/engines/libquery_engine-rhel-openssl-1.1.x.so.node)
# Schema Engine           : schema-engine-cli 34ace0eb2704183d2c05b60b52fba5c43c13f303 (at node_modules/@prisma/engines/schema-engine-rhel-openssl-1.1.x)
# Schema Wasm             : @prisma/prisma-schema-wasm 5.16.0-24.34ace0eb2704183d2c05b60b52fba5c43c13f303
# Default Engines Hash    : 34ace0eb2704183d2c05b60b52fba5c43c13f303
# Studio                  : 0.502.0
# Preview Features        : metrics, nativeDistinct, tracing, relationJoins

wget https://binaries.prisma.sh/all_commits/393aa359c9ad4a4bb28630fb5613f9c281cde053/rhel-openssl-1.0.x/query-engine.gz
wget https://binaries.prisma.sh/all_commits/393aa359c9ad4a4bb28630fb5613f9c281cde053/rhel-openssl-1.0.x/migration-engine.gz
wget https://binaries.prisma.sh/all_commits/393aa359c9ad4a4bb28630fb5613f9c281cde053/rhel-openssl-1.0.x/introspection-engine.gz
wget https://binaries.prisma.sh/all_commits/393aa359c9ad4a4bb28630fb5613f9c281cde053/rhel-openssl-1.0.x/prisma-fmt.gz

wget https://binaries.prisma.sh/all_commits/393aa359c9ad4a4bb28630fb5613f9c281cde053/rhel-openssl-1.0.x/libquery_engine.so.node.sha256
