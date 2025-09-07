{ self, lib, ... }:
{
  pkgs,
  config,
  system,
  nixConfig,
  ...
}:
{
  environment.shells = with pkgs; [
    bash
    zsh
  ];

  environment.systemPackages = with pkgs; [
    curl
    vim
    git
    gnupg
  ];
  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = system;

  nix = {
    settings = nixConfig;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm.bak";
  };

  environment.etc."hosts" = {
    # TODO Linking the hosts file to /etc/hosts in darwin doesn't work.
    enable = !pkgs.stdenv.hostPlatform.isDarwin;
    text = lib.textRegion {
      name = "davids-dotfiles/default";
      content = (builtins.readFile ./hosts);
    };
  };
}
