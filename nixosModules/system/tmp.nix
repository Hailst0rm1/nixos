{...}: {
  # Age out /tmp after 3 days instead of systemd's 10d default (tmp.conf).
  # 00-nixos.conf sorts before tmp.conf, so this line wins for /tmp.
  systemd.tmpfiles.rules = [
    "q /tmp 1777 root root 3d"
    # Serpantinum's pid and lock files must outlive the age limit.
    "x /tmp/serpantinumd.*"
  ];
}
