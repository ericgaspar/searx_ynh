#!/bin/bash

#=================================================
# EXPERIMENTAL HELPERS
#=================================================

# Remove a file or a directory securely
#
# usage: ynh_secure_remove --file=path_to_remove [--regex=regex to append to $file] [--non_recursive] [--dry_run]
# | arg: -f, --file - File or directory to remove
# | arg: -r, --regex - Regex to append to $file to filter the files to remove
# | arg: -n, --non_recursive - Perform a non recursive rm and a non recursive search with the regex
# | arg: -d, --dry_run - Do not remove, only list the files to remove
#
# Requires YunoHost version 2.6.4 or higher.
ynh_secure_remove () {
    # Declare an array to define the options of this helper.
    local legacy_args=frnd
    declare -Ar args_array=( [f]=file= [r]=regex= [n]=non_recursive [d]=dry_run )
    local file
    local regex
    local dry_run
    local non_recursive
    # Manage arguments with getopts
    ynh_handle_getopts_args "$@"
    regex=${regex:-}
    dry_run=${dry_run:-0}
    non_recursive=${non_recursive:-0}

    local forbidden_path="
/var/www \
/home/yunohost.app"

    # Fail if no argument is provided to the helper.
    if [ -z "$file" ]
    then
        ynh_print_warn --message="ynh_secure_remove called with no argument --file, ignoring."
        return 0
    fi

    if [ -n "$regex" ]
    then
        if [ -e "$file" ]
        then
            if [ $non_recursive -eq 1 ]; then
                local recursive="-maxdepth 1"
            else
                local recursive=""
            fi
            # Use find to list the files in $file and grep to filter with the regex
            files_to_remove="$(find -P "$file" $recursive -name ".." -prune -o -print | grep --extended-regexp "$regex")"
        else
            ynh_print_info --message="'$file' wasn't deleted because it doesn't exist."
            return 0
        fi
    else
        files_to_remove="$file"
    fi

    # Check each file before removing it
    while read file_to_remove
    do
        if [ -n "$file_to_remove" ]
        then
            # Check all forbidden path before removing anything
            # First match all paths or subpaths in $forbidden_path
            if [[ "$forbidden_path" =~ "$file_to_remove" ]] || \
                # Match all first level paths from / (Like /var, /root, etc...)
                [[ "$file_to_remove" =~ ^/[[:alnum:]]+$ ]] || \
                # Match if the path finishes by /. Because it seems there is an empty variable
                [ "${file_to_remove:${#file_to_remove}-1}" = "/" ]
            then
                ynh_print_err --message="Not deleting '$file_to_remove' because this path is forbidden !!!"

            # If the file to remove exists
            elif [ -e "$file_to_remove" ]
            then
                if [ $dry_run -eq 1 ]
                then
                    ynh_print_warn --message="File to remove: $file_to_remove"
                else
                    if [ $non_recursive -eq 1 ]; then
                        local recursive=""
                    else
                        local recursive="--recursive"
                    fi

                    # Remove a file or a directory
                    rm --force $recursive "$file_to_remove"
                fi
            else
                # Ignore non existent files with regex, as we likely remove the parent directory before its content is listed.
                if [ -z "$regex" ]
                then
                    ynh_print_info --message="'$file_to_remove' wasn't deleted because it doesn't exist."
                fi  
            fi
        fi
    done <<< "$(echo "$files_to_remove")"
}