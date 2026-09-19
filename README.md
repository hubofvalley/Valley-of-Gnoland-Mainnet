# Valley of Gnoland - Mainnet

Interactive terminal tooling by **Grand Valley** for installing, updating, inspecting, and managing a Gno.land `gnoland-1` mainnet node.

## Overview

[Gno.land](https://gno.land) is the Gno blockchain network maintained by the Gno community. This Valley manages the single Cosmos/CometBFT-style `gnoland` service, its pinned mainnet source checkout, the official launch genesis, and the `gno`, `gnoland`, and `gnokey` command-line tools.

The tools are installed from official, immutable Linux amd64 GHCR OCI image manifests built from the `chain/mainnet` branch. Valley extracts only `/usr/bin/gno`, `/usr/bin/gnoland`, and `/usr/bin/gnokey`, verifies the manifest, binary layer, and executable hashes, and does not require Docker. The launch genesis remains pinned to the official `chain/mainnet` release because the moving branch tip is not a genesis release.

This repository does not automate validator admission. Option `2c` can prepare, preview, sign through the local `gnokey` keyring, and broadcast the official mainnet valoper-candidate registration transaction after explicit operator confirmation. Registration only creates a candidate profile; GovDAO must still approve a proposal before the node joins the active validator set. Mainnet has no public faucet. The snapshot menu is deliberately fail-closed because no provider has been independently verified for `gnoland-1`.

## Network facts

| Field | Value |
|---|---|
| Chain ID | `gnoland-1` |
| Source branch | `chain/mainnet` |
| Source branch commit | `e75fef82c02876a4df92ad6e325c5479b9532168` |
| Launch release tag | `chain/mainnet` |
| Launch release/tag commit | `9c8eb132e483d6fd324d92c193e629ad65a98a37` |
| Versioned launch release | `v1.2.0` at `9c8eb132e483d6fd324d92c193e629ad65a98a37` |
| OCI-reported tool version | `heads/chain/mainnet.3444+e75fef82c` |
| Deployment path | `misc/deployments/mainnet.gno.land/` |
| Genesis SHA-256 | `ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0` |
| Compressed genesis SHA-256 | `32a0fef8db3c71fa8360dee39a0149ee961be115ba81363a15f854e4aad446c9` |
| RPC and comparison RPC | `https://rpc.gno.land` |
| Web | `https://gno.land` |
| Faucet | none - mainnet has no public faucet |
| Valoper candidate realm | `r/gnops/valopers` |
| Active validator realm | `r/sys/validators/v0` |
| Official persistent peers | `g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656` |

The immutable platform manifests, binary layers, extracted paths, and executable hashes are recorded in [VERSIONS.json](VERSIONS.json):

| Tool | Immutable image | Binary layer | Executable SHA-256 |
|---|---|---|---|
| `gno` | `ghcr.io/gnolang/gno/gno@sha256:307b3143ab53c025e9e51a0221fbed3c531517140654c91744e8de2b612fc2bc` | `sha256:676c5d4e100062b2caf1c629411581c6858fedd7b632c2248ca50b1c3204b5ff` | `423a64b605400882ac6ae016ef517b2465d64c49e71fd8d45d6d3a6ecfe0e87d` |
| `gnoland` | `ghcr.io/gnolang/gno/gnoland@sha256:ef516db1c3de66c93d502fbcb28978d8560ec64e33b7e6a1ae6bf9fdc446f0b0` | `sha256:b31ea46c33fd7cdb08f43975e079f5339e5f4ba672e121750a4ca6bce266ab63` | `5f568a5c96f9a0f9f20f5b0adbc72cc0d5c640e82bd3c7b129bb629758f029bc` |
| `gnokey` | `ghcr.io/gnolang/gno/gnokey@sha256:6fee82874a9d0506d7cc31e86bb2c2a1fb396d5933cf7bfbb05513589de67e71` | `sha256:fe63ba3901c28e13a488fe20efc6e3c8b3524b61f52645f5c89084a448955352` | `2d9f3019107403879e7b9f398deb15107945f33b91bc4ee85b938ff7f60b03cd` |

## Getting started

Public launcher:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Mainnet/main/resources/valleyofGnoland.sh)
```

For a local checkout, run:

```bash
bash resources/valleyofGnoland.sh
```

Mainnet-specific overrides are `GNOLAND_MAINNET_HOME` for the node data directory, `GNOLAND_MAINNET_SERVICE_NAME` for the systemd service name, and `GNO_BIN` for the installed `gno` path. Defaults are `$GNO_SOURCE_DIR/gnoland-data`, `gnoland`, and `$HOME/go/bin/gno`.

The read-only Node Doctor can run without entering the interactive menu:

```bash
bash resources/valleyofGnoland.sh doctor
bash resources/valleyofGnoland.sh doctor --json
bash resources/valleyofGnoland.sh doctor --strict
```

Read [docs/usage.md](docs/usage.md) before using install, update, service, or key-management options.

## Install and verification policy

Installation and update:

1. fetch the exact reviewed source commit `e75fef82c02876a4df92ad6e325c5479b9532168`; later branch movement is reported and never substitutes for the reviewed pin;
2. verify the official `chain/mainnet` release metadata and keep its launch genesis pinned to release commit `9c8eb132e483d6fd324d92c193e629ad65a98a37`;
3. resolve each immutable GHCR platform manifest, verify its manifest digest and expected binary layer digest, extract the fixed `/usr/bin/{gno,gnoland,gnokey}` member without Docker, and verify the executable SHA-256 plus reported tool version; and
4. stage source, tools, and compressed genesis before the transactional cutover.

`1a` uses a stage-first safe cutover. Existing validator/node secrets are preserved during a Valley-managed reinstall; a persistent backup is offered but optional. The previous runtime is retained temporarily until the replacement passes its `gnoland-1` RPC startup gate.

`1b` is transactional and no-op aware. It exits without restart when source, genesis, and all three tool hashes already match. A source or `gnoland` change can restart the service after staging; `gno`-only or `gnokey`-only changes do not restart `gnoland`. A failed startup/health gate restores the previous source and all previously installed tools.

## Features

- Pinned `chain/mainnet` source checkout and official launch genesis verification.
- Immutable GHCR OCI manifest/layer verification and Docker-free extraction of `gno`, `gnoland`, and `gnokey`.
- Stage-first install/reinstall with optional persistent backup and validator/node identity preservation.
- Transactional no-op-aware source/tool updates with post-restart RPC health checks and rollback.
- Release-drift detection against current GitHub launch-release metadata.
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
- [`chain/mainnet` source branch](https://github.com/gnolang/gno/tree/chain/mainnet)
- [Mainnet deployment files](https://github.com/gnolang/gno/tree/chain/mainnet/misc/deployments/mainnet.gno.land)
- [`chain/mainnet` launch release](https://github.com/gnolang/gno/releases/tag/chain/mainnet)
- [Gno GHCR packages](https://github.com/orgs/gnolang/packages?repo_name=gno)

## Connect with Grand Valley

- GitHub: https://github.com/hubofvalley
- X: https://x.com/bacvalley
- Email: letsbuidltogether@grandvalleys.com

**Let's Buidl Gnoland Together - Grand Valley**
