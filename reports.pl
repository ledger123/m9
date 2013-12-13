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
        INCLUDE_PATH => [ '/var/www/munshi9/tmpl', '/var/www/lighttpd/munshi9/tmpl' ],
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
    $vars->{hdr}->{setup_detail} =~ s/\n/<br>/g;
    print $q->header();
    $tt->process( "$tmpl.tmpl", $vars ) || die $tt->error(), "\n";
}

#----------------------------------------
sub fbchq {
    my $vars = {};
    $vars->{hdr} = $dbs->query( 'SELECT * FROM hc_fb_sale WHERE sale_id=?',       $id )->hash;
    $vars->{dtl} = $dbs->query( 'SELECT * FROM hc_fb_sale_lines WHERE sale_id=?', $id )->map_hashes('id');
    $vars->{user}   = $dbs->query("SELECT 'USER: ' || created_by || ' AT ' || TO_CHAR(creation_date, 'DD-MON-RR HH24:MI') FROM dual")->list;
    $vars->{outlet} = $dbs->query( 'SELECT outlet_name FROM hc_fb_outlets WHERE outlet_id = ?', $vars->{hdr}->{outlet_id} )->list;
    $vars->{sc_amt} = $dbs->query( 'SELECT ROUND(fsale_amt + bsale_amt + osale_amt * sc/100,2) FROM hc_fb_sale WHERE sale_id=?', $id )->list;

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
sub guestfolio {
    my $vars = {};
    $vars->{res} = $dbs->query( 'SELECT * FROM hc_res WHERE res_id=?', $id )->hash;
    $vars->{charges} = $dbs->query( 'SELECT * FROM hc_charges WHERE res_id=? ORDER BY charge_date', $id )->map_hashes('tr_num');
    print $q->header();
    $tt->process( "$tmpl.tmpl", $vars ) || die $tt->error(), "\n";
}

#----------------------------------------
sub regcard {
    my $vars = {};
    $vars->{res} = $dbs->query( 'SELECT * FROM hc_res WHERE res_id=?', $id )->hash;
    $vars->{checkin_time} = $dbs->query( "SELECT TO_CHAR(checkin_time2, 'DD-MON-YYYY HH24:MI:SS') FROM hc_res WHERE res_id = ?", $id )->list;
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
    $vars->{tax} = $dbs->query( "
        SELECT TO_CHAR(inv_date,'yymmdd')||i.inv_num id, i.inv_num, i.inv_date, i.inv_amt, r.rec_amt, r.other_ref1, r.other_ref2
        FROM hc_receipts_detail r, hc_invoices i
        WHERE r.inv_num = i.inv_num
        AND i.comp_code = ?
        AND r.rec_type = 'TAX'
        AND r.gl_posted = 'N'
        ORDER BY i.inv_num, i.inv_date
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
    $vars->{dtl}      = $dbs->query( 'SELECT pr_lines.*, ic_items.uom_stk_id unit FROM pr_lines, ic_items WHERE pr_lines.item_id = ic_items.item_id AND tr_num = ?', $id )->map_hashes('ln');
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

#----------------------------------------
sub report_header {

    my $report_title = shift;

    print $q->header();

    print qq|
<html>
<head>
 <title>$report_title</title>
 <link rel="stylesheet" href="/munshi9/standard.css" type="text/css">
<link rel="stylesheet" href="/munshi9/standard.css" type="text/css">
<link type="text/css" href="/munshi9/css/start/jquery-ui-1.8.10.custom.css" rel="Stylesheet" />
<script type="text/javascript" language="javascript" src="/munshi9/js/jquery-1.4.4.min.js"></script>
<script type="text/javascript" language="javascript" src="/munshi9/js/jquery.validate.min.js"></script>
<script type="text/javascript" language="javascript" src="/munshi9/js/jquery-ui-1.8.10.custom.min.js"></script>
<script type="text/javascript" language="javascript" src="/munshi9/js/jquery.tablesorter.min.js"></script>
|;

    print q|
<script type="text/javascript" charset="utf-8">
    $(document).ready(function() {
    $("input[type='text']:first", document.forms[0]).focus();
       $("#form1").validate();
    })
</script>
<script>
$(function() {
   $( ".datepicker" ).datepicker({
	dateFormat: 'd-M-yy',
	showOn: "button",
	buttonImage: "http://localhost/munshi9/css/calendar.gif",
	buttonImageOnly: true,
	showOtherMonths: true,
	selectOtherMonths: true,
	changeMonth: true,
	changeYear: true
   }); 

$(function(){
  $("#sortedtable").tablesorter();
});

});
</script>
</head>
|;
    print qq|
<body>
<h1>$report_title</h1>
|;

}

#----------------------------------------
# TODO:
#
sub sample_report {

    &report_header('Sample Report');

    my @columns        = qw(charge_code charge_date charge_desc amount);
    my @search_columns = qw(fromdate todate);

    my %sort_positions = {
        charge_code   => 1,
        charge_date   => 2,
        charge_desc   => 3,
        charge_amount => 4,
    };
    my $sort      = $q->param('sort') ? $q->param('sort') : 'charge_code';
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    print qq|
<form action="reports.pl" method="post">
From date: <input name=fromdate type=text size=12 class="datepicker" value="| . $q->param('fromdate') . qq|"><br/>
To date: <input name=todate type=text size=12 class="datepicker" value="| . $q->param('todate') . qq|"><br/>
Include: |;
    for (@columns) {
        $checked = ( $action eq 'Update' ) ? ( $q->param("l_$_") ? 'checked' : '' ) : 'checked';
        print qq|<input type=checkbox name=l_$_ value="1" $checked> | . ucfirst($_);
    }
    print qq|<br/>
    Subtotal: <input type=checkbox name=l_subtotal value="checked" | . $q->param('l_subtotal') . qq|><br/>
    <hr/>
    <input type=hidden name=nextsub value=$nextsub>
    <input type=submit name=action class=submit value="Update">
</form>
|;

    my @report_columns;
    for (@columns) { push @report_columns, $_ if $q->param("l_$_") }

    my $where = ' 1 = 1';
    my @bind  = ();

    if ( $q->param('fromdate') ) {
        $where .= qq| AND charge_date >= ?|;
        push @bind, $q->param('fromdate');
    }

    if ( $q->param('todate') ) {
        $where .= qq| AND charge_date <= ?|;
        push @bind, $q->param('todate');
    }

    my @allrows = $dbs->query(
        qq|
        SELECT  charge_code, charge_date, charge_desc, amount
        FROM hc_charges
        WHERE $where
        ORDER BY $sort_positions($sort) $sortorder
    |, @bind
    )->hashes;

    my @allrows = $dbs->query(
        qq|
        SELECT  charge_code, charge_date, charge_desc, amount
        FROM hc_charges 
        WHERE charge_date = '12-MAR-2013'
        AND rownum < 100
        ORDER BY $sort_positions($sort) $sortorder
    |
    )->hashes;

    my @total_columns = qw(amount);

    my %tabledata, %totals, %subtotals;

    my $url = "reports.pl?action=$action&nextsub=$nextsub&oldsort=$sort&sortorder=$sortorder&l_subtotal=" . $q->param(l_subtotal);
    for (@report_columns) { $url .= "&l_$_=" . $q->param("l_$_") if $q->param("l_$_") }
    for (@search_columns) { $url .= "&$_=" . $q->param("$_")     if $q->param("$_") }
    for (@report_columns) { $tabledata{$_} = qq|<th><a class="listheading" href="$url&sort=$_">| . ucfirst $_ . qq|</a></th>\n| }

    print qq|
        <table cellpadding="3" cellspacing="2">
        <tr class="listheading">
|;
    for (@report_columns) { print $tabledata{$_} }

    print qq|
        </tr>
|;

    my $groupvalue;
    for $row (@allrows) {
        $groupvalue = $row->{$sort} if !$groupvalue;
        if ( $q->param(l_subtotal) and $row->{$sort} ne $groupvalue ) {
            for (@report_columns) { $tabledata{$_} = qq|<td>&nbsp;</td>| }
            for (@total_columns) { $tabledata{$_} = qq|<th align="right">| . $nf->format_price( $subtotals{$_}, 2 ) . qq|</th>| }

            print qq|<tr class="listsubtotal">|;
            for (@report_columns) { print $tabledata{$_} }
            print qq|</tr>|;
            $groupvalue = $row->{$sort};
            for (@total_columns) { $subtotals{$_} = 0 }
        }
        for (@report_columns) { $tabledata{$_} = qq|<td>$row->{$_}</td>| }
        for (@total_columns) { $tabledata{$_} = qq|<td align="right">| . $nf->format_price( $row->{$_}, 2 ) . qq|</td>| }
        for (@total_columns) { $totals{$_}    += $row->{$_} }
        for (@total_columns) { $subtotals{$_} += $row->{$_} }

        print qq|<tr class="listrow0">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
    }

    for (@report_columns) { $tabledata{$_} = qq|<td>&nbsp;</td>| }
    for (@total_columns) { $tabledata{$_} = qq|<th align="right">| . $nf->format_price( $subtotals{$_}, 2 ) . qq|</th>| }

    print qq|<tr class="listsubtotal">|;
    for (@report_columns) { print $tabledata{$_} }
    print qq|</tr>|;

    for (@total_columns) { $tabledata{$_} = qq|<th align="right">| . $nf->format_price( $totals{$_}, 2 ) . qq|</th>| }
    print qq|<tr class="listtotal">|;
    for (@report_columns) { print $tabledata{$_} }
    print qq|</tr>|;
}

# EOF
