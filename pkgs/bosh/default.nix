{ buildGo123Module, fetchFromGitHub, installShellFiles, stdenv, lib, writeText }:

buildGo123Module rec {
  pname = "bosh";
  version = "7.9.3";

  src = fetchFromGitHub {
    owner = "cloudfoundry";
    repo = "bosh-cli";
    rev = "v${version}";
    sha256 = "sha256-ESM0DpCW97ulo5U/RCEaiKz1C5FeXflB7f/OlJaRwIQ=";
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
