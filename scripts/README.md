# Scripts

Build and packaging scripts.

- **check-lib-sync.sh** — compare library modules that appear in more than
  one of minimicro-sysdisk `sys/lib` (canonical), soda `lib`, and
  raylib-miniscript `assets/lib`; report copies that differ, which is newest,
  and a `bbdiff` command to compare them. Files in sync are listed first.

Planned:

- **build-dist.sh** — assemble a distribution package: pull a fresh
  raylib-miniscript host for the target platform, rename it `soda`, and lay
  `lib/` and `assets/` out beside it so that a user can drop their game in and
  run it with no toolchain of any kind.
