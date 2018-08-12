FROM node

RUN npm install hexo-cli -g
RUN hexo init blog

WORKDIR blog

# Checkout a known version of the theme for right css replacements
RUN git clone https://github.com/sun11/hexo-theme-paperbox.git themes/paperbox \
&& cd themes/paperbox \
&& git checkout 9c02944ac18d22640b5fc1dfee8fccb6a49786c1

RUN npm install
RUN npm install hexo-generator-feed --save
RUN npm install hexo-generator-search --save
RUN npm install hexo-generator-seo-friendly-sitemap --save

COPY _config.yml .

# Personal banner
COPY banner.jpg themes/paperbox/source/css/images/

# Favicon
COPY favicon/android-chrome-192x192.png themes/paperbox/source/
COPY favicon/android-chrome-512x512.png themes/paperbox/source/
COPY favicon/apple-touch-icon.png themes/paperbox/source/
COPY favicon/browserconfig.xml themes/paperbox/source/
COPY favicon/favicon.ico themes/paperbox/source/
COPY favicon/favicon-16x16.png themes/paperbox/source/
COPY favicon/favicon-32x32.png themes/paperbox/source/
COPY favicon/mstile-150x150.png themes/paperbox/source/
COPY favicon/safari-pinned-tab.svg themes/paperbox/source/
COPY favicon/site.webmanifest themes/paperbox/source/

# Theme
COPY theme/_config.yml themes/paperbox
COPY theme/head.ejs themes/paperbox/layout/_partial
COPY theme/fr-FR.yml themes/paperbox/languages

# Remove animated cube
RUN perl -i -pe 'BEGIN { undef $/; } s/<div id="contenedor">.*?<\/div>/<div id="contenedor"><\/div>/sm' themes/paperbox/layout/_partial/header.ejs

# Remove unfindable fonts
RUN sed -i 's/<link href="\/\/fonts.useso.com\/css?family=Source+Code+Pro" rel="stylesheet" type="text\/css">//' themes/paperbox/layout/_partial/head.ejs

# Change some css
RUN sed -i 's/#header-title/#header-title\n  width: 200px/' themes/paperbox/source/css/_partial/header.styl
RUN sed -i 's/padding: 5px 10px/padding: inherit 10px/' themes/paperbox/source/css/_partial/header.styl
RUN sed -i 's/bottom: 60px/bottom: 120px\n    font-size: 0.9em/' themes/paperbox/source/css/_partial/header.styl
RUN sed -i 's/bottom: -50px/bottom: -15px/' themes/paperbox/source/css/_partial/header.styl
RUN echo  '@media mq-mobile\n  .nav-icon\n    &:first-child\n      padding-left: 0\n    &:last-child\n      padding-right: 0' >> themes/paperbox/source/css/_partial/header.styl

# Use specific layout for pages
COPY theme/page.ejs themes/paperbox/layout/_partial
RUN echo "<%- partial('_partial/page', {post: page, index: false}) %>" > themes/paperbox/layout/page.ejs

# Add search feature
COPY theme/search.ejs /tmp/
RUN cat /tmp/search.ejs >> themes/paperbox/layout/_partial/after-footer.ejs
COPY theme/search.js themes/paperbox/source/js/
RUN sed -i 's/<a class="main-nav-link st-search-show-outputs"><%= __(.search.) %><\/a>/<a class="main-nav-link" href="\/rechercher" id="search-link"><%= __("search") %><\/a>/' themes/paperbox/layout/_partial/header.ejs
RUN sed -i 's/<a href="#search" class="mobile-nav-link st-search-show-outputs"><%= __(.search.) %><\/a>/<a href="\/rechercher" class="mobile-nav-link st-search-show-outputs"><%= __("search") %><\/a>/' themes/paperbox/layout/_partial/mobile-nav.ejs
RUN echo "#local-search-input\n  width: 150px" >> themes/paperbox/source/css/style.styl

# Fix sublanguages in hexo (see https://github.com/hexojs/hexo-util/pull/37)
RUN sed -i "s/require('highlight.js\/lib\/highlight')/require('highlight.js')/" node_modules/hexo-util/lib/highlight.js

# Fix problem on some sublanguages (i.e. Docker)
COPY tryhighlight_patched.js /
RUN if [$(grep tryHighlightPatched node_modules/hexo-util/lib/highlight.js) = ""];\
 then cat /tryhighlight_patched.js >>  node_modules/hexo-util/lib/highlight.js;\
 sed -i 's/return tryHighlight(/return tryHighlightPatched(/' node_modules/hexo-util/lib/highlight.js;\
 fi;

EXPOSE 4000

CMD ["hexo", "server", "--draft"]