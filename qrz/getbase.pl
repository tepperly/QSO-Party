#!/usr/bin/env perl

use CQP_RootCall;

foreach $argnum (0 .. $#ARGV) {
    print get_root_call($ARGV[$argnum]);
}
