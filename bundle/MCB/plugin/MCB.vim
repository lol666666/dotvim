"   File: MCB.vim (Mikey Code Browse)
" Author: Michael Sullivan

"-------------------------------------------------------------------------------

let s:gHistPath = ( $HOME . '/.mcb_history' )

"--------------------------------------

" Give us a chance to skip the plugin.
if exists('g:loaded_MCB')
    finish
endif
let g:loaded_MCB = 1

"--------------------------------------

" These are the main entry points.
command! -nargs=? DD call s:MCB_lookup( 'd', <q-args> )
command! -nargs=? XX call s:MCB_lookup( 'x', <q-args> )
command! -nargs=? BB call s:MCB_bookmark( <q-args> )
command! -nargs=? RR call s:MCB_RmMatchingStrFromBuf( <q-args> )

command! MCBHist             call s:MCB_openHist()
command! MCBPrev             call s:MCB_goPrev()
command! MCBNext             call s:MCB_goNext()
command! MCBGoto             call   MCB_goto()
command! MCBSudoWrite silent call s:MCB_sudoWrite()
command! MCBFoldWord         call   MCB_foldWordToggle()
command! MCBRmC              call s:MCB_RmC4LogNoise()
command! MCBRmE              call s:MCB_RmE6LogNoise()

"-------------------------------------------------------------------------------

" If the MCB_setSidebarMappings() function hasn't already been defined (in your
" .vimrc), then define it here.  This permits you to override the definition of
" this function in your .vimrc and adjust how key mappings are handled in the
" sidebar windows based on the mappings you have chosen for your use
try
    function MCB_setSidebarMappings()
        return
    endfunction
catch
endtry

"--------------------------------------

function MCB_setupDiff()
    " Language syntax creates visual clutter in a diff; turn it off.
    syntax off

    " Setup mappings.
    nnoremap <silent> <F1> :tabprev<CR>:2wincmd w<CR>
    nnoremap <silent> <F2> :tabnext<CR>:2wincmd w<CR>
    nnoremap <silent> <F3> [czz
    nnoremap <silent> <F4> ]czz

    silent tabfirst
    2wincmd w
endfunction

"--------------------------------------

" Diff window glue
if ( &diff )
    " If you quit one diff window, both should close.
    autocmd BufEnter * nested call s:MCB_diffExitOnlyWin()
    function s:MCB_diffExitOnlyWin()
        if ( ( winnr('$') == 1 ) && ( &diff == 1 ) )
            quit
        endif
    endfunction
    
    call MCB_setupDiff()
endif

"--------------------------------------

" Quickfix window glue: If it's the last window, quit.
autocmd BufEnter * nested call s:MCB_quickfixExitOnlyWin()

function s:MCB_quickfixExitOnlyWin()
    if ( ( winnr('$') == 2 ) && ( winbufnr(2) == s:MCB_getQuickfixBufNum() ) )
        quit
    endif
endfunction

"-------------------------------------------------------------------------------

function s:MCB_sudoWrite()
    write !sudo tee "%" >/dev/null    
endfunction

"--------------------------------------

function s:MCB_openFold()
    silent! foldclose!
    silent! normal! mzkzj
    silent! foldopen!
    silent! normal! 'z
    silent normal! zz
endfunction

"--------------------------------------

function s:MCB_recordHistory( aPath, aLine, aComment )
    if ( bufexists(s:gHistPath) )
        let vHistBufNum = bufnr(s:gHistPath)
        silent execute 'buffer ' . vHistBufNum
        if ( has('win32') )
            let aPath = substitute( a:aPath, '\\', '/', 'g' )
            let aPath = substitute( a:aPath, '\v^([a-zA-Z]):/', '/\L\1/', '' )
        endif
        call append( 0, a:aPath . ':' . a:aLine . ':' . a:aComment )
        call setpos( '.', [ 0, 1, 1, 0 ] )
        silent write
    endif
endfunction

"--------------------------------------

" Setup and open the history buffer.
function s:MCB_openHist()
    if ( v:servername != '' )
        let s:gHistPath = ( $HOME . '/.mcb_history_' . v:servername )
    else
        let s:gHistPath = ( $HOME . '/.mcb_history' )
    endif

    " Open.
    if ( bufexists(s:gHistPath) )
        let vHistBufNum = bufnr(s:gHistPath)
        silent execute 'buffer ' . vHistBufNum
        set nobuflisted
        set nowrap
    else
        silent execute 'edit ' . s:gHistPath
        set nobuflisted
        set nowrap
    endif

    " Syntax Hiliting.
    syntax region MCB_SYN_histLine        keepend excludenl start="\v^/" end="\v:$" contains=MCB_SYN_histPathFile,MCB_SYN_histGotoSym,MCB_SYN_histBookmarkSym
    syntax match  MCB_SYN_histPathFile    "\v/[^/:]+:"hs=s+1,he=e-1 contained
    syntax match  MCB_SYN_histGotoSym     "\v:(DREF: |XREF: |Fold: ).+$"ms=s+7,hs=s+7 contained
    syntax match  MCB_SYN_histBookmarkSym "\v:Bookmark: .+$"ms=s+11,hs=s+11 contained

    " Mappings.
    nnoremap <silent> <buffer> <CR> :call MCB_goto()<CR>
