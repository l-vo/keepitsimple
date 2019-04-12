#!/usr/bin/env bash

# Install theme
if [[ ! -d themes/paperbox ]]
then
    # Pull theme
    git clone https://github.com/sun11/hexo-theme-paperbox.git themes/paperbox
    cd themes/paperbox
    git checkout 9c02944ac18d22640b5fc1dfee8fccb6a49786c1
    cd ../..

    # Custom banner
    cp /tmp/theme/banner.jpg themes/paperbox/source/css/images/

    # Custom favicon
    cp /tmp/theme/favicon/android-chrome-192x192.png themes/paperbox/source/
    cp /tmp/theme/favicon/android-chrome-512x512.png themes/paperbox/source/
    cp /tmp/theme/favicon/apple-touch-icon.png themes/paperbox/source/
    cp /tmp/theme/favicon/browserconfig.xml themes/paperbox/source/
    cp /tmp/theme/favicon/favicon.ico themes/paperbox/source/
    cp /tmp/theme/favicon/favicon-16x16.png themes/paperbox/source/
    cp /tmp/theme/favicon/favicon-32x32.png themes/paperbox/source/
    cp /tmp/theme/favicon/mstile-150x150.png themes/paperbox/source/
    cp /tmp/theme/favicon/safari-pinned-tab.svg themes/paperbox/source/
    cp /tmp/theme/favicon/site.webmanifest themes/paperbox/source/

    # Specific config
    cp /tmp/theme/_config.yml themes/paperbox
    cp /tmp/theme/fr-FR.yml themes/paperbox/languages

    # Specific layouts
    cp /tmp/theme/head.ejs themes/paperbox/layout/_partial
    cp /tmp/theme/page.ejs themes/paperbox/layout/_partial
    echo "<%- partial('_partial/page', {post: page, index: false}) %>" > themes/paperbox/layout/page.ejs

    # Remove animated cube
    perl -i -pe 'BEGIN { undef $/; } s/<div id="contenedor">.*?<\/div>/<div id="contenedor"><\/div>/sm' themes/paperbox/layout/_partial/header.ejs

   # Remove unfindable fonts
    sed -i 's/<link href="\/\/fonts.useso.com\/css?family=Source+Code+Pro" rel="stylesheet" type="text\/css">//' themes/paperbox/layout/_partial/head.ejs

    # Custom css
    sed -i 's/#header-title/#header-title\n  width: 200px/' themes/paperbox/source/css/_partial/header.styl
    sed -i 's/padding: 5px 10px/padding: inherit 10px/' themes/paperbox/source/css/_partial/header.styl
    sed -i 's/bottom: 60px/bottom: 120px\n    font-size: 0.9em/' themes/paperbox/source/css/_partial/header.styl
    sed -i 's/bottom: -50px/bottom: -15px/' themes/paperbox/source/css/_partial/header.styl
    echo -e "@media mq-mobile\n  .nav-icon\n    &:first-child\n      padding-left: 0\n    &:last-child\n      padding-right: 0" >> themes/paperbox/source/css/_partial/header.styl

    # Search feature
    cat /tmp/theme/search.ejs >> themes/paperbox/layout/_partial/after-footer.ejs
    sed -i 's/<a class="main-nav-link st-search-show-outputs"><%= __(.search.) %><\/a>/<a class="main-nav-link" href="\/rechercher" id="search-link"><%= __("search") %><\/a>/' themes/paperbox/layout/_partial/header.ejs
    sed -i 's/<a href="#search" class="mobile-nav-link st-search-show-outputs"><%= __(.search.) %><\/a>/<a href="\/rechercher" class="mobile-nav-link st-search-show-outputs"><%= __("search") %><\/a>/' themes/paperbox/layout/_partial/mobile-nav.ejs
    echo -e "#local-search-input\\n  width: 150px" >> themes/paperbox/source/css/style.styl
fi

if [[ ! -d ../node_modules ]]
then
    npm install --no-save

    # Fix sublanguages in hexo (see https://github.com/hexojs/hexo-util/pull/37)
    sed -i "s/require('highlight.js\/lib\/highlight')/require('highlight.js')/" node_modules/hexo-util/lib/highlight.js
    # Fix problem on some sublanguages (i.e. Docker)
    sed -i 's/end: \/\[^\\\\]\\n\//end: \/[^\\\\]$\//' node_modules/highlight.js/lib/languages/dockerfile.js
fi

# Hexo binary shortcut
if [[ ! -f /usr/local/bin/hexo ]]
then
    ln -s /blog/node_modules/hexo-cli/bin/hexo /usr/local/bin/hexo
fi

hexo server --draft