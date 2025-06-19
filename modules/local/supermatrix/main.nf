process SUPERMATRIX {
    tag "$meta.id"
    label 'process_low'
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/biopython:1.66--np110py36_0' :
        'biocontainers/biopython:1.66--np110py36_0' }"
    
    input:
    tuple val(meta), path(alignments, stageAs: 'alignments/*')

    output:
    tuple val(meta), path("supermatrix.fasta"), emit: supermatrix
    tuple val(meta), path("partitions.txt"), emit: partitions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
#!/usr/bin/env python

import glob
from Bio import SeqIO

def concatenate_fastas(fasta_files, output_file, partition_file):
    all_ids = set()
    sequences_by_file = []
    lengths = []
    partition_ranges = []

    current_start = 1  # RAxML is 1-based indexing

    # Parse all FASTA files
    for i, file in enumerate(sorted(glob.glob(fasta_files))):
        seqs = {}
        for record in SeqIO.parse(file, "fasta"):
            seqs[record.id] = str(record.seq)
            all_ids.add(record.id)
        sequences_by_file.append(seqs)

        aln_length = len(next(iter(seqs.values())))  # assume aligned
        lengths.append(aln_length)

        current_end = current_start + aln_length - 1
        partition_ranges.append((f"part{i+1}", current_start, current_end))
        current_start = current_end + 1

    # Write concatenated sequences
    with open(output_file, "w") as out:
        for seq_id in sorted(all_ids):
            concat_seq = ""
            for i, seqs in enumerate(sequences_by_file):
                if seq_id in seqs:
                    concat_seq += seqs[seq_id]
                else:
                    concat_seq += "-" * lengths[i]
            out.write(f">{seq_id}\\n{concat_seq}\\n")

    # Write partition file
    with open(partition_file, "w") as part_out:
        for name, start, end in partition_ranges:
            part_out.write(f"DNA, {name} = {start}-{end}\\n")

concatenate_fastas('alignments/*', 'supermatrix.fasta', 'partitions.txt')
    """

    stub:
    """
    touch supermatrix.fasta
    """
}
