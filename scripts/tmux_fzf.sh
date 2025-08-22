DIR=$(fd --type d . "$HOME" | fzf)
[ -z "$DIR" ] && exit 0

SESSION_NAME=$(basename "$DIR")

tmux new-session -d -c "$DIR" -s "$SESSION_NAME"
tmux switch-client -t "$SESSION_NAME"
