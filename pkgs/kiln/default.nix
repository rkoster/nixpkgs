{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "kiln";
  version = "0.89.0";

  src = fetchGit {
    url = "/Users/rubenk/workspace/kiln";
    ref = "kiln-test-fixes";
    rev = "f608044aa79442aee9abbcc52a6d30d61cd18f71";
  };

#  src = fetchFromGitHub {
#    owner = "pivotal-cf";
#    repo = "kiln";
#    rev = "167d4dfe5b45d28d2cb48326c030812ff961af82"; # "v${version}";
#    sha256 = "sha256-h1EX62rDi07h1a0dmZgwIIjIz8B0DKkuvv4K8Tj+B0E=";
#  };

  vendorHash = "sha256-4EqPWc6wT4CdjRCapQfpS8ejCEpIT6JRYwI7q5TpTs4=";

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
