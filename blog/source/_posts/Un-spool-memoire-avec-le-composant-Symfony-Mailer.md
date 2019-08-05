---
title: Un spool mémoire avec le composant Symfony Mailer
tags:
  - symfony
  - mailer
  - spool
  - memory
  - kernel.terminate
  - messenger
date: 2019-08-05 17:01:01
---


A partir de Symfony 4.3, un nouveau composant a été introduit pour l'envoi d'emails. Il s'agit du composant *Mailer*. Au moment ou j'écris ces lignes, ce composant n'est encore qu'expérimental (ce qui signifie qu'il peut être modifié voir supprimé à l'occasion d'une release mineure). Il a cependant pour vocation à remplacer le composant *SwiftMailer* jusque là utilisé par Symfony.  
En utilisant ce composant, je me suis aperçu qu'il n'avait pas l'option `spool`. Cette option permettait avec *SwiftMailer* de créer une file d'attente de mails et de ne les envoyer qu'une fois la page affichée à l'utilisateur. Bien pratique lorsque l'on a un serveur mail distant ou un peu lent. N'est ce pour autant pas possible avec le nouveau composant *Mailer* ?<!-- more --> Nous allons voir que nous pouvons retrouver cette fonctionnalité via un autre composant expérimental de Symfony: le composant *Messenger*.

## Principe
Le composant *Mailer* A été prévu pour fonctionner de pair avec le composant *Messenger*. Via des *transports*, on va pouvoir rediriger les emails vers un serveur smtp mais aussi vers un serveur Redis ou un broker AMQP pour envoyer ensuite les emails avec un worker (une tâche de console qui attend de recevoir des *messages* pour les traiter).

Cependant si l'on a peu d'emails à envoyer (un simple formulaire de contact par exemple), monter un serveur Redis ou un broker AMQP pourra sembler un brin overkill. D'autre part, certains serveurs mutualisés ne permettent pas de faire tourner des workers indéfiniment. C'est là que le transport `in-memory` intervient. Présenté comme une [solution pour les tests](https://symfony.com/doc/current/messenger.html#in-memory-transport), ce transport va aussi nous permettre de n'envoyer les emails que lors de l'émission de l'événement `kernel.terminate`. Attention, le transport *in-memory* n'est disponible qu'à partir de la version 4.3 du composant *Messenger*.

## Installation et configuration du composant Messenger
Installons le composant:
```bash
$ composer require messenger
```
Puis paramétrons le:
```yaml
# config/packages/messenger.yaml
framework:
    messenger:
        transports:
            async: '%env(MESSENGER_TRANSPORT_DSN)%'

        routing:
            'Symfony\Component\Mailer\Messenger\SendEmailMessage': async
```
Nous définissons un transport que nous nommons par exemple `async`. La nature de ce transport sera defini par la variable d'environnement `MESSENGER_TRANSPORT_DSN`. Ensuite nous paramétrons que les messages de type `SendEmailMessage` (ceux utilisés par le mailer) utiliseront le transport `async`. Configurons enfin la variable d'environnement `MESSENGER_TRANSPORT_DSN` avec le type de transport `in-memory`:
```dotenv
# .env
MESSENGER_TRANSPORT_DSN='in-memory:///'
```

## Création d'un événement pour l'envoi des messages
Nous allons avoir besoin d'injecter dans notre événement les services `InMemoryTransport` et `MessageHandler`. Seulement ces services ne sont pas identifiés par leur nom de classe. Nous devons donc leur définir des aliases pour pouvoir utiliser l'*autowire*:
```yaml
# config/services.yaml
services:
    # add more service definitions when explicit configuration is needed
    # please note that last definitions always *replace* previous ones
    Symfony\Component\Messenger\Transport\InMemoryTransport: '@messenger.transport.async'
    Symfony\Component\Mailer\Messenger\MessageHandler: '@mailer.messenger.message_handler'
```
Nous pouvons maintenant créer notre `EventSubscriber`:
```php
<?php

namespace App\EventSubscriber;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpKernel\KernelEvents;
use Symfony\Component\Mailer\Messenger\MessageHandler;
use Symfony\Component\Messenger\Transport\InMemoryTransport;

class KernelTerminateSubscriber implements EventSubscriberInterface
{
    private $inMemoryTransport;
    private $messageHandler;

    public function __construct(InMemoryTransport $inMemoryTransport, MessageHandler $messageHandler)
    {
        $this->inMemoryTransport = $inMemoryTransport;
        $this->messageHandler = $messageHandler;
    }

    public static function getSubscribedEvents(): array
    {
        return [KernelEvents::TERMINATE => 'processInMemoryTransport'];
    }

    public function processInMemoryTransport(): void
    {
        $envelopes = $this->inMemoryTransport->get();
        foreach ($envelopes as $envelope) {
            $message = $envelope->getMessage();
            ($this->messageHandler)($message);

            $this->inMemoryTransport->ack($envelope);
        }
    }
}
```
Rien de très "tricky" ci-dessus, on récupère les messages du transport *in-memory*, on déclenche leur envoi via le service `MessageHandler` (qui est un *callable*) et on marque enfin le message comme traité via la méthode `ack`.

## Envoi de l'email
Rien de compliqué non plus dans le code d'envoi de l'email. Le fait que le composant *messenger* soit installé suffit à ce que le message ne soit pas envoyé directement et utilise le bus du composant. L'envoi se fait donc de la même façon que s'il était fait de façon synchrone. Dans un controller ou dans un service, on aura donc le code suivant:
```php
<?php

namespace App\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Routing\Annotation\Route;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Mime\Email;

class MonController extends AbstractController
{
        /**
         * @Route("/envoi-mail", name="envoi_mail")
         */
        public function sendEmail(MailerInterface $mailer): Response
        {
            $email = (new Email())
                        ->from('expediteur@fournisseur.tld')
                        ->to('destinataire@fournisseur.tld')
                        ->subject("Mon sujet")
                        ->text("Mon texte");
                
            $mailer->send($email);
            
            return new Response("Email envoyé avec succès");
        }   
}
```
Et voilà, notre email ne sera envoyé qu'après affichage de la page :)