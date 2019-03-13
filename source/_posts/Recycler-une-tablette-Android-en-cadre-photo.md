---
title: Recycler une tablette Android en cadre photo
description: Utilisation d'une tablette Android comme cadre photo avec mise à jour automatique des photos.
tags:
  - raspberry
  - py
  - photos
  - tablette
  - cadre
  - python
  - fotoo
  - photos-picker
date: 2019-02-20 14:47:08
---


L'éternel problème des cadres photos, c'est qu'il faut mettre les photos à jour. Et peu de gens prennent la peine de le faire, que ce soit sur une carte SD ou sur un compte Dropbox ou autre (pour les cadres photos wifi qui cela dit ne sont pas légions).
Nous allons voir ici comment utiliser une tablette Android comme cadre photo et la mettre automatiquement à jour avec des photos stockées sur un Raspberry Pi (ou un autre système allumé en permanence).  
<!-- more -->Comme évoqué dans [cet article](/2018/04/28/Installer-une-galerie-photo-Piwigo-sur-Raspberry-Pi/), j'utilise Piwigo sur un Raspberry Pi. Toutes mes photos sont donc sur mon Raspberry. Je vais donc pouvoir utiliser cette base de photos pour mettre à jour mon cadre photo numérique.

## Recycler une tablette Android
J'utilise ici une tablette Asus 7" achetée fin 2014 mais devenue trop lente pour un usage classique. Cependant la satisfaction d'avoir un système qui y met efficacement à jour les photos m'incite à réfléchir à l'aquisition d'une tablette dédiée peu puissante mais plus grande (plus de 10" serait bien).  
  
Je me suis largement inspiré de [cet excellent article](https://www.howtogeek.com/335161/how-to-turn-an-old-android-tablet-into-an-auto-updating-digital-photo-frame/) pour cette partie:  
- J'ai acheté [ce support](https://www.amazon.com/Anker-Portable-Multi-Angle-Smartphones-Compatible/dp/B00D856NOG/ref=sr_1_5?creativeASIN=B00D856NOG&linkCode=w61&imprToken=i3a7V8h8JSDE1PNDZTjrbQ&slotNum=0&ie=UTF8&qid=1512442407&sr=8-5&keywords=anker+tablet+stand&tag=823814-20) qui rempli parfaitement son rôle
- J'utilise comme recommandé le logiciel `Fotoo`

Je dois dire que `Fotoo` m'apporte entière satisfaction (j'ai acheté la version premium, plus ou moins 2€ je crois). Il me permet entre autre de démarrer et éteindre automatiquement mon cadre aux horaires que je choisis. Il tourne donc le soir en semaine  et toute la journée le week-end :)  
J'ai choisi que le cadre affiche de façon non aléatoire les photos situées dans un répertoire `Dropbox`.

