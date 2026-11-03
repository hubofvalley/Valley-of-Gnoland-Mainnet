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
- an advisory when the active v1.7.0 TMKMS signer listener uses a Unix socket;
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

The `tmkms_uds_isolation` warning reads only the active, single-line quoted
`listen_addr` value in `[consensus.priv_validator.tmkms_listener]`. In
v1.7.0, Unix listeners set socket mode `0600` after binding and do not use
`allowed_kms_pubkeys`. A same-UID signer does not isolate signer credentials
and double-sign state from the node OS user; a separate-UID signer may need
special permissions to connect. The warning does not prove a vulnerable
deployment or inspect live socket permissions, signer processes, or keys.
Review the upstream [TMKMS guidance](https://github.com/gnolang/gno/blob/v1.7.0/gno.land/cmd/gnoland/TMKMS.md)
before changing signer architecture. Unsupported TOML forms are not certified.

Height comparison is observational; it does not invent a healthy-gap threshold or infer validator admission.

## Exit codes

- `0`: no FAIL results; normal WARN results are allowed.
- `1`: a FAIL result, or any WARN under `--strict`.
- `2`: invalid command-line or runtime-ref input.
