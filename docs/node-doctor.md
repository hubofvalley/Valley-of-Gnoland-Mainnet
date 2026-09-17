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
- local RPC network identity, node-reported `catching_up` state, current height, and live peer count;
- the official comparison RPC network identity and its observed height relative to the local node;
- NTP synchronization when available; and
- a basic free-disk safety signal.

The height comparison is deliberately observational. It reports the raw block difference against `https://rpc.gno.land` when both endpoints identify as `gnoland-1`, but it does not invent a healthy-gap threshold or treat the comparison RPC as a canonical network-head oracle.

It does not change a node or infer validator admission. Candidate registration is handled separately by menu option `2c`; Node Doctor does not check operator funding, sign transactions, broadcast transactions, or determine GovDAO admission.

## Exit codes

- `0`: no FAIL results; normal-mode WARN results are allowed.
- `1`: one or more FAIL results, or any WARN under `--strict`.
- `2`: invalid command-line or runtime-ref input.

Treat the report as diagnostic evidence. Review any remediation before changing an active node.
