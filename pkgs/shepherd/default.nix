{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "shepherd";
  version = "0.7.7";

  src = builtins.fetchGit {
    url = "git@github.gwd.broadcom.net:TNZ/shepherd2.git";
    ref = "main";
    rev = "b2e46d058c2b3e164096b53ec6b2b3678f7eee8d";
  }; 

  vendorHash = "sha256-m5E+05OZW1THyjjHS6SnLJU4+2jeO+SMWLPkotVJ7SM=";

  doCheck = false;

  ldflags = [
    "-X gitlab.eng.vmware.com/shepherd/shepherd2/client/cli/cmd.Version=${version}"
    "-X gitlab.eng.vmware.com/shepherd/shepherd2/client/cli/cmd.DefaultLocation=https://v2.shepherd.run"
  ];

  subPackages = [ "main.go" ];
  modRoot = "client/cli";

  postBuild = ''
     cd "$GOPATH/bin"
     mv main shepherd
  ''; 

  meta = with lib; {
    description = "shepherd: CLI for the Shepherd v2 environment management system";
    homepage = "https://gitlab.eng.vmware.com/shepherd/shepherd2/-/tree/main/documentation/public-docs";
    maintainers = with maintainers; [ rkoster ];
  };
}
