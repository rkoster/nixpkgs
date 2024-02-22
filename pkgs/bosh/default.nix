{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "bosh";
  version = "7.5.3";

  src = fetchFromGitHub {
    owner = "cloudfoundry";
    repo = "bosh-cli";
    rev = "v${version}";
    sha256 = "sha256-G9622QudxCUKJpHoezfpSjLFsX9H4m65lacoMATWyAA=";
  };

  vendorHash = null;

  doCheck = false;

  preBuild = ''
    sed -i 's/\[DEV BUILD\]/'"${version}-nix"'/' cmd/version.go
    sed -i 's/darwin/disable/' vendor/github.com/cloudfoundry/bosh-utils/fileutil/tarball_compressor.go
  '';

  subPackages = [ "main.go" ];

  postBuild = ''
     cd "$GOPATH/bin"
     mv main bosh
  '';

  # postInstall = ''
  #   installShellCompletion --cmd aws \
  #     --zsh $out/bin/aws_zsh_completer.sh
  # '' + lib.optionalString (!stdenv.hostPlatform.isWindows) ''
  #   rm $out/bin/aws.cmd
  # '';

  meta = with lib; {
    description = "BOSH CLI v2+";
    homepage = "https://github.com/cloudfoundry/bosh-cli";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
