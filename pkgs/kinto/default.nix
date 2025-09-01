{ lib
, fetchFromGitHub
, python3Packages
, xkeysnail
, xorg
, makeWrapper
}:

python3Packages.buildPythonApplication rec {
  pname = "kinto";
  version = "1.2-13";
  format = "other";

  src = fetchFromGitHub {
    owner = "rbreaves";
    repo = "kinto";
    rev = "1.2-13";
    sha256 = "sha256-DlAG6mWilQbNSvhNv344yPxhgpn6N9VQ1CEwwZ4bPXg=";
  };

  propagatedBuildInputs = with python3Packages; [
    pillow
    xkeysnail
  ];

  nativeBuildInputs = [ makeWrapper ];

  # Don't use the default Python install
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/share/kinto

    # Copy Kinto configuration files
    cp -r linux/* $out/share/kinto/
    
    # Copy GUI components if they exist
    if [ -d linux/gui ]; then
      cp -r linux/gui $out/share/kinto/
    fi
    
    # Copy tray app if it exists
    if [ -d linux/trayapps ]; then
      cp -r linux/trayapps $out/share/kinto/
    fi
    
    # Create wrapper script for kinto-gui
    if [ -f linux/gui/kinto-gui.py ]; then
      makeWrapper ${python3Packages.python}/bin/python3 $out/bin/kinto-gui \
        --add-flags "$out/share/kinto/gui/kinto-gui.py"
    fi

    # Create wrapper script for kinto tray
    if [ -f linux/trayapps/appindicator/kintotray.py ]; then
      makeWrapper ${python3Packages.python}/bin/python3 $out/bin/kinto-tray \
        --add-flags "$out/share/kinto/trayapps/appindicator/kintotray.py"
    fi

    # Create wrapper for xkeysnail with kinto path
    makeWrapper ${xkeysnail}/bin/xkeysnail $out/bin/kinto-xkeysnail \
      --prefix PATH : ${lib.makeBinPath [ xorg.xhost ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Mac-style shortcut keys for Linux & Windows";
    homepage = "https://kinto.sh";
    license = licenses.gpl2;
    maintainers = with maintainers; [ rkoster ];
    platforms = platforms.linux;
  };
}