{ alsa-lib
, at-spi2-atk
, asar
, autoPatchelfHook
, cairo
, cups
, dbus
, dpkg
, expat
, fetchurl
, fontconfig
, freetype
, gdk-pixbuf
, gsettings-desktop-schemas
, glib
, gtk3
, lib
, libcap_ng
, libdrm
, libgbm
, libglvnd
, libnotify
, libpulseaudio
, libseccomp
, libsecret
, libx11
, libxcb
, libxcomposite
, libxcursor
, libxdamage
, libuuid
, libxext
, libxfixes
, libxi
, libxkbcommon
, libxrandr
, libxrender
, libxscrnsaver
, libxshmfence
, libxtst
, makeWrapper
, mesa
, nodejs
, nspr
, nss
, pango
, qemu
, stdenv
, trash-cli
, util-linux
, virtiofsd
, xdg-utils
,
}:

let
  pname = "claude-desktop";
  version = "1.24012.0";

  arch = {
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
  }.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  srcs = {
    x86_64-linux = fetchurl {
      url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_1.24012.0_amd64.deb";
      hash = "sha256-EJaoBjlW+EMP2+UEuxxeAphfMdD0XQguSWbl0w6n46w=";
    };
    aarch64-linux = fetchurl {
      url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_1.24012.0_arm64.deb";
      hash = "sha256-N91dwbC/yzGSVhrL0zy1kDeAb+m5UiGj3fOCRCAxlvE=";
    };
  };

  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libcap_ng
    libdrm
    libgbm
    libglvnd
    libnotify
    libpulseaudio
    libseccomp
    libsecret
    libuuid
    libxkbcommon
    mesa
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    util-linux
    libx11
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxtst
    libxcb
    libxshmfence
  ];

  runtimeBins = [
    glib
    qemu
    trash-cli
    virtiofsd
    xdg-utils
  ];
in
stdenv.mkDerivation {
  inherit pname version;

  src = srcs.${stdenv.hostPlatform.system};

  nativeBuildInputs = [
    asar
    autoPatchelfHook
    dpkg
    glib
    makeWrapper
    nodejs
  ];

  buildInputs = runtimeLibs;

  sourceRoot = ".";

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile "$src" | tar -x --no-same-owner --no-same-permissions
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib"
    cp -R usr/lib/claude-desktop "$out/lib/"

    mkdir -p "$out/bin"
    ln -s "$out/lib/claude-desktop/claude-desktop" "$out/bin/.claude-desktop-unwrapped"

    if [ -d usr/share ]; then
      cp -R usr/share "$out/"
    fi

    # Fix .desktop file to use absolute store paths so launchers find it
    if [ -f "$out/share/applications/claude-desktop.desktop" ]; then
      substituteInPlace "$out/share/applications/claude-desktop.desktop" \
        --replace-fail "Exec=claude-desktop " "Exec=$out/bin/claude-desktop " \
        --replace-fail "Icon=claude-desktop" "Icon=$out/share/icons/hicolor/256x256/apps/claude-desktop.png"
    fi

    chmod +x "$out"/lib/claude-desktop/*.so* \
      "$out"/lib/claude-desktop/claude-desktop \
      "$out"/lib/claude-desktop/chrome_crashpad_handler \
      "$out"/lib/claude-desktop/resources/chrome-native-host \
      "$out"/lib/claude-desktop/resources/cowork-linux-helper \
      "$out"/lib/claude-desktop/resources/virtiofsd

    find "$out/lib/claude-desktop/resources/app.asar.unpacked" -name '*.node' -exec chmod +x {} +

    mkdir -p "$out/share/OVMF" "$out/share/AAVMF"
    ln -s "${qemu}/share/qemu/edk2-x86_64-code.fd" "$out/share/OVMF/OVMF_CODE.fd"
    ln -s "${qemu}/share/qemu/edk2-i386-vars.fd" "$out/share/OVMF/OVMF_VARS.fd"
    ln -s "${qemu}/share/qemu/edk2-aarch64-code.fd" "$out/share/AAVMF/AAVMF_CODE.fd"
    ln -s "${qemu}/share/qemu/edk2-arm-vars.fd" "$out/share/AAVMF/AAVMF_VARS.fd"

    asar extract "$out/lib/claude-desktop/resources/app.asar" "$TMPDIR/app.asar"
    node - "$TMPDIR/app.asar/.vite/build/index.js" "$out" <<'EOF'
const fs = require("fs");
const [file, out] = process.argv.slice(2);
let text = fs.readFileSync(file, "utf8");
const replacements = new Map([
  ["/usr/share/OVMF/OVMF_CODE_4M.fd", `''${out}/share/OVMF/OVMF_CODE.fd`],
  ["/usr/share/OVMF/OVMF_CODE.fd", `''${out}/share/OVMF/OVMF_CODE.fd`],
  ["/usr/share/AAVMF/AAVMF_CODE.fd", `''${out}/share/AAVMF/AAVMF_CODE.fd`],
  ["/usr/libexec/virtiofsd", "${virtiofsd}/bin/virtiofsd"],
  ["/usr/bin/virtiofsd", "${virtiofsd}/bin/virtiofsd"],
]);
for (const [from, to] of replacements) {
  if (!text.includes(from)) {
    throw new Error(`missing expected Claude virtualization probe path: ''${from}`);
  }
  text = text.replaceAll(from, to);
}
fs.writeFileSync(file, text);
EOF
    rm "$out/lib/claude-desktop/resources/app.asar"
    asar pack "$TMPDIR/app.asar" "$out/lib/claude-desktop/resources/app.asar"

    # NB: deliberately not $out/share/glib-2.0/schemas. glib's setup-hook
    # (glibPostInstallHook) auto-relocates that exact path to
    # $out/share/gsettings-schemas/$name/glib-2.0/schemas via postInstallHooks,
    # which runs as part of `runHook postInstall` below and would silently
    # empty the directory we just compiled.
    mkdir -p "$out/share/claude-desktop-gsettings-schemas"
    cp ${gtk3}/share/gsettings-schemas/*/glib-2.0/schemas/*.xml "$out/share/claude-desktop-gsettings-schemas/"
    cp ${gsettings-desktop-schemas}/share/gsettings-schemas/*/glib-2.0/schemas/*.xml "$out/share/claude-desktop-gsettings-schemas/"
    glib-compile-schemas "$out/share/claude-desktop-gsettings-schemas"

    makeWrapper "$out/bin/.claude-desktop-unwrapped" "$out/bin/claude-desktop" \
      --prefix PATH : ${lib.makeBinPath runtimeBins} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --set GSETTINGS_SCHEMA_DIR "$out/share/claude-desktop-gsettings-schemas" \
      --set-default DISABLE_AUTOUPDATER 1 \
      --set-default OVMF_PATH "$out/share/OVMF"

    runHook postInstall
  '';

  dontStrip = true;
  dontWrapGApps = true;

  passthru = {
    inherit arch;
    updateScript = ./update.sh;
  };

  meta = {
    description = "Desktop application for Claude.ai";
    homepage = "https://claude.ai";
    license = lib.licenses.unfree;
    mainProgram = "claude-desktop";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
