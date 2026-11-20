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
- the effective `[rpc] unsafe` setting (privileged mempool flush and profiler routes),
  with an advisory when the configured value is enabled or cannot be verified;
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

The RPC unsafe check reads only the active `[rpc]` section in `config.toml`.
It reports PASS for one explicit `unsafe = false` setting; WARN for `true`,
missing, duplicate, or unsupported settings. Upstream defaults to `false`,
but Node Doctor does not treat a missing entry as proof of the effective value.
When enabled, `unsafe_*` RPC methods include mempool flushing and CPU/heap
profiler controls with caller-supplied output paths. This is a **configuration
exposure advisory**, not proof that an endpoint is reachable from the Internet:
network binding, firewalls, proxies, and authentication remain separate.
The check never changes RPC configuration. See the [Gnoland v1.7.0 RPC config](https://github.com/gnolang/gno/blob/v1.7.0/tm2/pkg/bft/rpc/config/config.go)
and [route definitions](https://github.com/gnolang/gno/blob/v1.7.0/tm2/pkg/bft/rpc/core/routes.go).

Height comparison is observational; it does not invent a healthy-gap threshold or infer validator admission.

## Exit codes

- `0`: no FAIL results; normal WARN results are allowed.
- `1`: a FAIL result, or any WARN under `--strict`.
- `2`: invalid command-line or runtime-ref input.
