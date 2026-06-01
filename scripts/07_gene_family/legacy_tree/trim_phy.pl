#! usr/bin/perl -w

use strict;
sub usage{
        print STDERR <<USAGE;
        usage: $0 <phy.file> <cut off>
USAGE
exit;
}
my $file=shift;
open IN,"$file" or die $!;
open OUT,">./$file.trim.phy" or die $!;
my ($num_species,$len);
my (@name,@seq,@gap_ratio,@match_ratio);
my %new_seq;
my @u_site;
my $i=0;
my $resultfile="./$file.trim.phy";
while (<IN>){
        chomp;
        if (/^\s+(\d+)\s+(\d+)/){
                $num_species=$1;
                $len=$2;
                next;
        }
        my @temp=split;
        $name[$i]=$temp[0];
        @{$seq[$i]}=(split //,$temp[1]);
        $i++;
}
print  "$num_species\n";
close IN;
for (my $j=0;$j<$len;$j++){
        my ($gap,$match)=(0,0);
        for (my $i=0;$i<$num_species;$i++){
                if ($seq[$i][$j] eq "-"){
                        $gap++;
                }else {
                        $match++;
                }
        }

        $gap_ratio[$j]=$gap/$num_species*100;
        $match_ratio[$j]=$match/$num_species*100;
}

for (my $i=0;$i<$num_species;$i++){
        for (my $j=0;$j<$len;$j++){
                if ($gap_ratio[$j]>=$ARGV[0]){
                        next;
                }else {
                        $new_seq{$i}.=$seq[$i][$j];
                }
        }
        print OUT "$name[$i]\t$new_seq{$i}\n";
}
my $len_temp=length($new_seq{0});
print "$len_temp\n";
`sed -i '1i $num_species        $len_temp' $resultfile`;
