package XML::Mini;
use strict;
$^W = 1;

use vars qw (
	     $AutoEscapeEntities
	     $AutoSetParent
	     $AvoidLoops
	     $CaseSensitive
	     $Debug
	     $IgnoreWhitespaces
	     $NoWhiteSpaces

	     $VERSION
	     );

$VERSION = '1.24';

$AvoidLoops = 0;
$AutoEscapeEntities = 1;
$Debug = 0;
$IgnoreWhitespaces = 1;
$CaseSensitive = 0;
$AutoSetParent = 0;
$NoWhiteSpaces = -999;

sub Log
{
    my $class = shift;
    
    print STDERR "XML::Mini LOG MESSAGE:" ;
    print STDERR join(" ", @_) . "\n";
}

sub Error
{
    my $class = shift;
    
    print STDERR "XML::Mini Error MESSAGE:" ;
    print STDERR join(" ", @_) . "\n";
    
    exit(254);
}

sub escapeEntities
{
    my $class = shift;
    my $toencode = shift;
    
    return undef unless (defined $toencode);
    
    $toencode=~s/&/&amp;/g;
    $toencode=~s/\"/&quot;/g;
    $toencode=~s/>/&gt;/g;
    $toencode=~s/</&lt;/g;
    $toencode=~s/([\xA0-\xFF])/"&#".ord($1).";"/ge;
    return $toencode;
}

1;
__END__

=head1 NAME

XML::Mini - Perl implementation of the XML::Mini XML create/parse interface.

=head1 SYNOPSIS

  use XML::Mini::Document;

  # Create a XML document and fill it up
  my $htmlDoc = XML::Mini::Document->new();

  my $docRoot = $htmlDoc->getRoot();

  my $html  = $docRoot->createChild('html');

   my $head  = $html->createChild('head');
    my $title = $head->createChild('title', 'XML::Mini Generated HTML page');

    my $style = $head->createChild('style');
    $style->comment("body,td,a,p,.h{font-family:arial,sans-serif;} .q{text-decoration:none; color:#0000cc;}");

   my $body  = $html->createChild('body');
   $body->attribute('bgcolor', '#ffffff');
   $body->attribute('link', '#0000cc');
   $body->attribute('vlink', '#551a8b');

    my $h = $body->createChild('h3', 'This page was generated by XML::Mini!');
  
    my $p1 = $body->createChild('p', "It slices, dices and never forgets the </closing tags>! heh ;) ");
    my $br = $p1->createChild('br');
  
    $p1->text("View the source of this page to take a look at ");
   
      my $href = $p1->createChild('a');
      $href->attribute('href', 'http://minixml.psychogenic.com');
      $href->text('XML::Mini');
     
    $p1->text("'s clean HTML.");
  
  # Display the page
  print $htmlDoc->toString();
  
  # ...
  # Parse existing XML
  my $xmlDoc = XML::Mini::Document->new();
  
  $xmlDoc->fromString($XMLString);
  
  # Now we can fetch elements:
  
  my $part = $xmlDoc->getElementByPath('partsRateReply/part');
  
  my $partId = $part->attribute('id');
  
  my $price = $partList->getElement('price');
  
  print "Part $partId costs: " . $price->getValue() . "\n";
  
  
=head1 DESCRIPTION

XML::Mini is a set of Perl (and PHP) classes that allow you to access XML data and create valid XML output with a tree-based hierarchy of elements.

It provides an easy, object-oriented interface for manipulating XML documents and their elements.  It is currently being used to send requests and understand responses from remote servers in Perl or PHP applications.

XML::Mini does not require any external libraries or modules.


The XML::Mini.pm module includes a number of variable you may use to tweak XML::Mini's behavior.  These include:


$XML::Mini::AutoEscapeEntities - when greater than 0, the values set for nodes are automatically escaped, thus
$element->text('4 is > 3') will set the contents of the appended node to '4 is &gt; 3'.  Default setting is 1.


$XML::Mini::IgnoreWhitespaces - when greater than 0, extraneous whitespaces will be ignored (maily useful when parsing).  Thus
<mytag>       Hello There        </mytag> will be parsed as containing a text node with contents 'Hello There' instead 
of '       Hello There        '.  Default setting is 1.


$XML::Mini::CaseSensitive - when greater than 0, element names are treated as case sensitive.  Thus, $element->getElement('subelement') and $element->getElement('SubElement') will be equivalent.  Defaults to 0.


=head1 Class methods


=head2 escapeEntites TOENCODE

This method returns ToENCODE with HTML sensitive values
(eg '<', '>', '"', etc) HTML encoded.

=cut

=head2 Log MESSAGE

Logs the message to STDERR

=head2 Error MESSAGE

Logs MESSAGE and exits the program, calling exit()


=head1 AUTHOR

LICENSE

    XML::Mini module, part of the XML::Mini XML parser/generator package.
    Copyright (C) 2002 Patrick Deegan
    All rights reserved
    
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


Official XML::Mini site: http://minixml.psychogenic.com

Contact page for author available at http://www.psychogenic.com/en/contact.shtml

=head1 SEE ALSO


XML::Mini::Document, XML::Mini::Element

http://minixml.psychogenic.com

=cut