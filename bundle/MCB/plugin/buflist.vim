"
"	File:    buflist.vim
"	Author:  Fabien Bouleau (syrion AT tiscali DOT fr)
"	Version: 1.7
"
"	Last Modified: March, 6th 2006
"
"	Usage:
"
"	When not in buffer list:
"
"	<F4> to open/access buffer list panel
"	<Leader><Leader>p to mark window as preview window
"
"	When in buffer list:
"
"	h to toggle help
"	p to preview file in preview window
"	d to delete currently selected buffer
"	u to update buffer list
"	n to edit below <F4>
"	N to edit above <F4>
"   x to toggle path display
"   s to toggle sorting
"	<F4> to go back to <F4> window
"	<S-F3> to decrease buffer list width -1
"	<S-F4> to increase buffer list width +1
"	<C-S-F3> to decrease buffer list width -5
"	<C-S-F4> to increase buffer list width +5
"	<CR> to edit file in last window visited before <F4>
"
"	Installation:
"
"	Copy the script into your $VIM/vimfiles/plugin
"

let g:MCB_bufBufNum = -1

let s:buflist_help    = 0
let s:buflist_path    = 0
let s:buflist_sort    = 0

if !exists("g:BufList_Hide")
    let g:BufList_Hide=1
endif

autocmd! * __BufList__
autocmd! * __Buf_List__

autocmd BufEnter __Buf_List__ nested call s:BufList_IamSoLonely()
autocmd BufAdd * call BufList_Update()
autocmd FileType * call BufList_Update()
autocmd CursorHold * call BufList_Update()

nmap <silent> <S-F3> :resize -1<CR>
nmap <silent> <S-F4> :resize +1<CR>
nmap <silent> <C-S-F3> :resize -5<CR>
nmap <silent> <C-S-F4> :resize +5<CR>

function! BufList_Edit()
    let nr = s:BufList_SelectedNr()
    if exists("g:BufList_Hide") && g:BufList_Hide == 1
        hide
    endif
	silent execute g:MCB_editWinNum . "wincmd w"
    silent execute "buffer " . nr
    call MCB_sidebarAction(1)
    call MCB_sidebarAction(-2)
endfunction

function! BufList_EditNew(pos)
	let name = s:BufList_SelectedName()
	silent execute g:MCB_editWinNum . "wincmd w"
	if a:pos == 0
		below new
	else
		above new
	endif
	silent execute "buffer " . fnameescape(name)
endfunction

function! BufList_EditIn(bufnum)
	let name = s:BufList_SelectedName()
	silent execute g:MCB_editWinNum{a:bufnum} . "wincmd w"
	if name != ""
		silent execute "buffer " . fnameescape(name)
	endif
endfunction

function! BufList_ToggleHelp()
	let s:buflist_help = 1 - s:buflist_help
	call BufList_Update()
endfunction

function! BufList_ToggleSort()
	let s:buflist_sort = (s:buflist_sort + 1) % 3
	call BufList_Update()
endfunction

function! BufList_TogglePath()
	let s:buflist_path = (s:buflist_path + 1) % 3
	call BufList_Update()
endfunction

function! BufList_ClosePanel()
	silent execute bufwinnr(g:MCB_bufBufNum) . "wincmd w"
"	let s:buflist_columns = winwidth(0)
	silent execute "vertical resize " . 0
"	silent execute "set columns-=" . s:buflist_columns
	hide
endfunction

