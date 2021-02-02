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
  # fly60 = fly "6.0.0" "0chavwymyh5kv4fkvdjvf3p5jjx4yn9aavq66333xnsl5pn7q9dq" super.lib.fakeSha256;
  # nix-build '<nixpkgs>' -A fly60 # will get you the real sha
  fly67 = fly "6.7.1" "0jc0hr0h1xya7avzxdwmvhnsm5cr3g21pig52draz5vjaya7bg55" "1fxbxkg7disndlmb065abnfn7sn79qclkcbizmrq49f064w1ijr4";
  fly64 = fly "6.4.0" "08lw345kzkic5b2dqj3d0d9x1mas9rpi4rdmbhww9r60swj169i7" "0a78cjfj909ic8wci8id2h5f6r34h90myk6z7m918n08vxv60jvw";
  fly60 = fly "6.0.0" "0chavwymyh5kv4fkvdjvf3p5jjx4yn9aavq66333xnsl5pn7q9dq" "127mc1wzqhn0l4ni6qxcx06qfdb1cgahzypjrs4vgr6i4sipjxck";
}
