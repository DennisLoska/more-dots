#!/bin/sh

SESSION_NAME="garden"
PROJECT=$1

tmux new-session -d -s $SESSION_NAME -n "neovim"
tmux send-keys -t $SESSION_NAME:1 "cd ~/work/$PROJECT" C-m
tmux send-keys -t $SESSION_NAME:1 "nvim" C-m

tmux new-window -t $SESSION_NAME:2 -n "process"
tmux send-keys -t $SESSION_NAME:2 "cd ~/work/$PROJECT" C-m
tmux send-keys -t $SESSION_NAME:2 "clear" C-m

tmux new-window -t $SESSION_NAME:3 -n "terminal"
tmux send-keys -t $SESSION_NAME:3 "cd ~/work/$PROJECT" C-m
tmux send-keys -t $SESSION_NAME:3 "clear" C-m

tmux attach-session -t $SESSION_NAME:1
