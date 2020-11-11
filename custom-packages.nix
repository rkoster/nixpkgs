{ pkgs }:

let
  callPackage = pkgs.lib.callPackageWith (pkgs // pkgs.xlibs // self);
  
  self = {
    ssoca = callPackage ./pkgs/ssoca { };
    leftovers = callPackage ./pkgs/leftovers { };
    bosh = callPackage ./pkgs/bosh { };
    boshBootloader = callPackage ./pkgs/bosh-bootloader { };
    ytt = callPackage ./pkgs/ytt { };        
  };
in
self
