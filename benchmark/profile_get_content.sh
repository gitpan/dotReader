#!/bin/sh

BK="test_packages/FreeBSD_Developers_Handbook/FreeBSDDevelopersHandbook.xml"
SC="X86"
#BK="test_packages/big_section/book.xml"
#SC="lib_Pod_perlfunc_html_alphabetical_listing_of_perl_functions"
perl -d:DProf util/show_section $BK $SC > /dev/null
