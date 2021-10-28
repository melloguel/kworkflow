function create_ssh_key()
{
  local ssh_dir="$1"
  local key_name="${2:-kw_ssh_key}"

  if [[ -n "$key_name" ]]; then
    mkdir -p "$ssh_dir"
    eval "ssh-keygen -t rsa -f $ssh_dir/$key_name"
  fi
}

function check_ssh_installation()
{

  cmd=''
  distro=$(detect_distro '/')

  case "$distro" in
    none)
      complain "We do not support your distro (yet). We cannot check if SSH is installed."
      ;;
    arch)
      pacman -Qe openssh > /dev/null
      if [[ "$?" != 0 ]]; then
        #not found
        cmd='pacman -S openssh'
      fi
      ;;
    debian)
      installed=$(dpkg-query -W --showformat='${Status}\n' openssh-client 2> /dev/null | grep -c 'ok installed')
      if [[ "$installed" -eq 0 ]]; then
        #not found
        cmd='apt install openssh-client'
      fi
      ;;
  esac

  [[ -n "$cmd" ]]

}

function interactive_init()
{

  local cmd=''
  local distro=''
  local has_ssh=0
  local ssh_keys
  local key_name ssh_dir
  local ssh_user ssh_ip

  load_string "$KW_LIB_DIR/strings/init.txt"

  say "${string_file['text_interactive_start']}"

  printf "\n"
  read -r -p '>>> Press ENTER to continue'

  say "${string_file['text_ssh_start']}"
  printf "\n"
  read -r -p '>>> Press ENTER to continue'

  check_ssh_installation

  if [[ -n "$cmd" ]]; then
    if [[ $(ask_yN 'SSH was not found in this system, would you like to install it?') =~ '1' ]]; then
      eval "sudo $cmd"
      has_ssh=$?
    fi
  fi

  if [[ "$has_ssh" =~ "0" ]]; then
    say "${string_file['$text_ssh_found']}"
    printf "\n"

    ssh_keys=$(find "$HOME/.ssh" -type f -name "*.pub")

    if [[ -n "$ssh_keys" ]]; then
      say "${string_file['text_ssh_keys']}"
    fi

    #TODO: Fix cases and make code more efficient
    select item in "Create new LOCAL RSA key for KW" "Create new GLOBAL RSA key for KW" $ssh_keys; do

      if [[ -n "$item" ]]; then
        case "$REPLY" in
          1 | 2)
            #Local or Global
            say 'Creating new SSH key...'
            warning 'If you type in the name of a key that already exists,'
            warning 'you will be prompted to confirm that you wish to overwrite the key.'
            warning 'Proceed with caution. We do not recommend you overwrite your key.'
            say 'Please, type in the name of your new key:'
            read -r -p "Key: " key_name
            warning 'SSH will ask you for a password.'
            warning 'Make sure you remember it for later use.'
            ;;&
          1) ssh_dir="$PWD/$KW_DIR/ssh" ;;
          2) ssh_dir="$HOME/.ssh" ;;
          *)
            #TODO: Add the path to the chosen key to KW config (Different issue).
            #Picked key
            ;;
        esac

        create_ssh_key "$ssh_dir" "$key_name"

        if [[ "$?" =~ "0" ]]; then
          success "Created new key at $ssh_dir/$key_name.pub"
        else
          complain "Failed to create new key."
        fi
        #TODO: Test this

        break
      fi
    done

    if [[ $(ask_yN 'Would you like to configure a SSH connection to a remote machine?') -eq 1 ]]; then
      say "${string_file['text_remote_start']}"
      read -r -p 'USER: ' ssh_user
      read -r -p 'IP  : ' ssh_ip
      options_values['REMOTE']="${ssh_user:-root}@${ssh_ip:-127.0.0.1}:22"
    fi
  fi
  #TODO: Help to setup git;

  #TODO: Help to setup kworkflow.config;

  #TODO: Check for required;
}
