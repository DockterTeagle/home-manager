{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    getExe
    optionalString
    mkIf
    mkOption
    types
    ;

  cfg = config.programs.mcfly;

  tomlFormat = pkgs.formats.toml { };

  # These shell integrations all wrap `mcfly-fzf init` in an interactive shell
  # check, due to a buggy interactivity check in its initialization.
  # See: https://github.com/nix-community/home-manager/issues/6663
  # and https://github.com/bnprks/mcfly-fzf/issues/10

  bashIntegration = ''
    eval "$(${getExe cfg.package} init bash)"
  ''
  + optionalString cfg.fzf.enable ''
    if [[ $- =~ i ]]; then
      eval "$(${getExe cfg.mcflyFzfPackage} init bash)"
    fi
  '';

  fishIntegration = ''
    ${getExe cfg.package} init fish | source
  ''
  + optionalString cfg.fzf.enable ''
    ${getExe cfg.mcflyFzfPackage} init fish | source
  '';

  zshIntegration = ''
    eval "$(${getExe cfg.package} init zsh)"
  ''
  + optionalString cfg.fzf.enable ''
    if [[ -o interactive ]]; then
    eval "$(${getExe cfg.mcflyFzfPackage} init zsh)"
    fi
  '';

in
{
  meta.maintainers = [ ];

  imports = [
    (lib.mkChangedOptionModule # \
      [ "programs" "mcfly" "enableFuzzySearch" ] # \
      [ "programs" "mcfly" "fuzzySearchFactor" ] # \
      (
        config:
        let
          value = lib.getAttrFromPath [ "programs" "mcfly" "enableFuzzySearch" ] config;
        in
        if value then 2 else 0
      )
    )
  ];

  options.programs.mcfly = {
    enable = lib.mkEnableOption "mcfly";

    package = lib.mkPackageOption pkgs "mcfly" { };

    mcflyFzfPackage = lib.mkPackageOption pkgs "mcfly-fzf" { };

    settings = mkOption {
      type = tomlFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          colors = {
            menubar = {
              bg = "black";
              fg = "red";
            };
            darkmode = {
              prompt = "cyan";
              timing = "yellow";
              results_selection_fg = "cyan";
              results_selection_bg = "black";
              results_selection_hl = "red";
            };
          };
        }
      '';
      description = ''
        Settings written to {file}`~/.config/mcfly/config.toml`.

        Note, if your McFly database is currently in {file}`~/.mcfly`,
        then this option has no effect.
        Move the database to {file}`$XDG_DATA_DIR/mcfly/history.db` and
        remove {file}`~/.mcfly` to make the settings take effect. See
        <https://github.com/cantino/mcfly#database-location>.
      '';
    };

    keyScheme = mkOption {
      type = types.enum [
        "emacs"
        "vim"
      ];
      default = "emacs";
      description = ''
        Key scheme to use.
      '';
    };

    interfaceView = mkOption {
      type = types.enum [
        "TOP"
        "BOTTOM"
      ];
      default = "TOP";
      description = ''
        Interface view to use.
      '';
    };

    fzf.enable = lib.mkEnableOption "McFly fzf integration";

    enableLightTheme = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Whether to enable light mode theme.
      '';
    };

    fuzzySearchFactor = mkOption {
      default = 0;
      type = types.ints.unsigned;
      description = ''
        Whether to enable fuzzy searching.
        0 is off; higher numbers weight toward shorter matches.
        Values in the 2-5 range get good results so far.
      '';
    };

    enableBashIntegration = lib.hm.shell.mkBashIntegrationOption { inherit config; };

    enableFishIntegration = lib.hm.shell.mkFishIntegrationOption { inherit config; };

    enableZshIntegration = lib.hm.shell.mkZshIntegrationOption { inherit config; };
  };

  config = mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [ cfg.package ] ++ lib.optional cfg.fzf.enable cfg.package;

        # Oddly enough, McFly expects this in the data path, not in config.
        xdg.dataFile."mcfly/config.toml" = mkIf (cfg.settings != { }) {
          source = tomlFormat.generate "mcfly-config.toml" cfg.settings;
        };

        programs.bash.initExtra = mkIf cfg.enableBashIntegration bashIntegration;

        programs.zsh.initContent = mkIf cfg.enableZshIntegration zshIntegration;

        programs.fish.interactiveShellInit = mkIf cfg.enableFishIntegration fishIntegration;

        home.sessionVariables.MCFLY_KEY_SCHEME = cfg.keyScheme;

        home.sessionVariables.MCFLY_INTERFACE_VIEW = cfg.interfaceView;
      }

      (mkIf cfg.enableLightTheme { home.sessionVariables.MCFLY_LIGHT = "TRUE"; })

      (mkIf (cfg.fuzzySearchFactor > 0) {
        home.sessionVariables.MCFLY_FUZZY = cfg.fuzzySearchFactor;
      })
    ]
  );
}
