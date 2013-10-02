#!/usr/bin/perl -w

$ENV{NLS_LANG}='AMERICAN_AMERICA.AL32UTF8';
$ENV{ORACLE_SID}='XE';
$ENV{ORACLE_HOME}='/usr/lib/oracle/xe/app/oracle/product/10.2.0/server';
$ENV{LD_LIBRARY_PATH}='/usr/lib/oracle/xe/app/oracle/product/10.2.0/server/lib';

use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use DBI;
use DBIx::Simple;
use Template;

my $q = new CGI;
print $q->header();

### Attributes to pass to DBI->connect() to disable automatic error checking

my %attr = (PrintError => 0, RaiseError => 0);
my $dbh = DBI->connect("dbi:Oracle:XE", "munshi8", "gbaba4000" , \%attr) or die "Can't connect to database: ", $DBI::errstr, "\n";
my $dbs = DBIx::Simple->connect($dbh);

my $table = $dbs->query(qq|SELECT room_num, room_desc FROM hc_rooms ORDER BY room_num|)->xto();

   $table->modify(table => { cellpadding => "3", cellspacing => "2" });
   $table->modify(tr => { class => ['listrow0', 'listrow1'] });
   $table->modify(th => { class => 'listheading' }, 'head');
   $table->modify(th => { class => 'listtotal' }, 'foot');
   $table->modify(th => { class => 'listsubtotal' });
   $table->modify(th => { align => 'center' }, 'head');
   $table->modify(th => { align => 'right' }, 'foot');
   $table->modify(th => { align => 'right' });

print $table->output;


my $file = 'ramada_invoice.html';
my @allrooms = $dbs->query(qq|SELECT room_num, room_desc FROM hc_rooms ORDER BY room_num|)->hashes;

my $vars = { allrooms => \@allrooms };

my $template = Template->new();
$template->process($file, $vars) || die "Template process failed: ", $template->error(), "\n";

1;
# EOF;
