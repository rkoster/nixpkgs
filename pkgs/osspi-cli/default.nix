{ lib, python39Packages, stdenv, fetchzip }:
with python39Packages;

stdenv.mkDerivation rec {
  pname = "osspi-cli";
  version = "1.7.6";

  src = builtins.fetchGit {
    url = "git@gitlab.eng.vmware.com:core-build/osspi-cli.git";
    ref = "develop";
    rev = "56a5314a97361d717ec254770bb0dab2442516e3";
  };

  buildInputs = [
    pkgs.curl
    virtualenv
  ];

  propagatedBuildInputs = [
    (python.withPackages (pythonPackages: with pythonPackages; [
      requests
      texttable
      retrying
#      pkgs.osspi-signer
    ]))
  ];

  # installPhase = ''
  #    mkdir -p $out/bin
  #    cp ${src}/bin/osstp-load.py $out/bin/osstp-load
  #    cp ${src}/settings.py $out/
  #    cp -r ${src}/lib $out/
  # '';

  meta = with lib; {
    description = "OSSPI CLI is a client of OSSPI System running in terminal. It provides a way of using OSSPI directly on your dev
box, like scaning your project for open-source packages, or checking package mapping information.";
    homepage = "https://gitlab.eng.vmware.com/core-build/osspi-cli/-/tree/master";
    maintainers = with maintainers; [ rkoster ];
  };
}
