#! /usr/bin/perl -w
# Program         : check_uptime.pl
# Author          : Michael Simoni
# Purpose         : check the uptime of a server and warns if it has been up to long
# Date            : Fri Sep 26 15:54:16 EDT 2008
################################################################################
# CVS Information
# $Source: /var/lib/cvs/nagios/check_uptime.pl,v $
# $Author: msimoni $
# $Date: 2008-10-19 17:57:46 $
# $Id: check_uptime.pl,v 1.3 2008-10-19 17:57:46 msimoni Exp $
# $Revision: 1.3 $
################################################################################
# Notes
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# you should have received a copy of the GNU General Public License
# along with this program (or with Nagios);  if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA
################################################################################
# strange as it may seem there are some applications out there that when
# loaded on a unix like system tend to behave eratticaly over time.
# A periodic reboot tends to keep the appliation and the server on course.
# Hense the reasoning behind this seemingly useless check for a unix system.
################################################################################
$| = 1;
use strict;
use English;
use Sys::Hostname;

#use Sys::uptime;
use Getopt::Long;
use vars qw($PROGNAME);
use lib "/usr/lib/nagios/plugins";
use utils qw (%ERRORS &print_revision &support);
################################################################################
# Globals
################################################################################
my $hostname = hostname();    # always the current host
my $debug    = 0;

my ( $opt_c, $opt_w, $opt_W, $opt_C, $opt_h, $opt_H, $opt_L, $opt_v, $opt_V );
my $result  = "";
my $message = "";
my ( $time, $status, $uptime, $units );

