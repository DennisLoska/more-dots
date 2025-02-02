#!/bin/sh

SESSION_NAME="garden"

tmux new-session -d -s $SESSION_NAME -n "neovim"
tmux send-keys -t $SESSION_NAME:0 "cd $PWD" C-m
tmux send-keys -t $SESSION_NAME:0 "nvim" C-m

tmux new-window -t $SESSION_NAME:1 -n "process"
tmux send-keys -t $SESSION_NAME:1 "cd $PWD" C-m

tmux new-window -t $SESSION_NAME:2 -n "terminal"
tmux send-keys -t $SESSION_NAME:2 "cd $PWD" C-m

tmux attach-session -t $SESSION_NAME:0
