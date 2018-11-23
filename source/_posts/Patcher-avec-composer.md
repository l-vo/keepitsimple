---
title: Patcher avec composer
tags:
  - PHP
  - Composer
date: 2018-11-24 09:46:18
---

Récemment, sans rien que nous ayons modifié de particulier, `simple-phpunit` ()qui lance nos tests Symfony) ne fonctionnait plus. Plus embêtant encore, ce problème faisait échouer nos CI. Après une courte investiguation, il s'est avéré que `simple-phpunit` (maintenu par Symfony) reposait sur des branches de PHPUNIT. Certaines anciennes branches ayant été supprimés du repository (probablement car elles vont cesser d'être maintenues), `simple-phpunit` ne pouvait plus fonctionner.

# Quelle solution ?
<!-- more -->
Le problème a rapidemment été corrigé du côté de Symfony (https://github.com/symfony/symfony/pull/29265). Sur notre projet nous sommes sur la version `3.4.17` de `symfony/phpunit-bridge`. Le fix a été mergé sur la branche `3.4`, mais nous ne pouvons pas en bénéficier via Composer tant qu'un nouveau tag n'est pas créé et poussé sur Packagist.  
La solution la plus simple est de passer sur la branche `3.4`:
```javascript
// composer.json
{
    //...
    "require-dev": {
      "symfony/phpunit-bridge": "dev-3.4"
    }
    //...
}
```
```bash
$ composer update symfony/phpunit-bridge
```
Seulement problème, on abandonne le fait d'être sur une version "tagguée", c'est à dire une version stable.
Une meilleure solution va être d'appliquer un patch via un plugin Composer.

# Plugin composer
Plusieurs plugins Composer pour appliquer des patches existent. J'ai choisi le premier affiché par Google, il semblait maintenu et la doc claire: [cweagans/composer-patches](https://github.com/cweagans/composer-patches). Installons le:
```bash
$ composer require cweagans/composer-patches ^1.0
```
Avant de s'intéresser au patch proprement dit, assurons nous d'être sur la dernière version de `symfony/phpunit-bridge` (en accord avec nos contraintes de version).
```javascript
// composer.json
{
    //...
    "require-dev": {
      "symfony/phpunit-bridge": "^3.4.18"
    }
    //...
}
```
```bash
$ composer update symfony/phpunit-bridge
```
La version `3.4.18` se trouve installée.

# Création du patch
Nous sommes sur le tag `3.4.18` mais le fix a été appliqué sur un commit plus avancé de la branche `3.4`. Il va nous falloir générer la différence (le patch) entre le commit sur lequel porte le tag `3.4.18` et le commit fixant le bug. Le fait que la modification ne porte que sur le fichier `simple-phpunit` et qu'aucune autre modification n'ai été faite sur ce fichier nous facilite grandement la tâche:
```bash
$ git clone https://github.com/symfony/symfony.git
$ cd symfony
$ git diff 3.4.18..dbb0f2 src/Symfony/Bridge/PhpUnit/bin/simple-phpunit > phpunit-bridge.patch
```
`dbb0f2` étant le commit du fix, voici le contenu du fichier de patch ainsi généré:
```diff
diff --git a/src/Symfony/Bridge/PhpUnit/bin/simple-phpunit b/src/Symfony/Bridge/PhpUnit/bin/simple-phpunit
index bcfc432f8a..af60eb0f8c 100755
--- a/src/Symfony/Bridge/PhpUnit/bin/simple-phpunit
+++ b/src/Symfony/Bridge/PhpUnit/bin/simple-phpunit
@@ -11,7 +11,7 @@
  */

 // Please update when phpunit needs to be reinstalled with fresh deps:
-// Cache-Id-Version: 2017-11-22 09:30 UTC
+// Cache-Id-Version: 2018-11-20 15:30 UTC

 error_reporting(-1);

@@ -63,26 +63,7 @@ if (!file_exists("$PHPUNIT_DIR/phpunit-$PHPUNIT_VERSION/phpunit") || md5_file(__
     if (file_exists("phpunit-$PHPUNIT_VERSION")) {
         passthru(sprintf('\\' === DIRECTORY_SEPARATOR ? '(del /S /F /Q %s & rmdir %1$s) >nul': 'rm -rf %s', "phpunit-$PHPUNIT_VERSION"));
     }
-    if (extension_loaded('openssl') && ini_get('allow_url_fopen') && !isset($_SERVER['http_proxy']) && !isset($_SERVER['https_proxy'])) {
-        $remoteZip = "https://github.com/sebastianbergmann/phpunit/archive/$PHPUNIT_VERSION.zip";
-        $remoteZipStream = @fopen($remoteZip, 'rb');
-        if (!$remoteZipStream) {
-            throw new \RuntimeException("Could not find $remoteZip");
-        }
-        stream_copy_to_stream($remoteZipStream, fopen("$PHPUNIT_VERSION.zip", 'wb'));
-    } elseif ('\\' === DIRECTORY_SEPARATOR) {
-        passthru("certutil -urlcache -split -f \"https://github.com/sebastianbergmann/phpunit/archive/$PHPUNIT_VERSION.zip\" $PHPUNIT_VERSION.zip");
-    } else {
-        @unlink("$PHPUNIT_VERSION.zip");
-        passthru("wget -q https://github.com/sebastianbergmann/phpunit/archive/$PHPUNIT_VERSION.zip");
-    }
-    if (!class_exists('ZipArchive')) {
-        throw new \Exception('simple-phpunit requires the "zip" PHP extension to be installed and enabled in order to uncompress the downloaded PHPUnit packages.');
-    }
-    $zip = new ZipArchive();
-    $zip->open("$PHPUNIT_VERSION.zip");
-    $zip->extractTo(getcwd());
-    $zip->close();
+    passthru("$COMPOSER create-project --no-install --prefer-dist --no-scripts --no-plugins --no-progress --ansi phpunit/phpunit phpunit-$PHPUNIT_VERSION \"$PHPUNIT_VERSION.*\"");
     chdir("phpunit-$PHPUNIT_VERSION");
     if ($SYMFONY_PHPUNIT_REMOVE) {
         passthru("$COMPOSER remove --no-update ".$SYMFONY_PHPUNIT_REMOVE);
@@ -214,7 +195,7 @@ if ($components) {
             // STATUS_STACK_BUFFER_OVERRUN (-1073740791/0xC0000409)
             // STATUS_ACCESS_VIOLATION (-1073741819/0xC0000005)
             // STATUS_HEAP_CORRUPTION (-1073740940/0xC0000374)
-            if ($procStatus && ('\\' !== DIRECTORY_SEPARATOR || !extension_loaded('apcu') || !ini_get('apc.enable_cli') || !in_array($procStatus, array(-1073740791, -1073741819, -1073740940)))) {
+            if ($procStatus && ('\\' !== DIRECTORY_SEPARATOR || !extension_loaded('apcu') || !filter_var(ini_get('apc.enable_cli'), FILTER_VALIDATE_BOOLEAN) || !in_array($procStatus, array(-1073740791, -1073741819, -1073740940)))) {
                 $exit = $procStatus;
                 echo "\033[41mKO\033[0m $component\n\n";
             } else {
```
Il reste cependant un problème à corriger, le patch porte sur `src/Symfony/Bridge/PhpUnit/bin/simple-phpunit` car nous l'avons généré depuis le repository Symfony. Dans notre projet le chemin n'est pas le même: `vendor/symfony/phpunit-bridge/bin/simple-phpunit`. Il faut donc modifier les paths dans notre fichier patch `phpunit-bridge.patch`.  
On obtient (les autres lignes restent inchangées):
```diff
diff --git a/vendor/symfony/phpunit-bridge/bin/simple-phpunit b/vendor/symfony/phpunit-bridge/bin/simple-phpunit
index bcfc432f8a..af60eb0f8c 100755
--- a/vendor/symfony/phpunit-bridge/bin/simple-phpunit
+++ b/vendor/symfony/phpunit-bridge/bin/simple-phpunit
@@ -11,7 +11,7 @@
```

# Appliquons le patch
Après avoir déplacé le `phpunit-bridge.patch` à la racine de notre projet (par exemple), il faut le renseigner dans notre composer.json:
```javascript
{
  //...
  "extra": {
    //...
    "patches": {
      "symfony/phpunit-bridge": {
        "Fix impossible to download phpunit zip since minor version branches has been deleted": "phpunit-bridge.patch"
    }
    //...
  }
  //...    
}
```
On déclenche ensuite l'application du patch:
```bash
$ composer update symfony/phpunit-bridge
```
On peut constater que que Composer applique le patch conformément au fichier que l'on a généré. Lorsque nous monterons de version `symfony/phpunit-bridge`, le fix sera déjà intégré dans la version téléchargée et le patch ne sera plus utile.

# Conclusion
Nous venons de voir comment générer un patch et l'appliquer à l'aide de Composer. Ainsi le fix sera présent que l'on déploie le projet "from scratch" ou lorsque l'on upgradera `symfony/phpunit-bridge`. Un fichier patch peut être bien plus compliqué à générer qu'ici (notamment s'il y a d'autres différences entre le dernier tag et le commit comprenant le fix), mais la méthodologie reste la même.
