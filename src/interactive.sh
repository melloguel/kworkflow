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
