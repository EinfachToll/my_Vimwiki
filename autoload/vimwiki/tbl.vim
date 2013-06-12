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
  return g:vimwiki_rxTableSep
endfunction "}}}

function! s:defautlSep() "{{{
  return "│"
endfunction "}}}

function! s:defaultLine()
  return "─"
endfunction

function! s:cell_splitter() "{{{
  return '\s*'.s:rxSep().'\s*'
endfunction "}}}

function! s:sep_splitter() "{{{
  return '-'.s:rxSep().'-'
endfunction "}}}

function! s:is_separator_tail(line) "{{{
  return a:line =~ '^\{-1}\%(\s*\|-*\)\%('.s:rxSep().'-\+\)\+'.s:rxSep().'\s*$'
endfunction "}}}

function! s:is_last_column(lnum, cnum) "{{{
  let line = strpart(getline(a:lnum), a:cnum - 1)
  "echomsg "DEBUG is_last_column> ".(line =~ s:rxSep().'\s*$' && line !~ s:rxSep().'.*'.s:rxSep().'\s*$')
  return line =~ s:rxSep().'\s*$'  && line !~ s:rxSep().'.*'.s:rxSep().'\s*$'
 
endfunction "}}}

function! s:is_first_column(lnum, cnum) "{{{
  let line = strpart(getline(a:lnum), 0, a:cnum - 1)
  "echomsg "DEBUG is_first_column> ".(line =~ '^\s*'.s:rxSep() && line !~ '^\s*'.s:rxSep().'.*'.s:rxSep())
  return line =~ '^\s*$' || (line =~ '^\s*'.s:rxSep() && line !~ '^\s*'.s:rxSep().'.*'.s:rxSep())
endfunction "}}}

function! s:count_separators_up(lnum) "{{{
  let lnum = a:lnum - 1
  while lnum > 1
    if !s:is_separator(getline(lnum))
      break
    endif
    let lnum -= 1
  endwhile

  return (a:lnum-lnum)
endfunction "}}}

function! s:count_separators_down(lnum) "{{{
  let lnum = a:lnum + 1
  while lnum < line('$')
    if !s:is_separator(getline(lnum))
      break
    endif
    let lnum += 1
  endwhile

  return (lnum-a:lnum)
endfunction "}}}

function! s:create_empty_row(cols) "{{{
  let row = s:defautlSep()
  let cell = "   ".s:defautlSep()

  for c in range(a:cols)
    let row .= cell
  endfor

  return row
endfunction "}}}

function! s:create_row_sep(cols) "{{{
  let row = '├'
  let cell = repeat(s:defaultLine(), 3) . '┼'

  for c in range(a:cols - 1)
    let row .= cell
  endfor
  let row .= repeat(s:defaultLine(), 3) . '┤'

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
  return len(s:get_cell_infos(a:lnum, getline(a:lnum)))
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
"Returns: something like [['bla', 3], ['blubb', 5]]
function! s:get_cell_infos(lnum, line_content) "{{{
  let result = []
  let cell = ''
  let width = 0

  let normalsyntax = synconcealed(a:lnum, indent(a:lnum)+1)[2]
  let line_width = col([a:lnum, '$'])

  let idx = match(a:line_content, '[│|]') + 2
  let ch = matchstr(a:line_content, '\%'.idx.'c.')
  while (ch == ' ' || ch == '') && idx < line_width
    let idx += 1
    let ch = matchstr(a:line_content, '\%'.idx.'c.')
  endwhile
  while idx < line_width
    let ch = matchstr(a:line_content, '\%'.idx.'c.')
    if ch == '' | let idx += 1 | continue | endif
    let syn = synconcealed(a:lnum, idx)
    "echom idx . " " . ch . " " . string(syn)

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
			if syn[0] == 0 || syn[1] != ''
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
  return a:line =~ '^\s*[├│|][-─|│┼]\{2,}[┤|│]\s*$'
endfunction "}}}

fu! vimwiki#tbl#format(lnum, ...)
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

  let &tw = s:textwidth
endfu



