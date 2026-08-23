#!/bin/bash

# Audio Jack Setup Script for Ryzen HD Audio Controller
# Configures analog audio output (headphones)

echo "Checking for Ryzen HD Audio Controller..."

card_id=$(pactl list short cards | grep -E "alsa_card\.pci-0000_f4_00.6" | awk '{print $1}')

if [ -z "$card_id" ]; then
    echo "Error: Could not find the expected audio card (pci-0000_f4_00.6)!"
    echo "Available cards:" 
    pactl list short cards
    exit 1
fi

echo "Setting analog stereo output profile..."
pactl set-card-profile "$card_id" output:analog-stereo+input:analog-stereo

sleep 2

sink_id=$(pactl list short sinks | grep "alsa_output.pci-0000_f4_00.6.analog-stereo" | awk '{print $1}')

if [ -z "$sink_id" ]; then
    echo "Error: Analog stereo sink not found!"
    echo "Available sinks:" 
    pactl list short sinks
    exit 1
fi

echo "Setting default sink..."
pactl set-default-sink "$sink_id"

echo "Activating sink..."
pactl suspend-sink "$sink_id" 0

sleep 1

state=$(pactl list sinks | grep -A 2 "Name: $sink_id" | grep "State:" | awk '{print $2}')
if [ "$state" = "RUNNING" ] || [ "$state" = "IDLE" ]; then
    echo "Audio configuration completed!" 
    echo "Sink: $sink_id (State: $state)"
else
    echo "Warning: Sink may not be fully active (State: $state). Try playing audio to test."
fi
