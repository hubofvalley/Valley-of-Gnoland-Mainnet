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

1. checks the selected service belongs to the current OS-user instance;
2. checks the official launch-release metadata and preserves the launch genesis pin;
3. stages source commit `e75fef82c02876a4df92ad6e325c5479b9532168`, the three immutable GHCR Linux amd64 image manifests, their expected binary layers, and compressed genesis without stopping the live node;
4. verifies each manifest digest, layer digest, extracted `/usr/bin/{gno,gnoland,gnokey}` SHA-256, reported tool version, compressed-genesis hash, and final genesis hash before cutover;
5. asks whether to create a persistent secrets/keyring backup; choosing no does not block installation;
6. for an existing Valley mainnet node, temporarily retains the previous runtime and preserves the existing validator/node `secrets/` directory exactly while rebuilding node data/config;
7. configures both official persistent peers and the selected local ports; and
8. starts the service and commits the cutover only after the local RPC reports `gnoland-1`. A failed startup gate triggers restoration of the previous runtime and all three tools.

The branch-tip commit and launch-release commit are deliberately separate. The launch release commit `9c8eb132e483d6fd324d92c193e629ad65a98a37` supplies the official genesis; the moving `chain/mainnet` tools are pinned to the immutable OCI manifests documented in [VERSIONS.json](../VERSIONS.json). Docker is not required.

## Safe update behavior

Option `1b` first compares installed source, genesis, and all three executable hashes to the reviewed target. If everything already matches, it exits with `Already up to date` and does not restart the service. Otherwise it stages the exact source commit, OCI binaries, and compressed genesis before cutover. An active `gnoland` service is stopped only when `gnoland` or its `GNOROOT` source actually changes. After restart, Valley waits for local RPC to report `gnoland-1`; a failed health gate restores the previous source and all previous binaries. If only `gno` and/or `gnokey` changes, the node is left running.

## Mainnet environment variables

The runtime scripts use mainnet-scoped variables so a shared shell profile cannot accidentally select another network's node:

- `GNOLAND_MAINNET_HOME`: node data directory; defaults to `$GNO_SOURCE_DIR/gnoland-data`.
- `GNOLAND_MAINNET_SERVICE_NAME`: systemd service name without the `.service` suffix; defaults to `gnoland`.
- `GNO_BIN`: installed `gno` executable; defaults to `$HOME/go/bin/gno`.

Unscoped legacy names are ignored. The service metadata remains `gnoland.service`, matching the default service selected by the installer.

## Menu options

The menu numbering and startup flow remain stable:

| Option | Behaviour |
|---|---|
| `1a` | Stage and safely install/re-install the reviewed mainnet runtime and all three OCI-extracted tools; persistent backup is optional and existing validator/node secrets are preserved. |
| `1b` | Compare, stage, verify, and transactionally update the reviewed source/tools with no-op detection, health gate, and rollback. |
| `1c` | Fail closed; no verified `gnoland-1` snapshot provider is configured. |
| `1d` | Add peers manually or restore both official persistent peers. |
| `1e` | Show local RPC, height, sync, peer, service, and disk status. |
| `1f` | Follow the selected service logs. |
| `1g` | Run the read-only Node Doctor. |
| `2a` | List, recover, or create a local operator key without overwriting a named key. |
| `2b` | Show the local consensus public key. |
| `2c` | Register a mainnet valoper candidate through `r/gnops/valopers.Register` using the same input → preview → confirm → broadcast flow as Valley of Gnoland Testnet. |
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
- Review the source commit, launch-release metadata, OCI refs/layers, genesis checksum, executable hashes, and service path before installation or update.
- Upstream `chain/mainnet` branch movement is informational; runtime scripts fetch the exact reviewed source commit rather than requiring it to remain the branch tip.
- OCI manifest, layer, executable, and genesis mismatches block install/update before service changes.
- Valley stores its shell exports in a marked `GRAND VALLEY GNOLAND MAINNET` block and does not delete unrelated shell-profile lines containing `go/bin`.
- UFW is never enabled from a hard-coded SSH port: the installer detects or asks for the SSH port, previews the rules, and requires `ENABLE-UFW` before activation.
- RPC and ABCI listeners default to loopback; only the P2P listener is configured for public binding by default.
- Never paste mnemonics or node secrets into chat or logs.
- The key-management menu does not prove validator status. Option `2c` is a separate transaction flow and always shows the exact registration call before asking for broadcast confirmation.
- Option `2c` uses the official mainnet parameters: `gno.land/r/gnops/valopers`, function `Register`, gas fee `1000000ugnot`, gas wanted `50000000`, chain ID `gnoland-1`, and `https://rpc.gno.land` as the remote.
- Matching the Testnet UX, option `2c` asks for the operator `g1...` address after the infrastructure type. Before preview/broadcast, Mainnet verifies that the entered address is controlled by the selected local `gnokey` entry.
- On Mainnet, option `2c` does not hard-block candidate registration on local RPC availability or `catching_up` state because the transaction is signed with `gnokey` and broadcast to `https://rpc.gno.land`. It still verifies `gno.land/r/sys/params.GetValoperRegisterFee()` and fails closed if the fee is nonzero or unreadable.
- Mainnet has no public faucet. Registration creates only a candidate profile; GovDAO approval through `r/sys/validators/v0` is still required for active-validator admission.
- The snapshot helper does not download, stop, modify, or replace node data unless a verified provider is added and reviewed.

## Verified endpoints

- Web: `https://gno.land`
- RPC/comparison RPC: `https://rpc.gno.land`
- Official persistent peers: `g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656`
- Valoper candidate realm: `r/gnops/valopers`
- Active validator realm: `r/sys/validators/v0`
