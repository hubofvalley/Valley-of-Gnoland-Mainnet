# Valley of Gnoland - Mainnet

Interactive terminal tooling by **Grand Valley** for installing, updating, inspecting, and managing a Gno.land `gnoland-1` mainnet node.

## Overview

[Gno.land](https://gno.land) is the Gno blockchain network maintained by the Gno community. This Valley installs the official Linux amd64 `chain/mainnet` release, keeps its source checkout pinned to the published mainnet branch, writes an isolated user-owned service configuration, and provides read-only status and diagnostic views.

This repository does not automate validator admission. Option `2c` can prepare, preview, sign through the local `gnokey` keyring, and broadcast the official mainnet valoper-candidate registration transaction after explicit operator confirmation. Registration only creates a candidate profile; GovDAO must still approve a proposal before the node joins the active validator set. Mainnet has no public faucet. The snapshot menu is deliberately fail-closed because no provider has been independently verified for `gnoland-1`.

## Network facts

| Field | Value |
|---|---|
| Chain ID | `gnoland-1` |
| Source branch | `chain/mainnet` |
| Source branch commit | `31b6650a100d9baf14e7669f8f0df924f1f841e0` |
| Release tag | `chain/mainnet` |
| Release tag commit | `9c8eb132e483d6fd324d92c193e629ad65a98a37` |
| Deployment path | `misc/deployments/mainnet.gno.land/` |
| Genesis SHA-256 | `ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0` |
| RPC and comparison RPC | `https://rpc.gno.land` |
| Web | `https://gno.land` |
| Faucet | none - mainnet has no public faucet |
| Valoper candidate realm | `r/gnops/valopers` |
| Active validator realm | `r/sys/validators/v0` |
| Official persistent peers | `g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656` |

Published Linux amd64 asset hashes are recorded in [VERSIONS.json](VERSIONS.json):

- `gnoland_linux_amd64`: `aa22a26823924642481fe7fc5e98eb9f42399b337f7afdac635d91403117db28`
- `gnokey_linux_amd64`: `38018492bcaa4de2f146d0566daf6507d9e811ee28547b963a015f51f9b14511`

## Getting started

Public launcher:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Mainnet/main/resources/valleyofGnoland.sh)
```

For a local checkout, run:

```bash
bash resources/valleyofGnoland.sh
```

Mainnet-specific overrides are `GNOLAND_MAINNET_HOME` for the node data
directory and `GNOLAND_MAINNET_SERVICE_NAME` for the systemd service name.
Their defaults are `$GNO_SOURCE_DIR/gnoland-data` and `gnoland`.

The read-only Node Doctor can run without entering the interactive menu:

```bash
bash resources/valleyofGnoland.sh doctor
bash resources/valleyofGnoland.sh doctor --json
bash resources/valleyofGnoland.sh doctor --strict
```

### Coordinated-upgrade release identity preflight

This repository also ships a read-only release-identity check for reviewing a
`gnoland` binary before it is considered for a coordinated upgrade:

```bash
bash resources/check_release_identity.sh --binary "$HOME/go/bin/gnoland"
bash resources/check_release_identity.sh --binary /path/to/candidate/gnoland --expect vX.Y.Z
```

The check reads the binary's own `gnoland version` output. It blocks binaries
that report `develop`, and it can require an exact reviewed version with
`--expect`. An `IDENTIFIED` result only proves that the artifact exposes the
expected release identity; it does **not** prove consensus compatibility or
replace the network's reviewed halt/restart procedure.

This distinction matters for the launch artifact currently pinned here.
Upstream [gnolang/gno#6177](https://github.com/gnolang/gno/pull/6177) reports
that the published `chain/mainnet` `gnoland` binary identifies itself as
`develop`. The current update command therefore remains a pinned launch-release
refresh, not a generic coordinated-upgrade executor. Do not repoint its release
constants at a consensus-changing release without a separately reviewed upgrade
procedure and release artifact.

Read [docs/usage.md](docs/usage.md) before using the install, update, service, or key-management options.

## Install and verification policy

Installation and update:

1. fetch the `chain/mainnet` source branch and require commit `31b6650a100d9baf14e7669f8f0df924f1f841e0`;
2. download the official `chain/mainnet` `genesis.json` into `misc/deployments/mainnet.gno.land/` and verify its SHA-256; and
3. download the published Linux amd64 `gnoland` and `gnokey` assets and verify their SHA-256 values before installation.

The branch commit and release tag commit are kept separate deliberately. The release assets identify the branch build, while `VERSIONS.json` records both the source pin and the tag metadata. No unpinned source build or unverified binary is accepted by the runtime scripts.

## Features

- Pinned `chain/mainnet` source checkout and official mainnet genesis verification.
- Verified Linux amd64 `gnoland` and `gnokey` release assets.
- Mainnet deployment path and official persistent peer configuration.
- Isolated service ownership checks, port-prefix selection, status, logs, and key management.
- Read-only Node Doctor with human and JSON output.
- Read-only release-identity preflight for coordinated-upgrade review.
- Fail-closed snapshot option until a provider is verified for `gnoland-1`.
- Mainnet valoper-candidate registration using the verified upstream `r/gnops/valopers.Register` procedure, with synced-node checks, transaction preview, and explicit broadcast confirmation.

## Documentation

- [Usage guide](docs/usage.md)
- [Manual node guide](docs/node-guide.md)
- [Node Doctor guide](docs/node-doctor.md)
- [Snapshot safety](docs/snapshots.md)
- [Version and verification record](VERSIONS.json)

## Upstream sources

- [Gno.land web](https://gno.land)
- [Gno source repository](https://github.com/gnolang/gno)
- [`chain/mainnet` source branch](https://github.com/gnolang/gno/tree/chain/mainnet)
- [Mainnet deployment files](https://github.com/gnolang/gno/tree/chain/mainnet/misc/deployments/mainnet.gno.land)
- [`chain/mainnet` release](https://github.com/gnolang/gno/releases/tag/chain/mainnet)

## Connect with Grand Valley

- GitHub: https://github.com/hubofvalley
- X: https://x.com/bacvalley
- Email: letsbuidltogether@grandvalleys.com

**Let's Buidl Gnoland Together - Grand Valley**
