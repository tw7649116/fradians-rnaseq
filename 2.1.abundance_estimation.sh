outd=$HOME/axSA_assemblies/drap/stranded/trinity_norm_altogether/abundance_estimation
reads=$HOME/axSA_assemblies/drap/reads/cleaned

tempd=/store/$USER && mkdir -p $tempd/reads && cd $tempd/reads 
rsync --progress $reads/*fq.gz $tempd/reads
find ./ -name \*gz | xargs -P 20 -n1 bash -c 'gzip -dc $0 > ${0%.gz}' &

trid=$HOME/tools/assembly/trinityrnaseq-2.5.1

export PATH=$HOME/tools/assembly/drap/third-party/express-1.5.1-linux_x86_64:$PATH
export PATH=$HOME/tools/assembly/qc/transrate-1.0.3-linux-x86_64/bin:$PATH
export PATH=$HOME/tools/assembly/rnaseq/RSEM-1.3.0:$PATH
export PATH=$HOME/tools/assembly/rnaseq/kallisto_linux-v0.44.0:$PATH
export PATH=$HOME/tools/assembly/rnaseq/Salmon-latest_linux_x86_64/bin:$PATH
export PATH=$HOME/tools/compare/samtools-1.3.1:$PATH

mkdir -p $outd && cd $outd
transcripts=$(readlink -f ../transcripts_fpkm_1.fa)

#Map with RSEM express kallisto salmon
#Finally, Salmon was chosen for speed adn simplicity
#You may edit "met" array accordingly
#No --trinity_mode  flag 
met=(RSEM express kallisto salmon)

for est_method in ${met[@]}; do
    #cmd="$trid/util/align_and_estimate_abundance.pl --SS_lib_type RF --transcripts $transcripts --est_method $est_method --aln_method bowtie2 --prep_reference"
    #eval $cmd &> prep.$est_method.log
    
    if [ "$est_method" = 'salmon' ]; then
        est_method_opts="$est_method --salmon_add_opts --gcBias"
    else
        est_method_opts=$est_method
    fi
    cmd=$(cat samples | xargs -n4 bash -c ' \
        cmd="'$trid'/util/align_and_estimate_abundance.pl \
        --SS_lib_type RF \
        --transcripts '$transcripts' \
        --est_method '"$est_method_opts"' \
        --seqType fq \
        --left $2 --right $3 \
        --aln_method bowtie2 \
        --thread_count 8 --output_dir '$tempd'/'$est_method'_$1 &> '$tempd'/'$est_method'.$1.log"; echo $cmd"\n"')
        echo -e $cmd | xargs -L1 -P 4 bash -c 'eval "${@}"' _
done

ls salmon_*/quant.sf > salmon.sf.file.list
$trid/util/abundance_estimates_to_matrix.pl --est_method salmon \
    --gene_trans_map  ../trinotate/transcripts.gene2tr.map \
    --out_prefix salmon \
    --name_sample_by_basedir \
    --quant_files salmon.sf.file.list

$trid/util/misc/count_matrix_features_given_MIN_TPM_threshold.pl salmon.isoform.TPM.not_cross_norm | tee salmon.isoform.TPM.not_cross_norm.counts_by_min_TPM
$trid/util/misc/contig_ExN50_statistic.pl salmon.isoform.TMM.EXPR.matrix transcripts_fpkm_1.fa > salmon.isoform.TMM.EXPR.matrix.ExN50.stats

#Assembly Ex90N50 2047, Number of Ex90 contigs -- 7912

#Optional: Map busco genes to ExN statistics
#Out of 324 genes that have BUSCO hits, 214 are expressed above Ex95 level.
join -1 2 -2 3 -t$'\t' \
    <(cat salmon.isoform.TMM.EXPR.matrix.E-inputs | sort -k2,2b) \
    <(cat ../../run_busco_euk_trinity_norm_altogether/full_table_busco_euk_trinity_norm_altogether.tsv \
        | grep -v '^#' \
        | sort -k3,3b) \
    | sort -k2n | less
    
join -1 2 -2 3 -t$'\t' \
    <(cat salmon.isoform.TMM.EXPR.matrix.E-inputs | sort -k2,2b) \
    <(cat ../../run_busco_euk_trinity_norm_altogether/full_table_busco_euk_trinity_norm_altogether.tsv \
        | grep -v '^#' \
        | sort -k3,3b) \
    | sort -k2n | less