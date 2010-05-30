################################################################################
# 
# SWL - Short Web Language
# by Kris Kowal
#
# SWL may be distributed under the terms of this General Public License.
# converts text/swl to text/html
# 
#
# Revision History
# (most recent first)
#
# 2005-08-15-1918    distribution 10 of SWL 2 
# 2005-08-06-1244                             fixed HTML include bug
# 2004-10-02-2115 PDT distribution 9 of SWL 2 attempted to fix newline problem
#                                             added email mangling
#                                             made ~/ expand to <swl /root>/
#                                              in SWL URL's
#                                             added C tag for calendars with
#                                              event descriptions in the date
#                                              cells
#                                             renamed swl swl.pl and rewrote
#                                              based on common usage including
#                                              standard io streams and "-f ."
#                                              default behavior
#                                             fixed bug whith the file include
#                                              tag.
#                                             guaranteed spec compliance for
#                                              some tags by binding properties
#                                              in double quotes.
#                                             fixed bug: failure to recognize
#                                              tags with following white space
#                                             fixed many bugs by moving toward
#                                              use strict
# ????-??-??-???? ??? distribution 8 of SWL 2 packaged for solaris 9
# 2003-05-09-1953 PST distribution 7 of SWL 2
#                                             improved command line interface
#                                             used environment variables to find
#                                              swl.pm
#                                             changed the $SWL::dir to @SWLPATH
#                                              for searching for locations with
#                                              swl files
#                                             added alternating table row
#                                              properties syntax
#                                             conformed to no news is good news
#                                              unix ideology
# 2002-10-25-0007 PDT distribution 6 of SWL 2 fixed a mis-spell in documentation
#                                             extended interpretation of month
#                                              names in calendars
#                                             <swl date> tag now reports local
#                                              time
# 2002-02-03-0151 PST distribution 5 of SWL 2 documentation fleshed out
#                                             added support for new file format
#                                              includes (text, html, csv, tab)
#                                             added support for .png graphics
#                                             fixed 'pre' bug
#                                             calendar tag
# ????-??-??-???? ??? distribution 4 of SWL 2 new logo and coresponding icons
# 2002-01-25-1111 PST distribution 3 of SWL 2 some bug fixes
#                                              added local.swlt search
# 2001-11-06-2327 PST distribution 2 of SWL 2 major release
# 2001-09-16-2122 PDT distribution 1 of SWL 2
# 2001-05-02-1429 PDT rebuilt
# 2000-08-26-1713 PDT multiple file support
# 2000-07-28          born as HT.pl
# 
################################################################################

$SWL::VERSION = "2.10";

use Cwd;

for my $path (
#PATH#
'/usr/local/share/swl',
#/PATH#
) {
  if ( -e $path ) {
    @::SWLPATH = ( "$path/lib" );
    last;
  }
}

################################################################################

# SWL
# returns a single string of swl code, without outlining and such

sub SWL
{
  return

    &SWL::CompilePost
    (
      &SWL::Compile
      (
        &SWL::CompilePre
        (
          &SWL::Structure( shift )
        )
      )
    );
    
}

################################################################################

package SWL;

################################################################################

sub Glob {
  my $file = shift;

  # prepend the current working directory if necessary
  if (
    $file !~ m/^[\\\/]/ and
    $file !~ m/^[a-z]\:[\\\/]/i
  ) {
    $file = ::cwd() . '/' . $file;
  }
  
  my @leftss = ([]);
  my @rights = split /\//, $file;

  while ( @rights ) {
    my $right = shift @rights;
    if ( $right eq '.' ) {
      # do Nothing
    } elsif ( $right eq '..' ) {
      # back up one
      @leftss = map {
        pop @$_;
        $_;
      } @leftss;
    } elsif ( $right eq '...' ) {
      @leftss = map {
        my @parts = @$_;
        map {
          [ @parts[0..$_] ];
        } reverse 0..$#parts;
      } @leftss;
    } else {
      @leftss = map {
      	my @paths = @$_;
      	my $path = join '/', @paths;
       	[ @paths, $right ];
      } @leftss;
    }
  }

  my @files;
  for $lefts ( @leftss ) {
    my $file = join '/', @$lefts;
    push @files, $file if -e $file;
  }
  return @files;
}

sub Grok {
  my $pattern = shift;
  my @files = Glob $pattern;
  return shift @files;
}

################################################################################

sub File
{
  my $FileIn = shift;
  my $FileOut = shift;

  # Store the old current directory (Restore at the end of this function)
  my $Cwd = ::cwd();

  # Move into the file's directory
  my @Path = split /[\\\/]/, $FileIn;
  $FileIn = pop @Path;
  chdir join '/', @Path;
  
  # get this file
  ( open FILE, "$FileIn" ) or ( open FILE, "$FileIn.swl" ) or return undef;
  my $In = join "\n", map {chomp; $_} <FILE>;
  close FILE;

  my @LocalIns = split /\./, $FileIn;
  shift @LocalIns;
  pop @LocalIns;

  # include whatever template is relevant
  for
  (
    map ".../$_",
    map {($_, ".$_");}
    map { join '.', $_, @LocalIns, 'swlt' }
    ('@', 'local')
  )
  {
    my $FileLocal = Grok($_);
    if ( $FileLocal ne '' ) 
    {
      $In = "+>$FileLocal\n$In";
      last;
    }
  }

  # compile
  my $Out = &main::SWL( $In );
  
  # put the file
  if ( $FileOut eq '' )
  {
    $FileOut = $FileIn;
    $FileOut =~ s/\.swl$//i;
    $FileOut = "$FileOut.html";
  }
  
  ( open FILE, ">$FileOut" ) or return undef;
  print FILE $Out;
  close FILE;
  
  chdir $Cwd;
  return 1;
}

################################################################################
################################################################################

# takes SWL code and converts it into a SWL node tree

