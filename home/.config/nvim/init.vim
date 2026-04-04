" Load Home Manager's generated glue while keeping init.vim as the entrypoint.
if filereadable(expand('~/.config/nvim/hm-generated.lua'))
  execute 'luafile ' . fnameescape(expand('~/.config/nvim/hm-generated.lua'))
endif

set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
