{ pkgs, lib, config, ... }:

let
  # Duplicate overlay definitions to include custom packages
  # This is necessary because devenv.sh operates independently from the flake system
  customPkgs = {
    ssoca = pkgs.callPackage ./pkgs/ssoca { };
    leftovers = pkgs.callPackage ./pkgs/leftovers { };
    bosh = pkgs.callPackage ./pkgs/bosh { };
    bosh-bootloader = pkgs.callPackage ./pkgs/bosh-bootloader { };
    cf = pkgs.callPackage ./pkgs/cf { };
    spruce = pkgs.callPackage ./pkgs/spruce { };
    safe = pkgs.callPackage ./pkgs/safe { };
    genesis = pkgs.callPackage ./pkgs/genesis { };
    credhub = pkgs.callPackage ./pkgs/credhub { };
    gojson = pkgs.callPackage ./pkgs/gojson { };
    runctl = pkgs.callPackage ./pkgs/runctl { };
    git-duet = pkgs.callPackage ./pkgs/git-duet { };
    smith = pkgs.callPackage ./pkgs/smith { };
    om = pkgs.callPackage ./pkgs/om { };
    hub-tool = pkgs.callPackage ./pkgs/hub-tool { };
    uaa-cli = pkgs.callPackage ./pkgs/uaa-cli { };
    dyff = pkgs.callPackage ./pkgs/dyff { };
    peribolos = pkgs.callPackage ./pkgs/peribolos { };
    jless = pkgs.callPackage ./pkgs/jless { };
    pinniped = pkgs.callPackage ./pkgs/pinniped { };
    nsc = pkgs.callPackage ./pkgs/nsc { };
    csb = pkgs.callPackage ./pkgs/csb { };
    srpcli = pkgs.callPackage ./pkgs/srpcli { };
    osstp-load = pkgs.callPackage ./pkgs/osstp-load { };
    osspi-signer = pkgs.callPackage ./pkgs/osspi-signer { };
    osspi-cli = pkgs.callPackage ./pkgs/osspi-cli { };
    tanzu = pkgs.callPackage ./pkgs/tanzu { };
    h2o = pkgs.callPackage ./pkgs/h2o { };
    kiln = pkgs.callPackage ./pkgs/kiln { };
    gosub = pkgs.callPackage ./pkgs/gosub { };
    imgpkg = pkgs.callPackage ./pkgs/imgpkg { };
    kbld = pkgs.callPackage ./pkgs/kbld { };
    pivnet = pkgs.callPackage ./pkgs/pivnet { };
    ctr = pkgs.callPackage ./pkgs/ctr { };
    slackdump = pkgs.callPackage ./pkgs/slackdump { };
    tanzu-sm-installer = pkgs.callPackage ./pkgs/tanzu-sm-installer { };
    cloud-provider-kind = pkgs.callPackage ./pkgs/cloud-provider-kind { };
    kinto = pkgs.callPackage ./pkgs/kinto { };
    token-count = pkgs.callPackage ./pkgs/token-count { };
    flasher-tool = pkgs.callPackage ./pkgs/flasher-tool { };
    
    # Incus client only
    incus-client = import ./pkgs/incus-client { 
      inherit (pkgs) lib buildGoModule fetchFromGitHub installShellFiles;
    };
    
    # ibosh with Go 1.25
    ibosh = (pkgs.buildGoModule.override { go = pkgs.go_1_25; }) rec {
      pname = "ibosh";
      version = "0.2.0";

      src = pkgs.fetchFromGitHub {
        owner = "rkoster";
        repo = "instant-bosh";
        rev = "56d3f34a0e79c8942ffee43afd559a2407e5d53d";
        sha256 = "sha256-sBh/3Yzcj+AoRKbO3sKnqwP0PTkuvwaOSumEJ+JD86I=";
      };

      vendorHash = "sha256-qj5MBQySJ6dSMcwP90iThNfEK5OxOGbq+e9Mofe6M5A=";

      postPatch = ''
        substituteInPlace go.mod \
          --replace-fail "go 1.25.1" "go 1.25"
      '';

      subPackages = [ "cmd/ibosh" ];

      ldflags = [
        "-s"
        "-w"
        "-X main.version=${version}"
        "-X main.commit=${src.rev}"
      ];

      meta = with pkgs.lib; {
        description = "instant-bosh CLI - Manage containerized BOSH directors";
        homepage = "https://github.com/rkoster/instant-bosh";
        license = licenses.bsl11;
        maintainers = with maintainers; [ rkoster ];
        mainProgram = "ibosh";
      };
    };

    # Additional packages needed by roles/linux-container/packages.nix
    pget = pkgs.callPackage ./pkgs/pget { };
    vendir = pkgs.callPackage ./pkgs/vendir { };
    ytt = pkgs.callPackage ./pkgs/ytt { };
    opencode = pkgs.callPackage ./pkgs/opencode { };
  };

  # Extend pkgs with custom packages before importing container packages
  extendedPkgs = pkgs // customPkgs;
  containerPackages = import ./roles/linux-container/packages.nix { pkgs = extendedPkgs; };

in {
  name = "nix-dev-container";

  packages = containerPackages ++ (with pkgs; [
    zsh
    tmux
    starship
    broot
    fzf
    direnv
    nix-direnv
    git
    emacs-nox
  ]);

  containers."shell" = {
    name = "workspace";
    copyToRoot = null;
    startupCommand = "${pkgs.zsh}/bin/zsh -l";
  };
}
