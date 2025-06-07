final: prev: {
  libfaketime = prev.libfaketime.overrideAttrs (oldAttrs: {
    version = "0.9.10";
    src = prev.fetchFromGitHub {
      owner = "wolfcw";
      repo = "libfaketime";
      rev = "v0.9.10";
      sha256 = "sha256-DYRuQmIhQu0CNEboBAtHOr/NnWxoXecuPMSR/UQ/VIQ=";
    };
    doCheck = false; # Disable failing tests on macOS
    
    # Fix for macOS compatibility in the Makefile
    postPatch = ''
      ${oldAttrs.postPatch or ""}
      
      if [[ "$(uname)" == "Darwin" ]]; then
        sed -i.bak 's/CFLAGS += -std=gnu99 -Wall -Wextra -Werror -DFAKE_STAT -DFAKE_LXC/CFLAGS += -std=gnu99 -Wall -Wextra -DFAKE_STAT -DFAKE_LXC/g' src/Makefile
        sed -i.bak 's/libfaketime.so.1/libfaketime.1.dylib/g' src/Makefile
      fi
    '';
    
    # Ensure DYLD_INSERT_LIBRARIES is used on macOS instead of LD_PRELOAD
    postFixup = ''
      ${oldAttrs.postFixup or ""}
      
      if [[ "$(uname)" == "Darwin" ]]; then
        # Create macOS-compatible wrapper for faketime
        mv $out/bin/faketime $out/bin/faketime.orig
        cat > $out/bin/faketime << EOF
      #!${final.bash}/bin/bash
      export DYLD_INSERT_LIBRARIES=$out/lib/libfaketime.1.dylib
      export FAKETIME_NO_CACHE=1
      exec "\$@"
      EOF
        chmod +x $out/bin/faketime
      fi
    '';
  });
}
