--  Copyright 2022 George Markle - 22/11/28
-- Global variables that must be available for both Meta and heading processing
local stringify = (require "pandoc.utils").stringify
local err_msg = "" -- Init
local hdg_text -- Current heading text
local dims = {"%", "in", "inches", "px", "pixels", "cm", "mm"}

local level = 0 -- Init heading level
local prev_level = 0 -- Previous heading level -- Init level to be incremented
local valid_hdg_attr_names =
    { -- Names of valid parameters. Each parameter and its value separated by "="
        "keep_with_next", -- For latex/pdf: If header orphaned, move to next page if within x lines of bottom.
        "numbering", -- Heading numbering: on/true, off/false. Turns numbering on or off.
        "number_reset_to", -- Reset heading number to indicated value. Sub-nums reset to 1.
        "hdg_label", -- Custom heading preface, e.g., "Section", "Appendix", etc.
        "hdg_label_size", -- Label font size
        "hdg_label_style", -- Label style
        "hdg_sep", -- Heading separator between number and heading
        "hdg_targ" -- Heading link target
    }
local hdg_params = {} -- Contains heading parameters {["param"],{default, global, this}}
local default_i = 1 -- 'Default' column of heading params table
local global_i = 2 -- 'Global' column of heading params table
local this_i = 3 -- 'This heading-specific' column of heading params table

-- Section label type allows defining numbered sections with custom labels
local hdg_labels = {}
local hdg_label = ""
local hdg_lbl = ""
local hdg_label_size
local hdg_nums = {} -- Holds current number associated with heading level
hdg_nums[1] = 0 -- Init first section#
local hdg_number = ""
local hdg_nm = ""
local numbering -- true/false, indicates if numbering active
local prev_numbering = false -- Allows latex heading numbering to be set only if status change
local hdg_sep = ""
local label_sep1 -- 1st label separater part will have same style as label
local label_sep2 -- 2nd label separater part will have same style as heading
local hdg_targ -- Heading link target

-- Heading text lists
local section_numbers = {-1, 0, 1, 2, 3, 4, 5} -- Follow Latex conventions
local section_names = {
    "part", "chapter", "section", "subsection", "subsubsection", "paragraph",
    "subparagraph"
}

local label_sizes = {
    "tiny", "smaller", "small", "normal", "large", "larger", "huge"
}
local hdg_ltx_label_sizes = { -- heading text sizes
    -- ["tiny"] = '\\small{X}',
    -- ["smaller"] = '\\small{X}',
    -- ["small"] = '\\small{X}',
    -- ["normal"] = "\\normalsize{X}",
    -- ["large"] = '\\large{X}',
    -- ["larger"] = '\\large{X}',
    -- ["huge"] = '\\large{X}'
    ["tiny"] = '{\\tiny X}',
    ["smaller"] = '{\\footnotesize X}',
    ["small"] = '{\\small X}',
    ["normal"] = "{\\normalsize X}",
    ["large"] = '{\\large X}',
    ["larger"] = '{\\Large X}',
    ["huge"] = '{\\LARGE X}'
}
local hdg_html_label_sizes = { -- heading text sizes
    ["tiny"] = '.3em',
    ["smaller"] = '.5em',
    ["small"] = '.8em',
    ["normal"] = '1.0em',
    ["large"] = '1.2em',
    ["larger"] = '1.5em',
    ["huge"] = '2em'
}
local hdg_docx_label_sizes = { -- heading text sizes
    ["tiny"] = '<w:sz w:val="12" />',
    ["smaller"] = '<w:sz w:val="16" />',
    ["small"] = '<w:sz w:val="20" />',
    ["normal"] = '<w:sz w:val="24" />',
    ["large"] = '<w:sz w:val="28" />',
    ["larger"] = '<w:sz w:val="32" />',
    ["huge"] = '<w:sz w:val="36" />'
}
local text_styles_list = {
    "plain", "normal", "italic", "bold", "oblique", "bold-oblique",
    "bold-italic"
}
local affirm_list = {"true", "yes", "false", "no"}
local docx_hdg_par_style = "" -- Initialize paragraph frame style
local docx_hdg_label_styles = { -- Text style Open Office codes
    ["plain"] = '<w:b w:val="false"/><w:i w:val="false"/>',
    ["normal"] = '<w:b w:val="false"/><w:i w:val="false"/>',
    ["italic"] = '<w:i w:val="true"/>',
    ["bold"] = '<w:b w:val="true"/>',
    ["oblique"] = '<w:i w:val="true"/>',
    ["bold-oblique"] = '<w:b w:val="true"/><w:i w:val="true"/>',
    ["bold-italic"] = '<w:b w:val="true"/><w:i w:val="true"/>'
}
local ltx_hdg_label_styles = { -- Text style latex/PDF codes
    ["plain"] = "{X}",
    ["normal"] = "{X}",
    ["italic"] = '\\textit{X}',
    ["oblique"] = '\\textit{X}',
    ["bold"] = '\\textbf{X}',
    ["bold-oblique"] = '\\textit{\\textbf{X}}',
    ["bold-italic"] = '\\textit{\\textbf{X}}'
}
local ltx_hdg_label_alignment = { -- heading text alignment
    ["left"] = '\\raggedright',
    ["center"] = '\\centering',
    ["right"] = '\\raggedleft'
}

