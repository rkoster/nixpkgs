{ buildGoModule, fetchFromGitHub, installShellFiles, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "imgpkg";
  version = "0.42.2";

  src = fetchFromGitHub {
    owner = "carvel-dev";
    repo = "imgpkg";
    rev = "v${version}";
    sha256 = "sha256-YpMAlFmSSXQYgPpkc9diIyAdJcglU66841tBDHE5VSQ=";
  };

  vendorHash = null;

  doCheck = false;

  nativeBuildInputs = [ installShellFiles ];

  preBuild = "CGO_ENABLED=0";

  subPackages = [ "cmd/imgpkg" ];

  ldflags = [
   "-X carvel.dev/imgpkg/pkg/imgpkg/cmd.Version=${version}"
  ];

  postInstall = ''
    installShellCompletion --cmd imgpkg \
      --bash <($out/bin/imgpkg completion bash) \
      --fish <($out/bin/imgpkg completion fish) \
      --zsh <($out/bin/imgpkg completion zsh)
  '';

  meta = with lib; {
    description = "Store application configuration files in Docker/OCI registries";
    homepage = "https://carvel.dev/imgpkg";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
