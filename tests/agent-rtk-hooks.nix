{
  kellanved,
  dancer,
  crokus,
}:
let
  inherit (kellanved) pkgs;
  inherit (pkgs) lib;
  home = host: host.config.home-manager.users.roberto;
  enabled = home kellanved;
  dancerEnabled = home dancer;
  crokusEnabled = crokus.config;
  disabled = home (
    kellanved.extendModules {
      modules = [
        { home-manager.users.roberto.profiles.agent-clis.rtkHooks.enable = lib.mkForce false; }
      ];
    }
  );
  files =
    cfg:
    lib.mapAttrs' (_: f: lib.nameValuePair f.target f) (lib.filterAttrs (_: f: f.enable) cfg.home.file);
  plugin = ".gemini/config/plugins/rtk";
  targets = [
    ".codex/hooks.json"
    "${plugin}/plugin.json"
    "${plugin}/hooks.json"
    "${plugin}/rules/AGENTS.md"
  ];
  agents = pkgs.llm-agents;
in
assert lib.all (cfg: cfg.profiles.agent-clis.rtkHooks.enable) [
  enabled
  dancerEnabled
  crokusEnabled
];
assert lib.all (p: !(files disabled ? ${p})) targets;
assert lib.all (p: !(files enabled).${p}.force) targets;
assert lib.all (p: !(files crokusEnabled ? ${p}) && files dancerEnabled ? ${p}) targets;
assert !(dancerEnabled.home.activation ? claudeCodeStatusLine);
assert crokusEnabled.home.activation ? claudeCodeStatusLine;
assert !(files enabled ? ".claude/settings.json");
pkgs.runCommand "agent-rtk-hooks" { nativeBuildInputs = [ pkgs.jq ]; } ''
  export HOME="$TMPDIR/home"
  ${lib.concatMapStringsSep "\n" (p: ''
    mkdir -p "$HOME/${dirOf p}"
    ln -s ${(files enabled).${p}.source} "$HOME/${p}"
  '') targets}
  rtk=${lib.getExe agents.rtk}
  jq -e --arg cmd "$rtk hook codex" '. == {hooks:{PreToolUse:[{matcher:"Bash", hooks:[{type:"command",command:$cmd}]}]}}' "$HOME/.codex/hooks.json"
  jq -e --arg cmd "$rtk hook antigravity" '. == {"rtk-rewrite":{enabled:true,PreToolUse:[{matcher:"run_command",hooks:[{type:"command",command:$cmd,timeout:10}]}]}}' "$HOME/${plugin}/hooks.json"
  mkdir -p "$HOME/${dirOf plugin}/neighbor"
  echo '{"name":"neighbor","description":"test","version":"1.0.0"}' > "$HOME/${dirOf plugin}/neighbor/plugin.json"
  ${lib.getExe agents.antigravity-cli} plugin list --json | jq -e '
    any(.[]; .name == "neighbor" and .enabled) and
    any(.[]; .name == "rtk" and .enabled and .rules == ["AGENTS.md"] and .hooks == ["rtk-rewrite"])'

  # Exercise the real Linux activation against fixtures, including a previous
  # managed rule and an overlapping rule that already belongs to the user.
  settings="$HOME/.gemini/antigravity-cli/settings.json"
  mkdir -p "$(dirname "$settings")"
  activate_agy() { ${
    lib.replaceStrings [ enabled.xdg.stateHome ] [ "$HOME/state" ]
      enabled.home.activation.agySandboxRuntime.data
  } }
  state="$HOME/state/agy-sandbox/managed-rules.json"
  mkdir -p "$(dirname "$state")"
  old='read_file(/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-old)'
  inherited='read_file(${agents.rtk})'
  jq -n --arg old "$old" '[$old]' > "$state"
  jq -n --arg old "$old" --arg inherited "$inherited" '{theme:"test",permissions:{deny:["other"],allow:[$old,$inherited,"local"]}}' > "$settings"
  cp "$settings" before-agy
  run() { :; }; activate_agy; cmp before-agy "$settings"
  run() { "$@"; }; activate_agy
  jq -e --arg old "$old" --arg inherited "$inherited" '.theme == "test" and .permissions.deny == ["other"] and (.permissions.allow | index($old) == null and index("local") != null and index($inherited) != null)' "$settings"
  jq -e --arg inherited "$inherited" 'length > 0 and index($inherited) == null and all(.[]; startswith("read_file(/nix/store/"))' "$state"
  cp "$settings" after-agy; activate_agy; cmp after-agy "$settings"

  mkdir -p "$HOME/.claude"
  settings="$HOME/.claude/settings.json"
  cat > "$settings" <<'JSON'
  {"theme":"dark","hooks":{"Stop":[],"PreToolUse":[
    {"matcher":"Bash","hooks":[{"type":"command","command":"~/.claude/hooks/rtk-rewrite.sh"},{"type":"command","command":"echo rtk hook claude"}]},
    {"matcher":"Read","hooks":[{"type":"prompt","prompt":"check"}]},
    {"matcher":"Bash","hooks":[{"type":"command","command":"rtk hook claude"},{"type":"command","command":"/old/bin/rtk hook claude"}]}
  ]}}
  JSON
  activate() { ${enabled.home.activation.claudeCodeStatusLine.data} }
  cp "$settings" before
  run() { :; }
  activate
  cmp before "$settings"
  run() { "$@"; }
  activate_off() { ${disabled.home.activation.claudeCodeStatusLine.data} }
  activate_off
  jq -S 'del(.statusLine)' "$settings" > off
  jq -S . before | cmp - off
  for pass in 1 2; do
    activate
    jq -e --arg cmd "$rtk hook claude" --arg status '${lib.getExe agents.ccstatusline}' '. == {
      theme:"dark",statusLine:{type:"command",command:$status,padding:0,refreshInterval:10},
      hooks:{Stop:[],PreToolUse:[
        {matcher:"Bash",hooks:[{type:"command",command:"echo rtk hook claude"}]},
        {matcher:"Read",hooks:[{type:"prompt",prompt:"check"}]},
        {matcher:"Bash",hooks:[{type:"command",command:$cmd}]}
      ]}}' "$settings"
    if [ "$pass" = 1 ]; then cp "$settings" first; else cmp first "$settings"; fi
  done
  # A generation with the option off still merges the status line; it must
  # not remove mutable hooks. A rollback therefore needs the manual cleanup.
  activate_off
  cmp first "$settings"
  # ccstatusline migrates old schemas in place; the real managed file is read-only.
  mkdir -p "$HOME/.config/ccstatusline"
  ln -s ${
    enabled.xdg.configFile."ccstatusline/settings.json".source
  } "$HOME/.config/ccstatusline/settings.json"
  echo '{"model":{"display_name":"renderer-test"}}' | ${lib.getExe agents.ccstatusline} > rendered
  grep -q 'renderer-test' rendered
  ! grep -qi 'invalid config' rendered || exit 1
  touch "$out"
''
