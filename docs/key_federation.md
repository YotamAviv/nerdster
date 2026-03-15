# Key Federation

Protocol design for supporting identity keys homed at organizations other than ONE-OF-US.NET.

**Primary doc:** [`oneofusv22/docs/key_federation.md`](../../oneofusv22/docs/key_federation.md)

## Nerdster-specific work items

See the "Protocol Changes" section in the primary doc. The Nerdster changes are:

- Accept optional `home` in the sign-in payload; default to `export.one-of-us.net` if absent.
- If `home != export.one-of-us.net`, fail with: *"Unsupported: Key Federation not yet implemented."*