-- local doc_specific_i = 4 -- 'Document-type-specific' column of heading params table
local doctypes = {"html", "epub", "docx", "pdf", "latex", "gfm", "markdown"}
local doctype_overrides = {} -- Will contain any document-type-specific overrides
local doctype = string.match(FORMAT, "[%a]+")

local ptr -- General purpose counter/pointer
local hdg_hits = 0 -- Counter allows detection of first hit to set heading numbering

-- META FUNCTION — Meta stores variables used in headings filter
function Meta(meta)
    print("\n=== SECTIONATOR DEBUG START ===")
    
    -- Try to get format-specific settings first, then fall back to global
    local sectionatorSettings, settingsSource = extractSectionatorSettings(meta)
    
    print("Using sectionator settings from:", settingsSource)
    
    if sectionatorSettings then
        print("sectionator type:", type(sectionatorSettings))
        if type(sectionatorSettings) == "table" then
            print("sectionator.numbering:", sectionatorSettings.numbering, type(sectionatorSettings.numbering))
            print("sectionator.hdg_label:", sectionatorSettings.hdg_label)
            print("sectionator.hdg_sep:", sectionatorSettings.hdg_sep)
            print("sectionator.hdg_label_size:", sectionatorSettings.hdg_label_size)
            print("sectionator.hdg_label_style:", sectionatorSettings.hdg_label_style)
        else
            print("sectionator value:", tostring(sectionatorSettings))
        end
    else
        print("No sectionator found in meta")
    end   
    print("Raw meta.toc:", meta.toc, type(meta.toc))
    print("=== SECTIONATOR DEBUG END ===\n")

    local err = ""
    local i
    local j
    local key
    local value
    local done = false
    local ptr = 1

    -- Specify param value defaults
    hdg_params = {
        ["keep_with_next"] = {"4", nil, nil},
        ["numbering"] = {nil, nil, nil},
        ["number_reset_to"] = {1, nil, nil},
        ["hdg_label"] = {"", nil, nil},
        ["hdg_label_size"] = {"normal", nil, nil},
        ["hdg_label_style"] = {"normal", nil, nil},
        ["hdg_sep"] = {"_--_", nil, nil},
        ["hdg_targ"] = {nil, nil, nil}
    }

    reset_nums_below(1) -- Reset all numbers above section level
    reset_hdg_params() -- Init variables at this level before next headings
    doctype_overrides = {} -- Clear record of doc-type-specific overrides

    -- MODIFIED: Process either format-specific or global settings
    if sectionatorSettings ~= nil then
        -- NEW: Check if sectionator is an object (table) or string
        if type(sectionatorSettings) == "table" then
            -- First, check if it's actually a string split into array elements
            local isStringArray = true
            local concatenatedString = ""

            -- Check if all elements are strings and can be concatenated
            for k, v in pairs(sectionatorSettings) do
                if type(k) == "number" then
                    concatenatedString = concatenatedString .. stringify(v)
                elseif type(k) == "string" then
                    -- This is a proper object format
                    isStringArray = false
                    break
                end
            end

            if isStringArray and #concatenatedString > 0 then
                -- MULTILINE STRING FORMAT: Treat as concatenated string
                print("Processing sectionator as multiline string format")
                local glParStr = concatenatedString
                glParStr = string.gsub(glParStr, "“", '"') -- Clean of any Pandoc open quotes that disables standard expressions
                glParStr = string.gsub(glParStr, "”", '"') -- Clean of any Pandoc open quotes that disable standard expressions
                repeat -- Gather any meta-specified global sectionator parameters
                    i, j = string.find(glParStr, "[%a%.%_]+%s*=", ptr) -- Look for param name
                    if i == nil then
                        done = true
                        break
                    end
                    key = trim(string.sub(glParStr, i, j - 1))
                    ptr = j
                    value = string.match(string.sub(glParStr, j + 1, j + 50),
                                         "[%%%-%+%_%w%.%:%s]+")
                    if value == nil then
                        done = true
                        break
                    end
                    ptr = j + 1
                    err = recordParam(key, value, global_i, doctype_overrides) -- Save information
                    if #err > 0 then -- If error
                        err_msg = err_msg .. err .. "\n"
                    end
                until done
            else
                -- OBJECT FORMAT: Handle as key-value pairs
                print("Processing sectionator as object format")
                for key, value in pairs(sectionatorSettings) do
                    -- FIXED: Only process string keys, ignore numeric indices
                    if type(key) == "string" then
                        local stringValue = stringify(value)
                        err = recordParam(key, stringValue, global_i,
                                          doctype_overrides)
                        if #err > 0 then
                            err_msg = err_msg .. err .. "\n"
                        end
                    else
                        print("Skipping numeric key:", key, "with value:",
                              stringify(value))
                    end
                end
            end
        else
            -- STRING FORMAT: Handle as comma-separated string (legacy format)
            print("Processing sectionator as string format")
            local glParStr = stringify(sectionatorSettings)
            glParStr = string.gsub(glParStr, string.char(226, 128, 156), '"') -- Left curly quote (U+201C)
            glParStr = string.gsub(glParStr, string.char(226, 128, 157), '"') -- Right curly quote (U+201D)
            repeat -- Gather any meta-specified global sectionator parameters
                i, j = string.find(glParStr, "[%a%.%_]+%s*=", ptr) -- Look for param name
                if i == nil then
                    done = true
                    break
                end
                key = trim(string.sub(glParStr, i, j - 1))
                ptr = j
                value = string.match(string.sub(glParStr, j + 1, j + 50),
                                     "[%%%-%+%_%w%.%:%s]+")
                if value == nil then
                    done = true
                    break
                end
                ptr = j + 1
                err = recordParam(key, value, global_i, doctype_overrides) -- Save information
                if #err > 0 then -- If error
                    err_msg = err_msg .. err .. "\n"
                end
            until done
        end
    else
        print("No 'sectionator' settings found in Meta section.")
    end

    doctype_override(global_i, doctype_overrides) -- Override any parameters where doc-specific override indicated
    return meta
