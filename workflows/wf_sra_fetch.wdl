version 1.0

workflow fetch_sra_to_fastq {
  input {
    String sample_id
    String? srr_accession
    String? wgs_id
    Int CPUs = 8
  }

  call fastq_dl_sra {
    input:
      sample_id = sample_id,
      srr_accession=srr_accession,
      wgs_id=wgs_id,
      CPUs=CPUs
  }

  output {
    File read1 = fastq_dl_sra.read1
    File? read2 = fastq_dl_sra.read2
  }
}

task fastq_dl_sra {
  input {
    String sample_id
    String? srr_accession
    String? wgs_id
    Int CPUs
  }
  command <<<
    if [[ ! -z "~{srr_accession}" ]];
    then
      prefetch ~{srr_accession}
      parallel-fastq-dump --sra-id "~{srr_accession}/~{srr_accession}.sra" --threads "~{CPUs}" --split-3 --gzip
    elif [[ ! -z "~{wgs_id}" ]];
    then
      output=($( esearch -db sra -query "~{wgs_id}" | \
        efetch -format docsum | \
        xtract -pattern DocumentSummary -element Run@acc | \
        tr '\t' '\n' ))
      if [[ ! -z "${output}" ]];
      then
        prefetch "${output}"
        parallel-fastq-dump --sra-id "${output}/${output}.sra" --threads "~{CPUs}" --split-3 --gzip
      else
        echo "DATA MISSING"
      fi
    else
      echo "You must provide a valid WGS id in the wgs_id column, or a valid SRR accession in the srr_accession column."
    fi

    if [[ -f "~{srr_accession}.fastq.gz" ]]; 
    then
      mv "~{srr_accession}.fastq.gz" "~{srr_accession}_1.fastq.gz"
    elif [[ -f "${output}.fastq.gz" ]];
    then
      mv "${output}.fastq.gz" "${output}_1.fastq.gz"
    fi

    if [[ -f "~{srr_accession}_1.fastq.gz" ]];
    then
      mv -v "~{srr_accession}_1.fastq.gz" "~{sample_id}_1.fastq.gz"
    elif [[ -f "${output}_1.fastq.gz" ]];
    then
      mv -v "${output}_1.fastq.gz" "~{sample_id}_1.fastq.gz"
    fi

    if [[ -f "~{srr_accession}_2.fastq.gz" ]];
    then
      mv -v "~{srr_accession}_2.fastq.gz" "~{sample_id}_2.fastq.gz"
    elif [[ -f "${output}_2.fastq.gz" ]];
    then
      mv -v "${output}_2.fastq.gz" "~{sample_id}_2.fastq.gz"
    fi
  >>> 

  output {
    File read1="~{sample_id}_1.fastq.gz"
    File? read2="~{sample_id}_2.fastq.gz"
  }

  runtime {
    docker: "ewolfsohn/sra_fetch_eutils:1.1"
    memory:"8 GB"
    cpu: "~{CPUs}"
    disks: "local-disk 100 SSD"
    preemptible:  1
  }
}

