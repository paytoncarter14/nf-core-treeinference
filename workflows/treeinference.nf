include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_treeinference_pipeline'

include { CREATEDB } from '../modules/local/createdb/main'
include { GETLOCUSLIST } from '../modules/local/getlocuslist/main'
include { SAMPLETOLOCUS } from '../modules/local/sampletolocus/main'
include { MAFFT_ALIGN } from '../modules/nf-core/mafft/align/main'
include { STRIPR } from '../modules/local/stripr/main'
include { IQTREE } from '../modules/local/iqtree/main'
include { IQTREECONCAT } from '../modules/local/iqtreeconcat/main'
include { TRIMAL } from '../modules/local/trimal/main'
include { WASTRAL } from '../modules/local/wastral/main'

workflow TREEINFERENCE {

    // TODO: allow sample sheet in addition to input_dir
    take:
    input_dir

    main:

    ch_versions = Channel.empty()
    input_ch = Channel.fromPath(input_dir + '/*.fasta').collect().map{[[id: 'all_samples'], it]}

    // Logic for --locus_list param
    // --locus_list is a text file with one locus per line
    // If --locus_list is not provided, all loci in the samples are used instead
    if (params.locus_list == null) {
        GETLOCUSLIST( input_ch )
        locus_list = GETLOCUSLIST.out.loci
    } else {
        locus_list = Channel.fromPath(params.locus_list).map{[[id: 'locus_list'], it]}
    }
    locus_list = locus_list.splitText().map{[[id: it[1].trim()], it[1].trim()]}

    // Logic for --exclude_list param
    // --exclude_list is a text file with one locus per line
    // Any loci in the file are excluded
    if (params.exclude_list != null) {
        exclude_set = file(params.exclude_list).readLines().collect{it.trim()}.toSet()
        locus_list = locus_list.filter{!exclude_set.contains(it[1])}
    }

    // TODO
    // Filter by --min_locus_coverage parameter
    // For example, if --min_locus_coverage is 0.7 and there are 100 loci,
    // taxa with fewer than 70 loci are omitted.

    // Convert one file per sample to one file per locus
    SAMPLETOLOCUS ( locus_list, input_ch )

    // TODO
    // Filter by --min_taxon_coverage parameter
    // For example, if --min_taxon_coverage is 0.7 and there are 100 taxa,
    // loci with fewer than 70 samples are omitted.

    // Align with MAFFT
    MAFFT_ALIGN ( SAMPLETOLOCUS.out.fasta.filter{it[1].size() > 0}, [[], []], [[], []], [[], []], [[], []], [[], []], [])

    // Get rid of _R_ at beginning of reverse complemented MAFFT sequences
    STRIPR ( MAFFT_ALIGN.out.fas )

    // Logic for the --use_trimal parameter
    if (params.use_trimal == true) {
        TRIMAL ( STRIPR.out.fasta )
        iqtree_input = TRIMAL.out.fasta
    } else {
        iqtree_input = STRIPR.out.fasta
    }
    
    // Run IQTREE on each locus to create gene trees, then create species tree with weighted-ASTRAL
    IQTREE ( iqtree_input.filter{file -> file[1].readLines().count{it.startsWith(">")} >= 4} )
    WASTRAL ( IQTREE.out.tree.map{it[1]}.collect().map{[[id: 'trees'], it]} )

    // Run IQTREE on a concatenation of all loci
    IQTREECONCAT ( iqtree_input.map{it[1]}.filter{file -> file.readLines().count{it.startsWith(">")} >= 4}.collect().map{[[id: 'alignments'], it]} )

    /* TODO: stats collection 
    CREATEDB(
        input_ch.map{it[1]}.collect(),
        SAMPLETOLOCUS.out.stats.map{it[1]}.collect()
    ) */

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
