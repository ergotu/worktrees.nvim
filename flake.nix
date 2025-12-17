{
  description = "A Neovim plugin for managing git worktrees";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , pre-commit-hooks
    ,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # Lua dependencies for testing
          luaEnv = pkgs.luajit.withPackages (
            ps: with ps; [
              busted
            ]
          );

          # Pre-commit hooks configuration
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              stylua = {
                enable = true;
                name = "stylua";
                entry = "${pkgs.stylua}/bin/stylua";
                files = "\\.lua$";
              };

              busted = {
                enable = true;
                name = "busted";
                entry = "${luaEnv}/bin/busted test/";
                pass_filenames = false;
              };

              nixpkgs-fmt = {
                enable = true;
                name = "nixpkgs-fmt";
                entry = "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt";
                files = "\\.nix$";
              };
            };
          };

          # Wrapped Neovim configuration
          neovimWrapped = pkgs.wrapNeovim pkgs.neovim-unwrapped {
            configure = {
              packages.worktrees-test = {
                start = [ pkgs.vimPlugins.snacks-nvim ];
              };
              customRC = ''
                lua << EOF
                -- Add current directory to runtime path to load the plugin
                vim.opt.rtp:prepend(vim.fn.getcwd())

                -- Disable persistent undo/backup for testing
                vim.opt.undofile = false
                vim.opt.backup = false

                -- Load the plugin safely
                local ok, worktrees = pcall(require, 'worktrees')
                if ok then
                  worktrees.setup()
                else
                  vim.notify("Failed to load worktrees plugin: " .. tostring(worktrees), vim.log.levels.ERROR)
                end

                -- Optional: Set some reasonable defaults for testing
                vim.opt.number = true
                vim.opt.expandtab = true
                vim.opt.shiftwidth = 2
                vim.opt.tabstop = 2
                EOF
              '';
            };
          };

          # Explicit script for nvim-test to avoid binary collision
          nvimTestScript = pkgs.writeShellScriptBin "nvim-test" ''
            exec ${neovimWrapped}/bin/nvim "$@"
          '';
        in
        {
          default = pkgs.mkShell {
            name = "worktrees.nvim-dev";

            buildInputs = with pkgs; [
              # Standard Neovim
              neovim

              # Test Runner Script
              nvimTestScript

              # Lua and testing
              luaEnv
              lua-language-server

              # Formatting
              stylua

              # Git for worktree operations
              git

              # Node.js and npx for MCP servers
              nodejs_22
              nodePackages.npm

              # Nix tooling
              nil
              nixpkgs-fmt
            ];

            shellHook = ''
              ${pre-commit-check.shellHook}

              echo "🌳 worktrees.nvim development environment"
              echo ""
              echo "Available commands:"
              echo "  nvim-test       - Neovim with plugin loaded (test config)"
              echo "  busted          - Run tests"
              echo "  stylua .        - Format code"
              echo "  stylua --check . - Check formatting"
              echo "  nix flake check - Run all checks"
              echo "  npx             - Run npm packages (for MCP servers)"
              echo ""
              echo "Pre-commit hooks installed ✓"
              echo "  - stylua (format Lua)"
              echo "  - busted (run tests)"
              echo "  - nixpkgs-fmt (format Nix)"
              echo ""
            '';
          };
        }
      );

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.vimUtils.buildVimPlugin {
            pname = "worktrees.nvim";
            version = "2.0.0";
            src = ./.;

            meta = with pkgs.lib; {
              description = "Neovim plugin for managing git worktrees";
              homepage = "https://github.com/ergotu/worktrees.nvim";
              license = licenses.mit;
              platforms = platforms.unix;
            };
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          luaEnv = pkgs.luajit.withPackages (
            ps: with ps; [
              busted
            ]
          );

          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              stylua = {
                enable = true;
                name = "stylua";
                entry = "${pkgs.stylua}/bin/stylua";
                files = "\\.lua$";
              };

              busted = {
                enable = true;
                name = "busted";
                entry = "${luaEnv}/bin/busted test/";
                pass_filenames = false;
              };

              nixpkgs-fmt = {
                enable = true;
                name = "nixpkgs-fmt";
                entry = "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt";
                files = "\\.nix$";
              };
            };
          };
        in
        {
          # Pre-commit checks
          pre-commit = pre-commit-check;

          # Run busted tests
          tests = pkgs.stdenv.mkDerivation {
            name = "worktrees.nvim-tests";
            src = ./.;

            buildInputs = [ luaEnv ];

            buildPhase = ''
              # Run busted tests
              busted --verbose test/
            '';

            installPhase = ''
              mkdir -p $out
              echo "Tests passed" > $out/result
            '';
          };

          # Check formatting with stylua
          formatting = pkgs.stdenv.mkDerivation {
            name = "worktrees.nvim-formatting";
            src = ./.;

            buildInputs = [ pkgs.stylua ];

            buildPhase = ''
              # Check that code is formatted
              stylua --check .
            '';

            installPhase = ''
              mkdir -p $out
              echo "Formatting check passed" > $out/result
            '';
          };
        }
      );
    };
}
