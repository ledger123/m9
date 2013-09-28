#!/usr/bin/perl 

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use File::Basename;

$CGI::POST_MAX = 1024 * 5000;
my $safe_filename_characters = "a-zA-Z0-9_.-";
my $upload_dir = "/var/www/uploads";

my $query = new CGI;

if ($query->param('action') eq 'Copy from History'){
   print $query->header();
   my $oldfile1 = "$upload_dir/" . $query->param('old_res_id') . '_front.png';
   my $oldfile2 = "$upload_dir/" . $query->param('old_res_id') . '_back.png';
   my $newfile1 = "$upload_dir/" . $query->param('res_id') . '_front.png';
   my $newfile2 = "$upload_dir/" . $query->param('res_id') . '_back.png';

   system "cp $oldfile1 $newfile1";
   system "cp $oldfile2 $newfile2";

   print "<h1>CNIC copied from history successfully.</h1>";
   exit;
}

my $filename = $query->param("cnicfront");
my $filename2 = $query->param("cnicback");
my $munshi9_url = $query->param("munshi9_url");

if ( !$filename ){
  print $query->header ( );
  print "There was a problem uploading your cnicfront (try a smaller file).";
  exit;
}

if ( !$filename2 ){
  print $query->header ( );
  print "There was a problem uploading your cnicback (try a smaller file).";
  exit;
}

my ( $name, $path, $extension ) = fileparse ( $filename, '..*' );
$filename = $query->param("res_id") . '_front.png';
$filename2 = $query->param("res_id") . '_back.png';

if ( $filename =~ /^([$safe_filename_characters]+)$/ ){
  $filename = $1;
  unlink "$upload_dir/$filename";
} else {
  die "Filename contains invalid characters";
}

if ( $filename2 =~ /^([$safe_filename_characters]+)$/ ){
  $filename2 = $1;
  unlink "$upload_dir/$filename2";
} else {
  die "Filename contains invalid characters";
}

my $upload_filehandle = $query->upload("cnicfront");
open ( UPLOADFILE, ">$upload_dir/$filename" ) or die "$!";
binmode UPLOADFILE;
while ( <$upload_filehandle> ){ print UPLOADFILE; }
close UPLOADFILE;

$upload_filehandle = $query->upload("cnicback");
open ( UPLOADFILE, ">$upload_dir/$filename2" ) or die "$!";
binmode UPLOADFILE;
while ( <$upload_filehandle> ){ print UPLOADFILE; }
close UPLOADFILE;

print $query->header ( );
print <<END_HTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>Thanks!</title>
<style type="text/css">
img {border: none;}
</style>
</head>
<body>
<p>Thanks for uploading your cnicfront!</p>
<p>Your cnicfront:</p>
<p><img src="http://$munshi9_url/uploads/$filename" alt="CNIC Front" width="200" height="100" /></p>
<p><img src="http://$munshi9_url/uploads/$filename2" alt="CNIC Back" width="200" height="100" /></p>
</body>
</html>
END_HTML

