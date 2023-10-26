#!/bin/bash

input_file="$1"
output_extension="$2"
filename=$(basename -- "$input_file")
filename_noext="${filename%.*}"

# alac is a special babyboy
if [ "$output_extension" == "alac" ]; then
    output_file="${filename_noext}.m4a"
else
    output_file="${filename_noext}.${output_extension}"
fi

lossy=("mp3" "aac" "ogg" "wma" "m4a")
lossless=("flac" "alac" "wav" "aiff")

# dont overwrite a file
if [ -e "$output_file" ]; then
    zenity --error --text="The target file already exists."
    exit 1
fi

# Check for conversion between lossy and lossless and show a warning
input_extension="${filename##*.}"
if [[ " ${lossy[@]} " =~ " ${input_extension} " ]] && [[ " ${lossless[@]} " =~ " ${output_extension} " ]]; then
    zenity --question --text="WARNING: Converting from a lossy to a lossless format.\n\nQuality will NOT improve.\n\nCompression artifacts will be present.\n\nThis betrays the point of lossless formats.\n\nPRESERVATIONISTS WILL WEEP.\n\nContinue?" \
        --ok-label="Continue" --cancel-label="Cancel" --default-cancel  --icon-name="warning"
    if [ $? -ne 0 ]; then
        kill $ZENITY_PID
        exit 1
    fi
fi

if [[ " ${lossless[@]} " =~ " ${input_extension} " ]] && [[ " ${lossy[@]} " =~ " ${output_extension} " ]]; then
    zenity --question --text="WARNING: Converting from a lossless to a lossy format.\n\nQuality will NOT be preserved.\n\nCompression artifacts will be PERMANENTLY introduced.\n\nCONVERTING BACK TO LOSSLESS WILL NOT UNDO THIS.\n\nContinue?" \
        --ok-label="Continue" --cancel-label="Cancel" --default-cancel  --icon-name="warning"
    if [ $? -ne 0 ]; then
        kill $ZENITY_PID
        exit 1
    fi
fi

# ffmpeg cmd changes based on ext
if [[ " ${lossy[@]} " =~ " ${output_extension} " ]] || [[ " ${lossless[@]} " =~ " ${output_extension} " ]]; then
    if [ "$output_extension" == "alac" ]; then  # alac is still a special babyboy
        ffmpeg -i "$input_file" -acodec alac "$output_file" 2>&1 &
    else
    ffmpeg -i "$input_file" -q:a 1 -map a "$output_file" 2>&1 &
    fi
else
    ffmpeg -i "$input_file" -q:a 1 "$output_file" 2>&1 &
fi
FFMPEG_PID=$!

# i hate zenity tbh
(    while kill -0 $FFMPEG_PID 2> /dev/null; do
        echo "# Converting\n$filename\nto\n$output_file"
        sleep 1
    done
) | zenity --progress --title="Converting Media" --text="Initializing..." --auto-close

# check if cancelled
if [ $? -eq 1 ]; then
    kill $FFMPEG_PID
    rm -f "$output_file"
    zenity --error --text="Conversion canceled. Target file deleted."
    exit 1
fi

# check exit statuses
wait $FFMPEG_PID
if [ $? -ne 0 ]; then
    zenity --error --text="An error occurred during conversion."
    exit 1
fi
