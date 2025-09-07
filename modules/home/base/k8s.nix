{ ... }:
{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    ;
in
{
  options = {
    davids.k8stools = {
      enable = mkEnableOption "Kubernetes tools";
    };
  };
  config = mkIf config.davids.k8stools.enable {
    home.packages = with pkgs; [
      kind
      kubectl
      kubernetes-helm
      k9s
      fluxcd
      kustomize
      skopeo
      oras
    ];
    programs.zsh.shellAliases = {
      k = "kubectl";
    };
  };
}
