#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv

FIELDS = [
    "query_id", "best_donor_hit", "best_donor_taxon", "best_donor_group", "best_donor_evalue",
    "best_donor_bitscore", "best_ingroup_hit", "best_ingroup_taxon", "best_ingroup_evalue",
    "best_ingroup_bitscore", "alien_index", "bitscore_delta", "candidate_status", "filter_reason",
]


def to_float(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def best_hit(rows, hit_class):
    subset = [row for row in rows if row.get("hit_class") == hit_class]
    if not subset:
        return None
    return sorted(subset, key=lambda r: (-to_float(r.get("bitscore")), to_float(r.get("evalue"), 1.0)))[0]


def evalue_score(row):
    if row is None:
        return 0.0
    evalue = max(to_float(row.get("evalue"), 1.0), 1e-300)
    return -math.log10(evalue)


def format_hit(row, key, default="NA"):
    return default if row is None else row.get(key, default)


def main():
    ap = argparse.ArgumentParser(description="Score conservative HGT candidates from classified similarity hits.")
    ap.add_argument("--classified-hits", required=True)
    ap.add_argument("--out", required=True, help="Accepted or review-priority candidates")
    ap.add_argument("--rejected", required=True, help="Rejected or ambiguous queries with reasons")
    ap.add_argument("--summary", default=None)
    ap.add_argument("--min-alien-index", type=float, default=30.0)
    ap.add_argument("--min-donor-bitscore", type=float, default=50.0)
    ap.add_argument("--min-query-cover", type=float, default=0.0)
    ap.add_argument("--max-evalue", type=float, default=1e-5)
    args = ap.parse_args()

    by_query = defaultdict(list)
    for row in read_tsv(args.classified_hits):
        by_query[row["query_id"]].append(row)

    accepted = []
    rejected = []
    counts = defaultdict(int)

    for query, hits in sorted(by_query.items()):
        donor = best_hit(hits, "donor")
        ingroup = best_hit(hits, "ingroup")
        reasons = []
        if donor is None:
            reasons.append("no_donor_hit")
        else:
            if to_float(donor.get("bitscore")) < args.min_donor_bitscore:
                reasons.append("low_donor_bitscore")
            if to_float(donor.get("evalue"), 1.0) > args.max_evalue:
                reasons.append("weak_donor_evalue")
            if to_float(donor.get("query_coverage")) < args.min_query_cover:
                reasons.append("low_query_coverage")
        if ingroup is None:
            reasons.append("no_ingroup_comparison")

        alien_index = evalue_score(donor) - evalue_score(ingroup)
        bitscore_delta = to_float(format_hit(donor, "bitscore", "0")) - to_float(format_hit(ingroup, "bitscore", "0"))
        if donor is not None and ingroup is not None and alien_index < args.min_alien_index:
            reasons.append("low_alien_index")

        status = "candidate" if not reasons else "rejected"
        row = {
            "query_id": query,
            "best_donor_hit": format_hit(donor, "subject_id"),
            "best_donor_taxon": format_hit(donor, "scientific_name"),
            "best_donor_group": format_hit(donor, "taxon_group"),
            "best_donor_evalue": format_hit(donor, "evalue"),
            "best_donor_bitscore": format_hit(donor, "bitscore"),
            "best_ingroup_hit": format_hit(ingroup, "subject_id"),
            "best_ingroup_taxon": format_hit(ingroup, "scientific_name"),
            "best_ingroup_evalue": format_hit(ingroup, "evalue"),
            "best_ingroup_bitscore": format_hit(ingroup, "bitscore"),
            "alien_index": f"{alien_index:.6f}",
            "bitscore_delta": f"{bitscore_delta:.6f}",
            "candidate_status": status,
            "filter_reason": ";".join(reasons) if reasons else "pass",
        }
        counts[status] += 1
        if status == "candidate":
            accepted.append(row)
        else:
            rejected.append(row)

    write_tsv(args.out, FIELDS, accepted)
    write_tsv(args.rejected, FIELDS, rejected)
    if args.summary:
        write_tsv(args.summary, ["metric", "value"], [{"metric": k, "value": v} for k, v in sorted(counts.items())])


if __name__ == "__main__":
    main()
