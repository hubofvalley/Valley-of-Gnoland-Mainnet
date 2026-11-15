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

- v1.7.0 Linux amd64 `gno`, `gnoland`, and `gnokey` executable hashes;
- the pinned v1.7.0 source tag commit `e4c2e7d9fe0f6f7aeeda54885ca1fe5cea991319`;
- the official launch genesis SHA-256 `ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0`;
- the effective `p2p.persistent_peers` value, repeated peer IDs, and service startup flags;
- local RPC network identity, `catching_up`, height, and live peer count;
- the official comparison RPC identity and observed height; and
- basic time and disk safety signals.

Expected executable hashes:

```text
gno      7d7771d899f8d6a266cf3c1fb2a9a997f2ad5791f3082dc0ee54711d9e5b5a79
gnoland  5e5525d53eabe65e6016d0669f5c7569a029c3ff6099105e0e5b7b7e0e461b51
gnokey   8cfe6bc58cbd010c8077e48a6eb18d0045e8f56289fe2b38eb699957a9bb9a0e
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

## v1.7.1 P2P buffer compatibility preflight

Before a rolling upgrade to Gnoland v1.7.1, Node Doctor reads the active
[p2p] section of config.toml and checks max_recv_buffer_bytes and
max_send_buffer_bytes without modifying either setting. Upstream v1.7.1
rejects a positive value below 8,454,144 bytes at startup (8 MiB + 64 KiB).
A missing override is compatible with the upstream default of 20 MiB.

An explicit value of 0 is accepted by Gnoland but disables the per-connection
buffer budget, so Node Doctor reports a safety WARN rather than a startup
failure. Values below the minimum and values that cannot be parsed safely
also produce WARN, including duplicate keys or sections. This bounded check
accepts plain decimal integers and single-line comments; it does not
fully parse TOML or certify the live P2P memory footprint.

These results are **upgrade-readiness diagnostics**, not evidence that the
currently pinned v1.7.0 node would fail to start. No runtime or config is
changed. See [the v1.7.1 release notes](https://github.com/gnolang/gno/releases/tag/v1.7.1)
and [the tagged P2P validation source](https://github.com/gnolang/gno/blob/v1.7.1/tm2/pkg/p2p/config/config.go).
