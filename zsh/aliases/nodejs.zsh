# Node.js and npm aliases

# Node.js shortcuts
alias n='node'
alias nd='node --inspect'
alias ne='node -e'

# npm package management
alias ni='npm install'
alias nid='npm install --save-dev'
alias nig='npm install -g'
alias ns='npm start'
alias nt='npm test'
alias nr='npm run'
alias nb='npm run build'
alias nd='npm run dev'
alias nw='npm run watch'

# npm utility commands
alias nls='npm list'
alias nlsg='npm list -g --depth=0'
alias nup='npm update'
alias nun='npm uninstall'
alias nci='npm ci'
alias ncc='npm cache clean --force'
alias nout='npm outdated'
alias nau='npm audit'
alias nauf='npm audit fix'

# npm info and search
alias nv='npm version'
alias ni='npm info'
alias nse='npm search'

# package.json shortcuts
alias nps='npm run start'
alias npt='npm run test'
alias npb='npm run build'
alias npd='npm run dev'

# nvm version management
alias nvm-ls='nvm list'
alias nvm-lsr='nvm ls-remote'
alias nvm-use='nvm use'
alias nvm-install='nvm install'
alias nvm-current='nvm current'
alias nvm-default='nvm alias default'

# Quick nvm switching (common versions)
alias nv18='nvm use 18'
alias nv20='nvm use 20'
alias nvlts='nvm use --lts'

# Project initialization
alias ninit='npm init -y'
alias nlink='npm link'
alias nunlink='npm unlink'