$opt_W = 20;
$opt_C = 30;
$opt_w = 1;
$opt_c = 1;
################################################################################
# show a usage statement
################################################################################
sub print_usage ()
{
    print <<EOD;
Usage:
$PROGNAME [ -H ] [ -L ] [-W <days>] [-C <days>] [-w <days>] [-c <days>]\n";
		-H check for uptime bieng to high
                -L check for uptime bieng to low
		-W Warning threshhold for uptime being up to long. Default: $opt_W
		-C Critical threshhold for uptime being up to long. Default: $opt_C
		-w Warning threshhold for uptime being up not long enough Default: $opt_w
		-c Critical threshhold for uptime being up not long enough Default: $opt_c
                -h| --help 
                -V| --version
                -v| --verbose

	With no options the the default beavior is to check uptime to be to high
        anything on the command line overrides the default behavior
EOD
    exit $ERRORS{UNKNOWN};
}
################################################################################
# print the standard help stuff
################################################################################
sub print_help ()
{
    print_revision( $PROGNAME, '$Revision: 1.3 $' );
    print "Copyright (c) 2008 Michael Simoni\n\n";
    print_usage();
    print "\n";
    print "Uptime must be no more than this many days old (default: warn $opt_W days, crit $opt_C)\n";
    print "This check is used as a reminder to reboot the machine after so many days\n";
    print "\n";
    support();
}
################################################################################
# make some error checks
################################################################################
sub error_checks()
{
    if ( $opt_W > $opt_C )
    {
        print "High Warning threshhold cannot be higher that High Critical threshhold\n";
        exit $ERRORS{"UNKNOWN"};
    }
}
################################################################################
# Check to see if the server has been up for to long.
# soe servers with bad applications need to be rebooted periodically
################################################################################
sub check_uptime_tohigh( $ $ $ $ )
{
    my ( $time, $status, $uptime, $units ) = @_;

    if ( "$units" =~ /day/ )
    {
        $uptime = $uptime + 0;    # just for good measure.
        if ( $opt_C and ( $uptime > $opt_C ) )
        {
            $result  = 'CRITICAL';
            $message = "system has been up to long.";
        }
        elsif ( $opt_W and $uptime > $opt_W )
        {
            $result  = 'WARNING';
            $message = "system has been up to long. Critical after $opt_C days.";
        }
        else
        {
            $result = "OK";
        }
    }
    else
    {
        $result = "OK";
    }
}
################################################################################
# Check to see if the server has been up not long enough
# Used to check random reboots. ping checks should alert to this behavior
# but attacking a problem from  different angle never hurts.
################################################################################
sub check_uptime_tolow( $ $ $ $ )
{
    my ( $time, $status, $uptime, $units ) = @_;

    if ( "$units" =~ /day/ )
    {
        $uptime = $uptime + 0;    # just for good measure.
        if ( $opt_c and $uptime < $opt_c )
        {
            $result  = 'CRITICAL';
            $message = "The system may have been rebooted. Decreases to warning after $opt_w days.";
        }
        elsif ( $opt_w and $uptime < $opt_w )
        {
            $result  = 'WARNING';
            $message = "The system may have been rebooted.";
        }
        else
        {
            $result = "OK";
        }
    }
    else
    {
        $result  = 'WARNING';
        $message = "System may have rebooted. Decreases to OK after $opt_w day(s).";
    }
}
################################################################################
# get the uptime data
################################################################################
sub get_uptime_data()
{
    my ( $time_uptime, $boot_time, $no_users, $la_1min, $la_5min, $la_15min );
    if ( ( $^O eq 'solaris' ) or ( $^O eq 'linux' ) )
    {
        my $uptime_data = `/usr/bin/uptime`;
        chomp($uptime_data);

        print "$uptime_data\n" if $opt_v;

        $uptime_data =~ s/load average://;
        if ( "$uptime_data" =~ /day/ )
        {
            ( $time_uptime, $boot_time, $no_users, $la_1min, $la_5min, $la_15min ) = split( ",", $uptime_data );
        }
        else
        {

            #no boot time data if it has been up less than one day
            ( $time_uptime, $no_users, $la_1min, $la_5min, $la_15min ) = split( ",", $uptime_data );
            $boot_time = "" if ( not defined $boot_time );
        }
        $time_uptime =~ s/^\s+|\s+$//g;    # strip leading and trailing blanks
        $boot_time   =~ s/^\s+|\s+$//g;    # strip leading and trailing blanks
        $no_users    =~ s/^\s+|\s+$//g;    # strip leading and trailing blanks
        $no_users    =~ s/users//;
        $la_1min     =~ s/^\s+|\s+$//g;    # strip leading and trailing blanks
        $la_5min     =~ s/^\s+|\s+$//g;    # strip leading and trailing blanks
        $la_15min    =~ s/^\s+|\s+$//g;    # strip leading and trailing blanks

        ( $time, $status, $uptime, $units ) = split /\s+/, $time_uptime;
        $units = "" if ( not defined $units );

        if ($opt_v)
        {
            print "Detected OS: $^O\n";
            print "
	   				time_uptime:$time_uptime
	   				units      :$units
	   				boot_time  :$boot_time
	   				no_users   :$no_users
	   				la_1min    :$la_1min
	   				la_5min    :$la_5min
	   				la_15min   :$la_15min\n";
        }
    }
    else
    {
        print "This plugin currently only works on Solaris 10 and linux.\n";
        print "Detected OS: $^O\n";
        exit $ERRORS{'UNKNOWN'};
    }

}
################################################################################
# Main
################################################################################
my $length_argv = @ARGV;    # check on correct number o command line paramters
$PROGNAME = "check_uptime";
################################################################################

Getopt::Long::Configure('bundling');
GetOptions(
    "V"         => \$opt_V,
    "version"   => \$opt_V,
    "v"         => \$opt_v,
    "verbose"   => \$opt_v,
    "h"         => \$opt_h,
    "help"      => \$opt_h,
    "w=i"       => \$opt_w,
    "c=i"       => \$opt_c,
    "W=i"       => \$opt_W,
    "C=i"       => \$opt_C,
    "checkhigh" => \$opt_H,
    "H"         => \$opt_H,
    "checklow"  => \$opt_L,
    "L"         => \$opt_L
);

if ($opt_V)
{
    print_revision( $PROGNAME, '$Revision: 1.3 $' );
    exit $ERRORS{'OK'};
}

if ($opt_h)
{
    print_help();
    exit $ERRORS{'OK'};
}

# Get the data
#error_checks();
get_uptime_data();
my $check_made = 0;
if ($opt_H) { check_uptime_tohigh( $time, $status, $uptime, $units ); $check_made++; }
if ($opt_L) { check_uptime_tolow( $time, $status, $uptime, $units ); $check_made++; }

if ( not $check_made )
{
    check_uptime_tohigh( $time, $status, $uptime, $units );
}

if ( $result eq "OK" ) { $message = ""; }
print "$result: UPTIME on $hostname - $message current uptime: $uptime $units\n";
exit $ERRORS{$result};


