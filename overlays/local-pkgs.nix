self: super:

{
  ssoca = super.callPackage ../pkgs/ssoca { };
  leftovers = super.callPackage ../pkgs/leftovers { };
  bosh = super.callPackage ../pkgs/bosh { };
  boshBootloader = super.callPackage ../pkgs/bosh-bootloader { };
  ytt = super.callPackage ../pkgs/ytt { };
  vendir = super.callPackage ../pkgs/vendir { };
  cf = super.callPackage ../pkgs/cf { };
  spruce = super.callPackage ../pkgs/spruce { };
  safe = super.callPackage ../pkgs/safe { };
  genesis = super.callPackage ../pkgs/genesis { };
  credhub = super.callPackage ../pkgs/credhub { };
}
