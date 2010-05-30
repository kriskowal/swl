
When writing web-sites, you typically either write the HTML
code or use a 'WYSIWYG' (What You See Is What You Get)
editor to make it for you.  Some sites use dynamic content
languages, e.g., ASP or PHP, to generate their code for them
on the fly.  SWL is an efficient alternative to each of
these.

What is SWL
-----------

SWL is, simply put, abbreviated HTML.  In fact, with a 2
character header, most HTML files can be put directly into a
SWL file and compile back to the same HTML they started out
as.  <b>But</b>, SWL offers an alternative to writing 'bulk
HTML', through the use of 'line-tags'.  A line-tag is a
brief ID (usually a single character) followed by a closed
angle bracket, '&gt;'.

Using line-tags, you can reduce:

    <table>
        <tr>
            <td> A1 </td>
            <td> B1 </td>
        </tr>
        <tr>
            <td> A2 </td>
            <td> B2 </td>
        </tr>
    </table>

To:

    t>
        A1      B1
        A2      B2
    />

Benefits
--------

* <b>Easy</b> to learn.  <b>Easy</b> to write.  <b>Easy</b>
  to use.
* <b>Brevity.</b>  SWL code is as short as it gets.  SWL
  source files (<u><i>without</i></u> file includes) tend to
  be one half to one third the size of the HTML they generate.
* <b>Brevity.</b>  The HTML that SWL outputs doesn't include
  unnecessary information.  WYSIWYG editors tend to put lots
  of junk line breaks and font information.
* <b>Brevity.</b>  Copy a document you want to publish into
  a text 'SWL' file.  It's almost ready for publication.  Your
  paragraphs are already set.  To format your headings will
  take 2 characters each.  To format your tables usually takes
  the addition of 4 characters.
* <b>No loss in developing potential.</b>  Anything that SWL
  doesn't recognize won't be changed in your object HTML.
* <b>Plays well with others.</b>  SWL is perfect for use
  with CSS (Cascading Style Sheets).  A lot of the junk that
  WYSIWYG editors pump out is for formatting each individual
  section.  Using a style sheet in your SWL template will
  automatically make every similar tag look the same, without
  junk code.  Most document editors (e.g., MS Word, Adobe
  Pagemaker) already include 'style' information which can be
  directly interpreted into SWL.  You could even write your
  PHP in SWL with just a flip of the template.
* <b>Plays well with others.</b>  SWL can import data from
  plain text, HTML, tab delimited text, and comma separated
  values (CSV).
* <b>Clean HTML.</b>  The ugliest SWL code outputs to
  easy-to-read HTML.  SWL indents nested tags and puts white
  space between major sections.
* <b>Efficiency</b>.  Once you compile your SWL into HTML,
  it's done.  When you use PHP and ASP to generate your pages,
  your web server has to start a program to compile it
  <b>every</b> time someone looks at it on the web.  You only
  have to compile SWL once.
* <b>Extensibility</b>.  You can make your own 'SWL tags' on
  the fly in your document.  You can use SWL's internal
  variables to change the ones it already has.  You can create
  templates and template modifications on the fly in your SWL
  documents, or include them from an external SWL library.
* <b>You don't have to be a programmer.</b>  You could teach
  a monkey to write 'SWL' and they would like it so much
  that they would forget to eat.
* Etc.

Syntax
------

SWL is like HTML in that HTML tags can be put into a SWL
document and will be preserved.  Unline HTML, SWL is
in-line.  That is, in HTML, you can have a paragraph
spanning multiple lines in your code.  In SWL, each line of
code is assumed to be a unique, self-contained paragraph.
Using 'tags' at the beginning of a line, you can specify
different formatting behavior for an individual line of code
or a range of lines, using the following syntacies.

Single Line of 'Tag' Formatting

    tag> single line of content

Multiple Lines on which 'Tag' will operate.

	tag>
		content lines
		content lines
	/>

To see the various ways to you can format your code, refer
to the tag reference.

Nested Tags

By nesting tags, you can create outlines, break out rows in
tables, and much more.  Here's the general idea:

Through SWL's system of tag nesting, all of the following
syntacies are functionally the same:

	a>
		b>
			content
		/>
	/>

	a>
		b>content
	/>

	a.b> content

Note that there are 2 closing tags nested in this example.

	a.b>
		content
	/./>

So, this also works.

	a.b>
			content
		/>
	/>

Links and Images

By simply enclosing links or image file URL's in spaced
angle-brackets, you can automatically create full image or
anchor tags without the syntax hastle.  These tags can be
placed anywhere in your code, not constrained to the
beginning of the line.  <b>Note:</b> the space after the
opening &lt; is required.  SWL will assume that any URL's
containing the <i>@</i> (at) symbol are email links.  Images
must end with <i>.gif</i>, <i>.jpg</i>, <i>.jpeg</i>,
<i>.svg</i> or <i>.png</i>.  I have ambitions of adding
support for other media extentions.

	< link link_text >
	< image alternate_text properties >
	< "link with spaces" "link text with spaces" >
	< "image file name" "alternate text" "properties with spaces" >


Your Web Root
-------------

SWL makes your website portable.  You can specify in a
single location where your entire document tree lies on the
web.  This allows SWL to manage all of your links when you
move your site.  All you have to do is change the
<tt>root</tt> variable and forcibly recompile your entire
site (which is only one command).

To use this feature, specify your web root in your template
(usually <tt>local.swlt</tt> or <tt>@.swlt</tt> in your
document root) and use <tt>~/</tt> in all of your links to
specify that your link is relative to your web root.  For
example:

	=.root>//cixar.com/~swilly
	< ~/index.html "Swilly's Homepage" >


Mangle Your Email Addresses
---------------------------

SWL can mangle your site's email addresses to reduce the
risk of web crawlers harvesting your email for unsolicited
email, SPAM.  To activate this feature, specify the
<tt>email-mangle</tt> variable in your site template and
forcibly recompile your site with the command "<tt>swl -f
.</tt>".

	=.email-mangle>yes

