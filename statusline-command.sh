#!/bin/bash
# Claude Code status line
#
# Output format:
#   ☯ 20:31:29 | Opus 4.6 | 12% ctx | $37.15 | [caveman]
#   ~/w/l/dev
#   tks 8.6k (490 > 8.1k) / 366.0k | ⏱  05:11:00 (api 4:01) / 15:32:00 (6 sess)

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')

state_dir="$HOME/.claude/state"
session_file="$state_dir/session.json"
today=$(date +%Y-%m-%d)

# --- Update daily accumulator ---
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
cur_in=$(echo "$input"  | jq -r '.context_window.total_input_tokens // 0')
cur_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
cur_dur=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
cur_cost=$(echo "$input"| jq -r '.cost.total_cost_usd // 0')

snap_file="$state_dir/snap-${session_id}.json"
cat > "$snap_file" 2>/dev/null <<SNAP
{"in":$cur_in,"out":$cur_out,"dur":$cur_dur,"cost":$cur_cost}
SNAP

# --- Track parts/replies since last prompt ---
# A new user prompt is detected when:
#   - total_output_tokens is unchanged since last call (Claude hasn't replied yet), AND
#   - total_input_tokens has grown (the new message was added to context)
# This is reliable because output tokens only grow while Claude is generating a
# reply; they stay flat between the moment the user sends a message and the first
# statusline refresh of the new reply.
parts_file="$state_dir/parts-${session_id}.json"
parts_count=0
last_in=0
last_out=0
if [ -f "$parts_file" ]; then
  parts_count=$(jq -r '.parts // 0'    "$parts_file" 2>/dev/null || echo 0)
  last_in=$(jq -r '.last_in // 0'      "$parts_file" 2>/dev/null || echo 0)
  last_out=$(jq -r '.last_out // 0'    "$parts_file" 2>/dev/null || echo 0)
fi

in_delta=$(( cur_in - last_in ))
out_delta=$(( cur_out - last_out ))

if [ "$parts_count" -eq 0 ]; then
  # First ever call for this session
  parts_count=1
elif [ "$out_delta" -eq 0 ] && [ "$in_delta" -gt 0 ]; then
  # Output hasn't grown but input has — new user prompt just arrived
  parts_count=1
else
  parts_count=$(( parts_count + 1 ))
fi
cat > "$parts_file" 2>/dev/null <<PARTS
{"parts":$parts_count,"last_in":$cur_in,"last_out":$cur_out}
PARTS

# Aggregate daily snapshots
daily_in=0 daily_out=0 daily_dur=0 daily_cost=0 daily_sessions=0
if [ -d "$state_dir" ]; then
  for sf in "$state_dir"/snap-*.json; do
    [ -f "$sf" ] || continue
    if [ "$(date -r "$sf" +%Y-%m-%d)" = "$today" ]; then
      daily_sessions=$((daily_sessions + 1))
      daily_in=$((daily_in   + $(jq -r '.in  // 0' "$sf")))
      daily_out=$((daily_out + $(jq -r '.out // 0' "$sf")))
      daily_dur=$((daily_dur + $(jq -r '.dur // 0' "$sf")))
      daily_cost=$(echo "$daily_cost + $(jq -r '.cost // 0' "$sf")" | bc 2>/dev/null || echo "$daily_cost")
    fi
  done
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

short_pwd() {
  local p="$1"
  p="${p/#$HOME/\~}"
  sed 's:\([^/]\)[^/]*/:\1/:g' <<<"$p"
}

# Format milliseconds -> HH:MM:SS or M:SS or 0:SS
fmt_duration() {
  local ms="$1"
  local total_secs=$(( ms / 1000 ))
  local h=$(( total_secs / 3600 ))
  local m=$(( (total_secs % 3600) / 60 ))
  local s=$(( total_secs % 60 ))
  if (( h > 0 )); then
    printf '%02d:%02d:%02d' "$h" "$m" "$s"
  elif (( m > 0 )); then
    printf '%d:%02d' "$m" "$s"
  else
    printf '0:%02d' "$s"
  fi
}

fmt_tokens() {
  local t="$1"
  if (( t >= 1000000 )); then
    printf '%s.%sM' "$(( t / 1000000 ))" "$(( (t % 1000000) / 100000 ))"
  elif (( t >= 1000 )); then
    printf '%s.%sk' "$(( t / 1000 ))" "$(( (t % 1000) / 100 ))"
  else
    printf '%s' "$t"
  fi
}

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
yellow=$'\e[1;33m'
green=$'\e[1;32m'
purple=$'\e[3;35m'
cyan=$'\e[1;36m'
dim=$'\e[2m'
blue=$'\e[1;34m'
red=$'\e[1;31m'
reset=$'\e[0m'

