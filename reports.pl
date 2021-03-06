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
my $emp_num   = $q->param('emp_num');
my $comp_code = $q->param('comp_code');
my $dir       = $q->param('dir');
$dir = 'misc' if !$dir;

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
    $vars->{hdr}     = $dbs->query( 'SELECT * FROM banquet_header WHERE event_number=?',                          $id )->hash;
    $vars->{dtl}     = $dbs->query( 'SELECT * FROM banquet_lines WHERE event_number=?',                           $id )->map_hashes('id');
    $vars->{dayname} = $dbs->query( "SELECT TO_CHAR(event_date, 'DAY') FROM banquet_header WHERE event_number=?", $id )->list;
    $vars->{hdr}->{setup_detail} =~ s/\n/<br>/g;
    print $q->header();
    $tt->process( "$tmpl.tmpl", $vars ) || die $tt->error(), "\n";
}

#----------------------------------------
sub fbchq {
    my $vars = {};
    $vars->{nf}          = $nf;
    $vars->{hdr}         = $dbs->query( 'SELECT * FROM hc_fb_sale WHERE sale_id=?', $id )->hash;
    $vars->{guest_name1} = $dbs->query( 'SELECT guest_name1 FROM hc_res WHERE res_id=?', $vars->{hdr}->{res_id} )->list;
    $vars->{dtl}         = $dbs->query( 'SELECT * FROM hc_fb_sale_lines WHERE sale_id=?', $id )->map_hashes('id');
    $vars->{user}        = $dbs->query( "SELECT 'USER: ' || created_by || ' AT ' || TO_CHAR(creation_date, 'DD-MON-RR HH24:MI') FROM hc_fb_sale WHERE sale_id=?", $id )->list;
    $vars->{outlet}      = $dbs->query( 'SELECT outlet_name FROM hc_fb_outlets WHERE outlet_id = ?', $vars->{hdr}->{outlet_id} )->list;
    $vars->{sc_amt}      = $dbs->query( 'SELECT ROUND((fsale_amt + bsale_amt + osale_amt) * sc/100,2) FROM hc_fb_sale WHERE sale_id=?', $id )->list;

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
    ( $vars->{ramada_username}, $vars->{ramada_checkin_time} ) = $dbs->query( "SELECT a\$sec.get_user, TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') FROM hc_res WHERE res_id = ?", $id )->list;
    print $q->header();
    $tt->process( "$tmpl.tmpl", $vars ) || die $tt->error(), "\n";
}