endfunction

"--------------------------------------

" Do an X/DREF and update the history.
function s:MCB_lookup( aLookupType, aSym )
    let vSym = a:aSym
    if ( vSym == '' )
        let vSym = expand('<cword>')
    endif

    " Before switching to any other buffers, make a note of what directory
    " the file we're editing is in so we can do the lookup relative to that
    " directory.
    let vHereDir = expand('%:p:h')

    let vEscSym = fnameescape(vSym)
    let vBufName   = ''
    let vBookmark  = ''
    let vCmdName   = ''
    if     ( a:aLookupType == 'x' )
        let vBufName  = 'XREF: ' . vEscSym
        let vBookmark = 'XREF Bookmark: ' . vEscSym
        let vCmdName  = 'xref'
    elseif ( a:aLookupType == 'd' )
        let vBufName  = 'DREF: ' . vEscSym
        let vBookmark = 'DREF Bookmark: ' . vEscSym
        let vCmdName  = 'dref'
    elseif ( a:aLookupType == 'f' )
        let vBufName  = 'FREF: ' . vEscSym
        let vBookmark = 'FREF Bookmark: ' . vEscSym
        let vCmdName  = 'fref'
    else
        echomsg 'Unknown lookup type: ' . a:aLookupType
        return
    endif
    let vEscBufName  = fnameescape(vBufName)
    let vIsBufUsable = 0
    let vIsBufEmpty  = 1

    " If the buffer exists, find out if it's empty.
    if ( bufexists(vBufName) && buflisted(vBufName) )
        let vIsBufUsable = 1
        let vBufLineList = getbufline( bufnr(vBufName), 1, '$' )
        let vIsBufEmpty  = ( len(vBufLineList) <= 1 )
    endif

    " If the buffer exists and is not empty, we're done.
    if ( vIsBufUsable && !vIsBufEmpty )
        " Record where we are in the history.
        if ( ( &buftype != 'nofile' ) && bufexists(s:gHistPath) )
            let vHerePath = expand('%:p')
            let vHereLine = line('.')
            call s:MCB_recordHistory( vHerePath, vHereLine, vBookmark )
        endif

        " Go.
        execute 'buffer ' . vEscBufName
        setlocal buflisted
        return
    endif

    " Do the lookup.
    silent execute 'cd ' . vHereDir
    let vCmd = ( vCmdName . ' ' . vEscSym )
    echo vCmd . '...'
    let vOut = system(vCmd)
    redraw
    echo ''
    redraw
    if ( vOut == '' )
        echomsg vCmd . ': Symbol not found'
        return
    elseif ( vOut =~ '\v^Error: ' )
        let vOut = substitute( vOut, '\v\r?\n', '', 'g' )
        echomsg vCmd . ': ' . vOut
        return
    endif
    
    " Is this an idutils DREF (the syntax is different)?
    let vIsIdutilsDref = 0
    if ( strpart( vOut, 0, 1 ) != '/' )
        let vIsIdutilsDref = 1
    endif

    " Record where we are in the history.
    if ( ( &buftype != 'nofile' ) && bufexists(s:gHistPath) )
        let vHerePath = expand('%:p')
        let vHereLine = line('.')
        call s:MCB_recordHistory( vHerePath, vHereLine, vBookmark )
    endif

    " Figure out how many results were returned.
    let vOutLineList = split( vOut, '\n' )
    if ( vIsIdutilsDref )
        let vIsOneResult = ( len(vOutLineList) == 1 )
    else
        let vIsOneResult = ( len(vOutLineList) == 2 )
    endif

    " If one result was returned, open it directly.  Otherwise, put the results
    " in a new window.
    if ( vIsOneResult )
        " Extract the path and line number.
        if ( vIsIdutilsDref )
            let vGotoPath = substitute( get( split( get( vOutLineList, 0 ), ':' ), 1 ), '\v^ +([^ ]+) +Type$', '\1', '' )
            let vGotoLine = substitute( get( split( get( vOutLineList, 0 ), ':' ), 0 ), '\v^ *([0-9]+)$',      '\1', '' ) + 0
        else
            let vGotoPath = get( split( get( vOutLineList, 0 ), ':' ), 0 )
            let vGotoLine = substitute( get( split( get( vOutLineList, 1 ), ':' ), 0 ), '\v^ *([0-9]+)$',      '\1', '' ) + 0
        endif

        " Record where we're going in the history.
        call s:MCB_recordHistory( vGotoPath, vGotoLine, vBufName )
        
        " Open the file and jump to the proper line.
        if ( has('win32') )
            let vGotoPath = substitute( vGotoPath, '\v^/([a-zA-Z])/', '\1:/', '' )
            let vGotoPath = substitute( vGotoPath, '/', '\\', 'g' )
        endif
        silent execute 'edit ' . vGotoPath
        silent execute 'normal! ' . vGotoLine . 'gg'
        call s:MCB_openFold()
    else
        " Setup buffer.
        if ( vIsBufUsable )
            execute 'buffer ' . vEscBufName
            setlocal buflisted
        else
            enew
            silent execute 'file ' . vEscBufName
        endif
        setlocal modifiable
        setlocal buftype=nofile
        setlocal bufhidden=hide
        setlocal noswapfile
        setlocal nowrap
        setlocal relativenumber
        setlocal filetype=cpp

        " Insert content.
        call setline( 1, vOutLineList )
        
        " Syntax Hiliting.
        if ( vIsIdutilsDref )
            syntax region MCB_SYN_lookupLine     keepend excludenl start="\v^" end="\v$"       contains=MCB_SYN_lookupPath,MCB_SYN_lookupSym
            syntax region MCB_SYN_lookupPath     keepend excludenl start="\v/" end="\v "me=e-1 contains=MCB_SYN_lookupPathFile
            syntax match  MCB_SYN_lookupPathFile "\v/[^/ ]+ "hs=s+1,he=e-1 contained
            syntax match  MCB_SYN_lookupSym      "\vType: .*$"hs=s+6       contained
        else
            syntax region MCB_SYN_lookupPathU     keepend excludenl start="\v^/" end="\v:$" contains=MCB_SYN_lookupPathFileU
            syntax match  MCB_SYN_lookupPathFileU "\v/[^/:]+:"hs=s+1,he=e-1 contained
            syntax match  MCB_SYN_lookupLineNum   "\v^ *[0-9]+:"
        endif

        " Mappings.
        nnoremap <silent> <buffer> <CR> :call MCB_goto()<CR>
    endif
