---
title: Installer une galerie photo (Piwigo) sur Raspberry PI
description: Installation d'une galerie photo (Piwigo) sur Raspberry PI
date: 2018-04-28 12:24:36
tags:
  - raspberry
  - py
  - nginx
  - piwigo
  - osmc
  - raspbian
---
## Quelle gallerie photo ?
Je cherchais une galerie photo à mettre sur mon Raspberry Pi 3. J'avais précédemment utilisé la galerie propriétaire DSPhoto (Synology) et je cherchais quelque chose s'en rapprochant en terme de fonctionnalités. A savoir:
- Possibilité d'uploader les photos par lot
- Existence d'une application ou au moins d'un site web adapté aux mobiles
- Capacité à présenter les photos en miniatures mais aussi de les télécharger en qualité originale si besoin
- Gestion d'albums privés et possibilité d'y accéder sans identification via un lien
- Support de certains formats vidéos

Après quelques recherches, j'ai fini par tomber sur Piwigo (http://fr.piwigo.org/), une galerie open source avec un système de plugin permettant d'étendre les fonctionnalités de base à celles que je recherchais.
<!-- more -->

## Installation
J'ai installé OSMC (https://osmc.tv/) pour faire de mon Raspberry PI un lecteur multimedia. Cette distribution étant basée sur une Debian Stretch, je n'ai pas de mal à trouver dans les dépôts Debian ce dont j'ai besoin pour faire tourner Piwigo; à savoir:
- Nginx
- Php-fpm
- Mysql

Une fois l'archive de Piwigo décompressée dans le répertoire web de Nginx, je suis les instructions de l'installateur et j'ai peu de temps après une galerie photo fonctionnelle.

## Fonctionnement
La galerie génère des miniatures des images, soit "en live" lorsque l'on consulte les albums, soit via le traitement par lot dans la partie administration. Une fois les miniatures générées, c'est assez plaisant, le site répond bien, c'est presque parfait. Presque.

