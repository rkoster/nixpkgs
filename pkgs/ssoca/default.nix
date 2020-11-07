{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {  
  name = "ssoca";
  version = "0.19.2";

  src = fetchFromGitHub {
    owner = "dpb587";
    repo = "ssoca";
    rev = "v0.19.2";
    sha256 = "1yhacjf41j3vmvl5ns5a6lb4bz74mb2y189qki29aw3dddl5nrhx";
  };

  vendorSha256 = null;

  doCheck = false;

  subPackages = [ "cli/client" ];

  buildFlagsArray = ''
    -ldflags=
      -X main.appSemver=v${version}"
  '';

  postBuild = ''
     cd "$GOPATH/bin"
     mv client ssoca
  ''; 

  meta = with lib; {
    homepage = "https://github.com/dpb587/ssoca";
    description = "SSO for services that use CA-based authentication.";
    license = licenses.mit;
    maintainers = with maintainers; [ rkoster ];
  };
}
