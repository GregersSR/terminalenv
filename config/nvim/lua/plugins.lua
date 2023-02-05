-- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Only required if you have packer configured as `opt`
vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'
  use {
  'mrcjkb/haskell-tools.nvim',
  requires = {
    'neovim/nvim-lspconfig',
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim', -- optional
  },
  -- tag = 'x.y.z' -- [^1]
}
end)

