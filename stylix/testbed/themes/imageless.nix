{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (config.stylix.inputs) tinted-schemes;
in
{
  home-manager.sharedModules = lib.singleton {
    stylix = {
      enable = true;
      base16Scheme = "${tinted-schemes}/base16/catppuccin-macchiato.yaml";
      polarity = "dark";
      cursor = {
        name = "Vanilla-DMZ";
        package = pkgs.vanilla-dmz;
        size = 32;
      };
    };
  };
}
