source ~/.config/fish/conf.d/done.fish

if test -f ~/.cache/wal/colors.fish
    source ~/.cache/wal/colors.fish
end

if set -q foreground
    set fish_color_normal $foreground
    set fish_color_command $color4
    set fish_color_keyword $color5
    set fish_color_quote $color3
    set fish_color_redirection $color6
    set fish_color_end $color3
    set fish_color_error $color1
    set fish_color_param $color2
    set fish_color_comment $color8
    set fish_color_match --background=$color4
    set fish_color_selection --background=$color8
    set fish_color_search_match --background=$color8
    set fish_color_history_current --bold
    set fish_color_operator $color6
    set fish_color_escape $color5
    set fish_color_cwd $color4
    set fish_color_cwd_root $color1
    set fish_color_valid_path --underline
    set fish_color_autosuggestion $color8
    set fish_color_user $color2
    set fish_color_host $color4
    set fish_color_cancel $color1 '--reverse'
    set fish_color_option $color3

    set fish_pager_color_background $background
    set fish_pager_color_completion $foreground
    set fish_pager_color_description $color8
    set fish_pager_color_prefix $color4
    set fish_pager_color_progress $color8

    set fish_pager_color_secondary_background $background
    set fish_pager_color_secondary_completion $foreground
    set fish_pager_color_secondary_description $color8
    set fish_pager_color_secondary_prefix $color4

    set fish_pager_color_selected_background --background=$color8
    set fish_pager_color_selected_completion $foreground
    set fish_pager_color_selected_description $color8
    set fish_pager_color_selected_prefix $color4
end
# =============================================================================


## Set values

function fish_greeting
    echo
    set -l current_time (date +"%-I:%M%P")
    set -l uptime_text (uptime -p | string replace -r '^up ' '')
    set -l kernel (uname -r)

    set_color -b black
    printf " "

    set_color brblack
    printf "it's  "
    set_color blue
    printf "%s  " $current_time
    set_color green
    printf "%s  " "$uptime_text"
    set_color magenta
    printf "%s " $kernel

    set_color normal
    echo
end

function fish_prompt
    echo

    set -l shell_path "/bin/fish"
    set -l user_name "$USER"
    set -l cwd (prompt_pwd)

    set_color -b black brwhite
    printf " %s " $shell_path

    set_color -b brblack brwhite
    printf " %s " $user_name

    set_color -b blue black
    printf " %s " $cwd

    set_color normal
    set_color blue
    printf " ❯ "

    set_color normal
end


# Format man pages
set -x MANROFFOPT "-c"
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

# Set settings for https://github.com/franciscolourenco/done
set -U __done_min_cmd_duration 10000
set -U __done_notification_urgency_level low

## Environment setup
# Apply .profile: use this to put fish compatible .profile stuff in
if test -f ~/.fish_profile
  source ~/.fish_profile
end

# Add ~/.local/bin to PATH
if test -d ~/.local/bin
    if not contains -- ~/.local/bin $PATH
        set -p PATH ~/.local/bin
    end
end

# Add depot_tools to PATH
if test -d ~/Applications/depot_tools
    if not contains -- ~/Applications/depot_tools $PATH
        set -p PATH ~/Applications/depot_tools
    end
end


## Functions
# Functions needed for !! and !$ https://github.com/oh-my-fish/plugin-bang-bang
function __history_previous_command
  switch (commandline -t)
  case "!"
    commandline -t $history[1]; commandline -f repaint
  case "*"
    commandline -i !
  end
end

function __history_previous_command_arguments
  switch (commandline -t)
  case "!"
    commandline -t ""
    commandline -f history-token-search-backward
  case "*"
    commandline -i '$'
  end
end

if [ "$fish_key_bindings" = fish_vi_key_bindings ];
  bind -Minsert ! __history_previous_command
  bind -Minsert '$' __history_previous_command_arguments
else
  bind ! __history_previous_command
  bind '$' __history_previous_command_arguments
end

# Fish command history
function history
    builtin history --show-time='%F %T '
end

function backup --argument filename
    cp $filename $filename.bak
end

# Copy DIR1 DIR2
function copy
    set count (count $argv | tr -d \n)
    if test "$count" = 2; and test -d "$argv[1]"
        set from (echo $argv[1] | trim-right /)
        set to (echo $argv[2])
        command cp -r $from $to
    else
        command cp $argv
    end
end


## Useful aliases
# Replace ls with eza
alias ls='eza -al --color=always --group-directories-first --icons' # preferred listing
alias la='eza -a --color=always --group-directories-first --icons'  # all files and dirs
alias ll='eza -l --color=always --group-directories-first --icons'  # long format
alias lt='eza -aT --color=always --group-directories-first --icons' # tree listing
alias l.="eza -a | grep -e '^\.'"                                     # show only dotfiles

# Common use
alias grubup="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias hw='hwinfo --short'                                   # Hardware Info
alias big="expac -H M '%m\t%n' | sort -h | nl"              # Sort installed packages according to size in MB
alias gitpkg='pacman -Q | grep -i "\-git" | wc -l'          # List amount of -git packages
alias update='sudo pacman -Syu'

# Get fastest mirrors
alias mirror="sudo cachyos-rate-mirrors"

# Help people new to Arch
alias apt='man pacman'
alias apt-get='man pacman'
alias please='sudo'
alias tb='nc termbin.com 9999'

# Cleanup orphaned packages
alias cleanup='sudo pacman -Rns (pacman -Qtdq)'

# Get the error messages from journalctl
alias jctl="journalctl -p 3 -xb"

# Recent installed packages
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"


if not pgrep -u (whoami) ssh-agent > /dev/null
    eval (ssh-agent -c) > /dev/null
end

ssh-add -l > /dev/null 2>&1
or ssh-add ~/.ssh/id_ed25519 > /dev/null 2>&1

# Bạn có thể tạo alias trong shell (như .bashrc hoặc .zshrc)
alias sudachi='bash -c "$(curl -sL https://raw.githubusercontent.com/KabosuNeko/sudachi/main/sudachi.sh)"'

if status is-login
    set -Ux GTK_IM_MODULE fcitx
    set -Ux QT_IM_MODULE fcitx
    set -Ux XMODIFIERS @im=fcitx
    set -Ux SDL_IM_MODULE fcitx
    set -Ux GLFW_IM_MODULE ibus
end
