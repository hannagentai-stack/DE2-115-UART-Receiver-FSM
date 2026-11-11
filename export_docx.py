import os
import re
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = parse_xml(
        f'<w:tcMar {nsdecls("w")}>'
        f'<w:top w:w="{top}" w:type="dxa"/>'
        f'<w:bottom w:w="{bottom}" w:type="dxa"/>'
        f'<w:left w:w="{left}" w:type="dxa"/>'
        f'<w:right w:w="{right}" w:type="dxa"/>'
        f'</w:tcMar>'
    )
    tcPr.append(tcMar)

def set_table_borders(table, color="D3D3D3", sz="4"):
    tblPr = table._tbl.tblPr
    borders = parse_xml(
        f'<w:tblBorders {nsdecls("w")}>'
        f'<w:top w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:bottom w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:insideH w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:insideV w:val="none"/>'
        f'<w:left w:val="none"/>'
        f'<w:right w:val="none"/>'
        f'</w:tblBorders>'
    )
    tblPr.append(borders)

def set_callout_border(cell, color="1F497D"):
    tcPr = cell._tc.get_or_add_tcPr()
    borders = parse_xml(
        f'<w:tcBorders {nsdecls("w")}>'
        f'<w:left w:val="single" w:sz="24" w:space="0" w:color="{color}"/>'
        f'<w:top w:val="none"/>'
        f'<w:right w:val="none"/>'
        f'<w:bottom w:val="none"/>'
        f'</w:tcBorders>'
    )
    tcPr.append(borders)

def format_inline_text(paragraph, text, default_font="Times New Roman", default_size=12, default_color=None, bold_prefix=False):
    # Regex to handle markdown formatting: `code`, **bold**, *italic*, math $...$
    pattern = re.compile(r'(\*\*.*?\*\*|\*.*?\*|`.*?`|\$\$.*?\$\$|\$.*?\$|\[.*?\]\(.*?\))')
    tokens = pattern.split(text)

    for i, token in enumerate(tokens):
        if not token:
            continue
        
        run = paragraph.add_run()
        run.font.name = default_font
        run.font.size = Pt(default_size)
        if default_color:
            run.font.color.rgb = default_color

        if token.startswith('**') and token.endswith('**'):
            run.text = token[2:-2]
            run.bold = True
        elif token.startswith('*') and token.endswith('*') and len(token) > 2:
            run.text = token[1:-1]
            run.italic = True
        elif token.startswith('`') and token.endswith('`'):
            run.text = token[1:-1]
            run.font.name = 'Consolas'
            run.font.size = Pt(default_size - 1)
            run.font.color.rgb = RGBColor(199, 37, 78) # Markdown code pink/red
        elif (token.startswith('$$') and token.endswith('$$')) or (token.startswith('$') and token.endswith('$')):
            math_text = token.strip('$')
            # Clean up latex commands for readable text
            math_text = math_text.replace('\\times', '×').replace('\\approx', '≈')
            math_text = math_text.replace('\\mu', 'μ').replace('\\pm', '±')
            math_text = math_text.replace('\\le', '≤').replace('\\ge', '≥')
            math_text = math_text.replace('\\mathbf{', '').replace('\\text{', '')
            math_text = math_text.replace('\\left(', '(').replace('\\right)', ')')
            math_text = math_text.replace('\\frac', '').replace('{', '').replace('}', '')
            math_text = math_text.replace('\\land', 'AND').replace('\\lor', 'OR')
            math_text = math_text.replace('_', ' ')
            run.text = f" {math_text} "
            run.italic = True
            run.font.name = 'Cambria Math'
        elif token.startswith('[') and '](' in token and token.endswith(')'):
            match = re.match(r'\[(.*?)\]\((.*?)\)', token)
            if match:
                link_text, url = match.groups()
                run.text = link_text
                run.font.color.rgb = RGBColor(46, 117, 182)
                run.underline = True
            else:
                run.text = token
        else:
            run.text = token

