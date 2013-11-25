#!/usr/bin/perl -w

$ENV{NLS_LANG}        = 'AMERICAN_AMERICA.AL32UTF8';
$ENV{ORACLE_SID}      = 'XE';
$ENV{ORACLE_HOME}     = '/usr/lib/oracle/xe/app/oracle/product/10.2.0/server';
$ENV{LD_LIBRARY_PATH} = '/usr/lib/oracle/xe/app/oracle/product/10.2.0/server/lib';

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use DBI;
use DBIx::Simple;
use Template;
use CGI::FormBuilder;
use Number::Format;

my $q  = new CGI;
my $nf = new Number::Format( -int_curr_symbol => '' );
my $tt = Template->new(
    {
        INCLUDE_PATH => '/var/www/munshi9/tmpl',
        INTERPOLATE  => 1,
    }
) || die "$Template::ERROR\n";

my %attr = ( PrintError => 0, RaiseError => 0 );    # Attributes to pass to DBI->connect() to disable automatic error checking
my $dbh = DBI->connect( "dbi:Oracle:XE", "munshi8", "gbaba4000", \%attr ) or die "Can't connect to database: ", $DBI::errstr, "\n";
my $dbs = DBIx::Simple->connect($dbh);

my $nextsub   = $q->param('nextsub');
my $action    = $q->param('action');
my $tmpl      = $q->param('tmpl');
my $id        = $q->param('id');
my $comp_code = $q->param('comp_code');

$nextsub = $q->param('nextsub');
&$nextsub;

1;

#---------------------------------------------------------
# sample report

sub sample {

    my @charge_codes = $dbs->query(qq|SELECT charge_code, charge_desc FROM hc_charge_codes ORDER BY 1|)->arrays;

    my $form1 = CGI::FormBuilder->new(
        method     => 'post',
        table      => 1,
        fields     => [qw(charge_code charge_desc)],
        options    => { charge_code => \@charge_codes, },
        messages   => { form_required_text => '', },
        labels     => { charge_code => 'Charge Code', },
        submit     => [qw(Search)],
        params     => $q,
        stylesheet => 1,
        template   => {
            type     => 'TT2',
            template => 'tmpl/search.tmpl',
            variable => 'form1',
        },
        keepextras => [qw(report_name action)],
    );
    $form1->field( name => 'charge_code', type => 'select' );

    print $q->header();
    print $form1->render;

    my $table = $dbs->query(qq|SELECT charge_code, charge_desc FROM hc_charge_codes ORDER BY charge_code|)->xto();

    $table->modify( table => { cellpadding => "3", cellspacing => "2" } );
    $table->modify( tr => { class => [ 'listrow0', 'listrow1' ] } );
    $table->modify( th => { class => 'listheading' }, 'head' );
    $table->modify( th => { class => 'listtotal' },   'foot' );
    $table->modify( th => { class => 'listsubtotal' } );
    $table->modify( th => { align => 'center' },      'head' );
    $table->modify( th => { align => 'right' },       'foot' );
    $table->modify( th => { align => 'right' } );

    print $table->output;
    print qq|
</body>
</html>
|;
}

#----------------------------------------
sub banquet {
    my $vars = {};
    $vars->{hdr} = $dbs->query( 'SELECT * FROM banquet_header WHERE event_number=?', $id )->hash;
    $vars->{dtl} = $dbs->query( 'SELECT * FROM banquet_lines WHERE event_number=?',  $id )->map_hashes('id');
    print $q->header();
    $tt->process( "$tmpl.tmpl", $vars ) || die $tt->error(), "\n";
}

#----------------------------------------
sub reservation {
    my $vars = {};
    $vars->{res} = $dbs->query( 'SELECT * FROM hc_res WHERE res_id=?', $id )->hash;
    $vars->{company} = $dbs->query( 'SELECT * FROM hc_companies WHERE comp_code = (SELECT comp_code FROM hc_res WHERE res_id = ?)', $id )->hash;
    print $q->header();
    $tt->process( "$tmpl.tmpl", $vars ) || die $tt->error(), "\n";
}

#----------------------------------------
sub reg_card {
    my $vars = {};
    $vars->{res} = $dbs->query( 'SELECT * FROM hc_res WHERE res_id=?', $id )->hash;
    print $q->header();
    $tt->process( "$tmpl.tmpl", $vars ) || die $tt->error(), "\n";
}

#----------------------------------------
sub guest_folio {
    my $vars = {};
    $vars->{res} = $dbs->query( 'SELECT * FROM hc_res WHERE res_id=?', $id )->hash;
    $vars->{charges} = $dbs->query( 'SELECT * FROM hc_charges WHERE res_id=? ORDER BY charge_date', $id )->map_hashes('tr_num');
    print $q->header();
    $tt->process( "$tmpl.tmpl", $vars ) || die $tt->error(), "\n";
}


