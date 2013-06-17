" vim:tabstop=2:shiftwidth=2:expandtab:foldmethod=marker:textwidth=79
" Vimwiki autoload plugin file
" Desc: Tables
" | Easily | manageable | text  | tables | !       |
" |--------|------------|-------|--------|---------|
" | Have   | fun!       | Drink | tea    | Period. |
"
" Author: Maxim Kim <habamax@gmail.com>
" Home: http://code.google.com/p/vimwiki/

" Load only once {{{
if exists("g:loaded_vimwiki_tbl_auto") || &cp
  finish
endif
let g:loaded_vimwiki_tbl_auto = 1
"}}}

let s:textwidth = &tw

" Misc functions {{{
function! s:rxSep() "{{{
  return '[│|]'
endfunction "}}}

function! s:rxSepline()
  return '[├│|][-─|│┼]\{2,}[┤|│]'
endfunction

function! s:get_sep()
  if g:vimwiki_tables_box_chars
    return "│"
  else
    return "|"
  endif
endfunction

function! s:get_line_char()
  if g:vimwiki_tables_box_chars
    return "─"
  else
    return "-"
  endif
endfunction

function! s:create_empty_row(cols) "{{{
  let row = s:get_sep()
  let cell = "   ".s:get_sep()

  for c in range(a:cols)
    let row .= cell
  endfor

  return row
endfunction "}}}

function! s:create_new_sep(cols) "{{{
  if g:vimwiki_tables_box_chars
    let begin_sep = '├'
    let middle_sep = '┼'
    let end_sep = '┤'
  else
    let begin_sep = '|'
    let middle_sep = '|'
    let end_sep = '|'
  endif

  let row = begin_sep
  let cell = repeat(s:get_line_char(), 3) . middle_sep

  for c in range(a:cols - 1)
    let row .= cell
  endfor
  let row .= repeat(s:get_line_char(), 3) . end_sep

  return row
endfunction "}}}

function! vimwiki#tbl#get_cells(line) "{{{
  let cell_infos = s:get_cell_infos(a:line, getline(a:line))
  let result = []
  for cell_info in cell_infos
    call add(result, cell_info[0])
  endfor
  return result
endfunction "}}}

function! s:col_count(lnum) "{{{
  let line_content = getline(a:lnum)
  if !s:is_separator(line_content)
    return len(s:get_cell_infos(a:lnum, getline(a:lnum)))
  else
    return strchars(substitute(line_content, '[^|│├┼┤]', '', 'g'))-1
  endif
endfunction "}}}

"Returns: the indent of the table's first line
function! s:get_indent(lnum) "{{{
  if !s:is_table(getline(a:lnum))
    return
  endif

  let indent = 0

  let lnum = a:lnum - 1
  while lnum > 1
    let line = getline(lnum)
    if !s:is_table(line)
      let indent = indent(lnum+1)
      break
    endif
    let lnum -= 1
  endwhile

  return indent
endfunction " }}}

function! s:get_rows(lnum) "{{{
  if !s:is_table(getline(a:lnum))
    return
  endif

  let upper_rows = []
  let lower_rows = []

  let lnum = a:lnum - 1
  while lnum >= 1
    let line = getline(lnum)
    if s:is_table(line)
      call add(upper_rows, [lnum, line])
    else
      break
    endif
    let lnum -= 1
  endwhile
  call reverse(upper_rows)

  let lnum = a:lnum
  while lnum <= line('$')
    let line = getline(lnum)
    if s:is_table(line)
      call add(lower_rows, [lnum, line])
    else
      break
    endif
    let lnum += 1
  endwhile

  return upper_rows + lower_rows
endfunction "}}}