function! s:get_cell_max_lens(lnum) "{{{
  let max_lens = {}
  for [lnum, row] in s:get_rows(a:lnum)
    if s:is_separator(row)
      continue
    endif
    let cells = s:get_cell_infos(lnum, row)
    for idx in range(len(cells))
      let width = cells[idx][1]
      if has_key(max_lens, idx)
        let max_lens[idx] = max([width, max_lens[idx]])
      else
        let max_lens[idx] = width
      endif
    endfor
  endfor
  return max_lens
endfunction "}}}

function! s:cur_column() "{{{
  let lnum = line('.')
  let line = getline(lnum)
  if !s:is_table(line)
    return -1
  endif
  " TODO: do we need conditional: if s:is_separator(line)

  let curs_pos = col('.')
  let mpos = match(line, '[│|├]') + 1
  let normalsyntax = synID(lnum, mpos, 0)
  let col = -1

  while mpos < curs_pos && mpos != -1
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
  let new_line = '│'
  for idx in range(len(a:cells))
    let cell = ' '.a:cells[idx][0].' '
    let width = a:cells[idx][1]

    let diff = a:max_lens[idx] - width
    let cell .= repeat(' ', diff)

    let new_line .= cell.'│'
  endfor

  let idx = len(a:cells)
  while idx < len(a:max_lens)
    let new_line .= repeat(' ', a:max_lens[idx]+2).'│'
    let idx += 1
  endwhile
  return new_line
endfunction

function! s:fmt_sep(max_lens) "{{{
  return '├' . join(map(a:max_lens, "repeat('─', v:val + 2)"), '┼') . '┤'
endfunction "}}}
"}}}

