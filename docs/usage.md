# Valley of Gnoland usage

Valley of Gnoland targets the Gno.land `gnoland-1` mainnet. Run it as the node OS user:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Mainnet/main/resources/valleyofGnoland.sh)
```

From a local checkout:

```bash
bash resources/valleyofGnoland.sh
```

The non-interactive Node Doctor is read-only:

```bash
bash resources/valleyofGnoland.sh doctor
bash resources/valleyofGnoland.sh doctor --json
bash resources/valleyofGnoland.sh doctor --strict
```

## First install

Option `1a` asks for the node moniker, a two-digit local port prefix, an optional public P2P host, firewall preference, service name, and operator-key choice. It then:

1. backs up existing node secrets and the local keyring when present;
2. checks the selected service belongs to the current OS-user instance;
3. fetches `chain/mainnet` and checks out source commit `31b6650a100d9baf14e7669f8f0df924f1f841e0`;
4. downloads the official Linux amd64 `gnoland` and `gnokey` assets and verifies their hashes;
5. downloads the official mainnet genesis into `misc/deployments/mainnet.gno.land/` and verifies its SHA-256;
6. creates the node configuration and fresh node secrets;
7. configures both official persistent peers and the selected local ports; and
8. starts the service only after the local RPC reports `gnoland-1`.

The release tag commit `9c8eb132e483d6fd324d92c193e629ad65a98a37` and source branch commit are recorded separately in `VERSIONS.json`. Installation replaces the Valley node data under the selected node home, so review the backup location and confirmation prompt before continuing.

## Mainnet environment variables

The runtime scripts use mainnet-scoped variables so a shared shell profile cannot accidentally select another network's node:

- `GNOLAND_MAINNET_HOME`: node data directory; defaults to `$GNO_SOURCE_DIR/gnoland-data`.
- `GNOLAND_MAINNET_SERVICE_NAME`: systemd service name without the `.service` suffix; defaults to `gnoland`.

Unscoped legacy names are ignored. The service metadata remains `gnoland.service`, matching the default service selected by the installer.

## Menu options

The menu numbering and startup flow remain stable:

| Option | Behaviour |
|---|---|
| `1a` | Install or re-install the pinned mainnet node with verified release assets. |
| `1b` | Update an existing mainnet service with the pinned source and verified release assets. |
| `1c` | Fail closed; no verified `gnoland-1` snapshot provider is configured. |
| `1d` | Add peers manually or restore both official persistent peers. |
| `1e` | Show local RPC, height, sync, peer, service, and disk status. |
| `1f` | Follow the selected service logs. |
| `1g` | Run the read-only Node Doctor. |
| `2a` | List, recover, or create a local operator key without overwriting a named key. |
| `2b` | Show the local consensus public key. |
| `2c` | Register a mainnet valoper candidate through `r/gnops/valopers.Register` after sync, current-fee, local-key/address, input, preview, and explicit broadcast checks. |
| `2d` | Run a manually supplied query or show verified mainnet links. |
| `3a` | Restart the selected service. |
| `3b` | Stop the selected service. |
| `3c` | Delete the Valley node data after explicit confirmation; the keyring is retained. |
| `3d` | Back up node secrets to a mode-0600 archive. |
| `4` | Show verified endpoints and release facts. |
| `5` | Show the recommended read-only-to-install workflow. |
| `6` | Exit. |

## Safety boundaries

- Run as the node OS user, not with `sudo bash`.
- Review the source branch, release tag metadata, genesis checksum, binary hashes, and service path before installation or update.
- RPC and ABCI listeners default to loopback; only the P2P listener is configured for public binding by default.
- Never paste mnemonics or node secrets into chat or logs.
- The key-management menu does not prove validator status. Option `2c` is a separate transaction flow and always shows the exact registration call before asking for broadcast confirmation.
- Option `2c` uses the official mainnet parameters: `gno.land/r/gnops/valopers`, function `Register`, gas fee `1000000ugnot`, gas wanted `50000000`, chain ID `gnoland-1`, and `https://rpc.gno.land` as the remote.
- The operator `g1...` address is derived directly from the selected local `gnokey` entry instead of being typed manually, so the signer and operator identity cannot accidentally diverge in the Valley flow.
- Before collecting registration inputs, option `2c` queries `gno.land/r/sys/params.GetValoperRegisterFee()`. It proceeds only when the current on-chain registration fee is verified as zero; a nonzero or unreadable fee fails closed instead of inventing an unreviewed `--send` payment.
- Mainnet has no public faucet. The operator account must already hold enough GNOT to pay fees. Registration creates only a candidate profile; GovDAO approval through `r/sys/validators/v0` is still required for active-validator admission.
- The snapshot helper does not download, stop, modify, or replace node data unless a verified provider is added and reviewed.

## Verified endpoints

- Web: `https://gno.land`
- RPC/comparison RPC: `https://rpc.gno.land`
- Official persistent peers: `g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656`
- Valoper candidate realm: `r/gnops/valopers`
- Active validator realm: `r/sys/validators/v0`