function! BufList_Update()
    let vMCB_prevWinNum      = winnr()
    let vMCB_winContainingUs = bufwinnr(g:MCB_bufBufNum)

    " If we're not visible, we're done.
    if ( ( vMCB_winContainingUs == -1 ) || ( winbufnr(g:MCB_sidebarWinNum) != g:MCB_bufBufNum ) )
        return
    endif

    " Don't do any updates while the command line is active.
    if ( bufname('%') == '[Command Line]' )
        return
    endif
    
    silent execute g:MCB_sidebarWinNum . "wincmd w"
 
    let linenr = line(".")

    setlocal modifiable
    silent %delete _

	let ssort = "num"
	let spath = "off"

	if s:buflist_path == 1
		let spath = "bef"
	elseif s:buflist_path == 2
		let spath = "aft"
	endif

	if s:buflist_sort == 1
		let ssort = "nam"
	elseif s:buflist_sort == 2
		let ssort = "ext"
	endif

	if(s:buflist_help == 0)
		let j = 0
	else
		call append(0, "\" h toggle help (on)")
		call append(1, "\" p preview buffer")
		call append(2, "\" d delete buffer")
		call append(3, "\" u update list")
		call append(4, "\" n edit below <F4>")
		call append(5, "\" N edit above <F4>")
		call append(6, "\" x toggle path display (" . spath . ")")
		call append(7, "\" s toggle sorting (" . ssort . ")")
		call append(8, "\" <F4> go back to <F4>")
		call append(9, "\" <S-F3> decrease width -1")
		call append(10, "\" <S-F4> increase width +1")
		call append(11, "\" <C-S-F3> decrease width -5")
		call append(12, "\" <C-S-F4> increase width +5")
		call append(13, "\" <CR> edit file in <F4>")
		call append(14, "\" \\\\n edit file in #n (n from 0 to 9)")
		call append(15, "")
		let j = 16
	endif
	
	let last_buffer = bufnr("$")
	let i = 1
	let s:cnt = 0

	while i <= last_buffer
		if( bufexists(i) && buflisted(i) && ( i != g:MCB_bufBufNum ) && ( getbufvar(i,'&buftype') != 'quickfix' ) )
			let bname = expand("#" . i . ":t")
            if ( has('win32') && (strpart(bname,0,1) == ' ') )
                let bname = expand("#" . i)
            endif
            if ( bname == '' )
                let bname = '[No Name]'
            endif
			let bext  = expand("#" . i . ":e")

			if s:buflist_path == 2
				let pname = " - " . expand("#" . i . ":p:h")
			elseif s:buflist_path == 0
				let pname = ""
			elseif s:buflist_path == 1
				let bname = expand("#" . i . ":p")
                if ( bname == '' )
                    let bname = '[No Name]'
                endif
				let pname = ""
			endif

			let s:buflist_name{s:cnt} = bname . pname
			let s:buflist_num{s:cnt}  = i
			let s:buflist_ext{s:cnt}  = bext
			let s:cnt = s:cnt + 1
		endif
		let i = i + 1
	endwhile

	if(s:buflist_sort > 0)
		call s:BufList_Sort()
	endif

	let i = 0
	while i < s:cnt
        let snr   = s:buflist_num{i} + ""
        let ssp   = "   "
        let ssp   = strpart(ssp, 0, strlen(ssp) - strlen(snr))
        let dirty = ( getbufvar(s:buflist_num{i}, '&modified'  ) ? '+ '    : '  '   )
        let isro  = ( getbufvar(s:buflist_num{i}, '&readonly'  ) ? ' [RO]' : ''     )
        let ismod = ( getbufvar(s:buflist_num{i}, '&modifiable') ? ''      : ' [L]' )
        call append(j, s:buflist_num{i} . ":" . ssp . dirty . s:buflist_name{i} . ismod . isro )
        let i = i + 1
        let j = j + 1
    endwhile

    silent normal! G"_dd
    silent execute "norm " . linenr . "gg"
    if ( &ft != 'vim' )
        set ft=vim
    endif
    setlocal nonumber
    silent! setlocal norelativenumber
    setlocal nomodifiable
    setlocal nowrap
    setlocal statusline=%f%<%=[L=%02l]\ [%P]

    silent execute vMCB_prevWinNum . "wincmd w"
endfunction

