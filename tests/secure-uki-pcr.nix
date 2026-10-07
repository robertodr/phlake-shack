{
  pkgs,
  disko,
  impermanence,
  policyBypassControl ? false,
}:
let
  test = import ./secure-uki.nix {
    inherit pkgs disko impermanence;
    enableTpm = true;
    extraPcrScript = ''
      POLICY_BYPASS_CONTROL = ${if policyBypassControl then "True" else "False"}
      ${builtins.readFile ./secure-uki-pcr.py}
    '';
  };
in
test.extend {
  modules = [
    ({ lib, ... }: {
      name = lib.mkForce "dancer-secure-uki-pcr";
      meta.timeout = lib.mkForce 1800;
      globalTimeout = 1800;
    })
  ];
}
