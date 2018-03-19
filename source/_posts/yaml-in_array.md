---
title: YAML et in_array, mauvaise surprise
date: 2018-03-18 21:40:13
tags:
  - PHP
---

Je vais ici vous conter une petite mésaventure qui m'est arrivée sur une des applications de la société où je travaille. Nous avons un Yaml de configuration qui indique quels clients doivent passer par une action donnée. Le fichier a cette forme:
```yaml
targetedCustomers:
  - auchan
  - leclerc
  - geant
  - cora
```

Ensuite, rien d'extraordinaire, on utilise in_array pour tester si le client courant est concerné par l'action proposée:
```php
// Some stuff for parsing Yaml before
// $targetedCustomers is worth ['auchan', 'leclerc', 'geant', 'cora'] 
if (in_array($currentCustomer, $targetedCustomers)) {
  // Execute the action
}
```

Jusque là tout va bien. Mais récemment nous avons ajouté le client "yes". Drôle de nom pour un client vous allez me dire. Il n'empêche.

```yaml
targetedCustomers:
  - auchan
  - leclerc
  - geant
  - cora
  - yes
```

Et tout d'un coup **TOUS** nos clients se sont mis à être elligibles pour l'action précédemment évoquée. Pas glop. Comment en est-on arrivé à ce résultat ?

## Yaml et ses valeurs resérvées
En Yaml, certaines valeurs sont automatiquement converties. La chaine de caractères "true" (peu importe la casse) devient le booléan true. De même pour la chaine "on". Et aussi pour la chaine "yes". Tiens ça se précise. Donc une fois parsé, notre Yaml devient:
```php
print_r($targetedCustomers);
/*
Array(
  [0] => auchan,
  [1] => leclerc,
  [2] => geant,
  [3] => cora,
  [4] => 1
)
*/
```
Le premier reflèxe en voyant ce résultat est simplement de se dire que le client "yes" n'est pas dans le tableau donc ne sera jamais elligible. Sauf que le typage faible de php vient enfoncer le clou.

## Les joies du typage dynamique de PHP
Une des premières caractéristiques de PHP est son typage dynamique. Une caractéristique qui a toujours fait de PHP un language un peu à part où se côtoient des bidouilleurs parfois même non informaticiens et des professionnels pour qui ce language n'a aucun secret. La fonction in_array accepte un troisième paramètre qui permet de faire la recherche dans un tableau en vérifiant aussi le type. Voyons donc ce qui ce passe si on ne vérifie pas le type (ce qui est le comportement par defaut):
```php
// strict mode
$test = ["auchan", "leclerc", true];
// in_array("lidl", $test, true) => false
// in_array("auchan", $test, true) => true

// non strict mode (default behavior)
// in_array("lidl", $test) => true
$test2 = ["auchan", "leclerc"];
// in_array(true, $test2) => true
```
Lorsque l'on n'est pas en mode strict, la conversion est à double sens. Si une valeur du tableau convertie dans le type de la valeur à rechercher correspond, on retourne true (ce qui est prévisible). Ce à quoi on s'attend moins, c'est que si la valeur à rechercher convertie dans le type d'une des valeur du tableau correspond à cette valeur, on retourne true aussi. A garder à l'esprit pour éviter ce genre de mésaventure...