endfunction

"--------------------------------------

" Goto the selected reference in the history or X/DREF buffers.
function MCB_goto()
    let vHistBufNum = bufnr(s:gHistPath)

    " Goto in the history is very easy (except for Windows gvim).
    if ( bufnr('%') == vHistBufNum )
        if ( has('win32') )
            let vLine = getline(line('.'))
            let vGotoPath = substitute( vLine, '\v^([^:]+):.*$', '\1', '' )
            let vGotoLine = substitute( vLine, '\v^[^:]+:([0-9]+):.*$', '\1', '' ) + 0
            
            if ( has('win32') )
                let vGotoPath = substitute( vGotoPath, '\v^/([a-zA-Z])/', '\1:/', '' )
                let vGotoPath = substitute( vGotoPath, '/', '\\', 'g' )
            endif
            silent execute 'edit ' . vGotoPath
            silent execute 'normal! ' . vGotoLine . 'gg'
        else
            call setpos( '.', [ 0, line('.'), 1, 0 ] )
            silent execute 'normal gF'
        endif
        call s:MCB_openFold()
        return
    endif

    " If get this far, we're in an X/Dref buffer.

    " Is this an idutils DREF (the syntax is different)?
    let vIsIdutilsDref = 0
    let vLine          = getline(line('.'))
    if ( stridx( vLine, '   Type: ' ) != -1 )
        let vIsIdutilsDref = 1
    endif

    " Get path of reference.
    if ( vIsIdutilsDref )
        let vGotoPath = substitute( get( split( vLine, ':' ), 1 ), '\v^ +([^ ]+) +Type$', '\1', '' )
    else
        let vOrigPos = getpos('.')
        call setpos( '.', [ vOrigPos[0], vOrigPos[1], vOrigPos[2]+1, vOrigPos[3] ] )
        let vPathLoc = search( "^/", 'bnW' )
        call setpos( '.', vOrigPos )
        if ( vPathLoc == 0 )
            echomsg "Couldn\'t locate path of file."
            return
        endif
        let vGotoPath = substitute( getline(vPathLoc), '\v^(.*):$', '\1', '' )
    endif

    " Get line number of reference.
    if ( vIsIdutilsDref )
        let vGotoLine = substitute( get( split( vLine, ':' ), 0 ), '\v^ *([0-9]+)$',   '\1', '' ) + 0
    else
        let vGotoLine = substitute( getline(line('.')), '\v^ *([0-9]+):', '\1', '' ) + 0
    endif

    " Get the reference (it's the name of the file we're in)
    let vHereRef = expand('%')
    
    " Record where we're going in the history.
    call s:MCB_recordHistory( vGotoPath, vGotoLine, vHereRef )
    
    " Open the file and jump to the proper line.
    if ( has('win32') )
        let vGotoPath = substitute( vGotoPath, '\v^/([a-zA-Z])/', '\1:/', '' )
        let vGotoPath = substitute( vGotoPath, '/', '\\', 'g' )
    endif
    silent execute 'edit ' . vGotoPath
    silent execute 'normal! ' . vGotoLine . 'gg'
    call s:MCB_openFold()
