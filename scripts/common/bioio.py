#!/usr/bin/env python3
"""Small standard-library helpers for BioAnalysis scripts."""
from __future__ import annotations

import csv
import gzip
import sys
from pathlib import Path
from typing import Dict, Iterable, Iterator, List, Mapping, Sequence, Tuple


def open_text(path, mode="rt"):
    path = str(path)
    if path.endswith(".gz"):
        return gzip.open(path, mode)
    return open(path, mode, newline="" if "t" in mode else None)


def ensure_file(path, label="input") -> Path:
    p = Path(path)
    if not p.exists():
        raise SystemExit(f"Missing {label}: {p}")
    if p.is_file() and p.stat().st_size == 0:
        raise SystemExit(f"Empty {label}: {p}")
    return p


def ensure_dir(path) -> Path:
    p = Path(path)
    p.mkdir(parents=True, exist_ok=True)
    return p


def wrap_sequence(seq: str, width: int = 60) -> str:
    return "\n".join(seq[i:i + width] for i in range(0, len(seq), width))


def read_fasta(path) -> Dict[str, str]:
    ensure_file(path, "FASTA")
    records: Dict[str, List[str]] = {}
    name = None
    with open_text(path) as handle:
        for line in handle:
            line = line.rstrip("\n")
            if not line:
                continue
            if line.startswith(">"):
                name = line[1:].split()[0]
                if name in records:
                    raise SystemExit(f"Duplicate FASTA ID {name!r} in {path}")
                records[name] = []
            elif name is None:
                raise SystemExit(f"Sequence before first header in {path}")
            else:
                records[name].append(line.strip())
    return {k: "".join(v) for k, v in records.items()}


def iter_fasta(path) -> Iterator[Tuple[str, str]]:
    ensure_file(path, "FASTA")
    name = None
    chunks: List[str] = []
    with open_text(path) as handle:
        for line in handle:
            line = line.rstrip("\n")
            if not line:
                continue
            if line.startswith(">"):
                if name is not None:
                    yield name, "".join(chunks)
                name = line[1:].split()[0]
                chunks = []
            else:
                chunks.append(line.strip())
    if name is not None:
        yield name, "".join(chunks)


def write_fasta(records: Iterable[Tuple[str, str]], path, width: int = 60) -> None:
    out = Path(path)
    if out.parent:
        out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w") as handle:
        for name, seq in records:
            handle.write(f">{name}\n")
            handle.write(wrap_sequence(seq, width) + "\n")


def parse_gff_attributes(attr: str) -> Dict[str, str]:
    attrs: Dict[str, str] = {}
    attr = attr.strip().rstrip(";")
    for part in attr.split(";"):
        part = part.strip()
        if not part:
            continue
        if "=" in part:
            key, value = part.split("=", 1)
        elif " " in part:
            key, value = part.split(" ", 1)
            value = value.strip().strip('"')
        else:
            continue
        attrs[key] = value
    return attrs


def read_id_set(path) -> set:
    if not path or str(path) == "NA":
        return set()
    ensure_file(path, "ID list")
    ids = set()
    with open_text(path) as handle:
        for line in handle:
            if line.strip() and not line.startswith("#"):
                ids.add(line.split()[0])
    return ids


def read_tsv(path) -> List[Dict[str, str]]:
    ensure_file(path, "TSV")
    with open_text(path) as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if not reader.fieldnames:
            raise SystemExit(f"Missing header in TSV: {path}")
        return list(reader)


def write_tsv(path, fieldnames: Sequence[str], rows: Iterable[Mapping[str, object]]) -> None:
    out = Path(path)
    if out.parent:
        out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w", newline="") as handle:
        writer = csv.DictWriter(handle, delimiter="\t", fieldnames=list(fieldnames), extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row.get(k, "NA") for k in fieldnames})


def write_lines(path, lines: Iterable[str]) -> None:
    out = Path(path)
    if out.parent:
        out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w") as handle:
        for line in lines:
            handle.write(str(line).rstrip("\n") + "\n")


def add_repo_to_path() -> None:
    root = Path(__file__).resolve().parents[1]
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
