import re
import sys


def align_tree_ids(pep_file, tree_file, output_file):
    full_ids = []
    with open(pep_file, "r") as handle:
        for line in handle:
            if line.startswith(">"):
                full_ids.append(line.strip()[1:].split()[0])

    with open(tree_file, "r") as handle:
        tree_content = handle.read()

    replace_count = 0
    skip_count = 0

    def replacer(match):
        nonlocal replace_count, skip_count
        prefix = match.group(1)
        tree_id = match.group(2)
        suffix = match.group(3)

        if tree_id in full_ids:
            skip_count += 1
            return match.group(0)

        matches = [fid for fid in full_ids if fid.startswith(tree_id)]
        if len(matches) == 1:
            replace_count += 1
            return f"{prefix}{matches[0]}{suffix}"
        if len(matches) > 1:
            print(f"Warning: tree ID {tree_id!r} matches multiple peptide IDs; skipping replacement.")
            skip_count += 1
            return match.group(0)

        skip_count += 1
        return match.group(0)

    new_tree_content = re.sub(r"([\(,])([^:\(\),]+)(:)", replacer, tree_content)
    with open(output_file, "w") as handle:
        handle.write(new_tree_content)

    print("-" * 40)
    print("Tree ID conversion complete.")
    print(f"Replaced IDs: {replace_count}")
    print(f"Skipped IDs: {skip_count}")
    print(f"Output tree: {output_file}")
    print("-" * 40)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python rename_tree.py <input.pep> <input.treefile> <output.tree>")
        sys.exit(1)
    align_tree_ids(sys.argv[1], sys.argv[2], sys.argv[3])
