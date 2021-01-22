self: super:

{
  fly67 = super.fly.overrideAttrs (old: {
    version = "6.7.1";

    src = super.fetchFromGitHub {
      owner = "concourse";
      repo = "concourse";
      rev = "v6.7.1";
      sha256 = "0jc0hr0h1xya7avzxdwmvhnsm5cr3g21pig52draz5vjaya7bg55";
    };

    vendorSha256 = null;
    deleteVendor = true;
    preBuild = ''
        unset GOPROXY
        go mod vendor
      '';

    buildFlagsArray = ''
        -ldflags=
        -X github.com/concourse/concourse.Version=6.7.1
      '';
  });
  
  fly64 = super.fly.overrideAttrs (old: {
    version = "6.4.0";

    src = super.fetchFromGitHub {
      owner = "concourse";
      repo = "concourse";
      rev = "v6.4.0";
      sha256 = "08lw345kzkic5b2dqj3d0d9x1mas9rpi4rdmbhww9r60swj169i7";
    };

    vendorSha256 = null;
    deleteVendor = true;
    preBuild = ''
        unset GOPROXY
        go mod vendor
      '';

    buildFlagsArray = ''
        -ldflags=
        -X github.com/concourse/concourse.Version=6.4.0
      '';
  });

  fly60 = super.fly.overrideAttrs (old: {
    version = "6.0.0";

    src = super.fetchFromGitHub {
      owner = "concourse";
      repo = "concourse";
      rev = "v6.0.0";
      sha256 = "0chavwymyh5kv4fkvdjvf3p5jjx4yn9aavq66333xnsl5pn7q9dq";
    };

    vendorSha256 = null;
    deleteVendor = true;
    preBuild = ''
        unset GOPROXY
        go mod vendor
      '';

    buildFlagsArray = ''
        -ldflags=
        -X github.com/concourse/concourse.Version=6.0.0
      '';
  });
}
