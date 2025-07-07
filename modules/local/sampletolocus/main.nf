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
    echo "${loci.join("\n")}" > loci.txt

    for f in input/*; do

        sample=\$(basename "\$f")
        sample="\${sample%.*}"  # remove extension

        awk -v sample="\$sample" -v locifile="loci.txt" '
        BEGIN {
            # Read allowed loci into an array
            while ((getline line < locifile) > 0) {
                loci[line] = 1
            }
            close(locifile)
        }
        /^>/ {
            # Extract locus name after >
            locus = substr(\$0, 2)
            # Check if locus is allowed
            if (!(locus in loci)) {
                skip = 1
            } else {
                skip = 0
                header = ">" sample
                print header >> "output/" locus ".fasta"
            }
            next
        }
        {
            if (!skip) {
                print >> "output/" locus ".fasta"
            }
        }
        ' "\$f"
    done


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
