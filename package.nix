{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  # Everything below is overridable, which is the whole point of this package:
  # T3 Code's interesting builds are branches, not releases, and a branch that
  # changes the wire protocol needs a client built from that same branch.
  sources ? builtins.fromJSON (builtins.readFile ./sources.json),
  branch ? sources.branch,
  commit ? sources.commit,
  version ? sources.version,
  url ? sources.url,
  hash ? sources.hashes.${stdenv.hostPlatform.system} or (throw "nixpille-t3code: no hash recorded for ${stdenv.hostPlatform.system}"),
}:
let
  pname = "t3code";

  src = fetchurl {
    inherit url hash;
    name = "T3-Code-${version}-x86_64.AppImage";
  };

  # Pulled out so the .desktop file and the wrapper agree on the binary name.
  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # wrapType2 runs the image inside an FHS environment. Type 1 would leave the
  # bundled Electron without a loader and it would not start at all.
  extraPkgs =
    pkgs: with pkgs; [
      # The pairing token is stored through libsecret; without it the app starts
      # but silently forgets its connection on every restart.
      libsecret
      libnotify
      nss
      nspr
      at-spi2-atk
      at-spi2-core
      libdrm
      mesa
      libxkbcommon
      libglvnd
      # T3 Code drives agent CLIs as child processes and shells out to git for
      # every diff and checkpoint. Both must exist inside the FHS environment,
      # not merely on the host PATH.
      git
      openssh
    ];

  extraInstallCommands = ''
    # Reuse upstream's own desktop entry and icons when the image ships them,
    # so the launcher matches the real app rather than a hand-written guess.
    if [ -d ${appimageContents}/usr/share/icons ]; then
      mkdir -p $out/share
      cp -r ${appimageContents}/usr/share/icons $out/share/
    fi

    mkdir -p $out/share/applications
    if [ -f ${appimageContents}/t3code.desktop ]; then
      install -m444 ${appimageContents}/t3code.desktop $out/share/applications/${pname}.desktop
      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace-quiet 'Exec=AppRun' 'Exec=${pname}' \
        --replace-quiet 'Exec=t3code' 'Exec=${pname}'
    else
      cat > $out/share/applications/${pname}.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=T3 Code
    Comment=Agent harness control surface (branch ${branch})
    Exec=${pname} %U
    Terminal=false
    Categories=Development;
    StartupWMClass=T3 Code
    EOF
    fi
  '';

  meta = {
    description = "T3 Code desktop app built from upstream branch ${branch}";
    longDescription = ''
      Packaged from a prebuilt AppImage rather than from source: upstream is a
      pnpm + vite-plus monorepo whose desktop artifact also compiles a Rust
      helper and runs electron-builder, none of which reproduces comfortably
      inside a Nix sandbox.

      Built from branch ${branch} at commit ${commit}.
    '';
    homepage = "https://github.com/pingdotgg/t3code";
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    # Upstream LICENSE is MIT (Copyright (c) 2026 T3 Tools Inc.), which is also
    # what makes redistributing a build of it in this repo's releases fine.
    license = lib.licenses.mit;
  };
}
