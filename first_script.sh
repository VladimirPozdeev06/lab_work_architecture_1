#!/bin/bash
test_folder=""
cleanup(){
if [ -n "$test_folder" ]  &&  [ -d "$test_folder" ]; then

rm -rf "$test_folder"
fi
if [ -n "$backup_dir" ]  &&  [ -d "$backup_dir" ]; then

rm -rf "$backup_dir"


fi
}
trap cleanup EXIT
if ! [ $# -eq 3 ]; then
    echo "The total amount of arguments is less than 3 so the test is wrong. The program will be ended with error code 1"
    exit 1
fi

original_path_to_folder="$1"
test_folder="${original_path_to_folder}_$$"

if [ -d "$original_path_to_folder" ]; then
   
cp -r "$original_path_to_folder" "$test_folder"
path_to_folder="$test_folder"
echo "It is correct path to folder '$path_to_folder'"
else 
    echo "The path_to folder is incorrect. The program will be ended with code 1"
    exit 1
fi



folder_size=$(du -sb "$path_to_folder" | cut -f1)
echo "The size: $folder_size"

backup_dir="/tmp/backup_$$"
mkdir -p "$backup_dir"

mapfile -t files_sorted_array < <(find "$path_to_folder" -type f  -printf "%T@ %p\n" | sort -n | cut -d' ' -f2-)

if [[ ! "$2" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    echo "The second argument is not a number. The error"
    exit 1
fi
if [[ "$2" =~ \. ]]; then
the_size_inputed_by_user=$(printf "%.0f" "$2")
echo "Merely the integer part of second argument was taken '$the_size_inputed_by_user'"
else
the_size_inputed_by_user="$2"
fi
if [[ ! "$3" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    echo "The third  argument is not a number. The error"
    exit 1
fi
if [ "$3" -lt 0 -o "$3" -gt 100 ]; then
echo "The third inputted argument  is not a percent"
exit 1
fi
if [[ "$3" =~ \. ]]; then
the_percent_to_archive_folder=$(printf "%.0f" "$3")
echo "Merely the integer part of number was taken"
else
the_percent_to_archive_folder="$3"
fi

archive_name="backup.tar.gz"
archive_path="${backup_dir}/${archive_name}"

if [ "$the_size_inputed_by_user" -lt "$folder_size" ]; then
echo "The first_acrivation.................."
    if [ "${#files_sorted_array[@]}" -eq 0 ]; then
        echo "No files in folder so nothing to archive. The end of program"
        exit 1
    fi

    for file in "${files_sorted_array[@]}"; do
        sync
        current_size=$(du -sb "$path_to_folder" | cut -f1)
        if [ "$current_size" -le "$the_size_inputed_by_user" ]; then
            echo "Now the size of folder less than target size"
            break
        fi
if  [ !  -f "$file" ]; then
continue
fi
r="${file#$path_to_folder/}"
        tar -rf "$archive_path" -C "$path_to_folder" "$r"
        rm "$file"
    done
else 
echo "The size inputted by user is greater than folder size so the first_arcivation will be skipped"
fi


new_size=$(du -sb "$path_to_folder" | cut -f1)
echo "new_size: '$new_size'"
user_size=$((the_size_inputed_by_user*the_percent_to_archive_folder/100))





mapfile -t files_sorted_array < <(find "$path_to_folder" -type f  -printf "%T@ %p\n" | sort -n | cut -d' ' -f2-)

if [ "${#files_sorted_array[@]}" -eq 0 ]; then
    echo "No files in folder so nothing to archive. The end of program"
    exit 1
fi
if [ "$new_size" -lt "$user_size" ]; then
    echo "The current size of folder already has been less than inputted percentage :))"
    echo "The success"
    exit 1
fi
echo "The second archivation....."

for file in "${files_sorted_array[@]}"; do
    current_size=$(du -sb "$path_to_folder" | cut -f1)
    if [ "$current_size" -le "$user_size" ]; then
        echo "Now the size of folder less than target size"
        break
    fi
   
if [ ! -f "$file" ]; then
continue
fi
r="${file#$path_to_folder/}"
        tar -rf "$archive_path" -C "$path_to_folder" "$r"
        rm "$file"

done
new_size=$(du -sb "$path_to_folder" | cut -f1)
echo "the final size: $new_size"
echo "The success"
exit
