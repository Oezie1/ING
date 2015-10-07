#!/usr/bin/perl -w
use warnings;
use strict;
use Getopt::Long;
use WWW::Mechanize;
use JSON;

use Data::Dumper;

my $username = '';
my $password = '';
my $save     = 0;
my $verbose  = 0;
my $query = '';

my $time = time();
my $json = JSON->new;

GetOptions ( "username|u=s" => \$username,  # string
             "password|p=s" => \$password,  # string
             "query|q=s"    => \$query,     # string
             "save|s"       => \$save,      # flag
             "verbose|v"    => \$verbose);  # flag


print "username: $username, password: $password query: $query verbose: $verbose\n" if $verbose;

my $mech = WWW::Mechanize->new();
$mech->get( "https://mijn.ing.nl/internetbankieren/SesamLoginServlet" );

my @form   = $mech->forms;
my $inputs = $form[0]->{'inputs'};

$mech->submit_form(
        form_number => 1,
        fields      => {
            $inputs->[0]->{'id'} => $username,
            $inputs->[1]->{'id'} => $password
        }
    );

# Cookies
$mech->get("https://bankieren.mijn.ing.nl/ssm/sso/continue");

# Fetch accounts
$mech->get("https://bankieren.mijn.ing.nl/api/g-payments/accounts");
my $accounts = $mech->content();
print $accounts."\n\n" if $verbose;

if( $mech->success() ) {
  my $accountsdata = $json->decode(substr($accounts,5));

  for ( @{$accountsdata->{accounts}} ) {
    my $ean = $_->{ean};
    my $searchstring = "ai=0&q=".$query."&df=01-01-2006&cd=all&ean=".$_->{ean};
    my $result = '';
    my $searchdata;

    do {
      # search transactions
      $mech->get("https://bankieren.mijn.ing.nl/api/g-payments/search?".$searchstring);

      if( $mech->success() ) {
        $result = $mech->content();
        print $result."\n\n" if $verbose;
        $searchdata = $json->decode(substr($result,5));

        for ( @{$searchdata->{transactions}} ) {
          my $statementLines = '';
      		for(@{$_->{statementLines}})
      		{
      				$statementLines .= $_;
      				$statementLines .= " " if length $_ < 30;
      		}
          print "Date: $_->{date} From: $_->{account} To: $_->{counterAccount} Amount: $_->{amount} $statementLines\n";
        }
        $searchstring = $searchdata->{nextBatchFilter}."&ean=".$ean;

      }
      else {
        last;
      }
    } while ($searchdata->{batchData}->{searchMore});
  }

}
