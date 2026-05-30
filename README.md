# dotfiles-common

Common dotfile configuration for most of my machines.

## Documentation

- [Library Functions](lib/README.md)

## Flake Outputs

This flake exports the following top-level structures:

- `packages`: Custom packages built per system from the `pkgs/` directory.
- `lib`: Reusable [Library Functions](lib/README.md) and utilities.
- `systemModules`: Reusable system-wide modules mapped from `modules/system/`.
- `homeModules`: Reusable Home Manager modules mapped from `modules/home/`.
- `devenvModules`: Reusable modules for `devenv.sh` environments mapped from `modules/devenv/`.

## Development

Folder structure:

```text
├── lib                    # library functions
├── modules
│   ├── darwin             # reusable modules for macOS
│   ├── nixos              # reusable modules for nixOS
│   ├── system             # reusable modules for unix-like systems (nixOS, darwin, etc.)
│   ├── devenv             # reusable modules for my projects managed with devenv.sh
│   └── home               # reusable modules for home manager
└── pkgs                   # packages
```
