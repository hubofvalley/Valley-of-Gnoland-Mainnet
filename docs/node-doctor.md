# Valley of Gnoland Node Doctor

Node Doctor is a read-only health and configuration-drift inspector for a Gno.land `gnoland-1` mainnet node. It does not edit configuration, restart services, change firewall rules, replace binaries, or touch keys.

## Run

```bash
bash resources/valleyofGnoland.sh doctor
bash resources/valleyofGnoland.sh doctor --json
bash resources/valleyofGnoland.sh doctor --strict
```

## Checks

The doctor checks:

- v1.7.1 Linux amd64 `gno`, `gnoland`, and `gnokey` executable hashes;
- the pinned v1.7.1 source tag commit `83431a7f0261882541a8a8dcf1643e6f246bbbe5`;
- the official launch genesis SHA-256 `ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0`;
- the effective `p2p.persistent_peers` value, repeated peer IDs, and service startup flags;
- local RPC network identity, `catching_up`, height, and live peer count;
- the official comparison RPC identity and observed height; and
- basic time and disk safety signals.

Expected executable hashes:

```text
gno      0f6c479d898a7fb2b37087a3697c084fd6c2babf1e082cbadc7b8fd9964e5209
gnoland  dbe89748f42a633a925153b16567a1229db9bd5004583ce64c80982e3e010565
gnokey   a3fa71fbb0c6e7789157f7d2eb9f1401ba86eb6ca3d237aba98fe0ec8628c674
```

Peer configuration is read without changing `config.toml`. The peer check only
accepts the active, single-line quoted `persistent_peers` string inside the
`[p2p]` section. Commented examples, settings in unrelated sections, missing
values, and unsupported forms must not produce a false PASS. Nonmatching or
unrecognized settings produce WARN; this check is not a full TOML validator.

Height comparison is observational; it does not invent a healthy-gap threshold or infer validator admission.

## Exit codes

- `0`: no FAIL results; normal WARN results are allowed.
- `1`: a FAIL result, or any WARN under `--strict`.
- `2`: invalid command-line or runtime-ref input.
