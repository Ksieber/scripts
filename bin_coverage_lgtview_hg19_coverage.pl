#!/usr/local/bin/perl -w
use strict;

my $r0=0;
my $r1=0;
my $r2=0;
my $r3=0;
my $r4=0;
my $r5=0;
my $r6=0;
my $r7=0;
my $r8=0;
my $r9=0;
my $r10=0;
my $r20=0;
my $r50=0;
my $r100=0;
my $n=0;

while(<>){
	next if($_ !~ /\d+/);
	if($_ > 0 && $_ <= 1){
		$r0= $r0+$_;
	}
	if($_ > 1 && $_ <= 2){
		$r1 = $r1+$_;
	}
	if($_ > 2 && $_ <= 3){
		$r2 = $r2+$_;
	}
	if($_ > 3 && $_ <= 4){
		$r3 = $r3+$_;
	}
	if($_ > 4 && $_ <= 5){
		$r4 = $r4+$_;
	}
	if($_ > 5 && $_ <= 6){
		$r5 = $r5+$_;
	}		
	if($_ > 6 && $_ <= 7){
		$r6 = $r6+$_;
	}
	if($_ > 7 && $_ <= 8){
		$r7 = $r7+$_;
	}
	if($_ > 8 && $_ <= 9){
		$r8 = $r8+$_;
	}
	if($_ > 9 && $_ <= 10){
		$r9=$r9+$_;
	}
	if($_ > 10 && $_ <= 20){
		$r10=$r10+$_;
	}
	if($_ > 20 && $_ <= 50){
		$r20=$r20+$_;
	}
	if($_ > 50 && $_ <= 100){
		$r50=$r50+$_;
	}
	if($_ > 100){
		$r100=$r100+$_;
	}
	$n++;
}

print "0:\t$r0\n";
print "1:\t$r1\n";
print "2:\t$r2\n";
print "3:\t$r3\n";
print "4:\t$r4\n";
print "5:\t$r5\n";
print "6:\t$r6\n";
print "7:\t$r7\n";
print "8:\t$r8\n";
print "9:\t$r9\n";
print "10:\t$r10\n";
print "20:\t$r20\n";
print "50:\t$r50\n";
print "100:\t$r100\n";

