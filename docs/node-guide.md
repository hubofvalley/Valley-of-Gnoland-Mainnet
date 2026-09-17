# Gno.land `gnoland-1` mainnet node guide

This guide records the verified mainnet deployment facts used by Valley of Gnoland.

## Network facts

| Field | Value |
|---|---|
| Chain ID | `gnoland-1` |
| Source branch | `chain/mainnet` |
| Source branch commit | `31b6650a100d9baf14e7669f8f0df924f1f841e0` |
| Release tag commit | `9c8eb132e483d6fd324d92c193e629ad65a98a37` |
| Deployment path | `misc/deployments/mainnet.gno.land/` |
| Genesis SHA-256 | `ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0` |
| RPC | `https://rpc.gno.land` |
| Web | `https://gno.land` |
| Faucet | none - mainnet has no public faucet |
| Valoper candidate realm | `r/gnops/valopers` |
| Active validator realm | `r/sys/validators/v0` |
| Official persistent peers | `g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656` |

Published Linux amd64 hashes:

```text
gnoland_linux_amd64  aa22a26823924642481fe7fc5e98eb9f42399b337f7afdac635d91403117db28
gnokey_linux_amd64   38018492bcaa4de2f146d0566daf6507d9e811ee28547b963a015f51f9b14511
```

## Source and release metadata

The source checkout is pinned to the current `chain/mainnet` branch commit. The release tag commit is recorded separately because the release metadata and branch build pin are distinct facts:

```bash
git clone https://github.com/gnolang/gno.git "$HOME/gno"
git -C "$HOME/gno" fetch --depth 1 origin refs/heads/chain/mainnet
git -C "$HOME/gno" checkout --detach --force 31b6650a100d9baf14e7669f8f0df924f1f841e0
```

Valley installs the official Linux amd64 release assets after checking their hashes. It does not substitute an unpinned source build.

## Genesis

The release genesis URL is:

```text
https://github.com/gnolang/gno/releases/download/chain/mainnet/genesis.json
```

Store it at:

```text
$HOME/gno/misc/deployments/mainnet.gno.land/genesis.json
```

Verify:

```text
ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0
```

## Valley service layout

These are operator-local paths:

```text
source / GNOROOT:  ~/gno
mainnet deployment: ~/gno/misc/deployments/mainnet.gno.land/
node home:         ~/gno/gnoland-data
keyring:           ~/.config/gno
binaries:          ~/go/bin/gnoland and ~/go/bin/gnokey
```

The mainnet scripts read `GNOLAND_MAINNET_HOME` for the node data directory and
`GNOLAND_MAINNET_SERVICE_NAME` for the systemd service name. They default to
`$HOME/gno/gnoland-data` and `gnoland`, respectively; the generated service is
therefore `gnoland.service` unless the operator selects another valid name.

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

The active validator realm is `r/sys/validators/v0`. Valley option `2c` implements the verified upstream candidate-registration flow against `gno.land/r/gnops/valopers` using `Register`, `1000000ugnot` gas fee, `50000000` gas wanted, chain ID `gnoland-1`, and `https://rpc.gno.land`. Its user-facing sequence mirrors Valley of Gnoland Testnet: operator key name, moniker, description, infrastructure type, operator `g1...` address, consensus `gpub1...` key, transaction preview, confirmation, then broadcast. Before preview/broadcast, Mainnet additionally verifies local sync, signer/address consistency, input format, and `gno.land/r/sys/params.GetValoperRegisterFee()==0`.

Mainnet has no public faucet. The operator key used to sign must control the supplied operator `g1...` address and that account must already hold enough GNOT to pay fees. A successful registration only creates a valoper candidate profile; a GovDAO proposal must still add the candidate to `r/sys/validators/v0` before the node becomes active.

Snapshot application is disabled until a provider is independently verified for `gnoland-1`.
