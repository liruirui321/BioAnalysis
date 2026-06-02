#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, write_tsv

FIELDS = [
    "query_id", "best_donor_hit", "best_donor_taxon", "best_donor_group", "best_donor_evalue",
    "best_donor_bitscore", "best_ingroup_hit", "best_ingroup_taxon", "best_ingroup_evalue",
    "best_ingroup_bitscore", "alien_index", "bitscore_delta", "candidate_status", "filter_reason",
]


def to_float(value, default=0.0):
    if value in {None, "", "-", "NA"}:
        return default
    try:
        return float(value)
    except ValueError:
        return default


def to_int(value, default=0):
    if value in {None, "", "-", "NA"}:
        return default
    try:
        return int(float(value))
    except ValueError:
        return default


def split_groups(value: str) -> set[str]:
    return {item.strip().casefold() for item in value.split(",") if item.strip()}


def get_case_insensitive(values, key):
    wanted = key.casefold()
    for name, value in values.items():
        if name.casefold() == wanted:
            return value
    return "NA"


def parse_blast2hgt(path):
    rows = []
    with open_text(path) as handle:
        header = None
        donor_count = None
        for line in handle:
            if not line.strip():
                continue
            cols = line.rstrip("\n").split("\t")
            if cols[0].startswith("#Query_id"):
                header = [cols[0].lstrip("#"), *cols[1:]]
                if (len(header) - 11) % 2 != 0:
                    raise SystemExit(f"Unsupported blast2hgt header column count in {path}")
                donor_count = (len(header) - 11) // 2
                continue
            if header is None or donor_count is None:
                continue
            if len(cols) != len(header):
                raise SystemExit(f"Column count mismatch in blast2hgt row for {cols[0]!r}")
            n = donor_count
            e_groups = header[2:2 + n]
            e_values = cols[2:2 + n]
            bit_groups = header[5 + n:5 + 2 * n]
            bit_values = cols[5 + n:5 + 2 * n]
            rows.append({
                "query_id": cols[0],
                "self_evalue": cols[1],
                "donor_evalues": dict(zip(e_groups, e_values)),
                "alien_index": cols[2 + n],
                "alien_index_taxon": cols[3 + n],
                "self_bitscore": cols[4 + n],
                "donor_bitscores": dict(zip(bit_groups, bit_values)),
                "bitscore_delta": cols[5 + 2 * n],
                "bitscore_delta_percent": cols[6 + 2 * n],
                "bit_ratio": cols[7 + 2 * n],
                "h_taxon": cols[8 + 2 * n],
                "donor_bitscore": cols[9 + 2 * n],
                "donor_taxon_count": cols[10 + 2 * n],
            })
    return rows


def best_evalue(row, group):
    return get_case_insensitive(row["donor_evalues"], group)


def main():
    ap = argparse.ArgumentParser(description="Filter blast2hgt lineage table output into conservative HGT candidate and rejected TSV files.")
    ap.add_argument("--blast2hgt", required=True, help="blast2hgt .rp.tsv output from lineage2table3.pub.pl")
    ap.add_argument("--out", required=True, help="Accepted or review-priority candidate TSV")
    ap.add_argument("--rejected", required=True, help="Rejected or ambiguous query TSV")
    ap.add_argument("--summary", default=None)
    ap.add_argument("--ingroup-group", required=True, help="Self/vertical group name used as the first blast2hgt --define value")
    ap.add_argument("--donor-groups", required=True, help="Comma-separated donor groups to accept, matching blast2hgt --define names")
    ap.add_argument("--min-alien-index", type=float, default=0.0)
    ap.add_argument("--min-bitscore-delta", type=float, default=0.0)
    ap.add_argument("--min-donor-bitscore", type=float, default=50.0)
    ap.add_argument("--min-donor-taxon-count", type=int, default=1)
    args = ap.parse_args()

    donors = split_groups(args.donor_groups)
    accepted = []
    rejected = []
    counts = defaultdict(int)

    for row in parse_blast2hgt(args.blast2hgt):
        donor_group = row["h_taxon"] if row["h_taxon"] != "unknown" else row["alien_index_taxon"]
        donor_group_key = donor_group.casefold()
        ingroup_key = args.ingroup_group.casefold()
        reasons = []
        if donor_group_key not in donors:
            reasons.append("donor_group_not_selected")
        if donor_group_key == ingroup_key:
            reasons.append("best_group_is_ingroup")
        if to_float(row["alien_index"]) < args.min_alien_index:
            reasons.append("low_alien_index")
        if to_float(row["bitscore_delta"]) < args.min_bitscore_delta:
            reasons.append("low_bitscore_delta")
        if to_float(row["donor_bitscore"]) < args.min_donor_bitscore:
            reasons.append("low_donor_bitscore")
        if to_int(row["donor_taxon_count"]) < args.min_donor_taxon_count:
            reasons.append("low_donor_taxon_count")

        status = "candidate" if not reasons else "rejected"
        out_row = {
            "query_id": row["query_id"],
            "best_donor_hit": "NA",
            "best_donor_taxon": donor_group,
            "best_donor_group": donor_group,
            "best_donor_evalue": best_evalue(row, donor_group),
            "best_donor_bitscore": row["donor_bitscore"],
            "best_ingroup_hit": "NA",
            "best_ingroup_taxon": args.ingroup_group,
            "best_ingroup_evalue": row["self_evalue"],
            "best_ingroup_bitscore": row["self_bitscore"],
            "alien_index": row["alien_index"],
            "bitscore_delta": row["bitscore_delta"],
            "candidate_status": status,
            "filter_reason": ";".join(reasons) if reasons else "pass",
        }
        counts[status] += 1
        if status == "candidate":
            accepted.append(out_row)
        else:
            rejected.append(out_row)

    write_tsv(args.out, FIELDS, accepted)
    write_tsv(args.rejected, FIELDS, rejected)
    if args.summary:
        write_tsv(args.summary, ["metric", "value"], [{"metric": k, "value": v} for k, v in sorted(counts.items())])


if __name__ == "__main__":
    main()
