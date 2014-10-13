package CQP_RootCall;

# file CQP_RootCall.pm

#hackaroo by WX5S
#released to N5KO, WB6S  9/18/2006
#some minor clean up WX5S  5/27/2010 no change to algorithm

use strict;
use warnings;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter;
our $VERSION=1.0;
our @ISA = qw(Exporter);
our @EXPORT = qw(get_root_call isa_dx_prefix);
our $DEBUG =0;

sub get_root_call       #extract root call from a call like: 4m7/w3abc/qrp
{
   my $call = shift;
   
   local $SIG{__WARN__} = 
      sub 
      {
           my $msg = shift;
           print STDERR "*******\n";
           print STDERR $msg;                        #has a \n in $msg
           print STDERR "callsign = $call\n";
           print STDERR "*******\n";
       };
   
   $call =~ tr/[a-z] /[A-Z]/d;              #remove spaces and convert to uppercase
   my ($part1, $part2) = split '/', $call;  #throws away "/"'s and creates token array
   if (!defined($part2)) {return $part1; }  #no "/"'s found, or like W6AB/
                                            #if prefix ends in a digit, then
   return ($part2) if ($part1 =~ m/\d\z/);  #its like 4m7/w7abc, return 2nd part
   return ($part2) 
          unless     ($part1 =~ m/\d/ )  
                  || ($part2 =~ m/\d$/);
                  # if no digit all in first part, then return the second part
                  # call is like DL/W8ABC. An exception is a malformed call like
                  # WABC/7 where the 2nd part would end in a digit, but no
                  # digit was in the first part
   return ($part1);  #was like w5aa/7 or w5aa/qrp or w5aa/ad6e
}

#######  WARNING - this needs a lot of work for KP4, KG4, KH2, etc...######
#### This is for CQP automated log checking. You might still be DX even
#### if this version says that you aren't, but if this says that you are
#### DX, there is 99.9% chance that you really are DX (fails for degenerate
#### cases like qrp/WX5S) but works fine for typical EU, Asia callsigns.
#### When CQP has an unrecognized QTH and this function says DX, then
#### QTH can be assumed to be DX for no mult credit (hey, you already
#### messed up with invalid name if it really was supposed to be a CA or
#### US State/VE mult name).

sub isa_dx_prefix   #return true if high probability of being DX
{ 
  my ($call) = shift;
  $call =~ tr/[a-z] /[A-Z]/d;     #remove spaces and convert to uppercase
  my($part1, $part2) = split '/', $call;  
     
  #need to handle the special case of old style portable
  #like G3ABC/W4 instead of W4/G3ABC
  return 0 if (     defined($part2)  and  $part2 =~ m/\d\z/ 
                and $part2 =~ m/^W|^N|^K|^A|^VE|^VA|^CY|^VY|^VO/ );
  return 0 if ($call =~ m/^W|^N|^K|^A|^VE|^VA|^CY|^VY|^VO/ );
  return 1;
}

#########################
sub test_get_root_call () 
{
   print "testing get_root_call(\$): \n";
   my @cases = (
    "f6abc/",
    "f6abc",
    "G3abc/w4",
    "w4/g3abc",
    "Kp2/WX5S",
    "wx5s",
    "WX5S/6",
    "WX5S /6",
    "WX5 s",
    "wx5s/qrp",
    "wx5s/dl",
    "WX5s/dl0",
    "dl/wx5s",
    "dl9/wx5s",
    "DL7/wx5s/mm2",
    "DL7/  wx5s/mm2",
    "4m7/w3abc",
    "4m7/w3abc/qrp",
    "W6YX/WX5S",    # an important case - W6YX is the answer
    "W6OAT/yuba",
    "Yuba/W6oat",
    "4m7/3B8CF",
    "3B8CF/4M7",
    "WA6O/YUBA",
    "3B8CF/mm", 
    "DL/3B8CF/mm/QRP",
    "dl/wabc",
    "dl/wabc/qrp",
    "3b8/wabc",
    "ve/wabc",
    "ve3/DL0ABC",
    "qrp/wx5s",
    "N6O/qrp",
    "9v1/ja3abc/mm",
    "ve8/wabc",
    "wabc/7",   
    "w7]=bc/ve8",   #sorry, you get W7]=bc with this BS callsign
    "wabc/q5p",     #you get q5p, thinks its like DL/WX5S
                    #the following test case currently returns 2nd part
    "wabc/qrp", #because if no digits at all you get 2nd part
    "wabc/mm/qrp",
    "WA61/YUBA",
    "WA61X/YUBA",
    "w3abc/4m7",
    "cy0/ve1rgb",
    "Cy0a",
    "vy0/VE3",
    );
    
    foreach (@cases) 
    {
        my $call = get_root_call($_);
        my $flag = isa_dx_prefix ($_);
        printf "base call: %10s  \tDX=$flag\tfrom: $_\n", $call;        
    }
} 

