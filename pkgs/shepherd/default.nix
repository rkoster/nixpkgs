{ buildGo123Module, fetchFromGitHub, stdenv, lib, writeText }:

buildGo123Module rec {
  pname = "shepherd";
  version = "0.7.8";

  src = builtins.fetchGit {
    url = "git@github.gwd.broadcom.net:TNZ/shepherd2.git";
    ref = "main";
    rev = "86366133cf28125e0c5135cb392551055945e929";
  };

  vendorHash = "sha256-wwucAdto5XpH18Tz1CObsPJqe5DZxxSCd870F/BvMbc=";

  doCheck = false;

  ldflags = [
    "-X gitlab.eng.vmware.com/shepherd/shepherd2/client/cli/cmd.Version=${version}"
    # "-X gitlab.eng.vmware.com/shepherd/shepherd2/client/cli/cmd.DefaultLocation=https://v2.shepherd.run"
    "-X gitlab.eng.vmware.com/shepherd/shepherd2/client/cli/cmd.DefaultLocation=https://v2-shepherd.lvn.broadcom.net"
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
