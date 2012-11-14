#!/usr/bin/perl
# Multimarkdown html generator

use Text::MultiMarkdown;
use File::Slurp;
use warnings;
use strict;

my $md_filename = $ARGV[0];
my $html_filename = $ARGV[1];
my $text = read_file($md_filename);
my $markdown = Text::MultiMarkdown->new;
my $html = $markdown->markdown($text,
	{document_format => 'complete' });

my $out_html = write_file($html_filename, $html);
