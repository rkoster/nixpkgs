{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "kiln";
  version = "0.89.0";

  src = fetchFromGitHub {
    owner = "pivotal-cf";
    repo = "kiln";
    rev = "167d4dfe5b45d28d2cb48326c030812ff961af82"; # "v${version}";
    sha256 = "sha256-h1EX62rDi07h1a0dmZgwIIjIz8B0DKkuvv4K8Tj+B0E=";
  };

  vendorHash = "sha256-E8rmRJRzpKS/xQ75FFmOcAhrXjcMcQZLCe33a27B3TI=";

  doCheck = false;

  ldflags = [
    "-X main.version=${version}"
  ];

  subPackages = [ "main.go" ];

  postBuild = ''
     cd "$GOPATH/bin"
     mv main kiln
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
