package XML::Mini::Document;
use strict;
$^W = 1;

use FileHandle;

use XML::Mini;
use XML::Mini::Element;
use XML::Mini::Element::Comment;
use XML::Mini::Element::Header;
use XML::Mini::Element::CData;
use XML::Mini::Element::DocType;
use XML::Mini::Element::Entity;
use XML::Mini::Node;

use vars qw ( 	$VERSION
		$TextBalancedAvailable
	 );
	 
eval "use Text::Balanced qw(extract_tagged)";
if ($@)
{
	$TextBalancedAvailable = 0;
} else {
	$TextBalancedAvailable = 1;
}


$VERSION = '1.27';

sub new
{
    my $class = shift;
    my $string = shift;
    
    my $self = {};
    bless $self, ref $class || $class;
    
    $self->init();
    
    if (defined $string)
    {
	$self->fromString($string);
    }
    
    return $self;
}

sub init {
	my $self = shift;
	delete $self->{'_xmlDoc'};
	
	$self->{'_xmlDoc'} = XML::Mini::Element->new("PSYCHOGENIC_ROOT_ELEMENT");
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
    my @elementNumbers = @_;
    
    my $element = $self->{'_xmlDoc'}->getElementByPath($path, @elementNumbers);
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
    my $elementNumber = shift; # optionally get only the ith element
    
    my $element = $self->{'_xmlDoc'}->getElement($name, $elementNumber);
    
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
    
    my $fRef = \$filename;
    my $contents;
    if (ref($filename) && UNIVERSAL::isa($filename, 'IO::Handle'))
    {
	$contents = join("", $filename->getlines());
	$filename->close();

    } elsif (ref $fRef eq 'GLOB') {
    
    	$contents = join('', $fRef->getlines());
	$fRef->close();
	
    } elsif (ref $fRef eq 'SCALAR') {
    
	return XML::Mini->Error("XML::Mini::Document::fromFile() Can't find file $filename")
		unless (-e $filename);
    
    
	return XML::Mini->Error("XML::Mini::Document::fromFile() Can't read file $filename")
		unless (-r $filename);
	
	my $infile = FileHandle->new();
	$infile->open( "<$filename")
		|| return  XML::Mini->Error("XML::Mini::Document::fromFile()  Could not open $filename for read: $!");
	$contents = join("", $infile->getlines());
	$infile->close();
    }
    
    return $self->fromString($contents);
}

sub parse 
{
	my $self = shift;
	my $input = shift;
	
	my $inRef = \$input;
	my $type = ref($inRef);
	
	if ($type eq 'SCALAR' && $input =~ m|<[^>]+>|sm)
	{
		# we have some XML
		return $self->fromString($input);
		
	} else {
		# hope it's a file name or handle
		return $self->fromFile($input);
	}
	
}


sub toString
{
    my $self = shift;
    my $depth = shift || 0;
    
    my $retString = $self->{'_xmlDoc'}->toString($depth);
    
    $retString =~ s/<\/PSYCHOGENIC_ROOT_ELEMENT>//smi;
    $retString =~ s/<PSYCHOGENIC_ROOT_ELEMENT([^>]*)?>\s*//smi;
    
    
    return $retString;
}

