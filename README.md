# <span style="font-style:normal; font-weight:normal; font-size:.5em; ">Section 1.</span>&nbsp;&nbsp;Heading numbering utility

The *sectionator.lua* Pandoc filter enables convenient section heading
numbering and with added control. You can specify options within the
YAML header that apply to *all* section headings *or* after each
heading, *normally* applicable to that heading only.

> **Regarding .docx documents:** Because .docx uses its own internal
> numbering system and because I felt it was more important to allow
> headings to renumber fluidly within a Word document rather than to
> remain unchanged as material was added or subtracted, the only
> parameter that works for .docx files is the *numbering* parameter. It
> can be turned on and off and selectively disabled; other parameters
> likely will not work for .docx.

Generally, you’ll enable section numbering for your entire document
within the YAML header. For example,

`sectionator: numbering=true`

Then, numbering for individual headings may be disabled per the normal
markdown notation, e.g.,

`My Heading{-}`

Or, they may be disabled for the remainder of the document (or
re-enabled) with the `numbering` parameter as follows:

`My Heading{numbering=false}`

You’ll find additional options below.

## <span style="font-style:normal; font-weight:normal; font-size:.5em; ">Section 1.1</span>&nbsp;&nbsp;For even more flexibility…

In addition to being able to specify heading parameters globally (with
the YAML header statement *sectionator*), you can also further specify
them for each document *type* being output by prefacing a parameter with
the document type and colon. For example, below we specify we wish the
word “Section” to appear before the heading number and that the section
number be separated from the heading with a colon and two spaces, but
*only* for html documents.

Within the YAML header:

`sectionator: html:hdg_label="Section", html:hdg_sep=":__"`

or following a heading within curly braces:

`My Heading{html:hdg_label="Section" html:hdg_sep=":__"}`

## <span style="font-style:normal; font-weight:normal; font-size:.5em; ">Section 1.2</span>&nbsp;&nbsp;Summary of options

- numbering – Heading numbering: on/true, off/false. Turns numbering on
  or off.
- number_reset_to – Reset heading number to indicated value. Sub-nums
  are reset to 1.
- hdg_label – Custom heading preface, e.g., “Section”. (Does not work
  with .docx documents as .docx uses its own numbering scheme.)
- hdg_label_size – Label relative font size
- hdg_label_style – Label style
- hdg_sep – Separator between heading section number and heading
- keep_with_next – (For latex/pdf.) Move heading to next page if within
  n lines of bottom. Prevents orphans.

## <span style="font-style:normal; font-weight:normal; font-size:.5em; ">Section 1.3</span>&nbsp;&nbsp;Document formats supported

It is assumed you already have installed Pandoc. If not, information is
provided [here](https://pandoc.org/installing.html).

Currently this filter supports the following document conversions from
markdown:

- html — For web
- docx — Regarding MS Word documents: limited to *numbering* only
  because .docx uses its own, internal numbering scheme.
- pdf — For convenient document exchange. If you intend to create pdf or
  latex documents, you will need to have *LaTex* installed. Click
  [here](https://www.latex-project.org/get/) for more information.
- latex — For typesetting and pdf conversion.
- epub — For commonly available e-published format

## <span style="font-style:normal; font-weight:normal; font-size:.5em; ">Section 1.4</span>&nbsp;&nbsp;Parameter details

| Parameter       | Notes                                                                                                                                                                                                                                                                                                                                                                              | Default                      | Examples                                                                          |
|:----------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:-----------------------------|:----------------------------------------------------------------------------------|
| numbering       | Turns heading numbering on or off (with true/false)                                                                                                                                                                                                                                                                                                                                | false                        | `numbering=true`                                                                  |
| number_reset_to | Reset heading number to value indicated. Sub-nums are reset to 1.                                                                                                                                                                                                                                                                                                                  | 1                            | `number_reset_to=8`                                                               |
| hdg_label       | Custom heading preface, e.g., “Section”. (Note, this does not work with .docx documents as .docx uses its own numbering scheme.)                                                                                                                                                                                                                                                   | none                         | `numbering=true`                                                                  |
| hdg_label_size  | Label relative font size. Options include: “tiny”, “smaller”, “small”, “normal”, “large”, “larger”, “huge”                                                                                                                                                                                                                                                                         | normal                       | `hdg_label_size="small"`                                                          |
| hdg_label_style | Label style. Options include “plain”, “normal”, “italic”, “bold”, “oblique”, “bold-oblique”, “bold-italic”                                                                                                                                                                                                                                                                         |                              |                                                                                   |
| hdg_sep         | Separator between heading section number and heading                                                                                                                                                                                                                                                                                                                               | `:__` (colon and two spaces) | `:_`, `_--_`, `___`, etc.                                                         |
| keep_with_next  | (For latex/pdf docs only.) Prevents headings from being orphaned when near page bottom. If you find a heading alone, it’s often because latex encountered an image(s) or other situation that complicated optimum page composition. In such case, use *keep_with_next* and specify a number of lines exceeding the equivalent number of lines between the heading and page bottom. | 4                            | If near page bottom, e.g., `keep_with_next=5`. If farther up, `keep_with_next=30` |

## <span style="font-style:normal; font-weight:normal; font-size:.5em; ">Section 1.5</span>&nbsp;&nbsp;Invoking filter from Pandoc

This filter can be invoked on the command line with the “–lua-filter”
option, e.g., “--lua-filter=sectionator.lua”. An example might be

`pandoc -f markdown -t html myfile.md -o myfile.html --lua-filter=./sectionator.lua -s`

Alternatively, if you are working within an environment like R-Studio
that runs Pandoc, it may be included in the YAML header, for example,

<pre><code>
---
title: \"My extraordinarily beautiful document\" 
output:
  html_document:
    <span style="color:#45c">pandoc_args: [\"--lua-filter=sectionator.lua\"]</span>
---
</code></pre>

## <span style="font-style:normal; font-weight:normal; font-size:.5em; ">Section 1.6</span>&nbsp;&nbsp;Include this package for orphan protection

For Pandoc conversion into Latex and pdf, this package statement should
be included in the latex template file to enable the keep_with_next
option.

`\usepackage{needspace}`

#### <span style="font-style:normal; font-weight:normal; font-size:.5em; "></span>I hope you find some of this useful. I welcome any corrections, feedback and suggestions!

George
