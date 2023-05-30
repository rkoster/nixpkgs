{ lib, python39Packages, stdenv, fetchzip }:
with python39Packages;

stdenv.mkDerivation rec {
  pname = "osstp-load";
  version = "3.0.0";

  src = fetchzip {
    url = "https://osm.eng.vmware.com/utilities/osstpclients3.zip";
    sha256 = "sha256-gLAZ1ylPRf/DbkDTNHFMWhhyn1VVY0PeHPCIpY07/LA=";
    stripRoot = false;
  };

  propagatedBuildInputs = [
    (python.withPackages (pythonPackages: with pythonPackages; [
      requests
      texttable
      retrying
      pkgs.osspi-signer
    ]))
  ];

  installPhase = ''
     mkdir -p $out/bin
     cp ${src}/bin/osstp-load.py $out/bin/osstp-load
     cp ${src}/settings.py $out/
     cp -r ${src}/lib $out/
  '';

  meta = with lib; {
    description = "osstp-load; CLI to load your OSSPI-generated manifest file to OSM";
    homepage = "https://confluence.eng.vmware.com/display/public/OSMUserGuide/Accessing+the+Client+Utilities";
    maintainers = with maintainers; [ rkoster ];
  };
}
