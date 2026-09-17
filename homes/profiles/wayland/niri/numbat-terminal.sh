app_id="com.roberto.numbat"
hidden_workspace="__numbat_scratchpad"
lock_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"

exec 9>"$lock_dir/numbat-terminal-$UID.lock"
flock 9

windows_json="$(niri msg --json windows)"
window_json="$(jq -c --arg app_id "$app_id" \
  '[.[] | select(.app_id == $app_id)][0] // empty' <<<"$windows_json")"

window_exists() {
  niri msg --json windows | jq -e --arg app_id "$app_id" \
    'any(.[]; .app_id == $app_id)' >/dev/null
}

if [[ -z "$window_json" ]]; then
  ghostty \
    --class="$app_id" \
    --title="Numbat" \
    --window-decoration=false \
    --gtk-titlebar=false \
    --gtk-single-instance=false \
    --quit-after-last-window-closed=true \
    --background=000000 \
    -e numbat 9>&- &
  launch_pid=$!
  launch_start_time="$(awk '{ print $22 }' "/proc/$launch_pid/stat" 2>/dev/null || true)"

  poll_attempts="${NUMBAT_TERMINAL_POLL_ATTEMPTS:-100}"
  poll_interval="${NUMBAT_TERMINAL_POLL_INTERVAL:-0.1}"
  for ((attempt = 0; attempt < poll_attempts; attempt++)); do
    if window_exists; then
      exit 0
    fi
    sleep "$poll_interval"
  done

  current_start_time="$(awk '{ print $22 }' "/proc/$launch_pid/stat" 2>/dev/null || true)"
  if [[ -n "$launch_start_time" && "$current_start_time" == "$launch_start_time" ]]; then
    kill "$launch_pid" 2>/dev/null || true
  fi
  wait "$launch_pid" 2>/dev/null || true
  if window_exists; then
    exit 0
  fi
  exit 1
fi

window_id="$(jq -r '.id' <<<"$window_json")"
is_focused="$(jq -r '.is_focused' <<<"$window_json")"
workspaces_json="$(niri msg --json workspaces)"
focused_workspace_name="$(jq -r \
  '[.[] | select(.is_focused)][0].name // empty' <<<"$workspaces_json")"

if [[ "$is_focused" == "true" ]]; then
  if [[ "$focused_workspace_name" == "$hidden_workspace" ]]; then
    exec niri msg action focus-workspace-previous
  fi

  exec niri msg action move-window-to-workspace \
    "$hidden_workspace" \
    --window-id "$window_id" \
    --focus false
fi

workspace_ref="$(jq -r \
  '[.[] | select(.is_focused)][0] | if .name then .name else (.idx | tostring) end' \
  <<<"$workspaces_json")"

niri msg action move-window-to-workspace \
  "$workspace_ref" \
  --window-id "$window_id" \
  --focus false
exec niri msg action focus-window --id "$window_id"
