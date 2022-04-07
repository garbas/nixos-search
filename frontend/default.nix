{ pkgs ? import <nixpkgs> { }
, channels
, version
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

  preferLocalBuild = true;

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

  ELASTICSEARCH_MAPPING_SCHEMA_VERSION = version;
  NIXOS_CHANNELS = builtins.toJSON channels;

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

  passthru.yarnPkg = yarnPkg;
}
