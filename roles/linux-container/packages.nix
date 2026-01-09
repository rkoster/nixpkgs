{ pkgs }:

with pkgs; [
  # Core CLI tools
  jq
  ripgrep
  tree
  pwgen
  ipcalc
  openssh
  watch
  hwatch
  wget
  nmap
  arp-scan
  aria2
  git-duet
  comma
  packer
  gnutar
  retry
  coreutils
  gcc

  # Container tools
  docker
  podman
  buildah
  skopeo
  dive

  # Kubernetes
  kubectl
  kind
  k9s

  # Cloud/CI tools
  gh
  devbox
  earthly
  google-cloud-sdk

  # SSH tools
  sshuttle
  sshpass

  # Language servers
  gopls
  yaml-language-server
  solargraph
  nodePackages.bash-language-server

  # Custom packages from overlays/local-pkgs.nix
  dyff
  jless
]
