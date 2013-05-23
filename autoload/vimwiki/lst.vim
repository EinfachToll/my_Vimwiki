" vim:tabstop=2:shiftwidth=2:expandtab:foldmethod=marker:textwidth=79
" Vimwiki autoload plugin file
" Everything concerning bulleted and numbered lists and checkboxes
" Author: Daniel Schemala <istjanichtzufassen@gmail.com>
" Home: http://code.google.com/p/vimwiki/

if exists("g:loaded_vimwiki_list_auto") || &cp
  finish
endif
let g:loaded_vimwiki_list_auto = 1

" incrementation functions for the various kinds of numbers {{{

function! s:increment_1(value) "{{{
  return eval(a:value) + 1
endfunction "}}}

function! s:increment_A(value) "{{{
  let list_of_chars = split(a:value, '.\zs')
  let done = 0
  for idx in reverse(range(len(list_of_chars)))
    let cur_num = char2nr(list_of_chars[idx])
    if cur_num < 90
      let list_of_chars[idx] = nr2char(cur_num + 1)
      let done = 1
      break
    else
      let list_of_chars[idx] = 'A'
    endif
  endfor
  if !done
    call insert(list_of_chars, 'A')
  endif
  return join(list_of_chars, '')
endfunction "}}}

function! s:increment_a(value) "{{{
  let list_of_chars = split(a:value, '.\zs')
  let done = 0
  for idx in reverse(range(len(list_of_chars)))
    let cur_num = char2nr(list_of_chars[idx])
    if cur_num < 122
      let list_of_chars[idx] = nr2char(cur_num + 1)
      let done = 1
      break
    else
      let list_of_chars[idx] = 'a'
    endif
  endfor
  if !done
    call insert(list_of_chars, 'a')
  endif
  return join(list_of_chars, '')
endfunction "}}}

function! s:increment_I(value) "{{{
  let subst_list = [ ['XLVIII$', 'IL'], ['VIII$', 'IX'], ['III$', 'IV'], ['DCCCXCIX$', 'CM'], ['CCCXCIX$', 'CD'], ['LXXXIX$', 'XC'], ['XXXIX$', 'XL'], ['\(I\{1,2\}\)$', '\1I'], ['CDXCIX$', 'D'], ['CMXCIX$', 'M'], ['XCIX$', 'C'], ['I\([VXLCDM]\)$', '\1'], ['\([VXLCDM]\)$', '\1I'] ]
  for [regex, subst] in subst_list
    if a:value =~# regex
      return substitute(a:value, regex, subst, '')
    endif
  endfor
endfunction "}}}

function! s:increment_i(value) "{{{
  let subst_list = [ ['xlviii$', 'il'], ['viii$', 'ix'], ['iii$', 'iv'], ['dcccxcix$', 'cm'], ['cccxcix$', 'cd'], ['lxxxix$', 'xc'], ['xxxix$', 'xl'], ['\(i\{1,2\}\)$', '\1i'], ['cdxcix$', 'd'], ['cmxcix$', 'm'], ['xcix$', 'c'], ['i\([vxlcdm]\)$', '\1'], ['\([vxlcdm]\)$', '\1i'] ]
  for [regex, subst] in subst_list
    if a:value =~# regex
      return substitute(a:value, regex, subst, '')
    endif
  endfor
endfunction "}}}

" incrementation functions for the various kinds of numbers }}}

function! s:substitute_rx_in_line(lnum, pattern, new_string) "{{{
  call setline(a:lnum, substitute(getline(a:lnum), a:pattern, a:new_string, ''))
endfunction "}}}

