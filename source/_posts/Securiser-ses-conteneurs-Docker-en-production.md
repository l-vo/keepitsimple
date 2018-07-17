---
title: Securiser ses conteneurs Docker en production
tags:
  - Docker
date: 2018-07-19 11:18:20
---

Docker est à l'origine conçu pour créer des conteneurs à la volée et effectuer des developpements/tests dans différents environments. Mais sa simplicité d'utilisation et son écosystème grandissant pousse de plus en plus ses adeptes à vouloir l'utiliser en prod. D'autant que de nouveaux outils (Kubernetes, Swarm...) et des améliorations récentes (user namespaces, variables d'environnement dans les docker-compose...) vont dans ce sens.  

Malheureusement les conteneurs Docker sont de base assez peu sécurisés. Nous allons 
voir quelques astuces simples pour limiter les possibilités d'attaques lorsque vous déploierez vos conteneurs en production. 

<!-- More -->

Tout d'abord je vous recommande la lecture de cette article: https://w3blog.fr/2016/02/23/docker-securite-10-bonnes-pratiques/. Bien que datant un peu, les préceptes qu'il aborde sont encore d'actualité. Je vais essayer de le compléter par quelques autres conseils pour sécuriser votre conteneur.

## Supprimer la création automatique de règles iptables
Par défaut, le daemon Docker créé les règles iptables dont il a besoin. Mais si vous êtes sur un système hôte avec plusieurs conteneurs et que vous le sécurisez via iptables et fail2ban (ou équivalent), vous allez vouloir garder le contrôle sur les règles qui vont être créées dans votre iptables. Celà se fait en modifiant les options du service Docker:
```
DOCKER_OPTS="--iptables=false"
```
Attention, lorsque vous modifiez les options du daemon, vous aurez la mauvaise surprise de voir que tous vos conteneurs, volumes etc sont à recréer. Vous pouvez les retrouver en revenant aux anciennes options du daemon; mais à garder à l'esprit si vous aviez prévu de faire cette modif en prod sans interruption de service.

## Utiliser les user namespaces
Un des problèmes innérants à la sécurité de Docker est le fait que les conteneurs tournent par defaut sur l'utilisateur root. Ce qui signifie que l'utilisateur root dans vos conteneurs a potentiellement les privilèges de l'utilisateur root de votre machine hôte. Oui, ça fait peur. Mais ça c'étant avant la mise en place sur Docker des user namespaces. Les user namespaces vont permettre de mapper les utilisateurs de vos conteneurs à des utilisateurs avec des privilèges plus limités sur votre système hôte. Là encore, la modification s'effectue via les options du daemon Docker:
```
DOCKER_OPTS="--userns-remap=default"
```
Une plage d'identifiants va être affecté à l'user/group dockremap dans les fichiers `/etc/subuid` et `/etc/subgid` de votre machine hôte et correspondront aux utilisateurs à l'intérieur de vos conteneurs. Un nom d'utilisateur autre que `dockremap` peut être utilisé si vous le specifiez comme valeur de `--userns-remap`à la place de `default`.

## Directive USER dans les Dockerfile
Vous avez maintenant quelques astuces pour protéger mieux vos conteneurs. Mais si vous publiez une image de conteneur "production ready", la personne qui va la déployer aura-t-elle utilisé les user namespaces ? Une image Docker ayant pour but d'être déployé en production ne devrait jamais démarrer sous l'utilisateur root. Ceci est possible via la directive `USER` mais on trouve finalement sur le net assez peu d'exemples d'utilisation de cette directive dans le but de sécuriser un conteneur. Voyons voir si nous voulons par exemple créer une image d'un conteneur MySQL sécurisé:

````dockerfile
FROM ubuntu:trusty

# Des instructions...
  
# On cré un utilisateur aux droits limités
RUN adduser --disabled-password --gecos "" user1
  
# On utilise cet utilisateur
USER user1

CMD ["mysqld_safe"]
````

Et là on se rend compte que user1 n'a pas les privilèges pour lancer mysqld_safe. Une astuce va donc être d'autoriser user1 à lancer mysqld_safe via le fichier `sudoers`:

````dockerfile
FROM ubuntu:trusty

# Des instructions...

# On cré un utilisateur aux droits limités
RUN adduser --disabled-password --gecos "" user1

# On autorise user1 à lancer mysqld_safe
RUN echo "user1 ALL = (root) NOPASSWD: /usr/bin/mysqld_safe" >> /etc/sudoers

# On utilise cet utilisateur
USER user1

CMD ["sudo", "mysqld_safe"]
````
Le conteneur tourne à présent sous l'utilisateur user1 qui n'a de privilèges que pour lancer mysqld_safe. Si vous rentrez dans le conteneur via `docker exec`, vous êtes connecté via user1 ce qui limite grandement les possibilités d'une personne mal intentionnée.

## Conclusion
Voilà, l'écosystème de Docker en continuelle évolution pousse de plus en plus vers une utilisation en production (et de nombreuses plus ou moins grosses sociétés ont déjà franchi le pas). Il ne faut cependant pas négliger la sécurité qui n'est pas moins importante ou plus facile à mettre en place que dans un système traditionnel sans conteneurs.