#----------------------------------------
sub invoice {
    my $vars = {};

    my $taxper = $dbs->query("SELECT global_value FROM z_apps_data WHERE id='FB_TAX1_PER'")->list;
    my $taxper = 1 + ( $taxper / 100 );

    $vars->{nf}      = $nf;
    $vars->{hdr}     = $dbs->query( 'SELECT * FROM hc_invoices WHERE inv_num=?', $id )->hash;
    $vars->{company} = $dbs->query( 'SELECT * FROM hc_companies WHERE comp_code=?', $vars->{hdr}->{comp_code} )->hash;
    $vars->{dtl}     = $dbs->query( "
	SELECT to_char(charge_date, 'yymmdd')||room_num||tr_num id, tr_num, charge_date, res_id, guest_name1, other_ref1, other_ref2, room_num, 0-amount amount, ROUND((0-amount) / $taxper, 2) tax_amt
	FROM hc_charges WHERE bill_num=? AND sale_id = 0 ORDER BY 1", $id )->map_hashes('id');
    $vars->{chq} = $dbs->query( "
	SELECT to_char(sale_date, 'yymmdd')||sale_id id, hc_fb_sale.* FROM hc_fb_sale
	WHERE sale_id IN (SELECT sale_id FROM hc_charges WHERE bill_num = ?) ORDER BY 1", $id )->map_hashes('id') or die( $dbs->error );

    $vars->{receipts} = $dbs->query( "
	SELECT to_char(tr_date, 'yymmdd')||tr_num id, tr_num, tr_date, rec_type, rec_ref, rec_desc, rec_amt, other_ref1, other_ref2
	FROM hc_receipts_detail WHERE inv_num = ? ORDER BY 1", $id )->map_hashes('id') or die( $dbs->error );

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
    $vars->{nf} = $nf;
    $vars->{hdr} = $dbs->query( 'SELECT * FROM po WHERE tr_num=?', $id )->hash;
    $vars->{hdr}->{terms} =~ s/\n/<br>/g;
    $vars->{company} = $dbs->query( 'SELECT * FROM ap_vendors WHERE vendor_id=?', $vars->{hdr}->{vendor_id} )->hash;
    $vars->{dtl} = $dbs->query( '
        SELECT po_lines.*, ic_items.uom_stk_id unit
        FROM po_lines
        JOIN ic_items ON (ic_items.item_id = po_lines.item_id) 
        WHERE tr_num = ?', $id )->map_hashes('id');
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
	buttonImage: "/munshi9/css/calendar.gif",
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
sub runsql {
    &report_header('Sample Report');

    print qq|
<form action="reports.pl" method="post">
SQL: <textarea name="query">| . $q->param('query') . qq|</textarea>
    <hr/>
    <input type=hidden name=nextsub value=$nextsub>
    <input type=submit name=action class=submit value="Update">
</form>
|;
    my $query = $q->param('query');
    die('Invalid query') if $query =~ /(insert|update|delete|drop|create)/i;

    if ( $q->param('action') eq 'Update' ) {
        my $table = $dbs->query($query)->xto(
            table => { cellpadding => "5",          cellspacing => "2" },
            tr    => { class       => [ 'listrow0', 'listrow1' ] },
            th    => { class       => ['listheading'] },
        ) or die( $dbs->error );

        print $table->output;

    }
}

#----------------------------------------
sub sample_report {

    &report_header('Sample Report');

    my @columns        = qw(charge_code charge_date charge_desc amount);
    my @total_columns  = qw(amount);
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

    my $where = ' 1 = 1 ';
    $where = ' 1 = 2 ' if $action ne 'Update';    # Display data only when Update button is pressed.
    my @bind = ();

    if ( $q->param('fromdate') ) {
        $where .= qq| AND charge_date >= ?|;
        push @bind, $q->param('fromdate');
    }

    if ( $q->param('todate') ) {
        $where .= qq| AND charge_date <= ?|;
        push @bind, $q->param('todate');
    }

    my $query = qq|
        SELECT  charge_code, charge_date, charge_desc, amount
        FROM hc_charges
        WHERE $where
        ORDER BY $sort_positions($sort) $sortorder
    |;

    my @allrows = $dbs->query( $query, @bind )->hashes or die( $dbs->error );

    my ( %tabledata, %totals, %subtotals );

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
    my $i = 0;
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

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#----------------------------------------
sub business_analysis {

    &report_header('Business Analysis Report');

    my @columns        = qw(payment_mode res_id room_num comp_code company checkin_date checkout_date room_rate adults nights amount);
    my @total_columns  = qw(adults room_rate nights amount);
    my @search_columns = qw(fromdate todate payment_mode);

    my %sort_positions = {
        payment_mode  => 1,
        res_id        => 2,
        room_num      => 3,
        comp_code     => 4,
        company       => 5,
        checkin_date  => 6,
        checkout_date => 7,
        room_rate     => 8,
        adults        => 9,
        nights        => 10,
        amount        => 11,
    };
    my $sort      = $q->param('sort') ? $q->param('sort') : 'payment_mode';
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    print qq|
<form action="reports.pl" method="post">
From charge date: <input name=fromdate type=text size=12 class="datepicker" value="| . $q->param('fromdate') . qq|"><br/>
To charge date: <input name=todate type=text size=12 class="datepicker" value="| . $q->param('todate') . qq|"><br/>
Payment Mode: <select name="payment_mode">| . lookup1( 'PAYMENT_MODE', $q->param('payment_mode') ) . qq|</select><br/>
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

    my $where = ' 1 = 1 ';
    $where = ' 1 = 2 ' if $action ne 'Update';    # Display data only when Update button is pressed.
    my @bind = ();

    if ( $q->param('fromdate') ) {
        $where .= qq| AND c.charge_date >= ?|;
        push @bind, $q->param('fromdate');
    }

    if ( $q->param('todate') ) {
        $where .= qq| AND c.charge_date <= ?|;
        push @bind, $q->param('todate');
    }

    if ( $q->param('payment_mode') ) {
        $where .= qq| AND r.payment_mode = ?|;
        push @bind, $q->param('payment_mode');
    }

    my $query = qq|
        SELECT r.payment_mode, r.res_id, r.room_num, r.comp_code, r.company, r.checkin_date, r.checkout_date, r.room_rate, r.adults, COUNT(*) nights, SUM(c.amount) amount
        FROM hc_res r
        JOIN hc_charges c ON (c.res_id = r.res_id)
        WHERE $where
        AND c.charge_code = '101'
        GROUP BY r.payment_mode, r.res_id, r.room_num, r.comp_code, r.company, r.checkin_date, r.checkout_date, r.room_rate, r.adults
        ORDER BY $sort_positions($sort) $sortorder
    |;

    my @allrows = $dbs->query( $query, @bind )->hashes or die( $dbs->error );

    my ( %tabledata, %totals, %subtotals );

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
    my $i = 0;
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

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#----------------------------------------
sub revenue_summary {

    &report_header('Room Revenue Summary');

    my @columns        = qw(comp_code company ntn rooms foodbev others salestax bedtax banquettax total);
    my @total_columns  = qw(rooms foodbev others salestax bedtax banquettax total);
    my @search_columns = qw(fromdate todate);

    my %sort_positions = {
        comp_code => 1,
        company   => 2,
        rooms     => 3,
    };

    my $sort      = $q->param('sort') ? $q->param('sort') : 'payment_mode';
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    print qq|
<form action="reports.pl" method="post">
From charge date: <input name=fromdate type=text size=12 class="datepicker" value="| . $q->param('fromdate') . qq|"><br/>
To charge date: <input name=todate type=text size=12 class="datepicker" value="| . $q->param('todate') . qq|"><br/>
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

    my $where = ' AND 1 = 1 ';
    $where = ' AND 1 = 2 ' if $action ne 'Update';    # Display data only when Update button is pressed.
    my @bind = ();

    if ( $q->param('fromdate') ) {
        $where .= qq| AND ch.charge_date >= ?|;
        push @bind, $q->param('fromdate');
    }

    if ( $q->param('todate') ) {
        $where .= qq| AND ch.charge_date <= ?|;
        push @bind, $q->param('todate');
    }

    my $query = qq|
        SELECT co.comp_code, co.company, co.ntn,
             (SELECT SUM(amount) FROM hc_charges ch 
             WHERE ch.charge_code IN (SELECT charge_code FROM hc_charge_codes WHERE gl_group IN ('ROOM'))
             $where
             AND ch.comp_code = co.comp_code) rooms,

             (SELECT SUM(amount) FROM hc_charges ch
             WHERE ch.charge_code IN (SELECT charge_code FROM hc_charge_codes WHERE gl_group IN ('F','B'))
             $where
             AND ch.comp_code = co.comp_code) foodbev,

             (SELECT SUM(amount) FROM hc_charges ch
             WHERE ch.charge_code IN (SELECT charge_code FROM hc_charge_codes WHERE gl_group IN ('O'))
             $where
             AND ch.comp_code = co.comp_code) others,

             (SELECT SUM(amount) FROM hc_charges ch
             WHERE ch.charge_code IN (SELECT charge_code FROM hc_charge_codes WHERE gl_group IN ('STAX'))
             $where
             AND ch.comp_code = co.comp_code) salestax,

             (SELECT SUM(amount) FROM hc_charges ch
             WHERE ch.charge_code IN (SELECT charge_code FROM hc_charge_codes WHERE gl_group IN ('BEDTAX'))
             $where
             AND ch.comp_code = co.comp_code) bedtax,

             (SELECT SUM(amount) FROM hc_charges ch
             WHERE ch.charge_code IN (SELECT charge_code FROM hc_charge_codes WHERE gl_group IN ('BANQTAX'))
             $where
             AND ch.comp_code = co.comp_code) banquettax,

             (SELECT SUM(amount) FROM hc_charges ch
             WHERE ch.charge_code IN (SELECT charge_code FROM hc_charge_codes WHERE gl_group IN ('ROOM', 'F', 'B', 'O', 'STAX', 'BEDTAX', 'BANQTAX'))
             $where
             AND ch.comp_code = co.comp_code) total

          FROM hc_companies co
          WHERE co.comp_code IN (SELECT DISTINCT comp_code FROM hc_charges ch WHERE 1 = 1 $where)
         ORDER BY 1,2
    |;

    #        WHERE $where
    #        ORDER BY $sort_positions($sort) $sortorder

    my @allbinds = ( @bind, @bind, @bind, @bind, @bind, @bind, @bind, @bind );
    my @allrows = $dbs->query( $query, @allbinds )->hashes or die( $dbs->error );

    my ( %tabledata, %totals, %subtotals );

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
    my $i = 0;
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

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#----------------------------------------
sub lookup1 {
    my ( $cname, $default ) = @_;
    my @rows = $dbs->query( q|SELECT cval FROM a$lookup WHERE cname = ? ORDER BY seq|, $cname )->hashes;
    my $option = qq|<option>\n|;
    for $row (@rows) {
        if ( $row->{cval} eq $default ) {
            $option .= qq|<option value="$row->{cval}" selected>$row->{cval}\n|;
        }
        else {
            $option .= qq|<option value="$row->{cval}">$row->{cval}\n|;
        }
    }
    $option;
}

#----------------------------------------
sub entlist {

    &report_header('Officer / Entertainment Report');

    my @columns        = qw(sale_date chq_num covers type1 type2 table_num food_amt bev_amt sale_amt);
    my @total_columns  = qw(covers food_amt bev_amt sale_amt);
    my @search_columns = qw(fromdate todate);

    my %sort_positions = {
        sale_date => 1,
        chq_num   => 2,
        covers    => 3,
        type1     => 4,
        type2     => 5,
        table_num => 6,
        food_amt  => 7,
        bev_amt   => 8,
        sale_amt  => 9,
    };

    my $sort      = $q->param('sort') ? $q->param('sort') : 'sale_date';
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    print qq|
<form action="reports.pl" method="post">
From date: <input name=fromdate type=text size=12 class="datepicker" value="| . $q->param('fromdate') . qq|"><br/>
To date: <input name=todate type=text size=12 class="datepicker" value="| . $q->param('todate') . qq|"><br/>
Chq Type1: <select name="type1">| . lookup1( 'FLAG1', $q->param('type1') ) . qq|</select><br/>
Chq Type2: <select name="type2">| . lookup1( 'FLAG2', $q->param('type2') ) . qq|</select><br/>
Table: <input name=table_num type=text size=15 value="| . $q->param('table_num') . qq|"><br/>
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

    my $where = ' 1 = 1 ';
    $where = ' 1 = 2 ' if $action ne 'Update';    # Display data only when Update button is pressed.
    my @bind = ();

    if ( $q->param('fromdate') ) {
        $where .= qq| AND sale_date >= ?|;
        push @bind, $q->param('fromdate');
    }

    if ( $q->param('todate') ) {
        $where .= qq| AND sale_date <= ?|;
        push @bind, $q->param('todate');
    }

    if ( $q->param('type1') ) {
        $where .= qq| AND flag1 = ?|;
        push @bind, $q->param('type1');
    }

    if ( $q->param('type2') ) {
        $where .= qq| AND flag4 = ?|;
        push @bind, $q->param('type2');
    }

    if ( $q->param('table_num') ) {
        $where .= qq| AND UPPER(table_num) = ?|;
        push @bind, uc $q->param('table_num');
    }

    my $query = qq|
            SELECT sale_date, chq_num, covers, 
                    flag1 type1, flag4 type2, table_num,
                    fsale_amt food_amt, bsale_amt bev_amt, sale_amt
            FROM hc_fb_sale
            WHERE $where
            AND outlet_id = 'OFF/ENT'
            ORDER BY $sort_positions($sort) $sortorder
    |;

    my @allrows = $dbs->query( $query, @bind )->hashes or die( $dbs->error );

    my ( %tabledata, %totals, %subtotals );

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
    my $i = 0;
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

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#----------------------------------------
sub store_dept_cat_issues {

    &report_header('Category wise Issues Summary');

    my @columns        = qw(store dept item_cat cat_desc net_cost);
    my @total_columns  = qw(net_cost);
    my @search_columns = qw(fromdate todate iss_loc_id rec_loc_id item_cat);

    my %sort_positions = {
        store    => 1,
        dept     => 2,
        item_cat => 3,
        cat_desc => 4,
        cost_amt => 5,
        tax_amt  => 6,
        net_amt  => 7,
    };

    my $sort      = $q->param('sort') ? $q->param('sort') : 'store';
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    print qq|
<form action="reports.pl" method="post">
<table>
<tr><th align="right">From date</th><td><input name=fromdate type=text size=12 class="datepicker" value="| . $q->param('fromdate') . qq|"></td></tr>
<tr><th align="right">To date</th><td><input name=todate type=text size=12 class="datepicker" value="| . $q->param('todate') . qq|"></td></tr>
<tr><th align="right">Store</th><td><input name=iss_loc_id type=text size=12 value="| . $q->param('iss_loc_id') . qq|"></td></tr>
<tr><th align="right">Department</th><td><input name=rec_loc_id type=text size=12 value="| . $q->param('rec_loc_id') . qq|"></td></tr>
<tr><th align="right">Category</th><td><input name=item_cat type=text size=12 value="| . $q->param('item_cat') . qq|"></td></tr>
<tr><th align="right">Include</th><td>|;
    for (@columns) {
        $checked = ( $action eq 'Update' ) ? ( $q->param("l_$_") ? 'checked' : '' ) : 'checked';
        print qq|<input type=checkbox name=l_$_ value="1" $checked> | . ucfirst($_);
    }
    print qq|</td></tr>
    <tr><th align="right">Subtotal</th><td><input type=checkbox name=l_subtotal value="checked" | . $q->param('l_subtotal') . qq|></td></tr>
</table>
    <hr/>
    <input type=hidden name=nextsub value=$nextsub>
    <input type=submit name=action class=submit value="Update">
</form>
|;

    my @report_columns;
    for (@columns) { push @report_columns, $_ if $q->param("l_$_") }

    my $where = ' 1 = 1 ';
    $where = ' 1 = 2 ' if $action ne 'Update';    # Display data only when Update button is pressed.
    my @bind = ();

    if ( $q->param('fromdate') ) {
        $where .= qq| AND h.tr_date >= ?|;
        push @bind, $q->param('fromdate');
    }
    if ( $q->param('todate') ) {
        $where .= qq| AND h.tr_date <= ?|;
        push @bind, $q->param('todate');
    }
    if ( $q->param('iss_loc_id') ) {
        $where .= qq| AND h.iss_loc_id LIKE ?|;
        push @bind, $q->param('iss_loc_id');
    }
    if ( $q->param('rec_loc_id') ) {
        $where .= qq| AND h.rec_loc_id LIKE ?|;
        push @bind, $q->param('rec_loc_id');
    }
    if ( $q->param('item_cat') ) {
        $where .= qq| AND h.item_cat LIKE ?|;
        push @bind, $q->param('item_cat');
    }

    my $query = qq|
            SELECT  h.iss_loc_id store, h.rec_loc_id dept, c.item_cat, c.cat_desc, SUM(l.net_cost) net_cost
                FROM ic_trans_lines_tmp l 
                JOIN ic_trans_header_tmp h ON (h.tr_num = l.tr_num)
                JOIN ic_items i ON (i.item_id = l.item_id)
                JOIN ic_items_cats c ON (c.item_cat = i.item_cat)
               WHERE $where
               AND h.tr_type = 'ISSUE'
               GROUP BY h.iss_loc_id, h.rec_loc_id, c.item_cat, c.cat_desc
               ORDER BY $sort_positions($sort) $sortorder
    |;

    my @allrows = $dbs->query( $query, @bind )->hashes or die( $dbs->error );

    my ( %tabledata, %totals, %subtotals );

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
    my $i = 0;
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

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#----------------------------------------
sub store_dept_cat_issues_dp {

    &report_header('Direct Purchases Summary');

    my @columns        = qw(store dept item_cat cat_desc net_cost);
    my @total_columns  = qw(net_cost);
    my @search_columns = qw(fromdate todate iss_loc_id rec_loc_id item_cat);

    my %sort_positions = {
        store    => 1,
        dept     => 2,
        item_cat => 3,
        cat_desc => 4,
        cost_amt => 5,
        tax_amt  => 6,
        net_amt  => 7,
    };

    my $sort      = $q->param('sort') ? $q->param('sort') : 'store';
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    print qq|
<form action="reports.pl" method="post">
<table>
<tr><th align="right">From date</th><td><input name=fromdate type=text size=12 class="datepicker" value="| . $q->param('fromdate') . qq|"></td></tr>
<tr><th align="right">To date</th><td><input name=todate type=text size=12 class="datepicker" value="| . $q->param('todate') . qq|"></td></tr>
<tr><th align="right">Store</th><td><input name=iss_loc_id type=text size=12 value="| . $q->param('iss_loc_id') . qq|"></td></tr>
<tr><th align="right">Department</th><td><input name=rec_loc_id type=text size=12 value="| . $q->param('rec_loc_id') . qq|"></td></tr>
<tr><th align="right">Category</th><td><input name=item_cat type=text size=12 value="| . $q->param('item_cat') . qq|"></td></tr>
<tr><th align="right">Include</th><td>|;
    for (@columns) {
        $checked = ( $action eq 'Update' ) ? ( $q->param("l_$_") ? 'checked' : '' ) : 'checked';
        print qq|<input type=checkbox name=l_$_ value="1" $checked> | . ucfirst($_);
    }
    print qq|</td></tr>
    <tr><th align="right">Subtotal</th><td><input type=checkbox name=l_subtotal value="checked" | . $q->param('l_subtotal') . qq|></td></tr>
</table>
    <hr/>
    <input type=hidden name=nextsub value=$nextsub>
    <input type=submit name=action class=submit value="Update">
</form>
|;

    my @report_columns;
    for (@columns) { push @report_columns, $_ if $q->param("l_$_") }

    my $where = ' 1 = 1 ';
    $where = ' 1 = 2 ' if $action ne 'Update';    # Display data only when Update button is pressed.
    my @bind = ();

    if ( $q->param('fromdate') ) {
        $where .= qq| AND h.tr_date >= ?|;
        push @bind, $q->param('fromdate');
    }
    if ( $q->param('todate') ) {
        $where .= qq| AND h.tr_date <= ?|;
        push @bind, $q->param('todate');
    }
    if ( $q->param('iss_loc_id') ) {
        $where .= qq| AND h.iss_loc_id LIKE ?|;
        push @bind, $q->param('iss_loc_id');
    }
    if ( $q->param('rec_loc_id') ) {
        $where .= qq| AND h.rec_loc_id LIKE ?|;
        push @bind, $q->param('rec_loc_id');
    }
    if ( $q->param('item_cat') ) {
        $where .= qq| AND h.item_cat LIKE ?|;
        push @bind, $q->param('item_cat');
    }

    my $query = qq|
            SELECT  h.iss_loc_id store, h.rec_loc_id dept, c.item_cat, c.cat_desc, SUM(l.net_cost) net_cost
                FROM ic_trans_lines_tmp l 
                JOIN ic_trans_header_tmp h ON (h.tr_num = l.tr_num)
                JOIN ic_items i ON (i.item_id = l.item_id)
                JOIN ic_items_cats c ON (c.item_cat = i.item_cat)
               WHERE $where
               AND h.tr_type = 'PURCHASE'
               AND l.item_id LIKE 'DP-%'
               GROUP BY h.iss_loc_id, h.rec_loc_id, c.item_cat, c.cat_desc
               ORDER BY $sort_positions($sort) $sortorder
    |;

    my @allrows = $dbs->query( $query, @bind )->hashes or die( $dbs->error );

    my ( %tabledata, %totals, %subtotals );

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
    my $i = 0;
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

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#----------------------------------------
sub store_dept_cat_issues_dp_detail {

    &report_header('Direct Purchases Detail');

    my @columns        = qw(dept item_id item_name qty net_cost);
    my @total_columns  = qw(qty net_cost);
    my @search_columns = qw(fromdate todate iss_loc_id rec_loc_id item_cat);

    my %sort_positions = {
        dept      => 1,
        item_id   => 2,
        item_name => 3,
        qty       => 4,
        net_amt   => 5,
    };

    my $sort      = $q->param('sort') ? $q->param('sort') : 'dept';
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    print qq|
<form action="reports.pl" method="post">
<table>
<tr><th align="right">From date</th><td><input name=fromdate type=text size=12 class="datepicker" value="| . $q->param('fromdate') . qq|"></td></tr>
<tr><th align="right">To date</th><td><input name=todate type=text size=12 class="datepicker" value="| . $q->param('todate') . qq|"></td></tr>
<tr><th align="right">Store</th><td><input name=iss_loc_id type=text size=12 value="| . $q->param('iss_loc_id') . qq|"></td></tr>
<tr><th align="right">Department</th><td><input name=rec_loc_id type=text size=12 value="| . $q->param('rec_loc_id') . qq|"></td></tr>
<tr><th align="right">Category</th><td><input name=item_cat type=text size=12 value="| . $q->param('item_cat') . qq|"></td></tr>
<tr><th align="right">Include</th><td>|;
    for (@columns) {
        $checked = ( $action eq 'Update' ) ? ( $q->param("l_$_") ? 'checked' : '' ) : 'checked';
        print qq|<input type=checkbox name=l_$_ value="1" $checked> | . ucfirst($_);
    }
    print qq|</td></tr>
    <tr><th align="right">Subtotal</th><td><input type=checkbox name=l_subtotal value="checked" | . $q->param('l_subtotal') . qq|></td></tr>
</table>
    <hr/>
    <input type=hidden name=nextsub value=$nextsub>
    <input type=submit name=action class=submit value="Update">
</form>
|;

    my @report_columns;
    for (@columns) { push @report_columns, $_ if $q->param("l_$_") }

    my $where = ' 1 = 1 ';
    $where = ' 1 = 2 ' if $action ne 'Update';    # Display data only when Update button is pressed.
    my @bind = ();

    if ( $q->param('fromdate') ) {
        $where .= qq| AND h.tr_date >= ?|;
        push @bind, $q->param('fromdate');
    }
    if ( $q->param('todate') ) {
        $where .= qq| AND h.tr_date <= ?|;
        push @bind, $q->param('todate');
    }
    if ( $q->param('iss_loc_id') ) {
        $where .= qq| AND h.iss_loc_id LIKE ?|;
        push @bind, $q->param('iss_loc_id');
    }
    if ( $q->param('rec_loc_id') ) {
        $where .= qq| AND h.rec_loc_id LIKE ?|;
        push @bind, $q->param('rec_loc_id');
    }
    if ( $q->param('item_cat') ) {
        $where .= qq| AND h.item_cat LIKE ?|;
        push @bind, $q->param('item_cat');
    }

    my $query = qq|
            SELECT  h.rec_loc_id dept, l.item_id, i.item_name, SUM(l.qty) qty, SUM(l.net_cost) net_cost
                FROM ic_trans_lines_tmp l 
                JOIN ic_trans_header_tmp h ON (h.tr_num = l.tr_num)
                JOIN ic_items i ON (i.item_id = l.item_id)
                JOIN ic_items_cats c ON (c.item_cat = i.item_cat)
               WHERE $where
               AND h.tr_type = 'PURCHASE'
               AND l.item_id LIKE 'DP-%'
               GROUP BY h.rec_loc_id, l.item_id, i.item_name
               ORDER BY $sort_positions($sort) $sortorder
    |;

    my @allrows = $dbs->query( $query, @bind )->hashes or die( $dbs->error );

    my ( %tabledata, %totals, %subtotals );

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
    my $i = 0;
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

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#----------------------------------------
sub history1 {

    &report_header('History Report');

    my @columns        = qw(res_id room guest1 mobile dob company email nation passport cnic);
    my @total_columns  = qw();
    my @search_columns = qw(fromdate todate);

    my %sort_positions = {
        res_id   => 1,
        room     => 2,
        guest1   => 3,
        mobile   => 4,
        dob      => 5,
        company  => 6,
        email    => 7,
        nation   => 8,
        passport => 9,
        cnic     => 10,
    };

    my $sort      = $q->param('sort') ? $q->param('sort') : 'room';
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

    my $where = ' 1 = 1 ';
    $where = ' 1 = 2 ' if $action ne 'Update';    # Display data only when Update button is pressed.
    my @bind = ();

    if ( $q->param('fromdate') ) {
        $where .= qq| AND h.checkin_date >= ?|;
        push @bind, $q->param('fromdate');
    }

    if ( $q->param('todate') ) {
        $where .= qq| AND h.checkin_date <= ?|;
        push @bind, $q->param('todate');
    }

    my $munshi9_url = $dbs->query( "select global_value from z_apps_data where id=?", 'MUNSHI9_URL' )->list;
    my $query = qq~
            SELECT   '<a href="http://$munshi9_url:8000/munshi9/a\$hc_res.frm?f_res_id='||res_id||'">'||res_id||'</a>' res_id, room_num room, guest_name1 guest1,
                     mobile, dob, company,
                     email, nation, passport,
                     nid_num cnic
                FROM hc_res h
               WHERE checked_in = 'Y'
                 AND room_num NOT IN ('CTL', 'NA')
                 AND $where
               ORDER BY $sort_positions($sort) $sortorder
    ~;

    my @allrows = $dbs->query( $query, @bind )->hashes;

    my ( %tabledata, %totals, %subtotals );

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
    my $i = 0;
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
        for (@report_columns) { $tabledata{$_} = qq|<td nowrap>$row->{$_}</td>| }
        for (@total_columns) { $tabledata{$_} = qq|<td align="right">| . $nf->format_price( $row->{$_}, 2 ) . qq|</td>| }
        for (@total_columns) { $totals{$_}    += $row->{$_} }
        for (@total_columns) { $subtotals{$_} += $row->{$_} }

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#----------------------------------------
sub history2 {

    &report_header('Banquet History Report');

    my @columns        = qw(event_number event_type event_date contact_person phone1 mobile email);
    my @total_columns  = qw();
    my @search_columns = qw(fromdate todate);

    my %sort_positions = {
        event_number   => 1,
        event_type     => 2,
        event_date     => 3,
        contact_person => 4,
        phone1         => 5,
        mobile         => 6,
        email          => 7,
    };

    my $sort      = $q->param('sort') ? $q->param('sort') : 'event_number';
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    print qq|
<form action="reports.pl" method="post">
From event date: <input name=fromdate type=text size=12 class="datepicker" value="| . $q->param('fromdate') . qq|"><br/>
To to date: <input name=todate type=text size=12 class="datepicker" value="| . $q->param('todate') . qq|"><br/>

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

    my $where = ' 1 = 1 ';
    $where = ' 1 = 2 ' if $action ne 'Update';    # Display data only when Update button is pressed.
    my @bind = ();

    if ( $q->param('fromdate') ) {
        $where .= qq| AND h.event_date >= ?|;
        push @bind, $q->param('fromdate');
    }

    if ( $q->param('todate') ) {
        $where .= qq| AND h.event_date <= ?|;
        push @bind, $q->param('todate');
    }

    my $query = qq|
              SELECT event_number, event_type, event_date, contact_person, phone1, mobile, email
                FROM banquet_header h
               WHERE $where
               ORDER BY $sort_positions($sort) $sortorder
    |;

    my @allrows = $dbs->query( $query, @bind )->hashes;

    my ( %tabledata, %totals, %subtotals );

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
    my $i = 0;
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
        for (@report_columns) { $tabledata{$_} = qq|<td nowrap>$row->{$_}</td>| }
        for (@total_columns) { $tabledata{$_} = qq|<td align="right">| . $nf->format_price( $row->{$_}, 2 ) . qq|</td>| }
        for (@total_columns) { $totals{$_}    += $row->{$_} }
        for (@total_columns) { $subtotals{$_} += $row->{$_} }

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#----------------------------------------
sub inhouse_summary {

    &report_header('Inhouse Summary');

    my @columns       = qw(res_id room room_type guest1 guest2 cnic passport group_id nation purpose next_dest checkin_remarks address mobile company billing payment pax rate checkin chkin_time user_name checkout);
    my @total_columns = qw(rate);

    my %sort_positions = {
        res_id     => 1,
        room       => 2,
        room_type  => 3,
        guest1     => 4,
        guest2     => 5,
        cnic       => 6,
        passport   => 7,
        group_id   => 8,
        nation     => 9,
        purpose     => 10,
        next_dest     => 11,
        checkin_remarks     => 12,
        address    => 13,
        mobile     => 14,
        company    => 15,
        billing    => 16,
        payment    => 17,
        pax        => 18,
        rate       => 19,
        checkin    => 20,
        chkin_time => 21,
        user_name  => 22,
        checkout   => 23,
    };

    my $sort      = $q->param('sort') ? $q->param('sort') : 'room';
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    print qq|
<form action="reports.pl" method="post">
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

    my $where = ' 1 = 1 ';
    $where = ' 1 = 2 ' if $action ne 'Update';    # Display data only when Update button is pressed.
    my @bind = ();

    if ( $q->param('fromdate') ) {
        $where .= qq| AND h.tr_date >= ?|;
        push @bind, $q->param('fromdate');
    }

    if ( $q->param('todate') ) {
        $where .= qq| AND h.tr_date <= ?|;
        push @bind, $q->param('todate');
    }

    my $query = qq|
            SELECT   hc_res.res_id, hc_res.room_num room, hc_res.room_type, hc_res.guest_name1 guest1, 
                     hc_res.guest_name2 guest2, nid_num cnic, passport, hc_res.GROUP_ID, hc_res.address, hc_res.mobile, hc_res.nation,
		     hc_res.purpose, hc_res.next_dest, hc_res.checkin_remarks,
                     hc_res.company, hc_res.billing_ins billing, hc_res.payment_mode payment, 
                     hc_res.adults pax, hc_res.room_rate rate, hc_res.checkin_date checkin, 
                     TO_CHAR(checkin_time2, 'HH24:MI') chkin_time, hc_res.created_by user_name, checkout_date checkout
                FROM hc_res
               WHERE hc_res.checked_in = 'Y'
                 AND hc_res.checked_out = 'N'
                 AND room_num NOT IN ('ADV', 'CTL', 'GM', 'LUD', 'NA', 'CTLR', 'ECB', 'SPR', 'GL')
                 AND $where
               ORDER BY $sort_positions($sort) $sortorder
    |;

    my @allrows = $dbs->query( $query, @bind )->hashes or die( $dbs->error );

    my ( %tabledata, %totals, %subtotals );

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
    my $i = 0;
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

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#----------------------------------------
sub expected_arrivals {

    &report_header('Expected Arrivals');

    my @columns       = qw(res_id room type guest1 guest2 grp company billing payment pax rate arrival vip usr checkout);
    my @total_columns = qw(rate);

    my %sort_positions = {
        res_id   => 1,
        room     => 2,
        type     => 3,
        guest1   => 4,
        guest2   => 5,
        grp      => 6,
        company  => 7,
        billing  => 8,
        payment  => 9,
        pax      => 10,
        rate     => 11,
        arrival  => 12,
        vip      => 13,
        usr      => 14,
        checkout => 15,
    };

    my $sort      = $q->param('sort') ? $q->param('sort') : 'room';
    my $vip       = $q->param('vip');
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    my $arrival_date;
    if ( $q->param('arrival_date') ) {
        $arrival_date = $q->param('arrival_date');
    }
    else {
        $arrival_date = $dbs->query("SELECT global_value FROM z_apps_data WHERE id='HC_SYSDATE'")->list;
    }

    my $arrival_date2;
    if ( $q->param('arrival_date2') ) {
        $arrival_date2 = $q->param('arrival_date2');
    }
    else {
        $arrival_date2 = $dbs->query("SELECT global_value FROM z_apps_data WHERE id='HC_SYSDATE'")->list;
    }

    print qq|
<form action="reports.pl" method="post">
Include: |;
    for (@columns) {
        $checked = ( $action eq 'Update' ) ? ( $q->param("l_$_") ? 'checked' : '' ) : 'checked';
        $checked = '' if $_ =~ /(guest2|billing|usr)/;
        print qq|<input type=checkbox name=l_$_ value="1" $checked> | . ucfirst($_);
    }
    print qq|<br/>
    From Arrival date: <input type=text class=datepicker name="arrival_date" size=12 value="$arrival_date"><br/>
    To Arrival date: <input type=text class=datepicker name="arrival_date2" size=12 value="$arrival_date2"><br/>
    VIP: <input type=text size=3 name=vip value="$vip"> (Y or N)<br/>
    Subtotal: <input type=checkbox name=l_subtotal value="checked" | . $q->param('l_subtotal') . qq|><br/>
    <hr/>
    <input type=hidden name=nextsub value=$nextsub>
    <input type=submit name=action class=submit value="Update">
</form>
|;

    my @report_columns;
    for (@columns) { push @report_columns, $_ if $q->param("l_$_") }

    my $where = ' 1 = 1 ';
    $where = ' 1 = 2 ' if $action ne 'Update';    # Display data only when Update button is pressed.
    my @bind = ();

    if ( $q->param('arrival_date') ) {
        $where .= qq| AND hc_res.arrival_date >= ?|;
        push @bind, $q->param('arrival_date');
    }

    if ( $q->param('arrival_date2') ) {
        $where .= qq| AND hc_res.arrival_date <= ?|;
        push @bind, $q->param('arrival_date2');
    }

    if ( $q->param('vip') ) {
        $where .= qq| AND hc_res.vip = ?|;
        push @bind, $q->param('vip');
    }

    my $query = qq|
            SELECT   hc_res.res_id, hc_res.room_num room, hc_res.room_type type, hc_res.guest_name1 guest1, 
                     hc_res.guest_name2 guest2, hc_res.GROUP_ID grp, hc_res.vip,
                     hc_res.company, hc_res.billing_ins billing, hc_res.payment_mode pymt, 
                     hc_res.adults pax, hc_res.room_rate rate, hc_res.arrival_date arrival, 
                     hc_res.created_by usr, checkout_date checkout
                FROM hc_res
               WHERE hc_res.res_status = 'Active'
                 AND $where
               ORDER BY $sort_positions($sort) $sortorder
    |;

    my @allrows = $dbs->query( $query, @bind )->hashes;

    my ( %tabledata, %totals, %subtotals );

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
    my $i = 0;
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
        for (@report_columns) { $tabledata{$_} = qq|<td nowrap>$row->{$_}</td>| }
        for (@total_columns) { $tabledata{$_} = qq|<td align="right" nowrap>| . $nf->format_price( $row->{$_}, 2 ) . qq|</td>| }
        $tabledata{billing} = qq|<td>$row->{billing}</td>|;    # wrapped
        for (@total_columns) { $totals{$_}    += $row->{$_} }
        for (@total_columns) { $subtotals{$_} += $row->{$_} }

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#----------------------------------------
sub dayuse_guests {

    &report_header('Day use guests');

    my @columns        = qw(checkin res_id room type guest1 guest2 comp_code company pax amount);
    my @total_columns  = qw(amount);
    my @search_columns = qw(fromdate todate comp_code);

    my %sort_positions = {
        checkin   => 1,
        res_id    => 2,
        room      => 3,
        type      => 4,
        guest1    => 5,
        guest2    => 6,
        comp_code => 7,
        company   => 8,
        pax       => 9,
        amount    => 10,
    };

    my $sort      = $q->param('sort') ? $q->param('sort') : 'checkin';
    my $vip       = $q->param('vip');
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    my $fromdate;
    my $todate;
    if ( $q->param('fromdate') ) {
        $fromdate = $q->param('fromdate');
        $todate   = $q->param('todate');
    }
    else {
        $fromdate = $dbs->query("SELECT global_value FROM z_apps_data WHERE id='HC_SYSDATE'")->list;
        $todate   = $fromdate;
    }

    print qq|
<form action="reports.pl" method="post">
Include: |;
    for (@columns) {
        $checked = ( $action eq 'Update' ) ? ( $q->param("l_$_") ? 'checked' : '' ) : 'checked';
        $checked = '' if $_ =~ /(guest2|billing|usr)/;
        print qq|<input type=checkbox name=l_$_ value="1" $checked> | . ucfirst($_);
    }
    print qq|<br/>
    From date: <input type=text class=datepicker name="fromdate" size=12 value="$fromdate"><br/>
    To date: <input type=text class=datepicker name="todate" size=12 value="$todate"><br/>
    Company Code: <input type=text name="comp_code" size=8 value="| . $q->param('comp_code') . qq|"><br/>
    Subtotal: <input type=checkbox name=l_subtotal value="checked"| . $q->param('l_subtotal') . qq|><br/>
    <hr/>
    <input type=hidden name=nextsub value=$nextsub>
    <input type=submit name=action class=submit value="Update">
</form>
|;

    my @report_columns;
    for (@columns) { push @report_columns, $_ if $q->param("l_$_") }

    my $where = ' 1 = 1 ';
    $where = ' 1 = 2 ' if $action ne 'Update';    # Display data only when Update button is pressed.
    my @bind = ();

    if ( $q->param('fromdate') ) {
        $where .= qq| AND r.checkin_date >= ?|;
        push @bind, $q->param('fromdate');
    }
    if ( $q->param('todate') ) {
        $where .= qq| AND r.checkin_date <= ?|;
        push @bind, $q->param('todate');
    }
    if ( $q->param('comp_code') ) {
        $where .= qq| AND r.comp_code like ?|;
        push @bind, $q->param('comp_code');
    }

    my $query = qq|
            SELECT   r.res_id, r.room_num room, r.room_type type, r.guest_name1 guest1, 
                     r.guest_name2 guest2, r.comp_code, r.company, r.adults pax, r.checkin_date checkin,
                     (select nvl(sum(amount),0) from hc_charges c where c.res_id = r.res_id and charge_code='101') amount
                FROM hc_res r
               WHERE TO_CHAR(r.checkin_date, 'DD-MON-RR') = TO_CHAR(r.actual_checkout_date, 'DD-MON-RR')
                 AND $where
               ORDER BY $sort_positions($sort) $sortorder
    |;

    my @allrows = $dbs->query( $query, @bind )->hashes or die( $dbs->error );

    my ( %tabledata, %totals, %subtotals );

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
    my $i = 0;
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
        for (@report_columns) { $tabledata{$_} = qq|<td nowrap>$row->{$_}</td>| }
        for (@total_columns) { $tabledata{$_} = qq|<td align="right" nowrap>| . $nf->format_price( $row->{$_}, 2 ) . qq|</td>| }
        $tabledata{billing} = qq|<td>$row->{billing}</td>|;    # wrapped
        for (@total_columns) { $totals{$_}    += $row->{$_} }
        for (@total_columns) { $subtotals{$_} += $row->{$_} }

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#----------------------------------------
sub billing_ins {

    &report_header('Billing Instructions Report');

    my @columns       = qw(res_id room guest1 group_id company checkin checkout adults billing checkin_remarks res_remarks);
    my @total_columns = qw(rate);

    my %sort_positions = {
        res_id          => 1,
        room            => 2,
        guest1          => 3,
        group_id        => 4,
        company         => 5,
        checkin         => 6,
        checkout        => 7,
        adults          => 8,
        billing         => 9,
        checkin_remarks => 10,
        res_remarks     => 11,
    };

    my $sort      = $q->param('sort') ? $q->param('sort') : 'room';
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    print qq|
<form action="reports.pl" method="post">
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

    my $where = ' 1 = 1 ';
    $where = ' 1 = 2 ' if $action ne 'Update';    # Display data only when Update button is pressed.
    my @bind = ();

    if ( $q->param('fromdate') ) {
        $where .= qq| AND h.tr_date >= ?|;
        push @bind, $q->param('fromdate');
    }

    if ( $q->param('todate') ) {
        $where .= qq| AND h.tr_date <= ?|;
        push @bind, $q->param('todate');
    }

    my $query = qq|
            SELECT   res_id, room_num room, guest_name1 guest1, 
                     company, group_id, checkin_date checkin,
                     checkout_date checkout, adults, billing_ins billing,
                     adults, checkin_remarks, res_remarks
                FROM hc_res
               WHERE hc_res.checked_in = 'Y'
                 AND hc_res.checked_out = 'N'
                 AND room_num NOT IN ('ADV', 'CTL', 'GM', 'LUD', 'NA', 'CTLR', 'ECB', 'SPR', 'GL')
                 AND $where
               ORDER BY $sort_positions($sort) $sortorder
    |;

    my @allrows = $dbs->query( $query, @bind )->hashes or die( $dbs->error );

    my ( %tabledata, %totals, %subtotals );

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
    my $i = 0;
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

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

## Please see file perltidy.ERR
## Please see file perltidy.ERR
#----------------------------------------
sub billing_ins {

    &report_header('Billing Instructions Report');

    my @columns       = qw(res_id room guest1 group_id company checkin checkout adults billing checkin_remarks res_remarks);
    my @total_columns = qw(rate);

    my %sort_positions = {
        res_id          => 1,
        room            => 2,
        guest1          => 3,
        group_id        => 4,
        company         => 5,
        checkin         => 6,
        checkout        => 7,
        adults          => 8,
        billing         => 9,
        checkin_remarks => 10,
        res_remarks     => 11,
    };

    my $sort      = $q->param('sort') ? $q->param('sort') : 'room';
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    print qq|
<form action="reports.pl" method="post">
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

    my $where = ' 1 = 1 ';
    $where = ' 1 = 2 ' if $action ne 'Update';    # Display data only when Update button is pressed.
    my @bind = ();

    if ( $q->param('fromdate') ) {
        $where .= qq| AND h.tr_date >= ?|;
        push @bind, $q->param('fromdate');
    }

    if ( $q->param('todate') ) {
        $where .= qq| AND h.tr_date <= ?|;
        push @bind, $q->param('todate');
    }

    my $query = qq|
            SELECT   res_id, room_num room, guest_name1 guest1, 
                     company, group_id, checkin_date checkin,
                     checkout_date checkout, adults, billing_ins billing,
                     adults, checkin_remarks, res_remarks
                FROM hc_res
               WHERE hc_res.checked_in = 'Y'
                 AND hc_res.checked_out = 'N'
                 AND room_num NOT IN ('ADV', 'CTL', 'GM', 'LUD', 'NA', 'CTLR', 'ECB', 'SPR', 'GL')
                 AND $where
               ORDER BY $sort_positions($sort) $sortorder
    |;

    my @allrows = $dbs->query( $query, @bind )->hashes or die( $dbs->error );

    my ( %tabledata, %totals, %subtotals );

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
    my $i = 0;
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

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#---------------------------------------------------------------------------------------------------
sub onhand {

    &report_header('Inventory Onhand Report');

    my @columns        = qw(item_cat item_id item_name uom_stk_id avg_cost onhand amount);
    my @total_columns  = qw(avg_cost onhand amount);
    my @search_columns = qw(store_id item_cat fromdate todate);

    my %sort_positions = {
        item_cat   => 1,
        item_id    => 2,
        item_name  => 3,
        uom_stk_id => 4,
        avg_cost   => 5,
        onhand     => 6,
        amount     => 7,
    };

    my $sort      = $q->param('sort') ? $q->param('sort') : 'item_cat';
    my $vip       = $q->param('vip');
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    my $item_cat  = $q->param('item_cat');
    my $store_id  = $q->param('store_id');
    my $fromdate  = $q->param('fromdate');
    my $todate    = $q->param('todate');
    my $include   = $q->param('include');
    $store_id = 'MAIN-STORE' if !$store_id;

    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    my $fromdate;
    my $todate;
    if ( $q->param('fromdate') ) {
        $fromdate = $q->param('fromdate');
        $todate   = $q->param('todate');
    }
    else {
        $fromdate = '1-JAN-2000';
        $todate   = $dbs->query("SELECT global_value FROM z_apps_data WHERE id='HC_SYSDATE'")->list;
    }

    print qq|
<form action="reports.pl" method="post">
Include: |;
    for (@columns) {
        $checked = ( $action eq 'Update' ) ? ( $q->param("l_$_") ? 'checked' : '' ) : 'checked';
        print qq|<input type=checkbox name=l_$_ value="1" $checked> | . ucfirst($_);
    }
    print qq|<br/>
    Include: <select name=include><option value="$include">$include<option value=""><option value="NON-ZERO">NON-ZERO</select><br/>
    Store: <input type=text name=store_id size=12 value="$store_id"><br/>
    Category: <input type=text name=item_cat size=12 value="$item_cat"><br/>
    From date: <input type=text class=datepicker name="fromdate" size=12 value="$fromdate"><br/>
    To date: <input type=text class=datepicker name="todate" size=12 value="$todate"><br/>
    Subtotal: <input type=checkbox name=l_subtotal value="checked" | . $q->param('l_subtotal') . qq|><br/>
    <hr/>
    <input type=hidden name=nextsub value=$nextsub>
    <input type=submit name=action class=submit value="Update">
</form>
|;

    my @report_columns;
    for (@columns) { push @report_columns, $_ if $q->param("l_$_") }

    my $where1;
    my $where2;

    my @bind = ();

    if ($store_id) {
        $where1 .= qq| AND h.rec_loc_id = ?|;
        push @bind, $store_id;
    }
    if ($item_cat) {
        $where1 .= qq| AND i.item_cat = ?|;
        push @bind, $item_cat;
    }
    if ( $q->param('fromdate') ) {
        $where1 .= qq| AND h.tr_date >= ?|;
        push @bind, $q->param('fromdate');
    }
    if ( $q->param('todate') ) {
        $where1 .= qq| AND h.tr_date <= ?|;
        push @bind, $q->param('todate');
    }

    if ($store_id) {
        $where2 .= qq| AND h.iss_loc_id = ?|;
        push @bind, $store_id;
    }
    if ($item_cat) {
        $where2 .= qq| AND i.item_cat = ?|;
        push @bind, $item_cat;
    }
    if ( $q->param('fromdate') ) {
        $where2 .= qq| AND h.tr_date >= ?|;
        push @bind, $q->param('fromdate');
    }
    if ( $q->param('todate') ) {
        $where2 .= qq| AND h.tr_date <= ?|;
        push @bind, $q->param('todate');
    }

    my $having;
    if ( $include eq 'NON-ZERO' ) {
        $having = "HAVING SUM (qty) <> 0";
    }

    my $query = qq|
            SELECT   item_cat, item_id, item_name, uom_stk_id, avg_cost, SUM (qty) onhand, avg_cost * SUM (qty) amount
                FROM (SELECT   i.item_cat, l.item_id, i.item_name, i.uom_stk_id, i.avg_cost, SUM (l.qty) qty
                          FROM ic_trans_lines_tmp l, ic_trans_header_tmp h, ic_items i
                         WHERE l.tr_num = h.tr_num
                           AND l.item_id = i.item_id
                           AND h.tr_type = 'PURCHASE'
                           $where1
                      GROUP BY i.item_cat, l.item_id, i.item_name, i.uom_stk_id, i.avg_cost
                      UNION ALL
                      SELECT   i.item_cat, l.item_id, i.item_name, i.uom_stk_id, i.avg_cost, SUM (0 - l.qty) qty
                          FROM ic_trans_lines_tmp l, ic_trans_header_tmp h, ic_items i
                         WHERE l.tr_num = h.tr_num
                           AND l.item_id = i.item_id
                           AND h.tr_type = 'ISSUE'
                           $where2
                      GROUP BY i.item_cat, l.item_id, i.item_name, i.uom_stk_id, i.avg_cost)
               GROUP BY item_cat, item_id, item_name, uom_stk_id, avg_cost
               $having
               ORDER BY $sort_positions($sort) $sortorder
    |;

    my @allrows = $dbs->query( $query, @bind )->hashes or die( $dbs->error );

    my ( %tabledata, %totals, %subtotals );

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

    my $url = $dbs->query("select global_value from z_apps_data where id='MUNSHI9_URL'")->list;
    $url = "http://$url:8000/munshi9";

    my $groupvalue;
    my $i = 0;
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
        for (@report_columns) { $tabledata{$_} = qq|<td nowrap>$row->{$_}</td>| }
        $tabledata{item_id} = qq|<td nowrap><a href="$url/a\$ic.ledger?p_item_id1=$row->{item_id}&p_tr_date1=$fromdate&p_tr_date2=$todate&p_iss_loc_id1=$store_id">$row->{item_id}</a>|;
        for (@total_columns) { $tabledata{$_} = qq|<td align="right" nowrap>| . $nf->format_price( $row->{$_}, 2 ) . qq|</td>| }
        $tabledata{billing} = qq|<td>$row->{billing}</td>|;    # wrapped
        for (@total_columns) { $totals{$_}    += $row->{$_} }
        for (@total_columns) { $subtotals{$_} += $row->{$_} }

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#---------------------------------------------------------------------------------------------------
sub onhand_parlevel {

    &report_header('Inventory Onhand Report with Par Level');

    my @columns        = qw(item_cat item_id item_name uom_stk_id onhand min max reorder par diff);
    my @total_columns  = qw(avg_cost onhand amount min max par diff);
    my @search_columns = qw(store_id item_cat fromdate todate);

    my %sort_positions = {
        item_cat   => 1,
        item_id    => 2,
        item_name  => 3,
        uom_stk_id => 4,
        avg_cost   => 5,
        onhand     => 6,
        amount     => 7,
    };

    my $sort      = $q->param('sort') ? $q->param('sort') : 'item_cat';
    my $vip       = $q->param('vip');
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    my $item_cat  = $q->param('item_cat');
    my $store_id  = $q->param('store_id');
    my $fromdate  = $q->param('fromdate');
    my $todate    = $q->param('todate');
    my $include   = $q->param('include');
    $store_id = 'MAIN-STORE' if !$store_id;

    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    my $fromdate;
    my $todate;
    if ( $q->param('fromdate') ) {
        $fromdate = $q->param('fromdate');
        $todate   = $q->param('todate');
    }
    else {
        $fromdate = '1-JAN-2000';
        $todate   = $dbs->query("SELECT global_value FROM z_apps_data WHERE id='HC_SYSDATE'")->list;
    }

    print qq|
<form action="reports.pl" method="post">
Include: |;
    for (@columns) {
        $checked = ( $action eq 'Update' ) ? ( $q->param("l_$_") ? 'checked' : '' ) : 'checked';
        print qq|<input type=checkbox name=l_$_ value="1" $checked> | . ucfirst($_);
    }
    print qq|<br/>
    Include: <select name=include><option value="$include">$include<option value=""><option value="NON-ZERO">NON-ZERO</select><br/>
    Store: <input type=text name=store_id size=12 value="$store_id"><br/>
    Category: <input type=text name=item_cat size=12 value="$item_cat"><br/>
    From date: <input type=text class=datepicker name="fromdate" size=12 value="$fromdate"><br/>
    To date: <input type=text class=datepicker name="todate" size=12 value="$todate"><br/>
    Subtotal: <input type=checkbox name=l_subtotal value="checked" | . $q->param('l_subtotal') . qq|><br/>
    <hr/>
    <input type=hidden name=nextsub value=$nextsub>
    <input type=submit name=action class=submit value="Update">
</form>
|;

    my @report_columns;
    for (@columns) { push @report_columns, $_ if $q->param("l_$_") }

    my $where1;
    my $where2;

    my @bind = ();

    if ($store_id) {
        $where1 .= qq| AND h.rec_loc_id = ?|;
        push @bind, $store_id;
    }
    if ($item_cat) {
        $where1 .= qq| AND i.item_cat = ?|;
        push @bind, $item_cat;
    }
    if ( $q->param('fromdate') ) {
        $where1 .= qq| AND h.tr_date >= ?|;
        push @bind, $q->param('fromdate');
    }
    if ( $q->param('todate') ) {
        $where1 .= qq| AND h.tr_date <= ?|;
        push @bind, $q->param('todate');
    }

    if ($store_id) {
        $where2 .= qq| AND h.iss_loc_id = ?|;
        push @bind, $store_id;
    }
    if ($item_cat) {
        $where2 .= qq| AND i.item_cat = ?|;
        push @bind, $item_cat;
    }
    if ( $q->param('fromdate') ) {
        $where2 .= qq| AND h.tr_date >= ?|;
        push @bind, $q->param('fromdate');
    }
    if ( $q->param('todate') ) {
        $where2 .= qq| AND h.tr_date <= ?|;
        push @bind, $q->param('todate');
    }

    my $having;
    if ( $include eq 'NON-ZERO' ) {
        $having = "HAVING SUM (qty) <> 0";
    }

    my $query = qq|
            SELECT   item_cat, item_id, item_name, uom_stk_id, avg_cost, rop min, roq max, SUM (qty) onhand, avg_cost * SUM (qty) amount
                FROM (SELECT   i.item_cat, l.item_id, i.item_name, i.uom_stk_id, i.avg_cost, i.rop, i.roq, SUM (l.qty) qty
                          FROM ic_trans_lines_tmp l, ic_trans_header_tmp h, ic_items i
                         WHERE l.tr_num = h.tr_num
                           AND l.item_id = i.item_id
                           AND h.tr_type = 'PURCHASE'
                           $where1
                      GROUP BY i.item_cat, l.item_id, i.item_name, i.uom_stk_id, i.avg_cost, i.rop, i.roq
                      UNION ALL
                      SELECT   i.item_cat, l.item_id, i.item_name, i.uom_stk_id, i.avg_cost, i.rop, i.roq, SUM (0 - l.qty) qty
                          FROM ic_trans_lines_tmp l, ic_trans_header_tmp h, ic_items i
                         WHERE l.tr_num = h.tr_num
                           AND l.item_id = i.item_id
                           AND h.tr_type = 'ISSUE'
                           $where2
                      GROUP BY i.item_cat, l.item_id, i.item_name, i.uom_stk_id, i.avg_cost, i.rop, i.roq)
               GROUP BY item_cat, item_id, item_name, uom_stk_id, avg_cost, rop, roq
               $having
               ORDER BY $sort_positions($sort) $sortorder
    |;

    my @allrows = $dbs->query( $query, @bind )->hashes or die( $dbs->error );

    my ( %tabledata, %totals, %subtotals );

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

    my $url = $dbs->query("select global_value from z_apps_data where id='MUNSHI9_URL'")->list;
    $url = "http://$url:8000/munshi9";

    my $groupvalue;
    my $i = 0;
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
        $row->{par}  = $row->{max} - $row->{min};
        $row->{diff} = $row->{onhand} - $row->{par};
        if ( $row->{par} <= $row->{onhand} ) {
            $row->{reorder} = 'In Stock';
        }
        else {
            $row->{reorder} = 'Order';
        }
        for (@report_columns) { $tabledata{$_} = qq|<td nowrap>$row->{$_}</td>| }
        $tabledata{item_id} = qq|<td nowrap><a href="$url/a\$ic.ledger?p_item_id1=$row->{item_id}&p_tr_date1=$fromdate&p_tr_date2=$todate&p_iss_loc_id1=$store_id">$row->{item_id}</a>|;
        for (@total_columns) { $tabledata{$_} = qq|<td align="right" nowrap>| . $nf->format_price( $row->{$_}, 2 ) . qq|</td>| }
        for (@total_columns) { $totals{$_}    += $row->{$_} }
        for (@total_columns) { $subtotals{$_} += $row->{$_} }

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#----------------------------------------
sub journal {

    &report_header('Linking Journal');

    my @columns        = qw(doc_date acc_num acc_title debit credit doc_num ref1 line_desc doc_type tbl_name);
    my @total_columns  = qw(debit credit);
    my @search_columns = qw(fromdate todate doc_num ref1);

    my %sort_positions = {
        doc_date  => 1,
        acc_num   => 2,
        acc_title => 3,
        debit     => 4,
        credit    => 5,
        doc_num   => 6,
        ref1      => 7,
        line_desc => 8,
        doc_type  => 9,
        tbl_name  => 10,
    };

    my $sort      = $q->param('sort') ? $q->param('sort') : 'acc_num';
    my $sortorder = $q->param('sortorder');
    my $oldsort   = $q->param('oldsort');
    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    print qq|
<form action="reports.pl" method="post">
From date: <input name=fromdate type=text size=12 class="datepicker" value="| . $q->param('fromdate') . qq|"><br/>
To date: <input name=todate type=text size=12 class="datepicker" value="| . $q->param('todate') . qq|"><br/>
Doc Num: <input name=doc_num type=text size=10 value="| . $q->param('doc_num') . qq|"><br/>
Ref1: <input name=ref1 type=text size=20 value="| . $q->param('ref1') . qq|"><br/>
Line Desc: <input name=line_desc type=text size=40 value="| . $q->param('line_desc') . qq|"><br/>
Include: |;
    for (@columns) {
        $checked = ( $action eq 'Update' ) ? ( $q->param("l_$_") ? 'checked' : '' ) : 'checked';
        print qq|<input type=checkbox name=l_$_ value="1" $checked> | . ucfirst($_);
    }

    my $l_subtotal = 'checked';
    $l_subtotal = $q->param('l_subtotal') if $action eq 'Update';

    print qq|<br/>
    Subtotal: <input type=checkbox name=l_subtotal value="checked" $l_subtotal><br/>
    <hr/>
    <input type=hidden name=nextsub value=$nextsub>
    <input type=submit name=action class=submit value="Update">
</form>
|;

    my @report_columns;
    for (@columns) { push @report_columns, $_ if $q->param("l_$_") }

    my $where = ' 1 = 1 ';
    $where = ' 1 = 2 ' if $action ne 'Update';    # Display data only when Update button is pressed.
    my @bind = ();

    if ( $q->param('fromdate') ) {
        $where .= qq| AND j.doc_date >= ?|;
        push @bind, $q->param('fromdate');
    }
    if ( $q->param('todate') ) {
        $where .= qq| AND j.doc_date <= ?|;
        push @bind, $q->param('todate');
    }
    if ( $q->param('doc_num') ) {
        $where .= qq| AND j.doc_num = ?|;
        push @bind, $q->param('doc_num');
    }
    if ( $q->param('ref1') ) {
        $where .= qq| AND j.ref1 like ?|;
        push @bind, $q->param('ref1');
    }
    if ( $q->param('line_desc') ) {
        $where .= qq| AND j.line_desc like ?|;
        push @bind, $q->param('line_desc');
    }

    my $query = qq|
            SELECT j.doc_date, j.doc_type, j.acc_num, c.acc_title,
                case
                    when j.amt > 0 then amt
                    else 0
                end as debit,
                case
                    when j.amt < 0 then 0 - amt
                    else 0
                end as credit,
                j.doc_num, j.ref1, j.line_desc
                FROM gl_journal j
                JOIN gl_accounts c ON (c.acc_num = j.acc_num)
               WHERE $where
               ORDER BY $sort_positions($sort) $sortorder
    |;

    my @allrows = $dbs->query( $query, @bind )->hashes or die( $dbs->error );

    my ( %tabledata, %totals, %subtotals );

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
    my $i = 0;
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
        for (@report_columns) { $tabledata{$_} = qq|<td nowrap>$row->{$_}</td>| }
        for (@total_columns) { $tabledata{$_} = qq|<td align="right">| . $nf->format_price( $row->{$_}, 2 ) . qq|</td>| }
        for (@total_columns) { $totals{$_}    += $row->{$_} }
        for (@total_columns) { $subtotals{$_} += $row->{$_} }

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>|;
        $i += 1;
        $i %= 2;
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

#---------------------------------------------------------------------------------------------------
sub attachments {

    #-----------------------------------------------
    # DB FORM
    #-----------------------------------------------
    my $form1 = CGI::FormBuilder->new(
        enctype    => 'multipart/form-data',
        method     => 'post',
        table      => 1,
        fields     => [qw(filename dir)],
        submit     => [qw(Upload)],
        stylesheet => 1,
        template   => {
            type     => 'TT2',
            template => 'form.tmpl',
            variable => 'form1',
        },
        keepextras => [qw(nextsub action)],
    );
    $form1->field( name => 'filename', type => 'file' );
    $form1->field( name => 'dir', type => 'hidden', value => $dir );
    $form1->field( name => 'emp_num', type => 'hidden', value => $emp_num );

    &report_header('File Upload');
    print $form1->render if $q->param('action') eq 'form';

    #-----------------------------------------------
    # DATA BASE PROCESSING
    #-----------------------------------------------
    if ( $form1->submitted eq 'Upload' ) {
        my $file = $form1->field('filename');
        if ($file) {
            mkdir "/var/www/munshi9/uploads/$dir", oct("771") or die $! if ( !-d "/var/www/munshi9/uploads/$dir" );

            open F, ">/var/www/munshi9/uploads/$dir/$file" or die $!;
            while (<$file>) {
                print F;
            }
            close F;
            $dbs->query("UPDATE hr_emp SET photo='$dir/$file' WHERE emp_num = ?", $emp_num);
            $dbh->commit;
            print ("UPDATE hr_emp SET photo='$dir/$file' WHERE emp_num = $emp_num");
            print qq|<h3>File uploaded</h3>|;
        }
    }

    print qq|<br/><br/><a href="$pageurl?nextsub=attachments&action=form&dir=$dir&emp_num=$emp_num">Add a new attachment</a>|;

    #-----------------------------------------------
    # REPORT
    #-----------------------------------------------
    opendir( my $dh, "/var/www/munshi9/uploads/$dir" );
    if ($!) {
        mkdir "/var/www/munshi9/uploads/$dir", oct("771");
        #print "Can't opendir /var/www/munshi9/uploads/$dir: $!";
    }
    else {
        @allfiles = readdir($dh);
        closedir $dh;
        print qq|<h4>List of files</h4>|;
        for (@allfiles) {
            if ( !( $_ eq '.' or $_ eq '..' ) ) {
                print qq|<li><a href="uploads/$dir/$_">$_</a></li>|;
            }
        }
        for (@allfiles) {
            if ( !( $_ eq '.' or $_ eq '..' ) ) {
                print qq|<img src="uploads/$dir/$_">$_</img><br/>|;
            }
        }

    }

    print qq|</body></html>|;
}

#---------------------------------------------------------------------------------------------------
sub ccard {

    my $row = {};
    if ( $q->param('id') ) {
        $row = $dbs->query( '
            SELECT id, name, address, email, dob, mobile, anniversary
            FROM ccard
            WHERE id = ?', $q->param('id') )->hash or die( $dbs->error );
    }

    #-----------------------------------------------
    # DB FORM
    #-----------------------------------------------
    my @form1flds   = qw(id name address email dob mobile anniversary );
    my @form1hidden = qw(id);
    my $form1       = CGI::FormBuilder->new(
        method     => 'post',
        table      => 1,
        fields     => \@form1flds,
        required   => [qw(name)],
        submit     => [qw(Save Delete)],
        values     => $row,
        params     => $q,
        stylesheet => 1,
        template   => {
            type     => 'TT2',
            template => 'form.tmpl',
            variable => 'form1',
        },
        keepextras => [qw(nextsub action)],
    );
    for (@form1hidden) { $form1->field( name => $_, type => 'hidden' ) }
    $form1->field( name => 'dob',         class => 'datepicker' );
    $form1->field( name => 'anniversary', class => 'datepicker' );
    &report_header('Comment Cards');
    print $form1->render if $q->param('action') eq 'form';

    #-----------------------------------------------
    # DATA BASE PROCESSING
    #-----------------------------------------------
    my $data = $form1->fields;
    $data->{id} *= 1;
    for (qw(action nextsub)) { delete $data->{$_} }
    if ( $form1->submitted eq 'Save' ) {
        if ( $data->{id} ) {
            $dbs->update( 'ccard', $data, { id => $data->{id} } );
        }
        else {
            delete $data->{id};
            $dbs->insert( 'ccard', $data );
        }
        print qq|Card saved\n|;
    }
    elsif ( $form1->submitted eq 'Delete' ) {
        $dbs->delete( 'hr_emp', { id => $data->{id} } );
        print qq|Card deleted\n|;
    }

    #-----------------------------------------------
    # REPORT
    #-----------------------------------------------
    print qq|<a href="$pageurl?nextsub=ccard&action=form">Add a new comment card</a>|;
    my $table = $dbs->query( "
        SELECT '<a href=reports.pl?nextsub=ccard&action=form&id='||id||'>'||name||'</a>' name, 
            address, email, dob, mobile, anniversary
        FROM ccard
        ORDER BY id"
      )->xto(
        table => { cellpadding => "5",          cellspacing => "2" },
        tr    => { class       => [ 'listrow0', 'listrow1' ] },
        th    => { class       => ['listheading'] },
      ) or die( $dbs->error );

    print $table->output;
    print qq|</body></html>|;
}

#---------------------------------------------------------------------------------------------------
sub emp {

    my $row = {};
    if ( $q->param('id') ) {
        $row = $dbs->query( '
            SELECT id, emp_num, emp_name,
                    father_name, desig, dept,
                    pymt_type, sex, married,
                    religion, ntn, nid,
                    eobi_num, blood_group, bank_acc,
                    address1, address2, city,
                    phone, email, dob, doj,
                    job_status, reference1, reference2,
                    reference3, basic_pay, house_rent,
                    coveyance, medical, utilities,
                    others, gross_pay
            FROM hr_emp
            WHERE id = ?', $q->param('id') )->hash or die( $dbs->error );
    }

    #-----------------------------------------------
    # DB FORM
    #-----------------------------------------------
    my @form1flds =
      qw(id emp_num emp_name father_name desig dept pymt_type sex married religion ntn nid eobi_num blood_group bank_acc address1 address2 city phone email dob doj job_status reference1 reference2 reference3 basic_pay house_rent coveyance medical utilities others gross_pay );
    my @form1hidden = qw(id);
    my $form1       = CGI::FormBuilder->new(
        method     => 'post',
        table      => 1,
        fields     => \@form1flds,
        required   => [qw(emp_name)],
        submit     => [qw(Save Delete)],
        values     => $row,
        params     => $q,
        stylesheet => 1,
        template   => {
            type     => 'TT2',
            template => 'form.tmpl',
            variable => 'form1',
        },
        keepextras => [qw(nextsub action)],
    );
    for (@form1hidden) { $form1->field( name => $_, type => 'hidden' ) }
    &report_header('Employees database');
    print $form1->render if $q->param('action') eq 'form';

    #-----------------------------------------------
    # DATA BASE PROCESSING
    #-----------------------------------------------
    my $data = $form1->fields;
    $data->{id} *= 1;
    for (qw(action nextsub)) { delete $data->{$_} }
    if ( $form1->submitted eq 'Save' ) {
        if ( $data->{id} ) {
            $dbs->update( 'hr_emp', $data, { id => $data->{id} } );
        }
        else {
            delete $data->{id};
            $dbs->insert( 'hr_emp', $data );
        }
        print qq|Employee saved\n|;
    }
    elsif ( $form1->submitted eq 'Delete' ) {
        $dbs->delete( 'hr_emp', { id => $data->{id} } );
        print qq|Employee deleted\n|;
    }

    #-----------------------------------------------
    # REPORT
    #-----------------------------------------------
    print qq|<a href="$pageurl?nextsub=emp&action=form">Add a new employee</a>|;
    my $table = $dbs->query( "
        SELECT '<a href=reports.pl?nextsub=emp&action=form&id='||id||'>'||emp_num||'</a>' emp_num, 
            emp_name 
        FROM hr_emp 
        ORDER BY id"
      )->xto(
        table => { cellpadding => "5",          cellspacing => "2" },
        tr    => { class       => [ 'listrow0', 'listrow1' ] },
        th    => { class       => ['listheading'] },
      ) or die( $dbs->error );

    print $table->output;
    print qq|</body></html>|;
}

#---------------------------------------------------------------------------------------------------
sub ccard {

    my $row = {};
    if ( $q->param('id') ) {
        $row = $dbs->query( '
            SELECT id, name, address, email, dob, mobile, anniversary
            FROM ccard
            WHERE id = ?', $q->param('id') )->hash or die( $dbs->error );
    }

    #-----------------------------------------------
    # DB FORM
    #-----------------------------------------------
    my @form1flds   = qw(id name address email dob mobile anniversary );
    my @form1hidden = qw(id);
    my $form1       = CGI::FormBuilder->new(
        method     => 'post',
        table      => 1,
        fields     => \@form1flds,
        required   => [qw(name)],
        submit     => [qw(Save Delete)],
        values     => $row,
        params     => $q,
        stylesheet => 1,
        template   => {
            type     => 'TT2',
            template => 'form.tmpl',
            variable => 'form1',
        },
        keepextras => [qw(nextsub action)],
    );
    for (@form1hidden) { $form1->field( name => $_, type => 'hidden' ) }
    $form1->field( name => 'dob',         class => 'datepicker' );
    $form1->field( name => 'anniversary', class => 'datepicker' );
    &report_header('Comment Cards');
    print $form1->render if $q->param('action') eq 'form';

    #-----------------------------------------------
    # DATA BASE PROCESSING
    #-----------------------------------------------
    my $data = $form1->fields;
    $data->{id} *= 1;
    for (qw(action nextsub)) { delete $data->{$_} }
    if ( $form1->submitted eq 'Save' ) {
        if ( $data->{id} ) {
            $dbs->update( 'ccard', $data, { id => $data->{id} } );
        }
        else {
            delete $data->{id};
            $dbs->insert( 'ccard', $data );
        }
        print qq|Card saved\n|;
    }
    elsif ( $form1->submitted eq 'Delete' ) {
        $dbs->delete( 'hr_emp', { id => $data->{id} } );
        print qq|Card deleted\n|;
    }

    #-----------------------------------------------
    # REPORT
    #-----------------------------------------------
    print qq|<a href="$pageurl?nextsub=ccard&action=form">Add a new comment card</a>|;
    my $table = $dbs->query( "
        SELECT '<a href=reports.pl?nextsub=ccard&action=form&id='||id||'>'||name||'</a>' name, 
            address, email, dob, mobile, anniversary
        FROM ccard
        ORDER BY id"
      )->xto(
        table => { cellpadding => "5",          cellspacing => "2" },
        tr    => { class       => [ 'listrow0', 'listrow1' ] },
        th    => { class       => ['listheading'] },
      ) or die( $dbs->error );

    print $table->output;
    print qq|</body></html>|;
}

#---------------------------------------------------------------------------------------------------
sub hc_revenue_rpt {

    my $row = {};
    if ( $q->param('id') ) {
        $row = $dbs->query( '
            SELECT id, seq_id, code, particulars, rptgroup, group2, calctotal
            FROM hc_revenue_rpt
            WHERE id = ?', $q->param('id') )->hash or die( $dbs->error );
    }

    #-----------------------------------------------
    # DB FORM
    #-----------------------------------------------
    my @form1flds   = qw(id seq_id code particulars rptgroup group2 calctotal);
    my @form1hidden = qw(id);
    my $form1       = CGI::FormBuilder->new(
        method     => 'post',
        table      => 1,
        fields     => \@form1flds,
        required   => [qw(seq_id code particulars rptgroup group2 calctotal)],
        options    => { calctotal => [qw(Y N)] },
        submit     => [qw(Save Delete)],
        values     => $row,
        params     => $q,
        stylesheet => 1,
        template   => {
            type     => 'TT2',
            template => 'form.tmpl',
            variable => 'form1',
        },
        keepextras => [qw(nextsub action)],
    );
    for (@form1hidden) { $form1->field( name => $_, type => 'hidden' ) }
    &report_header('Early Bird Codes');
    print $form1->render if $q->param('action') eq 'form';

    #-----------------------------------------------
    # DATA BASE PROCESSING
    #-----------------------------------------------
    my $data = $form1->fields;
    $data->{id} *= 1;
    for (qw(action nextsub)) { delete $data->{$_} }
    if ( $form1->submitted eq 'Save' ) {
        if ( $data->{id} ) {
            $dbs->update( 'hc_revenue_rpt', $data, { id => $data->{id} } );
        }
        else {
            $data->{id} = $dbs->query('select max(id)+1 from hc_revenue_rpt')->list;
            $dbs->insert( 'hc_revenue_rpt', $data );
        }
        print qq|Code saved\n|;
    }
    elsif ( $form1->submitted eq 'Delete' ) {
        $dbs->delete( 'hc_revenue_rpt', { id => $data->{id} } );
        print qq|Code deleted\n|;
    }

    #-----------------------------------------------
    # REPORT
    #-----------------------------------------------
    print qq|<a href="$pageurl?nextsub=hc_revenue_rpt&action=form">Add a new EBR code</a>|;
    my $table = $dbs->query( "
        SELECT id, '<a href=reports.pl?nextsub=hc_revenue_rpt&action=form&id='||id||'>'||seq_id||'</a>' seq,
            code, particulars, rptgroup, group2, calctotal
        FROM hc_revenue_rpt
        ORDER BY seq_id, code"
      )->xto(
        table => { cellpadding => "5",          cellspacing => "2" },
        tr    => { class       => [ 'listrow0', 'listrow1' ] },
        th    => { class       => ['listheading'] },
      ) or die( $dbs->error );

    print $table->output;
    print qq|</body></html>|;
}

# EOF
