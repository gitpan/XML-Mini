package XML::Mini::Document;
use strict;
$^W = 1;

use FileHandle;
use XML::Mini;
use XML::Mini::Element;
use XML::Mini::Element::Comment;
use XML::Mini::Element::CData;
use XML::Mini::Element::DocType;
use XML::Mini::Element::Entity;
use XML::Mini::Node;

use vars qw ( $VERSION );

$VERSION = '1.24';

sub new
{
    my $class = shift;
    my $string = shift;
    
    my $self = {};
    bless $self, ref $class || $class;
    
    $self->{'_xmlDoc'} = XML::Mini::Element->new("PSYCHOGENIC_ROOT_ELEMENT");
    
    if (defined $string)
    {
	$self->fromString($string);
    }
    
    return $self;
}

sub getRoot
{
    my $self = shift;
    return $self->{'_xmlDoc'};
}

sub setRoot
{
    my $self = shift;
    my $root = shift;
    
    return XML::Mini->Error("XML::MiniDoc::setRoot(): Trying to set non-XML::Mini::Element as root")
	unless ($self->isElement($root));
    
    $self->{'_xmlDoc'} = $root;
}
	
sub isElement
{
    my $self = shift;
    my $element = shift || return undef;
    
    my $type = ref $element;
    
    return undef unless $type;
    
    return 0 unless ($type =~ /^XML::Mini::Element/);
    
    return 1;
}

sub isNode
{
    my $self = shift;
    my $element = shift || return undef;
    
    my $type = ref $element;
    
    return undef unless $type;
    
    return 0 unless ($type =~ /^XML::Mini::Node/);
    
    return 1;
}

sub createElement
{
    my $self = shift;
    my $name = shift;
    my $value = shift; # optional
    
    my $newElement = XML::Mini::Element->new($name);
    
    return XML::Mini->Error("Could not create new element named '$name'")
	unless ($newElement);
    
    if (defined $value)
    {
	$newElement->text($value);
    }
    
    return $newElement;
}

sub getElementByPath
{
    my $self = shift;
    my $path = shift;
    
    my $element = $self->{'_xmlDoc'}->getElementByPath($path);
    if ($XML::Mini::Debug)
    {
	if ($element)
	{
	    XML::Mini->Log("XML::MiniDoc::getElementByPath(): element at $path found.");
	  } else {
	      XML::Mini->Log("XML::MiniDoc::getElement(): element at $path NOT found.");
	    }
    }
    
    return $element;
}

sub getElement
{
    my $self = shift;
    my $name = shift;
    
    my $element = $self->{'_xmlDoc'}->getElement($name);
    
    if ($XML::Mini::Debug)
    {
	if ($element)
	{
	    XML::Mini->Log("XML::MiniDoc::getElement(): element named $name found.");
	  } else {
	      XML::Mini->Log("XML::MiniDoc::getElement(): element named $name NOT found.");
	    }
    }
    
    return $element;
}

sub fromString
{
    my $self = shift;
    my $string = shift;
    
    $self->fromSubString($self->{'_xmlDoc'}, $string);
    
    return $self->{'_xmlDoc'}->numChildren();
}

sub fromFile
{
    my $self = shift;
    my $filename = shift;
    
    return XML::Mini->Error("XML::Mini::Document::fromFile() Can't find file $filename")
	unless (-e $filename);
    
    
    return XML::Mini->Error("XML::Mini::Document::fromFile() Can't read file $filename")
	unless (-r $filename);
    
    my $contents;
    my $infile = FileHandle->new();
    $infile->open( "<$filename")
	|| return  XML::Mini->Error("XML::Mini::Document::fromFile()  Could not open $filename for read: $!");
    
    $contents = join("", $infile->getlines());

    $infile->close();
    
    return $self->fromString($contents);
}