## Alimenter en photos le compte Dropbox (ou autre)
C'est la brique qu'il me manquait. J'avais toutes mes photos sur un Raspberry Pi, il me manquait le moyen d'en envoyer régulièrement une sélection vers mon compte Dropbox. J'ai décidé d'utiliser `Python` pour ça. Je ne suis pas expert ni même un utilisateur régulier de ce langage mais la version `2.7` à l'immense avantage d'être présente à peu près partout. Sur mon serveur dedié ? J'ai Python 2.7. Sur mon Raspberry Pi ? Idem. Mon Macbook Pro ? J'ai aussi Python 2.7.  
Le [projet](https://github.com/l-vo/photos-picker) est sur github et est en attente de quelques tests supplémentaires pour passer en version `1.0.0`. Mais aucune fonctionnalité supplémentaire ne devrait être ajoutée d'ici là.  
  
Appuyons-nous donc sur cette librairie pour créer un script qui va récupérer des photos sur mon Raspberry et les envoyer vers Dropbox. D'abord il faut installer la librairie:
```bash
$ pip install photos-picker
```
Maintenant le script, nommons le `upload_photos.py` (afin d'améliorer la lisibilité j'ai enlevé les imports):
```python
if __name__ == '__main__':

    try:
        # Ici le parseur d'argument, très pratique en Python.
        # Je choisi de pouvoir faire varier le nombre de photos à récupérer.
        parser = argparse.ArgumentParser()
        desc = "Script allowing to select photos randomly and put them on Dropbox"
        parser.description = desc
        parser.add_argument(
            "photo_count",
            help="Photo count to upload to Dropbox"
        )
        args = parser.parse_args()

        # Les pickers sont les algorithmes qui fixent la façon de sélectionner les photos. On peut sélectionner les photos:
        # - Aléatoirement (RandomPicker)
        # - Juste les dernières (LastPhotosPicker)
        # - "Intelligement" (SmartPicker), le plus intéressant des algorithmes à mon sens,
        #   sur le nombre de photos à récupérer, il va privilégier les photos récentes,
        #   plus les photos sont anciennes, moins elles ont de chance d'être sélectionnés.
        #   Mais il y a malgré tout obligatoirement des anciennes photos dans la sélection.
        picker = SmartPicker(
            # Répertoire où sont situées mes photos
            '/media/dd/piwigo/galleries/Years',
            int(args.photo_count),
            # On peut ordonner les photos par date après sélection (1 ou -1),
            # mais je choisi de le faire aléatoirement (0)
            0,
            # Patterns pour les noms de photos, je garde ceux par défaut:
            # *.tif, *.tiff', *.jpg, *.jpeg, *.png
            None,
            # Répertoires exclus, celui ci contient des miniatures générées par Piwigo
            ['/pwg_representative/']
        )

        # Les filtres vont permettre de modifier les photos avant upload
        # J'utilise les deux disponibles:
        # - RotateFilter permet de tourner la photo si besoin en fonction de l'orientation
        #   portée par les données EXIF. L'argument False permet de ne pas modifier
        #   (inversion width/height) les dimensions de l'image en cas de rotation
        #   (des bandes noires seront présentes de chaque côté).
        # - ResizeFilter permet de modifier la taille de l'image en gardant ses
        #   proportions. La largeur ne sera jamais supérieure à 1920 et la hauteur ne
        #   sera jamais supérieure à 1200.
        filters = (RotateFilter(False), ResizeFilter(1920, 1200))

        # Token Dropbox qui va donner à photos-picker les droits pour uploader les photos
        # (voir https://blogs.dropbox.com/developers/2014/05/generate-an-access-token-for-your-own-account/)
        token = 'mon-token-Dropbox'
        # L'uploader va permettre de choisir ou envoyer les photos (ici Dropbox)
        # Les uploaders acceptent en 2ème argument le répertoire ou seront stockées
        # les photos. Je me contente du répertoire par défaut: photos-picker
        uploader = DropboxUploader(token)

        # Création d'une instance photos-picker
        photos_picker = PhotosPicker(picker, filters, uploader)
        # Lancement de la récolte, des modifications et de l'upload des photos
        photos_picker.run()
    
    # Affichage "propre" des erreurs de type Exception
    except Exception as err:
        print("ERROR: {message}".format(message=err.message))

```
A noter que comme je n'ai pas spécifié de répertoire à `DropboxUploader`, le répertoire par défaut de l'uploader qui sera utilisé c'est à dire `photos-picker` pour `DropboxUploader`. C'est donc ce répertoire qui doit être configuré dans `Fotoo`.  
Photos-picker utilise [zope.event](https://zopeevent.readthedocs.io/en/latest/) qui permet d'émettre des évenement sur l'avancement des tâches. Nous allons utiliser [zope.event.classhandler](https://zopeevent.readthedocs.io/en/latest/classhandler.html) pour écouter ces événements:
```python
@handler(ScanProgressEvent)
def progress_listener(event):
    """
    Display pick progression

    :param ScanProgressEvent event: event
    """
    percent = int(event.files_scanned * 100/event.files_to_scan)
    print("\rScanning files: {percent}%".format(percent=percent), end='')
    sys.stdout.flush()

    if event.end:
        print("\nPicking photos...")


@handler(StartUploadEvent)
def start_upload_listener(event):
    """
    Display info when an upload starts

    :param StartUploadEvent event: event
    """

    msg = "Upload {rank}/{total}: uploading {filepath}..."
    print(msg.format(
        rank=event.upload_file_rank,
        total=event.files_to_upload,
        filepath=event.filepath
    ), end='')
    sys.stdout.flush()


@handler(EndUploadEvent)
def end_upload_listener(event):
    """
    Display info when an upload ends

    :param EndUploadEvent event: event
    """
    msg = "\rUpload {uploaded}/{total}: upload finished for {filepath}"
    print(msg.format(
        uploaded=event.uploaded_files,
        total=event.files_to_upload,
        filepath=event.filepath
    ))


@handler(StartFilterEvent)
def start_filter_listener(event):
    """
    Display when a filter start

    :param StartFilterEvent event: event
    """
    msg = "Start filter {filter} for {filepath}"
    print(msg.format(filter=event.filter_name(), filepath=event.filepath()))


@handler(EndFilterEvent)
def end_filter_listener(event):
    """
    Display when a filter end

    :param EndFilterEvent event: event
    """
    msg = "End filter {filter} for {filepath}"
    print(msg.format(filter=event.filter_name(), filepath=event.filepath()))
```
Les écouteurs ci-dessus permettent d'avoir une indication de la progression de la récolte des photos, et pour chaque photo récoltée, du début et de fin de chaque filtre et de l'upload. Voilà le code complet du script:
```python
#!/usr/bin/env python

#######################################################################
#                                                                     #
# Script allowing to select photos randomly and put them on dropbox   #
# (based on photos-picker lib (https://github.com/l-vo/photos-picker) #
#                                                                     #
#                                                                     #
# Requirements: pip install -r requirements.txt                       #
#                                                                     #
# Usage: ./photos_picker.py <photo_count>                             #
#                                                                     #
#######################################################################

from __future__ import division
from __future__ import print_function

import argparse

from photospicker.picker.pickers.smart_picker import SmartPicker
from photospicker.uploader.dropbox_uploader import DropboxUploader
from photospicker.filter.rotate_filter import RotateFilter
from photospicker.filter.resize_filter import ResizeFilter
from photospicker.event.scan_progress_event import ScanProgressEvent
from photospicker.event.start_upload_event import StartUploadEvent
from photospicker.event.end_upload_event import EndUploadEvent
from photospicker.event.start_filter_event import StartFilterEvent
from photospicker.event.end_filter_event import EndFilterEvent
from zope.event.classhandler import handler
from photospicker.photos_picker import PhotosPicker

import sys


@handler(ScanProgressEvent)
def progress_listener(event):
    """
    Display pick progression

    :param ScanProgressEvent event: event
    """
    percent = int(event.files_scanned * 100/event.files_to_scan)
    print("\rScanning files: {percent}%".format(percent=percent), end='')
    sys.stdout.flush()

    if event.end:
        print("\nPicking photos...")


@handler(StartUploadEvent)
def start_upload_listener(event):
    """
    Display info when an upload starts

    :param StartUploadEvent event: event
    """

    msg = "Upload {rank}/{total}: uploading {filepath}..."
    print(msg.format(
        rank=event.upload_file_rank,
        total=event.files_to_upload,
        filepath=event.filepath
    ), end='')
    sys.stdout.flush()


@handler(EndUploadEvent)
def end_upload_listener(event):
    """
    Display info when an upload ends

    :param EndUploadEvent event: event
    """
    msg = "\rUpload {uploaded}/{total}: upload finished for {filepath}"
    print(msg.format(
        uploaded=event.uploaded_files,
        total=event.files_to_upload,
        filepath=event.filepath
    ))


@handler(StartFilterEvent)
def start_filter_listener(event):
    """
    Display when a filter start

    :param StartFilterEvent event: event
    """
    msg = "Start filter {filter} for {filepath}"
    print(msg.format(filter=event.filter_name(), filepath=event.filepath()))


@handler(EndFilterEvent)
def end_filter_listener(event):
    """
    Display when a filter end

    :param EndFilterEvent event: event
    """
    msg = "End filter {filter} for {filepath}"
    print(msg.format(filter=event.filter_name(), filepath=event.filepath()))


if __name__ == '__main__':

    try:
        parser = argparse.ArgumentParser()
        desc = "Script allowing to select photos randomly and put them on Dropbox"
        parser.description = desc
        parser.add_argument(
            "photo_count",
            help="Photo count to upload to Dropbox"
        )
        args = parser.parse_args()

        picker = SmartPicker(
            '/media/dd/piwigo/galleries/Years',
            int(args.photo_count),
            0,
            None,
            ['/pwg_representative/']
        )

        filters = (RotateFilter(False), ResizeFilter(1920, 1200))

        token = 'mon-token-Dropbox'
        uploader = DropboxUploader(token)

        photos_picker = PhotosPicker(picker, filters, uploader)
        photos_picker.run()
    except Exception as err:
        print("ERROR: {message}".format(message=err.message))

```

## Planification de la tâche
Il suffit maintenant d'ajouter notre script dans crontab (`crontab -e`):
```
# Photoframe
0 6 * * 1-5 /media/dd/pyscripts/src/photo/upload_photos.py 200 >/var/log/upload_photos.log 2>&1
0 6 * * 6-7 /media/dd/pyscripts/src/photo/upload_photos.py 1000 >/var/log/upload_photos.log 2>&1
```
Je change ainsi mon lot de photos tous les jours. Du lundi au vendredi, je charge un nombre de photo plus restreint (200) par rapport au week-end (1000) ou le cadre photo reste allumé toute la journée.  
Dans ke fichier `/var/log/upload_photos.log`, je loggue les infos de progression émises par les écouteurs précédemment mis en place (et les éventuelles erreurs au cas où).

## Conclusion

### Vue d'ensemble
Avec un Raspberry, une tablette et quelques scripts, j'ai désormais la possibilité de partager mes photos (merci [Piwigo](https://fr.piwigo.org/)), mais aussi d'en transférer journalièrement sur ma tablette pour avoir l'équivalent d'un cadre photo boosté.

### L'architecture du Raspberry en question ?
Un petit bémol cependant, j'ai régulièrement des *segmentation fault* sur `photos-picker` lorsque je travaille sur un grand nombre de photos. L'architecture (ou peut être simplement la puissance ?) du Raspberry Pi 3 semble montrer ses limites (qui ont aussi nécessité le contournement pour Piwigo que j'ai décrit dans [mon article précédent](/2018/04/28/Installer-une-galerie-photo-Piwigo-sur-Raspberry-Pi/)). Un Raspberry like plus puissant ou mieux un petit PC qui ne soit pas limité par une architecture `ARM` serait sûrement idéal.  
On peut évidement penser aussi à un serveur dedié à condition d'avoir une capacité de disque assez importante pour stocker toutes nos photos mais aussi un débit en upload suffisant pour que chaque transfert de photos vers le serveur ne soit pas un calvaire (et avec le poids des photos aujourd'hui, ça peut vite l'être).