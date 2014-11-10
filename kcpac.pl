#!/usr/bin/perl

use strict;
use warnings;
use Fcntl qw(:seek);

print "kcpac 0.1 by utz\n";

my $debuglvl = $#ARGV + 1;

if ($debuglvl != 2) {
	print "no infile specified\nsyntax: kcpac.pl <infile> <start address (in hex)>\n";
	exit 1;
}

my $infile = $ARGV[0];
my $target = substr $ARGV[0], 0, -4;
my $suffix = ".kcc";
my $outfile = $target . $suffix;

my $progname = pack('A8', $target);	#generate 8 char internal program name
$progname = uc($progname);		#convert to uppercase

my $startaddr = hex($ARGV[1]);

my $binsize = -s $infile;
my $endaddr = $startaddr + $binsize + 1;

my $execaddr = $startaddr;		#for now, auto-run address = start address + header

#check if binfile is present, and open it if it is
if ( -e $infile ) {
	open INFILE, $infile or die "ERROR: Could not open $infile: $!";
	binmode INFILE;
} 
else {
	print "ERROR: $infile not found.\n";
	exit 1;
}

#check header of binfile
my $header = "no";
my $execcounter = 0;
my $byte = 0xff;

sysseek(INFILE, $execcounter, 0) or die $!;	#read header
sysread(INFILE, $byte, 1) == 1 or die $!;
$byte = ord($byte);

if ($byte == 0x7f) {
	$header = "yes";
	$execcounter++;				#skip 2nd byte
	while ($byte >= 2) {			#header ends with 0 or 1
		$execcounter++;
		sysseek(INFILE, $execcounter, 0) or die $!;
		sysread(INFILE, $byte, 1) == 1 or die $!;
		$byte = ord($byte);
		print "$byte\n";	
	}
	$execaddr = $execaddr + $execcounter + 1;
}

close INFILE;
open INFILE, $infile or die "ERROR: Could not open $infile: $!";
binmode INFILE;

#delete outfile if it exists
unlink $outfile if ( -e $outfile );

#create new outfile
open OUTFILE, ">$outfile" or die $!;
binmode OUTFILE;


#generate header
print OUTFILE "$progname", "COM", pack('c6',0,0,0,0,0,3);	#program name, vendor bytes, # of args
print OUTFILE pack('s<',$startaddr);			#start, end, autorun addr
print OUTFILE pack('s<',$endaddr);
print OUTFILE pack('s<',$execaddr);
print OUTFILE pack('c105',0);				#padding
my $buffer;
while (							#copy binfile
		read (INFILE, $buffer, $binsize)
		and print OUTFILE $buffer
	){};
	die "ERROR: Problem copying: $!\n" if $!;


#print info
print "program name:\t$progname.COM\n";
print "header found:\t$header\n";
print "start address:\t";
printf ("%#x", $startaddr);
print "\nend address:\t";
printf ("%#x", $endaddr);
print "\nexec address:\t";
printf ("%#x", $execaddr);
print "\n";

print "success: created $outfile\n";
