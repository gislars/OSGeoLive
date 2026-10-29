# FOSSGIS: one-line banner for interactive shells (qterminal, login, ssh).
# Installed as /etc/profile.d/zz-fossgis-welcome.sh and sourced from bashrc.
# Placeholders __EDITION_LINE__ replaced at build time by install_desktop.sh.

case $- in
   *i*) ;;
   *) return 0 2>/dev/null || exit 0 ;;
esac

# Avoid repeating the line when profile and bashrc both source this file
if [ -z "${FOSSGIS_TERMINAL_WELCOME_SHOWN:-}" ] ; then
   FOSSGIS_TERMINAL_WELCOME_SHOWN=1
   export FOSSGIS_TERMINAL_WELCOME_SHOWN
   printf '%s\n' "__EDITION_LINE__"
fi
