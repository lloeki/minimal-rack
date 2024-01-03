{
  pkgs ? import <nixpkgs> {},
}:
let
  ruby = pkgs.ruby_3_2;
  llvm = pkgs.llvmPackages_16;
  gcc = pkgs.gcc13;
in llvm.stdenv.mkDerivation {
  name = "sandbox-minimal.shell";

  buildInputs = [
    ruby

    # for psych >= 5.1 pulled by rails 7.1
    pkgs.libyaml.dev
  ];


  shellHook = ''
    export RUBY_VERSION="$(ruby -e 'puts RUBY_VERSION.gsub(/\d+$/, "0")')"
    export GEM_HOME="$(pwd)/vendor/bundle/ruby/$RUBY_VERSION"
    export BUNDLE_PATH="$(pwd)/vendor/bundle"
    export PATH="$GEM_HOME/bin:$PATH"
  '';
}
