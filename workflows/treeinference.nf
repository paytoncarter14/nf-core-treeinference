include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_treeinference_pipeline'

include { GETLOCUSLIST } from '../modules/local/getlocuslist/main'
include { SAMPLETOLOCUS } from '../modules/local/sampletolocus/main'
include { MAFFT_ALIGN } from '../modules/nf-core/mafft/align/main'
include { STRIPR } from '../modules/local/stripr/main'
include { IQTREE } from '../modules/local/iqtree/main'

workflow TREEINFERENCE {

    take:
    input_dir

    main:

    ch_versions = Channel.empty()

    input_ch = Channel.fromPath(input_dir + '/*.fasta').collect().map{[[id: 'all_samples'], it]}

    GETLOCUSLIST ( input_ch )
    SAMPLETOLOCUS ( GETLOCUSLIST.out.loci.splitText().map{[[id: it[1].trim()], it[1].trim()]}, input_ch )
    MAFFT_ALIGN ( SAMPLETOLOCUS.out.fasta, [[], []], [[], []], [[], []], [[], []], [[], []], [])
    STRIPR ( MAFFT_ALIGN.out.fas )
    IQTREE ( STRIPR.out.fasta.map{it[1]}.filter{file -> file.readLines().count{it.startsWith(">")} >= 3}.collect().map{[[id: 'alignments'], it]} )

    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'treeinference_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}
