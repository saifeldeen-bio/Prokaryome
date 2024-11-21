import sys
from Bio import SeqIO
Fasta=sys.argv[1]
sampleID=sys.argv[2]
seq=SeqIO.parse(Fasta,'fasta')
print(seq)
allseq=[i for i in SeqIO.parse(Fasta,'fasta')]
genome=[i for i in allseq if 'RagTag' in i.id]
SeqIO.write(genome,f'{sampleID}.reordered.fasta','fasta')
