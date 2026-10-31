{ flake, host }:
let
  lib = flake.inputs.nixpkgs.lib;
  c = flake.nixosConfigurations.${host}.config;
  h = c.home-manager.users.roberto;
  get = path: fallback: lib.attrByPath path fallback c;
  packages = ps: builtins.sort builtins.lessThan (map (p: "${lib.getName p}-${lib.getVersion p}") ps);
  paths = key: xs: map (x: if builtins.isString x then x else x.${key}) xs;
in
{
  hostname = c.networking.hostName;
  platform = c.nixpkgs.hostPlatform.system;
  stateVersion = c.system.stateVersion;
  homeStateVersion = h.home.stateVersion;
  kernel = c.boot.kernelPackages.kernel.version;
  kernelParams = c.boot.kernelParams;
  resumeDevice = c.boot.resumeDevice;
  kernelModules = c.boot.kernelModules;
  initrdModules = c.boot.initrd.availableKernelModules;
  systemdPatches = map (p: builtins.baseNameOf (toString p)) (c.systemd.package.patches or [ ]);
  logind = c.services.logind.settings;
  sleep = c.systemd.sleep.settings;
  fileSystems = lib.mapAttrs (_: fs: {
    inherit (fs)
      device
      fsType
      options
      neededForBoot
      ;
  }) c.fileSystems;
  disks = lib.mapAttrs (
    _: disk:
    let
      parts = disk.content.partitions;
      luks = parts.luks.content;
    in
    {
      inherit (disk) device;
      table = disk.content.type;
      espSize = parts.ESP.size;
      encryptionName = luks.name;
      encryptionFormatArgs = luks.extraFormatArgs;
      encryptionSettings = luks.settings;
      subvolumes = lib.mapAttrs (_: subvolume: {
        inherit (subvolume) mountpoint mountOptions;
      }) luks.content.subvolumes;
      swapSize = luks.content.subvolumes."/swap".swap.swapfile.size;
    }
  ) c.disko.devices.disk;
  ssh = c.services.openssh.settings;
  sshOpenFirewall = c.services.openssh.openFirewall;
  authorizedKeys = c.users.users.roberto.openssh.authorizedKeys.keys;
  uid = c.users.users.roberto.uid;
  groups = c.users.users.roberto.extraGroups;
  systemPackages = packages c.environment.systemPackages;
  homePackages = packages h.home.packages;
  homeVariables = h.home.sessionVariables;
  git = h.programs.git.settings;
  sshInitialization = {
    inherit (h.sshAuthSock.initialization) bash fish;
  };
  sshExtraConfig = h.programs.ssh.extraConfig;
  niri = get [ "programs" "niri" "enable" ] false;
  greetd = get [ "services" "greetd" "enable" ] false;
  secrets = builtins.attrNames c.sops.secrets;
  persistDirectories = paths "directory" c.environment.persistence."/persist".directories;
  persistFiles = paths "file" c.environment.persistence."/persist".files;
}