endfunction

"--------------------------------------

function s:MCB_getBufList()
    redir => vBufList
    silent! ls
    redir END

    return vBufList
endfunction

"--------------------------------------

function s:MCB_getQuickfixBufNum()
    let vResult = -1

    let vLsOut  = s:MCB_getBufList()
    let vLsList = split( vLsOut, '\n' )
    let vQfLine = filter( vLsList, 'v:val =~ "\\[Quickfix List\\]"' )
    if ( len(vQfLine) == 1 )
        let vBufNum = map( vQfLine, 'str2nr(matchstr( v:val, "\\d\\+" ))' )[0]
        if ( vBufNum != '' )
            let vResult = vBufNum
        endif
    endif
    
    return vResult
endfunction

"--------------------------------------

function s:MCB_goPrev()
    if ( s:MCB_getQuickfixBufNum() != -1 )
        try
            cprevious
        catch
        endtry
        silent normal! zz
    elseif ( bufexists(s:gHistPath) )
        let vPrevBufNum = bufnr('%')
        let vHistBufNum = bufnr(s:gHistPath)
        silent execute 'buffer ' . vHistBufNum
        let vHereLine = line('.')
        if ( vHereLine != line('$') )
            call setpos( '.', [ 0, vHereLine+1, 1, 0 ] )
        endif
        call MCB_goto()
    else
        execute 'normal! <C-o>'
    endif
endfunction

"--------------------------------------

function s:MCB_goNext()
    if ( s:MCB_getQuickfixBufNum() != -1 )
        try
            cnext
        catch
        endtry
        silent normal! zz
    elseif ( bufexists(s:gHistPath) )
        let vPrevBufNum = bufnr('%')
        let vHistBufNum = bufnr(s:gHistPath)
        silent execute 'buffer ' . vHistBufNum
        let vHereLine = line('.')
        if ( vHereLine != 1 )
            call setpos( '.', [ 0, vHereLine-1, 1, 0 ] )
        endif
        call MCB_goto()
    else
        execute 'normal! <C-i>'
    endif
endfunction

"--------------------------------------

function s:MCB_bookmark( aSym )
    if ( ( &buftype != 'nofile' ) && bufexists(s:gHistPath) )
        let vSym = a:aSym
        if ( vSym == '' )
            let vSym = expand('<cword>')
        endif

        let vPrevBufNum = bufnr('%')
        let vHerePath   = expand('%:p')
        let vHereLine   = line('.')
        let vWinSave    = winsaveview()

        call s:MCB_recordHistory( vHerePath, vHereLine, 'Bookmark: ' . vSym )

        silent execute 'buffer ' . vPrevBufNum
        call winrestview(vWinSave)
    endif
endfunction

"--------------------------------------

" Sidebar window glue: Window manager for TagList, BufList, and Project
" plugins to share the leftmost window (the sidebar window).  The behavior
" is controlled by the aAction argument:
" -  1: Focus on sidebar window, show TagList.
" -  2: Focus on sidebar window, show BufList.
" -  3: Focus on sidebar window, show Project.
" -  0: Switch focus between sidebar window and edit window.
" - -1: Focus on sidebar window, no buffer change.
" - -2: Focus on edit window,    no buffer change.
let g:MCB_sidebarWinNum         = 1
let g:MCB_editWinNum            = g:MCB_sidebarWinNum+1
let g:MCB_sidebarVisPersonality = -1
let g:MCB_sidebarWinSize        = 30
let g:MCB_sidebarWinSizeBig     = 70
function MCB_sidebarAction( aAction )
    let vMCB_curWinNum    = winnr()
    let vMCB_sidebarIsVis = ( ( winnr('$') > 1 ) && ( g:MCB_sidebarVisPersonality > 0 ) )
    let vMCB_sidebarIsAct = ( vMCB_sidebarIsVis && ( vMCB_curWinNum == g:MCB_sidebarWinNum ) )

    " Special Shortcuts
    " -  0: Toggle
    " - -1: Make sidebar window active
    " - -2: Make edit window active
    if (     a:aAction ==  0 )
        silent execute ( vMCB_sidebarIsAct ? g:MCB_editWinNum : g:MCB_sidebarWinNum ) . 'wincmd w'
        return
    elseif ( a:aAction == -1 )
        silent execute g:MCB_sidebarWinNum . 'wincmd w'
        return
    elseif ( a:aAction == -2 )
        silent execute g:MCB_editWinNum . 'wincmd w'
        return
    endif

    " If the command line is open, we're stuck.  Do nothing.
    if ( bufname(bufnr('%')) == '[Command Line]' )
        return
    endif

    " If we're in diff mode, don't interfere.
    if ( &diff )
        return
    endif

    " If there are too many windows, we can't effectively manage things.
    " Do nothing.
    "if ( winnr('$') > 2 )
    "    return
    "endif

    " Tailor our personality.
    let vMCB_bufToSwitchTo = -1
    if (     a:aAction == 1 )
        let vMCB_bufToSwitchTo = g:MCB_tagBufNum
    elseif ( a:aAction == 2 )
        let vMCB_bufToSwitchTo = g:MCB_bufBufNum
    elseif ( a:aAction == 3 )
        let vMCB_bufToSwitchTo = g:MCB_projBufNum
    else
        echomsg 'Unexpected personality: ' . a:aAction
        return
    endif

    " Make sure the window is visible and active.
    if ( !vMCB_sidebarIsVis )
        topleft vertical split
    else
        silent execute g:MCB_sidebarWinNum . 'wincmd w'
    endif

    " Show the window content.
    if ( bufexists(vMCB_bufToSwitchTo) )
        silent execute "buffer " . vMCB_bufToSwitchTo
        if (     a:aAction == 1 )
            silent execute g:MCB_editWinNum . 'wincmd w'
            call Tlist_Window_Open()
            silent execute g:MCB_sidebarWinNum . 'wincmd w'
        elseif ( a:aAction == 2 )
            call BufList_Update()
        elseif ( a:aAction == 3 )
        endif
    else
        if (     a:aAction == 1 )
            silent execute g:MCB_editWinNum . 'wincmd w'
            call Tlist_Window_Open()
            silent execute g:MCB_sidebarWinNum . 'wincmd w'
        elseif ( a:aAction == 2 )
            call BufList_CreatePanel()
            call BufList_Update()
        elseif ( a:aAction == 3 )
            Project
        endif
    endif
    let g:MCB_sidebarVisPersonality = a:aAction

    " Set the width of the window.
    let vMCB_NumCols = 30
    silent execute "vertical resize " . vMCB_NumCols
