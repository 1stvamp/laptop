# Oneleet's compliance agent, repackaged from its .deb. The daemon and the tray app
# expect to live in /opt/Oneleet, so the tree keeps that layout (see ./default.nix).
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
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
  libdrm,
  libgbm,
  libxkbcommon,
  nspr,
  nss,
  pango,
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
  libsecret,
  libuuid,
  vulkan-loader,
  wayland,
  libxscrnsaver,
  libxtst,

  xdg-utils,
}:

let
  source = lib.importJSON ./sources.json;

  runtimeLibs = [
    libGL
    libayatana-appindicator
    libnotify
    libsecret
    libuuid
    vulkan-loader
    wayland
    libxscrnsaver
    libxtst
  ];
in
stdenv.mkDerivation {
  pname = "oneleet";
  inherit (source) version;

  src = fetchurl { inherit (source) url hash; };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
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
    libdrm
    libgbm
    libxkbcommon
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemd
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
  ];

  runtimeDependencies = runtimeLibs;

  # Only the tray app is wrapped; postFixup does it.
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile "$src" | tar -x --no-same-owner --no-same-permissions
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    app=$out/opt/Oneleet
    mkdir -p $out/opt $out/bin
    cp -a opt/Oneleet $app
    cp -a usr/share $out/share

    # SUID helper and AppArmor profile; NixOS uses unprivileged user namespaces.
    rm -rf $app/chrome-sandbox $app/resources/apparmor $app/resources/apparmor-profile

    substituteInPlace $out/share/applications/oneleet-agent.desktop \
      --replace-fail /opt/Oneleet/oneleet-agent $app/oneleet-agent

    # What the deb's postinst links into /usr/bin.
    ln -s $app/oneleet-agent $out/bin/oneleet-agent
    ln -s $app/oneleet-daemon $out/bin/oneleet-cli

    runHook postInstall
  '';

  # Wrapped in place: the daemon starts the tray app by its /opt/Oneleet path.
  postFixup = ''
    wrapProgram $out/opt/Oneleet/oneleet-agent \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --prefix LD_LIBRARY_PATH : ${addDriverRunpath.driverLink}/lib:${lib.makeLibraryPath runtimeLibs} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
  '';

  meta = {
    description = "Oneleet compliance agent: daemon, osquery and tray app";
    homepage = "https://www.oneleet.com";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "oneleet-cli";
  };
}
