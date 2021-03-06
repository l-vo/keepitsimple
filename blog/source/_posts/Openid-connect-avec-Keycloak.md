---
title: Openid connect avec Keycloak
tags:
  - keycloak
  - openid
  - sso
  - symfony
  - security
  - authenticator
description: >
  Examples d'authentification en suivant le protocole OpenId Connect avec
  Keycloak et Symfony
date: 2022-01-05 21:29:28
---


# Jouons avec le nouveau composant security de Symfony

## Introduction
Dans cet article, nous allons utiliser Keycloak, un IAM implémentant le protocole OpenId pour le SSO. Les fonctionnalités et possibilités de paramétrages de Keycloak sont très nombreuses (utilisation d'autres identity providers populaires comme Twitter, Facebook, Github etc, 2FA...). Dans cet article nous utiliserons des utilisateurs directement enregistrés dans Keycloak. Vous pouvez trouver [l'exemple complet présenté dans cet article](https://github.com/l-vo/sf_keycloak_example) (qui utilise un container Docker pour Keycloak) sur mon compte Github. A noter que le code est à considérer comme à but pédagogique. Certains cas peuvent ne pas avoir été traités pour un usage en production (et il n'y a pas de couverture de tests).
<!--more-->

## Les Authenticators
Le nouveau système de sécurité de Symfony se base sur des [Authenticators](https://symfony.com/doc/5.4/security/custom_authenticator.html). Les classes authenticators ressemble dans leur structure à ce que proposait le désormais déprécié composant security-guard. Cependant Guard n'était qu'une méthode pouvant permettre d'écrire un système d'authentification, certains autre systèmes cohabitaient avec (form-login, ldap etc). La refonte du système de sécurité apporte une consistence supplémentaire. Toutes les méthodes d'authentification passent désormais par un authenticator. Voici l'interface des authenticators:
```php
interface AuthenticatorInterface
{
    public function supports(Request $request): ?bool;
    public function authenticate(Request $request): PassportInterface;
    public function createAuthenticatedToken(PassportInterface $passport, string $firewallName): TokenInterface;
    public function onAuthenticationSuccess(Request $request, TokenInterface $token, string $firewallName): ?Response;
    public function onAuthenticationFailure(Request $request, AuthenticationException $exception): ?Response;
}
```
La méthode *supports* permet d'activer l'authenticator. Dans notre cas, on veut que Symfony valide l'authentification lorsque le serveur OpenId redirige vers notre site sur la *redirect-uri* paramétrée. Notre code est donc:
```php
public function supports(Request $request): ?bool
{
    return 'openid_redirecturi' === $request->attributes->get('_route');
}
```
Les méthodes *onAuthenticationSuccess* et *onAuthenticationFailure* sont appellées en cas de succès ou d'échec. Elles permettent de retourner une réponse. Si *null* est retourné, l'action suis son cours avec le controller lié à la route. Dans notre cas nous n'avons pas associé de controller à la route `openid_redirecturi`. Nous devons donc forcément retourner une réponse:
```php
public function onAuthenticationSuccess(Request $request, TokenInterface $token, string $firewallName): ?Response
{
    return new RedirectResponse($this->urlGenerator->generate('profile'));
}

public function onAuthenticationFailure(Request $request, AuthenticationException $exception): ?Response
{
    $request->getSession()->getFlashBag()->add(
        'error',
        'An authentication error occured',
    );

    return new RedirectResponse($this->urlGenerator->generate('home'));
}
```
La méthode *createAuthenticatedToken* créé le token de sécurité une fois l'authentification réussie. Ce concept existait déjà avec l'ancien système d'authentification. Cependant des tokens pouvaient être créés avant même la validation de l'authentification. Ce n'est plus le cas maintenant. Voici le code simplifié:
```php
public function createAuthenticatedToken(PassportInterface $passport, string $firewallName): TokenInterface
{
    $token = parent::createAuthenticatedToken($passport, $firewallName);

    $currentRequest = $this->requestStack->getCurrentRequest();
    $jwtExpires = $currentRequest->attributes->get('_app_jwt_expires');
    $currentRequest->attributes->remove('_app_jwt_expires');

    $tokens = $passport->getAttribute(TokensBag::class);
    $token->setAttribute(TokensBag::class, $tokens->withExpiration($jwtExpires));

    return $token;
}
```
On remarque la notion de **passport**. Les passports et les **badges** sont une nouveauté de ce système (nous y reviendrons plus tard). Si l'on étend la classe *AbstractAuthenticator* le token est créé pour nous. Ici nous décorons la méthode de l'AbstractAuthenticator car nous souhaitons ajouter un attribut au token. L'attribut contient un DTO composé du token JWT, du refresh token et du timestamp d'expiration du JWT. La possibilité d'attacher des attributs existe maintenant aussi pour les passports. Cela permet de faire transiter des données supplémentaires sans devoir créer une classe spécifique pour le passport et/ou le token de sécurité.

Deux interfaces supplémentaires ont été implémentées, il s'agit de *InteractiveAuthenticatorInterface* et *AuthenticationEntryPointInterface*. La première ajoute une méthode `isInteractive`. Lorsque cette méthode retourne *true*, l'utilisateur peut être autorisé pour les actions qui demande l'attribut `IS_AUTHENTICATED_FULLY`. Enfin *AuthenticationEntryPointInterface* avec sa méthode *start* permet de specifier l'action a effectuer lorsque l'utilisateur essai d'aller sur une page dont il n'a pas les permissions et qu'il n'est pas encore authentifié. Dans notre cas, on veut rediriger vers l'url d'autorisation du server Keycloak:
```php
public function start(Request $request, AuthenticationException $authException = null): Response
{
    $state = (string)Uuid::v4();
    $request->getSession()->set(self::STATE_SESSION_KEY, $state);

    $qs = http_build_query([
        'client_id' => $this->clientId,
        'response_type' => 'code',
        'state' => $state,
        'scope' => 'openid roles profile email',
        'redirect_uri' => $this->urlGenerator->generate('openid_redirecturi', [], UrlGeneratorInterface::ABSOLUTE_URL),
    ]);

    return new RedirectResponse(sprintf('%s?%s', $this->authorizationEndpoint, $qs));
}
```
Le state mis en session est un moyen recommandé lorsque l'on utilise Oauth ou Openid pour protéger des attaques CSRF.

## Passport et badges
Le **passport** est l'objet qui va être utilisé pour valider l'authentification. A noter qu'il n'est pas conservé après le processus d'authentification. Il sert principalement de conteneur pour les **badges**. Les badges permettent plusieurs choses:
- Porter une information (ex: *UserBadge*)
- Effectuer une validation (ex: *PasswordCredentials*)
- Déclencher une fonctionnalité (ex: *RememberMeBadge*, *PasswordUpgradeBadge*)

En interne, Symfony emet un événement `CheckPassportEvent`. Un certain nombre de listeners écoutent cet événement, mais n'effectuent leur action qu'en fonction de la présence ou non de certains badges dans le passport. Les badges peuvent également être résolus. Certains sont déjà résolus à leur création, et d'autre ne le sont que si le listener associé à validé son action (ex de badge qui nécessite d'être résolu: *PasswordCredentials*). Après avoir émis l'événement *checkPassport*, le composant security ne valide l'authentification que si tous les badges du passport sont résolus.
Le rôle de la méthode *authenticate* de l'authenticator est de, à partir des informations de la requête, créer un passport avec les badges nécessaires. L'implémentation pour notre cas:
```php
public function authenticate(Request $request): PassportInterface
{
    $sessionState = $request->getSession()->get(self::STATE_SESSION_KEY);
    $queryState = $request->get(self::STATE_QUERY_KEY);
    if ($queryState === null || $queryState !== $sessionState) {
        throw new InvalidStateException();
    }
    
    $request->getSession()->remove(self::STATE_SESSION_KEY);

    $response = $this->openIdClient->getTokenFromAuthorizationCode($request->query->get('code', ''));

    $responseData = json_decode($response, true);
    $jwtToken = $responseData['id_token'];
    $refreshToken = $responseData['refresh_token'];

    $userBadge = new UserBadge($jwtToken);
    $passport = new SelfValidatingPassport($userBadge, [new PreAuthenticatedUserBadge()]);

    $passport->setAttribute(TokensBag::class, new TokensBag($jwtToken, $refreshToken));

    return $passport;
}
```
Pour faciliter la lisibilité, le code est simplifié par rapport à celui du repository (principalement sur les gestions d'erreurs). Mais l'essentiel est là. Dans cette méthode:
- On vérifie le state précédemment enregistré en session pour se protéger des attaques CSRF
- On récupère JWT et refresh token auprès du server Keycloak grâce au code d'autorisation présent dans la requête
- On créé un passport de type *SelfValidatingPassport*. Ce passport est à utiliser lorsque ce n'est pas notre application à proprement dit qui valide les credentials. La particularité de ce passport est donc de ne pas nécessiter de badge pour les credentials. Pour la même raison on ajoute le badge *PreAuthenticatedUserBadge* qui permet de bypasser la méthode *checkPreAuth* des [user checkers](https://symfony.com/doc/5.4/security/user_checkers.html).
- On passe des données au passport via les attributs pour pouvoir les passer au token de sécurité créé dans la méthode *createAuthenticatedToken* vue précédemment.

## User providers
Les [user providers](https://symfony.com/doc/5.4/security/user_providers.html) dans Symfony servent à:
- Retourner un objet implémentant *UserInterface* à partir d'un identifiant unique (celui contenu dans *UserBadge*)
- Rafraîchir cet objet à chaque requête (en général pour rester à jour avec les données en base de données

Une application Symfony doit avoir au minimum un user provider. Notre cas est un peu différent des user providers classiques où on irait chercher les informations utilisateur dans une source externe (base de donnée, API...). Les informations sont déjà présentes dans le JWT, le chargement de l'utilisateur à partir de l'identifiant unique va donc simplement consister à décoder le JWT:
```php
final class OpenIdUserProvider implements UserProviderInterface
{
    //...

    public function refreshUser(UserInterface $user): UserInterface
    {
        return $user;
    }

    public function supportsClass(string $class): bool
    {
        return $class === User::class;
    }

    public function loadUserByIdentifier(string $jwtToken): UserInterface
    {
        $decoded = JWT::decode($jwtToken, new Key($this->publicKey, 'RS256'));

        $currentRequest = $this->requestStack->getCurrentRequest();
        $currentRequest->attributes->set('_app_jwt_expires', $decoded->exp);

        return new User(
            $decoded->sub,
            $decoded->preferred_username,
            $decoded->email,
            $decoded->name,
            $decoded->realm_access->roles,
        );
    }
}
```
Nous n'avons pas besoin non plus de rafraîchir l'utilisateur. Ce serait en revanche le cas si des données de notre base locale étaient attachées à l'objet utilisateur. La méthode *supportClass* est directement liée à *refreshUser*. Elle permet de déterminer quel user provider doit être utilisé pour rafraîchir notre objet utilisateur en session.
On notera les roles *$decoded->realm_access->roles* dans le JWT. On peut parfaitement définir nos rôles dans Keycloak pour les utilier ensuite dans notre application Symfony, à condition qu'ils respectent le pattern `ROLE_*`. On voit également que l'on utilise un attribut de requête pour transporter le timestamp d'expiration du JWT à l'extérieur du user provider. Ce choix peut être discuté mais il m'a semblé être la moins mauvaise solution (par rapport à, par exemple, avoir une propriété pour l'expiration du JWT dans l'objet implémentant *UserInterface*).

Le plus gros de l'authentification est fait. Il reste cependant deux point à traiter afin d'avoir un système complet, le renouvellement du JWT et la déconnexion.

## Déconnexion

Symfony prend en charge une grande partie du process de logout à partir du moment ou l'on défini une route ou un path sous la clé de firewall *logout*. Ci-dessous la configuration utilisée dans notre exemple:
```yaml
security:
    enable_authenticator_manager: true

providers:
    keycloak:
        id: App\Security\OpenIdUserProvider

    firewalls:
        dev:
            pattern: ^/(_(profiler|wdt)|css|images|js)/
            security: false
        main:
            lazy: true
            custom_authenticator: App\Security\OpenIdAuthenticator
            logout:
                path: logout

    access_control:
        - { path: ^/profile, roles: ROLE_USER }
```
La route *logout* a été définie dans le routing (par défaut on redirige vers le path `/`). Le comportement de base fourni par Symfony peut suffir dans beaucoup de cas. Dans notre contexte de SSO, nous voulons aller un peu plus loin est aussi déconnecter l'utilisateur du serveur Keycloak. Depuis sa version 5.1, Symfony émet un événement spécifique au moment de la déconnexion (*LogoutEvent*), nous allons simplement nous brancher dessus pour déconnecter l'utilisateur du SSO:
```php
final class LogoutListener implements EventSubscriberInterface
{
    //...

    public function logoutFromOpenidProvider(LogoutEvent $event): void
    {
        $token = $this->tokenStorage->getToken();

        $user = $token->getUser();
        if (!$user instanceof User) {
            return;
        }

        $tokens = $token->getAttribute(TokensBag::class);
        $this->openIdClient->logout($tokens->getJwt(), $tokens->getRefreshToken());
    }

    public static function getSubscribedEvents(): array
    {
        return [LogoutEvent::class => 'logoutFromOpenidProvider'];
    }
}
```

## Regénération du JWT

Un JWT est prévu pour avoir une durée de validité assez courte. En effet, tant qu'il est valide, il n'est normalement pas nécessaire d'interroger le serveur émetteur pour avoir une éventuelle mise à jour de son état. En revanche lorsqu'il arrive à expiration, il doit être renouvellé grâce au refresh token. C'est à ce moment là que le fournisseur d'identité pourra renvoyer un JWT avec de nouvelles données (rôles...) si celles-ci ont été modifiés voir même une erreur si l'utilisateur n'est plus du tout autorisé à accéder au SSO.

Nous avons utilisé un listener sur *kernel.request* pour ce besoin. Il pourrait également paraitre logique de le faire dans la méthode *refreshUser* du user provider. C'est effectivement possible, mais la redirection (si besoin) vers une autre page est moins simple dans certain cas, par exemple celui où *refreshUser* est appellé alors qu'on est en train d'afficher un template Twig (via un appel à *is_granted*). Voilà donc notre event listener (toujours simplifié par rapport à la version du repo pour une question de lisibilité):
```php
final class JwtRefreshListener implements EventSubscriberInterface
{
    //...

    public function onKernelRequest(RequestEvent $event): void
    {
        $token = $this->tokenStorage->getToken();
        if (null === $token) {
            return;
        }

        $tokens = $token->getAttribute(TokensBag::class);
        if (time() < $tokens->getJwtExpires()) {
            return;
        }

        $refreshToken = $tokens->getRefreshToken();

        try {
            $response = $this->openIdClient->getTokenFromRefreshToken($refreshToken);
        } catch (HttpExceptionInterface $e) {
            $response = $e->getResponse();
            if (400 === $response->getStatusCode() && 'invalid_grant' === ($response->toArray(false)['error'] ?? null)) {
                // Logout when SSO session idle is reached
                    $this->tokenStorage->setToken(null);
                    $event->setResponse(new RedirectResponse($this->urlGenerator->generate('home')));

                    return;
            }

            throw new RuntimeException(
                sprintf('Bad status code returned by openID server (%s)', $e->getResponse()->getStatusCode()),
                previous: $e,
            );
        }

        $responseData = json_decode($response, true);
        $jwtToken = $responseData['id_token'];
        $refreshToken = $responseData['refresh_token'];
        $user = $this->userProvider->loadUserByIdentifier($jwtToken);

        $request = $event->getRequest();
        $jwtExpires = $request->attributes->get('_app_jwt_expires');
        $request->attributes->remove('_app_jwt_expires');

        $token->setAttribute(TokensBag::class, new TokensBag($jwtToken, $refreshToken, $jwtExpires));

        $token->setUser($user);
    }

    public static function getSubscribedEvents(): array
    {
        return [RequestEvent::class => 'onKernelRequest'];
    }
}
```
Dans le cas ou le JWT est expiré, on interroge le serveur Keycloak pour avoir des nouveaux JWT et refresh token. Grâce au JWT on peut ainsi recharger une version "à jour" de l'utilisateur. En cas de retour *invalid_grant* par le SSO, on déconnecte l'utilisateur de l'application.

## Conclusion
Ainsi se termine ce petit exemple d'authentification avec le système d'Authenticators. On remarque que même dans un flow d'authentification un peu plus complexe qu'une vérification de login/password en base de donnée, les composants de Symfony sont comme souvent suffisament flexibles pour s'adapter à presque tous les cas d'utilisations.
