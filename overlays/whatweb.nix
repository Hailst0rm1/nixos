final: prev: {
  # FIX for whatweb: nixpkgs passes `ruby_3_4` to bundlerEnv but bundlerEnv expects `ruby`,
  # so gems always build with the default ruby. The installPhase also hardcodes gems/3.3.0.
  # Ruby 3.4 removed getoptlong from stdlib which breaks whatweb.
  # Fix: override ruby_3_4 → ruby_3_3 for the exec line, and patch installPhase to use
  # the correct ruby and dynamically resolve the gem path.
  whatweb = (prev.whatweb.override {ruby_3_4 = prev.ruby_3_3;}).overrideAttrs (old: {
    installPhase = let
      ruby = prev.ruby_3_3;
      gems = builtins.head (builtins.filter (i: (i.name or "") == "whatweb-env") (old.buildInputs or []));
      gempath = "${gems}/lib/ruby/gems/*";
    in ''
      runHook preInstall

      raw=$out/share/whatweb/whatweb
      rm $out/bin/whatweb
      cat << EOF > $out/bin/whatweb
      #!/bin/sh -e
      export GEM_PATH="\$(echo ${gempath})"
      export RUBYOPT="-W0"
      exec ${ruby}/bin/ruby "$raw" "\$@"
      EOF
      chmod +x $out/bin/whatweb

      runHook postInstall
    '';
  });
}