endfunction

"--------------------------------------

function MCB_foldWordToggle()
    if !exists('b:IsFoldWord')
        let b:IsFoldWord = 0
    endif

    if ( b:IsFoldWord == 0 )
        " Make a note of where we are.
        let b:vFoldBufNumOrig = bufnr('%')
        let b:vFoldLineOrig   = line('.')
        let b:vFoldWordOrig   = expand('<cword>')
        let b:vFoldSearchOrig = @/

        " Fold.
        silent execute 'let @/ = "' . b:vFoldWordOrig . '"'
        silent execute 'match incsearch /' . b:vFoldWordOrig . '/'
        silent! execute 'Fw'
        let b:IsFoldWord = 1
    else
        " Unfold.
        silent! execute 'Fe'
        silent execute 'match none'
        silent execute "let @/ = '" . b:vFoldSearchOrig . "'"
        nohlsearch
        let b:IsFoldWord = 0

        " If the line number changed, record where we were and then where we
        " went in the history.
        let vHereLine       = line('.')
        let vFoldBufNumOrig = b:vFoldBufNumOrig
        if ( b:vFoldLineOrig != vHereLine )
            let vHerePath     = expand('%:p')
            let vFoldWordOrig = b:vFoldWordOrig
            call s:MCB_recordHistory( vHerePath, b:vFoldLineOrig, 'Fold Bookmark: ' . vFoldWordOrig )
            call s:MCB_recordHistory( vHerePath, vHereLine,       'Fold: '          . vFoldWordOrig )
        endif
        silent execute 'buffer ' . vFoldBufNumOrig
    endif
endfunction

"--------------------------------------

function s:MCB_RmMatchingStrFromBuf( aStr )
    let vStr = a:aStr
    if ( vStr == '' )
        let vStr = expand('<cword>')
    endif

    " Create a regex that matches similar lines.  Don't forget to escape any
    " special characters.
    let vRegex = substitute( vStr,   '\v\.',                     '\\.',              '' )
    let vRegex = substitute( vRegex, '\v\<',                     '\\<',              '' )
    let vRegex = substitute( vRegex, '\v\>',                     '\\>',              '' )
    let vRegex = substitute( vRegex, '\v\(',                     '\\(',              '' )
    let vRegex = substitute( vRegex, '\v\)',                     '\\)',              '' )
    let vRegex = substitute( vRegex, '\v\{',                     '\\{',              '' )
    let vRegex = substitute( vRegex, '\v\}',                     '\\}',              '' )
    let vRegex = substitute( vRegex, '\v\[',                     '\\[',              '' )
    let vRegex = substitute( vRegex, '\v\]',                     '\\]',              '' )
    let vRegex = substitute( vRegex, '\v\^',                     '\\^',              '' )
    let vRegex = substitute( vRegex, '\v\$',                     '\\$',              '' )
    let vRegex = substitute( vRegex, '\v\*',                     '\\*',              '' )
    let vRegex = substitute( vRegex, '\v\+',                     '\\+',              '' )
    let vRegex = substitute( vRegex, '\v\?',                     '\\?',              '' )
    let vRegex = substitute( vRegex, '\v\\\<0x[0-9a-fA-F]+\\\>', '#hexPlaceHolder',  '' )
    let vRegex = substitute( vRegex, '\v[0-9]+',                 '[0-9]+',           '' )
    let vRegex = substitute( vRegex, '#hexPlaceHolder',          '<0x[0-9a-fA-F]+>', '' )

    " Everything is magical.
    let vRegex = '\v' . vRegex

    " Use the generated regex to remove matching lines in the file.
    for vLineIndex in reverse( range(line('$')+1) )
        if ( match( getline(vLineIndex), vRegex ) != -1 )
            silent execute 'normal! ' . vLineIndex . 'gg'
            silent normal! dd
        endif
    endfor
