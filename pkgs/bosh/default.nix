{ buildGoModule, fetchFromGitHub, installShellFiles, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "bosh";
  version = "7.5.3";

  src = fetchFromGitHub {
    #  owner = "cloudfoundry";
    owner = "kinjelom";
    repo = "bosh-cli";
    # rev = "v${version}";
    rev = "cf9d1abb38b07547f37e8da356d5e41fa3e82cdf";
    sha256 = "sha256-20uOv8wmMaTN3ZJBMjC09Cblo78cuVK+XczKbbh82+8=";
  };

  vendorHash = null;

  doCheck = false;

  nativeBuildInputs = [ installShellFiles ];

  preBuild = ''
    sed -i 's/\[DEV BUILD\]/'"${version}-nix"'/' cmd/version.go
    sed -i 's/darwin/disable/' vendor/github.com/cloudfoundry/bosh-utils/fileutil/tarball_compressor.go
  '';

  subPackages = [ "main.go" ];

  postBuild = ''
     cd "$GOPATH/bin"
     mv main bosh
  '';

  postInstall = ''
    installShellCompletion --cmd bosh \
      --bash <($out/bin/bosh completion bash) \
      --fish <($out/bin/bosh completion fish) \
      --zsh <($out/bin/bosh completion zsh)
  '';

  meta = with lib; {
    description = "BOSH CLI v2+";
    homepage = "https://github.com/cloudfoundry/bosh-cli";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