end

-- *************************************************************************
-- Extract sectionator settings from format-specific section first, then global
    function extractSectionatorSettings(meta)
        local settings = {}
        local currentFormat = string.match(FORMAT, "[%a]+") -- e.g., html, pdf, docx
        local formatKey = currentFormat .. "_document" -- e.g., html_document, pdf_document
        
        print("Current format:", currentFormat, "Format key:", formatKey)
        
        -- First try to get settings from format-specific section
        if meta.output and meta.output[formatKey] and meta.output[formatKey].sectionator then
            print("Found format-specific sectionator settings for", formatKey)
            settings = meta.output[formatKey].sectionator
            return settings, "format-specific"
        end
        
        -- Fall back to global settings
        if meta.sectionator then
            print("Using global sectionator settings")
            return meta.sectionator, "global"
        end
        
        print("No sectionator settings found")
        return nil, "none"
    end

-- *************************************************************************
-- Reset these variables before next heading
function reset_hdg_params()
    for ptr = 1, #valid_hdg_attr_names, 1 do -- Reset all param vals for current heading
        hdg_params[valid_hdg_attr_names[ptr]][this_i] = nil
    end
end

-- *************************************************************************
-- Reset section numbers above this level
function reset_nums_below(n)
    for ptr = (n + 1), #section_names, 1 do hdg_nums[ptr] = 1 end
