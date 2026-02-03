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

TODO: Write usage instructions here

## Development

### Repo layout

- `src/` Crystal implementation (in progress)
- `spec/` Crystal specs
- `ultraviolet_go/` upstream Go Ultraviolet source (git submodule)

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

## Contributing

1. Fork it (<https://github.com/dsisnero/ultraviolet/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Dom](https://github.com/dsisnero) - creator and maintainer
