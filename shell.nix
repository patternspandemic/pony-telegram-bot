#with import <nprepo> {
#  overlays = [ (self: super: {
#    ponyc = super.ponyc.override {
##      #stdenv = clangStdenv;
##      #llvm = super.llvm_38;
##      #libressl = super.libressl_2_5;
#    };
#  })];
#};

with import <nprepo> {};

let
  
in

stdenv.mkDerivation {
  name = "pony-telegram-bot";
  #buildInputs = [ (enableDebugging ponyc) gdb lldb ];
  buildInputs = [ ponyc ];
  buildCommand = ":";
  shellHook = ''
  '';
}
