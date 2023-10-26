#!/bin/bash

input_file="$1"
output_extension="$2"
filename=$(basename -- "$input_file")
filename_noext="${filename%.*}"
output_file="${filename_noext}.${output_extension}"

lossy=("mp3" "aac" "ogg" "wma")
lossless=("flac" "alac" "wav" "aiff")

# dont overwrite a file
if [ -e "$output_file" ]; then
    kdialog --error "The target file already exists."
    exit 1
fi

# init var for ffmpeg stderrrrr
error_output=""

# warn if lossy to lossless
input_extension="${filename##*.}"
if [[ " ${lossy[@]} " =~ " ${input_extension} " ]] && [[ " ${lossless[@]} " =~ " ${output_extension} " ]]; then
    kdialog --warningyesno "WARNING: Converting from a lossy to a lossless format.\n\nQuality will NOT improve.\n\nCompression artifacts will be present.\n\nThis betrays the point of lossless formats.\n\nPRESERVATIONISTS WILL WEEP.\n\nContinue?"
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

# warn if lossless to lossy
input_extension="${filename##*.}"
if [[ " ${lossless[@]} " =~ " ${input_extension} " ]] && [[ " ${lossy[@]} " =~ " ${output_extension} " ]]; then
    kdialog --warningyesno "WARNING: Converting from a lossless to a lossy format.\n\nQuality will NOT be preserved.\n\nCompression artifacts will be PERMANENTLY introduced.\n\nCONVERTING BACK TO LOSSLESS WILL NOT UNDO THIS.\n\nContinue?"
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

# ffmpeg cmd changes based on ext
if [[ " ${lossy[@]} " =~ " ${output_extension} " ]] || [[ " ${lossless[@]} " =~ " ${output_extension} " ]]; then
    error_output=$(ffmpeg -i "$input_file" -q:a 0 -map a "$output_file" 2>&1)
else
    error_output=$(ffmpeg -i "$input_file" "$output_file" 2>&1)
fi

# check exit statuses
if [ $? -ne 0 ]; then
    # y u fail, ffmpeg????
    if echo "$error_output" | grep -q "Invalid data found when processing input"; then
        kdialog --error "FFmpeg does not support source file type."
    else
        kdialog --error "An unknown error occurred:\n$error_output"
    fi
    exit 1
fi
