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

#use Data::Dumper;
open IN,shift;

my (%hash,%hash2,%pos,%pos2);

while(<IN>){
    chomp;
    next if $_=~/^#/;
	my @a=split/\s+/,$_;
	for(my $i=$a[3];$i<=$a[4];$i++){
		$pos{$a[0]}{$i}=1;
	}
}

foreach my $key_chr (sort keys %pos){
        my $pos2 = $pos{$key_chr};
        foreach my $key_pos (sort {$a<=>$b} keys %$pos2){
                my $step=int($key_pos/5000);
                $hash{$key_chr}{$step}++;
        }
}
    

#print Dumper(\%hash);
foreach my  $key1 (sort keys %hash){
    my $hash2 = $hash{$key1};
    foreach my $key2 (sort {$a<=>$b} keys %$hash2){
	my $start=$key2*5000;
	my $end=$start+4999;
	my $percentage=sprintf("%.3f",$hash2->{$key2}/5000);
	#print $key1."\t".$start."\t".$end."\t".$hash2->{$key2}."\n";
	print $key1."\t".$start."\t".$end."\t"."$percentage\n";
    }
}
=cut
