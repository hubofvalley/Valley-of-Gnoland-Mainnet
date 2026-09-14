# Valley of Gnoland Node Doctor

Node Doctor is a read-only health and configuration-drift inspector for a Gno.land `gnoland-1` mainnet node. It does not edit configuration, restart services, change firewall rules, replace binaries, or touch operator/consensus keys.

## Run

From this checkout:

```bash
bash resources/valleyofGnoland.sh doctor
bash resources/valleyofGnoland.sh doctor --json
bash resources/valleyofGnoland.sh doctor --strict
```

## Checks

The doctor checks:

- the published Linux amd64 `gnoland` and `gnokey` executable hashes;
- the pinned `chain/mainnet` source commit `31b6650a100d9baf14e7669f8f0df924f1f841e0`;
- the official mainnet genesis SHA-256 `ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0` in `misc/deployments/mainnet.gno.land/`;
- the two official persistent peers in `config.toml`;
- the service unit's `gnoland-1` chain ID and mainnet startup flags;
- local RPC network identity and the official comparison RPC;
- NTP synchronization when available; and
- a basic free-disk safety signal.

It does not change a node or infer validator admission. A candidate must use a separately verified mainnet funding and registration process; this Valley does not provide one.

## Exit codes

- `0`: no FAIL results; normal-mode WARN results are allowed.
- `1`: one or more FAIL results, or any WARN under `--strict`.
- `2`: invalid command-line or runtime-ref input.

Treat the report as diagnostic evidence. Review any remediation before changing an active node.
