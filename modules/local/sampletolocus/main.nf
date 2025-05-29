process SAMPLETOLOCUS {
    tag "$meta.id"
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "biocontainers/grep:3.4--h516909a_0"

    input:
    tuple val(meta), val(locus)
    tuple val(meta2), path(fastas, stageAs: 'fasta/')

    output:
    tuple val(meta), path("*.fasta"), emit: fasta
    tuple val(meta), path('SAMPLETOLOCUS.*.stats'), emit: stats
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    awk -v locus="${locus}" '
    FNR == 1 {
        n = split(FILENAME, path_parts, "/")
        full = path_parts[n]
        split(full, name_parts, /\\./)
        base = name_parts[1]
        for (i = 2; i < length(name_parts); i++) {
            base = base "." name_parts[i]
        }
    }

    /^>/ {
    show = (\$0 == ">" locus)
    }

    show {
        if (\$0 ~ /^>/)
            print ">" base
        else
            print
    }
    ' fasta/* > ${locus}.fasta

    echo "${locus},\$(grep -c "^>" ${locus}.fasta)" > SAMPLETOLOCUS.${locus}.stats || true

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sampletolocus:
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sampletolocus: 
    END_VERSIONS
    """
}
