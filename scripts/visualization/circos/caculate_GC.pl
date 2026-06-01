#!/share/app/perl-5.22.0/bin/perl -w
=head1 Name
    /hwfssz1/ST_AGRIC/F13ZHQYJSY1409_ME/USER/lilinzhou/chlorella/6.mcscan/4.circos/BD08-BD09/GC/caculate_GC.pl
Info
    Author: lilinzhou, lilinzhou@genomics.cn
    Created Time: 2018-06-26 16:39:01
Usage
    caculate_GC.pl   
=cut
use strict;
use feature qw(say);
use Getopt::Long;
my ($help);
GetOptions(
  "help!"=>\$help
);
die `pod2text $0` if (@ARGV<1);


use Bio::Seq;
use Bio::SeqIO;
use Data::Dumper;

my %hash;
my ($gc_content,$len,$num);
my $seqio_obj=Bio::SeqIO -> new(-file => "$ARGV[0]", -format => 'fasta');
while (my $seq_obj = $seqio_obj->next_seq()) { 
    my $id=$seq_obj->display_id;
    my $seq=$seq_obj->seq;
    $hash{$id}=$seq;
}

foreach my $key (keys %hash){
    $len=length($hash{$key});
    $num=$len/5000;
    for(my $i=0;$i<=$num;$i++){
    my $start=0+$i*5000;
    my $seq=substr($hash{$key},$start,5000);
    my $L=length($seq); $seq=~s/A|a|T|t//gi; my $L1=length($seq);
    my $LAT=$L-$L1;
    $seq=~s/C|c|G|g//gi; my $L2=length($seq);
    my $LCG=$L1-$L2;
    if($LAT+$LCG == 0){$gc_content=0}else{
    $gc_content = $LCG/($LAT+$LCG);}
    $gc_content=sprintf "%.2f",$gc_content;
    my $end=$start+4999;
    if($i == $num){
    print "$key\t$start\t$len\t$gc_content\n";}else{
    print "$key\t$start\t$end\t$gc_content\n";
}
}
}
