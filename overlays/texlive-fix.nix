final: prev: {
  # Override texlive format packages to disable strict mode and faketime
  texlive = prev.texlive // {
    # The issue is specifically with format generation
    mkFormatDerivation = {
      pkgName,
      engine ? pkgName,
      poolFile ? "tex", # ignored on modern TeX engines
      packages ? [],
      extraInputs ? [],
      dumpName ? pkgName,
      ...
    }:
      let
        origFmt = prev.texlive.mkFormatDerivation {
          inherit pkgName engine poolFile packages extraInputs dumpName;
        };
      in
        origFmt.overrideAttrs (oldAttrs: {
          # Patch the scripts before they run
          preBuild = ''
            ${oldAttrs.preBuild or ""}
            
            # Find the main format script that will be executed
            for f in $(find $out -name "*.fmt.sh" 2>/dev/null || echo ""); do
              echo "Patching format script: $f"
              
              # Create a backup
              cp $f $f.orig
              
              # Replace strict mode with no-strict and remove faketime
              sed -i.bak \
                -e 's|--strict|--no-strict|g' \
                -e 's|faketime -f.*tex|tex|g' \
                "$f"
                
              # Double-check to make sure script still references tex binary
              if ! grep -q "tex " "$f"; then
                echo "Warning: tex binary not found in patched script!"
                # Fall back to original, but with --no-strict
                cp $f.orig $f
                sed -i.bak 's|--strict|--no-strict|g' "$f"
              fi
            done
            
            # Create a wrapper faketime that just ignores the time options
            mkdir -p $out/bin
            cat > $out/bin/faketime << 'EOF'
#!/bin/sh
# Skip faketime options if present
if [ "$1" = "-f" ]; then
  shift 2
fi
# Just run the command without time manipulation
exec "$@"
EOF
            chmod +x $out/bin/faketime
            
            # Ensure our faketime is found first
            export PATH=$out/bin:$PATH
          '';
        });
  };
}
