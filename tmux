# sets scrollback 
set-option -g history-limit 9000

# remap prefix to Control + a
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# force a reload of the config file
unbind r
bind r source-file ~/.tmux.conf \; display "Reloaded!"

# remove delay
set -s escape-time 1

# move between panes: vim-like
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# resize panes: vim-like
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# visual notification
setw -g monitor-activity on
set -g visual-activity on

# set status bar colors
set -g status-fg white
set -g status-bg black

# center window list in status bar
set -g status-justify centre

# status bar left
set -g status-left-length 40
set -g status-left "#[fg=green]Session: [ #S ] #[fg=yellow]#I #[fg=cyan]#P"

# status bar right
set -g status-right "#[fg=cyan][ #h ] %d %b %R"

# run commands in multiple panes
bind C-s set-window-option synchronize-panes

# switch between sessions
bind -r ( switch-client -p
bind -r ) switch-client -n

# Use vim keybindings in copy mode
setw -g mode-keys vi
