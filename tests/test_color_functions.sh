#!/bin/bash

# Test script for color-functions.sh

source lib/color-functions.sh

# Test color output
echo "Testing color output:"
printf "%sRed Text%s\n" "$(color_red)" "$NC"
printf "%sGreen Text%s\n" "$(color_green)" "$NC"
printf "%sYellow Text%s\n" "$(color_yellow)" "$NC"
printf "%sBlue Text%s\n" "$(color_blue)" "$NC"

# Test text formatting
echo "Testing text formatting:"
printf "%sBold Text%s\n" "$(text_bold)" "$NC"
printf "%sDim Text%s\n" "$(text_dim)" "$NC"
printf "%sUnderlined Text%s\n" "$(text_underline)" "$NC"

# Test 256-color support (if available)
supports_256_colors
if [ $? -eq 0 ]; then
    echo "Testing 256-color support:"
    printf "%s256 Color (196)%s\n" "$(color256_fg 196)" "$NC"
    printf "%s256 Color (46)%s\n" "$(color256_fg 46)" "$NC"
fi

echo "Color functions test complete."

