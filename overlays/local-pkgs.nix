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
  gh = super.callPackage ../pkgs/gh { };
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
  osstp-load = super.callPackage ../pkgs/osstp-load { };
  osspi-signer = super.callPackage ../pkgs/osspi-signer { };
}
