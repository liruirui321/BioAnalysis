#!/usr/bin/env python3
from pathlib import Path
import argparse
import csv
import gzip
import re
from collections import defaultdict

CODON_TABLE = {
    "TTT":"F","TTC":"F","TTA":"L","TTG":"L","TCT":"S","TCC":"S","TCA":"S","TCG":"S",
    "TAT":"Y","TAC":"Y","TAA":"*","TAG":"*","TGT":"C","TGC":"C","TGA":"*","TGG":"W",
    "CTT":"L","CTC":"L","CTA":"L","CTG":"L","CCT":"P","CCC":"P","CCA":"P","CCG":"P",
    "CAT":"H","CAC":"H","CAA":"Q","CAG":"Q","CGT":"R","CGC":"R","CGA":"R","CGG":"R",
    "ATT":"I","ATC":"I","ATA":"I","ATG":"M","ACT":"T","ACC":"T","ACA":"T","ACG":"T",
    "AAT":"N","AAC":"N","AAA":"K","AAG":"K","AGT":"S","AGC":"S","AGA":"R","AGG":"R",
    "GTT":"V","GTC":"V","GTA":"V","GTG":"V","GCT":"A","GCC":"A","GCA":"A","GCG":"A",
    "GAT":"D","GAC":"D","GAA":"E","GAG":"E","GGT":"G","GGC":"G","GGA":"G","GGG":"G",
}
RC = str.maketrans("ACGTNacgtn", "TGCANtgcan")


def open_text(path):
    path = str(path)
    if path.endswith(".gz"):
        return gzip.open(path, "rt")
    return open(path, errors="replace")


def wrap(seq, width=60):
    return "\n".join(seq[i:i + width] for i in range(0, len(seq), width))


def read_fasta(path):
    records = {}
    name = None
    chunks = []
    with open_text(path) as handle:
        for line in handle:
            if line.startswith(">"):
                if name is not None:
                    records[name] = "".join(chunks).upper()
                name = line[1:].split()[0]
                chunks = []
            else:
                chunks.append(line.strip())
    if name is not None:
        records[name] = "".join(chunks).upper()
    return records


def parse_attrs(attr):
    attrs = {}
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


def read_keep_ids(path):
    if not path or path == "NA":
        return None
    return {line.strip().split()[0] for line in open_text(path) if line.strip() and not line.startswith("#")}


def parent_ids(value):
    return [x for x in value.split(",") if x]


def parse_gff(path, keep_transcript_regex=None):
    mrnas = {}
    children = defaultdict(list)
    lines = []
    with open_text(path) as handle:
        for line in handle:
            if line.startswith("#") or not line.strip():
                lines.append((line, None, None))
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 9:
                lines.append((line, None, None))
                continue
            attrs = parse_attrs(parts[8])
            feature = parts[2]
            fid = attrs.get("ID")
            parents = parent_ids(attrs.get("Parent", ""))
            if feature in {"mRNA", "transcript"} and fid:
                if keep_transcript_regex and not re.search(keep_transcript_regex, fid):
                    lines.append((line, None, None))
                    continue
                mrnas[fid] = {"seqid": parts[0], "start": int(parts[3]), "end": int(parts[4]), "strand": parts[6], "attrs": attrs}
            elif parents:
                for parent in parents:
                    children[parent].append(parts)
            lines.append((line, parts, attrs))
    return mrnas, children, lines


def choose_t1_transcripts(mrnas):
    chosen = set()
    by_gene = defaultdict(list)
    no_parent = []
    for tid, rec in mrnas.items():
        parent = rec["attrs"].get("Parent")
        if parent:
            by_gene[parent].append(tid)
        else:
            no_parent.append(tid)
    for tids in by_gene.values():
        t1 = [tid for tid in tids if re.search(r"(?:^|\.)t1(?:$|\.)", tid)]
        chosen.add(sorted(t1 or tids)[0])
    chosen.update(tid for tid in no_parent if re.search(r"(?:^|\.)t1(?:$|\.)", tid) or not re.search(r"\.t\d+(?:$|\.)", tid))
    return chosen


