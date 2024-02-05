---
title: 'Doctrine ORM: astuces et pièges'
tags:
  - doctrine
description: >-
  La recherche de l'optimisation est une tâche fréquente lorsque l'on utilise
  Doctrine ORM. Voici quelques astuces mais aussi les pièges à éviter.
date: 2020-06-02 20:32:22
---


[Doctrine ORM](https://www.doctrine-project.org/projects/doctrine-orm/en/current/index.html) est une librairie PHP qui fournit une abstraction de la couche de persistence des donnéees et permet ainsi au développeur de se focaliser sur une approche orientée object de sa logique métier.  
Si l'utilisation de *Doctrine* apporte (comme pour d'autres ORM) un code plus clair et un gain de temps pour le développeur, la contrepartie est une consommation de mémoire plus importante voire (si l'on n'y prend pas garde) une augmentation du nombre de requêtes. Nous allons aborder dans cet article quelques astuces mais aussi des pièges à éviter.
<!-- more -->

## Le problème des requêtes N+1

Probablement le cas le plus connu et le plus rencontré. Supposons que nous ayons des entités `Product` et `Category`. Une categorie étant composée de plusieurs produits. Si je souhaite lister tous mes produits pas catégorie je pourrais avoir le code suivant:
```php
$categories = $entityManager->getRepository(Category::class)->findAll();

foreach ($categories as $category) {
    echo $category->getName().":";
    
    foreach ($category->getProducts() as $product) {
        echo " ".$product->getName();
    }

    echo "\n";
}
```
Avec cette approche, Doctrine va faire une première requête pour récupérer toute les catégories. Ensuite pour chaque catégorie, une nouvelle requête est lancée pour récupérer tous les produits de la catégorie. Ce n'est pas dramatique tant qu'il y a peu de produits, mais imaginons que nous ayons 1000 catégories de 2-3 produits chacune, souhaitons nous vraiment effectuer 1000 requêtes ? Doctrine se comporte par default de façon **lazy**, ce qui signifie qu'il ne vas pas essayer de récupérer les entités liés tant qu'on ne demande pas un champ de ces entités (`$product->getName()` ici).
La solution la plus simple dans ce genre de cas est d'effectuer une jointure dans la requête initiale:
```php
class CategoryRepository
{
    public function findAllWithProducts(): array
    {
        return $this
            ->createQueryBuilder('c')
            ->leftJoin('c.products', 'p')
            ->addSelect('p')
            ->getQuery()
            ->getResult();
    }
}
```
En utilisant `findAllWithProducts` au lieu de `findAll`, seulement une requête sera effectuée pour ramener toutes les catégories et leurs produits liés. Pas de piège particulier ici, la difficulté résidera dans la faculté à trouver l'équilibre entre requêtes avec jointures et requêtes sans jointure sous peine de voir exploser le nombre de méthodes des repositories. Une autre possibilité qui peut éviter de créer une méthode de repository que l'on utiliserait qu'une seule fois est de s'appuyer sur le fonctionnement de l'**identity map**.


## L'identity map de Doctrine
L'identity map une notion est essentielle pour comprendre Doctrine. L'ORM maintient en interne une *hashmap* de toutes les entités déjà obtenues par le script courant lors de requêtes vers la base de donnée. Les clés de la hashmap sont les identifiants de ces entités. chaque fois que Doctrine requête à nouveau une entité présente dans son **identity map**, l'entité en mémoire est retournée sans faire un nouvel appel à la base de donnée.  
Attention cependant, celà ne fonctionne que si l'entité est requêtée à partir de son identifiant; c'est à dire lorsque l'on utilise la méthode `find()` des repositories ou lorsque l'on récupère une entité à partir d'une autre entité à laquelle elle est liée (`$category->getProducts()` dans notre cas des [requêtes N+1](#Le-probleme-des-requetes-N-1).  
Sachant celà, si l'on reprend l'exemple cité et que l'on ne souhaite pas créer la méthode de repository `findAllWithProducts`, on peut procéder de cette façon:
```php
$categories = $entityManager->getRepository(Category::class)->findAll();
$products = $entityManager->getRepository(Product::class)->findAll();

foreach ($categories as $category) {
    echo $category->getName().":";
     
    foreach ($category->getProducts() as $product) {
        echo " ".$product->getName();
    }
    
    echo "\n";
}
```
Ici deux requêtes suffisent pour obtenir tous nos enregistrements. Lorsque `findAll` est exécutée depuis le repository des produits, tous les produits sont chargés dans l'identity map. Ainsi les produits peuvent être récupérés depuis l'identity map économisant de cette façon des appels vers la base de donnée.

