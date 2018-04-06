---
title: Debug facile avec XDEBUG
date: 2018-04-06 20:48:05
tags:
  - PHP
---
Intéressons nous au debugging d'applications. Tout développeur en fait continuellement dans ses projects. Souvent de la façon la plus basique qui soit:
```php
echo $myVar; exit();
```
Mais lorsque l'on a besoin de suivre l'execution dans une pile de plusieurs fonctions et à l'intérieur de chacune d'elle visualiser plusieurs variables pour connaitre le contexte, la méthode ci-dessus ne suffit plus. C'est là qu'intervient XDEBUG.

## Quand utiliser XDEBUG ?
Parce qu'il ralentit considérablement l'application, XDEBUG ne doit pas être utilisé dans des environnements de production. En revanche son utilisation est conseillée en environnement de développement. Au delà du débuggage, XDEBUG peut aussi faire du profilage d'application (pour localiser les parties "gourmandes" de votre code), ou encore génerer la couverture de code de vos tests couplé à PHPUnit. Nous nous intéresserons dans cet article uniquement à la partie débuggage.

## Installation, configuration et utilisation basique de XDEBUG
Pour installer XDEBUG depuis un serveur Debian, rien de très compliqué:
```bash
$ sudo apt-get update && sudo apt-get install php5-xdebug
```
### Communication avec le serveur ou se trouve l'IDE
Si l'application que vous souhaitez débugger n'est pas sur la même machine que votre IDE (ou si votre application est dans une VM ce qui est le plus courant), vous allez devoir configurer le remote host de XDEBUG.
* La méthode la plus simple et qui fonctionne dans la plupart des cas est de mettre le paramètre `xdebug.remote_connect_back` à `On` (ou `1`, ces valeurs étant équivalentes). XDEBUG essaiera simplement de se connecter à l'IP d'ou provient la requête (si un proxy se trouve devant votre application, xdebug checkera les headers `HTTP_X_FORWARDED_FOR` et `REMOTE_ADDR`, voir un autre header configuré dans le paramètre ` xdebug.remote_addr_header` si renseigné. On considérera être dans ce cas dans nos exemples.
* Si `xdebug.remote_connect_back` ne fonctionne pas, vous pouvez spécifier l'IP de la machine ou se trouve votre IDE (ou l'IP de votre machine hôte depuis votre VM) dans le paramètre `xdebug.remote_host`.

Vous trouverez des informations plus completes sur le paramètrage de xdebug sur le site officiel: https://xdebug.org/docs/all_settings.


### Debbugger les scripts CLI PHP

Il y a plusieurs façons de lancer une session de débuggage avec un script CLI PHP.

#### Déclenchement à l'aide d'une variable d'environnement

Supposons notre config telle que ci-dessous:
```
// /etc/php5/cli/conf.d/20-xdebug.ini
zend_extension=/usr/lib/php5/20100525/xdebug.so
xdebug.remote_enable=On
xdebug.remote_connect_back=On
```
Le mode débuggage peut s'enclencher à l'aide d'une variable d'environnement:

```bash
$ export XDEBUG_CONFIG="idekey=ma-valeur-quelconque" # Start debugging session
$ php monscript.php
$ unset XDEBUG_CONFIG # stop debugging session
```

Sur l'IDE PHPSTORM que j'utilise, lorsqu'on lance un script CLI pour le débugger, c'est cette façon de faire qui est utilisée. L'IDE lance le script avec une `idekey` aléatoire, écoute les informations de débuggage qui arrivent avec cette `idekey` et dans le cas d'un serveur distant (ou VM) utilise les mappings définis dans l'IDE pour l'interpréteur distant afin de savoir à quels fichiers locaux correspondent les fichiers distants en cours d'exécution.

