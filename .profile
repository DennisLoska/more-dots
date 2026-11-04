# ~/.profile: executed by the command interpreter for login shells.
# Keeps one source for both machines: secrets stay in ~/.zshrc, not here.
# macOS (denniss-macbook-pro): RVM + LM Studio CLI paths.
# Linux (flux): stock Debian-style defaults.

if [ "$(uname -s)" = "Darwin" ]; then
	# RVM for scripting
	export PATH="$PATH:$HOME/.rvm/bin"
	[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

	# LM Studio CLI (lms)
	export PATH="$PATH:/Users/dennis/.lmstudio/bin"
else
	# ~/.profile defaults: not read by bash(1) if ~/.bash_profile or ~/.bash_login exists.
	# the default umask is set in /etc/profile; for ssh logins configure libpam-umask.
	#umask 022

	# if running bash, include .bashrc if it exists
	if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
		. "$HOME/.bashrc"
	fi

	# user private bin
	if [ -d "$HOME/bin" ]; then
		PATH="$HOME/bin:$PATH"
	fi

	# private local bin
	if [ -d "$HOME/.local/bin" ]; then
		PATH="$HOME/.local/bin:$PATH"
	fi
fi
