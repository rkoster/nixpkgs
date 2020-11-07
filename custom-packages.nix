{ pkgs }:

let
  callPackage = pkgs.lib.callPackageWith (pkgs // pkgs.xlibs // self);
  
  self = {
    ssoca = callPackage ./pkgs/ssoca { };
    leftovers = callPackage ./pkgs/leftovers { };
  };
in
self
