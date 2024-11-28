version 1.0
workflow Prokaryome {
  meta {
  author: "Saifeldeen M. Ibrahim"
  description: "Prokaryome workflow for prokaryotic genome assembly, polishing, quality assessment, annotation, and visualization."
  }
  input{
    Array[Pair[File, File]] raw_reads
    File reference
    File trim_adapter_file
    String trim_sliding_window
    String trim_read_min_length
    String trim_head_crop
    String trim_trailing_crop
 }
  scatter (sample in raw_reads) {
      call fastqc {
          input:
              forward_file = sample.left,
              reverse_file = sample.right
      }
      call trimmomatic{
        input:
            forward_file = sample.left,
            reverse_file = sample.right,
            sliding_window = trim_sliding_window,
            read_min_length = trim_read_min_length,
            adapter = trim_adapter_file,
            head_crop = trim_head_crop,
            trailing_crop = trim_trailing_crop
      }
      call assembly{
        input:
            forward_file = trimmomatic.tpf,
            reverse_file = trimmomatic.tpr
      }
      call polishing_1 {
        input:
            forward_file = trimmomatic.tpf,
            reverse_file = trimmomatic.tpr,
            raw_assembly = assembly.assembly_out
      }
      call polishing_2 {
        input:
            forward_file = trimmomatic.tpf,
            reverse_file = trimmomatic.tpr,
            p1_assembly = polishing_1.round1
      }
      call polishing_3 {
        input:
            forward_file = trimmomatic.tpf,
            reverse_file = trimmomatic.tpr,
            p2_assembly = polishing_2.round2
      }
      call polishing_4 {
        input:
            forward_file = trimmomatic.tpf,
            reverse_file = trimmomatic.tpr,
            p3_assembly = polishing_3.round3
      }
      call quast {
        input:
            ref = reference,
            scaf = assembly.assembly_out,
            pol = polishing_4.round4,
            seqame = sub(basename(sample.left), "_1.fastq.gz$", "")
      }
      call generate_draft_genome {
        input:
            reference_genome = reference,
            polished_assembly = polishing_4.round4,
            seqame = sub(basename(sample.left), "_1.fastq.gz$", "")
      }
      call get_draft_genome {
        input:
            ragtag_draft = generate_draft_genome.draft,
            seqame = sub(basename(sample.left), "_1.fastq.gz$", "")
      }
      call annotation {
        input:
            draft_genome = get_draft_genome.draft,
            seqame = sub(basename(sample.left), "_1.fastq.gz$", "")
      }
      call genovi {
        input:
            annotation_dir = annotation.annotation_out,
            seqame = sub(basename(sample.left), "_1.fastq.gz$", ""),
            status = genovi_status,
            plot_title = genovi_plot_title,
            title_position = genovi_title_position,
            color_scheme = genovi_color_scheme
      }
  }
  call multiqc {
    input:
        fastqc_out = fastqc.FastqcOutDir
  }
}
##############################################################
task fastqc {
  input{
    File forward_file
    File reverse_file
  }
  command <<<
    mkdir -p fastqcOut
    fastqc ~{forward_file} ~{reverse_file} -o fastqcOut
  >>>
  output {
    File FastqcOutDir = "fastqcOut"
  }
  runtime {
    docker: "staphb/fastqc"
  }
}
task multiqc {
  input{
    Array[File] fastqc_out
  }
  command <<<
  mkdir -p multiqcOut
  multiqc ~{sep=' ' fastqc_out}"/" -o multiqcOut
  >>>
  output {
    File MultiqcOutDir = "multiqcOut"
  }
  runtime {
    docker: "staphb/multiqc"
  }
}
task trimmomatic {
  input {
    File forward_file
    File reverse_file
    File adapter
    String sliding_window
    String read_min_length
    String head_crop
    String trailing_crop
    String forward_basename = sub(basename(forward_file), "_1.fastq.gz$", "")
    String reverse_basename = sub(basename(reverse_file), "_2.fastq.gz$", "")
  }
  command <<<
    mkdir -p trimmed_reads/Paired trimmed_reads/Unpaired
    trimmomatic PE -phred33 ~{forward_file} ~{reverse_file} \
    trimmed_reads/Paired/~{forward_basename}_1_paired.fastq trimmed_reads/Unpaired/~{forward_basename}_1_unpaired.fastq \
    trimmed_reads/Paired/~{reverse_basename}_2_paired.fastq trimmed_reads/Unpaired/~{reverse_basename}_2_unpaired.fastq \
    SLIDINGWINDOW:~{sliding_window} MINLEN:~{read_min_length} ILLUMINACLIP:~{adapter}:2:30:10 HEADCROP:~{head_crop} TRAILING:~{trailing_crop}
  >>>
  output {
    File tpf = "trimmed_reads/Paired/~{forward_basename}_1_paired.fastq"
    File tpr = "trimmed_reads/Paired/~{reverse_basename}_2_paired.fastq"
    File tuf = "trimmed_reads/Unpaired/~{forward_basename}_1_unpaired.fastq"
    File tur = "trimmed_reads/Unpaired/~{reverse_basename}_2_unpaired.fastq"
  }
  runtime {
    docker: "staphb/trimmomatic"
    }
}
task assembly {
  input {
    File forward_file
    File reverse_file
    String sample_basename = sub(basename(reverse_file), "_2_paired.fastq$", "")
  }
  command <<<
    spades.py -1 ~{forward_file} -2 ~{reverse_file} -o ~{sample_basename}_assembly
  >>>
  output {
    File assembly_out = "~{sample_basename}_assembly"
  }
  runtime {
    docker: "staphb/spades"
    }
}
task polishing_1 {
  input {
    File forward_file
    File reverse_file
    File raw_assembly
  }
  command <<<
    mkdir polishing_1
    bwa index ~{raw_assembly}/scaffolds.fasta
    bwa mem ~{raw_assembly}/scaffolds.fasta ~{forward_file} ~{reverse_file} | samtools view - -Sb |samtools sort - -o polishing_1/mapping1.sorted.bam
    samtools index polishing_1/mapping1.sorted.bam
    pilon --genome ~{raw_assembly}/scaffolds.fasta --fix all --changes --frags polishing_1/mapping1.sorted.bam --output polishing_1/pilon_stage1|tee polishing_1/stage1.pilon
  >>>
  output {
    File round1 = "polishing_1"
  }
}
task polishing_2 {
  input {
    File forward_file
    File reverse_file
    File p1_assembly
  }
  command <<<
    mkdir polishing_2
    bwa index ~{p1_assembly}/pilon_stage1.fasta
    bwa mem ~{p1_assembly}/pilon_stage1.fasta ~{forward_file} ~{reverse_file} | samtools view - -Sb |samtools sort - -o polishing_2/mapping2.sorted.bam
    samtools index polishing_2/mapping2.sorted.bam
    pilon --genome ~{p1_assembly}/pilon_stage1.fasta --fix all --changes --frags polishing_2/mapping2.sorted.bam --output polishing_2/pilon_stage2|tee polishing_2/stage2.pilon
  >>>
  output {
    File round2 = "polishing_2"
  }
}
task polishing_3 {
  input {
    File forward_file
    File reverse_file
    File p2_assembly
  }
  command <<<
    mkdir polishing_3
    bwa index ~{p2_assembly}/pilon_stage2.fasta
    bwa mem ~{p2_assembly}/pilon_stage2.fasta ~{forward_file} ~{reverse_file} | samtools view - -Sb |samtools sort - -o polishing_3/mapping3.sorted.bam
    samtools index polishing_3/mapping3.sorted.bam
    pilon --genome ~{p2_assembly}/pilon_stage2.fasta --fix all --changes --frags polishing_3/mapping3.sorted.bam --output polishing_3/pilon_stage3|tee polishing_3/stage3.pilon
  >>>
  output {
    File round3 = "polishing_3"
  }
}
task polishing_4 {
  input {
    File forward_file
    File reverse_file
    File p3_assembly
    String sample_basename = sub(basename(reverse_file), "_2_paired.fastq$", "")
  }
  command <<<
    mkdir final_polishing
    bwa index ~{p3_assembly}/pilon_stage3.fasta
    bwa mem ~{p3_assembly}/pilon_stage3.fasta ~{forward_file} ~{reverse_file} | samtools view - -Sb |samtools sort - -o final_polishing/mapping4.sorted.bam
    samtools index final_polishing/mapping4.sorted.bam
    pilon --genome ~{p3_assembly}/pilon_stage3.fasta --fix all --changes --frags final_polishing/mapping4.sorted.bam --output final_polishing/~{sample_basename}.polished|tee final_polishing/~{sample_basename}.pilon
  >>>
  output {
    File round4 = "final_polishing"
  }
}
task quast {
  input {
    File ref
    File scaf
    File pol
    String seqame
  }
  command <<<
    mkdir QC_~{seqame}_ASSEMBLY
    quast.py -o QC_~{seqame}_ASSEMBLY -R ~{ref} ~{scaf}/scaffolds.fasta ~{pol}/~{seqame}.polished.fasta
  >>>
  output {
    File quast_out = "QC_~{seqame}_ASSEMBLY"
  }
  runtime{
    docker: "staphb/quast"
  }
}
task generate_draft_genome {
  input {
    File reference_genome
    File polished_assembly
    String seqame
  }
  command <<<
    ragtag.py scaffold ~{reference_genome} ~{polished_assembly}/~{seqame}.polished.fasta -o ~{seqame}_Draft
  >>>
  output {
    File draft = "~{seqame}_Draft"
  }
}
task get_draft_genome {
  input {
    File ragtag_draft
    String seqame
  }
  command <<<
    mkdir ~{seqame}_Final_Draft
    extractDraft ~{ragtag_draft}/ragtag.scaffold.fasta ~{seqame}
    mv *reordered.fasta ~{seqame}_Final_Draft/
  >>>
  output {
    File draft = "~{seqame}_Final_Draft"
  }
}
task annotation {
  input {
    File draft_genome
    String seqame
  }
  command <<<
    prokka --kingdom Bacteria --outdir ~{seqame}_annotation --prefix ~{seqame} --addgenes ~{draft_genome}/~{seqame}.reordered.fasta
  >>>
  output {
    File annotation_out = "~{seqame}_annotation"
  }
  runtime {
    docker: "staphb/prokka"
  }
}
task genovi {
  input {
    File annotation_dir
    String seqame
    String status 
    String plot_title
    String title_position
    String color_scheme
  }
  command <<<
    genovi -i ~{annotation_dir}/~{seqame}.gbk -s ~{status} -o ~{seqame}_out -t ~{plot_title} -cs ~{color_scheme} --title_position ~{title_position} --size
  >>>
  output {
    File genovi_out = "~{seqame}_out"
  }
  runtime {
    docker: "staphb/genovi"
  }
}
