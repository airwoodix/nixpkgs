/* This file defines the composition for Lua packages.  It has
   been factored out of all-packages.nix because there are many of
   them.  Also, because most Nix expressions for Lua packages are
   trivial, most are actually defined here.  I.e. there's no function
   for each package in a separate file: the call to the function would
   be almost as must code as the function itself. */

{ fetchurl, stdenv, lua, unzip, pkg-config
, pcre, oniguruma, gnulib, tre, glibc, sqlite, openssl, expat
, autoreconfHook, gnum4
, postgresql, cyrus_sasl
, fetchFromGitHub, which, writeText
, pkgs
, lib
}:

let
  packages = ( self:

let
  luaAtLeast = lib.versionAtLeast lua.luaversion;
  luaOlder = lib.versionOlder lua.luaversion;
  isLua51 = (lib.versions.majorMinor lua.version) == "5.1";
  isLua52 = (lib.versions.majorMinor lua.version) == "5.2";
  isLua53 = lua.luaversion == "5.3";
  isLuaJIT = lib.getName lua == "luajit";

  lua-setup-hook = callPackage ../development/interpreters/lua-5/setup-hook.nix { };

  # Check whether a derivation provides a lua module.
  hasLuaModule = drv: drv ? luaModule ;

  callPackage = pkgs.newScope self;

  requiredLuaModules = drvs: with lib; let
    modules =  filter hasLuaModule drvs;
  in unique ([lua] ++ modules ++ concatLists (catAttrs "requiredLuaModules" modules));

  # Convert derivation to a lua module.
  toLuaModule = drv:
    drv.overrideAttrs( oldAttrs: {
      # Use passthru in order to prevent rebuilds when possible.
      passthru = (oldAttrs.passthru or {})// {
        luaModule = lua;
        requiredLuaModules = requiredLuaModules drv.propagatedBuildInputs;
      };
    });


  platformString =
    if stdenv.isDarwin then "macosx"
    else if stdenv.isFreeBSD then "freebsd"
    else if stdenv.isLinux then "linux"
    else if stdenv.isSunOS then "solaris"
    else throw "unsupported platform";

  buildLuaApplication = args: buildLuarocksPackage ({namePrefix="";} // args );

  buildLuarocksPackage = with pkgs.lib; makeOverridable(callPackage ../development/interpreters/lua-5/build-lua-package.nix {
    inherit toLuaModule;
    inherit lua;
  });
in
with self; {

  getLuaPathList = majorVersion: [
    "share/lua/${majorVersion}/?.lua"
    "share/lua/${majorVersion}/?/init.lua"
  ];
  getLuaCPathList = majorVersion: [
    "lib/lua/${majorVersion}/?.so"
  ];

  # helper functions for dealing with LUA_PATH and LUA_CPATH
  getPath = drv: pathListForVersion:
    lib.concatMapStringsSep ";" (path: "${drv}/${path}") (pathListForVersion lua.luaversion);
  getLuaPath = drv: getPath drv getLuaPathList;
  getLuaCPath = drv: getPath drv getLuaCPathList;

  #define build lua package function
  buildLuaPackage = callPackage ../development/lua-modules/generic {
    inherit lua writeText;
  };


  inherit toLuaModule hasLuaModule lua-setup-hook;
  inherit buildLuarocksPackage buildLuaApplication;
  inherit requiredLuaModules luaOlder luaAtLeast
    isLua51 isLua52 isLua53 isLuaJIT lua callPackage;

  # wraps programs in $out/bin with valid LUA_PATH/LUA_CPATH
  wrapLua = callPackage ../development/interpreters/lua-5/wrap-lua.nix {
    inherit lua; inherit (pkgs) makeSetupHook makeWrapper;
  };

  luarocks = callPackage ../development/tools/misc/luarocks {
    inherit lua;
  };

  luarocks-nix = callPackage ../development/tools/misc/luarocks/luarocks-nix.nix { };

  luxio = buildLuaPackage {
    pname = "luxio";
    version = "13";

    src = fetchurl {
      url = "https://git.gitano.org.uk/luxio.git/snapshot/luxio-luxio-13.tar.bz2";
      sha256 = "1hvwslc25q7k82rxk461zr1a2041nxg7sn3sw3w0y5jxf0giz2pz";
    };

    nativeBuildInputs = [ which pkg-config ];

    postPatch = ''
      patchShebangs .
    '';

    preBuild = ''
      makeFlagsArray=(
        INST_LIBDIR="$out/lib/lua/${lua.luaversion}"
        INST_LUADIR="$out/share/lua/${lua.luaversion}"
        LUA_BINDIR="$out/bin"
        INSTALL=install
        );
    '';

    meta = with lib; {
      description = "Lightweight UNIX I/O and POSIX binding for Lua";
      homepage = "https://www.gitano.org.uk/luxio/";
      license = licenses.mit;
      maintainers = with maintainers; [ richardipsum ];
      platforms = platforms.unix;
    };
  };

  vicious = toLuaModule(stdenv.mkDerivation rec {
    pname = "vicious";
    version = "2.5.0";

    src = fetchFromGitHub {
      owner = "Mic92";
      repo = "vicious";
      rev = "v${version}";
      sha256 = "0lb90334mz0my8ydsmnsnkki0xr58kinsg0hf9d6k4b0vjfi0r0a";
    };

    buildInputs = [ lua ];

    installPhase = ''
      mkdir -p $out/lib/lua/${lua.luaversion}/
      cp -r . $out/lib/lua/${lua.luaversion}/vicious/
      printf "package.path = '$out/lib/lua/${lua.luaversion}/?/init.lua;' ..  package.path\nreturn require((...) .. '.init')\n" > $out/lib/lua/${lua.luaversion}/vicious.lua
    '';

    meta = with lib; {
      description = "A modular widget library for the awesome window manager";
      homepage    = "https://github.com/Mic92/vicious";
      license     = licenses.gpl2;
      maintainers = with maintainers; [ makefu mic92 ];
      platforms   = platforms.linux;
    };
  });

});
in packages
