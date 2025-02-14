{ stdenv, lib, callPackage, fetchurl, fetchpatch, nixosTests }:

let
  common = opts: callPackage (import ../../browsers/firefox/common.nix opts) {
    webrtcSupport = false;
    geolocationSupport = false;
  };
in

rec {
  thunderbird = common rec {
    pname = "thunderbird";
    version = "91.1.0";
    application = "comm/mail";
    binaryName = pname;
    src = fetchurl {
      url = "mirror://mozilla/thunderbird/releases/${version}/source/thunderbird-${version}.source.tar.xz";
      sha512 = "c465ff25d67c5c28db53d3b1ccda10a743276e58c693406bf31bde0253f34123348180ae18765bd60b958c050e3a874dd69ac82d7612007a8c7a2e25939840ff";
    };
    patches = [
      ./no-buildconfig-90.patch

      # There is a bug in Thunderbird 91 where add-ons are required
      # to be signed when the build is run with default settings.
      # https://bugzilla.mozilla.org/show_bug.cgi?id=1727113
      # https://phabricator.services.mozilla.com/D124361
      ./D124361.diff
    ];

    meta = with lib; {
      description = "A full-featured e-mail client";
      homepage = "https://thunderbird.net/";
      maintainers = with maintainers; [ eelco lovesegfault pierron vcunat ];
      platforms = platforms.unix;
      badPlatforms = platforms.darwin;
      broken = stdenv.buildPlatform.is32bit; # since Firefox 60, build on 32-bit platforms fails with "out of memory".
                                             # not in `badPlatforms` because cross-compilation on 64-bit machine might work.
      license = licenses.mpl20;
    };
    updateScript = callPackage ./update.nix {
      attrPath = "thunderbird-unwrapped";
    };
  };

  thunderbird-78 = common rec {
    pname = "thunderbird";
    version = "78.13.0";
    application = "comm/mail";
    binaryName = pname;
    src = fetchurl {
      url = "mirror://mozilla/thunderbird/releases/${version}/source/thunderbird-${version}.source.tar.xz";
      sha512 = "daee9ea9e57bdfce231a35029807f279a06f8790d71efc8998c78eb42d99a93cf98623170947df99202da038f949ba9111a7ff7adbd43c161794deb6791370a0";
    };
    patches = [
      ./no-buildconfig-78.patch
    ];

    meta = with lib; {
      description = "A full-featured e-mail client";
      homepage = "https://thunderbird.net/";
      maintainers = with maintainers; [ eelco lovesegfault pierron vcunat ];
      platforms = platforms.unix;
      badPlatforms = platforms.darwin;
      broken = stdenv.buildPlatform.is32bit; # since Firefox 60, build on 32-bit platforms fails with "out of memory".
                                             # not in `badPlatforms` because cross-compilation on 64-bit machine might work.
      license = licenses.mpl20;
    };
    updateScript = callPackage ./update.nix {
      attrPath = "thunderbird-78-unwrapped";
    };
  };
}
