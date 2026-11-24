# Match only a standalone RTK command, never a command that merely mentions it.
def rtk_owned:
  .type == "command" and ((.command // "") | test(
    "^(?:(?:/(?:[-A-Za-z0-9_.+]+/)*)?rtk hook claude|(?:[~$A-Za-z0-9_./+-]+/)?rtk-rewrite\\.sh)\\z"
  ));

def without_rtk:
  if any(.hooks[]?; rtk_owned) then
    .hooks |= map(select(rtk_owned | not)) | select(.hooks != [])
  else . end;

.statusLine = $statusLine |
.hooks.PreToolUse = ((.hooks.PreToolUse // [] | map(without_rtk)) + [
  {matcher: "Bash", hooks: [{type: "command", command: $rtkCommand}]}
])
