# Set the C locale for sorting to fix slow ls performance
export LC_ALL=C

# Define aliases that use the new locale
alias ls='ls --color=auto'
alias ll='ls -lah'

