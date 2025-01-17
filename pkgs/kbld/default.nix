{ buildGoModule, fetchFromGitHub, installShellFiles, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "kbld";
  version = "0.43.2";

  src = fetchFromGitHub {
    owner = "carvel-dev";
    repo = "kbld";
    rev = "v${version}";
    sha256 = "sha256-/WhCHJUV59tf92YevDajUEx7orwNOWCagj3ks/tgACs=";
  };

  vendorHash = null;

  doCheck = false;

  nativeBuildInputs = [ installShellFiles ];

  preBuild = "CGO_ENABLED=0";

  subPackages = [ "cmd/kbld" ];

  ldflags = [
   "-X carvel.dev/kbld/pkg/kbld/version.Version=${version}"
  ];

  postInstall = ''
    installShellCompletion --cmd imgpkg \
      --bash <($out/bin/kbld completion bash) \
      --fish <($out/bin/kbld completion fish) \
      --zsh <($out/bin/kbld completion zsh)
  '';

  meta = with lib; {
    description = "kbld seamlessly incorporates image building and image pushing into your development and deployment workflows";
    homepage = "https://carvel.dev/kbld";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
