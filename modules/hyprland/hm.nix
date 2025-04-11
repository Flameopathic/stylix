{ config, lib, ... }:
let
  mkTarget =
    {
      name,
      humanName,
      autoEnable ? true,
      extraOptions ? { },
      configElements ? [ ],
      generalConfig ? null,
    }:
    let
      cfg = config.stylix.targets.${name};
    in
    {
      options.stylix.targets.${name} = {
        enable = config.lib.stylix.mkEnableTarget humanName autoEnable;
      } // extraOptions;

      config =
        let
          provideStylixArgs =
            args:
            (lib.mkMerge (
              map (
                arg:
                if arg == "cfg" then
                  {
                    inherit cfg;
                  }
                else
                  {
                    ${arg} = config.stylix.${arg};
                  }
              ) args
            ));
          provideAvailableStylixArgs =
            args:
            (lib.mkMerge (
              map (
                arg:
                if arg == "cfg" then
                  {
                    inherit cfg;
                  }
                else if (config.stylix.${arg} != null) then
                  {
                    ${arg} = config.stylix.${arg};
                  }
                else
                  { }
              ) args
            ));
          mkConfig =
            fn:
            let
              args = builtins.attrNames (lib.functionArgs fn);
            in
            fn (provideAvailableStylixArgs args);
          mkConditionalConfig =
            fn:
            let
              args = builtins.attrNames (lib.functionArgs fn);
            in
            if
              builtins.all (arg: (arg == "cfg") || (config.stylix.${arg} != null)) args
            then
              fn (provideStylixArgs args)
            else
              { };
        in
        lib.mkIf (config.stylix.enable && cfg.enable) (
          lib.mkMerge (
            (map mkConditionalConfig configElements)
            ++ lib.optional (generalConfig != null) (mkConfig generalConfig)
          )
        );
    };
in
mkTarget {
  name = "hyprland";
  humanName = "Hyprland";
  extraOptions.hyprpaper.enable = config.lib.stylix.mkEnableTarget "Hyprpaper" (
    config.stylix.image != null
  );
  configElements = [
    (
      { colors }:
      {
        wayland.windowManager.hyprland.settings =
          let
            rgb = color: "rgb(${color})";
            rgba = color: alpha: "rgba(${color}${alpha})";
          in
          {
            decoration.shadow.color = rgba colors.base00 "99";
            general = {
              "col.active_border" = rgb colors.base0D;
              "col.inactive_border" = rgb colors.base03;
            };
            group = {
              "col.border_inactive" = rgb colors.base03;
              "col.border_active" = rgb colors.base0D;
              "col.border_locked_active" = rgb colors.base0C;

              groupbar = {
                text_color = rgb colors.base05;
                "col.active" = rgb colors.base0D;
                "col.inactive" = rgb colors.base03;
              };
            };
            misc.background_color = rgb colors.base00;
          };
      }
    )
  ];
  generalConfig =
    { cfg }:
    (lib.mkIf cfg.hyprpaper.enable {
      services.hyprpaper.enable = true;
      stylix.targets.hyprpaper.enable = true;
      wayland.windowManager.hyprland.settings.misc.disable_hyprland_logo = true;
    });
}