function! BufList_Preview()
    if(exists("g:MCB_editWinNum"))
    let nr = winnr()
call BufList_EditIn(10)
    silent execute nr . "wincmd w"
    else
let name = s:BufList_SelectedName()
    if name != ""
    silent execute "pedit " . s:BufList_SelectedName()
    silent execute bufwinnr(g:MCB_bufBufNum) . "wincmd w"
    endif
    endif
    endfunction

function! BufList_Delete_Force()
    let vBufToDel    = s:BufList_SelectedNr()
    let vWinsWithBuf = filter( range( 1, winnr('$') ), 'winbufnr(v:val) == ' . vBufToDel )
    let vOrigWin     = winnr()

    if ( vBufToDel <= 0 )
        return
    endif

    for vCurWin in vWinsWithBuf
        silent execute vCurWin . 'wincmd w'
        let vPrevBuf = bufnr('#')
        if ( ( vPrevBuf > 0 ) && buflisted(vPrevBuf) && ( vPrevBuf != vBufToDel ) )
            silent buffer #
        else
            silent bprevious
        endif
        if ( bufnr('%') == vBufToDel )
            silent enew
        endif
    endfor
    execute vOrigWin . 'wincmd w'

    silent execute 'bdelete! ' . vBufToDel
    call BufList_Update()
endfunction

function! BufList_Delete()
    let vBufToDel    = s:BufList_SelectedNr()
    let vWinsWithBuf = filter( range( 1, winnr('$') ), 'winbufnr(v:val) == ' . vBufToDel )
    let vOrigWin     = winnr()

    if ( vBufToDel <= 0 )
        return
    endif

    for vCurWin in vWinsWithBuf
        silent execute vCurWin . 'wincmd w'
        let vPrevBuf = bufnr('#')
        if ( ( vPrevBuf > 0 ) && buflisted(vPrevBuf) && ( vPrevBuf != vBufToDel ) )
            silent buffer #
        else
            silent bprevious
        endif
        if ( bufnr('%') == vBufToDel )
            silent enew
        endif
    endfor
    execute vOrigWin . 'wincmd w'

    silent execute 'bdelete ' . vBufToDel
    call BufList_Update()
endfunction

function! BufList_Decrease(n)
    if s:buflist_columns > n
    let s:buflist_columns = s:buflist_columns - n
    silent execute "vertical resize " . s:buflist_columns
    endif
    endfunction

function! BufList_Increase(n)
    if s:buflist_columns < 80
    let s:buflist_columns = s:buflist_columns + n
    silent execute "vertical resize " . s:buflist_columns
    endif
    endfunction

function! s:BufList_Sort()
    let f = 0

    while f == 0
    let f = 1
    let j = 0
    while j < s:cnt - 1
    let bufswap = 0
    if s:buflist_sort == 1
    if s:buflist_name{j} > s:buflist_name{j + 1}
    let bufswap = 1
    endif
    elseif s:buflist_sort == 2
    if s:buflist_ext{j} > s:buflist_ext{j + 1}
    let bufswap = 1
    endif
    if s:buflist_ext{j} == s:buflist_ext{j + 1} 
    \  && s:buflist_name{j} > s:buflist_name{j + 1}
    let bufswap = 1
    endif
    endif

    if bufswap == 1
    let tmp = s:buflist_name{j}
    let s:buflist_name{j} = s:buflist_name{j + 1}
    let s:buflist_name{j + 1} = tmp

    let tmp = s:buflist_ext{j}
    let s:buflist_ext{j} = s:buflist_ext{j + 1}
    let s:buflist_ext{j + 1} = tmp

    let n = s:buflist_num{j}
    let s:buflist_num{j} = s:buflist_num{j + 1}
    let s:buflist_num{j + 1} = n

    let f = 0
    endif
    let j = j + 1
    endwhile
    endwhile
    endfunction

