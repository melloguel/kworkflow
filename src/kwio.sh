# Associative array to read strings from files

# NOTE: src/kw_config_loader.sh must be included before this file
declare -gr BLUECOLOR='\033[1;34;49m%s\033[m'
declare -gr REDCOLOR='\033[1;31;49m%s\033[m'
declare -gr YELLOWCOLOR='\033[1;33;49m%s\033[m'
declare -gr GREENCOLOR='\033[1;32;49m%s\033[m'
declare -gr SEPARATOR='========================================================='

# Alerts command completion to the user.
#
# @COMMAND First argument should be the kw command string which the user wants
#          to get notified about. It can be printed in visual notification if
#          ${configurations[visual_alert_command]} uses it.
# @ALERT_OPT Second argument is the string with the "--alert=" option or "" if
#            no alert option was given by the user.
function alert_completion()
{

  local COMMAND=$1
  local ALERT_OPT=$2
  local opts

  if [[ $# -gt 1 && "$ALERT_OPT" =~ ^--alert= ]]; then
    opts="$(printf '%s\n' "$ALERT_OPT" | sed s/--alert=//)"
  else
    opts="${configurations[alert]}"
  fi

  while read -rN 1 option; do
    if [ "$option" == 'v' ]; then
      if command_exists "${configurations[visual_alert_command]}"; then
        eval "${configurations[visual_alert_command]} &"
      else
        warning 'The following command set in the visual_alert_command variable could not be run:'
        warning "${configurations[visual_alert_command]}"
        warning 'Check if the necessary packages are installed.'
      fi
    elif [ "$option" == 's' ]; then
      if command_exists "${configurations[sound_alert_command]}"; then
        eval "${configurations[sound_alert_command]} &"
      else
        warning 'The following command set in the sound_alert_command variable could not be run:'
        warning "${configurations[sound_alert_command]}"
        warning 'Check if the necessary packages are installed.'
      fi
    fi
  done <<< "$opts"
}

# Print colored message. This function verifies if stdout
# is open and print it with color, otherwise print it without color.
#
# @param $1 [${@:2}] [-n ${@:3}] it receives the variable defining
# the color to be used and two optional params:
#   - the option '-n', to not output the trailing newline
#   - text message to be printed
#shellcheck disable=SC2059
function colored_print()
{
  local message="${*:2}"
  local colored_format="${!1}"

  if [[ $# -ge 2 && $2 = '-n' ]]; then
    message="${*:3}"
    if [ -t 1 ]; then
      printf "$colored_format" "$message"
    else
      printf '%s' "$message"
    fi
  else
    if [ -t 1 ]; then
      printf "$colored_format\n" "$message"
    else
      printf '%s\n' "$message"
    fi
  fi
}

# Print normal message (e.g info messages).
function say()
{
  colored_print BLUECOLOR "$@"
}

# Print error message.
function complain()
{
  colored_print REDCOLOR "$@"
}

# Warning error message.
function warning()
{
  colored_print YELLOWCOLOR "$@"
}

# Print success message.
function success()
{
  colored_print GREENCOLOR "$@"
}

# Ask for yes or no
#
# @message A string with the message to be displayed for the user.
#
# Returns:
# Return "1" if the user accept the question, otherwise, return "0"
#
# Note: ask_yN return the string '1' and '0', you have to handle it by
# yourself in the code.
function ask_yN()
{
  local message="$*"

  read -r -p "$message [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    printf '%s\n' '1'
  else
    printf '%s\n' '0'
  fi
}

# load text used in the module from a file into a dictionary.
# This function requires a key before a body of text to
# name that particular body of text, as in this example:

# [KEY]:
# text

# @path the full path of the text file to be read
# as the first argument.
# @reset optional parameter. If not null, will reset the dictionary.

# KEY must be non-empty, alphanumeric and between square brackets followed by a
# colon. The global array string_file can then be queried by key as in
# ${string_file[KEY]} to obtain the string. KEY should be named according
# to its respective module for compatibility. That is, if we have modules A and B,
# name A's keys as [KEY_A] and B's keys as [KEY_B]. This makes it so the modules
# keys will be compatible with each other

# Return:
# 0: In case of success.
# 1: If an invalid key is found, prints the line with a bad key.
# 2: If a key is not found.
# 3: If @path is invalid, or is not a text file.
# 4: If the file given in @path is empty.
function load_module_text()
{
  local path="$1"
  local reset="$2"
  local key=''
  local line_counter=0
  local error=0
  local key_set=0
  local first_line=0

  if [[ -n "$reset" ]]; then
    unset module_text_dictionary
  fi

  declare -gA module_text_dictionary

  if ! [[ -f "$path" ]]; then
    complain "[ERROR]:$path: Does not exist or is not a text file."
    return 3
  fi

  if ! [[ -s "$path" ]]; then
    complain "[ERROR]:$path: File is empty."
    return 4
  fi

  while read -r line; do
    ((line_counter++))
    if [[ "$line" =~ ^\[(.*)\]:$ ]]; then
      key=''
      #echo before "${BASH_REMATCH[1]}"
      [[ "${BASH_REMATCH[1]}" =~ (^[A-Za-z0-9_][A-Za-z0-9_]*$) ]] && key="${BASH_REMATCH[1]}"
      #echo after "${BASH_REMATCH[1]}"
      #echo "${BASH_REMATCH[1]}"
      #key="${BASH_REMATCH[0]}" #$(printf '%s' "$line" | grep -o -E '\w+')
      if [[ -z "$key" ]]; then
        error=1
        complain "[ERROR]:$path:$line_counter: keys should be alphanum chars"
        continue
      fi

      if [[ -n "${module_text_dictionary[$key]}" ]]; then
        warning "[WARNING]:$path:$line_counter: overwriting '$key' key."
      fi

      key_set=1
      first_line=1
      module_text_dictionary["$key"]=''
    elif [[ -n "$key" ]]; then
      if [[ "$first_line" -eq 1 ]]; then
        module_text_dictionary["$key"]="$line"
        first_line=0
      else
        module_text_dictionary["$key"]+=$'\n'"$line"
      fi
    fi
  done < "$path"

  if [[ "$key_set" -eq "0" ]]; then
    error=2
    complain "[ERROR]:$path: no key found"
  fi

  return "$error"
}
