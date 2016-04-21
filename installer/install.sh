#!/bin/sh

curl -fsSL https://github.com/elifarley/shellbase/archive/1.0.5.tar.gz \
  | tar --exclude installer --exclude README.md --exclude LICENSE --strip=1 --overwrite -zxvC "$HOME" && \
  sed -i '/^set listchars=tab/d' "$HOME"/.vimrc && \
  curl -fsSL https://raw.githubusercontent.com/seebi/dircolors-solarized/master/dircolors.ansi-dark > "$HOME"/.dircolors && \
  printf "PATH=$PATH\n" >> "$HOME"/.ssh/environment && \
  printf ". '$HOME'/.ssh/environment\npwd" \
    >> "$HOME"/.bashrc

apt-get install -y --no-install-recommends vim exuberant-ctags less locate git && \
apt-get autoremove --purge -y && apt-get clean && rm -rf $RM_ITEMS

# Install Pathogen - https://github.com/tpope/vim-pathogen
mkdir -p "$HOME"/.vim/autoload "$HOME"/.vim/bundle "$HOME"/.vim/colors && \
curl -fsSL https://raw.githubusercontent.com/sjl/badwolf/master/colors/badwolf.vim > "$HOME"/.vim/colors/badwolf.vim && \
curl -fsSL https://raw.githubusercontent.com/jnurmine/Zenburn/master/colors/zenburn.vim > "$HOME"/.vim/colors/zenburn.vim && \
curl -fsSL https://tpo.pe/pathogen.vim > "$HOME"/.vim/autoload/pathogen.vim && \
sed -i '1 i\execute pathogen#infect()\ncall pathogen#helptags()\n' "$HOME"/.vimrc && \
( cd ~/.vim/bundle && mkdir -p csapprox && curl -fsSL https://github.com/godlygeek/csapprox/archive/4.00.tar.gz \
  | tar --strip 1 -zxC csapprox && \
  git clone https://github.com/tpope/vim-obsession && \
  git clone git://github.com/tpope/vim-vinegar.git && \
  git clone https://github.com/ervandew/supertab && \
  git clone https://github.com/ctrlpvim/ctrlp.vim.git && \
  git clone https://github.com/majutsushi/tagbar && \
  git clone git://github.com/tpope/vim-fugitive.git && \
  git clone git://github.com/tpope/vim-rails.git && \
  git clone git://github.com/tpope/vim-bundler.git \
)