" Keyboard functions "{{{
function! s:kbd_create_new_row(cols, goto_first) "{{{
  let cmd = "\<ESC>o".s:create_empty_row(a:cols)
  let cmd .= "\<ESC>:call vimwiki#tbl#format(line('.'))\<CR>"
  let cmd .= "\<ESC>0"
  if a:goto_first
    let cmd .= ":call search('\\(".s:rxSep()."\\)\\zs', 'c', line('.'))\<CR>"
  else
    let cmd .= (col('.')-1)."l"
    let cmd .= ":call search('\\(".s:rxSep()."\\)\\zs', 'bc', line('.'))\<CR>"
  endif
  let cmd .= "a"

  return cmd
endfunction "}}}

function! s:kbd_goto_next_row() "{{{
  let cmd = "\<ESC>j"
  let cmd .= ":call search('.\\(".s:rxSep()."\\)', 'c', line('.'))\<CR>"
  let cmd .= ":call search('\\(".s:rxSep()."\\)\\zs', 'bc', line('.'))\<CR>"
  let cmd .= "a"
  return cmd
endfunction "}}}

function! s:kbd_goto_prev_row() "{{{
  let cmd = "\<ESC>k"
  let cmd .= ":call search('.\\(".s:rxSep()."\\)', 'c', line('.'))\<CR>"
  let cmd .= ":call search('\\(".s:rxSep()."\\)\\zs', 'bc', line('.'))\<CR>"
  let cmd .= "a"
  return cmd
endfunction "}}}

" Used in s:kbd_goto_next_col
function! vimwiki#tbl#goto_next_col() "{{{
  let curcol = virtcol('.')
  let lnum = line('.')
  let newcol = s:get_indent(lnum)
  let max_lens = s:get_cell_max_lens(lnum)
  for cell_len in values(max_lens)
    if newcol >= curcol-1
      break
    endif
    let newcol += cell_len + 3 " +3 == 2 spaces + 1 separator |<space>...<space>
  endfor
  let newcol += 2 " +2 == 1 separator + 1 space |<space
  call vimwiki#u#cursor(lnum, newcol)
endfunction "}}}

function! s:kbd_goto_next_col(jumpdown) "{{{
  let cmd = "\<ESC>"
  if a:jumpdown
    let seps = s:count_separators_down(line('.'))
    let cmd .= seps."j0"
  endif
  let cmd .= ":call vimwiki#tbl#goto_next_col()\<CR>"
  return cmd
endfunction "}}}

" Used in s:kbd_goto_prev_col
function! vimwiki#tbl#goto_prev_col() "{{{
  let curcol = virtcol('.')
  let lnum = line('.')
  let newcol = s:get_indent(lnum)
  let max_lens = s:get_cell_max_lens(lnum)
  let prev_cell_len = 0
  "echom string(max_lens) 
  for cell_len in values(max_lens)
    let delta = cell_len + 3 " +3 == 2 spaces + 1 separator |<space>...<space>
    if newcol + delta > curcol-1
      let newcol -= (prev_cell_len + 3) " +3 == 2 spaces + 1 separator |<space>...<space>
      break
    elseif newcol + delta == curcol-1
      break
    endif
    let prev_cell_len = cell_len
    let newcol += delta
  endfor
  let newcol += 2 " +2 == 1 separator + 1 space |<space
  call vimwiki#u#cursor(lnum, newcol)
endfunction "}}}

function! s:kbd_goto_prev_col(jumpup) "{{{
  let cmd = "\<ESC>"
  if a:jumpup
    let seps = s:count_separators_up(line('.'))
    let cmd .= seps."k"
    let cmd .= "$"
  endif
  let cmd .= ":call vimwiki#tbl#goto_prev_col()\<CR>a"
  " let cmd .= ":call search('\\(".s:rxSep()."\\)\\zs', 'b', line('.'))\<CR>"
  " let cmd .= "a"
  "echomsg "DEBUG kbd_goto_prev_col> ".cmd
  return cmd
endfunction "}}}

"}}}

" Global functions {{{
function! vimwiki#tbl#kbd_cr() "{{{
  let lnum = line('.')
  if !s:is_table(getline(lnum))
    return "\<CR>"
  endif

  if s:is_separator(getline(lnum+1)) || !s:is_table(getline(lnum+1))
    let cols = len(vimwiki#tbl#get_cells(getline(lnum)))
    return s:kbd_create_new_row(cols, 0)
  else
    return s:kbd_goto_next_row()
  endif
endfunction "}}}

function! vimwiki#tbl#kbd_tab(mode) "{{{
  let lnum = line('.')
  if !s:is_table(getline(lnum))
    return "\<Tab>"
  endif

  let last = s:is_last_column(lnum, col('.'))
  let is_sep = s:is_separator_tail(getline(lnum))
  "echomsg "DEBUG kbd_tab> last=".last.", is_sep=".is_sep
  if (is_sep || last) && !s:is_table(getline(lnum+1))
    let cols = len(vimwiki#tbl#get_cells(getline(lnum)))
    return s:kbd_create_new_row(cols, 1)
  endif
  let machdas = s:kbd_goto_next_col(is_sep || last)
  if a:mode == "R"
    let machdas .= 'lR'
  else
    let machdas .= 'a'
  endif
  return machdas
endfunction "}}}

function! vimwiki#tbl#kbd_shift_tab() "{{{
  let lnum = line('.')
  if !s:is_table(getline(lnum))
    return "\<S-Tab>"
  endif

  let first = s:is_first_column(lnum, col('.'))
  let is_sep = s:is_separator_tail(getline(lnum))
  "echomsg "DEBUG kbd_tab> ".first
  if (is_sep || first) && !s:is_table(getline(lnum-1))
    return ""
  endif
  return s:kbd_goto_prev_col(is_sep || first)
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
    call add(lines, s:create_row_sep(cols))
  endif

  for r in range(rows - 1)
    call add(lines, row)
  endfor
  
  call append(line('.'), lines)
endfunction "}}}

function! vimwiki#tbl#align_or_cmd(cmd) "{{{
  if s:is_table(getline('.'))
    call vimwiki#tbl#format(line('.'))
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

"XXX evtl. könnte der Cursor mitrücken
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
    call vimwiki#tbl#format(line('.'), cur_col-1, cur_col) 
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

  "XXX funkioniert nicht für Trennlinien
  if cur_col < s:col_count(line('.'))-1
    call vimwiki#tbl#format(line('.'), cur_col, cur_col+1) 
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
  return s:cell_splitter()
endfunction "}}}

function! vimwiki#tbl#sep_splitter() "{{{
  return s:sep_splitter()
endfunction "}}}

"}}}
