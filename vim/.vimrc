" Disable vi-compatibility nonsense
set nocompatible


" ==== Style ===================================================================

    " Set the colorscheme to molokai
    colorscheme molokai

    " Set the colorscheme to solarized
    " colorscheme solarized
    " let g:solarized_termcolors=256
    " set background=dark

    " Enable the highlight on the cursor's current line
    set cursorline

    " Enable line numbers
    set number

    " Turn syntax highlighting on
    syntax on

    " Display rule at the bottom
    set ruler

    " Set the maximum line width to 128
    set textwidth=128

" ==============================================================================


" ==== Plugins =================================================================

    " Enable Pathogen and load plugins
    execute pathogen#infect()

    " vim-airline options
    " Use powerline fonts for the powerline icons
    let g:airline_powerline_fonts=1
    " Always display the status bar
    set laststatus=2

    " vim-airline-themes options
    " Set the airline theme to wombat
    let g:airline_theme='wombat'

" ==============================================================================

" ==== Whitespace  =============================================================

    " Before writing to buffer (i.e. saving file), remove all trailing whitespace
    autocmd BufWritePre * %s/\s\+$//e

    " Indent according to previous line
    set autoindent

    " Use 4-spaces instead of tab
    set expandtab
    set shiftwidth=4

    " Set the tab's width to 4
    set tabstop=4

    " Do not replace/use 4-spaces over tab in Makefiles
    autocmd FileType make set noexpandtab

    " Display whitespace characters, specifically tab and trailing whitespace
    set list
    set listchars=tab:>-,trail:~

    " Enable expected backspace behavior
    set backspace=eol,indent,start

" ==============================================================================


