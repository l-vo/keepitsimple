---
title: Installer un serveur mail sur Debian 9 (Stretch)
tags:
  - Linux
date: 2019-03-08 11:34:09
---


Il m'arrive de temps à autre de changer de serveur dedié; pour en prendre un qui corresponde plus à mes besoins du moment ou simplement en faveur d'une offre plus intéressante. Ma grande hantise dans ces moments là, c'est la réinstallation du serveur de mail. N'étant pas "sysadmin", j'y passe à chaque fois beaucoup trop de temps à mon goût, en montant ça à tatons au fil des articles que je trouve ici et là sur le web.  
Ce problème me décide aujourd'hui à écrire un article, qui me permettra d'avoir une doc qui corresponde à mes besoins et que je sois sûr de retrouver la prochaine fois que j'en aurais besoin.
<!-- more -->
Nous allons donc dans cet article configurer un serveur mail gérant plusieurs adresses sur plusieurs domaines. Nous utiliserons des certificats [Let's Encrypt](https://letsencrypt.org/) et nous mettrons en place [SpamAssassin](https://spamassassin.apache.org/) pour la gestion des mails indésirables. Nous installerons également le webmail [Roundcube](https://roundcube.net/). En revanche nous ne gérerons pas dynamiquement l'ajout de nouvelles adresses mail ou de nouveaux domaines. Je l'ai fait par le passé (par curiosité via [PostfixAdmin](http://postfixadmin.sourceforge.net/)), mais n'ayant pas besoin de créer des adresses mail régulièrement ou de donner à un tiers la possibilité d'en créer, je me garderais ici de cette complexité.

Cet article est redigé pas à pas, afin de bien comprendre ce qu'apporte chaque étape. De cette façon, si par exemple vous n'avez besoin que d'un webmail pour vos comptes locaux, vous pourrez très bien suivre ce tutorial et vous arrêter après l'installation du webmail.

On considérera dans cet article que toutes les commandes sont exécutées depuis un compte administrateur.

## Installation de Postfix et mailutils
Pour expédier et recevoir nos emails, nous allons avoir besoin de `Postfix`:
```bash
$ apt-get install postfix
```
Des écrans de configurations vont défiler:
- Lorsque le programme d'installation va demander le type de configuration du serveur de mail, il faut choisir `Internet Site`
- Ensuite un FQDN va être demandé, généralement il doit correspondre au hostname de votre serveur. Quand Postfix reçoit un un mail provenant de ce domaine, il sait qu'il doit le remettre à un compte **local**. Dans nos examples, on considérera que notre FQDN est `mondomaine.tld`.  

L'installation devrait ensuite se terminer.
  
Précédemment lorsque je parle de *compte locaux*, il s'agit de comptes qui correspondent à des utilisateurs sur mon système. La précision est importante car nous utiliserons ensuite dans notre serveur mail des *comptes virtuels* qui ne seront que des boites mails indépendantes qui peuvent être utilisées ou non par des utilisateurs du système. L'utilisateur `moi` sur mon système pourra utiliser le compte mail virtuel `moi @ mondomaine.tld`, mais il pourra aussi y avoir d'autres comptes virtuels (par exemple `webmaster @ mondomaine.tld` ou `foo @ bar.com`) qui ne correspondront à aucun compte local.

Pour continuer notre installation, nous allons avoir besoin d'un binaire de mail, pour envoyer des emails et consulter notre boite aux lettres:
```bash
$ apt-get install mailutils
```

Pour reprendre l'exemple précédent, supposons que le hostname (`/etc/hostname`) de notre serveur soit `mondomaine.tld` et que `moi` soit un utilisateur de ce système; les commandes suivantes devraient envoyer un mail à l'utilisateur `moi`:
```bash
$ echo "Test de mail" | mail -s "Test de mail 1" moi
$ echo "Test de mail" | mail -s "Test de mail 1" moi@mondomaine.tld
```
Pour les consulter, il suffit de se connecter en temps que user `moi` et de taper la commande *mail*:
```bash
$ mail
```
Essayons maintenant d'envoyer un mail vers l'extérieur en supposant que *monmailperso @ monfournisseur.com* soit mon adresse mail perso:
```bash
$ echo "Test de mail vers l'extérieur" | mail -s "Test de mail 3" monmailperso@monfournisseur.com
```

A ce stade il est fort possible que l'email arrive dans les spams. Nous allons voir comment remédier à ça.

## Eviter l'indésirabilité de nos mails
Afin que nos mails n'atterissent pas dans le dossier spam de notre destinataire, certaines précautions sont à prendre.

### Tester l'indésirabilité
[Ce site](https://www.mail-tester.com) permet de vérifier si nos emails risquent d'être classés comme indésirables par le logiciel de messagerie de notre destinataire (attention, vous êtes dans la version gratuite limités à 3 emails testés par jour). Utilisons donc l'adresse email fournie par *mail-tester* avec notre commande précédemment utilisée:
```bash
$ echo "Test de mail vers l'extérieur" | mail -s "Test de mail 3" test-6ad40@mail-tester.com
```
Pour améliorer le score que va vous retourner *mail-tester*, il est nécessaire d'avoir des entrées `SPF` et `DKIM` dans nos DNS. Vous pouvez trouvez un peu plus d'explication sur le rôle de ces entrées [ici](https://www.badsender.com/2014/01/13/delivrabilite-spf-dkim-dmarc/).

### Ajouter une entrée MX dans nos DNS
Cette entrée est nécessaire à SPF, mais au delà, elle permet de specifier le serveur de mail entrant pour un domaine (on peut avoir un site *mondomaine.fr* sur une machine et le serveur web sur une autre machine, donc avec une autre ip c'est pour celà que l'on cré souvent des CNAME du genre *smtp.mondomaine.fr*). Je choisi de suivre ce principe et dans mes DNS d'avoir des enregistrements `CNAME` (alias) de mon domaine `mondomaine.tld`. J'ai donc `smtp.mondomaine.tld` et `imap.mondomaine.tld` qui pointent vers `mondomaine.tld`. Mais ce n'est en rien obligatoire, pour faire sans alias spécifiques smtp/imap il suffit de remplacer dans mes exemples `smtp.mondomaine.tld` et `imap.mondomaine.tld` par simplement `mondomaine.tld`. L'entrée MX est composé d'un chiffre (1) et d'un nom de domaine (ou de sous-domaine):  

```
3600 IN MX 1   smtp.mondomaine.tld.
```
Une fois que le champ MX est en place et qu'il s'est propagé (ça marche souvent tout de suite mais on préfère partir du principe qu'il faut 24h pour que les modifications DNS soient totallement effectives), on doit être en mesure d'envoyer des emails de l'extérieur vers le nom de domaine que l'on a configuré. Pour reprendre notre exemple précédent, nous pouvons envoyer un mail depuis une adresse email quelconque vers `moi @ mondomaine.tld`. Nous devrions voir le mail en se connectant à l'utilisateur `moi` et en utilisant la commande vu précédemment:

```bash
$ mail
```

### Paramétrer SPF
L'idée du SPF, c'est de créer un enregistrement de type `TXT` dans nos DNS mettant en relation l'ip du serveur et le champ MX. Voilà mon enregistrement SPF, `xxx.xxx.xxx.xxx` devant être remplacé par mon adresse ip:  
  
```
3600 IN TXT    "v=spf1 ip4:xxx.xxx.xxx.xxx mx:smtp.mondomaine.tld ~all"
```

### Paramétrer DKIM
Cette partie reprend largement les information de [ce billet](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-dkim-with-postfix-on-debian-wheezy).

D'abord on installe *opendkim*
```bash
$ apt-get install opendkim opendkim-tools
```
On créé ensuite la structure pour les configurations:
```bash
$ mkdir /etc/opendkim
$ mv /etc/opendkim.conf /etc/opendkim/
$ ln -s /etc/opendkim/opendkim.conf /etc/opendkim.conf
$ mkdir /etc/opendkim/keys
# Pour chaque domaine que vous voudrez gérer, il faut créer un répertoire:
$ mkdir /etc/opendkim/keys/mondomaine.tld
```
Configurons opendkim pour utiliser le port 12301 en ajoutant les lignes suivantes à la fin du fichier `/etc/default/opendkim`
```
AutoRestart             Yes
AutoRestartRate         10/1h
UMask                   002
Syslog                  yes
SyslogSuccess           Yes
LogWhy                  Yes

Canonicalization        relaxed/simple

ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable

Mode                    sv
PidFile                 /var/run/opendkim/opendkim.pid
SignatureAlgorithm      rsa-sha256

UserID                  opendkim:opendkim

Socket                  inet:12301@localhost
```
Ainsi que dans la configuration Postfix `/etc/postfix/main.cf`:
```
# DKIM
milter_protocol = 2
milter_default_action = accept
smtpd_milters = inet:localhost:12301
non_smtpd_milters = inet:localhost:12301
```
Nous allons maintenant définir notre ou nos domaines, dans le fichier `/etc/opendkim/TrustedHosts` que nous créons:
```
127.0.0.1
localhost
192.168.0.1/24

mondomaine.tld
monautredomaine.net
encoreunautredomaine.org
```
On continue dans la configuration avec le fichier `/etc/opendkim/KeyTable` (comme précédemment vous devez avoir une ligne par domaine):
```
mail._domainkey.mondomaine.tld mondomaine.tld:mail:/etc/opendkim/keys/mondomaine.tld/mail.private
```
Puis `/etc/opendkim/SigningTable` (toujours une ligne par domaine):
```
*@mondomaine.tld mail._domainkey.mondomaine.tld
```
Voilà pour la conf :). Maintenant générons les clés, une par domaine. Les clés étant générés dans le répertoire courant, il faut donc se déplacer dans le répertoire que vous avez renseigné dans le fichier `KeyTable` pour le domaine.
```bash
$ cd /etc/opendkim/keys/mondomaine.tld
$ sudo opendkim-genkey -s mail -d mondomaine.tld
```
Le fichier `mail.txt` va contenir un enregistrement DNS du genre:
```
mail._domainkey	IN	TXT	( "v=DKIM1; h=sha256; k=rsa; "
	  "p=encodeddata1"
	  "encodeddata2" )
```
Le fichier `mail.private` doit être accessible par opendkim, il faut donc en changer les droits:
```bash
$ chown opendkim:opendkim mail.private
```
Il n'y a plus qu'a copier coller ces données dans vos enregistrements DNS. Au final, entre MX, SPF et DKIM, vos DNS devraient avoir cette allure:
```
$TTL 3600
@	IN SOA xxx.xxxxxx.xxx. xxx.xxxxxx.xxx.
                  3600 IN NS     xxx.xxxxxx.xxx.
                  3600 IN NS     xxx.xxxxxx.xxx.
                  3600 IN A      xxx.xxx.xxx.xxx
imap              3600 IN CNAME  mondomaine.tld.
smtp              3600 IN CNAME  mondomaine.tld.
                  3600 IN MX 1   smtp.mondomaine.tld.
                  3600 IN TXT    "v=spf1 ip4:xxx.xxx.xxx.xxx mx:smtp.mondomaine.tld ~all"
mail._domainkey   3600 IN TXT    ( "v=DKIM1; k=rsa; h=sha256; p=myencodeddata1" "myencodeddata2" )
```
On reload postfix et opendkim
```bash
$ systemctl reload opendkim
$ systemctl reload postfix
```

Si vous réessayez *mail-tester* votre score devrait être meilleur et votre email ne devrait plus tomber dans les spam lorsque vous l'envoyez vers l'extérieur. Cependant comme nous avons modifié les enregistrements DNS, il faut garder à l'esprit que cela peut prendre jusqu'à 24h pour se propager totalement.

### DMARC
Vous avez peut être noté que *mail-tester* nous signale malgré tout une entrée `DMARC` manquante. Sa mise en place est très simple (comme SPF, rien à installer, seulement une entrée DNS à créer), mais nécessite un suivi pour le paramétrage qui dépasse le cadre de cet article. Si vous voulez en savoir plus, je vous invite à lire [cet article](https://www.dmarcanalyzer.com/fr/comment-creer-un-dmarc-record/). Mais en général, les champs SPF et DKIM suffisent pour qu'en message "normal" ne soit pas classé comme spam.

## Installation de Dovecot
Passons maintenant à l'installation de Dovecot. De base le système Linux gère un fichier par utilisateur qui contient tous ses mails (dans notre exemple `/var/mail/moi`). Dovecot va nous permettre d'avoir une structure de type *Maildir* (comme son nom l'indique basé sur des répertoires, avec 1 mail = 1 fichier) et de faire de l'IMAP, c'est à dire de pouvoir consulter les emails via un webmail ou via un client de messagerie, les messages restant synchronisés entre les différents logiciels.
```bash
$ apt-get install dovecot-imapd
```

### Utilisation du format de stockage Maildir
Tout d'abord nous allons demander à Postfix de déposer les emails dans le répertoire `~/Maildir` de l'utilisateur en ajoutant la ligne suivante à la fin du fichier de configuration Postfix `/etc/postfix/main.cf`:
```
home_mailbox = Maildir/
```
On reload Postfix
```bash
$ systemctl reload postfix
```
Si l'on envoi un mail à l'utilisateur courant, un répertoire *Maildir* se créé dans le répertoire *home* de l'utilisateur destinataire. Si l'on parcours ce répertoire, on trouve un fichier dans `~/Maildir/new` qui correspond à notre email. En revanche lorsque l'on essaie de voir le mail via la commande habituelle:
```bash
$ mail
```
Aucun mail ne s'affiche et c'est normal. Il existe une commande `mutt` qui permet de consulter les mails au format *Maildir*, mais elle n'a que peu d'intérêt ici étant donné que nous allons pouvoir utiliser le protocole IMAP pour utiliser un webmail ou un client de messagerie lourd. Préparons Dovecot à cela; d'abord, indiquons lui le format et la localisation des emails; dans le fichier `/etc/dovecot/conf.d/10-mail.conf`, changeons le paramètre *mail_location*:
```
mail_location = maildir:~/Maildir
```
Dovecot permet aussi differents mode d'authentification (fichier `/etc/dovecot/conf.d/10-auth.conf). Si on regarde à la fin de celui-ci, on a les lignes suivantes:
```
!include auth-system.conf.ext
#!include auth-sql.conf.ext
#!include auth-ldap.conf.ext
#!include auth-passwdfile.conf.ext
#!include auth-checkpassword.conf.ext
#!include auth-vpopmail.conf.ext
#!include auth-static.conf.ext
```
Le seul moyen d'authentification actif (décommenté) est celui qui utilise l'authentification système (authentification via le password du user sur le système). C'est bien ce dont on a besoin, rien a modifier pour l'instant dans ce fichier. On recharge Dovecot:
```
$ systemctl reload dovecot
```

## Installation de Roundcube
Nous allons utiliser Roundcube comme webmail. Roundcube nécessite un serveur web (`Apache` ou `nginx`) et une base de donnée `Mysql`. Je vous encourage à regarder les informations plus exhaustives sur la configuration de Roundcube [ici](https://github.com/roundcube/roundcubemail/wiki/Installation).

### Installation et création de la base de donnée MySQL
D'abord, installons mysql et connectons nous en root;
```bash
$ apt-get install mysql-server
$ mysql
```
Nous allons maintenant créer une base dédiée à Roundcube et un utilisateur qu'utilisera notre webmail pour s'y connecter. Bien sûr *monpassword* est pour l'exemple, votre password devra être plus sécurisé, le seul impératif étant de mettre le même dans l'assistant de configuration Roundcube. Donc une fois que l'on a l'invite MySQL:
```mysql
> CREATE DATABASE roundcubemail;
> GRANT ALL PRIVILEGES ON roundcubemail.* TO roundcube@localhost IDENTIFIED BY 'monpassword';
> FLUSH PRIVILEGES;
```

### Mise en place des sources de Roundcube
Téléchargons la dernière version de [Roundcube](https://roundcube.net/download/). On choisira la version *complète* qui évite d'avoir à installer manuellement les dépendances PHP.
  
Téléchargeons et décompressons les sources dans `/var/www/roundcube`:
```bash
$ wget https://github.com/roundcube/roundcubemail/releases/download/1.3.8/roundcubemail-1.3.8-complete.tar.gz
$ tar -zxf roundcubemail-1.3.8-complete.tar.gz
$ rm roundcubemail-1.3.8-complete.tar.gz
$ mv roundcubemail-1.3.8 /var/www/roundcube
$ chown -R www-data: /var/www/roundcube && chmod -R 775 /var/www/roundcube
```

### Installation du serveur web
Nous allons ensuite avoir besoin d'un serveur web. Roundcube est pré-paramétré pour être utilisé avec Apache. Par simplicité c'est donc Apache que nous allons utiliser. Installons Apache2, PHP et les extensions nécessaires à Roundcube (vous pouvez normalement utiliser une version plus récente de PHP si vous le souhaitez, j'utilise la 7.0 parce que c'est celle qui est installée sur Stretch avec la commande *apt-get install php*):
```bash
$ apt-get install apache2 libapache2-mod-php php7.0 php7.0-dom php7.0-gd php7.0-imagick php7.0-intl php7.0-ldap php7.0-mbstring php7.0-mysql php7.0-zip
```
Commençons par une petite config à modifier dans le fichier `/etc/php/7.0/apache2/php.ini`:
```ini
date.timezone = Europe/Paris
```
Si tout s'est bien passé, lorsque vous tapez dans la barre d'adresse de votre navigateur votre nom de domaine qui vous permettra d'accéder à Roundcube (*mondomaine.tld* pour moi), la page d'accueil d'Apache2 devrait s'afficher.

Il faut maintenant créer la configuration du serveur web pour qu'il serve les sources Roundcube; éditons un nouveau fichier `/etc/apache2/sites-available/roundcube.conf` et mettons y le contenu suivant (votre nom de domaine qui va vous permettre d'accéder à l'interface Roundcube doit être en lieu et place de *mondomaine.tld*):
```
<VirtualHost *:80>
        ServerName      mondomaine.tld
        DocumentRoot    /var/www/roundcube
 
        <Directory /var/www/roundcube>
                AllowOverride All
                Order Allow,Deny
                Allow from All
        </Directory>
</VirtualHost>
```
Activons ensuite la configuration Roundcube et désactivons la configuration d'exemple qui affiche la page d'accueil Apache2:
```bash
$ a2dissite 000-default
$ a2ensite roundcube
$ systemctl reload apache2
```

### Configuration de Roundcube
Lançons maintenant l'installateur automatique de Roundcube en utilisant l'url `/installer` depuis votre domaine. Chez moi ce sera donc `http://mondomaine.tld/installer`. Vous pouvez dans la plupart des cas laisser les valeurs par default. Renseignez juste au step 2 *"Create config"* le mot de passe de l'utilisateur *roundcube* pour la base de donnée (*monpassword* dans notre exemple).
Après avoir cliqué sur le bouton *CREATE*, la page *"Create config"* se rechargera indiquant que le fichier de configuration a été créé. Un bouton *Continue* est affiché en dessous pour passer à l'étape *"Test config"*. Ne négligez pas cette étape, elle vous proposera d'initializer la base de donnée via un bouton, sans ça vous ne pourrez rien faire car il vous manquera les tables dans la base. Voilà pour la configuration.

Lorsque vous vous rendez à l'url de base de votre domaine (`http://mondomaine.tld/` pour moi), vous devriez avoir la mire de connexion Roundcube. Vous devriez normalement voir l'email que nous avons envoyé précédemment. Roundcube devrait également vous permettre d'envoyer des mails vers l'extérieur.

Si tout est ok il faut pour des raisons de sécurité supprimer le répertoire d'installation de Roundcube:
```bash
$ rm -rf installer
```
L'installation que nous avons faite ici est vraiment basique, il peut y avoir des ajustements notamment sur la configuration PHP à faire. Je vous encourage par rapport à cela à lire les [recommandations d'installation Roundcube](https://github.com/roundcube/roundcubemail/wiki/Installation). De plus, afin d'éviter que les mots de passe de votre système ne transitent en clair sur le réseau, il vous appartient de [sécuriser votre webmail via https](https://www.memoinfo.fr/tutoriels-linux/configurer-lets-encrypt-apache/).

## Comptes mails virtuels
Là ça va devenir un peu plus intéressant. Parce que même si l'on a pas à gérer plusieurs dizaines d'adresses mail, on ne souhaite pas avoir a créer pour chaque compte mail un compte utilisateur sur le système. De plus, avec le système actuel, comment gérer des adresses d'un autre domaine ? On peut créer un autre domaine qui pointe vers la même machine, mais si on a `moi @ mondomaine1.com` et `moi @ mondomaine2.com` qui appartiennent à deux personnes différentes, les deux adresses arriveront au compte système *moi*. Et lorsque l'on enverra vers l'extérieur, un seul des deux domaines pourra être configuré, si c'est *mondomaine1.com* on ne pourra jamais envoyer des mails à partir de l'adresse `moi @ mondomaine2.com`. La solution à ces problèmes sont les comptes mails virtuels.

Nous avons tout d'abord besoin d'un groupe et d'un utilisateur système qui va avoir accès aux boites mail virtuelles. Nommmons le `vmail` et attribuons lui l'id `2222`:
```bash
$ groupadd vmail -g 2222
$ useradd vmail -r -g 2222 -u 2222 -d /var/vmail -m
```
### Paramétrage de Postfix
Dans le répertoire `/etc/postix`, créons un fichier `vhosts` qui contiendra les domaines pour lesquels on veut gérer les emails (un par ligne):
```
mondomaine.tld
monautredomaine.net
encoreunautredomaine.org
```
Ensuite créons un fichier `valiases`, vous n'aurez probablement pas besoin de le remplir, il permet de créer des alias de comptes de messagerie, par exemple si je veux masquer l'adresse perso de quelqu'un, je pourrais afficher sur mon site `quisuisje@mondomaine.tld`, et dans mon fichier *vialiases*:
```
quisuisje@mondomaine.tld  unemailperso@gmail.com
```
Mais dans la plupart des cas, vous n'aurez pas besoin de mettre de contenu dans ce fichier.  
  
Enfin, l'indispensable fichier `vmaps`, qui va indiquer les chemins relatifs des boites mails dans le dossier `/var/vmail`. Le format est libre mais en général on chosi de regrouper par domaine pour le cas ou des noms existeraient dans plusieurs domaines. Attention à ne pas oublier le `/` de fin, il est particulièrement important car il détermine que nous allons utiliser le format *Maildir* et non *mbox*:
```
moi@mondomaine.tld                mondomaine.tld/me/
monmail1@monautredomaine.net      monautredomaine.net/monmail1/
monmail2@monautredomaine.net      monautredomaine.net/monmail2/
monmail1@encoreunautredomaine.org encoreunautredomaine.org/monmail1/
monmail3@encoreunautredomaine.org encoreunautredomaine.org/monmail3/
```

"Hashons" en table les fichiers maps et aliases. Ce format permet de ne pas avoir à reloader Postfix lorsque ces fichiers sont modifiés.
```bash
$ postmap /etc/postfix/valiases
$ postmap /etc/postfix/vmaps
```
Et ajoutons les paramètrages suivants dans `/etc/postfix/main.cf`:
```
virtual_mailbox_domains = /etc/postfix/vhosts
virtual_mailbox_base = /var/vmail
virtual_mailbox_maps = hash:/etc/postfix/vmaps
virtual_minimum_uid = 2222
virtual_uid_maps = static:2222
virtual_gid_maps = static:2222
virtual_alias_maps = hash:/etc/postfix/valiases
```
Tout en supprimant (ou commentant) celui-ci qui devient inutile:
```
#home_mailbox = Maildir/
```
Et surtout en enlevant votre domaine (*mondomaine.tld* pour moi) du paramètre `$mydestination`. Ainsi Postfix sait qu'il ne doit plus delivrer le mail à un utilisateur système pour le domaine que l'on vient d'enlever. La conséquence sera que nos utilisateurs systèmes utiliseront des boites virtuelles.  
   
Rechargeons Postfix:
```bash
$ systemctl reload postfix
```
Vous pouvez maintenant envoyer un email au compte virtuel créé (ou à l'un des comptes virtuels créés), vous devriez constater que la structure au format *Maildir* s'est créé pour votre compte dans `/var/vmail`.

### Paramétrage de Dovecot
Pour consulter l'email précédemment envoyé, il faut maintenant configurer Dovecot. Nous allons avoir deux choses à modifier dans Dovecot; la nouvelle localisation des mails (`/var/vmail`) et la façon de s'authentifier (les utilisateurs ne correspondant plus à des comptes systèmes, on n'a plus de mots de passe !).
Tout d'abord modifions la localisation des boites mails (qui doivent être dans le répertoire `/var/vmail`), avec l'arborescence en accord avec ce que l'on a défini dans Postfix. Effectuons cette modif dans `/etc/dovecot/conf.d/10-mail.conf` (vous pouvez trouver la signification de %d et %n dans les commentaires de ce fichier):
```
mail_location = maildir:/var/vmail/%d/%n
```
Ensuite à la fin du fichier `/etc/dovecot/conf.d/10-auth.conf`, nous allons remplacer l'authentification "système" par une authentification à base de fichier password:
```
#!include auth-system.conf.ext
#!include auth-sql.conf.ext
#!include auth-ldap.conf.ext
!include auth-passwdfile.conf.ext
#!include auth-checkpassword.conf.ext
#!include auth-vpopmail.conf.ext
#!include auth-static.conf.ext
```
Paramétrons ensuite le fichier `/etc/dovecot/conf.d/auth-passwdfile.conf.ext`, son contenu devra être le suivant:
```
auth_mechanisms = plain cram-md5
passdb {
  driver = passwd-file
  args = scheme=sha512-crypt /etc/sha512-crypt.pwd
}

userdb {
  driver = static
  args = uid=vmail gid=vmail home=/var/vmail/%d/%n
}
```
Pour résumer cette configuration, on va mettre les mots de passes cryptés au format sha512 dans un fichier /etc/sha512-crypt.pwd. Le méchanisme d'authentification est dit "plain-text", ce qui signifie que les mots de passe transitent en clair sur le réseau. Pour palier à ce problème, les connexions doivent être cryptées, c'est pour cela que le webmail précédemment mis en place doit être protégé par une connexion sécurisée. Je ne m'attarderais pas plus sur cette partie qui sort un peu du cadre de cette article, même si l'on reparlera brièvement de connexion sécurisée et de *Let's Encrypt un peu plus loin*.

A noter que là aussi on doit passer le chemin du stockage des mails virtuels.

Pour générer un mot de passe au format sha512, vous pouvez utiliser la commande fournie par Dovecot:
```bash
$ doveadm pw -s sha512-crypt
```

Le fichier `/etc/sha512-crypt.pwd` doit être au format user:mot_de_passe_crypte, ainsi votre fichier devrait ressembler plus ou moins à ça:
```
moi@mondomaine.tld:{SHA512-CRYPT}$6$IIqxym0pZk32SFlQ$sC04yUm9EX5xvTYWxqKGk5T94ehqbnQgkJZSrOXRBk/1PF/2/kIMvHOZMCEHSp43nG9VZ6p06SCbPTOPWns020
monmail1@mondomaine2.fr:{SHA512-CRYPT}$6$b5syhg6XjqU9ppTQ$lKRxY5VlfMldDghGl1RdCnyhPDVDyrL/tRy6z2wYMFdWO6ZMLhJdseindT6MCySkjjdYvzVbYpA4sNk2qnC3X1
monmail2@mondomaine2.fr:{SHA512-CRYPT}$6$n94IadnRSXEJ.yio$kohBaVSbtJwieU2PIbxVCuP0vpxGSed8Qz3rA8252AQ5Kai4MnPCr4mVc8SLXHdj7J8zowz181pLEDwZdBny60
monmail1@mondomaine3.com:{SHA512-CRYPT}$6$7zYKwZRZ3Yeu6k/L$qDU3FpO2yTsMISP/8z8Pza1WL5SzKu.votfyhY8jVvT7f5/8H4AifgluJB.HGaNCQB5qzctKLIrQ2.rAMbZl1.
monmail3@mondomaine3.com:{SHA512-CRYPT}$6$m5LIbqaGfkSVh8xb$rXUtjG2eeRJu/CA6HMMGQ6jB8fVxgXhl/QXW4MoKA4zaZ7jB1gt/VpwEtPNc5pQZKi0wvX0wttmVm6v2BXyd2.
```
On reload Dovecot:
```bash
$ systemctl reload dovecot
```
Vous devriez maintenant être en mesure de vous connecter à Roundcube via l'utilisateur virtuel et le mot de passe que vous avez choisi. Vous devriez pouvoir consulter le mail que l'on a précédemment envoyé pendant la configuration de Postfix, et également en envoyer vers l'extérieur.
Nous sommes désormais en mesure de créer autant de compte mails que nous le souhaitons sur les différents domaines qui nous appartiennent. Notre principale restriction est maintenant que nous ne pouvons consulter/envoyer des emails que par l'intérmédiaire d'un webmail.

## Utilisation d'un client mail
Pour être en mesure d'utiliser un client mail, il va nous falloir un moyen de d'authentifier les requêtes du client. Nous allons pour cela simplement nous appuyer sur le système déjà mis en place sur Dovecot.

Dans la section `service auth` du fichier `/etc/dovecot/conf.d/10-master.conf` ajoutons les lignes suivantes:
```
# Postfix smtp-auth
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user=postfix
    group=postfix
  }
```

Indiquons à Postfix que nous allons utiliser Dovecot pour l'authentification SASL en ajoutant dans `/etc/postfix/main.cf`
```
smtpd_sasl_auth_enable = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
```
Comme nous entrons dans le monde des connexions sécurisées et des certificats, il va nous falloir un certificat pour utiliser la connexion avec notre serveur mail. Vous pouvez utiliser le certificat "snake-oil" par default en décommentant ces lignes (toujours dans `main.cf`):
```
smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
smtpd_use_tls=yes
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache
```
Cependant ce n'est pas le plus secure et pour cette raison tous les clients mails ne l'acceptent pas. Et puis même si vous n'avez pas de "vrai" certificat longue durée associé à votre domaine, utiliser un certificat par défaut alors que *Let's Encrypt*
 fait des merveilles serait un crime. Un prochain billet est prévu prochainement pour vous parler un peu de ce fantastique outil :). En utilisant Let's Encrypt, la configuration est chez moi:
```
smtpd_tls_CAfile = /etc/letsencrypt/live/imap.mondomaine.tld/chain.pem
smtpd_tls_cert_file = /etc/letsencrypt/live/imap.mondomaine.tld/cert.pem
smtpd_tls_key_file = /etc/letsencrypt/live/imap.mondomaine.tld/privkey.pem
smtpd_use_tls=yes
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache
```
Vous noterez que mon certificat se nomme *imap.mondomaine.tld*, c'est un certificat multi-domaine qui inclus imap.mondomaine.tld, smtp.mondomaine.tld ainsi que les entrées imap/smtp de mes autres domaines. Let's encrypt nomme le certificat avec le premier domaine de la commande, donc ici imap.mondomaine.tld.

Rajoutons également cette ligne qui va nous permettre de chiffrer les emails:
```
smtp_tls_security_level = may
```


A tout seigneur, tout honneur, il faut également permettre à Postfix d'utiliser le port `587`, port par convention pour les connexions sécurisées. Décommentons les lignes ci-dessous du fichier `/etc/postfix/master.cf`:
```
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=$mua_client_restrictions
  -o smtpd_helo_restrictions=$mua_helo_restrictions
  -o smtpd_sender_restrictions=$mua_sender_restrictions
  -o smtpd_recipient_restrictions=
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
```

Associons également notre certificat aux requêtes sur le port `465`. Dans le fichier `/etc/dovecot/conf.d/10-ssl.conf`, activons ssl et ajoutons notre certificat:
```
ssl = yes
# ...
ssl_cert = </etc/letsencrypt/live/imap.mondomaine.tld/fullchain.pem
ssl_key = </etc/letsencrypt/live/imap.mondomaine.tld/privkey.pem
```

Reloadons Postfix et Dovecot pour prendre en compte les modifications:
```bash
$ systemctl reload postfix
$ systemctl reload dovecot
```
En configurant votre client mail sur les ports `587` (pour le courrier sortant) et `465` (pour le courrier entrant), cela avec une connexion chiffrée `STARTTLS`, vous devriez être capable d'envoyer des emails (désormais chiffrés) sans avoir à passer par le webmail.

## Gestion du spam avec SpamAssassin et Procmail
Avec la possibilité d'utiliser un webmail ou un client mail et en envoyant des emails chiffrés, on a de quoi pouvoir utiliser nos emails presque normallement. Presque car nous n'avons pas encore géré le fléau du monde numérique moderne, le spam. Nous allons utiliser pour cela deux outils, `SpamAssassin` qui va détecter les emails de spam et les flagger, et `Procmail` qui permet de déplacer dans des dossiers des mails qui répondent à des critères choisis.

### Mise en place de SpamAssassin
Je vais ici plus ou moins reprendre les très bonnes explications de [cet article](http://www.sublimigeek.fr/comment-installer-spamassassin-sur-son-serveur). N'hésitez pas à lire cet article qui est plus détaillé sur la partie SpamAssassin.

Installons l'outil ainsi que *spamc* qui est nécessaire:
```bash
$ apt-get install spamassassin spamc
```
Crééons un utilisateur spécifique `spamd`:
```bash
$ useradd --home /var/spamassassin --create-home --system spamd
```
On change le propriétaire de `/var/lib/spamassassin`:
```bash
$ chown spamd: /var/lib/spamassassin
```
Ensuite il faut faire quelques modifications dans la configuration du démon SpamAssassin dans le fichier `/etc/default/spamassassin`:
```
ENABLED=1
# ...
OPTIONS="--create-prefs --max-children 5 --helper-home-dir --username spamd -H /var/lib/spamassassin -s /var/log/spamd.log"
```
Maintenant, il faut mettre en place SpamAssassin en tant que filtre Postfix. Dans le fichier `/etc/postfix/main.cf`, rajoutons **-o content_filter=spamassassin** à la ligne qui gère le port smtp. ça devrais nous donner:
```
smtp      inet  n       -       y       -       -       smtpd
  -o content_filter=spamassassin
```
Toujours dans le fichier `master.cf` (à la fin de préférence), déclarons le filtre proprement dit:
```
spamassassin unix  -       n       n       -       -       pipe
   user=spamd argv=/usr/bin/spamc -f -e
   /usr/sbin/sendmail - oi -f ${sender} ${recipient}
```

Maintenant nous allons rédiger nos règles de spam dans le fichier `/etc/spamassassin/local.cf`; j'utilise le paramétrage l'article de sublimigeek, à vous d'adapter ensuite à l'usage:
```
rewrite_header Subject *****SPAM***** 
required_score 3.0 
report_safe 0
use_bayes 1
bayes_auto_learn 1 
```

Enfin on démarre SpamAssassin et on redémarre Postfix (le reload ne suffit pas):
```bash
$ systemctl start spamassassin
$ systemctl restart postfix
```

Si vous envoyez un mail avec comme corps `XJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X`, cela devrait générer un faux positif et vous devriez voir ajouter `*****SPAM*****` à l'objet de votre message. Voyons maintenant comment les classer dans un dossier "Spam".

### Installation et configuration de Procmail
Installons le logiciel:
```bash
$ apt-get install procmail
```

Pour utiliser Procmail, il faut le définir en temps que transport pour Postfix; créons le fichier `/etc/postfix/transport` avec une ligne pour chacun de vos comptes:
```
moi@mondomaine.tld                procmail
monmail1@monautredomaine.net      procmail
monmail2@monautredomaine.net      procmail
monmail1@encoreunautredomaine.org procmail
monmail3@encoreunautredomaine.org procmail
```
"Hashons" le fichier:
```bash
$ postmap /etc/postfix/transport
```
Et renseignons la table nouvellement créée dans la configuration Postfix en ajoutant à `/etc/postfix/main.cf` ces lignes:
```
procmail_destination_recipient_limit = 1
transport_maps = hash:/etc/postfix/transport
```
Détaillons maintenant ce "transport" dans `/etc/postfix/master.cf`; un peu à la manière de ce que l'on a fait pour SpamAssassin on ajoute à la fin:
```
procmail unix - n n - - pipe
  flags=RO user=vmail argv=/usr/bin/procmail -t -m USER=${user} EXTENSION=${extension} DOMAIN=${nexthop} /etc/postfix/procmailrc.common
```
On renseigne ici l'utilisateur paramétré pour gérer nos comptes mails virtuels, un fichier de configuration (/etc/postfix/procmailrc.common`) et des variables qui pourront être utilisées dans ce fichier. Créons le maintenant avec le contenu suivant.
```
MAILDIR="$HOME/$DOMAIN/$USER"
DEFAULT="$MAILDIR/"
VERBOSE=ON
#each user will set his own log file
LOGFILE="/var/vmail/proclog-$DOMAIN-$USER"
NL="
"
WS="    "
SWITCHRC="$HOME/$DOMAIN/.procmail/$USER"
```
Pour faire simple, cela nous permet de créer dans le répertoire correspondant à notre domaine (*/var/vmail/mondomaine.tld* pour suivre notre exemple) un dossier `.procmail` qui pourra contenir des fichiers au nom de chaque user. Chaque fichier definira les règles procmail concernant cet utilisateur. Ajoutons donc une règle Procmail pour l'utilisateur "moi" en insérant dans un fichier `/var/vmail/mondomaine.tld/.procmail/moi`:
```
:0fw: spamassassin.lock
* < 256000
| spamc

:0:
* ^X-Spam-Status: Yes
{
  # Move and mark as read
  # First deliver to maildir so LASTFOLDER gets set
  :0 c
  .Spam/new

  # Manipulate the filename
  :0 ai
  * LASTFOLDER ?? ()\/[^/]+^^
  |mv "$LASTFOLDER" "$MAILDIR/.Spam/cur/$MATCH:2,S"
}
```
Cette configuration nous permet de marquer comme lus et de ranger dans un dossier Spam les messages qui ont été précédemment flaggés par SpamAssassin. Pour plus d'info sur la syntaxe Procmail, vous pouvez consulter [ce wiki](https://wiki.archlinux.org/index.php/Procmail).

Reloadons Postfix:
```
$ systemctl reload postfix
```

Il manque juste une petite chose pour que notre système fonctionne, c'est que l'on a pas de répertoire "Spam", et sans ça, notre règle Procmail ne peut fonctionner. Dans `/etc/dovecot/conf.d/15-mailboxes.conf`, dans la section `namespace inbox` là ou sont déclarés les répertoires avec une fonction particulière (Trash, Send...), nous allons configurer la création automatique d'un répertoire "Spam" en ajoutant la configuration suivante:
```
mailbox Spam {
  auto = subscribe
}
```
On reload Dovecot:
```
$ systemctl reload dovecot
```
Voilà, si vous allez sur le webmail (déconnectez-vous et reconnectez si vous étiez déjà connecté), vous devriez maintenant voir un répertoire Spam. Et si vous envoyez un test de spam, celui ci devrait se retrouver en "lu" dans le répertoire Spam.
