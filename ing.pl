#!/usr/bin/perl -w
use warnings;
use strict;
use Getopt::Long;
use WWW::Mechanize;
use JSON;
use RRDs;

my $username = '';
my $password = '';
my $save     = 0;
my $verbose  = 0;

my $time = time();

GetOptions ( "username|u=s" => \$username,  # string
             "password|p=s" => \$password,  # string
             "save|s"       => \$save,      # flag
             "verbose|v"    => \$verbose);  # flag


print "username: $username, password: $password verbose: $verbose\n" if $verbose;

my $mech = WWW::Mechanize->new( autocheck => 0, timeout => 10 );
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
$mech->get( "https://bankieren.mijn.ing.nl/ssm/sso/continue ");

# Fetch accounts
$mech->get( "https://bankieren.mijn.ing.nl/particulier/betalen/api/accounts" );
my $accounts = $mech->content();
print $accounts."\n\n" if $verbose;

if( $save  && $mech->success() ) {
  open (MYFILE, ">accounts${time}.json" );
  print MYFILE $accounts;
  close (MYFILE);
}

# Fetch savings-accounts
$mech->get( "https://bankieren.mijn.ing.nl/api/savings-arrangements/savings-accounts" );
my $savings = $mech->content();
print $savings."\n\n" if $verbose;

if( $save && $mech->success() ) {
  open (MYFILE, ">savings${time}.json" );
  print MYFILE $savings;
  close (MYFILE);
}

# Fetch mortgages
$mech->get( "https://bankieren.mijn.ing.nl/api/mortgages" );
my $mortgages = $mech->content();
print $mortgages."\n\n" if $verbose;

if( $save && $mech->success() ) {
  open (MYFILE, ">mortgages${time}.json" );
  print MYFILE $mortgages;
  close (MYFILE);
}

# Fetch stocks
$mech->get( "https://bankieren.mijn.ing.nl/particulier/beleggen/api/relations/CURRENT/products" );
my $stocks = $mech->content();
print $stocks."\n\n" if $verbose;

my $json = JSON->new;
my $data = $json->decode($stocks);

# print @$data[0]->{productId}->{compoundId};
for( @$data ) {

  $mech->get( "https://bankieren.mijn.ing.nl/particulier/beleggen/api/relations/CURRENT/products/$_->{productId}->{compoundId}/portfolio");

  my $stocksinfo = $mech->content();
  print $stocksinfo."\n\n" if $verbose;

  if( $save && $mech->success() ) {
    open (MYFILE, ">stocks$_->{productId}->{compoundId}${time}.json" );
    print MYFILE $stocksinfo;
    close (MYFILE);
  }
}
