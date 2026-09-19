# Gno.land `gnoland-1` mainnet node guide

This guide records the verified mainnet deployment facts used by Valley of Gnoland.

## Network facts

| Field | Value |
|---|---|
| Chain ID | `gnoland-1` |
| Source branch | `chain/mainnet` |
| Source branch commit | `e75fef82c02876a4df92ad6e325c5479b9532168` |
| OCI-reported tool version | `heads/chain/mainnet.3444+e75fef82c` |
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
| `gno` | `ghcr.io/gnolang/gno/gno@sha256:307b3143ab53c025e9e51a0221fbed3c531517140654c91744e8de2b612fc2bc` | `sha256:676c5d4e100062b2caf1c629411581c6858fedd7b632c2248ca50b1c3204b5ff` | `423a64b605400882ac6ae016ef517b2465d64c49e71fd8d45d6d3a6ecfe0e87d` |
| `gnoland` | `ghcr.io/gnolang/gno/gnoland@sha256:ef516db1c3de66c93d502fbcb28978d8560ec64e33b7e6a1ae6bf9fdc446f0b0` | `sha256:b31ea46c33fd7cdb08f43975e079f5339e5f4ba672e121750a4ca6bce266ab63` | `5f568a5c96f9a0f9f20f5b0adbc72cc0d5c640e82bd3c7b129bb629758f029bc` |
| `gnokey` | `ghcr.io/gnolang/gno/gnokey@sha256:6fee82874a9d0506d7cc31e86bb2c2a1fb396d5933cf7bfbb05513589de67e71` | `sha256:fe63ba3901c28e13a488fe20efc6e3c8b3524b61f52645f5c89084a448955352` | `2d9f3019107403879e7b9f398deb15107945f33b91bc4ee85b938ff7f60b03cd` |

The extracted paths are `/usr/bin/gno`, `/usr/bin/gnoland`, and `/usr/bin/gnokey`. The source checkout and tools report `heads/chain/mainnet.3444+e75fef82c`.

## Source and launch-release metadata

The source checkout is pinned to the verified branch commit:

```bash
git clone https://github.com/gnolang/gno.git "$HOME/gno"
git -C "$HOME/gno" fetch --depth 1 origin e75fef82c02876a4df92ad6e325c5479b9532168
git -C "$HOME/gno" checkout --detach --force e75fef82c02876a4df92ad6e325c5479b9532168
```

The moving branch build and launch genesis are separate facts. Valley keeps the genesis from the official `chain/mainnet` release/tag at `9c8eb132e483d6fd324d92c193e629ad65a98a37`, while the three current tools come from the immutable OCI manifests above. No source build is substituted for the verified OCI binaries.

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
