set smartindent
set tabstop=4
set shiftwidth=4
set expandtab

call pathogen#incubate()
call pathogen#helptags()

execute pathogen#infect()
syntax on
filetype plugin indent on

autocmd FileType html,htmldjango,jinjahtml,eruby,mako let b:closetag_html_style=1
autocmd FileType html,xhtml,xml,htmldjango,jinjahtml,eruby,mako source ~/.vim/bundle/closetag/plugin/closetag.vim

" Sidebar/Edit window selection
nnoremap <silent> go :call MCB_sidebarAction(0)<CR>
nnoremap <silent> ge :call MCB_sidebarAction(-2)<CR>

" Taglist
nnoremap <silent> gt :call MCB_sidebarAction(1)<CR>
if ( !&diff )
    let g:Tlist_Auto_Open      = 1
endif
let g:Tlist_Show_One_File      = 1
let g:Tlist_Compact_Format     = 1
let g:Tlist_Enable_Fold_Column = 0
let g:Tlist_Exit_OnlyWindow    = 1

" Buflist
nnoremap <silent> gb :call MCB_sidebarAction(2)<CR>
let g:BufList_Hide = 0

" Project
nnoremap <silent> gp :call MCB_sidebarAction(3)<CR>
let g:proj_flags            = 'imstST'
let g:proj_window_width     = 30
let g:proj_window_increment = 40

