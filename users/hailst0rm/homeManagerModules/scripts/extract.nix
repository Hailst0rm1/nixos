{pkgs, ...}: {
  # Shell script to handle rebuilds in a more convenient way
  home.packages = with pkgs; [
    (
      writeShellScriptBin "ex"
      ''
         #!/usr/bin/env sh
        if [ -f $1 ] ; then
           case $1 in
             *.tar.bz2)   tar xjf $1   ;;
             *.tar.gz)    tar xzf $1   ;;
             *.bz2)       bunzip2 $1   ;;
             *.rar)       ${pkgs.unrar}/bin/unrar x $1   ;;
             *.gz)        gunzip $1    ;;
             *.tar)       tar xf $1    ;;
             *.tbz2)      tar xjf $1   ;;
             *.tgz)       tar xzf $1   ;;
             *.zip)       ${pkgs.unzip}/bin/unzip $1     ;;
             *.Z)         uncompress $1;;
             *.7z)        7z x $1      ;;
             *.deb)       ar x $1      ;;
             *.tar.xz)    tar xf $1    ;;
             *.tar.zst)   tar xf $1    ;;
             *)           echo "'$1' cannot be extracted via ex()" ;;
           esac
         else
           echo "'$1' is not a valid file"
         fi
      ''
    )
  ];
}
