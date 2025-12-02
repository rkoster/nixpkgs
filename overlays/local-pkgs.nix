self: super:

{
  ssoca = super.callPackage ../pkgs/ssoca { };
  leftovers = super.callPackage ../pkgs/leftovers { };
  bosh = super.callPackage ../pkgs/bosh { };
  bosh-bootloader = super.callPackage ../pkgs/bosh-bootloader { };
  cf = super.callPackage ../pkgs/cf { };
  spruce = super.callPackage ../pkgs/spruce { };
  safe = super.callPackage ../pkgs/safe { };
  genesis = super.callPackage ../pkgs/genesis { };
  credhub = super.callPackage ../pkgs/credhub { };
  gojson = super.callPackage ../pkgs/gojson { };
  runctl = super.callPackage ../pkgs/runctl { };
  git-duet = super.callPackage ../pkgs/git-duet { };
  smith = super.callPackage ../pkgs/smith { };
  om = super.callPackage ../pkgs/om { };
  hub-tool = super.callPackage ../pkgs/hub-tool { };
  uaa-cli = super.callPackage ../pkgs/uaa-cli { };
  dyff = super.callPackage ../pkgs/dyff { };
  peribolos = super.callPackage ../pkgs/peribolos { };
  jless = super.callPackage ../pkgs/jless { };
  pinniped = super.callPackage ../pkgs/pinniped { };
  nsc = super.callPackage ../pkgs/nsc { };
  csb = super.callPackage ../pkgs/csb { };
  srpcli = super.callPackage ../pkgs/srpcli { };
  osstp-load = super.callPackage ../pkgs/osstp-load { };
  osspi-signer = super.callPackage ../pkgs/osspi-signer { };
  osspi-cli = super.callPackage ../pkgs/osspi-cli { };
  tanzu = super.callPackage ../pkgs/tanzu { };
  h2o = super.callPackage ../pkgs/h2o { };
  shepherd = super.callPackage ../pkgs/shepherd { };
  kiln = super.callPackage ../pkgs/kiln { };
  gosub = super.callPackage ../pkgs/gosub { };
  imgpkg = super.callPackage ../pkgs/imgpkg { };
  kbld = super.callPackage ../pkgs/kbld { };
  pivnet = super.callPackage ../pkgs/pivnet { };
  ctr = super.callPackage ../pkgs/ctr { };
  slackdump = super.callPackage ../pkgs/slackdump { };
  vulnsvc = super.callPackage ../pkgs/vulnsvc { };
  tanzu-sm-installer = super.callPackage ../pkgs/tanzu-sm-installer { };
  cloud-provider-kind = super.callPackage ../pkgs/cloud-provider-kind { };
  sheepctl = super.callPackage ../pkgs/sheepctl { };
  kinto = super.callPackage ../pkgs/kinto { };
  token-count = super.callPackage ../pkgs/token-count { };
  
  # Build ibosh using our nixpkgs (which allows unfree licenses)
  # instead of the instant-bosh flake's nixpkgs
  ibosh = super.buildGoModule rec {
    pname = "ibosh";
    version = "0.1.0";

    src = super.fetchFromGitHub {
      owner = "rkoster";
      repo = "instant-bosh";
      rev = "d4758f800b88161ee59ccc0e97e4b9321706a07c";
      sha256 = "sha256-VhHjuiVtEUU7eUL5snHAQ2gM+AFycfmEwefA+pOROB4=";
    };

    vendorHash = null;

    subPackages = [ "cmd/ibosh" ];

    ldflags = [ "-s" "-w" ];

    nativeBuildInputs = [ super.installShellFiles ];

    postInstall = ''
      installShellCompletion --cmd ibosh \
        --bash <($out/bin/ibosh --generate-bash-completion) \
        --zsh <($out/bin/ibosh --generate-zsh-completion) \
        --fish <($out/bin/ibosh --generate-fish-completion)
    '';

    meta = with super.lib; {
      description = "instant-bosh CLI - Manage containerized BOSH directors";
      homepage = "https://github.com/rkoster/instant-bosh";
      license = licenses.bsl11;
      maintainers = with maintainers; [ rkoster ];
      mainProgram = "ibosh";
    };
  };
}
