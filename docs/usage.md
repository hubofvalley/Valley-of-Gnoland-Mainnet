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

## v1.8.0 mainnet compatibility gate

The official `gnoland-1` upgrade to `v1.8.0` completed on **2026-11-18** after block `1,651,500` (GovDAO proposal #19). The currently reviewed Grand Valley launcher and its install/update helpers still pin `v1.7.0`, which does **not** satisfy the post-halt `v1.8.0` requirement.

Until a **separately reviewed and validated** halt-aware runtime update replaces these pins, options `1a` and `1b` are deliberately **blocked before any local or remote helper is executed**. A message such as `Already up to date` for the pinned `v1.7.0` assets does not establish compatibility with the live chain. Read-only Node Doctor and status tools remain available. No binary, service, configuration, data, or network changes are made by this guard.

For historical replay from genesis, upstream documents a distinct two-version procedure: use `v1.7.1` up to the `v1.8.0` halt height, then `v1.8.0`. The blocked Grand Valley `v1.7.0` installer/updater are **not** a replay supervisor. Follow the [official mainnet upgrade ledger](https://github.com/gnolang/gno/blob/chain/mainnet/misc/deployments/mainnet.gno.land/UPGRADES.md) and [v1.8.0 release notes](https://github.com/gnolang/gno/releases/tag/v1.8.0); a reviewed recovery rehearsal is still required before any production upgrade.

## First install

Option `1a` checks service ownership, verifies the v1.7.0 release metadata, stages the exact v1.7.0 source tag, all three Linux amd64 release assets, and the compressed `chain/mainnet` genesis without stopping the live node. It verifies the release checksum file, each executable hash and version, genesis, service configuration, and local RPC before cutover. Existing validator/node secrets are preserved; a persistent backup is optional.

## Safe update behavior

Option `1b` compares installed source, genesis, and all three executable hashes to the reviewed target. If everything already matches, it exits with `Already up to date` and does not restart. Otherwise it stages the exact source tag, release assets, and genesis before cutover. A failed health gate restores the previous source and tools.

## Mainnet environment variables

- `GNOLAND_MAINNET_HOME`: node data directory, default `$GNO_SOURCE_DIR/gnoland-data`.
- `GNOLAND_MAINNET_SERVICE_NAME`: systemd service name, default `gnoland`.
- `GNO_BIN`: installed `gno` executable, default `$HOME/go/bin/gno`.

## Menu options

| Option | Behaviour |
|---|---|
| `1a` | Stage and safely install/re-install v1.7.0 runtime assets and source; persistent backup is optional. |
| `1b` | Compare, stage, verify, and transactionally update the v1.7.0 source/tools with no-op detection, health gate, and rollback. |
| `1c` | Fail closed; no verified `gnoland-1` snapshot provider is configured. |
| `1d` | Add peers manually or restore both official persistent peers. |
| `1e` | Show local RPC, height, sync, peer, service, and disk status. |
| `1f` | Follow service logs. |
| `1g` | Run the read-only Node Doctor. |
| `2a` | Manage a local operator key without overwriting a named key. |
| `2b` | Show local consensus identity. |
| `2c` | Register a mainnet valoper candidate through `r/gnops/valopers.Register` after explicit confirmation. |
| `3a` | Restart the selected service. |
| `3b` | Stop the selected service. |
| `3c` | Delete Valley node data after explicit confirmation; the keyring is retained. |
| `3d` | Back up node secrets. |
| `4` | Show verified endpoints and release facts. |
| `5` | Show guidelines. |
| `6` | Exit. |

## Safety boundaries

- Run as the node OS user, not with `sudo bash`.
- Review the v1.7.0 source tag, release checksum, executable hashes, genesis checksum, and service path before update.
- RPC and ABCI remain loopback-only; P2P is public by default for peer connectivity.
- Never paste mnemonics or node secrets into chat or logs.
- Mainnet has no public faucet. Candidate registration still requires GovDAO admission to `r/sys/validators/v0`.
- Snapshot application remains fail-closed without an independently verified provider.

## Package approval status

For a package submission, use the public mainnet review-stage page: <https://gpas.gno.land/>. It intentionally omits security-sensitive details.

## Verified endpoints

- Web: `https://gno.land`
- RPC: `https://rpc.gno.land`
- Package approval status: `https://gpas.gno.land/`
- Persistent peers: `g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656`
- Candidate realm: `r/gnops/valopers`
- Active validator realm: `r/sys/validators/v0`
