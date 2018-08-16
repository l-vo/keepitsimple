---
title: Partager des volumes Docker via AFP sur OS X
tags:
  - Docker
date: 2018-08-16 19:38:08
---

Suite à la lecture de [cet article](https://jolicode.com/blog/ma-stack-de-developpement-avec-docker-sous-macos-x), je voudrais faire un court retour d'expérience sur une solution alternative
 que je privilégie depuis un certain temps. 
 
## La problématique
Si depuis que j'ai goûté à Docker, je ne peux m'en passer pour mes conteneurs de développement, j'ai vite été confronté à des limitations sur OS X:
- Les performances médiocres lorsque je partage un dossier entre ma machine hôte et mon conteneur (les projects Symfony sont très lents même sans activer XDebug).
- Les fonctionnalités limités du volume partagé. Il ne permet par exemple pas d'utiliser les ACL comme préconisé par Symfony pour jongler entre les actions du server web (user www-data) et celles de la console (user courant).  
<!-- more -->

## Configurations de volume cached et delegated
Conscient que cette solution ne réglerait de toute façon pas mon deuxième problème (la gestion des ACL), j'ai quand même voulu tester les performances des configurations de volume `cached` et `delegated` (plus d'infos sur ces configurations [ici](https://docs.docker.com/docker-for-mac/osxfs-caching/#tuning-with-consistent-cached-and-delegated-configurations)). Pour du développement, j'ai besoin que les modifications sur les fichiers faites depuis ma machine hôte soient immédiatement repércutées dans mon conteneur. Je choisis donc la configuration `delegated`:

```yaml
# docker-compose.yml d'un conteneur Symfony
version: '3'
  services:
    symfony:
      # ...
      volumes:
        - /Users/laurent/dev/my-symfony-project:/var/www/html:delegated
```

Alors oui, les performances dans mon cas d'utilisation sont meilleures qu'avec la configuration par defaut (`consistent`, c'est à dire synchronisation immédiate dans les deux sens). Mais dans une situation de développement, les pages sont encore beaucoup trop longues à charger et l'utilisation de XDebug reste compliquée.

## Volumes partagés avec le système hôte via AFP

### Principe
Plutôt que de partager le volume avec la machine hôte, ce qui diminue les performances et limite les fonctionalités du système de fichier, on va essayer de rester plus proche de la philosophie de Docker: les volumes sont partagés entre différents conteneurs et c'est un conteneur qui nous permet d'accéder à notre système de fichier. A savoir un conteneur Netatalk (protocole AFP). Alors bien sûr il y a des inconvénients, et pas des moindres qui vont en rebuter plus d'un:
* Vous ne pouvez accéder à la source de vos projets si votre conteneur AFP n'est pas démarré
* Votre IDE va accéder à vos fichiers via un partage réseau et peut avoir des difficultés à les analyser

Je privilégie cependant cette solution, car j'ai enfin des temps de chargement acceptables sur mon projet et une gestion de droits (ACL) fonctionnelle. J'utilise l'IDE PHPStorm d'Intellij qui n'est pas un éditeur des plus légers et une fois la première indexation faite, ça fonctionne plutôt bien. Si vous choisissez d'utiliser un partage via AFP sur plusieurs projets, il faut que vous ayez un seul conteneur AFP qui va servir les fichiers de tous vos projets. C'est ce que nous allons faire dans la prochaine section.

### Mise en place

#### Creation d'un volume externe
Ce volume va contenir le code source du projet sur lequel vous développez.
```bash
$ docker volume create myproject_files
```

#### Conteneur du projet
(Symfony dans notre exemple)

```yaml
# docker-compose.yml d'un conteneur Symfony
version: '3'
  services:
    symfony:
      # ...
      volumes:
        - myproject_files:/var/www/html

volumes:
  myproject_files:
    external: true            
```

#### Conteneur Netatalk

C'est le conteneur respectant le protocole AFP qui va servier les fichiers de notre (nos) projet(s).

##### Dockerfile:  
```dockerfile
# netatalk/Dockerfile
FROM cptactionhank/netatalk

# On va ici aussi utiliser les ACL afin de ne pas avoir de problème de droits sur
# nos fichiers qui peuvent provenir de plusieurs conteneurs avec des users différents
RUN apt-get update && apt-get install acl

COPY afp.conf /etc

COPY run.sh /
RUN chmod u+x /run.sh

CMD ["/run.sh"]
```

##### Fichier de configuration Netatalk:
```
;netatalk/afp.conf
[Global]
; output log entries to stdout instead of syslog
; it is the docker way where the engine in turn
; can direct the log output to a storage backend
log file = /dev/stdout

; enable guest access as well as user accounts
uam list = uams_guest.so uams_dhx2.so uams_dhx.so

[Share]
path = /media/share
; when the environment variable `AFP_USER` is not
; provided valid users list will be empty and
; thus be available for both guests and
; authenticated users
valid users = user1
```

`user1` utilisé ci-dessus en tant qu'utilisateur valide doit correspondre à la variable d'environnement `AFP_USER` du fichier docker-compose.yml (voir plus loin).

##### Fichier lancé au démarrage du conteneur:
```bash
# netatalk/run.sh
#!/usr/bin/env bash

# Grace à ces ACL, le user 1000 (user1) pourra accéder aux fichiers pouvant
# appartenir à des utilisateurs de différents projets avec des UID différents.
# La valeur 1000 doit être la même que celles des variables d'environnement
# AFP_UID et AFP_GID dans le fichier docker-compose.yml.
setfacl -dR -m u:1000:rwX /media/share
setfacl -R -m u:1000:rwX /media/share

/docker-entrypoint.sh
```

##### Fichier docker-compose:
```yaml
# docker-compose.yml
version: "3"

services:
  afp:
    build: netatalk
    ports:
      - 1548:548
    volumes:
      - myproject_files:/media/share/myproject

    environment:
      - AFP_USER=user1
      - AFP_PASSWORD=user1
      - AFP_UID=1000
      - AFP_GID=1000

volumes:
  myproject_files:
    external: true 
```

### Utilisation
Votre conteneur AFP peut recevoir des volumes de différents projets, je vous conseille de procéder ainsi, démarrer un conteneur AFP par projet sera vite fastidieux lorsque vous voudrez consulter des sources de différents projets.

Pour intégrer le volume partagé d'un projet supplémentaire, il suffit de le rajouter dans les sections volumes:
```yaml
# docker-compose.yml
version: "3"

services:
  afp:
    build: netatalk
    ports:
      - 1548:548
    volumes:
      - myproject_files:/media/share/myproject
      - myotherproject_files:/media/share/myotherproject

    environment:
      - AFP_USER=user1
      - AFP_PASSWORD=user1
      - AFP_UID=1000
      - AFP_GID=1000

volumes:
  myproject_files:
    external: true
  myotherproject_files:
    external: true 
```


## Conclusion
Cette solution n'a pas pour prétention ni d'être meilleure que les autres, ni de résoudre tous les problèmes (d'ailleurs elle ne le fait pas !). Elle peut cependant être intéressante pour les personnes qui ne seraient pas tout à fait satisfaites des volumes partagés de façon traditionnelle entre machine hôte et conteneur et qui sont prêtes à faire d'autres compromis.