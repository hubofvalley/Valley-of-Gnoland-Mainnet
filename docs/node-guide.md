# Gno.land `gnoland-1` mainnet node guide

This guide records the verified mainnet deployment facts used by Valley of Gnoland.

## Network facts

| Field | Value |
|---|---|
| Chain ID | `gnoland-1` |
| Source branch context | `chain/mainnet` |
| Runtime source tag | `v1.7.1` |
| Runtime source/tag commit | `83431a7f0261882541a8a8dcf1643e6f246bbbe5` |
| Launch genesis release/tag | `chain/mainnet` |
| Launch genesis release commit | `9c8eb132e483d6fd324d92c193e629ad65a98a37` |
| Deployment path | `misc/deployments/mainnet.gno.land/` |
| Genesis SHA-256 | `ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0` |
| Compressed genesis SHA-256 | `32a0fef8db3c71fa8360dee39a0149ee961be115ba81363a15f854e4aad446c9` |
| RPC | `https://rpc.gno.land` |
| Package approval status | `https://gpas.gno.land/` |
| Web | `https://gno.land` |
| Faucet | none - mainnet has no public faucet |
| Valoper candidate realm | `r/gnops/valopers` |
| Active validator realm | `r/sys/validators/v0` |
| Official persistent peers | `g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656` |

## v1.7.1 release assets

Valley downloads the official Linux amd64 assets from the v1.7.1 GitHub release and verifies `CHECKSUMS.txt` before any service cutover.

| Tool | Asset | SHA-256 |
|---|---|---|
| `gno` | `gno_linux_amd64` | `0f6c479d898a7fb2b37087a3697c084fd6c2babf1e082cbadc7b8fd9964e5209` |
| `gnoland` | `gnoland_linux_amd64` | `dbe89748f42a633a925153b16567a1229db9bd5004583ce64c80982e3e010565` |
| `gnokey` | `gnokey_linux_amd64` | `a3fa71fbb0c6e7789157f7d2eb9f1401ba86eb6ca3d237aba98fe0ec8628c674` |

`CHECKSUMS.txt` SHA-256: `8028057a68bc7ca87fd1e86f87d1eeb77c1bb69b064896b01ce44b48ee8a1642`.

## Source and launch genesis

The runtime source is pinned to the v1.7.1 tag commit:

```bash
git clone https://github.com/gnolang/gno.git "$HOME/gno"
git -C "$HOME/gno" fetch --depth 1 origin 83431a7f0261882541a8a8dcf1643e6f246bbbe5
git -C "$HOME/gno" checkout --detach --force 83431a7f0261882541a8a8dcf1643e6f246bbbe5
```

The launch genesis is a separate pin from the `chain/mainnet` release. No branch-tip movement substitutes for the reviewed runtime tag or genesis.

## Genesis

Valley uses the official compressed launch genesis:

```text
https://github.com/gnolang/gno/releases/download/chain/mainnet/genesis.json.gz
SHA-256: 32a0fef8db3c71fa8360dee39a0149ee961be115ba81363a15f854e4aad446c9
```

Store the decompressed file at `$HOME/gno/misc/deployments/mainnet.gno.land/genesis.json`; its SHA-256 must be `ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0`.

## Valley service layout

```text
source / GNOROOT:  ~/gno
mainnet deployment: ~/gno/misc/deployments/mainnet.gno.land/
node home:         ~/gno/gnoland-data
keyring:           ~/.config/gno
binaries:          ~/go/bin/gno, ~/go/bin/gnoland, ~/go/bin/gnokey
```

The scripts default to `gnoland.service`, keep RPC/ABCI loopback-only, and expose P2P for peer connectivity.

## Validation and candidate status

After startup, option `1e` or Node Doctor compares local RPC identity with `gnoland-1` and observes the public RPC at `https://rpc.gno.land`. A public endpoint response does not by itself prove local service health.

Option `2c` uses `gno.land/r/gnops/valopers.Register`, `1000000ugnot` gas fee, `50000000` gas wanted, chain ID `gnoland-1`, and `https://rpc.gno.land`. Local sync is advisory because the transaction is signed with `gnokey` and broadcast through the public mainnet RPC. Registration creates only a candidate profile; GovDAO must still approve admission to `r/sys/validators/v0`.

Snapshot application is disabled until a provider is independently verified for `gnoland-1`.
