#!/bin/bash

input_file="$1"
output_extension="$2"
input_format="$3"
filename=$(basename -- "$input_file")
filename_noext="${filename%.*}"

# alac is a special babyboy
if [ "$output_extension" == "alac" ]; then
    output_file="${filename_noext}.m4a"
else
    output_file="${filename_noext}.${output_extension}"
fi

alossy=("mp3" "aac" "ogg" "wma" "m4a")
alossless=("flac" "alac" "wav" "aiff")
ilossy=("jpg" "gif" "webp")
ilossless=("png" "bmp" "tiff" "eps" "raw" "ico" "tga")
superlossless=("psd")
alllossy=( "${alossy[@]}" "${ilossy[@]}" )
alllossless=( "${alossless[@]}" "${ilossless[@]}" )

# dont overwrite a file
if [ -e "$output_file" ]; then
    zenity --error --text="The target file already exists."
    exit 1
fi

# Check for conversion between alossy and alossless and show a warning
input_extension="${filename##*.}"
if [[ " ${alllossy[@]} " =~ " ${input_extension} " ]] && [[ " ${alllossless[@]} " =~ " ${output_extension} " ]]; then
    zenity --question --text="WARNING: Converting from a lossy to a lossless format.\n\nQuality will NOT improve.\n\nCompression artifacts will be present.\n\nThis betrays the point of lossless formats.\n\nPRESERVATIONISTS WILL WEEP.\n\nContinue?" \
        --ok-label="Continue" --cancel-label="Cancel" --default-cancel  --icon-name="warning"
    if [ $? -ne 0 ]; then
        kill $ZENITY_PID
        exit 1
    fi
fi

if [[ " ${alllossless[@]} " =~ " ${input_extension} " ]] && [[ " ${alllossy[@]} " =~ " ${output_extension} " ]]; then
    zenity --question --text="WARNING: Converting from a lossless to a lossy format.\n\nQuality will NOT be preserved.\n\nCompression artifacts will be PERMANENTLY introduced.\n\nCONVERTING BACK TO LOSSLESS WILL NOT UNDO THIS.\n\nContinue?" \
        --ok-label="Continue" --cancel-label="Cancel" --default-cancel  --icon-name="warning"
    if [ $? -ne 0 ]; then
        kill $ZENITY_PID
        exit 1
    fi
fi

if [[ " ${superlossless[@]} " =~ " ${input_extension} " ]]; then
    zenity --question --text="WARNING: This file is not only lossless, but contains\nadditional data such as layer information.\nConversion will discard this information.\n\nCONVERTING BACK TO LOSSLESS WILL NOT UNDO THIS.\n\nContinue?" \
        --ok-label="Continue" --cancel-label="Cancel" --default-cancel  --icon-name="warning"
    if [ $? -ne 0 ]; then
        kill $ZENITY_PID
        exit 1
    fi
fi


if [[ " $input_format " == " audio " ]] || [[ " $input_format " == " video " ]]; then
    # ffmpeg cmd changes based on ext
    if [[ " ${alossy[@]} " =~ " ${output_extension} " ]] || [[ " ${alossless[@]} " =~ " ${output_extension} " ]]; then
        if [ "$output_extension" == "alac" ]; then  # alac is still a special babyboy
            error_output=$(ffmpeg -i "$input_file" -acodec alac "$output_file" 2>&1) &
        else
        error_output=$(ffmpeg -i "$input_file" -q:a 1 -map a "$output_file" 2>&1) &
        fi
    else
        error_output=$(ffmpeg -i "$input_file" -q:a 1 "$output_file" 2>&1) &
    fi
    else
    if [[ " $input_format " == " image " ]]; then
        error_output=$(convert "$input_file" "$output_file" 2>&1) &
    fi
fi

CONVERT_PID=$!

# i hate zenity tbh
(    while kill -0 $CONVERT_PID 2> /dev/null; do
        echo "# Converting\n$filename\nto\n$output_file"
        sleep 1
    done
) | zenity --progress --title="Converting Media" --text="Initializing..." --auto-close

# check if cancelled
if [ $? -eq 1 ]; then
    kill $CONVERT_PID
    rm -f "$output_file"
    zenity --error --text="Conversion canceled. Target file deleted."
    exit 1
fi

# check exit statuses
wait $CONVERT_PID
if [ $? -ne 0 ]; then
    zenity --error --text="An error occurred during conversion:\n\n$error_output"
    exit 1
fi
