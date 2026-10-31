{
  pkgs,
  fwupdPackage,
  fwupdTmpfilesRules,
}:
pkgs.testers.runNixOSTest {
  name = "dancer-fwupd-efi";
  nodes.machine = {
    services.fwupd = {
      enable = true;
      package = fwupdPackage;
    };
    # Exercise the actual Dancer rule, not a duplicate written only for this VM.
    systemd.tmpfiles.rules = builtins.filter (
      rule: pkgs.lib.hasInfix "/run/fwupd-efi" rule
    ) fwupdTmpfilesRules;
  };
  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    def verify_helper():
        machine.succeed("test -s /run/fwupd-efi/fwupdx64.efi")
        machine.succeed("cmp /run/fwupd-efi/fwupdx64.efi ${fwupdPackage.fwupd-efi}/libexec/fwupd/efi/fwupdx64.efi")
        versions = machine.succeed("fwupdmgr --version")
        lines = [line for line in versions.splitlines() if "org.freedesktop.fwupd" in line]
        assert len(lines) == 2 and all("${fwupdPackage.version}" in line for line in lines), versions

    verify_helper()
    # This is a synthetic preservation marker, NOT a valid signed EFI binary.
    machine.succeed("printf synthetic-preservation-marker > /run/fwupd-efi/fwupdx64.efi.signed")
    machine.succeed("systemd-tmpfiles --create")
    assert machine.succeed("cat /run/fwupd-efi/fwupdx64.efi.signed").strip() == "synthetic-preservation-marker"
    machine.succeed("rm /run/fwupd-efi/fwupdx64.efi.signed")

    machine.shutdown()
    machine.wait_for_shutdown()
    machine.start()
    machine.wait_for_unit("multi-user.target")
    verify_helper()
    machine.succeed("test ! -e /run/fwupd-efi/fwupdx64.efi.signed")
  '';
}
