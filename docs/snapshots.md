# Snapshot safety

Snapshot application is disabled for `gnoland-1` mainnet.

No snapshot provider has been independently verified for the live network, so `resources/apply_snapshot.sh` fails closed before it downloads an archive, stops a service, or touches node data. Menu option `1c` remains visible to preserve the established Valley UX and numbering.

A provider may be added only after all of the following are independently checked:

1. the provider explicitly identifies the archive as `gnoland-1` state;
2. the archive layout is restricted to the intended node database and WAL paths;
3. chain and height metadata are available before activation;
4. a trustworthy checksum or equivalent verification metadata is published;
5. rollback behavior is regression-tested; and
6. the provider and all URLs are recorded in `VERSIONS.json` and reviewed.

Until then, use normal P2P synchronization with both official persistent peers:

```text
g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656
```