## Les problèmes
là où le bât blesse, c'est précisémment cette génération de miniatures. Quand on a des albums d'un certain nombre de photos (je ne parle pas d'albums de 1000 photos, on reste en dessous des 100 à raison de 5Mo environ par photo), la génération est très longue.   
 
 Pire, comme toute les générations se lancent en parallèle (une génération par photo affichée, aussi bien à l'affichage de l'album qu'à l'affichage dans le traitement par lot), la charge en vient à planter l'application. A tel point que je suis obligé de redémarrer mon serveur web pour pouvoir à nouveau utiliser la galerie.
 
Une autre chose, lorsque je lance la synchronisation des photos que j'ai précédemment uploadé, s'il y a beaucoup de photos à synchroniser, mon Nginx timeout (même si au final la synchro est bien effectuée au bout d'un moment car le Php-fpm lui continue et termine son travail).

## Les solutions
### Augmentation du timeout pour la synchronisation
Ici, rien de très compliqué, la directive `fastcgi_read_timeout` règle mon problème, je choisi de la mettre ce timeout à 5 minutes:
```
fastcgi_read_timeout 300;
```

### Bloquage de la génération d'image en live
En attendant qu'un script cgi soit mis au point pour générer les miniatures, n'ayant pas trop de temps à consacrer au problème, je choisi de mettre un "hack" dans ma configuration Nginx qui va me permettre de détourner les requêtes de génération qui se lancent en parallèle. Je met ma configuration dans un snippet:
```
# /etc/nginx/snippets/phpfpm.conf
# Live image loading is too expensive, disable it           
if ($arg_ajaxload != "true") {                              
    set $redirect 1;                                        
}                                                           
                                                                            
if ($arg_b = "") {                                          
    set $redirect 1;                                        
}                                                           

# For videos, needed only if you use the VideoJS plugin         
if ($args ~ "pwg_representative") {                         
    set $redirect 0;                                          
}                                                           
                                                                            
if ($redirect = 1) {                                        
    rewrite ^/i.php$ /_data/i$args?;                          
    rewrite ^(/_data/i/.*?)(&.*)$ $1 last;                    
}          
                                
# Usual configuration for Nginx with Php-fpm                                
fastcgi_pass unix:/var/run/php5-fpm.sock;        
include fastcgi_params;                          
fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;

# For fixing synchronization timeout
fastcgi_read_timeout 300; 
```
L'idée est que lorsque les requêtes ne sont pas les requêtes de générations explicites du traitement par lot (c'est à dire les requêtes émises par les images affichées dans les albums ou les images affichées dans le traitement par lot), on transforme l'url de génération en live par une url statique pour chercher la miniature comme si elle avait déjà été générée. On obtient donc une image vide tant que les miniatures ne sont pas générées mais au moins on ne plante pas le serveur.

Lorsque l'url contient un paramètre `b`, il s'agit forcément d'une génération implicite de miniature que l'on ne veut pas exécuter donc on applique la redirection. C'est aussi le cas si le paramètre `ajaxload` est présent et qu'il n'est pas égal à `true`. Pour les utilisateurs du plugin VideoJS, il ne faut pas appliquer la redirection pour les miniatures de vidéos, on reconnait ces urls par la présence du paramètre `pwg_representative`.

Ce snippet doit être inclus dans la configuration Nginx:

```
# /etc/nginx/sites-enabled/default
server {                                                                   
    listen 80 default_server;
   	listen [::]:80 default_server;

    # Gallery root directory is on my external drive
    root /media/dd/piwigo;                             
                                            
    # Default index file
    index index.php;
                                                                 
    server_name _;                                               
                                                                 
    location / {                                                 
            # First attempt to serve request as file, then       
            # as directory, then fall back to displaying a 404.
            try_files $uri $uri/ =404;                         
    }                                                          
                                                               
    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #                                                                   
    location ~ \.php$ {                                                 
            include snippets/fastcgi-php.conf;                          
            include snippets/phpfpm.conf;                               
    }                                                                   
                                              
    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one                                 
    #                                                          
    location ~ /\.ht {                                         
            deny all;                                          
    }                                                          
                              
    # Hide Nginx version
    server_tokens off;
}  
```

J'en ai aussi profité pour ajouter une petite sécurité afin que les pages sensibles (administration, installation...) ne soient accessible qu'à partir du réseau local (en clair quand je suis relié à ma box ou connecté à mon WIFI):
```
# Allow sensible pages access only from local network
location ~ ^/(admin.php|upgrade.php|install.php)$ {
        allow 192.168.1.0/24;
        deny all;                               
        include snippets/fastcgi-php.conf;                     
        include snippets/phpfpm.conf;
}
```
Ce qui nous donne la configuration complète:
```
# /etc/nginx/sites-enabled/default
server {                                                                   
    listen 80 default_server;
   	listen [::]:80 default_server;

    # Gallery root directory is on my external drive
    root /media/dd/piwigo;                             
                                            
    # Default index file
    index index.php;
                                                                 
    server_name _;                                               
                                                                 
    location / {                                                 
            # First attempt to serve request as file, then       
            # as directory, then fall back to displaying a 404.
            try_files $uri $uri/ =404;                         
    }
    
    # Allow sensible pages access only from local network
    location ~ ^/(admin.php|upgrade.php|install.php)$ {
            allow 192.168.1.0/24;
            deny all;                               
            include snippets/fastcgi-php.conf;                     
            include snippets/phpfpm.conf;
    }                                                          
                                                               
    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #                                                                   
    location ~ \.php$ {                                                 
            include snippets/fastcgi-php.conf;                          
            include snippets/phpfpm.conf;                               
    }                                                                   
                                              
    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one                                 
    #                                                          
    location ~ /\.ht {                                         
            deny all;                                          
    }                                                          
                              
    # Hide Nginx version
    server_tokens off;
}  
```

## Conclusion

Avec cette configuration:
- je dépose mes photos dans le répertoire `galleries` de Piwigo (un `rsync` fait ça très bien)
- je synchronise mes photos déposées ("synchronisation" dans la partie Administration)
- j'utilise le traitement par lot pour générer mes miniatures

Je dispose désormais d'une galerie pleine de fonctionnalités, skinnable et réactive simplement à partir d'un Raspberry Pi et qui n'est limitée en taille que par la capacité de mon disque dur.


