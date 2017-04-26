with import <nprepo> {};

let
  
in

stdenv.mkDerivation {
  name = "pony-telegram-bot";
  buildInputs = [ ponyc ];
  buildCommand = ":";
  shellHook = ''
  '';
}
