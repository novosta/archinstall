#!/bin/bash

# Create config directory if it doesn't exist
mkdir -p ~/.config/hypr

# Write the new config to ~/.config/hypr/hyprland.conf
cat > ~/.config/hypr/hyprland.conf <<EOL
################
### MONITORS ###
################

monitor=HDMI-A-1,preferred,auto,auto

###################
### MY PROGRAMS ###
###################

\$terminal = alacritty
\$fileManager = dolphin
\$menu = wofi --show drun

#################
### AUTOSTART ###
#################

exec-once = waybar &
exec-once = \$terminal &
exec-once = nm-applet &

#####################
### LOOK AND FEEL ###
#####################

general {
    gaps_in = 5
    gaps_out = 20
    border_size = 2
    col.active_border = rgba(33ccffee)
    col.inactive_border = rgba(595959aa)
    resize_on_border = false
    allow_tearing = false
    layout = dwindle
}

decoration {
    rounding = 10
    active_opacity = 1.0
    inactive_opacity = 1.0
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
}

dwindle {
    pseudotile = true
    preserve_split = true
}

#############
### INPUT ###
#############

input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0
}

device {
    name = epic-mouse-v1
    sensitivity = -0.5
}

###################
### KEYBINDINGS ###
###################

\$mainMod = SUPER

bind = \$mainMod, Q, exec, \$terminal
bind = \$mainMod, C, killactive,
bind = \$mainMod, M, exit,
bind = \$mainMod, E, exec, \$fileManager
bind = \$mainMod, R, exec, \$menu
bindm = \$mainMod, mouse:272, movewindow
bindm = \$mainMod, mouse:273, resizewindow
EOL

echo "Hyprland configuration has been updated!"