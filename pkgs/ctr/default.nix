{ buildGoModule, fetchFromGitHub, installShellFiles, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "ctr";
  version = "1.7.18";

  src = fetchFromGitHub {
    owner = "containerd";
    repo = "containerd";
    rev = "v${version}";
    sha256 = "sha256-IlK5IwniaBhqMgxQzV8btQcbdJkNEQeUMoh6aOsBOHQ=";
  };

  vendorHash = null;

  doCheck = false;

  nativeBuildInputs = [ installShellFiles ];

  preBuild = "CGO_ENABLED=0";

  subPackages = [ "cmd/ctr" ];

  ldflags = [
   "-X github.com/containerd/containerd/v2/version.Version=${version}"
  ];

  # postInstall = ''
  #   installShellCompletion --cmd imgpkg \
  #     --bash <($out/bin/imgpkg completion bash) \
  #     --fish <($out/bin/imgpkg completion fish) \
  #     --zsh <($out/bin/imgpkg completion zsh)
  # '';

  meta = with lib; {
    description = "containerd ctr cli";
    homepage = "https://github.com/containerd/containerd";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
