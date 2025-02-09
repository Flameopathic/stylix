{
  pkgs,
  lib,
  config,
  options,
  ...
}:

let
  cfg = config.stylix;

in
{
  options.stylix = {
    polarity = lib.mkOption {
      type = lib.types.enum [
        "either"
        "light"
        "dark"
      ];
      default = "either";
      description = ''
        Use this option to force a light or dark theme.

        By default we will select whichever is ranked better by the genetic
        algorithm. This aims to get good contrast between the foreground and
        background, as well as some variety in the highlight colours.
      '';
    };

    image = lib.mkOption {
      type = with lib.types; nullOr (coercedTo package toString path);
      description = ''
        Wallpaper image.

        This is set as the background of your desktop environment, if possible,
        and used to generate a colour scheme if you don't set one manually.
      '';
      default = null;
    };

    imageScalingMode = lib.mkOption {
      type = lib.types.enum [
        "stretch"
        "fill"
        "fit"
        "center"
        "tile"
      ];
      default = "fill";
      description = ''
        Scaling mode for the wallpaper image.

        `stretch`
        : Stretch the image to cover the screen.

        `fill`
        : Scale the image to fill the screen, potentially cropping it.

        `fit`
        : Scale the image to fit the screen without being cropped.

        `center`
        : Center the image without resizing it.

        `tile`
        : Tile the image to cover the screen.
      '';
    };

    generated = {
      json = lib.mkOption {
        type = lib.types.package;
        description = "The output file produced by the palette generator.";
        readOnly = true;
        internal = true;
        # This *must* be the derivation running the palette generator,
        # and not anything indirect such as filling a template, otherwise
        # the output of the palette generator will not be protected from
        # garbage collection.
        default = pkgs.runCommand "palette.json" { } ''
          ${cfg.paletteGenerator}/bin/palette-generator \
            "${cfg.polarity}" \
            ${lib.escapeShellArg "${cfg.image}"} \
            "$out"
        '';
      };

      palette = lib.mkOption {
        type = lib.types.attrs;
        description = "The palette generated by the palette generator.";
        readOnly = true;
        internal = true;
        default = (lib.importJSON cfg.generated.json) // {
          author = "Stylix";
          scheme = "Stylix";
          slug = "stylix";
        };
      };

      fileTree = lib.mkOption {
        type = lib.types.raw;
        description = "The files storing the palettes in json and html.";
        readOnly = true;
        internal = true;
      };
    };

    base16Scheme = lib.mkOption {
      description = ''
        A scheme following the base16 standard.

        This can be a path to a file, a string of YAML, or an attribute set.
      '';
      type =
        with lib.types;
        oneOf [
          path
          lines
          attrs
        ];
      default = cfg.generated.palette;
      defaultText = lib.literalMD ''
        The colors used in the theming.

        Those are automatically selected from the background image by default,
        but could be overridden manually.
      '';
    };

    override = lib.mkOption {
      description = ''
        An override that will be applied to stylix.base16Scheme when generating
        config.lib.stylix.colors.

        Takes anything that a scheme generated by base16nix can take as argument
        to override.
      '';
      type = lib.types.attrs;
      default = { };
    };

    paletteGenerator = lib.mkOption {
      description = "The palette generator executable.";
      type = lib.types.package;
      internal = true;
      readOnly = true;
    };

    base16 = lib.mkOption {
      description = "The base16.nix library.";
      internal = true;
      readOnly = true;
    };
  };

  config = {
    # This attrset can be used like a function too, see
    # https://github.com/SenchoPens/base16.nix/blob/b390e87cd404e65ab4d786666351f1292e89162a/README.md#theme-step-22
    lib.stylix.colors = (cfg.base16.mkSchemeAttrs cfg.base16Scheme).override cfg.override;

    assertions = [
      {
        assertion = cfg.image != null || cfg.base16Scheme != null;
        message = "One of `stylix.image` or `stylix.base16Scheme` must be set";
      }
    ];

    stylix.generated.fileTree = {
      # The raw output of the palette generator.
      "stylix/generated.json" = {
        # We import the generated palette during evaluation but don't make it
        # a dependency, which means the garbage collector is free to delete it
        # immediately. Future evaluations may need to download, compile, and
        # run the palette generator from scratch to recreate the same palette.
        #
        # To improve performance, we can make the generated file part of the
        # system, which protects it from garbage collection and so increases
        # the potential for reuse between evaluations.
        #
        # The palette generator executable is not affected, and can still be
        # cleaned up as usual, so the overhead on system size is less than a
        # kilobyte.
        source = cfg.generated.json;

        # Only do this when `base16Scheme` is still the option default, which
        # is when the generated palette is used. Depending on the file in other
        # cases would force the palette generator to run when we never read the
        # output.
        #
        # Controlling this by comparing against the default value with == would
        # also force the palette generator to run, as we would have to evaluate
        # the default value to check for equality. To work around this, we
        # check only the priority of the resolved value. The priority of option
        # defaults is 1500 [1], and any value less than this means the user has
        # changed the option.
        #
        # [1]: https://github.com/NixOS/nixpkgs/blob/5f30488d37f91fd41f0d40437621a8563a70b285/lib/modules.nix#L1063
        enable = options.stylix.base16Scheme.highestPrio >= 1500;
      };

      # The current palette, with overrides applied.
      "stylix/palette.json".source = config.lib.stylix.colors {
        template = ./palette.json.mustache;
        extension = ".json";
      };

      # We also provide a HTML version which is useful for viewing the colors
      # during development.
      "stylix/palette.html".source = config.lib.stylix.colors {
        template = ./palette.html.mustache;
        extension = ".html";
      };
    };
  };
}
