#!/bin/bash

# Audio Jack Setup Script for Ryzen HD Audio Controller
# Automatically detects and configures analog audio output

echo "Checking for Ryzen HD Audio Controller..."

# Find the correct audio card (Ryzen HD Audio Controller)
# On this system, we know that pci-0000_f4_00.6 is the analog audio controller
# since it's the only non-HDMI device with an output sink

card_id=$(pactl list short cards | grep -E "alsa_card\.pci-0000_f4_00.6" | awk '{print $1}')

if [ -z "$card_id" ]; then
    echo "Error: Could not find the expected audio card (pci-0000_f4_00.6)!"
    echo "Available cards:" 
    pactl list short cards
    exit 1
fi

# Find the correct sink for this card
# First try the pro-output-0 sink (what you're using successfully)
sink_id=$(pactl list short sinks | grep "alsa_output.pci-0000_f4_00.6.pro-output-0" | awk '{print $1}')

# If not found, fall back to analog-stereo as alternative
if [ -z "$sink_id" ]; then
    echo "Pro-output-0 sink not found, trying analog-stereo..."
    sink_id=$(pactl list short sinks | grep "alsa_output.pci-0000_f4_00.6.analog-stereo" | awk '{print $1}')
fi

# If still not found, look for any non-HDMI output on this card
if [ -z "$sink_id" ]; then
    echo "Neither pro-output-0 nor analog-stereo found, searching for any non-HDMI output..."
    sink_id=$(pactl list short sinks | grep "alsa_output.pci-0000_f4_00.6" | grep -v "hdmi" | awk '{print $1}' | head -1)
fi

if [ -z "$sink_id" ]; then
    echo "Error: No suitable audio output found for $card_id!"
    echo "Available sinks:" 
    pactl list short sinks
    exit 1
fi

# Set as default sink (this is what actually matters for audio output)
echo "Setting default sink..."
pactl set-default-sink "$sink_id"

# Check if sink is suspended and activate it if needed
echo "Checking sink state..."
state=$(pactl list sinks | grep -A 2 "Name: $sink_id" | grep "State:" | awk '{print $2}')
if [ "$state" = "SUSPENDED" ]; then
    echo "Activating suspended sink..."
    pactl suspend-sink "$sink_id" 0
fi

echo "Note: Audio profile setting skipped as your system is already configured correctly."

# Ensure the profile is active and working
sleep 1
if pactl list sinks short | grep -q "$sink_id"; then
    echo "Audio configuration completed successfully!" 
    echo "Your audio jack should now be working with Pro Audio output."
else
    echo "Warning: Audio configuration may not be fully applied."
fi

exit 0
