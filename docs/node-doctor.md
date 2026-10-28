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

- the SHA-256 digests of official `v1.5.1` Linux amd64 release assets, while recognizing the older Grand Valley-reviewed OCI-extracted artifacts as legacy;
- the official `v1.5.1` source commit `07e44776c26187830b7dcbd2454991b5a1960378`, while recognizing the older reviewed `chain/mainnet` source pin;
- the official launch genesis SHA-256 `ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0` in `misc/deployments/mainnet.gno.land/`;
- the two official persistent peers in `config.toml`;
- the service unit's `gnoland-1` chain ID and mainnet startup flags;
- local RPC network identity, node-reported `catching_up` state, current height, and live peer count;
- the official comparison RPC network identity and its observed height relative to the local node;
- NTP synchronization when available; and
- a basic free-disk safety signal.

Official `v1.5.1` Linux amd64 executable SHA-256 values (from the [upstream release assets](https://github.com/gnolang/gno/releases/tag/v1.5.1)):

```text
gno      fd70e8173b98dd7ac73b45d8d1cdcb446dbf11ab1f7e3f34e29336066f8e1485
gnoland  ca2319a1a7ebf07fed9268403b0a6ac5e474eee8d0da4babe9b4fb2f8eff2241
gnokey   73a4cc744fc02a0e8aa05ab77be730d7bb96192f5a6ae6a63d5f01e1a6713477
```

The older Grand Valley-reviewed `e75fef82c` OCI-extracted tool hashes remain recognized:

```text
gno      423a64b605400882ac6ae016ef517b2465d64c49e71fd8d45d6d3a6ecfe0e87d
gnoland  5f568a5c96f9a0f9f20f5b0adbc72cc0d5c640e82bd3c7b129bb629758f029bc
gnokey   2d9f3019107403879e7b9f398deb15107945f33b91bc4ee85b938ff7f60b03cd
```

Node Doctor reports **PASS** for each verified `v1.5.1` asset/source commit, **WARN** for each known legacy artifact/source commit, and **FAIL** for unrecognized digests/commits. The legacy branch-build artifacts remain recognized but do not include the P2P reliability changes in the official `v1.5.1` rolling patch. `--strict` exits nonzero on WARN, as before. Each component is checked independently; this is not an attestation of full cross-component release consistency.

This is diagnostic-only: the installer/updater pins and the JSON `source_commit` metadata remain the repository's older reviewed deployment baseline. No binaries, services, or network settings are changed. The [mainnet upgrade ledger](https://github.com/gnolang/gno/blob/chain/mainnet/misc/deployments/mainnet.gno.land/UPGRADES.md) records `v1.5.1` as the active rolling release and explicitly states that mainnet skips `v1.6.0`; do not infer network activation from the latest published tag.

The height comparison is deliberately observational. It reports the raw block difference against `https://rpc.gno.land` when both endpoints identify as `gnoland-1`, but it does not invent a healthy-gap threshold or treat the comparison RPC as a canonical network-head oracle.

It does not change a node or infer validator admission. Candidate registration is handled separately by menu option `2c`; Node Doctor does not check operator funding, sign transactions, broadcast transactions, or determine GovDAO admission.

## Exit codes

- `0`: no FAIL results; normal-mode WARN results are allowed.
- `1`: one or more FAIL results, or any WARN under `--strict`.
- `2`: invalid command-line or runtime-ref input.

Treat the report as diagnostic evidence. Review any remediation before changing an active node.
