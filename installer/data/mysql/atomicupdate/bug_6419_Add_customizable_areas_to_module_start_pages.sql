$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    # you can use $dbh here like:
$dbh->do(q{
INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('IntranetSerialsHomeHTML', '', 'Show the following HTML in a div on the bottom of the serials home page', NULL, 'Free')});

    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Bug 6419 - Add customizable areas to intranet start pages)\n";
}