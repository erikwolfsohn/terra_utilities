version 1.0

workflow fetch_sra_to_fastq {
  input {
    String? srr_accession
    String? wgs_id
    Int CPUs = 8
  }

  call fastq_dl_sra {
    input:
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

    echo -e 'read1\tread2' >> outfile.tsv
    echo *.fastq.gz | tr [:blank:] '\t' >> outfile.tsv

    python3 <<CODE
    import csv
    with open("./outfile.tsv",'r') as tsv_file:
      tsv_reader=csv.reader(tsv_file, delimiter="\t")
      tsv_data=list(tsv_reader)
      tsv_dict=dict(zip(tsv_data[0], tsv_data[1]))
      with open ("READ1",'wt') as read_1:
        read_1_string=tsv_dict['read1']
        read_1.write(read_1_string)
      with open ("READ2",'wt') as read_2:
        read_2_string=tsv_dict['read2']
        read_2.write(read_2_string)
    CODE
  >>>

  output {
    File read1=read_string("READ1")
    File? read2=read_string("READ2")
  }

  runtime {
    docker: "ewolfsohn/sra_fetch_eutils:1.1"
    memory:"8 GB"
    cpu: "~{CPUs}"
    disks: "local-disk 100 SSD"
    preemptible:  1
  }
}