sub toString
{
    my $self = shift;
    my $depth = shift || 0;
    
    my $retString = $self->{'_xmlDoc'}->toString($depth);
    
    $retString =~ s/<\/PSYCHOGENIC_ROOT_ELEMENT>//smi;
    
    if ($depth == $XML::Mini::NoWhiteSpaces)
    {
		$retString =~ s/<PSYCHOGENIC_ROOT_ELEMENT([^>]*)?>\s*/<?xml version="1.0"$1?>/smi;
    } else {
		$retString =~ s/<PSYCHOGENIC_ROOT_ELEMENT([^>]*)>\s*/<?xml version="1.0"$1?>\n /smi;
    }
    
    return $retString;
}

sub fromSubString
{
    my $self = shift;
    my $parentElement = shift;
    my $XMLString = shift;
    
    if ($XML::Mini::Debug) 
    {
		XML::Mini->Log("Called fromSubString() with parent '" . $parentElement->name() . "'\n");
    }
    
    
    # The heart of the parsing is here, in our mega regex
    # The sections are for:
    # <tag>...</tag>
    # <!-- comments -->
    # <singletag />
    # <![CDATA [ STUFF ]]>
    # <!DOCTYPE ... [ ... ]>
    # <!ENTITY bla "bla">
    # plain text
    #=~/<\s*([^\s>]+)([^>]+)?>(.*?)<\s*\/\\1\s*>\s*([^<]+)?(.*)
    
    while ($XMLString =~/\s*<\s*([^\s>]+)([^>]+)?>(.*?)<\s*\/\1\s*>\s*([^<]+)?(.*)|
    \s*<!--(.+?)-->\s*|
    \s*<\s*([^\s>]+)([^>]+)\/\s*>\s*([^<>]+)?|
    \s*<!\[CDATA\s*\[(.*?)\]\]\s*>\s*|
    \s*<!DOCTYPE\s*([^\[]*)\[(.*?)\]\s*>\s*|
    \s*<!ENTITY\s*([^"'>]+)\s*(["'])([^\14]+)\14\s*>\s*|
    ^([^<]+)(.*)/xogsmi)
	   

    {
	# Check which string matched.'
	my $uname = $7;
	my $comment = $6;
	my $cdata = $10;
	my $doctypedef = $12;
	my $entityname = $13;
	my $plaintext = $16;
	
	if (defined $uname)
	{
	    my $ufinaltxt = $9;
	    my $newElement = $parentElement->createChild($uname);
	    $self->_extractAttributesFromString($newElement, $8);
	    if (defined $ufinaltxt && $ufinaltxt =~ m|\S+|)
	    {
		$parentElement->createNode($ufinaltxt);
	    }
	} elsif (defined $comment) {
	    #my $newElement = XML::Mini::Element::Comment->new('!--');
	    #$newElement->createNode($comment);
	    $parentElement->comment($comment);
	} elsif (defined $cdata) {
	    my $newElement = XML::Mini::Element::CData->new($cdata);
	    $parentElement->appendChild($newElement);
	} elsif (defined $doctypedef) {
	    my $newElement = XML::Mini::Element::DocType->new($11);
	    $parentElement->appendChild($newElement);
	    $self->fromSubString($newElement, $doctypedef);
	    
	} elsif (defined $entityname) {
	    
	    my $newElement = XML::Mini::Element::Entity->new($entityname, $15);
	    $parentElement->appendChild($newElement);
	    
	} elsif (defined $plaintext) {
	    
	    my $afterTxt = $17;
	    if ($plaintext !~ /^\s+$/)
	    {
		$parentElement->createNode($plaintext);
	    }
	    
	    if (defined $afterTxt)
	    {
		$self->fromSubString($parentElement, $afterTxt);
	    }
	} elsif ($1) {
	    
	    my $nencl = $3;
	    my $finaltxt = $4;
	    my $otherTags = $5;
	    my $newElement = $parentElement->createChild($1);
	    $self->_extractAttributesFromString($newElement, $2);
	    
	    
	    if ($nencl =~ /^\s*([^\s<][^<]*)/)
	    {
		my $txt = $1;
		$newElement->createNode($txt);
		$nencl =~ s/^\s*[^<]+//;
	    }
	    
	    $self->fromSubString($newElement, $nencl);
	    
	    if (defined $finaltxt)
	    {
		$parentElement->createNode($finaltxt);
	    }
	    
	    if (defined $otherTags)
	    {
		$self->fromSubString($parentElement, $otherTags);
	    }
	}
    } # end while matches
} #* end method fromSubString */

sub toFile
{
    my $self = shift;
    my $filename = shift || return XML::Mini->Error("XML::Mini::Document::toFile - must pass a filename to save to");
    my $safe = shift;
    
    my $dir = $filename;
    
    $dir =~ s|(.+/)?[^/]+$|$1|;
    
    if ($dir)
    {
	return XML::Mini->Error("XML::Mini::Document::toFile - called with file '$filename' but cannot find director $dir")
	    unless (-e $dir && -d $dir);
	return XML::Mini->Error("XML::Mini::Document::toFile - called with file '$filename' but no permission to write to dir $dir")
	    unless (-w $dir);
    }
    
    my $contents = $self->toString();
    
    return XML::Mini->Error("XML::Mini::Document::toFile - got nothing back from call to toString()")
	unless ($contents);
    
    my $outfile = FileHandle->new();
    
    if ($safe)
    {
	if ($filename =~ m|/\.\./| || $filename =~ m|#;`\*|)
	{
	    return XML::Mini->Error("XML::Mini::Document::toFile() Filename '$filename' invalid with SAFE flag on");
	}
	    
	if (-e $filename)
	{
	    if ($safe =~ /NOOVERWRITE/i)
	    {
		return XML::Mini->Error("XML::Mini::Document::toFile() file '$filename' exists and SAFE flag is '$safe'");
	    }
	    
	    if (-l $filename)
	    {
		return XML::Mini->Error("XML::Mini::Document::toFile() file '$filename' is a "
					. "symbolic link and SAFE flag is on");
	    }
	}
    }

    $outfile->open( ">$filename")
	|| return  XML::Mini->Error("XML::Mini::Document::toFile()  Could not open $filename for write: $!");
    $outfile->print($contents);
    $outfile->close();
    return length($contents);
}

sub getValue
{
    my $self = shift;
    return $self->{'_xmlDoc'}->getValue();
}

sub dump
{
    my $self = shift;
    return Dumper($self);
}

#// _extractAttributesFromString
#// private method for extracting and setting the attributs from a
#// ' a="b" c = "d"' string
sub _extractAttributesFromString
{
    my $self = shift;
    my $element = shift;
    my $attrString = shift;
    
    return undef unless (defined $attrString);
    my $count = 0;
    while ($attrString =~ /([^\s]+)\s*=\s*(['"])([^\2]+?)\2/g)
    {
	my $attrname = $1;
	my $attrval = $3;
	
	if (defined $attrname)
	{
	    $element->attribute($attrname, $attrval, '');
	    $count++;
	}
    }
    
    return $count;
}

1;

__END__

=head1 NAME

XML::Mini::Document - Perl implementation of the XML::Mini Document API.

=head1 SYNOPSIS

	use XML::Mini::Document;
	
	my $xmlDoc = XML::Mini::Document->new();
	
	# init the doc from an XML string
	$xmlDoc->fromString($XMLString);
	
	# Fetch the ROOT element for the document
	# (an instance of XML::Mini::Element)
	my $xmlElement = $xmlDoc->getRoot();
	
	# play with the element and its children
	# ...
	
	# output the document
	print $xmlDoc->toString();
	

=head1 DESCRIPTION

The XML::Mini::Document class is the programmer's handle to XML::Mini functionality.

A XML::Mini::Document instance is created in every program that uses XML::Mini.
With the XML::Mini::Document object, you can access the root XML::Mini::Element, 
find/fetch/create elements and read in or output XML strings.


=head2 new [XMLSTRING]

Creates a new instance of XML::Mini::Document, optionally calling
fromString with the passed XMLSTRING

=head2 getRoot

Returns a reference the this document's root element
(an instance of XML::Mini::Element)

=head2 setRoot NEWROOT

setRoot NEWROOT
Set the document root to the NEWROOT XML::Mini::Element object.

=head2 isElement ELEMENT

Returns a true value if ELEMENT is an instance of XML::Mini::Element,
false otherwise.

=head2 isNode NODE

Returns a true value if NODE is an instance of XML::MiniNode,
false otherwise.

=head2 createElement NAME [VALUE]

Creates a new XML::Mini::Element with name NAME.

This element is an orphan (has no assigned parent)
and will be lost unless it is appended (XML::Mini::Element::appendChild())
to an element at some point.

If the optional VALUE (string or numeric) parameter is passed,
the new element's text/numeric content will be set using VALUE.
Returns a reference to the newly created element.

=head2 getElement NAME

Searches the document for an element with name NAME.

Returns a reference to the first XML::Mini::Element with name NAME,
if found, NULL otherwise.

NOTE: The search is performed like this, returning the first 
element that matches:

 - Check the Root Element's immediate children (in order) for a match.
 - Ask each immediate child (in order) to XML::Mini::Element::getElement()
  (each child will then proceed similarly, checking all it's immediate
   children in order and then asking them to getElement())

=head2 getElementByPath PATH

Attempts to return a reference to the (first) element at PATH
where PATH is the path in the structure from the root element to
the requested element.

For example, in the document represented by:

	 <partRateRequest>
	  <vendor>
	   <accessid user="myusername" password="mypassword" />
	  </vendor>
	  <partList>
	   <partNum>
	    DA42
	   </partNum>
	   <partNum>
	    D99983FFF
	   </partNum>
	   <partNum>
	    ss-839uent
	   </partNum>
	  </partList>
	 </partRateRequest>

 	$accessid = $xmlDocument->getElementByPath('partRateRequest/vendor/accessid');

Will return what you expect (the accessid element with attributes user = "myusername"
and password = "mypassword").

BUT be careful:

	my $accessid = $xmlDocument->getElementByPath('partRateRequest/partList/partNum');

will return the partNum element with the value "DA42".  Other partNums are 
inaccessible by getElementByPath() - Use XML::Mini::Element::getAllChildren() instead.

Returns the XML::Mini::Element reference if found, NULL otherwise.

=head2 fromString XMLSTRING

Initialise the XML::Mini::Document (and it's root XML::Mini::Element) using the 
XML string XMLSTRING.

Returns the number of immediate children the root XML::Mini::Element now
has.

=head2 fromFile FILENAME

Initialise the XML::Mini::Document (and it's root XML::Mini::Element) using the
XML from file FILNAME.

Returns the number of immediate children the root XML::Mini::Element now
has.

=head2 toString [DEPTH]

Converts this XML::MiniDoc object to a string and returns it.

The optional DEPTH may be passed to set the space offset for the
first element.

If the optional DEPTH is set to $XML::Mini::NoWhiteSpaces
no \n or whitespaces will be inserted in the xml string
(ie it will all be on a single line with no spaces between the tags.

Returns a string of XML representing the document.

=head2 toFile FILENAME [SAFE]

Stringify and save the XML document to file FILENAME

If SAFE flag is passed and is a true value, toFile will do some extra checking, refusing to open the file
if the filename matches m|/\.\./| or m|#;`\*| or if FILENAME points to a softlink.  In addition, if SAFE
is 'NOOVERWRITE', toFile will fail if the FILENAME already exists.

=head2 getValue

Utility function, call the root XML::Mini::Element's getValue()

=head2 dump

Debugging aid, dump returns a nicely formatted dump of the current structure of the
XML::MiniDoc object.

=head1 AUTHOR

LICENSE

    XML::Mini::Document module, part of the XML::Mini XML parser/generator package.
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


XML::Mini, XML::Mini::Element

http://minixml.psychogenic.com

=cut
