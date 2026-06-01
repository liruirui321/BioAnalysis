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

use Data::Dumper;
open IN,shift;

my (%hash,%hash2,%hash3);


while(<IN>){
    chomp;
    my @a=split/\t/,$_;
    if($_=~/##/){
    next;
    }else{
    my $gene_pos=int($a[3]/500000);
    $a[8] =~ /Class=(\w+)\/?(\S+)?;/;
    #$type = $1;
    my $length=$a[4]-$a[3]+1;
    $hash{$a[0]}{$gene_pos}{$1}+=$length;
    }
}
#print Dumper(\%hash);
foreach my  $key1 (sort keys %hash){
    my $hash2 = $hash{$key1};
    foreach my $key2 (sort {$a<=>$b} keys %$hash2){
	my $start=$key2*500000;
	my $end=$start+499999;
	my $hash3 = $hash{$key1}{$key2};
	foreach my $key3 (keys %$hash3){
	my $percentage=$hash2->{$key2}->{$key3}/500000;
	print $key1."\t"."\t".$key3."\t".$start."\t".$end."\t".sprintf("%.2f",$percentage)."\n";
	}
    }
}
