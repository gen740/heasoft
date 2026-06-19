xmmsasShellHook() {
  export SAS_DIR=@xmmsas@
  export SAS_PIPELINE=0
  source $SAS_DIR/sas-setup.sh
}

if [ -z "${shellHookFuncs+x}" ]; then
  shellHookFuncs=xmmsasShellHook
else
  shellHookFuncs="$shellHookFuncs xmmsasShellHook"
fi
