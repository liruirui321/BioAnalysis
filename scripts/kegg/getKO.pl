#!/usr/bin/perl -w

=pod
description: get KO from background file
author: Zhang Fangxian, zhangfx@genomics.cn
created date: 20090903
modified date: 20101127, 20090906, 20090905
=cut

use strict;
use Getopt::Long;
use File::Basename qw(basename);
use File::Path qw(mkpath);

my ($gldir, $glist, $ext, $bg, $outdir, $help);

GetOptions("gldir:s" => \$gldir, "ext:s" => \$ext, "glist:s" => \$glist, "bg:s" => \$bg, "outdir:s" => \$outdir, "help|?" => \$help);
$ext ||= "glist";
$outdir ||= "./";

if ((!defined $gldir && !defined $glist) || !defined $bg || defined $help) {
        die << "USAGE";
description: get KO from background file
usage: perl $0 [options]
options:
        -glist <str>    gene-list files, separated by comma ",", with higher priority than -gldir
        -gldir <path>   directory, containging gene-list files, processing all files in the directory, with lower priority than -glist
        -ext <str>      extension of gene-list files in directory gldir, default is "glist"
        -bg <file> *    background file, output of blast2ko.pl
        -outdir <path>  output directory, default is "./"

        -help|?         help information
e.g.:
        perl $0 -glist 1.glist -bg all.ko -outdir ./
        perl $0 -gldir ./ -bg all.ko -outdir ./
        perl $0 -gldir ./ -ext xls -bg all.ko -outdir ./
USAGE
}

# main
if (!-f $bg) {
        die "file $bg not exits\n";
}

if (defined $glist) {
        my @files = split /,/, $glist;
        my $exit = 0;
        for (@files) {
                if (!-f $_) {
                        warn "file $_ not exits\n";
                        $exit = 1;
                }
        }
        exit 1 if ($exit == 1);
        $gldir = "./gltmptmp$$";
        mkdir $gldir or die $!;
        for (@files) {
                symlink $_, "$gldir/" . basename($_);
        }
} else {
        if (!glob("$gldir/*.$ext")) {
                die "no file whith extension of $ext in directory $gldir\n";
        }
        my $gldir0 = $gldir;
        $gldir = "./gltmptmp$$";
        mkdir $gldir or die $!;
        for (glob("$gldir0/*.$ext")) {
                symlink $_, "$gldir/" . basename($_);
        }
}

my %bgs;
open BG, "< $bg" or die $!;
while (<BG>) {
        s/[\r\n]//g;
        next if (/^#/);
        next if (/^$/);
        my @tabs = split /\t/, $_, 2;
        $bgs{$tabs[0]} = $tabs[1] || "";
}
close BG;

if (!-d $outdir) {
        mkpath $outdir or die $!;
}

for my $file (glob("$gldir/*")) {
        my $pre;
        if (defined $glist) {
                $pre = &getKeyName($file);
        } else {
                $pre = $file;
                $pre =~ s/.*\/(.*)\.$ext$/$1/;
        }
        my $output = "$outdir/$pre.ko";
        open IN, "< $file" or die $!;
        open OUT, "> $output" or die $!;
        while (<IN>) {
                chomp;
                my $tab = (split /\t/, $_)[0];
                if (exists $bgs{$tab}) {
                        print OUT "$tab\t$bgs{$tab}\n";
                }
        }
        close OUT;
        close IN;
}

unlink glob "$gldir/*";
rmdir $gldir;

exit 0;

sub getKeyName {
        my ($key_name) = @_;
        $key_name = (split /[\/\\]/, $key_name)[-1];
#       $key_name =~ s/\..*$//;
        if($key_name=~ /(\S+)\.glist$/)
        {
                $key_name = $1;
        }else{
                print "The file name has something wrong!\n";
        }

        return $key_name;
}
