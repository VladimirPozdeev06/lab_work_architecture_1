#!/bin/bash

if [ $# -lt 3 ]; then
    echo "The total amount of arguments is less than 3 so the test is wrong. The program will be ended with error code 1"
    exit 1
fi

path_to_folder="$1"
if [ -d "$path_to_folder" ]; then
    echo "It is correct file_folder: '$path_to_folder'"
else 
    echo "The path_to folder is incorrect. The program will be ended with code 1"
    exit 1
fi

folder_size=$(du -sb "$path_to_folder" | cut -f1)
echo "The size: $folder_size"

backup_dir="${path_to_folder}/backup"
mkdir -p "$backup_dir"

mapfile -t files_sorted_array < <(find "$path_to_folder" -type f -not -path "*/backup/*" -printf "%T@ %p\n" | sort -n | cut -d' ' -f2-)
the_size_inputed_by_user="$2"
archive_name="backup.tar.gz"
archive_path="${backup_dir}/${archive_name}"

if [ "$the_size_inputed_by_user" -lt "$folder_size" ]; then

    if ["${#files_sorted_array[@]}" -eq 0 ]; then
        echo "No files in folder so nothing to archive. The end of program"
        exit 1
    fi

    for file in "${files_sorted_array[@]}"; do
        current_size=$(du -sb "$path_to_folder" | cut -f1)
        if [ "$current_size" -le "$the_size_inputed_by_user" ]; then
            echo "Now the size of folder less than target size"
            break
        fi

        tar -rf "$archive_path" -C "$path_to_folder" "$file"
        rm "$file"
    done
fi


new_size=$(du -sb "$path_to_folder" | cut -f1)

current_percentage=$((100 * new_size / the_size_inputed_by_user))
the_percent_to_archive_folder="$3"


if [ "$the_percent_to_archive_folder" -lt "$current_percentage" ]; then
    echo "The current size of folder already has been less than inputted percentage :))"
    exit 1
fi

echo "The second archivation....."

mapfile -t files_sorted_array < <(find "$path_to_folder" -type f -not -path "*/backup/*" -printf "%T@ %p\n" | sort -n | cut -d' ' -f2-)

if ["${#files_sorted_array[@]}" -eq 0 ]; then
    echo "No files in folder so nothing to archive. The end of program"
    exit 1
fi

for file in "${files_sorted_array[@]}"; do
    current_size=$(du -sb "$path_to_folder" | cut -f1)
    if [ "$current_size" -le "$the_size_inputed_by_user" ]; then
        echo "Now the size of folder less than target size"
        break
    fi
    tar -rf "$archive_path" -C "$path_to_folder" "$file"
    rm "$file"
done