sub fromSubStringBT {
	my $self = shift;
	my $parentElement = shift;
   	my $XMLString = shift;
	my $useIgnore = shift;
	
	if ($XML::Mini::Debug) 
	{
		XML::Mini->Log("Called fromSubStringBT() with parent '" . $parentElement->name() . "'\n");
	}
	
	my @res;
	if ($useIgnore)
	{
		my $ignore = [ '<\s*[^\s>]+[^>]*\/\s*>',	# <unary \/>
			'<\?\s*[^\s>]+\s*[^>]*\?>', # <? headers ?>
			'<!--.+?-->',			# <!-- comments -->
			'<!\[CDATA\s*\[.*?\]\]\s*>\s*', 	# CDATA 
			'<!DOCTYPE\s*([^\[]*)\[(.*?)\]\s*>',	# DOCTYPE
			'<!ENTITY\s*[^>]+>'
		];
		
		@res = Text::Balanced::extract_tagged($XMLString, undef, undef, undef, { 'ignore' => $ignore });
	} else {
		@res = Text::Balanced::extract_tagged($XMLString);
	}
	
	if ($#res == 5)
	{
		# We've extracted a balanced <tag>..</tag>
	
		my $extracted = $res[0]; # the entire <t>..</t>
		my $remainder = $res[1]; # stuff after the <t>..</t>HERE  - 3
		my $prefix = $res[3]; # the <t ...> itself - 1
		my $contents = $res[4]; # the '..' between <t>..</t> - 2
		my $suffix = $res[5]; # the </t>
		
		#XML::Mini->Log("Grabbed prefix '$prefix'...");
		my $newElement;
		
		if ($prefix =~ m|<\s*([^\s>]+)\s*([^>]*)>|)
		{
			my $name = $1;
			my $attribs = $2;
			$newElement = $parentElement->createChild($name);
	    		$self->_extractAttributesFromString($newElement, $attribs) if ($attribs);
			
			$self->fromSubStringBT($newElement, $contents) if ($contents =~ m|\S|);
			
			$self->fromSubStringBT($parentElement, $remainder) if ($remainder =~ m|\S|);
		} else {
			
			XML::Mini->Log("XML::Mini::Document::fromSubStringBT extracted balanced text from invalid tag '$prefix' - ignoring");
    		}
	} else {
	
		$XMLString =~ s/>\s*\n/>/gsm;
		if ($XMLString =~ m/^\s*<\s*([^\s>]+)[^>]*>.*<\s*\/\1\s*>/osm)
		{
			# starts with a normal <tag> ... </tag> but has some ?? in it
			
			return $self->fromSubStringBT($parentElement, $XMLString, 'USEIGNORE');
		}
	
		# not a <tag>...</tag>
		#it's either a                             
		if ($XMLString =~ m/^\s*(<\s*([^\s>]+)([^>]+)\/\s*>|	# <unary \/>
					 <\?\s*([^\s>]+)\s*([^>]*)\?>|	# <? headers ?>
					 <!--(.+?)-->|			# <!-- comments -->
					 <!\[CDATA\s*\[(.*?)\]\]\s*>\s*| 	# CDATA 
					 <!DOCTYPE\s*([^\[]*)\[(.*?)\]\s*>\s*|	# DOCTYPE
					 <!ENTITY\s*([^"'>]+)\s*(["'])([^\11]+)\11\s*>\s*| # ENTITY
					 ([^<]+))(.*)/xogsmi) # plain text
		{
			my $firstPart	 = $1;
			my $unaryName 	 = $2;
			my $unaryAttribs = $3;
			my $headerName 	 = $4;
			my $headerAttribs= $5;
			my $comment 	 = $6;
			my $cdata	 = $7;
			my $doctype	 = $8;
			my $doctypeCont  = $9;
			my $entityName	 = $10;
			my $entityCont	 = $12;
			my $plainText	 = $13;
			my $remainder 	 = $14;
			
			# There is some duplication here that should be merged with that in fromSubString()
			if ($unaryName)
			{
				my $newElement = $parentElement->createChild($unaryName);
				$self->_extractAttributesFromString($newElement, $unaryAttribs) if ($unaryAttribs);
			} elsif ($headerName)
			{
				my $newElement = XML::Mini::Element::Header->new($headerName);
				$self->_extractAttributesFromString($newElement, $headerAttribs) if ($headerAttribs);
				$parentElement->appendChild($newElement);
			} elsif (defined $comment) {
				$parentElement->comment($comment);
			} elsif (defined $cdata) {
				my $newElement = XML::Mini::Element::CData->new($cdata);
				$parentElement->appendChild($newElement);
			} elsif (defined $doctypeCont) {
				my $newElement = XML::Mini::Element::DocType->new($doctype);
				$parentElement->appendChild($newElement);
				$self->fromSubStringBT($newElement, $doctypeCont);
			} elsif (defined $entityName) {
				my $newElement = XML::Mini::Element::Entity->new($entityName, $entityCont);
				$parentElement->appendChild($newElement);
			} elsif (defined $plainText && $plainText =~ m|\S|sm)
			{
				$parentElement->createNode($plainText);
			} else {
				XML::Mini->Log("NO MATCH???") if ($XML::Mini::Debug);
			}
			
			
			if (defined $remainder && $remainder =~ m|\S|sm)
			{
				$self->fromSubStringBT($parentElement, $remainder);
			}
			
		} else {
			# No match here either...
			XML::Mini->Log("No match in fromSubStringBT() for '$XMLString'") if ($XML::Mini::Debug);
			
		} # end if it matches one of our other tags or plain text
		
	} # end if Text::Balanced returned a match
	
	
} # end fromSubStringBT()
			
	
    

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
    
    
    if ($TextBalancedAvailable)
    {
    	return $self->fromSubStringBT($parentElement, $XMLString);
    }
    
    while ($XMLString =~/\s*<\s*([^\s>]+)([^>]+)?>(.*?)<\s*\/\1\s*>\s*([^<]+)?(.*)|
    \s*<!--(.+?)-->\s*|
    \s*<\s*([^\s>]+)\s*([^>]*)\/\s*>\s*([^<>]+)?|
    \s*<!\[CDATA\s*\[(.*?)\]\]\s*>\s*|
    \s*<!DOCTYPE\s*([^\[]*)\[(.*?)\]\s*>\s*|
    \s*<!ENTITY\s*([^"'>]+)\s*(["'])([^\14]+)\14\s*>\s*|
    \s*<\?\s*([^\s>]+)\s*([^>]*)\?>|
    ^([^<]+)(.*)/xogsmi)
	   

    {
	# Check which string matched.'
	my $uname = $7;
	my $comment = $6;
	my $cdata = $10;
	my $doctypedef = $12;
	my $entityname = $13;
	my $headername = $16;
	my $headerAttribs  = $17;
	my $plaintext = $18;
	
	if (defined $uname)
	{
	    my $ufinaltxt = $9;
	    my $newElement = $parentElement->createChild($uname);
	    $self->_extractAttributesFromString($newElement, $8);
	    if (defined $ufinaltxt && $ufinaltxt =~ m|\S+|)
	    {
		$parentElement->createNode($ufinaltxt);
	    }
	} elsif (defined $headername)
	{
		my $newElement = XML::Mini::Element::Header->new($headername);
		$self->_extractAttributesFromString($newElement, $headerAttribs) if ($headerAttribs);
		$parentElement->appendChild($newElement);
	
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
	    
	    my $afterTxt = $19;
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
	$xmlDoc->parse($XMLString);
	
	# Fetch the ROOT element for the document
	# (an instance of XML::Mini::Element)
	my $xmlRoot = $xmlDoc->getRoot();
	
	# play with the element and its children
	# ...
	my $topLevelChildren = $xmlRoot->getAllChildren();
	
	foreach my $childElement (@{$topLevelChildren})
	{
		# ...
	}
	
	
	# Create a new document
	my $newDoc = XML::Mini::Document->new();
	my $newDocRoot = $newDoc->getRoot();
	
	# create the <? xml ?> header
	my $xmlHeader = $newDocRoot->header('xml');
	# add the version 
	$xmlHeader->attribute('version', '1.0');
	
	my $person = $newDocRoot->createChild('person');
	
	my $name = $person->createChild('name');
	$name->createChild('first')->text('John');
	$name->createChild('last')->text('Doe');
	
	my $eyes = $person->createChild('eyes');
	$eyes->attribute('color', 'blue');
	$eyes->attribute('number', 2);
	
	# output the document
	print $newDoc->toString();
	
	
This example would output :

 

 <?xml version="1.0"?>
  <person>
   <name>
    <first>
     John
    </first>
    <last>
     Doe
    </last>
  </name>
  <eyes color="blue" number="2" />
  </person>


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

=head2 getElement NAME [POSITON]

Searches the document for an element with name NAME.

Returns a reference to the first XML::Mini::Element with name NAME,
if found, NULL otherwise.

NOTE: The search is performed like this, returning the first 
element that matches:

 - Check the Root Element's immediate children (in order) for a match.
 - Ask each immediate child (in order) to XML::Mini::Element::getElement()
  (each child will then proceed similarly, checking all it's immediate
   children in order and then asking them to getElement())
   
If a numeric POSITION parameter is passed, getElement() will return only 
the POSITIONth element of name NAME (starting at 1).  Thus, on document
 

  <?xml version="1.0"?>
  <people>
   <person>
    bob
   </person>
   <person>
    jane
   </person>
   <person>
    ralph
   </person>
  </people>


$people->getElement('person') will return the element containing the text node
'bob', while $people->getElement('person', 3) will return the element containing the 
text 'ralph'.



=head2 getElementByPath PATH [POSITIONARRAY]

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

will return the partNum element with the value "DA42".  To access other partNum elements you
must either use the POSITIONSARRAY or the getAllChildren() method on the partRateRequest element.

POSITIONSARRAY functions like the POSITION parameter to getElement(), but instead of specifying the
position of a single element, you must indicate the position of all elements in the path.  Therefore, to
get the third part number element, you would use

	my $thirdPart = $xmlDocument->getElementByPath('partRateRequest/partList/partNum', 1, 1, 3);
	
The additional 1,1,3 parameters indicate that you wish to retrieve the 1st partRateRequest element in 
the document, the 1st partList child of partRateRequest and the 3rd partNum child of the partList element
(in this instance, the partNum element that contains 'ss-839uent').


Returns the XML::Mini::Element reference if found, NULL otherwise.


=head2 parse SOURCE

Initialise the XML::Mini::Document (and its root XML::Mini::Element) using the
XML from file SOURCE.

SOURCE may be a string containing your XML document.

In addition to parsing strings, possible SOURCEs are:
 

	# a file location string 
	$miniXMLDoc->parse('/path/to/file.xml');
	
	# an open file handle
	open(INFILE, '/path/to/file.xml');
	$miniXMLDoc->parse(*INFILE);
	
	# an open FileHandle object
	my $fhObj = FileHandle->new();
	$fhObj->open('/path/to/file.xml');
	$miniXML->parse($fhObj);
	
In all cases where SOURCE is a file or file handle, XML::Mini takes care of slurping the
contents and closing the handle.


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


=head1 CAVEATS

It is impossible to parse "cross-nested" tags using regular expressions (i.e. sequences of the form
<a><b><a>...</a></b></a>).  However, if you have the Text::Balanced module installed (it is installed 
by default with Perl 5.8), such sequences will be handled flawlessly.

Even if you do not have the Text::Balanced module available, it is still possible to generate this type
of XML - the problem only appears when parsing.

=head1 AUTHOR


Copyright (C) 2002-2003 Patrick Deegan, Psychogenic Inc.

Programs that use this code are bound to the terms and conditions of the GNU GPL (see the LICENSE file). 
If you wish to include these modules in non-GPL code, you need prior written authorisation 
from the authors.


LICENSE

    XML::Mini::Document module, part of the XML::Mini XML parser/generator package.
    Copyright (C) 2002-2003 Patrick Deegan
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

Contact page for author available at http://www.psychogenic.com/

=head1 SEE ALSO


XML::Mini, XML::Mini::Element

http://minixml.psychogenic.com

=cut
