self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.t3code;
  inherit (lib) mkEnableOption mkOption mkIf types literalExpression;

  # Only rebuild the package when something was actually overridden. Passing the
  # defaults back through .override would still work, but it makes the resulting
  # store path differ from the flake's own output for no reason, which is
  # confusing when comparing closures.
  overrides = lib.filterAttrs (_: v: v != null) {
    inherit (cfg)
      branch
      version
      url
      hash
      ;
  };

  package =
    if overrides == { } then cfg.package else cfg.package.override overrides;
in
{
  options.programs.t3code = {
    enable = mkEnableOption "T3 Code desktop app";

    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.t3code;
      defaultText = literalExpression "nixpille-t3code.packages.\${system}.t3code";
      description = "Base package, before any of the overrides below are applied.";
    };

    branch = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "t3code/codex-turn-mapping";
      description = ''
        Upstream branch this build came from. Recorded in the package metadata
        and the desktop entry.

        This does not select a build on its own -- there is nothing to select
        from. It labels the artifact named by {option}`url`, so that a machine
        pinned to a protocol-breaking branch says so in `nix-store -q --references`
        and in its launcher, instead of looking like a stock install.
      '';
    };

    version = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "0.0.33";
      description = "Version string of the artifact at {option}`url`.";
    };

    url = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Where to fetch the AppImage. Override together with {option}`hash` to
        pin a build other than the one in this flake's `sources.json` -- for
        example an artifact you built yourself and attached to your own release.
      '';
    };

    hash = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "sha256-AAAA...";
      description = "SRI hash of the artifact at {option}`url`.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ package ];

    assertions = [
      {
        assertion = (cfg.url == null) == (cfg.hash == null);
        message = ''
          programs.t3code: set `url` and `hash` together or not at all.
          Overriding one without the other either fetches an unpinned artifact
          or checks a hash against the wrong file.
        '';
      }
    ];
  };
}