# ---------------------------------------------------------------------------
# Extract JSON fields
# ---------------------------------------------------------------------------
model=$(echo "$input"        | jq -r '.model.display_name // "?"')
total_in=$(echo "$input"     | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input"    | jq -r '.context_window.total_output_tokens // 0')
ctx_used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
duration_ms=$(echo "$input"  | jq -r '.cost.total_duration_ms // 0')
api_duration_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')

# Shorten model name
model_short=$(echo "$model" | sed 's/^[Cc]laude[[:space:]]*//' | sed 's/[[:space:]]*[0-9]\{8\}$//')

# ---------------------------------------------------------------------------
# Skills from session state
# ---------------------------------------------------------------------------
skills_str=""
if [ -f "$session_file" ]; then
  skills=$(jq -r '.skills // [] | join(",")' "$session_file" 2>/dev/null)
  if [ -n "$skills" ]; then
    skills_str="[${skills}]"
  fi
fi

# ---------------------------------------------------------------------------
# Computed values
# ---------------------------------------------------------------------------
# time_str=$(date +%H:%M:%S)
dir_str=$(short_pwd "$cwd")

# Context
ctx_str=""
ctx_int=0
if [ -n "$ctx_used_pct" ]; then
  ctx_int=${ctx_used_pct%.*}
  ctx_str="${ctx_int}% ctx"
fi

# Daily cost
daily_cost_str=""
if [ "$daily_cost" != "0" ] && [ -n "$daily_cost" ]; then
  daily_cost_fmt=$(printf '%.2f' "$daily_cost" 2>/dev/null || echo "$daily_cost")
  daily_cost_str="\$${daily_cost_fmt}"
fi

# Session tokens
total_tokens=$(( total_in + total_out ))
tok_fmt=$(fmt_tokens "$total_tokens")
in_fmt=$(fmt_tokens "$total_in")
out_fmt=$(fmt_tokens "$total_out")
duration_str=$(fmt_duration "$duration_ms")
api_str=$(fmt_duration "$api_duration_ms")

# Daily tokens/duration
daily_tokens=$(( daily_in + daily_out ))
daily_tok_fmt=$(fmt_tokens "$daily_tokens")
daily_dur_str=$(fmt_duration "$daily_dur")

# ---------------------------------------------------------------------------
# Line 1: ☯ time | model | ctx% | cost | [skills]
# ---------------------------------------------------------------------------
# line1="☯ ${yellow}${time_str}${reset}"
line1="☯ ${yellow}${dir_str}${reset}"
line1+=" ${dim}|${reset} ${blue}${model_short}${reset}"
if [ -n "$ctx_str" ]; then
  if (( ctx_int >= 80 )); then
    line1+=" ${dim}|${reset} ${red}${ctx_str}${reset}"
  else
    line1+=" ${dim}|${reset} ${cyan}${ctx_str}${reset}"
  fi
fi
if [ -n "$daily_cost_str" ]; then
  line1+=" ${dim}|${reset} ${yellow}${daily_cost_str}${reset}"
fi
if [ -n "$skills_str" ]; then
  line1+=" ${dim}|${reset} ${purple}${skills_str}${reset}"
fi
if [ -n "$session_id" ] && [ "$session_id" != "unknown" ]; then
  line1+=" ${dim}|${reset} ${dim}${session_id}${reset}"
fi
printf '%s\n' "$line1"

# ---------------------------------------------------------------------------
# Line 2: short cwd
# ---------------------------------------------------------------------------
# printf "${dim}%s${reset}\n" "$dir_str"

# ---------------------------------------------------------------------------
# Line 3: tks session (in > out) / daily | ⏱ session (api) / daily (sess)
# ---------------------------------------------------------------------------
printf "${dim}tks${reset} ${cyan}%s${reset} ${dim}(%s > %s)${reset} ${dim}/${reset} ${cyan}%s${reset} ${dim}|${reset} ⏱  ${green}%s${reset} ${dim}(api %s)${reset} ${dim}/${reset} ${green}%s${reset} ${dim}(%d sess)${reset} ${dim}|${reset} ${yellow}%d${reset}${dim}p${reset}\n" \
  "$tok_fmt" "$in_fmt" "$out_fmt" "$daily_tok_fmt" "$duration_str" "$api_str" "$daily_dur_str" "$daily_sessions" "$parts_count"

# ---------------------------------------------------------------------------
# Line 4 (optional): task progress bar from openspec changes tasks.md files
# Scans $cwd/openspec/changes/*/tasks.md (non-archived), counts - [x] vs - [ ]
# ---------------------------------------------------------------------------
tp_completed=0
tp_total=0
tp_label=""
changes_dir="${cwd}/openspec/changes"
if [ -d "$changes_dir" ]; then
  # Only look at non-archived changes (direct subdirs, not archive/)
  for tasks_file in "$changes_dir"/*/tasks.md; do
    [ -f "$tasks_file" ] || continue
    done_count=$(grep -c '^\- \[x\]' "$tasks_file" 2>/dev/null || echo 0)
    todo_count=$(grep -c '^\- \[ \]' "$tasks_file" 2>/dev/null || echo 0)
    file_total=$(( done_count + todo_count ))
    if [ "$file_total" -gt 0 ]; then
      tp_completed=$(( tp_completed + done_count ))
      tp_total=$(( tp_total + file_total ))
      # Use the change dir name as label (last non-tasks.md path component)
      slug=$(basename "$(dirname "$tasks_file")")
      if [ -n "$tp_label" ]; then
        tp_label="${tp_label}, ${slug}"
      else
        tp_label="$slug"
      fi
    fi
  done
fi

if [ "$tp_total" -gt 0 ] 2>/dev/null; then
  bar_width=20
  filled=$(( tp_completed * bar_width / tp_total ))
  empty=$(( bar_width - filled ))
  bar=""
  i=0
  while [ "$i" -lt "$filled" ]; do bar="${bar}█"; i=$(( i + 1 )); done
  i=0
  while [ "$i" -lt "$empty" ]; do bar="${bar}░"; i=$(( i + 1 )); done

  if [ -n "$tp_label" ]; then
    printf "${dim}[${reset}${green}%s${reset}${dim}]${reset} ${yellow}%d/%d${reset}${dim} tasks${reset} ${dim}|${reset} ${purple}%s${reset}\n" \
      "$bar" "$tp_completed" "$tp_total" "$tp_label"
  else
    printf "${dim}[${reset}${green}%s${reset}${dim}]${reset} ${yellow}%d/%d${reset}${dim} tasks${reset}\n" \
      "$bar" "$tp_completed" "$tp_total"
  fi
fi
