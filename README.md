# Valley of Gnoland - Mainnet

Interactive terminal tooling by **Grand Valley** for installing, updating, inspecting, and managing a Gno.land `gnoland-1` mainnet node.

## Overview

[Gno.land](https://gno.land) is the Gno blockchain network maintained by the Gno community. This Valley manages the single Cosmos/CometBFT-style `gnoland` service, its pinned mainnet source checkout, the official launch genesis, and the `gno`, `gnoland`, and `gnokey` command-line tools.

The tools are installed from official, immutable Linux amd64 GHCR OCI image manifests for the current reviewed versioned release, `v1.5.0`. That release is built from the same `e75fef82c02876a4df92ad6e325c5479b9532168` source commit that Valley already reviews for mainnet. Valley extracts only `/usr/bin/gno`, `/usr/bin/gnoland`, and `/usr/bin/gnokey`, verifies the manifest, binary layer, executable hash, and reported release identity, and does not require Docker. The launch genesis remains pinned separately to the official `chain/mainnet` genesis release because genesis identity and the moving runtime release are different contracts.

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
| Current versioned runtime release | `v1.5.0` at `e75fef82c02876a4df92ad6e325c5479b9532168` |
| OCI-reported tool version | `v1.5.0` |
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
| `gno` | `ghcr.io/gnolang/gno/gno@sha256:e9ad26286c98a1ab7fdddc59f478a13eda1abba80123fd18a8d46e0f3944036c` | `sha256:b00b81b81eb1b2e1336abf3571be1c5de3f0b304e68025134f21ab203c145656` | `a72b09348a7448fb83d1f608ecfefd044e8d12df4c0c70300c35453482edd7e4` |
| `gnoland` | `ghcr.io/gnolang/gno/gnoland@sha256:70f465a64dbe16e6e93e225967b5c1643d95f3361ef8edfd261445b7a870494d` | `sha256:e9a097249a947328c93223f9be06961b128ed8fdbfb537e767d73b9bebcd0d51` | `f88af6fd5485fe84ed6787fc06a19b07b4bf11aebb49f296c62990ffdd9a9765` |
| `gnokey` | `ghcr.io/gnolang/gno/gnokey@sha256:23f51c151b02776cee8ee8fbb799ff7bade7aea049d05563b126d196c1cdb0c0` | `sha256:79304ee04a936f559911c47d79dff8ccb1ce455387e7dc561ead36dcf8512ca8` | `f90bb28057eaae6301e58f7ce7dc2bed988d70be5f5e9d54aec2580d71b586b4` |

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
3. resolve each immutable `v1.5.0` GHCR Linux amd64 platform manifest, verify its manifest digest and expected binary layer digest, extract the fixed `/usr/bin/{gno,gnoland,gnokey}` member without Docker, and verify the executable SHA-256 plus the `v1.5.0` reported release identity; and
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
