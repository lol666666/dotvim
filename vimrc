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