"wenn conceal aus ist natürlich was einfacheres
"XXX was überlegen für Tabs in Zellen
"XXX vielleicht geht das doch mit getline()[i]
"Returns: something like [['bla', 3], ['blubb', 5]]
function! s:get_cell_infos(lnum, line_content) "{{{
  let result = []
  let cell = ''
  let width = 0

  let normalsyntax = synconcealed(a:lnum, indent(a:lnum)+1)[2]
  let line_width = col([a:lnum, '$'])

  let idx = match(a:line_content, s:rxSep()) + 2
  let ch = matchstr(a:line_content, '\%'.idx.'c.')
  while (ch == ' ' || ch == '') && idx < line_width
    let idx += 1
    let ch = matchstr(a:line_content, '\%'.idx.'c.')
  endwhile
  while idx < line_width
    let ch = matchstr(a:line_content, '\%'.idx.'c.')
    if ch == '' | let idx += 1 | continue | endif
    let syn = synconcealed(a:lnum, idx)

    if syn[2] == normalsyntax || syn[2] == 0
      if ch == '|' || ch == '│'
        call add(result, [cell, width])
        let cell = ''
        let width = 0
        let idx += 1
        let ch = matchstr(a:line_content, '\%'.idx.'c.')
        while (ch == ' ' || ch == '') && idx < line_width
          let idx += 1
          let ch = matchstr(a:line_content, '\%'.idx.'c.')
        endwhile
        continue
      elseif ch == ' '
        let ws_number = 0
        while ch == ' ' && idx < line_width
          let ws_number += 1
          let idx += 1
          let ch = matchstr(a:line_content, '\%'.idx.'c.')
        endwhile
        if ch != '|' && ch != '│'
          let cell .= repeat(' ', ws_number)
          let width += ws_number
        endif
        continue
      else
        let cell .= ch
        let width += strwidth(ch)
      endif
    else
      let cell .= ch
      "XXX: in case of g:vimwiki_table_conceal == 0, the whole computation
      "could be simplified
			if syn[0] == 0 || syn[1] != '' || !g:vimwiki_table_conceal
        let width += strwidth(ch)
			endif
    endif
    let idx += 1
  endwhile

  return result
endfunction "}}}

function! s:is_table(line) "{{{
  return (a:line !~ s:rxSep().s:rxSep() && a:line =~ '^\s*'.s:rxSep().'.\+'.s:rxSep().'\s*$') || s:is_separator(a:line)
endfunction "}}}

function! s:is_separator(line) "{{{
  return a:line =~ '^\s*'.s:rxSepline().'\s*$'
endfunction "}}}

"mv_curs is 1 iff this function is called from insert mode
"because of Vim's stupid cursor movement on <Esc>
fu! vimwiki#tbl#format(lnum, mv_curs, ...)
  if !(&filetype == 'vimwiki')
    return
  endif
  let line = getline(a:lnum)
  if !s:is_table(line)
    return
  endif

  "lines is of the form
  "[ [3, [['bla', 3], ['blubb', 5]]], [4, [['a', 1], ['b', 1]]] ]
  let lines = []
  let separators = []
  for [lnum, row] in s:get_rows(a:lnum)
    if s:is_separator(row)
      call add(separators, lnum)
    else
      call add(lines, [lnum, s:get_cell_infos(lnum, row)])
    endif
  endfor

  "if called by move_column_left, swap columns
  if a:0 == 2
    let col1 = a:1
    let col2 = a:2
    for [lnum, cells] in lines
      let tmpcell = cells[col1]
      let cells[col1] = cells[col2]
      let cells[col2] = tmpcell
    endfor
  endif

  "for every column, get the max width
  let max_lens = []
  for [lnum, cells] in lines
    for idx in range(len(cells))
      let width = cells[idx][1]
      if idx < len(max_lens)
        let max_lens[idx] = max([width, max_lens[idx]])
      else
        call add(max_lens, width)
      endif
    endfor
  endfor


  "echom string(lines)
  "echom string(separators)
  "echom string(max_lens)
  "return

  let indent = s:get_indent(a:lnum)
  if &expandtab
    let indentstring = repeat(' ', indent)
  else
    let indentstring = repeat('	', indent / &tabstop) . repeat(' ', indent % &tabstop)
  endif

  if a:mv_curs
    normal! l
  endif
  let current_tbl_column = s:cur_column()

  "create the new table line
  for [lnum, cells] in lines
    let new_row = s:fmt_row(cells, max_lens)
    call setline(lnum, indentstring.new_row)
  endfor
  if !empty(separators)
    let sep_line = s:fmt_sep(max_lens)
    for lnum in separators
      call setline(lnum, indentstring.sep_line)
    endfor
  endif

  call s:goto_tbl_col(a:lnum, current_tbl_column)

  let &tw = s:textwidth
