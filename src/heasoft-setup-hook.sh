heasoftShellHook() {
  headas_path=$(find @heasoft@ -maxdepth 1 -type d \( -name 'aarch64*' -o -name 'x86_64*' \) | head -n 1)
  export HEADAS=$headas_path
  source "$headas_path/headas-init.sh"
}

if [ -z "${shellHookFuncs+x}" ]; then
  shellHookFuncs=heasoftShellHook
else
  shellHookFuncs="$shellHookFuncs heasoftShellHook"
fi