test_get_root_call() if $DEBUG;

sub test(){test_get_root_call();};

1;
__END__
example test run:
testing get_root_call($): 
base call:      F6ABC   DX=1    from: f6abc/
base call:      F6ABC   DX=1    from: f6abc
base call:      G3ABC   DX=0    from: G3abc/w4
base call:      G3ABC   DX=0    from: w4/g3abc
base call:       WX5S   DX=0    from: Kp2/WX5S
base call:       WX5S   DX=0    from: wx5s
base call:       WX5S   DX=0    from: WX5S/6
base call:       WX5S   DX=0    from: WX5S /6
base call:       WX5S   DX=0    from: WX5 s
base call:       WX5S   DX=0    from: wx5s/qrp
base call:       WX5S   DX=0    from: wx5s/dl
base call:       WX5S   DX=0    from: WX5s/dl0
base call:       WX5S   DX=1    from: dl/wx5s
base call:       WX5S   DX=1    from: dl9/wx5s
base call:       WX5S   DX=1    from: DL7/wx5s/mm2
base call:       WX5S   DX=1    from: DL7/  wx5s/mm2
base call:      W3ABC   DX=1    from: 4m7/w3abc
base call:      W3ABC   DX=1    from: 4m7/w3abc/qrp
base call:       W6YX   DX=0    from: W6YX/WX5S
base call:      W6OAT   DX=0    from: W6OAT/yuba
base call:      W6OAT   DX=1    from: Yuba/W6oat
base call:      3B8CF   DX=1    from: 4m7/3B8CF
base call:      3B8CF   DX=1    from: 3B8CF/4M7
base call:       WA6O   DX=0    from: WA6O/YUBA
base call:      3B8CF   DX=1    from: 3B8CF/mm
base call:      3B8CF   DX=1    from: DL/3B8CF/mm/QRP
base call:       WABC   DX=1    from: dl/wabc
base call:       WABC   DX=1    from: dl/wabc/qrp
base call:       WABC   DX=1    from: 3b8/wabc
base call:       WABC   DX=0    from: ve/wabc
base call:     DL0ABC   DX=0    from: ve3/DL0ABC
base call:       WX5S   DX=1    from: qrp/wx5s
base call:        N6O   DX=0    from: N6O/qrp
base call:     JA3ABC   DX=1    from: 9v1/ja3abc/mm
base call:       WABC   DX=0    from: ve8/wabc
base call:       WABC   DX=0    from: wabc/7
base call:     W7]=BC   DX=0    from: w7]=bc/ve8
base call:        Q5P   DX=0    from: wabc/q5p    ## wrong should be wabc
base call:        QRP   DX=0    from: wabc/qrp    ## wrong shuold be wabc
base call:         MM   DX=0    from: wabc/mm/qrp ## wrong should be wabc
base call:       YUBA   DX=0    from: WA61/YUBA   ## wrong should be WA61
base call:      WA61X   DX=0    from: WA61X/YUBA
base call:      W3ABC   DX=0    from: w3abc/4m7
base call:     VE1RGB   DX=0    from: cy0/ve1rgb
base call:       CY0A   DX=0    from: Cy0a

Process completed successfully
