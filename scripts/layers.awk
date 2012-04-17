BEGIN {
	FS =",";
	print "Configured layers:\n";
 }

$1 !~ "^#" { print "layer repository name: " $1 "\nlayer uri: " $2 "\nlayer branch/revision: " $3 "/" $4 ; system("${OE_BASE}/scripts/layerman " $1 " "  $2 " " $3 " " $4 " " command " " commandarg);}
