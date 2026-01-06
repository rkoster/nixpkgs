{ buildGoModule, go_1_25, fetchFromGitHub, lib }:

(buildGoModule.override { go = go_1_25; }) rec {
  pname = "flasher-tool";
  version = "2643981a4a1f4f425ea4f331f66bdb9da6abf843";

  src = fetchFromGitHub {
    owner = "lxc";
    repo = "incus-os";
    rev = version;
    sha256 = "sha256-7AM3bOrM1vgzG1jmhJw9PU6vpEKWb5Ydt0XAHQh4GtE=";
  };

  sourceRoot = "${src.name}/incus-osd";

  vendorHash = "sha256-xRVWLXmWS9L/nyLaLaJW7rX6KkaqeBWjsaqSNH3Hi5Q=";

  subPackages = [ "cmd/flasher-tool" ];

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Incus OS flasher tool for creating bootable USB images";
    homepage = "https://github.com/lxc/incus-os";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
    mainProgram = "flasher-tool";
    platforms = platforms.linux;
  };
}
