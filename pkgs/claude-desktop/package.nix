# Anthropic's official claude-desktop .deb, repackaged. Adapted from
# github.com/kubastick/claude-desktop-nixos (MIT, see ./LICENSE). The deb bundles a
# newer Electron than nixpkgs, so its binaries are kept and patched with autoPatchelfHook.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  addDriverRunpath,

  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libcap_ng,
  libdrm,
  libgbm,
  libseccomp,
  libxkbcommon,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,

  # dlopen'd at runtime
  libGL,
  libayatana-appindicator,
  libnotify,
  libpulseaudio,
  libsecret,
  libuuid,
  vulkan-loader,
  wayland,
  libxtst,

  gjs,
  xdg-utils,
  qemu_kvm,
  virtiofsd,
}:

let
  source = lib.importJSON ./sources.json;

  runtimeLibs = [
    libGL
    libayatana-appindicator
    libnotify
    libpulseaudio
    libsecret
    libuuid
    vulkan-loader
    wayland
    libxtst
  ];

  # qemu and virtiofsd are for Cowork's VM.
  runtimeBins = [
    xdg-utils
    qemu_kvm
    virtiofsd
  ];
in
stdenv.mkDerivation {
  pname = "claude-desktop";
  inherit (source) version;

  src = fetchurl { inherit (source) url sha256; };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libcap_ng
    libdrm
    libgbm
    libseccomp
    libxkbcommon
    nspr
    nss
    pango
    pipewire
    stdenv.cc.cc.lib
    systemd
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
  ];

  runtimeDependencies = runtimeLibs;

  # postFixup builds the one wrapper, with gappsWrapperArgs spliced in.
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile "$src" | tar -x --no-same-owner --no-same-permissions
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    app=$out/lib/claude-desktop
    mkdir -p $out/lib $out/bin
    cp -a usr/lib/claude-desktop $app
    cp -a usr/share $out/share
    rm -rf $out/share/lintian

    # SUID helper; NixOS uses unprivileged user namespaces instead.
    rm -f $app/chrome-sandbox

    # What the deb's postinst would otherwise install: MIME types and the GNOME search provider.
    install -Dm644 $app/resources/linux-mime/com.anthropic.Claude.xml \
      $out/share/mime/packages/com.anthropic.Claude.xml
    sp=$app/resources/gnome-search-provider
    install -Dm644 $sp/com.anthropic.Claude.search-provider.ini \
      $out/share/gnome-shell/search-providers/com.anthropic.Claude.search-provider.ini
    install -Dm644 $sp/com.anthropic.Claude.SearchProvider.service \
      $out/share/dbus-1/services/com.anthropic.Claude.SearchProvider.service
    substituteInPlace $out/share/dbus-1/services/com.anthropic.Claude.SearchProvider.service \
      --replace-fail /usr/bin/gjs ${lib.getExe' gjs "gjs"} \
      --replace-fail /usr/lib/claude-desktop $app

    if [ -x $app/resources/bin/ccd ]; then
      ln -s $app/resources/bin/ccd $out/bin/ccd
    fi

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath runtimeBins} \
      --prefix LD_LIBRARY_PATH : ${addDriverRunpath.driverLink}/lib:${lib.makeLibraryPath runtimeLibs} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
  '';

  meta = {
    description = "Claude desktop app: Chat, Cowork and Claude Code";
    homepage = "https://code.claude.com/docs/en/desktop-linux";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "claude-desktop";
  };
}
