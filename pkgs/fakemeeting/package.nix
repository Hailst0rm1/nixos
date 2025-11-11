{
  lib,
  python3,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "fakemeeting";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [
    python3
  ];

  installPhase = ''
        runHook preInstall

        mkdir -p $out/bin $out/share/fakemeeting

        # Install the Python script
        install -m755 ${./fakemeeting.py} $out/share/fakemeeting/fakemeeting.py

        # Install template files
        install -m644 ${./email_template.html} $out/share/fakemeeting/email_template.html
        install -m644 ${./iCalendar_template.ics} $out/share/fakemeeting/iCalendar_template.ics

        # Create wrapper script
        cat > $out/bin/fakemeeting << EOF
    #!/usr/bin/env bash
    exec ${python3}/bin/python3 $out/share/fakemeeting/fakemeeting.py "\$@"
    EOF
        chmod +x $out/bin/fakemeeting

        runHook postInstall
  '';

  meta = with lib; {
    description = "Create and send fake calendar meeting invitations via SMTP";
    longDescription = ''
      A tool to generate and send calendar invitations (.ics files) via email.
      Useful for social engineering assessments and phishing simulations.

      Usage: fakemeeting <smtp_server> <sender_email> <recipient_email> <event_url>
    '';
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.linux;
  };
}
