caldbShellHook() {
  export CALDB=@caldb@
  source @caldb@/software/tools/caldbinit.sh
}

if [ -z "${shellHookFuncs+x}" ]; then
  shellHookFuncs=caldbShellHook
else
  shellHookFuncs="$shellHookFuncs caldbShellHook"
fi
