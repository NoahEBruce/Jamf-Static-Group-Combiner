# Jamf Static Group Combiner

A Bash script that combines computer membership from one or more Jamf Pro computer groups into an existing static computer group using [`jamf-cli`](https://github.com/Jamf-Concepts/jamf-cli).

The source groups can be static or smart groups. Existing members of the target group are retained, duplicate members are ignored, and empty source groups are safely skipped.

> This is a community script and is not affiliated with or supported by Jamf.

## What it does

The script:

1. Uses a named `jamf-cli` configuration profile to select the Jamf Pro instance.
2. Previews every configured source group before making changes.
3. Skips source groups that currently have no members.
4. Stops before applying if a genuine preview error occurs.
5. Adds members from each populated source group to the target static group.
6. Leaves computers already in the target group unchanged.
7. Reports partial failures if one update succeeds and a later update fails.

The operation is additive. It never removes computers from the target group.

## Requirements

- macOS or another environment with Bash
- [`jamf-cli`](https://github.com/Jamf-Concepts/jamf-cli) installed and available in `PATH`
- A configured direct-instance Jamf Pro profile
- An API role with permission to read computers and computer groups and update static computer groups
- An existing target static computer group

The script has been tested with `jamf-cli` 1.34.0.

## Installation

Clone the repository:

```bash
git clone https://github.com/YOUR-USERNAME/jamf-static-group-combiner.git
cd jamf-static-group-combiner
```

Make the script executable:

```bash
chmod +x jamf-static-group-combiner.sh
```

Confirm that your Jamf profiles are available:

```bash
jamf-cli config list -o table
```

## Configuration

Edit the user-configuration section near the top of `jamf-static-group-combiner.sh`.

### Jamf Pro instance

Set `CONFIG_NAME` to the name of the applicable `jamf-cli` profile:

```bash
CONFIG_NAME="Prod"
```

The script passes this value to `jamf-cli` with `-p`, so it does not depend on the default profile.

### Source groups

Enter one or more source computer-group names:

```bash
SOURCE_GROUPS=(
  "GROUP-1"
  "GROUP-2"
)
```

Each source may be a static or smart computer group.

### Target group

Enter the name of the existing target static computer group:

```bash
TARGET_STATIC_GROUP="Combined-Group"
```

The target must be static. Jamf calculates smart-group membership from criteria, so the script cannot add members directly to a smart group.

### Default execution mode

The safe default is preview-only:

```bash
APPLY_CHANGES=false
```

Keeping this set to `false` is recommended. Use the `--apply` option when you intentionally want to make changes.

## Usage

### Preview

Run the script without arguments:

```bash
./jamf-static-group-combiner.sh
```

This calls `jamf-cli` with `--dry-run`. No group membership is changed.

Review the selected profile, target group, source count, and per-group preview results.

### Apply

After reviewing the preview, apply the changes:

```bash
./jamf-static-group-combiner.sh --apply
```

The script previews every group again before beginning the apply phase.

### Help

```bash
./jamf-static-group-combiner.sh --help
```

## Repeated runs

The script is safe to run repeatedly for additive updates.

- New source-group members are added to the target.
- Computers already in the target are left unchanged.
- Duplicate computers across multiple sources are harmless.
- Empty source groups are reported and skipped.

This makes the script suitable for periodically adding newly eligible computers to a deployment ring.

## Important: this is not exact synchronization

The target group is treated as an accumulating destination:

```text
target after run = existing target members + all current source members
```

If a computer is later removed from every source group, this script does **not** remove it from the target. No `remove-members` command is used.

If you require the target to exactly match the combined sources, you need a reconciliation workflow that calculates and reviews both additions and removals.

## Empty groups and other failures

An empty source group produces a message similar to:

```text
Skipping empty source group: GROUP-2
```

The script continues processing the other source groups.

Other preview failures stop the script before it applies changes. Examples include:

- A missing or misspelled group name
- An ambiguous computer or group name
- An invalid or smart target group
- Authentication or permission failures
- Jamf API or network errors

Apply operations are not transactional. If one source update succeeds and a later update fails, the earlier successful membership changes remain applied.

## How it works

For each source group, the script previews this operation:

```bash
jamf-cli -p "$CONFIG_NAME" \
  pro classic-computer-groups add-members \
  --name "$TARGET_STATIC_GROUP" \
  --from-group "$source_group" \
  --dry-run
```

During an approved apply run, `--dry-run` is replaced with `--yes`:

```bash
jamf-cli -p "$CONFIG_NAME" \
  pro classic-computer-groups add-members \
  --name "$TARGET_STATIC_GROUP" \
  --from-group "$source_group" \
  --yes
```

`jamf-cli` resolves the source membership, skips computers already present, performs batched Classic API requests, and reads the target group back to verify the changes.

## Security notes

- No Jamf credentials are stored in this repository or script.
- Authentication is handled by the selected `jamf-cli` profile and its configured secret storage.
- Do not commit exported credentials, tokens, client secrets, or local configuration files.
- Test against a non-production profile and group before using the script in production.
- Keep preview-only mode as the default.

## Suggested repository layout

```text
jamf-static-group-combiner/
├── README.md
├── jamf-static-group-combiner.sh
├── LICENSE
└── .gitignore
```

## License

Consider publishing the project under the [MIT License](https://opensource.org/license/mit). Add a `LICENSE` file before publishing if you want others to reuse or modify the script.
