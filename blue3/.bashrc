#
# CRIADO POR: SAMIR HANNA VERZA
# CRIADO EM: 20/05/2019
# ATUALIZADO: 20/05/2019
#
#
#
#OLD
# export PS1='\[\033[1;37m\]\t ${debian_chroot:+($debian_chroot)}\[\033[01;33m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[1;33m\]# \[\033[37m\]'
#NEW
#PS1='${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\u\[\033[01;34m\]@\[\033[01;33m\]\h\[\033[01;34m\][\[\033[00m\]\[\033[01;37m\]\w\[\033[01;34m\]]\[\033[01;31m\]\$\[\033[00m\] '
# LAST
PS1='\[\033[1;37m\]\t ${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\u\[\033[01;34m\]@\[\033[01;33m\]\h\[\033[01;34m\][\[\033[00m\]\[\033[01;37m\]\w\[\033[01;34m\]]\[\033[01;33m\]\$\[\033[00m\] '

# ?
source /usr/share/doc/fzf/examples/key-bindings.bash

alias l='ls -alFh --color=auto'
alias vi='vi -C -c "set nocp" -c "syn on"'
alias ..='cd ..'
alias ls='ls --color'
alias lh="ls -aFh -lS --color | grep -v '^d'"
alias grep='grep --color'
alias ip='ip -c'
alias tail='grc tail'
alias ping='grc ping'
alias traceroute='grc traceroute'
alias ps='grc ps'
alias netstat='grc netstat'
alias dig='grc dig'
alias meuip='curl ifconfig.me; echo;'
alias mv='mv -v'
