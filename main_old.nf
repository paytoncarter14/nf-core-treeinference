process SAMPLETOLOCUS {
    tag "$meta1.id"
    label 'process_single'
    conda "${moduleDir}/environment.yml"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/grep:3.4--h516909a_0' :
        'biocontainers/grep:3.4--h516909a_0' }"

    input:
    tuple val(meta1), val(loci)
    tuple val(meta2), path(fasta, stageAs: 'input/')

    output:
    tuple val(meta1), path("output/*.fasta"), emit: fasta
    path('versions.yml') , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    mkdir output

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
    ' input/* > output/${locus}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sampletolocus:
    END_VERSIONS
    """

    stub:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sampletolocus: 
    END_VERSIONS
    """
}
