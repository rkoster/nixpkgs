{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "h2o";
  version = "2.2.0";

  src = builtins.fetchGit {
    url = "git@gitlab.eng.vmware.com:h2o/neptune/cli.git";
    ref = "master";
    rev = "b3d85f1c9c888ac3d98fe7962b649760e63eac52"; # 2.2.0
  };  

  vendorHash = "sha256-SxVAgPsh8YeZ7omVXU1jYPO5QQpx60GVDdZ2bAtG3uA=";

  doCheck = false;

  ldflags = [
    "-X gitlab.eng.vmware.com/h2o/neptune/cli/conf.Version=${version}"
  ];

  subPackages = [ "main.go" ];

  postBuild = ''
     cd "$GOPATH/bin"
     mv main h2o
  ''; 

  meta = with lib; {
    description = "CLI for the H2O project";
    homepage = "https://h2o.vmware.com/";
    maintainers = with maintainers; [ rkoster ];
  };
}