Vous pouvez aussi choisir de lancer le script directement sur votre machine distante (ou VM) et vous contenter découter toutes les connections de débuggage entrant dans votre IDE. Sur PHPSTORM par exemple, si l'on procède comme ça il nous manquera les informations de mapping. Il faut donc aussi définir la variable d'environnement `PHP_IDE_CONFIG` qui va faire référence à un une configuration de serveur que vous avez defini dans PHPSTORM. Ce sont les mappings définis dans cette configuration qui seront utilisés (plus d'infos ici: https://www.jetbrains.com/help/phpstorm/zero-configuration-debugging.html#d468732e672).

Une des limitation de cette méthode est que si un autre script CLI est lancé pendant votre session de débuggage (par un cron par exemple ou manuellement), il bénéficiera des variables d'environnement définies et sera également lancé en mode débuggage.

#### Déclenchement en modifiant la configuration XDEBUG à la volée

Une autre possibilité est d'utiliser le paramètre -d de PHP pour modifier sa configuration uniquement pour le script que l'on lance:
```bash
$ php -dxdebug.remote_enable=1 -dxdebug.remote_connect_back=1 -dxdebug.xdebug.remote_autostart=1 monscript.php
```
Le débuggage est ici déclenché par `xdebug.xdebug.remote_autostart`. Mettre cette directive dans votre fichier xdebug.ini serait bien trop coûteux car tous les scripts seraient lancés en mode débuggage; mais il peut être intéressant de l'utiliser uniquement pour le script que l'on souhaite débugger. Vous pouvez aussi bien sûr mettre `xdebug.remote_enable` et `xdebug.remote_connect_back` dans votre fichier xdebug.ini et simplement affecter `xdebug.remote_autostart` à la volée (via le paramètre php -d).

#### Désactivation/Activation complète de XDEBUG

Selon la puissance de votre serveur ou VM, il arrive parfois que de laisser XDEBUG activé soit trop coûteux. Même si aucune session de débuggage n'est déclenchée, la présence de XDEBUG provoque malgré tout une grosse baisse des performances. Vous pouvez donc choisir de n'activer XDEBUG que lorsque vous voulez utiliser le débugger:
```
// /etc/php5/cli/conf.d/20-xdebug.ini
zend_extension=/usr/lib/php5/20100525/xdebug.so
xdebug.remote_enable=On
xdebug.remote_connect_back=On
```
  
```bash
$ sudo php5enmod xdebug
$ php -dxdebug.xdebug.remote_autostart=1 monscript.php
$ sudo php5dismod xdebug
```

Vous pouvez bien sûr aussi choisir de mettre le paramètre `xdebug.xdebug.remote_autostart` dans le fichier de configuration xdebug.ini. ça vous évitera de toujours devoir rajouter ce paramètre à la volée mais il faut garder à l'esprit que tout autre script CLI lancé pendant que XDEBUG est activé sera automatiquement en mode débuggage.

### Debbugger un site web en PHP
Pour débugger un site web, le principe reste le même. Vous pouvez bien sûr utiliser `xdebug.xdebug.remote_autostart` mais déclencher systématiquement une session de debuggage étant rarement le but recherché, on préférera utiliser le cookie `XDEBUG_SESSION`. Vous pouvez affecter la valeur que vous souhaitez à ce cookie, le principe est le même qu'avec `idekey`, sa présence déclenche une session de débuggage. Et de la même façon, si vous lancez votre page en débuggage depuis votre IDE, votre IDE écoutera les connexions entrantes avec le cookie `XDEBUG_SESSION` ayant la même valeur que celle qu'il aura passé au lancement de la page. Si vous ne lancez pas votre page depuis votre IDE, un cookie peut facilement être ajouté avec les outils "développeur" de votre navigateur. Vous pouvez aussi passer à l'url le paramètre `XDEBUG_SESSION_START` qui provoquera la création du cookie `XDEBUG_SESSION`:

`http://www.monsite.com?XDEBUG_SESSION_START=ma-valeur-quelconque`

### Aller plus loin
Arrivé ici, nous savons débugger un script CLI et un site web. Mais quid si l'on souhaite débugger une API ? Le principe reste le même !

#### API REST
Si vous utilisez un outil tel que Postman (par exemple) pour exécuter vos requêtes REST, il vous suffit simplement de rajouter le paramètre `XDEBUG_SESSION_START` à vos urls comme vu précédemment.

Si l'appel à votre API est effectuée au milieu du code de votre application, il vous suffit d'envoyer un cookie `XDEBUG_SESSION`; par exemple avec le client http Guzzle:

```php
$client = new \GuzzleHttp\Client();
$cookieJar = GuzzleHttp\Cookie\CookieJar::fromArray([
  'XDEBUG_SESSION' => 'ma-valeur-quelconque'
], 'monapi.com');
$res = $client->request('GET', 'http://monapi.com/maressource.php', $cookieJar);
```

#### API SOAP

Si vous utilisez un outil comme SoapUI, il faut ajouter le paramètre `XDEBUG_SESSION_START` à l'url de votre fichier wsdl.

Si l'appel à votre API est effectuée au milieu du code de votre application, même fonctionnement que pour une API REST, on ajoute le cookie `XDEBUG_SESSION` dans le code:

```php
$client = new \SoapClient('http://www.monapi.com);
$client->__setCookie('XDEBUG_SESSION', 'ma-valeur-quelconque');
$client->mamethode($monparam);
```

## Conclusion
Voilà ! j'espère que ce petit tour d'horizon vous aura permis de mieux appréhender le fonctionnement de XDEBUG :)