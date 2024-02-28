#!/usr/bin/env perl 

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Basename qw/basename/;
use Schedule::SGELK;

use version 0.77;
our $VERSION = '0.1.1';

local $0 = basename $0;
sub logmsg{local $0=basename $0; print STDERR "$0: @_\n";}
exit(main());

sub main{
  my $settings={};
  GetOptions($settings,qw(help)) or die $!;
  usage() if($$settings{help});

  my $nf = $ARGV[0] or die "ERROR: need nextflow file";

  my $nextflowObj = readNf($nf, $settings);
  ...;

  return 0;
}

sub readNf{
  my($infile, $settings) = @_;

  my $nfContent;
  {
    open(my $fh, $infile) or die "ERROR: could not read $infile: $!";
    undef $/;
    $nfContent = <$fh>;
    close $fh;
  }

  # Major to capture
  my($main, %process);

  if($nfContent =~ m/workflow\s*(.+)/ms){
    $main = readClosure($1, $settings);
  } else {
    die "ERROR: no workflow{} found";
  }

  $nfContent.="\nprocess"; # help with lookaheads
  while($nfContent =~ /process\s+(.+?)\s+(.+?)(?=process)/gms){
    my $body = readClosure($2, $settings);
    my $name = $1;
    
    # Convert the body to actual code
    my $process = processToCode($body, $settings);

    $process{$name} = $process;
  }

  print $nfContent;
}

# Read something between {}
sub readClosure{
  my($instr, $settings) = @_;
  
  my $numOpenClosures = 0;
  my $startPos = index($instr, '{', 0);
  my $stopPos;
  if($startPos < 0){
    die "ERROR: could not find a { in the input string $instr";
  }
  $numOpenClosures++;

  my $pos = $startPos+1;
  for(my $pos = $startPos+1; $pos<length($instr); $pos++){
    my $char = substr($instr, $pos, 1);
    if($char eq '{'){
      $numOpenClosures++;
    }
    if($char eq '}'){
      $numOpenClosures--;

      if($numOpenClosures < 1){
        $stopPos = $pos;
        last;
      }
    }
  }

  my $outstr = substr($instr, $startPos, $stopPos-$startPos+1);
  # trim beginning or ending whitespace or curlies
  $outstr =~ s/^\{+|\}+$|^\s+|\s+$//gs;

  return $outstr;

}

sub processToCode{
  my($instr, $settings) = @_;

  my @lines = map{s/^\s+|\s+$//g; $_}
                split(/\n/, $instr);

  my($inputType, $inputValue);
  my($outputType, $outputValue);
  my($shell);

  for(my $i=0;$i<@lines;$i++){
    $lines[$i] =~ s/^\s+|\s+$//g; # whitespace trim
    if($lines[$i] =~ /input:/){
      my $input = $lines[++$i];
      ($inputType, $inputValue) = split(/\s+/, $input, 2);
    }
    if($lines[$i] =~ /output:/){
      my $output = $lines[++$i];
      ($outputType, $outputValue) = split(/\s+/, $output, 2);
    }

    if($lines[$i] =~ /^"""$/){
      do{
        $shell .= $lines[++$i];
      } while($lines[$i] !~ /"""/);
      $shell =~ s/"""$//; # remove that last bit with quotes
    }
  }

  my %process = (
    inputType    => $inputType,
    outputType   => $outputType,
    inputValue   => $inputValue,
    outputValue  => $outputValue,
    shell        => $shell,
  );

  return \%process;
}

sub usage{
  print "$0: runs a nextflow file
  Usage: $0 [options] main.nf
  --help   This useful help menu
  \n";
  exit 0;
}
