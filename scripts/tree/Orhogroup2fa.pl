#!/usr/bin/perl -w
use strict;
die "Usage:<Orhogroup_directory_path> <all_pep>" unless @ARGV==2;
my $dir=shift;
my $pep=shift;
my @c;

open DN,"$dir/Single-copy-OG";
mkdir ("$dir/01.splitfiles");
while (<DN>){
	chomp;
	@c=split;
	open DS,">$dir/01.splitfiles/$c[0]";
	print DS $_;
	}
close DN;
close DS;

open IN2,$pep||$!;
my %hash;
my $id;
my $seq;
while (<IN2>){
	$id=$1 if /\>?(\S+)/;
	$/="\>";
	$seq=<IN2>;
	$/="\n";
	$seq=~s/[\>\s+]//g;
	$hash{$id}=$seq;
	}
close IN2;

opendir DH,"$dir/01.splitfiles" or die "cannot open $dir:$!";
my @split;
foreach my $file (readdir DH){
	open IN,"$dir/01.splitfiles/$file" or die "Cannot read files";
	mkdir ("$dir/02.output");
	open OUT,">$dir/02.output/$file.fa";
	while (<IN>){
		chomp;
		@split=split;
		for (my $i=1;$i<@split;$i++){
			if ($hash{$split[$i]}){
			print OUT ">$split[$i]\n$hash{$split[$i]}\n";
			}
		}
	}
}
close IN;
close OUT;