endfunction

"--------------------------------------

function s:MCB_LogSyntaxHiliting()
    syntax match comment   "\v^.*:send all .*$"
    syntax match comment   "\v^.*Memo via CLI:.*$"
    syntax match comment   "\v^.*\<DIAG\>.*$"
    syntax match statement "\v^.*CLI command:.*$"
    syntax match preproc   "\v(Card Secondary State=|desired state=).*$"
    syntax match preproc   "\v^.*(LdrRqstServer|LoadRqstServer).*DIAG.*$"
    syntax match preproc   "\v^.*LdrServer.*DIAG.*$"
    syntax match preproc   "\v<resetType>=[^ :]+"
    syntax match warn      "\v\c^.*<warning>.*$"
    syntax match warn      "\v^.*log messages discarded.*$"
    syntax match warn      "\v\c^.*<bad>.*$"
    syntax match warn      "\v\c^.*<timeout>.*$"
    syntax match error     "\v^Trap Severity=(warning|error).*$"
    syntax match error     "\v\c^.*<exception>.*$"
    syntax match error     "\v\c^.*(<emergency>|<emgy>).*$"
    syntax match error     "\v\c^.*(<critical>|<crit>).*$"
    syntax match error     "\v\c^.*(<alert>|<alrt>).*$"
    syntax match error     "\v\c^.*(<error>|out of frame|<Err>|Invalid Request).*$"
    syntax match error     "\v\c^.*(<fail>|<failed>|<fault>|<failure>).*$"
    syntax match error     "\v\c^.*<fatal>.*$"
    syntax match error     "\v^.*Dump of SystemMtce.*$"
    syntax match error     "\v^.*not in pendingUpdates\."
    syntax match error     "\v^.*attrList is NULL"
    syntax match error     "\vMtcePing Failed"
endfunction

"--------------------------------------

function s:MCB_RmE6LogNoise()
    " Add something here...

    " Syntax Hiliting.
    call s:MCB_LogSyntaxHiliting()
endfunction

"--------------------------------------

