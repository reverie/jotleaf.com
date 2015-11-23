#!/bin/bash
#
# Takes care of this stuff:
#   1) Sets up Django environment variables
#   2) Supresses known warnings so that cron doesn't email us

PROJECT="jotleaf"

# If the script moves this must be changed!
ROOT="$(dirname $0)"

SCRIPTS_DIR=$ROOT

PYTHON="$VIRTUALENVWRAPPER_HOOK_DIR/$PROJECT/bin/python"
#if [ -x "/envs/jotleaf/bin/python" ]; then 
#    PYTHON="/envs/jotleaf/bin/python" # Expected server setup
#elif [ -x "$HOME/envs/jotleaf/bin/python" ]; then
#    PYTHON="$HOME/envs/jotleaf/bin/python" # Some dev setups
#else
#    echo "Error: Couldn't find virtualenv python"
#    exit 1
#fi

# Django environment
PYTHONPATH=$ROOT:$ROOT/$PROJECT; export PYTHONPATH
DJANGO_SETTINGS_MODULE=settings; export DJANGO_SETTINGS_MODULE
PATH=$PATH:/sbin; export PATH # needed for ejabberdctl

script_name=$1
shift 1;
args=$@

# Figure out debug settings
if [ $PROJECT_DEBUG ]; then
    DEBUG='-m pdb'
fi

# Supresses any DeprecationWarnings
$PYTHON -W "ignore::DeprecationWarning::0" $DEBUG $SCRIPTS_DIR/$script_name $args
