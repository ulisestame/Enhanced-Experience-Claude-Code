#!/bin/bash
input=$(cat)

# One jq pass for every field: the bar refreshes once a second, so spawning
# a dozen processes per render would be a dozen times the cost for nothing.
# Fields are joined with US (0x1f), not a tab: bash treats tab as whitespace
# IFS and collapses empty fields, which silently shifts every later value.
IFS=$'\x1f' read -r MODEL EFFORT DIR PCT COST ADDED REMOVED DURATION_MS \
    RATE5 RATE7 RATE5_RESET RATE7_RESET <<< "$(printf '%s' "$input" | jq -r '
    [ .model.display_name,
      (.effort.level // ""),
      .workspace.current_dir,
      ((.context_window.used_percentage // 0) | floor),
      (.cost.total_cost_usd // 0),
      (.cost.total_lines_added // 0),
      (.cost.total_lines_removed // 0),
      (.cost.total_duration_ms // 0),
      (.rate_limits.five_hour.used_percentage // ""),
      (.rate_limits.seven_day.used_percentage // ""),
      (.rate_limits.five_hour.resets_at // ""),
      (.rate_limits.seven_day.resets_at // "")
    ] | map(tostring) | join("\u001f")')"
DIR_NAME="${DIR##*/}"

COST_FMT=$(printf '$%.4f' "$COST")

# Scale the unit to the magnitude: days of uptime should not read as 10000m
fmt_duration() {
    local s=$1 d h m
    d=$((s / 86400)); h=$((s % 86400 / 3600)); m=$((s % 3600 / 60))
    if   [ "$d" -gt 0 ]; then echo "${d}d ${h}h"
    elif [ "$h" -gt 0 ]; then echo "${h}h ${m}m"
    elif [ "$m" -gt 0 ]; then echo "${m}m $((s % 60))s"
    else                      echo "${s}s"; fi
}

# Time left until a rate-limit window resets, compact: "2h14m" / "48m" / "6d3h"
fmt_until() {
    local left=$(( $1 - $(date +%s) )) d h m
    [ "$left" -le 0 ] && { echo "now"; return; }
    d=$((left / 86400)); h=$((left % 86400 / 3600)); m=$((left % 3600 / 60))
    if   [ "$d" -gt 0 ]; then echo "${d}d${h}h"
    elif [ "$h" -gt 0 ]; then echo "${h}h${m}m"
    else                      echo "${m}m"; fi
}

DURATION_FMT=$(fmt_duration $((DURATION_MS / 1000)))

# --- FUN TEST: animation + truecolor (not committed) ---
TICK=$(( $(date +%s) % 8 ))
SPIN_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧)
SPIN=${SPIN_FRAMES[$TICK]}
# One shared green->red ramp, sampled by position, so the bar cells and the
# percentage that follows them are always the same colour at the same point.
ramp_at() {
    local i=$1 w=$2 r g
    r=$(( 60 + (195 * i / (w - 1)) ))
    g=$(( 235 - (150 * i / (w - 1)) ))
    printf '%s;%s;90' "$r" "$g"
}

# Context bar: each column is split in two with "▌" — foreground paints the
# left half, background the right — so a 22-column bar carries 44 gradient
# steps and 44 fill steps without getting any wider.
gradient_bar() {
    # Paint with background colour on a plain space: the cell is filled by the
    # terminal itself, so no glyph metrics are involved and every cell is
    # exactly the same height. Block glyphs like "▌" are a pixel short of the
    # cell in many fonts, which shows as a notch along the bar.
    local w=$1 pct=$2 out="" i filled c
    filled=$(( pct * w / 100 ))
    for ((i = 0; i < w; i++)); do
        if [ "$i" -lt "$filled" ]; then c=$(ramp_at $i $w); else c="58;58;70"; fi
        out+="\033[48;2;${c}m "
    done
    printf '%s\033[0m' "$out"
}

GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

if [ "$PCT" -ge 66 ]; then
    BAR_COLOR=$RED
elif [ "$PCT" -ge 36 ]; then
    BAR_COLOR=$YELLOW
else
    BAR_COLOR=$GREEN
fi

BAR_WIDTH=17
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /▓}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"
BAR="${BAR_COLOR}${BAR}${RESET}"

# Lines changed, green/red, only when this session has touched something
DIFF_SEG=""
if [ "$ADDED" -gt 0 ] || [ "$REMOVED" -gt 0 ]; then
    DIFF_SEG="${GREEN}+${ADDED}${RESET}/${RED}-${REMOVED}${RESET}"
fi

MODEL_SEG="[$MODEL]"
[ -n "$EFFORT" ] && MODEL_SEG="[$MODEL · ${EFFORT}]"

# Line 1: dir, git branch, model, effort, ctx, cost
if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
    BRANCH_SEG="🌿 $BRANCH"
    [ -n "$DIFF_SEG" ] && BRANCH_SEG="$BRANCH_SEG $DIFF_SEG"
    echo -e "📁 $DIR_NAME | $BRANCH_SEG | $MODEL_SEG | 💰 $COST_FMT"
else
    echo -e "📁 $DIR_NAME | $MODEL_SEG | 💰 $COST_FMT"
fi

# A blank row between the two lines — one terminal row is the smallest
# vertical gap available.
echo ""
# Line 2: rate limits, ctx
PARTS=("$SPIN $DURATION_FMT")
RESETS=()
if [ -n "$RATE5" ]; then
    PARTS+=("⚡ 5hr: ${RATE5%.*}%")
    [ -n "$RATE5_RESET" ] && RESETS+=("$(fmt_until "${RATE5_RESET%.*}")")
fi
if [ -n "$RATE7" ]; then
    PARTS+=("📅 weekly: ${RATE7%.*}%")
    [ -n "$RATE7_RESET" ] && RESETS+=("$(fmt_until "${RATE7_RESET%.*}")")
fi
# Resets get their own segment; values follow the same order as the
# percentage segments above (5hr first, then weekly).
if [ ${#RESETS[@]} -gt 0 ]; then
    RESET_SEG=""
    for R in "${RESETS[@]}"; do
        [ -n "$RESET_SEG" ] && RESET_SEG="$RESET_SEG / "
        RESET_SEG="$RESET_SEG$R"
    done
    PARTS+=("⏳ Resets in $RESET_SEG")
fi
BAR_CELLS=22
PCT_COLOR=$(ramp_at $(( PCT * (BAR_CELLS - 1) / 100 )) $BAR_CELLS)
PARTS+=("ctx: $(gradient_bar $BAR_CELLS $PCT) \033[38;2;${PCT_COLOR}m${PCT}%\033[0m")
# Join segments with " | " directly — a blanket sed would also pad the
# tight "↻|" inside a segment and make it look like a segment break.
LINE2=""
for P in "${PARTS[@]}"; do
    [ -n "$LINE2" ] && LINE2="$LINE2 | "
    LINE2="$LINE2$P"
done
echo -e "$LINE2"
