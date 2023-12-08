{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "gojson";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "ChimeraCoder";
    repo = "gojson";
    rev = "v${version}";
    sha256 = "013qdxdc7cy7r5jd0xj217gxj4jc84j1ady4lza386pp7wgzww0j";
  };

  vendorHash = null;

  doCheck = false;

  preBuild = ''
    go mod init github.com/ChimeraCoder/gojson
  '';

  subPackages = [ "gojson" ];

  meta = with lib; {
    description = "Automatically generate Go (golang) struct definitions from example JSON";
    homepage = "https://github.com/ChimeraCoder/gojson";
    license = licenses.gpl3;
    maintainers = with maintainers; [ rkoster ];
  };
}
