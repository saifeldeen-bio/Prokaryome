# Prokaryome
It is a WDL-based tool designed to streamline microbiome data processing for assembling, polishing, annotating, and visualizing prokaryotic genomes. It simplifies the analysis process from raw sequencing reads to high-quality annotated genomes, making it accessible to both novice and experienced researchers. The pipeline begins with quality control (QC) to assess and filter sequencing reads, removing low-quality reads. This is followed by de novo assembly to construct a draft genome, which undergoes four rounds of polishing to enhance accuracy and eliminate residual errors. After assembly refinement, the workflow performs genome annotation, identifying key features such as coding sequences, tRNAs, and rRNAs. The final step produces visualizations and comprehensive reports, providing insights into genome structure and content.

# Workflow
![Prokaryome_workflow](https://github.com/user-attachments/assets/7e168e54-72d3-47b5-81ab-9a1cf264ede3)

## Installation
 1. Create conda environment:

```bash
conda create -n prokaryome
conda activate prokaryome
```
2. configure Conda channels:
```bash
conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge
conda config --set channel_priority strict
```
3. Install the following tools:

```bash
conda install bioconda::bwa
conda install bioconda::samtools
conda install bioconda::pilon
conda install bioconda::ragtag
```

The remaining tools are pulled from Docker Hub, so there is no need to install them.

4. Install `Cromwell` since it is the execution engine that compile and run WDL workflows.

```bash
conda install bioconda::cromwell
```

Once you've installed, you can write and run WDL workflows

4. Download Prokaryome

```bash
git clone https://github.com/saifeldeen-bio/Prokaryome.git
unzip Prokaryome
cd Prokaryome/
sudo mv extractDraft ../path-to/usr/bin
sudo mv Prokaryome-PE.wdl ../path-to/usr/bin
```
In your home directory run
```bash
nano ~/.bashrc
```
Add the following alias to the bashrc file
```bash
alias Prokaryome-PE='cromwell run /usr/bin/Prokaryome-PE.wdl'
```
Then Save and exit
## Inputs (.json)

```
{
  "Prokaryome.raw_reads": [
    {
      "left": "raw_reads/SRR00000000_1.fastq.gz",
      "right": "raw_reads/SRR00000000_2.fastq.gz"
    }
  ],
  "Prokaryome.reference": "ref/dmel-all-chromosome-r6.46.fasta",
  "Prokaryome.trim_sliding_window": "4:25",
  "Prokaryome.trim_read_min_length": "36",
  "Prokaryome.trim_adapter_file": "adapters/adapters.fa",
  "Prokaryome.trim_head_crop": "0",
  "Prokaryome.trim_trailing_crop": "0",
  "Prokaryome.genovi_status": "complete",
  "Prokaryome.genovi_plot_title": "anytitle",
  "Prokaryome.genovi_title_position": "center",
  "Prokaryome.genovi_color_scheme": "blue"
}
```
1. `Prokaryome.raw_reads`: Your FASTQ files as an array of paired files for paired-end reads.  
2. `Prokaryome.trim_sliding_window`: The sliding window size used for trimming in Trimmomatic.  
3. `Prokaryome.trim_read_min_length`: The minimum read length to retain after trimming in Trimmomatic.  
4. `Prokaryome.trim_adapter_file`: The adapter sequences to be removed from your reads. You can add custom sequences to remove. If you do not want to remove any adapters or sequences, provide a blank file.  
5. `Prokaryome.trim_head_crop`: Trims a specified number of bases from the start of each read, useful for removing overrepresented sequences at the beginning.  
6. `Prokaryome.trim_trailing_crop`: Trims a specified number of bases from the end of each read.  
7. `Prokaryome.genovi_status`: Determines whether each sequence is drawn as a unique circular representation (complete) or as a circle with bands for each sequence (draft).  
8. `Prokaryome.genovi_plot_title`: The title of the image (e.g., strain taxonomic identification).  
9. `Prokaryome.genovi_title_position`: The position of the title on the image: center, top, or bottom.  
10. `Prokaryome.genovi_color_scheme`: The color scheme of the genome. Options include: neutral, blue, purple, soil, grayscale, velvet, pastel, ocean, wood, beach, desert, ice, island, forest, toxic, fire, and spring.  

## Input Directory Structure

The workflow expects the following directory structure:

```
project/
├── input.json       # inputs file
├── raw_reads/       # Contains paired-end FASTQ files
│   ├── sample_1.fastq.gz
│   └── sample_2.fastq.gz
├── ref/             # Contains the reference genome
|    └── reference.fasta
├── adapters/             # Contains the reference genome
       └── adapters.fa
```

## Running

```bash
Prokaryome -i inputs.json
```

## Steps and Tools Used

### Workflow Steps

1. **Quality Control**:  
   - **Tool**: `FastQC` & `MultiQC`
   - Evaluates the quality of raw sequencing reads.

2. **Trimming**:  
   - **Tool**: `Trimmomatic`
   - Removes low-quality bases.

3. **Assembly**:  
   - **Tool**: `Spades`
   - Constructs the genome assembly.

4. **Polishing**:  
   - **Tool**: `BWA`, `Samtools`, and `Pilon`  
   - Refines the assembly across four rounds to improve accuracy.

5. **Assembly Quality Assessment**:  
   - **Tool**: `Quast`
   - Evaluates the quality of the assembly compared to the reference genome.

6. **Draft Genome Generation**:  
   - **Tool**: `RagTag` & `extract_draft.py`
   - Generates a draft genome scaffold using the polished assembly and reference.

7. **Annotation**:  
   - **Tool**: `Prokka`
   - Annotates the genome with genes and functional information.

8. **Visualization**:  
   - **Tool**: `Genovi`
   - Visualizes annotated genome features.

### Required Dependencies

Install the following software as prerequisites:  
- `Cromwell`: Workflow engine for running WDL files.  
- `BWA` For mapping reads during polishing.  
- `Samtools` For BAM file handling.  
- `Pilon` For assembly polishing (not dockerized).  
- `RagTag` For draft genome generation.  

# Outputs

## Quality Control Reports:  
   - FastQC reports for individual samples.  
   - MultiQC summary report consolidating all quality metrics.
   - Quast Assembly Reports

![image](https://github.com/user-attachments/assets/17868715-b6ad-4d23-8ec4-8323d5bbb4c9)

![image](https://github.com/user-attachments/assets/db33a6d0-aab5-46da-823a-276c93d9c41f)

![image](https://github.com/user-attachments/assets/80525848-3a54-47c7-a97b-46db90997dc2)

## Assembly Files
1. **`contigs.fasta`**  
   - Contains assembled contigs.
   - Primary output for downstream analysis.

2. **`scaffolds.fasta`**  
   - Contains assembled scaffolds (contigs connected with gaps).
   - Useful if your data supports scaffolding (e.g., paired-end reads).
     
3. **`assembly_graph.fastg`**  
   - A FASTG file representing the assembly graph.
   - Useful for visualizing and analyzing the assembly structure.

4. **`assembly_graph_with_scaffolds.gfa`**  
   - A GFA format graph that includes scaffold information.
   - Suitable for genome assembly graph viewers.

5. **`contigs.paths`**  
   - Contains the paths of contigs through the assembly graph.

6. **`scaffolds.paths`**  
   - Contains the paths of scaffolds through the assembly graph.
     
7. **`spades.log`**  
   - A detailed log of the SPAdes run.

8. **`params.txt`**  
   - Lists the parameters used for the SPAdes run.

9. **`input_dataset.yaml`**  
   - Describes the input data provided to SPAdes.

10. **`contigs.stats`**  
    - Provides statistics on the assembled contigs (e.g., length, coverage).

11. **`scaffolds.stats`**  
    - Provides statistics on the assembled scaffolds.
      
12. **`corrected/` directory**  
    - Contains reads that were error-corrected during the assembly process.
      
13. **`misc/` directory**  
    - Includes intermediate files and additional data used in the assembly process.


## Annotated Genome:  
   - Prokka outputs, including GenBank, GFF, and Annotation tables.

## Genome Visualization:  
   - Figures and graphical outputs from Genovi like the circular viewer of genome, numbers of Clusters of Orthologous Groups of proteins (COGs) subcategories and their frequencies

![Genovi](https://github.com/user-attachments/assets/fd9ede02-e947-420b-b212-ba820a65bbba)

## References
1. Babraham Bioinformatics, FastQC
2. Ewels, Philip, et al. "MultiQC: summarize analysis results for multiple tools and samples in a single report." Bioinformatics 32.19 (2016): 3047-3048.
3. Bolger, Anthony M., Marc Lohse, and Bjoern Usadel. "Trimmomatic: a flexible trimmer for Illumina sequence data." Bioinformatics 30.15 (2014): 2114-2120.
4. Bankevich, Anton, et al. "SPAdes: a new genome assembly algorithm and its applications to single-cell sequencing." Journal of computational biology 19.5 (2012): 455-477.
5. Jung, Youngmok, and Dongsu Han. "BWA-MEME: BWA-MEM emulated with a machine learning approach." Bioinformatics 38.9 (2022): 2404-2413.
6. Danecek, Petr, et al. "Twelve years of SAMtools and BCFtools." Gigascience 10.2 (2021): giab008.
7. Walker, Bruce J., et al. "Pilon: an integrated tool for comprehensive microbial variant detection and genome assembly improvement." PloS one 9.11 (2014): e112963.
8. Alonge, Michael, et al. "Automated assembly scaffolding using RagTag elevates a new tomato system for high-throughput genome editing." Genome biology 23.1 (2022): 258.
9. Seemann, Torsten. "Prokka: rapid prokaryotic genome annotation." Bioinformatics 30.14 (2014): 2068-2069.
10. Cumsille, Andrés, et al. "GenoVi, an open-source automated circular genome visualizer for bacteria and archaea." PLoS Computational Biology 19.4 (2023): e1010998.
