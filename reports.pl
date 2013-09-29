#!/usr/bin/perl -w

$ENV{NLS_LANG}='AMERICAN_AMERICA.AL32UTF8';
$ENV{ORACLE_SID}='XE';
$ENV{ORACLE_HOME}='/usr/lib/oracle/xe/app/oracle/product/10.2.0/server';
$ENV{LD_LIBRARY_PATH}='/usr/lib/oracle/xe/app/oracle/product/10.2.0/server/lib';

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use DBI;
use DBIx::Simple;
use Template;
use CGI::FormBuilder;

my $q = new CGI;

my %attr = (PrintError => 0, RaiseError => 0); # Attributes to pass to DBI->connect() to disable automatic error checking
my $dbh = DBI->connect("dbi:Oracle:XE", "munshi8", "gbaba4000" , \%attr) or die "Can't connect to database: ", $DBI::errstr, "\n";
my $dbs = DBIx::Simple->connect($dbh);

my $nextsub = $q->param('nextsub');
my $action = $q->param('action');

$nextsub = 'sample';
&$nextsub;

1;


#---------------------------------------------------------
# sample report

sub sample {

   my @charge_codes = $dbs->query(qq|SELECT charge_code, charge_desc FROM hc_charge_codes ORDER BY 1|)->arrays;

   my $form1 = CGI::FormBuilder->new(
	method => 'post',
	table => 1,
	fields => [qw(charge_code charge_desc)],
	options => {
		charge_code => \@charge_codes,
	},
	messages => {
		form_required_text => '',
	},
	labels => {
		charge_code => 'Charge Code',
	},
	submit => [qw(Search)],
        params => $q,
	stylesheet => 1,
	template => {
		type => 'TT2',
        	template => 'tmpl/search.tmpl',
		variable => 'form1',
	},
	keepextras => [qw(report_name action)],
   );
   $form1->field(name => 'charge_code', type => 'select');

   print $q->header();
   print $form1->render;

   my $table = $dbs->query(qq|SELECT charge_code, charge_desc FROM hc_charge_codes ORDER BY charge_code|)->xto();

   $table->modify(table => { cellpadding => "3", cellspacing => "2" });
   $table->modify(tr => { class => ['listrow0', 'listrow1'] });
   $table->modify(th => { class => 'listheading' }, 'head');
   $table->modify(th => { class => 'listtotal' }, 'foot');
   $table->modify(th => { class => 'listsubtotal' });
   $table->modify(th => { align => 'center' }, 'head');
   $table->modify(th => { align => 'right' }, 'foot');
   $table->modify(th => { align => 'right' });

   print $table->output;
   print qq|
</body>
</html>
|;
}

# EOF