end

-- *************************************************************************
-- Intercept headers and add code to ensure will not be orphaned. 
function Header(hdg)
    local results
    local sec_type -- section, subsection, etc.
    local r = ""
    local name = ""
    local val = ""
    local err_msg = "" -- Reset error message
    local label_sep1 = "" -- 1st label separater part will have same style as label
    local label_sep2 = "" -- 2nd label separater part will have same style as heading

    local hdg_label_html_style = "" -- label html style accumulator
    local hdg_label_docx_style = "" -- label docx style accumulator
    local hdg_label_ltx_style = "X" -- label ltx style accumulator

    reset_hdg_params() -- Init params at this level before loading new params
    hdg_hits = hdg_hits + 1 -- Increment heading number
    if hdg.content ~= nil then
        hdg_text = stringify(hdg.content)
    else
        hdg_text = "" -- Empty string
    end
    level = hdg.level -- Level of this heading
    if #hdg.attributes ~= 0 then
        -- Gather attributes and ensure each attribute name is valid
        doctype_overrides = {} -- Clear record of doc-type-specific overrides
        for ptr = 1, #hdg.attributes, 1 do -- Gather parameters from heading
            r = r .. "heading attribute item: " .. hdg.attributes[ptr][1] ..
                    " - " .. hdg.attributes[ptr][2] .. '\n'
            name = hdg.attributes[ptr][1]
            val = hdg.attributes[ptr][2]
            err = recordParam(name, val, this_i, doctype_overrides) -- Record values from heading attributes
            if #err > 0 then err_msg = err_msg .. err end
        end
        if hdg_params["numbering"][global_i] == true then
            hdg_params["numbering"][this_i] = true -- 
            hdg_params["numbering"][global_i] = nil -- Numbering is turned on or off only at headings
        end
        doctype_override(this_i, doctype_overrides) -- Override any param for which doc-type constraint indicated
    end

    -- ptr = 1 -- Init counter
    -- repeat -- Print complete table
    --     v = valid_hdg_attr_names[ptr] -- Get next name from table of valid parameters
    --     ptr = ptr + 1
    -- until ptr > #valid_hdg_attr_names

    -- *************************************************************************
    val = getParam("hdg_label") -- Heading figure label, e.g. 'Section', allowing sequencial numbering of custom label
    if val ~= nil then
        hdg_label = val
        hdg_labels[level] = hdg_label
    end

    val, par_source = getParam("keep_with_next") -- Indicates margin should be restored after heading
    if tonumber(val) > 2 then
        keep_with_next = val
    else
        keep_with_next = hdg_params["keep_with_next"][default_i]
        err_msg = err_msg ..
                      "Parameter 'keep_with_next' must be greater than 2. (Heading '" ..
                      hdg_text .. "')\n"
    end

    val, par_source = getParam("numbering") -- Indicates if number should precede this heading
    numbering = false
    if verify_entry(val, affirm_list) then -- if true/false
        if val == "true" or val == "yes" then
            numbering = true
            if hdg_nums[level] == nil then hdg_nums[level] = 1 end
        else
            numbering = false
            hdg_params["numbering"][global_i] = nil -- Turns off numbering for remaining headings 
        end
    elseif #val > 0 then
        err_msg = err_msg ..
                      "Parameter 'numbering' must be 'true' or 'false'. (Heading '" ..
                      hdg_text .. "')\n"
    end
    if string.find(tostring(hdg.attr), "unnumbered") then -- Allow exception if this heading flagged as not numbered
        numbering = false
    end

    val = hdg_params["number_reset_to"][this_i] -- Reset level number to this value
    if val ~= nil then
        if value(val) > 0 and value(val) <= 5 then -- if number
            number_reset_to = val
            hdg_nums[level] = val
            reset_nums_below(level)
        else
            err_msg = err_msg ..
                          "Value of 'number_reset_to' must be between 1 and 5. (Heading '" ..
                          hdg_text .. "')\n"
        end
    end

    val, par_source = getParam("hdg_sep") -- Label to appear before heading
    if type(val) == "string" and #val < 20 then -- if valid
        hdg_sep = val
    else
        err_msg = err_msg ..
                      "Parameter 'hdg_sep' must be a valid string less than 20 characters. (Heading: '" ..
                      hdg_text .. "')\n"
    end

    val, par_source = getParam("hdg_label_style") -- Label style
    if (val ~= nil and #val > 1) then
        if verify_entry(val, text_styles_list) then
            hdg_label_style = val
            if (hdg_label_style == "bold" or hdg_label_style == "bold-oblique" or
                hdg_label_style == "bold-italic") and FORMAT:match "html" then
                hdg_label_html_style = hdg_label_html_style ..
                                           "font-weight:bold; "
                if hdg_label_style == "bold-oblique" or hdg_label_style ==
                    "bold-italic" then
                    hdg_label_html_style =
                        hdg_label_html_style .. "font-style:italic" .. "; "
                end
            else
                if hdg_label_style == "plain" then
                    hdg_label_style = "normal"
                end
                hdg_label_html_style = hdg_label_html_style .. "font-style:" ..
                                           hdg_label_style .. "; font-weight:" ..
                                           "normal" .. "; "
                hdg_label_docx_style = hdg_label_docx_style ..
                                           docx_hdg_label_styles[hdg_label_style]
                hdg_label_ltx_style = string.gsub(hdg_label_ltx_style, "X",
                                                  ltx_hdg_label_styles[hdg_label_style])
            end
        else
            err_msg = err_msg .. "Bad label style name ('" .. val .. "')" ..
                          par_source
        end
    end

    val, par_source = getParam("hdg_label_size") -- Label text size
    if val ~= nil then
        if verify_entry(val, label_sizes) then
            hdg_label_size = val -- Get label relative font size
            hdg_label_html_style = hdg_label_html_style .. "font-size:" ..
                                       hdg_html_label_sizes[hdg_label_size] ..
                                       "; "
            hdg_label_docx_style = hdg_label_docx_style ..
                                       hdg_docx_label_sizes[hdg_label_size]
            hdg_label_ltx_style = string.gsub(hdg_label_ltx_style, "X",
                                              hdg_ltx_label_sizes[hdg_label_size])
        else
            err_msg = err_msg .. "Bad label size ('" .. val .. "')" ..
                          par_source
        end
    end

    if #err_msg > 0 then print(err_msg) end

    -- **************************************************************************************************
    -- All entered values have been gathered. Now we process values and prep for heading output.

    if (level <= prev_level or prev_level == 0) and numbering then
        hdg_nums[level] = hdg_nums[level] + 1 -- Increment section number
        reset_nums_below(level)
    end
    prev_level = level -- Remember previous level
    hdg_lbl = string.gsub(hdg_label, "_", " ") .. " " -- Substitute real spaces
    hdg_label_sep = string.gsub(hdg_sep, "_", " ") -- Enables space char in separator entered as "\_"
    if numbering and #hdg_lbl > 0 then
        if #hdg_label_sep > 0 then -- If specified separator between label and heading
            i, j = string.find(hdg_label_sep, "^%S?")
            -- x = string.sub(hdg_label_sep, 1, 2)
            if i ~= nil then -- If first char(s) of separator are non-space
                label_sep1 = string.sub(hdg_label_sep, i, j) -- Will have same style as label
                label_sep2 = string.sub(hdg_label_sep, j + 1, 50) -- Anything after space has heading style
                if label_sep2 == nil then label_sep2 = "" end
            else
                label_sep1 = ""
                label_sep2 = hdg_label_sep
            end
        else
            label_sep1 = ""
            label_sep2 = ""
        end
        hdg_nm = ""
        if numbering then -- If numbering
            for ptr = level, 1, -1 do
                hdg_nm = tostring(hdg_nums[ptr]) .. "." .. hdg_nm
            end
            hdg_nm = trimdots(hdg_nm)
            if level == 1 then hdg_nm = hdg_nm .. "." end
        end
    else
        hdg_lbl = ""
        label_sep1 = ""
        label_sep2 = ""
        hdg_nm = ""
    end

    -- *************************************************************************
-- HTML/Epub/markdown documents prep
if (FORMAT:match "html" or FORMAT:match "epub" or FORMAT:match "gfm" or
FORMAT:match "mark.*") then -- For html or markdown documents
label_sep2 = string.gsub(label_sep2, " ", "&nbsp;") -- Enables more than one space char in separator

-- First, build the complete HTML string for the header content
local html_content = '<span style="' .. hdg_label_html_style ..
                           '">' .. hdg_lbl .. hdg_nm .. label_sep1 ..
                           '</span>' .. label_sep2 .. hdg_text

if (#err_msg > 1) then
    -- Prepend the error message to the HTML string
    html_content = "<span style='color:red'>ERROR IN HEADING INFORMATION - " ..
                  err_msg .. "</span><br>" .. html_content
end

-- Now, create the Pandoc object from the final string.
-- The content of a Header must be a list of inlines.
local header_inlines = {pandoc.RawInline('html', html_content)}

results = pandoc.Header(level, header_inlines, hdg.attr)

        -- *************************************************************************
        -- Latex/PDF documents prep
    elseif (numbering and FORMAT:match "latex") then -- For Latex/PDF documents
        if string.find(label_sep2, "%-%-%-") then  -- Look for three consecutive hyphens
            label_sep2 = label_sep2:gsub("---", "\\textemdash{}") -- 3 hyphens to Em-dash
        end
        if string.find(label_sep2, "%-%-") then  -- Look for two consecutive hyphens
            label_sep2 = label_sep2:gsub("--", "\\textendash{}") -- 2 hyphens to En-dash   
        end     
        if hdg.level < 2 then -- Get header level to determine latex level name
            sec_type = "section"
        elseif hdg.level == 2 then
            sec_type = "subsection"
        elseif hdg.level > 2 then -- Latex doesn't number beyond subsubsection level
            sec_type = "subsubsection"
        end
        if #err_msg > 0 then
            emsg = "\\textcolor{red}{[ERROR IN HEADING INFORMATION - " ..
                       err_msg .. "]}\n\n"
        else
            emsg = ""
        end

        hdg_txt = string.gsub(hdg_label_ltx_style, "X",
                              hdg_lbl .. hdg_nm .. label_sep1) .. label_sep2 ..
                      hdg_text -- Include any style attributes
        if hdg.level > 0 then -- Cannot be title
            results = -- emsg .. set_numbering .. "\\needspace{" .. keep_with_next ..
            emsg .. "\\needspace{" .. keep_with_next .. "\\baselineskip}{" ..
                '\\hypertarget{' .. hdg.identifier .. '}{%\n\\' .. sec_type ..
                -- '{' .. stringify(hdg.content) .. '}\\label{' .. hdg.identifier ..
                '{' .. hdg_txt .. '}\\label{' .. hdg.identifier .. '}}' .. "}"
        end
        results = pandoc.RawInline('latex', results)

        -- *************************************************************************
        -- DOCX prep
    elseif (FORMAT:match "docx" or FORMAT:match "odt") then -- For WORD DOCX documents
        if (#err_msg > 1) then
            er_msg =
                "<w:r><w:rPr><w:color w:val='DD0000' /></w:rPr><w:t>[ERROR IN IMAGE INFORMATION - " ..
                    err_msg ..
                    "]<w:br w:type='line' /></w:t><w:rPr><w:color w:val='auto' /></w:rPr></w:r>"
        else
            er_msg = ""
        end
        if numbering then
            nm_sys = '<w:numPr><w:numId w:val="14"/></w:numPr>' -- w:val number is numbering system
        else
            nm_sys = '<w:numPr><w:numId w:val="0"/></w:numPr>'
        end
        -- results_cap = '</w:p><w:bookmarkStart w:id="0" w:name="' ..
        --                   hdg.identifier ..
        --                   '" /><w:bookmarkEnd w:id="0" w:name="multiple-benefits"/><w:p><w:pPr><w:pStyle w:val="Heading' ..
        --                   level .. '"/>' .. nm_sys ..
        --                   '</w:pPr><w:r><w:t xml:space="preserve">' .. hdg_text ..
        --                   '</w:t></w:r>'
        results_cap = '<w:bookmarkStart w:id="0" w:name="' .. hdg.identifier ..
                          '" /><w:bookmarkEnd w:id="0" w:name="multiple-benefits"/><w:pPr><w:pStyle w:val="Heading' ..
                          level .. '"/>' .. nm_sys ..
                          '</w:pPr><w:r><w:t xml:space="preserve">' .. hdg_text ..
                          '</w:t></w:r>'
        results = {pandoc.RawInline('openxml', results_cap)}
    end
    return results
end

-- **************************************************************************************************
-- Examine param name for any format prefix. If not specified, simply record into table.
-- If fomrat prefix indicated, record in special table used later to override.
function recordParam(name, value, lev, overrides)
    local nam = ""
    local i
    local j
    local doctyp = ""
    local doc_specific = false
    local err = ""
    local alt_doctype = doctype -- Accommodates ability to recognize that pdf docs are processed via latex
    if doctype == "latex" then alt_doctype = "pdf" end
    i, j = string.find(name, "%.[_%a]+$") -- Get param without doc constraint (CHANGED : to %.)
    if i ~= nil then -- If constraint indicated
        nam = string.sub(name, i + 1, j) -- Get name without constraint
        i, j = string.find(name, "[_%a]+%.") -- Get doc type constraint (CHANGED : to %.)
        if i ~= nil then -- If doc type prefix indicated
            doctyp = string.sub(name, i, j - 1)
            if verify_entry(doctyp, doctypes) then -- Ensure doctype prefix valid
                doc_specific = true
            else
                err = err .. "Invalid file type prefix ('" .. doctyp .. "') " ..
                          id_source(lev) .. ". \n" -- Invalid
                doctyp = ""
                doc_specific = false
            end
        end
        if (doc_specific == true and
            (doctyp == real_doctype or doctyp == alt_doctype)) then
            table.insert(overrides, {nam, value})
        end
    else -- No doc type constraint
        nam = name
        doc_specific = false
    end
    if verify_entry(nam, valid_hdg_attr_names) == false then
        err = err .. "Bad attribute name ('" .. name .. "') " .. id_source(lev)
        if #err > 0 then print("Found error: " .. err) end
    end
    if doc_specific == false then
        if #err == 0 then -- Only for valid entries
            hdg_params[nam][lev] = value -- Doc type not specified. Save into table
        end
    end
    return err
end

-- Substitute characters so latex doesn't have a cow
function clean_txt_for_ltx(txt)
    txt = string.gsub(txt, "\\", "\\textbackslash ")
    txt = string.gsub(txt, "_", "\\_")
    txt = string.gsub(txt, "%%", "\\%%%%")
    txt = string.gsub(txt, "{", "\\{")
    txt = string.gsub(txt, "}", "\\}")
    txt = string.gsub(txt, "#", "\\#")
    return txt
end

-- Check entry against simple table of allowed values and return true if valid
function verify_entry(e, tbl)
    local result = false
    local i
    local j
    if e ~= nil then
        for i = 1, #tbl, 1 do
            if tbl[i] == e then
                result = true
                break
            end
        end
    end
    return result
end

-- Override any parameter for which a document-specific parameter is specified
function doctype_override(lev, overrides)
    local ptr = 1
    local done = false
    local nam
    local x
    repeat
        if overrides[ptr] ~= nil then
            nam = overrides[ptr][1]
            hdg_params[nam][lev] = overrides[ptr][2] -- Override non-doc-specific value
        end
        ptr = ptr + 1
    until ptr > #overrides
end

-- Gather key/value pairs from meta geometry
function getGeometries(params)
    local key
    local value
    local gVars = {} -- init
    local i
    local j
    local ptr = 1 -- Init counter
    repeat
        i, j, key, value = string.find(params, "(%a+)%s*=%s*([%w.]+)", ptr)
        if i == nil then return gVars end
        gVars[key] = value
        ptr = j + 1
    until (key == nil)
    -- return
end

-- Character escaping
function escape(s, in_attribute)
    return s:gsub('[<>&"\']', function(x)
        if x == '<' then
            return '&lt;'
        elseif x == '>' then
            return '&gt;'
        elseif x == '&' then
            return '&amp;'
        elseif in_attribute and x == '"' then
            return '&quot;'
        elseif in_attribute and x == "'" then
            return '&#39;'
        else
            return x
        end
    end)
end

-- Convert an attributes table into string for HTML tags
function attributes(attr)
    local attr_table = {}
    for x, y in pairs(attr) do
        if y and y ~= '' then
            table.insert(attr_table, ' ' .. x .. '="' .. escape(y, true) .. '"')
        end
    end
    return table.concat(attr_table)
end

-- Get value for specified parameter
function getParam(p)
    local result
    local lev
    local source -- Identify source in case of error with this param
    if hdg_params[p][this_i] ~= nil then
        lev = this_i -- Remember level
        result = hdg_params[p][lev]
    elseif hdg_params[p][global_i] ~= nil then
        lev = global_i
        result = hdg_params[p][lev]
    elseif hdg_params[p][default_i] ~= nil then
        lev = default_i
        result = hdg_params[p][lev]
    else
        -- result = nil
        result = ""
    end
    return result, id_source(lev)
end

function id_source(lev) -- Return string that identifies source of parameter issue
    if lev == global_i then
        source = " in markdown file Meta 'sectionator' statement. \n"
    elseif lev == this_i then
        source = " specified in markdown file for heading '" .. hdg_text ..
                     "'. \n"
    else
        source = " as default value"
    end
    return source
end

-- Return html padding style. Defaults will be used unless overriding spec supplied for a position (top, right, bottom, left)
function htmlPad(pad_tbl, p_top, p_right, p_bottom, p_left)
    local p_string = "padding: "
    local p = {p_top, p_right, p_bottom, p_left}
    local i
    local j
    for i = 1, 4, 1 do
        if (p[i] ~= nil and p[i] ~= '') then pad_tbl[i] = p[i] end
    end
    for i = 1, 4, 1 do p_string = p_string .. pad_tbl[i] .. "px " end
    return (p_string)
end

function trim(s) return s:match "^%s*(.-)%s*$" end

function trimdots(s) return s:match "^%.*(.-)%s*%.$" end
-- function trimdots(s) return s end

-- **************************************************************************************************
-- Conversion functions

function inchesToTwips(inches) return (inches * twips_per_in) end

function inchesToEMUs(inches) return (inches * emu_per_in) end

function inchesToPixels(inches) return (inches * pixels_per_in) end

function dimToInchesInteger(val) -- Convert any dimension value into inches integer
    return math.floor(dimToInches(val))
end

function dimToInches(val) -- Convert any dimension value into inches
    local i
    local j
    local val_dim
    local err = ""
    i, j = string.find(val, "[%d%.]+") -- Get number
    if i ~= nil then -- If number specified
        val_num = string.sub(val, i, j)
        if string.find(val, "%%") then -- If expressed in percentage
            val_in = tonumber(val_num) / 100 * pg_text_width
            val_dim = "%"
        else
            i, j = string.find(val, "[%a]+") -- Get dimension
            if i ~= nil then
                val_dim = string.sub(val, i, j)
                if verify_entry(val_dim, dims) then
                    if string.find(val_dim, "in") then -- If expressed in inches
                        val_in = tonumber(val_num) -- Get value in inches
                    elseif string.find(val_dim, "px") then -- If expressed in pixels
                        val_in = tonumber(val_num) / pixels_per_in -- Get value in inches
                    elseif string.find(val_dim, "cm") then -- If expressed in centimeters
                        val_in = tonumber(val_num) / cm_per_in -- Get value in inches
                    elseif string.find(val_dim, "mm") then -- If expressed in milimeters
                        val_in = tonumber(val_num) / mm_per_in -- Get value in inches
                    end
                else
                    err = "Bad dimension ('" .. val .. "') specified "
                end
            else
                err = "No dimension ('" .. val .. "') indicated "
                val_in = 0
            end
        end
    else
        val_in = 0
        err = "No value ('" .. val .. "') specified "
    end
    return val_in, err
end

-- Get docx vertical padding, to which supplied value is added
function get_docx_padding_v(val)
    if val ~ nil then val = 0 end
    return (docx_padding_v + val) * twips_per_in
end

-- *************************************************************************
-- Define filter with sequence
return {
    traverse = 'topdown',
    {Meta = Meta}, -- Must be first
    {Code = Code},
    {CodeBlock = CodeBlock},
    {Header = Header},
    {heading = heading}
}