## Vider l'identity map
Le fait que PHP libère la mémoire à la fin des scripts (et donc une fois la page affichée lorsqu'utilisé derrière un serveur web) permet de grandement limiter les problèmes de mémoire possibles. Mais lorsque l'on utilise Doctrine dans des **long-running scripts** (scripts de maintenance, etc), la mémoire peut vite devenir un problème (notament à cause du fait que les entités sont conservés dans l'identity map). Doctrine nous permet cependant de [nettoyer l'identity map](https://www.doctrine-project.org/projects/doctrine-orm/en/current/reference/working-with-objects.html#entities-and-the-identity-map). La méthode `clear` peut être utilisée sans argument pour vider complétement l'identity map ou avec une classe d'entity pour ne nettoyer que les entités du type fourni. Mais voyons les effets de bord que `clear` peut engendrer lorsqu'on ne nettoie qu'un type d'entité:
```php
foreach ($categories as $category) {
    echo $category->getName().":";
    
    $count = 0;
    foreach ($category->getProducts() as $product) {
        echo " ".$product->getName();
        $count++;
    }
    
    echo "\n";
    $category->setProductCount($count);
    $entityManager->clear(Product::class);
}
$entityManager->flush();
```
Si nous utilisons un [logger de queries](https://www.doctrine-project.org/projects/doctrine-orm/en/current/reference/advanced-configuration.html#sql-logger-optional) (je vous conseille vivement d'en utiliser un si vous débutez avec Doctrine, ça vous aidera à comprendre comment la librairie se comporte), nous allons constater qu'une requête d'`INSERT` est effectuée pour chaque produit. Un effet de bord que personne ne souhaite avoir dans son application ! Dans notre cas, Doctrine ne possède plus les produits dans sa liste d'objets managés. Par contre elle possède toujours les catégories qui sont encore porteurs des produits. Lorsque l'on effectue le `flush`, et que Doctrine calcul les changements, il interprète les produits au sein des entités categories comme de nouvelles entités et cherche donc à les insérer.  
Vous l'aurez peut être deviné, ce que j'ai écrit n'est pas tout à fait juste car pour que ce comportement se produise, il faut que les entités `Category` aient leur collection de produits paramétrée en `cascade: persist`. Il est prévu pour **Doctrine 3.0** de supprimer la possibilité de ne nettoyer qu'un type d'entité via `clear` ce qui devrait empêcher ce comportement. Mais d'ici que **Doctrine 2.x** disparaisse complétement, connaître ce possible problème vous évitera peut être des mésaventures !   

## Les partial objects
Dans sa documentation, Doctrine aborde le cas des [partial objects](https://www.doctrine-project.org/projects/doctrine-orm/en/current/reference/partial-objects.html) mais sans vraiment recommander leur usage car utiliser des objects qui n'ont pas toutes leurs propriétés chargées peut être déroutant et source d'erreurs. Il est important de savoir qu'un partial object n'est pas sauvegardé lorsqu'on le modifie. C'est un comportement cohérent mais le fait qu'aucune erreur ne soit levée peut masquer le problème. De plus il faut garder à l'esprit que lorsque vous utilisez **DQL** ou le **query builder** pour ramener un partial object par son identifiant, vous n'interrogez pas l'[identity map](#L’identity-map-de-Doctrine), pour voir si l'entité est déjà en mémoire. Pire, je ne sais pas s'il s"agit d'un bug ou d'un comportement acceptable mais une fois qu'un objet partial est stocké dans l'identity map, vous ne pouvez plus récupérer l'objet complet de façon classique:
```php
    $product = $entityManager
        ->getRepository(Product::class)
        ->createQueryBuilder('p')
        ->select('PARTIAL c.{id, name}')
        ->where('c.id = :id')
        ->setParameter('id', 5)
        ->getQuery()
        ->getOneOrNullResult();

    var_dump($product->getDescription());  // null

    $product = $entityManager->getRepository(Product::class)->find(5);
    var_dump($product->getDescription());  // null

    $entityManager->refresh($product);
    var_dump($product->getDescription());  // "My description"
```
Ainsi l'appel à `find` continue de renvoyer le partial object et c'est bien `refresh` qu'il faut appeler pour récupérer l'object complet. 