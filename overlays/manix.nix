self: super:
{
  manix_master = super.pkgs.manix.overrideAttrs (oldAttrs: rec {
  version = "0.6.2+7e905be";

  src = super.fetchFromGitHub {
    owner = "mlvzk";
    repo  = "manix";
    rev = "7e905be";
    sha256 = "1sjwlck3r83hy9qzzw1kjyfnd2r0pgrdl0km6lfmbj7xwshfd0as";
  };

  });
}