function! s:substitute_string_in_line(lnum, pattern, new_string) "{{{
  call s:substitute_rx_in_line(a:lnum, vimwiki#u#escape(a:pattern), a:new_string)
endfunction "}}}

"Returns: the mainly used data structure in this file
"An item represents a single list item and is a dictionary with the keys
"lnum - the line number of the list item
"type - 1 for bulleted item, 2 for numbered item, 0 for a regular line
"mrkr - the concrete marker, e.g. '**' or 'b)'
"cb   - the char in the checkbox or '' if there is no checkbox
function! s:get_item(lnum) "{{{
  let item = {'lnum': a:lnum}
  if a:lnum == 0 || a:lnum > line('$')
    let item.type = 0
    return item
  endif
  let matches = matchlist(getline(a:lnum), vimwiki#lst#get_list_item_rx(1))
  if matches == [] || (matches[1] == '' && matches[2] == '') || (matches[1] != '' && matches[2] != '')
    let item.type = 0
    return item
  endif

  let item.cb = matches[3]

  if matches[1] != ''
    let item.type = 1
    let item.mrkr = matches[1]
  else
    let item.type = 2
    let item.mrkr = matches[2]
  endif

  return item
endfunction "}}}


"Returns: level of the line
"0 is the 'highest' level
function! s:get_level(lnum) "{{{
  if VimwikiGet('syntax') != 'media'
    let level = getline(a:lnum) !~ '^\s*$' ? indent(a:lnum) : 0
  else
    let rx_markers = '^[' . vimwiki#u#escape(join(keys(g:vimwiki_bullet_points), "")) . ']\+'
    let level = s:string_length(matchstr(getline(a:lnum), rx_markers)) - 1
    if level < 0
      let level = (indent(a:lnum) == 0) ? 0 : 9999
    endif
  endif
  return level
endfunction "}}}

"XXX does not distinguish between letters and romanian numerals
"Should be no problem as long as the user doesn't mix them
function! s:regexp_of_marker(item) "{{{
  if a:item.type == 1
    return vimwiki#u#escape(a:item.mrkr)
  elseif a:item.type == 2
    for ki in ['d', 'u', 'l']
      let mats = matchstr(a:item.mrkr, '\'.ki.'\+['.vimwiki#u#escape(g:vimwiki_bullet_numbers[1]).']')
      if mats != ''
        let [_, divisor] = s:get_chars_and_divisor(mats)
        return '\'.ki.'\+'.vimwiki#u#escape(divisor)
      endif
    endfor
  else
    return ''
  endif
endfunction "}}}

function! s:empty_item() "{{{
  return {'type': 0}
endfunction "}}}

"Returns: the list item after a:item in its list or empty item
"If a:all is 1, the markers can differ
function! s:get_next_list_item(item, all) "{{{
  return s:get_next_or_prev_list_item(a:item, +1, line('$')+1, a:all)
endfunction "}}}

"Returns: the list item before a:item in its list or empty item
"If a:all is 1, the markers can differ
function! s:get_prev_list_item(item, all) "{{{
  return s:get_next_or_prev_list_item(a:item, -1, 0, a:all)
endfunction "}}}

function! s:get_next_or_prev_list_item(item, direction, until, all) "{{{
  let org_lvl = s:get_level(a:item.lnum)
  let org_regex = s:regexp_of_marker(a:item)
  let cur_ln = s:get_next_prev_line(a:item.lnum, a:direction)
  while cur_ln != a:until
    let cur_lvl = s:get_level(cur_ln)
    let cur_linecontent = getline(cur_ln)

    if cur_lvl == org_lvl
      if a:all == 1 || cur_linecontent =~# '^\s*'.org_regex.'\s'
        return s:get_item(cur_ln)
      else
        return s:empty_item()
      endif
    elseif cur_lvl < org_lvl
      return s:empty_item()
    else
      let cur_ln = s:get_next_prev_line(cur_ln, a:direction)
    endif
  endwhile
  return s:empty_item()
endfunction "}}}

function! s:first_char(string) "{{{
  return matchstr(a:string, '^.')
endfunction "}}}

"Returns: 'bla)' -> ['bla', ')']
" must be that complicated, because
" 'bla)'[:-2] wouldn't work for multibyte chars
function! s:get_chars_and_divisor(string) "{{{
  return matchlist(a:string, '^\(.\+\)\(.\)$')[1:2]
endfunction "}}}

"Returns: 1, a, i, A, I or ''
"If in doubt if alphanumeric character or romanian
"numeral, peek in the previous line
function! s:guess_kind_of_numbered_item(item) "{{{
  if a:item.type != 2 | return '' | endif
  let kinds = split(g:vimwiki_bullet_numbers[0], '.\zs')
  let [chars, divisor] = s:get_chars_and_divisor(a:item.mrkr)

  if chars =~ '\d\+'
    return '1'
  endif
  if chars =~# '\l\+'
    if chars !~# '^[ivxlcdm]\+' || index(kinds, 'i') == -1
      return 'a'
    else

      let item_above = s:get_prev_list_item(a:item, 0)
      if item_above.type != 0
        let [chars_above, div_above] = s:get_chars_and_divisor(item_above.mrkr)
        if index(kinds, 'a') == -1 || (div_above !=# divisor && chars =~# 'i\+') || s:increment_i(chars_above) ==# chars
          return 'i'
        else
          return 'a'
        endif
      else
        if chars =~# 'i\+' || index(kinds, 'a') == -1
          return 'i'
        else
          return 'a'
        endif
      endif

    endif
  endif
  if chars =~# '\u\+'
    if chars !~# '^[IVXLCDM]\+' || index(kinds, 'I') == -1
      return 'A'
    else

      let item_above = s:get_prev_list_item(a:item, 0)
      if item_above.type != 0
        let [chars_above, div_above] = s:get_chars_and_divisor(item_above.mrkr)
        if index(kinds, 'A') == -1 || (div_above !=# divisor && chars =~# 'I\+') || s:increment_i(chars_above) ==# chars
          return 'I'
        else
          return 'A'
        endif
      else
        if chars =~# 'I\+' || index(kinds, 'A') == -1
          return 'I'
        else
          return 'A'
        endif
      endif

    endif
  endif
endfunction "}}}


function! s:get_first_item_in_list(item, all) "{{{
  let first_item = a:item
  while 1
    let prev_item = s:get_prev_list_item(first_item, a:all)
    if prev_item.type == 0
      break
    else
      let first_item = prev_item
    endif
  endwhile
  return first_item
endfunction "}}}

"Returns: lnum+1 in most cases, but skips blank lines and preformatted text
"0 in case of nonvalid line
"If there is no second argument, 0 is returned at a header, otherwise the
"header is skipped
function! s:get_next_line(lnum, ...) "{{{
  if getline(a:lnum) =~# '^\s*'.g:vimwiki_rxPreStart
    let cur_ln = a:lnum + 1
    while cur_ln <= line('$') && getline(cur_ln) !~# '^\s*'.g:vimwiki_rxPreEnd.'\s*$'
      let cur_ln += 1
    endwhile
    let next_line = nextnonblank(cur_ln+1)
  else
    let next_line = nextnonblank(a:lnum+1)
  endif

  if a:0 > 0 && getline(next_line) =~# g:vimwiki_rxHeader
    let next_line = s:get_next_line(next_line, 1)
  endif

  if next_line < 0 || next_line > line('$') || (getline(next_line) =~# g:vimwiki_rxHeader && a:0 == 0)
    return 0
  endif

  return next_line
endfunction "}}}

"Returns: lnum-1 in most cases, but skips blank lines and preformatted text
"0 in case of nonvalid line and a header, because a header ends every list
function! s:get_prev_line(lnum) "{{{
  let prev_line = prevnonblank(a:lnum-1)

  if getline(prev_line) =~# '^\s*'.g:vimwiki_rxPreEnd.'\s*$'
    let cur_ln = a:lnum - 1
    while 1
      if cur_ln == 0 || getline(cur_ln) =~# '^\s*'.g:vimwiki_rxPreStart
        break
      endif
      let cur_ln -= 1
    endwhile
    let prev_line = cur_ln
  endif

  if prev_line < 0 || prev_line > line('$') || getline(prev_line) =~# g:vimwiki_rxHeader
    return 0
  endif

  return prev_line
endfunction "}}}

function! s:get_next_prev_line(lnum, dir) "{{{
  if a:dir == 1
    return s:get_next_line(a:lnum)
  else
    return s:get_prev_line(a:lnum)
  endif
endfunction "}}}

function! s:get_first_child(item) "{{{
  if a:item.lnum >= line('$')
    return s:empty_item()
  endif
  let org_lvl = s:get_level(a:item.lnum)
  let cur_item = s:get_item(s:get_next_line(a:item.lnum))
  while 1
    if cur_item.type != 0 && s:get_level(cur_item.lnum) > org_lvl
      return cur_item
    endif
    if cur_item.lnum > line('$') || cur_item.lnum <= 0 || s:get_level(cur_item.lnum) <= org_lvl
      return s:empty_item()
    endif
    let cur_item = s:get_item(s:get_next_line(cur_item.lnum))
  endwhile
endfunction "}}}


"Returns: the next sibling of a:child, given the parent item
"Used for iterating over children
"Note: child items do not necessarily have the same indent, i.e. level
function! s:get_next_child_item(parent, child) "{{{
  if a:parent.type == 0 | return s:empty_item() | endif
  let parent_lvl = s:get_level(a:parent.lnum)
  let cur_ln = s:get_last_line_of_item_incl_children(a:child)
  while 1
    let next_line = s:get_next_line(cur_ln)
    if next_line == 0 || s:get_level(next_line) <= parent_lvl
      break
    endif
    let cur_ln = next_line
    let cur_item = s:get_item(cur_ln)
    if cur_item.type > 0
      return cur_item
    endif
  endwhile
  return s:empty_item()
endfunction "}}}

"Renumbers the current list from a:item on downwards
"Returns: the last item that was adjusted
function! s:adjust_numbered_list_below(item, recursive) "{{{
  if !(a:item.type == 2 || (a:item.type == 1 && a:recursive))
    return a:item
  endif

  let kind = s:guess_kind_of_numbered_item(a:item)

  let cur_item = a:item
  while 1
    if a:recursive
      call s:adjust_items_recursively(cur_item)
    endif

    let next_item = s:get_next_list_item(cur_item, 0)
    if next_item.type == 0
      break
    endif

    if cur_item.type == 2
      let [chars, divisor] = s:get_chars_and_divisor(cur_item.mrkr)
      let new_val = s:increment_{kind}(chars) . divisor
      call s:substitute_string_in_line(next_item.lnum, next_item.mrkr, new_val)
      let next_item.mrkr = new_val
    endif

    let cur_item = next_item
  endwhile
  return cur_item
endfunction "}}}

function! s:adjust_items_recursively(parent) "{{{
  if a:parent.type == 0
    return s:empty_item()
  end

  let child_item = s:get_first_child(a:parent)
  if child_item.type == 0
    return child_item
  endif
  while 1
    let last_item = s:adjust_numbered_list(child_item, 1, 1)

    let child_item = s:get_next_child_item(a:parent, last_item)
    if child_item.type == 0
      return last_item
    endif
  endwhile
endfunction "}}}

"Renumbers the list a:item is in.
"If a:all == 0, only the items which have the same kind of marker as a:item are
"considered, otherwise all items.
"Returns: the last item that was adjusted
function! s:adjust_numbered_list(item, all, recursive) "{{{
  if !(a:item.type == 2 || (a:item.type == 1 && (a:all || a:recursive)))
    return s:empty_item()
  end

  let first_item = s:get_first_item_in_list(a:item, a:all)

  while 1
    if first_item.type == 2
      let [_, divisor] = s:get_chars_and_divisor(first_item.mrkr)
      let new_mrkr = s:guess_kind_of_numbered_item(first_item) . divisor
      call s:substitute_string_in_line(first_item.lnum, first_item.mrkr, new_mrkr)
      let first_item.mrkr = new_mrkr
    endif

    let last_item = s:adjust_numbered_list_below(first_item, a:recursive)

    let next_first_item = s:get_next_list_item(last_item, 1)
    if a:all == 0 || next_first_item.type == 0
      return last_item
    endif
    let first_item = next_first_item
  endwhile
endfunction "}}}

"Returns: the (rounded) rate of [X] checked child items in percent
function! s:get_rate(item) "{{{
  let rate = -1
  if a:item.type == 0 || a:item.cb == ''
    return rate
  endif
  let state = a:item.cb
  return index(g:vimwiki_listsyms, state) * 25
endfunction "}}}

"Set state of the list item to [ ] or [o] or whatever
"Returns: 1 if the state changed, 0 otherwise
function! s:set_state(item, new_rate) "{{{
  let new_state = s:rate_to_state(a:new_rate)
  let old_state = s:rate_to_state(s:get_rate(a:item))
  if new_state !=# old_state
    call s:substitute_rx_in_line(a:item.lnum, '\[.]', '['.new_state.']')
    return 1
  else
    return 0
  endif
endfunction "}}}

"Set state of the list item to [ ] or [o] or whatever
"Updates the states of its child items
function! s:set_state_plus_children(item, new_rate) "{{{
  call s:set_state(a:item, a:new_rate)

  let child_item = s:get_first_child(a:item)
  while 1
    if child_item.type == 0
      break
    endif
    if child_item.cb != ''
      call s:set_state_plus_children(child_item, a:new_rate)
    endif
    let child_item = s:get_next_child_item(a:item, child_item)
  endwhile
endfunction "}}}

function! s:rate_to_state(rate) "{{{
  let state = ''
  if a:rate == 100
    let state = g:vimwiki_listsyms[4]
  elseif a:rate == 0
    let state = g:vimwiki_listsyms[0]
  elseif a:rate >= 67
    let state = g:vimwiki_listsyms[3]
  elseif a:rate >= 34
    let state = g:vimwiki_listsyms[2]
  else
    let state = g:vimwiki_listsyms[1]
  endif
  return state
endfunction "}}}

function! s:get_parent(item) "{{{
  let parent_line = 0

  let cur_ln = prevnonblank(a:item.lnum)
  let child_lvl = s:get_level(cur_ln)
  if child_lvl == 0
    return s:empty_item()
  endif

  while 1
    let cur_ln = s:get_prev_line(cur_ln)
    if cur_ln == 0 | break | endif
    let cur_lvl = s:get_level(cur_ln)
    if cur_lvl < child_lvl
      let cur_item = s:get_item(cur_ln)
      if cur_item.type == 0
        let child_lvl = cur_lvl
        continue
      endif
      let parent_line = cur_ln
      break
    endif
  endwhile
  return s:get_item(parent_line)
endfunction "}}}

function! s:update_state(item) "{{{
  if a:item.type == 0 || a:item.cb == ''
    return
  endif

  let sum_siblings = 0
  let count_siblings = 0

  let child_item = s:get_first_child(a:item)

  while 1
    if child_item.type == 0
      break
    endif
    if child_item.cb != ''
      let count_siblings += 1
      let sum_siblings += s:get_rate(child_item)
    endif
    let child_item = s:get_next_child_item(a:item, child_item)
  endwhile

  let new_rate = count_siblings > 0 ? sum_siblings / count_siblings : 0

  "set state and set the parents states recursively
  let state_changed = s:set_state(a:item, new_rate)
  if state_changed
    call s:update_state(s:get_parent(a:item))
  endif
endfunction "}}}


"Creates checkbox in a list item.
"Returns: 1 if successful
function! s:create_cb(item) "{{{
  if a:item.type == 0 || a:item.cb != ''
    return 0
  endif

  let new_item = a:item
  let new_item.cb = g:vimwiki_listsyms[0]
  call s:substitute_rx_in_line(new_item.lnum, vimwiki#u#escape(new_item.mrkr) . '\zs\ze', ' [' . new_item.cb . ']')

  call s:update_state(new_item)
  return 1
endfunction "}}}

"Returns: the item if there is one in a:lnum
"else the multiline item a:lnum belongs to
function! s:get_corresponding_item(lnum) "{{{
  let item = s:get_item(a:lnum)
  if item.type != 0
    return item
  endif
  let org_lvl = s:get_level(a:lnum)
  let cur_ln = a:lnum
  while cur_ln > 0
    let cur_lvl = s:get_level(cur_ln)
    let cur_item = s:get_item(cur_ln)
    if cur_lvl < org_lvl && cur_item.type != 0
      return cur_item
    endif
    if cur_lvl < org_lvl
      let org_lvl = cur_lvl
    endif
    let cur_ln = s:get_prev_line(cur_ln)
  endwhile
  return s:empty_item()
endfunction "}}}

"Returns: the last line of a (possibly multiline) item, including all children
function! s:get_last_line_of_item_incl_children(item) "{{{
  let cur_ln = a:item.lnum
  let org_lvl = s:get_level(a:item.lnum)
  while 1
    let next_line = s:get_next_line(cur_ln)
    if next_line == 0 || s:get_level(next_line) <= org_lvl
      return cur_ln
    endif
    let cur_ln = next_line
  endwhile
endfunction "}}}

"Returns: the last line of a (possibly multiline) item
"Note: there can be other list items inbetween these lines
function! s:get_last_line_of_item(item) "{{{
  if a:item.type == 0 | return 0 | endif
  let org_lvl = s:get_level(a:item.lnum)
  let last_corresponding_line = a:item.lnum

  let cur_ln = s:get_next_line(a:item.lnum)
  while 1
    if cur_ln == 0 || s:get_level(cur_ln) <= org_lvl
      break
    endif
    let cur_item = s:get_item(cur_ln)
    if cur_item.type == 0
      let last_corresponding_line = cur_ln
      let cur_ln = s:get_next_line(cur_ln)
    else
      let cur_ln = s:get_next_line(s:get_last_line_of_item_incl_children(cur_item))
    endif
  endwhile

  return last_corresponding_line
endfunction "}}}

"Returns: the column where the text of a line starts (possible list item
"markers and checkboxes are skipped)
function! s:text_begin(lnum) "{{{
  return s:string_length(matchstr(getline(a:lnum), vimwiki#lst#get_list_item_rx(1)))
endfunction "}}}

if exists("*strdisplaywidth")
  fu! s:string_length(str)
    return strdisplaywidth(a:str)
  endfu
else
  fu! s:string_length(str)
    return strlen(substitute(a:str, '.', 'x', 'g'))
  endfu
endif

"Returns: 2 if there is a marker and text
" 1 for a marker and no text
" 0 for no marker at all (empty line or only text)
function! s:line_has_marker(lnum) "{{{
  if getline(a:lnum) =~# vimwiki#lst#get_list_item_rx(1).'\s*$'
    return 1
  elseif getline(a:lnum) =~# vimwiki#lst#get_list_item_rx(1).'\s*\S'
    return 2
  else
    return 0
  endif
endfunction "}}}

"Renumbers the list the cursor is in
"also update its parents state
function! vimwiki#lst#adjust_numbered_list() "{{{
  let cur_item = s:get_corresponding_item(line('.'))
  if cur_item.type == 0 | return | endif
  call s:adjust_numbered_list(cur_item, 1, 0)
  call s:update_state(s:get_parent(cur_item))
endfunction "}}}

"Renumbers all lists of the buffer
"of course, this might take some seconds
function! vimwiki#lst#adjust_whole_buffer() "{{{
  let cur_ln = 1
  while 1
    let cur_item = s:get_item(cur_ln)
    if cur_item.type != 0
      let cur_item = s:adjust_numbered_list(cur_item, 0, 1)
    endif
    let cur_ln = s:get_next_line(cur_item.lnum, 1)
    if cur_ln <= 0 || cur_ln > line('$')
      return
    endif
  endwhile
endfunction "}}}

"Toggle checkbox between [ ] and [X] or creates one
function! vimwiki#lst#toggle_cb(line1, line2) "{{{
  let from_item = s:get_corresponding_item(a:line1)
  let to_item = s:get_corresponding_item(a:line2)
  if from_item.type == 0
    return
  endif

  let parent_items_of_lines = []

  if from_item.cb == ''

    "if line1 has no CB, make a CB in every selected line
    let parent_items_of_lines = []
    for cur_ln in range(from_item.lnum, to_item.lnum)
      let cur_item = s:get_item(cur_ln)
      let success = s:create_cb(cur_item)

      if success
        let cur_parent_item = s:get_parent(cur_item)
        if index(parent_items_of_lines, cur_parent_item) == -1
          call insert(parent_items_of_lines, cur_parent_item)
        endif
      endif
    endfor

  else

    "if line1 has CB, toggle it and set all siblings to the same new state
    let rate_first_line = s:get_rate(from_item)
    let new_rate = rate_first_line==100 ? 0 : 100

    for cur_ln in range(from_item.lnum, to_item.lnum)
      let cur_item = s:get_item(cur_ln)
      if cur_item.type != 0 && cur_item.cb != ''
        call s:set_state_plus_children(cur_item, new_rate)
        let cur_parent_item = s:get_parent(cur_item)
        if index(parent_items_of_lines, cur_parent_item) == -1
          call insert(parent_items_of_lines, cur_parent_item)
        endif
      endif
    endfor

  endif

  for parent_item in parent_items_of_lines
    call s:update_state(parent_item)
  endfor

endfunction "}}}

function! s:get_idx_list_markers(item) "{{{
  if a:item.type == 1
    let m = s:first_char(a:item.mrkr)
  else
    let [_, divisor] = s:get_chars_and_divisor(a:item.mrkr)
    let m = s:guess_kind_of_numbered_item(a:item) . divisor
  endif
  return index(g:vimwiki_list_markers, m)
endfunction "}}}

function! s:get_next_mrkr(item) "{{{
  if a:item.type == 0
    let new_mrkr = g:vimwiki_list_markers[0]
  else
    let idx = s:get_idx_list_markers(a:item)
    let new_mrkr = g:vimwiki_list_markers[(idx + 1) % len(g:vimwiki_list_markers)]
  endif
  return new_mrkr
endfunction "}}}

function! s:get_prev_mrkr(item) "{{{
  if a:item.type == 0
    return g:vimwiki_list_markers[-1]
  endif
  let idx = s:get_idx_list_markers(a:item)
  if idx == -1
    return g:vimwiki_list_markers[-1]
  else
    return g:vimwiki_list_markers[(idx - 1 + len(g:vimwiki_list_markers)) % len(g:vimwiki_list_markers)]
  endif
endfunction "}}}

function! s:set_new_mrkr(item, new_mrkr) "{{{
  if a:item.type == 0
    call s:substitute_rx_in_line(a:item.lnum, '^\s*\zs\ze', a:new_mrkr.' ')
    if indent(a:item.lnum) == 0 && VimwikiGet('syntax') != 'media'
      call s:set_indent(a:item.lnum, vimwiki#lst#get_list_margin())
    endif
  else
    call s:substitute_string_in_line(a:item.lnum, a:item.mrkr, a:new_mrkr)
  endif
endfunction "}}}

function! vimwiki#lst#change_marker(line1, line2, new_mrkr) "{{{
  let cur_col_from_eol = col("$") - col("'^")
  let new_mrkr = a:new_mrkr
  let cur_ln = a:line1
  while 1
    let cur_item = s:get_item(cur_ln)

    if new_mrkr ==# "next"
      let new_mrkr = s:get_next_mrkr(cur_item)
    elseif new_mrkr ==# "prev"
      let new_mrkr = s:get_prev_mrkr(cur_item)
    endif

    "handle markers like ***
    if has_key(g:vimwiki_bullet_points, s:first_char(new_mrkr)) && g:vimwiki_bullet_points[s:first_char(new_mrkr)] == 1
      "use *** if the item above has *** too
      let item_above = s:get_prev_list_item(cur_item, 1)
      if item_above.type == 1 && s:first_char(item_above.mrkr) == s:first_char(new_mrkr)
        let new_mrkr = item_above.mrkr
      else
        "use *** if the item below has *** too
        let item_below = s:get_next_list_item(cur_item, 1)
        if item_below.type == 1 && s:first_char(item_below.mrkr) == s:first_char(new_mrkr)
          let new_mrkr = item_below.mrkr
        else
          "if the old is ### and the new is * use ***
          if cur_item.type == 1 && has_key(g:vimwiki_bullet_points, s:first_char(cur_item.mrkr)) && g:vimwiki_bullet_points[s:first_char(cur_item.mrkr)] == 1
            let new_mrkr = repeat(new_mrkr, s:string_length(cur_item.mrkr))
          else
            "use *** if the parent item has **
            let parent_item = s:get_parent(cur_item)
            if parent_item.type == 1 && s:first_char(parent_item.mrkr) == s:first_char(new_mrkr)
              let new_mrkr = repeat(s:first_char(parent_item.mrkr), s:string_length(parent_item.mrkr)+1)
            endif
          endif
        endif
      endif

    endif

    call s:set_new_mrkr(cur_item, new_mrkr)
    call s:adjust_numbered_list(s:get_item(cur_ln), 1, 0)

    if cur_ln >= a:line2 | break | endif
    let cur_ln = s:get_next_line(cur_ln, 1)
  endwhile

  call cursor('.', col('$') - cur_col_from_eol)
endfunction "}}}

function! s:remove_cb(item) "{{{
  let item = a:item
  if item.type != 0 && item.cb != ''
    let item.cb = ''
    call s:substitute_rx_in_line(item.lnum, '\s\+\[.\]', '')
  endif
  return item
endfunction "}}}

function! vimwiki#lst#remove_cb(first_line, last_line) "{{{
  let first_item = s:get_corresponding_item(a:first_line)
  let last_item = s:get_corresponding_item(a:last_line)

  if first_item.type == 0 || last_item.type == 0
    return
  endif

  let parent_items_of_lines = []
  let cur_ln = first_item.lnum
  while 1
    if cur_ln <= 0 || cur_ln > last_item.lnum | break | endif
    let cur_item = s:get_item(cur_ln)
    if cur_item.type != 0
      let cur_item = s:remove_cb(cur_item)
      let cur_parent_item = s:get_parent(cur_item)
      if index(parent_items_of_lines, cur_parent_item) == -1
        call insert(parent_items_of_lines, cur_parent_item)
      endif
    endif
    let cur_ln = s:get_next_line(cur_ln)
  endwhile
  for parent_item in parent_items_of_lines
    call s:update_state(parent_item)
  endfor
endfunction "}}}

function! vimwiki#lst#remove_cb_in_list() "{{{
  let first_item = s:get_first_item_in_list(s:get_corresponding_item(line('.')), 0)

  let cur_item = first_item
  while 1
    let next_item = s:get_next_list_item(cur_item, 0)
    let cur_item = s:remove_cb(cur_item)
    if next_item.type == 0
      break
    else
      let cur_item = next_item
    endif
  endwhile

  call s:update_state(s:get_parent(first_item))
endfunction "}}}


function! vimwiki#lst#change_marker_in_list(new_mrkr) "{{{
  let first_item = s:get_first_item_in_list(s:get_corresponding_item(line('.')), 0)
  if first_item.type == 0 | return | endif
  let first_item_line = first_item.lnum

  let cur_item = first_item
  while 1
    let next_item = s:get_next_list_item(cur_item, 0)
    call s:set_new_mrkr(cur_item, a:new_mrkr)
    if next_item.type == 0
      break
    else
      let cur_item = next_item
    endif
  endwhile

  call s:adjust_numbered_list(s:get_item(first_item_line), 0, 0)
endfunction "}}}

function! s:set_indent(lnum, new_indent) "{{{
  if &expandtab
    let indentstring = repeat(' ', a:new_indent)
  else
    let indentstring = repeat('\t', a:new_indent / &tabstop) . repeat(' ', a:new_indent % &tabstop)
  endif
  call s:substitute_rx_in_line(a:lnum, '^\s*', indentstring)
endfunction "}}}

function! s:decrease_level(item) "{{{
  let removed_indent = 0
  if VimwikiGet('syntax') == 'media' && a:item.type == 1 && g:vimwiki_bullet_points[s:first_char(a:item.mrkr)]
    if s:string_length(a:item.mrkr) >= 2
      call s:substitute_string_in_line(a:item.lnum, s:first_char(a:item.mrkr), '')
      let removed_indent = -1
    endif
  else
    let old_indent = indent(a:item.lnum)
    if &shiftround
      let new_indent = (old_indent - 1) / &shiftwidth * &shiftwidth
    else
      let new_indent = old_indent - &shiftwidth
    endif
    call s:set_indent(a:item.lnum, new_indent)
    let removed_indent = new_indent - old_indent
  endif
  return removed_indent
endfunction "}}}

function! s:increase_level(item) "{{{
  let additional_space = 0
  if VimwikiGet('syntax') == 'media' && a:item.type == 1 && g:vimwiki_bullet_points[s:first_char(a:item.mrkr)]
    call s:substitute_string_in_line(a:item.lnum, a:item.mrkr, a:item.mrkr . s:first_char(a:item.mrkr))
    let additional_indent = 1
  else
    let old_indent = indent(a:item.lnum)
    if &shiftround
      let new_indent = (old_indent / &shiftwidth + 1) * &shiftwidth
    else
      let new_indent = old_indent + &shiftwidth
    endif
    call s:set_indent(a:item.lnum, new_indent)
    let additional_indent = new_indent - old_indent
  endif
  return additional_indent
endfunction "}}}

"adds a:indent_by to the current indent
"a:indent_by can be negative
function! s:indent_line_by(lnum, indent_by) "{{{
  let item = s:get_item(a:lnum)
  if VimwikiGet('syntax') == 'media' && item.type == 1 && g:vimwiki_bullet_points[s:first_char(item.mrkr)]
    if a:indent_by > 0
      call s:substitute_string_in_line(a:lnum, item.mrkr, item.mrkr . s:first_char(item.mrkr))
    elseif a:indent_by < 0
      call s:substitute_string_in_line(a:lnum, s:first_char(item.mrkr), '')
    endif
  else
    call s:set_indent(a:lnum, indent(a:lnum) + a:indent_by)
  endif
endfunction "}}}

"Returns: the item above or the item below or an empty item
function! s:get_a_neighbor_item(item) "{{{
  let prev_item = s:get_prev_list_item(a:item, 1)
  if prev_item.type != 0
    return prev_item
  else
    let next_item = s:get_next_list_item(a:item, 1)
    if next_item.type != 0
      return next_item
    endif
  endif
  return s:empty_item()
endfunction "}}}

"sets kind of the item depending on neighbor items and the parent item
function! s:adjust_mrkr(item, look_above_and_below) "{{{
  if a:item.type == 0 || VimwikiGet('syntax') == 'media'
    return
  endif

  let new_mrkr = a:item.mrkr
  if a:look_above_and_below
    let neighbor_item = s:get_a_neighbor_item(a:item)
  else
    let neighbor_item = s:get_prev_list_item(a:item, 1)
  endif
  if neighbor_item.type != 0
    let new_mrkr = neighbor_item.mrkr
  endif

  "if possible, set e.g. *** if parent has ** as marker
  if neighbor_item.type == 0 && a:item.type == 1 && has_key(g:vimwiki_bullet_points, s:first_char(a:item.mrkr)) && g:vimwiki_bullet_points[s:first_char(a:item.mrkr)] == 1
    let parent_item = s:get_parent(a:item)
    if parent_item.type == 1 && s:first_char(parent_item.mrkr) == s:first_char(a:item.mrkr)
      let new_mrkr = repeat(s:first_char(parent_item.mrkr), s:string_length(parent_item.mrkr)+1)
    endif
  endif

  call s:substitute_string_in_line(a:item.lnum, a:item.mrkr, new_mrkr)
  call s:adjust_numbered_list(a:item, 0, 1)
endfunction "}}}

"changes lvl of lines in selection
function! s:change_level(from_line, to_line, direction, plus_children) "{{{
  let from_item = s:get_corresponding_item(a:from_line)
  if from_item.type == 0 | return | endif
  if a:from_line == a:to_line
    if a:plus_children
      let to_line = s:get_last_line_of_item_incl_children(from_item)
    else
      let to_line = s:get_last_line_of_item(from_item)
    endif
  else
    let to_line = a:to_line
  endif

  if from_item.type == 0 || to_line == 0
    return
  endif

  let to_be_adjusted = s:get_a_neighbor_item(from_item)
  let old_parent = s:get_parent(from_item)
  let first_line_level = s:get_level(from_item.lnum)
  let more_than_one_level_concerned = 0

  let first_line_indented_by = (a:direction == 'increase') ? s:increase_level(from_item) : s:decrease_level(from_item)

  let cur_ln = s:get_next_line(from_item.lnum)
  while cur_ln > 0 && cur_ln <= to_line
    if !more_than_one_level_concerned && s:get_level(cur_ln) != first_line_level && s:get_item(cur_ln).type != 0
      let more_than_one_level_concerned = 1
    endif
    call s:indent_line_by(cur_ln, first_line_indented_by)
    let cur_ln = s:get_next_line(cur_ln, 1)
  endwhile

  call s:adjust_mrkr(from_item, (a:from_line == a:to_line))
  call s:update_state(old_parent)
  let from_item = s:get_item(from_item.lnum)
  if s:get_rate(from_item) < 100
    call s:update_state(from_item)
  else
    call s:update_state(s:get_parent(from_item))
  endif

  if more_than_one_level_concerned
    call vimwiki#lst#adjust_whole_buffer()
  else
    call s:adjust_numbered_list(to_be_adjusted, 0, 0)
  endif
endfunction "}}}

function! vimwiki#lst#change_level(from_line, to_line, direction, plus_children) "{{{
  let cur_col = col('$') - col('.')
  call s:change_level(a:from_line, a:to_line, a:direction, a:plus_children)
  call cursor('.', col('$') - cur_col)
endfunction "}}}

function! s:clone_marker_from_to(from, to) "{{{
  let item_from = s:get_item(a:from)
  if item_from.type == 0 | return | endif
  let new_mrkr = item_from.mrkr . ' '
  call s:substitute_rx_in_line(a:to, '^\s*', new_mrkr)
  let new_indent = ( VimwikiGet('syntax') != 'media' ? indent(a:from) : 0 )
  call s:set_indent(a:to, new_indent)
  if item_from.cb != ''
    call s:create_cb(s:get_item(a:to))
    call s:update_state(s:get_parent(s:get_item(a:to)))
  endif
  if item_from.type == 2
    let adjust_from = ( a:from < a:to ? a:from : a:to )
    call s:adjust_numbered_list_below(s:get_item(adjust_from), 0)
  endif
endfunction "}}}

"indent line a:lnum to be the continuation of a:prev_item
function! s:indent_multiline(prev_item, lnum) "{{{
  if a:prev_item.type != 0
    call s:set_indent(a:lnum, s:text_begin(a:prev_item.lnum))
  endif
endfunction "}}}


function! vimwiki#lst#kbd_o() "{{{
  let fold_end = foldclosedend('.')
  let lnum = (fold_end == -1) ? line('.') : fold_end
  let cur_item = s:get_item(lnum)
  "inserting and deleting the x is necessary
  "because otherwise the indent is lost
  normal! ox
  if cur_item.lnum < s:get_last_line_of_item(cur_item)
    call s:indent_multiline(cur_item, cur_item.lnum+1)
  else
    call s:clone_marker_from_to(cur_item.lnum, cur_item.lnum+1)
  endif
  startinsert!
endfunction "}}}

function! vimwiki#lst#kbd_O() "{{{
  normal! Ox
  let cur_ln = line('.')
  if getline(cur_ln+1) !~ '^\s*$'
    call s:clone_marker_from_to(cur_ln+1, cur_ln)
  else
    call s:clone_marker_from_to(cur_ln-1, cur_ln)
  endif
  startinsert!
endfunction "}}}

function! s:remove_mrkr(item) "{{{
  let item = a:item
  if item.cb != ''
    let item = s:remove_cb(item)
    let parent_item = s:get_parent(item)
  else
    let parent_item = s:empty_item()
  endif
  call s:substitute_rx_in_line(item.lnum, vimwiki#u#escape(item.mrkr).'\s*', '')
  call remove(item, 'mrkr')
  call remove(item, 'cb')
  let item.type = 0
  call s:update_state(parent_item)
  return item
endfunction "}}}

function! s:create_marker(lnum) "{{{
  let new_sibling = s:get_corresponding_item(a:lnum)
  if new_sibling.type == 0
    let new_sibling = s:get_a_neighbor_item(s:get_item(a:lnum))
  endif
  if new_sibling.type != 0
    call s:clone_marker_from_to(new_sibling.lnum, a:lnum)
  else
    let cur_item = s:get_item(a:lnum)
    call s:set_new_mrkr(cur_item, g:vimwiki_list_markers[0])
    call s:adjust_numbered_list(cur_item, 0, 0)
  endif
endfunction "}}}

"XXX: this is a bit messy
function! vimwiki#lst#kbd_cr(normal, just_mrkr) "{{{
  let lnum = line('.')
  let has_bp = s:line_has_marker(lnum)

  "special behaviour if there is only a marker with no text
  if (has_bp == 1 && a:just_mrkr == 2) || (has_bp != 0 && virtcol('.') < s:text_begin(lnum))
    "insert new Mark but remove Mark in old line
    call append(lnum-1, '')
    startinsert!
    return
  elseif has_bp == 1 && a:just_mrkr == 3
    "list is finished, but cursor stays in current line
    let item = s:get_item(lnum)
    let neighbor_item = s:get_a_neighbor_item(item)
    let child_item = s:get_first_child(item)
    let parent_item = (item.cb != '') ? s:get_parent(item) : s:empty_item()
    normal! "_cc
    call s:adjust_numbered_list(neighbor_item, 0, 0)
    call s:adjust_numbered_list(child_item, 0, 0)
    call s:update_state(parent_item)
    startinsert
    return
  elseif has_bp == 1 && a:just_mrkr == 4
    "list is finished, but cursor goes to next line
    let item = s:get_item(lnum)
    let neighbor_item = s:get_a_neighbor_item(item)
    let child_item = s:get_first_child(item)
    let parent_item = (item.cb != '') ? s:get_parent(item) : s:empty_item()
    normal! "_cc
    call s:adjust_numbered_list(neighbor_item, 0, 0)
    call s:adjust_numbered_list(child_item, 0, 0)
    call s:update_state(parent_item)
    startinsert
    return
  elseif has_bp == 1 && a:just_mrkr == 5
    "successively decrease level
    if s:get_level(lnum) > 0
      call s:change_level(lnum, lnum, 'decrease', 0)
      startinsert!
    else
      let item = s:get_item(lnum)
      let neighbor_item = s:get_a_neighbor_item(item)
      let child_item = s:get_first_child(item)
      let parent_item = (item.cb != '') ? s:get_parent(item) : s:empty_item()
      normal! "_cc
      call s:adjust_numbered_list(neighbor_item, 0, 0)
      call s:adjust_numbered_list(child_item, 0, 0)
      call s:update_state(parent_item)
      startinsert
    endif
    return
  endif


  let cur_col = col("$") - col("'^")


  if has_bp == 0 && (a:normal == 2 || a:normal == 3)
    normal! gi
    call s:create_marker(lnum+1)
  endif

  if has_bp == 0
    normal! gix
  endif

  "make multilined list item
  if (has_bp == 2 && (a:normal == 2 || a:normal == 4 || (cur_col == 0 && getline(lnum) =~ '\s$'))) " || (cur_item.lnum < s:get_last_line_of_item(cur_item))
    normal! gi
    let prev_line = s:get_corresponding_item(s:get_prev_line(lnum+1))
    call s:indent_multiline(prev_line, lnum+1)

    "the ultimate feature of this script: make new marker on <CR>
  elseif (has_bp == 2 && (a:normal == 1 || a:normal == 3)) || (has_bp == 1 && a:just_mrkr == 1)
    normal! gi
    call s:clone_marker_from_to(lnum, lnum+1)
    "tiny sweet extra feature: indent next line if current line ends with :
    if getline(lnum) =~ ':$'
      call s:change_level(lnum+1, lnum+1, 'increase', 0)
    endif
  endif


  call cursor(lnum+1, col("$") - cur_col)
  if cur_col == 0
    startinsert!
  else
    startinsert
  endif

endfunction "}}}

"creates a list item in the current line or removes it
function! vimwiki#lst#toggle_list_item() "{{{
  let cur_col_from_eol = col("$") - col("'^")
  let cur_item = s:get_item(line('.'))

  if cur_item.type == 0
    call s:create_marker(cur_item.lnum)
  else
    let prev_item = s:get_prev_list_item(cur_item, 1)
    if prev_item.type == 0
      let prev_item = s:get_corresponding_item(s:get_prev_line(cur_item.lnum))
    endif
    let cur_item = s:remove_mrkr(cur_item)
    let adjust_prev_item = (prev_item.type == 2 && s:get_level(cur_item.lnum) <= s:get_level(prev_item.lnum)) ? 1 : 0
    call s:indent_multiline(prev_item, cur_item.lnum)
    if adjust_prev_item
      call s:adjust_numbered_list_below(prev_item, 0)
    endif
  endif

  "set cursor position s.t. it's on the same char as before
  let new_cur_col = col("$") - cur_col_from_eol
  call cursor(cur_item.lnum, new_cur_col >= 1 ? new_cur_col : 1)

  if cur_col_from_eol == 0 || getline(cur_item.lnum) =~ '^\s*$'
    startinsert!
  else
    startinsert
  endif
endfunction "}}}

function! vimwiki#lst#default_symbol() "{{{
  return g:vimwiki_list_markers[0]
endfunction "}}}

function! vimwiki#lst#get_list_margin() "{{{
  if VimwikiGet('list_margin') < 0
    return &sw
  else
    return VimwikiGet('list_margin')
  endif
endfunction "}}}

function! vimwiki#lst#get_list_item_rx(with_cb) "{{{
  let rx_without_cb = '^\s*\%(\('.g:vimwiki_rxListBullet.'\)\|\('.g:vimwiki_rxListNumber.'\)\)'
  if a:with_cb
    return rx_without_cb . '\s\+\%(\[\(['.join(g:vimwiki_listsyms, '').']\)\]\s\)\?'
  else
    return rx_without_cb . '\s'
  endif
endfunction "}}}