endfu

fu! vimwiki#tbl#bla()
  echom s:cur_column()
  echom s:col_count(line('.'))
endfu

function! s:cur_column() "{{{
  let lnum = line('.')
  let line = getline(lnum)
  if !s:is_table(line)
    return -1
  endif

  let curs_pos = col('.')
  let mpos = match(line, '[│|├]') + 1
  let normalsyntax = synID(lnum, mpos, 0)
  let col = -1

  while mpos < curs_pos
    let ch = matchstr(line, '\%'.mpos.'c.')
    if (ch =~ '[|│├┼┤]') && synID(lnum, mpos, 0) == normalsyntax
      let col += 1
    endif
    let mpos += 1
  endwhile
  return col
endfunction

" }}}

" Format functions {{{
function! s:fmt_row(cells, max_lens)
  let sep = s:get_sep()
  let new_line = sep
  for idx in range(len(a:cells))
    let cell = ' '.a:cells[idx][0].' '
    let width = a:cells[idx][1]

    let diff = a:max_lens[idx] - width
    let cell .= repeat(' ', diff)

    let new_line .= cell.sep
  endfor

  let idx = len(a:cells)
  while idx < len(a:max_lens)
    let new_line .= repeat(' ', a:max_lens[idx]+2).sep
    let idx += 1
  endwhile
  return new_line
endfunction

function! s:fmt_sep(max_lens) "{{{
  if g:vimwiki_tables_box_chars
    return '├' . join(map(a:max_lens, "repeat('─', v:val + 2)"), '┼') . '┤'
  else
    return '|' . join(map(a:max_lens, "repeat('-', v:val + 2)"), '|') . '|'
  endif
endfunction "}}}

function! s:goto_tbl_col(lnum, tbl_col)
  let line_content = getline(a:lnum)
  let mpos = match(line_content, '[│|├]') + 1
  let normalsyntax = synID(a:lnum, mpos, 0)
  let cur_tbl_col = -1
  let curs_offset = 0
  let max = col([a:lnum, '$']) - 1

  while mpos <= max
    let ch = matchstr(line_content, '\%'.mpos.'c.')
    if (ch =~ '[|│├┼┤]') && synID(a:lnum, mpos, 0) == normalsyntax
      "extra offset for 3 byte-characters
      let curs_offset = ch =~ '|' ? 0 : 2
      let cur_tbl_col += 1
      if cur_tbl_col == a:tbl_col
        call cursor(a:lnum, mpos+curs_offset+2)
        return
      endif
    endif
    let mpos += 1
  endwhile

endfunction

"}}}

