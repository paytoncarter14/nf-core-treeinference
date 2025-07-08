process COUNTUNIQUESEQS {
    tag "${meta.id}"
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container 'biocontainers/grep:3.4--h516909a_0'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${fasta.name}"), stdout, emit: fasta

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    awk '!/^>/ {seq[\$0]} END {print length(seq)}' "${fasta}"
    """
}
