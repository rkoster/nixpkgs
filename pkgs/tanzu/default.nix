{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "tanzu";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "vmware-tanzu";
    repo = "tanzu-cli";
    rev = "v${version}";
    sha256 = "sha256-+WYRHflT3rkGKjvGjNo3zj56muBfmF/2a2GHgy8Ahes=";
  };

  vendorHash = "sha256-UHkkAFgrWEKXyTZUji8Gvm8GDb3S6u4SiTO3UABrzfo=";

  doCheck = false;

  preBuild = ''
    export GOWORK=off
  '';

  ldflags = [
    "-X github.com/vmware-tanzu/tanzu-cli/pkg/buildinfo.Version=main.Version=${version}"
  ];

  subPackages = [ "cmd/tanzu" ];

  # postBuild = ''
  #    cd "$GOPATH/bin"
  #    mv main tanzu
  # ''; 

  meta = with lib; {
    description = "The Tanzu Core CLI project provides the core functionality of the Tanzu CLI. The CLI is based on a plugin architecture where CLI command functionality can be delivered through independently developed plugin binaries";
    homepage = "https://github.com/vmware-tanzu/tanzu-cli";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
