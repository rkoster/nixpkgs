{ buildGoModule, fetchFromGitHub, installShellFiles, lib }:

buildGoModule rec {
  pname = "ibosh";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "rkoster";
    repo = "instant-bosh";
    rev = "7cf8065df7096e15d53a8e183e2f08f9fd267176";
    sha256 = "sha256-KpsgJmMZxOcDF1HMnFauABoVpTOd/mtHzekjpGwEwqg=";
  };

  vendorHash = "sha256-3GPvp9OFpIzTm/BtuWy+sUnuhFc/2QOZ4WO7eh24nqY=";

  subPackages = [ "cmd/ibosh" ];

  ldflags = [ "-s" "-w" ];

  nativeBuildInputs = [ installShellFiles ];

  postInstall = ''
    installShellCompletion --cmd ibosh \
      --bash <($out/bin/ibosh --generate-bash-completion) \
      --zsh <($out/bin/ibosh --generate-zsh-completion) \
      --fish <($out/bin/ibosh --generate-fish-completion)
  '';

  meta = with lib; {
    description = "instant-bosh CLI - Manage containerized BOSH directors";
    homepage = "https://github.com/rkoster/instant-bosh";
    license = licenses.bsl11;
    maintainers = with maintainers; [ rkoster ];
    mainProgram = "ibosh";
  };
}