function s:MCB_RmC4LogNoise()
    " MTCE Noise.
    call s:MCB_RmMatchingStrFromBuf('addScmAccessAclAttribute() called;ifIndex=')
    call s:MCB_RmMatchingStrFromBuf('BasicMtceTakeevSystemMtceStatus')
    call s:MCB_RmMatchingStrFromBuf('call startSyncUpdate')
    call s:MCB_RmMatchingStrFromBuf('Card Detected Change:')
    call s:MCB_RmMatchingStrFromBuf('Card Duplex Status Change')
    call s:MCB_RmMatchingStrFromBuf('CardMtceCpuStats::collectCpuStats')
    call s:MCB_RmMatchingStrFromBuf('CardMtceFunction::handleCardSetClock')
    call s:MCB_RmMatchingStrFromBuf('CardMtceFunction: InitProgressStatus Change')
    call s:MCB_RmMatchingStrFromBuf('Card Secondary State Change')
    call s:MCB_RmMatchingStrFromBuf('CCR EventMsgManager')
    call s:MCB_RmMatchingStrFromBuf('CCR Gate')
    call s:MCB_RmMatchingStrFromBuf('cntActiveDQoSGates')
    call s:MCB_RmMatchingStrFromBuf('cntRcvdCCRGateAudit')
    call s:MCB_RmMatchingStrFromBuf('cntSentCCRGateAudit')
    call s:MCB_RmMatchingStrFromBuf('cntStdbyDQoSGatesCreated')
    call s:MCB_RmMatchingStrFromBuf('cntStdbyGatesYetToBeVerified')
    call s:MCB_RmMatchingStrFromBuf('Config: RemoteCmPoller::handleDataQueryResponse: GEN configuration complete')
    call s:MCB_RmMatchingStrFromBuf('Config: RemoteCmPoller::setIS SubscriberDataManager is now in service')
    call s:MCB_RmMatchingStrFromBuf('CopsConnectionManager::')
    call s:MCB_RmMatchingStrFromBuf('COPS Master Socket ready on port')
    call s:MCB_RmMatchingStrFromBuf('DAppl::updateCmMibStatus(): M Card CM MIB status data recovery completed')
    call s:MCB_RmMatchingStrFromBuf('DCARDMTCE_MAC_TIMESTAMP_AUDIT')
    call s:MCB_RmMatchingStrFromBuf('DMMAPPL: MacDomain ')
    call s:MCB_RmMatchingStrFromBuf('DMMCardDevicePollMonitor')
    call s:MCB_RmMatchingStrFromBuf('] DMS:')
    call s:MCB_RmMatchingStrFromBuf('Downstream Channel Port Number')
    call s:MCB_RmMatchingStrFromBuf('DRV: EVMON')
    call s:MCB_RmMatchingStrFromBuf('DsDataMgr: Mac Domain Recovery')
    call s:MCB_RmMatchingStrFromBuf('] enable forwarding')
    call s:MCB_RmMatchingStrFromBuf('] enableForwarding')
    call s:MCB_RmMatchingStrFromBuf('Enterprise Specific Trap (cardDplxStatusChange)')
    call s:MCB_RmMatchingStrFromBuf('Enterprise Specific Trap (cardPrStateChange)')
    call s:MCB_RmMatchingStrFromBuf('Enterprise Specific Trap (cardSecStateChange)')
    call s:MCB_RmMatchingStrFromBuf('Enterprise Specific Trap (portPrStateChange)')
    call s:MCB_RmMatchingStrFromBuf('Enterprise Specific Trap (portSecStateChange)')
    call s:MCB_RmMatchingStrFromBuf("EVMON: mv821xx/0: event \\'Link")
    call s:MCB_RmMatchingStrFromBuf('evPortMtceNotificationAck')
    call s:MCB_RmMatchingStrFromBuf("group \\'EthLinkStatusChange\\'")
    call s:MCB_RmMatchingStrFromBuf('handlePortMtceNotification')
    call s:MCB_RmMatchingStrFromBuf('Link Down : Index')
    call s:MCB_RmMatchingStrFromBuf('Link Down Trap (')
    call s:MCB_RmMatchingStrFromBuf('Link Up : Index')
    call s:MCB_RmMatchingStrFromBuf('Mac Domain Id')
    call s:MCB_RmMatchingStrFromBuf('MCardMtceFunction: Clone MCard failed: shutting down remote services')
    call s:MCB_RmMatchingStrFromBuf('MCardMtceFunction: Clone Side Standby:')
    call s:MCB_RmMatchingStrFromBuf('MCardMtceFunction: Mate Fabric Standby:')
    call s:MCB_RmMatchingStrFromBuf('MTCE_TEMP_READ_VALUES')
    call s:MCB_RmMatchingStrFromBuf('MTCE_VCM_READ_VALUES')
    call s:MCB_RmMatchingStrFromBuf('MTCE_VOLTAGE_CONTROLLER_READ_VALUES')
    call s:MCB_RmMatchingStrFromBuf('Port Secondary State')
    call s:MCB_RmMatchingStrFromBuf('PORT Secondary State Change')
    call s:MCB_RmMatchingStrFromBuf('Port Type=dport')
    call s:MCB_RmMatchingStrFromBuf('Port Type=eport1000BaseT')
    call s:MCB_RmMatchingStrFromBuf('Port Type=eport10BaseT')
    call s:MCB_RmMatchingStrFromBuf('Port Type=macport')
    call s:MCB_RmMatchingStrFromBuf('Port Type=uchannel')
    call s:MCB_RmMatchingStrFromBuf('Port Type=uport')
    call s:MCB_RmMatchingStrFromBuf('Primary State Change')
    call s:MCB_RmMatchingStrFromBuf('] PSM:')
    call s:MCB_RmMatchingStrFromBuf('rcmCardMtceStateData')
    call s:MCB_RmMatchingStrFromBuf('SCM Access: configured out-of-band management')
    call s:MCB_RmMatchingStrFromBuf('Secondary State Change')
    call s:MCB_RmMatchingStrFromBuf('send evPortMtceNotification')
    call s:MCB_RmMatchingStrFromBuf('slotsEnabledMask')
    call s:MCB_RmMatchingStrFromBuf('snmpTrapOID.0 cardDetectedChange')
    call s:MCB_RmMatchingStrFromBuf('snmpTrapOID.0 cardDplxStatusChange')
    call s:MCB_RmMatchingStrFromBuf('snmpTrapOID.0 cardPrStateChange')
    call s:MCB_RmMatchingStrFromBuf('snmpTrapOID.0 cardSecStateChange')
    call s:MCB_RmMatchingStrFromBuf('snmpTrapOID.0 linkDown')
    call s:MCB_RmMatchingStrFromBuf('snmpTrapOID.0 linkUp')
    call s:MCB_RmMatchingStrFromBuf('snmpTrapOID.0 portPrStateChange')
    call s:MCB_RmMatchingStrFromBuf('snmpTrapOID.0 portSecStateChange')
    call s:MCB_RmMatchingStrFromBuf('Spisl Crossover to Clone RCM Link')
    call s:MCB_RmMatchingStrFromBuf('SPISL: Spisl Crossover to RCM Link')
    call s:MCB_RmMatchingStrFromBuf('SubscriberDataBackupManager: RecoverSDM:')
    call s:MCB_RmMatchingStrFromBuf('SystemMtceCard::handleDataQueryResponse')
    call s:MCB_RmMatchingStrFromBuf('SystemMtceCard::setCardInitializationTimeout')
    call s:MCB_RmMatchingStrFromBuf('SystemMtceCard::setPortDsPower')
    call s:MCB_RmMatchingStrFromBuf('SystemMtceCard::setPortState')
    call s:MCB_RmMatchingStrFromBuf('SystemMtce::notifyCardStateChange')
    call s:MCB_RmMatchingStrFromBuf('SystemMtce::refreshPortInfo')
    call s:MCB_RmMatchingStrFromBuf('SystemMtce: SelectActiveStandby')
    call s:MCB_RmMatchingStrFromBuf('SystemMtce::sendClockSync')
    call s:MCB_RmMatchingStrFromBuf('SystemMtce::sendSystemMtceStatus')
    call s:MCB_RmMatchingStrFromBuf('time being set')
    call s:MCB_RmMatchingStrFromBuf('Trap Severity=cleared')
    call s:MCB_RmMatchingStrFromBuf('Trap Severity=informational')
    call s:MCB_RmMatchingStrFromBuf('] unpause ForwardingQueue')
    call s:MCB_RmMatchingStrFromBuf('Upstream Channel Port Number')
    call s:MCB_RmMatchingStrFromBuf('Upstream Rcvr Port Number')

    " CLI Command Noise.
    call s:MCB_RmMatchingStrFromBuf(':alias ')
    call s:MCB_RmMatchingStrFromBuf('Authentication request from IP address')
    call s:MCB_RmMatchingStrFromBuf('Card Duplex Status Change')
    call s:MCB_RmMatchingStrFromBuf('config session 1000')
    call s:MCB_RmMatchingStrFromBuf('configure no pagination')
    call s:MCB_RmMatchingStrFromBuf(':enable')
    call s:MCB_RmMatchingStrFromBuf('exc file alias/aliaslist.txt')
    call s:MCB_RmMatchingStrFromBuf('Link Down : Index')
    call s:MCB_RmMatchingStrFromBuf('Local password authentication successful for user c4')
    call s:MCB_RmMatchingStrFromBuf('Primary State Change')
    call s:MCB_RmMatchingStrFromBuf('Secondary State Change')

    " A-Link Noise.
    call s:MCB_RmMatchingStrFromBuf('ATLAS: A-link A:')
    call s:MCB_RmMatchingStrFromBuf('ATLAS: A-link B:')
    call s:MCB_RmMatchingStrFromBuf('Generic - ATLAS: Upstream Fabric A FIFO Full')
    call s:MCB_RmMatchingStrFromBuf('Generic - ATLAS: Upstream Fabric B FIFO Full')
    call s:MCB_RmMatchingStrFromBuf('LOCOFOCO: A-link A:')
    call s:MCB_RmMatchingStrFromBuf('LOCOFOCO: A-link B:')

    " Event Noise.
    call s:MCB_RmMatchingStrFromBuf("DRV: EVMON: xspi/0: event \\'MAC Local Fault\\'")
    call s:MCB_RmMatchingStrFromBuf('EventNotConsumed:')
    call s:MCB_RmMatchingStrFromBuf('Xspi 0 Err - XSPI: Calendar State Machine is disabled')

    " NTP Noise.
    call s:MCB_RmMatchingStrFromBuf('NTP :')

    " CM Noise.
    call s:MCB_RmMatchingStrFromBuf(']       CM')
    call s:MCB_RmMatchingStrFromBuf('CM cfg file:')
    call s:MCB_RmMatchingStrFromBuf('CM Config:')
    call s:MCB_RmMatchingStrFromBuf('DHCPv6')
    call s:MCB_RmMatchingStrFromBuf('from previous flap')
    call s:MCB_RmMatchingStrFromBuf('REG aborted no REG-ACK')
    call s:MCB_RmMatchingStrFromBuf('Registered and Baseline Privacy Initialization Complete')
    call s:MCB_RmMatchingStrFromBuf('Registration (2.0) successful')
    call s:MCB_RmMatchingStrFromBuf('registration success')
    call s:MCB_RmMatchingStrFromBuf('SM_RANGING_SAME_CHAN')

    " DMM Noise.
    call s:MCB_RmMatchingStrFromBuf('DMMCABLE: DmmCable: ')
    call s:MCB_RmMatchingStrFromBuf('DMMCABLE: DMMCable: ')

    " Syntax Hiliting.
    call s:MCB_LogSyntaxHiliting()
endfunction

"-------------------------------------------------------------------------------

