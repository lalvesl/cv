{
  description = "abnTeX2 environment with TeX Live";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      for_each_system = nixpkgs.lib.genAttrs supportedSystems;

      pkgs = for_each_system (system: import nixpkgs { inherit system; });
      tex_pkg = for_each_system (
        system:
        (pkgs.${system}.texlive.combine {
          inherit (pkgs.${system}.texlive) scheme-full abntex2;
        })
      );
      general_pkgs = for_each_system (system: [
        tex_pkg.${system}
        pkgs.${system}.material-design-icons
        # pkgs.${system}.zathura
      ]);
    in
    {
      devShells = for_each_system (system: {
        default = pkgs.${system}.mkShell {
          name = "tex_in_live shell";
          buildInputs = [ ] ++ general_pkgs.${system};
        };
      });

      apps = for_each_system (system: {
        default = {
          type = "app";
          program = "${pkgs.${system}.writeShellScript "watch" ''
            echo "Watching for changes..."
            mkdir -p result_watch
            if ! pgrep -x "zathura" > /dev/null; then
              ${pkgs.${system}.zathura}/bin/zathura result_watch/main.pdf &
            fi
            exec ${tex_pkg.${system}}/bin/latexmk -pvc -pdf -outdir=result_watch main.tex
            find | grep "eps-converted-to.pdf" | xargs rm
          ''}";
        };

        clear = {
          type = "app";
          program = "${pkgs.${system}.writeShellScript "clear" ''
            echo "Remove generated files"
            git ls-files --others -i --exclude-standard | xargs rm -r
            rm -r result*
          ''}";
        };
      });

      # packages = for_each_system (system: {
      #   default = pkgs.${system}.writeShellScriptBin "latex-build" ''
      #     rm -r result
      #     mkdir -p result
      #     exec ${general_pkgs.${system}}/bin/latexmk -pdf -outdir=result main.tex
      #   '';
      # });

      packages = for_each_system (system: {
        default = pkgs.${system}.stdenv.mkDerivation {
          pname = "abntex2_some_document";
          version = "1.0";

          src = ./.;

          buildInputs = [ ] ++ general_pkgs.${system};

          buildPhase = ''
            echo "📦 Building your document..."
            mkdir -p $out
            cp -r $src/* .
            latexmk -pdf main.tex
            echo "✅ Build complete: main.pdf"
          '';

          installPhase = ''
            mkdir -p $out
            cp main.pdf $out/lucas_alves_de_lima.pdf
          '';

          # dontFixup = true;
          # unpackPhase = "true";
        };
      });
    };
}
