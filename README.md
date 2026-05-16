# dotfiles-common

Common dotfile configuration for most of my machines.

Structure:

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
