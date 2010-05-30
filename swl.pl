#!/usr/bin/env perl

################################################################################
# 
# 
# SWL - Short Web Language
# by Kris Kowal
# Version 2.9
# 2004-10-02-21-15 PDT
# 
# SWL may be distributed under the terms of this General Public License.
# 
# converts text/swl to text/html using swl.pm
#
################################################################################

sub version {
print << "END";
SWL (Short Web Language) Version $SWL::VERSION
(C) Copyright 2001-2004 by Kris Kowal
END
}
sub usage {
version;
print << "END";
Usage: swl [[-fFr] input [-o output] ...] ...]

    input is the name of an input file like moo.swl
    output is the name of an output file like moo.html

    -f forces all following files to be written even if the input is
        older than the output
    -F stops forcing (default)
    -r same as "-f ."
    -o overrides the default output file name

    -q quiet
    -v verbose (default)

    input and output can be '-' to use standard io instead of files
END
}

require lib;
for my $path (
#PATH#
'/usr/local/share/swl',
#/PATH#
) {
  if ( -e $path ) {
    import lib $path;
    last;
  }
}
require swl;

my @args = @ARGV;
if ( @args == 0 ) {
	@args = ( '.' );
}

my $force = 0;
my $recur = 0;
my $verbose = 1;
while ( my $arg = shift @args ) {

	if ( $arg =~ /^--(.*)/ ) {
		$1 eq 'version' and do {
			$verbose and version();
			exit;
		};
		$1 eq 'help' and do {
			$verbose and usage();
			exit;
		};
		$verbose and print STDERR "Invalid switch: $1\n";
	} elsif ( $arg =~ /^-(.+)/ ) {
		for $arg ( split '', $1 ) {
			$arg eq 'f' and do {
				$force = 1;
				next;
			};
			$arg eq 'F' and do {
				$force = 0;
				next;
			};
			$arg eq 'r' and do {
				unshift @args, '.';
				next;
			};
			$arg eq 'h' and do {
				$verbose and usage();
				next;
			};
			$arg eq 'q' and do {
				$verbose = 0;
				next;
			};
			$arg eq 'Q' and do {
				$verbose = 1;
				next;
			};
			$arg eq 'v' and do {
				$verbose = 1;
				next;
			};
			$arg eq 'V' and do {
				$verbose = 0;
				next;
			};
			$verbose and print STDERR "Invalid switch: $arg\n";
		}
		next;
	}

	# todo: use glob instead
	my @files = ( $arg );
	while ( my $in = shift @files ) {

		next if $in eq '';

		# construct the default output
		my $out;
		if ( $in ne '-' ) {
			$in = SWL::Grok( $in );
			$out = $in;
			$out =~ s/\.[^\.]*$//;
			$out .= ".html" if $out !~ /\./;
		} else {
			$out = '-';
		}

		# check whether an output override follows
		my $next = shift @args;
		if ( $next eq '-o' ) {
			$out = shift @args;
		} else {
			unshift @args, $next;
		}
		
		if ( $in ne '-' and -d $in ) {
			push @files, grep { -d $_; } glob("$in/*");
			push @files, glob("$in/*.swl");
		} elsif (
			$force or
			$out eq '-' or
			not -e $out or
			( stat "$in" )[9] > ( stat "$out" )[9]
		) {
			if ( $verbose and $out ne '-' ) {
				print "$out\n";
			}
			SWL::File( "$in", "$out" ) or
				$verbose and print STDERR "Error: Could not compile '$in'\n";
		}

	}

}

exit;

