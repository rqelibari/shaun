# Shaun
# by Rezart Qelibari
# https://github.com/rqelibari/shaun
# MIT License

# Originated from `Pure`
# by Sindre Sorhus
# https://github.com/sindresorhus/pure
# MIT License

# For my own and others sanity
# prompt:
# %F => color dict
# %f => reset color
# %~ => current path
# %* => time
# %n => username
# %m => shortname host
# %(?..) => prompt conditional - %(condition.true.false)
# terminal codes:
# \e7   => save cursor position
# \e[2A => move cursor 2 lines up
# \e[1G => go to position 1 in terminal
# \e8   => restore cursor position
# \e[K  => clears everything after the cursor on the current line
# \e[2K => clear everything on the current line


# turns seconds into human readable time
# 165392 => 1d 21h 56m 32s
# https://github.com/sindresorhus/pretty-time-zsh
prompt_shaun_human_time() {
	local tmp=$1
	local days=$(( tmp / 60 / 60 / 24 ))
	local hours=$(( tmp / 60 / 60 % 24 ))
	local minutes=$(( tmp / 60 % 60 ))
	local seconds=$(( tmp % 60 ))
	(( $days > 0 )) && echo -n "${days}d "
	(( $hours > 0 )) && echo -n "${hours}h "
	(( $minutes > 0 )) && echo -n "${minutes}m "
	echo "${seconds}s"
}

# fastest possible way to check if repo is dirty
prompt_shaun_git_dirty() {
	# check if we're in a git repo
	command git rev-parse --is-inside-work-tree &>/dev/null || return 0
	# check if it's dirty

  # check for staged files
  command git diff --quiet --cached || return 1
  # check for modified files
  command git diff --quiet || return 2
  # check for untracked files
  [[ -z $(command git ls-files --others --exclude-standard) ]] || return 3
}

# displays the exec time of the last command if set threshold was exceeded
prompt_shaun_cmd_exec_time() {
	local stop=$(date +%s)
	local start=${cmd_timestamp:-$stop}
	integer elapsed=$stop-$start
	(($elapsed > ${SHAUN_CMD_MAX_EXEC_TIME:=5})) && prompt_shaun_human_time $elapsed
}

prompt_shaun_preexec() {
	cmd_timestamp=$(date +%s)

	# shows the current dir and executed command in the title when a process is active
	print -Pn "\e]0;"
	echo -nE "$PWD:t: $2"
	print -Pn "\a"
}

# string length ignoring ansi escapes
prompt_shaun_string_length() {
	echo ${#${(S%%)1//(\%([KF1]|)\{*\}|\%[Bbkf])}}
}

prompt_shaun_check_git_arrows() {
	# reset git arrows
	prompt_shaun_git_arrows=

	# check if there is an upstream configured for this branch
	command git rev-parse --abbrev-ref @'{u}' &>/dev/null || return

	local arrow_status
	# check git left and right arrow_status
	arrow_status="$(command git rev-list --left-right --count HEAD...@'{u}' 2>/dev/null)"
	# exit if the command failed
	(( !$? )) || return

	# left and right are tab-separated, split on tab and store as array
	arrow_status=(${(ps:\t:)arrow_status})
	local arrows left=${arrow_status[1]} right=${arrow_status[2]}

	(( ${right:-0} > 0 )) && arrows+="${SHAUN_GIT_DOWN_ARROW:-⇣}"
	(( ${left:-0} > 0 )) && arrows+="${SHAUN_GIT_UP_ARROW:-⇡}"

	[[ -n $arrows ]] && prompt_shaun_git_arrows=" ${arrows}"
}

prompt_shaun_precmd() {
	# shows the full path in the title
	print -Pn '\e]0;%~\a'

  # check for git arrows
	prompt_shaun_check_git_arrows

	# git info
	vcs_info

  local git_color=242
	prompt_shaun_git_dirty
  local retval=$?
  if [[ $retval -ne 0 ]]; then
    git_color='11';
    local GIT_STAGED_AMOUNT=${$(git diff --name-only --cached | wc -l)// /}
    local GIT_MODIFIED_AMOUNT=${$(git diff --name-only | wc -l)// /}
    local GIT_UNTRACKED_AMOUNT=${$(git ls-files --others --exclude-standard | wc -l)// /}
    [[ ${GIT_STAGED_AMOUNT} -gt 0 ]] && prompt_shaun_git_arrows+=' %F{10}+'${GIT_STAGED_AMOUNT}'%f';
    [[ ${GIT_MODIFIED_AMOUNT} -gt 0 ]] && prompt_shaun_git_arrows+=' %F{214}'${GIT_MODIFIED_AMOUNT}'m%f';
    [[ ${GIT_UNTRACKED_AMOUNT} -gt 0 ]] && prompt_shaun_git_arrows+=' %F{1}'${GIT_UNTRACKED_AMOUNT}'*%f';
  fi

	local prompt_shaun_preprompt="%F{$git_color}${vcs_info_msg_0_}"
  prompt_shaun_preprompt+="%F{cyan}${prompt_shaun_git_arrows}%f"
  [[ -n $prompt_shaun_username ]] && prompt_shaun_preprompt+=' '$prompt_shaun_username
  prompt_shaun_preprompt+=" %F{yellow}$(prompt_shaun_cmd_exec_time)%f"
  RPROMPT=$prompt_shaun_preprompt;
}


prompt_shaun_setup() {
	# prevent percentage showing up
	# if output doesn't end with a newline
	export PROMPT_EOL_MARK=''

	prompt_opts=(cr subst percent)

	autoload -Uz add-zsh-hook
	autoload -Uz vcs_info

	add-zsh-hook precmd prompt_shaun_precmd
	add-zsh-hook preexec prompt_shaun_preexec

	zstyle ':vcs_info:*' enable git
	zstyle ':vcs_info:git*' formats ' %b'
	zstyle ':vcs_info:git*' actionformats ' %b|%a'

	# show username@host if logged in through SSH
	[[ "$SSH_CONNECTION" != '' ]] && prompt_shaun_username='%n@%m '

	# prompt turns red if the previous command didn't exit with 0
	PROMPT='%F{blue}%c %(?.%F{magenta}.%F{red})%(!.#.❯)%f '
}

prompt_shaun_setup "$@"