" Keyboard functions "{{{

function! vimwiki#tbl#goto_next_col() "{{{
  let lnum = line('.')
  let cur_tbl_col = s:cur_column()
  let col_count = s:col_count(lnum)

  if cur_tbl_col < col_count - 1
    call s:goto_tbl_col(lnum, cur_tbl_col+1)
  else
    let lnum += 1
    while s:is_separator(getline(lnum))
      let lnum += 1
    endwhile
    if s:is_table(getline(lnum))
      call s:goto_tbl_col(lnum, 0)
    else
      call append(lnum-1, s:create_empty_row(col_count))
      if g:vimwiki_table_auto_fmt
        call vimwiki#tbl#format(lnum, 0)
      endif
      call s:goto_tbl_col(lnum, 0)
    endif
  endif
endfunction "}}}

function! vimwiki#tbl#goto_prev_col() "{{{
  let lnum = line('.')
  let cur_tbl_col = s:cur_column()
  if cur_tbl_col > 0
    call s:goto_tbl_col(lnum, cur_tbl_col-1)
  else
    let lnum -= 1
    while s:is_separator(getline(lnum))
      let lnum -= 1
    endwhile
    if s:is_table(getline(lnum))
      call s:goto_tbl_col(lnum, s:col_count(lnum)-1)
    endif
  endif
endfunction "}}}

"}}}

" Global functions {{{
function! vimwiki#tbl#kbd_cr() "{{{
  let lnum = line('.')
  let cur_tbl_col = s:cur_column()

  let lnum += 1
  while s:is_separator(getline(lnum))
    let lnum += 1
  endwhile
  if !s:is_table(getline(lnum))
    call append(lnum-1, s:create_empty_row(s:col_count(lnum-1)))
    if g:vimwiki_table_auto_fmt
      call vimwiki#tbl#format(lnum, 0)
    endif
  endif

  call s:goto_tbl_col(lnum, cur_tbl_col)
endfunction "}}}

function! vimwiki#tbl#kbd_tab(mode) "{{{
  if !s:is_table(getline('.'))
    return "\<Tab>"
  endif
  let action = "\<Esc>l:call vimwiki#tbl#goto_next_col()\<CR>"
  if a:mode == "R"
    let action .= 'R'
  else
    let action .= 'i'
  endif
  return action
endfunction "}}}

function! vimwiki#tbl#kbd_shift_tab(mode) "{{{
  if !s:is_table(getline('.'))
    return "\<S-Tab>"
  endif
  let action = "\<Esc>l:call vimwiki#tbl#goto_prev_col()\<CR>"
  if a:mode == "R"
    let action .= 'R'
  else
    let action .= 'i'
  endif
  return action
endfunction "}}}

function! vimwiki#tbl#create(...) "{{{
  if a:0 > 1
    let cols = a:1
    let rows = a:2
  elseif a:0 == 1
    let cols = a:1
    let rows = 2
  elseif a:0 == 0
    let cols = 5
    let rows = 2
  endif

  if cols < 1
    let cols = 5
  endif

  if rows < 1
    let rows = 2
  endif

  let lines = []
  let row = s:create_empty_row(cols)

  call add(lines, row)
  if rows > 1
    call add(lines, s:create_new_sep(cols))
  endif

  for r in range(rows - 1)
    call add(lines, row)
  endfor
  
  call append(line('.'), lines)
endfunction "}}}

function! vimwiki#tbl#align_or_cmd(cmd) "{{{
  if s:is_table(getline('.'))
    call vimwiki#tbl#format(line('.'), 0)
  else
    exe 'normal! '.a:cmd
  endif
endfunction "}}}

function! vimwiki#tbl#reset_tw(lnum) "{{{
  if !(&filetype == 'vimwiki')
    return
  endif
  let line = getline(a:lnum)
  if !s:is_table(line)
    return
  endif
  
  let s:textwidth = &tw
  let &tw = 0
endfunction "}}}

function! vimwiki#tbl#move_column_left() "{{{

  "echomsg "DEBUG move_column_left: "

  let line = getline('.')

  if !s:is_table(line)
    return
  endif

  let cur_col = s:cur_column()

  if cur_col == -1
    return
  endif

  if cur_col > 0
    call vimwiki#tbl#format(line('.'), 0, cur_col-1, cur_col) 
    call s:goto_tbl_col(line('.'), cur_col-1)
  endif

endfunction "}}}

function! vimwiki#tbl#move_column_right() "{{{
  let line = getline('.')
  if !s:is_table(line)
    return
  endif

  let cur_col = s:cur_column()
  if cur_col == -1
    return
  endif

  if cur_col < s:col_count(line('.'))-1
    call vimwiki#tbl#format(line('.'), 0, cur_col, cur_col+1) 
    call s:goto_tbl_col(line('.'), cur_col+1)
  endif

endfunction "}}}

function! vimwiki#tbl#get_rows(lnum) "{{{
  return s:get_rows(a:lnum)
endfunction "}}}

function! vimwiki#tbl#is_table(line) "{{{
  return s:is_table(a:line)
endfunction "}}}

function! vimwiki#tbl#is_separator(line) "{{{
  return s:is_separator(a:line)
endfunction "}}}

function! vimwiki#tbl#cell_splitter() "{{{
  return '\s*'.s:rxSep().'\s*'
endfunction "}}}

function! vimwiki#tbl#sep_splitter() "{{{
  return '-'.s:rxSep().'-'
endfunction "}}}

"}}}
