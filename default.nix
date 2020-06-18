{ pkgs ? import <nixpkgs> { }
, version ? "0"
}:
let
  package = builtins.fromJSON (builtins.readFile ./package.json);
  yarnPkg = pkgs.yarn2nix-moretea.mkYarnPackage rec {
    name = "${package.name}-yarn-${package.version}";
    src = null;
    dontUnpack = true;
    packageJSON = ./package.json;
    yarnLock = ./yarn.lock;
    preConfigure = ''
      mkdir ${package.name}
      cd ${package.name}
      ln -s ${packageJSON} ./package.json
      ln -s ${yarnLock} ./yarn.lock
    '';
    yarnPreBuild = ''
      mkdir -p $HOME/.node-gyp/${pkgs.nodejs.version}
      echo 9 > $HOME/.node-gyp/${pkgs.nodejs.version}/installVersion
      ln -sfv ${pkgs.nodejs}/include $HOME/.node-gyp/${pkgs.nodejs.version}
    '';
    pkgConfig = {
      node-sass = {
        buildInputs = [ pkgs.python pkgs.libsass pkgs.pkgconfig ];
        postInstall = ''
          LIBSASS_EXT=auto yarn --offline run build
          rm build/config.gypi
        '';
      };
    };
    publishBinsFor =
      [
        "webpack"
        "webpack-dev-server"
      ];
  };
in
pkgs.stdenv.mkDerivation {
  name = "${package.name}-${package.version}";
  src = pkgs.lib.cleanSource ./.;

  buildInputs =
    [
      yarnPkg
    ] ++
    (with pkgs; [
      nodejs
      elm2nix
    ]) ++
    (with pkgs.nodePackages; [
      yarn
    ]) ++
    (with pkgs.elmPackages; [
      elm
      elm-format
      elm-language-server
      elm-test
      elm-analyse
    ]);

  configurePhase = pkgs.elmPackages.fetchElmDeps {
    elmPackages = import ./elm-srcs.nix;
    elmVersion = pkgs.elmPackages.elm.version;
    registryDat = ./registry.dat;
  };

  patchPhase = ''
    rm -rf node_modules
    ln -sf ${yarnPkg}/libexec/${package.name}/node_modules .
  '';

  buildPhase = ''
    # Yarn writes cache directories etc to $HOME.
    export HOME=$PWD/yarn_home
    yarn prod
  '';

  installPhase = ''
    mkdir -p $out
    cp -R ./dist/* $out/
    cp netlify.toml $out/
  '';
  shellHook = ''
    rm -rf node_modules
    ln -sf ${yarnPkg}/libexec/${package.name}/node_modules .
    export PATH=$PWD/node_modules/.bin:$PATH
    echo "============================"
    echo "= To develop run: yarn dev ="
    echo "============================"
  '';

}
