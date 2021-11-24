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

function check_installation()
{
  local name="$1"
  local arch_name="$2"
  local debian_name="$3"
  local warning_message
  local distro
  local cmd=''

  distro=$(detect_distro '/')

  # Get install command
  case "$distro" in
    none)
      warning_message="We do not support your distro (yet). We cannot check if $name is installed."
      warning "$warning_message"
      if [[ $(ask_yN "Do you wish to proceed without configuring $name?") =~ '0' ]]; then
        exit 0
      fi
      ;;
    arch)
      pacman -Qe "$arch_name" > /dev/null
      if [[ "$?" != 0 ]]; then
        cmd="pacman -S $arch_name"
      fi
      ;;
    debian)
      installed=$(dpkg-query -W --showformat='${Status}\n' "$debian_name" 2> /dev/null | grep -c 'ok installed')
      if [[ "$installed" -eq 0 ]]; then
        cmd="apt install $debian_name"
      fi
      ;;
  esac

  printf '%s\n' "$cmd"
}

function git_install()
{
  local cmd="$1"
  local has_git
  
  has_git=0
  if [[ -n "$cmd" ]]; then
    if [[ $(ask_yN 'Git was not found in this system, would you like to install it?' 'y') =~ '1' ]]; then
      eval "sudo $cmd"
      has_git="$?"
    fi
  fi

  printf '%d\n' "$has_git" 
}

function get_git_config()
{
  local -n git_config="$1"
  local configured
  
  git_config['name']=$(git config user.name)
  git_config['email']=$(git config user.email)
  git_config['editor']=$(git config core.editor)
  git_config['branch']=$(git config init.defaultBranch)

  configured=0
  if [[ -z "${git_config['name']}" ]]; then
    configured=1
  fi

  if [[ -z "${git_config['email']}" ]]; then
    configured=1
  fi

  if [[ -z "${git_config['editor']}" ]]; then
    configured=1
  fi
  
  if [[ -z "${git_config['branch']}" ]]; then
    configured=1
  fi

  return "$configured"
}

function set_config_scope()
{
  local config_cmd="$1"
  local scope

  config_cmd='git config'

  if [[ $(git rev-parse --is-inside-work-tree 2> /dev/null) == 'true' ]]; then
    printf '%s\n' 'Select the scope of this configuration:'

    select scope in 'Local' 'Global'; do
      case $scope in
        'Global')
          config_cmd+=' --global'
          break
          ;;
        'Local')
          config_cmd+=' --local'
          break
          ;;
      esac
    done  
  else
    # Git is installed, but PWD is not a Git repository
    config_cmd+=' --global'
  fi

  printf '%s\n' "$config_cmd"
}

function set_git_configuration()
{
  local has_git="$1"
  local configured="$2"
  local -n git_config="$3"
  local git_editor_suggestion
  local config_cmd
  local scope

  if [[ "$has_git" =~ '0' && "$configured" =~ '1' ]]; then
    printf '%s\n' 'Now Git will be configured.'
    config_cmd=$(set_config_scope)

    if [[ -z "${git_config['name']}" ]]; then
      if [[ $(ask_yN 'Would you like to configure your name on Git?' 'y') =~ '1' ]]; then
        git_config['name']=$(ask_with_default 'What is your name?' "$USER")
        eval "$config_cmd user.name ${git_config['name']}"
      fi
    fi

    if [[ -z "${git_config['email']}" ]]; then
      if [[ $(ask_yN 'Would you like to configure your email on Git?' 'y') =~ '1' ]]; then
        read -r -p 'What is your email? ' git_config['email']
        # TODO: Validate if it is a valid email
        eval "$config_cmd user.email ${git_config['email']}"
      fi
    fi

    if [[ -z "${git_config['editor']}" ]]; then
      if [[ $(ask_yN 'Would you like to configure your default editor on Git?' 'y') =~ '1' ]]; then

        # This follows git precedence to determine used editor
        git_editor_suggestion='vi'
        [[ -n "$EDITOR" ]] && git_editor_suggestion="$EDITOR"
        [[ -n "$VISUAL" ]] && git_editor_suggestion="$VISUAL"

        configurations['editor']=$(ask_with_default 'What is your main editor?' "$git_editor_suggestion")
        eval "$config_cmd core.editor ${git_config['editor']}"
      fi
    fi

    if [[ -z "${git_config['branch']}" ]]; then
      # This is a minor configuration, so default is "no"
      if [[ $(ask_yN 'Would you like to configure your initial default branch on Git?' 'n') =~ '1' ]]; then
        git_config['branch']=$(ask_with_default 'What is your default branch name?' 'main')
        eval "$config_cmd init.defaultBranch ${git_config['branch']}"
      fi
    fi
  fi
}

function git_setup()
{
  local -A configurations
  local has_git
  local configured
  local cmd

  cmd=$(check_installation 'Git' 'git' 'git')
  has_git=$(git_install "$cmd")
  get_git_config configurations
  configured="$?"
  set_git_configuration "$has_git" "$configured" configurations
}

function interactive_init()
{
  local cmd=''
  local distro=''
  local has_ssh=0
  local ssh_keys
  local key_name ssh_dir
  local ssh_user ssh_ip

  load_module_text "$KW_LIB_DIR/strings/init.txt"

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
    
  git_setup
  
  #TODO: Help to setup kworkflow.config;

  #TODO: Check for required;
}