function! BufList_CreatePanel()
"    topleft vnew
    enew
    let g:MCB_bufBufNum=bufnr("%")

    let s:buflist_columns = 30
    let s:buflist_help    = 0
    let s:buflist_path    = 0
    let s:buflist_sort    = 0

    silent execute "vertical resize " . s:buflist_columns
    "	silent execute "set columns+=" . s:buflist_columns

    set buftype=nofile
    set noswapfile
    set nobuflisted
    set ft=vim
    silent file __Buf_List__

    nnoremap <buffer> <silent> <space> :silent exec 'vertical resize ' . ( winwidth('.') > g:MCB_sidebarWinSize ? g:MCB_sidebarWinSize : g:MCB_sidebarWinSizeBig )<CR>
    nnoremap <buffer> <silent> p :call BufList_Preview()<CR>
    nnoremap <buffer> <silent> d :call BufList_Delete()<CR>
    nnoremap <buffer> <silent> D :call BufList_Delete_Force()<CR>
    nnoremap <buffer> <silent> u :call BufList_Update()<CR>
    nnoremap <buffer> <silent> x :call BufList_TogglePath()<CR>
    nnoremap <buffer> <silent> s :call BufList_ToggleSort()<CR>
    nnoremap <buffer> <silent> <CR> :call BufList_Edit()<CR>

    "nmap <buffer> <silent> h :call BufList_ToggleHelp()<CR>
    "nmap <buffer> <silent> n :call BufList_EditNew(0)<CR>
    "nmap <buffer> <silent> N :call BufList_EditNew(1)<CR>
    "nmap <silent> <buffer> <F3> :hide<CR>
	"nmap <silent> <buffer> <S-F3> :call BufList_Decrease(1)<CR>
	"nmap <silent> <buffer> <S-F4> :call BufList_Increase(1)<CR>
	"nmap <silent> <buffer> <C-S-F3> :call BufList_Decrease(5)<CR>
	"nmap <silent> <buffer> <C-S-F4> :call BufList_Increase(5)<CR>

	"nmap <silent> <buffer> <Leader><Leader>0 :call BufList_EditIn(0)<CR>
	"nmap <silent> <buffer> <Leader><Leader>1 :call BufList_EditIn(1)<CR>
	"nmap <silent> <buffer> <Leader><Leader>2 :call BufList_EditIn(2)<CR>
	"nmap <silent> <buffer> <Leader><Leader>3 :call BufList_EditIn(3)<CR>
	"nmap <silent> <buffer> <Leader><Leader>4 :call BufList_EditIn(4)<CR>
	"nmap <silent> <buffer> <Leader><Leader>5 :call BufList_EditIn(5)<CR>
	"nmap <silent> <buffer> <Leader><Leader>6 :call BufList_EditIn(6)<CR>
	"nmap <silent> <buffer> <Leader><Leader>7 :call BufList_EditIn(7)<CR>
	"nmap <silent> <buffer> <Leader><Leader>8 :call BufList_EditIn(8)<CR>
	"nmap <silent> <buffer> <Leader><Leader>9 :call BufList_EditIn(9)<CR>
	"nmap <silent> <buffer> <Leader><Leader>p :call BufList_EditIn(10)<CR>

    call MCB_setSidebarMappings()

	return 1
endfunction

function! s:BufList_SelectedNr()
	let line = getline(".")
    let val  = strpart(line, 0, match(getline("."), ":")) + 0
	return val
endfunction

function! s:BufList_SelectedName()
	let nr = s:BufList_SelectedNr()
	return nr > 0 ? bufname(nr) : ""
endfunction

function! s:BufList_IamSoLonely()
	let i = 1
	let n = 0

	while i <= bufnr("$")
		if (bufexists(i) && bufwinnr(i) != -1)
			let n = n + 1
		endif
		let i = i + 1
	endwhile

	if (n == 1)
		quit
	endif
endfunction

" vim:ts=4:sw=4
