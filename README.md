# Valley of Gnoland - Mainnet

Interactive terminal tooling by **Grand Valley** for installing, updating, inspecting, and managing a Gno.land `gnoland-1` mainnet node.

## Overview

[Gno.land](https://gno.land) is the Gno blockchain network. This Valley manages the single Cosmos/CometBFT-style `gnoland` service, its pinned v1.7.1 source checkout, the official launch genesis, and the `gno`, `gnoland`, and `gnokey` command-line tools.

The tools come from the official v1.7.1 Linux amd64 release assets. Valley stages each asset, verifies the release `CHECKSUMS.txt` digest, verifies each executable SHA-256 and reported version, and performs a transactional cutover. The launch genesis remains pinned to the separate official `chain/mainnet` release because the runtime version tag is not a genesis release.

This repository does not automate validator admission. Option `2c` can prepare, preview, sign through the local `gnokey` keyring, and broadcast the official mainnet valoper-candidate registration transaction after explicit operator confirmation. Registration only creates a candidate profile; GovDAO must still approve a proposal before the node joins the active validator set. Mainnet has no public faucet. The snapshot menu is deliberately fail-closed because no provider has been independently verified for `gnoland-1`.

## Network facts

| Field | Value |
|---|---|
| Chain ID | `gnoland-1` |
| Source branch context | `chain/mainnet` |
| Runtime source tag | `v1.7.1` |
| Runtime source/tag commit | `83431a7f0261882541a8a8dcf1643e6f246bbbe5` |
| Launch genesis release/tag | `chain/mainnet` |
| Launch genesis release commit | `9c8eb132e483d6fd324d92c193e629ad65a98a37` |
| Runtime release | `v1.7.1` |
| Deployment path | `misc/deployments/mainnet.gno.land/` |
| Genesis SHA-256 | `ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0` |
| Compressed genesis SHA-256 | `32a0fef8db3c71fa8360dee39a0149ee961be115ba81363a15f854e4aad446c9` |
| RPC and comparison RPC | `https://rpc.gno.land` |
| Package approval status | `https://gpas.gno.land/` |
| Web | `https://gno.land` |
| Faucet | none - mainnet has no public faucet |
| Valoper candidate realm | `r/gnops/valopers` |
| Active validator realm | `r/sys/validators/v0` |
| Official persistent peers | `g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656` |

The release contract is recorded in [VERSIONS.json](VERSIONS.json). The v1.7.1 release asset set is:

| Tool | Asset | SHA-256 |
|---|---|---|
| `gno` | `gno_linux_amd64` | `0f6c479d898a7fb2b37087a3697c084fd6c2babf1e082cbadc7b8fd9964e5209` |
| `gnoland` | `gnoland_linux_amd64` | `dbe89748f42a633a925153b16567a1229db9bd5004583ce64c80982e3e010565` |
| `gnokey` | `gnokey_linux_amd64` | `a3fa71fbb0c6e7789157f7d2eb9f1401ba86eb6ca3d237aba98fe0ec8628c674` |

Release `CHECKSUMS.txt` SHA-256: `8028057a68bc7ca87fd1e86f87d1eeb77c1bb69b064896b01ce44b48ee8a1642`.

The v1.7.1 release is a rolling patch, not a coordinated halt: upstream records it as active on 2026-11-13. This repository pins the release source and SHA-256-verified native assets without changing the separately pinned genesis. Installation and update remain explicit operator actions. See [release behavior and configuration limits](docs/usage.md#v171-rolling-release-notes).

## Getting started

Public launcher:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Mainnet/main/resources/valleyofGnoland.sh)
```

For a local checkout:

```bash
bash resources/valleyofGnoland.sh
```

Mainnet-specific overrides are `GNOLAND_MAINNET_HOME`, `GNOLAND_MAINNET_SERVICE_NAME`, and `GNO_BIN`. The defaults are `$GNO_SOURCE_DIR/gnoland-data`, `gnoland`, and `$HOME/go/bin/gno`.

The read-only Node Doctor can run without entering the interactive menu:

```bash
bash resources/valleyofGnoland.sh doctor
bash resources/valleyofGnoland.sh doctor --json
bash resources/valleyofGnoland.sh doctor --strict
```

Read [docs/usage.md](docs/usage.md) before using install, update, service, or key-management options.

## Install and verification policy

Installation and update:

1. fetch the exact v1.7.1 source tag commit `83431a7f0261882541a8a8dcf1643e6f246bbbe5`;
2. verify the official v1.7.1 release metadata and all three asset digests;
3. stage the runtime assets and the compressed `chain/mainnet` genesis before stopping a service; and
4. verify executable versions, hashes, genesis, service ownership, and local RPC health before committing the cutover.

`1a` uses a stage-first safe cutover. Existing validator/node secrets are preserved during a Valley-managed reinstall; a persistent backup is offered but optional.

`1b` is transactional and no-op aware. It exits without restart when source, genesis, and all three tool hashes already match. A source or `gnoland` change can restart the service after staging; a failed startup/health gate restores the previous source and all previously installed tools.

## Features

- Pinned v1.7.1 source checkout and official launch genesis verification.
- Direct GitHub release-asset verification using the v1.7.1 release checksum file.
- Stage-first install/reinstall with optional persistent backup and validator/node identity preservation.
- Transactional no-op-aware source/tool updates with post-restart RPC health checks and rollback.
- Release-drift detection against current GitHub v1.7.1 metadata.
- Grand Valley-managed shell-profile block that does not delete unrelated `go/bin` lines.
- UFW setup that preserves the detected/configured SSH port and requires an explicit second confirmation.
- Mainnet deployment path and official persistent peer configuration.
- Isolated service ownership checks, port-prefix selection, status, logs, and key management.
- Read-only Node Doctor with human and JSON output.
- Fail-closed snapshot option until a provider is verified for `gnoland-1`.
- Mainnet valoper-candidate registration using the verified upstream `r/gnops/valopers.Register` procedure, with signer/address and on-chain registration-fee checks fail-closed.

## Validator / Key / Account Console

The `2.x` menu is an operator console rather than a raw-command shortcut. It can inspect local operator keys, account balance/account sequence, gas price, valoper candidate and active-validator state, and the local-vs-registered consensus identity. It also exposes confirmed valoper profile updates, guarded signing-key rotation, and an advanced read-only realm inspector. Option `2c` remains the validator-registration entry point.

## Documentation

- [Usage guide](docs/usage.md)
- [Manual node guide](docs/node-guide.md)
- [Node Doctor guide](docs/node-doctor.md)
- [Snapshot safety](docs/snapshots.md)
- [Version and verification record](VERSIONS.json)

## Upstream sources

- [Gno.land web](https://gno.land)
- [Gno source repository](https://github.com/gnolang/gno)
- [v1.7.1 source tag](https://github.com/gnolang/gno/tree/v1.7.1)
- [Mainnet deployment files](https://github.com/gnolang/gno/tree/chain/mainnet/misc/deployments/mainnet.gno.land)
- [v1.7.1 release](https://github.com/gnolang/gno/releases/tag/v1.7.1)
- [launch genesis release](https://github.com/gnolang/gno/releases/tag/chain%2Fmainnet)

## Connect with Grand Valley

- GitHub: https://github.com/hubofvalley
- X: https://x.com/bacvalley
- Email: letsbuidltogether@grandvalleys.com

**Let's Buidl Gnoland Together - Grand Valley**
