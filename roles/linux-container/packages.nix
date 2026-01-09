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
  lastpass-cli

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
  cloud-provider-kind

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

  # AI tools
  opencode
  token-count

  # JRE for Synopsys Detect
  jre_minimal

  # BOSH ecosystem (custom packages from overlays)
  bosh
  om
  bosh-bootloader
  ytt
  cf
  bundix
  credhub
  ibosh

  # Carvel tools
  pget
  imgpkg
  vendir
  kbld

  # Additional custom packages from overlays/local-pkgs.nix
  ssoca
  leftovers
  spruce
  safe
  genesis
  gojson
  runctl
  smith
  hub-tool
  uaa-cli
  dyff
  peribolos
  jless
  pinniped
  nsc
  csb
  srpcli
  osstp-load
  osspi-signer
  osspi-cli
  tanzu
  h2o
  kiln
  gosub
  pivnet
  ctr
  slackdump
  tanzu-sm-installer
  firecracker
  flasher-tool
  incus-client
]
