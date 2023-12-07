self: super:

let
  fly = (versionArg: sha256Arg: vendorSha256Arg: (
    super.buildGoModule rec {
      pname = "fly";
      version = versionArg;

     src = super.fetchFromGitHub {
       owner = "concourse";
       repo = "concourse";
       rev = "v${version}";
       sha256 = sha256Arg;
     };

     vendorSha256 = vendorSha256Arg;

     doCheck = false;

     subPackages = [ "fly" ];

     buildFlagsArray = ''
       -ldflags=
         -X github.com/concourse/concourse.Version=${version}
     '';

     postInstall = super.lib.optionalString (super.stdenv.hostPlatform == super.stdenv.buildPlatform) ''
       mkdir -p $out/share/{bash-completion/completions,zsh/site-functions}
       $out/bin/fly completion --shell bash > $out/share/bash-completion/completions/fly
       $out/bin/fly completion --shell zsh > $out/share/zsh/site-functions/_fly
     '';

     meta = with super.lib; {
       description = "A command line interface to Concourse CI";
       homepage = "https://concourse-ci.org";
       license = licenses.asl20;
       maintainers = with maintainers; [ rkoster ];
     };
    }));
in {
  # fly60 = fly "6.0.0" "0chavwymyh5kv4fkvdjvf3p5jjx4yn9aavq66333xnsl5pn7q9dq"
  # nix-build '<nixpkgs>' -A fly60 # will get you the real sha
  fly711 = fly "7.11.0" "sha256-lp6EXdwmgmjhFxRQXn2P4iRrtJS1QTvg4225V/6E7MI=" "sha256-p3EhXrRjAFG7Ayfj/ArAWO7KL3S/iR/nwFwXcDc+DSs=";
  fly710 = fly "7.10.0" "sha256-KmKIr7Y3CQmv1rXdju6xwUHABqj/dkXpgWc/yNrAza8=" "sha256-lc0okniezfTNLsnCBIABQxSgakRUidsprrEnkH8il2g=";
  fly79 = fly "7.9.1" "sha256-ySyarky92+VSo/KzQFrWeh35KDMTQDV34F5iFrARHJs=" "sha256-Oy1wP82ZhdpGHs/gpfdveOK/jI9yuo0D3JtxjLg+W/w=";
  fly78 = fly "7.8.2" "sha256-Lgsn5k3ITJnRnOXXZjfjlEEG+OvTZjFq+LB3Us3DH8k=" "sha256-91N6AOxXFOI6AM28avlInseAeZkqE9IfybJAX31tPDg=";
  fly75 = fly "7.5.0" "1085gxjrc5fh6a1j2cjcv3h4na4cabcliw6isgf0aimqz4ic1v77" "0dhcs5ma968bii2np51zbib2kvc8g8cpjkwzvnzgpmz7pi4z3b37";
  fly74 = fly "7.4.0" "0hy5sndqnbci42wc336hand9xkqkf6q5xdchxmjknnshkd6hzwaj" "02dknyv3nxy55dspdcv321x4db8hfxqmz0jivkijyd8a18d8g3r1";
  fly73 = fly "7.3.2" "0h6znpj5fmgjqpqcbvsv7kw6fi310lam7iw8pbg74a3k86mfygr0" "0g1rjs7ss0q5j9hbz5kykrkvl1sg6nxl82jay8mln7y88d3fnjnz";
  fly72 = fly "7.2.0" "1l3a9qhrdqk462fv2r7lcq5s725v5bv824wivc1sn9m03pkcvb5q" "1ljnn0swv9zv2kxa7g341iy5pbm3zjmq88c4k0zhsm4gag5dgyyq";
  fly67 = fly "6.7.5" "15nnnsq75s7139nna950p15xr73ssi37p7kxczg5p28s3gz23gx4" "08i1hpg1p6yrwh2vi29gm8z9kcw2z5jqvb08cmmy8mm2b5h19hi1";
  fly64 = fly "6.4.1" "16si1qm835yyvk2f0kwn9wnk8vpy5q4whgws1s2p6jr7dswg43h8" "0nv9q3j9cja8c6d7ac8fzb8zf82zz1z77f8cxvn3vxjki7fhlavm";
  fly60 = fly "6.0.0" "0chavwymyh5kv4fkvdjvf3p5jjx4yn9aavq66333xnsl5pn7q9dq" "127mc1wzqhn0l4ni6qxcx06qfdb1cgahzypjrs4vgr6i4sipjxck";
  fly56 = fly "5.6.0" "12hgd05j83lhx5257jnhwc22r2m5g7vl6ag8p8sn75l4122jj503" "0dqg0kw9an567kz0zk67a7gkjvrj3csdiy4r2caf3ikgzlwd228v";
  fly58 = fly "5.8.1" "0frd9rkzf7zsn0rncw24gdxdkbcl2rqhkn4v908sv0hshywps155" "1r55kf570b41lf3ap0l7dhfxmp8x82jpwyvl4wpwxjklnvin5w0j";
}
