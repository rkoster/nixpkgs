{ buildGoModule, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "runctl";
  version = "2.0.0";

  # use fetchGit since it supports using ssh private keys for auth
  src = builtins.fetchGit {
    url = "git@gitlab.eng.vmware.com:devtools/runway/cli/runctl.git";
    ref = "master";
    rev = "c3838e844efc96ef0111a4d7bb29d8560a2fbb14"; # release-v2.0.0
  };

  vendorHash = "0cnn964g4qkr7jxjp5chzrvq2qx4fk98m0jcgfs5ryxycc68x386";

  doCheck = false;

  subPackages = [ "runctl.go" ];

  ldflags = [
    "-X gitlab.com/vmware/devtools/runway/runctl/version.Version=${version}"
    "-X gitlab.com/vmware/devtools/runway/runctl/version.ReleasePhase=nix"
  ];

  meta = with lib; {
    description = "runctl; CLI to manage Runway namespaces and plugins";
    homepage = "http://go/runway";
    maintainers = with maintainers; [ rkoster ];
  };
}
