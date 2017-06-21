#!/bin/bash

printf "\n" >> /home/ubuntu/.bashrc
echo 'export PS1="\[\e[01;34m\]compute\[\e[0m\]\[\e[01;37m\]:\w\[\e[0m\]\[\e[00;37m\]\n\\$ \[\e[0m\]"' >> /home/ubuntu/.bashrc
printf "\n" >> /home/ubuntu/.bashrc

