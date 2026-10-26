#!/usr/bin/env bash

set -u
set -o pipefail

# ==============================================================================
# USER CONFIGURATION
# ==============================================================================

# jamf-cli config profile/instance name (for example: "Test" or "Prod").
CONFIG_NAME="Prod"

# Static or smart computer groups whose members will be added to the target.
SOURCE_GROUPS=(
  "GROUP-1"
  "GROUP-2"
)

# Existing static computer group that will receive the combined membership.
TARGET_STATIC_GROUP="Combined-Group"

# false: preview only; true: preview everything, then apply if all previews pass.
APPLY_CHANGES=false

# ==============================================================================
# SCRIPT LOGIC -- no changes should be needed below this line
# ==============================================================================

usage() {
  cat <<'EOF'
Usage: combine-static-groups.sh [--apply] [--help]

Combines the membership of the configured source computer groups into an
existing target static computer group. Existing target members are retained.

Options:
  --apply  Override APPLY_CHANGES and apply changes after successful previews.
  --help   Show this help text.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --apply)
      APPLY_CHANGES=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Error: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if ! command -v jamf-cli >/dev/null 2>&1; then
  printf 'Error: jamf-cli was not found in PATH.\n' >&2
  exit 1
fi

if [[ -z "$CONFIG_NAME" ]]; then
  printf 'Error: CONFIG_NAME cannot be empty.\n' >&2
  exit 1
fi

if [[ -z "$TARGET_STATIC_GROUP" ]]; then
  printf 'Error: TARGET_STATIC_GROUP cannot be empty.\n' >&2
  exit 1
fi

if (( ${#SOURCE_GROUPS[@]} == 0 )); then
  printf 'Error: configure at least one entry in SOURCE_GROUPS.\n' >&2
  exit 1
fi

printf 'Jamf profile: %s\n' "$CONFIG_NAME"
printf 'Target group: %s\n' "$TARGET_STATIC_GROUP"
printf 'Source groups: %d\n' "${#SOURCE_GROUPS[@]}"

# Preview every source before making any changes. This catches missing groups,
# ambiguous names, and a target that is not a static computer group.
preview_failed=false
ready_source_groups=()

for source_group in "${SOURCE_GROUPS[@]}"; do
  if [[ -z "$source_group" ]]; then
    printf '\nError: SOURCE_GROUPS contains an empty entry.\n' >&2
    preview_failed=true
    continue
  fi

  if [[ "$source_group" == "$TARGET_STATIC_GROUP" ]]; then
    printf '\nError: source and target group are both %q.\n' "$source_group" >&2
    preview_failed=true
    continue
  fi

  printf '\nPreviewing source group: %s\n' "$source_group"
  if preview_output=$(jamf-cli -p "$CONFIG_NAME" \
      pro classic-computer-groups add-members \
      --name "$TARGET_STATIC_GROUP" \
      --from-group "$source_group" \
      --dry-run 2>&1); then
    printf '%s\n' "$preview_output"
    ready_source_groups+=("$source_group")
  else
    printf '%s\n' "$preview_output"

    if [[ "$preview_output" == *"has no members"* ]]; then
      printf 'Skipping empty source group: %s\n' "$source_group"
      continue
    fi

    printf 'Preview failed for source group: %s\n' "$source_group" >&2
    preview_failed=true
  fi
done

if [[ "$preview_failed" == true ]]; then
  printf '\nNo changes were made because at least one preview failed.\n' >&2
  exit 1
fi

if (( ${#ready_source_groups[@]} == 0 )); then
  printf '\nNo populated source groups were found. No changes were made.\n'
  exit 0
fi

if [[ "$APPLY_CHANGES" != true ]]; then
  printf '\nPreview completed successfully. No changes were made.\n'
  printf 'Run this script with --apply, or set APPLY_CHANGES=true, to add the members.\n'
  exit 0
fi

printf '\nAll previews succeeded. Applying membership changes...\n'
apply_failed=false

for source_group in "${ready_source_groups[@]}"; do
  printf '\nAdding members from source group: %s\n' "$source_group"
  if ! jamf-cli -p "$CONFIG_NAME" \
      pro classic-computer-groups add-members \
      --name "$TARGET_STATIC_GROUP" \
      --from-group "$source_group" \
      --yes; then
    printf 'Update failed for source group: %s\n' "$source_group" >&2
    apply_failed=true
  fi
done

if [[ "$apply_failed" == true ]]; then
  printf '\nOne or more updates failed. Earlier successful updates may have been applied.\n' >&2
  exit 1
fi

printf '\nCombined membership was added successfully to: %s\n' "$TARGET_STATIC_GROUP"
