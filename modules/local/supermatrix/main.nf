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

    when:
    task.ext.when == null || task.ext.when

    script:
    """
#!/usr/bin/env python

import argparse
import glob
from Bio import SeqIO

def concatenate_fastas(fasta_files, output_file):
    all_ids = set()
    sequences_by_file = []
    lengths = []

    # Parse all FASTA files
    for file in glob.glob(fasta_files):
        seqs = {}
        for record in SeqIO.parse(file, "fasta"):
            seqs[record.id] = str(record.seq)
            all_ids.add(record.id)
        sequences_by_file.append(seqs)
        lengths.append(len(next(iter(seqs.values()))))  # assume aligned, all same length

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

concatenate_fastas('alignments/*', 'supermatrix.fasta')
    """

    stub:
    """
    touch supermatrix.fasta
    """
}