#----------------------------------------
sub invoice {
    my $vars = {};
    $vars->{nf}      = $nf;
    $vars->{hdr}     = $dbs->query( 'SELECT * FROM hc_invoices WHERE inv_num=?', $id )->hash;
    $vars->{company} = $dbs->query( 'SELECT * FROM hc_companies WHERE comp_code=?', $vars->{hdr}->{comp_code} )->hash;
    $vars->{dtl}     = $dbs->query( "
	SELECT to_char(charge_date, 'yymmdd')||tr_num id, tr_num, charge_date, res_id, guest_name1, other_ref1, other_ref2, room_num, 0-amount amount, ROUND((0-amount) / 1.16, 2) tax_amt
	FROM hc_charges WHERE bill_num=? AND sale_id = 0 ORDER BY 1", $id )->map_hashes('id');
    $vars->{chq} = $dbs->query( "
	SELECT to_char(sale_date, 'yymmdd')||sale_id id, hc_fb_sale.* FROM hc_fb_sale
	WHERE sale_id IN (SELECT sale_id FROM hc_charges WHERE bill_num = ?) ORDER BY 1", $id )->map_hashes('id');
    print $q->header();
    $tt->process( "$tmpl.tmpl", $vars ) || die $tt->error(), "\n";
}


#----------------------------------------
sub payable {
    my $vars = {};
    $vars->{nf}      = $nf;
    $vars->{hdr}     = $dbs->query( 'SELECT * FROM ap_header WHERE inv_id=?', $id )->hash;
    $vars->{company} = $dbs->query( 'SELECT * FROM ap_vendors WHERE comp_code=?', $vars->{hdr}->{vendor_id} )->hash;
    $vars->{dtl}     = $dbs->query( "SELECT * FROM ic_trans_header_tmp WHERE inv_id=?", $id )->map_hashes('tr_num');
    print $q->header();
    $tt->process( "$tmpl.tmpl", $vars ) || die $tt->error(), "\n";
}


#----------------------------------------
sub reminder {
    my $vars = {};
    $vars->{nf}       = $nf;
    $vars->{company}  = $dbs->query( 'SELECT * FROM hc_companies WHERE comp_code=?', $comp_code )->hash;
    $vars->{invoices} = $dbs->query( "
        SELECT TO_CHAR(inv_date,'yymmdd')||inv_num id, hc_invoices.* 
        FROM hc_invoices WHERE comp_code=? AND ROUND(inv_amt - rec_amt,0) <> 0 ", $comp_code )->map_hashes('id');
    $vars->{tax}     = $dbs->query( "
        SELECT TO_CHAR(inv_date,'yymmdd')||i.inv_num id, i.inv_num, i.inv_date, i.inv_amt, r.rec_amt
        FROM hc_receipts_detail r, hc_invoices i
        WHERE r.inv_num = i.inv_num
        AND i.comp_code = ?
        AND i.inv_num IN (SELECT DISTINCT inv_num FROM hc_receipts_detail WHERE rec_type = 'TAX' AND gl_posted = 'N')
    ", $comp_code )->map_hashes('id');
    print $q->header();
    $tt->process( "$tmpl.tmpl", $vars ) || die $tt->error(), "\n";
}

#----------------------------------------
sub taxreminder {
    my $vars = {};
    $vars->{nf}      = $nf;
    $vars->{company} = $dbs->query( 'SELECT * FROM hc_companies WHERE comp_code=?', $comp_code )->hash;
    $vars->{tax}     = $dbs->query( "
        SELECT TO_CHAR(inv_date,'yymmdd')||i.inv_num id, i.inv_amt,
        (SELECT SUM(rec_amt) FROM hc_receipts_detail rd WHERE rd.inv_num = i.inv_num AND rd.rec_type <> 'TAX') rec_amt
        FROM hc_receipts_detail r, hc_invoices i
        WHERE r.inv_num = i.inv_num
        AND comp_code=? AND ROUND(inv_amt - rec_amt,0) <> 0
        AND inv_num IN (SELECT DISTINCT inv_num FROM hc_receipts_detail WHERE rec_type = 'TAX')
    ", $comp_code )->map_hashes('id');
    print $q->header();
    $tt->process( "$tmpl.tmpl", $vars ) || die $tt->error(), "\n";
}

#----------------------------------------
sub pr {
    my $vars = {};
    $vars->{nf}       = $nf;
    $vars->{hdr}      = $dbs->query( 'SELECT * FROM pr WHERE tr_num=?', $id )->hash;
    $vars->{company}  = $dbs->query( 'SELECT * FROM ap_vendors WHERE vendor_id=?', $vars->{hdr}->{vendor_id} )->hash;
    $vars->{dtl}      = $dbs->query( 'SELECT * FROM pr_lines WHERE tr_num = ?', $id )->map_hashes('id');
    $vars->{pr_amt}   = $dbs->query( 'SELECT SUM(req_qty*cost) FROM pr_lines WHERE tr_num = ?', $id )->list;
    $vars->{req_by}   = $dbs->query( 'SELECT loc_name FROM ic_locs WHERE loc_id = ?', $vars->{hdr}->{req_by} )->list;
    $vars->{store_id} = $dbs->query( 'SELECT loc_name FROM ic_locs WHERE loc_id = ?', $vars->{hdr}->{store_id} )->list;
    print $q->header();
    $tt->process( "$tmpl.tmpl", $vars ) || die $tt->error(), "\n";
}

#----------------------------------------
sub po {
    my $vars = {};
    $vars->{nf}      = $nf;
    $vars->{hdr}     = $dbs->query( 'SELECT * FROM po WHERE tr_num=?', $id )->hash;
    $vars->{company} = $dbs->query( 'SELECT * FROM ap_vendors WHERE vendor_id=?', $vars->{hdr}->{vendor_id} )->hash;
    $vars->{dtl}     = $dbs->query( 'SELECT * FROM po_lines WHERE tr_num = ?', $id )->map_hashes('id');
    print $q->header();
    $tt->process( "$tmpl.tmpl", $vars ) || die $tt->error(), "\n";
}

# EOF