def filter_gff(lines, selected_transcripts, keep_seqids=None):
    selected_genes = set()
    kept = []
    gene_by_id = {}
    for line, parts, attrs in lines:
        if parts is None:
            continue
        if keep_seqids is not None and parts[0] not in keep_seqids:
            continue
        fid = attrs.get("ID", "")
        if parts[2] == "gene" and fid:
            gene_by_id[fid] = line

    for line, parts, attrs in lines:
        if parts is None:
            continue
        if keep_seqids is not None and parts[0] not in keep_seqids:
            continue
        feature = parts[2]
        fid = attrs.get("ID", "")
        parents = parent_ids(attrs.get("Parent", ""))
        if feature in {"mRNA", "transcript"} and fid in selected_transcripts:
            kept.append(line)
            selected_genes.update(parents)
        elif feature != "gene" and any(parent in selected_transcripts for parent in parents):
            kept.append(line)

    if not selected_genes:
        return kept

    output = []
    written_genes = set()
    for line in kept:
        parts = line.rstrip("\n").split("\t")
        attrs = parse_attrs(parts[8])
        parents = parent_ids(attrs.get("Parent", ""))
        if parts[2] in {"mRNA", "transcript"}:
            for gid in parents:
                if gid in gene_by_id and gid not in written_genes:
                    output.append(gene_by_id[gid])
                    written_genes.add(gid)
        output.append(line)
    return output


def revcomp(seq):
    return seq.translate(RC)[::-1].upper()


def cds_for_transcript(transcript_id, mrnas, children, genome):
    rec = mrnas[transcript_id]
    cds_parts = [p for p in children.get(transcript_id, []) if p[2] == "CDS"]
    if not cds_parts:
        return ""
    cds_parts.sort(key=lambda p: int(p[3]))
    seq_chunks = []
    for p in cds_parts:
        chrom = p[0]
        if chrom not in genome:
            raise KeyError(f"GFF seqid {chrom!r} not found in genome FASTA")
        seq_chunks.append(genome[chrom][int(p[3]) - 1:int(p[4])])
    seq = "".join(seq_chunks).upper()
    if rec["strand"] == "-":
        seq = revcomp(seq)
    return seq


def translate(cds):
    aa = []
    for i in range(0, len(cds) - 2, 3):
        aa.append(CODON_TABLE.get(cds[i:i + 3].upper(), "X"))
    return "".join(aa)


def check_cds(cds, pep):
    return {
        "len": len(cds),
        "phase_ok": int(len(cds) % 3 == 0),
        "start_ok": int(cds[:3].upper() == "ATG"),
        "terminal_stop": int(pep.endswith("*")),
        "internal_stop": pep[:-1].count("*"),
        "ambiguous_nt": len(re.findall(r"[^ACGT]", cds.upper())),
    }


def write_check(path, rows):
    with open(path, "w") as out:
        out.write("transcript_id\tseqid\tcds_len\tphase_ok\tstart_ok\tterminal_stop\tinternal_stop\tambiguous_nt\n")
        for tid, seqid, stats in rows:
            out.write(f"{tid}\t{seqid}\t{stats['len']}\t{stats['phase_ok']}\t{stats['start_ok']}\t{stats['terminal_stop']}\t{stats['internal_stop']}\t{stats['ambiguous_nt']}\n")