def build_docx(md_path, docx_path):
    doc = Document()

    # Set page margins (Normal: 1 inch = 72 pt = 2.54 cm)
    for section in doc.sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)

    # Set normal style
    normal_style = doc.styles['Normal']
    normal_style.font.name = 'Times New Roman'
    normal_style.font.size = Pt(12)
    normal_style.font.color.rgb = RGBColor(38, 38, 38)
    normal_style.paragraph_format.line_spacing = 1.25
    normal_style.paragraph_format.space_after = Pt(4)

    with open(md_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    in_code_block = False
    code_lang = ""
    code_lines = []

    in_table = False
    table_rows = []

    in_callout = False
    callout_lines = []
    callout_type = "NOTE"

    i = 0
    num_lines = len(lines)

    while i < num_lines:
        line = lines[i].rstrip('\r\n')

        # Check code block delimiters
        if line.startswith('```'):
            if in_code_block:
                # End of code block
                in_code_block = False
                code_text = "\n".join(code_lines)
                
                # Create a 1x1 table for code block with light gray background
                tbl = doc.add_table(rows=1, cols=1)
                tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
                cell = tbl.cell(0, 0)
                set_cell_background(cell, "F4F6F9")
                set_cell_margins(cell, top=120, bottom=120, left=180, right=180)
                
                tcPr = cell._tc.get_or_add_tcPr()
                borders = parse_xml(
                    f'<w:tcBorders {nsdecls("w")}>'
                    f'<w:left w:val="single" w:sz="6" w:space="0" w:color="D0D7DE"/>'
                    f'<w:top w:val="single" w:sz="6" w:space="0" w:color="D0D7DE"/>'
                    f'<w:right w:val="single" w:sz="6" w:space="0" w:color="D0D7DE"/>'
                    f'<w:bottom w:val="single" w:sz="6" w:space="0" w:color="D0D7DE"/>'
                    f'</w:tcBorders>'
                )
                tcPr.append(borders)

                p = cell.paragraphs[0]
                p.paragraph_format.line_spacing = 1.15
                p.paragraph_format.space_after = Pt(0)
                p.paragraph_format.space_before = Pt(0)
                run = p.add_run(code_text)
                run.font.name = 'Consolas'
                run.font.size = Pt(9.5)
                run.font.color.rgb = RGBColor(36, 41, 47)

                p_after = doc.add_paragraph()
                p_after.paragraph_format.space_before = Pt(4)
                p_after.paragraph_format.space_after = Pt(4)

                code_lines = []
            else:
                in_code_block = True
                code_lang = line[3:].strip()
                code_lines = []
            i += 1
            continue

        if in_code_block:
            code_lines.append(line)
            i += 1
            continue

        # Check callout block
        if line.startswith('> [!NOTE]') or line.startswith('> [!TIP]') or line.startswith('> [!IMPORTANT]') or line.startswith('> [!WARNING]'):
            in_callout = True
            if "TIP" in line:
                callout_type = "TIP"
            elif "IMPORTANT" in line or "WARNING" in line:
                callout_type = "IMPORTANT"
            else:
                callout_type = "NOTE"
            callout_lines = []
            i += 1
            continue

        if in_callout:
            if line.startswith('>') or (line.strip() and not line.startswith('#')):
                clean_line = line.lstrip('>').strip()
                callout_lines.append(clean_line)
                i += 1
                continue
            else:
                # End callout
                in_callout = False
                tbl = doc.add_table(rows=1, cols=1)
                tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
                cell = tbl.cell(0, 0)
                bg_color = "F0F4F8" if callout_type == "NOTE" else ("EAF5EA" if callout_type == "TIP" else "FFF8E7")
                border_color = "1F497D" if callout_type == "NOTE" else ("2E7D32" if callout_type == "TIP" else "D97706")
                set_cell_background(cell, bg_color)
                set_callout_border(cell, border_color)
                set_cell_margins(cell, top=140, bottom=140, left=200, right=200)

                p = cell.paragraphs[0]
                p.paragraph_format.line_spacing = 1.25
                p.paragraph_format.space_after = Pt(2)
                p.paragraph_format.space_before = Pt(2)
                
                header_title = "LƯU Ý KỸ THUẬT" if callout_type == "NOTE" else ("GỢI Ý & ĐÁNH GIÁ" if callout_type == "TIP" else "ĐẶC BIỆT QUAN TRỌNG")
                header_color = RGBColor(31, 73, 125) if callout_type == "NOTE" else (RGBColor(46, 125, 50) if callout_type == "TIP" else RGBColor(180, 83, 9))
                header_run = p.add_run(f"📌 {header_title}: ")
                header_run.bold = True
                header_run.font.name = 'Times New Roman'
                header_run.font.size = Pt(11.5)
                header_run.font.color.rgb = header_color
                
                content_text = " ".join(callout_lines)
                format_inline_text(p, content_text, default_size=11.5)

                p_after = doc.add_paragraph()
                p_after.paragraph_format.space_after = Pt(4)
                callout_lines = []
                # do not continue, let the current line be processed

        # Check markdown table
        if line.startswith('|') and line.endswith('|'):
            # Collect all table lines
            table_raw_rows = []
            while i < num_lines and lines[i].strip().startswith('|') and lines[i].strip().endswith('|'):
                table_raw_rows.append(lines[i].strip())
                i += 1
            
            # Parse table
            parsed_rows = []
            for tr in table_raw_rows:
                # Ignore separator line like | :--- | :--- |
                cells = [c.strip() for c in tr.split('|')[1:-1]]
                if all(re.match(r'^:?-+:?$', c) for c in cells if c):
                    continue
                parsed_rows.append(cells)

            if parsed_rows:
                num_cols = max(len(r) for r in parsed_rows)
                tbl = doc.add_table(rows=len(parsed_rows), cols=num_cols)
                tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
                set_table_borders(tbl, "C0C0C0")

                for r_idx, row_data in enumerate(parsed_rows):
                    for c_idx in range(num_cols):
                        cell = tbl.cell(r_idx, c_idx)
                        text_val = row_data[c_idx] if c_idx < len(row_data) else ""
                        set_cell_margins(cell, top=100, bottom=100, left=140, right=140)

                        if r_idx == 0:
                            # Header row
                            set_cell_background(cell, "1F497D")
                            p = cell.paragraphs[0]
                            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                            p.paragraph_format.space_before = Pt(2)
                            p.paragraph_format.space_after = Pt(2)
                            run = p.add_run(text_val.replace('**', ''))
                            run.bold = True
                            run.font.name = 'Times New Roman'
                            run.font.size = Pt(11)
                            run.font.color.rgb = RGBColor(255, 255, 255)
                        else:
                            # Body rows
                            if r_idx % 2 == 1:
                                set_cell_background(cell, "FFFFFF")
                            else:
                                set_cell_background(cell, "F9FAFC")
                            
                            p = cell.paragraphs[0]
                            p.paragraph_format.space_before = Pt(2)
                            p.paragraph_format.space_after = Pt(2)
                            p.paragraph_format.line_spacing = 1.15
                            
                            # Align numbers or short codes center
                            if re.match(r'^(\d+|\+?-?\d+\.?\d*%?|0x[0-9A-Fa-f]+|PIN_\w+|2\.5 V|3\.3-V.*)$', text_val.strip()):
                                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                            
                            format_inline_text(p, text_val, default_size=11)

                p_after = doc.add_paragraph()
                p_after.paragraph_format.space_after = Pt(4)
            continue

        # Check Headings
        if line.startswith('# '):
            p = doc.add_paragraph()
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.space_before = Pt(16)
            p.paragraph_format.space_after = Pt(8)
            run = p.add_run(line[2:].strip())
            run.font.name = 'Times New Roman'
            run.font.size = Pt(18)
            run.bold = True
            run.font.color.rgb = RGBColor(31, 73, 125) # Navy
        elif line.startswith('## '):
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(14)
            p.paragraph_format.space_after = Pt(6)
            run = p.add_run(line[3:].strip())
            run.font.name = 'Times New Roman'
            run.font.size = Pt(14)
            run.bold = True
            run.font.color.rgb = RGBColor(31, 73, 125)
        elif line.startswith('### '):
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(10)
            p.paragraph_format.space_after = Pt(4)
            run = p.add_run(line[4:].strip())
            run.font.name = 'Times New Roman'
            run.font.size = Pt(13)
            run.bold = True
            run.font.color.rgb = RGBColor(46, 117, 182) # Blue
        elif line.startswith('#### '):
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(6)
            p.paragraph_format.space_after = Pt(2)
            run = p.add_run(line[5:].strip())
            run.font.name = 'Times New Roman'
            run.font.size = Pt(12)
            run.bold = True
            run.italic = True
            run.font.color.rgb = RGBColor(89, 89, 89)
        elif line.strip() in ['---pagebreak---', '<div class="pagebreak"></div>', '\\pagebreak', '---page-break---']:
            doc.add_page_break()
        elif line.startswith('---'):
            # Divider line: add a page break if explicit, otherwise small spacing
            pass
        elif line.lstrip().startswith('* ') or line.lstrip().startswith('- '):
            raw_stripped = line.lstrip()
            indent_spaces = len(line) - len(raw_stripped)
            level = min(indent_spaces // 2, 3)
            p = doc.add_paragraph(style='List Bullet')
            p.paragraph_format.left_indent = Inches(0.25 * (level + 1))
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.line_spacing = 1.2
            format_inline_text(p, raw_stripped[2:].strip(), default_size=12)
        elif re.match(r'^\s*\d+\.\s', line):
            # Numbered list
            raw_stripped = line.lstrip()
            indent_spaces = len(line) - len(raw_stripped)
            level = min(indent_spaces // 2, 3)
            prefix_match = re.match(r'^(\d+\.\s)(.*)', raw_stripped)
            p = doc.add_paragraph()
            p.paragraph_format.left_indent = Inches(0.25 * (level + 1))
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.line_spacing = 1.2
            num_run = p.add_run(prefix_match.group(1))
            num_run.bold = True
            num_run.font.name = 'Times New Roman'
            num_run.font.size = Pt(12)
            format_inline_text(p, prefix_match.group(2).strip(), default_size=12)
        elif line.strip():
            # Normal paragraph
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(2)
            p.paragraph_format.space_after = Pt(4)
            p.paragraph_format.line_spacing = 1.25
            format_inline_text(p, line.strip(), default_size=12)

        i += 1

    # Add header and footer
    header_title = "TÀI LIỆU HƯỚNG DẪN KỸ THUẬT"
    for l in lines:
        if l.startswith('# '):
            header_title = l[2:].strip()
            break

    for s_idx, section in enumerate(doc.sections):
        header = section.header
        hp = header.paragraphs[0]
        hp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        hrun = hp.add_run(header_title[:65])
        hrun.font.name = 'Times New Roman'
        hrun.font.size = Pt(9)
        hrun.font.color.rgb = RGBColor(128, 128, 128)

        footer = section.footer
        fp = footer.paragraphs[0]
        fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        frun = fp.add_run("Tài liệu kỹ thuật - Trang ")
        frun.font.name = 'Times New Roman'
        frun.font.size = Pt(9.5)
        frun.font.color.rgb = RGBColor(128, 128, 128)

        # XML page number field
        fldSimple = parse_xml(r'<w:fldSimple %s w:instr="PAGE"/>' % nsdecls('w'))
        fp._p.append(fldSimple)

    doc.save(docx_path)
    print(f"[OK] Successfully exported DOCX to: {docx_path}")

if __name__ == '__main__':
    import sys
    if len(sys.argv) >= 3:
        md_file = sys.argv[1]
        docx_file = sys.argv[2]
    else:
        md_file = r"c:\Users\handa\OneDrive\Documents\Projects\UART\BAO_CAO_DO_AN_UART_RECEIVER.md"
        docx_file = r"c:\Users\handa\OneDrive\Documents\Projects\UART\BAO_CAO_DO_AN_UART_RECEIVER.docx"
    build_docx(md_file, docx_file)
