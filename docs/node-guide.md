# Gno.land `gnoland-1` mainnet node guide

This guide records the verified mainnet deployment facts used by Valley of Gnoland.

## Network facts

| Field | Value |
|---|---|
| Chain ID | `gnoland-1` |
| Source branch | `chain/mainnet` |
| Source branch commit | `e75fef82c02876a4df92ad6e325c5479b9532168` |
| Current versioned runtime release | `v1.5.0` at `e75fef82c02876a4df92ad6e325c5479b9532168` |
| OCI-reported tool version | `v1.5.0` |
| Launch release/tag commit | `9c8eb132e483d6fd324d92c193e629ad65a98a37` |
| Versioned launch release | `v1.2.0` at `9c8eb132e483d6fd324d92c193e629ad65a98a37` |
| Deployment path | `misc/deployments/mainnet.gno.land/` |
| Genesis SHA-256 | `ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0` |
| Compressed genesis SHA-256 | `32a0fef8db3c71fa8360dee39a0149ee961be115ba81363a15f854e4aad446c9` |
| RPC | `https://rpc.gno.land` |
| Web | `https://gno.land` |
| Faucet | none - mainnet has no public faucet |
| Valoper candidate realm | `r/gnops/valopers` |
| Active validator realm | `r/sys/validators/v0` |
| Official persistent peers | `g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656` |

## Immutable OCI tools

Valley installs Linux amd64 executables from official GHCR OCI platform manifests. It does not require Docker. For each image, the installer/updater verifies the manifest digest, downloads the expected compressed binary layer, verifies that layer digest, extracts the exact `/usr/bin/...` member, and verifies the executable hash and reported version.

| Tool | Immutable image manifest | Binary layer | Extracted binary SHA-256 |
|---|---|---|---|
| `gno` | `ghcr.io/gnolang/gno/gno@sha256:e9ad26286c98a1ab7fdddc59f478a13eda1abba80123fd18a8d46e0f3944036c` | `sha256:b00b81b81eb1b2e1336abf3571be1c5de3f0b304e68025134f21ab203c145656` | `a72b09348a7448fb83d1f608ecfefd044e8d12df4c0c70300c35453482edd7e4` |
| `gnoland` | `ghcr.io/gnolang/gno/gnoland@sha256:70f465a64dbe16e6e93e225967b5c1643d95f3361ef8edfd261445b7a870494d` | `sha256:e9a097249a947328c93223f9be06961b128ed8fdbfb537e767d73b9bebcd0d51` | `f88af6fd5485fe84ed6787fc06a19b07b4bf11aebb49f296c62990ffdd9a9765` |
| `gnokey` | `ghcr.io/gnolang/gno/gnokey@sha256:23f51c151b02776cee8ee8fbb799ff7bade7aea049d05563b126d196c1cdb0c0` | `sha256:79304ee04a936f559911c47d79dff8ccb1ce455387e7dc561ead36dcf8512ca8` | `f90bb28057eaae6301e58f7ce7dc2bed988d70be5f5e9d54aec2580d71b586b4` |

The extracted paths are `/usr/bin/gno`, `/usr/bin/gnoland`, and `/usr/bin/gnokey`. The pinned source checkout is `e75fef82c02876a4df92ad6e325c5479b9532168`, and the tools report `v1.5.0`.

## Source and launch-release metadata

The source checkout is pinned to the verified branch commit:

```bash
git clone https://github.com/gnolang/gno.git "$HOME/gno"
git -C "$HOME/gno" fetch --depth 1 origin e75fef82c02876a4df92ad6e325c5479b9532168
git -C "$HOME/gno" checkout --detach --force e75fef82c02876a4df92ad6e325c5479b9532168
```

The runtime release and launch genesis are separate facts. Valley keeps the genesis from the official `chain/mainnet` release/tag at `9c8eb132e483d6fd324d92c193e629ad65a98a37`, while the three current tools come from immutable `v1.5.0` OCI manifests built from the already-reviewed `e75fef82c02876a4df92ad6e325c5479b9532168` source commit. No source build is substituted for the verified OCI binaries.

## Genesis

Valley uses the official compressed launch-release genesis for transfer efficiency:

```text
https://github.com/gnolang/gno/releases/download/chain/mainnet/genesis.json.gz
SHA-256: 32a0fef8db3c71fa8360dee39a0149ee961be115ba81363a15f854e4aad446c9
```

Store the decompressed file at:

```text
$HOME/gno/misc/deployments/mainnet.gno.land/genesis.json
```

Its SHA-256 must be:

```text
ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0
```

The installer/updater verifies both the compressed archive and decompressed genesis before cutover.

## Valley service layout

These are operator-local paths:

```text
source / GNOROOT:  ~/gno
mainnet deployment: ~/gno/misc/deployments/mainnet.gno.land/
node home:         ~/gno/gnoland-data
keyring:           ~/.config/gno
binaries:          ~/go/bin/gno, ~/go/bin/gnoland, ~/go/bin/gnokey
```

The mainnet scripts read `GNOLAND_MAINNET_HOME`, `GNOLAND_MAINNET_SERVICE_NAME`, and `GNO_BIN`. They default to `$HOME/gno/gnoland-data`, `gnoland`, and `$HOME/go/bin/gno`; the generated service is `gnoland.service` unless the operator selects another valid name.

The menu selects a two-digit prefix for local listeners. It keeps RPC and ABCI on loopback and binds P2P on `0.0.0.0`; the selected service file starts with:

```text
gnoland start --chainid gnoland-1 --genesis <mainnet deployment>/genesis.json --skip-genesis-sig-verification
```

The official persistent peers are configured as one comma-separated value:

```text
g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656
```

## Validation and candidate status

After startup, option `1e` or Node Doctor compares the local RPC network to `gnoland-1` and compares public status with `https://rpc.gno.land`. A public endpoint response does not by itself prove local service health.

The active validator realm is `r/sys/validators/v0`. Valley option `2c` implements the verified upstream candidate-registration flow against `gno.land/r/gnops/valopers` using `Register`, `1000000ugnot` gas fee, `50000000` gas wanted, chain ID `gnoland-1`, and `https://rpc.gno.land`. Its user-facing sequence mirrors Valley of Gnoland Testnet: operator key name, moniker, description, infrastructure type, operator `g1...` address, consensus `gpub1...` key, transaction preview, confirmation, then broadcast. Local RPC sync remains advisory because registration is signed with `gnokey` and broadcast through the public mainnet RPC. Before preview/broadcast, Mainnet verifies signer/address consistency, input format, and `gno.land/r/sys/params.GetValoperRegisterFee()==0`.

Mainnet has no public faucet. The operator key must control the supplied operator `g1...` address and the account must already hold enough GNOT to pay fees. A successful registration creates only a valoper candidate profile; a GovDAO proposal must still add the candidate to `r/sys/validators/v0` before the node becomes active.

Snapshot application is disabled until a provider is independently verified for `gnoland-1`.
