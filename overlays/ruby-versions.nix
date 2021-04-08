self: super:
{
  ruby_2_7_3 = super.pkgs.ruby_2_7.overrideAttrs (oldAttrs: rec {
    version = "2.7.3";
    src = super.fetchFromGitHub {
      owner  = "ruby";
      repo   = "ruby";
      rev    = "v2_7_3";
      sha256 = "0vxg9w4dgpw2ig5snxmkahvzdp2yh71w8qm49g35d5hqdsql7yrx";
    };
  });
}