sub Structure
{
  my @Lines = split /\n/, shift;

  # map the lines and assign their line number
  my @Lines = map
  {
    $Lines[$_] =~ s/^(\s*)//;
    {
      'string' => $Lines[$_],
      'space' => length $1,
      'number' => $_,
    };
  } 0..$#Lines;

  # create a structure root  
  my $Root = 
  {
    'mark' => 'p',
    'nodes' => [],
    'vars' => {},
  };
  
  my @NodeStack = ( $Root );
  my $Mark;
  my $Line;
  my $Level;

  # simplify lines
  while ( $Line = shift @Lines )
  {
  
    my $Number = $Line->{'number'};
    my $Space = $Line->{'space'};
    my $String = $Line->{'string'};
    
    my $StringLeft;
    my $StringRight;
    
    # if there's an open bracket (a disallowed tag character)
    if ( $String =~ '<' )
    {
      my $Pos = index $String, '<';
      $StringRight = substr $String, $Pos;
      $String = substr $String, 0, $Pos;
    }
    
    # if there is a tag bracket
    if ( $String =~ '>' )
    {
      my $Pos = index $String, '>';
      $StringLeft = substr $String, 0, $Pos;
      $StringRight = ( substr $String, $Pos + 1 ) . $StringRight;
      $StringLeft =~ s/\s*$//g; # clean trailing space off
      $StringRight =~ s/\s*$//g; # clean trailing space off
    }
    # if there isn't a tag bracket
    else
    {
      $StringLeft = '';
      $StringRight = $String . $StringRight;
    }
    
    # if there was any mark information
    if ( $StringLeft ne '' )
    {
    
      # clean off trailing space
      $StringLeft =~ s/\s+$//;

      # get the first mark
      my @Marks = split '\.', $StringLeft;
      my $Mark = shift @Marks;
      
      # put the content back on
      if ( $StringRight ne '' )
      {
      
        # push the content onto a new line
        unshift @Lines,
        (
          map
          {
            {
              'string' => '/>',
            };
          } -1..$#Marks,
        );
        unshift @Lines,
        (
          {
            'space' => 0,
            'number' => $Number,
            'string' => $StringRight,
          }
        );

      }
    
      # push the rest of the marks back on the stack
      unshift @Lines, map
      {
        {
          'space' => $Space,
          'number' => $Number,
          'string' => "$_>",
        };
      } @Marks;
      
      
      # interpret the relevent mark
      
      # if it's a stack up
      if ( $Mark ne '/' )
      {

        # add the node to the tree      
        my %Node =
        (
          'mark' => $Mark,
          'linenumber' => $Number,
          'space' => $Space, # this value is useless beyond the scope of this function.
          'nodes' => [],
        );

        push @{ $NodeStack[$#NodeStack]{'nodes'} }, \%Node;
        push @NodeStack, \%Node;
          
      }
      
      # if it's a stack down
      else
      {
        # pop the node stack
        pop @NodeStack if $#NodeStack > 0;
      }
      
    }
    # if there wasn't any mark information on this line
    else
    {
    
      $Space -= $NodeStack[$#NodeStack]{'space'} + 1;
    
      # add the line to the node stack
      my %Node =
      (
        'mark' => '',
        'linenumber' => $Number,
        'nodes' => [ ( "\t" x $Space ) . $StringRight ],
      );

      push @{ $NodeStack[$#NodeStack]{'nodes'} }, \%Node;
      
    }

  }
  
  return $Root;
}

################################################################################

sub Structure::TXT
{
  my $In = shift;
  return map
  {
    {
      'mark' => '',
      'nodes' =>
      [
        $_,
      ],
    };
  } split "\n", $In;
}

################################################################################

sub Structure::HTML
{
  my $In = shift;
  return
  {
    'mark' => ':',
    'nodes' =>
    [
      {
        'mark' => '',
        'nodes' =>
        [
          $In,
        ],
      },
    ],
  };
}

################################################################################

sub Structure::CSV
{
  return map
  {

    # spearate the line into tab delimited cells with '.' in blank ones
    # account for quotes

    my $Line = $_;
    chomp $Line;

    my @Cells;

    while ( $Line ne '' )
    {
      if ( $Line =~ '^"' )
      {

        my $Cell;
        $Line = substr $Line, 1; # bump the inital quote

        while (1)
        {
          my $QuotePos = index $Line, '"';
          my $QuoteQuotePos = index $Line, '""';
          my $QuoteCommaPos = index $Line, '",';
          if ( $QuotePos == $QuoteQuotePos ) # search for real quotes
          {
            $Cell .= substr $Line, 0, $QuotePos;
            $Cell .= '"';
            $Line = substr $Line, $QuotePos + 2;
          }
          elsif ( $QuotePos == $QuoteCommaPos ) # search for end of cell quotes
          {
            $Cell .= substr $Line, 0, $QuotePos;
            $Line = substr $Line, $QuotePos + 2;
            last;
          }
          else
          {
            $Cell .= $Line;
            $Line = '';
            last;
          }
        }
        push @Cells, "$Cell";
      }
      elsif ( $Line =~ '^,' )
      {
        push @Cells, '.';
        $Line = substr $Line, 1;
      }
      else
      {
        if ( $Line =~ ',' )
        {
          my $CommaPos = index $Line, ",";
          my $Cell = substr $Line, 0, $CommaPos;
          $Cell = '.' if $Cell eq '';
          push @Cells, $Cell;
          $Line = substr $Line, $CommaPos + 1;
        }
        else
        {
          push @Cells, $Line;
          $Line = '';
        }
      }
    }

    {
      'mark' => '',
      'nodes' =>
      [
        join "\t", @Cells
      ],
    };

  } split "\n", shift;
}

################################################################################

sub Structure::TAB
{
  return map
  {

    # spearate the line into tab delimited cells with '.' in blank ones
    # account for quotes

    my $Line = $_;
    chomp $Line;

    my @Cells;

    while ( $Line ne '' )
    {
      if ( $Line =~ '^"' )
      {

        my $Cell;
        $Line = substr $Line, 1; # bump the inital quote

        while (1)
        {
          my $QuotePos = index $Line, '"';
          my $QuoteQuotePos = index $Line, '""';
          my $QuoteTabPos = index $Line, "\"\t";
          if ( $QuotePos == $QuoteQuotePos ) # search for real quotes
          {
            $Cell .= substr $Line, 0, $QuotePos;
            $Cell .= '"';
            $Line = substr $Line, $QuotePos + 2;
          }
          elsif ( $QuotePos == $QuoteTabPos ) # search for end of cell quotes
          {
            $Cell .= substr $Line, 0, $QuotePos;
            $Line = substr $Line, $QuotePos + 2;
            last;
          }
          else
          {
            $Cell .= $Line;
            $Line = '';
            last;
          }
        }
        push @Cells, "$Cell";
      }
      elsif ( $Line =~ "^\t" )
      {
        push @Cells, '.';
        $Line = substr $Line, 1;
      }
      else
      {
        if ( $Line =~ "\t" )
        {
          my $CommaPos = index $Line, "\t";
          my $Cell = substr $Line, 0, $CommaPos;
          $Cell = '.' if $Cell eq '';
          push @Cells, $Cell;
          $Line = substr $Line, $CommaPos + 1;
        }
        else
        {
          push @Cells, $Line;
          $Line = '';
        }
      }
    }

    {
      'mark' => '',
      'nodes' =>
      [
        join "\t", @Cells
      ],
    };

  } split "\n", shift;
}


################################################################################

sub StructureInclude
{
	my $Node = shift;
	my $File = shift;
	my $Extention = shift;
	
	my $Grok = Grok( $File );

	if (
		(
			$File !~ /^[\\\/]/ and
			$File !~ /^[a-z]\:[\\\/]/i
		) and
		$Grok eq ''
	)
	{
		for my $Path ( @::SWLPATH )
		{
			$Grok = Grok( "$Path/$File" );
			last if $Grok ne '';
		}
	}

	my $Path = $Grok;
	$Path =~ s/[^\\\/]*$//;

	my %Types = (
		'swl' => 'SWL',
		'swlt' => 'SWL',
		'text' => 'TXT',
		'csv' => 'CSV',
		'tab' => 'TAB',
		'html' => 'HTML',
		'htm' => 'HTML',
		'txt' => 'TXT',
	);
	$Extention = $1 if not $Extention and $File =~ m/\.([^\.]+)$/i;
	$Type = $Types{$Extention};

	(open FILE, "$Grok") or print STDERR "Unable to open '$File'\n";
	my $In = join "\n", map {chomp; $_} <FILE>;
	close FILE;

	my $Cwd = ::cwd();
	chdir $Path;

	if ( $Type eq 'SWL' )
	{

		# make a structure (multi-tree of nodes)
		my $Structure = &Structure( $In );
		$Structure = &CompilePre( $Structure );

		# add those nodes
		push @{ $Node->{'nodes'} }, @{ $Structure->{'nodes'} };

	}
	elsif ( $Type eq 'HTML' )
	{
		push @{ $Node->{'nodes'} }, &Structure::HTML( $In );
	}
	elsif ( $Type eq 'TXT' )
	{
		push @{ $Node->{'nodes'} }, &Structure::TXT( $In );
	  }
	elsif ( $Type eq 'CSV' )
	{
		push @{ $Node->{'nodes'} }, &Structure::CSV( $In );
	  }
	elsif ( $Type eq 'TAB' )
	{
		push @{ $Node->{'nodes'} }, &Structure::TAB( $In );
	}
	else
	{

		my $NodeNew =
		{
			'mark' => '',
			'nodes' =>
			[
				$In,
			],
		};
		push @{ $Node->{'nodes'} }, $NodeNew;

	}

	chdir $Cwd;

}

################################################################################

#  reads high level tags, like '+' to add nodes from other files

#  File

#    Title (from highest header level or from the 'title' directive, depending)

#    NodeRoot
#    NodeParent

#    FileNext
#    FilePrev
#    FileParent

#    TOC

sub CompilePre
{

  my $RootIn = shift;
  my $RootOut = {};
  
  my @StackIn = ( $RootIn );
  my @StackOut = ( $RootOut );
  
  RECUR: while ( @StackIn != 0 )
  {
  
    my $NodeIn = $StackIn[$#StackIn];
    my $NodeOut = $StackOut[$#StackOut];
    
    # copy each key, recur for node lists
    while ( my @Keys = keys %$NodeIn )
    {
    
      my $Key = shift @Keys;
      
      # if it's a node list, copy its members
      if ( $Key eq 'nodes' )
      {
      
        # copy each node      
        while ( my $Node = shift @{ $NodeIn->{'nodes'} } )
        {
        
          # if the node is just data, don't recur, just copy
          if ( $Node->{'mark'} eq '' )
          {
            push @{ $NodeOut->{'nodes'} }, $Node;
          }
          
          # handle includes
          elsif ( $Node->{'mark'} eq '+' )
          {

            # read in each file
            foreach my $NodeSub ( @{ $Node->{'nodes'} } )
            {
            
              if ( $NodeSub->{'mark'} eq '' )
              {
              	StructureInclude( $NodeOut, $NodeSub->{'nodes'}[0] );
              }
              elsif
              (
                grep { $NodeSub->{'mark'} eq $_ }
                'swl', 'swlt', 'html', 'text', 'txt', 'csv', 'tab'
              )
              {
                foreach my $NodeSubSub ( @{ $NodeSub->{'nodes'} } )
                {
                  if ( $NodeSubSub->{'mark'} eq '' )
                  {
										StructureInclude( $NodeOut, $NodeSubSub->{'nodes'}[0],  $NodeSub->{'mark'} );
                  }
                }
              }
              else
              {
              	StructureInclude( $NodeOut, $NodeSub->{'nodes'}[0], 'text' );
              }
              
            }
            
          }
          
          # if it's not just data, there might be sub-nodes, so recur
          else
          {
          
            my $NodeNew = {};
            push @{ $NodeOut->{'nodes'} }, $NodeNew;
          
            push @StackIn, $Node;
            push @StackOut, $NodeNew;
            next RECUR;
          
          }
          
        }
      
      }
      
      # otherwise, just copy the key over
      else
      {
        $NodeOut->{$Key} = $NodeIn->{$Key};
      }
      
      delete $NodeIn->{$Key};
      
    }
    
    pop @StackIn;
    pop @StackOut;
    
  }
  
  return $RootOut;

}

################################################################################

# The template function is a fallback, in case any of the template '<swl>' tags
# in the datafile weren't replaced.  this either deletes them or replaces them
# with defaults.

sub CompilePost
{

  my $String = shift;
  my $Templatez = shift;
  
  my %TemplateChangerz;
  
  my $Body;
  if ( exists $Templatez->{'.template'} )
  {
    $Body = $String;
    $String = '<swl template>';
  }
  
  # replace all templates
  while ( $String =~ '<swl ' )
  {
  
    my $Pos = index $String, '<swl ';
    
    my $StringLeft = substr $String, 0, $Pos;
    my $StringRight = substr $String, $Pos + 5;
    my $Tag;
    
    # if the tag ends (as it is supposed to)    
    if ( $StringRight =~ '>' )
    {
      
      my $Pos = index $StringRight, '>';
      
      $Tag = substr $StringRight, 0, $Pos;
      $StringRight = substr $StringRight, $Pos + 1;
      
      # get rid of trailing spaces
      $Tag =~ s/\s+$//;
      
      # get rid of global requirement '/'s
      $Tag =~ s/\///g;
      
      # if it is a member of a template changer
      if ( exists $TemplateChangerz{$Tag} )
      {
        $Tag = $TemplateChangerz{$Tag};
      }      

      # find a replacement
      if ( $Tag eq 'body' )
      {
        $Tag = $Body;
      }
      elsif ( $Tag eq 'date' )
      {
        $Tag = localtime;
      }
      elsif ( $Tag eq 'author' )
      {
        $Tag = "SWL $SWL::VERSION";
      }
      # if it's a template changer
      elsif ( $Tag =~ /^(.*) \= (.*)$/ )
      {
        $TemplateChangerz{$1} = $2;
        $Tag = '';
      }
      # find a substitude for the mid-string
      elsif ( exists $Templatez->{ ".$Tag" } )
      {
      
        my @Lines = @{ $Templatez->{ ".$Tag" } };
        
        $Tag = join "\n", @Lines;

        # recompile the contents of the tag        
        my $node = &Structure( ":>\n$Tag" );
        $Tag = &Compile( $node );
        
      }
      else
      {
        $Tag = '';
      }
      
    }
    
    $Tag =~ s/\s+$//;
    $Tag =~ s/^\s+//;

    $String = $StringLeft . $Tag . $StringRight;
    
  }
  
  # find and replace link bits
  while ( $String =~ '< ' )
  {
  
    my $Pos = index $String, '< ';
    
    my $StringLeft = substr $String, 0, $Pos;
    my $StringRight = substr $String, $Pos + 2;
    my $Tag;
    
    # if the tag ends (as it is supposed to
    if ( $StringRight =~ ' >' )
    {
      
      my $Pos = index $StringRight, ' >';
      
      $Tag = substr $StringRight, 0, $Pos;
      $StringRight = substr $StringRight, $Pos + 2;
      
      # collect the parts from the tag's content
      my @Parts = ();
      while ( $Tag ne '' )
      {
      
        my $Part;
      
        # get rid of leading and trailing spaces
        $Tag =~ s/^\s*(.*)\s*$/$1/;
        
        # if the part is in quotes
        if ( '"' eq substr $Tag, 0, 1 )
        {
          $Tag = substr $Tag, 1;
          if ( $Tag =~ '"' )
          {
            my $Pos = index $Tag, '"';
            $Part = substr $Tag, 0, $Pos;
            $Tag = substr $Tag, $Pos + 2;
          }
          else
          {
            $Part = $Tag;
          }
        }
        # if it ends with a space
        elsif ( $Tag =~ ' ' )
        {
          my $Pos = index $Tag, ' ';
          $Part = substr $Tag, 0, $Pos;
          $Tag = substr $Tag, $Pos + 1;
        }
        # otherwise, just use whatever's left
        else
        {
          $Part = $Tag;
          $Tag = '';
        }
        
        push @Parts, $Part;
        
      }
      
      # determine what type of output this warrants
      my $Part = shift @Parts;
      $Part =~ s/^\~\//$Templatez->{'.root'}[0]\//; # grok
      #  if it's an image
      if
      (
        $Part =~ /\.gif/
        or $Part =~ /\.jpg/
        or $Part =~ /\.jpeg/
        or $Part =~ /\.svg/
        or $Part =~ /\.png/
      )
      {
        my $File = $Part;
        my $Name = shift @Parts;
        my $Propertys = join '', map " $_", @Parts;

        $File =~ s/ /%20/g;
        $Name = qq("$Name") if $Name =~ ' ';

        $Tag = qq(<img src="$File" alt="$Name$Propertys">);
      }
      # if it's an email address
      elsif ( $Part =~ /\@/ )
      {
        my $Link = $Part;
        my $Name = shift @Parts;
      	if ( $Templatez->{'.email-mangle'}[0] )
	{
          ( my $Left, my $Right ) = split '@', $Link;
          $Left = join ', ', reverse map "'&#$_'", map ord, split '', $Left;
          $Right = join ', ', reverse map "'&#$_'", map ord, split '', $Right;
	  if ( not $Name ) {
	    $Name = "left + '&#64' + right";
	  } else {
	    $Name = '"' . ( join '', map "&#$_", map ord, split '', $Name ) . '"';
	  }
          $Tag = qq{
            <script language=javascript>
	      var left = [ $Left ].reverse().join("");
	      var right = [ $Right ].reverse().join("");
              document.write( "<a href='mailto:" + left + '&#64' + right + "'>" );
              document.write( $Name );
              document.write( "</a>" );
            </script>
          };
	}
	else
	{
          $Name = $Link if $Name eq '';
          $Link =~ s/ /%20/g;
          $Tag = qq(<a href="mailto:$Link">$Name</a>);
	}
      }
      # otherwise, treat it as a link
      else
      {
        my $Link = $Part;
        my $Name = shift @Parts;
        $Name = $Link if $Name eq '';
        $Link =~ s/ /%20/g;
        $Tag = qq(<a href="$Link">$Name</a>);
      }
      
    }
    
    $String = $StringLeft . $Tag . $StringRight;
    
  }
  
  return $String;
  
}

################################################################################
#
#  COMPILATION FUNCTIONS
# all of the following functions and variables are used by the recursive
# compile function.
#

# changes SWL nodes into a string of HTML recursively

sub Compile
{
  my $Node = shift;
  my $Parent = shift;
  my $Level = shift;
  my $Out;
  
  $Level = 0 if not defined $Level;
  
  # find the list of marks and templates
  if ( defined $Parent )
  {

    # construct the current node's mark by concatenating the local mark onto
    #   the local mark
    $Node->{'mark'} = "$Parent->{'mark'}.$Node->{'mark'}";

    # construct a mark list from the local marks and the parent's marks
    $Node->{'vars'} =
    {
      %{ &CopyMarkNest( $Parent->{'vars'} ) },
      %{ &CopyMarkNest( $Node->{'vars'} ) },
    };
    
  }
  else
  {
  
    # construct the current node's mark from itself
    $Node->{'mark'} = ".$Node->{'mark'}";
    
  }


  # MARKS
  
  # find the longest mark in the mark list that the node's mark fits in
  #   and call the appropriate build function
  FIND_MARK:
  {
  
    # search through user defined marks first
    
    my $Markz = &FlatenMarkNest( $Node->{'vars'}{'^'}[1] );
    
    # sort keys
    my @Marks = sort
    {
      my $aba = $a;
      my $bab = $b;
      $aba =~ s/\.//g;
      $bab =~ s/\.//g;
      ( length( $b ) - length( $bab ) )
      <=>
      ( length( $a ) - length( $aba ) )
      ;
    } keys %$Markz;
    
    # find the first mark on the list that fits
    foreach my $Mark ( @Marks )
    {
      if ( $Node->{'mark'} =~ /$Mark$/ )
      {
        $Out = &BuildMacro( $Markz->{$Mark}, $Node, $Level );
        last FIND_MARK;
      }
    }
    
    # search builtin marks
    # sort keys
    my @Marks = sort
    {
      my $aba = $a;
      my $bab = $b;
      $aba =~ s/\.//g;
      $bab =~ s/\.//g;
      ( length( $b ) - length( $bab ) )
      <=>
      ( length( $a ) - length( $aba ) )
      ;
    } keys %SWL::Builds;
    # find the first mark on the list that fits
    foreach my $Mark ( @Marks )
    {
      if ( $Node->{'mark'} =~ /\.$Mark$/ )
      {
        $Out = &{ $SWL::Builds{$Mark} }( $Node, $Parent, $Level );
        last FIND_MARK;
      }
    }
    
  }
  
  
  # TEMPLATE REPLACEMENTS (impossible infinite recursion)
  
  my $Templatez = &FlatenMarkNest2( $Node->{'vars'}{'='}[1] );

  my $In = $Out;
  my $Out;

  # replace all templates
  while ( $In =~ '<swl ' )
  {
  
    my $Pos = index $In, '<swl ';
    
    $Out .= substr $In, 0, $Pos;
    $In = substr $In, $Pos + 5;
    
    # if the tag ends (as it is supposed to)    
    if ( $In =~ '>' )
    {
      
      my $Pos = index $In, '>';
      
      my $Tag = substr $In, 0, $Pos;
      $In = substr $In, $Pos + 1;
      
      # get rid of trailing spaces
      $Tag =~ s/\s+$//;
      
      # find a substitude for the mid-string
      if ( exists $Templatez->{ ".$Tag" } )
      {

        my @Lines = @{ $Templatez->{ ".$Tag" } };
        
        $Tag = join "\n", @Lines;

        # recompile the contents of the tag
        my $Node = &Structure( ":>\n$Tag" );
        $Tag = &Compile( $Node );
        
      }
      else
      {
        $Tag = "<swl $Tag>";
      }
      
      $Tag =~ s/\s+$//;
      $Tag =~ s/^\s+//;
      
      $Out .= $Tag;
      
    }
    
    
  }
  
  $Out .= $In;

  if ( wantarray )
  {
    return
    (
      $Out,
      $Templatez,
    );
  }
  else
  {
    return $Out;
  }
  
}

################################################################################

# develops a node based on a macro definition hash

sub BuildMacro
{
  my $Macro = shift;
  my $Node = shift;
  my $Level = shift;
  my $Out;
  
  &ClearBlankNodes( $Node );
    
  # if there's only one node (single)
  if ( @{ $Node->{'nodes'} } == 1 )
  {
  
    if ( $Node->{'nodes'}[0]{'mark'} eq '' )
    {
      
      # top
      if ( @{ $Macro->{'single-top'}[0] } )
      {
        foreach my $Line ( @{ $Macro->{'single-top'}[0] } )
        {
          # indent
          if
          (
            $Macro->{'noindent'}[0][0] eq ''
            or lc $Macro->{'noindent'}[0][0] eq 'no'
            or lc $Macro->{'noindent'}[0][0] eq 'false'
          )
          {
            $Out .= "\t" x $Level;
          }
          if
          (
            $Macro->{'nocontent'}[0][0] eq ''
            or lc $Macro->{'nocontent'}[0][0] eq 'no'
            or lc $Macro->{'nocontent'}[0][0] eq 'false'
          )
          {
            $Out .= "$Line";
          }
          $Out .= "\n";
        }
      }
      elsif ( @{ $Macro->{'top'}[0] } )
      {
        foreach my $Line ( @{ $Macro->{'top'}[0] } )
        {
          # indent
          if
          (
            $Macro->{'noindent'}[0][0] eq ''
            or lc $Macro->{'noindent'}[0][0] eq 'no'
            or lc $Macro->{'noindent'}[0][0] eq 'false'
          )
          {
            $Out .= "\t" x $Level;
          }
          if
          (
            $Macro->{'nocontent'}[0][0] eq ''
            or lc $Macro->{'nocontent'}[0][0] eq 'no'
            or lc $Macro->{'nocontent'}[0][0] eq 'false'
          )
          {
            $Out .= "$Line";
          }
          $Out .= "\n";
        }
      }
    
      my $Line = $Node->{'nodes'}[0]{'nodes'}[0];
      
      # tab
      if ( $Macro->{'single-tab'}[0][0] ne '' )
      {
        $Line =~ s/\t/$Macro->{'single-tab'}[0]/ge;
      }
      elsif ( $Macro->{'tab'}[0][0] ne '' )
      {
        $Line =~ s/\t/$Macro->{'tab'}[0][0]/ge;
      }
      
      # colon
      if ( $Macro->{'single-colon'}[0][0] ne '' )
      {
        if ( $Line !~ s/:/$Macro->{'single-colon'}[0][0]/e )
        {
          $Line = $Macro->{'single-colon'}[0][0] . $Line;
        }
      }
      elsif ( $Macro->{'colon'}[0][0] ne '' )
      {
        if ( $Line !~ s/:/$Macro->{'colon'}[0][0]/e )
        {
          $Line = $Macro->{'colon'}[0][0] . $Line;
        }
      }

      
      if ( $Line ne '' )
      {
      
        # indent
        if
        (
          $Macro->{'noindent'}[0][0] eq ''
          or lc $Macro->{'noindent'}[0][0] eq 'no'
          or lc $Macro->{'noindent'}[0][0] eq 'false'
        )
        {
          $Out .= "\t" x $Level;
          if
          (
            @{ $Macro->{'top'}[0] }
            or @{ $Macro->{'bottom'}[0] }
            or @{ $Macro->{'single-bottom'}[0] }
            or @{ $Macro->{'single-top'}[0] }
          )
          {
            $Out .= "\t";
          }
        }
        
        # left
        if ( $Macro->{'single-left'}[0][0] ne '' )
        {
          $Out .= $Macro->{'single-left'}[0][0];
        }
        elsif ( $Macro->{'left'}[0][0] ne '' )
        {
          $Out .= $Macro->{'left'}[0][0];
        }

        if
        (
          $Macro->{'nocontent'}[0][0] eq ''
          or lc $Macro->{'nocontent'}[0][0] eq 'no'
          or lc $Macro->{'nocontent'}[0][0] eq 'false'
        )
        {
          $Out .= "$Line";
        }
        
        # right
        if ( $Macro->{'single-right'}[0][0] ne '' )
        {
          $Out .= $Macro->{'single-right'}[0][0];
        }
        elsif ( $Macro->{'right'}[0][0] ne '' )
        {
          $Out .= $Macro->{'right'}[0][0];
        }

        $Out .= "\n";

      }
      
      # bottom
      if ( @{ $Macro->{'single-bottom'}[0] } )
      {
        foreach my $Line ( @{ $Macro->{'single-bottom'}[0] } )
        {
          # indent
          if
          (
            $Macro->{'noindent'}[0][0] eq ''
            or lc $Macro->{'noindent'}[0][0] eq 'no'
            or lc $Macro->{'noindent'}[0][0] eq 'false'
          )
          {
            $Out .= "\t" x $Level;
          }
          if
          (
            $Macro->{'nocontent'}[0][0] eq ''
            or lc $Macro->{'nocontent'}[0][0] eq 'no'
            or lc $Macro->{'nocontent'}[0][0] eq 'false'
          )
          {
            $Out .= "$Line";
          }
          $Out .= "\n";
        }
      }
      if ( @{ $Macro->{'bottom'}[0] } )
      {
        foreach my $Line ( @{ $Macro->{'bottom'}[0] } )
        {
          # indent
          if
          (
            $Macro->{'noindent'}[0][0] eq ''
            or lc $Macro->{'noindent'}[0][0] eq 'no'
            or lc $Macro->{'noindent'}[0][0] eq 'false'
          )
          {
            $Out .= "\t" x $Level;
          }
          if
          (
            $Macro->{'nocontent'}[0][0] eq ''
            or lc $Macro->{'nocontent'}[0][0] eq 'no'
            or lc $Macro->{'nocontent'}[0][0] eq 'false'
          )
          {
            $Out .= "$Line";
          }
          $Out .= "\n";
        }
      }
    
    }
    # if it's a single, blank section, use the multi-top and multi-bottom
    else
    {

      # top
      if ( @{ $Macro->{'multi-top'}[0] } )
      {
        foreach my $Line ( @{ $Macro->{'multi-top'}[0] } )
        {
          # indent
          if
          (
            $Macro->{'noindent'}[0][0] eq ''
            or lc $Macro->{'noindent'}[0][0] eq 'no'
            or lc $Macro->{'noindent'}[0][0] eq 'false'
          )
          {
            $Out .= "\t" x $Level;
          }
          if
          (
            $Macro->{'nocontent'}[0][0] eq ''
            or lc $Macro->{'nocontent'}[0][0] eq 'no'
            or lc $Macro->{'nocontent'}[0][0] eq 'false'
          )
          {
            $Out .= "$Line";
          }
          $Out .= "\n";
        }
      }
      elsif ( @{ $Macro->{'top'}[0] } )
      {
        foreach my $Line ( @{ $Macro->{'top'}[0] } )
        {
          # indent
          if
          (
            $Macro->{'noindent'}[0][0] eq ''
            or lc $Macro->{'noindent'}[0][0] eq 'no'
            or lc $Macro->{'noindent'}[0][0] eq 'false'
          )
          {
            $Out .= "\t" x $Level;
          }
          if
          (
            $Macro->{'nocontent'}[0][0] eq ''
            or lc $Macro->{'nocontent'}[0][0] eq 'no'
            or lc $Macro->{'nocontent'}[0][0] eq 'false'
          )
          {
            $Out .= "$Line";
          }
          $Out .= "\n";
        }
      }
    
      if
      (
        @{ $Macro->{'multi-top'}[0] }
        or @{ $Macro->{'top'}[0] }
        or @{ $Macro->{'multi-bottom'}[0] }
        or @{ $Macro->{'bottom'}[0] }
      )
      {
        $Out .= &Compile( $Node->{'nodes'}[0], $Node, $Level + 1);
      }
      else
      {
        $Out .= &Compile( $Node->{'nodes'}[0], $Node, $Level );
      }

      # bottom
      if ( @{ $Macro->{'multi-bottom'}[0] } )
      {
        foreach my $Line ( @{ $Macro->{'multi-bottom'}[0] } )
        {
          # indent
          if
          (
            $Macro->{'noindent'}[0][0] eq ''
            or lc $Macro->{'noindent'}[0][0] eq 'no'
            or lc $Macro->{'noindent'}[0][0] eq 'false'
          )
          {
            $Out .= "\t" x $Level;
          }
          if
          (
            $Macro->{'nocontent'}[0][0] eq ''
            or lc $Macro->{'nocontent'}[0][0] eq 'no'
            or lc $Macro->{'nocontent'}[0][0] eq 'false'
          )
          {
            $Out .= "$Line";
          }
          $Out .= "\n";
        }
      }
      elsif ( @{ $Macro->{'bottom'}[0] } )
      {
        foreach my $Line ( @{ $Macro->{'bottom'}[0] } )
        {
          # indent
          if
          (
            $Macro->{'noindent'}[0][0] eq ''
            or lc $Macro->{'noindent'}[0][0] eq 'no'
            or lc $Macro->{'noindent'}[0][0] eq 'false'
          )
          {
            $Out .= "\t" x $Level;
          }
          if
          (
            $Macro->{'nocontent'}[0][0] eq ''
            or lc $Macro->{'nocontent'}[0][0] eq 'no'
            or lc $Macro->{'nocontent'}[0][0] eq 'false'
          )
          {
            $Out .= "$Line";
          }
          $Out .= "\n";
        }
      }

    }
    
  }
  # if there are multiple or no nodes (multi)
  else
  {
  
    my $First = 1;

    # top
    if ( @{ $Macro->{'multi-top'}[0] } )
    {
      foreach my $Line ( @{ $Macro->{'multi-top'}[0] } )
      {
        # indent
        if
        (
          $Macro->{'noindent'}[0][0] eq ''
          or lc $Macro->{'noindent'}[0][0] eq 'no'
          or lc $Macro->{'noindent'}[0][0] eq 'false'
        )
        {
          $Out .= "\t" x $Level;
        }
        # content
        if
        (
          $Macro->{'nocontent'}[0][0] eq ''
          or lc $Macro->{'nocontent'}[0][0] eq 'no'
          or lc $Macro->{'nocontent'}[0][0] eq 'false'
        )
        {
          $Out .= "$Line";
        }
        $Out .= "\n";
      }
    }
    elsif ( @{ $Macro->{'top'}[0] } )
    {
      foreach my $Line ( @{ $Macro->{'top'}[0] } )
      {
        # indent
        if
        (
          $Macro->{'noindent'}[0][0] eq ''
          or lc $Macro->{'noindent'}[0][0] eq 'no'
          or lc $Macro->{'noindent'}[0][0] eq 'false'
        )
        {
          $Out .= "\t" x $Level;
        }
        # content
        if
        (
          $Macro->{'nocontent'}[0][0] eq ''
          or lc $Macro->{'nocontent'}[0][0] eq 'no'
          or lc $Macro->{'nocontent'}[0][0] eq 'false'
        )
        {
          $Out .= "$Line";
        }
        $Out .= "\n";
      }
    }
    
    my @Outs;

    foreach my $NodeSub ( @{ $Node->{'nodes'} } )
    {
    
      my $Out;

      if ( $NodeSub->{'mark'} eq '' )
      {
      
        my $Line = $NodeSub->{'nodes'}[0];
        $Line =~ s/^\s*//;
        $Line =~ s/\s*$//;
        
        # tab
        if ( $Macro->{'multi-first-tab'}[0][0] ne '' and $First  )
        {
          $Line =~ s/\t/$Macro->{'multi-first-tab'}[0][0]/ge;
        }
        elsif ( $Macro->{'multi-tab-first'}[0][0] ne '' and $First  )
        {
          $Line =~ s/\t/$Macro->{'multi-tab-first'}[0][0]/ge;
        }
        elsif ( $Macro->{'first-tab'}[0][0] ne '' and $First  )
        {
          $Line =~ s/\t/$Macro->{'first-tab'}[0][0]/ge;
        }
        elsif ( $Macro->{'multi-tab'}[0][0] ne '' )
        {
          $Line =~ s/\t/$Macro->{'multi-tab'}[0][0]/ge;
        }
        elsif ( $Macro->{'tab'}[0][0] ne '' )
        {
          $Line =~ s/\t/$Macro->{'tab'}[0][0]/ge;
        }
        
        # colon
        if ( $Macro->{'multi-first-colon'}[0][0] ne '' )
        {
          if ( $Line !~ s/:/$Macro->{'multi-first-colon'}[0][0]/e )
          {
            $Line = $Macro->{'multi-first-colon'}[0][0] . $Line;
          }
        }
        elsif ( $Macro->{'multi-colon-first'}[0][0] ne '' )
        {
          if ( $Line !~ s/:/$Macro->{'multi-colon-first'}[0][0]/e )
          {
            $Line = $Macro->{'multi-colon-first'}[0][0] . $Line;
          }
        }
        elsif ( $Macro->{'first-colon'}[0][0] ne '' )
        {
          if ( $Line !~ s/:/$Macro->{'first-colon'}[0][0]/e )
          {
            $Line = $Macro->{'first-colon'}[0][0] . $Line;
          }
        }
        elsif ( $Macro->{'multi-colon'}[0][0] ne '' )
        {
          if ( $Line !~ s/:/$Macro->{'multi-colon'}[0][0]/e )
          {
            $Line = $Macro->{'multi-colon'}[0][0] . $Line;
          }
        }
        elsif ( $Macro->{'colon'}[0][0] ne '' )
        {
          if ( $Line !~ s/:/$Macro->{'colon'}[0][0]/e )
          {
            $Line = $Macro->{'colon'}[0][0] . $Line;
          }
        }
        
        if ( $Line ne '' )
        {
        
          # indent
          if
          (
            $Macro->{'noindent'}[0][0] eq ''
            or lc $Macro->{'noindent'}[0][0] eq 'no'
            or lc $Macro->{'noindent'}[0][0] eq 'false'
          )
          {
            $Out .= "\t" x $Level;
            if
            (
              @{ $Macro->{'multi-top'}[0] }
              or @{ $Macro->{'top'}[0] }
              or @{ $Macro->{'multi-bottom'}[0] }
              or @{ $Macro->{'bottom'}[0] }
            )
            {
              $Out .= "\t";
            }
          }

          # left
          if ( $Macro->{'multi-first-left'}[0][0] ne '' and $First )
          {
            $Out .= $Macro->{'multi-first-left'}[0][0];
          }
          elsif ( $Macro->{'multi-left-first'}[0][0] ne '' and $First )
          {
            $Out .= $Macro->{'multi-left-first'}[0][0];
          }
          elsif ( $Macro->{'first-left'}[0][0] ne '' and $First  )
          {
            $Out .= $Macro->{'first-left'}[0][0];
          }
          elsif ( $Macro->{'multi-left'}[0][0] ne '' )
          {
            $Out .= $Macro->{'multi-left'}[0][0];
          }
          elsif ( $Macro->{'left'}[0][0] ne '' )
          {
            $Out .= $Macro->{'left'}[0][0];
          }
        
          # content
          if
          (
            $Macro->{'nocontent'}[0][0] eq ''
            or lc $Macro->{'nocontent'}[0][0] eq 'no'
            or lc $Macro->{'nocontent'}[0][0] eq 'false'
          )
          {
            $Out .= "$Line";
          }

          # right
          if ( $Macro->{'multi-first-right'}[0][0] ne '' and $First  )
          {
            $Out .= $Macro->{'multi-first-right'}[0][0];
          }
          elsif ( $Macro->{'multi-right-first'}[0][0] ne '' and $First  )
          {
            $Out .= $Macro->{'multi-right-first'}[0][0];
          }
          elsif ( $Macro->{'first-right'}[0][0] ne '' and $First  )
          {
            $Out .= $Macro->{'first-right'}[0][0];
          }
          elsif ( $Macro->{'multi-right'}[0][0] ne '' )
          {
            $Out .= $Macro->{'multi-right'}[0][0];
          }
          elsif ( $Macro->{'right'}[0][0] ne '' )
          {
            $Out .= $Macro->{'right'}[0][0];
          }

          $Out .= "\n";

          $First = 0;
          
        }
        
      }
      else
      {
      
        if
        (
          @{ $Macro->{'multi-top'}[0] }
          or @{ $Macro->{'top'}[0] }
          or @{ $Macro->{'multi-bottom'}[0] }
          or @{ $Macro->{'bottom'}[0] }
        )
        {
          $Out .= &Compile( $NodeSub, $Node, $Level + 1 );
        }
        else
        {
          $Out .= &Compile( $NodeSub, $Node, $Level );
        }
        
      }
      
      push @Outs, $Out;
      
    }
    
    # between
    if ( @{ $Macro->{'multi-between'}[0] } )
    {
      my $Between = join '', map
      {
        my $Out;
        # indent
        if
        (
          $Macro->{'noindent'}[0][0] eq ''
          or lc $Macro->{'noindent'}[0][0] eq 'no'
          or lc $Macro->{'noindent'}[0][0] eq 'false'
        )
        {
          $Out .= "\t" x $Level;
        }
        # content
        if
        (
          $Macro->{'nocontent'}[0][0] eq ''
          or lc $Macro->{'nocontent'}[0][0] eq 'no'
          or lc $Macro->{'nocontent'}[0][0] eq 'false'
        )
        {
          $Out .= "$_";
        }
        $Out .= "\n";
        $Out;
      } @{ $Macro->{'multi-between'}[0] };
      $Out .= join $Between, @Outs;
    }
    elsif ( @{ $Macro->{'between'}[0] } )
    {
      my $Between = join '', map
      {
        my $Out;
        # indent
        if
        (
          $Macro->{'noindent'}[0][0] eq ''
          or lc $Macro->{'noindent'}[0][0] eq 'no'
          or lc $Macro->{'noindent'}[0][0] eq 'false'
        )
        {
          $Out .= "\t" x $Level;
        }
        # content
        if
        (
          $Macro->{'nocontent'}[0][0] eq ''
          or lc $Macro->{'nocontent'}[0][0] eq 'no'
          or lc $Macro->{'nocontent'}[0][0] eq 'false'
        )
        {
          $Out .= "$_";
        }
        $Out .= "\n";
        $Out;
      } @{ $Macro->{'between'}[0] };
      $Out .= join $Between, @Outs;
    }
    else
    {
      $Out .= join '', @Outs;
    }

    # bottom
    if ( @{ $Macro->{'multi-bottom'}[0] } )
    {
      foreach my $Line ( @{ $Macro->{'multi-bottom'}[0] } )
      {
        # indent
        if
        (
          $Macro->{'noindent'}[0][0] eq ''
          or lc $Macro->{'noindent'}[0][0] eq 'no'
          or lc $Macro->{'noindent'}[0][0] eq 'false'
        )
        {
          $Out .= "\t" x $Level;
        }
        # content
        if
        (
          $Macro->{'nocontent'}[0][0] eq ''
          or lc $Macro->{'nocontent'}[0][0] eq 'no'
          or lc $Macro->{'nocontent'}[0][0] eq 'false'
        )
        {
          $Out .= "$Line";
        }
        $Out .= "\n";
      }
    }
    elsif ( @{ $Macro->{'bottom'}[0] } )
    {
      foreach my $Line ( @{ $Macro->{'bottom'}[0] } )
      {
        # indent
        if
        (
          $Macro->{'noindent'}[0][0] eq ''
          or lc $Macro->{'noindent'}[0][0] eq 'no'
          or lc $Macro->{'noindent'}[0][0] eq 'false'
        )
        {
          $Out .= "\t" x $Level;
        }
        # content
        if
        (
          $Macro->{'nocontent'}[0][0] eq ''
          or lc $Macro->{'nocontent'}[0][0] eq 'no'
          or lc $Macro->{'nocontent'}[0][0] eq 'false'
        )
        {
          $Out .= "$Line";
        }
        $Out .= "\n";
      }
    }
    
  }

  return $Out;
    
}

################################################################################

sub BuildVariable
{

  # adds plain lines to the definition
  # adds calls recursively for sub-definitions
  
  my $Hash = shift; # the hash that contains the definition (it's an array)
  my $Key = shift; # the key that refers to that definition
  my $Node = shift; # the node with nodes that need to be processed into the def
  
  # my $Array = $Hash->{"$Key"}; # the array is the actual object
    # being affecteded here.  it's just referenced so that we can
    # delete it from its parent hash

  if ( @{ $Node->{'nodes'} } )
  {
    # if there are nodes to read
  
    # create the appropriate sub values
    $Hash->{"$Key"}[0] = []; # for line definitions
    $Hash->{"$Key"}[1] = {} if not defined $Hash->{"$Key"}[1]; # for nested definitions
    
    foreach my $NodeSub ( @{ $Node->{'nodes'} } )
    {
    
      # if it's a line to add to the definition
      if ( $NodeSub->{'mark'} eq '' )
      {
        push @{ $Hash->{"$Key"}[0] }, $NodeSub->{'nodes'}[0];
      }
      # if it's a sub-definition
      else
      {
        &BuildVariable( $Hash->{"$Key"}[1], $NodeSub->{'mark'}, $NodeSub );
      }
      
    }

  }
  else
  {
    #  if there are no nodes, delete any previously existing value
    delete $Hash->{"$Key"};
  }

}

################################################################################

sub BuildList
{

  my $Node = shift;
  my $Parent = shift;
  my $Level = shift;
  my $Top = shift;
  my $Bottom = shift;

  &ClearBlankNodes( $Node );
    
  my $Out;
  $Out .= "\n";

  $Out .= "\t" x $Level;
  $Out .= "$Top";
  $Out .= "\n";

  foreach my $NodeSub ( @{ $Node->{'nodes'} } )
  {

    if ( $NodeSub->{'mark'} eq '' )
    {

      my $line = $NodeSub->{'nodes'}[0];
      $line =~ s/^\s*//;
      $line =~ s/\s*$//;

      if ( $line ne '' )
      {
        $Out .= "\t" x ( $Level + 1 );
        $Out .= "<li>$line</li>";
        $Out .= "\n";
      }
      else
      {
        $Out .= "\n";
      }

    }
    else
    {
      $Out .= &Compile( $NodeSub, $Node, $Level + 1 );
    }
    
  }

  $Out .= "\t" x $Level;
  $Out .= "$Bottom";
  $Out .= "\n";

}

################################################################################

sub BuildListLink
{

  my $Node = shift;
  my $Parent = shift;
  my $Level = shift;
  my $Top = shift;
  my $Bottom = shift;

  &ClearBlankNodes( $Node );
    
  my $Out;
  $Out .= "\n";

  $Out .= "\t" x $Level;
  $Out .= "$Top";
  $Out .= "\n";

  foreach my $NodeSub ( @{ $Node->{'nodes'} } )
  {

    if ( $NodeSub->{'mark'} eq '' )
    {

      my $line = $NodeSub->{'nodes'}[0];
      $line =~ s/^\s*//;
      $line =~ s/\s*$//;
      
      ( my $link, my $title ) = split "\t", $line;
      $title = $link if $title eq '';
      $link =~ s/ /%20/g;
      $link =~ s/\~\//<swl root>\//; # grok

      if ( $line ne '' )
      {
        $Out .= "\t" x ( $Level + 1 );
        $Out .= qq(<li><a href="$link">$title</a></li>);
        $Out .= "\n";
      }
      else
      {
        $Out .= "\n";
      }

    }
    else
    {
      $Out .= &Compile( $NodeSub, $Node, $Level + 1 );
    }
    
  }

  $Out .= "\t" x $Level;
  $Out .= "$Bottom";
  $Out .= "\n";

}

################################################################################

sub BuildHeading
{

  my $Node = shift;
  my $Parent = shift;
  my $Level = shift;
  my $Heading = shift;

  &ClearBlankNodes( $Node );
    
  my $Out;
  $Out .= "\n";
  $Out .= "\n";

  my @NodeSubs = @{ $Node->{'nodes'} };

  if ( @NodeSubs )
  {

    my $Line = $Node->{'nodes'}[0]{'nodes'}[0];
    $Line =~ s/^\s*//;
    $Line =~ s/\s*$//;
    
    $Out .= "\t" x $Level;
    $Out .= "<h$Heading>";
    $Out .= "\n";
    
    $Out .= "\t" x ( $Level + 1 );
    $Out .= "$Line";
    $Out .= "\n";
    
    shift @NodeSubs;
    foreach my $NodeSub ( @NodeSubs )
    {
    
      if ( $NodeSub->{'mark'} eq '' )
      {

        my $Line = $NodeSub->{'nodes'}[0];
        $Line =~ s/^\s*//;
        $Line =~ s/\s*$//;

        $Out .= "\t" x ( $Level + 1 );
        $Out .= "<br>$Line\n";
      }
      
    }

    $Out .= "\t" x $Level;
    $Out .= "</h$Heading>";

  }
  else
  {

    my $Line = $Node->{'nodes'}[0];
    $Line =~ s/^\s*//;
    $Line =~ s/\s*$//;

    if ( $Node->{'mark'} eq '' )
    {
      $Out .= "\t" x $Level;
      $Out .= "<h$Heading>$Line</h$Heading>";
    }

  }

  $Out .= "\n";

  return $Out;
  
}

################################################################################

sub BuildCommentList
{

  my $Node = shift;
  my $Parent = shift;
  my $Level = shift;
  my $Method = shift;

  &ClearBlankNodes( $Node );
    
  my $Out;

  my $Number = $Method;

  foreach my $NodeSub ( @{ $Node->{'nodes'} } )
  {

    if ( $NodeSub->{'mark'} eq '' )
    {

      my $Line = $NodeSub->{'nodes'}[0];
      $Line =~ s/^\s*//;
      $Line =~ s/\s*$//;

      $Out .= "\t" x $Level;
      $Out .= $Number++;
      $Out .= ".)\t";
      $Out .= "$Line";
      $Out .= "\n";

    }

  }

  return $Out;

}

################################################################################
################################################################################
#
# BUILDS
#  %Builds contains the default definitions for all high level 'tags',
# associating them with appropriate function references.

%SWL::Builds =
(

################################################################################

  '@' => sub
  {
  
    my $Node = shift;
    my $Parent = shift;
    my $Level = shift;
    
    foreach my $NodeSub ( @{ $Node->{'nodes'} } )
    {
      if ( $NodeSub->{'mark'} ne '' )
      {
        $Parent->{'vars'} = {} if not exists $Parent->{'vars'};
        &BuildVariable( $Parent->{'vars'}, $NodeSub->{'mark'}, $NodeSub );
      }
    }
    
  },
  
################################################################################

  '\^' => sub
  {
  
    my $Node = shift;
    my $Parent = shift;
    my $Level = shift;
    
    foreach my $NodeSub ( @{ $Node->{'nodes'} } )
    {
      if ( $NodeSub->{'mark'} ne '' )
      {
        $Parent->{'vars'}{'^'}[1] = {} if not defined $Parent->{'vars'}{'^'}[1];
        &BuildVariable( $Parent->{'vars'}{'^'}[1], $NodeSub->{'mark'}, $NodeSub );
      }
    }
    
  },
  
################################################################################

  '=' => sub
  {
  
    my $Node = shift;
    my $Parent = shift;
    my $Level = shift;
    
    foreach my $NodeSub ( @{ $Node->{'nodes'} } )
    {
      if ( $NodeSub->{'mark'} ne '' )
      {
        $Parent->{'vars'}{'='}[1] = {} if not defined $Parent->{'vars'}{'='}[1];
        &BuildVariable( $Parent->{'vars'}{'='}[1], $NodeSub->{'mark'}, $NodeSub );
      }
    }
    
  },
  
################################################################################

  ':' => sub
  {

    my $Node = shift;
    my $Parent = shift;
    my $Level = shift;
    my $Out;
    $Out .= "\n";

    foreach my $NodeSub ( @{ $Node->{'nodes'} } )
    {

      if ( $NodeSub->{'mark'} eq '' )
      {
        $Out .= "$NodeSub->{'nodes'}[0]\n";
      }
      else
      {
        $Out .= &Compile( $NodeSub, $Node, $Level + 1 );
      }

    }

    return $Out;

  },

################################################################################

  '-' => sub
  {

    my $Node = shift;
    my $Parent = shift;
    my $Level = shift;
    my $Out;
    $Out .= "\n";
    $Out .= "\n";

    $Out .= "\t" x $Level;
    if ( $Node->{'vars'}{'hr'}[1]{'clear'}[0][0] )
    {
      $Node->{'vars'}{'hr'}[1]{'clear'}[0][0] = 0;
      $Out .= "<br clear=all>";
      $Out .= "\n";
    }
    $Out .= "<hr>";
    $Out .= "\n";

    return $Out;

  },

################################################################################

  'p' => sub
  {

    my $Node = shift;
    my $Parent = shift;
    my $Level = shift;
    my $Out;

    &ClearBlankNodes( $Node );
    
    foreach my $NodeSub ( @{ $Node->{'nodes'} } )
    {

      if ( $NodeSub->{'mark'} eq '' )
      {
        my $line = $NodeSub->{'nodes'}[0];
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;
        if ( $line ne '' )
        {
          $Out .= "\t" x $Level;
          $Out .= "<p>$line</p>";
          $Out .= "\n";
        }
      }
      else
      {
        $Out .= &Compile( $NodeSub, $Node, $Level );
      }
    }

    return $Out;

  },

################################################################################

  'P' => sub
  {

    my $Node = shift;
    my $Parent = shift;
    my $Level = shift;
    my $Out;

    my $DoBr;

    if ( @{ $Node->{'nodes'} } == 1 )
    {
      if ( $Node->{'nodes'}[0]{'mark'} eq '' )
      {
        my $line = $Node->{'nodes'}[0]{'nodes'}[0];
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;
        if ( $line ne '' )
        {
          $Out .= "\t" x $Level;
          $Out .= "<p>$line</p>";
          $Out .= "\n";
        }
      }
      else
      {
        $Out .= &Compile( $Node->{'nodes'}[0], $Node, $Level + 1 );
      }
    }
    else
    {

      $Out .= "\t" x $Level;
      $Out .= '<p>';
      $Out .= "\n";

      foreach my $NodeSub ( @{ $Node->{'nodes'} } )
      {

        if ( $NodeSub->{'mark'} eq '' )
        {
          my $line = $NodeSub->{'nodes'}[0];
          $line =~ s/^\s*//;
          $line =~ s/\s*$//;
          if ( $line ne '' )
          {
            $Out .= "\t" x ( $Level + 1 );
            $Out .= '<br>' if $DoBr;
            $Out .= "$line";
            $Out .= "\n";
            $DoBr = 1;
          }
        }
        else
        {
          $Out .= &Compile( $NodeSub, $Node, $Level + 2 );
        }
      }

      $Out .= "\t" x $Level;
      $Out .= '</p>';
      $Out .= "\n";

    }

    return $Out;

  },

################################################################################

  'j' => sub
  {

    my $Node = shift;
    my $Parent = shift;
    my $Level = shift;
    my $Out;
    $Out .= "\n";

    &ClearBlankNodes( $Node );
    
    foreach my $NodeSub ( @{ $Node->{'nodes'} } )
    {

      if ( $NodeSub->{'mark'} eq '' )
      {
      
        my $line = $NodeSub->{'nodes'}[0];
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;
        $line = qq("$line") if $line =~ /\s/; # enclose in quotes if contains spaces
        
        $Out .= "\t" x $Level;
        $Out .= "<a name=$line></a>";
        $Out .= "\n";
        
      }
      else
      {
        $Out .= &Compile( $NodeSub, $Node, $Level );
      }
    }

    return $Out;

  },

################################################################################

  '\*' => sub
  {
    return BuildList( shift, shift, shift, '<ul>', '</ul>' );
  },

################################################################################

  '#' => sub
  {
    return BuildList( shift, shift, shift, '<ol type=1>', '</ol>' );
  },

################################################################################

  'a' => sub
  {
    return BuildList( shift, shift, shift, '<ol type=a>', '</ol>' );
  },

################################################################################

  'A' => sub
  {
    return BuildList( shift, shift, shift, '<ol type=A>', '</ol>' );
  },

################################################################################

  'i' => sub
  {
    return BuildList( shift, shift, shift, '<ol type=i>', '</ol>' );
  },

################################################################################

  'I' => sub
  {
    return BuildList( shift, shift, shift, '<ol type=I>', '</ol>' );
  },

################################################################################

  'l' => sub
  {
    return BuildListLink( shift, shift, shift, '<ul>', '</ul>' );
  },

################################################################################

  '\*l' => sub
  {
    return BuildListLink( shift, shift, shift, '<ul>', '</ul>' );
  },

################################################################################

  '#l' => sub
  {
    return BuildListLink( shift, shift, shift, '<ol type=1>', '</ol>' );
  },

################################################################################

  'al' => sub
  {
    return BuildListLink( shift, shift, shift, '<ol type=a>', '</ol>' );
  },

################################################################################

  'Al' => sub
  {
    return BuildListLink( shift, shift, shift, '<ol type=A>', '</ol>' );
  },

################################################################################

  'il' => sub
  {
    return BuildListLink( shift, shift, shift, '<ol type=i>', '</ol>' );
  },

################################################################################

  'Il' => sub
  {
    return BuildListLink( shift, shift, shift, '<ol type=I>', '</ol>' );
  },

################################################################################

  '1' => sub
  {
    return BuildHeading( shift, shift, shift, 1 );
  },
  
################################################################################

  '2' => sub
  {
    return BuildHeading( shift, shift, shift, 2 );
  },
  
################################################################################

  '3' => sub
  {
    return BuildHeading( shift, shift, shift, 3 );
  },
  
################################################################################

  '4' => sub
  {
    return BuildHeading( shift, shift, shift, 4 );
  },
  
################################################################################

  '5' => sub
  {
    return BuildHeading( shift, shift, shift, 5 );
  },
  
################################################################################

  '6' => sub
  {
    return BuildHeading( shift, shift, shift, 6 );
  },
  
################################################################################

  't' => sub
  {

    my $Node = shift;
    my $Parent = shift;
    my $Level = shift;
    
    my $Table; # ->[ X ][ Y ][ Z: line number ] = Cell
    my $Y = 0;
    my $X = 0;
    
    &ClearBlankNodes( $Node );
    foreach my $NodeSub ( @{ $Node->{'nodes'} } )
    {

      # if it's just a line of text, interpret it as a row of cells, tab delimited
      if ( $NodeSub->{'mark'} eq '' )
      {
      
        my @Cells = split "\t", $NodeSub->{'nodes'}[0];
        
        foreach my $Cell ( @Cells )
        {
        
          $Cell = '&nbsp;' if $Cell eq '.';
          $Cell = ( "\t" x ( $Level + 3 ) ) . $Cell . "\n";
          $Table->[ $X ][ $Y ][ 0 ] = $Cell;
          
          #Tab
          $Y++;
        }
        
        # CRLF :-)
        $Y = 0;
        $X++;
        
      }
      # if it's tagged 'h', interpret it as a row of header cells, tab delimited
      elsif ( $NodeSub->{'mark'} eq 'h' )
      {
        &ClearBlankNodes( $NodeSub );
        foreach my $NodeSubSub ( @{ $NodeSub->{'nodes'} } )
        {
          my @Cells = split "\t", $NodeSubSub->{'nodes'}[0];
          foreach my $Cell ( @Cells )
          {

            $Cell = '&nbsp;' if $Cell eq '.';
            $Cell = ( "\t" x ( $Level + 3 ) ) . $Cell . "\n";
            $Table->[ $X ][ $Y ][ 0 ] = $Cell;
            bless $Table->[ $X ][ $Y ], 'header';
            #Tab
            $Y++;
          }
          # CRLF :-)
          $Y = 0;
          $X++;
        }
      }
      # if it's a row tag, interpret each line as a normal cell
      elsif ( $NodeSub->{'mark'} eq 'r' )
      {
        &ClearBlankNodes( $NodeSub );
        foreach my $NodeSubSub ( @{ $NodeSub->{'nodes'} } )
        {
          # if it's unmarked, make the line a normal cell
          if ( $NodeSubSub->{'mark'} eq '' )
          {
            my $Cell = $NodeSubSub->{'nodes'}[0];
            $Cell = '&nbsp;' if $Cell eq '.';
            $Cell = ( "\t" x ( $Level + 3 ) ) . $Cell . "\n";
            $Table->[ $X ][ $Y ][ 0 ] = $Cell;
            $Y++;
          }
          # if it's marked 'h', make columns of header cells
          elsif ( $NodeSubSub->{'mark'} eq 'h' )
          {
            &ClearBlankNodes( $NodeSubSub );
            foreach my $NodeSubSubSub ( @{ $NodeSubSub->{'nodes'} } )
            {
              my $Cell = $NodeSubSubSub->{'nodes'}[0];
              $Cell = '&nbsp;' if $Cell eq '.';
              $Cell = ( "\t" x ( $Level + 3 ) ) . $Cell . "\n";
              $Table->[ $X ][ $Y ][ 0 ] = $Cell;
              bless $Table->[ $X ][ $Y ], 'header';
              $Y++;
            }
          }
          # if it's a cell tag, interpret each line as a line of the cell,
          #  <br> delimited
          elsif ( $NodeSubSub->{'mark'} eq 'c' )
          {
            &ClearBlankNodes( $NodeSubSub );
            foreach my $NodeSubSubSub ( @{ $NodeSubSub->{'nodes'} } )
            {
              my $Cell = $NodeSubSubSub->{'nodes'}[0];
              $Cell = '&nbsp;' if $Cell eq '.';
              $Cell = ( "\t" x ( $Level + 3 ) ) . $Cell . "\n";
              push @{ $Table->[ $X ][ $Y ] }, $Cell;
            }
            $Y++;
          }
          # if it's a header cell tag, interpret each line as a line of
          #  the header cell, <br> delimited
          elsif ( $NodeSubSub->{'mark'} eq 'ch' )
          {
            &ClearBlankNodes( $NodeSubSub );
            foreach my $NodeSubSubSub ( @{ $NodeSubSub->{'nodes'} } )
            {
              my $Cell = $NodeSubSubSub->{'nodes'}[0];
              $Cell = '&nbsp;' if $Cell eq '.';
              $Cell = ( "\t" x ( $Level + 3 ) ) . $Cell . "\n";
              push @{ $Table->[ $X ][ $Y ] }, $Cell;
            }
            bless $Table->[ $X ][ $Y ], 'header'; # note to make it a <th> cell
            $Y++;
          }
          else
          {
            my $Cell = &Compile( $NodeSubSub, $NodeSub, $Level + 3 );
            if ( $Cell )
            {
              $Table->[ $X ][ $Y ][ 0 ] = $Cell;
              $Y++;
            }
          }
          
        }
        
        # CRLF
        $Y = 0;
        $X++;
        
      }
      # if it's a header row, interpret each line as a header cell
      elsif ( $NodeSub->{'mark'} eq 'rh' )
      {

        &ClearBlankNodes( $NodeSub );
        foreach my $NodeSubSub ( @{ $NodeSub->{'nodes'} } )
        {
        
          # if it's unmarked, make the line a header cell
          if ( $NodeSubSub->{'mark'} eq '' )
          {
            my $Cell = $NodeSubSub->{'nodes'}[0];
            $Cell = '&nbsp;' if $Cell eq '.';
            $Cell = ( "\t" x ( $Level + 3 ) ) . $Cell . "\n";
            $Table->[ $X ][ $Y ][ 0 ] = $Cell;
            bless $Table->[ $X ][ $Y ], 'header'; # note to make it a <th> cell
            $Y++;
          }
          # if it's a cell tag, interpret each line as a line of the cell,
          #  <br> delimited
          elsif ( $NodeSubSub->{'mark'} eq 'c' )
          {
            &ClearBlankNodes( $NodeSubSub );
            foreach my $NodeSubSubSub ( @{ $NodeSubSub->{'nodes'} } )
            {
              my $Cell = $NodeSubSubSub->{'nodes'}[0];
              $Cell = '&nbsp;' if $Cell eq '.';
              $Cell = ( "\t" x ( $Level + 3 ) ) . $Cell . "\n";
              push @{ $Table->[ $X ][ $Y ] }, $Cell;
            }
            $Y++;
          }
          # if it's a header cell tag, interpret each line as a line of
          #  the header cell, <br> delimited
          elsif ( $NodeSubSub->{'mark'} eq 'ch' )
          {
            &ClearBlankNodes( $NodeSubSub );
            foreach my $NodeSubSubSub ( @{ $NodeSubSub->{'nodes'} } )
            {
              my $Cell = $NodeSubSubSub->{'nodes'}[0];
              $Cell = '&nbsp;' if $Cell eq '.';
              $Cell = ( "\t" x ( $Level + 3 ) ) . $Cell . "\n";
              push @{ $Table->[ $X ][ $Y ] }, $Cell;
            }
            bless $Table->[ $X ][ $Y ], 'header'; # note to make it a <th> cell
            $Y++;
          }
          else
          {
            my $Cell = &Compile( $NodeSubSub, $NodeSub, $Level + 3 );
            if ( $Cell )
            {
              $Table->[ $X ][ $Y ][ 0 ] = $Cell;
              bless $Table->[ $X ][ $Y ], 'header';
              $Y++;
            }
          }
          
        }

        # CRLF
        $Y = 0;
        $X++;
        
      }
      else
      {

        my $Cell = &Compile( $NodeSub, $Node, $Level + 3 );
        if ( $Cell )
        {
          $Table->[ $X ][ $Y ][ 0 ] = "$Cell";
          # CRLF
          $Y = 0;
          $X++;
        }
        
        
      }

    }
    
    # find the number of columns the table will have
    my $YMax;
    foreach my $Row ( @$Table )
    {
      $YMax = $#$Row if $#$Row > $YMax;
    }
    
    # Write the Table
    my $Out;
    $Out .= "\n";
    
    my $PropertyTable = Property( $Node, ['table'] );    
		my $PropertyTd = Property( $Node, ['td'], ['cell'], ['table', 'td'], ['table', 'cell'], );
		my $PropertyTh = Property( $Node, ['th'], ['cellh'], ['table', 'th'], ['table', 'cellh'], );

    $Out .= "\t" x ( $Level );
    $Out .= "<p><table$PropertyTable>\n";

    my $RowEven = 1;
    foreach my $Row ( @$Table )
    {
      $RowEven = not $RowEven;

      # find the properties of the table rows
      my $Tempz = $Node->{'vars'}{'tr'}[1];
      my %Pairz;
      foreach my $Key ( sort keys %$Tempz )
      {
        if ( $Tempz->{$Key}[0][0] ne '' )
        {
          $Pairz{$Key} = $Tempz->{$Key}[0][0];
        }
      }
      # override properties with the odd/evens
      my $Tempz = $Node->{'vars'}{ $RowEven? 'treven' :'trodd' }[1];
      foreach my $Key ( sort keys %$Tempz )
      {
        if ( $Tempz->{$Key}[0][0] ne '' )
        {
          $Pairz{$Key} = $Tempz->{$Key}[0][0];
        }
      }
      my $PropertyTr = join '', map " $_=$Pairz{$_}", keys %Pairz;
      
      $Out .= "\t" x ( $Level + 1 );
      $Out .= "<tr$PropertyTr>\n";

      my $Y = 0;
      while ( $Y <= $YMax )
      {
        my $Cell = $Row->[ $Y ];
        $Y++;
        
        # determine how many columns the cell will go accross
        # (depends on how many are empty afterward)
        my $Colspan = 1;
        my $PropertyColspan;
        while
        (
          $Y <= $YMax + 1
          and
          (
            $Row->[ $Y ] eq ''
            or $Row->[ $Y ][ 0 ] =~ /^\s*$/
          )
        )
        {
          $Colspan++;
          $Y++;
        }
        $PropertyColspan = " colspan=$Colspan" if $Colspan > 1;

        # write out the cell's tag
        $Out .= "\t" x ( $Level + 2 );
        if ( $Cell =~ '^header=' )
        {
          $Out .= "<th$PropertyTh$PropertyColspan>\n";
        }
        else
        {
          $Out .= "<td$PropertyTd$PropertyColspan>\n";
        }
      
        # do the first line
        my $Line = shift @$Cell;
        $Out .= "$Line";
        
        # do the remaining lines
        foreach my $Line ( @$Cell )
        {
          $Out .= "<br>$Line";
        }
        
        # write the end tag for the cell
        $Out .= "\t" x ( $Level + 2 );
        if ( $Cell =~ '^header=' )
        {
          $Out .= "</th>\n";
        }
        else
        {
          $Out .= "</td>\n";
        }
        
      }
      # end the row
      $Out .= "\t" x ( $Level + 1 );
      $Out .= "</tr>\n";
    }
    # end the table
    $Out .= "\t" x ( $Level );
    $Out .= "</table></p>\n";

    return $Out;

  },

################################################################################

  'C' => sub
  {
  
    my $Node = shift;
    my $Parent = shift;
    my $Level = shift;
    
    &ClearBlankNodes( $Node );

		my %Dates = CalendarAnalyze( $Node );

    # set default date (current) if there is no other
    my $Year =  substr localtime, 20, 4;
    my $Month = $SWL::CalendarMonthNumberFromShort{ substr localtime, 4, 3 };
    my $Day = substr localtime, 9, 2;
    $Day =~ s/\s//g;
    %Dates = ( $Year => { $Month => { $Day => [], }, }, ) if %Dates == 0;

    my $PropertyTable = Property( $Node, ['table'], ['calendar', 'table'], );

    my @RowCommons = (
		  ['tr'],
			['row'],
			['table', 'tr'],
			['table', 'row'],
			['calendar', 'tr'],
			['calendar', 'row'],
			['calendar', 'table', 'tr'],
			['calendar', 'table', 'row'],
		);
		my $PropertyMonthRow = Property( $Node, @RowCommons, ['calendar', 'month', 'tr'], ['calendar', 'month', 'row'], );
		my $PropertyDayRow = Property( $Node, @RowCommons, );
		my $PropertyDateRow = Property( $Node, @RowCommons, );
		my $PropertyRow = Property( $Node, @RowCommons, );

    my @CellhCommons = (
		  ['td'],
			['cellh'],
			['table', 'td'],
			['table', 'cellh'],
			['calendar', 'td'],
			['calendar', 'cellh'],
			['calendar', 'table', 'td'],
			['calendar', 'table', 'cellh'],
		);
		my $PropertyMonthCell = Property( $Node, @CellhCommons, ['calendar', 'month'], {'colspan' => 7}, );
		my $PropertyDayCell = Property( $Node, {'width' => '14%'}, @CellhCommons, ['calendar', 'day'], );

    my @CellCommons = (
		  ['td'],
			['cell'],
			['table', 'td'],
			['table', 'cell'],
			['calendar', 'td'],
			['calendar', 'cell'],
			['calendar', 'table', 'td'],
			['calendar', 'table', 'cell'],
		);
		my $PropertyDateCell = Property( $Node, @CellCommons, ['calendar', 'date'], );
		my $PropertyEventCell = Property( $Node, @CellCommons, ['calendar', 'date'], ['calendar', 'event'], );
		my $PropertyCell = Property( $Node, @CellCommons, );
    
    my $Out;
    # table
    $Out .= "\t" x ( $Level );
    $Out .= "<p><table$PropertyTable>\n";
        
    foreach my $Year ( sort { $a <=> $b }  keys %Dates )
    {
      foreach my $Month ( sort { $a <=> $b } keys %{$Dates{$Year}} )
      {
      
        # month
        $Out .= "\t" x ( $Level + 1 );
        $Out .= "<tr$PropertyMonthRow><th$PropertyMonthCell>";
        $Out .= $SWL::CalendarMonthName{$Month} . ' ' . $Year;
        $Out .= "</th></tr>\n";
        
        # days
        $Out .= "\t" x ( $Level + 1 );
        $Out .= join "",
        (
          "<tr$PropertyDayRow>",
          (
            map
            {
              "<th$PropertyDayCell>$_</th>";
            } qw ( Sun Mon Tue Wed Thu Fri Sat )
          ),
          "</tr>\n",
        );

        # dates
        my @Dates = 
        (
          ( map { ''; } 1..&CalendarMonthSeed($Year, $Month) ),
          (
            map
            {
            
              if ( exists $Dates{$Year}{$Month}{$_} )
              {
	              (
                  join '', 
                    "<td$PropertyEventCell>",
	      	          (
		                  join "<br>", 
		                    "<b>$_</b>",
		                    @{$Dates{$Year}{$Month}{$_}}	
		                ),
		                "</td>"
		            );
              }
              else
              {
                "<td$PropertyDateCell>$_</td>";
              }
              
            } 1..&CalendarMonthCount($Year, $Month)
          ),
        );
        
        # date rows
        while ( @Dates )
        {
        
          $Out .= "\t" x ( $Level + 1 );
          $Out .= "<tr$PropertyDateRow>\n";
          
          foreach my $Cell ( @Dates[0..6] )
          {
          
            if ( $Cell eq '' )
            {
              $Out .= "\t" x ( $Level + 2 );
              $Out .= "<td$PropertyDateCell>&nbsp;</td>\n";
            }
            else
            {
              $Out .= "\t" x ( $Level + 2 );
              $Out .= "$Cell\n";
            }
            
          }
          
          $Out .= "\t" x ( $Level + 1 );
          $Out .= "</tr>\n";
          
          @Dates = @Dates[7..$#Dates];
          
        }
        
      }
    }
    
    # end of table
    $Out .= "</table></p>\n";

    return $Out;
    
  },

################################################################################

	# todo factor c and C

  'c' => sub
  {

    my $Node = shift;
    my $Parent = shift;
    my $Level = shift;
    
    &ClearBlankNodes( $Node );

		my %Dates = CalendarAnalyze( $Node );

    # set default date (current) if there is no other
    my $Year =  substr localtime, 20, 4;
    my $Month = $SWL::CalendarMonthNumberFromShort{ substr localtime, 4, 3 };
    my $Day = substr localtime, 9, 2;
    $Day =~ s/\s//g;
    %Dates = ( $Year => { $Month => { $Day => [], }, }, ) if %Dates == 0;

    my $PropertyTable = Property( $Node, ['table'], ['calendar', 'table'], );

    my @RowCommons = (
		  ['tr'],
			['row'],
			['table', 'tr'],
			['table', 'row'],
			['calendar', 'tr'],
			['calendar', 'row'],
			['calendar', 'table', 'tr'],
			['calendar', 'table', 'row'],
		);
		my $PropertyMonthRow = Property( $Node, @RowCommons, ['calendar', 'month', 'tr'], ['calendar', 'month', 'row'], );
		my $PropertyDayRow = Property( $Node, @RowCommons, );
		my $PropertyDateRow = Property( $Node, @RowCommons, );
		my $PropertyRow = Property( $Node, @RowCommons, );

    my @CellhCommons = (
		  ['td'],
			['cellh'],
			['table', 'td'],
			['table', 'cellh'],
			['calendar', 'td'],
			['calendar', 'cellh'],
			['calendar', 'table', 'td'],
			['calendar', 'table', 'cellh'],
		);
		my $PropertyMonthCell = Property( $Node, @CellhCommons, ['calendar', 'month'], {'colspan' => 7}, );
		my $PropertyDayCell = Property( $Node, {'width' => '14%'}, @CellhCommons, ['calendar', 'day'], );

    my @CellCommons = (
		  ['td'],
			['cell'],
			['table', 'td'],
			['table', 'cell'],
			['calendar', 'td'],
			['calendar', 'cell'],
			['calendar', 'table', 'td'],
			['calendar', 'table', 'cell'],
		);
		my $PropertyDateCell = Property( $Node, @CellCommons, ['calendar', 'date'], );
		my $PropertyEventCell = Property( $Node, @CellCommons, ['calendar', 'date'], ['calendar', 'event'], );
		my $PropertyCell = Property( $Node, @CellCommons, );
    
    my $Out;
    # table
    $Out .= "\t" x ( $Level );
    $Out .= "<p><table$PropertyTable>\n";
        
    foreach my $Year ( sort { $a <=> $b }  keys %Dates )
    {
      foreach my $Month ( sort { $a <=> $b } keys %{$Dates{$Year}} )
      {
      
        # month heading
        $Out .= "\t" x ( $Level + 1 );
        $Out .= "<tr$PropertyMonthRow><th$PropertyMonthCell>";
        $Out .= $SWL::CalendarMonthName{$Month} . ' ' . $Year;
        $Out .= "</th></tr>\n";
        
        # create dates
        my @Dates = 
        (
          ( map { ''; } 1..&CalendarMonthSeed($Year, $Month) ),
          (
            map
            {
            
              if ( exists $Dates{$Year}{$Month}{$_} )
              {
                "<td$PropertyEventCell><b>$_</b></td>";
              }
              else
              {
                "<td$PropertyDateCell>$_</td>";
              }
              
            } 1..&CalendarMonthCount($Year, $Month)
          ),
        );
        
        # first row
        $Out .= "\t" x ( $Level + 1 );
        $Out .= join "",
        (
          "<tr$PropertyDayRow>",
          (
            map
            {
              "<th$PropertyDayCell>$_</th>";
            } qw ( Sun Mon Tue Wed Thu Fri Sat )
          ),
          "</tr>",
        );
        
        # date rows
        while ( @Dates )
        {
        
          $Out .= "\t" x ( $Level + 1 );
          $Out .= "<tr$PropertyDateRow>\n";
          
          foreach my $Cell ( @Dates[0..6] )
          {
          
            if ( $Cell eq '' )
            {
              $Out .= "\t" x ( $Level + 2 );
              $Out .= "<td$PropertyDateCell>&nbsp;</td>\n";
            }
            else
            {
              $Out .= "\t" x ( $Level + 2 );
              $Out .= "$Cell\n";
            }
            
          }
          
          $Out .= "\t" x ( $Level + 1 );
          $Out .= "</tr>\n";
          
          @Dates = @Dates[7..$#Dates];
          
        }
        
        # event descriptions
        foreach my $Date ( sort { $a <=> $b } keys %{$Dates{$Year}{$Month}} )
        {
          
          foreach my $Event ( @{$Dates{$Year}{$Month}{$Date}} )
          {
          
            if ( $Event ne '' )
            {

              $Out .= "\t" x ( $Level + 1 );
              $Out .= "<tr$PropertyDateRow>\n";

              $Out .= "\t" x ( $Level + 2 );
              $Out .= "<th$PropertyEventCell><b>$Date</b></th><td$PropertyEventCell colspan=6>\n";

              $Out .= "\t" x ( $Level + 3 );
              $Out .= "$Event\n";

              $Out .= "\t" x ( $Level + 2 );
              $Out .= "</td>\n";

              $Out .= "\t" x ( $Level + 1 );
              $Out .= "</tr>\n";
              
            }
            
          }

        }
        
      }
    }
    
    # end of table
    $Out .= "</table></p>\n";

    return $Out;
    
  },

################################################################################

  'o' => sub
  {

    my $Node = shift;
    my $Parent = shift;
    my $LevelBase = shift;
    
    &ClearBlankNodes( $Node );
    
    my @ListHeadings = ( 'I', 'A', '1', 'i', 'a', );
    
    my $Out;
    $Out .= "\n";
    
    my $Level = 0;
    
    foreach my $NodeSub ( @{ $Node->{'nodes'} } )
    {

      if ( $NodeSub->{'mark'} eq '' )
      {

        my $Line = $NodeSub->{'nodes'}[0];
        $Line =~ s/\s*$//;
        
        # determine the outline level based on the number of tabs on the line
        $Line =~ s/^(\s*)//;
        my $LevelNew = 1 + length $1;
        
        while ( $Level > $LevelNew )
        {
          $Level--;
          $Out .= "\t" x ( $LevelBase + $Level );
          $Out .= "</ol>";
          $Out .= "\n";
        }
        while ( $Level < $LevelNew )
        {
          $Out .= "\t" x ( $LevelBase + $Level );
          $Out .= "<ol type=";
          $Out .= $ListHeadings[ $Level % ( $#ListHeadings + 1 ) ];
          $Out .= ">";
          $Out .= "\n";
          $Level++;
        }

        $Out .= "\t" x ( $LevelBase + $Level );
        $Out .= "<li>$Line</li>";
        $Out .= "\n";

      }
      else
      {
        $Out .= &Compile( $NodeSub, $Node, $LevelBase + $Level + 1 );
      }

    }
    
    while ( $Level > 0 )
    {
      $Level--;
      $Out .= "\t" x ( $LevelBase + $Level );
      $Out .= "</ol>";
      $Out .= "\n";
    }

    return $Out;

  },

################################################################################

  'ol' => sub
  {

    my $Node = shift;
    my $Parent = shift;
    my $LevelBase = shift;
    
    &ClearBlankNodes( $Node );
    
    my @ListHeadings = ( 'I', 'A', '1', 'i', 'a', );
    
    my $Out;
    $Out .= "\n";
    
    my $Level = 0;
    
    foreach my $NodeSub ( @{ $Node->{'nodes'} } )
    {

      if ( $NodeSub->{'mark'} eq '' )
      {

        my $Line = $NodeSub->{'nodes'}[0];
        $Line =~ s/\s*$//;
        
        # determine the outline level based on the number of tabs on the line
        $Line =~ s/^(\s*)//;
        my $LevelNew = 1 + length $1;
        
        # find the link and name
        my @temps = split "\t", $Line;
        my $Link = shift @temps;
        my $Name = shift @temps;
        $Link =~ s/ /%20/g;
        $Name = $Link if $Name eq '';
        
        while ( $Level > $LevelNew )
        {
          $Level--;
          $Out .= "\t" x ( $LevelBase + $Level );
          $Out .= "</ol>";
          $Out .= "\n";
        }
        while ( $Level < $LevelNew )
        {
          $Out .= "\t" x ( $LevelBase + $Level );
          $Out .= "<ol type=";
          $Out .= $ListHeadings[ $Level % ( $#ListHeadings + 1 ) ];
          $Out .= ">";
          $Out .= "\n";
          $Level++;
        }

        $Out .= "\t" x ( $LevelBase + $Level );
        $Out .= qq(<li><a href="$Link">$Name</a></li>);
        $Out .= "\n";

      }
      else
      {
        $Out .= &Compile( $NodeSub, $Node, $LevelBase + $Level + 1 );
      }

    }
    
    while ( $Level > 0 )
    {
      $Level--;
      $Out .= "\t" x ( $LevelBase + $Level );
      $Out .= "</ol>";
      $Out .= "\n";
    }

    return $Out;

  },

################################################################################

  '"' => sub
  {
  
    my $Node = shift;
    my $Parent = shift;
    my $Level = shift;
    
    my $Out;
    $Out .= "\n";
    
    if ( @{ $Node->{'nodes'} } > 1 )
    {

      $Out .= '<pre>';

      foreach my $NodeSub ( @{ $Node->{'nodes'} } )
      {

        if ( $NodeSub->{'mark'} eq '' )
        {
        
          my $Line = $NodeSub->{'nodes'}[0];
          $Line =~ s/\s*$//;

          $Out .= "\n";
          $Out .= "$Line";
          
        }
        else
        {
          $Out .= &Compile( $NodeSub, $Node, $Level + 1 );
        }

      }

      $Out .= '</pre>';
      $Out .= "\n";

    }
    else
    {

      my $NodeSub = $Node->{'nodes'}[0];

      if ( $NodeSub->{'mark'} eq '' )
      {
      
        my $Line = $NodeSub->{'nodes'}[0];
        $Line =~ s/\s*$//;
        
        $Out .= "\t" x $Level;
        $Out .= '<pre>';
        $Out .= "$Line";
        $Out .= '</pre>';
        $Out .= "\n";
        
      }
      else
      {
        $Out .= '<pre>';
        $Out .= &Compile( $NodeSub, $Node, $Level );
        $Out .= '</pre>';
        $Out .= "\n";
      }

    }

    return $Out;

  },

################################################################################

  '!' => sub
  {
  
    my $Node = shift;
    my $Parent = shift;
    my $Level = shift;
    
    &ClearBlankNodes( $Node );
    
    my $Out;
    
    if ( @{ $Node->{'nodes'} } > 1 )
    {

      $Out .= "\t" x $Level;
      $Out .= '<!--';
      $Out .= "\n";

      foreach my $NodeSub ( @{ $Node->{'nodes'} } )
      {

        if ( $NodeSub->{'mark'} eq '' )
        {
        
          my $Line = $NodeSub->{'nodes'}[0];
          $Line =~ s/\s*$//;

          $Out .= "\t" x ( $Level + 1 );
          $Out .= "$Line";
          $Out .= "\n";
          
        }
        else
        {
          $Out .= &Compile( $NodeSub, $Node, $Level + 1 );
        }

      }

      $Out .= "\t" x $Level;
      $Out .= '-->';
      $Out .= "\n";

    }
    else
    {

      my $NodeSub = $Node->{'nodes'}[0];

      if ( $NodeSub->{'mark'} eq '' )
      {
      
        my $Line = $NodeSub->{'nodes'}[0];
        $Line =~ s/\s*$//;
        
        $Out .= "\t" x $Level;
        $Out .= '<!-- ';
        $Out .= "$Line";
        $Out .= ' -->';
        $Out .= "\n";
        
      }
      else
      {
        $Out .= &Compile( $NodeSub, $Node, $Level );
      }

    }

    return $Out;

  },

################################################################################

  '!.\*' => sub
  {
  
    my $Node = shift;
    my $Parent = shift;
    my $Level = shift;
    
    &ClearBlankNodes( $Node );
    
    my $Out;
    
    foreach my $NodeSub ( @{ $Node->{'nodes'} } )
    {

      if ( $NodeSub->{'mark'} eq '' )
      {

        my $Line = $NodeSub->{'nodes'}[0];
        $Line =~ s/^\s*//;
        $Line =~ s/\s*$//;

        $Out .= "\t" x $Level;
        $Out .= '*';
        $Out .= "\t";
        $Out .= "$Line";
        $Out .= "\n";

      }

    }

    return $Out;

  },
  
################################################################################

  '!.#' => sub
  {
    return BuildCommentList( shift, shift, shift, 1 );
  },
  
################################################################################

  '!.a' => sub
  {
    return BuildCommentList( shift, shift, shift, 'a' );
  },
  
################################################################################

  '!.A' => sub
  {
    return BuildCommentList( shift, shift, shift, 'A' );
  },
  
################################################################################

);

$SWL::Builds{'calendar'} = $SWL::Builds{'C'};

################################################################################
################################################################################
#
# VARS
# %Vars contains the default values in '@' data.

%SWL::Vars =
(
  '^' =>
  [
    [],
    {},
  ],
  '=' =>
  [
    [],
    {},
  ],
);

################################################################################
################################################################################
#
# Property
# A utility function for building HTML attributes.
#

sub Property {
  my $Node = shift;
  my %Tempz;
  for my $Vars ( @_ )
  {
    my $Node = $Node->{'vars'};
		if ( $Vars =~ /^ARRAY/ )
		{
      for my $Var ( @$Vars )
      {
  	    $Node = $Node->{$Var}[1];
      }
      %Tempz = ( %Tempz, %$Node );
		}
		elsif ( $Vars =~ /^HASH/ )
		{
      %Tempz = ( %Tempz, %$Vars );
		}
  }
  return join '', map {
    my $Value = ( $Tempz{$_} =~ /^ARRAY/ )? $Tempz{$_}[0][0] : $Tempz{$_};
    # todo escape quotes
    qq( $_="$Value") if $Value ne '';
  } sort keys %Tempz;
}

################################################################################

sub CalendarMonthSeed
{

  # use Zeller's Congruence

  my $year = $_[0];
  my $month = $_[1] - 2;

  if ( $month < 1 )
  {
    $month += 12;
    $year--;
  }

  return
  (
    + 1
    + int
      (
        (13 * $month) / 5
      )
    + ( $year % 100 )
    + int
      (
        ( $year % 100 ) / 4
      )
    + int
      (
        int( $year / 100 ) / 4
      )
    - ( 2 * int( $year / 100 ) )
  ) % 7
  ;

}

sub CalendarMonthCount
{

  my $year = shift;
  my $month = shift;

  my %Count = 
  (
    1 => 31,
    2 =>
    (
      ( $year % 4 )?
          # is not divisible by 4
          28
        :
          # is divisible by 4
          ( $year % 100 )?
              # is divisible by 4 and is not divisible by 100
              ( $year % 400 )?
                  # is divisible by 4, is not divisible by 100, is not divisible by 400
                  28
                :
                  # is divisible by 4, is not divisible by 100, is divisible by 400
                  29
            :
              # is divisible by 4 and is divisible by 100
              28
    ),
    3 => 31,
    4 => 30,
    5 => 31,
    6 => 30,
    7 => 31,
    8 => 31,
    9 => 30,
    10 => 31,
    11 => 30,
    12 => 31,
  );
  
  return $Count{$month};
  
}

%SWL::CalendarMonthName = 
(
  1 => 'January',
  2 => 'February',
  3 => 'March',
  4 => 'April',
  5 => 'May',
  6 => 'June',
  7 => 'July',
  8 => 'August',
  9 => 'September',
  10 => 'October',
  11 => 'November',
  12 => 'December',
);

%SWL::CalendarMonthNumberFromShort =
(
  'Jan' => 1,
  'Feb' => 2,
  'Mar' => 3,
  'Apr' => 4,
  'May' => 5,
  'Jun' => 6,
  'Jul' => 7,
  'Aug' => 8,
  'Sep' => 9,
  'Oct' => 10,
  'Nov' => 11,
  'Dec' => 12,
);

sub CalendarAnalyze
{
  my $Node = shift;
  my %Dates;
  foreach my $NodeSub ( @{ $Node->{'nodes'} } )
  {
  
    if ( $NodeSub->{'mark'} eq '' )
    {
  
      my $Line = $NodeSub->{'nodes'}[0];
      $Line =~ s/\s*$//;
      # todo: something in this odd case
      
    }
    elsif ( $NodeSub->{'mark'} =~ /^(\d+)$/ )
    {
      my $Year = $1 + 0;
      $Dates{$Year} = {} if not exists $Dates{$Year};
      
      foreach my $NodeSubSub ( @{ $NodeSub->{'nodes'} } )
      {
      
        # try to obtain a month number if the mark is the month name
        my $Month = substr $NodeSubSub->{'mark'}, 0, 3;
        foreach my $MonthKey ( keys %SWL::CalendarMonthNumberFromShort )
        {
          if ( $Month eq $MonthKey )
          {
            $NodeSubSub->{'mark'} = $SWL::CalendarMonthNumberFromShort{ $Month };
          }
        }
  
        if ( $NodeSubSub->{'mark'} eq '' )
        {
          # messages for the year
        }
        elsif ( $NodeSubSub->{'mark'} =~ /^(\d+)$/ )
        {
          my $Month = $1 + 0;
          $Dates{$Year}{$Month} = {} if not exists $Dates{$Year}{$Month};
          
          foreach my $NodeSubSubSub ( @{ $NodeSubSub->{'nodes'} } )
          {
            if ( $NodeSubSubSub->{'mark'} eq '' )
            {
              # messages for the month
            }
            elsif ( $NodeSubSubSub->{'mark'} =~ /^(\d+)$/ )
            {
              my $Day = $1 + 0;
              $Dates{$Year}{$Month}{$Day} = [] if not exists $Dates{$Year}{$Month}{$Day};
              
              foreach my $NodeSubSubSubSub ( @{ $NodeSubSubSub->{'nodes'} } )
              {
                if ( $NodeSubSubSubSub->{'mark'} eq '' )
                {
                  # add event to list
                  push @{$Dates{$Year}{$Month}{$Day}}, $NodeSubSubSubSub->{'nodes'}[0];
                }
                else
                {
                  # compile data into the list
                  push @{$Dates{$Year}{$Month}{$Day}}, scalar &Compile( $NodeSubSubSubSub, $Node, $Level + 3 );
                }
              }
              
            }
            else
            {
              &Compile( $NodeSub, $Node, $Level + 1 );
  		            #todo capture these compiles in the appropriate place
            }
          }
          
        }
        else
        {
          &Compile( $NodeSub, $Node, $Level + 1 );
        }
      }
      
    }
    else
    {
      &Compile( $NodeSub, $Node, $Level + 1 );
    }

  }
  return %Dates;
}


################################################################################

sub ClearBlankNodes
{
  my $Node = shift;
  
  $Node->{'nodes'} =
  [
    grep
      { $_->{'mark'} ne '' or $_->{'nodes'}[0] !~ /^\s*$/; }
      @{ $Node->{'nodes'} }
  ];

}

################################################################################

sub CopyMarkNest
{
  my $Hash = shift;
  my %Out;
  foreach my $Key ( keys %$Hash )
  {
    $Out{$Key} =
    [
      $Hash->{$Key}[0],
      &CopyMarkNest( $Hash->{$Key}[1] ),
    ];
  }
  return \%Out;
}

################################################################################

sub FlatenMarkNest
{

  my $Hash = shift;
  
  my %Outz = ( ' ' => $Hash );
  my @Todos = ( ' ' );
  
  while ( my $Key = pop @Todos )
  {
    foreach my $KeySub ( keys %{ $Outz{$Key} } )
    {
    
      my $KeyNew = "$Key.$KeySub";
      $KeyNew =~ s/^ //;
      
      $Outz{"$KeyNew"} = $Outz{$Key}{$KeySub}[1];
      push @Todos, $KeyNew;
      
    }
  }

  return \%Outz;
}

################################################################################

sub FlatenMarkNest2
{

  my $Hash = shift;
  
  my %Hashz = ( ' ' => $Hash );
  my %Arrayz = ( );
  
  my @Todos = ( ' ' );
  
  while ( my $Key = pop @Todos )
  {
    foreach my $KeySub ( keys %{ $Hashz{$Key} } )
    {
    
      my $KeyNew = "$Key.$KeySub";
      $KeyNew =~ s/^ //;
      
      $Hashz{"$KeyNew"} = $Hashz{$Key}{$KeySub}[1];
      push @Todos, $KeyNew;

      $Arrayz{"$KeyNew"} = $Hashz{$Key}{$KeySub}[0];
      
    }
  }

  return \%Arrayz;
}

################################################################################

1;
