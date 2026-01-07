{ lib
, buildGoModule
, fetchFromGitHub
, installShellFiles
}:

buildGoModule rec {
  pname = "incus-client";
  version = "6.20.0";

  src = fetchFromGitHub {
    owner = "lxc";
    repo = "incus";
    rev = "v${version}";
    hash = "sha256-nhf7defhiFBHsqfZ6y+NN3TuteII6t8zCvpTsPsO+EE=";
  };

  vendorHash = "sha256-jIOV6vIkptHEuZcD/aS386o2M2AQHTjHngBxFi2tESA=";

  subPackages = [ "cmd/incus" ];

  nativeBuildInputs = [ installShellFiles ];

  postInstall = ''
    # Set HOME to avoid "mkdir /var/empty/.config: permission denied"
    export HOME=$TMPDIR
    
    installShellCompletion --bash --name incus <($out/bin/incus completion bash)
    installShellCompletion --fish --name incus.fish <($out/bin/incus completion fish)
    installShellCompletion --zsh --name _incus <($out/bin/incus completion zsh)
  '';

  meta = {
    description = "Incus client - CLI for managing remote Incus servers";
    homepage = "https://github.com/lxc/incus";
    license = lib.licenses.asl20;
    maintainers = [];
    platforms = lib.platforms.unix;
    mainProgram = "incus";
  };
}
