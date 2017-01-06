# Install bash configurations (.bash_profile, .bash_prompt, and .bashrc)
for $file in bash{_profile,_prompt,rc}; do
    cp bash/$file ~/.$file
done;

# Install tmux configurations
cp tmux/tmux.conf ~/.tmux.conf

# Install Vim configurations
cp vim/vimrc ~/.vimrc

# Install Vim plugins
cp -fR vim/vim/ ~/.vim