def write_outputs(prefix, outdir, genome_path, gff_path, keep_seqids=None, keep_transcript_regex=None, filter_bad_cds=True):
    outdir.mkdir(parents=True, exist_ok=True)
    genome = read_fasta(genome_path)
    mrnas, children, lines = parse_gff(gff_path, keep_transcript_regex)
    selected = choose_t1_transcripts(mrnas)
    if keep_seqids is not None:
        selected = {tid for tid in selected if mrnas[tid]["seqid"] in keep_seqids}

    seqs = {}
    raw_rows = []
    for tid in sorted(selected, key=lambda t: (mrnas[t]["seqid"], mrnas[t]["start"], mrnas[t]["end"], t)):
        cds = cds_for_transcript(tid, mrnas, children, genome)
        if not cds:
            continue
        pep = translate(cds)
        stats = check_cds(cds, pep)
        seqs[tid] = (cds, pep, stats)
        raw_rows.append((tid, mrnas[tid]["seqid"], stats))

    if filter_bad_cds:
        final_selected = {tid for tid, (cds, pep, stats) in seqs.items() if stats["phase_ok"] and stats["internal_stop"] == 0}
    else:
        final_selected = set(seqs)
    gff_lines = filter_gff(lines, final_selected, keep_seqids)

    with open(outdir / f"{prefix}.gff", "w") as out:
        out.writelines(gff_lines)

    final_rows = []
    with open(outdir / f"{prefix}.cds", "w") as cds_out, open(outdir / f"{prefix}.pep", "w") as pep_out:
        for tid in sorted(final_selected, key=lambda t: (mrnas[t]["seqid"], mrnas[t]["start"], mrnas[t]["end"], t)):
            cds, pep, stats = seqs[tid]
            cds_out.write(f">{tid}\n{wrap(cds)}\n")
            pep_out.write(f">{tid}\n{wrap(pep)}\n")
            final_rows.append((tid, mrnas[tid]["seqid"], stats))

    write_check(outdir / f"{prefix}.raw.cds.check", raw_rows)
    write_check(outdir / f"{prefix}.cds.check", final_rows)
    return {
        "transcripts": len(selected),
        "raw_cds_written": len(raw_rows),
        "filtered_bad_cds": len(raw_rows) - len(final_rows),
        "cds_written": len(final_rows),
        "gff_features": len(gff_lines),
        "outdir": str(outdir),
    }


def read_manifest(path):
    with open(path, newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        required = {"species_id", "species_name", "genome_fasta", "annotation_gff"}
        missing = required - set(reader.fieldnames or [])
        if missing:
            raise SystemExit(f"Manifest missing columns: {', '.join(sorted(missing))}")
        return list(reader)


def main():
    parser = argparse.ArgumentParser(description="Generate GFF/CDS/PEP outputs from genome FASTA and GFF/GFF3 annotations.")
    parser.add_argument("--manifest", required=True, help="TSV with species_id, species_name, genome_fasta, annotation_gff, optional keep_ids")
    parser.add_argument("--outdir", default="gff_cds_pep_outputs")
    parser.add_argument("--transcript-regex", default=None, help="Optional regex to pre-filter transcript IDs before t1 selection")
    parser.add_argument("--keep-bad-cds", action="store_true", help="Do not filter CDS with non-triplet length or internal stop codons")
    args = parser.parse_args()

    outbase = Path(args.outdir)
    summary = []
    for row in read_manifest(args.manifest):
        sp = row["species_id"]
        name = row["species_name"]
        genome = row["genome_fasta"]
        gff = row["annotation_gff"]
        hic = write_outputs(f"{sp}.hic", outbase / sp / "hic", genome, gff, keep_transcript_regex=args.transcript_regex, filter_bad_cds=not args.keep_bad_cds)
        summary.append((sp, name, "hic", hic))
        keep = read_keep_ids(row.get("keep_ids", "NA"))
        if keep is not None:
            chrom = write_outputs(f"{sp}.chr", outbase / sp / "chromosome", genome, gff, keep_seqids=keep, keep_transcript_regex=args.transcript_regex, filter_bad_cds=not args.keep_bad_cds)
            summary.append((sp, name, "chromosome", chrom))
        print(f"{sp}: wrote {hic['cds_written']} HiC/all CDS/PEP records")

    with open(outbase / "summary.tsv", "w") as out:
        out.write("species\tspecies_name\tlevel\ttranscripts_selected\traw_cds_written\tfiltered_bad_cds\tcds_written\tgff_features\toutdir\n")
        for sp, name, level, stats in summary:
            out.write(f"{sp}\t{name}\t{level}\t{stats['transcripts']}\t{stats['raw_cds_written']}\t{stats['filtered_bad_cds']}\t{stats['cds_written']}\t{stats['gff_features']}\t{stats['outdir']}\n")


if __name__ == "__main__":
    main()
