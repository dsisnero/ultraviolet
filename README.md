# ultraviolet

Crystal shard that will track and port pieces of Charm's Ultraviolet terminal
library. This repo keeps the upstream Go implementation as a git submodule for
reference while porting behavior into Crystal.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     ultraviolet:
       github: dsisnero/ultraviolet
   ```

2. Run `shards install`

## Usage

```crystal
require "ultraviolet"
```

See `TUTORIAL.md` and `examples/helloworld.cr` for a minimal working example.

## Development

### Repo layout

- `src/` Crystal implementation (in progress)
- `spec/` Crystal specs
- `ultraviolet_go/` upstream Go Ultraviolet source (git submodule)
- `docs/go_test_parity.tsv` Go test parity manifest
- `docs/go_source_parity.tsv` Go exported-source parity manifest

### Upstream pin

Current upstream target:

`github.com/charmbracelet/ultraviolet v0.0.0-20260205113103-524a6607adb8`

### Syncing the upstream submodule

1. Update the submodule to the desired tag or commit:

   ```bash
   git -C ultraviolet_go fetch --tags
   git -C ultraviolet_go checkout <tag-or-sha>
   ```

2. Record the new submodule pointer:

   ```bash
   git add ultraviolet_go
   git commit -m "Update ultraviolet_go submodule"
   ```

### First-time setup

```bash
git submodule update --init --recursive
```

### Parity checks

Use these checks to verify Crystal stays aligned with upstream Go:

```bash
make check-go-test-parity
make check-go-source-parity
```

## Contributing

1. Fork it (<https://github.com/dsisnero/ultraviolet/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Dom](https://github.com/dsisnero) - creator and maintainer
