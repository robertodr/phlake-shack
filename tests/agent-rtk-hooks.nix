{
  kellanved,
  dancer,
  crokus,
}:
let
  inherit (kellanved) pkgs;
  inherit (pkgs) lib;
  home = host: host.config.home-manager.users.roberto;
  enableLinux =
    host:
    home (
      host.extendModules {
        modules = [ { home-manager.users.roberto.profiles.agent-clis.rtkHooks.enable = true; } ];
      }
    );
  enabled = enableLinux kellanved;
  dancerEnabled = enableLinux dancer;
  crokusEnabled =
    (crokus.extendModules { modules = [ { profiles.agent-clis.rtkHooks.enable = true; } ]; }).config;
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
assert lib.all
  (cfg: !cfg.profiles.agent-clis.rtkHooks.enable && lib.all (p: !(files cfg ? ${p})) targets)
  [
    (home kellanved)
    (home dancer)
    crokus.config
  ];
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
  activate_off() { ${(home kellanved).home.activation.claudeCodeStatusLine.data} }
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
  touch "$out"
''
